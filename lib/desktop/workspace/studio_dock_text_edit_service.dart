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

  /// Original/source text changes are a separate guarded edit. They must not
  /// silently rewrite translated text or bypass checkpoint history.
  Future<StudioDockSessionSnapshot?> applyOriginal({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
    required String originalText,
  }) async {
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null ||
        session.subtitleCollectionId != baseline.collectionId) return null;
    StudioDockLoadedCue? cue;
    for (final line in baseline.cues) {
      if (line.index == cueNumber) { cue = line; break; }
    }
    if (cue == null || cue.index <= 0) return null;
    if (cue.original == originalText) return baseline;
    final before = SubtitleLine()
      ..index = cue.index
      ..startTime = cue.start
      ..endTime = cue.end
      ..original = cue.original
      ..edited = cue.storedEdited
      ..marked = cue.marked
      ..comment = cue.comment
      ..resolved = cue.resolved;
    final after = SubtitleLine()
      ..index = cue.index
      ..startTime = cue.start
      ..endTime = cue.end
      ..original = originalText
      ..edited = cue.storedEdited
      ..marked = cue.marked
      ..comment = cue.comment
      ..resolved = cue.resolved;
    final applied = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: [before],
      updatedLines: [after],
      operationType: 'edit',
      description: 'Edited original text of line $cueNumber',
    );
    if (!applied) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }

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
