import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';
import 'package:subtitle_studio/services/checkpoint_reference_catalog.dart';
import 'package:subtitle_studio/services/checkpoint_reference_migration_plan.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// Persistent reference boundary. In-transaction functions MUST be called
/// inside the caller's Isar writeTxn, never through nested transactions.
class HistoryRefRepository {
  final Isar _isar;
  HistoryRefRepository(this._isar);

  static String _kind(CheckpointReferenceKind kind) => switch (kind) {
    CheckpointReferenceKind.head => 'head',
    CheckpointReferenceKind.branchTip => 'branch',
    CheckpointReferenceKind.manualBookmark => 'bookmark',
  };

  /// Validates all refs before returning them, so partially upgraded or
  /// corrupt sessions cannot silently point to another project's commits.
  static Future<List<HistoryRef>> ensureMigratedInTransaction(
    Isar isar, {
    required int sessionId,
  }) async {
    final refs = await isar.historyRefs
        .filter().sessionIdEqualTo(sessionId).findAll();
    final commits = await isar.checkpoints
        .filter().sessionIdEqualTo(sessionId).findAll();
    if (refs.isNotEmpty) {
      _validateExisting(refs, commits, sessionId);
      return refs;
    }
    if (commits.isEmpty) return const <HistoryRef>[];

    // The plan validates the entire legacy/V2 parent graph before a write.
    // A corrupt graph aborts the enclosing transaction without partial refs.
    final plan = CheckpointReferenceMigrationPlan.prepare(commits);
    final headId = plan.headCheckpointId!;
    if (plan.requiresLegacyHeadNormalization) {
      CheckpointHeadReference.moveInMemory(
        checkpoints: commits,
        checkpointId: headId,
      );
      await isar.checkpoints.putAll(commits);
    }
    final createdAt = DateTime.now().toUtc();
    final created = <HistoryRef>[
      for (final reference in plan.references)
        HistoryRef(
          sessionId: sessionId,
          subtitleCollectionId: plan.subtitleCollectionId!,
          name: reference.name,
          kind: _kind(reference.kind),
          targetCheckpointId: reference.checkpointId,
          symbolicBranchName:
              reference.name == 'HEAD' ? 'refs/heads/main' : null,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
    ];
    await isar.historyRefs.putAll(created);
    return created;
  }

  static void _validateExisting(
    List<HistoryRef> refs,
    List<Checkpoint> commits,
    int sessionId,
  ) {
    if (commits.isEmpty) {
      throw const CheckpointIntegrityException(
        'Stored history refs exist without checkpoint history.',
      );
    }
    final byId = {for (final c in commits) c.id: c};
    final byName = <String, HistoryRef>{};
    for (final ref in refs) {
      if (ref.sessionId != sessionId ||
          ref.schemaVersion != 1 ||
          ref.subtitleCollectionId != commits.first.subtitleCollectionId ||
          !byId.containsKey(ref.targetCheckpointId) ||
          ref.name.isEmpty) {
        throw const CheckpointIntegrityException(
          'Stored history reference has an invalid target or owner.',
        );
      }
      final target = byId[ref.targetCheckpointId]!;
      if (target.sessionId != sessionId ||
          target.subtitleCollectionId != ref.subtitleCollectionId ||
          byName.containsKey(ref.name) ||
          !_validName(ref.name, ref.kind) ||
          (ref.kind != 'head' && ref.symbolicBranchName != null) ||
          (ref.name == 'HEAD' && ref.kind != 'head') ||
          (ref.name.startsWith('refs/heads/') && ref.kind != 'branch') ||
          (ref.name.startsWith('refs/bookmarks/') && ref.kind != 'bookmark') ||
          !(ref.name == 'HEAD' ||
              ref.name.startsWith('refs/heads/') ||
              ref.name.startsWith('refs/bookmarks/'))) {
        throw const CheckpointIntegrityException(
          'Stored history reference is duplicated or invalid.',
        );
      }
      byName[ref.name] = ref;
    }
    final head = byName['HEAD'];
    if (head == null || refs.where((r) => r.kind == 'head').length != 1) {
      throw const CheckpointIntegrityException(
        'Persistent history requires exactly one HEAD reference.',
      );
    }
    final attached = head.symbolicBranchName;
    if (attached != null) {
      final branch = byName[attached];
      if (branch == null || branch.kind != 'branch' ||
          branch.targetCheckpointId != head.targetCheckpointId) {
        throw const CheckpointIntegrityException(
          'HEAD and attached branch reference disagree.',
        );
      }
    }
  }

  static bool _validName(String name, String kind) {
    if (name.length > 180) return false;
    if (kind == 'head') return name == 'HEAD';
    final prefix = switch (kind) {
      'branch' => 'refs/heads/',
      'bookmark' => 'refs/bookmarks/',
      _ => '',
    };
    if (prefix.isEmpty || !name.startsWith(prefix)) return false;
    final suffix = name.substring(prefix.length);
    final safe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*');
    return suffix.split('/').every((part) =>
        part.isNotEmpty && part != '.' && part != '..' &&
        !part.endsWith('.lock') &&
        safe.firstMatch(part)?.end == part.length);
  }

  static bool _collides(String name, Iterable<String> existing) =>
      existing.any((other) =>
          name == other || name.startsWith('$other/') ||
          other.startsWith('$name/'));

  /// Add a lightweight branch/bookmark pointing at an existing commit.
  /// No duplicate subtitle snapshot is created.
  Future<HistoryRef> create({
    required int sessionId,
    required String name,
    required String kind,
    required int targetCheckpointId,
  }) => _isar.writeTxn(() async {
    if (!(_validName(name, kind) && (kind == 'branch' || kind == 'bookmark'))) {
      throw const FormatException('Invalid branch or bookmark name.');
    }
    final refs = await ensureMigratedInTransaction(_isar, sessionId: sessionId);
    final names = refs.map((r) => r.name);
    if (_collides(name, names)) {
      throw StateError('History reference name already exists or overlaps.');
    }
    final checkpoint = await _isar.checkpoints.get(targetCheckpointId);
    final session = await _isar.sessions.get(sessionId);
    if (refs.isEmpty || session == null || checkpoint == null ||
        checkpoint.sessionId != sessionId ||
        checkpoint.subtitleCollectionId != session.subtitleCollectionId) {
      throw StateError('Reference checkpoint is missing or belongs to another session.');
    }
    final now = DateTime.now().toUtc();
    final created = HistoryRef(
      sessionId: sessionId,
      subtitleCollectionId: checkpoint.subtitleCollectionId,
      name: name,
      kind: kind,
      targetCheckpointId: checkpoint.id,
      createdAt: now,
      updatedAt: now,
    );
    await _isar.historyRefs.put(created);
    return created;
  });

  /// Rename without changing the commit ID; update symbolic HEAD atomically.
  Future<void> rename({
    required int sessionId,
    required String name,
    required String newName,
  }) => _isar.writeTxn(() async {
    final refs = await ensureMigratedInTransaction(_isar, sessionId: sessionId);
    final old = refs.where((ref) => ref.name == name).firstOrNull;
    if (old == null || name == 'HEAD' || name == 'refs/heads/main' ||
        !_validName(newName, old.kind)) {
      throw StateError('Reference cannot be renamed.');
    }
    if (_collides(newName, refs.where((ref) => ref.id != old.id)
        .map((ref) => ref.name))) {
      throw StateError('Target reference name already exists or overlaps.');
    }
    final head = refs.firstWhere((ref) => ref.name == 'HEAD');
    if (head.symbolicBranchName == name) {
      head.symbolicBranchName = newName;
      head.updatedAt = DateTime.now().toUtc();
      await _isar.historyRefs.put(head);
    }
    old.name = newName;
    old.updatedAt = DateTime.now().toUtc();
    await _isar.historyRefs.put(old);
  });

  /// Unpin an explicit ref; never delete HEAD, main or attached branches.
  Future<void> delete({
    required int sessionId,
    required String name,
  }) => _isar.writeTxn(() async {
    final refs = await ensureMigratedInTransaction(_isar, sessionId: sessionId);
    final target = refs.where((ref) => ref.name == name).firstOrNull;
    final head = refs.where((ref) => ref.name == 'HEAD').firstOrNull;
    if (target == null || head == null || name == 'HEAD' ||
        name == 'refs/heads/main' ||
        target.name == head.symbolicBranchName) {
      throw StateError('Missing, protected or attached history reference.');
    }
    await _isar.historyRefs.delete(target.id);
  });

  /// Fetch a branch tip for checkout. Checkout itself uses a second
  /// transaction with a target revalidation to prevent stale switches.
  Future<int> resolveBranch({
    required int sessionId,
    required String name,
  }) async {
    final refs = await getReferences(sessionId);
    final branch = refs.where((ref) =>
        ref.name == name && ref.kind == 'branch').firstOrNull;
    if (branch == null) throw StateError('Branch not found.');
    return branch.targetCheckpointId;
  }

  /// Durable migration runs at most once per session. Existing records are
  /// validated rather than overwritten, even if startup is repeated.
  Future<List<HistoryRef>> ensureMigrated(int sessionId) {
    return _isar.writeTxn(() =>
        ensureMigratedInTransaction(_isar, sessionId: sessionId));
  }

  /// Read persisted refs; automatically upgrade old history atomically.
  Future<List<HistoryRef>> getReferences(int sessionId) async {
    final refs = await ensureMigrated(sessionId);
    return List<HistoryRef>.unmodifiable(refs);
  }

  /// Advance the single HEAD ref in the SAME transaction as a commit.
  /// If HEAD is attached, advance that named branch too. A direct checkout
  /// instead detaches HEAD and keeps prior branch tips unchanged.
  static Future<void> moveHeadInTransaction(
    Isar isar, {
    required int sessionId,
    required int checkpointId,
    bool detach = false,
    String? attachBranchName,
  }) async {
    final refs = await ensureMigratedInTransaction(
      isar, sessionId: sessionId,
    );
    if (refs.isEmpty) {
      throw const CheckpointIntegrityException('Cannot move empty HEAD.');
    }
    final head = refs.firstWhere((r) => r.name == 'HEAD');
    final commits = await isar.checkpoints
        .filter().sessionIdEqualTo(sessionId).findAll();
    if (!commits.any((c) =>
        c.id == checkpointId &&
        c.subtitleCollectionId == head.subtitleCollectionId)) {
      throw const CheckpointIntegrityException(
        'HEAD cannot target a missing or foreign checkpoint.',
      );
    }
    final branchName =
        attachBranchName ?? (detach ? null : head.symbolicBranchName);
    final match = refs.where((ref) =>
        ref.name == branchName && ref.kind == 'branch').firstOrNull;
    if (branchName != null && match == null) {
      throw const CheckpointIntegrityException(
        'Attached branch was deleted during HEAD movement.',
      );
    }
    if (attachBranchName != null &&
        match!.targetCheckpointId != checkpointId) {
      throw const CheckpointIntegrityException(
        'Branch tip changed during checkout.',
      );
    }
    final now = DateTime.now().toUtc();
    head.targetCheckpointId = checkpointId;
    head.symbolicBranchName = branchName;
    head.updatedAt = now;
    if (branchName != null && attachBranchName == null) {
      match!.targetCheckpointId = checkpointId;
      match.updatedAt = now;
      await isar.historyRefs.put(match);
    }
        await isar.historyRefs.put(head);
  }

  static Future<void> deleteSessionRefsInTransaction(
    Isar isar, {
    required int sessionId,
  }) async {
    final refs = await isar.historyRefs
        .filter().sessionIdEqualTo(sessionId).findAll();
    if (refs.isNotEmpty) {
      await isar.historyRefs.deleteAll(refs.map((r) => r.id).toList());
    }
  }
}
