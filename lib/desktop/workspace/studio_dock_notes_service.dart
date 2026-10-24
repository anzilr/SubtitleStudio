import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// Atomic, optimistic edits to a cue's review mark, comment and resolution.
/// Uses the same V2 history transaction as text and timing edits rather than
/// writing annotation flags through a second desktop-specific repository.
class StudioDockNotesService {
  const StudioDockNotesService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  Future<StudioDockSessionSnapshot?> apply({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
    required String? comment,
    required bool marked,
    required bool resolved,
  }) async {
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }

    StudioDockLoadedCue? cue;
    for (final item in baseline.cues) {
      if (item.index == cueNumber) { cue = item; break; }
    }
    if (cue == null || cue.index <= 0) return null;
    final selectedCue = cue;

    final normalizedComment = comment?.trim().isEmpty == true ? null : comment;
    // A comment or a resolved review item remains marked. Explicit Unmark in
    // the inspector clears both the note and its resolved state beforehand.
    final nextMarked = marked || normalizedComment != null || resolved;
    final nextResolved = nextMarked && resolved;
    SubtitleLine clone() => SubtitleLine()
      ..index = selectedCue.index
      ..startTime = selectedCue.start
      ..endTime = selectedCue.end
      ..original = selectedCue.original
      ..edited = selectedCue.storedEdited
      ..marked = selectedCue.marked
      ..comment = selectedCue.comment
      ..resolved = selectedCue.resolved;

    final before = clone();
    final after = clone()
      ..marked = nextMarked
      ..comment = normalizedComment
      ..resolved = nextResolved;
    if (CheckpointStateReducer.samePersistedLine(before, after)) {
      final current = await _subtitles.fetchLines(baseline.collectionId);
      final matches = current.where((line) => line.index == cueNumber);
      if (matches.length != 1 ||
          !CheckpointStateReducer.samePersistedLine(matches.single, before)) {
        return null;
      }
      return baseline;
    }
    final saved = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: [before],
      updatedLines: [after],
      operationType: 'annotation',
      description: 'Updated review notes on line $cueNumber',
    );
    if (!saved) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
