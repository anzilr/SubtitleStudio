import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/models/subtitle_entry.dart';

void main() {
  group('SubtitleEntry', () {
    test('uses value equality for no-op edit detection', () {
      final first = SubtitleEntry(
        index: '1',
        startTime: '00:00:01,000',
        endTime: '00:00:02,000',
        text: 'Hello',
      );
      final same = first.copyWith();

      expect(same, equals(first));
      expect(same.hashCode, first.hashCode);
    });

    test('parses flexible arrow spacing and dot milliseconds', () {
      final entry = SubtitleEntry.fromSrtText(
        '\uFEFF1\n00:00:01.000   --> 00:00:02,500 align:start\nHello',
      );

      expect(entry, isNotNull);
      expect(entry!.index, '1');
      expect(entry.startTime, '00:00:01.000');
      expect(entry.endTime, '00:00:02,500');
      expect(entry.text, 'Hello');
    });

    test('rejects an unnumbered single cue block', () {
      expect(
        SubtitleEntry.fromSrtText(
          '00:00:01,000 --> 00:00:02,000\nHello\nWorld',
        ),
        isNull,
      );
    });
  });
}
