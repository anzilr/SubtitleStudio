import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/video/subtitle.dart';
import 'package:subtitle_studio/widgets/video/subtitle_timeline_index.dart';

Subtitle _cue(
  int index,
  int startMs,
  int endMs, {
  String? text,
}) {
  return Subtitle(
    index: index,
    start: Duration(milliseconds: startMs),
    end: Duration(milliseconds: endMs),
    text: text ?? 'Cue $index',
  );
}

void main() {
  group('SubtitleTimelineIndex', () {
    test('finds a long cue spanning shorter inactive cues', () {
      final index = SubtitleTimelineIndex([
        _cue(1, 0, 100000),
        _cue(2, 10000, 20000),
        _cue(3, 30000, 40000),
      ]);

      final active = index.findActive(const Duration(milliseconds: 50000));

      expect(active.map((cue) => cue.index), [1]);
    });

    test('returns all overlapping cues in original list order', () {
      final index = SubtitleTimelineIndex([
        _cue(10, 1000, 10000),
        _cue(11, 2000, 8000),
        _cue(12, 3000, 4000),
      ]);

      final active = index.findActive(const Duration(milliseconds: 3500));

      expect(active.map((cue) => cue.index), [10, 11, 12]);
    });

    test('end time is exclusive', () {
      final index = SubtitleTimelineIndex([
        _cue(1, 1000, 2000),
      ]);

      expect(
        index.findActive(const Duration(milliseconds: 1999)),
        hasLength(1),
      );
      expect(
        index.findActive(const Duration(milliseconds: 2000)),
        isEmpty,
      );
    });

    test('works when input cues are not sorted by start time', () {
      final index = SubtitleTimelineIndex([
        _cue(20, 5000, 7000),
        _cue(10, 1000, 9000),
        _cue(30, 3000, 6000),
      ]);

      final active = index.findActive(const Duration(milliseconds: 5500));

      expect(active.map((cue) => cue.index), [20, 10, 30]);
    });

    test('returns empty before the first cue and after all cues end', () {
      final index = SubtitleTimelineIndex([
        _cue(1, 1000, 2000),
        _cue(2, 2500, 3000),
      ]);

      expect(
        index.findActive(const Duration(milliseconds: 500)),
        isEmpty,
      );
      expect(
        index.findActive(const Duration(milliseconds: 3500)),
        isEmpty,
      );
    });
  });
}
