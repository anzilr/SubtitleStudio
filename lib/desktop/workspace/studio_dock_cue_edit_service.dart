import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';
import 'studio_dock_timing_edit_service.dart';

/// One atomic edit to a cue's translated text and time interval. The Text
/// inspector may change both fields before Apply, so they must share a single
/// optimistic checkpoint rather than becoming two independently saved edits.
class StudioDockCueEditService {
  const StudioDockCueEditService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  Future<StudioDockSessionSnapshot?> apply({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
    required String editedText,
    required String start,
    required String end,
  }) async {
    if (StudioDockTimingEditService.validate(start, end) != null) return null;
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }
    StudioDockLoadedCue? cue;
    for (final item in baseline.cues) {
      if (item.index == cueNumber) { cue = item; break; }
    }
    if (cue == null || cue.index <= 0) return null;
    final selected = cue;
    SubtitleLine clone() => SubtitleLine()
      ..index = selected.index
      ..startTime = selected.start
      ..endTime = selected.end
      ..original = selected.original
      ..edited = selected.storedEdited
      ..marked = selected.marked
      ..comment = selected.comment
      ..resolved = selected.resolved;

    final before = clone();
    final after = clone()
      ..edited = editedText
      ..startTime = start
      ..endTime = end;
    if (CheckpointStateReducer.samePersistedLine(before, after)) {
      final persisted = await _subtitles.fetchLines(baseline.collectionId);
      final matches = persisted.where((line) => line.index == cueNumber);
      return matches.length == 1 &&
          CheckpointStateReducer.samePersistedLine(matches.single, before)
          ? baseline : null;
    }
    final saved = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: [before],
      updatedLines: [after],
      operationType: 'edit',
      description: 'Updated text and timing on line $cueNumber',
    );
    if (!saved) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
