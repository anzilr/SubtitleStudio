import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:subtitle_studio/services/subtitle_encoding_preview.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';

/// Native desktop preflight for an SRT file. Cancelling never writes a session
/// or changes the previously active project. The selected encoding is passed
/// to the same strict decoder used by mobile's import preview.
class StudioDockSrtImportDialog extends StatefulWidget {
  const StudioDockSrtImportDialog({
    super.key,
    required this.filePath,
    this.readBytes,
    this.availableEncodings,
  });

  final String filePath;
  /// Injectable boundaries keep widget tests deterministic; production uses
  /// real desktop file access and the OS charset catalogue.
  final Future<Uint8List> Function(String path)? readBytes;
  final Future<List<String>> Function()? availableEncodings;

  @override
  State<StudioDockSrtImportDialog> createState() =>
      _StudioDockSrtImportDialogState();
}

class _StudioDockSrtImportDialogState extends State<StudioDockSrtImportDialog> {
  String _encoding = 'Auto';
  List<String> _encodings = SubtitleTextCodec.supportedEncodings;
  Uint8List? _bytes;
  bool _previewBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEncodings();
  }

  Future<void> _loadEncodings() async {
    try {
      final encodings = await (widget.availableEncodings?.call() ??
          SubtitleExtendedEncodingService.standard.availableEncodings());
      if (mounted) setState(() => _encodings = encodings);
    } catch (_) {
      // The portable decoder's built-in charsets remain available.
    }
  }

  Future<void> _preview() async {
    if (_previewBusy) return;
    setState(() { _previewBusy = true; _error = null; });
    try {
      final bytes = _bytes ??= await (widget.readBytes?.call(widget.filePath) ??
          File(widget.filePath).readAsBytes());
      final preview = await const SubtitleEncodingPreview().generate(
        bytes,
        selectedEncoding: _encoding == 'Auto' ? null : _encoding,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Text preview · ${preview.encoding}'),
          content: SizedBox(
            width: 580,
            height: 360,
            child: Column(children: [
              if (preview.truncated)
                const Text('Showing the first 500 characters.'),
              Expanded(child: SingleChildScrollView(
                child: SelectableText(preview.text,
                  key: const ValueKey('studio-srt-import-preview-text')),
              )),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error =
          'Cannot preview with this encoding: $error');
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import SRT'),
    content: SizedBox(
      width: 510,
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.filePath.split(Platform.pathSeparator).last,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        const Text('Source encoding'),
        const SizedBox(height: 5),
        DropdownButton<String>(
          key: const ValueKey('studio-srt-import-encoding'),
          isExpanded: true,
          value: _encoding,
          items: [
            const DropdownMenuItem(value: 'Auto',
                child: Text('Auto (strict UTF-8 or detected BOM)')),
            for (final encoding in _encodings)
              DropdownMenuItem(value: encoding, child: Text(encoding)),
          ],
          onChanged: _previewBusy ? null : (value) {
            if (value != null) setState(() {
              _encoding = value;
              _error = null;
            });
          },
        ),
        const Text('Preview text before importing to check the encoding.'),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('studio-srt-import-preview'),
          onPressed: _previewBusy ? null : _preview,
          icon: _previewBusy
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.visibility_outlined),
          label: const Text('Preview text'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
        ],
      ]),
    ),
    actions: [
      TextButton(
        key: const ValueKey('studio-srt-import-cancel'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel')),
      FilledButton(
        key: const ValueKey('studio-srt-import-confirm'),
        onPressed: _previewBusy ? null : () => Navigator.pop(context,
            _encoding),
        child: const Text('Import SRT')),
    ],
  );
}
