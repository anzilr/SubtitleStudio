import 'package:flutter/material.dart';
import 'package:subtitle_studio/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/services/raw_srt_document.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/utils/unicode_text_input_formatter.dart';

/// Raw SRT source document, not a graphical cue-by-cue form.
/// One multiline field owns cursor, selection, undo, line breaks and text.
class SourceViewPane extends StatelessWidget {
  const SourceViewPane({
    super.key,
    required this.entries,
    required this.scrollController,
    required this.onChanged,
    this.rawText,
    this.onRawTextChanged,
  });

  final List<SubtitleEntry> entries;
  final ScrollController scrollController;
  final VoidCallback onChanged;
  final String? rawText;
  final ValueChanged<String>? onRawTextChanged;

  @override
  Widget build(BuildContext context) => RawSrtEditor(
        initialText: rawText ?? RawSrtDocument.compose(entries),
        scrollController: scrollController,
        onChanged: (source) {
          if (onRawTextChanged != null) {
            onRawTextChanged!(source);
          } else {
            // Compatibility for existing standalone SourceViewPane consumers.
            // Invalid intermediate keystrokes remain visible in the editor.
            try {
              final parsed = RawSrtDocument.parseStrict(source);
              entries..clear()..addAll(parsed);
            } on FormatException {
              // Parent must validate the raw document before persisting.
            }
          }
          onChanged();
        },
      );
}

/// Shared raw text surface for embedded and standalone Source View.
/// Rebuilds from theme changes must not replace the editing controller.
class RawSrtEditor extends StatefulWidget {
  const RawSrtEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
    this.scrollController,
  });

  final String initialText;
  final ValueChanged<String> onChanged;
  final ScrollController? scrollController;

  @override
  State<RawSrtEditor> createState() => _RawSrtEditorState();
}

class _RawSrtEditorState extends State<RawSrtEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void didUpdateWidget(covariant RawSrtEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        widget.initialText != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return ColoredBox(
      color: tokens.surface,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.md),
        child: TextField(
          key: const ValueKey('raw-srt-editor'),
          controller: _controller,
          scrollController: widget.scrollController,
          maxLines: null,
          minLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          inputFormatters: [UnicodeTextInputFormatter()],
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            color: tokens.onSurface,
            fontSize: 14,
            height: 1.4,
            fontFamily: 'monospace',
          ),
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
