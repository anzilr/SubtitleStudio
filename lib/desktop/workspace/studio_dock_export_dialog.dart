import 'package:flutter/material.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/widgets/subtitle_encoding_picker.dart';

/// Collects the same output choices offered by mobile SRT export without
/// changing the active project's encoding or linked source location.
class StudioDockExportDialog extends StatefulWidget {
  const StudioDockExportDialog({
    super.key,
    required this.isEditMode,
    required this.currentEncoding,
    this.availableEncodings,
  });

  final bool isEditMode;
  final String currentEncoding;
  final Future<List<String>> Function()? availableEncodings;

  @override
  State<StudioDockExportDialog> createState() => _StudioDockExportDialogState();
}

class _StudioDockExportDialogState extends State<StudioDockExportDialog> {
  late String _encoding;
  List<String> _encodings = SubtitleTextCodec.supportedEncodings;
  String _customTag = 'MSone';
  bool _originalOnly = false;

  @override
  void initState() {
    super.initState();
    _encoding = widget.currentEncoding.trim().isEmpty
        ? 'UTF-8' : widget.currentEncoding;
    _loadEncodings();
  }

  Future<void> _loadEncodings() async {
    try {
      final supported = await (widget.availableEncodings?.call() ??
          SubtitleExtendedEncodingService.standard.availableEncodings());
      if (!mounted) return;
      setState(() => _encodings = supported);
    } catch (_) {
      // The portable codec list remains available if the native catalogue
      // cannot be queried. The export boundary still validates the charset.
    }
  }

  Future<void> _chooseEncoding() async {
    final supported = <String>{..._encodings, _encoding}.toList();
    final selected = await SubtitleEncodingPicker.show(
      context: context,
      options: supported,
      selected: _encoding,
      title: 'Output subtitle encoding',
    );
    if (mounted && selected != null) setState(() => _encoding = selected);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Export SRT'),
    content: SizedBox(
      width: 470,
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Export saves a separate subtitle file. Your current '
              'project and its linked source file will not change.'),
          if (!widget.isEditMode) ...[
            const SizedBox(height: 16),
            const Text('Subtitle text'),
            RadioGroup<bool>(
              groupValue: _originalOnly,
              onChanged: (value) {
                if (value != null) setState(() => _originalOnly = value);
              },
              child: const Column(children: [
                RadioListTile<bool>(
                  key: ValueKey('studio-export-edited'),
                  title: Text('Edited text'),
                  value: false,
                ),
                RadioListTile<bool>(
                  key: ValueKey('studio-export-original'),
                  title: Text('Original text'),
                  value: true,
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('studio-export-custom-tag'),
            initialValue: _customTag,
            onChanged: (value) => _customTag = value,
            decoration: const InputDecoration(
              labelText: 'Filename tag',
              helperText: 'Added to the exported filename (edited text only).',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('studio-export-encoding'),
            onPressed: _chooseEncoding,
            icon: const Icon(Icons.manage_search),
            label: Text('Output encoding: $_encoding'),
          ),
        ],
      )),
    ),
    actions: [
      TextButton(
        key: const ValueKey('studio-export-cancel'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('studio-export-confirm'),
        onPressed: () => Navigator.pop(context, StudioDockExportOptions(
          originalOnly: _originalOnly,
          encoding: _encoding,
          customTag: _customTag,
        )),
        child: const Text('Export SRT'),
      ),
    ],
  );
}
