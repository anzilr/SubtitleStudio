import 'package:flutter/material.dart';
import 'package:subtitle_studio/screens/screen_edit_line.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';

/// Dialog for setting a custom subtitle repeat range.
class RepeatRangeDialog extends StatefulWidget {
  final EditSubtitleScreenState editScreenState;

  const RepeatRangeDialog({
    super.key,
    required this.editScreenState,
  });

  @override
  State<RepeatRangeDialog> createState() => RepeatRangeDialogState();
}

class RepeatRangeDialogState extends State<RepeatRangeDialog> {
  int _startIndex = 0;
  int _endIndex = 0;
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();

    final subtitleCount = widget.editScreenState.subtitles.length;
    if (subtitleCount > 0) {
      _endIndex = subtitleCount - 1;
    }

    _startController = TextEditingController(text: '${_startIndex + 1}');
    _endController = TextEditingController(text: '${_endIndex + 1}');
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleCount = widget.editScreenState.subtitles.length;

    if (subtitleCount == 0) {
      return AlertDialog(
        title: const Text('No Subtitles'),
        content: const Text(
          'No subtitles available for custom range repeat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.repeat_one, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text(
            'Custom Repeat Range',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select subtitle range for repeat playback:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildIndexField(
                    context,
                    label: 'Start Subtitle:',
                    controller: _startController,
                    onChanged: (value) {
                      final intValue = int.tryParse(value);
                      if (intValue == null ||
                          intValue < 1 ||
                          intValue > subtitleCount) {
                        return;
                      }

                      setState(() {
                        _startIndex = intValue - 1;
                        if (_endIndex < _startIndex) {
                          _endIndex = _startIndex;
                          _endController.text = '${_endIndex + 1}';
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildIndexField(
                    context,
                    label: 'End Subtitle:',
                    controller: _endController,
                    onChanged: (value) {
                      final intValue = int.tryParse(value);
                      if (intValue == null ||
                          intValue < _startIndex + 1 ||
                          intValue > subtitleCount) {
                        return;
                      }

                      setState(() {
                        _endIndex = intValue - 1;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildRangePreview(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _enableNormalRepeat,
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
          child: const Text('Normal Repeat'),
        ),
        ElevatedButton(
          onPressed: () => _applyCustomRange(subtitleCount),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply Range'),
        ),
      ],
    );
  }

  Widget _buildIndexField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildRangePreview(BuildContext context) {
    final subtitles = widget.editScreenState.subtitles;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Range: ${_endIndex - _startIndex + 1} subtitle(s)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          if (subtitles.isNotEmpty) ...[
            Text(
              'Start: ${_formatDuration(subtitles[_startIndex].start)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'End: ${_formatDuration(subtitles[_endIndex].end)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _enableNormalRepeat() {
    widget.editScreenState.clearCustomRepeatRange();

    if (!widget.editScreenState.isRepeatModeEnabled) {
      widget.editScreenState.toggleRepeatMode();
    } else {
      widget.editScreenState.startRepeatPlayback();
    }

    Navigator.of(context).pop();
    SnackbarHelper.showSuccess(context, 'Normal repeat mode enabled');
  }

  void _applyCustomRange(int subtitleCount) {
    final startValue = int.tryParse(_startController.text);
    final endValue = int.tryParse(_endController.text);

    if (startValue == null ||
        endValue == null ||
        startValue < 1 ||
        startValue > subtitleCount ||
        endValue < startValue ||
        endValue > subtitleCount) {
      SnackbarHelper.showError(
        context,
        'Please enter valid range (1-$subtitleCount)',
      );
      return;
    }

    widget.editScreenState.setCustomRepeatRange(
      startValue - 1,
      endValue - 1,
    );

    if (!widget.editScreenState.isRepeatModeEnabled) {
      widget.editScreenState.toggleRepeatMode();
    } else {
      widget.editScreenState.startRepeatPlayback();
    }

    Navigator.of(context).pop();
    SnackbarHelper.showSuccess(
      context,
      'Custom repeat range set: $startValue to $endValue',
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final centiseconds =
        (duration.inMilliseconds.remainder(1000) / 10).round();

    final time =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$time';
    }
    return time;
  }
}
