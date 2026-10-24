import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_cue_edit_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockCueEditService edit;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final subtitles = SubtitleRepository(
        db.isar, CheckpointRepository(db.isar));
    loader = StudioDockSessionLoader(projects, subtitles);
    edit = StudioDockCueEditService(projects, subtitles);
  });
  tearDown(() async => db.close());

  Future<({int sessionId, int collectionId})> seed() async {
    final first = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = 'Original subtitle'
      ..edited = 'Draft subtitle'
      ..marked = true
      ..comment = 'Review carefully'
      ..resolved = false;
    final second = SubtitleLine()
      ..index = 2
      ..startTime = '00:00:03,000'
      ..endTime = '00:00:04,000'
      ..original = 'Other subtitle'
      ..edited = null
      ..marked = false
      ..comment = null
      ..resolved = false;
    final collection = SubtitleCollection(
        fileName: 'Combined.srt', encoding: 'UTF-8',
        lines: [first, second]);
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    final session = Session(
        fileName: 'Combined.srt', subtitleCollectionId: collection.id);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    return (sessionId: session.id, collectionId: collection.id);
  }

  test('Text and Timing Apply creates one atomic history edit', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final next = await edit.apply(
        baseline: baseline, cueNumber: 1,
        editedText: '<i>New subtitle</i>',
        start: '00:00:01,250', end: '00:00:02,500');
    expect(next, isNotNull);
    expect(next!.cues.first.edited, '<i>New subtitle</i>');
    expect(next.cues.first.start, '00:00:01,250');
    expect(next.cues.first.end, '00:00:02,500');
    expect(next.cues.first.original, 'Original subtitle');
    expect(next.cues.first.marked, isTrue);
    expect(next.cues.first.comment, 'Review carefully');
    expect(next.cues.last.original, 'Other subtitle');
    expect(next.cues.last.storedEdited, isNull);
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('invalid timing cannot save text in a partial transaction', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await edit.apply(
        baseline: baseline, cueNumber: 1, editedText: 'Changed',
        start: '00:00:03,000', end: '00:00:02,000'), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines.first.edited, 'Draft subtitle');
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('stale annotation blocks combined edit and preserves both fields',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.first.comment = 'Concurrent review note';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await edit.apply(
        baseline: baseline, cueNumber: 1, editedText: 'Stale draft',
        start: '00:00:01,500', end: '00:00:02,500'), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines.first.edited, 'Draft subtitle');
    expect(stored.lines.first.startTime, '00:00:01,000');
    expect(stored.lines.first.comment, 'Concurrent review note');
  });

  test('unchanged combined proposal never checkpoints; stale no-op rejects',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await edit.apply(
        baseline: baseline, cueNumber: 1, editedText: 'Draft subtitle',
        start: '00:00:01,000', end: '00:00:02,000'), same(baseline));
    expect(await db.isar.checkpoints.count(), 0);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.first.marked = false;
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await edit.apply(
        baseline: baseline, cueNumber: 1, editedText: 'Draft subtitle',
        start: '00:00:01,000', end: '00:00:02,000'), isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });
}
