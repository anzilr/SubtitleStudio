import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';
import 'studio_dock_timing_edit_service.dart';

class StudioDockStructureChange {
  const StudioDockStructureChange(this.snapshot, this.selectedCueNumber);

  final StudioDockSessionSnapshot snapshot;
  /// -1 means the last cue was removed and the collection is now empty.
  final int selectedCueNumber;
}

/// Adds/deletes cues using the shared V2 checkpoint transaction and a full
/// optimistic snapshot comparison. A stale cue number can never silently
/// shift a later subtitle after another editor has inserted or deleted lines.
class StudioDockCueStructureService {
  const StudioDockCueStructureService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  List<SubtitleLine> _persistedLines(StudioDockSessionSnapshot baseline) => [
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

  Future<bool> _owns(StudioDockSessionSnapshot baseline) async {
    final session = await _projects.getSession(baseline.sessionId);
    return session != null &&
        session.subtitleCollectionId == baseline.collectionId;
  }

  Future<StudioDockStructureChange?> insert({
    required StudioDockSessionSnapshot baseline,
    required int? afterCueNumber,
    required String start,
    required String end,
    required String original,
    required String edited,
  }) async {
    if (StudioDockTimingEditService.validate(start, end) != null ||
        !await _owns(baseline)) return null;
    final position = afterCueNumber == null
        ? 0
        : baseline.cues.indexWhere((cue) => cue.index == afterCueNumber) + 1;
    if (afterCueNumber != null && position == 0) return null;
    final line = SubtitleLine()
      ..index = position + 1
      ..startTime = start
      ..endTime = end
      ..original = original
      ..edited = edited.isEmpty ? null : edited
      ..marked = false
      ..comment = null
      ..resolved = false;

    final insertedNumber = await _subtitles.addLineFromSnapshotWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: _persistedLines(baseline),
      line: line,
      insertIndex: position,
    );
    if (insertedNumber == null) return null;
    final snapshot = await StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
    return StudioDockStructureChange(snapshot, insertedNumber);
  }

  Future<StudioDockStructureChange?> delete({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
  }) async {
    if (!await _owns(baseline)) return null;
    final position = baseline.cues.indexWhere((cue) => cue.index == cueNumber);
    if (position < 0) return null;
    final deleted = await _subtitles.deleteLineFromSnapshotWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: _persistedLines(baseline),
      index: position,
    );
    if (!deleted) return null;
    final snapshot = await StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
    final selected = snapshot.cues.isEmpty
        ? -1
        : snapshot.cues[position.clamp(0, snapshot.cues.length - 1).toInt()].index;
    return StudioDockStructureChange(snapshot, selected);
  }
}
