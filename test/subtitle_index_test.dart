import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/subtitle_index.dart';

void main() {
  group('subtitle index conversion', () {
    test('converts 1-based cue numbers to zero-based indexes', () {
      expect(cueNumberToListIndex(1), 0);
      expect(cueNumberToListIndex(2), 1);
      expect(cueNumberToListIndex(100), 99);
    });

    test('rejects null, zero and negative cue numbers', () {
      expect(cueNumberToListIndex(null), isNull);
      expect(cueNumberToListIndex(0), isNull);
      expect(cueNumberToListIndex(-1), isNull);
    });

    test('converts zero-based indexes to 1-based cue numbers', () {
      expect(listIndexToCueNumber(0), 1);
      expect(listIndexToCueNumber(1), 2);
      expect(listIndexToCueNumber(99), 100);
    });

    test('rejects negative list indexes', () {
      expect(() => listIndexToCueNumber(-1), throwsRangeError);
    });
  });
}
