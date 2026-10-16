import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkbox tiles in extraction options use Material ink surface', () {
    final text = File('lib/widgets/subtitle_extract_options_sheet.dart')
        .readAsStringSync();
    expect(RegExp(r'Material\\([\\s\\S]*?child: CheckboxListTile\\(')
        .hasMatch(text), isTrue);
    // Flutter asserts when a decorated Container backgrounds CheckboxListTile
    // without a local Material ancestor owning its ink splashes.
    expect(RegExp(
      r'Container\\(\\s*decoration: BoxDecoration\\([\\s\\S]*?'
      r'border: Border\\.all\\(color: borderColor, width: 1\\),\\s*'
      r'\\),\\s*child: CheckboxListTile\\(',
    ).hasMatch(text), isFalse);
  });
}
