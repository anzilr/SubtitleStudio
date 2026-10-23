import 'dart:math' as math;

/// Constraint-aware vertical sizes for Studio Dock's center panels.
class StudioDockBands {
  const StudioDockBands({required this.video, required this.waveform,
      required this.table});

  static const double splitter = 5;
  final double video;
  final double waveform;
  final double table;

  static StudioDockBands resolve(double availableHeight,
      {double videoShare = .43, double waveformShare = .13}) {
    final usable = math.max(0.0, availableHeight - 2 * splitter);
    if (usable == 0) {
      return const StudioDockBands(video: 0, waveform: 0, table: 0);
    }
    final scale = math.min(1.0, usable / 476.0);
    final minVideo = 200.0 * scale;
    final minWaveform = 96.0 * scale;
    final minTable = 180.0 * scale;
    final video = (usable * videoShare)
        .clamp(minVideo, usable - minWaveform - minTable).toDouble();
    final waveform = (usable * waveformShare)
        .clamp(minWaveform, usable - video - minTable).toDouble();
    return StudioDockBands(video: video, waveform: waveform,
        table: math.max(0.0, usable - video - waveform));
  }
}
