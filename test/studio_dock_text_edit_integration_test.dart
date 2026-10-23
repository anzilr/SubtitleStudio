import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_timing_edit_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_cue_structure_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockTextEditService editor;
  late StudioDockTimingEditService timing;
  late StudioDockCueStructureService structure;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final subtitles = SubtitleRepository(
      db.isar, CheckpointRepository(db.isar));
    loader = StudioDockSessionLoader(projects, subtitles);
    editor = StudioDockTextEditService(projects, subtitles);
    timing = StudioDockTimingEditService(projects, subtitles);
    structure = StudioDockCueStructureService(projects, subtitles);
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
    final result = await editor.apply(
      baseline: baseline, cueNumber: 1, editedText: '');
    expect(identical(result, baseline), isTrue);
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

  test('Timing Apply uses one checkpoint and preserves all other cue fields',
      () async {
    final ids = await seed();
    final before = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    final after = await timing.apply(
      baseline: before, cueNumber: 1,
      start: '00:00:01,250', end: '00:00:02,750');
    expect(after, isNotNull);
    expect(after!.cues.first.start, '00:00:01,250');
    expect(after.cues.first.end, '00:00:02,750');
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines[0].original, 'Original\nretained');
    expect(stored.lines[0].edited, isNull);
    expect(stored.lines[0].comment, 'Existing note');
    expect(stored.lines[0].marked, isTrue);
    expect(stored.lines[1].startTime, '00:00:03,000');
    final historyCount = await db.isar.checkpoints.count();
    expect(historyCount, greaterThanOrEqualTo(2));

    final unchanged = await timing.apply(
      baseline: after, cueNumber: 1,
      start: '00:00:01,250', end: '00:00:02,750');
    expect(identical(unchanged, after), isTrue);
    expect(await db.isar.checkpoints.count(), historyCount);
  });

  test('Invalid, stale and non-owned timing changes cannot write', () async {
    final ids = await seed();
    final before = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    for (final times in [
      ('00:00:02,000', '00:00:01,000'),
      ('00:00:01,000,000', '00:00:02,000'),
      ('00:70:01,000', '00:00:02,000'),
      ('00:00:01.000', '00:00:02,000'),
    ]) {
      expect(await timing.apply(
        baseline: before, cueNumber: 1,
        start: times.$1, end: times.$2), isNull);
    }
    expect(await db.isar.checkpoints.count(), 0);

    final changed = await timing.apply(
      baseline: before, cueNumber: 1,
      start: '00:00:01,100', end: '00:00:02,100');
    expect(changed, isNotNull);
    expect(await timing.apply(
      baseline: before, cueNumber: 1,
      start: '00:00:01,500', end: '00:00:02,500'), isNull);
    expect(await timing.apply(
      baseline: changed!, cueNumber: 999,
      start: '00:00:01,500', end: '00:00:02,500'), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines.first.startTime, '00:00:01,100');
  });

  test('Insert reindexes by time and preserves existing cue metadata',
      () async {
    final ids = await seed();
    final before = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    final result = await structure.insert(
      baseline: before,
      afterCueNumber: 1,
      start: '00:00:02,200', end: '00:00:02,800',
      original: 'Inserted source', edited: 'Inserted edit');
    expect(result, isNotNull);
    expect(result!.selectedCueNumber, 2);
    expect(result.snapshot.cues.map((c) => c.original).toList(), [
      'Original\nretained', 'Inserted source', '',
    ]);
    expect(result.snapshot.cues.map((c) => c.index).toList(), [1, 2, 3]);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines[0].comment, 'Existing note');
    expect(stored.lines[0].marked, isTrue);
    expect(stored.lines[0].edited, isNull);
    expect(stored.lines[1].edited, 'Inserted edit');
    expect(stored.lines[2].original, isEmpty);
    expect(await db.isar.checkpoints.count(), greaterThanOrEqualTo(2));

    final deleted = await structure.delete(
      baseline: result.snapshot, cueNumber: 2);
    expect(deleted, isNotNull);
    expect(deleted!.snapshot.cues.length, 2);
    expect(deleted.selectedCueNumber, 2);
    expect(deleted.snapshot.cues[1].original, isEmpty);
    expect(deleted.snapshot.cues.map((c) => c.index), [1, 2]);
  });

  test('Stale structural commands cannot shift or delete a newer cue',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    final updated = await editor.apply(
      baseline: baseline, cueNumber: 1, editedText: 'Newer text');
    expect(updated, isNotNull);

    expect(await structure.delete(
      baseline: baseline, cueNumber: 1), isNull);
    expect(await structure.insert(
      baseline: baseline, afterCueNumber: 1,
      start: '00:00:02,200', end: '00:00:02,800',
      original: 'Wrong placement', edited: ''), isNull);
    expect(await structure.delete(
      baseline: updated!, cueNumber: 99), isNull);
    expect(await structure.insert(
      baseline: updated, afterCueNumber: 99,
      start: '00:00:02,200', end: '00:00:02,800',
      original: 'Wrong anchor', edited: ''), isNull);
    final stored = (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(stored.lines.length, 2);
    expect(stored.lines.first.edited, 'Newer text');
  });

  test('Empty project can insert and delete its only cue with history',
      () async {
    final ids = await seed();
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.lines.clear();
      await db.isar.subtitleCollections.put(collection);
    });
    final empty = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(empty.cues, isEmpty);
    final added = await structure.insert(
      baseline: empty, afterCueNumber: null,
      start: '00:00:00,000', end: '00:00:02,000',
      original: '', edited: '');
    expect(added, isNotNull);
    expect(added!.selectedCueNumber, 1);
    expect(added.snapshot.cues.single.original, isEmpty);
    expect(added.snapshot.cues.single.storedEdited, isNull);

    final deleted = await structure.delete(
      baseline: added.snapshot, cueNumber: 1);
    expect(deleted, isNotNull);
    expect(deleted!.snapshot.cues, isEmpty);
    expect(deleted.selectedCueNumber, -1);
    expect(await db.isar.checkpoints.count(), greaterThanOrEqualTo(3));
  });

  test('Structural edits reject invalid times and foreign collection owner',
      () async {
    final ids = await seed();
    final baseline = await loader.load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(await structure.insert(
      baseline: baseline, afterCueNumber: 1,
      start: '00:00:04,000', end: '00:00:02,000',
      original: 'Invalid', edited: ''), isNull);

    await db.isar.writeTxn(() async {
      await db.isar.sessions.delete(ids.sessionId);
    });
    expect(await structure.delete(
      baseline: baseline, cueNumber: 1), isNull);
    expect(await structure.insert(
      baseline: baseline, afterCueNumber: 1,
      start: '00:00:02,200', end: '00:00:02,800',
      original: 'Foreign', edited: ''), isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });
}
