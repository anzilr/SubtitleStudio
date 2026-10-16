import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/repositories/editor_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/video_repository.dart';
import 'support/test_isar_harness.dart';

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
        '1\\n00:00:01,000 --> 00:00:02,000\\nHello world\\n');
    await preferences.saveSecondarySubtitlePath(collectionId, file.path);
    final data = await video.loadSavedSecondarySubtitle(collectionId);
    expect(data, isNotNull);
    expect(data!.useOriginal, isFalse);
    expect(data.subtitles, hasLength(1));
    expect(data.subtitles!.first.text, contains('Hello world'));
    expect(await preferences.getSecondarySubtitlePath(collectionId), file.path);
  });
}
