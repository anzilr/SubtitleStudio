import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_tile_source.dart';
import 'package:subtitle_studio/features/waveform/services/zoom_buffer_generator.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_painter.dart';

class _Prefs implements WaveformPreferencesRepository {
  @override
  Future<WaveformGenerationConfig> getGenerationConfig() async =>
      const WaveformGenerationConfig(
          maxPixelsForDetailedView: 1024,
          sampleRateFactor: 16, zoomMultiplier: 1.5);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WaveformData _pcm({int size = 4096}) => WaveformData(
  channels: 2, sampleRate: 3000, totalSamples: size,
  rawSamples: [
    Int16List.fromList(List<int>.generate(size, (i) {
      if (i % 89 == 0) return -32768;
      if (i % 97 == 0) return 32767;
      return (i * 149 % 56001) - 28000;
    })),
    Int16List.fromList(List<int>.generate(size,
        (i) => i % 101 == 0 ? 32767 : (i * 211 % 50000) - 25000)),
  ],
);

Future<List<ZoomLevel>> _eager(WaveformData pcm) async {
  final generator = ZoomBufferGenerator(_Prefs());
  return generator.applyScaling(await generator.generateZoomLevels(pcm));
}

void _compare(WaveformTileSource source, ZoomLevel level,
    {required int first, required int count}) {
  final tiles = source.visibleTiles(
    firstPixel: first, visiblePixels: count,
    samplesPerPixel: level.samplesPerPixel);
  var compared = 0;
  for (final tile in tiles) {
    for (var i = 0; i < tile.pixelCount; i++) {
      final pixel = tile.firstPixel + i;
      if (pixel < first || pixel >= first + count) continue;
      for (var channel = 0; channel < level.channels; channel++) {
        final actual = tile.channels[channel][i];
        final expected = level.data[channel][pixel];
        expect(actual.min, closeTo(expected.min, 1e-12),
            reason: 'channel ' + channel.toString() + ' min pixel ' +
                pixel.toString());
        expect(actual.max, closeTo(expected.max, 1e-12),
            reason: 'channel ' + channel.toString() + ' max pixel ' +
                pixel.toString());
        compared++;
      }
    }
  }
  expect(compared, greaterThan(0));
}

Future<Uint8List> _render(WaveformPainter painter) async {
  const size = Size(220, 92);
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = Uint8List.fromList(bytes!.buffer.asUint8List(
      bytes.offsetInBytes, bytes.lengthInBytes));
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  test('eager/tiled channel peaks match across zoom levels and viewports',
      () async {
    final pcm = _pcm();
    final levels = await _eager(pcm);
    final tiles = WaveformTileSource(
      data: pcm, sourceIdentity: 'compare', tileWidth: 97, maxTiles: 12);
    expect(levels.length, greaterThan(3));
    for (final index in <int>{0, levels.length ~/ 2, levels.length - 1}) {
      final level = levels[index];
      final width = level.pixelCount;
      _compare(tiles, level, first: 0, count: width.clamp(0, 220));
      if (width > 170) {
        _compare(tiles, level, first: width - 170, count: 170);
      }
    }
    expect(tiles.cachedTileCount, lessThanOrEqualTo(12));
  });

  testWidgets('tiled and legacy painter images are identical at scroll zoom',
      (tester) async {
    final pcm = _pcm();
    final levels = await _eager(pcm);
    final tiles = WaveformTileSource(
      data: pcm, sourceIdentity: 'paint', tileWidth: 71, maxTiles: 12);
    for (final level in [levels.first, levels[levels.length ~/ 2]]) {
      for (final offset in [0.0, 27.25, 110.5]) {
        if (level.pixelCount < offset + 220) continue;
        WaveformPainter make(WaveformTileSource? src) => WaveformPainter(
          zoomLevel: level,
          tileSource: src,
          scrollOffset: offset,
          playbackPosition: Duration.zero,
          subtitles: const [],
          sampleRate: pcm.sampleRate,
          samplesPerPixel: level.samplesPerPixel,
          showWaveformOnly: true,
          showPlaybackIndicator: false,
          waveformColor: Colors.teal,
          backgroundColor: Colors.black,
        );
        final eager = await _render(make(null));
        final tiled = await _render(make(tiles));
        expect(tiled, orderedEquals(eager), reason:
            'sample-per-pixel ' + level.samplesPerPixel.toString() +
            ' offset ' + offset.toString());
      }
    }
    expect(tiles.cachedTileCount, lessThanOrEqualTo(12));
  });

  test('one-million-sample track remains bounded at every viewport', () {
    final source = WaveformTileSource(
      data: WaveformData(
        channels: 1, sampleRate: 3000, totalSamples: 1000000,
        rawSamples: [Int16List(1000000)]),
      sourceIdentity: 'large-track', tileWidth: 128, maxTiles: 8,
    );
    for (var first = 0; first < 80000; first += 1150) {
      source.visibleTiles(
        firstPixel: first, visiblePixels: 900, samplesPerPixel: 2);
      expect(source.cachedTileCount, lessThanOrEqualTo(8));
    }
    final count = source.computedTileCount;
    source.visibleTiles(firstPixel: 0, visiblePixels: 900, samplesPerPixel: 2);
    expect(source.computedTileCount, greaterThan(count));
  });
}
