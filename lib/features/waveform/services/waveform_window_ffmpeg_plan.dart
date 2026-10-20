import 'package:subtitle_studio/features/waveform/services/waveform_ffmpeg_plan.dart';

/// Seek strategy used ONLY by the CP86 R9 diagnostic extraction.
///
/// Input seeking is typically faster on seekable containers but can differ
/// from accurate output seeking around stream priming and timestamp gaps.
enum WaveformWindowSeekMode { inputFast, outputAccurate }

/// A strictly bounded experimental FFmpeg extraction plan.
///
/// This class never writes a persistent peak cache. The output is a temporary
/// signed 16-bit mono PCM segment. Mapping reuses the existing, tested track
/// policy. Absolute playback alignment is NOT guaranteed by the plan alone.
class WaveformWindowFfmpegPlan {
  static const int sampleRate = 2756;
  static const Duration maxWindow = Duration(seconds: 60);
  static const Duration maxStart = Duration(hours: 24);

  final String inputPath;
  final String outputPath;
  final String? selectedTrackId;
  final Duration start;
  final Duration duration;
  final WaveformWindowSeekMode seekMode;

  const WaveformWindowFfmpegPlan({
    required this.inputPath,
    required this.outputPath,
    required this.start,
    this.duration = const Duration(seconds: 30),
    this.selectedTrackId,
    this.seekMode = WaveformWindowSeekMode.inputFast,
  });

  /// Two bytes per mono sample plus one second for codec/demuxer rounding.
  /// The FFmpeg command also limits the output duration with -t.
  int get maximumPcmBytes =>
      ((duration.inMicroseconds * sampleRate + 999999) ~/ 1000000 +
          sampleRate) * 2;

  static String _seconds(Duration value) {
    final micros = value.inMicroseconds;
    return '${micros ~/ 1000000}.${(micros % 1000000).toString().padLeft(6, '0')}';
  }

  List<String> arguments() {
    if (start.isNegative || start > maxStart ||
        duration <= Duration.zero || duration > maxWindow) {
      throw const FormatException(
        'Window start must be within 24h and length must be 1µs–60s.',
      );
    }

    // Delegate path validation, selected-stream identity, and rate policy to
    // the shipping full-duration FFmpeg plan. Do not silently select audio 0
    // for a missing/invalid explicit track.
    final base = WaveformFfmpegPlan(
      inputPath: inputPath,
      outputPath: outputPath,
      selectedTrackId: selectedTrackId,
      pcmSampleRate: sampleRate,
    ).arguments();
    final inputIndex = base.indexOf('-i');

    return List<String>.unmodifiable([
      ...base.sublist(0, inputIndex),
      if (seekMode == WaveformWindowSeekMode.inputFast &&
          start > Duration.zero)
        ...['-ss', _seconds(start)],
      ...base.sublist(inputIndex, inputIndex + 2),
      if (seekMode == WaveformWindowSeekMode.outputAccurate &&
          start > Duration.zero)
        ...['-ss', _seconds(start)],
      // Explicitly ignore non-audio streams and bound output duration.
      '-vn', '-sn', '-dn',
      ...base.sublist(inputIndex + 2, base.length - 1),
      '-t', _seconds(duration),
      base.last,
    ]);
  }

  String ffmpegKitCommand() =>
      WaveformFfmpegPlan.formatArgumentsForFfmpegKit(arguments());
}
