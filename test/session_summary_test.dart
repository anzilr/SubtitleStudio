import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/models/session_summary.dart';

SubtitleLine _line(String original, {String? edited}) {
  return SubtitleLine()
    ..index = 1
    ..startTime = '00:00:01,000'
    ..endTime = '00:00:02,000'
    ..original = original
    ..edited = edited;
}

Session _session({String fileName = 'sample.srt'}) {
  return Session(
    fileName: fileName,
    subtitleCollectionId: 1,
    lastEditedIndex: 4,
  );
}

void main() {
  group('SessionSummaryAnalyzer', () {
    test('does not label Malayalam-only subtitles as English', () {
      final summary = SessionSummaryAnalyzer.analyze(
        _session(),
        [_line('മലയാളം സബ്ടൈറ്റിൽ')],
      );

      expect(summary.languages, ['ML']);
      expect(summary.languageCodes, 'ML');
    });

    test('detects Latin and Malayalam scripts independently', () {
      final summary = SessionSummaryAnalyzer.analyze(
        _session(),
        [_line('Hello മലയാളം')],
      );

      expect(summary.languages, ['EN', 'ML']);
      expect(summary.languageCodes, 'EN/ML');
    });

    test('computes edit progress and last edited index', () {
      final summary = SessionSummaryAnalyzer.analyze(
        _session(),
        [
          _line('One', edited: 'Edited'),
          _line('Two'),
        ],
      );

      expect(summary.totalLines, 2);
      expect(summary.editedLines, 1);
      expect(summary.lastEditedIndex, 4);
    });

    test('detects MSone signature in trailing subtitle lines', () {
      final summary = SessionSummaryAnalyzer.analyze(
        _session(),
        [_line('Visit www.malayalamsubtitles.org')],
      );

      expect(summary.isMsoneSubtitle, isTrue);
    });

    test('uses filename fallback for MSone detection', () {
      final summary = SessionSummaryAnalyzer.analyze(
        _session(fileName: 'MSONE_movie.srt'),
        const [],
      );

      expect(summary.isMsoneSubtitle, isTrue);
    });

    test('empty summary uses no guessed language', () {
      final summary = SessionSummary.empty(_session());

      expect(summary.totalLines, 0);
      expect(summary.languages, isEmpty);
      expect(summary.languageCodes, '—');
    });
  });
}
