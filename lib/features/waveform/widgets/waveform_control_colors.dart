import 'package:flutter/material.dart';

/// Original role-coded waveform action colors preserved across every skin.
/// This user-requested functional exception does not color subtitle contents.
abstract final class WaveformControlColors {
  static const Color zoom = Colors.orange;
  static const Color overlap = Colors.orange;
  static const Color magnet = Colors.red;
  static const Color addLine = Color(0xFF00695C);
  static const Color confirm = Colors.green;
  static const Color cancel = Colors.red;
  static const Color autoScroll = Colors.blue;
  static const Color playhead = Colors.red;
  static const Color timeReadout = Color(0x99EE9B00);
  static Color get editBars => Colors.blue.shade400;

  static Color waveform(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? Colors.blue.shade400
          : theme.colorScheme.secondary;

  static Color subtitleHighlight(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? Colors.amber.shade600.withValues(alpha: 0.4)
          : Colors.orange.shade400.withValues(alpha: 0.45);
}
