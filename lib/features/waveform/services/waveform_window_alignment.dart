import 'dart:math' as math;
import 'dart:typed_data';

/// Diagnostic-only correlation against the full 2,756 Hz peak cache.
/// We deliberately do NOT treat an extracted segment as timeline-aligned
/// until its native-device waveform, offset, and gap behavior is validated.
class WaveformWindowAlignment {
  final int comparedSamples;
  final int lagSamples;
  final double normalizedError;
  final bool inconclusiveSilence;

  const WaveformWindowAlignment({
    required this.comparedSamples,
    required this.lagSamples,
    required this.normalizedError,
    required this.inconclusiveSilence,
  });

  @override
  String toString() =>
      'samples=$comparedSamples lagSamples=$lagSamples '
      'relativeError=${normalizedError.toStringAsFixed(4)} '
      'inconclusiveSilence=$inconclusiveSilence';

  /// Try offsets up to 100ms in both directions. Sample at a bounded number
  /// of points, skipping initial resampler/codec priming. This is a heuristic,
  /// not a replacement for native timestamp/PTS fixture testing.
  static WaveformWindowAlignment? compare({
    required Int16List window,
    required Int16List full,
    required Duration start,
    int sampleRate = 2756,
  }) {
    if (sampleRate <= 0 || start.isNegative || window.isEmpty ||
        full.isEmpty) return null;
    final base = (start.inMicroseconds * sampleRate / 1000000).round();
    if (base < 0 || base >= full.length) return null;
    final warmup = math.min(sampleRate ~/ 2, window.length ~/ 4);
    final available = math.min(window.length - warmup, 2048);
    if (available < 32) return null;
    final step = math.max(1, available ~/ 256);
    final maxLag = math.min(sampleRate ~/ 10, 276);
    var bestLag = 0;
    var bestScore = double.infinity;
    var bestMagnitude = 0;
    var bestCount = 0;

    // Test the exact requested timeline position explicitly (lag == 0),
    // then compare symmetrical offsets for seek/resampler priming drift.
    for (var n = -16; n <= 16; n++) {
      final lag = (n * maxLag / 16).round();
      var error = 0;
      var magnitude = 0;
      var count = 0;
      for (var i = warmup; i < warmup + available; i += step) {
        final j = base + i + lag;
        if (j < 0 || j >= full.length) continue;
        error += (window[i] - full[j]).abs();
        magnitude += math.max(window[i].abs(), full[j].abs());
        count++;
      }
      if (count < 32) continue;
      final score = magnitude == 0 ? 0.0 : error / magnitude;
      if (score < bestScore) {
        bestScore = score;
        bestLag = lag;
        bestMagnitude = magnitude;
        bestCount = count;
      }
    }

    if (bestCount == 0) return null;
    return WaveformWindowAlignment(
      comparedSamples: bestCount,
      lagSamples: bestLag,
      normalizedError: bestScore,
      inconclusiveSilence: bestMagnitude < bestCount * 50,
    );
  }
}
