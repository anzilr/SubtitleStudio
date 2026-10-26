import 'dart:math' as math;

/// Constraint-aware vertical sizes for Studio Dock's center panels.
class StudioDockBands {
  const StudioDockBands({required this.video, required this.waveform,
      required this.table});

  static const double splitter = 5;
  // Keep video and waveform large enough for editing. Dense subtitle rows
  // and compact headers make the remaining 40% of the workspace useful.
  static const double defaultVideoShare = .36;
  static const double defaultWaveformShare = .24;
  static const double minVideoShare = .18;
  static const double minWaveformShare = .12;
  final double video;
  final double waveform;
  final double table;

  static StudioDockBands resolve(double availableHeight,
      {double videoShare = defaultVideoShare,
       double waveformShare = defaultWaveformShare}) {
    final usable = math.max(0.0, availableHeight - 2 * splitter);
    if (usable == 0) {
      return const StudioDockBands(video: 0, waveform: 0, table: 0);
    }
    final scale = math.min(1.0, usable / 486.0);
    final minVideo = 154.0 * scale;
    final minWaveform = 100.0 * scale;
    final minTable = 232.0 * scale;
    // At very short heights the scaled minimums fill the available pixels.
    // A floating-point rounding difference can otherwise invert clamp bounds.
    final maxVideo = math.max(minVideo, usable - minWaveform - minTable);
    final video = (usable * videoShare)
        .clamp(minVideo, maxVideo).toDouble();
    final maxWaveform = math.max(minWaveform, usable - video - minTable);
    final waveform = (usable * waveformShare)
        .clamp(minWaveform, maxWaveform).toDouble();
    return StudioDockBands(video: video, waveform: waveform,
        table: math.max(0.0, usable - video - waveform));
  }
}
