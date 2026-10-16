import 'package:flutter/material.dart';

/// Applies or removes a simple subtitle HTML-style tag.
///
/// When text is selected, only the trimmed selection is toggled while leading
/// and trailing whitespace remains outside the tags. With a collapsed
/// selection the whole line is toggled, matching the FormattingMenu behavior.
void toggleTextFormatting({
  required TextEditingController controller,
  required String tag,
}) {
  if (controller.text.isEmpty || !controller.selection.isValid) {
    return;
  }

  final originalText = controller.text;
  final selection = controller.selection;
  final selectedText = selection.textInside(originalText);

  if (selectedText.isNotEmpty) {
    final start = selection.start;
    final end = selection.end;

    final trimmedLeft = selectedText.trimLeft();
    final trimmedRight = selectedText.trimRight();
    final leadingLength = selectedText.length - trimmedLeft.length;
    final trailingLength = selectedText.length - trimmedRight.length;
    final leadingSpaces = selectedText.substring(0, leadingLength);
    final trailingSpaces = trailingLength == 0
        ? ''
        : selectedText.substring(selectedText.length - trailingLength);
    final trimmedText = selectedText.trim();

    if (_isWrapped(trimmedText, tag)) {
      final unwrappedText = _unwrap(trimmedText, tag);
      controller.text = originalText.replaceRange(
        start,
        end,
        '$leadingSpaces$unwrappedText$trailingSpaces',
      );
      controller.selection = TextSelection.collapsed(
        offset: start + leadingSpaces.length + unwrappedText.length,
      );
    } else {
      final wrappedText = '<$tag>$trimmedText</$tag>';
      controller.text = originalText.replaceRange(
        start,
        end,
        '$leadingSpaces$wrappedText$trailingSpaces',
      );
      controller.selection = TextSelection.collapsed(
        offset: start + leadingSpaces.length + wrappedText.length,
      );
    }
    return;
  }

  final trimmedText = originalText.trim();
  if (_isWrapped(trimmedText, tag)) {
    controller.text = _unwrap(trimmedText, tag);
  } else {
    controller.text = '<$tag>$trimmedText</$tag>';
  }
  controller.selection = TextSelection.collapsed(
    offset: controller.text.length,
  );
}

bool _isWrapped(String text, String tag) =>
    text.startsWith('<$tag>') && text.endsWith('</$tag>');

String _unwrap(String text, String tag) {
  return text.substring(
    tag.length + 2,
    text.length - (tag.length + 3),
  );
}
