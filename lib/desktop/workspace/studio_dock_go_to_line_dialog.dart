import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop presentation of the mobile Go to Line command. The dialog owns
/// its text controller so route-dismissal animations never outlive the input.
class StudioDockGoToLineDialog extends StatefulWidget {
  const StudioDockGoToLineDialog({
    super.key,
    required this.lineCount,
    required this.initialLine,
  });

  final int lineCount;
  final int initialLine;

  @override
  State<StudioDockGoToLineDialog> createState() =>
      _StudioDockGoToLineDialogState();
}

class _StudioDockGoToLineDialogState extends State<StudioDockGoToLineDialog> {
  late final TextEditingController _input;
  late int _sliderLine;
  String? _error;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _sliderLine = widget.initialLine.clamp(1, widget.lineCount).toInt();
    _input = TextEditingController(text: '$_sliderLine');
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    if (_completed) return;
    final line = int.tryParse(_input.text.trim());
    if (line == null || line < 1 || line > widget.lineCount) {
      setState(() => _error =
          'Enter a line number between 1 and ${widget.lineCount}.');
      return;
    }
    _completed = true;
    Navigator.of(context).pop(line);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter): _submit,
      const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
      const SingleActivator(LogicalKeyboardKey.escape):
          () => Navigator.of(context).pop(),
    },
    child: AlertDialog(
    title: const Text('Go to line'),
    content: SizedBox(
      width: 390,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Jump to one of ${widget.lineCount} subtitle lines. '
            'If a video is attached, seek to that subtitle.'),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('studio-go-to-line-input'),
          controller: _input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Subtitle line (1–${widget.lineCount})',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
          onChanged: (value) {
            final candidate = int.tryParse(value);
            setState(() {
              _error = null;
              if (candidate != null && candidate >= 1 &&
                  candidate <= widget.lineCount) {
                _sliderLine = candidate;
              }
            });
          },
        ),
        if (widget.lineCount > 1) ...[
          const SizedBox(height: 12),
          Slider(
            key: const ValueKey('studio-go-to-line-slider'),
            min: 1,
            max: widget.lineCount.toDouble(),
            divisions: widget.lineCount <= 200 ? widget.lineCount - 1 : null,
            value: _sliderLine.toDouble(),
            label: 'Line $_sliderLine',
            onChanged: (value) {
              final line = value.round().clamp(1, widget.lineCount).toInt();
              setState(() {
                _sliderLine = line;
                _error = null;
                _input.text = '$line';
                _input.selection = TextSelection.collapsed(
                    offset: _input.text.length);
              });
            },
          ),
        ],
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
      FilledButton(
        key: const ValueKey('studio-go-to-line-confirm'),
        onPressed: _submit,
        child: const Text('Go to line'),
      ),
    ],
    ),
  );
}
