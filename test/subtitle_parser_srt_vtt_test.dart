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
