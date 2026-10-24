import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// The review state is independent of the review mark: resolving a subtitle
/// keeps its note and mark, while reopening only clears the resolved flag.
/// Explicit unmark is the sole destructive action, clearing both annotations.
enum StudioDockReviewAction { mark, unmark, resolve, reopen }

/// Apply a review action to the complete selection in one optimistic history
/// transaction, including guard checks for selected cues that do not change.
class StudioDockBulkReviewService {
  const StudioDockBulkReviewService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  Future<StudioDockSessionSnapshot?> apply({
    required StudioDockSessionSnapshot baseline,
    required Set<int> cueNumbers,
    required StudioDockReviewAction action,
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
    var changedCount = 0;
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
      final replacement = clone();
      switch (action) {
        case StudioDockReviewAction.mark:
          replacement.marked = true;
        case StudioDockReviewAction.unmark:
          replacement.marked = false;
          replacement.comment = null;
          replacement.resolved = false;
        case StudioDockReviewAction.resolve:
          // A resolved item is always in the review list. Never erase notes.
          replacement.marked = true;
          replacement.resolved = true;
        case StudioDockReviewAction.reopen:
          replacement.resolved = false;
      }
      if (!CheckpointStateReducer.samePersistedLine(current, replacement)) {
        changedCount++;
      }
      before.add(current);
      after.add(replacement);
    }
    if (changedCount == 0) {
      final current = await _subtitles.fetchLines(baseline.collectionId);
      final currentByIndex = {for (final cue in current) cue.index: cue};
      return before.every((expected) {
        final actual = currentByIndex[expected.index];
        return actual != null &&
            CheckpointStateReducer.samePersistedLine(expected, actual);
      }) ? baseline : null;
    }
    final description = switch (action) {
      StudioDockReviewAction.mark =>
          'Marked $changedCount subtitles for review',
      StudioDockReviewAction.unmark =>
          'Removed review marks from $changedCount subtitles',
      StudioDockReviewAction.resolve =>
          'Resolved reviews on $changedCount subtitles',
      StudioDockReviewAction.reopen =>
          'Reopened reviews on $changedCount subtitles',
    };
    final saved = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: before,
      updatedLines: after,
      operationType: 'annotation',
      description: description,
    );
    if (!saved) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
