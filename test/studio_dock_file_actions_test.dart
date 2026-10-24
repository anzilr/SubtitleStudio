import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_text_edit_service.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/services/editor_direct_save_service.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness db;
  late ProjectRepository projects;
  late SubtitleRepository subtitles;
  late StudioDockFileActions actions;
  late Directory temp;

  setUp(() async {
    db = await TestIsarHarness.open();
    projects = ProjectRepository(db.isar);
    subtitles = SubtitleRepository(db.isar, CheckpointRepository(db.isar));
    // Common file I/O tests are platform-neutral. Security-scoped bookmarks
    // have their own injected macOS cases below, not native plugin calls in
    // a headless Flutter test runner.
    actions = StudioDockFileActions(projects, subtitles,
      isMacOS: false, directSave: EditorDirectSaveService(isMacOS: false));
    temp = await Directory.systemTemp.createTemp('studio_dock_file_');
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<({int sessionId, int collectionId})> seed({
    String? sourcePath,
    String encoding = 'UTF-8',
  }) async {
    final collection = SubtitleCollection(
      fileName: 'Desktop.srt',
      encoding: encoding,
      originalFileUri: sourcePath,
      filePath: sourcePath,
      lines: [
        SubtitleLine()
          ..index = 1
          ..startTime = '00:00:01,000'
          ..endTime = '00:00:02,000'
          ..original = 'Original first\n'
          ..edited = ''
          ..marked = true
          ..comment = 'Review note'
          ..resolved = false,
        SubtitleLine()
          ..index = 2
          ..startTime = '00:00:03,000'
          ..endTime = '00:00:04,000'
          ..original = 'Original second'
          ..edited = 'Translated second'
          ..marked = false
          ..comment = null
          ..resolved = false,
      ],
    );
    await db.isar.writeTxn(() async =>
        db.isar.subtitleCollections.put(collection));
    final session = Session(
      fileName: 'Desktop.srt', subtitleCollectionId: collection.id);
    await db.isar.writeTxn(() async => db.isar.sessions.put(session));
    return (sessionId: session.id, collectionId: collection.id);
  }

  test('Save As is encoded, linked, and subsequent direct Save works',
      () async {
    final ids = await seed();
    final prepared = await actions.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    expect(prepared, isNotNull);
    expect(prepared!.plan.fileName, 'Desktop.srt');
    final path = '${temp.path}/Renamed.srt';
    expect(await actions.writeToPath(prepared: prepared, selectedPath: path),
      StudioDockFileResult.saved);
    expect(await File(path).exists(), isTrue);
    final bytes = await File(path).readAsBytes();
    final text = utf8.decode(bytes);
    expect(text, contains('Translated second'));
    expect(text, isNot(contains('Review note')));
    final collection =
        (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(collection.originalFileUri, path);
    expect(collection.filePath, path);
    expect(collection.lines.first.edited, isEmpty);
    expect(collection.lines.first.original, 'Original first\n');
    expect(collection.lines.first.comment, 'Review note');

    expect(await actions.saveExisting(
      sessionId: ids.sessionId, collectionId: ids.collectionId),
      StudioDockFileResult.saved);
    expect(await File(path).readAsBytes(), bytes);
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('Export original/edited is non-mutating and preserves blank edits',
      () async {
    final ids = await seed();
    final original = await actions.prepareExport(
      sessionId: ids.sessionId, collectionId: ids.collectionId,
      originalOnly: true);
    final edited = await actions.prepareExport(
      sessionId: ids.sessionId, collectionId: ids.collectionId,
      originalOnly: false);
    expect(original!.plan.fileName, 'Desktop.original.srt');
    expect(edited!.plan.fileName, 'Desktop.MSone.srt');
    final originalPath = '${temp.path}/Source.srt';
    final editedPath = '${temp.path}/Edited.srt';
    expect(await actions.writeToPath(
      prepared: original, selectedPath: originalPath),
      StudioDockFileResult.saved);
    expect(await actions.writeToPath(
      prepared: edited, selectedPath: editedPath),
      StudioDockFileResult.saved);
    expect(await File(originalPath).readAsString(),
      contains('Original first'));
    expect(await File(originalPath).readAsString(),
      contains('Original second'));
    expect(await File(editedPath).readAsString(),
      contains('Translated second'));
    expect(await File(editedPath).readAsString(),
      isNot(contains('Original first')));
    final collection =
        (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(collection.originalFileUri, isNull);
    expect(collection.filePath, isNull);
    expect(await db.isar.checkpoints.count(), 0);
  });

  test('Overwrite is refused until explicitly approved', () async {
    final ids = await seed();
    final prepared = (await actions.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    final target = File('${temp.path}/Existing.srt');
    await target.writeAsString('Keep this');
    expect(await actions.writeToPath(
      prepared: prepared, selectedPath: target.path),
      StudioDockFileResult.alreadyExists);
    expect(await target.readAsString(), 'Keep this');
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .originalFileUri, isNull);
    expect(await actions.writeToPath(
      prepared: prepared, selectedPath: target.path,
      replaceExisting: true), StudioDockFileResult.saved);
    expect(await target.readAsString(), contains('Translated second'));
  });

  test('Stale timing/text/review state cannot overwrite an external file',
      () async {
    final ids = await seed();
    final prepared = (await actions.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    final baseline = await StudioDockSessionLoader(projects, subtitles).load(
      sessionId: ids.sessionId, collectionId: ids.collectionId);
    final changed = await StudioDockTextEditService(projects, subtitles).apply(
      baseline: baseline, cueNumber: 2, editedText: 'Newer edit');
    expect(changed, isNotNull);
    final path = '${temp.path}/ShouldNotExist.srt';
    expect(await actions.writeToPath(
      prepared: prepared, selectedPath: path),
      StudioDockFileResult.stale);
    expect(await File(path).exists(), isFalse);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .lines[1].edited, 'Newer edit');
  });

  test('Wrong session owner or changed output identity fails closed',
      () async {
    final ids = await seed();
    final prepared = (await actions.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    await db.isar.writeTxn(() async {
      final collection =
          (await db.isar.subtitleCollections.get(ids.collectionId))!;
      collection.originalFileUri = '/another/location.srt';
      await db.isar.subtitleCollections.put(collection);
    });
    expect(await actions.writeToPath(
      prepared: prepared, selectedPath: '${temp.path}/Wrong.srt'),
      StudioDockFileResult.stale);
    await db.isar.writeTxn(() async => db.isar.sessions.delete(ids.sessionId));
    expect(await actions.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId), isNull);
    expect(await actions.saveExisting(
      sessionId: ids.sessionId, collectionId: ids.collectionId),
      StudioDockFileResult.failed);
  });

  test('Rejected destination and unsupported encoding never write bytes',
      () async {
    final ids = await seed();
    final prepared = (await actions.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    expect(await actions.writeToPath(
      prepared: prepared, selectedPath: '${temp.path}/Wrong.txt'),
      StudioDockFileResult.failed);
    expect(await File('${temp.path}/Wrong.txt').exists(), isFalse);

    final wrongEncoding = await seed(encoding: 'UNRECOGNIZED-CHARSET');
    await expectLater(actions.prepareSaveAs(
      sessionId: wrongEncoding.sessionId,
      collectionId: wrongEncoding.collectionId),
      throwsA(anyOf(isA<FormatException>(), isA<UnsupportedError>())));
  });

  test('macOS missing bookmark saves bytes but does not link unsafe path',
      () async {
    final ids = await seed();
    final mac = StudioDockFileActions(
      projects, subtitles, isMacOS: true,
      createBookmark: (_) async => null);
    final prepared = (await mac.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    final path = '${temp.path}/Mac.srt';
    expect(await mac.writeToPath(prepared: prepared, selectedPath: path),
      StudioDockFileResult.savedButUnlinked);
    expect(await File(path).exists(), isTrue);
    expect((await db.isar.subtitleCollections.get(ids.collectionId))!
        .originalFileUri, isNull);

    final bookable = StudioDockFileActions(
      projects, subtitles, isMacOS: true,
      createBookmark: (_) async => Uint8List.fromList([1, 2, 3]));
    final prepared2 = (await bookable.prepareSaveAs(
      sessionId: ids.sessionId, collectionId: ids.collectionId))!;
    expect(await bookable.writeToPath(
      prepared: prepared2, selectedPath: '${temp.path}/MacLinked.srt'),
      StudioDockFileResult.saved);
    final linked =
        (await db.isar.subtitleCollections.get(ids.collectionId))!;
    expect(linked.macOsSrtBookmark, base64Encode([1, 2, 3]));
  });
}
