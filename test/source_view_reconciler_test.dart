import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/services/source_view_reconciler.dart';

SubtitleLine _line({
  required int index,
  required String start,
  required String end,
  required String original,
  String? edited,
  bool marked = false,
  String? comment,
  bool resolved = false,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = start
    ..endTime = end
    ..original = original
    ..edited = edited
    ..marked = marked
    ..comment = comment
    ..resolved = resolved;
}

void main() {
  group('SourceViewReconciler', () {
    test('updates existing cue while preserving metadata', () {
      final existing = [
        _line(
          index: 1,
          start: '00:00:01,000',
          end: '00:00:02,000',
          original: 'Original',
          marked: true,
          comment: 'Check wording',
          resolved: true,
        ),
      ];

      final result = SourceViewReconciler.reconcile(
        existingLines: existing,
        entries: [
          SubtitleEntry(
            index: '1',
            startTime: '00:00:01,100',
            endTime: '00:00:02,200',
            text: 'Edited',
          ),
        ],
      );

      expect(result, hasLength(1));
      expect(result.single.index, 1);
      expect(result.single.startTime, '00:00:01,100');
      expect(result.single.endTime, '00:00:02,200');
      expect(result.single.original, 'Original');
      expect(result.single.edited, 'Edited');
      expect(result.single.marked, isTrue);
      expect(result.single.comment, 'Check wording');
      expect(result.single.resolved, isTrue);
    });

    test('removes deleted cues and preserves surviving cue identity', () {
      final existing = [
        _line(
          index: 1,
          start: '00:00:01,000',
          end: '00:00:02,000',
          original: 'One',
        ),
        _line(
          index: 2,
          start: '00:00:03,000',
          end: '00:00:04,000',
          original: 'Two',
          marked: true,
        ),
        _line(
          index: 3,
          start: '00:00:05,000',
          end: '00:00:06,000',
          original: 'Three',
          comment: 'Keep this',
        ),
      ];

      final result = SourceViewReconciler.reconcile(
        existingLines: existing,
        entries: [
          SubtitleEntry(
            index: '1',
            startTime: '00:00:01,000',
            endTime: '00:00:02,000',
            text: 'One',
          ),
          SubtitleEntry(
            index: '3',
            startTime: '00:00:05,000',
            endTime: '00:00:06,000',
            text: 'Three',
          ),
        ],
      );

      expect(result, hasLength(2));
      expect(result[0].index, 1);
      expect(result[1].index, 2);
      expect(result[1].original, 'Three');
      expect(result[1].comment, 'Keep this');
      expect(result.any((line) => line.original == 'Two'), isFalse);
    });

    test('creates a clean persisted line for an added source cue', () {
      final result = SourceViewReconciler.reconcile(
        existingLines: [
          _line(
            index: 1,
            start: '00:00:01,000',
            end: '00:00:02,000',
            original: 'Existing',
          ),
        ],
        entries: [
          SubtitleEntry(
            index: '1',
            startTime: '00:00:01,000',
            endTime: '00:00:02,000',
            text: 'Existing',
          ),
          SubtitleEntry(
            index: '2',
            startTime: '00:00:03,000',
            endTime: '00:00:04,000',
            text: 'Added',
          ),
        ],
      );

      expect(result, hasLength(2));
      final added = result[1];
      expect(added.index, 2);
      expect(added.original, 'Added');
      expect(added.edited, isNull);
      expect(added.marked, isFalse);
      expect(added.comment, isNull);
      expect(added.resolved, isFalse);
    });

    test('falls back to exact cue content when cue number is invalid', () {
      final existing = [
        _line(
          index: 1,
          start: '00:00:01,000',
          end: '00:00:02,000',
          original: 'Keep metadata',
          marked: true,
        ),
      ];

      final result = SourceViewReconciler.reconcile(
        existingLines: existing,
        entries: [
          SubtitleEntry(
            index: 'not-a-number',
            startTime: '00:00:01,000',
            endTime: '00:00:02,000',
            text: 'Keep metadata',
          ),
        ],
      );

      expect(result.single.marked, isTrue);
      expect(result.single.index, 1);
    });
  });
}
