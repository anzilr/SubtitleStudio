import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

SubtitleLine _line(
  int index,
  String original, {
  String? edited,
  bool marked = false,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = original
    ..edited = edited
    ..marked = marked
    ..comment = null
    ..resolved = false;
}

void main() {
  group('CheckpointStateReducer', () {
    test('copyLine creates an independent deep value copy', () {
      final source = _line(1, 'Original', edited: 'Edited', marked: true)
        ..comment = 'note'
        ..resolved = true;

      final copy = CheckpointStateReducer.copyLine(source);

      expect(copy.index, source.index);
      expect(copy.startTime, source.startTime);
      expect(copy.endTime, source.endTime);
      expect(copy.original, source.original);
      expect(copy.edited, source.edited);
      expect(copy.marked, isTrue);
      expect(copy.comment, 'note');
      expect(copy.resolved, isTrue);

      copy.original = 'Changed';
      copy.comment = null;

      expect(source.original, 'Original');
      expect(source.comment, 'note');
    });

    test('applies add delta at requested position', () {
      final lines = <SubtitleLine>[
        _line(1, 'A'),
        _line(2, 'C'),
      ];
      final delta = SubtitleLineDelta()
        ..changeType = 'add'
        ..lineIndex = 1
        ..afterState = _line(2, 'B');

      CheckpointStateReducer.applyDeltasInPlace(lines, [delta]);

      expect(lines.map((line) => line.original), ['A', 'B', 'C']);
    });

    test('clamps add delta beyond list length', () {
      final lines = <SubtitleLine>[_line(1, 'A')];
      final delta = SubtitleLineDelta()
        ..changeType = 'add'
        ..lineIndex = 99
        ..afterState = _line(2, 'B');

      CheckpointStateReducer.applyDeltasInPlace(lines, [delta]);

      expect(lines.map((line) => line.original), ['A', 'B']);
    });

    test('applies delete delta', () {
      final lines = <SubtitleLine>[
        _line(1, 'A'),
        _line(2, 'B'),
        _line(3, 'C'),
      ];
      final delta = SubtitleLineDelta()
        ..changeType = 'delete'
        ..lineIndex = 1;

      CheckpointStateReducer.applyDeltasInPlace(lines, [delta]);

      expect(lines.map((line) => line.original), ['A', 'C']);
    });

    test('ignores out-of-range delete delta', () {
      final lines = <SubtitleLine>[_line(1, 'A')];
      final delta = SubtitleLineDelta()
        ..changeType = 'delete'
        ..lineIndex = 9;

      CheckpointStateReducer.applyDeltasInPlace(lines, [delta]);

      expect(lines.single.original, 'A');
    });

    test('applies modify delta with a copied after state', () {
      final lines = <SubtitleLine>[
        _line(1, 'A'),
        _line(2, 'Before'),
      ];
      final after = _line(2, 'After', edited: 'Translated');
      final delta = SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = 1
        ..afterState = after;

      CheckpointStateReducer.applyDeltasInPlace(lines, [delta]);

      expect(lines[1].original, 'After');
      expect(lines[1].edited, 'Translated');
      expect(identical(lines[1], after), isFalse);
    });

    test('strict reducer rejects an out-of-range delete', () {
      final lines = <SubtitleLine>[_line(1, 'A')];
      final delta = SubtitleLineDelta()
        ..changeType = 'delete'
        ..lineIndex = 9
        ..beforeState = _line(1, 'A');

      expect(
        () => CheckpointStateReducer.applyDeltasStrictInPlace(
          lines,
          [delta],
        ),
        throwsA(isA<CheckpointIntegrityException>()),
      );
    });

    test('strict reducer rejects a mismatched before state', () {
      final lines = <SubtitleLine>[
        _line(1, 'Actual'),
      ];
      final delta = SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = 0
        ..beforeState = _line(1, 'Expected')
        ..afterState = _line(1, 'After');

      expect(
        () => CheckpointStateReducer.applyDeltasStrictInPlace(
          lines,
          [delta],
        ),
        throwsA(isA<CheckpointIntegrityException>()),
      );
      expect(lines.single.original, 'Actual');
    });

    test('strict reducer applies a valid modify delta', () {
      final lines = <SubtitleLine>[_line(1, 'Before')];
      final delta = SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = 0
        ..beforeState = _line(1, 'Before')
        ..afterState = _line(1, 'After');

      CheckpointStateReducer.applyDeltasStrictInPlace(lines, [delta]);

      expect(lines.single.original, 'After');
    });

    test('applies multiple deltas in chronological order', () {
      final lines = <SubtitleLine>[
        _line(1, 'A'),
        _line(2, 'B'),
      ];
      final add = SubtitleLineDelta()
        ..changeType = 'add'
        ..lineIndex = 2
        ..afterState = _line(3, 'C');
      final modify = SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = 0
        ..afterState = _line(1, 'A2');
      final delete = SubtitleLineDelta()
        ..changeType = 'delete'
        ..lineIndex = 1;

      CheckpointStateReducer.applyDeltasInPlace(
        lines,
        [add, modify, delete],
      );

      expect(lines.map((line) => line.original), ['A2', 'C']);
    });
  });
}
