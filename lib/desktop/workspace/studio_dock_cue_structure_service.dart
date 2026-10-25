import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';

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


  static String? validateSplit(String start, String splitAt, String end) {
    if (StudioDockTimingEditService.validate(start, splitAt) != null ||
        StudioDockTimingEditService.validate(splitAt, end) != null) {
      return 'Split time must be strictly inside the line (HH:mm:ss,SSS).';
    }
    return null;
  }

  Future<StudioDockStructureChange?> split({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
    required String splitAt,
    required String firstOriginal,
    required String secondOriginal,
    required String firstEdited,
    required String secondEdited,
  }) async {
    if (!await _owns(baseline)) return null;
    final position = baseline.cues.indexWhere((cue) => cue.index == cueNumber);
    if (position < 0) return null;
    final cue = baseline.cues[position];
    if (validateSplit(cue.start, splitAt, cue.end) != null) return null;
    // Preserve null-vs-empty edited semantics unless the user supplies new
    // translated text for a formerly unedited cue.
    final hasEdited = cue.storedEdited != null ||
        firstEdited.isNotEmpty || secondEdited.isNotEmpty;
    SubtitleLine part({required bool second}) => SubtitleLine()
      ..index = cue.index + (second ? 1 : 0)
      ..startTime = second ? splitAt : cue.start
      ..endTime = second ? cue.end : splitAt
      ..original = second ? secondOriginal : firstOriginal
      ..edited = hasEdited ? (second ? secondEdited : firstEdited) : null
      ..marked = second ? false : cue.marked
      ..comment = second ? null : cue.comment
      ..resolved = second ? false : cue.resolved;

    final selected = await _subtitles.splitLineFromSnapshotWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: _persistedLines(baseline),
      index: position,
      firstPart: part(second: false),
      secondPart: part(second: true),
    );
    if (selected == null) return null;
    final snapshot = await StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId, collectionId: baseline.collectionId);
    return StudioDockStructureChange(snapshot, selected);
  }

  Future<StudioDockStructureChange?> merge({
    required StudioDockSessionSnapshot baseline,
    required int cueNumber,
    required bool withPrevious,
  }) async {
    if (!await _owns(baseline)) return null;
    final selected = baseline.cues.indexWhere((cue) => cue.index == cueNumber);
    if (selected < 0) return null;
    final firstIndex = withPrevious ? selected - 1 : selected;
    if (firstIndex < 0 || firstIndex + 1 >= baseline.cues.length) return null;
    final first = baseline.cues[firstIndex];
    final second = baseline.cues[firstIndex + 1];
    final firstEnd = TimeValidator.timeStringToMilliseconds(first.end);
    final secondEnd = TimeValidator.timeStringToMilliseconds(second.end);
    final end = firstEnd >= secondEnd ? first.end : second.end;
    if (StudioDockTimingEditService.validate(first.start, end) != null) {
      return null;
    }
    // If one cue was translated, its neighbor must not vanish from the
    // translated result: use its original text as a fallback. Otherwise keep
    // the nullable edited field untouched for an entirely untranslated pair.
    final edited = first.storedEdited == null && second.storedEdited == null
        ? null
        : '${first.storedEdited ?? first.original}\n'
          '${second.storedEdited ?? second.original}';
    final notes = [first.comment, second.comment]
        .whereType<String>().where((note) => note.isNotEmpty).toList();
    final merged = SubtitleLine()
      ..index = first.index
      ..startTime = first.start
      ..endTime = end
      ..original = '${first.original}\n${second.original}'
      ..edited = edited
      ..marked = first.marked || second.marked
      ..comment = notes.isEmpty ? null : notes.join('\n')
      ..resolved = first.resolved && second.resolved;

    final mergedNumber = await _subtitles.mergeAdjacentLinesFromSnapshotWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: _persistedLines(baseline),
      firstIndex: firstIndex,
      mergedLine: merged,
    );
    if (mergedNumber == null) return null;
    final snapshot = await StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId, collectionId: baseline.collectionId);
    return StudioDockStructureChange(snapshot, mergedNumber);
  }
}
