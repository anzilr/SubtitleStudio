import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_tile_source.dart';
import 'package:subtitle_studio/features/waveform/services/zoom_buffer_generator.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';

class _Preferences implements WaveformPreferencesRepository {
  @override
  Future<WaveformGenerationConfig> getGenerationConfig() async =>
      const WaveformGenerationConfig(
        maxPixelsForDetailedView: 1024,
        sampleRateFactor: 16,
        zoomMultiplier: 1.5,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WaveformData _pcm(int count, {int channels = 1}) => WaveformData(
  channels: channels,
  sampleRate: 3000,
  totalSamples: count,
  rawSamples: List.generate(channels,
      (ch) => Int16List.fromList(List<int>.generate(
        count, (i) => (i * (ch + 7) % 60000) - 30000))),
);

void main() {
  test('metadata has same zoom geometry but no full-track channel arrays',
      () async {
    for (final count in [0, 1, 17, 4096, 40001]) {
      for (final channels in [1, 2]) {
        final data = _pcm(count, channels: channels);
        final generator = ZoomBufferGenerator(_Preferences());
        final actual = await generator.prepareZoomLevels(
          data, tiled: true);
        final eager = await generator.prepareZoomLevels(
          data, tiled: false);
        expect(actual.length, eager.length);
        expect(actual, isNotEmpty);
        for (var i = 0; i < actual.length; i++) {
          final metadata = actual[i];
          final materialized = eager[i];
          expect(metadata.isMetadataOnly, isTrue);
          expect(metadata.samplesPerPixel, materialized.samplesPerPixel);
          expect(metadata.pixelCount, materialized.pixelCount);
          expect(metadata.channels, channels);
          expect(metadata.data, isEmpty);
          expect(metadata.getChannelData(0), isNull);
          expect(metadata.getSample(0, 0), isNull);
          expect(materialized.isMetadataOnly, isFalse);
        }
        final buffer = WaveformBuffer(rawData: data, zoomLevels: actual);
        final ready = WaveformReady(buffer: buffer, currentZoomIndex: 0);
        expect(ready.currentZoomLevel.isMetadataOnly, isTrue);
        expect(ready.totalWidth,
            closeTo(count / actual.first.samplesPerPixel, 0.00001));
        final copy = ready.copyWith(
          currentZoomIndex: actual.length - 1, scrollPosition: 40.25);
        expect(copy.samplesPerPixel, actual.last.samplesPerPixel);
        expect(copy.currentZoomLevel.pixelCount, actual.last.pixelCount);
        expect(copy.timeToPixel(const Duration(seconds: 1)),
            closeTo(3000 / copy.samplesPerPixel, 0.51));
        expect(copy.pixelToTime(copy.timeToPixel(
            const Duration(milliseconds: 500))).inMilliseconds,
            closeTo(500, 1000));
      }
    }
  });

  test('large metadata ladder avoids allocation proportional to duration',
      () async {
    // This sentinel contains no PCM samples. Metadata preparation must
    // NEVER try to inspect or allocate those samples.
    const count = 900000000;
    final declared = WaveformData(
      channels: 2, sampleRate: 3000, totalSamples: count,
      rawSamples: [Int16List(0), Int16List(0)],
    );
    final zooms = await ZoomBufferGenerator(_Preferences())
        .prepareZoomLevels(declared, tiled: true);
    expect(zooms, isNotEmpty);
    expect(zooms.length, lessThan(150));
    expect(zooms.every((level) => level.data.isEmpty), isTrue);
    expect(zooms.every((level) => level.isMetadataOnly), isTrue);
    expect(zooms.every((level) => level.pixelCount > 0), isTrue);
    expect(zooms.every((level) => level.channels == 2), isTrue);
  });

  test('tiles from metadata levels preserve samples and zoom lengths',
      () async {
    final pcm = _pcm(12000, channels: 2);
    final generator = ZoomBufferGenerator(_Preferences());
    final metadata = await generator.prepareZoomLevels(pcm, tiled: true);
    final eager = await generator.prepareZoomLevels(pcm, tiled: false);
    final tiles = WaveformTileSource(
      data: pcm, sourceIdentity: 'metadata', tileWidth: 71, maxTiles: 16);
    for (final i in [0, metadata.length ~/ 2, metadata.length - 1]) {
      final meta = metadata[i];
      final reference = eager[i];
      final width = meta.pixelCount < 250 ? meta.pixelCount : 250;
      final tileViews = tiles.visibleTiles(firstPixel: 0,
          visiblePixels: width, samplesPerPixel: meta.samplesPerPixel);
      expect(tileViews, isNotEmpty);
      for (final tile in tileViews) {
        for (var k = 0; k < tile.pixelCount; k++) {
          final position = tile.firstPixel + k;
          if (position >= width) continue;
          for (var channel = 0; channel < 2; channel++) {
            final expected = reference.getSample(channel, position)!;
            final actual = tile.channels[channel][k];
            expect(actual.min, closeTo(expected.min, 1e-12));
            expect(actual.max, closeTo(expected.max, 1e-12));
          }
        }
      }
    }
    expect(tiles.cachedTileCount, lessThanOrEqualTo(16));
  });

  test('invalid metadata-level widths and channels rejected', () {
    expect(() => ZoomLevel.metadata(
      samplesPerPixel: 0, pixelCount: 100, channels: 1),
      throwsArgumentError);
    expect(() => ZoomLevel.metadata(
      samplesPerPixel: 1, pixelCount: -1, channels: 1),
      throwsArgumentError);
    expect(() => ZoomLevel.metadata(
      samplesPerPixel: 1, pixelCount: 10, channels: 0),
      throwsArgumentError);
  });
}
