import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness harness;
  bool harnessOpened = false;
  late WaveformPreferencesRepository repository;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = WaveformPreferencesRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('WaveformPreferencesRepository', () {
    test('preserves legacy generation defaults', () async {
      final config = await repository.getGenerationConfig();

      expect(config.maxPixelsForDetailedView, 500000);
      expect(config.sampleRateFactor, 16);
      expect(config.zoomMultiplier, 1.25);
    });

    test('loads configured generation settings', () async {
      await PreferencesStore(harness.isar).update((preferences) {
        preferences.waveformMaxPixels = 250000;
        preferences.waveformSampleRateFactor = 8;
        preferences.waveformZoomMultiplier = 1.4;
      });

      final config = await repository.getGenerationConfig();

      expect(config.maxPixelsForDetailedView, 250000);
      expect(config.sampleRateFactor, 8);
      expect(config.zoomMultiplier, 1.4);
    });

    test('round-trips typed waveform cache metadata and clears it', () async {
      await repository.saveWaveformCache(
        subtitleCollectionId: 42,
        pcmPath: '/tmp/waveform.raw',
        sampleRate: 44100,
        totalSamples: 123456,
        channels: 1,
      );

      final cache = await repository.getWaveformCache(42);

      expect(cache, isNotNull);
      expect(cache!.pcmPath, '/tmp/waveform.raw');
      expect(cache.sampleRate, 44100);
      expect(cache.totalSamples, 123456);
      expect(cache.channels, 1);
      expect(cache.generatedAt, isNotNull);

      await repository.clearWaveformCache(42);
      expect(await repository.getWaveformCache(42), isNull);
    });

    test('round-trips typed zoom preferences', () async {
      await repository.saveWaveformZoomLevels(
        subtitleCollectionId: 7,
        zoomIndex: 4,
        verticalZoom: 1.8,
      );

      final zoom = await repository.getWaveformZoomLevels(7);

      expect(zoom, isNotNull);
      expect(zoom!.zoomIndex, 4);
      expect(zoom.verticalZoom, 1.8);
    });
  });
}
