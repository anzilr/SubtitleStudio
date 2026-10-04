import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';

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

    final borderColor =
        hasError ? Colors.red : const Color(0xFF0A9396);

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
                color: hasError ? Colors.red : null,
              ),
            ),
            if (isVideoLoaded) ...[
              const SizedBox(width: 12),
              IconButton(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                color: const Color(0xFF0A9396),
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
                      const Color(0xFF0A9396).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: timeController,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            TimeInputFormatter(),
          ],
          style: TextStyle(
            color: hasError ? Colors.red : const Color(0xFFEE9B00),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          decoration: InputDecoration(
            hintText: 'HH:mm:ss,SSS',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: borderColor,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: borderColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          textInputAction: TextInputAction.next,
          enableIMEPersonalizedLearning: false,
          enableInteractiveSelection: true,
          showCursor: true,
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
            color: hasError ? Colors.red : Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (componentError != null)
          Text(
            componentError,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          )
        else if (orderError != null)
          Text(
            orderError,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
