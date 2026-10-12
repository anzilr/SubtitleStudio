import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/search_replace/search_replace_planner.dart';
import 'package:subtitle_studio/operations/subtitle_sync_operations.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String text) => SubtitleLine()
  ..index = index
  ..startTime = '00:00:0$index,000'
  ..endTime = '00:00:0$index,800'
  ..original = text
  ..edited = null
  ..marked = index == 2
  ..comment = index == 2 ? 'Do not lose this comment' : null
  ..resolved = index == 2;

Future<({int sessionId, int collectionId})> _seed(TestIsarHarness harness) async {
  late int collectionId;
  late int sessionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'batch-edit.srt',
        encoding: 'UTF-8',
        lines: [_line(1, 'First'), _line(2, 'Second')],
      ),
    );
    sessionId = await harness.isar.sessions.put(
      Session(fileName: 'batch-edit.srt', subtitleCollectionId: collectionId),
    );
  });
  return (sessionId: sessionId, collectionId: collectionId);
}

void main() {
  late TestIsarHarness harness;
  late SubtitleRepository repository;
  late CheckpointRepository history;

  setUp(() async {
    harness = await TestIsarHarness.open();
    history = CheckpointRepository(harness.isar);
    repository = SubtitleRepository(harness.isar, history);
  });

  tearDown(() async => harness.close());

  test('normalized-text sparse batch is atomic and undoable', () async {
    final ids = await _seed(harness);
    final initial = await repository.fetchSubtitleCollection(ids.collectionId);
    final expected = CheckpointStateReducer.copyLines(initial!.lines);
    final updated = CheckpointStateReducer.copyLine(expected[1])
      ..edited = 'Normalized Malayalam text';

    expect(await repository.updateMultipleLinesWithHistory(
      collectionId: ids.collectionId,
      sessionId: ids.sessionId,
      expectedLines: [expected[1]],
      updatedLines: [updated],
      operationType: 'normalize',
      description: 'Normalize text',
    ), isTrue);
    final commits = await history.getCheckpointsForSession(ids.sessionId);
    expect(commits, hasLength(2));
    final root = commits.singleWhere((c) => c.operationType == 'snapshot');
    final edit = commits.singleWhere((c) => c.operationType == 'normalize');
    expect(edit.deltas.single.lineIndex, 1);
    expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);

    final after = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    expect(after.lines[0].original, 'First');
    expect(after.lines[1].comment, 'Do not lose this comment');
    expect(after.lines[1].marked, isTrue);
    expect(after.lines[1].resolved, isTrue);
    expect(after.lines[1].edited, 'Normalized Malayalam text');

    expect(await history.undoToCheckpoint(
      checkpointId: root.id,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines[1].edited, isNull);
    expect(await history.redoToCheckpoint(
      checkpointId: edit.id,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines[1].edited, 'Normalized Malayalam text');
  });

  test('changed preview target rejects the whole batch without partial writes',
      () async {
    final ids = await _seed(harness);
    final snapshot = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    final expected = CheckpointStateReducer.copyLines(snapshot.lines);
    final updates = [
      CheckpointStateReducer.copyLine(expected[0])..edited = 'Candidate one',
      CheckpointStateReducer.copyLine(expected[1])..edited = 'Candidate two',
    ];
    await harness.isar.writeTxn(() async {
      final current =
          (await harness.isar.subtitleCollections.get(ids.collectionId))!;
      current.lines[1].comment = 'Concurrent review';
      await harness.isar.subtitleCollections.put(current);
    });

    expect(await repository.updateMultipleLinesWithHistory(
      collectionId: ids.collectionId,
      sessionId: ids.sessionId,
      expectedLines: expected,
      updatedLines: updates,
      operationType: 'normalize',
      description: 'Stale batch',
    ), isFalse);
    final current = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    expect(current.lines[0].edited, isNull);
    expect(current.lines[1].edited, isNull);
    expect(current.lines[1].comment, 'Concurrent review');
    expect(await history.getCheckpointsForSession(ids.sessionId), isEmpty);
  });

  test('unrelated changes remain intact when editing another cue', () async {
    final ids = await _seed(harness);
    final snapshot = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    final originalFirst = CheckpointStateReducer.copyLine(snapshot.lines[0]);
    final changedFirst = CheckpointStateReducer.copyLine(originalFirst)
      ..edited = 'First updated';

    await harness.isar.writeTxn(() async {
      final current =
          (await harness.isar.subtitleCollections.get(ids.collectionId))!;
      current.lines[1].comment = 'Unrelated concurrent comment';
      await harness.isar.subtitleCollections.put(current);
    });

    expect(await repository.updateMultipleLinesWithHistory(
      collectionId: ids.collectionId,
      sessionId: ids.sessionId,
      expectedLines: [originalFirst],
      updatedLines: [changedFirst],
      operationType: 'normalize',
      description: 'Unrelated line safe',
    ), isTrue);
    final current = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    expect(current.lines[0].edited, 'First updated');
    expect(current.lines[1].comment, 'Unrelated concurrent comment');
    expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);
  });

  test('missing cues and duplicate requested indices cause no mutations',
      () async {
    final ids = await _seed(harness);
    final snapshot = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    final original = CheckpointStateReducer.copyLine(snapshot.lines[0]);
    final missing = CheckpointStateReducer.copyLine(original)..index = 500;

    expect(await repository.updateMultipleLinesWithHistory(
      collectionId: ids.collectionId,
      sessionId: ids.sessionId,
      expectedLines: [original],
      updatedLines: [missing],
      operationType: 'normalize',
      description: 'Missing',
    ), isFalse);
    expect(await repository.updateMultipleLinesWithHistory(
      collectionId: ids.collectionId,
      sessionId: ids.sessionId,
      expectedLines: [original],
      updatedLines: [original, original],
      operationType: 'normalize',
      description: 'Duplicate',
    ), isFalse);
    expect((await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines[0].original, 'First');
    expect(await history.getCheckpointsForSession(ids.sessionId), isEmpty);
  });

  test('session mismatch fails without new commit', () async {
    final ids = await _seed(harness);
    final source = (await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines[0];
    expect(await repository.updateMultipleLinesWithHistory(
      collectionId: ids.collectionId,
      sessionId: ids.sessionId + 999,
      expectedLines: [source],
      updatedLines: [CheckpointStateReducer.copyLine(source)..edited = 'Bad'],
      operationType: 'sync',
      description: 'Foreign',
    ), isFalse);
    expect(await history.getCheckpointsForSession(ids.sessionId), isEmpty);
  });

  test('Find & Replace groups selected matches into one reversible V2 commit',
      () async {
    final ids = await _seed(harness);
    await harness.isar.writeTxn(() async {
      final collection =
          (await harness.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines[1].original = 'red red';
      await harness.isar.subtitleCollections.put(collection);
    });
    final root = await history.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    final original = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    final text = original.lines[1];
    final plan = SubtitleSearchReplacePlanner.build(
      matches: [
        SubtitleSearchMatch(line: text, start: 0, end: 3),
        SubtitleSearchMatch(line: text, start: 4, end: 7),
      ],
      searchTerm: 'red',
      replacement: 'x',
      caseSensitive: true,
    );
    expect(plan.replacements, 2);
    expect(await repository.updateMultipleLinesWithHistory(
      collectionId: ids.collectionId,
      sessionId: ids.sessionId,
      expectedLines: plan.expectedLines,
      updatedLines: plan.updatedLines,
      operationType: 'replace',
      description: 'Replace selected matches',
    ), isTrue);

    final checkpoint = (await history.getHeadCheckpoint(ids.sessionId))!;
    expect(checkpoint.operationType, 'replace');
    expect(checkpoint.deltas, hasLength(1));
    expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);
    expect((await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines[1].edited, 'x x');

    expect(await history.undoToCheckpoint(
      checkpointId: root,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines[1].edited, isNull);
    expect(await history.redoToCheckpoint(
      checkpointId: checkpoint.id,
      sessionId: ids.sessionId,
    ), isTrue);
    expect((await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines[1].edited, 'x x');
  });

  test('timecode resync commits V2 history and preserves annotations',
      () async {
    final ids = await _seed(harness);
    final lines = (await repository.fetchSubtitleCollection(ids.collectionId))!
        .lines;
    final result = await SubtitleSyncOperations.shiftTimecodes(
      subtitleRepository: repository,
      subtitleId: ids.collectionId,
      sessionId: ids.sessionId,
      subtitleLines: CheckpointStateReducer.copyLines(lines),
      newStartTime: '00:00:03,000',
      newEndTime: '00:00:04,800',
    );
    expect(result.success, isTrue);
    final updated = (await repository.fetchSubtitleCollection(ids.collectionId))!;
    expect(updated.lines[0].startTime, '00:00:03,000');
    expect(updated.lines[1].startTime, '00:00:04,000');
    expect(updated.lines[1].comment, 'Do not lose this comment');
    expect(updated.lines[1].marked, isTrue);
    expect(updated.lines[1].resolved, isTrue);
    expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);
  });
}
