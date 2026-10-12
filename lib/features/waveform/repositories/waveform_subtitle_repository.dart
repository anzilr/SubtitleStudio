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
    List<SubtitleLine>? expectedLines,
  }) async {
    if (updatedLines.isEmpty) return true;

    try {
      final updates = <int, SubtitleLine>{};
      for (final line in updatedLines) {
        if (line.index <= 0 || updates.containsKey(line.index)) {
          return false;
        }
        updates[line.index] = CheckpointStateReducer.copyLine(line);
      }
      final expected = <int, SubtitleLine>{};
      if (expectedLines != null) {
        for (final line in expectedLines) {
          if (line.index <= 0 || expected.containsKey(line.index)) {
            return false;
          }
          expected[line.index] = CheckpointStateReducer.copyLine(line);
        }
        if (expected.length != updates.length ||
            !updates.keys.every(expected.containsKey)) {
          return false;
        }
      }

      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: subtitleCollectionId,
        operationType: 'edit',
        description: updatedLines.length == 1
            ? 'Adjusted timing for line \${updatedLines.single.index}'
            : 'Adjusted timing for \${updatedLines.length} lines',
        buildMutation: (currentLines) {
          final nextLines = CheckpointStateReducer.copyLines(currentLines);
          final matchedIndexes = <int>{};
          final deltas = <SubtitleLineDelta>[];

          for (var i = 0; i < nextLines.length; i++) {
            final current = nextLines[i];
            final replacement = updates[current.index];
            if (replacement == null) continue;
            if (!matchedIndexes.add(current.index)) {
              throw StateError('Duplicate destination subtitle cue index.');
            }

            final before = expected[current.index];
            if (expectedLines != null &&
                (before == null ||
                 !CheckpointStateReducer.samePersistedLine(current, before))) {
              throw StateError('Waveform edit is stale; refresh the subtitle.');
            }

            // Waveform owns timing only; never overwrite unrelated edits,
            // comments, marks or resolution flags from a cached UI line.
            final after = CheckpointStateReducer.copyLine(current)
              ..startTime = replacement.startTime
              ..endTime = replacement.endTime;
            if (CheckpointStateReducer.samePersistedLine(current, after)) {
              continue;
            }
            deltas.add(
              SubtitleLineDelta()
                ..changeType = 'modify'
                ..lineIndex = i
                ..beforeState = CheckpointStateReducer.copyLine(current)
                ..afterState = CheckpointStateReducer.copyLine(after),
            );
            nextLines[i] = after;
          }

          if (matchedIndexes.length != updates.length) {
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

      // An unchanged requested timing edit is a successful no-op.
      return true;
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

        final replacements = <int, SubtitleLine>{};
        for (final line in updatedLines) {
          if (line.index <= 0 || replacements.containsKey(line.index)) {
            return false;
          }
          replacements[line.index] =
              CheckpointStateReducer.copyLine(line);
        }

        // Validate the entire requested batch before mutating anything.
        final matched = <int>{};
        for (final line in collection.lines) {
          if (replacements.containsKey(line.index) &&
              !matched.add(line.index)) {
            return false;
          }
        }
        if (matched.length != replacements.length) return false;

        for (final line in collection.lines) {
          final replacement = replacements[line.index];
          if (replacement == null) continue;
          // Even the compatibility path may only change waveform timing.
          line.startTime = replacement.startTime;
          line.endTime = replacement.endTime;
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
