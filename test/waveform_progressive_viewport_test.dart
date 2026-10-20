import 'dart:typed_data';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_progressive_coverage.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_progressive_viewport.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_window_preview.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_sparse_viewport_painter.dart';

WaveformWindowPreview makePreview(Duration start, {int seconds = 30}) {
  final pcm = Int16List.fromList(List.generate(seconds * 10,
      (i) => i.isEven ? -32768 : 32767));
  return WaveformWindowPreview.fromPcm(
    start: start,
    pcm: pcm, sampleRate: 10, bucketCount: 10,
  );
}

void main() {
  test('nonzero absolute windows occupy only their own pixels', () {
    final preview = makePreview(const Duration(minutes: 30));
    final viewport = WaveformProgressiveViewport(
      start: const Duration(minutes: 29, seconds: 30),
      end: const Duration(minutes: 31),
      extents: [
        WaveformProgressiveExtent(
          start: preview.start, end: preview.end, preview: preview),
      ],
    );
    final spans = viewport.project(900);
    expect(spans.length, 3);
    expect(spans.map((span) => span.isKnown).toList(), [false, true, false]);
    expect(spans[0].startPixel, 0);
    expect(spans[0].endPixel, 300);
    expect(spans[1].startPixel, 300);
    expect(spans[1].endPixel, 600);
    expect(spans[2].endPixel, 900);
    expect(spans[0].signedPeaksAt(100), isNull);
    expect(spans[1].signedPeaksAt(400), (-1.0, 32767 / 32768.0));
    expect(spans[2].signedPeaksAt(700), isNull);
    expect(spans[1].signedPeaksAt(600), isNull);
  });

  test('clipped coverage maps signed amplitudes using original time', () {
    final preview = makePreview(const Duration(minutes: 30));
    final viewport = WaveformProgressiveViewport(
      start: const Duration(minutes: 30, seconds: 10),
      end: const Duration(minutes: 30, seconds: 20),
      extents: [
        WaveformProgressiveExtent(
          start: const Duration(minutes: 30, seconds: 10),
          end: const Duration(minutes: 30, seconds: 20),
          preview: preview,
        ),
      ],
    );
    final span = viewport.project(100).single;
    expect(span.startPixel, 0);
    expect(span.endPixel, 100);
    expect(span.signedPeaksAt(20), (-1.0, 32767 / 32768.0));
  });

  test('missing extents remain unknown and overlaps are rejected', () {
    final preview = makePreview(const Duration(seconds: 30));
    final scope = WaveformProgressiveViewport(
      start: Duration.zero,
      end: const Duration(seconds: 90),
      extents: [WaveformProgressiveExtent(
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 60), preview: preview)],
    );
    expect(scope.project(90).map((s) => s.isKnown),
        [false, true, false]);
    final bad = WaveformProgressiveViewport(
      start: Duration.zero,
      end: const Duration(seconds: 60),
      extents: [
        const WaveformProgressiveExtent(
          start: Duration.zero,
          end: Duration(seconds: 40),
          preview: null,
        ),
        const WaveformProgressiveExtent(
          start: Duration(seconds: 30),
          end: Duration(seconds: 60),
          preview: null,
        ),
      ],
    );
    expect(() => bad.project(100), throwsArgumentError);
  });

  test('oversized and malformed viewport parameters fail closed', () {
    final p = WaveformProgressiveViewport(
      start: Duration.zero,
      end: const Duration(seconds: 90),
      extents: const [],
    );
    expect(() => p.project(double.infinity), throwsArgumentError);
    expect(() => p.project(16385), throwsArgumentError);
    expect(() => p.project(0), throwsArgumentError);
    expect(p.project(100).single.isKnown, isFalse);
  });

  testWidgets('sparse viewport actually paints with unknown regions',
      (tester) async {
    final preview = makePreview(const Duration(minutes: 30));
    final viewport = WaveformProgressiveViewport(
      start: const Duration(minutes: 29, seconds: 30),
      end: const Duration(minutes: 31),
      extents: [WaveformProgressiveExtent(
        start: preview.start, end: preview.end, preview: preview)],
    );
    var painted = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SizedBox(width: 270, height: 75, child: CustomPaint(
        painter: WaveformSparseViewportPainter(
          viewport: viewport,
          waveColor: Colors.teal,
          unknownColor: Colors.grey,
          onPaint: () => painted++,
        ),
      )),
    )));
    expect(painted, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  test('zero-sized sparse painter never claims to have drawn', () {
    final viewport = WaveformProgressiveViewport(
      start: Duration.zero,
      end: const Duration(seconds: 30),
      extents: const [],
    );
    var painted = 0;
    final recorder = PictureRecorder();
    WaveformSparseViewportPainter(
      viewport: viewport,
      waveColor: Colors.teal,
      unknownColor: Colors.grey,
      onPaint: () => painted++,
    ).paint(Canvas(recorder), Size.zero);
    recorder.endRecording().dispose();
    expect(painted, 0);
  });
}
