import 'package:flutter/material.dart';

/// Cross-skin safety colors. The Carbon Zero family keeps its decorative UI
/// achromatic; danger and warning are deliberate, accessible safety signals.
///
/// Only real destructive operations use [danger]. Marked/commented/edited
/// status uses the selected skin's ordinary semantic action colors.
abstract final class StudioStatusColors {
  static const dangerLight = Color(0xFFB32636);
  static const dangerDark = Color(0xFFFF8A98);
  static const onDangerLight = Colors.white;
  static const onDangerDark = Color(0xFF2B0810);

  static const warningLight = Color(0xFF956000);
  static const warningDark = Color(0xFFF2BA62);
  static const onWarningLight = Colors.white;
  static const onWarningDark = Color(0xFF251700);

  static Color danger(Brightness brightness) =>
      brightness == Brightness.dark ? dangerDark : dangerLight;
  static Color onDanger(Brightness brightness) =>
      brightness == Brightness.dark ? onDangerDark : onDangerLight;
  static Color warning(Brightness brightness) =>
      brightness == Brightness.dark ? warningDark : warningLight;
  static Color onWarning(Brightness brightness) =>
      brightness == Brightness.dark ? onWarningDark : onWarningLight;

  static Color dangerOf(BuildContext context) =>
      Theme.of(context).colorScheme.error;
  static Color onDangerOf(BuildContext context) =>
      Theme.of(context).colorScheme.onError;
}
