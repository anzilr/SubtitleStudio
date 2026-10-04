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
  Future<bool> updateMultipleLines(
    int collectionId,
    List<SubtitleLine> updatedLines,
  ) async {
    if (updatedLines.isEmpty) return true;

    try {
      return await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null) return false;

        final updatesByCueNumber = <int, SubtitleLine>{
          for (final line in updatedLines) line.index: line,
        };

        var updatedCount = 0;
        for (int i = 0; i < collection.lines.length; i++) {
          final replacement =
              updatesByCueNumber[collection.lines[i].index];
          if (replacement != null) {
            collection.lines[i] = replacement;
            updatedCount++;
          }
        }

        if (updatedCount != updatesByCueNumber.length) {
          logWarning(
            'SubtitleRepository: Batch update matched $updatedCount of '
            '${updatesByCueNumber.length} requested lines',
          );
        }

        await _isar.subtitleCollections.put(collection);
        return updatedCount == updatesByCueNumber.length;
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

  /// Mark a subtitle line
  Future<bool> markLine(int collectionId, int index, bool marked) async {
    logInfo('SubtitleRepository: Marking line $index in collection $collectionId as $marked');
    try {
      final success = await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            index < 0 ||
            index >= collection.lines.length) {
          return false;
        }

        collection.lines[index].marked = marked;
        await _isar.subtitleCollections.put(collection);
        return true;
      });
      if (success) {
        logInfo('SubtitleRepository: Successfully marked line $index');
      } else {
        logWarning('SubtitleRepository: Failed to mark line $index');
      }
      return success;
    } catch (e) {
      logError('SubtitleRepository: Error marking line $index: $e');
      rethrow;
    }
  }

  /// Update comment for a subtitle line
  Future<bool> updateComment(int collectionId, int index, String? comment) async {
    logInfo('SubtitleRepository: Updating comment for line $index in collection $collectionId');
    try {
      final success = await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            index < 0 ||
            index >= collection.lines.length) {
          return false;
        }

        collection.lines[index].comment = comment;
        await _isar.subtitleCollections.put(collection);
        return true;
      });

      if (success) {
        logInfo(
          'SubtitleRepository: Successfully updated comment for line $index',
        );
      } else {
        logWarning(
          'SubtitleRepository: Could not update comment for invalid line $index',
        );
      }
      return success;
    } catch (e) {
      logError('SubtitleRepository: Error updating comment for line $index: $e');
      rethrow;
    }
  }

  /// Clear mark/comment state for a subtitle line in one transaction.
  Future<bool> unmarkLine(int collectionId, int index) async {
    return _isar.writeTxn(() async {
      final collection = await _isar.subtitleCollections.get(collectionId);
      if (collection == null ||
          index < 0 ||
          index >= collection.lines.length) {
        return false;
      }

      final line = collection.lines[index];
      line.marked = false;
      line.comment = null;
      line.resolved = false;
      await _isar.subtitleCollections.put(collection);
      return true;
    });
  }

  /// Update the resolved state attached to a subtitle comment.
  Future<bool> updateResolved(
    int collectionId,
    int index,
    bool resolved,
  ) async {
    return _isar.writeTxn(() async {
      final collection = await _isar.subtitleCollections.get(collectionId);
      if (collection == null ||
          index < 0 ||
          index >= collection.lines.length) {
        return false;
      }

      collection.lines[index].resolved = resolved;
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

  /// Persist a changed subtitle collection.
  Future<bool> updateCollection(SubtitleCollection collection) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.subtitleCollections.put(collection);
      });
      return true;
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
  Future<void> syncSourceViewToDatabase(
    int collectionId,
    List<SubtitleEntry> entries,
  ) async {
    logInfo(
      'SubtitleRepository: Syncing ${entries.length} source view entries to database',
    );

    try {
      final collection = await _isar.subtitleCollections.get(collectionId);
      if (collection == null) {
        throw Exception('Subtitle collection $collectionId not found');
      }

      final reconciled = SourceViewReconciler.reconcile(
        existingLines: collection.lines,
        entries: entries,
      );

      await _isar.writeTxn(() async {
        collection.lines = reconciled;
        await _isar.subtitleCollections.put(collection);
      });

      logInfo(
        'SubtitleRepository: Successfully synced source view '
        '(${collection.lines.length} lines)',
      );
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
