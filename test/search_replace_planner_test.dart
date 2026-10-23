import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/search_replace/search_replace_planner.dart';

SubtitleLine _line(int index, String original, {String? edited}) =>
    SubtitleLine()
      ..index = index
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = original
      ..edited = edited
      ..marked = true
      ..comment = 'Existing comment'
      ..resolved = true;

SubtitleSearchMatch _match(SubtitleLine line, int start, int end) =>
    SubtitleSearchMatch(line: line, start: start, end: end);

void main() {
  test('replace all handles three matches in the same cue', () {
    final source = _line(1, 'hello hello HELLO');
    final plan = SubtitleSearchReplacePlanner.build(
      matches: [
        _match(source, 0, 5),
        _match(source, 6, 11),
        _match(source, 12, 17),
      ],
      searchTerm: 'hello',
      replacement: 'hi',
      caseSensitive: false,
    );
    expect(plan.replacements, 3);
    expect(plan.expectedLines, hasLength(1));
    expect(plan.updatedLines, hasLength(1));
    expect(plan.updatedLines.single.edited, 'hi hi hi');
    expect(plan.updatedLines.single.original, 'hello hello HELLO');
    expect(plan.updatedLines.single.comment, 'Existing comment');
    expect(plan.updatedLines.single.marked, isTrue);
    expect(plan.updatedLines.single.resolved, isTrue);
    expect(source.edited, isNull);
  });

  test('selected occurrences in one line accumulate instead of overwriting',
      () {
    final source = _line(1, 'one one one');
    final plan = SubtitleSearchReplacePlanner.build(
      matches: [_match(source, 4, 7), _match(source, 8, 11)],
      searchTerm: 'one',
      replacement: 'two words',
      caseSensitive: true,
    );
    expect(plan.replacements, 2);
    expect(plan.updatedLines.single.edited, 'one two words two words');
    expect(plan.expectedLines.single.edited, isNull);
  });

  test('replacement uses edited text when one already exists', () {
    final source = _line(4, 'original only', edited: 'cat cat');
    final plan = SubtitleSearchReplacePlanner.build(
      matches: [_match(source, 0, 3), _match(source, 4, 7)],
      searchTerm: 'cat',
      replacement: 'dog',
      caseSensitive: true,
    );
    expect(plan.updatedLines.single.original, 'original only');
    expect(plan.updatedLines.single.edited, 'dog dog');
    expect(plan.expectedLines.single.edited, 'cat cat');
  });

  test('multiple affected cues produce one replacement per cue', () {
    final first = _line(1, 'red');
    final second = _line(2, 'red');
    final plan = SubtitleSearchReplacePlanner.build(
      matches: [_match(first, 0, 3), _match(second, 0, 3)],
      searchTerm: 'red',
      replacement: 'blue',
      caseSensitive: true,
    );
    expect(plan.updatedLines.map((l) => l.index).toList(), [1, 2]);
    expect(plan.updatedLines.map((l) => l.edited).toList(), ['blue', 'blue']);
  });

  test('overlapping or repeated matches fail rather than corrupt text', () {
    final source = _line(1, 'repeat');
    expect(
      () => SubtitleSearchReplacePlanner.build(
        matches: [_match(source, 0, 3), _match(source, 0, 3)],
        searchTerm: 'rep',
        replacement: 'x',
        caseSensitive: true,
      ),
      throwsFormatException,
    );
  });

  test('stale/invalid ranges and mixed cue snapshots are rejected', () {
    final line = _line(1, 'hello');
    expect(
      () => SubtitleSearchReplacePlanner.build(
        matches: [_match(line, 0, 5)],
        searchTerm: 'world',
        replacement: 'new',
        caseSensitive: true,
      ),
      throwsFormatException,
    );
    expect(
      () => SubtitleSearchReplacePlanner.build(
        matches: [_match(line, -1, 2)],
        searchTerm: 'he',
        replacement: 'new',
        caseSensitive: true,
      ),
      throwsFormatException,
    );
    expect(
      () => SubtitleSearchReplacePlanner.build(
        matches: [_match(line, 0, 5), _match(_line(1, 'world'), 0, 5)],
        searchTerm: 'hello',
        replacement: 'new',
        caseSensitive: true,
      ),
      throwsFormatException,
    );
  });
}
