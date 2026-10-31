import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/utils/intent_handler.dart';

void main() {
  test('file associations recognize only complete supported extensions', () {
    for (final path in <String>[
      r'C:\Movies\scene.srt',
      '/storage/emulated/0/Download/Scene.SRT',
    ]) {
      expect(IntentHandler.isSrtFile(path), isTrue, reason: path);
      expect(IntentHandler.isMsoneFile(path), isFalse, reason: path);
    }
    for (final path in <String>[
      r'C:\Projects\Movie.msone',
      '/storage/emulated/0/Download/Archive.MSONE',
    ]) {
      expect(IntentHandler.isMsoneFile(path), isTrue, reason: path);
      expect(IntentHandler.isSrtFile(path), isFalse, reason: path);
    }
    for (final path in <String>[
      '/Downloads/subtitle.ass',
      '/Downloads/subtitle.ssa',
      '/Downloads/subtitle.vtt',
      '/Downloads/subtitle.srt.backup',
      '/Downloads/subtitle.msone.tmp',
      '/Downloads/subtitle.srt/other.txt',
      '/Downloads/not-a-subtitle.txt',
    ]) {
      expect(IntentHandler.isSrtFile(path), isFalse, reason: path);
      expect(IntentHandler.isMsoneFile(path), isFalse, reason: path);
    }
    expect(IntentHandler.isSrtFile(null), isFalse);
    expect(IntentHandler.isMsoneFile(null), isFalse);
  });

  test('intent file reader retains bytes for charset selection', () async {
    final folder = await Directory.systemTemp.createTemp('intent_charset_');
    addTearDown(() => folder.delete(recursive: true));
    final file = File(folder.path + Platform.pathSeparator + 'legacy.srt');
    final input = [0x43, 0x61, 0x66, 0xE9, 0x20, 0x93, 0x58, 0x94];
    await file.writeAsBytes(input);
    final info = IntentFileInfo(
      path: file.path,
      originalPath: file.path,
      isContentUri: false,
    );
    expect(await IntentHandler.readBytesFromIntentFile(info), input);
    await expectLater(
      IntentHandler.readContentFromIntentFile(info),
      throwsFormatException,
    );
    final text = await IntentHandler.readContentFromIntentFile(
      info, encoding: 'Windows-1252');
    expect(text, 'Café “X”');
    expect(SubtitleTextCodec.encode(text, encoding: 'Windows-1252'), input);
  });
}
