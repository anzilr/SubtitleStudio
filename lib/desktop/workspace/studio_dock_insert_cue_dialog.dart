import 'dart:async';

import 'package:flutter/material.dart';

import 'studio_dock_timing_edit_service.dart';

class StudioDockNewCueDraft {
  const StudioDockNewCueDraft({
    required this.start,
    required this.end,
    required this.original,
    required this.edited,
  });

  final String start;
  final String end;
  final String original;
  final String edited;
}

/// Keeps the draft open if its atomic history transaction is rejected.
class StudioDockInsertCueDialog extends StatefulWidget {
  const StudioDockInsertCueDialog({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.onSubmit,
    this.isEditMode = false,
  });

  final String initialStart;
  final String initialEnd;
  final bool isEditMode;
  final Future<bool> Function(StudioDockNewCueDraft) onSubmit;

  @override
  State<StudioDockInsertCueDialog> createState() =>
      _StudioDockInsertCueDialogState();
}

class _StudioDockInsertCueDialogState extends State<StudioDockInsertCueDialog> {
  late final TextEditingController _start;
  late final TextEditingController _end;
  final _original = TextEditingController();
  final _edited = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: widget.initialStart);
    _end = TextEditingController(text: widget.initialEnd);
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _original.dispose();
    _edited.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final timingError = StudioDockTimingEditService.validate(
      _start.text.trim(), _end.text.trim());
    if (timingError != null) {
      setState(() => _error = timingError);
      return;
    }
    setState(() { _saving = true; _error = null; });
    var saved = false;
    try {
      saved = await widget.onSubmit(StudioDockNewCueDraft(
        start: _start.text.trim(),
        end: _end.text.trim(),
        original: widget.isEditMode ? '' : _original.text,
        edited: _edited.text,
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
        _error = 'Could not insert this line. The project may have changed '
            'elsewhere. Your draft is preserved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Insert subtitle line'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Line order follows its start and end timecodes.',
              style: TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(
                key: const ValueKey('studio-insert-start'),
                controller: _start,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Start', hintText: 'HH:mm:ss,SSS',
                  border: OutlineInputBorder(), isDense: true),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                key: const ValueKey('studio-insert-end'),
                controller: _end,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'End', hintText: 'HH:mm:ss,SSS',
                  border: OutlineInputBorder(), isDense: true),
              )),
            ]),
            const SizedBox(height: 14),
            if (!widget.isEditMode) ...[
              TextField(
                key: const ValueKey('studio-insert-original'),
                controller: _original,
                enabled: !_saving,
                minLines: 2, maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Original text', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('studio-insert-edited'),
              controller: _edited,
              enabled: !_saving,
              minLines: 2, maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.isEditMode
                    ? 'Subtitle Text' : 'Edited text (optional)',
                border: const OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const ValueKey('studio-insert-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error,
                  fontSize: 12)),
            ],
          ],
        )),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('studio-confirm-insert'),
          onPressed: _saving ? null : () => unawaited(_submit()),
          icon: const Icon(Icons.add),
          label: Text(_saving ? 'Inserting…' : 'Insert line'),
        ),
      ],
    ),
  );
}
