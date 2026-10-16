import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/text_formatting.dart';

void main() {
  group('toggleTextFormatting', () {
    test('wraps and unwraps selected text while preserving whitespace', () {
      final controller = TextEditingController(text: 'A  word  B')
        ..selection = const TextSelection(baseOffset: 1, extentOffset: 9);

      toggleTextFormatting(controller: controller, tag: 'b');

      expect(controller.text, 'A  <b>word</b>  B');

      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 16);
      toggleTextFormatting(controller: controller, tag: 'b');

      expect(controller.text, 'A  word  B');
    });

    test('toggles whole text when selection is collapsed', () {
      final controller = TextEditingController(text: 'Subtitle')
        ..selection = const TextSelection.collapsed(offset: 4);

      toggleTextFormatting(controller: controller, tag: 'i');
      expect(controller.text, '<i>Subtitle</i>');

      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      toggleTextFormatting(controller: controller, tag: 'i');
      expect(controller.text, 'Subtitle');
    });

    test('does nothing for an invalid selection', () {
      final controller = TextEditingController(text: 'Subtitle');

      toggleTextFormatting(controller: controller, tag: 'u');

      expect(controller.text, 'Subtitle');
    });
  });
}
