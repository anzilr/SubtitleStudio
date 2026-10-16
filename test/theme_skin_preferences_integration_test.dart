import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/themes/theme_preferences_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness harness;

  setUp(() async => harness = await TestIsarHarness.open());
  tearDown(() async => harness.close());

  test('existing preferences have a nullable skin field without data loss',
      () async {
    final legacy = Preferences(autoSave: false)
      ..themeMode = 'classic'
      ..maxCheckpoints = 37
      ..appFontName = 'CustomFont.ttf';
    await harness.isar.writeTxn(() async {
      await harness.isar.preferences.put(legacy);
    });

    final repo = ThemePreferencesRepository(harness.isar);
    final before = await repo.load();
    expect(before.exists, isTrue);
    expect(before.skinId, isNull);
    expect(before.themeMode, 'classic');
    expect(before.fontName, 'CustomFont.ttf');

    await repo.saveSkinId('builtin.carbonJade');
    final after = await harness.isar.preferences.where().findFirst();
    expect(after, isNotNull);
    expect(after!.id, legacy.id);
    expect(after.themeMode, 'classic');
    expect(after.skinId, 'builtin.carbonJade');
    expect(after.maxCheckpoints, 37);
    expect(after.autoSave, isFalse);
    expect(after.appFontName, 'CustomFont.ttf');
  });

  test('empty install reads without creating a Preferences row', () async {
    final repo = ThemePreferencesRepository(harness.isar);
    final snapshot = await repo.load();
    expect(snapshot.exists, isFalse);
    expect(snapshot.skinId, isNull);
    expect(snapshot.themeMode, isNull);
    expect(await harness.isar.preferences.where().count(), 0);
  });

  test('skin and mode are persisted independently, including community IDs',
      () async {
    final repo = ThemePreferencesRepository(harness.isar);
    await Future.wait([
      repo.saveSkinId('community.community-theme-001'),
      repo.saveThemeMode('dark'),
    ]);
    var prefs = await harness.isar.preferences.where().findAll();
    expect(prefs, hasLength(1));
    expect(prefs.single.skinId, 'community.community-theme-001');
    expect(prefs.single.themeMode, 'dark');

    await repo.saveThemeMode('classic');
    final afterMode = await repo.load();
    expect(afterMode.skinId, 'community.community-theme-001');
    expect(afterMode.themeMode, 'classic');

    await repo.saveSkinId('builtin.copperCinema');
    final afterSkin = await repo.load();
    expect(afterSkin.skinId, 'builtin.copperCinema');
    expect(afterSkin.themeMode, 'classic');
    prefs = await harness.isar.preferences.where().findAll();
    expect(prefs, hasLength(1));
  });
}
