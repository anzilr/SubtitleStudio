import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/core/file_access/secondary_subtitle_document_reader.dart';

final class _FakeBytes implements SecondarySubtitleByteSource {
  _FakeBytes({this.isAndroid = true, this.isWindows = false});
  @override
  final bool isAndroid;
  @override
  final bool isWindows;
  final native = <String, Uint8List>{};
  final docs = <String, Uint8List>{};
  final attempts = <String>[];
  @override
  Future<Uint8List> readNative(String path) async {
    attempts.add('native');
    final bytes = native[path];
    if (bytes == null) throw const FileSystemException('Missing file');
    return bytes;
  }

  @override
  Future<Uint8List> readDocument(String uri) async {
    attempts.add('document');
    final bytes = docs[uri];
    if (bytes == null) throw const FileSystemException('Grant revoked');
    return bytes;
  }
}

void main() {
  const srt = '1\n00:00:01,000 --> 00:00:02,000\nHello world\n';
  const vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello web\n';

  test('native SRT uses native bytes once', () async {
    const path = '/app/subtitle.srt';
    final fake = _FakeBytes()
      ..native[path] = Uint8List.fromList(utf8.encode(srt));
    final cues = await SecondarySubtitleDocumentReader(byteSource: fake)
        .readAndParse(path);
    expect(cues.single.text, 'Hello world');
    expect(fake.attempts, ['native']);
  });

  test('Android document is never opened through File', () async {
    const uri = 'content://provider.example/document/primary%3AMovie%2Fsub.srt';
    final fake = _FakeBytes()
      ..docs[uri] = Uint8List.fromList(utf8.encode(srt));
    final cues = await SecondarySubtitleDocumentReader(byteSource: fake)
        .readAndParse(uri);
    expect(cues.single.text, 'Hello world');
    expect(fake.attempts, ['document']);
  });

  test('opaque provider ID is classified by WebVTT signature', () async {
    const uri = 'content://provider.example/document/opaque%3A123';
    final fake = _FakeBytes()
      ..docs[uri] = Uint8List.fromList(utf8.encode(vtt));
    final cues = await SecondarySubtitleDocumentReader(byteSource: fake)
        .readAndParse(uri);
    expect(cues.single.text, 'Hello web');
    expect(fake.attempts, ['document']);
  });

  test('file URI is decoded to native path before File access', () async {
    const uri = 'file:///tmp/secondary%20subtitle.srt';
    final decoded = Uri.parse(uri).toFilePath(windows: false);
    final fake = _FakeBytes(isAndroid: false)
      ..native[decoded] = Uint8List.fromList(utf8.encode(srt));
    final cues = await SecondarySubtitleDocumentReader(byteSource: fake)
        .readAndParse(uri);
    expect(cues.single.text, 'Hello world');
    expect(fake.attempts, ['native']);
  });

  test('Windows file URI uses Windows drive path without an Android grant',
      () async {
    const uri = 'file:///C:/Studio/secondary%20subtitle.srt';
    final path = Uri.parse(uri).toFilePath(windows: true);
    final fake = _FakeBytes(isAndroid: false, isWindows: true)
      ..native[path] = Uint8List.fromList(utf8.encode(srt));
    final cues = await SecondarySubtitleDocumentReader(byteSource: fake)
        .readAndParse(uri);
    expect(cues.single.text, 'Hello world');
    expect(fake.attempts, ['native']);
  });

  test('iOS-style sandbox file URI reads local copy, not a SAF document',
      () async {
    const uri = 'file:///private/var/mobile/Documents/Subtitle%20One.srt';
    const path = '/private/var/mobile/Documents/Subtitle One.srt';
    final fake = _FakeBytes(isAndroid: false)
      ..native[path] = Uint8List.fromList(utf8.encode(srt));
    final cues = await SecondarySubtitleDocumentReader(byteSource: fake)
        .readAndParse(uri);
    expect(cues.single.text, 'Hello world');
    expect(fake.attempts, ['native']);
  });

  test('host OS reads a real percent-escaped secondary-subtitle file URI',
      () async {
    final dir = await Directory.systemTemp.createTemp('cp88_secondary_uri_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File('${dir.path}${Platform.pathSeparator}my subtitle.srt');
    await file.writeAsBytes(utf8.encode(srt));
    final locator = Uri.file(file.path, windows: Platform.isWindows).toString();
    final cues = await const SecondarySubtitleDocumentReader()
        .readAndParse(locator);
    expect(cues.single.text, 'Hello world');
  });

  test('revoked document never attempts native fallback', () async {
    const uri = 'content://provider.example/document/revoked.srt';
    final fake = _FakeBytes();
    await expectLater(
      SecondarySubtitleDocumentReader(byteSource: fake).readAndParse(uri),
      throwsA(isA<FileSystemException>()),
    );
    expect(fake.attempts, ['document']);
  });

  test('non-Android content documents cannot become local paths', () async {
    const uri = 'content://provider.example/document/only.srt';
    final fake = _FakeBytes(isAndroid: false);
    await expectLater(
      SecondarySubtitleDocumentReader(byteSource: fake).readAndParse(uri),
      throwsA(isA<FileSystemException>()),
    );
    expect(fake.attempts, isEmpty);
  });

  test('remote, opaque and unsupported file types fail closed', () async {
    final fake = _FakeBytes();
    for (final uri in [
      'https://example.com/source.srt?token=private',
      'saf:unresolved-id.srt',
      'rtsp://example.com/track.srt',
    ]) {
      await expectLater(
        SecondarySubtitleDocumentReader(byteSource: fake).readAndParse(uri),
        throwsA(isA<FileSystemException>()),
      );
    }
    expect(fake.attempts, isEmpty);

    const path = '/app/subtitle.txt';
    fake.native[path] = Uint8List.fromList(utf8.encode(srt));
    await expectLater(
      SecondarySubtitleDocumentReader(byteSource: fake).readAndParse(path),
      throwsFormatException,
    );
  });

  test('invalid UTF-8 does not silently replace unknown characters', () async {
    const path = '/app/subtitle.srt';
    final fake = _FakeBytes()
      ..native[path] = Uint8List.fromList([0xFF, 0x00]);
    await expectLater(
      SecondarySubtitleDocumentReader(byteSource: fake).readAndParse(path),
      throwsFormatException,
    );
  });
}
