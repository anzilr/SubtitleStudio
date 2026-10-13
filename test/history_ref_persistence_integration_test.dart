import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/checkpoint_store.dart';
import 'package:subtitle_studio/services/history_ref_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(String original) => SubtitleLine()
  ..index = 1
  ..startTime = '00:00:01,000'
  ..endTime = '00:00:02,000'
  ..original = original
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

Future<({int sessionId, int collectionId})> _seed(TestIsarHarness harness) async {
  late int sessionId;
  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'history-refs.srt',
        encoding: 'UTF-8',
        lines: [_line('One')],
      ),
    );
    sessionId = await harness.isar.sessions.put(
      Session(fileName: 'history-refs.srt', subtitleCollectionId: collectionId),
    );
  });
  return (sessionId: sessionId, collectionId: collectionId);
}

Checkpoint _checkpoint({
  required int session,
  required int collection,
  int? parent,
  required String title,
  required bool active,
  bool v2 = false,
}) => Checkpoint(
  sessionId: session,
  subtitleCollectionId: collection,
  timestamp: DateTime.utc(2026, 10, 13),
  operationType: 'snapshot',
  description: title,
  parentCheckpointId: parent,
  isActive: active,
  checkpointType: 'snapshot',
  deltas: const [],
  snapshot: [_line(title)],
  metadata: v2 ? CheckpointHistoryMetadata.encodePostOperation() : null,
);

