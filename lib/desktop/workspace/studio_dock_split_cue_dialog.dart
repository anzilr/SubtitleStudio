import 'dart:async';

import 'package:flutter/material.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';

import 'studio_dock_cue_structure_service.dart';

class StudioDockSplitCueDraft {
  const StudioDockSplitCueDraft({
    required this.splitAt,
    required this.firstOriginal,
    required this.secondOriginal,
    required this.firstEdited,
    required this.secondEdited,
  });

  final String splitAt;
  final String firstOriginal;
  final String secondOriginal;
  final String firstEdited;
  final String secondEdited;
}

/// A desktop-only editor for both halves of a split. Cancellation leaves
/// storage unchanged; a rejected checkpoint leaves all five inputs intact.
class StudioDockSplitCueDialog extends StatefulWidget {
  const StudioDockSplitCueDialog({
    super.key,
    required this.cueNumber,
    required this.start,
    required this.end,
    required this.original,
    required this.edited,
    required this.onSubmit,
    this.isEditMode = false,
  });

  final int cueNumber;
  final String start;
  final String end;
  final String original;
  final String edited;
  final bool isEditMode;
  final Future<bool> Function(StudioDockSplitCueDraft) onSubmit;

  @override
  State<StudioDockSplitCueDialog> createState() => _StudioDockSplitCueDialogState();
}

class _StudioDockSplitCueDialogState extends State<StudioDockSplitCueDialog> {
  late final TextEditingController _time;
  late final TextEditingController _firstOriginal;
  late final TextEditingController _secondOriginal;
  late final TextEditingController _firstEdited;
  late final TextEditingController _secondEdited;
  bool _saving = false;
  String? _error;

  static String _format(int millis) =>
      '${(millis ~/ 3600000).toString().padLeft(2, '0')}:'
      '${((millis ~/ 60000) % 60).toString().padLeft(2, '0')}:'
      '${((millis ~/ 1000) % 60).toString().padLeft(2, '0')},'
      '${(millis % 1000).toString().padLeft(3, '0')}';

  // Distribute complete words or lines as useful initial suggestions. Every
  // field remains editable; no text is persisted until Split is confirmed.
  static (String, String) _halves(String source) {
    if (source.isEmpty) return ('', '');
    final midpoint = source.length ~/ 2;
    final boundaries = <int>[
      for (var i = 1; i < source.length - 1; i++)
        if (source[i] == '\n' || source[i] == ' ') i,
    ];
    if (boundaries.isEmpty) return (source, '');
    boundaries.sort((a, b) =>
        (a - midpoint).abs().compareTo((b - midpoint).abs()));
    final index = boundaries.first;
    // The visual subtitle separator replaces the original boundary spacing.
    return (source.substring(0, index), source.substring(index + 1));
  }

  @override
  void initState() {
    super.initState();
    final start = TimeValidator.timeStringToMilliseconds(widget.start);
    final end = TimeValidator.timeStringToMilliseconds(widget.end);
    _time = TextEditingController(text: _format(start + (end - start) ~/ 2));
    final source = _halves(widget.original);
    final edit = _halves(widget.edited);
    _firstOriginal = TextEditingController(text: source.$1);
    _secondOriginal = TextEditingController(text: source.$2);
    _firstEdited = TextEditingController(text: edit.$1);
    _secondEdited = TextEditingController(text: edit.$2);
  }

  @override
  void dispose() {
    for (final controller in [
      _time, _firstOriginal, _secondOriginal, _firstEdited, _secondEdited,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final time = _time.text.trim();
    final error = StudioDockCueStructureService.validateSplit(
      widget.start, time, widget.end);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() { _saving = true; _error = null; });
    var saved = false;
    try {
      saved = await widget.onSubmit(StudioDockSplitCueDraft(
        splitAt: time,
        firstOriginal: _firstOriginal.text,
        secondOriginal: _secondOriginal.text,
        firstEdited: _firstEdited.text,
        secondEdited: _secondEdited.text,
      ));
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = 'Could not split this cue. The project may have changed '
            'elsewhere. Your draft is preserved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('Split subtitle cue #${widget.cueNumber}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Split within ${widget.start} – ${widget.end}. '
                'Review the text in both new cues before saving.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('studio-split-at'),
              controller: _time,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Split at (HH:mm:ss,SSS)',
                border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 16),
            for (final half in [
              ('First cue', _firstOriginal, _firstEdited, 'first'),
              ('Second cue', _secondOriginal, _secondEdited, 'second'),
            ]) ...[
              Text(half.$1, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (!widget.isEditMode) ...[
                TextField(
                  key: ValueKey('studio-split-${half.$4}-original'),
                  controller: half.$2,
                  enabled: !_saving,
                  minLines: 2, maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Original', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                key: ValueKey('studio-split-${half.$4}-edited'),
                controller: half.$3,
                enabled: !_saving,
                minLines: 2, maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.isEditMode
                      ? 'Subtitle Text' : 'Edited (optional)',
                  border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null)
              Text(_error!, key: const ValueKey('studio-split-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        )),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('studio-confirm-split'),
          onPressed: _saving ? null : () => unawaited(_submit()),
          icon: const Icon(Icons.call_split),
          label: Text(_saving ? 'Splitting…' : 'Split cue'),
        ),
      ],
    ),
  );
}
