import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/operations/subtitle_effect_operations.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

SubtitleLine _line(int index, String text) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

void main() {
  group('SubtitleEffectOperations.buildEffectDeltas', () {
    test('replaces one line with generated effect lines when replayed', () {
      final before = [
        _line(1, 'A'),
        _line(2, 'B'),
        _line(3, 'C'),
      ];
      final effectLines = [
        _line(2, 'B1'),
        _line(3, 'B2'),
        _line(4, 'B3'),
      ];

      final deltas = SubtitleEffectOperations.buildEffectDeltas(
        originalLine: before[1],
        originalLineIndex: 1,
        effectLines: effectLines,
      );

      expect(deltas, hasLength(4));
      expect(deltas.first.changeType, 'delete');
      expect(deltas.first.lineIndex, 1);
      expect(deltas.first.beforeState?.original, 'B');

      final restored = CheckpointStateReducer.copyLines(before);
      CheckpointStateReducer.applyDeltasInPlace(restored, deltas);

      expect(
        restored.map((line) => line.original).toList(),
        ['A', 'B1', 'B2', 'B3', 'C'],
      );
    });

    test('copies delta states instead of retaining mutable line references', () {
      final original = _line(1, 'Original');
      final effect = _line(1, 'Effect');

      final deltas = SubtitleEffectOperations.buildEffectDeltas(
        originalLine: original,
        originalLineIndex: 0,
        effectLines: [effect],
      );

      original.original = 'Mutated original';
      effect.original = 'Mutated effect';

      expect(deltas.first.beforeState?.original, 'Original');
      expect(deltas.last.afterState?.original, 'Effect');
    });
  });
}
