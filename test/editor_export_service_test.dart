import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/services/editor_export_service.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';

class _FakeExportFiles implements EditorExportFileOperations {
  final folders = <String>{};
  final files = <String, Uint8List>{};
  final writes = <String>[];

  @override
  Future<bool> directoryExists(String path) async => folders.contains(path);

  @override
  Future<bool> fileExists(String path) async => files.containsKey(path);

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    writes.add(path);
    files[path] = bytes;
  }
}

SubtitleLine _line({String original = 'Private original', String? edited}) =>
    SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = original
      ..edited = edited;

Future<EditorExportPlan> _plan(EditorExportService service, {
  String requestedName = 'scene.srt',
  String customTag = 'MSone',
  String encoding = 'UTF-8',
  bool originalOnly = false,
  String? edited,
}) => service.prepare(
      lines: [_line(edited: edited)],
      encoding: encoding,
      requestedName: requestedName,
      customTag: customTag,
      originalOnly: originalOnly,
    );

void main() {
  test('names use one SRT suffix and preserve existing MSone convention',
      () async {
    final service = EditorExportService();
    expect((await _plan(service, requestedName: 'scene.SRT')).fileName,
        'scene.MSone.srt');
    expect((await _plan(service, requestedName: 'scene.msone.SRT')).fileName,
        'scene.msone.srt');
    expect((await _plan(service, originalOnly: true)).fileName,
        'scene.original.srt');
    expect((await _plan(service, customTag: ' release ')).fileName,
        'scene.release.srt');
  });

  test('filename and custom tag cannot escape the chosen export folder',
      () async {
    final service = EditorExportService();
    for (final bad in ['../elsewhere', r'a\b', 'x:y', '', '  ', '.', '..']) {
      await expectLater(_plan(service, requestedName: bad),
          throwsA(isA<ArgumentError>()));
    }
    for (final badTag in ['../../other', r'a\b', 'x:y']) {
      await expectLater(_plan(service, customTag: badTag),
          throwsA(isA<ArgumentError>()));
    }
  });

  test('prepares exact UTF-16BE bytes retaining deliberately blank edit',
      () async {
    final plan = await _plan(EditorExportService(),
        encoding: 'UTF-16BE BOM', edited: '');
    expect(plan.fileName, 'scene.MSone.srt');
    final decoded = SubtitleTextCodec.decode(plan.bytes);
    expect(decoded.encoding, 'UTF-16BE BOM');
    expect(decoded.content, contains('00:00:02,000\n\n\n'));
    expect(decoded.content, isNot(contains('Private original')));
  });

  test('original-only export does not accidentally substitute edited text',
      () async {
    final plan = await _plan(EditorExportService(),
        originalOnly: true, edited: 'Changed');
    final text = SubtitleTextCodec.decode(plan.bytes).content;
    expect(plan.fileName, 'scene.original.srt');
    expect(text, contains('Private original'));
    expect(text, isNot(contains('Changed')));
  });

  test('unrepresentable text fails before any destination interaction',
      () async {
    final files = _FakeExportFiles()..folders.add('/safe');
    final service = EditorExportService(files: files, isWindows: false);
    await expectLater(_plan(service, encoding: 'Windows-1252',
        edited: 'മലയാളം'), throwsA(isA<FormatException>()));
    expect(files.writes, isEmpty);
    expect(files.files, isEmpty);
  });

  test('desktop create refuses collision, explicit Replace can overwrite',
      () async {
    final files = _FakeExportFiles()..folders.add('/safe');
    final service = EditorExportService(files: files, isWindows: false);
    final plan = await _plan(service, edited: 'New');
    const output = '/safe/scene.MSone.srt';
    files.files[output] = Uint8List.fromList([42]);
    expect(await service.writeDesktop(folder: '/safe', plan: plan),
        EditorExportWriteResult.alreadyExists);
    expect(files.files[output], [42]);
    expect(files.writes, isEmpty);
    expect(await service.writeDesktop(folder: '/safe', plan: plan,
        replaceExisting: true), EditorExportWriteResult.saved);
    expect(files.files[output], plan.bytes);
    expect(files.writes, [output]);
  });

  test('renaming to a second existing destination never overwrites it',
      () async {
    final files = _FakeExportFiles()..folders.add('/safe');
    final service = EditorExportService(files: files, isWindows: false);
    final plan = await _plan(service);
    const other = '/safe/already.MSone.srt';
    files.files[other] = Uint8List.fromList([90]);
    final renamed = plan.renamed(service.fileNameFor(
      requestedName: 'already', customTag: 'MSone', originalOnly: false));
    expect(await service.writeDesktop(folder: '/safe', plan: renamed),
        EditorExportWriteResult.alreadyExists);
    expect(files.files[other], [90]);
    expect(files.writes, isEmpty);
  });

  test('nonlocal/absent destination is rejected without writing', () async {
    final files = _FakeExportFiles();
    final service = EditorExportService(files: files, isWindows: false);
    final plan = await _plan(service);
    expect(() => service.destinationPath('content://media/document/1', plan),
        throwsA(isA<ArgumentError>()));
    expect(() => service.destinationPath('https://example.org/file', plan),
        throwsA(isA<ArgumentError>()));
    await expectLater(service.writeDesktop(folder: '/missing', plan: plan),
        throwsA(isA<FileSystemException>()));
    expect(files.writes, isEmpty);
  });

  test('folder suggestion never converts Android SAF display path to folder',
      () {
    final service = EditorExportService(isWindows: false);
    expect(service.suggestedFolder(
      originalFileUri: 'content://documents/document/opaque%3A1',
      legacyFilePath: '/display/looks-native.srt',
    ), isNull);
    expect(service.suggestedFolder(
      legacyFilePath: '/subtitles/scene.srt',
    ), '/subtitles');
    expect(service.suggestedFolder(
      originalFileUri: 'file:///My%20Subtitles/scene.srt',
    ), '/My Subtitles');
  });

  test('Windows escaped file URI uses proper backslash folder path', () async {
    final files = _FakeExportFiles()..folders.add(r'C:\My Subtitles');
    final service = EditorExportService(files: files, isWindows: true);
    final plan = await _plan(service);
    final result = await service.writeDesktop(
        folder: 'file:///C:/My%20Subtitles', plan: plan);
    expect(result, EditorExportWriteResult.saved);
    expect(files.writes, [r'C:\My Subtitles\scene.MSone.srt']);
    expect(service.suggestedFolder(
      originalFileUri: 'file:///C:/My%20Subtitles/scene.srt',
    ), r'C:\My Subtitles');
    expect(service.suggestedFolder(
      legacyFilePath: 'C:/My Subtitles/scene.srt',
    ), r'C:\My Subtitles');
  });

  test('real host writes chosen bytes and keeps blank text', () async {
    final temp = await Directory.systemTemp.createTemp('cp90_export_');
    addTearDown(() => temp.delete(recursive: true));
    final service = EditorExportService();
    final plan = await _plan(service, encoding: 'UTF-8 BOM', edited: '');
    expect(await service.writeDesktop(folder: temp.path, plan: plan),
        EditorExportWriteResult.saved);
    final saved = File('${temp.path}${Platform.pathSeparator}${plan.fileName}');
    final decoded = SubtitleTextCodec.decode(await saved.readAsBytes());
    expect(decoded.encoding, 'UTF-8 BOM');
    expect(decoded.content, contains('00:00:02,000\n\n\n'));
    expect(decoded.content, isNot(contains('Private original')));
  });
}
