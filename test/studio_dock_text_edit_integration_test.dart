import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockTextEditService editor;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final subtitles = SubtitleRepository(
      db.isar, CheckpointRepository(db.isar));
    loader = StudioDockSessionLoader(projects, subtitles);
    editor = StudioDockTextEditService(projects, subtitles);
  });
  tearDown(() async => db.close());

  Future<({int sessionId, int collectionId})> seed() async {
    final first = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,100'
      ..original = 'Original\nretained'
      ..edited = null
      ..marked = true
      ..comment = 'Existing note'
      ..resolved = false;
    final second = SubtitleLine()
      ..index = 2
      ..startTime = '00:00:03,000'
      ..endTime = '00:00:04,000'
      ..original = ''
      ..edited = ''
      ..marked = false
      ..comment = null
      ..resolved = false;
    final collection = SubtitleCollection(
      fileName: 'Desktop.srt',
      encoding: 'UTF-8',
      lines: [first, second],
    );
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    final session = Session(
      fileName: 'Desktop.srt',
      subtitleCollectionId: collection.id,
    );
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    return (sessionId: session.id, collectionId: collection.id);
  }

  test('Apply writes edited text atomically and preserves source metadata',
      () async {
    final ids = await seed();
    final before = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    final after = await editor.apply(
      baseline: before, cueNumber: 1, editedText: 'Desktop edit');
    expect(after, isNotNull);
    expect(after!.cues.first.edited, 'Desktop edit');
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines[0].original, 'Original\nretained');
    expect(stored.lines[0].edited, 'Desktop edit');
    expect(stored.lines[0].comment, 'Existing note');
    expect(stored.lines[0].marked, true);
    expect(stored.lines[0].startTime, '00:00:01,000');
    expect(stored.lines[1].original, '');
    expect(stored.lines[1].edited, '');
    expect(await db.isar.checkpoints.count(), greaterThanOrEqualTo(2));

    final next = await editor.apply(
      baseline: after, cueNumber: 1, editedText: 'Next change');
    expect(next!.cues.first.edited, 'Next change');
  });

  test('Unchanged nullable edited text never creates a history commit',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    final same = await editor.apply(
      baseline: baseline, cueNumber: 1, editedText: '');
    expect(same, same);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines[0].edited, isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('Stale edits are rejected rather than overwriting newer changes',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);

    final first = await editor.apply(
      baseline: baseline, cueNumber: 1, editedText: 'First writer');
    expect(first, isNotNull);
    final stale = await editor.apply(
      baseline: baseline, cueNumber: 1, editedText: 'Stale writer');
    expect(stale, isNull);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines.first.edited, 'First writer');
  });

  test('Changing review metadata invalidates an old desktop edit baseline',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines[0].comment = 'Newer comment';
      await db.isar.subtitleCollections.put(collection);
    });
    final stale = await editor.apply(
      baseline: baseline, cueNumber: 1, editedText: 'Must be rejected');
    expect(stale, isNull);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines.first.edited, null);
  });

  test('Rejects edits to non-owned, missing or invalid cue IDs',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await editor.apply(
      baseline: baseline, cueNumber: 99, editedText: 'No'), isNull);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.delete(ids.sessionId);
    });
    expect(await editor.apply(
      baseline: baseline, cueNumber: 1, editedText: 'No'), isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });
}
