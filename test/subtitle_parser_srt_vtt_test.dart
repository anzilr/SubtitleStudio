import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';

void main() {
  group('SubtitleParser.parseSrt', () {
    test('accepts BOM, flexible arrow whitespace and dot milliseconds', () {
      const input =
          '\uFEFF1\n00:00:01.000   -->   00:00:02,500\nHello\n';

      final result = SubtitleParser.parseSrt(input);

      expect(result, hasLength(1));
      expect(result.single.index, 1);
      expect(result.single.startTime, '00:00:01.000');
      expect(result.single.endTime, '00:00:02.500');
      expect(result.single.text, 'Hello');
    });

    test('supports cues without numeric indexes', () {
      const input =
          '00:00:01,000 --> 00:00:02,000\nOne\n\n'
          '00:00:03,000 --> 00:00:04,000\nTwo\n';

      final result = SubtitleParser.parseSrt(input);

      expect(result.map((cue) => cue.index), [1, 2]);
      expect(result.map((cue) => cue.text), ['One', 'Two']);
    });

    test('tolerates missing blank separator between numbered cues', () {
      const input =
          '1\n00:00:01,000 --> 00:00:02,000\nOne\n'
          '2\n00:00:03,000 --> 00:00:04,000\nTwo\n';

      final result = SubtitleParser.parseSrt(input);

      expect(result, hasLength(2));
      expect(result[0].text, 'One');
      expect(result[1].text, 'Two');
    });

    test('preserves empty cues, interior blank lines and text whitespace', () {
      const input =
          '1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n\r\nthere\r\n\r\n'
          '2\r\n00:00:03,000 --> 00:00:04,000\r\n\r\n'
          '3\r\n00:00:05,000 --> 00:00:06,000\r\n  padded text  \r\n\r\n'
          '4\r\n00:00:07,000 --> 00:00:08,000\r\nlast';

      final result = SubtitleParser.parseSrt(input);

      expect(result.map((cue) => cue.index), [1, 2, 3, 4]);
      expect(result.map((cue) => cue.text), [
        'Hello\n\nthere', '', '  padded text  ', 'last',
      ]);
    });

    test('keeps extra blank lines at cue edges while using one separator', () {
      const input =
          '1\n00:00:01,000 --> 00:00:02,000\n\nLeading\n\n\n'
          '2\n00:00:03,000 --> 00:00:04,000\nMiddle\n\n\n'
          '3\n00:00:05,000 --> 00:00:06,000\n\n';

      final result = SubtitleParser.parseSrt(input);

      expect(result.map((cue) => cue.text), [
        '\nLeading\n', 'Middle\n', '',
      ]);
    });

    test('accepts legacy SRT timestamps with one or two millisecond digits', () {
      const input =
          '1\n00:00:01,5 --> 00:00:02,50\nEarly\n\n'
          '2\n00:00:03,000 --> 00:00:04,000\nLater\n';

      final result = SubtitleParser.parseSrt(input);
      expect(result, hasLength(2));
      expect(result.first.text, 'Early');
    });

    test('keeps whitespace-only text at EOF without a separator newline', () {
      const input = '1\n00:00:01,000 --> 00:00:02,000\n   ';
      expect(SubtitleParser.parseSrt(input).single.text, '   ');
    });
  });

  group('SubtitleParser.parseVtt', () {
    test('parses MM:SS.mmm timestamps and cue settings', () {
      const input = '''
WEBVTT

00:01.000 --> 00:02.500 align:start position:10%
Hello
''';

      final result = SubtitleParser.parseVtt(input);

      expect(result, hasLength(1));
      expect(result.single.startTime, '00:00:01.000');
      expect(result.single.endTime, '00:00:02.500');
      expect(result.single.text, 'Hello');
    });

    test('supports non-numeric cue identifiers', () {
      const input = '''
WEBVTT

intro
00:00:01.000 --> 00:00:02.000
<v Roger>Hello there</v>
''';

      final result = SubtitleParser.parseVtt(input);

      expect(result, hasLength(1));
      expect(result.single.index, 1);
      expect(result.single.text, 'Hello there');
    });

    test('skips NOTE and STYLE blocks', () {
      const input = '''
WEBVTT

NOTE this is metadata
not a cue

STYLE
::cue { color: lime; }

00:00:01.000 --> 00:00:02.000
Visible
''';

      final result = SubtitleParser.parseVtt(input);

      expect(result, hasLength(1));
      expect(result.single.text, 'Visible');
    });
  });
}
