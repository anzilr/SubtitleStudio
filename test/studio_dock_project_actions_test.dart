import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_project_actions.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';

import 'support/test_isar_harness.dart';

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
}
