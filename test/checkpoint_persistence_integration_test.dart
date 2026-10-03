import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/services/checkpoint_manager.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'support/test_isar_harness.dart';

class _SeededSession {
  final int sessionId;
  final int subtitleCollectionId;

  const _SeededSession({
    required this.sessionId,
    required this.subtitleCollectionId,
  });
}

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

Future<_SeededSession> _seedSession(TestIsarHarness harness) async {
  late int subtitleCollectionId;
  late int sessionId;

  await harness.isar.writeTxn(() async {
    subtitleCollectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'checkpoint-test.srt',
        encoding: 'UTF-8',
        lines: [
          _line(1, 'A'),
          _line(2, 'B'),
        ],
      ),
    );

    sessionId = await harness.isar.sessions.put(
      Session(
        fileName: 'checkpoint-test.srt',
        subtitleCollectionId: subtitleCollectionId,
      ),
    );
  });

  return _SeededSession(
    sessionId: sessionId,
    subtitleCollectionId: subtitleCollectionId,
  );
}

Future<List<SubtitleLine>> _readLines(
  TestIsarHarness harness,
  int subtitleCollectionId,
) async {
  final collection =
      await harness.isar.subtitleCollections.get(subtitleCollectionId);
  expect(collection, isNotNull);
  return CheckpointStateReducer.copyLines(collection!.lines);
}

Future<void> _writeLines(
  TestIsarHarness harness,
  int subtitleCollectionId,
  List<SubtitleLine> lines,
) async {
  await harness.isar.writeTxn(() async {
    final collection =
        await harness.isar.subtitleCollections.get(subtitleCollectionId);
    expect(collection, isNotNull);
    collection!.lines = CheckpointStateReducer.copyLines(lines);
    await harness.isar.subtitleCollections.put(collection);
  });
}

