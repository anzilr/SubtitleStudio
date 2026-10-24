import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_notes_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockNotesService notes;
  late StudioDockTextEditService text;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final subtitles = SubtitleRepository(
        db.isar, CheckpointRepository(db.isar));
    loader = StudioDockSessionLoader(projects, subtitles);
    notes = StudioDockNotesService(projects, subtitles);
    text = StudioDockTextEditService(projects, subtitles);
  });
  tearDown(() async => db.close());

  Future<({int sessionId, int collectionId})> seed() async {
    final line = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = 'Original subtitle'
      ..edited = 'Edited subtitle'
      ..marked = false
      ..comment = null
      ..resolved = false;
    final collection = SubtitleCollection(
        fileName: 'Notes.srt', encoding: 'UTF-8', lines: [line]);
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    final session = Session(
        fileName: 'Notes.srt', subtitleCollectionId: collection.id);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    return (sessionId: session.id, collectionId: collection.id);
  }

  test('one Notes Apply preserves cue data and records a history point',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final updated = await notes.apply(
      baseline: baseline, cueNumber: 1,
      comment: 'Check translation\nagainst reference',
      marked: true, resolved: true,
    );
    expect(updated, isNotNull);
    expect(updated!.cues.single.comment,
        'Check translation\nagainst reference');
    expect(updated.cues.single.marked, isTrue);
    expect(updated.cues.single.resolved, isTrue);
    final persisted = (await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines.single;
    expect(persisted.original, 'Original subtitle');
    expect(persisted.edited, 'Edited subtitle');
    expect(persisted.startTime, '00:00:01,000');
    expect(await db.isar.checkpoints.count(), 2);

    final cleared = await notes.apply(
      baseline: updated, cueNumber: 1,
      comment: null, marked: false, resolved: false);
    expect(cleared!.cues.single.comment, isNull);
    expect(cleared.cues.single.marked, isFalse);
    expect(cleared.cues.single.resolved, isFalse);
    expect(await db.isar.checkpoints.count(), 3);
  });

  test('comment automatically marks line; blank comment normalizes to null',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    final updated = await notes.apply(
      baseline: baseline, cueNumber: 1,
      comment: 'Review this', marked: false, resolved: false);
    expect(updated!.cues.single.marked, isTrue);
    expect(updated.cues.single.comment, 'Review this');
    final cleared = await notes.apply(
      baseline: updated, cueNumber: 1,
      comment: '   ', marked: false, resolved: false);
    expect(cleared!.cues.single.comment, isNull);
    expect(cleared.cues.single.marked, isFalse);
  });

  test('no-op and missing cue never create a checkpoint', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await notes.apply(
      baseline: baseline, cueNumber: 1,
      comment: null, marked: false, resolved: false), same(baseline));
    expect(await notes.apply(
      baseline: baseline, cueNumber: 99,
      comment: 'Invalid', marked: true, resolved: false), isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('stale text or review metadata rejects an old Notes draft', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await text.apply(
      baseline: baseline, cueNumber: 1, editedText: 'Newer text'), isNotNull);
    expect(await notes.apply(
      baseline: baseline, cueNumber: 1,
      comment: 'Must not overwrite', marked: true, resolved: false), isNull);
    final fresh = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.single.comment = 'Newer comment';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await notes.apply(
      baseline: fresh, cueNumber: 1,
      comment: 'Stale note', marked: true, resolved: false), isNull);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines.single.comment, 'Newer comment');
  });

  test('unchanged draft also rejects a stale persisted cue', () async {
    final ids = await seed();
    final baseline = await loader.load(
        sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await text.apply(
      baseline: baseline, cueNumber: 1, editedText: 'Concurrent edit'),
        isNotNull);
    expect(await notes.apply(
      baseline: baseline, cueNumber: 1,
      comment: null, marked: false, resolved: false), isNull);
  });
}
