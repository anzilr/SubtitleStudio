import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both extraction checkbox tiles have a dedicated Material ink surface',
      () {
    final text = File('lib/widgets/subtitle_extract_options_sheet.dart')
        .readAsStringSync();
    final tiles = RegExp(r'child: CheckboxListTile\(');
    final safeWrappers = RegExp(
      r'Material\([\s\S]*?clipBehavior: Clip.antiAlias,\s*'
      r'child: CheckboxListTile\(',
    );
    expect(tiles.allMatches(text).length, 2);
    expect(safeWrappers.allMatches(text).length, 2);
  });
}
