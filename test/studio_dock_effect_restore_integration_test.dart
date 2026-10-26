import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_effect_restore_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_history_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/operations/srt_effect_frames.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockEffectRestoreService restore;
  late StudioDockHistoryService history;
  late int sessionId;
  late int collectionId;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final checkpoints = CheckpointRepository(db.isar);
    final subtitles = SubtitleRepository(db.isar, checkpoints);
    loader = StudioDockSessionLoader(projects, subtitles);
    restore = StudioDockEffectRestoreService(projects, subtitles);
    history = StudioDockHistoryService(loader, checkpoints);

    final frames = SrtEffectFrames.build(effect: 'typewriterCursor',
        text: 'Hello', color: 'FFAA00', availableMilliseconds: 4000);
    final collection = SubtitleCollection(
      fileName: 'Effects.srt', encoding: 'UTF-8',
      lines: [
        for (var i = 0; i < frames.length; i++)
          SubtitleLine()
            ..index = i + 1
            ..startTime = '00:00:0${i + 1},000'
            ..endTime = '00:00:0${i + 2},000'
            ..original = 'Original source'
            ..edited = frames[i]
            ..marked = i == 1
            ..comment = i == 1 ? 'Review this' : null,
        SubtitleLine()
          ..index = frames.length + 1
          ..startTime = '00:00:07,000'
          ..endTime = '00:00:08,000'
          ..original = 'Next line',
      ],
    );
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    collectionId = collection.id;
    final session = Session(
      fileName: 'Effects.srt', subtitleCollectionId: collectionId);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    sessionId = session.id;
  });
  tearDown(() async => db.close());

  test('restore removes effect atomically and Undo brings every frame back',
      () async {
    final before = await loader.load(
        sessionId: sessionId, collectionId: collectionId);
    final restored = await restore.restore(
        baseline: before, firstCueId: 1, expectedFrameCount: 5);
    expect(restored, isNotNull);
    expect(restored!.cues, hasLength(2));
    expect(restored.cues.first.edited, 'Hello');
    expect(restored.cues.first.original, 'Original source');
    expect(restored.cues.first.start, before.cues.first.start);
    expect(restored.cues.first.end, before.cues[4].end);
    expect(restored.cues.first.marked, isTrue);
    expect(restored.cues.first.comment, 'Review this');
    expect(restored.cues.last.index, 2);
    expect(restored.cues.last.original, 'Next line');

    final graph = await history.load(sessionId);
    final head = graph.headCheckpointId!;
    final parent = graph.nodes.firstWhere(
        (node) => node.checkpointId == head).parentCheckpointId!;
    final undone = await history.checkout(
      baseline: restored, expectedHeadId: head, targetCheckpointId: parent);
    expect(undone, isNotNull);
    expect(undone!.snapshot.cues, hasLength(before.cues.length));
    expect(undone.snapshot.cues[1].comment, 'Review this');
    expect(undone.snapshot.cues[1].marked, isTrue);
  });

  test('stale restore request cannot remove another editor’s changes', () async {
    final before = await loader.load(
        sessionId: sessionId, collectionId: collectionId);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(collectionId))!;
      collection.lines[2].comment = 'New annotation from other window';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await restore.restore(
      baseline: before, firstCueId: 1, expectedFrameCount: 5,
    ), isNull);
    final after = await loader.load(
        sessionId: sessionId, collectionId: collectionId);
    expect(after.cues, hasLength(before.cues.length));
    expect(after.cues[2].comment, 'New annotation from other window');
  });
}
