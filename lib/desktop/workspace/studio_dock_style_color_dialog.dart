import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/colour_picker_widget.dart';

/// Scoped owner for the existing SubtitleStudio text color picker. Its editing
/// controller lives until the dialog is fully disposed, including the closing
/// animation; calling this widget never writes a subtitle file or database.
class StudioDockStyleColorDialog extends StatefulWidget {
  const StudioDockStyleColorDialog({
    super.key,
    required this.text,
    required this.initialColor,
    required this.colorHistory,
  });

  final String text;
  final Color initialColor;
  final List<Color> colorHistory;

  @override
  State<StudioDockStyleColorDialog> createState() =>
      _StudioDockStyleColorDialogState();
}

class _StudioDockStyleColorDialogState
    extends State<StudioDockStyleColorDialog> {
  late final TextEditingController _controller;
  final _pickerKey = GlobalKey<ColorPickerWithTextEditingState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text)
      ..selection = TextSelection(
        baseOffset: 0, extentOffset: widget.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Subtitle text color'),
    content: SizedBox(
      width: 480,
      height: 460,
      child: ColorPickerWithTextEditing(
        key: _pickerKey,
        controller: _controller,
        initialSelection: _controller.selection,
        initialColor: widget.initialColor,
        colorHistory: widget.colorHistory,
        showApplyButton: false,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('studio-style-color-confirm'),
        onPressed: () {
          _pickerKey.currentState?.applyChanges();
          Navigator.pop(context, _controller.text);
        },
        child: const Text('Use color'),
      ),
    ],
  );
}
