import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line({
  required int index,
  required String text,
  required String start,
  required String end,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = start
    ..endTime = end
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

Future<int> _seedCollection(
  TestIsarHarness harness, {
  List<SubtitleLine>? lines,
}) {
  return harness.isar.writeTxn(() {
    return harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'repository-test.srt',
        encoding: 'UTF-8',
        lines: lines ??
            [
              _line(
                index: 1,
                text: 'A',
                start: '00:00:01,000',
                end: '00:00:01,900',
              ),
              _line(
                index: 2,
                text: 'B',
                start: '00:00:02,000',
                end: '00:00:02,900',
              ),
              _line(
                index: 3,
                text: 'C',
                start: '00:00:03,000',
                end: '00:00:03,900',
              ),
            ],
      ),
    );
  });
}

void main() {
  late TestIsarHarness harness;
  late SubtitleRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = SubtitleRepository(
      harness.isar,
      CheckpointRepository(harness.isar),
    );
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('SubtitleRepository persistence', () {
    test('text edit is an atomic v2 delta commit', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'repository-test.srt',
          ),
        );
      });

      final checkpoints = CheckpointRepository(harness.isar);
      final initialId = await checkpoints.createInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
      );

      final updated = _line(
        index: 1,
        text: 'A edited',
        start: '00:00:01,000',
        end: '00:00:01,900',
      );

      expect(
        await repository.saveLineChanges(
          collectionId,
          updated,
          sessionId: sessionId,
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .sortByTimestamp()
          .findAll();
      expect(history, hasLength(2));

      final edit = history.last;
      expect(edit.parentCheckpointId, initialId);
      expect(edit.checkpointType, 'delta');
      expect(edit.snapshot, isEmpty);
      expect(CheckpointHistoryMetadata.isPostOperation(edit), isTrue);
      expect(
        history.where((checkpoint) => checkpoint.isActive).single.id,
        edit.id,
      );

      expect(
        await checkpoints.undoToCheckpoint(
          checkpointId: initialId,
          sessionId: sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleCollection(collectionId))
            ?.lines
            .first
            .original,
        'A',
      );

      expect(
        await checkpoints.redoToCheckpoint(
          checkpointId: edit.id,
          sessionId: sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleCollection(collectionId))
            ?.lines
            .first
            .original,
        'A edited',
      );
    });

    test('first atomic edit auto-creates an untouched v2 root', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'auto-root.srt',
          ),
        );
      });

      final updated = _line(
        index: 1,
        text: 'A edited',
        start: '00:00:01,000',
        end: '00:00:01,900',
      );

      expect(
        await repository.saveLineChanges(
          collectionId,
          updated,
          sessionId: sessionId,
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .findAll();
      expect(history, hasLength(2));

      final root = history.firstWhere(
        (checkpoint) => checkpoint.description == 'Initial state',
      );
      final edit = history.firstWhere(
        (checkpoint) => checkpoint.operationType == 'edit',
      );

      expect(root.parentCheckpointId, isNull);
      expect(root.checkpointType, 'snapshot');
      expect(CheckpointHistoryMetadata.isPostOperation(root), isTrue);
      expect(
        root.snapshot.map((line) => line.original).toList(),
        ['A', 'B', 'C'],
      );
      expect(edit.parentCheckpointId, root.id);
      expect(edit.isActive, isTrue);

      final checkpoints = CheckpointRepository(harness.isar);
      expect(
        await checkpoints.undoToCheckpoint(
          checkpointId: root.id,
          sessionId: sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleCollection(collectionId))
            ?.lines
            .first
            .original,
        'A',
      );
    });

    test('external working-tree changes are captured before the next commit',
        () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'working-tree-sync.srt',
          ),
        );
      });

      final checkpoints = CheckpointRepository(harness.isar);
      final initialId = await checkpoints.createInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
      );

      expect(await repository.markLine(collectionId, 0, true), isTrue);

      final updated = _line(
        index: 1,
        text: 'A edited',
        start: '00:00:01,000',
        end: '00:00:01,900',
      )..marked = true;

      expect(
        await repository.saveLineChanges(
          collectionId,
          updated,
          sessionId: sessionId,
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .findAll();
      expect(history, hasLength(3));

      final sync = history.firstWhere(
        (checkpoint) => checkpoint.operationType == 'sync',
      );
      final edit = history.firstWhere(
        (checkpoint) => checkpoint.operationType == 'edit',
      );

      expect(sync.parentCheckpointId, initialId);
      expect(sync.checkpointType, 'snapshot');
      expect(sync.snapshot.first.original, 'A');
      expect(sync.snapshot.first.marked, isTrue);
      expect(edit.parentCheckpointId, sync.id);

      expect(
        await checkpoints.undoToCheckpoint(
          checkpointId: sync.id,
          sessionId: sessionId,
        ),
        isTrue,
      );
      final syncedCollection =
          await repository.fetchSubtitleCollection(collectionId);
      expect(syncedCollection!.lines.first.original, 'A');
      expect(syncedCollection.lines.first.marked, isTrue);

      expect(
        await checkpoints.redoToCheckpoint(
          checkpointId: edit.id,
          sessionId: sessionId,
        ),
        isTrue,
      );
      final editedCollection =
          await repository.fetchSubtitleCollection(collectionId);
      expect(editedCollection!.lines.first.original, 'A edited');
      expect(editedCollection.lines.first.marked, isTrue);
    });

    test('effect replacement is one atomic v2 snapshot commit', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'effect-history.srt',
          ),
        );
      });

      final checkpoints = CheckpointRepository(harness.isar);
      final initialId = await checkpoints.createInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
      );

      final effectLines = [
        _line(
          index: 2,
          text: 'B-1',
          start: '00:00:02,000',
          end: '00:00:02,400',
        ),
        _line(
          index: 3,
          text: 'B-2',
          start: '00:00:02,401',
          end: '00:00:02,900',
        ),
      ];

      expect(
        await repository.replaceLineWithGeneratedLinesWithHistory(
          collectionId: collectionId,
          originalIndex: 1,
          replacementLines: effectLines,
          sessionId: sessionId,
          description: 'Applied test effect',
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .findAll();
      expect(history, hasLength(2));

      final effect = history.firstWhere(
        (checkpoint) => checkpoint.operationType == 'effect',
      );
      expect(CheckpointHistoryMetadata.isPostOperation(effect), isTrue);
      expect(effect.parentCheckpointId, initialId);
      expect(effect.checkpointType, 'snapshot');
      expect(
        effect.snapshot.map((line) => line.original).toList(),
        ['A', 'B-1', 'B-2', 'C'],
      );

      expect(
        await checkpoints.undoToCheckpoint(
          checkpointId: initialId,
          sessionId: sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleCollection(collectionId))
            ?.lines
            .map((line) => line.original)
            .toList(),
        ['A', 'B', 'C'],
      );
    });

    test('atomic delete stores a v2 post-operation snapshot', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'delete-history.srt',
          ),
        );
      });

      final checkpoints = CheckpointRepository(harness.isar);
      final initialId = await checkpoints.createInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
      );

      expect(
        await repository.deleteLineWithHistory(
          collectionId: collectionId,
          index: 1,
          sessionId: sessionId,
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .sortByTimestamp()
          .findAll();
      final commit = history.last;
      expect(CheckpointHistoryMetadata.isPostOperation(commit), isTrue);
      expect(commit.checkpointType, 'snapshot');
      expect(
        commit.snapshot.map((line) => line.original).toList(),
        ['A', 'C'],
      );

      expect(
        await checkpoints.undoToCheckpoint(
          checkpointId: initialId,
          sessionId: sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleCollection(collectionId))
            ?.lines
            .map((line) => line.original)
            .toList(),
        ['A', 'B', 'C'],
      );

      expect(
        await checkpoints.redoToCheckpoint(
          checkpointId: commit.id,
          sessionId: sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleCollection(collectionId))
            ?.lines
            .map((line) => line.original)
            .toList(),
        ['A', 'C'],
      );
    });

    test('atomic add stores the exact sorted post-operation state', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'add-history.srt',
          ),
        );
      });
      await CheckpointRepository(harness.isar).createInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
      );

      final inserted = _line(
        index: 2,
        text: 'Between',
        start: '00:00:01,950',
        end: '00:00:01,990',
      );
      expect(
        await repository.addLineWithHistory(
          collectionId: collectionId,
          line: inserted,
          insertIndex: 1,
          sessionId: sessionId,
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .sortByTimestamp()
          .findAll();
      final commit = history.last;
      expect(commit.checkpointType, 'snapshot');
      expect(
        commit.snapshot.map((line) => line.original).toList(),
        ['A', 'Between', 'B', 'C'],
      );
    });

    test('atomic split stores the exact post-operation state', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'split-history.srt',
          ),
        );
      });
      await CheckpointRepository(harness.isar).createInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
      );

      expect(
        await repository.splitLineWithHistory(
          collectionId: collectionId,
          firstPart: _line(
            index: 2,
            text: 'B first',
            start: '00:00:02,000',
            end: '00:00:02,400',
          ),
          secondPart: _line(
            index: 3,
            text: 'B second',
            start: '00:00:02,401',
            end: '00:00:02,900',
          ),
          originalIndex: 1,
          sessionId: sessionId,
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .sortByTimestamp()
          .findAll();
      expect(
        history.last.snapshot.map((line) => line.original).toList(),
        ['A', 'B first', 'B second', 'C'],
      );
    });

    test('atomic merge stores the exact post-operation state', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'merge-history.srt',
          ),
        );
      });
      await CheckpointRepository(harness.isar).createInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
      );

      expect(
        await repository.mergeLinesWithHistory(
          collectionId: collectionId,
          mergedLine: _line(
            index: 2,
            text: 'B + C',
            start: '00:00:02,000',
            end: '00:00:03,900',
          ),
          firstLineIndex: 1,
          secondLineIndex: 2,
          sessionId: sessionId,
        ),
        isTrue,
      );

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .sortByTimestamp()
          .findAll();
      expect(
        history.last.snapshot.map((line) => line.original).toList(),
        ['A', 'B + C'],
      );
    });

    test('deleteLine removes and reindexes remaining cues', () async {
      final collectionId = await _seedCollection(harness);

      expect(await repository.deleteLine(collectionId, 1), isTrue);

      final stored = await repository.fetchSubtitleCollection(collectionId);
      expect(stored, isNotNull);
      expect(
        stored!.lines.map((line) => line.original).toList(),
        ['A', 'C'],
      );
      expect(stored.lines.map((line) => line.index).toList(), [1, 2]);
    });

    test('addLine inserts and normalizes ordering/indexes', () async {
      final collectionId = await _seedCollection(harness);

      final inserted = _line(
        index: 2,
        text: 'Between',
        start: '00:00:01,950',
        end: '00:00:01,990',
      );

      expect(
        await repository.addLine(collectionId, inserted, 1),
        isTrue,
      );

      final stored = await repository.fetchSubtitleCollection(collectionId);
      expect(
        stored!.lines.map((line) => line.original).toList(),
        ['A', 'Between', 'B', 'C'],
      );
      expect(stored.lines.map((line) => line.index).toList(), [1, 2, 3, 4]);
    });

    test('splitLine replaces one cue with two persisted parts', () async {
      final collectionId = await _seedCollection(harness);

      final firstPart = _line(
        index: 2,
        text: 'B first',
        start: '00:00:02,000',
        end: '00:00:02,400',
      );
      final secondPart = _line(
        index: 3,
        text: 'B second',
        start: '00:00:02,401',
        end: '00:00:02,900',
      );

      expect(
        await repository.splitLine(
          collectionId,
          firstPart,
          secondPart,
          1,
        ),
        isTrue,
      );

      final stored = await repository.fetchSubtitleCollection(collectionId);
      expect(
        stored!.lines.map((line) => line.original).toList(),
        ['A', 'B first', 'B second', 'C'],
      );
      expect(stored.lines.map((line) => line.index).toList(), [1, 2, 3, 4]);
    });

    test('mergeLines replaces two cues with one persisted cue', () async {
      final collectionId = await _seedCollection(harness);

      final merged = _line(
        index: 2,
        text: 'B + C',
        start: '00:00:02,000',
        end: '00:00:03,900',
      );

      expect(
        await repository.mergeLines(
          collectionId,
          merged,
          1,
          2,
        ),
        isTrue,
      );

      final stored = await repository.fetchSubtitleCollection(collectionId);
      expect(
        stored!.lines.map((line) => line.original).toList(),
        ['A', 'B + C'],
      );
      expect(stored.lines.map((line) => line.index).toList(), [1, 2]);
    });

    test('invalid split and merge indexes do not mutate the collection',
        () async {
      final collectionId = await _seedCollection(harness);

      expect(
        await repository.splitLine(
          collectionId,
          _line(
            index: 9,
            text: 'X',
            start: '00:00:09,000',
            end: '00:00:09,400',
          ),
          _line(
            index: 10,
            text: 'Y',
            start: '00:00:09,401',
            end: '00:00:09,900',
          ),
          99,
        ),
        isFalse,
      );
      expect(
        await repository.mergeLines(
          collectionId,
          _line(
            index: 1,
            text: 'Invalid',
            start: '00:00:01,000',
            end: '00:00:02,000',
          ),
          0,
          99,
        ),
        isFalse,
      );

      final stored = await repository.fetchSubtitleCollection(collectionId);
      expect(
        stored!.lines.map((line) => line.original).toList(),
        ['A', 'B', 'C'],
      );
    });

    test('updateLastEditedIndex persists session progress', () async {
      final collectionId = await _seedCollection(harness);
      late int sessionId;
      await harness.isar.writeTxn(() async {
        sessionId = await harness.isar.sessions.put(
          Session(
            subtitleCollectionId: collectionId,
            fileName: 'repository-test.srt',
          ),
        );
      });

      expect(
        await repository.updateLastEditedIndex(sessionId, 2),
        isTrue,
      );
      expect(await repository.getLastEditedIndex(sessionId), 2);
    });
  });
}
