import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// Applies a single edited-text change through the shared atomic checkpoint
/// transaction. This service does not manage files, media, or a separate DB.
///
/// [baseline] is the exact snapshot the user saw before editing. We rebuild
/// the full persisted cue so the repository can reject stale marks, comments,
/// timing, and text changes *inside* the transaction.
class StudioDockTextEditService {
  const StudioDockTextEditService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  Future<StudioDockSessionSnapshot?> apply({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
    required String editedText,
  }) async {
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null ||
        session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }

    StudioDockLoadedCue? cue;
    for (final item in baseline.cues) {
      if (item.index == cueNumber) {
        cue = item;
        break;
      }
    }
    if (cue == null || cue.index <= 0) return null;

    // Avoid manufacturing a checkpoint just by pressing Apply on an
    // unchanged draft (including the difference between null and '').
    if (editedText == cue.edited) return baseline;

    SubtitleLine cloneBaseline() => SubtitleLine()
      ..index = cue!.index
      ..startTime = cue.start
      ..endTime = cue.end
      ..original = cue.original
      ..edited = cue.storedEdited
      ..marked = cue.marked
      ..comment = cue.comment
      ..resolved = cue.resolved;

    final before = cloneBaseline();
    final after = cloneBaseline()..edited = editedText;
    final applied = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: [before],
      updatedLines: [after],
      operationType: 'edit',
      description: 'Edited line $cueNumber',
    );
    if (!applied) return null;

    // Re-read the authoritative collection after committing. The returned
    // snapshot becomes the baseline for the next edit in the same session.
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
