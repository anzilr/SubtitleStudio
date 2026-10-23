import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_file_save_service.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_access.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';

class _FakeOperations implements SourceViewFileOperations {
  _FakeOperations({this.isAndroid = true, this.isWindows = false});

  @override
  final bool isAndroid;
  @override
  final bool isWindows;
  final local = <String, Uint8List>{};
  final documents = <String, Uint8List>{};
  final calls = <String>[];
  bool denyDocuments = false;

  @override
  Future<Uint8List?> readNative(String path) async => local[path];

  @override
  Future<bool> writeNative(String path, Uint8List bytes) async {
    calls.add('native');
    if (!local.containsKey(path)) return false;
    local[path] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> readDocument(String uri) async => documents[uri];

  @override
  Future<bool> writeDocument(String uri, Uint8List bytes) async {
    calls.add('document');
    if (denyDocuments || !documents.containsKey(uri)) return false;
    documents[uri] = bytes;
    return true;
  }

  @override
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  }) async => null;
}

class _FakePicker implements EditLineSaveAsPicker {
  EditLineSavedLocation? next;
  String? requestedName;
  Uint8List? requestedBytes;

  @override
  Future<EditLineSavedLocation?> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    requestedName = fileName;
    requestedBytes = bytes;
    return next;
  }
}

SubtitleCollection _collection({
  String encoding = 'UTF-8',
  String? uri,
  String? path,
  String fileName = 'Subtitle',
}) => SubtitleCollection(
      fileName: fileName,
      filePath: path,
      originalFileUri: uri,
      encoding: encoding,
      lines: const [],
    );

SubtitleLine _line({String original = 'Original', String? edited}) =>
    SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = original
      ..edited = edited;

void main() {
  const docUri = 'content://example.documents/document/subtitle%3A1';
  const localPath = '/cache/subtitle.srt';

  test('encodes a deliberately empty edit without restoring original',
      () async {
    final saver = EditLineFileSaveService();
    final bytes = await saver.prepareBytes(
      _collection(encoding: 'UTF-16LE BOM'),
      [_line(edited: '')],
    );
    final decoded = SubtitleTextCodec.decode(bytes);
    expect(decoded.encoding, 'UTF-16LE BOM');
    expect(decoded.content, contains('00:00:01,000 --> 00:00:02,000'));
    expect(decoded.content, isNot(contains('Original')));
    // The cue remains structurally present, with an empty text line.
    expect(decoded.content, contains('00:00:02,000\n\n\n'));
  });

  test('incompatible charset aborts before any write or picker', () async {
    final ops = _FakeOperations()..local[localPath] = Uint8List.fromList([4]);
    final picker = _FakePicker();
    final saver = EditLineFileSaveService(
      access: SourceViewFileAccessImpl(operations: ops),
      picker: picker,
    );
    await expectLater(
      saver.prepareBytes(_collection(encoding: 'Windows-1252'),
          [_line(original: 'മലയാളം')]),
      throwsA(anyOf(isA<FormatException>(), isA<UnsupportedError>())),
    );
    expect(ops.calls, isEmpty);
    expect(picker.requestedName, isNull);
    expect(ops.local[localPath], [4]);
  });

  test('original SAF URI takes precedence over legacy cached display path',
      () async {
    final ops = _FakeOperations()
      ..documents[docUri] = Uint8List.fromList([1])
      ..local[localPath] = Uint8List.fromList([9]);
    final saver = EditLineFileSaveService(
      access: SourceViewFileAccessImpl(operations: ops),
    );
    final bytes = Uint8List.fromList([2, 3]);
    final model = _collection(uri: docUri, path: localPath);
    expect(await saver.saveExisting(model, bytes), isTrue);
    expect(ops.calls, ['document']);
    expect(ops.documents[docUri], bytes);
    expect(ops.local[localPath], [9]);

    ops.denyDocuments = true;
    expect(await saver.saveExisting(model, Uint8List.fromList([4])), isFalse);
    expect(ops.calls, ['document', 'document']);
    expect(ops.local[localPath], [9]);
  });

  test('legacy local path works only when no original URI is recorded',
      () async {
    final ops = _FakeOperations(isAndroid: false)
      ..local[localPath] = Uint8List.fromList([1]);
    final saver = EditLineFileSaveService(
      access: SourceViewFileAccessImpl(operations: ops),
    );
    expect(await saver.saveExisting(
        _collection(path: localPath), Uint8List.fromList([3])), isTrue);
    expect(ops.local[localPath], [3]);
    expect(await saver.saveExisting(
        _collection(uri: 'https://example.test/s.srt', path: localPath),
        Uint8List.fromList([4])), isFalse);
    expect(ops.local[localPath], [3]);
  });

  test('Windows file URI routes decoded native path through adapter',
      () async {
    const uri = 'file:///C:/My%20Subtitles/edited.srt';
    final path = Uri.parse(uri).toFilePath(windows: true);
    final ops = _FakeOperations(isAndroid: false, isWindows: true)
      ..local[path] = Uint8List.fromList([1]);
    final saver = EditLineFileSaveService(
      access: SourceViewFileAccessImpl(operations: ops),
    );
    expect(await saver.saveExisting(_collection(uri: uri),
        Uint8List.fromList([8])), isTrue);
    expect(ops.local[path], [8]);
  });

  test('Save As carries the selected authority without changing model',
      () async {
    final picker = _FakePicker()
      ..next = const EditLineSavedLocation(
        filePath: '/display/subtitle.srt',
        originalFileUri: docUri,
      );
    final saver = EditLineFileSaveService(picker: picker);
    final model = _collection(fileName: 'talk.SRT');
    final bytes = Uint8List.fromList([1, 2]);
    expect(await saver.saveAs(model, bytes), same(picker.next));
    expect(picker.requestedName, 'talk.SRT');
    expect(picker.requestedBytes, bytes);
    expect(model.originalFileUri, isNull);
    picker.next = null;
    expect(await saver.saveAs(_collection(), bytes), isNull);
    expect(picker.requestedName, 'Subtitle.srt');
  });

  test('real existing native file retains strict encoding bytes', () async {
    final temp = await Directory.systemTemp.createTemp('cp90_edit_line_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}${Platform.pathSeparator}edited.srt');
    await file.writeAsBytes([0x7F]);
    final model = _collection(path: file.path, encoding: 'UTF-8 BOM');
    final saver = EditLineFileSaveService();
    final bytes = await saver.prepareBytes(model, [_line(edited: '')]);
    expect(await saver.saveExisting(model, bytes), isTrue);
    expect(await file.readAsBytes(), bytes);
  });
}
