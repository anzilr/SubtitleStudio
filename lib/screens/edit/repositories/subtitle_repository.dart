import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/utils/subtitle_sorting.dart';
import 'package:subtitle_studio/widgets/video/subtitle.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/checkpoint_history_transaction.dart';
import 'package:subtitle_studio/services/checkpoint_line_metadata_service.dart';
import 'package:subtitle_studio/services/legacy_collection_write_guard.dart';
import 'package:subtitle_studio/utils/time_parser.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/services/source_view_reconciler.dart';

/// Repository layer for subtitle operations
/// 
/// This class abstracts all database operations and business logic
/// for subtitle management, following clean architecture principles.
/// 
/// Responsibilities:
/// - Fetch subtitle lines and collections
/// - Update subtitle lines (edit, mark, comment)
/// - Delete subtitle lines (single and batch)
/// - Checkpoint management integration
/// - Source view synchronization
/// - Generate subtitles for video player
class SubtitleRepository {
  final Isar _isar;
  final CheckpointRepository _checkpoints;
  final CheckpointHistoryTransaction _historyTransaction;
  final PreferencesStore _preferencesStore;

  SubtitleRepository(this._isar, this._checkpoints)
      : _historyTransaction = CheckpointHistoryTransaction(_isar),
        _preferencesStore = PreferencesStore(_isar);

  /// Fetch all subtitle lines for a collection
  Future<List<SubtitleLine>> fetchLines(int collectionId) async {
    logInfo('SubtitleRepository: Fetching subtitle lines for collection $collectionId');
    try {
      final collection = await _isar.subtitleCollections.get(collectionId);
      final subtitles = collection?.lines ?? const <SubtitleLine>[];
      logInfo(
        'SubtitleRepository: Successfully fetched ${subtitles.length} subtitle lines',
      );
      return subtitles;
    } catch (e) {
      logError('SubtitleRepository: Failed to fetch subtitle lines: $e');
      rethrow;
    }
  }

  /// Fetch subtitle collection by ID
  Future<SubtitleCollection?> fetchSubtitleCollection(int id) async {
    logInfo('SubtitleRepository: Fetching subtitle collection $id');
    try {
      final collection = await _isar.subtitleCollections.get(id);
      if (collection != null) {
        logInfo('SubtitleRepository: Successfully fetched collection "${collection.fileName}"');
      } else {
        logWarning('SubtitleRepository: Collection $id not found');
      }
      return collection;
    } catch (e) {
      logError('SubtitleRepository: Failed to fetch collection: $e');
      rethrow;
    }
  }

