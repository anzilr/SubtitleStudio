import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';

/// Shared readable background and focus boundary for Original/Edited cues.
///
/// Uses the semantic palette instead of Material primary as a solid text field
/// fill. Existing text/undo/focus controllers are owned by Edit Line, not by
/// this surface: changing a skin never replaces them.
class StudioCueFieldSurface extends StatefulWidget {
  const StudioCueFieldSurface({
    super.key,
    required this.child,
    this.height = 100,
    this.padding = const EdgeInsets.all(StudioSpacing.xs),
  });

  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  State<StudioCueFieldSurface> createState() => _StudioCueFieldSurfaceState();
}

class _StudioCueFieldSurfaceState extends State<StudioCueFieldSurface> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (mounted && focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      child: Container(
        height: widget.height,
        width: double.infinity,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: tokens.fieldSurface,
          border: Border.all(
            color: _focused ? tokens.focusBorder : tokens.fieldBorder,
            width: _focused ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(StudioRadius.input),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Inner cue TextField intentionally does not paint over its parent's surface
/// or draw a second focused border. Keyboard and controller settings stay with
/// the caller, preserving existing multi-script editing behavior.
abstract final class StudioCueFieldStyle {
  static InputDecoration decoration({
    required EdgeInsetsGeometry padding,
  }) =>
      InputDecoration(
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: padding,
      );

  static TextStyle text(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
        .copyWith(color: tokens.onSurface, fontSize: 16);
  }

  static TextStyle label(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
        .copyWith(
          color: tokens.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        );
  }

  static TextStyle index(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
        .copyWith(
          color: tokens.mutedText,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        );
  }
}
