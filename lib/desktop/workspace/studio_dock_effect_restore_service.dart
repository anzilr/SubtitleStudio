import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';

import 'studio_dock_effect_groups.dart';
import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// Replaces one *verified* collapsed effect with a normal, readable cue.
/// The repository performs the final optimistic check in the same atomic
/// checkpoint transaction as the structural mutation.
class StudioDockEffectRestoreService {
  const StudioDockEffectRestoreService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  static List<SubtitleLine> persistedLines(StudioDockSessionSnapshot baseline) => [
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

  static List<StudioDockEffectGroup> detect(StudioDockSessionSnapshot baseline) =>
      StudioDockEffectGroups.detect([
        for (final cue in baseline.cues)
          StudioDockEffectFrame(
            id: cue.index,
            start: cue.start,
            end: cue.end,
            original: cue.original,
            edited: cue.edited,
            effectiveText: cue.storedEdited ?? cue.original,
          ),
      ]);

  static SubtitleLine restoredCue(StudioDockSessionSnapshot baseline,
      StudioDockEffectGroup group) {
    final source = [
      for (final cue in baseline.cues)
        if (group.contains(cue.index)) cue,
    ];
    if (source.length != group.length || group.length < 2 ||
        source.first.index != group.firstId ||
        source.last.index != group.lastId) {
      throw const FormatException('The selected effect frames changed.');
    }
    final hasTranslatedFrames = source.any((cue) => cue.storedEdited != null);
    final notes = source.map((cue) => cue.comment?.trim())
        .whereType<String>().where((note) => note.isNotEmpty).toSet();
    return SubtitleLine()
      ..index = source.first.index
      ..startTime = source.first.start
      ..endTime = source.last.end
      // Imported SRT frames have no separate clean original; restore their
      // visible text. Generated translation frames retain their source text.
      ..original = hasTranslatedFrames ? source.first.original : group.previewText
      ..edited = hasTranslatedFrames ? group.previewText : null
      ..marked = source.any((cue) => cue.marked)
      ..resolved = source.every((cue) => cue.resolved)
      ..comment = notes.isEmpty ? null : notes.join('\n');
  }

  Future<StudioDockSessionSnapshot?> restore({
    required StudioDockSessionSnapshot baseline,
    required int firstCueId,
    required int expectedFrameCount,
  }) async {
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }
    final matching = detect(baseline).where((group) =>
        group.firstId == firstCueId && group.length == expectedFrameCount);
    if (matching.length != 1) return null;
    final group = matching.single;
    final start = baseline.cues.indexWhere((cue) => cue.index == firstCueId);
    if (start < 0) return null;
    final restored = restoredCue(baseline, group);
    final saved = await _subtitles.restoreEffectFromSnapshotWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: persistedLines(baseline),
      firstIndex: start,
      frameCount: group.length,
      restoredLine: restored,
    );
    if (!saved) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
