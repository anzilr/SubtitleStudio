import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/marked_lines_filter.dart';

SubtitleLine cue(int index, {bool marked = false, String? comment,
    bool resolved = false}) => SubtitleLine()
  ..index = index
  ..startTime = '00:00:00,000'
  ..endTime = '00:00:01,000'
  ..original = 'Subtitle $index'
  ..marked = marked
  ..comment = comment
  ..resolved = resolved;

void main() {
  test('unchecked lists marked cues only, not unmarked comments', () {
    final marked = cue(5, marked: true);
    final comments = cue(2, comment: 'Unmarked comment');
    final accidentallyIncluded = cue(7, comment: 'Stale cached row');
    final result = MarkedLinesFilter.apply(
      markedLines: [marked, accidentallyIncluded],
      allLinesWithComments: [comments, accidentallyIncluded],
      includeUnmarkedComments: false,
    );
    expect(result.map((e) => e.index), [5]);
  });

  test('checked includes only marked plus genuine comment lines', () {
    final marked = cue(5, marked: true);
    final markedComment = cue(3, marked: true, comment: 'Marked comment');
    final unmarkedComment = cue(2, comment: 'Unmarked comment', resolved: true);
    final commentless = cue(4, comment: '   ');
    final result = MarkedLinesFilter.apply(
      markedLines: [marked, markedComment],
      allLinesWithComments: [
        unmarkedComment,
        markedComment,
        commentless,
        cue(9),
      ],
      includeUnmarkedComments: true,
    );
    expect(result.map((e) => e.index), [2, 3, 5]);
    expect(result.where((e) => e.resolved).length, 1);
  });

  test('switching off restores marked-only count and keeps marked version', () {
    final marked = cue(10, marked: true, comment: 'Current comment');
    final oldCopy = cue(10, marked: true, comment: 'Stale copy');
    final unmarked = cue(11, comment: 'Only comment');
    final checked = MarkedLinesFilter.apply(
      markedLines: [marked],
      allLinesWithComments: [oldCopy, unmarked],
      includeUnmarkedComments: true,
    );
    expect(checked.map((e) => e.index), [10, 11]);
    expect(checked.first.comment, 'Current comment');
    final unchecked = MarkedLinesFilter.apply(
      markedLines: [marked],
      allLinesWithComments: [oldCopy, unmarked],
      includeUnmarkedComments: false,
    );
    expect(unchecked.map((e) => e.index), [10]);
  });
}
