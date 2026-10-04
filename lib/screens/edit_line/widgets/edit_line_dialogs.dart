import 'package:flutter/material.dart';

Future<bool> showUnsavedChangesSheet({
  required BuildContext context,
  required VoidCallback onLeaveWithoutSaving,
  required Future<bool> Function() onSave,
  required VoidCallback onSavedAndLeave,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        isDismissible: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final primaryColor = Theme.of(sheetContext).primaryColor;
          final onSurfaceColor =
              Theme.of(sheetContext).colorScheme.onSurface;
          final mutedColor =
              onSurfaceColor.withValues(alpha: 0.6);

          return Container(
            margin: const EdgeInsets.all(16),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unsaved Changes',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(false),
                    tooltip: 'Close (ESC)',
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have unsaved changes in this subtitle line.',
                    style:
                        Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What would you like to do?',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: mutedColor),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop(false);
                    onLeaveWithoutSaving();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Leave Without Saving'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final saved = await onSave();
                    if (saved && sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(false);
                      onSavedAndLeave();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save & Leave'),
                ),
              ],
            ),
          );
        },
      ) ??
      false;
}

Future<void> showOriginalLineWarningSheet({
  required BuildContext context,
  required bool enableShowOriginal,
  required VoidCallback onContinue,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final isDark =
          Theme.of(sheetContext).brightness == Brightness.dark;
      final primaryColor = Theme.of(sheetContext).primaryColor;
      final onSurfaceColor =
          Theme.of(sheetContext).colorScheme.onSurface;
      final mutedColor = onSurfaceColor.withValues(alpha: 0.6);
      final borderColor = onSurfaceColor.withValues(alpha: 0.12);

      return Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important Notice',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please review these important changes',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: mutedColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? onSurfaceColor.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (enableShowOriginal) ...[
                        Text(
                          'When "Show Original Line" is enabled:',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const _BulletPoint(
                          'Original text will be copied to the edited field when it\'s empty',
                        ),
                        const SizedBox(height: 8),
                        const _BulletPoint(
                          'Auto-save with navigation will be DISABLED to prevent accidental saving of original text as edited',
                        ),
                        const SizedBox(height: 8),
                        const _BulletPoint(
                          'You can manually enable auto-save later at your own risk',
                        ),
                      ] else ...[
                        Text(
                          'When "Show Original Line" is disabled:',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const _BulletPoint(
                          'Original text will no longer be automatically copied to edited field',
                        ),
                        const SizedBox(height: 8),
                        const _BulletPoint(
                          'Auto-save with navigation will be ENABLED automatically',
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Do you want to continue?',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: onSurfaceColor,
                            side: BorderSide(
                              color: onSurfaceColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            onContinue();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check,
                                size: 20,
                                color: onSurfaceColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Continue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: onSurfaceColor.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onSurfaceColor.withValues(alpha: 0.8),
                ),
          ),
        ),
      ],
    );
  }
}
