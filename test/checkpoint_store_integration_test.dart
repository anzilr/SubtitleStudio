import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_store.dart';
import 'package:subtitle_studio/services/checkpoint_state_hasher.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String text) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

void main() {
  late TestIsarHarness harness;
  late CheckpointStore store;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    store = CheckpointStore(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  test('restores collection and makes only target checkpoint active',
      () async {
    late int collectionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'store-test.srt',
          encoding: 'UTF-8',
          lines: [_line(1, 'Current')],
        ),
      );
    });

    final first = Checkpoint(
      sessionId: 10,
      subtitleCollectionId: collectionId,
      timestamp: DateTime.utc(2026, 10, 3, 10),
      operationType: 'snapshot',
      description: 'Initial state',
      isActive: false,
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: [_line(1, 'Initial')],
    );
    final second = Checkpoint(
      sessionId: 10,
      subtitleCollectionId: collectionId,
      timestamp: DateTime.utc(2026, 10, 3, 11),
      operationType: 'edit',
      description: 'Edit',
      isActive: true,
      checkpointType: 'delta',
      deltas: const [],
      snapshot: const [],
    );

    final firstId = await store.putCheckpoint(first);
    final secondId = await store.putCheckpoint(second);

    final collection = await store.getSubtitleCollection(collectionId);
    expect(collection, isNotNull);
    collection!.lines = [_line(1, 'Restored')];

    final target = await store.getCheckpoint(firstId);
    expect(target, isNotNull);

    await store.restoreCollectionAndActivateOnly(
      sessionId: 10,
      targetCheckpoint: target!,
      collection: collection,
      expectedHeadId: secondId,
      expectedWorkingStateHash:
          CheckpointStateHasher.hashLines([_line(1, 'Current')]),
    );

    final storedCollection = await store.getSubtitleCollection(collectionId);
    expect(storedCollection!.lines.single.original, 'Restored');

    final checkpoints = await store.getCheckpointsForSession(10);
    expect(
      checkpoints.where((checkpoint) => checkpoint.isActive).map((c) => c.id),
      [firstId],
    );
    expect(
      checkpoints.firstWhere((checkpoint) => checkpoint.id == secondId).isActive,
      isFalse,
    );
  });

  test('checkout rejects stale HEAD and preserves the current document',
      () async {
    late int collectionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'race-test.srt',
          encoding: 'UTF-8',
          lines: [_line(1, 'Current')],
        ),
      );
    });
    final root = Checkpoint(
      sessionId: 11,
      subtitleCollectionId: collectionId,
      timestamp: DateTime.utc(2026, 10, 3, 9),
      operationType: 'snapshot',
      description: 'Initial state',
      isActive: false,
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: [_line(1, 'Initial')],
    );
    final next = Checkpoint(
      sessionId: 11,
      subtitleCollectionId: collectionId,
      timestamp: DateTime.utc(2026, 10, 3, 10),
      operationType: 'edit',
      description: 'Second',
      isActive: true,
      checkpointType: 'delta',
      deltas: const [],
      snapshot: const [],
    );
    final rootId = await store.putCheckpoint(root);
    final nextId = await store.putCheckpoint(next);
    final proposed = await store.getSubtitleCollection(collectionId);
    proposed!.lines = [_line(1, 'Stale restored')];

    expect(
      () => store.restoreCollectionAndActivateOnly(
        sessionId: 11,
        targetCheckpoint: root,
        collection: proposed,
        expectedHeadId: rootId,
        expectedWorkingStateHash:
            CheckpointStateHasher.hashLines([_line(1, 'Current')]),
      ),
      throwsA(isA<CheckpointConcurrentModificationException>()),
    );

    expect((await store.getSubtitleCollection(collectionId))!
        .lines.single.original, 'Current');
    expect((await store.getCurrentHeadCheckpoint(11))!.id, nextId);
  });

  test('checkout rejects concurrent working-tree changes even if HEAD matches',
      () async {
    late int collectionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'race-test.srt',
          encoding: 'UTF-8',
          lines: [_line(1, 'Before')],
        ),
      );
    });
    final root = Checkpoint(
      sessionId: 12,
      subtitleCollectionId: collectionId,
      timestamp: DateTime.utc(2026, 10, 3),
      operationType: 'snapshot',
      description: 'Initial state',
      isActive: true,
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: [_line(1, 'Before')],
    );
    final rootId = await store.putCheckpoint(root);
    final stale = (await store.getSubtitleCollection(collectionId))!;
    stale.lines = [_line(1, 'Requested restore')];
    await harness.isar.writeTxn(() async {
      final current =
          (await harness.isar.subtitleCollections.get(collectionId))!;
      current.lines = [_line(1, 'Concurrent edit')];
      await harness.isar.subtitleCollections.put(current);
    });

    expect(
      () => store.restoreCollectionAndActivateOnly(
        sessionId: 12,
        targetCheckpoint: root,
        collection: stale,
        expectedHeadId: rootId,
        expectedWorkingStateHash:
            CheckpointStateHasher.hashLines([_line(1, 'Before')]),
      ),
      throwsA(isA<CheckpointIntegrityException>()),
    );

    expect((await store.getSubtitleCollection(collectionId))!
        .lines.single.original, 'Concurrent edit');
    expect((await store.getCurrentHeadCheckpoint(12))!.id, rootId);
  });

  test('checkout does not overwrite unrelated file metadata', () async {
    late int collectionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'original.srt',
          encoding: 'UTF-8',
          lines: [_line(1, 'Before')],
        ),
      );
    });
    final root = Checkpoint(
      sessionId: 13,
      subtitleCollectionId: collectionId,
      timestamp: DateTime.utc(2026, 10, 3),
      operationType: 'snapshot',
      description: 'Initial state',
      isActive: true,
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: [_line(1, 'Before')],
    );
    final rootId = await store.putCheckpoint(root);
    final stale = (await store.getSubtitleCollection(collectionId))!;
    stale.lines = [_line(1, 'Restored')];
    await harness.isar.writeTxn(() async {
      final fresh =
          (await harness.isar.subtitleCollections.get(collectionId))!;
      fresh.fileName = 'renamed.srt';
      await harness.isar.subtitleCollections.put(fresh);
    });

    await store.restoreCollectionAndActivateOnly(
      sessionId: 13,
      targetCheckpoint: root,
      collection: stale,
      expectedHeadId: rootId,
      expectedWorkingStateHash:
          CheckpointStateHasher.hashLines([_line(1, 'Before')]),
    );
    final restored = (await store.getSubtitleCollection(collectionId))!;
    expect(restored.fileName, 'renamed.srt');
    expect(restored.lines.single.original, 'Restored');
  });

  test('insertAsHead keeps exactly one HEAD and checks expected HEAD',
      () async {
    final first = Checkpoint(
      sessionId: 7,
      subtitleCollectionId: 70,
      timestamp: DateTime.utc(2026, 10, 3, 9),
      operationType: 'snapshot',
      description: 'Initial state',
      isActive: true,
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: [_line(1, 'Initial')],
    );

    final firstId = await store.putCheckpoint(first);

    final second = Checkpoint(
      sessionId: 7,
      subtitleCollectionId: 70,
      timestamp: DateTime.utc(2026, 10, 3, 10),
      operationType: 'edit',
      description: 'Second',
      parentCheckpointId: firstId,
      checkpointType: 'delta',
      deltas: const [],
      snapshot: const [],
    );

    final secondId = await store.insertAsHead(
      sessionId: 7,
      expectedHeadId: firstId,
      checkpoint: second,
    );

    final checkpoints = await store.getCheckpointsForSession(7);
    final active =
        checkpoints.where((checkpoint) => checkpoint.isActive).toList();

    expect(active, hasLength(1));
    expect(active.single.id, secondId);

    final staleCommit = Checkpoint(
      sessionId: 7,
      subtitleCollectionId: 70,
      timestamp: DateTime.utc(2026, 10, 3, 11),
      operationType: 'edit',
      description: 'Stale',
      parentCheckpointId: firstId,
      checkpointType: 'delta',
      deltas: const [],
      snapshot: const [],
    );

    expect(
      () => store.insertAsHead(
        sessionId: 7,
        expectedHeadId: firstId,
        checkpoint: staleCommit,
      ),
      throwsA(isA<CheckpointConcurrentModificationException>()),
    );
  });

  test('session checkpoint deletion does not remove another session history',
      () async {
    final first = Checkpoint(
      sessionId: 1,
      subtitleCollectionId: 11,
      timestamp: DateTime.utc(2026, 10, 3),
      operationType: 'snapshot',
      description: 'One',
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: const [],
    );
    final second = Checkpoint(
      sessionId: 2,
      subtitleCollectionId: 22,
      timestamp: DateTime.utc(2026, 10, 3),
      operationType: 'snapshot',
      description: 'Two',
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: const [],
    );

    final firstId = await store.putCheckpoint(first);
    final secondId = await store.putCheckpoint(second);

    await store.deleteCheckpointsForSession(1);

    expect(await store.getCheckpoint(firstId), isNull);
    expect(await store.getCheckpoint(secondId), isNotNull);
  });
}
