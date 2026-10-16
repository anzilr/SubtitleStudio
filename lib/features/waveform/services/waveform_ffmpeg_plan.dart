/// Testable FFmpeg extraction contract shared by native and desktop calls.
/// Media Kit AudioTrack.id is NOT guaranteed to be an FFmpeg audio ordinal.
/// Legacy numeric IDs retain their prior heuristic until native verification.
class WaveformFfmpegPlan {
  final String inputPath;
  final String outputPath;
  final String? selectedTrackId;
  final int pcmSampleRate;

  const WaveformFfmpegPlan({
    required this.inputPath,
    required this.outputPath,
    this.selectedTrackId,
    this.pcmSampleRate = 44100,
  });

  /// Only null/auto permit automatic track selection.
  /// Explicit ffmpeg:a:N refers to a verified zero-based audio ordinal.
  static int? audioOrdinal(String? selectedTrackId) {
    if (selectedTrackId == null || selectedTrackId == 'auto') return null;
    if (selectedTrackId.isEmpty || selectedTrackId == 'no' ||
        selectedTrackId.trim() != selectedTrackId) {
      throw FormatException('No usable selected audio track: $selectedTrackId');
    }
    if (selectedTrackId.startsWith('ffmpeg:a:')) {
      final suffix = selectedTrackId.substring('ffmpeg:a:'.length);
      final n = int.tryParse(suffix);
      if (n == null || n < 0 || n > 100000 ||
          !RegExp(r'^[0-9]+$').hasMatch(suffix)) {
        throw FormatException('Invalid FFmpeg audio index: $selectedTrackId');
      }
      return n;
    }
    final n = int.tryParse(selectedTrackId);
    if (n == null || n < 0 || n > 100000 ||
        !RegExp(r'^[0-9]+$').hasMatch(selectedTrackId)) {
      throw FormatException('Invalid Media Kit audio ID: $selectedTrackId');
    }
    // Existing behavior: a Media Kit ID 1 means audio ordinal 0.
    // This remains a heuristic pending media stream ID resolution.
    return n >= 1 ? n - 1 : 0;
  }

  /// Global FFmpeg stream indexes differ from audio-only ordinals.
  static String? streamMap(String? selectedTrackId) {
    if (selectedTrackId != null &&
        selectedTrackId.startsWith('ffmpeg:stream:')) {
      final suffix = selectedTrackId.substring('ffmpeg:stream:'.length);
      final index = int.tryParse(suffix);
      if (index == null || index < 0 || index > 100000 ||
          !RegExp(r'^[0-9]+$').hasMatch(suffix)) {
        throw FormatException('Invalid global FFmpeg stream: $selectedTrackId');
      }
      return '0:$index';
    }
    final ordinal = audioOrdinal(selectedTrackId);
    return ordinal == null ? null : '0:a:$ordinal';
  }

  /// The actual stream selector used by FFmpeg, also safe for debug logging.
  /// A verified global stream ID is not an audio-only ordinal.
  String get selectedStreamMap => streamMap(selectedTrackId) ?? 'auto';

  List<String> arguments() {
    if (inputPath.isEmpty || outputPath.isEmpty) {
      throw const FormatException('Audio input and output paths are required.');
    }
    for (final path in [inputPath, outputPath]) {
      if (path.contains('\u0000') || path.contains('\n') ||
          path.contains('\r')) {
        throw const FormatException('Invalid FFmpeg audio path.');
      }
    }
    if (pcmSampleRate != 44100 && pcmSampleRate != 2756) {
      throw FormatException('Unsupported waveform PCM rate: $pcmSampleRate');
    }
    final map = streamMap(selectedTrackId);
    return List<String>.unmodifiable([
      '-nostdin',
      '-hide_banner',
      '-nostats',
      '-loglevel', 'error',
      '-y',
      '-i', inputPath,
      if (map != null) ...['-map', map],
      '-af', 'aresample=async=1:first_pts=0',
      '-ac', '1',
      '-ar', pcmSampleRate.toString(),
      '-f', 's16le',
      '-acodec', 'pcm_s16le',
      outputPath,
    ]);
  }

  /// FFmpegKit accepts one command string; quote individual argv components.
  String ffmpegKitCommand() => arguments().map(_quote).join(' ');

  static String _quote(String value) {
    if (value.isEmpty) return '""';
    if (!RegExp(r'[\s"\\]').hasMatch(value)) return value;
    return '"' + value.replaceAll('\\', '\\\\').replaceAll('"', '\\"') + '"';
  }
}
