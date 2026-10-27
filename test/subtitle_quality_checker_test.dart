import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';

void main() {
  test('animation frames skip dialogue heuristics but retain real errors', () {
    const cues = [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:01,200', text: 'H', effectGroupId: 1),
      SubtitleQualityCue(id: 2, start: '00:00:01,200',
          end: '00:00:01,400', text: 'He', effectGroupId: 1),
      SubtitleQualityCue(id: 3, start: '00:00:01,400',
          end: '00:00:01,600', text: 'Hello', effectGroupId: 1),
      SubtitleQualityCue(id: 4, start: '00:00:03,000',
          end: '00:00:03,100', text: 'Ordinary dialogue'),
      SubtitleQualityCue(id: 5, start: '00:00:04,000',
          end: '00:00:03,500', text: 'Bad timing', effectGroupId: 5),
    ];
    final report = SubtitleQualityChecker.scan(cues);
    expect(report.issues.where((issue) => issue.cueId <= 3), isEmpty);
    expect(report.issues.any((issue) => issue.cueId == 4 &&
        issue.type == SubtitleQualityIssueType.shortDuration), isTrue);
    expect(report.issues.any((issue) => issue.cueId == 5 &&
        issue.type == SubtitleQualityIssueType.invalidDuration), isTrue);
    expect(SubtitleQualityChecker.proposeSafeFixes(cues), isEmpty);
    expect(SubtitleQualityChecker.proposeTimingSuggestions(cues), isEmpty);
  });

  test('unrelated subtitles still trigger overlaps with an effect', () {
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', text: 'Ordinary'),
      SubtitleQualityCue(id: 2, start: '00:00:01,500',
          end: '00:00:01,700', text: 'H', effectGroupId: 2),
      SubtitleQualityCue(id: 3, start: '00:00:01,700',
          end: '00:00:01,900', text: 'Hi', effectGroupId: 2),
    ]);
    expect(report.issues.where((issue) =>
        issue.type == SubtitleQualityIssueType.overlap).length, 2);
  });

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

  test('nested font/bold tags retain Malayalam dialogue as visible text', () {
    const text = '<font color="#00ff00"><b>"ദ ഗോൾഡൻ വോയേജ്\n'
        'ഓഫ് സിൻബാദ്"</b></font>';
    expect(SubtitleQualityChecker.visibleText(text),
        '"ദ ഗോൾഡൻ വോയേജ്\nഓഫ് സിൻബാദ്"');
    final report = SubtitleQualityChecker.scan(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:04,000', text: text),
    ]);
    expect(report.count(SubtitleQualityIssueType.emptyText), 0);
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

  test('balanced line-break fix preserves words without touching markup', () {
    const before = 'Alpha beta gamma delta epsilon zeta eta theta';
    final fixes = SubtitleQualityChecker.proposeSafeFixes(const [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:04,000', text: before),
    ], profile: const SubtitleQualityProfile(maxCharactersPerLine: 24));
    expect(fixes, hasLength(1));
    final fix = fixes.single;
    expect(fix.kind, SubtitleQualityFixKind.balancedLineBreak);
    expect(fix.maxCharactersPerLine, 24);
    expect(fix.after.split('\n'), hasLength(2));
    expect(fix.after.replaceAll('\n', ' '), before);
    for (final line in fix.after.split('\n')) {
      expect(line.length, lessThanOrEqualTo(24));
    }
    expect(SubtitleQualityChecker.balancedLineBreak(before,
        maxCharactersPerLine: 24), fix.after);
  });

  test('line-break fixes decline styled, multiline and spaced captions', () {
    for (final value in [
      '<b>Alpha beta gamma delta epsilon zeta eta theta</b>',
      'Alpha beta gamma\ndelta epsilon zeta eta theta',
      'Alpha  beta gamma delta epsilon zeta eta theta',
      'OneSuperLongUnbreakableWordBecauseThereIsNoSpace',
    ]) {
      expect(SubtitleQualityChecker.balancedLineBreak(value,
          maxCharactersPerLine: 24), isNull);
    }
    const original = 'Alpha  beta gamma delta epsilon zeta eta theta';
    final fixes = SubtitleQualityChecker.proposeSafeFixes(const [
      SubtitleQualityCue(id: 3, start: '00:00:01,000',
          end: '00:00:04,000', text: original),
    ], profile: const SubtitleQualityProfile(maxCharactersPerLine: 24));
    expect(fixes.single.kind, SubtitleQualityFixKind.whitespace);
    expect(fixes.single.after, isNot(contains('\n')));
    expect(SubtitleQualityChecker.proposeSafeFixes(const [
      SubtitleQualityCue(id: 4, start: '00:00:01,000',
          end: '00:00:04,000',
          text: 'Alpha beta gamma delta epsilon zeta eta theta'),
    ], profile: const SubtitleQualityProfile(
        maxLines: 1, maxCharactersPerLine: 24)), isEmpty);
  });

  test('safe timing ideas only shorten a cue when readability remains valid', () {
    const cues = [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:03,000', text: 'Hello'),
      SubtitleQualityCue(id: 2, start: '00:00:03,050',
          end: '00:00:05,000', text: 'World'),
    ];
    final ideas = SubtitleQualityChecker.proposeTimingSuggestions(cues);
    expect(ideas, hasLength(1));
    expect(ideas.single.cueId, 1);
    expect(ideas.single.followingCueId, 2);
    expect(ideas.single.beforeEnd, '00:00:03,000');
    expect(ideas.single.proposedEnd, '00:00:02,970');
    expect(cues.first.end, '00:00:03,000');
    expect(SubtitleQualityChecker.proposeTimingSuggestions(cues,
        profile: const SubtitleQualityProfile(minGapMs: 30)), isEmpty);
  });

  test('timing preview refuses overlap and unsafe duration or CPS', () {
    const overlap = [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:03,100', text: 'A'),
      SubtitleQualityCue(id: 2, start: '00:00:03,000',
          end: '00:00:05,000', text: 'B'),
    ];
    expect(SubtitleQualityChecker.proposeTimingSuggestions(overlap), isEmpty);
    const tooShort = [
      SubtitleQualityCue(id: 1, start: '00:00:02,000',
          end: '00:00:03,000', text: 'A'),
      SubtitleQualityCue(id: 2, start: '00:00:03,050',
          end: '00:00:05,000', text: 'B'),
    ];
    expect(SubtitleQualityChecker.proposeTimingSuggestions(tooShort), isEmpty);
    const tooFast = [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:03,000',
          text: 'This is a very long subtitle that will be too fast'),
      SubtitleQualityCue(id: 2, start: '00:00:03,050',
          end: '00:00:05,000', text: 'B'),
    ];
    expect(SubtitleQualityChecker.proposeTimingSuggestions(tooFast), isEmpty);
  });

  test('timing preview does not hide an earlier overlapping cue', () {
    const cues = [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:08,000', text: 'Long caption'),
      SubtitleQualityCue(id: 2, start: '00:00:02,000',
          end: '00:00:04,000', text: 'Short caption'),
      SubtitleQualityCue(id: 3, start: '00:00:04,050',
          end: '00:00:06,000', text: 'Another caption'),
      SubtitleQualityCue(id: 4, start: '00:00:10,000',
          end: '00:00:12,000', text: 'Later caption'),
      SubtitleQualityCue(id: 5, start: '00:00:12,050',
          end: '00:00:14,000', text: 'Final caption'),
    ];
    final ideas = SubtitleQualityChecker.proposeTimingSuggestions(cues);
    // Ending cue 2 at 03,970 would still leave cue 1 running until 08,000.
    // Independent safe pairs later in the file must still be offered.
    expect(ideas, hasLength(1));
    expect(ideas.single.cueId, 4);
    expect(ideas.single.followingCueId, 5);
    expect(ideas.single.proposedEnd, '00:00:11,970');
  });

  test('timing preview checks ties at the preceding end time', () {
    const tied = [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:03,000', text: 'First'),
      SubtitleQualityCue(id: 2, start: '00:00:01,500',
          end: '00:00:03,000', text: 'Second'),
      SubtitleQualityCue(id: 3, start: '00:00:03,050',
          end: '00:00:05,000', text: 'Third'),
    ];
    expect(SubtitleQualityChecker.proposeTimingSuggestions(tied), isEmpty);

    const cleared = [
      SubtitleQualityCue(id: 1, start: '00:00:01,000',
          end: '00:00:01,500', text: 'First'),
      SubtitleQualityCue(id: 2, start: '00:00:01,600',
          end: '00:00:03,000', text: 'Second'),
      SubtitleQualityCue(id: 3, start: '00:00:03,050',
          end: '00:00:05,000', text: 'Third'),
    ];
    final ideas = SubtitleQualityChecker.proposeTimingSuggestions(cleared);
    expect(ideas, hasLength(1));
    expect(ideas.single.cueId, 2);
  });
}
