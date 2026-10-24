import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_source_view_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockSourceViewService source;
  late StudioDockTextEditService text;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final subtitles = SubtitleRepository(
        db.isar, CheckpointRepository(db.isar));
    loader = StudioDockSessionLoader(projects, subtitles);
    source = StudioDockSourceViewService(projects, subtitles);
    text = StudioDockTextEditService(projects, subtitles);
  });
  tearDown(() async => db.close());

  Future<({int sessionId, int collectionId})> seed({bool editMode = false}) async {
    final first = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = 'Original\n\nretained'
      ..edited = null
      ..marked = true
      ..comment = 'Keep note'
      ..resolved = false;
    final second = SubtitleLine()
      ..index = 2
      ..startTime = '00:00:03,000'
      ..endTime = '00:00:04,000'
      ..original = 'Original two'
      ..edited = ''
      ..marked = false
      ..comment = null
      ..resolved = false;
    final collection = SubtitleCollection(
      fileName: 'Source.srt', encoding: 'UTF-8', lines: [first, second]);
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    final session = Session(
      fileName: 'Source.srt', subtitleCollectionId: collection.id,
      editMode: editMode);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    return (sessionId: session.id, collectionId: collection.id);
  }

  test('raw Source View composes interior blank lines and empty edited cue',
      () async {
    final ids = await seed();
    final snapshot = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(StudioDockSourceViewService.compose(snapshot),
        '1\n00:00:01,000 --> 00:00:02,000\nOriginal\n\nretained\n\n'
        '2\n00:00:03,000 --> 00:00:04,000\n');
    expect(await source.apply(
        baseline: snapshot,
        rawSource: StudioDockSourceViewService.compose(snapshot)),
        same(snapshot));
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('edit mode Source View stores newly written cues in subtitle text',
      () async {
    final ids = await seed(editMode: true);
    final baseline = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(baseline.isEditMode, isTrue);
    final changed = await source.apply(
      baseline: baseline,
      rawSource: '1\n00:00:01,000 --> 00:00:02,000\nScratch line\n\n'
          '2\n00:00:03,000 --> 00:00:04,000\nSecond line\n\n'
          '3\n00:00:05,000 --> 00:00:06,000\nThird line',
    );
    expect(changed?.isEditMode, isTrue);
    final saved = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(saved.lines[0].edited, 'Scratch line');
    expect(saved.lines[2].original, isEmpty);
    expect(saved.lines[2].edited, 'Third line');
    expect(StudioDockSourceViewService.compose(changed!), contains('Third line'));
  });

  test('bulk Source View edit uses one history commit and retains metadata',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final updated = await source.apply(
      baseline: baseline,
      rawSource: '1\n00:00:01,000 --> 00:00:02,500\nNew edit\n\n'
          '2\n00:00:03,000 --> 00:00:04,000\n\n'
          '3\n00:00:05,000 --> 00:00:06,000\nNew cue',
    );
    expect(updated, isNotNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines, hasLength(3));
    expect(stored.lines[0].original, 'Original\n\nretained');
    expect(stored.lines[0].edited, 'New edit');
    expect(stored.lines[0].endTime, '00:00:02,500');
    expect(stored.lines[0].marked, true);
    expect(stored.lines[0].comment, 'Keep note');
    expect(stored.lines[1].edited, '');
    expect(stored.lines[2].original, 'New cue');
    expect(stored.lines[2].edited, isNull);
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('incomplete and empty raw documents fail without a database write',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    for (final invalid in ['', '1\n00:00:01,000 -->']) {
      await expectLater(source.apply(
          baseline: baseline, rawSource: invalid),
          throwsA(isA<FormatException>()));
    }
    expect(await db.isar.checkpoints.count(), 0);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines, hasLength(2));
  });

  test('stale raw document cannot overwrite intervening cue change', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await text.apply(
        baseline: baseline, cueNumber: 1, editedText: 'Newer edit'),
        isNotNull);
    final result = await source.apply(
      baseline: baseline,
      rawSource: '1\n00:00:01,000 --> 00:00:02,000\nStale source',
    );
    expect(result, isNull);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines.first.edited, 'Newer edit');
    expect(await db.isar.checkpoints.count(), 2);
  });

  test('source reconciliation can remove cues, but cannot erase newer notes',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.first.comment = 'Updated from another window';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await source.apply(
        baseline: baseline,
        rawSource: '1\n00:00:01,000 --> 00:00:02,000\nChanged'), isNull);
    final fresh = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final result = await source.apply(
        baseline: fresh,
        rawSource: '1\n00:00:01,000 --> 00:00:02,000\nChanged');
    expect(result?.cues, hasLength(1));
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines.first.comment, 'Updated from another window');
  });
}
