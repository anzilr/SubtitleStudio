import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';

/// Shared surfaced container for new SubtitleStudio UI. Material owns its
/// surface/ink instead of decorating over buttons or nested ListTiles.
class StudioSurface extends StatelessWidget {
  const StudioSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StudioSpacing.md),
    this.raised = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return Material(
      color: raised ? tokens.raisedSurface : tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioRadius.card),
        side: BorderSide(color: tokens.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Consistent label/icon alignment across sheets and editing tools.
class StudioSectionHeader extends StatelessWidget {
  const StudioSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final type = Theme.of(context).textTheme.titleSmall;
    return Row(
      children: [
        Icon(icon, size: StudioSizing.icon, color: tokens.primaryAction),
        const SizedBox(width: StudioSpacing.xs),
        Expanded(
          child: Text(
            title,
            style: type?.copyWith(
              color: tokens.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// One branded primary-action component. Keep action wiring in the caller.
class StudioPrimaryAction extends StatelessWidget {
  const StudioPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final style = FilledButton.styleFrom(
      backgroundColor: tokens.primaryAction,
      foregroundColor: tokens.onPrimaryAction,
      minimumSize: const Size(StudioSizing.touchTarget, StudioSizing.touchTarget),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioRadius.input),
      ),
    );
    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style,
          child: Text(label));
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: StudioSizing.icon),
      label: Text(label),
    );
  }
}

/// Status labels use text and an icon, never color alone.
enum StudioStatusTone { information, caution }

class StudioStatusMessage extends StatelessWidget {
  const StudioStatusMessage({
    super.key,
    required this.message,
    this.tone = StudioStatusTone.information,
  });

  final String message;
  final StudioStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final warning = tone == StudioStatusTone.caution;
    final color = warning
        ? Theme.of(context).colorScheme.error
        : tokens.mutedText;

    return Semantics(
      liveRegion: warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_outlined : Icons.info_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: StudioSpacing.xxs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
