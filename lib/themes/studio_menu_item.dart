import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';

/// Shared content for Editor/Edit Line popup choices.
///
/// This widget only paints a row. The enclosing PopupMenuItem retains its
/// original value, selection callback, keyboard behavior and semantics.
/// Normal commands use the theme accent, while genuinely destructive commands
/// use the error text role. No arbitrary category color badge is introduced.
enum StudioMenuItemTone { normal, destructive, muted }

class StudioMenuItemContent extends StatelessWidget {
  const StudioMenuItemContent({
    super.key,
    required this.icon,
    required this.title,
    this.tone = StudioMenuItemTone.normal,
  });

  final IconData icon;
  final String title;
  final StudioMenuItemTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final iconColor = switch (tone) {
      StudioMenuItemTone.normal => tokens.primaryAction,
      StudioMenuItemTone.destructive => tokens.dangerText,
      StudioMenuItemTone.muted => tokens.mutedText,
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(StudioSpacing.xs),
          decoration: BoxDecoration(
            color: tokens.fieldSurface,
            borderRadius: BorderRadius.circular(StudioRadius.input),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: StudioSizing.icon,
          ),
        ),
        const SizedBox(width: StudioSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.onSurface,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
