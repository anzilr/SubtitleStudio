import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_repository.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_draft_save_service.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line({
  required int index,
  required String original,
  String? edited,
  required String start,
  required String end,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = start
    ..endTime = end
    ..original = original
    ..edited = edited
    ..marked = false
    ..comment = null
    ..resolved = false;
}

Future<({int collectionId, int sessionId})> _seed(
  TestIsarHarness harness,
) async {
  final collection = SubtitleCollection(
    fileName: 'edit-line.srt',
    encoding: 'UTF-8',
    lines: [
      _line(
        index: 1,
        original: 'One',
        start: '00:00:01,000',
        end: '00:00:01,900',
      ),
      _line(
        index: 2,
        original: 'Two',
        start: '00:00:02,000',
        end: '00:00:02,900',
      ),
    ],
  );

  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(collection);
  });

  final session = Session(
    fileName: 'edit-line.srt',
    subtitleCollectionId: collectionId,
  );

  late int sessionId;
  await harness.isar.writeTxn(() async {
    sessionId = await harness.isar.sessions.put(session);
  });

  return (collectionId: collectionId, sessionId: sessionId);
}

void main() {
  late TestIsarHarness harness;
  late EditLineRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = EditLineRepository(
      harness.isar,
      EditLinePreferencesRepository(harness.isar),
    );
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('EditLineRepository persistence', () {
    test('draft save persists a blank edit with immutable checkpoint before-state',
        () async {
      final ids = await _seed(harness);
      await harness.isar.writeTxn(() async {
        final collection =
            (await harness.isar.subtitleCollections.get(ids.collectionId))!;
        collection.lines.first.edited = 'Earlier translation';
        await harness.isar.subtitleCollections.put(collection);
      });

      final history = CheckpointRepository(harness.isar);
      await history.createInitialSnapshot(
        sessionId: ids.sessionId,
        subtitleCollectionId: ids.collectionId,
      );
      final original =
          (await repository.fetchSubtitleLine(ids.collectionId, 1))!;
      final saver = EditLineDraftSaveService(
        saveExisting: (line, {beforeLine}) =>
            repository.saveSubtitleLineChangesResolved(
          collectionId: ids.collectionId,
          updatedLine: line,
          beforeLine: beforeLine,
          sessionId: ids.sessionId,
        ),
        insertNew: (line, index) => repository.addSubtitleLineWithHistoryResolved(
          collectionId: ids.collectionId,
          line: line,
          insertIndex: index,
          sessionId: ids.sessionId,
        ),
        updateLastEditedIndex: (index) =>
            repository.updateLastEditedIndex(ids.sessionId, index),
      );

      final result = await saver.save(
        currentLine: original,
        originalText: 'Updated source',
        editedText: '',
        startTime: original.startTime,
        endTime: original.endTime,
        initialOriginalText: original.original,
        initialStartTime: original.startTime,
        initialEndTime: original.endTime,
        isEditMode: false,
        insertLine: false,
        insertIndex: 0,
      );

      expect(result.saved, isTrue);
      expect(original.edited, 'Earlier translation');
      expect(original.original, 'One');
      final stored =
          (await repository.fetchSubtitleLine(ids.collectionId, 1))!;
      expect(stored.edited, '');
      expect(stored.original, 'Updated source');
      final checkpoints = await harness.isar.checkpoints
          .filter().sessionIdEqualTo(ids.sessionId).sortByTimestamp().findAll();
      expect(checkpoints, hasLength(2));
      expect(checkpoints.last.deltas, hasLength(1));
      expect(checkpoints.last.deltas.single.beforeState?.edited,
          'Earlier translation');
      expect(checkpoints.last.deltas.single.afterState?.edited, '');
    });


    test('timing reorder returns committed selection and full row order',
        () async {
      final ids = await _seed(harness);
      final history = CheckpointRepository(harness.isar);
      await history.createInitialSnapshot(
        sessionId: ids.sessionId,
        subtitleCollectionId: ids.collectionId,
      );
      final original = (await repository.fetchSubtitleLine(
        ids.collectionId, 1,
      ))!;
      final updated = _line(
        index: 1,
        original: 'One',
        edited: '',
        start: '00:00:03,000',
        end: '00:00:03,900',
      )..comment = 'moved cue';
      final committed = await repository.saveSubtitleLineChangesResolved(
        collectionId: ids.collectionId,
        updatedLine: updated,
        beforeLine: original,
        sessionId: ids.sessionId,
      );
      expect(committed, isNotNull);
      expect(committed!.selectedLine.index, 2);
      expect(committed.selectedLine.original, 'One');
      expect(committed.selectedLine.edited, '');
      expect(committed.lines.map((line) => line.original).toList(),
          ['Two', 'One']);
      expect(committed.lines.map((line) => line.index).toList(), [1, 2]);
      expect(original.index, 1);
      final persisted = (await repository.fetchSubtitleCollection(
        ids.collectionId,
      ))!;
      expect(persisted.lines.map((line) => line.original).toList(),
          ['Two', 'One']);
      expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);
    });

    test('identical text and timecodes retain distinct cue identity',
        () async {
      final ids = await _seed(harness);
      await harness.isar.writeTxn(() async {
        final collection = (await harness.isar.subtitleCollections.get(
          ids.collectionId,
        ))!;
        collection.lines[0]
          ..original = 'Same'
          ..edited = ''
          ..comment = 'first cue';
        collection.lines[1]
          ..original = 'Same'
          ..edited = ''
          ..comment = 'second cue';
        await harness.isar.subtitleCollections.put(collection);
      });
      final original = (await repository.fetchSubtitleLine(
        ids.collectionId, 1,
      ))!;
      final updated = _line(
        index: 1,
        original: 'Same',
        edited: '',
        start: '00:00:02,000',
        end: '00:00:02,900',
      )..comment = 'first cue';
      final committed = await repository.saveSubtitleLineChangesResolved(
        collectionId: ids.collectionId,
        updatedLine: updated,
        beforeLine: original,
        sessionId: ids.sessionId,
      );
      expect(committed, isNotNull);
      expect(committed!.selectedLine.index, 1);
      expect(committed.selectedLine.comment, 'first cue');
      expect(committed.lines[1].comment, 'second cue');
      expect(committed.lines.map((line) => line.original).toList(),
          ['Same', 'Same']);
    });

    test('insertion returns post-sort index and exact ordered rows',
        () async {
      final ids = await _seed(harness);
      final inserted = _line(
        index: 3,
        original: 'Early inserted',
        edited: '',
        start: '00:00:00,500',
        end: '00:00:00,800',
      );
      final committed = await repository.addSubtitleLineWithHistoryResolved(
        collectionId: ids.collectionId,
        line: inserted,
        insertIndex: 2,
        sessionId: ids.sessionId,
      );
      expect(committed, isNotNull);
      expect(committed!.selectedLine.index, 1);
      expect(committed.lines.map((line) => line.original).toList(),
          ['Early inserted', 'One', 'Two']);
      expect(committed.lines.map((line) => line.index).toList(), [1, 2, 3]);
      expect(inserted.index, 3);
    });

    test('Save As updates paths without overwriting subsequent subtitle edits',
        () async {
      final ids = await _seed(harness);
      final stale = await repository.fetchSubtitleCollection(ids.collectionId);
      expect(stale, isNotNull);

      // Simulate a concurrent edit while the Save As file picker was open.
      await harness.isar.writeTxn(() async {
        final fresh =
            (await harness.isar.subtitleCollections.get(ids.collectionId))!;
        fresh.lines.first.original = 'Newer edit';
        fresh.lines.last.comment = 'Review note';
        await harness.isar.subtitleCollections.put(fresh);
      });

      expect(await repository.updateSubtitleSaveLocation(
        collectionId: ids.collectionId,
        sessionId: ids.sessionId,
        filePath: '/subtitles/saved-as.srt',
        originalFileUri: '/subtitles/saved-as.srt',
      ), isTrue);

      final saved =
          (await repository.fetchSubtitleCollection(ids.collectionId))!;
      expect(saved.filePath, '/subtitles/saved-as.srt');
      expect(saved.originalFileUri, '/subtitles/saved-as.srt');
      expect(saved.lines.first.original, 'Newer edit');
      expect(saved.lines.last.comment, 'Review note');
      expect(await harness.isar.checkpoints.count(), 0);
    });

    test('Save As cannot mutate another session or a missing collection',
        () async {
      final ids = await _seed(harness);
      expect(await repository.updateSubtitleSaveLocation(
        collectionId: ids.collectionId,
        sessionId: ids.sessionId + 100000,
        filePath: '/different.srt',
        originalFileUri: '/different.srt',
      ), isFalse);
      expect(await repository.updateSubtitleSaveLocation(
        collectionId: ids.collectionId + 100000,
        sessionId: ids.sessionId,
        filePath: '/different.srt',
        originalFileUri: '/different.srt',
      ), isFalse);
      expect(await repository.updateSubtitleSaveLocation(
        collectionId: ids.collectionId,
        sessionId: ids.sessionId,
        filePath: '',
        originalFileUri: '/different.srt',
      ), isFalse);
      final current =
          (await repository.fetchSubtitleCollection(ids.collectionId))!;
      expect(current.filePath, isNull);
      expect(current.originalFileUri, isNull);
      expect(current.lines.first.original, 'One');
    });

    test('Edit Line raw full-collection writes cannot replace V2 state',
        () async {
      final ids = await _seed(harness);
      final old = (await repository.fetchSubtitleCollection(ids.collectionId))!;
      final history = CheckpointRepository(harness.isar);
      await history.createInitialSnapshot(
        sessionId: ids.sessionId,
        subtitleCollectionId: ids.collectionId,
      );
      final before = await repository.fetchSubtitleLine(ids.collectionId, 1);
      final updated = _line(
        index: 1,
        original: 'Current committed state',
        start: '00:00:01,000',
        end: '00:00:01,900',
      );
      expect(await repository.saveSubtitleLineChanges(
        collectionId: ids.collectionId,
        updatedLine: updated,
        sessionId: ids.sessionId,
        beforeLine: before,
      ), isTrue);

      old.lines.first.original = 'Stale data';
      expect(await repository.updateSubtitleCollection(old), isFalse);
      expect((await repository.fetchSubtitleCollection(ids.collectionId))!
          .lines.first.original, 'Current committed state');
      expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);
    });

    test('save stores an atomic v2 post-operation checkpoint', () async {
      final ids = await _seed(harness);
      await harness.isar.writeTxn(() async {
        await harness.isar.preferences.put(
          Preferences(
            autoSave: true,
            checkpointStrategy: 'snapshot',
          ),
        );
      });

      final checkpoints = CheckpointRepository(harness.isar);
      final initialId = await checkpoints.createInitialSnapshot(
        sessionId: ids.sessionId,
        subtitleCollectionId: ids.collectionId,
      );
      expect(initialId, isNot(0));

      final before =
          await repository.fetchSubtitleLine(ids.collectionId, 1);
      expect(before, isNotNull);

      final updated = _line(
        index: 1,
        original: 'One',
        edited: 'Translated one',
        start: '00:00:01,000',
        end: '00:00:01,900',
      );

      expect(
        await repository.saveSubtitleLineChanges(
          collectionId: ids.collectionId,
          updatedLine: updated,
          sessionId: ids.sessionId,
          beforeLine: before,
        ),
        isTrue,
      );

      final stored =
          await repository.fetchSubtitleLine(ids.collectionId, 1);
      expect(stored?.edited, 'Translated one');

      final history = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(ids.sessionId)
          .sortByTimestamp()
          .findAll();
      expect(history, hasLength(2));

      final checkpoint = history.last;
      expect(CheckpointHistoryMetadata.isPostOperation(checkpoint), isTrue);
      expect(checkpoint.parentCheckpointId, initialId);
      expect(checkpoint.checkpointType, 'snapshot');
      expect(checkpoint.snapshot, hasLength(2));
      expect(checkpoint.snapshot.first.original, 'One');
      expect(checkpoint.snapshot.first.edited, 'Translated one');
      expect(checkpoint.deltas, hasLength(1));
      expect(checkpoint.deltas.single.beforeState?.edited, isNull);
      expect(
        checkpoint.deltas.single.afterState?.edited,
        'Translated one',
      );

      expect(
        await checkpoints.undoToCheckpoint(
          checkpointId: initialId,
          sessionId: ids.sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleLine(ids.collectionId, 1))?.edited,
        isNull,
      );

      expect(
        await checkpoints.redoToCheckpoint(
          checkpointId: checkpoint.id,
          sessionId: ids.sessionId,
        ),
        isTrue,
      );
      expect(
        (await repository.fetchSubtitleLine(ids.collectionId, 1))?.edited,
        'Translated one',
      );
    });

    test('failed atomic edit leaves collection and history unchanged',
        () async {
      final ids = await _seed(harness);
      final invalid = _line(
        index: 99,
        original: 'Invalid',
        start: '00:00:09,000',
        end: '00:00:09,900',
      );

      expect(
        await repository.saveSubtitleLineChanges(
          collectionId: ids.collectionId,
          updatedLine: invalid,
          sessionId: ids.sessionId,
        ),
        isFalse,
      );

      final collection =
          await repository.fetchSubtitleCollection(ids.collectionId);
      expect(
        collection!.lines.map((line) => line.original).toList(),
        ['One', 'Two'],
      );
      expect(
        await harness.isar.checkpoints
            .filter()
            .sessionIdEqualTo(ids.sessionId)
            .findAll(),
        isEmpty,
      );
    });

    test('add and delete persist normalized cue indexes', () async {
      final ids = await _seed(harness);

      expect(
        await repository.addSubtitleLine(
          ids.collectionId,
          _line(
            index: 2,
            original: 'Between',
            start: '00:00:01,950',
            end: '00:00:01,990',
          ),
          1,
        ),
        isTrue,
      );

      var collection =
          await repository.fetchSubtitleCollection(ids.collectionId);
      expect(
        collection!.lines.map((line) => line.original).toList(),
        ['One', 'Between', 'Two'],
      );
      expect(
        collection.lines.map((line) => line.index).toList(),
        [1, 2, 3],
      );

      expect(
        await repository.deleteSubtitleLine(ids.collectionId, 1),
        isTrue,
      );

      collection =
          await repository.fetchSubtitleCollection(ids.collectionId);
      expect(
        collection!.lines.map((line) => line.original).toList(),
        ['One', 'Two'],
      );
      expect(
        collection.lines.map((line) => line.index).toList(),
        [1, 2],
      );
    });
  });
}
