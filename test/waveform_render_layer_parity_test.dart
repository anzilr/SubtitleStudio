import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_painter.dart';

WaveformPainter _make(Duration position) => WaveformPainter(
  zoomLevel: ZoomLevel(
    samplesPerPixel: 8,
    data: [
      List<WaveformSample>.generate(100, (i) =>
          WaveformSample(-0.3 - i % 3 * 0.1, 0.2 + i % 5 * 0.1)),
    ],
  ),
  scrollOffset: 2.25,
  playbackPosition: position,
  subtitles: const [],
  sampleRate: 2000,
  samplesPerPixel: 8,
  waveformColor: Colors.teal,
  backgroundColor: Colors.black,
  playbackColor: Colors.red,
  showWaveformOnly: true,
  showPlaybackIndicator: true,
);

Future<Uint8List> _paintPixels(
    WaveformPainter painter, {required bool split}) async {
  const size = Size(180, 110);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (split) {
    painter.forLayer(WaveformPaintLayer.scenery).paint(canvas, size);
    painter.forLayer(WaveformPaintLayer.overlays).paint(canvas, size);
  } else {
    painter.paint(canvas, size);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(180, 110);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  testWidgets('split painter exactly preserves single-pass rendered pixels',
      (tester) async {
    for (final position in [
      Duration.zero,
      const Duration(milliseconds: 140),
      const Duration(milliseconds: 290),
    ]) {
      final base = _make(position);
      final result = await tester.runAsync(() async => (
        combined: await _paintPixels(base, split: false),
        split: await _paintPixels(base, split: true),
      ));
      expect(result, isNotNull);
      expect(result!.split, orderedEquals(result.combined),
          reason: 'playhead ' + position.inMilliseconds.toString());
    }
  });

  test('changing playhead invalidates only the dynamic render layer', () {
    final before = _make(Duration.zero);
    final after = _make(const Duration(milliseconds: 180));
    expect(after.forLayer(WaveformPaintLayer.scenery).shouldRepaint(
      before.forLayer(WaveformPaintLayer.scenery)), isFalse);
    expect(after.forLayer(WaveformPaintLayer.overlays).shouldRepaint(
      before.forLayer(WaveformPaintLayer.overlays)), isTrue);
    expect(after.shouldRepaint(before), isTrue);
  });

  test('scroll and waveform zoom invalidate scenery and overlay layers', () {
    final before = _make(Duration.zero);
    final scrolled = WaveformPainter(
      zoomLevel: before.zoomLevel,
      scrollOffset: before.scrollOffset + 5,
      playbackPosition: before.playbackPosition,
      subtitles: before.subtitles,
      sampleRate: before.sampleRate,
      samplesPerPixel: before.samplesPerPixel,
      showWaveformOnly: true,
    );
    expect(scrolled.forLayer(WaveformPaintLayer.scenery).shouldRepaint(
      before.forLayer(WaveformPaintLayer.scenery)), isTrue);
    expect(scrolled.forLayer(WaveformPaintLayer.overlays).shouldRepaint(
      before.forLayer(WaveformPaintLayer.overlays)), isTrue);
  });
}
