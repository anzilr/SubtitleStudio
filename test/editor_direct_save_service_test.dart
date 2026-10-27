import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/services/editor_direct_save_service.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_file_save_service.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_access.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';

class _FakeFileOperations implements SourceViewFileOperations {
  _FakeFileOperations({this.isAndroid = false});

  @override
  final bool isAndroid;
  @override
  bool get isWindows => false;
  final files = <String, Uint8List>{};
  final documents = <String, Uint8List>{};
  final writes = <String>[];
  bool rejectDocuments = false;

  @override
  Future<Uint8List?> readNative(String path) async => files[path];
  @override
  Future<bool> writeNative(String path, Uint8List bytes) async {
    writes.add('native');
    if (!files.containsKey(path)) return false;
    files[path] = bytes;
    return true;
  }
  @override
  Future<Uint8List?> readDocument(String uri) async => documents[uri];
  @override
  Future<bool> writeDocument(String uri, Uint8List bytes) async {
    writes.add('document');
    if (rejectDocuments || !documents.containsKey(uri)) return false;
    documents[uri] = bytes;
    return true;
  }
  @override
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  }) async => null;
}

class _FakeBookmarks implements EditorBookmarkAccess {
  String? resolved;
  bool failToResolve = false;
  int resolutions = 0;
  final released = <String>[];
  Uint8List? lastBytes;

  @override
  Future<String?> resolve(Uint8List bookmark) async {
    resolutions++;
    lastBytes = bookmark;
    if (failToResolve) throw const FileSystemException('Bookmark denied');
    return resolved;
  }
  @override
  Future<void> release(String nativePath) async {
    released.add(nativePath);
  }
}

SubtitleCollection _collection({
  String encoding = 'UTF-8',
  String? filePath,
  String? originalFileUri,
  String? bookmark,
}) => SubtitleCollection(
      fileName: 'editor.srt',
      encoding: encoding,
      filePath: filePath,
      originalFileUri: originalFileUri,
      macOsSrtBookmark: bookmark,
      lines: const [],
    );

SubtitleLine _line({String original = 'Original', String? edited}) =>
    SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = original
      ..edited = edited;

EditorDirectSaveService _service(_FakeFileOperations operations, {
  required bool isMacOS,
  _FakeBookmarks? bookmarks,
}) => EditorDirectSaveService(
      saver: EditLineFileSaveService(
          access: SourceViewFileAccessImpl(operations: operations)),
      bookmarks: bookmarks,
      isMacOS: isMacOS,
    );

