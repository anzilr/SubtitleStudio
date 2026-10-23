import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_tile_source.dart';
import 'package:subtitle_studio/features/waveform/services/zoom_buffer_generator.dart';

class _GenerationPreferences implements WaveformPreferencesRepository {
  @override
  Future<WaveformGenerationConfig> getGenerationConfig() async =>
      const WaveformGenerationConfig(
        maxPixelsForDetailedView: 2048,
        sampleRateFactor: 16,
        zoomMultiplier: 1.4,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('repeatable eager vs visible-range allocation/timing diagnostic',
      () async {
    // Deterministic synthetic PCM; no codecs, devices or network necessary.
    const count = 180000;
    final pcm = WaveformData(
      channels: 2, sampleRate: 3000, totalSamples: count,
      rawSamples: [
        Int16List.fromList(List<int>.generate(
          count, (i) => (i * 313 % 60000) - 30000)),
        Int16List.fromList(List<int>.generate(
          count, (i) => (i * 211 % 50000) - 25000)),
      ],
    );
    final eagerTimer = Stopwatch()..start();
    final generator = ZoomBufferGenerator(_GenerationPreferences());
    final levels = generator.applyScaling(
      await generator.generateZoomLevels(pcm));
    eagerTimer.stop();
    final eagerBuckets = levels.fold<int>(0,
      (acc, level) => acc + level.pixelCount * level.channels);

    final source = WaveformTileSource(
      data: pcm, sourceIdentity: 'diagnostic-v1',
      tileWidth: 256, maxTiles: 8);
    final tileTimer = Stopwatch()..start();
    final level = levels[levels.length ~/ 2];
    final first = level.pixelCount > 2000 ? 1000 : 0;
    final requested = source.visibleTiles(
      firstPixel: first, visiblePixels: 900,
      samplesPerPixel: level.samplesPerPixel);
    tileTimer.stop();
    final tileBuckets = requested.fold<int>(0,
      (acc, tile) => acc + tile.pixelCount * tile.channels.length);

    debugPrint('Checkpoint78 synthetic diagnostic '
        'eager_ms=' + eagerTimer.elapsedMilliseconds.toString() +
        ' visible_tile_ms=' + tileTimer.elapsedMilliseconds.toString() +
        ' eager_buckets=' + eagerBuckets.toString() +
        ' visible_buckets=' + tileBuckets.toString());

    expect(levels, isNotEmpty);
    expect(eagerBuckets, greaterThan(tileBuckets));
    expect(tileBuckets, lessThanOrEqualTo((900 + 512) * 2));
    expect(source.cachedTileCount, lessThanOrEqualTo(8));
  });
}
