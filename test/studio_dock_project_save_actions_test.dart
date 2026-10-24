import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_project_save_actions.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/project_save_coordinator.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late StudioDockProjectSaveActions projects;
  late Directory temp;

  setUp(() async {
    db = await TestIsarHarness.open();
    projects = StudioDockProjectSaveActions(
      ProjectRepository(db.isar),
      SubtitleRepository(db.isar, CheckpointRepository(db.isar)),
      ProjectSaveCoordinator(CheckpointRepository(db.isar)),
    );
    temp = await Directory.systemTemp.createTemp('studio_dock_msone_');
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<({int sessionId, int collectionId, int checkpointId})> seed() async {
    final collection = SubtitleCollection(
      fileName: 'Scene.srt',
      encoding: 'UTF-8',
      lines: [
        SubtitleLine()
          ..index = 1
          ..startTime = '00:00:01,000'
          ..endTime = '00:00:02,000'
          ..original = 'Original'
          ..edited = 'Translation'
          ..marked = true
          ..comment = 'Keep this note'
          ..resolved = false,
      ],
    );
    await db.isar.writeTxn(() async =>
        db.isar.subtitleCollections.put(collection));
    final session = Session(
      fileName: 'Scene.srt', subtitleCollectionId: collection.id);
    await db.isar.writeTxn(() async => db.isar.sessions.put(session));
    final checkpoint = Checkpoint(
      sessionId: session.id,
      subtitleCollectionId: collection.id,
      timestamp: DateTime.utc(2026, 10, 24),
      operationType: 'snapshot',
      description: 'Scene first checkpoint',
      isActive: true,
      checkpointType: 'snapshot',
      snapshot: collection.lines,
      deltas: const [],
    );
    await db.isar.writeTxn(() async => db.isar.checkpoints.put(checkpoint));
    return (sessionId: session.id, collectionId: collection.id,
        checkpointId: checkpoint.id);
  }

  test('Save As stores complete .msone history and relinks session', () async {
    final ids = await seed();
    final prepared = await projects.prepare(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(prepared, isNotNull);
    expect(prepared!.fileName, 'Scene.msone');
    final path = '${temp.path}/Saved.msone';
    expect(await projects.writeToPath(prepared: prepared, selectedPath: path),
        StudioDockFileResult.saved);
    final encoded = await File(path).readAsString();
    final restored = ProjectDocumentCodec.decode(encoded);
    expect(restored.subtitleCollection.lines.single.edited, 'Translation');
    expect(restored.subtitleCollection.lines.single.comment, 'Keep this note');
    expect(restored.checkpoints.single.id, ids.checkpointId);
    expect(restored.checkpoints.single.description, 'Scene first checkpoint');
    expect(restored.historyReferences!.entries.map((ref) => ref.name),
        containsAll(['HEAD', 'refs/heads/main']));
    expect(await ProjectRepository(db.isar).getProjectFilePath(ids.sessionId),
        path);

    // After a stored edit, direct project Save updates the linked document.
    await db.isar.writeTxn(() async {
      final c = (await db.isar.subtitleCollections.get(ids.collectionId))!;
      c.lines.first.comment = 'Changed note';
      await db.isar.subtitleCollections.put(c);
    });
    expect(await projects.saveExisting(
      sessionId: ids.sessionId, collectionId: ids.collectionId),
      StudioDockFileResult.saved);
    expect(ProjectDocumentCodec.decode(await File(path).readAsString())
        .subtitleCollection.lines.single.comment, 'Changed note');
  });

  test('Save with no linked .msone requests Save As', () async {
    final ids = await seed();
    expect(await projects.saveExisting(
      sessionId: ids.sessionId, collectionId: ids.collectionId),
      StudioDockFileResult.needsLocation);
  });

  test('Save As refuses replacement without explicit authorization', () async {
    final ids = await seed();
    final prepared = (await projects.prepare(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    final path = '${temp.path}/Existing.msone';
    await File(path).writeAsString('untouched');
    expect(await projects.writeToPath(prepared: prepared, selectedPath: path),
      StudioDockFileResult.alreadyExists);
    expect(await File(path).readAsString(), 'untouched');
    expect(await ProjectRepository(db.isar).getProjectFilePath(ids.sessionId),
      isNull);
    expect(await projects.writeToPath(
      prepared: prepared, selectedPath: path, replaceExisting: true),
      StudioDockFileResult.saved);
    expect(ProjectDocumentCodec.decode(await File(path).readAsString())
      .checkpoints, hasLength(1));
  });

  test('Changed cues or changed history invalidate open Save As picker',
      () async {
    final ids = await seed();
    final staleText = (await projects.prepare(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    await db.isar.writeTxn(() async {
      final c = (await db.isar.subtitleCollections.get(ids.collectionId))!;
      c.lines.first.edited = 'New translation';
      await db.isar.subtitleCollections.put(c);
    });
    final path = '${temp.path}/Stale.msone';
    expect(await projects.writeToPath(
      prepared: staleText, selectedPath: path), StudioDockFileResult.stale);
    expect(await File(path).exists(), isFalse);

    final staleHistory = (await projects.prepare(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    await db.isar.writeTxn(() async {
      final cp = (await db.isar.checkpoints.get(ids.checkpointId))!;
      cp.description = 'Updated checkpoint note';
      await db.isar.checkpoints.put(cp);
    });
    expect(await projects.writeToPath(
      prepared: staleHistory, selectedPath: path), StudioDockFileResult.stale);
    expect(await File(path).exists(), isFalse);
  });

  test('Changed project locator or owner is never overwritten', () async {
    final ids = await seed();
    final prepared = (await projects.prepare(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    await ProjectRepository(db.isar).updateSessionProjectPath(
      sessionId: ids.sessionId,
      projectFilePath: '${temp.path}/Different.msone');
    expect(await projects.writeToPath(
      prepared: prepared, selectedPath: '${temp.path}/Old.msone'),
      StudioDockFileResult.stale);
    await db.isar.writeTxn(() async => db.isar.sessions.delete(ids.sessionId));
    expect(await projects.prepare(
      sessionId: ids.sessionId, collectionId: ids.collectionId), isNull);
    expect(await File('${temp.path}/Old.msone').exists(), isFalse);
  });

  test('Invalid destination does not create a project or mutate metadata',
      () async {
    final ids = await seed();
    final prepared = (await projects.prepare(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    expect(await projects.writeToPath(
      prepared: prepared, selectedPath: '${temp.path}/Wrong.srt'),
      StudioDockFileResult.failed);
    expect(await File('${temp.path}/Wrong.srt').exists(), isFalse);
    expect(await ProjectRepository(db.isar).getProjectFilePath(ids.sessionId),
      isNull);
  });
}
