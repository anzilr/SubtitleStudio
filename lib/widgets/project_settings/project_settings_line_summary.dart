import 'package:subtitle_studio/database/models/models.dart';

/// Synchronous project statistics derived from lines the caller has already
/// loaded. Opening Project Settings must not query the large embedded
/// collection again just to obtain counts and review marks.
class ProjectSettingsLineSummary {
  const ProjectSettingsLineSummary({
    required this.sessionInfo,
    required this.markedLines,
  });

  final Map<String, dynamic> sessionInfo;
  final List<SubtitleLine> markedLines;

  static final Map<String, RegExp> _scripts = {
    'ML': RegExp(r'[\u0D00-\u0D7F]'),
    'HI': RegExp(r'[\u0900-\u097F]'),
    'AR': RegExp(r'[\u0600-\u06FF]'),
    'ZH': RegExp(r'[\u4E00-\u9FFF]'),
    'JA': RegExp(r'[\u3040-\u309F\u30A0-\u30FF]'),
    'KO': RegExp(r'[\uAC00-\uD7AF]'),
    'RU': RegExp(r'[\u0400-\u04FF]'),
  };

  factory ProjectSettingsLineSummary.fromLoadedLines(
    List<SubtitleLine> lines, {
    required int lastEditedIndex,
  }) {
    var editedCount = 0;
    final marked = <SubtitleLine>[];
    final languages = <String>{'EN'};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.edited?.isNotEmpty == true) editedCount++;
      if (line.marked) marked.add(line);
      if (i < 10) {
        final text = line.original + (line.edited ?? '');
        for (final script in _scripts.entries) {
          if (script.value.hasMatch(text)) languages.add(script.key);
        }
      }
    }
    return ProjectSettingsLineSummary(
      sessionInfo: {
        'totalLines': lines.length,
        'editedLines': editedCount,
        'lastEditedIndex': lastEditedIndex,
        'progress': lines.isEmpty ? 0.0 : editedCount / lines.length,
        'languageCodes': languages.join('/'),
        'languages': languages.toList(),
      },
      markedLines: List.unmodifiable(marked),
    );
  }
}
