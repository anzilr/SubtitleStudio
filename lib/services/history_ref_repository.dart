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
          !byName.containsKey(ref.name) && ref.name.isEmpty) {
        throw const CheckpointIntegrityException(
          'Stored history reference has an invalid target or owner.',
        );
      }
      final target = byId[ref.targetCheckpointId]!;
      if (target.sessionId != sessionId ||
          target.subtitleCollectionId != ref.subtitleCollectionId ||
          byName.containsKey(ref.name) ||
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
    final branchName = detach ? null : head.symbolicBranchName;
    final now = DateTime.now().toUtc();
    head.targetCheckpointId = checkpointId;
    head.symbolicBranchName = branchName;
    head.updatedAt = now;
    if (branchName != null) {
      final branch = refs.firstWhere((r) => r.name == branchName);
      branch.targetCheckpointId = checkpointId;
      branch.updatedAt = now;
      await isar.historyRefs.put(branch);
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
