import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/services/ai_context_builder.dart';

SubtitleLine _line(int index, String original, {String? edited}) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = original
    ..edited = edited;
}

void main() {
  final lines = <SubtitleLine>[
    _line(1, 'One', edited: 'Edited one'),
    _line(2, 'Two'),
    _line(3, 'Three', edited: 'Edited three'),
    _line(4, 'Four'),
    _line(5, 'Five'),
  ];

  group('EditLineAiContextBuilder', () {
    test('builds bounded previous and next context around current cue', () {
      final result = EditLineAiContextBuilder.build(
        lines: lines,
        currentIndex: 2,
        useEditedText: false,
        contextRadius: 2,
      );

      expect(result.currentIndex, 2);
      expect(result.previousLines, ['One', 'Two']);
      expect(result.nextLines, ['Four', 'Five']);
      expect(result.allLines, ['One', 'Two', 'Three', 'Four', 'Five']);
    });

    test('uses edited text only when edit mode requests it', () {
      final result = EditLineAiContextBuilder.build(
        lines: lines,
        currentIndex: 1,
        useEditedText: true,
        contextRadius: 2,
      );

      expect(result.previousLines, ['Edited one']);
      expect(result.nextLines, ['Edited three', 'Four']);
      expect(
        result.allLines,
        ['Edited one', 'Two', 'Edited three', 'Four', 'Five'],
      );
      expect(
        result.originalAllLines,
        ['One', 'Two', 'Three', 'Four', 'Five'],
      );
      expect(
        result.editedAllLines,
        ['Edited one', 'Two', 'Edited three', 'Four', 'Five'],
      );
    });

    test('clamps negative and oversized current indexes safely', () {
      final first = EditLineAiContextBuilder.build(
        lines: lines,
        currentIndex: -20,
        useEditedText: false,
      );
      final last = EditLineAiContextBuilder.build(
        lines: lines,
        currentIndex: 999,
        useEditedText: false,
      );

      expect(first.currentIndex, 0);
      expect(first.previousLines, isEmpty);
      expect(last.currentIndex, lines.length - 1);
      expect(last.nextLines, isEmpty);
    });

    test('returns empty context for an empty subtitle document', () {
      final result = EditLineAiContextBuilder.build(
        lines: const [],
        currentIndex: 0,
        useEditedText: true,
      );

      expect(result.currentIndex, 0);
      expect(result.allLines, isEmpty);
      expect(result.previousLines, isEmpty);
      expect(result.nextLines, isEmpty);
    });
  });
}
