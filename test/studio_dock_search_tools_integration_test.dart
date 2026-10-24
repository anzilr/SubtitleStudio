import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_bulk_tools_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_search_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockSearchService search;
  late StudioDockBulkToolsService tools;
  late StudioDockTextEditService edit;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final subtitles = SubtitleRepository(
        db.isar, CheckpointRepository(db.isar));
    loader = StudioDockSessionLoader(projects, subtitles);
    search = StudioDockSearchService(projects, subtitles);
    tools = StudioDockBulkToolsService(projects, subtitles);
    edit = StudioDockTextEditService(projects, subtitles);
  });
  tearDown(() async => db.close());

  Future<({int sessionId, int collectionId})> seed() async {
    final first = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = '<b>Red fish</b> red FISH'
      ..edited = null
      ..marked = true
      ..comment = 'Keep review note'
      ..resolved = true;
    final second = SubtitleLine()
      ..index = 2
      ..startTime = '00:00:03,000'
      ..endTime = '00:00:04,000'
      ..original = 'No matching original'
      ..edited = 'Fish and fish'
      ..marked = false
      ..comment = null
      ..resolved = false;
    final collection = SubtitleCollection(
      fileName: 'Search.srt', encoding: 'UTF-8',
      lines: [first, second],
    );
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    final session = Session(
        fileName: 'Search.srt', subtitleCollectionId: collection.id);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    return (sessionId: session.id, collectionId: collection.id);
  }

  test('Find preserves effective nullable text and query boundaries', () async {
    final ids = await seed();
    final snapshot = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final all = StudioDockSearchService.findSnapshot(
        snapshot: snapshot, term: 'fish',
        caseSensitive: false, wholeWord: true);
    expect(all, hasLength(4));
    expect(all.map((hit) => hit.cueNumber), [1, 1, 2, 2]);
    expect(all.first.occurrence.line.edited, isNull);
    expect(all.first.occurrence.line.comment, 'Keep review note');
    final exact = StudioDockSearchService.findSnapshot(
        snapshot: snapshot, term: 'Fish',
        caseSensitive: true, wholeWord: false);
    expect(exact, hasLength(1));
    expect(exact.single.cueNumber, 2);
    expect(StudioDockSearchService.findSnapshot(
        snapshot: snapshot, term: '',
        caseSensitive: false, wholeWord: false), isEmpty);
  });

  test('Replace selected same-cue matches is one guarded checkpoint', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final matches = StudioDockSearchService.findSnapshot(
        snapshot: baseline, term: 'fish',
        caseSensitive: false, wholeWord: true);
    final updated = await search.replace(
      baseline: baseline, matches: matches.take(2).toList(),
      searchTerm: 'fish', replacement: 'cat', caseSensitive: false);
    expect(updated, isNotNull);
    expect(updated!.cues.first.edited, '<b>Red cat</b> red cat');
    expect(updated.cues.first.original, '<b>Red fish</b> red FISH');
    expect(updated.cues.first.marked, isTrue);
    expect(updated.cues.first.comment, 'Keep review note');
    expect(updated.cues.first.resolved, isTrue);
    expect(updated.cues.last.edited, 'Fish and fish');
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('Replace rejects a stale match and cannot overwrite newer text',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final matches = StudioDockSearchService.findSnapshot(
        snapshot: baseline, term: 'fish',
        caseSensitive: false, wholeWord: false);
    expect(await edit.apply(baseline: baseline, cueNumber: 1,
        editedText: 'Newer work'), isNotNull);
    expect(await search.replace(
      baseline: baseline, matches: matches.take(1).toList(),
      searchTerm: 'fish', replacement: 'cat', caseSensitive: false), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines.first.edited, 'Newer work');
  });

  test('Time shift moves every cue without changing durations or notes',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final shifted = await tools.shiftAll(
        baseline: baseline, deltaMilliseconds: -250);
    expect(shifted, isNotNull);
    expect(shifted!.cues.first.start, '00:00:00,750');
    expect(shifted.cues.first.end, '00:00:01,750');
    expect(shifted.cues.last.start, '00:00:02,750');
    expect(shifted.cues.last.end, '00:00:03,750');
    expect(shifted.cues.first.comment, 'Keep review note');
    expect(shifted.cues.first.storedEdited, isNull);
    expect(await db.isar.checkpoints.count(), 2);
    expect(() => StudioDockBulkToolsService.planShift(shifted, -1000),
        throwsFormatException);
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('Time shift aborts atomically after a concurrent annotation change',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.last.comment = 'Fresh note';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await tools.shiftAll(
        baseline: baseline, deltaMilliseconds: 500), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines.first.startTime, '00:00:01,000');
    expect(stored.lines.last.comment, 'Fresh note');
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('Clear formatting changes only supported tags and keeps original',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final cleared = await tools.clearFormatting(baseline: baseline);
    expect(cleared, isNotNull);
    expect(cleared!.cues.first.edited, 'Red fish red FISH');
    expect(cleared.cues.first.original, '<b>Red fish</b> red FISH');
    expect(cleared.cues.first.comment, 'Keep review note');
    expect(cleared.cues.last.edited, 'Fish and fish');
    expect(await db.isar.checkpoints.count(), 2);
    expect(await tools.clearFormatting(baseline: cleared), same(cleared));
    expect(await db.isar.checkpoints.count(), 2);
  });
}
