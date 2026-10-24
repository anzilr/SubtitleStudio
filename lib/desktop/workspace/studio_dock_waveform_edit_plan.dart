import 'package:flutter/foundation.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';

/// Pure adapter from waveform durations to Studio Dock's guarded SRT writes.
/// Waveform gestures must not directly mutate Isar or checkpoint history.
@immutable
class StudioDockWaveformEditPlan {
  const StudioDockWaveformEditPlan._();

  static const int _dayMilliseconds = 24 * 60 * 60 * 1000;

  static String? formatTime(Duration time) {
    final milliseconds = time.inMilliseconds;
    if (milliseconds < 0 || milliseconds >= _dayMilliseconds) return null;
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds ~/ 60000) % 60;
    final seconds = (milliseconds ~/ 1000) % 60;
    final fraction = milliseconds % 1000;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},'
        '${fraction.toString().padLeft(3, '0')}';
  }

  /// Match mobile's insertion rule: insert before the first later start.
  /// An equal start follows existing lines with that same start time.
  static int insertionPosition(List<String> currentStarts, Duration start) {
    for (var index = 0; index < currentStarts.length; index++) {
      if (start.inMilliseconds <
          TimeValidator.timeStringToMilliseconds(currentStarts[index])) {
        return index;
      }
    }
    return currentStarts.length;
  }
}
