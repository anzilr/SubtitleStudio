import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/themes/studio_time_field.dart';

class TimeComponentField extends ConsumerWidget {
  final String label;
  final bool isStartTime;
  final TextEditingController timeController;
  final bool isVideoLoaded;
  final String? fallbackComponentError;
  final String? fallbackOrderError;
  final VoidCallback onSync;
  final VoidCallback onTimeChanged;
  final VoidCallback onEditingComplete;

  const TimeComponentField({
    super.key,
    required this.label,
    required this.isStartTime,
    required this.timeController,
    required this.isVideoLoaded,
    required this.fallbackComponentError,
    required this.fallbackOrderError,
    required this.onSync,
    required this.onTimeChanged,
    required this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validation = ref.watch(
      editLineControllerProvider.select(
        (state) => (
          state.isInitialized,
          state.startTimeError,
          state.endTimeError,
          state.timeOrderError,
        ),
      ),
    );

    final componentError = validation.$1
        ? (isStartTime ? validation.$2 : validation.$3)
        : fallbackComponentError;
    final orderError =
        validation.$1 ? validation.$4 : fallbackOrderError;
    final hasError = componentError != null || orderError != null;

    final tokens = StudioDesignTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: hasError ? tokens.dangerText : tokens.onSurface,
              ),
            ),
            if (isVideoLoaded) ...[
              const SizedBox(width: 12),
              IconButton(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                color: tokens.primaryAction,
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                tooltip:
                    'Sync ${isStartTime ? 'start' : 'end'} time with current video position',
                style: IconButton.styleFrom(
                  backgroundColor:
                      tokens.primaryAction.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        StudioTimeField(
          controller: timeController,
          label: label,
          hasError: hasError,
          inputFormatters: [TimeInputFormatter()],
          onChanged: (value) {
            final controller =
                ref.read(editLineControllerProvider.notifier);
            if (isStartTime) {
              controller.updateStartTime(value);
            } else {
              controller.updateEndTime(value);
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onTimeChanged();
            });
          },
          onEditingComplete: onEditingComplete,
        ),
        const SizedBox(height: 8),
        Text(
          'HH:mm:ss,SSS',
          style: TextStyle(
            fontSize: 11,
            color: hasError ? tokens.dangerText : tokens.mutedText,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (componentError != null)
          Text(
            componentError,
            style: TextStyle(fontSize: 11, color: tokens.dangerText, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          )
        else if (orderError != null)
          Text(
            orderError,
            style: TextStyle(fontSize: 11, color: tokens.dangerText, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
