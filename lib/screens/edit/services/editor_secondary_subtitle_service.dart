import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';

/// The selected secondary track's origin, independent of whether it is shown.
///
/// A matching first cue is not evidence that an external track is derived
/// from the primary subtitles. This explicit value avoids that ambiguity.
enum EditorSecondarySubtitleSource { none, originalText, external }

/// Pure projection of primary subtitle data for the secondary video overlay.
class EditorSecondarySubtitleService {
  const EditorSecondarySubtitleService._();

  /// Rebuild only an original-text overlay. External tracks must survive
  /// primary edits unchanged, even when their first text happens to match.
  static List<SimpleSubtitleLine>? refreshedOriginal({
    required EditorSecondarySubtitleSource source,
    required List<SubtitleLine> primaryLines,
  }) {
    if (source != EditorSecondarySubtitleSource.originalText) return null;
    return fromOriginal(primaryLines);
  }

  /// Preserve every primary cue, including intentionally empty text, while
  /// adapting legacy line-break tags to the video overlay's text format.
  static List<SimpleSubtitleLine> fromOriginal(
    List<SubtitleLine> primaryLines,
  ) {
    return List<SimpleSubtitleLine>.unmodifiable(
      primaryLines.map(
        (line) => SimpleSubtitleLine(
          index: line.index,
          startTime: line.startTime,
          endTime: line.endTime,
          text: line.original.replaceAll('<br>', '\n'),
        ),
      ),
    );
  }
}
