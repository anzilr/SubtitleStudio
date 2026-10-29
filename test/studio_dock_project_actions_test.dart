import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_project_actions.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/widgets/session_selection/project_history_import_plan.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';

import 'support/test_isar_harness.dart';

ProjectDocument _portableDocument({
  String? sourcePath,
  bool invalidHistory = false,
}) => ProjectDocument.create(
  version: '2.0',
  session: ProjectSessionData.create(
    fileName: 'archive.srt', lastEditedIndex: 1,
    editMode: false, projectFilePath: null,
  ),
  subtitleCollection: ProjectSubtitleCollectionData.create(
    fileName: 'archive.srt', filePath: sourcePath,
    originalFileUri: sourcePath, encoding: 'UTF-8',
    lines: [ProjectSubtitleLineData.create(
      index: 1, startTime: '00:00:01,000', endTime: '00:00:02,000',
      original: 'Imported text', edited: 'Edited text',
      marked: true, comment: 'Review this', resolved: false,
    )],
  ),
  checkpoints: [ProjectCheckpointData.create(
    id: 123, sessionId: 9, subtitleCollectionId: 12,
    timestamp: DateTime.utc(2026, 10, 27).toIso8601String(),
    operationType: 'snapshot', description: 'Archive start',
    parentCheckpointId: invalidHistory ? 999 : null,
    isActive: true, checkpointType: 'snapshot',
    metadata: null, deltas: const [],
    snapshot: [ProjectSubtitleLineData.create(
      index: 1, startTime: '00:00:01,000', endTime: '00:00:02,000',
      original: 'Imported text', edited: 'Edited text', marked: true,
      comment: null, resolved: false,
    )],
  )],
  metadata: ProjectMetadataData.create(
    totalLines: 1, editedLines: 1, markedLines: 1,
    lastSaved: DateTime.utc(2026, 10, 27).toIso8601String(),
  ),
);

