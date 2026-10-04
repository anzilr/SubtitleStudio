import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_transaction.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

/// Persistence boundary for waveform-driven subtitle timing edits.
class WaveformSubtitleRepository {
  final Isar _isar;
  final CheckpointHistoryTransaction _historyTransaction;

  WaveformSubtitleRepository(this._isar)
      : _historyTransaction = CheckpointHistoryTransaction(_isar);

  /// Atomically applies waveform timing edits and records one v2 history commit.
  Future<bool> updateLinesWithHistory({
    required int subtitleCollectionId,
    required int sessionId,
    required List<SubtitleLine> updatedLines,
  }) async {
    if (updatedLines.isEmpty) return true;

    try {
      final result = await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: subtitleCollectionId,
        operationType: 'edit',
        description: updatedLines.length == 1
            ? 'Adjusted timing for line \${updatedLines.single.index}'
            : 'Adjusted timing for \${updatedLines.length} lines',
        buildMutation: (currentLines) {
          final nextLines = CheckpointStateReducer.copyLines(currentLines);
          final replacements = <int, SubtitleLine>{
            for (final line in updatedLines) line.index: line,
          };
          final matchedIndexes = <int>{};
          final deltas = <SubtitleLineDelta>[];

          for (var i = 0; i < nextLines.length; i++) {
            final current = nextLines[i];
            final replacement = replacements[current.index];
            if (replacement == null) continue;

            matchedIndexes.add(current.index);
            deltas.add(
              SubtitleLineDelta()
                ..changeType = 'modify'
                ..lineIndex = i
                ..beforeState = CheckpointStateReducer.copyLine(current)
                ..afterState = CheckpointStateReducer.copyLine(replacement),
            );
            nextLines[i] = CheckpointStateReducer.copyLine(replacement);
          }

          if (matchedIndexes.length != replacements.length) {
            throw StateError(
              'One or more waveform subtitle lines were not found.',
            );
          }

          return CheckpointMutationPlan(
            nextLines: nextLines,
            deltas: deltas,
          );
        },
        metadata: const {
          'source': 'waveform',
        },
      );

      return result.checkpointId != 0 || updatedLines.isEmpty;
    } catch (error, stackTrace) {
      await logError(
        'WaveformSubtitleRepository: failed atomic timing update',
        context: 'updateLinesWithHistory',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Replaces the requested subtitle lines by their stable 1-based cue index.
  ///
  /// Returns false if the collection is missing or if any requested cue cannot
  /// be matched, preventing a partial/false-success write.
  Future<bool> updateLines(
    int subtitleCollectionId,
    List<SubtitleLine> updatedLines,
  ) async {
    if (updatedLines.isEmpty) return true;

    try {
      return await _isar.writeTxn(() async {
        final collection =
            await _isar.subtitleCollections.get(subtitleCollectionId);
        if (collection == null) {
          await logWarning(
            'WaveformSubtitleRepository: collection not found: '
            '$subtitleCollectionId',
          );
          return false;
        }

        final replacements = <int, SubtitleLine>{
          for (final line in updatedLines) line.index: line,
        };
        final matchedIndexes = <int>{};

        for (int i = 0; i < collection.lines.length; i++) {
          final currentIndex = collection.lines[i].index;
          final replacement = replacements[currentIndex];
          if (replacement != null) {
            collection.lines[i] = replacement;
            matchedIndexes.add(currentIndex);
          }
        }

        if (matchedIndexes.length != replacements.length) {
          await logWarning(
            'WaveformSubtitleRepository: one or more subtitle lines were '
            'not found in collection $subtitleCollectionId',
          );
          return false;
        }

        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (error, stackTrace) {
      await logError(
        'WaveformSubtitleRepository: failed to update subtitle lines',
        context: 'updateLines',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
