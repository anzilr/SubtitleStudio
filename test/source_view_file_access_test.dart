import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_access.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_target.dart';

class _MemoryFileOperations implements SourceViewFileOperations {
  _MemoryFileOperations({this.isAndroid = true, this.isWindows = false});

  @override
  final bool isAndroid;
  @override
  final bool isWindows;
  final Map<String, Uint8List> local = {};
  final Map<String, Uint8List> docs = {};
  final List<String> events = [];
  bool rejectDocumentReads = false;
  bool rejectDocumentWrites = false;
  bool returnEmptyDocument = false;
  bool cancelCreate = false;

  @override
  Future<Uint8List?> readNative(String path) async {
    events.add('readNative');
    return local[path];
  }

  @override
  Future<bool> writeNative(String path, Uint8List bytes) async {
    events.add('writeNative');
    if (!local.containsKey(path)) return false;
    local[path] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> readDocument(String uri) async {
    events.add('readDocument');
    if (rejectDocumentReads) throw StateError('revoked');
    if (returnEmptyDocument) return Uint8List(0);
    return docs[uri];
  }

  @override
  Future<bool> writeDocument(String uri, Uint8List bytes) async {
    events.add('writeDocument');
    if (rejectDocumentWrites) throw StateError('revoked');
    if (!docs.containsKey(uri)) return false;
    docs[uri] = bytes;
    return true;
  }

  @override
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  }) async {
    events.add('createDocument');
    if (cancelCreate) return null;
    const uri = 'content://test.documents/document/new%3Asrt';
    docs[uri] = Uint8List(0);
    return const SourceViewCreatedDocument(
      uri: uri, displayPath: 'New SRT',
    );
  }
}