void main() {
  late TestIsarHarness harness;
  late HistoryRefRepository refs;
  late CheckpointStore store;

  setUp(() async {
    harness = await TestIsarHarness.open();
    refs = HistoryRefRepository(harness.isar);
    store = CheckpointStore(harness.isar);
  });

  tearDown(() async {
    await harness.close();
  });

  test('legacy history upgrades atomically and only once', () async {
    final ids = await _seed(harness);
    late int rootId;
    late int tipId;
    await harness.isar.writeTxn(() async {
      rootId = await harness.isar.checkpoints.put(_checkpoint(
        session: ids.sessionId, collection: ids.collectionId,
        title: 'Initial', active: true,
      ));
      tipId = await harness.isar.checkpoints.put(_checkpoint(
        session: ids.sessionId, collection: ids.collectionId,
        parent: rootId, title: 'Second', active: true,
      ));
    });
    final migrated = await refs.ensureMigrated(ids.sessionId);
    expect(migrated.map((r) => r.name).toSet(), {
      'HEAD', 'refs/heads/main',
    });
    expect(migrated.every((r) => r.targetCheckpointId == tipId), isTrue);
    final active = await harness.isar.checkpoints
        .filter().sessionIdEqualTo(ids.sessionId).isActiveEqualTo(true).findAll();
    expect(active.map((cp) => cp.id), [tipId]);
    final oldIds = migrated.map((r) => r.id).toSet();
    final again = await refs.ensureMigrated(ids.sessionId);
    expect(again.map((r) => r.id).toSet(), oldIds);
    expect(await harness.isar.historyRefs.count(), 2);
  });

  test('commits and checkouts update persistent HEAD in same transaction',
      () async {
    final ids = await _seed(harness);
    final history = CheckpointRepository(harness.isar);
    final root = await history.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    var currentRefs = await refs.getReferences(ids.sessionId);
    expect(currentRefs.singleWhere((r) => r.name == 'HEAD').targetCheckpointId,
        root);

    final newCommit = _checkpoint(
      session: ids.sessionId,
      collection: ids.collectionId,
      parent: root,
      title: 'Next',
      active: true,
      v2: true,
    );
    final newId = await store.insertAsHead(
      sessionId: ids.sessionId,
      expectedHeadId: root,
      checkpoint: newCommit,
    );
    currentRefs = await refs.getReferences(ids.sessionId);
    expect(currentRefs.singleWhere((r) => r.name == 'HEAD').targetCheckpointId,
        newId);
    expect(currentRefs.singleWhere((r) => r.name == 'refs/heads/main')
        .targetCheckpointId, newId);
    expect(currentRefs.singleWhere((r) => r.name == 'HEAD')
        .symbolicBranchName, 'refs/heads/main');

    final rootSnapshot = (await harness.isar.subtitleCollections
        .get(ids.collectionId))!;
    await store.restoreCollectionAndActivateOnly(
      sessionId: ids.sessionId,
      targetCheckpoint: (await store.getCheckpoint(root))!,
      collection: rootSnapshot,
      expectedHeadId: newId,
      expectedWorkingStateHash: CheckpointStateHasher.hashLines(
        rootSnapshot.lines,
      ),
    );
    currentRefs = await refs.getReferences(ids.sessionId);
    expect(currentRefs.singleWhere((r) => r.name == 'HEAD').targetCheckpointId,
        root);
    expect(currentRefs.singleWhere((r) => r.name == 'refs/heads/main')
        .targetCheckpointId, root);
  });

  test('invalid cross-session ref fails without rewriting checkpoint history',
      () async {
    final first = await _seed(harness);
    final other = await _seed(harness);
    final cp = await harness.isar.writeTxn(() => harness.isar.checkpoints.put(
      _checkpoint(
        session: first.sessionId,
        collection: first.collectionId,
        title: 'Original',
        active: true,
        v2: true,
      ),
    ));
    await harness.isar.writeTxn(() async {
      await harness.isar.historyRefs.put(HistoryRef(
        sessionId: first.sessionId,
        subtitleCollectionId: other.collectionId,
        name: 'HEAD',
        kind: 'head',
        targetCheckpointId: cp,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ));
    });
    await expectLater(
      refs.ensureMigrated(first.sessionId),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    expect(await harness.isar.historyRefs.count(), 1);
    expect((await store.getCheckpoint(cp))!.isActive, isTrue);
  });

  test('retention cannot delete named branch tip or manual bookmark targets',
      () async {
    final ids = await _seed(harness);
    late int root;
    await harness.isar.writeTxn(() async {
      root = await harness.isar.checkpoints.put(_checkpoint(
        session: ids.sessionId, collection: ids.collectionId,
        title: 'Root', active: false, v2: true,
      ));
      for (var i = 0; i < 5; i++) {
        await harness.isar.checkpoints.put(_checkpoint(
          session: ids.sessionId, collection: ids.collectionId,
          parent: root, title: 'Branch $i', active: i == 4, v2: true,
        ));
      }
    });
    final initial = await refs.ensureMigrated(ids.sessionId);
    expect(initial.length, 7); // HEAD, main, five automatic branch refs except HEAD => 6
    expect(await store.pruneSession(
      sessionId: ids.sessionId,
      maxCheckpoints: 2,
    ), 0);
    expect((await store.getCheckpointsForSession(ids.sessionId)), hasLength(6));
  });

  test('checkpoint deletion removes refs in one transaction', () async {
    final ids = await _seed(harness);
    await harness.isar.writeTxn(() async {
      await harness.isar.checkpoints.put(_checkpoint(
        session: ids.sessionId, collection: ids.collectionId,
        title: 'Root', active: true, v2: true,
      ));
    });
    expect((await refs.ensureMigrated(ids.sessionId)), hasLength(2));
    await store.deleteCheckpointsForSession(ids.sessionId);
    expect(await harness.isar.historyRefs.count(), 0);
    expect(await harness.isar.checkpoints.count(), 0);
  });

  test('old Isar database opens with the additive HistoryRef schema', () async {
    // A real file-backed upgrade, not merely an empty in-memory migration.
    final dir = await Directory.systemTemp.createTemp('history_ref_upgrade_');
    final name = 'legacy_before_history_refs';
    await Isar.initializeIsarCore(download: true);
    try {
      final legacy = await Isar.open([
        PreferencesSchema,
        SessionSchema,
        SubtitleCollectionSchema,
        DictionaryEntrySchema,
        CheckpointSchema,
        VideoPreferencesSchema,
        TutorialStatusSchema,
      ], directory: dir.path, name: name);
      late int sessionId;
      await legacy.writeTxn(() async {
        final collectionId = await legacy.subtitleCollections.put(
          SubtitleCollection(
            fileName: 'archive.srt', encoding: 'UTF-8',
            lines: [_line('Unchanged text')],
          ),
        );
        sessionId = await legacy.sessions.put(
          Session(fileName: 'archive.srt', subtitleCollectionId: collectionId),
        );
        await legacy.checkpoints.put(_checkpoint(
          session: sessionId, collection: collectionId,
          title: 'Before upgrade', active: true,
        ));
      });
      await legacy.close();
      final upgraded = await Isar.open([
        PreferencesSchema,
        SessionSchema,
        SubtitleCollectionSchema,
        DictionaryEntrySchema,
        CheckpointSchema,
        HistoryRefSchema,
        VideoPreferencesSchema,
        TutorialStatusSchema,
      ], directory: dir.path, name: name);
      try {
        final restored = await HistoryRefRepository(upgraded)
            .ensureMigrated(sessionId);
        expect(restored, hasLength(2));
        final sessions = await upgraded.sessions.get(sessionId);
        expect(sessions, isNotNull);
        final collection = await upgraded.subtitleCollections
            .get(sessions!.subtitleCollectionId);
        expect(collection!.lines.single.original, 'Unchanged text');
      } finally {
        await upgraded.close(deleteFromDisk: true);
      }
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });
}
