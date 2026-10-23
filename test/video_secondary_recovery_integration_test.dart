import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:subtitle_studio/core/file_access/secondary_subtitle_document_reader.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/repositories/editor_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/video_repository.dart';
import 'support/test_isar_harness.dart';

final class _FakeDocumentBytes implements SecondarySubtitleByteSource {
  final Map<String, Uint8List> documents = {};
  final List<String> attempts = [];
  bool revoked = false;

  @override
  bool get isAndroid => true;

  @override
  bool get isWindows => false;

  @override
  Future<Uint8List> readDocument(String uri) async {
    attempts.add('document');
    if (revoked) throw const FileSystemException('Document permission revoked');
    final bytes = documents[uri];
    if (bytes == null) throw const FileSystemException('Document unavailable');
    return bytes;
  }

  @override
  Future<Uint8List> readNative(String path) async {
    attempts.add('native');
    throw const FileSystemException('Unexpected fallback to native File');
  }
}

void main() {
  late TestIsarHarness h;
  late EditorPreferencesRepository preferences;
  late VideoRepository video;

  setUp(() async {
    h = await TestIsarHarness.open();
    preferences = EditorPreferencesRepository(h.isar);
    video = VideoRepository(preferences);
  });

  tearDown(() async => h.close());

  test('missing old Android cache secondary cannot block editor initialization',
      () async {
    const collectionId = 901;
    const lostPath =
        '/data/user/0/org.malayalamsubtitles.studio/code_cache/extracted_subtitle_901_missing.srt';
    await preferences.saveSecondarySubtitlePath(collectionId, lostPath);
    await preferences.setSecondaryIsOriginal(collectionId, false);

    expect(await video.loadSavedSecondarySubtitle(collectionId), isNull);
    expect(await preferences.getSecondarySubtitlePath(collectionId), isNull);
    expect(await video.loadSavedSecondarySubtitle(collectionId), isNull);
  });

  test('missing user-chosen secondary is skipped without destroying its path',
      () async {
    const collectionId = 902;
    final missing = '${h.directory.path}/user_can_reconnect.srt';
    await preferences.saveSecondarySubtitlePath(collectionId, missing);
    expect(await video.loadSavedSecondarySubtitle(collectionId), isNull);
    expect(await preferences.getSecondarySubtitlePath(collectionId), missing);
  });

  test('durable external secondary still loads normally', () async {
    const collectionId = 903;
    final file = File('${h.directory.path}/secondary.srt');
    await file.writeAsString(
        '1\n00:00:01,000 --> 00:00:02,000\nHello world\n');
    await preferences.saveSecondarySubtitlePath(collectionId, file.path);
    final data = await video.loadSavedSecondarySubtitle(collectionId);
    expect(data, isNotNull);
    expect(data!.useOriginal, isFalse);
    expect(data.subtitles, hasLength(1));
    expect(data.subtitles!.first.text, contains('Hello world'));
    expect(await preferences.getSecondarySubtitlePath(collectionId), file.path);
  });

  test('direct SAF secondary uses typed reader without native fallback',
      () async {
    const collectionId = 904;
    const uri =
        'content://com.example.documents/document/primary%3AMovies%2Fsubs.srt';
    const content = '1\n00:00:01,000 --> 00:00:02,000\nSAF subtitle\n';
    final bytes = _FakeDocumentBytes()
      ..documents[uri] = Uint8List.fromList(utf8.encode(content));
    final repository = VideoRepository(preferences,
      secondaryReader: SecondarySubtitleDocumentReader(byteSource: bytes));
    await preferences.saveSecondarySubtitlePath(collectionId, uri);

    final data = await repository.loadSavedSecondarySubtitle(collectionId);
    expect(data, isNotNull);
    expect(data!.externalPath, uri);
    expect(data.subtitles!.single.text, 'SAF subtitle');
    expect(bytes.attempts, ['document']);
    expect(await preferences.getSecondarySubtitlePath(collectionId), uri);
  });

  test('revoked SAF secondary is optional and keeps reconnectable URI',
      () async {
    const collectionId = 905;
    const uri = 'content://com.example.documents/document/id%3Asecondary.srt';
    final bytes = _FakeDocumentBytes()..revoked = true;
    final repository = VideoRepository(preferences,
      secondaryReader: SecondarySubtitleDocumentReader(byteSource: bytes));
    await preferences.saveSecondarySubtitlePath(collectionId, uri);
    await preferences.setSecondaryIsOriginal(collectionId, false);

    expect(await repository.loadSavedSecondarySubtitle(collectionId), isNull);
    expect(bytes.attempts, ['document']);
    expect(await preferences.getSecondarySubtitlePath(collectionId), uri);
    // A later valid grant can restore the same originally selected source.
    bytes.revoked = false;
    bytes.documents[uri] = Uint8List.fromList(utf8.encode(
        '1\n00:00:01,000 --> 00:00:02,000\nRecovered\n'));
    final recovered = await repository.loadSavedSecondarySubtitle(collectionId);
    expect(recovered!.subtitles!.single.text, 'Recovered');
    expect(await preferences.getSecondarySubtitlePath(collectionId), uri);
  });

}