void main() {
  late TestIsarHarness harness;
  bool harnessOpened = false;
  late CheckpointManager manager;
  late _SeededSession seeded;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    manager = CheckpointManager(harness.isar);
    seeded = await _seedSession(harness);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('CheckpointManager persistence', () {
    test('initial snapshot is persisted once and is idempotent', () async {
      final first = await manager.createInitialSnapshot(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
      );
      final second = await manager.createInitialSnapshot(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
      );

      expect(first, isNot(0));
      expect(second, first);

      final checkpoints = await manager.getCheckpointsForSession(
        seeded.sessionId,
      );
      expect(checkpoints, hasLength(1));

      final snapshot = checkpoints.single;
      expect(snapshot.checkpointType, 'snapshot');
      expect(snapshot.description, 'Initial state');
      expect(snapshot.parentCheckpointId, isNull);
      expect(
        snapshot.snapshot.map((line) => line.original).toList(),
        ['A', 'B'],
      );
      expect(snapshot.deltas, isEmpty);
    });

    test('restore replays an automatic snapshot operation for descendants',
        () async {
      final preferences = PreferencesStore(harness.isar);
      await preferences.update((value) {
        value.checkpointStrategy = 'hybrid';
        value.snapshotInterval = 1;
        value.maxCheckpoints = 25;
      });

      await manager.createInitialSnapshot(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
      );

      final firstBefore = _line(1, 'A');
      final firstAfter = _line(1, 'A1');
      await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: firstBefore,
        afterLine: firstAfter,
      );
      await _writeLines(
        harness,
        seeded.subtitleCollectionId,
        [firstAfter, _line(2, 'B')],
      );

      final secondBefore = _line(2, 'B');
      final secondAfter = _line(2, 'B1');
      final snapshotOperationId = await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: secondBefore,
        afterLine: secondAfter,
      );
      await _writeLines(
        harness,
        seeded.subtitleCollectionId,
        [firstAfter, secondAfter],
      );

      final thirdBefore = _line(1, 'A1');
      final thirdAfter = _line(1, 'A2');
      final thirdCheckpointId = await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: thirdBefore,
        afterLine: thirdAfter,
      );
      await _writeLines(
        harness,
        seeded.subtitleCollectionId,
        [thirdAfter, secondAfter],
      );

      final snapshotOperation =
          await harness.isar.checkpoints.get(snapshotOperationId);
      expect(snapshotOperation, isNotNull);
      expect(snapshotOperation!.checkpointType, 'snapshot');
      expect(
        snapshotOperation.snapshot.map((line) => line.original).toList(),
        ['A1', 'B'],
      );
      expect(snapshotOperation.deltas, hasLength(1));
      expect(snapshotOperation.deltas.single.afterState?.original, 'B1');

      final restored = await manager.undoToCheckpoint(
        checkpointId: thirdCheckpointId,
        sessionId: seeded.sessionId,
      );
      expect(restored, isTrue);

      final restoredLines =
          await _readLines(harness, seeded.subtitleCollectionId);
      expect(
        restoredLines.map((line) => line.original).toList(),
        ['A1', 'B1'],
      );

      final checkpoints =
          await manager.getCheckpointsForSession(seeded.sessionId);
      final active = checkpoints.where((checkpoint) => checkpoint.isActive);
      expect(
        active.map((checkpoint) => checkpoint.id).toList(),
        [thirdCheckpointId],
      );
    });

    test('new edit after checkout preserves old descendants as a branch',
        () async {
      final initialId = await manager.createInitialSnapshot(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
      );

      final firstBefore = _line(1, 'A');
      final firstAfter = _line(1, 'A1');
      final firstCheckpointId = await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: firstBefore,
        afterLine: firstAfter,
      );
      await _writeLines(
        harness,
        seeded.subtitleCollectionId,
        [firstAfter, _line(2, 'B')],
      );

      final secondBefore = _line(2, 'B');
      final secondAfter = _line(2, 'B1');
      final secondCheckpointId = await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: secondBefore,
        afterLine: secondAfter,
      );
      await _writeLines(
        harness,
        seeded.subtitleCollectionId,
        [firstAfter, secondAfter],
      );

      final thirdBefore = _line(1, 'A1');
      final thirdAfter = _line(1, 'A2');
      final thirdCheckpointId = await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: thirdBefore,
        afterLine: thirdAfter,
      );
      await _writeLines(
        harness,
        seeded.subtitleCollectionId,
        [thirdAfter, secondAfter],
      );

      expect(
        await manager.undoToCheckpoint(
          checkpointId: secondCheckpointId,
          sessionId: seeded.sessionId,
        ),
        isTrue,
      );

      final beforeBranch =
          await _readLines(harness, seeded.subtitleCollectionId);
      expect(
        beforeBranch.map((line) => line.original).toList(),
        ['A1', 'B'],
      );

      final branchAfter = _line(2, 'B2');
      final branchCheckpointId = await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: _line(2, 'B'),
        afterLine: branchAfter,
      );

      expect(
        await harness.isar.checkpoints.get(secondCheckpointId),
        isNotNull,
      );
      expect(
        await harness.isar.checkpoints.get(thirdCheckpointId),
        isNotNull,
      );

      final branchCheckpoint =
          await harness.isar.checkpoints.get(branchCheckpointId);
      expect(branchCheckpoint, isNotNull);
      expect(branchCheckpoint!.parentCheckpointId, secondCheckpointId);

      final checkpoints =
          await manager.getCheckpointsForSession(seeded.sessionId);
      expect(
        checkpoints.map((checkpoint) => checkpoint.id).toSet(),
        {
          initialId,
          firstCheckpointId,
          secondCheckpointId,
          thirdCheckpointId,
          branchCheckpointId,
        },
      );
      final active =
          checkpoints.where((checkpoint) => checkpoint.isActive).toList();
      expect(active, hasLength(1));
      expect(active.single.id, branchCheckpointId);

      await _writeLines(
        harness,
        seeded.subtitleCollectionId,
        [firstAfter, branchAfter],
      );

      final nextCheckpointId = await manager.createEditCheckpoint(
        sessionId: seeded.sessionId,
        subtitleCollectionId: seeded.subtitleCollectionId,
        beforeLine: _line(1, 'A1'),
        afterLine: _line(1, 'A3'),
      );

      final nextCheckpoint =
          await harness.isar.checkpoints.get(nextCheckpointId);
      expect(nextCheckpoint, isNotNull);
      expect(nextCheckpoint!.parentCheckpointId, branchCheckpointId);
    });
  });
}
