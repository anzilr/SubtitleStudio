import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/core/file_access/secondary_subtitle_storage.dart';

void main() {
  test('legacy code_cache extracted subtitles are ephemeral, user files are not',
      () {
    expect(SecondarySubtitleStorage.isLegacyEphemeralExtraction(
        '/data/user/0/app/code_cache/extracted_subtitle_1_Untitled.srt'), isTrue);
    expect(SecondarySubtitleStorage.isLegacyEphemeralExtraction(
        '/data/user/0/app/cache/extracted_subtitle_1_Untitled.srt'), isTrue);
    expect(SecondarySubtitleStorage.isOwnedExtraction(
        '/home/user/extracted_subtitle_1_Untitled.srt'), isFalse);
    expect(SecondarySubtitleStorage.isOwnedExtraction(
        '/data/user/0/app/files/secondary_subtitles/extracted_subtitle_1_99.srt'), isTrue);
  });

  test('persistent extraction atomically writes and guards user files', () async {
    final root = await Directory.systemTemp.createTemp('secondary_test_');
    addTearDown(() => root.delete(recursive: true));
    final saved = await SecondarySubtitleStorage.persist(
      supportDirectory: root, collectionId: 1,
      extension: 'srt',
      content: '1\\n00:00:01,000 --> 00:00:02,000\\nExample\\n',
    );
    expect(saved, contains('secondary_subtitles'));
    expect(await File(saved).readAsString(), contains('Example'));
    expect(await File('$saved.writing').exists(), isFalse);
    final userFile = File('${root.path}/extracted_subtitle_1_user.srt');
    await userFile.writeAsString('preserve');
    await SecondarySubtitleStorage.deleteOwnedFileIfPresent(userFile.path);
    expect(await userFile.readAsString(), 'preserve');
    await SecondarySubtitleStorage.deleteOwnedFileIfPresent(saved);
    expect(await File(saved).exists(), isFalse);
  });

  test('invalid extensions never write', () async {
    final root = await Directory.systemTemp.createTemp('secondary_test_');
    addTearDown(() => root.delete(recursive: true));
    await expectLater(SecondarySubtitleStorage.persist(
      supportDirectory: root, collectionId: 1,
      extension: 'exe', content: 'bad',
    ), throwsArgumentError);
  });
}
