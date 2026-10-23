import 'package:subtitle_studio/utils/time_parser.dart';
import 'package:subtitle_studio/widgets/video/subtitle.dart';

import 'studio_dock_session_snapshot.dart';

/// Builds the existing player model without a second subtitle/timing engine.
class StudioDockMediaPlan {
  const StudioDockMediaPlan._();

  /// Fail closed if a desktop bookmark/path is missing. No media controller
  /// is constructed merely because a file name exists in preferences.
  static Future<String?> resolveVideoPath({
    required int collectionId,
    required Future<String?> Function(int) getSavedPath,
    required Future<bool> Function(String) exists,
  }) async {
    final saved = await getSavedPath(collectionId);
    if (saved == null || saved.trim().isEmpty) return null;
    if (!await exists(saved)) return null;
    return saved;
  }

  /// Match the normal player's distinction between an absent translation
  /// (null -> original) and an intentionally empty translation ('' -> blank).
  static List<Subtitle> overlayCues(StudioDockSessionSnapshot snapshot) {
    final result = <Subtitle>[];
    for (final cue in snapshot.cues) {
      try {
        final start = parseTimeString(cue.start);
        final end = parseTimeString(cue.end);
        if (start.isNegative || end <= start) continue;
        result.add(Subtitle(
          index: cue.index,
          start: start,
          end: end,
          text: cue.storedEdited ?? cue.original,
          marked: cue.marked,
          comment: cue.comment,
        ));
      } on FormatException {
        // One malformed cue must not crash the entire media display.
      }
    }
    return result;
  }
}
