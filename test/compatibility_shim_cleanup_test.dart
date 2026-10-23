import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtitle import stays typed without obsolete map converters', () {
    final model = File('lib/models/subtitle_import_result.dart').readAsStringSync();
    final repository =
        File('lib/services/subtitle_import_repository.dart').readAsStringSync();

    expect(model, isNot(contains('fromLegacyMap(')));
    expect(model, isNot(contains('toLegacyMap(')));
    expect(repository, contains('return SubtitleImportResult('));
  });

  test('Android picker keeps its URI-only native channel after alias removal', () {
    final picker = File('lib/utils/file_picker_utils_saf.dart').readAsStringSync();
    final handler = File('lib/utils/saf_file_handler.dart').readAsStringSync();
    final native = File(
      'android/app/src/main/kotlin/org/malayalamsubtitles/studio/MainActivity.kt',
    ).readAsStringSync();

    expect(picker, contains('SafFileHandler.openFile('));
    expect(picker, isNot(contains('SafFileHandler.openFileUriOnly(')));
    expect(handler, contains("_channel.invokeMethod('openFileUriOnly'"));
    expect(handler, isNot(contains('static Future<SafFileInfo?> openFileUriOnly(')));
    expect(native, contains('"openFileUriOnly" -> {'));
    expect(native, contains('handleOpenFileUriOnly(call, result)'));
  });
}
