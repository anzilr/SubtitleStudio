import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/database/stores/video_preferences_store.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness harness;

  setUp(() async {
    harness = await TestIsarHarness.open();
  });

  tearDown(() async {
    await harness.close();
  });

  group('PreferencesStore', () {
    test('findFirst does not create a preferences row', () async {
      final store = PreferencesStore(harness.isar);

      expect(await store.findFirst(), isNull);
      expect(await harness.isar.preferences.where().findAll(), isEmpty);
    });

    test('concurrent getOrCreate calls keep a single row', () async {
      final store = PreferencesStore(harness.isar);

      await Future.wait(
        List.generate(20, (_) => store.getOrCreate()),
      );

      final all = await harness.isar.preferences.where().findAll();

      expect(all, hasLength(1));
      expect(all.single.autoSave, isTrue);
    });

    test('concurrent atomic updates do not lose mutations', () async {
      final store = PreferencesStore(harness.isar);
      final initial = await store.getOrCreate();
      expect(initial.maxCheckpoints, 25);

      await Future.wait(
        List.generate(
          20,
          (_) => store.update(
            (preferences) => preferences.maxCheckpoints += 1,
          ),
        ),
      );

      final all = await harness.isar.preferences.where().findAll();

      expect(all, hasLength(1));
      expect(all.single.maxCheckpoints, 45);
    });
  });

  group('VideoPreferencesStore', () {
    test('concurrent getOrCreate calls keep one row per subtitle', () async {
      final store = VideoPreferencesStore(harness.isar);

      await Future.wait(
        List.generate(20, (_) => store.getOrCreate(42)),
      );

      final all = await harness.isar.videoPreferences.where().findAll();

      expect(all, hasLength(1));
      expect(all.single.subtitleCollectionId, 42);
    });

    test('updates keep a single row for the same subtitle collection', () async {
      final store = VideoPreferencesStore(harness.isar);

      await Future.wait(
        List.generate(
          20,
          (index) => store.update(42, (preferences) {
            preferences.waveformZoomIndex = index;
          }),
        ),
      );

      final all = await harness.isar.videoPreferences.where().findAll();

      expect(all, hasLength(1));
      expect(all.single.subtitleCollectionId, 42);
      expect(all.single.waveformZoomIndex, isNotNull);
    });

    test('keeps independent rows for different subtitle collections', () async {
      final store = VideoPreferencesStore(harness.isar);

      await Future.wait([
        store.update(10, (preferences) {
          preferences.waveformZoomIndex = 2;
        }),
        store.update(20, (preferences) {
          preferences.waveformZoomIndex = 5;
        }),
      ]);

      final first = await harness.isar.videoPreferences
          .filter()
          .subtitleCollectionIdEqualTo(10)
          .findFirst();
      final second = await harness.isar.videoPreferences
          .filter()
          .subtitleCollectionIdEqualTo(20)
          .findFirst();

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.waveformZoomIndex, 2);
      expect(second!.waveformZoomIndex, 5);
    });
  });
}
