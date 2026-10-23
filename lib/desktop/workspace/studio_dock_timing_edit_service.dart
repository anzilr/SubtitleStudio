import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// A single, optimistic, checkpoint-backed timing edit in Studio Dock.
/// The full stored cue is compared inside the shared transaction, including
/// the text and review metadata which this command must not overwrite.
class StudioDockTimingEditService {
  const StudioDockTimingEditService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  static String? validate(String start, String end) {
    // Preserve the canonical persisted SRT time format. The more permissive
    // text-input validator also accepts one-digit components, but Studio Dock
    // must not silently reinterpret or truncate those user-entered values.
    final canonical = RegExp(r'^\d{2}:\d{2}:\d{2},\d{3}$');
    if (!canonical.hasMatch(start) || !canonical.hasMatch(end)) {
      return 'Use HH:mm:ss,SSS for both times';
    }
    return TimeValidator.validateTimeString(start) ??
        TimeValidator.validateTimeString(end) ??
        TimeValidator.validateTimeOrder(start, end);
  }

  Future<StudioDockSessionSnapshot?> apply({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
    required String start,
    required String end,
  }) async {
    if (validate(start, end) != null) return null;
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null ||
        session.subtitleCollectionId != baseline.collectionId) return null;

    StudioDockLoadedCue? cue;
    for (final item in baseline.cues) {
      if (item.index == cueNumber) {
        cue = item;
        break;
      }
    }
    if (cue == null || cue.index <= 0) return null;
    if (start == cue.start && end == cue.end) return baseline;

    final selectedCue = cue;
    SubtitleLine cloneBaseline() => SubtitleLine()
      ..index = selectedCue.index
      ..startTime = selectedCue.start
      ..endTime = selectedCue.end
      ..original = selectedCue.original
      ..edited = selectedCue.storedEdited
      ..marked = selectedCue.marked
      ..comment = selectedCue.comment
      ..resolved = selectedCue.resolved;

    final before = cloneBaseline();
    final after = cloneBaseline()
      ..startTime = start
      ..endTime = end;
    final applied = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: [before],
      updatedLines: [after],
      operationType: 'timing',
      description: 'Changed timing for line $cueNumber',
    );
    if (!applied) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
