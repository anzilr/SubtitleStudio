import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/subtitle_sorting.dart';
import 'package:subtitle_studio/widgets/video/subtitle.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:subtitle_studio/services/checkpoint_manager.dart';
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

  SubtitleRepository(this._isar);

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

  /// Persist one edited subtitle line and create an edit checkpoint when
  /// text or timing changed.
  Future<bool> saveLineChanges(
    int collectionId,
    SubtitleLine updatedLine, {
    required int sessionId,
    SubtitleLine? beforeLine,
  }) async {
    SubtitleLine? lineBeforeChanges;
    var shouldCreateCheckpoint = false;

    final saved = await _isar.writeTxn(() async {
      final collection = await _isar.subtitleCollections.get(collectionId);
      if (collection == null) return false;

      final listIndex = updatedLine.index - 1;
      if (listIndex < 0 || listIndex >= collection.lines.length) {
        return false;
      }

      lineBeforeChanges = beforeLine ?? collection.lines[listIndex];

      final timingChanged =
          lineBeforeChanges!.startTime != updatedLine.startTime ||
          lineBeforeChanges!.endTime != updatedLine.endTime;

      shouldCreateCheckpoint =
          timingChanged ||
          lineBeforeChanges!.original != updatedLine.original ||
          lineBeforeChanges!.edited != updatedLine.edited;

      collection.lines[listIndex] = updatedLine;

      if (timingChanged) {
        collection.lines = sortAndReindexSubtitleLines(collection.lines);
      }

      await _isar.subtitleCollections.put(collection);
      return true;
    });

    if (saved &&
        shouldCreateCheckpoint &&
        lineBeforeChanges != null) {
      await CheckpointManager.createEditCheckpoint(
        sessionId: sessionId,
        subtitleCollectionId: collectionId,
        beforeLine: lineBeforeChanges!,
        afterLine: updatedLine,
      );
    }

    return saved;
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

  /// Batch delete multiple subtitle lines using one collection rewrite.
  ///
  /// [createCheckpoint] is retained for API compatibility; checkpoint creation
  /// is coordinated by the calling workflow because this repository method
  /// does not have the session ID required to create one.
  Future<Map<String, int>> batchDeleteLines(
    int collectionId,
    List<int> indices, {
    bool createCheckpoint = true,
  }) async {
    logInfo(
      'SubtitleRepository: Batch deleting ${indices.length} lines '
      'from collection $collectionId',
    );

    try {
      final requested = indices.toSet();
      if (requested.isEmpty) {
        return const {'success': 0, 'failed': 0};
      }

      final result = await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null) {
          return {
            'success': 0,
            'failed': requested.length,
          };
        }

        final valid = requested
            .where(
              (index) =>
                  index >= 0 && index < collection.lines.length,
            )
            .toSet();

        final remaining = <SubtitleLine>[];
        for (int index = 0; index < collection.lines.length; index++) {
          if (!valid.contains(index)) {
            remaining.add(collection.lines[index]);
          }
        }

        if (valid.isNotEmpty) {
          collection.lines = sortAndReindexSubtitleLines(remaining);
          await _isar.subtitleCollections.put(collection);
        }

        return {
          'success': valid.length,
          'failed': requested.length - valid.length,
        };
      });

      logInfo(
        'SubtitleRepository: Batch delete completed - '
        'Success: ${result['success']}, Failed: ${result['failed']}',
      );

      return result;
    } catch (e) {
      logError('SubtitleRepository: Batch delete error: $e');
      rethrow;
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

  /// Create a checkpoint for the current state
  Future<void> createCheckpoint(
    int collectionId,
    int sessionId,
    String operationType,
    String description,
  ) async {
    logInfo('SubtitleRepository: Creating checkpoint "$description" for collection $collectionId');
    try {
      await CheckpointManager.createCheckpoint(
        subtitleCollectionId: collectionId,
        sessionId: sessionId,
        operationType: operationType,
        description: description,
        deltas: [], // Empty for manual checkpoints
      );
      logInfo('SubtitleRepository: Successfully created checkpoint');
    } catch (e) {
      logError('SubtitleRepository: Error creating checkpoint: $e');
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
      await CheckpointManager.createInitialSnapshot(
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

      await _isar.writeTxn(() async {
        final preferences = await _isar.preferences.where().findFirst() ??
            Preferences(autoSave: true);
        preferences.lastEditedSession = sessionId;
        await _isar.preferences.put(preferences);
      });
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
