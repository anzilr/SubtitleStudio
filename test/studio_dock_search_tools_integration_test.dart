import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_bulk_tools_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_search_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';

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

  Future<({int sessionId, int collectionId})> seed({
      String secondEdited = 'Fish and fish',
      String firstEnd = '00:00:02,000',
      String secondStart = '00:00:03,000',
      String secondEnd = '00:00:04,000',
      bool includeThird = false}) async {
    final first = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = firstEnd
      ..original = '<b>Red fish</b> red FISH'
      ..edited = null
      ..marked = true
      ..comment = 'Keep review note'
      ..resolved = true;
    final second = SubtitleLine()
      ..index = 2
      ..startTime = secondStart
      ..endTime = secondEnd
      ..original = 'No matching original'
      ..edited = secondEdited
      ..marked = false
      ..comment = null
      ..resolved = false;
    final lines = <SubtitleLine>[first, second];
    if (includeThird) {
      lines.add(SubtitleLine()
        ..index = 3
        ..startTime = '00:00:05,050'
        ..endTime = '00:00:07,000'
        ..original = 'Third source'
        ..edited = 'Third target');
    }
    final collection = SubtitleCollection(
      fileName: 'Search.srt', encoding: 'UTF-8',
      lines: lines,
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

  test('quality fixes apply in one guarded checkpoint and reject stale edits',
      () async {
    final ids = await seed(secondEdited: 'Fish  and fish ');
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final fixes = SubtitleQualityChecker.proposeSafeFixes([
      for (final cue in baseline.cues)
        SubtitleQualityCue(id: cue.index, start: cue.start,
            end: cue.end, text: cue.storedEdited ?? cue.original),
    ]);
    expect(fixes, hasLength(1));
    expect(fixes.single.before, 'Fish  and fish ');
    final updated = await tools.applyQualityFixes(
      baseline: baseline, fixes: fixes,
    );
    expect(updated?.cues.last.edited, 'Fish and fish');
    expect(updated?.cues.last.original, 'No matching original');
    expect(await db.isar.checkpoints.count(), 2);

    expect(await tools.applyQualityFixes(baseline: updated!, fixes: fixes),
        isNull, reason: 'A previously applied preview is stale');
    final forged = SubtitleQualityFix(
      cueId: 2,
      before: 'Fish and fish',
      after: 'Something else',
      description: 'Forged replacement',
    );
    expect(await tools.applyQualityFixes(
        baseline: updated, fixes: [forged]), isNull);
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('line-break fix is one guarded checkpoint and rejects forged splits',
      () async {
    const source = 'Alpha beta gamma delta epsilon zeta eta theta';
    final ids = await seed(secondEdited: source);
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final fixes = SubtitleQualityChecker.proposeSafeFixes([
      for (final cue in baseline.cues)
        SubtitleQualityCue(id: cue.index, start: cue.start,
            end: cue.end, text: cue.storedEdited ?? cue.original),
    ], profile: const SubtitleQualityProfile(maxCharactersPerLine: 24));
    expect(fixes, hasLength(1));
    expect(fixes.single.kind, SubtitleQualityFixKind.balancedLineBreak);
    final updated = await tools.applyQualityFixes(
        baseline: baseline, fixes: fixes);
    expect(updated, isNotNull);
    expect(updated!.cues.last.edited.split('\n'), hasLength(2));
    expect(updated.cues.last.original, 'No matching original');
    expect(await db.isar.checkpoints.count(), 2);

    expect(await tools.applyQualityFixes(
        baseline: updated, fixes: fixes), isNull);
    final forged = SubtitleQualityFix(
      cueId: 2,
      before: updated.cues.last.edited,
      after: 'Changed words\nwithout approval',
      description: 'Forged split',
      kind: SubtitleQualityFixKind.balancedLineBreak,
      maxCharactersPerLine: 24,
    );
    expect(await tools.applyQualityFixes(
        baseline: updated, fixes: [forged]), isNull);
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('timing gaps apply atomically with unchanged following-cue guards',
      () async {
    final ids = await seed(firstEnd: '00:00:03,000',
        secondStart: '00:00:03,050', secondEnd: '00:00:05,000',
        includeThird: true);
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final ideas = SubtitleQualityChecker.proposeTimingSuggestions([
      for (final cue in baseline.cues)
        SubtitleQualityCue(id: cue.index, start: cue.start,
            end: cue.end, text: cue.storedEdited ?? cue.original),
    ]);
    expect(ideas, hasLength(2));
    final updated = await tools.applyQualityTimingSuggestions(
        baseline: baseline, suggestions: ideas);
    expect(updated, isNotNull);
    expect(updated!.cues[0].end, '00:00:02,970');
    expect(updated.cues[1].start, '00:00:03,050');
    expect(updated.cues[1].end, '00:00:04,970');
    expect(updated.cues[2].start, '00:00:05,050');
    expect(updated.cues.first.original, '<b>Red fish</b> red FISH');
    expect(updated.cues.first.marked, isTrue);
    expect(updated.cues.first.comment, 'Keep review note');
    expect(await db.isar.checkpoints.count(), 2);
    expect(await tools.applyQualityTimingSuggestions(
        baseline: updated, suggestions: ideas), isNull);
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('timing batch rejects changed neighbor and forged output', () async {
    final ids = await seed(firstEnd: '00:00:03,000',
        secondStart: '00:00:03,050');
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final ideas = SubtitleQualityChecker.proposeTimingSuggestions([
      for (final cue in baseline.cues)
        SubtitleQualityCue(id: cue.index, start: cue.start,
            end: cue.end, text: cue.storedEdited ?? cue.original),
    ]);
    expect(ideas, hasLength(1));
    final originalIdea = ideas.single;
    final forged = SubtitleQualityTimingSuggestion(
      cueId: originalIdea.cueId,
      followingCueId: originalIdea.followingCueId,
      beforeEnd: originalIdea.beforeEnd,
      proposedEnd: '00:00:02,900',
      detail: originalIdea.detail,
      profile: originalIdea.profile,
    );
    expect(await tools.applyQualityTimingSuggestions(
        baseline: baseline, suggestions: [forged]), isNull);
    expect(await db.isar.checkpoints.count(), 0);

    expect(await edit.apply(baseline: baseline, cueNumber: 2,
        editedText: 'New edit to following cue'), isNotNull);
    expect(await tools.applyQualityTimingSuggestions(
        baseline: baseline, suggestions: ideas), isNull,
        reason: 'An unchanged following cue is an optimistic transaction guard');
    final current = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(current.cues.first.end, '00:00:03,000');
    expect(current.cues.last.edited, 'New edit to following cue');
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

  test('Selected stretch keeps durations, unrelated cues and one checkpoint',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final stretched = await tools.shiftSelected(
      baseline: baseline,
      cueNumbers: {1, 2},
      newStart: '00:00:02,000',
      newEnd: '00:00:08,000',
    );
    expect(stretched, isNotNull);
    expect(stretched!.cues.first.start, '00:00:02,000');
    expect(stretched.cues.first.end, '00:00:03,000');
    expect(stretched.cues.last.start, '00:00:06,000');
    expect(stretched.cues.last.end, '00:00:07,000');
    expect(stretched.cues.first.comment, 'Keep review note');
    expect(stretched.cues.first.storedEdited, isNull);
    expect(stretched.cues.last.storedEdited, 'Fish and fish');
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('Selected shift rejects stale and out-of-day edits before history',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(() => StudioDockBulkToolsService.planShiftSelected(
      baseline, {1}, '23:59:59,500', '23:59:59,900'),
      throwsFormatException);
    expect(await db.isar.checkpoints.count(), 0);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.first.comment = 'Newer review work';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await tools.shiftSelected(
      baseline: baseline, cueNumbers: {1},
      newStart: '00:00:02,000', newEnd: '00:00:03,000'), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines.first.startTime, '00:00:01,000');
    expect(stored.lines.first.comment, 'Newer review work');
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('Selected deletion reindexes once and creates one history checkpoint',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final reduced = await tools.deleteSelected(
      baseline: baseline, cueNumbers: {1});
    expect(reduced, isNotNull);
    expect(reduced!.cues, hasLength(1));
    expect(reduced.cues.single.index, 1);
    expect(reduced.cues.single.storedEdited, 'Fish and fish');
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('Selected deletion rejects a stale full snapshot and removes no cues',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.last.comment = 'Newer unrelated note';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await tools.deleteSelected(
      baseline: baseline, cueNumbers: {1}), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines, hasLength(2));
    expect(stored.lines.last.comment, 'Newer unrelated note');
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
