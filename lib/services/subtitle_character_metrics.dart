/// Character-count semantics shared by mobile Edit Line and Studio Dock.
///
/// Counts the visible text as mobile has historically done: replace HTML
/// `<br>` with a newline, remove HTML and subtitle override tags, and count
/// Dart string code units. The line limit is the user's Edit Line preference.
class SubtitleCharacterMetrics {
  const SubtitleCharacterMetrics({
    required this.count,
    required this.hasLongLine,
  });

  final int count;
  final bool hasLongLine;

  static final RegExp _breakTag = RegExp(r'<br>', caseSensitive: false);
  static final RegExp _htmlTags = RegExp(r'<[^>]*>');
  static final RegExp _subtitleTags = RegExp(r'\{[^}]*\}');

  static SubtitleCharacterMetrics measure(
    String text, {
    int maxLineLength = 32,
  }) {
    if (text.isEmpty) {
      return const SubtitleCharacterMetrics(count: 0, hasLongLine: false);
    }

    final stripped = text
        .replaceAllMapped(_breakTag, (_) => '\n')
        .replaceAll(_htmlTags, '')
        .replaceAll(_subtitleTags, '');
    final hasLongLine = stripped.split('\n').any(
          (line) => line.length > maxLineLength,
        );
    return SubtitleCharacterMetrics(
      count: stripped.length,
      hasLongLine: hasLongLine,
    );
  }
}
