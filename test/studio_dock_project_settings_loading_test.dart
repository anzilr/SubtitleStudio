import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/project_settings/project_settings_line_summary.dart';

void main() {
  test('settings calculates statistics and marks from the loaded lines', () {
    final lines = List<SubtitleLine>.generate(990, (index) => SubtitleLine()
      ..index = index + 1
      ..original = 'Subtitle $index');
    lines[0].edited = 'Translation';
    lines[1].marked = true;
    lines[2].original = 'മലയാളം';

    final summary = ProjectSettingsLineSummary.fromLoadedLines(
      lines,
      lastEditedIndex: 35,
    );

    expect(summary.sessionInfo['totalLines'], 990);
    expect(summary.sessionInfo['editedLines'], 1);
    expect(summary.sessionInfo['lastEditedIndex'], 35);
    expect(summary.sessionInfo['progress'], closeTo(1 / 990, 0.000001));
    expect(summary.sessionInfo['languageCodes'], 'EN/ML');
    expect(summary.markedLines.single.index, 2);
    expect(summary.markedLines.length, 1);
  });

  test('empty projects produce safe statistics', () {
    final summary = ProjectSettingsLineSummary.fromLoadedLines(
      const <SubtitleLine>[],
      lastEditedIndex: 1,
    );
    expect(summary.sessionInfo['totalLines'], 0);
    expect(summary.sessionInfo['progress'], 0.0);
    expect(summary.markedLines, isEmpty);
  });
}
