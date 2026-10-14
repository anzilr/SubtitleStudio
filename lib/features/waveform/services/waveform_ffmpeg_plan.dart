/// Testable FFmpeg extraction contract shared by native and desktop calls.
/// Media Kit AudioTrack.id is NOT guaranteed to be an FFmpeg audio ordinal.
/// Existing numeric IDs retain their historical best-effort mapping until a
/// verified track resolver is available. Explicit ffmpeg:a:N is zero-based.
class WaveformFfmpegPlan {
  final String inputPath;
  final String outputPath;
  final String? selectedTrackId;

  const WaveformFfmpegPlan({
    required this.inputPath,
    required this.outputPath,
    this.selectedTrackId,
  });

  /// Returns null only when the user selected automatic track selection.
  /// A missing/invalid explicitly selected track must never fall back.
  static int? audioOrdinal(String? selectedTrackId) {
    if (selectedTrackId == null || selectedTrackId == 'auto') return null;
    if (selectedTrackId.isEmpty || selectedTrackId == 'no' ||
        selectedTrackId.trim() != selectedTrackId) {
      throw FormatException('No usable selected audio track: $selectedTrackId');
    }
    if (selectedTrackId.startsWith('ffmpeg:a:')) {
      final n = int.tryParse(selectedTrackId.substring('ffmpeg:a:'.length));
      if (n == null || n < 0 || n > 100000 ||
          !RegExp(r'^[0-9]+
        throw FormatException('Invalid FFmpeg audio index: $selectedTrackId');
      }
      return n;
    }
    final n = int.tryParse(selectedTrackId);
    if (n == null || n < 0 || n > 100000) {
      throw FormatException('Invalid Media Kit audio ID: $selectedTrackId');
    }
    // Legacy heuristic only. Media Kit's numeric ID can be an mpv track
    // identifier rather than this ordinal. Device probes must verify it.
    return n >= 1 ? n - 1 : 0;
  }

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
    final ordinal = audioOrdinal(selectedTrackId);
    return List<String>.unmodifiable([
      '-nostdin',
      '-hide_banner',
      '-nostats',
      '-loglevel', 'error',
      '-y',
      '-i', inputPath,
      if (ordinal != null) ...['-map', '0:a:$ordinal'],
      // Align gaps and initial offset (common in screen capture media).
      '-af', 'aresample=async=1:first_pts=0',
      '-ac', '1',
      '-ar', '44100',
      '-f', 's16le',
      '-acodec', 'pcm_s16le',
      outputPath,
    ]);
  }

  /// FFmpegKit accepts a command string. Quote each argv value independently
  /// rather than interpolating user-controlled paths into a shell-like string.
  String ffmpegKitCommand() => arguments().map(_quote).join(' ');

  static String _quote(String value) {
    if (value.isEmpty) return '""';
    if (!RegExp(r'[\s"\\]').hasMatch(value)) return value;
    return '"' + value.replaceAll('\\', '\\\\').replaceAll('"', '\\"') + '"';
  }
}
).hasMatch(
            selectedTrackId.substring('ffmpeg:a:'.length))) {
        throw FormatException('Invalid FFmpeg audio index: $selectedTrackId');
      }
      return n;
    }
    final n = int.tryParse(selectedTrackId);
    if (n == null || n < 0 || n > 100000) {
      throw FormatException('Invalid Media Kit audio ID: $selectedTrackId');
    }
    // Legacy heuristic only. Media Kit's numeric ID can be an mpv track
    // identifier rather than this ordinal. Device probes must verify it.
    return n >= 1 ? n - 1 : 0;
  }

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
    final ordinal = audioOrdinal(selectedTrackId);
    return List<String>.unmodifiable([
      '-nostdin',
      '-hide_banner',
      '-nostats',
      '-loglevel', 'error',
      '-y',
      '-i', inputPath,
      if (ordinal != null) ...['-map', '0:a:$ordinal'],
      // Align gaps and initial offset (common in screen capture media).
      '-af', 'aresample=async=1:first_pts=0',
      '-ac', '1',
      '-ar', '44100',
      '-f', 's16le',
      '-acodec', 'pcm_s16le',
      outputPath,
    ]);
  }

  /// FFmpegKit accepts a command string. Quote each argv value independently
  /// rather than interpolating user-controlled paths into a shell-like string.
  String ffmpegKitCommand() => arguments().map(_quote).join(' ');

  static String _quote(String value) {
    if (value.isEmpty) return '""';
    if (!RegExp(r'[\s"\\]').hasMatch(value)) return value;
    return '"' + value.replaceAll('\\', '\\\\').replaceAll('"', '\\"') + '"';
  }
}
