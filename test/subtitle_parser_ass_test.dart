import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';

void main() {
  group('SubtitleParser.parseAss', () {
    test('parses a standard ASS Events section', () {
      const ass = r'''
[Script Info]
Title: Example

[V4+ Styles]
Format: Name, Fontname, Fontsize
Style: Default,Arial,20

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:03.25,Default,,0,0,0,,Hello world
Dialogue: 0,0:00:04.50,0:00:06.00,Default,,0,0,0,,Second line

[Fonts]
''';

      final result = SubtitleParser.parseAss(ass);

      expect(result, hasLength(2));
      expect(result[0].index, 1);
      expect(result[0].startTime, '00:00:01.000');
      expect(result[0].endTime, '00:00:03.250');
      expect(result[0].text, 'Hello world');
      expect(result[1].index, 2);
      expect(result[1].text, 'Second line');
    });

    test('preserves commas inside the Text field', () {
      const ass = r'''
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,Hello, world, again
''';

      final result = SubtitleParser.parseAss(ass);

      expect(result, hasLength(1));
      expect(result.single.text, 'Hello, world, again');
    });

    test('supports Text in a non-final declared position', () {
      const ass = r'''
[Events]
Format: Start, Text, End, Layer
Dialogue: 0:00:01.00,Hello, world,0:00:02.50,0
''';

      final result = SubtitleParser.parseAss(ass);

      expect(result, hasLength(1));
      expect(result.single.startTime, '00:00:01.000');
      expect(result.single.endTime, '00:00:02.500');
      expect(result.single.text, 'Hello, world');
    });

    test('removes ASS override tags and converts escaped line breaks', () {
      const ass = r'''
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,{\i1}First line\NSecond line{\i0}
''';

      final result = SubtitleParser.parseAss(ass);

      expect(result, hasLength(1));
      expect(result.single.text, 'First line\nSecond line');
    });

    test('returns no cues when Events has no usable Format declaration', () {
      const ass = r'''
[Events]
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,No format
''';

      expect(SubtitleParser.parseAss(ass), isEmpty);
    });
  });
}
