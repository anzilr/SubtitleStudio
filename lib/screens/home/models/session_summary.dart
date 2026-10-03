import 'package:subtitle_studio/database/models/models.dart';

class SessionSummary {
  final int totalLines;
  final int editedLines;
  final int lastEditedIndex;
  final List<String> languages;
  final bool isMsoneSubtitle;

  const SessionSummary({
    required this.totalLines,
    required this.editedLines,
    required this.lastEditedIndex,
    required this.languages,
    required this.isMsoneSubtitle,
  });

  String get languageCodes =>
      languages.isEmpty ? '—' : languages.join('/');

  factory SessionSummary.empty(Session session) {
    return SessionSummary(
      totalLines: 0,
      editedLines: 0,
      lastEditedIndex: session.lastEditedIndex ?? 1,
      languages: const [],
      isMsoneSubtitle: SessionSummaryAnalyzer.filenameLooksMsone(
        session.fileName,
      ),
    );
  }
}

class SessionSummaryAnalyzer {
  const SessionSummaryAnalyzer._();

  static SessionSummary analyze(
    Session session,
    List<SubtitleLine> subtitleLines,
  ) {
    final editedCount = subtitleLines
        .where((line) => line.edited?.isNotEmpty == true)
        .length;

    return SessionSummary(
      totalLines: subtitleLines.length,
      editedLines: editedCount,
      lastEditedIndex: session.lastEditedIndex ?? 1,
      languages: _detectLanguages(subtitleLines),
      isMsoneSubtitle:
          _containsMsoneSignature(subtitleLines) ||
          filenameLooksMsone(session.fileName),
    );
  }

  static bool filenameLooksMsone(String fileName) {
    final normalized = fileName.toLowerCase();
    return normalized.contains('malayalamsubtitles') ||
        normalized.contains('msone');
  }

  static bool _containsMsoneSignature(List<SubtitleLine> subtitleLines) {
    final linesToCheck = subtitleLines.length >= 5
        ? subtitleLines.sublist(subtitleLines.length - 5)
        : subtitleLines;

    for (final line in linesToCheck) {
      final text = '${line.original}${line.edited ?? ''}'.toLowerCase();
      if (text.contains('www.malayalamsubtitles.org') ||
          text.contains('msone') ||
          text.contains('msonepage')) {
        return true;
      }
    }

    return false;
  }

  static List<String> _detectLanguages(List<SubtitleLine> subtitleLines) {
    final detected = <String>{};
    final linesToCheck = subtitleLines.take(10);

    for (final line in linesToCheck) {
      final text = '${line.original}${line.edited ?? ''}';

      if (RegExp(r'[A-Za-z]').hasMatch(text)) detected.add('EN');
      if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(text)) detected.add('ML');
      if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) detected.add('HI');
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) detected.add('AR');
      if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text)) detected.add('ZH');
      if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text)) {
        detected.add('JA');
      }
      if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) detected.add('KO');
      if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) detected.add('RU');
    }

    const displayOrder = ['EN', 'ML', 'HI', 'AR', 'ZH', 'JA', 'KO', 'RU'];
    return [
      for (final code in displayOrder)
        if (detected.contains(code)) code,
    ];
  }
}
