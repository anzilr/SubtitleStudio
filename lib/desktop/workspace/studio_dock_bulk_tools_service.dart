import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';
import 'studio_dock_style_actions.dart';
import 'studio_dock_timing_edit_service.dart';

/// Production batch tools: every changed cue is an optimistic expected/next
/// pair committed through the existing shared checkpoint transaction.
class StudioDockBulkToolsService {
  const StudioDockBulkToolsService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  static const _lastSrtMillisecond = 86399999;

  static SubtitleLine _copy(StudioDockLoadedCue cue) => SubtitleLine()
    ..index = cue.index
    ..startTime = cue.start
    ..endTime = cue.end
    ..original = cue.original
    ..edited = cue.storedEdited
    ..marked = cue.marked
    ..comment = cue.comment
    ..resolved = cue.resolved;

  static String formatMilliseconds(int milliseconds) {
    if (milliseconds < 0 || milliseconds > _lastSrtMillisecond) {
      throw const FormatException('Shift would move a cue beyond 00:00–23:59:59,999.');
    }
    final hours = (milliseconds ~/ 3600000).toString().padLeft(2, '0');
    final minutes = ((milliseconds ~/ 60000) % 60).toString().padLeft(2, '0');
    final seconds = ((milliseconds ~/ 1000) % 60).toString().padLeft(2, '0');
    final millis = (milliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$millis';
  }

  static List<SubtitleLine> planShift(
      StudioDockSessionSnapshot snapshot, int deltaMilliseconds) {
    if (deltaMilliseconds == 0) return const [];
    return [
      for (final cue in snapshot.cues)
        _shiftCue(cue, deltaMilliseconds),
    ];
  }

  /// Match the mobile selected-sync planner: new first-start/last-end anchor
  /// scales relative cue starts while retaining each selected cue's duration.
  /// Reject out-of-SRT values *before* entering the shared history writer.
  static List<SubtitleLine> planShiftSelected(
    StudioDockSessionSnapshot snapshot,
    Set<int> cueNumbers,
    String newStart,
    String newEnd,
  ) {
    if (cueNumbers.isEmpty ||
        StudioDockTimingEditService.validate(newStart, newEnd) != null) {
      throw const FormatException('Select cues and valid start/end timecodes.');
    }
    final selected = [
      for (final cue in snapshot.cues)
        if (cueNumbers.contains(cue.index)) cue,
    ];
    if (selected.length != cueNumbers.length) {
      throw const FormatException('The subtitle selection is out of date.');
    }
    for (final cue in selected) {
      if (StudioDockTimingEditService.validate(cue.start, cue.end) != null) {
        throw FormatException('Invalid timecodes on subtitle ${cue.index}.');
      }
    }
    final originalStart =
        TimeValidator.timeStringToMilliseconds(selected.first.start);
    final originalEnd =
        TimeValidator.timeStringToMilliseconds(selected.last.end);
    final originalSpan = originalEnd - originalStart;
    if (originalSpan <= 0) {
      throw const FormatException('Selected subtitles have an invalid time span.');
    }
    final newStartMs = TimeValidator.timeStringToMilliseconds(newStart);
    final newEndMs = TimeValidator.timeStringToMilliseconds(newEnd);
    final factor = (newEndMs - newStartMs) / originalSpan;
    return [
      for (final cue in selected)
        _shiftSelectedCue(cue, originalStart, newStartMs, factor),
    ];
  }

  static SubtitleLine _shiftSelectedCue(
      StudioDockLoadedCue cue, int originalStart, int newStart, double factor) {
    final cueStart = TimeValidator.timeStringToMilliseconds(cue.start);
    final duration = TimeValidator.timeStringToMilliseconds(cue.end) - cueStart;
    final shiftedStart = newStart + ((cueStart - originalStart) * factor).round();
    final startText = formatMilliseconds(shiftedStart);
    final endText = formatMilliseconds(shiftedStart + duration);
    if (StudioDockTimingEditService.validate(startText, endText) != null) {
      throw FormatException('Selected subtitle ${cue.index} would have invalid timing.');
    }
    return _copy(cue)
      ..startTime = startText
      ..endTime = endText;
  }

  static SubtitleLine _shiftCue(
      StudioDockLoadedCue cue, int deltaMilliseconds) {
    if (StudioDockTimingEditService.validate(cue.start, cue.end) != null) {
      throw FormatException('Invalid timecodes on subtitle ${cue.index}.');
    }
    final nextStart = formatMilliseconds(
        TimeValidator.timeStringToMilliseconds(cue.start) + deltaMilliseconds);
    final nextEnd = formatMilliseconds(
        TimeValidator.timeStringToMilliseconds(cue.end) + deltaMilliseconds);
    return _copy(cue)
      ..startTime = nextStart
      ..endTime = nextEnd;
  }

  static List<SubtitleLine> planClearFormatting(
      StudioDockSessionSnapshot snapshot) => [
    for (final cue in snapshot.cues)
      if (StudioDockStyleActions.clearSupportedTags(
              cue.storedEdited ?? cue.original) !=
          (cue.storedEdited ?? cue.original))
        _copy(cue)..edited = StudioDockStyleActions.clearSupportedTags(
            cue.storedEdited ?? cue.original),
  ];

  Future<StudioDockSessionSnapshot?> shiftAll({
    required StudioDockSessionSnapshot baseline,
    required int deltaMilliseconds,
  }) async {
    if (deltaMilliseconds == 0) return baseline;
    final updated = planShift(baseline, deltaMilliseconds);
    return _commit(
      baseline: baseline,
      updated: updated,
      operationType: 'sync',
      description: 'Shifted ${updated.length} subtitle timecodes by '
          '$deltaMilliseconds milliseconds',
    );
  }

  Future<StudioDockSessionSnapshot?> shiftSelected({
    required StudioDockSessionSnapshot baseline,
    required Set<int> cueNumbers,
    required String newStart,
    required String newEnd,
  }) async {
    try {
      final updated = planShiftSelected(baseline, cueNumbers, newStart, newEnd);
      if (updated.every((line) {
        final cue = baseline.cues.firstWhere((cue) => cue.index == line.index);
        return cue.start == line.startTime && cue.end == line.endTime;
      })) return baseline;
      return await _commit(
        baseline: baseline,
        updated: updated,
        operationType: 'sync',
        description: 'Shifted ${updated.length} selected subtitle timecodes',
      );
    } on FormatException {
      return null;
    }
  }

  Future<StudioDockSessionSnapshot?> deleteSelected({
    required StudioDockSessionSnapshot baseline,
    required Set<int> cueNumbers,
  }) async {
    if (cueNumbers.isEmpty) return null;
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }
    final positions = <int>[
      for (var index = 0; index < baseline.cues.length; index++)
        if (cueNumbers.contains(baseline.cues[index].index)) index,
    ];
    if (positions.length != cueNumbers.length) return null;
    final deleted = await _subtitles.deleteSelectedLinesFromSnapshotWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: [for (final cue in baseline.cues) _copy(cue)],
      selectedIndices: positions,
    );
    if (!deleted) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }

  Future<StudioDockSessionSnapshot?> clearFormatting({
    required StudioDockSessionSnapshot baseline,
  }) async {
    final updated = planClearFormatting(baseline);
    return _commit(
      baseline: baseline,
      updated: updated,
      operationType: 'effect',
      description: 'Removed formatting tags from ${updated.length} subtitles',
    );
  }

  Future<StudioDockSessionSnapshot?> _commit({
    required StudioDockSessionSnapshot baseline,
    required List<SubtitleLine> updated,
    required String operationType,
    required String description,
  }) async {
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }
    if (updated.isEmpty) return baseline;
    final expectedById = {
      for (final cue in baseline.cues) cue.index: _copy(cue),
    };
    final saved = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: [for (final line in updated) expectedById[line.index]!],
      updatedLines: updated,
      operationType: operationType,
      description: description,
    );
    if (!saved) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
