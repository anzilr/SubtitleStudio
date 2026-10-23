import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both banner sheets wrap recommended-position CheckboxListTile in Material',
      () {
    for (final path in [
      'lib/widgets/banner_configuration_sheet.dart',
      'lib/widgets/banner_configuration_sheet_new.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(RegExp(r'Material\(\s*type: MaterialType.transparency,\s*'
        r'child: CheckboxListTile\(').hasMatch(source), isTrue,
        reason: 'Banner preference tile needs a local ink-rendering Material');
    }
  });
}
