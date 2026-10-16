import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// One match in a subtitle as displayed when Search was run.
///
/// Start and end are UTF-16 string offsets in the effective edited/original
/// text. A plan never touches Isar; persistence happens via the shared
/// history-aware batch mutation service.
class SubtitleSearchMatch {
  final SubtitleLine line;
  final int start;
  final int end;

  const SubtitleSearchMatch({
    required this.line,
    required this.start,
    required this.end,
  });
}

class SubtitleReplacementPlan {
  final List<SubtitleLine> expectedLines;
  final List<SubtitleLine> updatedLines;
  final int replacements;

  const SubtitleReplacementPlan({
    required this.expectedLines,
    required this.updatedLines,
    required this.replacements,
  });
}

class SubtitleSearchReplacePlanner {
  const SubtitleSearchReplacePlanner._();

  /// Build one replacement per affected cue, using descending match offsets.
  ///
  /// The original visible lines become expected optimistic-concurrency values
  /// for the Isar transaction. Even when multiple selected matches belong to
  /// one cue, every replacement is kept and all other persisted fields survive.
  static SubtitleReplacementPlan build({
    required Iterable<SubtitleSearchMatch> matches,
    required String searchTerm,
    required String replacement,
    required bool caseSensitive,
  }) {
    if (searchTerm.isEmpty) {
      throw const FormatException('Search term cannot be empty.');
    }
    final expectedByCue = <int, SubtitleLine>{};
    final spansByCue = <int, List<SubtitleSearchMatch>>{};
    var count = 0;

    for (final match in matches) {
      final source = match.line;
      if (source.index <= 0) {
        throw const FormatException('Subtitle cue numbers must be positive.');
      }
      final effectiveText = source.edited ?? source.original;
      if (match.start < 0 ||
          match.end > effectiveText.length ||
          match.start >= match.end) {
        throw FormatException('Invalid match range in cue ${source.index}.');
      }
      final actual = effectiveText.substring(match.start, match.end);
      if ((caseSensitive ? actual : actual.toLowerCase()) !=
          (caseSensitive ? searchTerm : searchTerm.toLowerCase())) {
        throw FormatException('Search results are stale for cue ${source.index}.');
      }

      final previous = expectedByCue[source.index];
      if (previous != null &&
          !CheckpointStateReducer.samePersistedLine(previous, source)) {
        throw FormatException('Conflicting snapshots for cue ${source.index}.');
      }
      expectedByCue.putIfAbsent(
        source.index,
        () => CheckpointStateReducer.copyLine(source),
      );
      spansByCue.putIfAbsent(source.index, () => []).add(match);
      count++;
    }

    final updated = <SubtitleLine>[];
    for (final entry in expectedByCue.entries) {
      final source = entry.value;
      var content = source.edited ?? source.original;
      final ranges = spansByCue[entry.key]!
        ..sort((a, b) => b.start.compareTo(a.start));

      // Descending offsets keep the remaining match positions stable.
      var nextBoundary = content.length;
      for (final match in ranges) {
        if (match.end > nextBoundary) {
          throw FormatException('Overlapping matches in cue ${entry.key}.');
        }
        content = content.replaceRange(match.start, match.end, replacement);
        nextBoundary = match.start;
      }

      updated.add(CheckpointStateReducer.copyLine(source)..edited = content);
    }

    return SubtitleReplacementPlan(
      expectedLines: expectedByCue.values.toList(growable: false),
      updatedLines: updated,
      replacements: count,
    );
  }
}