  /// Persist one edited subtitle line atomically with v2 history.
  Future<bool> saveLineChanges(
    int collectionId,
    SubtitleLine updatedLine, {
    required int sessionId,
    SubtitleLine? beforeLine,
  }) async {
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'edit',
        description: 'Edited line ${updatedLine.index}',
        buildMutation: (currentLines) {
          final listIndex = updatedLine.index - 1;
          if (listIndex < 0 || listIndex >= currentLines.length) {
            throw RangeError.index(
              listIndex,
              currentLines,
              'updatedLine.index',
            );
          }

          final persistedBefore = currentLines[listIndex];
          final timingChanged =
              persistedBefore.startTime != updatedLine.startTime ||
              persistedBefore.endTime != updatedLine.endTime;
          final historyChanged =
              !CheckpointStateReducer.samePersistedLine(
            persistedBefore,
            updatedLine,
          );

          final nextLines =
              CheckpointStateReducer.copyLines(currentLines);
          nextLines[listIndex] =
              CheckpointStateReducer.copyLine(updatedLine);

          if (timingChanged) {
            final sorted = sortAndReindexSubtitleLines(nextLines);
            nextLines
              ..clear()
              ..addAll(sorted);
          }

          final deltas = <SubtitleLineDelta>[];
          if (historyChanged) {
            deltas.add(
              SubtitleLineDelta()
                ..changeType = 'modify'
                ..lineIndex = listIndex
                ..beforeState =
                    CheckpointStateReducer.copyLine(persistedBefore)
                ..afterState =
                    CheckpointStateReducer.copyLine(updatedLine),
            );
          }

          return CheckpointMutationPlan(
            nextLines: nextLines,
            deltas: deltas,
            // Timing edits can reorder cues, which the current line delta
            // format does not encode. Store the exact post-operation state.
            forceSnapshot: timingChanged,
          );
        },
      );
      return true;
    } catch (error) {
      logError(
        'SubtitleRepository: Failed atomic line save: $error',
      );
      return false;
    }
  }

  /// Update several subtitle lines in one collection transaction.
  ///
  /// Cue numbers are matched by [SubtitleLine.index], so callers can submit a
  /// sparse set of modified lines without rewriting unrelated entries.
  /// Apply a sparse batch from a preview using a single V2 commit.
  ///
  /// The caller provides the exact lines that it originally displayed.
  /// We match by stable cue number and compare each expected line against
  /// the current Isar state *inside* the history transaction. If any target
  /// has changed, reject the whole batch instead of overwriting newer edits.
  /// Unrelated lines are copied from current storage, never from UI state.
  Future<bool> updateMultipleLinesWithHistory({
    required int collectionId,
    required int sessionId,
    required List<SubtitleLine> expectedLines,
    required List<SubtitleLine> updatedLines,
    required String operationType,
    required String description,
  }) async {
    if (updatedLines.isEmpty) return true;

    try {
      final expectedByCue = <int, SubtitleLine>{};
      for (final line in expectedLines) {
        if (line.index <= 0 || expectedByCue.containsKey(line.index)) {
          throw const FormatException('Expected cue numbers must be unique and positive.');
        }
        expectedByCue[line.index] = CheckpointStateReducer.copyLine(line);
      }

      final updatedByCue = <int, SubtitleLine>{};
      for (final line in updatedLines) {
        if (line.index <= 0 || updatedByCue.containsKey(line.index) ||
            !expectedByCue.containsKey(line.index)) {
          throw const FormatException('Updated cues must be unique and present in the expected snapshot.');
        }
        updatedByCue[line.index] = CheckpointStateReducer.copyLine(line);
      }

      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: operationType,
        description: description,
        buildMutation: (currentLines) {
          final nextLines = CheckpointStateReducer.copyLines(currentLines);
          final seen = <int>{};
          final deltas = <SubtitleLineDelta>[];

          for (var position = 0; position < nextLines.length; position++) {
            final current = nextLines[position];
            final replacement = updatedByCue[current.index];
            if (replacement == null) continue;
            if (!seen.add(current.index)) {
              throw StateError('Duplicate destination cue ${current.index}.');
            }
            final expected = expectedByCue[current.index]!;
            if (!CheckpointStateReducer.samePersistedLine(current, expected)) {
              throw StateError('Subtitle cue ${current.index} changed after preview; refresh before applying.');
            }
            if (CheckpointStateReducer.samePersistedLine(current, replacement)) {
              continue;
            }
            deltas.add(SubtitleLineDelta()
              ..changeType = 'modify'
              ..lineIndex = position
              ..beforeState = CheckpointStateReducer.copyLine(current)
              ..afterState = CheckpointStateReducer.copyLine(replacement));
            nextLines[position] = CheckpointStateReducer.copyLine(replacement);
          }

          if (seen.length != updatedByCue.length) {
            throw StateError('One or more subtitle cues were removed or renumbered since preview.');
          }
          return CheckpointMutationPlan(
            nextLines: nextLines,
            deltas: deltas,
          );
        },
      );
      return true;
    } catch (error) {
      logError('SubtitleRepository: Atomic batch update rejected: $error');
      return false;
    }
  }

  Future<bool> updateMultipleLines(
    int collectionId,
    List<SubtitleLine> updatedLines,
  ) async {
    if (updatedLines.isEmpty) return true;

    try {
      return await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);

        if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
          _isar, collectionId,
        )) return false;        if (collection == null) return false;

        // Legacy compatibility path: verify every cue before touching any
        // stored line. Previously a missing cue produced a false result but
        // still committed partial updates.
        final updatesByCueNumber = <int, SubtitleLine>{};
        for (final line in updatedLines) {
          if (line.index <= 0 ||
              updatesByCueNumber.containsKey(line.index)) {
            return false;
          }
          updatesByCueNumber[line.index] =
              CheckpointStateReducer.copyLine(line);
        }

        final matched = <int>{};
        for (final line in collection.lines) {
          if (updatesByCueNumber.containsKey(line.index)) {
            if (!matched.add(line.index)) return false;
          }
        }
        if (matched.length != updatesByCueNumber.length) return false;

        for (var i = 0; i < collection.lines.length; i++) {
          final replacement =
              updatesByCueNumber[collection.lines[i].index];
          if (replacement != null) collection.lines[i] = replacement;
        }

        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (e, stackTrace) {
      await logError(
        'SubtitleRepository: Batch update failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Persist an annotation as a v2 commit when editing within a session.
  /// The no-session fallback is retained for legacy integrations while their
  /// callers migrate to the history-aware API.
  Future<bool> markLine(
    int collectionId,
    int index,
    bool marked, {
    int? sessionId,
  }) async {
    if (sessionId != null) {
      try {
        return await CheckpointLineMetadataService(_isar).change(
          sessionId: sessionId,
          collectionId: collectionId,
          lineIndex: index,
          description: marked ? 'Marked line ${index + 1}' : 'Unmarked line ${index + 1}',
          modify: (line) => line.marked = marked,
        );
      } catch (error) {
        logError('SubtitleRepository: Atomic mark failed: $error');
        return false;
      }
    }
    return _legacyModifyLine(collectionId, index, (line) {
      line.marked = marked;
    });
  }

  Future<bool> updateComment(
    int collectionId,
    int index,
    String? comment, {
    int? sessionId,
  }) async {
    if (sessionId != null) {
      try {
        return await CheckpointLineMetadataService(_isar).change(
          sessionId: sessionId,
          collectionId: collectionId,
          lineIndex: index,
          description: 'Updated comment on line ${index + 1}',
          modify: (line) => line.comment = comment,
        );
      } catch (error) {
        logError('SubtitleRepository: Atomic comment update failed: $error');
        return false;
      }
    }
    return _legacyModifyLine(collectionId, index, (line) {
      line.comment = comment;
    });
  }

  Future<bool> unmarkLine(int collectionId, int index, {int? sessionId}) async {
    void clear(SubtitleLine line) {
      line.marked = false;
      line.comment = null;
      line.resolved = false;
    }

    if (sessionId != null) {
      try {
        return await CheckpointLineMetadataService(_isar).change(
          sessionId: sessionId,
          collectionId: collectionId,
          lineIndex: index,
          description: 'Cleared mark and comment on line ${index + 1}',
          modify: clear,
        );
      } catch (error) {
        logError('SubtitleRepository: Atomic unmark failed: $error');
        return false;
      }
    }
    return _legacyModifyLine(collectionId, index, clear);
  }

  Future<bool> updateResolved(
    int collectionId,
    int index,
    bool resolved, {
    int? sessionId,
  }) async {
    if (sessionId != null) {
      try {
        return await CheckpointLineMetadataService(_isar).change(
          sessionId: sessionId,
          collectionId: collectionId,
          lineIndex: index,
          description: 'Updated resolution of line ${index + 1}',
          modify: (line) => line.resolved = resolved,
        );
      } catch (error) {
        logError('SubtitleRepository: Atomic resolve failed: $error');
        return false;
      }
    }
    return _legacyModifyLine(collectionId, index, (line) {
      line.resolved = resolved;
    });
  }

  Future<bool> _legacyModifyLine(
    int collectionId,
    int index,
    void Function(SubtitleLine line) modify,
  ) async {
    return _isar.writeTxn(() async {
      final collection = await _isar.subtitleCollections.get(collectionId);
      if (collection == null ||
          index < 0 ||
          index >= collection.lines.length) {
        return false;
      }
      if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
        _isar, collectionId,
      )) return false;
      modify(collection.lines[index]);
      await _isar.subtitleCollections.put(collection);
      return true;
    });
  }

  Future<bool> replaceLineWithGeneratedLinesWithHistory({
    required int collectionId,
    required int originalIndex,
    required List<SubtitleLine> replacementLines,
    required int sessionId,
    required String description,
  }) async {
    if (replacementLines.isEmpty) return false;

    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'effect',
        description: description,
        buildMutation: (currentLines) {
          if (originalIndex < 0 || originalIndex >= currentLines.length) {
            throw RangeError.index(
              originalIndex,
              currentLines,
              'originalIndex',
            );
          }

          final original = currentLines[originalIndex];
          final nextLines = CheckpointStateReducer.copyLines(currentLines)
            ..removeAt(originalIndex)
            ..insertAll(
              originalIndex,
              replacementLines.map(CheckpointStateReducer.copyLine),
            );

          final deltas = <SubtitleLineDelta>[
            SubtitleLineDelta()
              ..changeType = 'delete'
              ..lineIndex = originalIndex
              ..beforeState = CheckpointStateReducer.copyLine(original)
              ..afterState = null,
            for (var i = 0; i < replacementLines.length; i++)
              SubtitleLineDelta()
                ..changeType = 'add'
                ..lineIndex = originalIndex + i
                ..beforeState = null
                ..afterState = CheckpointStateReducer.copyLine(
                  replacementLines[i],
                ),
          ];

          return CheckpointMutationPlan(
            nextLines: sortAndReindexSubtitleLines(nextLines),
            deltas: deltas,
            forceSnapshot: true,
          );
        },
      );
      return true;
    } catch (error) {
      logError(
        'SubtitleRepository: Atomic effect replacement failed: $error',
      );
      return false;
    }
  }

  Future<bool> deleteLineWithHistory({
    required int collectionId,
    required int index,
    required int sessionId,
  }) async {
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'delete',
        description: 'Deleted line ${index + 1}',
        buildMutation: (currentLines) {
          if (index < 0 || index >= currentLines.length) {
            throw RangeError.index(index, currentLines, 'index');
          }

          final deleted = currentLines[index];
          final nextLines =
              CheckpointStateReducer.copyLines(currentLines)
                ..removeAt(index);
          final sorted = sortAndReindexSubtitleLines(nextLines);

          return CheckpointMutationPlan(
            nextLines: sorted,
            deltas: [
              SubtitleLineDelta()
                ..changeType = 'delete'
                ..lineIndex = index
                ..beforeState =
                    CheckpointStateReducer.copyLine(deleted)
                ..afterState = null,
            ],
            forceSnapshot: true,
          );
        },
      );
      return true;
    } catch (error) {
      logError(
        'SubtitleRepository: Atomic delete failed for line $index: $error',
      );
      return false;
    }
  }

  /// Desktop-safe structural mutation: the entire displayed collection must
  /// still match inside the atomic history transaction before indices shift.
  /// Legacy positional commands retain their existing contracts.
  bool _sameDisplayedLines(
    List<SubtitleLine> current,
    List<SubtitleLine> expected,
  ) {
    if (current.length != expected.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (!CheckpointStateReducer.samePersistedLine(current[i], expected[i])) {
        return false;
      }
    }
    return true;
  }

  /// Returns the newly inserted 1-based cue number after timeline sorting,
  /// or null if the displayed snapshot is stale or the mutation fails.
  Future<int?> addLineFromSnapshotWithHistory({
    required int collectionId,
    required int sessionId,
    required List<SubtitleLine> expectedLines,
    required SubtitleLine line,
    required int insertIndex,
  }) async {
    final expected = CheckpointStateReducer.copyLines(expectedLines);
    if (insertIndex < 0 || insertIndex > expected.length) return null;
    int? insertedNumber;
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'add',
        description: 'Added line at position ${insertIndex + 1}',
        buildMutation: (currentLines) {
          if (!_sameDisplayedLines(currentLines, expected)) {
            throw StateError('Subtitle collection changed since preview.');
          }
          final nextLines = CheckpointStateReducer.copyLines(currentLines);
          final added = CheckpointStateReducer.copyLine(line)
            ..index = insertIndex + 1;
          nextLines.insert(insertIndex, added);
          final sorted = sortAndReindexSubtitleLines(nextLines);
          insertedNumber = sorted.indexOf(added) + 1;
          return CheckpointMutationPlan(
            nextLines: sorted,
            deltas: [SubtitleLineDelta()
              ..changeType = 'add'
              ..lineIndex = insertIndex
              ..beforeState = null
              ..afterState = CheckpointStateReducer.copyLine(added)],
            forceSnapshot: true,
          );
        },
      );
      return insertedNumber;
    } catch (error) {
      logError('SubtitleRepository: Guarded insert rejected: $error');
      return null;
    }
  }

  Future<bool> deleteLineFromSnapshotWithHistory({
    required int collectionId,
    required int sessionId,
    required List<SubtitleLine> expectedLines,
    required int index,
  }) async {
    final expected = CheckpointStateReducer.copyLines(expectedLines);
    if (index < 0 || index >= expected.length) return false;
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'delete',
        description: 'Deleted line ${index + 1}',
        buildMutation: (currentLines) {
          if (!_sameDisplayedLines(currentLines, expected)) {
            throw StateError('Subtitle collection changed since preview.');
          }
          final deleted = currentLines[index];
          final nextLines = CheckpointStateReducer.copyLines(currentLines)
            ..removeAt(index);
          return CheckpointMutationPlan(
            nextLines: sortAndReindexSubtitleLines(nextLines),
            deltas: [SubtitleLineDelta()
              ..changeType = 'delete'
              ..lineIndex = index
              ..beforeState = CheckpointStateReducer.copyLine(deleted)
              ..afterState = null],
            forceSnapshot: true,
          );
        },
      );
      return true;
    } catch (error) {
      logError('SubtitleRepository: Guarded delete rejected: $error');
      return false;
    }
  }

  /// Splits a cue only if *every* persisted cue still matches the desktop
  /// snapshot. Both halves and their history are committed in one transaction.
  Future<int?> splitLineFromSnapshotWithHistory({
    required int collectionId,
    required int sessionId,
    required List<SubtitleLine> expectedLines,
    required int index,
    required SubtitleLine firstPart,
    required SubtitleLine secondPart,
  }) async {
    final expected = CheckpointStateReducer.copyLines(expectedLines);
    if (index < 0 || index >= expected.length) return null;
    int? selectedNumber;
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'split',
        description: 'Split line ${index + 1}',
        buildMutation: (currentLines) {
          if (!_sameDisplayedLines(currentLines, expected)) {
            throw StateError('Subtitle collection changed since preview.');
          }
          final before = CheckpointStateReducer.copyLine(currentLines[index]);
          final first = CheckpointStateReducer.copyLine(firstPart);
          final second = CheckpointStateReducer.copyLine(secondPart);
          final next = CheckpointStateReducer.copyLines(currentLines)
            ..[index] = first
            ..insert(index + 1, second);
          final sorted = sortAndReindexSubtitleLines(next);
          selectedNumber = sorted.indexOf(first) + 1;
          return CheckpointMutationPlan(
            nextLines: sorted,
            deltas: [
              SubtitleLineDelta()
                ..changeType = 'modify'
                ..lineIndex = index
                ..beforeState = before
                ..afterState = CheckpointStateReducer.copyLine(first),
              SubtitleLineDelta()
                ..changeType = 'add'
                ..lineIndex = index + 1
                ..beforeState = null
                ..afterState = CheckpointStateReducer.copyLine(second),
            ],
            forceSnapshot: true,
          );
        },
      );
      return selectedNumber;
    } catch (error) {
      logError('SubtitleRepository: Guarded split rejected: $error');
      return null;
    }
  }

  /// Merges two adjacent displayed cues; stale or non-adjacent positions are
  /// rejected within the transaction, never applied to a shifted neighbor.
  Future<int?> mergeAdjacentLinesFromSnapshotWithHistory({
    required int collectionId,
    required int sessionId,
    required List<SubtitleLine> expectedLines,
    required int firstIndex,
    required SubtitleLine mergedLine,
  }) async {
    final expected = CheckpointStateReducer.copyLines(expectedLines);
    if (firstIndex < 0 || firstIndex + 1 >= expected.length) return null;
    int? selectedNumber;
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'merge',
        description: 'Merged lines ${firstIndex + 1} and ${firstIndex + 2}',
        buildMutation: (currentLines) {
          if (!_sameDisplayedLines(currentLines, expected)) {
            throw StateError('Subtitle collection changed since preview.');
          }
          final firstBefore = CheckpointStateReducer.copyLine(currentLines[firstIndex]);
          final secondBefore = CheckpointStateReducer.copyLine(currentLines[firstIndex + 1]);
          final merged = CheckpointStateReducer.copyLine(mergedLine);
          final next = CheckpointStateReducer.copyLines(currentLines)
            ..removeAt(firstIndex + 1)
            ..[firstIndex] = merged;
          final sorted = sortAndReindexSubtitleLines(next);
          selectedNumber = sorted.indexOf(merged) + 1;
          return CheckpointMutationPlan(
            nextLines: sorted,
            deltas: [
              SubtitleLineDelta()
                ..changeType = 'modify'
                ..lineIndex = firstIndex
                ..beforeState = firstBefore
                ..afterState = CheckpointStateReducer.copyLine(merged),
              SubtitleLineDelta()
                ..changeType = 'delete'
                ..lineIndex = firstIndex + 1
                ..beforeState = secondBefore
                ..afterState = null,
            ],
            forceSnapshot: true,
          );
        },
      );
      return selectedNumber;
    } catch (error) {
      logError('SubtitleRepository: Guarded merge rejected: $error');
      return null;
    }
  }

  Future<bool> addLineWithHistory({
    required int collectionId,
    required SubtitleLine line,
    required int insertIndex,
    required int sessionId,
  }) async {
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'add',
        description: 'Added line at position ${insertIndex + 1}',
        buildMutation: (currentLines) {
          final targetIndex = insertIndex.clamp(0, currentLines.length);
          final nextLines =
              CheckpointStateReducer.copyLines(currentLines);
          nextLines.insert(
            targetIndex,
            CheckpointStateReducer.copyLine(line),
          );

          return CheckpointMutationPlan(
            nextLines: sortAndReindexSubtitleLines(nextLines),
            deltas: [
              SubtitleLineDelta()
                ..changeType = 'add'
                ..lineIndex = targetIndex
                ..beforeState = null
                ..afterState =
                    CheckpointStateReducer.copyLine(line),
            ],
            forceSnapshot: true,
          );
        },
      );
      return true;
    } catch (error) {
      logError('SubtitleRepository: Atomic add failed: $error');
      return false;
    }
  }

  Future<bool> splitLineWithHistory({
    required int collectionId,
    required SubtitleLine firstPart,
    required SubtitleLine secondPart,
    required int originalIndex,
    required int sessionId,
  }) async {
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'split',
        description: 'Split line ${originalIndex + 1}',
        buildMutation: (currentLines) {
          if (originalIndex < 0 || originalIndex >= currentLines.length) {
            throw RangeError.index(
              originalIndex,
              currentLines,
              'originalIndex',
            );
          }

          final original = currentLines[originalIndex];
          final nextLines =
              CheckpointStateReducer.copyLines(currentLines);
          nextLines[originalIndex] =
              CheckpointStateReducer.copyLine(firstPart);
          nextLines.insert(
            originalIndex + 1,
            CheckpointStateReducer.copyLine(secondPart),
          );

          return CheckpointMutationPlan(
            nextLines: sortAndReindexSubtitleLines(nextLines),
            deltas: [
              SubtitleLineDelta()
                ..changeType = 'modify'
                ..lineIndex = originalIndex
                ..beforeState =
                    CheckpointStateReducer.copyLine(original)
                ..afterState =
                    CheckpointStateReducer.copyLine(firstPart),
              SubtitleLineDelta()
                ..changeType = 'add'
                ..lineIndex = originalIndex + 1
                ..beforeState = null
                ..afterState =
                    CheckpointStateReducer.copyLine(secondPart),
            ],
            forceSnapshot: true,
          );
        },
      );
      return true;
    } catch (error) {
      logError('SubtitleRepository: Atomic split failed: $error');
      return false;
    }
  }

  Future<bool> mergeLinesWithHistory({
    required int collectionId,
    required SubtitleLine mergedLine,
    required int firstLineIndex,
    required int secondLineIndex,
    required int sessionId,
  }) async {
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'merge',
        description:
            'Merged lines ${firstLineIndex + 1} and ${secondLineIndex + 1}',
        buildMutation: (currentLines) {
          if (firstLineIndex < 0 ||
              secondLineIndex < 0 ||
              firstLineIndex >= currentLines.length ||
              secondLineIndex >= currentLines.length ||
              firstLineIndex == secondLineIndex) {
            throw StateError('Invalid merge indexes.');
          }

          final firstBefore = currentLines[firstLineIndex];
          final secondBefore = currentLines[secondLineIndex];

          final replayDeltas = <SubtitleLineDelta>[
            SubtitleLineDelta()
              ..changeType = 'modify'
              ..lineIndex = firstLineIndex
              ..beforeState =
                  CheckpointStateReducer.copyLine(firstBefore)
              ..afterState =
                  CheckpointStateReducer.copyLine(mergedLine),
            SubtitleLineDelta()
              ..changeType = 'delete'
              ..lineIndex = secondLineIndex
              ..beforeState =
                  CheckpointStateReducer.copyLine(secondBefore)
              ..afterState = null,
          ];

          final nextLines =
              CheckpointStateReducer.copyLines(currentLines);
          final maxIndex = firstLineIndex > secondLineIndex
              ? firstLineIndex
              : secondLineIndex;
          final minIndex = firstLineIndex < secondLineIndex
              ? firstLineIndex
              : secondLineIndex;
          nextLines.removeAt(maxIndex);
          nextLines.removeAt(minIndex);
          nextLines.insert(
            minIndex,
            CheckpointStateReducer.copyLine(mergedLine),
          );

          return CheckpointMutationPlan(
            nextLines: sortAndReindexSubtitleLines(nextLines),
            deltas: replayDeltas,
            forceSnapshot: true,
          );
        },
      );
      return true;
    } catch (error) {
      logError('SubtitleRepository: Atomic merge failed: $error');
      return false;
    }
  }

  /// Delete a single subtitle line
  Future<bool> deleteLine(int collectionId, int index) async {
    logInfo('SubtitleRepository: Deleting line $index from collection $collectionId');
    try {
      final success = await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            index < 0 ||
            index >= collection.lines.length) {
          return false;
        }

        if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
          _isar, collectionId,
        )) return false;

        final remaining = List<SubtitleLine>.from(collection.lines)
          ..removeAt(index);
        collection.lines = sortAndReindexSubtitleLines(remaining);
        await _isar.subtitleCollections.put(collection);
        return true;
      });
      if (success) {
        logInfo('SubtitleRepository: Successfully deleted line $index');
      } else {
        logWarning('SubtitleRepository: Failed to delete line $index');
      }
      return success;
    } catch (e) {
      logError('SubtitleRepository: Error deleting line $index: $e');
      rethrow;
    }
  }

  /// Batch delete selected lines atomically with v2 history.
  Future<Map<String, int>> batchDeleteLines(
    int collectionId,
    List<int> indices, {
    required int sessionId,
  }) async {
    logInfo(
      'SubtitleRepository: Batch deleting ${indices.length} lines '
      'from collection $collectionId',
    );

    final requested = indices.toSet();
    if (requested.isEmpty) {
      return const {'success': 0, 'failed': 0};
    }

    var successCount = 0;
    var failedCount = requested.length;

    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'delete',
        description: 'Batch deleted ${requested.length} lines',
        buildMutation: (currentLines) {
          final valid = requested
              .where(
                (index) => index >= 0 && index < currentLines.length,
              )
              .toList()
            ..sort((a, b) => b.compareTo(a));

          successCount = valid.length;
          failedCount = requested.length - valid.length;

          if (valid.isEmpty) {
            return CheckpointMutationPlan(
              nextLines: CheckpointStateReducer.copyLines(currentLines),
              deltas: const <SubtitleLineDelta>[],
            );
          }

          final deltas = <SubtitleLineDelta>[
            for (final index in valid)
              SubtitleLineDelta()
                ..changeType = 'delete'
                ..lineIndex = index
                ..beforeState =
                    CheckpointStateReducer.copyLine(currentLines[index])
                ..afterState = null,
          ];

          final nextLines =
              CheckpointStateReducer.copyLines(currentLines);
          for (final index in valid) {
            nextLines.removeAt(index);
          }

          return CheckpointMutationPlan(
            nextLines: sortAndReindexSubtitleLines(nextLines),
            deltas: deltas,
            forceSnapshot: true,
          );
        },
      );

      return {
        'success': successCount,
        'failed': failedCount,
      };
    } catch (error) {
      logError('SubtitleRepository: Atomic batch delete error: $error');
      return {
        'success': 0,
        'failed': requested.length,
      };
    }
  }

  /// Get marked subtitle lines
  Future<List<SubtitleLine>> getMarkedLines(int collectionId) async {
    logInfo('SubtitleRepository: Fetching marked lines for collection $collectionId');
    try {
      final collection = await _isar.subtitleCollections.get(collectionId);
      final markedLines =
          collection?.lines.where((line) => line.marked).toList() ??
              const <SubtitleLine>[];
      logInfo('SubtitleRepository: Found ${markedLines.length} marked lines');
      return markedLines;
    } catch (e) {
      logError('SubtitleRepository: Error fetching marked lines: $e');
      rethrow;
    }
  }

  /// Get all subtitle lines with comments
  Future<List<SubtitleLine>> getLinesWithComments(int collectionId) async {
    logInfo('SubtitleRepository: Fetching lines with comments for collection $collectionId');
    try {
      final collection = await _isar.subtitleCollections.get(collectionId);
      final linesWithComments = collection?.lines
              .where((line) => line.comment?.trim().isNotEmpty == true)
              .toList() ??
          const <SubtitleLine>[];
      logInfo(
        'SubtitleRepository: Found ${linesWithComments.length} lines with comments',
      );
      return linesWithComments;
    } catch (e) {
      logError('SubtitleRepository: Error fetching lines with comments: $e');
      rethrow;
    }
  }

  /// Fetch a session by ID.
  Future<Session?> fetchSession(int sessionId) {
    return _isar.sessions.get(sessionId);
  }

  /// Read the last edited cue index for a session.
  Future<int?> getLastEditedIndex(int sessionId) async {
    return (await _isar.sessions.get(sessionId))?.lastEditedIndex;
  }

  /// Persist the last edited cue index for a session.
  Future<bool> updateLastEditedIndex(int sessionId, int index) async {
    return _isar.writeTxn(() async {
      final session = await _isar.sessions.get(sessionId);
      if (session == null) return false;

      session.lastEditedIndex = index;
      await _isar.sessions.put(session);
      return true;
    });
  }

  /// Atomically replaces the collection state and records one v2 history commit.
  ///
  /// This is intended for compound operations whose final state has already
  /// been computed by a domain service (for example banner insertion).
  Future<bool> replaceCollectionLinesWithHistory({
    required int collectionId,
    required int sessionId,
    required List<SubtitleLine> nextLines,
    required List<SubtitleLineDelta> deltas,
    required String operationType,
    required String description,
    Map<String, dynamic>? metadata,
    bool forceSnapshot = true,
  }) async {
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: operationType,
        description: description,
        metadata: metadata,
        buildMutation: (_) {
          return CheckpointMutationPlan(
            nextLines: CheckpointStateReducer.copyLines(nextLines),
            deltas: deltas,
            forceSnapshot: forceSnapshot,
          );
        },
      );
      return true;
    } catch (error) {
      logError(
        'SubtitleRepository: Atomic collection replacement failed: $error',
      );
      return false;
    }
  }
  /// Update only the saved file URI on a freshly loaded collection.
  ///
  /// Callers may have loaded their subtitle collection before a long-running
  /// file save. Rewriting that stale object could erase intervening edits.
  Future<bool> updateOriginalFileUri({
    required int collectionId,
    required String originalFileUri,
  }) async {
    try {
      return await _isar.writeTxn(() async {
        final current = await _isar.subtitleCollections.get(collectionId);
        if (current == null) return false;
        current.originalFileUri = originalFileUri;
        await _isar.subtitleCollections.put(current);
        return true;
      });
    } catch (error) {
      logError('SubtitleRepository: File URI update failed: $error');
      return false;
    }
  }

  /// Desktop Save As relinks only file-identity metadata after a successful
  /// write. A second editor that changed the destination meanwhile must not
  /// be overwritten by a stale Save As dialog.
  Future<bool> updateSaveLocationIfUnchanged({
    required int collectionId,
    required int sessionId,
    required String? expectedFilePath,
    required String? expectedOriginalFileUri,
    required String? expectedMacOsBookmark,
    required String filePath,
    required String originalFileUri,
    String? macOsBookmark,
  }) async {
    if (filePath.isEmpty || originalFileUri.isEmpty) return false;
    try {
      return await _isar.writeTxn(() async {
        final session = await _isar.sessions.get(sessionId);
        if (session == null ||
            session.subtitleCollectionId != collectionId) return false;
        final current = await _isar.subtitleCollections.get(collectionId);
        if (current == null ||
            current.filePath != expectedFilePath ||
            current.originalFileUri != expectedOriginalFileUri ||
            current.macOsSrtBookmark != expectedMacOsBookmark) return false;
        current.filePath = filePath;
        current.originalFileUri = originalFileUri;
        current.macOsSrtBookmark = macOsBookmark;
        await _isar.subtitleCollections.put(current);
        return true;
      });
    } catch (error) {
      logError('SubtitleRepository: Save As relink rejected: $error');
      return false;
    }
  }

  /// Persist only the encoding metadata on the latest collection object.
  ///
  /// A project settings sheet can stay open while subtitles are edited
  /// elsewhere. Never write its cached collection back to Isar.
  Future<bool> updateEncoding({
    required int collectionId,
    required int sessionId,
    required String encoding,
  }) async {
    if (encoding.trim().isEmpty) return false;
    try {
      return await _isar.writeTxn(() async {
        final session = await _isar.sessions.get(sessionId);
        if (session == null ||
            session.subtitleCollectionId != collectionId) return false;
        final current = await _isar.subtitleCollections.get(collectionId);
        if (current == null) return false;
        current.encoding = encoding;
        await _isar.subtitleCollections.put(current);
        return true;
      });
    } catch (error) {
      logError('SubtitleRepository: Encoding update failed: $error');
      return false;
    }
  }

  /// Legacy full-collection writer. New callers must use targeted metadata
  /// updates or a session-scoped V2 edit. Never bypass an existing V2 HEAD.
  Future<bool> updateCollection(SubtitleCollection collection) async {
    try {
      return await _isar.writeTxn(() async {
        final current = await _isar.subtitleCollections.get(collection.id);
        if (current == null) return false;
        if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
          _isar,
          collection.id,
        )) return false;
        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (e) {
      logError('SubtitleRepository: Error updating collection: $e');
      return false;
    }
  }

  /// Replace one subtitle line with two split parts.
  ///
  /// Checkpoint creation is coordinated by the calling operation so this
  /// method owns persistence only.
  Future<bool> splitLine(
    int collectionId,
    SubtitleLine firstPart,
    SubtitleLine secondPart,
    int originalIndex,
  ) async {
    try {
      return await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            originalIndex < 0 ||
            originalIndex >= collection.lines.length) {
          return false;
        }

        if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
          _isar, collectionId,
        )) return false;
        final lines = List<SubtitleLine>.from(collection.lines);
        lines[originalIndex] = firstPart;
        lines.insert(originalIndex + 1, secondPart);
        collection.lines = sortAndReindexSubtitleLines(lines);
        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (e) {
      logError('SubtitleRepository: Error splitting line: $e');
      return false;
    }
  }

  /// Replace two subtitle lines with one merged line.
  ///
  /// Checkpoint creation is coordinated by the calling operation so this
  /// method owns persistence only.
  Future<bool> mergeLines(
    int collectionId,
    SubtitleLine mergedLine,
    int firstLineIndex,
    int secondLineIndex,
  ) async {
    try {
      return await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            firstLineIndex < 0 ||
            secondLineIndex < 0 ||
            firstLineIndex >= collection.lines.length ||
            secondLineIndex >= collection.lines.length ||
            firstLineIndex == secondLineIndex) {
          return false;
        }

        if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
          _isar, collectionId,
        )) return false;
        final lines = List<SubtitleLine>.from(collection.lines);
        final maxIndex =
            firstLineIndex > secondLineIndex ? firstLineIndex : secondLineIndex;
        final minIndex =
            firstLineIndex < secondLineIndex ? firstLineIndex : secondLineIndex;
        lines.removeAt(maxIndex);
        lines.removeAt(minIndex);
        lines.insert(minIndex, mergedLine);

        collection.lines = sortAndReindexSubtitleLines(lines);
        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (e) {
      logError('SubtitleRepository: Error merging lines: $e');
      return false;
    }
  }

  /// Insert a subtitle line and normalize ordering/indexes once.
  Future<bool> addLine(
    int collectionId,
    SubtitleLine line,
    int insertIndex,
  ) async {
    try {
      return await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null) return false;

        if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
          _isar, collectionId,
        )) return false;
        final lines = List<SubtitleLine>.from(collection.lines);
        final targetIndex = insertIndex.clamp(0, lines.length);
        lines.insert(targetIndex, line);
        collection.lines = sortAndReindexSubtitleLines(lines);
        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (e) {
      logError('SubtitleRepository: Error adding line: $e');
      return false;
    }
  }

  /// Generate subtitles for video player from SubtitleLine list
  List<Subtitle> generateSubtitles(List<SubtitleLine> subtitleLines) {
    logInfo('SubtitleRepository: Generating ${subtitleLines.length} subtitles for video player');
    try {
      return subtitleLines.asMap().entries.map((entry) {
        final index = entry.key;
        final line = entry.value;
        return Subtitle(
          index: index,
          start: parseTimeString(line.startTime),
          end: parseTimeString(line.endTime),
          text: line.edited ?? line.original,
          marked: line.marked,
          comment: line.comment,
        );
      }).toList();
    } catch (e) {
      logError('SubtitleRepository: Error generating subtitles: $e');
      rethrow;
    }
  }

  /// Generate subtitles from SimpleSubtitleLine list
  List<Subtitle> generateSimpleSubtitles(List<SimpleSubtitleLine> subtitleLines) {
    logInfo('SubtitleRepository: Generating ${subtitleLines.length} simple subtitles for video player');
    try {
      return subtitleLines.asMap().entries.map((entry) {
        final index = entry.key;
        final line = entry.value;
        return Subtitle(
          index: index,
          start: parseTimeString(line.startTime),
          end: parseTimeString(line.endTime),
          text: line.text,
          marked: false,
          comment: null,
        );
      }).toList();
    } catch (e) {
      logError('SubtitleRepository: Error generating simple subtitles: $e');
      rethrow;
    }
  }

  /// Convert subtitle lines to source view entries
  List<SubtitleEntry> convertToSourceViewEntries(List<SubtitleLine> lines) {
    logInfo('SubtitleRepository: Converting ${lines.length} lines to source view entries');
    try {
      return lines.asMap().entries.map((entry) {
        return SubtitleEntry.fromSubtitleLine(entry.value, entry.key);
      }).toList();
    } catch (e) {
      logError('SubtitleRepository: Error converting to source view entries: $e');
      rethrow;
    }
  }

  /// Sync source view entries back to database.
  ///
  /// The source list is authoritative: removed entries are deleted, added
  /// entries become new subtitle lines, and matching existing cues keep their
  /// original/mark/comment metadata.
  ///
  /// Desktop callers use the guarded variant below. It compares the entire
  /// previously displayed state in the same transaction as the mutation, so
  /// raw multi-cue edits cannot overwrite changes made by another window.
  Future<bool> syncSourceViewFromSnapshotWithHistory({
    required int collectionId,
    required int sessionId,
    required List<SubtitleLine> expectedLines,
    required List<SubtitleEntry> entries,
    bool isEditMode = false,
  }) async {
    final expected = CheckpointStateReducer.copyLines(expectedLines);
    try {
      await _historyTransaction.commit(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        operationType: 'source-view',
        description: 'Saved Source View changes',
        buildMutation: (currentLines) {
          if (!CheckpointStateReducer.samePersistedLines(
              currentLines, expected)) {
            throw StateError('Source View baseline is stale. Reload the project.');
          }
          final next = SourceViewReconciler.reconcile(
            existingLines: currentLines,
            entries: entries,
            isEditMode: isEditMode,
          );
          return CheckpointMutationPlan(
            nextLines: next,
            deltas: CheckpointStateReducer.diffAsIndexDeltas(currentLines, next),
            forceSnapshot: true,
          );
        },
      );
      return true;
    } catch (error) {
      logError('SubtitleRepository: Guarded Source View commit failed: $error');
      return false;
    }
  }

  Future<void> syncSourceViewToDatabase(
    int collectionId,
    List<SubtitleEntry> entries, {
    int? sessionId,
  }) async {
    logInfo(
      'SubtitleRepository: Syncing ${entries.length} source view entries to database',
    );

    try {
      if (sessionId != null) {
        final session = await _isar.sessions.get(sessionId);
        final isEditMode = session?.editMode ?? false;
        await _historyTransaction.commit(
          sessionId: sessionId,
          subtitleCollectionId: collectionId,
          operationType: 'source-view',
          description: 'Saved Source View changes',
          buildMutation: (currentLines) {
            final reconciled = SourceViewReconciler.reconcile(
              existingLines: currentLines,
              entries: entries,
              isEditMode: isEditMode,
            );
            return CheckpointMutationPlan(
              nextLines: reconciled,
              deltas: CheckpointStateReducer.diffAsIndexDeltas(
                currentLines,
                reconciled,
              ),
              // Source View permits arbitrary reordering and bulk replacement.
              forceSnapshot: true,
            );
          },
        );
      } else {
        // Compatibility-only entrypoint for callers not yet session-scoped.
        // The active editor always supplies its session above.
        await _isar.writeTxn(() async {
          final collection = await _isar.subtitleCollections.get(collectionId);
          if (collection == null) {
            throw StateError('Subtitle collection $collectionId not found');
          }
          if (!await LegacyCollectionWriteGuard.canReplaceEntireCollection(
            _isar, collectionId,
          )) {
            throw StateError(
              'A session-scoped V2 history commit is required for Source View.',
            );
          }
          collection.lines = SourceViewReconciler.reconcile(
            existingLines: collection.lines,
            entries: entries,
          );
          await _isar.subtitleCollections.put(collection);
        });
      }
      logInfo('SubtitleRepository: Source View synced successfully');
    } catch (e) {
      logError('SubtitleRepository: Error syncing source view: $e');
      rethrow;
    }
  }

  /// Create initial checkpoint snapshot
  Future<void> createInitialSnapshot(
    int collectionId,
    int sessionId,
  ) async {
    logInfo('SubtitleRepository: Creating initial checkpoint snapshot for collection $collectionId');
    try {
      await _checkpoints.createInitialSnapshot(
        subtitleCollectionId: collectionId,
        sessionId: sessionId,
      );
      logInfo('SubtitleRepository: Successfully created initial snapshot');
    } catch (e) {
      logWarning('SubtitleRepository: Could not create initial snapshot: $e');
      // Don't rethrow - this is not critical for basic functionality
    }
  }

  /// Update last edited session
  Future<void> updateLastEditedSession(int sessionId) async {
    logInfo('SubtitleRepository: Updating last edited session to $sessionId');
    try {
      if (sessionId <= 0) {
        throw ArgumentError.value(
          sessionId,
          'sessionId',
          'Session ID must be positive.',
        );
      }

      await _preferencesStore.update(
        (preferences) => preferences.lastEditedSession = sessionId,
      );
      logInfo('SubtitleRepository: Successfully updated last edited session');
    } catch (e) {
      logError('SubtitleRepository: Error updating last edited session: $e');
      rethrow;
    }
  }

  /// Get session edit mode
  Future<bool> getSessionEditMode(int sessionId) async {
    logInfo('SubtitleRepository: Fetching edit mode for session $sessionId');
    try {
      final session = await _isar.sessions.get(sessionId);
      final editMode = session?.editMode ?? false;
      logInfo('SubtitleRepository: Session $sessionId edit mode: $editMode');
      return editMode;
    } catch (e) {
      logError('SubtitleRepository: Error fetching session edit mode: $e');
      rethrow;
    }
  }
}
