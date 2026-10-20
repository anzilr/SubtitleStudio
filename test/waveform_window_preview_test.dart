import 'dart:typed_data';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_window_preview_painter.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_window_preview.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';

void main() {
  testWidgets('paint callback confirms a nonempty preview canvas',
      (tester) async {
    final preview = WaveformWindowPreview.fromPcm(
      start: const Duration(minutes: 30),
      pcm: Int16List.fromList([-1000, 32767, -32768, 2000]),
      sampleRate: 4, bucketCount: 2,
    );
    var paints = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 240, height: 60,
          child: CustomPaint(
            painter: WaveformWindowPreviewPainter(
              preview: preview,
              color: Colors.teal,
              onPaint: () => paints++,
            ),
          ),
        ),
      ),
    ));
    expect(paints, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  test('zero-size canvas does not report preview paint', () {
    final preview = WaveformWindowPreview.fromPcm(
      start: Duration.zero,
      pcm: Int16List.fromList([1, -1]),
      sampleRate: 2,
    );
    var callbackCount = 0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    WaveformWindowPreviewPainter(
      preview: preview, color: Colors.teal,
      onPaint: () => callbackCount++,
    ).paint(canvas, Size.zero);
    recorder.endRecording().dispose();
    expect(callbackCount, 0);
  });

  test('preview duration is absolute and preserves signed transients', () {
    final pcm = Int16List.fromList([
      0, 100, 32767, -32768, 0, 0, -12000, 0,
    ]);
    final preview = WaveformWindowPreview.fromPcm(
      start: const Duration(minutes: 30),
      pcm: pcm, sampleRate: 8, bucketCount: 2,
    );
    expect(preview.start, const Duration(minutes: 30));
    expect(preview.end, const Duration(minutes: 30, seconds: 1));
    expect(preview.minima.first, -1);
    expect(preview.maxima.first, 32767 / 32768.0);
    expect(preview.minima.last, -12000 / 32768.0);
    expect(preview.maxima.last, 0);
    expect(preview.minima.length, 2);
    expect(preview.maxima.length, 2);
    expect(WaveformLoading('a', windowPreview: preview).props,
        contains(preview));
  });

  test('preview never allocates more than its bounded display buckets', () {
    final pcm = Int16List(82680);
    pcm[82679] = 32767;
    final preview = WaveformWindowPreview.fromPcm(
      start: Duration.zero, pcm: pcm, sampleRate: 2756,
    );
    expect(preview.minima.length, 256);
    expect(preview.maxima.last, 32767 / 32768.0);
    expect(preview.end, const Duration(seconds: 30));
    expect(() => preview.maxima.add(1), throwsUnsupportedError);
  });

  test('invalid or empty preview data is rejected', () {
    expect(() => WaveformWindowPreview.fromPcm(
      start: const Duration(seconds: -1),
      pcm: Int16List.fromList([1]), sampleRate: 1,
    ), throwsArgumentError);
    expect(() => WaveformWindowPreview.fromPcm(
      start: Duration.zero, pcm: Int16List(0), sampleRate: 2756,
    ), throwsArgumentError);
    expect(() => WaveformWindowPreview.fromPcm(
      start: Duration.zero, pcm: Int16List.fromList([1]),
      sampleRate: 2756, bucketCount: 1025,
    ), throwsArgumentError);
  });
}
