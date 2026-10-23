import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/import_comments/project_comment_import.dart';
import 'package:subtitle_studio/services/checkpoint_history_transaction.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// Imports project annotations as one undoable, post-operation V2 commit.
///
/// The destination collection is read by CheckpointHistoryTransaction inside
/// the write transaction. A source .msone file supplies cue numbers rather
/// than trusted destination row positions.
class ProjectCommentRepository {
  final Isar _isar;
  final CheckpointHistoryTransaction _history;

  ProjectCommentRepository(Isar isar)
      : _isar = isar,
        _history = CheckpointHistoryTransaction(isar);

  Future<int> importComments({
    required int subtitleCollectionId,
    required ProjectCommentImportPlan plan,
    int? sessionId,
  }) async {
    if (plan.entries.isEmpty) return 0;

    final byIndex = <int, ProjectCommentImportEntry>{};
    for (final entry in plan.entries) {
      if (entry.index <= 0 || byIndex.containsKey(entry.index)) {
        throw FormatException(
          'Imported comment indices must be positive and unique: '
          '${entry.index}.',
        );
      }
      byIndex[entry.index] = entry;
    }

    // Existing callers supply the collection only. Resolve its *unique*
    // session, rather than guessing one or committing to another session.
    final targetSessionId = sessionId ??
        await _resolveUniqueSessionId(subtitleCollectionId);

    var matchedCount = 0;
    await _history.commit(
      sessionId: targetSessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'import-comments',
      description: 'Imported project comments',
      metadata: {
        'source': 'msone-comment-import',
        'requested': plan.entries.length,
      },
      buildMutation: (currentLines) {
        final nextLines = CheckpointStateReducer.copyLines(currentLines);
        final deltas = <SubtitleLineDelta>[];
        var matches = 0;

        for (var index = 0; index < nextLines.length; index++) {
          final line = nextLines[index];
          final imported = byIndex[line.index];
          if (imported == null) continue;
          matches++;

          final before = CheckpointStateReducer.copyLine(line);
          line
            ..comment = imported.comment
            ..marked = imported.marked
            ..resolved = imported.resolved;
          if (CheckpointStateReducer.samePersistedLine(before, line)) {
            continue;
          }

          deltas.add(SubtitleLineDelta()
            ..changeType = 'modify'
            ..lineIndex = index
            ..beforeState = before
            ..afterState = CheckpointStateReducer.copyLine(line));
        }

        matchedCount = matches;
        return CheckpointMutationPlan(
          nextLines: nextLines,
          deltas: deltas,
        );
      },
    );

    return matchedCount;
  }

  Future<int> _resolveUniqueSessionId(int collectionId) async {
    final sessions = await _isar.sessions.where().findAll();
    final owners = sessions
        .where((session) => session.subtitleCollectionId == collectionId)
        .toList(growable: false);
    if (owners.length != 1) {
      throw StateError(
        'A unique editing session is required to import comments for '
        'collection $collectionId; found ${owners.length}.',
      );
    }
    return owners.single.id;
  }
}
