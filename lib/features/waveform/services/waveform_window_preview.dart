import 'dart:math' as math;
import 'dart:typed_data';

/// A transient, source-relative window for R10 experimental visualization.
///
/// Only this window's PCM is known. No unknown audio can be represented as
/// zero/silence and it must never be written to the normal full-track cache.
class WaveformWindowPreview {
  const WaveformWindowPreview({
    required this.start,
    required this.end,
    required this.minima,
    required this.maxima,
  });

  final Duration start;
  final Duration end;
  final List<double> minima;
  final List<double> maxima;

  static WaveformWindowPreview fromPcm({
    required Duration start,
    required Int16List pcm,
    required int sampleRate,
    int bucketCount = 256,
  }) {
    if (start.isNegative || sampleRate <= 0 ||
        pcm.isEmpty || bucketCount <= 0 || bucketCount > 1024) {
      throw ArgumentError('Invalid R10 window sample metadata.');
    }
    // Bound UI work regardless of recording length: min/max in each
    // bucket is essential for retaining rare short transients.
    final count = math.min(bucketCount, pcm.length);
    final low = List<double>.filled(count, 0);
    final high = List<double>.filled(count, 0);
    for (var bucket = 0; bucket < count; bucket++) {
      final from = (bucket * pcm.length ~/ count);
      final to = math.max(from + 1, (bucket + 1) * pcm.length ~/ count);
      var minValue = 32767;
      var maxValue = -32768;
      for (var i = from; i < to; i++) {
        final value = pcm[i];
        minValue = math.min(minValue, value);
        maxValue = math.max(maxValue, value);
      }
      low[bucket] = minValue / 32768.0;
      high[bucket] = maxValue / 32768.0;
    }
    final micros = pcm.length * 1000000 ~/ sampleRate;
    return WaveformWindowPreview(
      start: start,
      end: start + Duration(microseconds: micros),
      minima: List<double>.unmodifiable(low),
      maxima: List<double>.unmodifiable(high),
    );
  }
}
