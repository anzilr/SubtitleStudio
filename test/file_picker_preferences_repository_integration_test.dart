import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/file_picker_preferences_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness harness;
  bool harnessOpened = false;
  late FilePickerPreferencesRepository repository;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = FilePickerPreferencesRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('FilePickerPreferencesRepository', () {
    test('starts with no last-used directory', () async {
      expect(await repository.getLastUsedDirectory(), isNull);
    });

    test('round-trips and clears last-used directory', () async {
      await repository.setLastUsedDirectory('/tmp/subtitles');
      expect(
        await repository.getLastUsedDirectory(),
        '/tmp/subtitles',
      );

      await repository.setLastUsedDirectory(null);
      expect(await repository.getLastUsedDirectory(), isNull);
    });
  });
}
