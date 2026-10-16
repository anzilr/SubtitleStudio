import 'package:flutter/material.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';

/// Uses the shared component theme instead of a one-off teal/red button UI.
/// Navigation and save/discard callbacks remain caller-owned.
class UnsavedChangesSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;

  const UnsavedChangesSheet({
    super.key,
    required this.onConfirm,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final typography = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Unsaved Changes',
              style: typography.titleLarge?.copyWith(
                color: tokens.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              'You may have unsaved changes.',
              style: typography.bodyMedium?.copyWith(color: tokens.mutedText),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: StudioSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDiscard();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: StudioSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    child: const Text('Save and Exit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
