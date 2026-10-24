import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/search_replace/search_replace_planner.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// Immutable search-time match. [occurrence.line] is the complete stored cue
/// the user searched, including nullable edits and annotation metadata.
class StudioDockSearchHit {
  const StudioDockSearchHit(this.occurrence);

  final SubtitleSearchMatch occurrence;

  int get cueNumber => occurrence.line.index;
  String get content => occurrence.line.edited ?? occurrence.line.original;
  int get start => occurrence.start;
  int get end => occurrence.end;
}

/// Shared SearchReplacePlanner bridge for the desktop workspace. Querying is
/// read-only; Replace uses the existing optimistic history batch mutation.
class StudioDockSearchService {
  const StudioDockSearchService(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  static SubtitleLine _persistedCue(StudioDockLoadedCue cue) => SubtitleLine()
    ..index = cue.index
    ..startTime = cue.start
    ..endTime = cue.end
    ..original = cue.original
    ..edited = cue.storedEdited
    ..marked = cue.marked
    ..comment = cue.comment
    ..resolved = cue.resolved;

  static List<StudioDockSearchHit> findSnapshot({
    required StudioDockSessionSnapshot snapshot,
    required String term,
    required bool caseSensitive,
    required bool wholeWord,
  }) => findLines(
    lines: snapshot.cues.map(_persistedCue),
    term: term,
    caseSensitive: caseSensitive,
    wholeWord: wholeWord,
  );

  static List<StudioDockSearchHit> findLines({
    required Iterable<SubtitleLine> lines,
    required String term,
    required bool caseSensitive,
    required bool wholeWord,
  }) {
    if (term.isEmpty) return const [];
    final pattern = RegExp(wholeWord
        ? '\\b${RegExp.escape(term)}\\b'
        : RegExp.escape(term), caseSensitive: caseSensitive);
    return [
      for (final line in lines)
        for (final match in pattern.allMatches(line.edited ?? line.original))
          StudioDockSearchHit(SubtitleSearchMatch(
            line: CheckpointStateReducer.copyLine(line),
            start: match.start,
            end: match.end,
          )),
    ];
  }

  Future<StudioDockSessionSnapshot?> replace({
    required StudioDockSessionSnapshot baseline,
    required List<StudioDockSearchHit> matches,
    required String searchTerm,
    required String replacement,
    required bool caseSensitive,
  }) async {
    if (matches.isEmpty || searchTerm.isEmpty) return null;
    final session = await _projects.getSession(baseline.sessionId);
    if (session == null || session.subtitleCollectionId != baseline.collectionId) {
      return null;
    }

    // The match must come from the snapshot displayed to this same window.
    // Repository comparisons inside the history transaction then protect
    // against any other window writing between Search and Replace.
    final expected = {
      for (final cue in baseline.cues) cue.index: _persistedCue(cue),
    };
    for (final hit in matches) {
      final original = expected[hit.cueNumber];
      if (original == null || !CheckpointStateReducer.samePersistedLine(
          original, hit.occurrence.line)) return null;
    }

    final plan = SubtitleSearchReplacePlanner.build(
      matches: matches.map((hit) => hit.occurrence),
      searchTerm: searchTerm,
      replacement: replacement,
      caseSensitive: caseSensitive,
    );
    final saved = await _subtitles.updateMultipleLinesWithHistory(
      collectionId: baseline.collectionId,
      sessionId: baseline.sessionId,
      expectedLines: plan.expectedLines,
      updatedLines: plan.updatedLines,
      operationType: 'replace',
      description: 'Replaced ${plan.replacements} subtitle text matches',
    );
    if (!saved) return null;
    return StudioDockSessionLoader(_projects, _subtitles).load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
  }
}
