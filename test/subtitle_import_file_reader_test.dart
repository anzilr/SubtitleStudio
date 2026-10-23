import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/core/file_access/subtitle_import_file_reader.dart';

final class _FakeImportBytes implements SubtitleImportByteAccess {
  _FakeImportBytes({this.isAndroid = true, this.isWindows = false});
  @override
  final bool isAndroid;
  @override
  final bool isWindows;
  final native = <String, Uint8List>{};
  final docs = <String, Uint8List>{};
  final called = <String>[];

  @override
  Future<Uint8List> readNative(String path) async {
    called.add('native');
    final b = native[path];
    if (b == null) throw const FileSystemException('Native missing');
    return b;
  }
  @override
  Future<Uint8List> readDocument(String uri) async {
    called.add('document');
    final b = docs[uri];
    if (b == null) throw const FileSystemException('Document denied');
    return b;
  }
}

void main() {
  const uri = 'content://provider.example/document/primary%3ADownload%2Fa.srt';
  const presentation = '/storage/emulated/0/Download/a.srt';

  test('synthetic display path with SAF grant reads original content URI', () async {
    final a = _FakeImportBytes()..docs[uri] = Uint8List.fromList([0, 255, 128]);
    final reference = SubtitleImportFileReference.resolve(
      filePath: presentation, safUri: uri, accessLocator: uri);
    final bytes = await SubtitleImportFileReader(access: a).read(reference);
    expect(reference.accessLocator, uri);
    expect(reference.safUri, uri);
    expect(bytes, [0, 255, 128]);
    expect(a.called, ['document']);
  });

  test('direct content URI works even with no separate SAF field', () async {
    final a = _FakeImportBytes()..docs[uri] = Uint8List.fromList([97]);
    final ref = SubtitleImportFileReference.resolve(filePath: uri);
    expect(ref.safUri, uri);
    expect(await SubtitleImportFileReader(access: a).read(ref), [97]);
    expect(a.called, ['document']);
  });

  test('revoked grant cannot fall back to synthetic local file', () async {
    final a = _FakeImportBytes();
    final ref = SubtitleImportFileReference.resolve(
      filePath: presentation, safUri: uri);
    await expectLater(SubtitleImportFileReader(access: a).read(ref),
      throwsA(isA<FileSystemException>()));
    expect(a.called, ['document']);
  });

  test('mismatched direct-source URI and grant are rejected', () {
    expect(() => SubtitleImportFileReference.resolve(
      filePath: uri,
      safUri: 'content://other.provider/document/unrelated.srt',
    ), throwsFormatException);
  });

  test('remote and malformed grants are rejected before I/O', () {
    for (final source in ['https://example.net/a.srt?token=private',
      'rtsp://example.net/a.srt', 'saf:old.srt', '']) {
      expect(() => SubtitleImportFileReference.resolve(filePath: source),
          throwsFormatException);
    }
    expect(() => SubtitleImportFileReference.resolve(
      filePath: presentation, safUri: 'content://'), throwsFormatException);
  });

  test('desktop local path and file URI are handled without SAF', () async {
    final a = _FakeImportBytes(isAndroid: false);
    const path = '/tmp/one subtitle.srt';
    a.native[path] = Uint8List.fromList([49, 10]);
    final direct = SubtitleImportFileReference.resolve(filePath: path);
    expect(await SubtitleImportFileReader(access: a).read(direct), [49, 10]);
    final asUri = SubtitleImportFileReference.resolve(
      filePath: 'file:///tmp/one%20subtitle.srt');
    expect(await SubtitleImportFileReader(access: a).read(asUri), [49, 10]);
    expect(a.called, ['native', 'native']);
  });

  test('Windows file URI decodes to native drive path', () async {
    const uri = 'file:///C:/Studio/one%20subtitle.srt';
    final access = _FakeImportBytes(isAndroid: false, isWindows: true);
    final nativePath = Uri.parse(uri).toFilePath(windows: true);
    access.native[nativePath] = Uint8List.fromList([49, 10]);
    final source = SubtitleImportFileReference.resolve(filePath: uri);
    final bytes = await SubtitleImportFileReader(access: access).read(source);
    expect(bytes, [49, 10]);
    expect(access.called, ['native']);
  });

  test('iOS sandboxed picker URI loads native bytes without SAF', () async {
    const uri = 'file:///private/var/mobile/Documents/Malayalam%20sample.srt';
    const local = '/private/var/mobile/Documents/Malayalam sample.srt';
    final access = _FakeImportBytes(isAndroid: false)
      ..native[local] = Uint8List.fromList([49, 10]);
    final source = SubtitleImportFileReference.resolve(filePath: uri);
    expect(await SubtitleImportFileReader(access: access).read(source),
        [49, 10]);
    expect(access.called, ['native']);
  });

  test('Android source cannot be read on non Android', () async {
    final a = _FakeImportBytes(isAndroid: false);
    final ref = SubtitleImportFileReference.resolve(filePath: uri);
    await expectLater(SubtitleImportFileReader(access: a).read(ref),
      throwsA(isA<FileSystemException>()));
    expect(a.called, isEmpty);
  });
}
