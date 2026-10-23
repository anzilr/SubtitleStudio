import 'package:subtitle_studio/database/models/models.dart';

/// Pure source filter shared by Marked Lines rows and counts.
///
/// A subtitle comment is not the same as a mark. Some callers pass a cached
/// mix of marked and comment-only lines; never infer membership from that
/// input list alone. Keep lines ordered by their actual cue number.
abstract final class MarkedLinesFilter {
  static List<SubtitleLine> apply({
    required List<SubtitleLine> markedLines,
    List<SubtitleLine>? allLinesWithComments,
    required bool includeUnmarkedComments,
  }) {
    final byIndex = <int, SubtitleLine>{};
    for (final line in markedLines) {
      if (line.marked) byIndex[line.index] = line;
    }
    if (includeUnmarkedComments) {
      for (final line in allLinesWithComments ?? const <SubtitleLine>[]) {
        if (line.comment?.trim().isNotEmpty == true) {
          // Preserve the already supplied marked row when duplicates exist.
          byIndex.putIfAbsent(line.index, () => line);
        }
      }
    }
    return byIndex.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }
}