void main() {
  const nativePath = '/existing/cue.srt';
  const document = 'content://example.documents/document/abc%3A1';

  test('Editor Save writes exact charset bytes and preserves empty edits',
      () async {
    final ops = _FakeFileOperations(isAndroid: true)
      ..documents[document] = Uint8List.fromList([11]);
    final collection = _collection(
      originalFileUri: document,
      filePath: '/synthetic/display.srt',
      encoding: 'UTF-16BE BOM',
    );
    final result = await _service(ops, isMacOS: false)
        .save(collection, [_line(edited: '')]);
    expect(result.saved, isTrue);
    expect(result.legacyFilePathToPersist, isNull);
    expect(ops.writes, ['document']);
    final decoded = SubtitleTextCodec.decode(ops.documents[document]!);
    expect(decoded.encoding, 'UTF-16BE BOM');
    expect(decoded.content, contains('00:00:02,000\n\n\n'));
    expect(decoded.content, isNot(contains('Original')));
  });

  test('revoked authoritative document never redirects to display path',
      () async {
    final ops = _FakeFileOperations(isAndroid: true)
      ..rejectDocuments = true
      ..documents[document] = Uint8List.fromList([1])
      ..files[nativePath] = Uint8List.fromList([2]);
    final result = await _service(ops, isMacOS: false).save(
      _collection(originalFileUri: document, filePath: nativePath),
      [_line()],
    );
    expect(result.saved, isFalse);
    expect(ops.writes, ['document']);
    expect(ops.files[nativePath], [2]);
  });

  test('legacy existing path is saved and proposed for identity migration',
      () async {
    final ops = _FakeFileOperations()
      ..files[nativePath] = Uint8List.fromList([3]);
    final result = await _service(ops, isMacOS: false)
        .save(_collection(filePath: nativePath), [_line()]);
    expect(result.saved, isTrue);
    expect(result.legacyFilePathToPersist, nativePath);
    expect(ops.writes, ['native']);
  });

  test('SRT compiler never overwrites a linked VTT, ASS or SSA source',
      () async {
    for (final extension in ['vtt', 'ass', 'ssa']) {
      final path = '/existing/original.$extension';
      final ops = _FakeFileOperations()
        ..files[path] = Uint8List.fromList([1, 2, 3]);
      final collection = _collection(filePath: path);
      // Even if an imported archive advertises an SRT display name, its
      // non-SRT native locator must not become the target of SRT Save.
      final result = await _service(ops, isMacOS: false)
          .save(collection, [_line()]);
      expect(result.saved, isFalse);
      expect(ops.writes, isEmpty);
      expect(ops.files[path], [1, 2, 3]);
    }
  });

  test('non-SRT project filename cannot write an SRT-looking file', () async {
    final ops = _FakeFileOperations()
      ..files[nativePath] = Uint8List.fromList([4, 5]);
    final collection = _collection(filePath: nativePath)
      ..fileName = 'imported.ass';
    final result = await _service(ops, isMacOS: false)
        .save(collection, [_line()]);
    expect(result.saved, isFalse);
    expect(ops.writes, isEmpty);
    expect(ops.files[nativePath], [4, 5]);
  });

  test('encoding failure happens before any bookmark or write operation',
      () async {
    final bookmarks = _FakeBookmarks()..resolved = nativePath;
    final ops = _FakeFileOperations()
      ..files[nativePath] = Uint8List.fromList([3]);
    await expectLater(
      _service(ops, isMacOS: true, bookmarks: bookmarks).save(
        _collection(encoding: 'Windows-1252',
            bookmark: base64Encode(const [1, 2])),
        [_line(original: 'മലയാളം')],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(bookmarks.resolutions, 0);
    expect(ops.writes, isEmpty);
    expect(ops.files[nativePath], [3]);
  });

  test('macOS bookmark resolves, writes encoded bytes, always releases',
      () async {
    final bookmarks = _FakeBookmarks()..resolved = nativePath;
    final ops = _FakeFileOperations()
      ..files[nativePath] = Uint8List.fromList([3]);
    final collection = _collection(
      filePath: '/outdated/previous.srt',
      encoding: 'UTF-8 BOM',
      bookmark: base64Encode(const [1, 2, 3, 4]),
    );
    final result = await _service(ops, isMacOS: true, bookmarks: bookmarks)
        .save(collection, [_line()]);
    expect(result.saved, isTrue);
    expect(result.legacyFilePathToPersist, isNull);
    expect(bookmarks.lastBytes, [1, 2, 3, 4]);
    expect(bookmarks.released, [nativePath]);
    expect(ops.writes, ['native']);
    expect(SubtitleTextCodec.decode(ops.files[nativePath]!).encoding,
        'UTF-8 BOM');

    // Even an unavailable resolved file must release the scoped resource.
    ops.files.clear();
    final fallback = await _service(ops, isMacOS: true, bookmarks: bookmarks)
        .save(collection, [_line()]);
    expect(fallback.saved, isFalse);
    expect(bookmarks.released, [nativePath, nativePath]);
  });

  test('macOS absent or invalid bookmark does not write stale paths',
      () async {
    final bookmarks = _FakeBookmarks();
    final ops = _FakeFileOperations()
      ..files[nativePath] = Uint8List.fromList([5]);
    final saver = _service(ops, isMacOS: true, bookmarks: bookmarks);
    expect((await saver.save(
        _collection(filePath: nativePath), [_line()])).saved, isFalse);
    expect((await saver.save(
        _collection(filePath: nativePath, bookmark: 'not base64'),
        [_line()])).saved, isFalse);
    expect(bookmarks.resolutions, 0);
    expect(bookmarks.released, isEmpty);
    expect(ops.writes, isEmpty);
  });

  test('revoked macOS bookmark falls back without writing stale path',
      () async {
    final bookmarks = _FakeBookmarks()..failToResolve = true;
    final ops = _FakeFileOperations()
      ..files[nativePath] = Uint8List.fromList([5]);
    final result = await _service(ops, isMacOS: true, bookmarks: bookmarks)
        .save(_collection(filePath: nativePath,
            bookmark: base64Encode(const [1, 2, 3])), [_line()]);
    expect(result.saved, isFalse);
    expect(bookmarks.resolutions, 1);
    expect(bookmarks.released, isEmpty);
    expect(ops.writes, isEmpty);
    expect(ops.files[nativePath], [5]);
  });

  test('host existing file saves via percent-escaped file URI', () async {
    final temp = await Directory.systemTemp.createTemp('cp90_editor_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}${Platform.pathSeparator}edit cue.srt');
    await file.writeAsBytes([9]);
    final uri = Uri.file(file.path, windows: Platform.isWindows).toString();
    final result = await EditorDirectSaveService(isMacOS: false).save(
      _collection(originalFileUri: uri, encoding: 'UTF-8 BOM'),
      [_line(edited: '')],
    );
    expect(result.saved, isTrue);
    expect(SubtitleTextCodec.decode(await file.readAsBytes()).encoding,
        'UTF-8 BOM');
  });
}
