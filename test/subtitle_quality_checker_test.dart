import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';

void main() {
  const checker = SubtitleQualityProfile();

  test('clean subtitles are not flagged', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:03,000', text: 'Hello there.'),
      SubtitleQualityCue(id: 2, start: '00:00:03,100',
          end: '00:00:05,500', text: '<i>How are you?</i>'),
    ]);
    expect(report.issues, isEmpty);
    expect(report.affectedCues, 0);
  });

  test('reports overlaps, short gaps and temporal order independently', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 30, start: '00:00:05,010',
          end: '00:00:07,000', text: 'Third cue'),
      SubtitleQualityCue(id: 10, start: '00:00:01,000',
          end: '00:00:04,000', text: 'First cue'),
      SubtitleQualityCue(id: 20, start: '00:00:03,800',
          end: '00:00:05,000', text: 'Second cue'),
    ]);
    expect(report.issues.map((issue) => issue.type), [
      SubtitleQualityIssueType.insufficientGap,
      SubtitleQualityIssueType.overlap,
    ]);
    // Results are listed in document order, even though intervals are checked
    // chronologically. The overlap belongs to cue 20; short gap to cue 30.
    expect(report.issues.map((issue) => issue.cueId), [30, 20]);
  });

  test('nested overlapping cues preserve the latest end as anchor', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:00,000',
          end: '00:00:10,000', text: 'Long first cue'),
      SubtitleQualityCue(id: 2, start: '00:00:02,000',
          end: '00:00:03,000', text: 'Short second cue'),
      SubtitleQualityCue(id: 3, start: '00:00:05,000',
          end: '00:00:06,000', text: 'Still overlapping first cue'),
    ]);
    expect(report.count(SubtitleQualityIssueType.overlap), 2);
    expect(report.affectedCues, 3,
        reason: 'First cue also violates the maximum duration');
  });

  test('flags invalid timecodes and nonpositive duration without fake gaps', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:88,000',
          end: '00:00:02,000', text: 'Bad time'),
      SubtitleQualityCue(id: 2, start: '00:00:05,000',
          end: '00:00:05,000', text: 'Zero duration'),
      SubtitleQualityCue(id: 3, start: '00:00:06,000',
          end: '00:00:07,000', text: 'Valid timing'),
    ]);
    expect(report.count(SubtitleQualityIssueType.invalidTimecode), 1);
    expect(report.count(SubtitleQualityIssueType.invalidDuration), 1);
    expect(report.count(SubtitleQualityIssueType.overlap), 0);
    expect(report.count(SubtitleQualityIssueType.insufficientGap), 0);
  });

  test('ignores formatting tags for CPS, width and emptiness checks', () {
    const text = r'{\an8}<i>Hi</i>';
    expect(SubtitleQualityChecker.visibleText(text), 'Hi');
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', text: text),
      SubtitleQualityCue(id: 2, start: '00:00:03,000',
          end: '00:00:04,000', text: '<i></i>'),
    ]);
    expect(report.count(SubtitleQualityIssueType.fastReading), 0);
    expect(report.count(SubtitleQualityIssueType.emptyText), 1);
  });

  test('reading speed, line length and duration rules are configurable', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:01,500', text: 'Very long line\nSecond\nThird'),
    ], profile: const SubtitleQualityProfile(
      maxCharactersPerSecond: 5,
      maxCharactersPerLine: 8,
      maxLines: 2,
      minDurationMs: 1000,
      maxDurationMs: 4000,
    ));
    expect(report.count(SubtitleQualityIssueType.fastReading), 1);
    expect(report.count(SubtitleQualityIssueType.longLine), 1);
    expect(report.count(SubtitleQualityIssueType.tooManyLines), 1);
    expect(report.count(SubtitleQualityIssueType.shortDuration), 1);
    expect(report.affectedCues, 1);
  });

  test('does not modify source text or erase intentional blank lines', () {
    const text = 'First line\n\nThird line';
    const cue = SubtitleQualityCue(id: 1, start: '00:00:01.000',
        end: '00:00:03.000', text: text);
    final report = SubtitleQualityChecker.scan(const [cue]);
    expect(cue.text, text);
    expect(report.count(SubtitleQualityIssueType.tooManyLines), 1);
  });

  test('profile defaults and thresholds are inclusive at boundaries', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', text: 'Hi'),
      SubtitleQualityCue(id: 2, start: '00:00:02,080',
          end: '00:00:03,080', text: 'Hi'),
    ], profile: checker);
    expect(report.issues, isEmpty);
  });

  test('reading speed and width use grapheme clusters for Malayalam', () {
    const text = 'കി'; // Consonant plus vowel sign, one visible character.
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', text: text),
    ], profile: const SubtitleQualityProfile(maxCharactersPerLine: 1));
    expect(report.count(SubtitleQualityIssueType.longLine), 0);
    expect(report.count(SubtitleQualityIssueType.fastReading), 0);
  });

  test('streaming and relaxed profiles use different CPS limits', () {
    const cue = SubtitleQualityCue(id: 1, start: '00:00:01,000',
        end: '00:00:02,000', text: 'Eighteen characters');
    final strict = SubtitleQualityChecker.scan(const [cue],
        profile: SubtitleQualityPreset.streaming.profile);
    final relaxed = SubtitleQualityChecker.scan(const [cue],
        profile: SubtitleQualityPreset.relaxed.profile);
    expect(strict.count(SubtitleQualityIssueType.fastReading), 1);
    expect(relaxed.count(SubtitleQualityIssueType.fastReading), 0);
  });

  test('safe whitespace suggestions preserve tags and deliberate blank lines', () {
    const before = 'Hello  <i>world</i>  \n\nNext  line ';
    final fixes = SubtitleQualityChecker.proposeSafeFixes(const [
      SubtitleQualityCue(id: 7, start: '00:00:01,000',
          end: '00:00:03,000', text: before),
    ]);
    expect(fixes, hasLength(1));
    expect(fixes.single.before, before);
    expect(fixes.single.after, 'Hello <i>world</i>\n\nNext line');
    expect(fixes.single.after, contains('\n\n'));
    expect(SubtitleQualityChecker.normalizeSpaces(fixes.single.after),
        fixes.single.after);
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 7, start: '00:00:01,000',
          end: '00:00:03,000', text: before),
    ]);
    expect(report.count(SubtitleQualityIssueType.unnecessaryWhitespace), 1);
  });
}
