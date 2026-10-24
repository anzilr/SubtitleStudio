import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_history_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_cue_structure_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockSessionLoader loader;
  late StudioDockHistoryService history;
  late StudioDockTextEditService editor;
  late StudioDockCueStructureService structure;
  late int sessionId;
  late int collectionId;

  setUp(() async {
    db = await TestIsarHarness.open();
    final projects = ProjectRepository(db.isar);
    final checkpoints = CheckpointRepository(db.isar);
    final subtitles = SubtitleRepository(db.isar, checkpoints);
    loader = StudioDockSessionLoader(projects, subtitles);
    history = StudioDockHistoryService(loader, checkpoints);
    editor = StudioDockTextEditService(projects, subtitles);
    structure = StudioDockCueStructureService(projects, subtitles);

    final collection = SubtitleCollection(
      fileName: 'History.srt', encoding: 'UTF-8',
      lines: [
        SubtitleLine()
          ..index = 1
          ..startTime = '00:00:01,000'
          ..endTime = '00:00:02,000'
          ..original = 'Source'
          ..edited = null
          ..comment = 'Review note'
          ..marked = true,
      ],
    );
    await db.isar.writeTxn(() async {
      await db.isar.subtitleCollections.put(collection);
    });
    collectionId = collection.id;
    final session = Session(
      fileName: 'History.srt', subtitleCollectionId: collectionId);
    await db.isar.writeTxn(() async {
      await db.isar.sessions.put(session);
    });
    sessionId = session.id;
  });
  tearDown(() async => db.close());

  test('Undo and Redo restore exact persisted cues without losing history',
      () async {
    final initial = await loader.load(
      sessionId: sessionId, collectionId: collectionId);
    final edited = await editor.apply(
      baseline: initial, cueNumber: 1, editedText: 'New translation');
    expect(edited, isNotNull);
    final beforeGraph = await history.load(sessionId);
    final head = beforeGraph.headCheckpointId!;
    final parent = beforeGraph.nodes.firstWhere(
      (node) => node.checkpointId == head).parentCheckpointId!;
    final checkpointCount = await db.isar.checkpoints.count();

    final undone = await history.checkout(
      baseline: edited!, expectedHeadId: head, targetCheckpointId: parent);
    expect(undone, isNotNull);
    expect(undone!.snapshot.cues.single.storedEdited, isNull);
    expect(undone.snapshot.cues.single.comment, 'Review note');
    expect(undone.snapshot.cues.single.marked, isTrue);
    expect(undone.graph.headCheckpointId, parent);
    expect(undone.graph.nodes.firstWhere((n) => n.checkpointId == parent)
        .childCheckpointIds, contains(head));

    final redone = await history.checkout(
      baseline: undone.snapshot, expectedHeadId: parent,
      targetCheckpointId: head);
    expect(redone!.snapshot.cues.single.edited, 'New translation');
    expect(redone.graph.headCheckpointId, head);
    expect(await db.isar.checkpoints.count(), checkpointCount);
  });

  test('Rejects a stale HEAD or stale cue metadata before checkout', () async {
    final initial = await loader.load(
      sessionId: sessionId, collectionId: collectionId);
    final edited = (await editor.apply(
      baseline: initial, cueNumber: 1, editedText: 'Committed'))!;
    final graph = await history.load(sessionId);
    final head = graph.headCheckpointId!;
    final parent = graph.nodes.firstWhere(
        (node) => node.checkpointId == head).parentCheckpointId!;

    expect(await history.checkout(
      baseline: initial, expectedHeadId: head,
      targetCheckpointId: parent), isNull);
    expect(await history.checkout(
      baseline: edited, expectedHeadId: parent,
      targetCheckpointId: head), isNull);
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(collectionId))!;
      collection.lines.first.comment = 'Changed in another window';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await history.checkout(
      baseline: edited, expectedHeadId: head,
      targetCheckpointId: parent), isNull);
    expect((await db.isar.subtitleCollections.get(collectionId))!
        .lines.single.edited, 'Committed');
    expect((await history.load(sessionId)).headCheckpointId, head);
  });

  test('History restores structural edits and preserves alternate redo paths',
      () async {
    final initial = await loader.load(
      sessionId: sessionId, collectionId: collectionId);
    final inserted = await structure.insert(
      baseline: initial, afterCueNumber: 1,
      start: '00:00:03,000', end: '00:00:04,000',
      original: 'Another source', edited: 'Another edit');
    expect(inserted, isNotNull);
    final insertedGraph = await history.load(sessionId);
    final insertHead = insertedGraph.headCheckpointId!;
    final parent = insertedGraph.nodes.firstWhere(
        (node) => node.checkpointId == insertHead).parentCheckpointId!;

    final undone = (await history.checkout(
      baseline: inserted!.snapshot, expectedHeadId: insertHead,
      targetCheckpointId: parent))!;
    expect(undone.snapshot.cues.length, 1);
    final alternate = (await editor.apply(
      baseline: undone.snapshot, cueNumber: 1,
      editedText: 'Alternate edit'))!;
    final alternateHead = (await history.load(sessionId)).headCheckpointId!;
    final atFork = (await history.checkout(
      baseline: alternate, expectedHeadId: alternateHead,
      targetCheckpointId: parent))!;
    final choices = atFork.graph.nodes.firstWhere(
        (node) => node.checkpointId == parent).childCheckpointIds;
    expect(choices, containsAll([insertHead, alternateHead]));

    final chosen = (await history.checkout(
      baseline: atFork.snapshot, expectedHeadId: parent,
      targetCheckpointId: insertHead))!;
    expect(chosen.snapshot.cues.length, 2);
    expect(chosen.snapshot.cues.last.original, 'Another source');
    expect(chosen.snapshot.cues.first.comment, 'Review note');
  });
}
