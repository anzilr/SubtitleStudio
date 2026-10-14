import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_tile_source.dart';

WaveformData audio(List<List<int>> values) => WaveformData(
  channels: values.length, sampleRate: 8,
  totalSamples: values.first.length,
  rawSamples: values.map((v) => Int16List.fromList(v)).toList(),
);

void main() {
  test('signed peaks survive visible-range aggregation and scaling', () {
    final source = WaveformTileSource(
      data: audio([[-32768, 0, 12000, -20000, 0, 0, 32767, 0]]),
      sourceIdentity: 'mono', tileWidth: 2, maxTiles: 2,
    );
    final tiles = source.visibleTiles(
      firstPixel: 0, visiblePixels: 4, samplesPerPixel: 2,
    );
    expect(tiles.length, 2);
    expect(tiles.first.channels.single.first.min, closeTo(-1, 0.00001));
    expect(tiles.first.channels.single.first.max, 0);
    expect(tiles.first.channels.single[1].min, lessThan(0));
    expect(tiles.first.channels.single[1].max, greaterThan(0));
    expect(tiles.last.channels.single[1].max, closeTo(1, 0.0001));
    source.visibleTiles(firstPixel: 0, visiblePixels: 4, samplesPerPixel: 2);
    expect(source.computedTileCount, 2);
  });

  test('stereo channels and partial final tiles are independent', () {
    final source = WaveformTileSource(
      data: audio([[-32768, 0, 0, 0, 0], [0, 0, 0, 0, 32767]]),
      sourceIdentity: 'stereo', tileWidth: 2,
    );
    final tiles = source.visibleTiles(
      firstPixel: 2, visiblePixels: 5, samplesPerPixel: 1);
    expect(tiles.length, 2);
    expect(tiles.last.pixelCount, 1);
    expect(tiles.last.channels.first.single.max, 0);
    expect(tiles.last.channels[1].single.max, closeTo(1, 0.0001));
    expect(source.visibleTiles(
      firstPixel: 50, visiblePixels: 1, samplesPerPixel: 1), isEmpty);
  });

  test('LRU capacity bounded across zoom and source changes', () {
    final source = WaveformTileSource(
      data: audio([List<int>.filled(32, 100)]),
      sourceIdentity: 'one', tileWidth: 2, maxTiles: 2,
    );
    for (final start in [0, 2, 0, 4, 2]) {
      source.visibleTiles(
        firstPixel: start, visiblePixels: 2, samplesPerPixel: 1);
    }
    expect(source.cachedTileCount, 2);
    expect(source.computedTileCount, 4);
    source.visibleTiles(
      firstPixel: 0, visiblePixels: 2, samplesPerPixel: 2);
    expect(source.computedTileCount, 5);
    expect(source.cachedTileCount, 2);
    source.replaceSource(audio([List<int>.filled(32, -100)]),
      sourceIdentity: 'two');
    expect(source.cachedTileCount, 0);
    expect(source.visibleTiles(firstPixel: 0,
      visiblePixels: 2, samplesPerPixel: 1).first.channels.first.first.min,
      lessThan(0));
  });

  test('bad metadata, invalid viewport and mutation are rejected', () {
    expect(() => WaveformTileSource(
      data: WaveformData(channels: 2, sampleRate: 8,
        totalSamples: 3, rawSamples: [Int16List(3)]),
      sourceIdentity: 'invalid'), throwsArgumentError);
    final source = WaveformTileSource(
      data: audio([[1, 2, 3]]), sourceIdentity: 'valid',
    );
    expect(() => source.visibleTiles(
      firstPixel: 0, visiblePixels: 8193, samplesPerPixel: 1),
      throwsRangeError);
    final list = source.visibleTiles(
      firstPixel: 0, visiblePixels: 3, samplesPerPixel: 1);
    expect(() => list.add(list.first), throwsUnsupportedError);
    expect(() => list.first.channels.first.add(
      const WaveformSample(0, 1)), throwsUnsupportedError);
  });
}
