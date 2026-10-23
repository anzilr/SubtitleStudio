import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/import_comments/project_comment_import.dart';
import 'package:subtitle_studio/features/import_comments/project_comment_repository.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String text) => SubtitleLine()
  ..index = index
  ..startTime = '00:00:0$index,000'
  ..endTime = '00:00:0$index,800'
  ..original = text
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

const _comments = ProjectCommentImportPlan([
  ProjectCommentImportEntry(
    index: 2,
    comment: 'Review translation',
    marked: true,
    resolved: true,
  ),
]);

Future<({int sessionId, int collectionId})> _seed(
  TestIsarHarness harness,
) async {
  late int collectionId;
  late int sessionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'comment-import.srt',
        encoding: 'UTF-8',
        lines: [_line(1, 'First'), _line(2, 'Second')],
      ),
    );
    sessionId = await harness.isar.sessions.put(
      Session(
        fileName: 'comment-import.srt',
        subtitleCollectionId: collectionId,
      ),
    );
  });
  return (sessionId: sessionId, collectionId: collectionId);
}

void main() {
  late TestIsarHarness harness;
  late ProjectCommentRepository imports;
  late CheckpointRepository history;

  setUp(() async {
    harness = await TestIsarHarness.open();
    imports = ProjectCommentRepository(harness.isar);
    history = CheckpointRepository(harness.isar);
  });

  tearDown(() async => harness.close());

  test('comment import produces one v2 delta with exact undo and redo',
      () async {
    final ids = await _seed(harness);
    final root = await history.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );

    expect(
      await imports.importComments(
        subtitleCollectionId: ids.collectionId,
        plan: _comments,
      ),
      1,
    );
    final entries = await history.getCheckpointsForSession(ids.sessionId);
    expect(entries, hasLength(2));
    final edit = entries.singleWhere(
      (checkpoint) => checkpoint.operationType == 'import-comments',
    );
    expect(edit.parentCheckpointId, root);
    expect(edit.checkpointType, 'delta');
    expect(edit.deltas, hasLength(1));
    expect(edit.deltas.single.lineIndex, 1);
    expect(CheckpointHistoryMetadata.isPostOperation(edit), isTrue);
    expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);

    var collection =
        (await harness.isar.subtitleCollections.get(ids.collectionId))!;
    expect(collection.lines[0].comment, isNull);
    expect(collection.lines[1].comment, 'Review translation');
    expect(collection.lines[1].marked, isTrue);
    expect(collection.lines[1].resolved, isTrue);

    expect(await history.undoToCheckpoint(
      checkpointId: root,
      sessionId: ids.sessionId,
    ), isTrue);
    collection =
        (await harness.isar.subtitleCollections.get(ids.collectionId))!;
    expect(collection.lines[1].comment, isNull);
    expect(collection.lines[1].marked, isFalse);

    expect(await history.redoToCheckpoint(
      checkpointId: edit.id,
      sessionId: ids.sessionId,
    ), isTrue);
    collection =
        (await harness.isar.subtitleCollections.get(ids.collectionId))!;
    expect(collection.lines[1].comment, 'Review translation');
    expect(collection.lines[1].resolved, isTrue);
  });

  test('same import twice does not add an extra commit', () async {
    final ids = await _seed(harness);
    expect(await imports.importComments(
      subtitleCollectionId: ids.collectionId,
      plan: _comments,
      sessionId: ids.sessionId,
    ), 1);
    final before = await history.getCheckpointsForSession(ids.sessionId);
    expect(before, hasLength(2));

    expect(await imports.importComments(
      subtitleCollectionId: ids.collectionId,
      plan: _comments,
      sessionId: ids.sessionId,
    ), 1);
    final after = await history.getCheckpointsForSession(ids.sessionId);
    expect(after, hasLength(2));
  });

  test('import mutates current persisted lines, never a stale collection copy',
      () async {
    final ids = await _seed(harness);
    await harness.isar.writeTxn(() async {
      final current =
          (await harness.isar.subtitleCollections.get(ids.collectionId))!;
      current.lines[0].original = 'Changed before import';
      current.lines[1].edited = 'Retained translation';
      await harness.isar.subtitleCollections.put(current);
    });

    expect(await imports.importComments(
      subtitleCollectionId: ids.collectionId,
      plan: _comments,
    ), 1);
    final current =
        (await harness.isar.subtitleCollections.get(ids.collectionId))!;
    expect(current.lines[0].original, 'Changed before import');
    expect(current.lines[1].edited, 'Retained translation');
    expect(current.lines[1].comment, 'Review translation');
    expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);
  });

  test('foreign explicit session cannot import into another collection',
      () async {
    final ids = await _seed(harness);
    final second = await harness.isar.writeTxn(() async {
      final other = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'other.srt',
          encoding: 'UTF-8',
          lines: [_line(2, 'Foreign')],
        ),
      );
      return harness.isar.sessions.put(
        Session(fileName: 'other.srt', subtitleCollectionId: other),
      );
    });

    await expectLater(
      () => imports.importComments(
        subtitleCollectionId: ids.collectionId,
        sessionId: second,
        plan: _comments,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await harness.isar.subtitleCollections.get(ids.collectionId))!
        .lines[1].comment, isNull);
    expect(await history.getCheckpointsForSession(second), isEmpty);
  });

  test('ambiguous collection owner is rejected rather than guessed',
      () async {
    final ids = await _seed(harness);
    await harness.isar.writeTxn(() async {
      await harness.isar.sessions.put(
        Session(
          fileName: 'second-owner.srt',
          subtitleCollectionId: ids.collectionId,
        ),
      );
    });

    await expectLater(
      () => imports.importComments(
        subtitleCollectionId: ids.collectionId,
        plan: _comments,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await harness.isar.subtitleCollections.get(ids.collectionId))!
        .lines[1].comment, isNull);
    expect(await history.getCheckpointsForSession(ids.sessionId), isEmpty);
  });

  test('duplicate imported cue numbers fail without partial writes',
      () async {
    final ids = await _seed(harness);
    await expectLater(
      () => imports.importComments(
        subtitleCollectionId: ids.collectionId,
        plan: const ProjectCommentImportPlan([
          ProjectCommentImportEntry(
            index: 2,
            comment: 'First',
            marked: true,
            resolved: false,
          ),
          ProjectCommentImportEntry(
            index: 2,
            comment: 'Second',
            marked: false,
            resolved: true,
          ),
        ]),
      ),
      throwsA(isA<FormatException>()),
    );
    expect((await harness.isar.subtitleCollections.get(ids.collectionId))!
        .lines[1].comment, isNull);
    expect(await history.getCheckpointsForSession(ids.sessionId), isEmpty);
  });
}
