import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_bulk_review_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockBulkReviewService review;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final subtitles = SubtitleRepository(
        db.isar, CheckpointRepository(db.isar));
    loader = StudioDockSessionLoader(projects, subtitles);
    review = StudioDockBulkReviewService(projects, subtitles);
  });
  tearDown(() async => db.close());

  Future<({int sessionId, int collectionId})> seed() async {
    SubtitleLine line(int id) => SubtitleLine()
      ..index = id
      ..startTime = '00:00:0$id,000'
      ..endTime = '00:00:0${id + 1},000'
      ..original = 'Original $id'
      ..edited = 'Edited $id'
      ..marked = id == 1
      ..comment = id == 1 ? 'Existing note' : null
      ..resolved = id == 1;
    final collection = SubtitleCollection(
        fileName: 'Review.srt', encoding: 'UTF-8',
        lines: [line(1), line(2)]);
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    final session = Session(
        fileName: 'Review.srt', subtitleCollectionId: collection.id);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    return (sessionId: session.id, collectionId: collection.id);
  }

  test('marking a selection creates one checkpoint without editing text',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final updated = await review.apply(
        baseline: baseline, cueNumbers: {1, 2},
        action: StudioDockReviewAction.mark);
    expect(updated, isNotNull);
    expect(updated!.cues.every((cue) => cue.marked), isTrue);
    expect(updated.cues.first.comment, 'Existing note');
    expect(updated.cues.first.resolved, isTrue);
    expect(updated.cues.last.original, 'Original 2');
    expect(updated.cues.last.edited, 'Edited 2');
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('unmarking selected cues clears their review notes and resolves',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final updated = await review.apply(
        baseline: baseline, cueNumbers: {1, 2},
        action: StudioDockReviewAction.unmark);
    expect(updated, isNotNull);
    expect(updated!.cues.first.marked, isFalse);
    expect(updated.cues.first.comment, isNull);
    expect(updated.cues.first.resolved, isFalse);
    expect(updated.cues.last.marked, isFalse);
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('resolve and reopen preserve marks, comments and text', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final resolved = await review.apply(
        baseline: baseline, cueNumbers: {1, 2},
        action: StudioDockReviewAction.resolve);
    expect(resolved, isNotNull);
    expect(resolved!.cues.every((cue) => cue.marked && cue.resolved), isTrue);
    expect(resolved.cues.first.comment, 'Existing note');
    expect(resolved.cues.last.edited, 'Edited 2');
    expect(await db.isar.checkpoints.count(), 2);

    final reopened = await review.apply(
        baseline: resolved, cueNumbers: {1, 2},
        action: StudioDockReviewAction.reopen);
    expect(reopened, isNotNull);
    expect(reopened!.cues.every((cue) => cue.marked && !cue.resolved), isTrue);
    expect(reopened.cues.first.comment, 'Existing note');
    expect(await db.isar.checkpoints.count(), 3);
  });

  test('reopening an unmarked cue does not mark it', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await review.apply(
        baseline: baseline, cueNumbers: {2},
        action: StudioDockReviewAction.reopen), same(baseline));
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('unchanged selected cues are guarded during a mixed batch', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      // Cue 1 is already resolved, but its annotation must still be guarded.
      collection.lines.first.comment = 'Concurrent review edit';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await review.apply(
        baseline: baseline, cueNumbers: {1, 2},
        action: StudioDockReviewAction.resolve), isNull);
    final persisted = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(persisted.lines.first.comment, 'Concurrent review edit');
    expect(persisted.lines.last.resolved, isFalse);
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('unchanged review action also rejects stale state', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.first.edited = 'Concurrent text edit';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await review.apply(
        baseline: baseline, cueNumbers: {1},
        action: StudioDockReviewAction.resolve), isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('a concurrent note change rejects the group without partial changes',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.last.comment = 'New note in other window';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await review.apply(
        baseline: baseline, cueNumbers: {1, 2},
        action: StudioDockReviewAction.mark), isNull);
    final persisted = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(persisted.lines.last.marked, isFalse);
    expect(persisted.lines.last.comment, 'New note in other window');
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('invalid cue selection is rejected without writing', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await review.apply(
        baseline: baseline, cueNumbers: {99},
        action: StudioDockReviewAction.mark), isNull);
    expect(await review.apply(
        baseline: baseline, cueNumbers: {},
        action: StudioDockReviewAction.mark), isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });
}
