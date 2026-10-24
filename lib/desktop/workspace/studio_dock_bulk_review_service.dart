import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// Mark or unmark a selected group of cues in one optimistic history edit.
/// Explicit unmark clears the associated note and resolution, consistent with
/// the single-cue Notes inspector, and must be confirmed in the workspace.
class StudioDockBulkReviewService {
  const StudioDockBulkReviewService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  Future<StudioDockSessionSnapshot?> apply({
    required StudioDockSessionSnapshot baseline,
    required Set<int> cueNumbers,
    required bool marked,
  }) async {
    if (cueNumbers.isEmpty || cueNumbers.any((id) => id <= 0)) return null;
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }

    final byIndex = {
      for (final cue in baseline.cues) cue.index: cue,
    };
    final before = <SubtitleLine>[];
    final after = <SubtitleLine>[];
    for (final index in cueNumbers.toList()..sort()) {
      final cue = byIndex[index];
      if (cue == null) return null;
      SubtitleLine clone() => SubtitleLine()
        ..index = cue.index
        ..startTime = cue.start
        ..endTime = cue.end
        ..original = cue.original
        ..edited = cue.storedEdited
        ..marked = cue.marked
        ..comment = cue.comment
        ..resolved = cue.resolved;
      final current = clone();
      final replacement = clone()
        ..marked = marked;
      if (!marked) {
        replacement.comment = null;
        replacement.resolved = false;
      }
      if (CheckpointStateReducer.samePersistedLine(current, replacement)) {
        continue;
      }
      before.add(current);
      after.add(replacement);
    }
    if (after.isEmpty) return baseline;
    final saved = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: before,
      updatedLines: after,
      operationType: 'annotation',
      description: marked
          ? 'Marked ${after.length} subtitles for review'
          : 'Removed review marks from ${after.length} subtitles',
    );
    if (!saved) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
