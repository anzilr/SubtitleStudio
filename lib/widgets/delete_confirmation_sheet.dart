import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';

/// Confirmation content; the caller remains responsible for route dismissal.
class DeleteConfirmationSheet extends StatelessWidget {
  final int lineIndex;
  final VoidCallback onConfirm;

  const DeleteConfirmationSheet({
    super.key,
    required this.lineIndex,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          onConfirm();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(StudioRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.all(StudioSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(StudioSpacing.sm),
                    decoration: BoxDecoration(
                      color: tokens.dangerText.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(StudioRadius.card),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: tokens.dangerText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: StudioSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Subtitle Line',
                          style: text.titleLarge?.copyWith(
                            color: tokens.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: StudioSpacing.xxs),
                        Text(
                          'This action cannot be undone',
                          style: text.bodyMedium?.copyWith(
                            color: tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(StudioSpacing.md),
                decoration: BoxDecoration(
                  color: tokens.fieldSurface,
                  borderRadius: BorderRadius.circular(StudioRadius.card),
                  border: Border.all(color: tokens.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: tokens.dangerText,
                          size: StudioSizing.icon,
                        ),
                        const SizedBox(width: StudioSpacing.xs),
                        Expanded(
                          child: Text(
                            'Line $lineIndex will be permanently deleted',
                            style: text.titleMedium?.copyWith(
                              color: tokens.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      'Are you sure you want to delete this subtitle line? '
                      'This action cannot be undone and the line will be '
                      'removed from your project.',
                      style: text.bodyMedium?.copyWith(
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StudioSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: StudioSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.dangerText,
                        foregroundColor: tokens.surface,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
