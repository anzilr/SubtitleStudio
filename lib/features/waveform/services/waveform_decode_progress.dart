/// Throttles FFmpegKit media-time callbacks during long audio extraction.
///
/// getTime() reports milliseconds of decoded/output media time. This is NOT
/// progress percentage: input duration is not known for SAF-only selections,
/// and metadata can be wrong for discontinuous tracks.
class WaveformDecodeProgress {
  int _lastMilliseconds = -1;
  bool _closed = false;

  /// Prevent statistics emitted after the FFmpeg session's completion from
  /// returning the screen to its loading state.
  void close() => _closed = true;

  /// Returns the next visibly different processed-media timestamp, or null
  /// for invalid, repeated, regressing and sub-two-second callbacks.
  Duration? accept(num milliseconds) {
    if (_closed || !milliseconds.isFinite || milliseconds <= 0 ||
        milliseconds > 864000000) {
      return null;
    }
    final value = milliseconds.floor();
    if (_lastMilliseconds >= 0 &&
        value - _lastMilliseconds < 2000) {
      return null;
    }
    _lastMilliseconds = value;
    return Duration(milliseconds: value);
  }

  static String format(Duration time) {
    final seconds = time.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds ~/ 60) % 60;
    final remainder = seconds % 60;
    return 'Audio processed: $hours:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }
}
