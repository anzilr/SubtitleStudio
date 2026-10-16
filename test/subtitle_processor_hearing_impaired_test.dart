import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/subtitle_processor.dart';

SubtitleLine _line({
  required int index,
  required String original,
  String? edited,
  bool marked = false,
  String? comment,
  bool resolved = false,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:01,000'
    ..endTime = '00:00:02,000'
    ..original = original
    ..edited = edited
    ..marked = marked
    ..comment = comment
    ..resolved = resolved;
}

void main() {
  group('removeHearingImpairedText', () {
    test('does not mutate the caller subtitle line', () {
      final source = _line(
        index: 1,
        original: '[door closes]\nHello there',
        edited: 'Translated',
        marked: true,
        comment: 'Review',
        resolved: true,
      );

      final result = removeHearingImpairedText([source]);

      expect(result, hasLength(1));
      expect(result.single.original, 'Hello there');

      expect(source.original, '[door closes]\nHello there');
      expect(source.edited, 'Translated');
    });

    test('preserves non-text metadata in cleaned copies', () {
      final source = _line(
        index: 7,
        original: '[music] Hello',
        edited: 'Edited text',
        marked: true,
        comment: 'Keep metadata',
        resolved: true,
      );

      final cleaned = removeHearingImpairedText([source]).single;

      expect(cleaned, isNot(same(source)));
      expect(cleaned.index, 7);
      expect(cleaned.startTime, source.startTime);
      expect(cleaned.endTime, source.endTime);
      expect(cleaned.edited, 'Edited text');
      expect(cleaned.marked, isTrue);
      expect(cleaned.comment, 'Keep metadata');
      expect(cleaned.resolved, isTrue);
    });

    test('drops cues that contain no meaningful text after cleanup', () {
      final source = _line(
        index: 1,
        original: '[LOUD MUSIC] ♪',
      );

      expect(removeHearingImpairedText([source]), isEmpty);
      expect(source.original, '[LOUD MUSIC] ♪');
    });
  });
}
