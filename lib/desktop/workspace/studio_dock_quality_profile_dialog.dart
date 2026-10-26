import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';

/// Edits quality rules only; the calling report owns persistence and rescans.
class StudioDockQualityProfileDialog extends StatefulWidget {
  const StudioDockQualityProfileDialog({
    super.key,
    required this.profile,
  });

  final SubtitleQualityProfile profile;

  @override
  State<StudioDockQualityProfileDialog> createState() =>
      _StudioDockQualityProfileDialogState();
}

class _StudioDockQualityProfileDialogState
    extends State<StudioDockQualityProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _cps = TextEditingController(
      text: widget.profile.maxCharactersPerSecond.toString());
  late final _line = TextEditingController(
      text: widget.profile.maxCharactersPerLine.toString());
  late final _lines = TextEditingController(
      text: widget.profile.maxLines.toString());
  late final _minMs = TextEditingController(
      text: widget.profile.minDurationMs.toString());
  late final _maxMs = TextEditingController(
      text: widget.profile.maxDurationMs.toString());
  late final _gapMs = TextEditingController(
      text: widget.profile.minGapMs.toString());

  @override
  void dispose() {
    for (final controller in [_cps, _line, _lines, _minMs, _maxMs, _gapMs]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _integerField(String label, TextEditingController controller,
      {required int minimum, required int maximum, String? hint}) {
    return TextFormField(
      key: ValueKey('quality-custom-${label.toLowerCase().replaceAll(' ', '-')}'),
      controller: controller,
      decoration: InputDecoration(labelText: label, helperText: hint,
          isDense: true, border: const OutlineInputBorder()),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null || parsed < minimum || parsed > maximum) {
          return 'Enter $minimum–$maximum';
        }
        if (identical(controller, _maxMs) &&
            parsed <= (int.tryParse(_minMs.text) ?? -1)) {
          return 'Must exceed minimum duration';
        }
        return null;
      },
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, SubtitleQualityProfile(
      maxCharactersPerSecond: double.parse(_cps.text),
      maxCharactersPerLine: int.parse(_line.text),
      maxLines: int.parse(_lines.text),
      minDurationMs: int.parse(_minMs.text),
      maxDurationMs: int.parse(_maxMs.text),
      minGapMs: int.parse(_gapMs.text),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Custom quality limits'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  key: const ValueKey('quality-custom-reading-speed'),
                  controller: _cps,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Maximum characters per second',
                    helperText: 'CPS · visible characters, excluding tags',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = double.tryParse(value ?? '');
                    return n == null || !n.isFinite || n <= 0 || n > 100
                        ? 'Enter a number above 0 and at most 100'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                _integerField('Characters per line', _line,
                    minimum: 1, maximum: 300),
                const SizedBox(height: 14),
                _integerField('Maximum text lines', _lines,
                    minimum: 1, maximum: 20),
                const SizedBox(height: 14),
                _integerField('Minimum duration (ms)', _minMs,
                    minimum: 0, maximum: 599999),
                const SizedBox(height: 14),
                _integerField('Maximum duration (ms)', _maxMs,
                    minimum: 1, maximum: 600000),
                const SizedBox(height: 14),
                _integerField('Minimum gap (ms)', _gapMs,
                    minimum: 0, maximum: 10000),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('quality-custom-save'),
            onPressed: _save,
            child: const Text('Save limits'),
          ),
        ],
      );
}
