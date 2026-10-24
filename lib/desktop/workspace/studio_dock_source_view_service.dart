import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/services/raw_srt_document.dart';
import 'package:subtitle_studio/screens/edit/services/source_view_reconciler.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// Studio Dock adapter for the existing raw SRT editor and shared history.
/// It does not own a new parser, persistence model or encoding/file writer.
class StudioDockSourceViewService {
  const StudioDockSourceViewService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  static List<SubtitleLine> _persistedLines(
      StudioDockSessionSnapshot baseline) => [
    for (final cue in baseline.cues)
      SubtitleLine()
        ..index = cue.index
        ..startTime = cue.start
        ..endTime = cue.end
        ..original = cue.original
        ..edited = cue.storedEdited
        ..marked = cue.marked
        ..comment = cue.comment
        ..resolved = cue.resolved,
  ];

  /// Display the exact rendered text, including intentionally empty edits.
  static String compose(StudioDockSessionSnapshot snapshot) =>
      RawSrtDocument.compose([
        for (final cue in snapshot.cues)
          SubtitleEntry(
            index: cue.index.toString(),
            startTime: cue.start,
            endTime: cue.end,
            text: cue.storedEdited ?? cue.original,
          ),
      ]);

  /// Validate a complete raw document and apply it atomically if the entire
  /// persisted baseline still matches. Invalid input throws [FormatException];
  /// stale edits return null and must leave the user's raw draft untouched.
  Future<StudioDockSessionSnapshot?> apply({
    required StudioDockSessionSnapshot baseline,
    required String rawSource,
  }) async {
    final entries = RawSrtDocument.parseStrict(rawSource);
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }

    final previous = _persistedLines(baseline);
    final next = SourceViewReconciler.reconcile(
      existingLines: previous,
      entries: entries,
      isEditMode: baseline.isEditMode,
    );
    // Avoid adding a new checkpoint when the user only changed separators,
    // indentation or other formatting outside the persisted subtitle data.
    if (CheckpointStateReducer.samePersistedLines(previous, next)) {
      final current = await _subtitles.fetchLines(baseline.collectionId);
      if (!CheckpointStateReducer.samePersistedLines(current, previous)) {
        return null;
      }
      return baseline;
    }

    final applied = await _subtitles.syncSourceViewFromSnapshotWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: previous,
      entries: entries,
      isEditMode: baseline.isEditMode,
    );
    if (!applied) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
