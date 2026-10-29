import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_project_actions.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_project_save_actions.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/project_save_coordinator.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';

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

  test('optional project save after SRT import preserves source and session',
      () async {
    const source = '1\n00:00:01,000 --> 00:00:02,000\nHello\n';
    final srtPath = '${temp.path}/Imported.srt';
    await File(srtPath).writeAsString(source);
    final importActions = StudioDockProjectActions(
      subtitleImporter: SubtitleImportRepository(db.isar),
      projectImporter: SessionProjectImportRepository(db.isar),
    );
    final imported = await importActions.importFile(srtPath);

    // The optional checkbox is off by default. Merely importing an SRT must
    // not create a second file or link an external project location.
    expect(await ProjectRepository(db.isar).getProjectFilePath(imported.id),
        isNull);
    expect(File('${temp.path}/Imported.msone').existsSync(), isFalse);
    expect(await File(srtPath).readAsString(), source);

    // When the user opts in, the same guarded Save As service produces the
    // complete portable document without replacing or modifying the SRT.
    final prepared = await projects.prepare(
      sessionId: imported.id,
      collectionId: imported.subtitleCollectionId,
    );
    expect(prepared?.fileName, 'Imported.msone');
    final projectPath = '${temp.path}/Imported.msone';
    expect(await projects.writeToPath(
      prepared: prepared!, selectedPath: projectPath,
    ), StudioDockFileResult.saved);
    final saved = ProjectDocumentCodec.decode(
        await File(projectPath).readAsString());
    expect(saved.subtitleCollection.lines.single.original, 'Hello');
    expect(saved.subtitleCollection.filePath, srtPath);
    expect(await ProjectRepository(db.isar).getProjectFilePath(imported.id),
        projectPath);
    expect(await db.isar.sessions.count(), 1);
    expect(await File(srtPath).readAsString(), source);
  });

  test('new Edit Mode project saves both files and reopens edited content',
      () async {
    final imports = StudioDockProjectActions(
      subtitleImporter: SubtitleImportRepository(db.isar),
      projectImporter: SessionProjectImportRepository(db.isar),
    );
    final created = await imports.createEmpty('Fresh scene',
        encoding: 'ISO-8859-1');
    final savedSrt = '${temp.path}/Fresh scene.srt';
    final savedProject = '${temp.path}/Fresh scene.msone';
    final subtitles = SubtitleRepository(
        db.isar, CheckpointRepository(db.isar));
    final files = StudioDockFileActions(ProjectRepository(db.isar), subtitles);

    final initial = await files.prepareSaveAs(
      sessionId: created.id, collectionId: created.subtitleCollectionId);
    expect(initial, isNotNull);
    expect(await files.writeToPath(
      prepared: initial!, selectedPath: savedSrt,
    ), StudioDockFileResult.saved);
    expect(await File(savedSrt).readAsString(), isEmpty);

    final preparedProject = await projects.prepare(
      sessionId: created.id, collectionId: created.subtitleCollectionId);
    expect(preparedProject, isNotNull);
    expect(await projects.writeToPath(
      prepared: preparedProject!, selectedPath: savedProject,
    ), StudioDockFileResult.saved);
    final initialDocument = ProjectDocumentCodec.decode(
        await File(savedProject).readAsString());
    expect(initialDocument.subtitleCollection.encoding, 'ISO-8859-1');
    expect(initialDocument.subtitleCollection.filePath, savedSrt);
    expect(initialDocument.subtitleCollection.lines, isEmpty);

    // Simulate the first Edit Mode subtitle and save both linked documents.
    await db.isar.writeTxn(() async {
      final collection = (await db.isar.subtitleCollections.get(
          created.subtitleCollectionId))!;
      collection.lines.add(SubtitleLine()
        ..index = 1
        ..startTime = '00:00:01,000'
        ..endTime = '00:00:02,000'
        ..original = ''
        ..edited = 'Cafe');
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await files.saveExisting(
      sessionId: created.id, collectionId: created.subtitleCollectionId,
    ), StudioDockFileResult.saved);
    expect(await projects.saveExisting(
      sessionId: created.id, collectionId: created.subtitleCollectionId,
    ), StudioDockFileResult.saved);
    expect(await File(savedSrt).readAsString(), contains('Cafe'));
    final reloaded = ProjectDocumentCodec.decode(
        await File(savedProject).readAsString());
    expect(reloaded.subtitleCollection.lines.single.edited, 'Cafe');
    expect(await ProjectRepository(db.isar).getProjectFilePath(created.id),
        savedProject);
    expect(await db.isar.sessions.count(), 1);
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
