import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_repository.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String value) => SubtitleLine()
  ..index = index
  ..startTime = '00:00:0$index,000'
  ..endTime = '00:00:0$index,800'
  ..original = value
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

Future<({int sessionId, int collectionId})> _seed(
  TestIsarHarness harness,
) async {
  late int sessionId;
  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'migration.srt',
        encoding: 'UTF-8',
        lines: [_line(1, 'One'), _line(2, 'Two')],
      ),
    );
    sessionId = await harness.isar.sessions.put(
      Session(
        fileName: 'migration.srt',
        subtitleCollectionId: collectionId,
      ),
    );
  });
  return (sessionId: sessionId, collectionId: collectionId);
}

void main() {
  late TestIsarHarness harness;
  late CheckpointRepository checkpoints;
  late SubtitleRepository editor;
  late EditLineRepository editLine;

  setUp(() async {
    harness = await TestIsarHarness.open();
    checkpoints = CheckpointRepository(harness.isar);
    editor = SubtitleRepository(harness.isar, checkpoints);
    editLine = EditLineRepository(
      harness.isar,
      EditLinePreferencesRepository(harness.isar),
    );
  });

  tearDown(() async => harness.close());

  test('annotations are v2 commits with exact undo and redo', () async {
    final ids = await _seed(harness);
    final root = await checkpoints.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    expect(root, greaterThan(0));
    expect(await editor.markLine(
      ids.collectionId, 0, true, sessionId: ids.sessionId,
    ), isTrue);
    expect(await editor.updateComment(
      ids.collectionId, 0, 'Review this', sessionId: ids.sessionId,
    ), isTrue);
    final beforeResolve = (await checkpoints.getHeadCheckpoint(ids.sessionId))!.id;

    expect(await editor.updateResolved(
      ids.collectionId, 0, true, sessionId: ids.sessionId,
    ), isTrue);
    final resolvedId = (await checkpoints.getHeadCheckpoint(ids.sessionId))!.id;
    expect(await editor.unmarkLine(
      ids.collectionId, 0, sessionId: ids.sessionId,
    ), isTrue);
    final history = await checkpoints.getCheckpointsForSession(ids.sessionId);
    expect(history, hasLength(5));
    expect(history.where(
      (checkpoint) => checkpoint.operationType == 'annotation',
    ), hasLength(4));
    expect(history.every(
      (checkpoint) => CheckpointHistoryMetadata.isPostOperation(checkpoint),
    ), isTrue);
    expect((await checkpoints.validateHistory(ids.sessionId)).isHealthy, isTrue);

    expect(await checkpoints.undoToCheckpoint(
      checkpointId: beforeResolve,
      sessionId: ids.sessionId,
    ), isTrue);
    var document = (await editor.fetchSubtitleCollection(ids.collectionId))!;
    expect(document.lines.first.marked, isTrue);
    expect(document.lines.first.comment, 'Review this');
    expect(document.lines.first.resolved, isFalse);

    expect(await checkpoints.redoToCheckpoint(
      checkpointId: resolvedId,
      sessionId: ids.sessionId,
    ), isTrue);
    document = (await editor.fetchSubtitleCollection(ids.collectionId))!;
    expect(document.lines.first.resolved, isTrue);
    expect((await checkpoints.validateHistory(ids.sessionId)).isHealthy, isTrue);
  });

  test('no-op annotation does not add redundant commits', () async {
    final ids = await _seed(harness);
    expect(await editor.markLine(
      ids.collectionId, 0, true, sessionId: ids.sessionId,
    ), isTrue);
    final prior = await checkpoints.getCheckpointsForSession(ids.sessionId);
    expect(prior, hasLength(2));
    expect(await editor.markLine(
      ids.collectionId, 0, true, sessionId: ids.sessionId,
    ), isTrue);
    final after = await checkpoints.getCheckpointsForSession(ids.sessionId);
    expect(after, hasLength(2));
  });

  test('foreign session cannot commit or mutate another subtitle collection',
      () async {
    final ids = await _seed(harness);
    final foreign = await harness.isar.writeTxn(() async {
      final other = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'foreign.srt',
          encoding: 'UTF-8',
          lines: [_line(1, 'Other')],
        ),
      );
      return harness.isar.sessions.put(
        Session(
          fileName: 'foreign.srt',
          subtitleCollectionId: other,
        ),
      );
    });

    expect(await editor.markLine(
      ids.collectionId, 0, true, sessionId: foreign,
    ), isFalse);
    expect(await editor.addLineWithHistory(
      collectionId: ids.collectionId,
      line: _line(3, 'Injected'),
      insertIndex: 2,
      sessionId: foreign,
    ), isFalse);
    final document = (await editor.fetchSubtitleCollection(ids.collectionId))!;
    expect(document.lines, hasLength(2));
    expect(document.lines.first.marked, isFalse);
    expect(await checkpoints.getCheckpointsForSession(foreign), isEmpty);
  });

  test('active editor add and delete use replayable v2 history', () async {
    final ids = await _seed(harness);
    final root = await checkpoints.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    expect(await editor.addLineWithHistory(
      collectionId: ids.collectionId,
      line: _line(3, 'Three'),
      insertIndex: 2,
      sessionId: ids.sessionId,
    ), isTrue);
    final afterAdd = (await checkpoints.getHeadCheckpoint(ids.sessionId))!.id;
    expect(await editor.deleteLineWithHistory(
      collectionId: ids.collectionId,
      index: 0,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await checkpoints.validateHistory(ids.sessionId)).isHealthy, isTrue);

    expect(await checkpoints.undoToCheckpoint(
      checkpointId: afterAdd,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await editor.fetchSubtitleCollection(ids.collectionId))!
        .lines.length, 3);
    expect(await checkpoints.undoToCheckpoint(
      checkpointId: root,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await editor.fetchSubtitleCollection(ids.collectionId))!
        .lines.length, 2);
  });

  test('Edit Line annotation and insert APIs preserve undo history',
      () async {
    final ids = await _seed(harness);
    final root = await checkpoints.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    expect(await editLine.markSubtitleLine(
      ids.collectionId, 0, true, sessionId: ids.sessionId,
    ), isTrue);
    expect(await editLine.updateSubtitleLineComment(
      ids.collectionId, 0, 'Proofread', sessionId: ids.sessionId,
    ), isTrue);
    expect(await editLine.updateSubtitleLineResolved(
      ids.collectionId, 0, true, sessionId: ids.sessionId,
    ), isTrue);
    expect(await editLine.addSubtitleLineWithHistory(
      collectionId: ids.collectionId,
      line: _line(3, 'New'),
      insertIndex: 2,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await checkpoints.validateHistory(ids.sessionId)).isHealthy, isTrue);
    expect(await checkpoints.undoToCheckpoint(
      checkpointId: root,
      sessionId: ids.sessionId,
    ), isTrue);
    final original = (await editor.fetchSubtitleCollection(ids.collectionId))!;
    expect(original.lines, hasLength(2));
    expect(original.lines.first.marked, isFalse);
    expect(original.lines.first.comment, isNull);
    expect(original.lines.first.resolved, isFalse);
  });

  test('Source View bulk replacement is a single validated V2 commit',
      () async {
    final ids = await _seed(harness);
    final root = await checkpoints.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    await editor.syncSourceViewToDatabase(ids.collectionId, [
      SubtitleEntry(
        index: '2',
        startTime: '00:00:02,000',
        endTime: '00:00:02,800',
        text: 'Two revised',
      ),
      SubtitleEntry(
        index: '99',
        startTime: '00:00:03,000',
        endTime: '00:00:03,800',
        text: 'Inserted',
      ),
      SubtitleEntry(
        index: '1',
        startTime: '00:00:01,000',
        endTime: '00:00:01,800',
        text: 'One',
      ),
    ], sessionId: ids.sessionId);

    final history = await checkpoints.getCheckpointsForSession(ids.sessionId);
    expect(history, hasLength(2));
    expect(history.singleWhere((c) => c.operationType == 'source-view')
        .checkpointType, 'snapshot');
    expect((await checkpoints.validateHistory(ids.sessionId)).isHealthy, isTrue);
    final changed = (await editor.fetchSubtitleCollection(ids.collectionId))!;
    expect(changed.lines.map((l) => l.original).toList(),
        ['Two', 'Inserted', 'One']);
    expect(changed.lines.first.edited, 'Two revised');

    final headId = (await checkpoints.getHeadCheckpoint(ids.sessionId))!.id;
    expect(await checkpoints.undoToCheckpoint(
      checkpointId: root,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await editor.fetchSubtitleCollection(ids.collectionId))!
        .lines.map((l) => l.original).toList(), ['One', 'Two']);
    expect(await checkpoints.redoToCheckpoint(
      checkpointId: headId,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await editor.fetchSubtitleCollection(ids.collectionId))!
        .lines.map((l) => l.original).toList(),
        ['Two', 'Inserted', 'One']);
  });

  test('positional diff replays arbitrary shrink, grow and no-op states', () {
    for (final (before, after) in <(List<SubtitleLine>, List<SubtitleLine>)>[
      ([_line(1, 'A'), _line(2, 'B')], [_line(1, 'C')]),
      ([_line(1, 'A')], [_line(1, 'A'), _line(2, 'B')]),
      ([_line(1, 'A')], <SubtitleLine>[]),
      (<SubtitleLine>[], [_line(1, 'A')]),
      ([_line(1, 'A')], [_line(1, 'A')]),
    ]) {
      final deltas = CheckpointStateReducer.diffAsIndexDeltas(before, after);
      final replayed = CheckpointStateReducer.copyLines(before);
      CheckpointStateReducer.applyDeltasStrictInPlace(replayed, deltas);
      expect(CheckpointStateReducer.samePersistedLines(replayed, after), isTrue);
    }
  });

}
