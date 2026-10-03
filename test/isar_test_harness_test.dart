import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness harness;

  setUp(() async {
    harness = await TestIsarHarness.open();
  });

  tearDown(() async {
    await harness.close();
  });

  group('TestIsarHarness', () {
    test('opens production schemas and persists a real transaction', () async {
      final preferences = Preferences(autoSave: true)
        ..themeMode = 'dark'
        ..maxCheckpoints = 17;

      await harness.isar.writeTxn(() async {
        await harness.isar.preferences.put(preferences);
      });

      final stored = await harness.isar.preferences.where().findFirst();

      expect(stored, isNotNull);
      expect(stored!.id, isNot(Isar.autoIncrement));
      expect(stored.autoSave, isTrue);
      expect(stored.themeMode, 'dark');
      expect(stored.maxCheckpoints, 17);
    });

    test('starts each test with a fresh empty database', () async {
      final preferences = await harness.isar.preferences.where().findAll();
      final videoPreferences =
          await harness.isar.videoPreferences.where().findAll();
      final checkpoints = await harness.isar.checkpoints.where().findAll();

      expect(preferences, isEmpty);
      expect(videoPreferences, isEmpty);
      expect(checkpoints, isEmpty);
    });
  });
}
