import 'dart:math' as math;

import 'package:subtitle_studio/features/waveform/services/waveform_progressive_coverage.dart';

/// A clipped absolute-media-time span mapped to viewport pixel coordinates.
/// Unknown spans always have `preview == null` and are not zero-valued audio.
class WaveformProjectedSpan {
  const WaveformProjectedSpan({
    required this.startPixel,
    required this.endPixel,
    required this.extent,
  });

  final double startPixel;
  final double endPixel;
  final WaveformProgressiveExtent extent;

  bool get isKnown => extent.isKnown;

  /// A signed min/max pair for a pixel in a decoded extent, or null for
  /// unknown time. Uses absolute media position, not segment-local x offset.
  (double, double)? signedPeaksAt(double x) {
    final preview = extent.preview;
    if (preview == null || x < startPixel || x >= endPixel ||
        endPixel <= startPixel) return null;
    final fraction = (x - startPixel) / (endPixel - startPixel);
    final startUs = extent.start.inMicroseconds;
    final endUs = extent.end.inMicroseconds;
    final mediaUs = startUs + ((endUs - startUs) * fraction).floor();
    final sampleDurationUs = preview.end.inMicroseconds -
        preview.start.inMicroseconds;
    if (sampleDurationUs <= 0) return null;
    final index = ((mediaUs - preview.start.inMicroseconds) *
        preview.minima.length ~/ sampleDurationUs)
        .clamp(0, preview.minima.length - 1);
    return (preview.minima[index], preview.maxima[index]);
  }
}

/// Pure viewport geometry for partial audio. Gaps between known extents
/// become explicit unknown regions instead of silent zero-amplitude peaks.
class WaveformProgressiveViewport {
  const WaveformProgressiveViewport({
    required this.start,
    required this.end,
    required this.extents,
  });

  final Duration start;
  final Duration end;
  final List<WaveformProgressiveExtent> extents;

  List<WaveformProjectedSpan> project(double width) {
    if (start.isNegative || end <= start ||
        !width.isFinite || width <= 0 || width > 16384 ||
        extents.length > 1024) {
      throw ArgumentError('Invalid bounded progressive viewport.');
    }
    final fromUs = start.inMicroseconds;
    final untilUs = end.inMicroseconds;
    final durationUs = untilUs - fromUs;
    double mapX(int tUs) => (tUs - fromUs) / durationUs * width;

    final visible = <WaveformProgressiveExtent>[];
    var previousEnd = fromUs;
    for (final extent in extents) {
      final begin = extent.start.inMicroseconds;
      final finish = extent.end.inMicroseconds;
      if (begin < fromUs || finish > untilUs ||
          begin < previousEnd || finish <= begin) {
        throw ArgumentError('Nonmonotonic or unbounded waveform extents.');
      }
      final preview = extent.preview;
      if (preview != null &&
          (preview.start > extent.start || preview.end < extent.end ||
           preview.minima.isEmpty ||
           preview.minima.length != preview.maxima.length)) {
        throw ArgumentError('Preview does not cover the claimed extent.');
      }
      if (begin > previousEnd) {
        visible.add(WaveformProgressiveExtent(
          start: Duration(microseconds: previousEnd),
          end: Duration(microseconds: begin),
          preview: null,
        ));
      }
      visible.add(extent);
      previousEnd = finish;
    }
    if (previousEnd < untilUs) {
      visible.add(WaveformProgressiveExtent(
        start: Duration(microseconds: previousEnd),
        end: Duration(microseconds: untilUs),
        preview: null,
      ));
    }
    return List<WaveformProjectedSpan>.unmodifiable(visible.map((extent) =>
      WaveformProjectedSpan(
        startPixel: math.max(0.0, mapX(extent.start.inMicroseconds)),
        endPixel: math.min(width, mapX(extent.end.inMicroseconds)),
        extent: extent,
      )));
  }
}