void main() {
  late TestIsarHarness harness;
  late StudioDockProjectActions actions;

  setUp(() async {
    harness = await TestIsarHarness.open();
    actions = StudioDockProjectActions(
      subtitleImporter: SubtitleImportRepository(harness.isar),
      projectImporter: SessionProjectImportRepository(harness.isar),
    );
  });
  tearDown(() async => harness.close());

  test('desktop import preserves blank SRT lines, encoding and session storage',
      () async {
    final file = File('${harness.directory.path}/test.srt');
    await file.writeAsString(
      '1\n00:00:01,000 --> 00:00:02,000\nOriginal\n\n'
      '2\n00:00:03,000 --> 00:00:04,000\n\n\n'
      '3\n00:00:05,000 --> 00:00:06,000\nAfter\n');
    final session = await actions.importFile(file.path);
    final stored =
        await harness.isar.subtitleCollections.get(session.subtitleCollectionId);
    expect(stored, isNotNull);
    expect(stored!.filePath, file.path);
    expect(stored.encoding, 'UTF-8');
    expect(stored.lines, hasLength(3));
    expect(stored.lines[1].original, isEmpty);
    expect(stored.lines[1].edited, isNull);
    expect(await harness.isar.sessions.count(), 1);
  });

  test('explicit desktop charset override decodes exactly the previewed SRT',
      () async {
    final file = File('${harness.directory.path}/legacy.srt');
    await file.writeAsBytes([
      ...'1\n00:00:01,000 --> 00:00:02,000\nIt'.codeUnits,
      0x92, ...'s ready\n'.codeUnits,
    ]);
    await expectLater(actions.importFile(file.path), throwsFormatException);
    expect(await harness.isar.sessions.count(), 0);
    final session = await actions.importFile(file.path,
        selectedEncoding: 'Windows-1252');
    final stored = await harness.isar.subtitleCollections.get(
        session.subtitleCollectionId);
    expect(stored!.encoding, 'Windows-1252');
    expect(stored.lines.single.original, 'It\u2019s ready');
    expect(await harness.isar.sessions.count(), 1);
  });

  test('desktop import transformations are opt-in and do not edit the SRT',
      () async {
    final file = File('${harness.directory.path}/cleanup.srt');
    const source = '1\n00:00:01,000 --> 00:00:02,000\n'
        '[music playing] Hello\n\n'
        '2\n00:00:01,000 --> 00:00:02,000\nWorld\n';
    await file.writeAsString(source);

    final untouched = await actions.importFile(file.path);
    final before = await harness.isar.subtitleCollections.get(
        untouched.subtitleCollectionId);
    expect(before!.lines, hasLength(2));
    expect(before.lines.first.original, contains('[music playing]'));

    final cleaned = await actions.importFile(file.path,
        removeHearingImpaired: true, mergeOverlapping: true);
    final after = await harness.isar.subtitleCollections.get(
        cleaned.subtitleCollectionId);
    expect(after!.lines, hasLength(1));
    expect(after.lines.single.original, contains('Hello'));
    expect(after.lines.single.original, contains('World'));
    expect(after.lines.single.original, isNot(contains('[music playing]')));
    expect(await file.readAsString(), source,
        reason: 'Import cleanup must never rewrite the original file.');
  });

  test('VTT/ASS/SSA import is blocked before creating a writable project', () async {
    for (final extension in ['vtt', 'ass', 'ssa']) {
      final file = File('${harness.directory.path}/test.$extension');
      await file.writeAsString('Do not overwrite this source');
      await expectLater(actions.importFile(file.path), throwsFormatException);
      expect(await file.readAsString(), 'Do not overwrite this source');
    }
    expect(await harness.isar.sessions.count(), 0);
  });

  test('empty new project is persisted only after explicit creation', () async {
    expect(await harness.isar.sessions.count(), 0);
    await expectLater(actions.createEmpty('  '), throwsFormatException);
    expect(await harness.isar.sessions.count(), 0);
    final session = await actions.createEmpty('New desktop');
    expect(session.fileName, 'New desktop.srt');
    expect(session.editMode, isTrue);
    final collection =
        await harness.isar.subtitleCollections.get(session.subtitleCollectionId);
    expect(collection!.lines, isEmpty);
    expect(collection.filePath, isEmpty);
  });

  test('invalid or missing imports never create sessions', () async {
    await expectLater(
      actions.importFile('${harness.directory.path}/missing.srt'),
      throwsA(isA<FileSystemException>()));
    final unsupported = File('${harness.directory.path}/bad.txt');
    await unsupported.writeAsString('not a subtitle');
    await expectLater(actions.importFile(unsupported.path),
        throwsFormatException);
    expect(await harness.isar.sessions.count(), 0);
  });

  test('portable project import requires explicit review, then can stay unlinked',
      () async {
    final path = '${harness.directory.path}/portable.msone';
    final file = File(path);
    final document = _portableDocument(sourcePath: '/other/pc/archive.srt');
    await file.writeAsString(ProjectDocumentCodec.encode(document));
    await expectLater(actions.importFile(path), throwsFormatException);
    expect(await actions.readProjectDocument(path), isA<ProjectDocument>());
    expect(await StudioDockProjectActions.isUsableSrtPath(
        StudioDockProjectActions.archivedSrtPath(document)), isFalse);
    expect(await harness.isar.sessions.count(), 0);

    final session = await actions.importProject(
      archivePath: path,
      document: document,
      plan: const StudioDockProjectImportPlan(
        source: StudioDockProjectSrtSource.unlinked,
      ),
    );
    final collection = await harness.isar.subtitleCollections.get(
      session.subtitleCollectionId);
    expect(collection!.filePath, isNull);
    expect(collection.originalFileUri, isNull);
    expect(collection.lines.single.edited, 'Edited text');
    expect(collection.lines.single.marked, isTrue);
    expect(session.projectFilePath, path);
    expect(session.lastEditedIndex, 1);
    expect(session.editMode, isFalse);
    expect(await harness.isar.checkpoints.count(), 1);
  });

  test('project import can use located SRT without overwriting it', () async {
    final archive = File('${harness.directory.path}/located.msone');
    await archive.writeAsString('archive');
    final srt = File('${harness.directory.path}/located.srt');
    const contents = '1\n00:00:01,000 --> 00:00:02,000\nOriginal\n';
    await srt.writeAsString(contents);
    final session = await actions.importProject(
      archivePath: archive.path,
      document: _portableDocument(),
      plan: StudioDockProjectImportPlan(
        source: StudioDockProjectSrtSource.locatedFile,
        locatedSrtPath: srt.path,
      ),
    );
    final collection = await harness.isar.subtitleCollections.get(
      session.subtitleCollectionId);
    expect(collection!.filePath, srt.path);
    expect(collection.originalFileUri, srt.path);
    expect(collection.fileName, 'located.srt');
    expect(await srt.readAsString(), contents);
  });

  test('replacing a project retains its SRT and imports history in one transaction',
      () async {
    final originalSrt = File('${harness.directory.path}/original.srt');
    const srtSource = '1\n00:00:01,000 --> 00:00:02,000\nOriginal\n';
    await originalSrt.writeAsString(srtSource);
    final previous = await actions.importFile(originalSrt.path);
    final archive = File('${harness.directory.path}/replace.msone');
    await archive.writeAsString('archive');
    final targets = await actions.importTargets();
    expect(targets.single.session.id, previous.id);
    expect(targets.single.srtPath, originalSrt.path);

    final updated = await actions.importProject(
      archivePath: archive.path,
      document: _portableDocument(),
      plan: StudioDockProjectImportPlan(
        source: StudioDockProjectSrtSource.existingSession,
        replaceSessionId: previous.id,
      ),
    );
    expect(updated.id, previous.id);
    expect(updated.lastEditedIndex, 1);
    final collection = await harness.isar.subtitleCollections.get(
      previous.subtitleCollectionId);
    expect(collection!.filePath, originalSrt.path);
    expect(collection.lines.single.original, 'Imported text');
    expect(await harness.isar.sessions.count(), 1);
    expect(await harness.isar.checkpoints.count(), 1);
    expect(await originalSrt.readAsString(), srtSource);
  });

  test('failed history replacement is atomic and subtitle-only recovery explicit',
      () async {
    final srt = File('${harness.directory.path}/before.srt');
    await srt.writeAsString('1\n00:00:01,000 --> 00:00:02,000\nBefore\n');
    final previous = await actions.importFile(srt.path);
    final archive = File('${harness.directory.path}/broken.msone');
    await archive.writeAsString('archive');
    final plan = StudioDockProjectImportPlan(
      source: StudioDockProjectSrtSource.existingSession,
      replaceSessionId: previous.id,
    );
    final document = _portableDocument(invalidHistory: true);

    await expectLater(actions.importProject(
      archivePath: archive.path, document: document, plan: plan,
    ), throwsA(isA<ProjectHistoryImportException>()));
    final unchanged = await harness.isar.subtitleCollections.get(
      previous.subtitleCollectionId);
    expect(unchanged!.lines.single.original, 'Before');
    expect(await harness.isar.checkpoints.count(), 0);

    await actions.importProject(
      archivePath: archive.path, document: document, plan: plan,
      importSubtitlesOnly: true,
    );
    final recovered = await harness.isar.subtitleCollections.get(
      previous.subtitleCollectionId);
    expect(recovered!.lines.single.original, 'Imported text');
    expect(await harness.isar.checkpoints.count(), 0);
  });

  test('missing or non-SRT association cannot change existing project', () async {
    final srt = File('${harness.directory.path}/safe.srt');
    await srt.writeAsString('1\n00:00:01,000 --> 00:00:02,000\nSafe\n');
    final previous = await actions.importFile(srt.path);
    final archive = File('${harness.directory.path}/unsafe.msone');
    await archive.writeAsString('archive');
    for (final source in [StudioDockProjectSrtSource.archive,
      StudioDockProjectSrtSource.locatedFile]) {
      await expectLater(actions.importProject(
        archivePath: archive.path,
        document: _portableDocument(sourcePath: '/missing/source.srt'),
        plan: StudioDockProjectImportPlan(
          source: source, replaceSessionId: previous.id,
          locatedSrtPath: '${harness.directory.path}/not-subtitles.ass',
        ),
      ), throwsA(isA<FileSystemException>()));
    }
    final unchanged = await harness.isar.subtitleCollections.get(
      previous.subtitleCollectionId);
    expect(unchanged!.lines.single.original, 'Safe');
    expect(await harness.isar.sessions.count(), 1);
  });
}