void main() {
  const local = '/data/app/cache/editor.srt';
  const uri = 'content://test.documents/document/subtitle%3Asrt';
  final original = Uint8List.fromList([49, 10, 50]);
  final changed = Uint8List.fromList([51, 10, 52]);

  test('prefers the original Android document for read and write', () async {
    final ops = _MemoryFileOperations()
      ..local[local] = original
      ..docs[uri] = original;
    final service = SourceViewFileAccessImpl(operations: ops);
    final target = SourceViewFileTarget.resolve(
      filePath: local, safUri: uri,
    );
    expect(await service.read(target), original);
    expect(ops.events, ['readDocument']);
    expect(await service.write(target, changed),
        SourceViewSaveDestination.androidDocument);
    expect(ops.docs[uri], changed);
    expect(ops.local[local], original);
    expect(ops.events, ['readDocument', 'writeDocument']);
  });

  test('a revoked direct content URI cannot read or overwrite other paths',
      () async {
    final ops = _MemoryFileOperations()
      ..rejectDocumentReads = true
      ..rejectDocumentWrites = true
      ..local[local] = original;
    final service = SourceViewFileAccessImpl(operations: ops);
    final target = SourceViewFileTarget.resolve(filePath: uri);
    await expectLater(service.read(target), throwsA(isA<FileSystemException>()));
    expect(await service.write(target, changed), isNull);
    expect(ops.local[local], original);
    expect(ops.events, ['readDocument', 'writeDocument']);
  });

  test('existing native cache can be fallback after revoked grant', () async {
    final ops = _MemoryFileOperations()
      ..rejectDocumentReads = true
      ..rejectDocumentWrites = true
      ..local[local] = original;
    final service = SourceViewFileAccessImpl(operations: ops);
    final target = SourceViewFileTarget.resolve(
      filePath: local, safUri: uri,
    );
    expect(await service.read(target), original);
    expect(await service.write(target, changed),
        SourceViewSaveDestination.nativeFile);
    expect(ops.local[local], changed);
    expect(ops.events, [
      'readDocument', 'readNative', 'writeDocument', 'writeNative',
    ]);
  });

  test('invalid direct URI and absent native source fail closed', () async {
    final ops = _MemoryFileOperations();
    final service = SourceViewFileAccessImpl(operations: ops);
    final web = SourceViewFileTarget.resolve(
      filePath: 'https://example.com/sub.srt?key=token',
    );
    await expectLater(service.read(web), throwsA(isA<FileSystemException>()));
    expect(await service.write(web, changed), isNull);
    expect(ops.events, isEmpty);
    final missing = SourceViewFileTarget.resolve(filePath: '/missing.srt');
    await expectLater(service.read(missing), throwsA(isA<FileSystemException>()));
    expect(await service.write(missing, changed), isNull);
  });

  test('empty SAF document is authoritative even with an older native cache',
      () async {
    final ops = _MemoryFileOperations()
      ..returnEmptyDocument = true
      ..local[local] = original;
    final service = SourceViewFileAccessImpl(operations: ops);
    expect(await service.read(SourceViewFileTarget.resolve(
      filePath: local, safUri: uri)), isEmpty);
    expect(await service.read(SourceViewFileTarget.resolve(
      filePath: uri)), isEmpty);
    expect(ops.local[local], original);
    expect(ops.events, ['readDocument', 'readDocument']);
  });

  test('null SAF response falls back to cache, but direct URI fails closed',
      () async {
    final ops = _MemoryFileOperations()..local[local] = original;
    final service = SourceViewFileAccessImpl(operations: ops);
    expect(await service.read(SourceViewFileTarget.resolve(
      filePath: local, safUri: uri)), original);
    await expectLater(service.read(SourceViewFileTarget.resolve(
      filePath: uri)), throwsA(isA<FileSystemException>()));
    expect(ops.events, ['readDocument', 'readNative', 'readDocument']);
  });

  test('non-Android adapter avoids Android SAF while permitting local IO',
      () async {
    final ops = _MemoryFileOperations(isAndroid: false)
      ..local[local] = original;
    final service = SourceViewFileAccessImpl(operations: ops);
    final target = SourceViewFileTarget.resolve(
      filePath: local, safUri: uri,
    );
    expect(await service.read(target), original);
    expect(ops.events, ['readNative']);
    expect(await service.write(target, changed),
        SourceViewSaveDestination.nativeFile);
    expect(ops.events, ['readNative', 'writeNative']);
    expect(() => service.createDocument(fileName: 'export.srt',
        mimeType: 'text/plain'), throwsUnsupportedError);
  });

  test('Windows file URI uses decoded native path without changing source',
      () async {
    const locator = 'file:///C:/Studio/My%20Subtitles/raw.srt';
    final path = Uri.parse(locator).toFilePath(windows: true);
    final ops = _MemoryFileOperations(isAndroid: false, isWindows: true)
      ..local[path] = original;
    final source = SourceViewFileTarget.resolve(filePath: locator);
    final access = SourceViewFileAccessImpl(operations: ops);
    expect(source.source.location, locator);
    expect(await access.read(source), original);
    expect(await access.write(source, changed),
        SourceViewSaveDestination.nativeFile);
    expect(ops.local[path], changed);
    expect(ops.events, ['readNative', 'writeNative']);
  });

  test('macOS, Linux and sandboxed iOS file URI route through native adapter',
      () async {
    const locator = 'file:///private/var/mobile/My%20Subtitles/raw.srt';
    const path = '/private/var/mobile/My Subtitles/raw.srt';
    final ops = _MemoryFileOperations(isAndroid: false)
      ..local[path] = original;
    final source = SourceViewFileTarget.resolve(filePath: locator);
    final access = SourceViewFileAccessImpl(operations: ops);
    expect(await access.read(source), original);
    expect(await access.write(source, changed),
        SourceViewSaveDestination.nativeFile);
    expect(ops.local[path], changed);
    expect(ops.events, ['readNative', 'writeNative']);
  });

  test('non-local and malformed file URIs cannot be treated as native files',
      () async {
    final ops = _MemoryFileOperations(isAndroid: false);
    final access = SourceViewFileAccessImpl(operations: ops);
    final source = SourceViewFileTarget.resolve(
        filePath: 'file://remote.example/private/sub.srt');
    await expectLater(access.read(source),
        throwsA(isA<FileSystemException>()));
    expect(await access.write(source, changed), isNull);
    expect(ops.events, isEmpty);
  });

  test('actual host OS reads and saves a percent-escaped file URI', () async {
    final dir = await Directory.systemTemp.createTemp('cp88_source_uri_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File('${dir.path}${Platform.pathSeparator}my source.srt');
    await file.writeAsBytes(original);
    final uri = Uri.file(file.path, windows: Platform.isWindows).toString();
    final target = SourceViewFileTarget.resolve(filePath: uri);
    final service = SourceViewFileAccessImpl();
    expect(await service.read(target), original);
    expect(await service.write(target, changed),
        SourceViewSaveDestination.nativeFile);
    expect(await file.readAsBytes(), changed);
    // Persistence retains the file URI, never its decoded operation path.
    expect(target.source.location, uri);
  });

  test('Save As validates created documents and honors cancellation', () async {
    final ops = _MemoryFileOperations();
    final service = SourceViewFileAccessImpl(operations: ops);
    final selected = await service.createDocument(
      fileName: 'new.srt', mimeType: 'text/plain',
    );
    expect(selected, isNotNull);
    expect(await service.writeCreatedDocument(selected!, changed), isTrue);
    expect(ops.docs[selected.uri], changed);
    await expectLater(service.writeCreatedDocument(
      const SourceViewCreatedDocument(
        uri: 'https://untrusted.example/overwrite',
        displayPath: 'Other',
      ), changed), throwsFormatException);
    expect(ops.events.where((value) => value == 'writeDocument'), hasLength(1));
    ops.cancelCreate = true;
    expect(await service.createDocument(
      fileName: 'again.srt', mimeType: 'text/plain',
    ), isNull);
  });
}
