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
      SubtitleQualityIssueType.outOfSequence,
      SubtitleQualityIssueType.overlap,
    ]);
    // Results are listed in document order, even though intervals are checked
    // chronologically. The overlap belongs to cue 20; short gap to cue 30.
    // Cue 10 also precedes cue 30 in time despite appearing after it in file.
    expect(report.issues.map((issue) => issue.cueId), [30, 10, 20]);
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
          end: '00:00:03,080', text: 'Yo'),
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

  test('custom profile round-trip retains each rule', () {
    const profile = SubtitleQualityProfile(
      maxCharactersPerSecond: 14.5,
      maxCharactersPerLine: 38,
      maxLines: 3,
      minDurationMs: 800,
      maxDurationMs: 6200,
      minGapMs: 130,
    );
    final restored = SubtitleQualityProfile.decode(profile.encode());
    expect(restored.maxCharactersPerSecond, 14.5);
    expect(restored.maxCharactersPerLine, 38);
    expect(restored.maxLines, 3);
    expect(restored.minDurationMs, 800);
    expect(restored.maxDurationMs, 6200);
    expect(restored.minGapMs, 130);
    expect(SubtitleQualityPreset.custom.label, 'Custom');
  });

  test('invalid saved custom profiles safely restore general limits', () {
    for (final json in [
      'garbage',
      '[]',
      '{"maxCharactersPerSecond":-2}',
      '{"maxCharactersPerSecond":20,"maxCharactersPerLine":0,'
          '"maxLines":2,"minDurationMs":0,"maxDurationMs":7000,'
          '"minGapMs":80}',
    ]) {
      expect(SubtitleQualityProfile.decode(json).maxCharactersPerLine, 42);
    }
  });

  test('detects repeated neighboring caption text despite styling changes', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', text: '<b>Hello\nworld!</b>'),
      SubtitleQualityCue(id: 2, start: '00:00:03,000',
          end: '00:00:04,000', text: 'hello world!'),
      SubtitleQualityCue(id: 3, start: '00:00:05,000',
          end: '00:00:06,000', text: 'Something else'),
      SubtitleQualityCue(id: 4, start: '00:00:07,000',
          end: '00:00:08,000', text: 'Hello world!'),
    ]);
    final repeated = report.issues.where(
        (issue) => issue.type == SubtitleQualityIssueType.repeatedText).toList();
    expect(repeated, hasLength(1));
    expect(repeated.single.cueId, 2);
    expect(repeated.single.detail, contains('#1'));
  });

  test('detects file timecodes out of order, without changing cue order', () {
    const cues = [
      SubtitleQualityCue(id: 11, start: '00:00:05,000',
          end: '00:00:06,000', text: 'Later'),
      SubtitleQualityCue(id: 12, start: '00:00:01,000',
          end: '00:00:02,000', text: 'Earlier'),
    ];
    final report = SubtitleQualityChecker.scan(cues);
    expect(report.count(SubtitleQualityIssueType.outOfSequence), 1);
    expect(report.issues.singleWhere((issue) =>
        issue.type == SubtitleQualityIssueType.outOfSequence).cueId, 12);
    expect(cues.first.id, 11);
    expect(cues.last.id, 12);
  });

  test('empty captions do not trigger repeated-text false positives', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', text: '  '),
      SubtitleQualityCue(id: 2, start: '00:00:03,000',
          end: '00:00:04,000', text: '<b></b>'),
    ]);
    expect(report.count(SubtitleQualityIssueType.repeatedText), 0);
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
