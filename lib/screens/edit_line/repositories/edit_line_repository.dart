import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/subtitle_sorting.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_preferences_repository.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:subtitle_studio/widgets/video/subtitle.dart'; // For Subtitle
import 'package:subtitle_studio/utils/subtitle_parser.dart'; // For SimpleSubtitleLine
import 'package:subtitle_studio/utils/platform_file_handler.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/checkpoint_history_transaction.dart';

/// Repository layer for EditLineScreen operations
/// 
/// This class abstracts all database operations, file I/O, and business logic
/// for single subtitle line editing, following clean architecture principles.
/// 
/// Responsibilities:
/// - Fetch and update single subtitle lines
/// - Load and save preferences specific to edit line screen
/// - Video path management
/// - File save operations (SRT export)
/// - Character counting and validation logic
/// - Subtitle generation for video player
/// 
/// Following Single Responsibility Principle:
/// - Database operations are isolated from UI
/// - Business logic separated from presentation
/// - Preferences managed in one place
/// - File I/O abstracted from UI concerns
class EditLineRepository {
  final Isar _isar;
  final EditLinePreferencesRepository _preferences;
  final CheckpointHistoryTransaction _historyTransaction;

  EditLineRepository(
    this._isar,
    this._preferences,
  ) : _historyTransaction = CheckpointHistoryTransaction(_isar);

  /// Fetch a single subtitle line by collection ID and index
  /// 
  /// Returns null if not found or index is out of bounds
  Future<SubtitleLine?> fetchSubtitleLine(
    Id collectionId,
    int index,
  ) async {
    await logInfo(
      'Fetching subtitle line at index $index from collection $collectionId',
      context: 'EditLineRepository.fetchSubtitleLine',
    );

    try {
      final collection = await _isar.subtitleCollections.get(collectionId);

      if (collection == null) {
        await logWarning(
          'Subtitle collection $collectionId not found',
          context: 'EditLineRepository.fetchSubtitleLine',
        );
        return null;
      }

      // Check bounds: index is 1-based for display, but array is 0-based
      if (index < 1 || index > collection.lines.length) {
        await logWarning(
          'Index $index out of bounds for collection $collectionId (length: ${collection.lines.length})',
          context: 'EditLineRepository.fetchSubtitleLine',
        );
        return null;
      }

      final line = collection.lines[index - 1]; // Convert to 0-based array index

      final editedPreview = line.edited != null && line.edited!.isNotEmpty
          ? line.edited!.substring(0, line.edited!.length > 50 ? 50 : line.edited!.length)
          : '';

      await logInfo(
        'Successfully fetched line $index: "$editedPreview..."',
        context: 'EditLineRepository.fetchSubtitleLine',
      );

      return line;
    } catch (e, stackTrace) {
      await logError(
        'Failed to fetch subtitle line',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.fetchSubtitleLine',
      );
      rethrow;
    }
  }

  /// Fetch subtitle collection metadata
  Future<SubtitleCollection?> fetchSubtitleCollection(Id collectionId) async {
    await logInfo(
      'Fetching subtitle collection $collectionId',
      context: 'EditLineRepository.fetchSubtitleCollection',
    );

    try {
      final collection = await _isar.subtitleCollections.get(collectionId);

      if (collection != null) {
        await logInfo(
          'Successfully fetched collection "${collection.fileName}" with ${collection.lines.length} lines',
          context: 'EditLineRepository.fetchSubtitleCollection',
        );
      } else {
        await logWarning(
          'Collection $collectionId not found',
          context: 'EditLineRepository.fetchSubtitleCollection',
        );
      }

      return collection;
    } catch (e, stackTrace) {
      await logError(
        'Failed to fetch subtitle collection',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.fetchSubtitleCollection',
      );
      rethrow;
    }
  }

  /// Update a subtitle line in the database
  /// 
  /// Updates original text, edited text, start time, and end time
  /// Returns true if successful, false otherwise
  Future<bool> updateSubtitleLine({
    required Id collectionId,
    required int lineIndex,
    required String originalText,
    required String editedText,
    required String startTime,
    required String endTime,
  }) async {
    await logInfo(
      'Updating subtitle line $lineIndex in collection $collectionId',
      context: 'EditLineRepository.updateSubtitleLine',
    );

    try {
      return await logPerformance(
        'Update subtitle line',
        () async {
          final collection = await _isar.subtitleCollections.get(collectionId);

          if (collection == null) {
            await logWarning(
              'Collection $collectionId not found',
              context: 'EditLineRepository.updateSubtitleLine',
            );
            return false;
          }

          // Validate index bounds (1-based)
          if (lineIndex < 1 || lineIndex > collection.lines.length) {
            await logWarning(
              'Index $lineIndex out of bounds',
              context: 'EditLineRepository.updateSubtitleLine',
            );
            return false;
          }

          // Update the line (0-based array access)
          final arrayIndex = lineIndex - 1;
          collection.lines[arrayIndex].original = originalText;
          collection.lines[arrayIndex].edited = editedText;
          collection.lines[arrayIndex].startTime = startTime;
          collection.lines[arrayIndex].endTime = endTime;

          // Write to database
          await _isar.writeTxn(() async {
            await _isar.subtitleCollections.put(collection);
          });

          await logInfo(
            'Successfully updated line $lineIndex',
            context: 'EditLineRepository.updateSubtitleLine',
          );

          return true;
        },
        context: 'EditLineRepository',
      );
    } catch (e, stackTrace) {
      await logError(
        'Failed to update subtitle line',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.updateSubtitleLine',
      );
      return false;
    }
  }

  /// Persist a complete line atomically with v2 checkpoint history.
  Future<bool> saveSubtitleLineChanges({
    required Id collectionId,
    required SubtitleLine updatedLine,
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
          final arrayIndex = updatedLine.index - 1;
          if (arrayIndex < 0 || arrayIndex >= currentLines.length) {
            throw RangeError.index(
              arrayIndex,
              currentLines,
              'updatedLine.index',
            );
          }

          final persistedBefore = currentLines[arrayIndex];
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
          nextLines[arrayIndex] =
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
                ..lineIndex = arrayIndex
                ..beforeState =
                    CheckpointStateReducer.copyLine(persistedBefore)
                ..afterState =
                    CheckpointStateReducer.copyLine(updatedLine),
            );
          }

          return CheckpointMutationPlan(
            nextLines: nextLines,
            deltas: deltas,
            forceSnapshot: timingChanged,
          );
        },
      );
      return true;
    } catch (error, stackTrace) {
      await logError(
        'Failed to save complete subtitle line',
        error: error,
        stackTrace: stackTrace,
        context: 'EditLineRepository.saveSubtitleLineChanges',
      );
      return false;
    }
  }

  Future<bool> addSubtitleLine(
    Id collectionId,
    SubtitleLine line,
    int insertIndex,
  ) async {
    try {
      return await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            insertIndex < 0 ||
            insertIndex > collection.lines.length) {
          return false;
        }

        final lines = List<SubtitleLine>.from(collection.lines)
          ..insert(insertIndex, line);
        collection.lines = sortAndReindexSubtitleLines(lines);
        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (e, stackTrace) {
      await logError(
        'Failed to add subtitle line',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.addSubtitleLine',
      );
      return false;
    }
  }

  Future<bool> updateSubtitleCollection(
    SubtitleCollection collection,
  ) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.subtitleCollections.put(collection);
      });
      return true;
    } catch (e, stackTrace) {
      await logError(
        'Failed to update subtitle collection',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.updateSubtitleCollection',
      );
      return false;
    }
  }

  Future<void> updateLastEditedIndex(int sessionId, int index) async {
    await _isar.writeTxn(() async {
      final session = await _isar.sessions.get(sessionId);
      if (session == null) return;
      session.lastEditedIndex = index;
      await _isar.sessions.put(session);
    });
  }

  /// Delete a subtitle line from the collection
  Future<bool> deleteSubtitleLine(Id collectionId, int lineIndex) async {
    await logInfo(
      'Deleting subtitle line $lineIndex from collection $collectionId',
      context: 'EditLineRepository.deleteSubtitleLine',
    );

    try {
      final success = await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            lineIndex < 0 ||
            lineIndex >= collection.lines.length) {
          return false;
        }

        final remaining = List<SubtitleLine>.from(collection.lines)
          ..removeAt(lineIndex);
        collection.lines = sortAndReindexSubtitleLines(remaining);
        await _isar.subtitleCollections.put(collection);
        return true;
      });

      if (success) {
        await logInfo(
          'Successfully deleted line $lineIndex',
          context: 'EditLineRepository.deleteSubtitleLine',
        );
      } else {
        await logWarning(
          'Failed to delete line $lineIndex',
          context: 'EditLineRepository.deleteSubtitleLine',
        );
      }

      return success;
    } catch (e, stackTrace) {
      await logError(
        'Error deleting subtitle line',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.deleteSubtitleLine',
      );
      return false;
    }
  }

  /// Mark or unmark a subtitle line
  Future<bool> markSubtitleLine(
    Id collectionId,
    int lineIndex,
    bool marked,
  ) async {
    await logInfo(
      'Marking line $lineIndex in collection $collectionId as $marked',
      context: 'EditLineRepository.markSubtitleLine',
    );

    try {
      final success = await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            lineIndex < 0 ||
            lineIndex >= collection.lines.length) {
          return false;
        }

        collection.lines[lineIndex].marked = marked;
        await _isar.subtitleCollections.put(collection);
        return true;
      });

      if (success) {
        await logInfo(
          'Successfully marked line $lineIndex',
          context: 'EditLineRepository.markSubtitleLine',
        );
      } else {
        await logWarning(
          'Failed to mark line $lineIndex',
          context: 'EditLineRepository.markSubtitleLine',
        );
      }

      return success;
    } catch (e, stackTrace) {
      await logError(
        'Error marking subtitle line',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.markSubtitleLine',
      );
      return false;
    }
  }

  /// Update comment for a subtitle line
  Future<bool> updateSubtitleLineComment(
    Id collectionId,
    int lineIndex,
    String? comment,
  ) async {
    await logInfo(
      'Updating comment for line $lineIndex in collection $collectionId',
      context: 'EditLineRepository.updateSubtitleLineComment',
    );

    try {
      final success = await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            lineIndex < 0 ||
            lineIndex >= collection.lines.length) {
          return false;
        }

        collection.lines[lineIndex].comment = comment;
        await _isar.subtitleCollections.put(collection);
        return true;
      });

      if (!success) {
        await logWarning(
          'Could not update comment for invalid line $lineIndex',
          context: 'EditLineRepository.updateSubtitleLineComment',
        );
        return false;
      }

      await logInfo(
        'Successfully updated comment for line $lineIndex',
        context: 'EditLineRepository.updateSubtitleLineComment',
      );

      return true;
    } catch (e, stackTrace) {
      await logError(
        'Error updating comment',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.updateSubtitleLineComment',
      );
      return false;
    }
  }

  Future<bool> updateSubtitleLineResolved(
    Id collectionId,
    int lineIndex,
    bool resolved,
  ) async {
    try {
      return await _isar.writeTxn(() async {
        final collection = await _isar.subtitleCollections.get(collectionId);
        if (collection == null ||
            lineIndex < 0 ||
            lineIndex >= collection.lines.length) {
          return false;
        }

        collection.lines[lineIndex].resolved = resolved;
        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (e, stackTrace) {
      await logError(
        'Failed to update resolved status',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.updateSubtitleLineResolved',
      );
      return false;
    }
  }

  Future<List<SubtitleLine>> getMarkedSubtitleLines(
    Id collectionId,
  ) async {
    try {
      final collection = await _isar.subtitleCollections.get(collectionId);
      return collection?.lines
              .where((line) => line.marked)
              .toList(growable: false) ??
          const <SubtitleLine>[];
    } catch (e, stackTrace) {
      await logError(
        'Failed to load marked subtitle lines',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.getMarkedSubtitleLines',
      );
      return const <SubtitleLine>[];
    }
  }

  /// Generate subtitles for video player from collection
  Future<List<Subtitle>> generateSubtitles(Id collectionId) async {
    await logInfo(
      'Generating subtitles for video player from collection $collectionId',
      context: 'EditLineRepository.generateSubtitles',
    );

    try {
      return await logPerformance(
        'Generate subtitles for video',
        () async {
          final collection = await _isar.subtitleCollections.get(collectionId);

          if (collection == null || collection.lines.isEmpty) {
            await logWarning(
              'Collection $collectionId not found or empty',
              context: 'EditLineRepository.generateSubtitles',
            );
            return <Subtitle>[];
          }

          final subtitles = collection.lines.map((line) {
            final startDuration = _parseTimeString(line.startTime);
            final endDuration = _parseTimeString(line.endTime);

            return Subtitle(
              index: line.index,
              start: startDuration,
              end: endDuration,
              text: line.edited ?? '', // Handle null with empty string
            );
          }).toList();

          await logInfo(
            'Generated ${subtitles.length} subtitles for video player',
            context: 'EditLineRepository.generateSubtitles',
          );

          return subtitles;
        },
        context: 'EditLineRepository',
      );
    } catch (e, stackTrace) {
      await logError(
        'Failed to generate subtitles',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.generateSubtitles',
      );
      return [];
    }
  }

  /// Generate secondary subtitles from simple subtitle lines
  List<Subtitle> generateSecondarySubtitles(
    List<SimpleSubtitleLine> lines,
  ) {
    return lines.map((line) {
      final startDuration = _parseTimeString(line.startTime);
      final endDuration = _parseTimeString(line.endTime);

      return Subtitle(
        index: line.index,
        start: startDuration,
        end: endDuration,
        text: line.text, // text is non-nullable in SimpleSubtitleLine
      );
    }).toList();
  }

  /// Parse time string (HH:mm:ss,SSS or HH:mm:ss.SSS) to Duration
  Duration _parseTimeString(String time) {
    try {
      // Normalize separator - replace period with comma for consistency
      final normalized = time.replaceAll('.', ',');
      final parts = normalized.split(',');
      final hms = parts[0].split(':');
      final hours = int.parse(hms[0]);
      final minutes = int.parse(hms[1]);
      final seconds = int.parse(hms[2]);
      final milliseconds = int.parse(parts[1]);

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } catch (e) {
      logWarning(
        'Failed to parse time string "$time": $e',
        context: 'EditLineRepository._parseTimeString',
      );
      return Duration.zero;
    }
  }

  // ============================================
  // PREFERENCES OPERATIONS
  // ============================================

  /// Load all preferences relevant to edit line screen
  /// 
  /// Batches all preference loading into a single efficient operation
  Future<EditLinePreferences> loadAllPreferences(Id collectionId) async {
    await logInfo(
      'Loading all preferences for edit line screen',
      context: 'EditLineRepository.loadAllPreferences',
    );

    try {
      return await logPerformance(
        'Load all edit line preferences',
        () async {
          final stored = await _preferences.load(collectionId);

          final preferences = EditLinePreferences(
            isMsoneEnabled: stored.msoneEnabled,
            showOriginalLine: stored.showOriginalLine,
            autoSaveWithNavigation: stored.autoSaveWithNavigation,
            saveToFileEnabled: stored.saveToFileEnabled,
            autoResizeOnKeyboard: stored.autoResizeOnKeyboard,
            maxLineLength: stored.maxLineLength,
            showOriginalTextField: stored.showOriginalTextField,
            videoPath: stored.videoPath,
            resizeRatio: stored.editLineResizeRatio,
            mobileVideoResizeRatio: stored.mobileVideoResizeRatio,
            layoutPreference: stored.switchLayout,
            colorHistory: stored.colorHistory
                .map(_parseColorFromHex)
                .whereType<Color>()
                .toList(growable: false),
          );

          await logInfo(
            'Successfully loaded all preferences',
            context: 'EditLineRepository.loadAllPreferences',
          );

          return preferences;
        },
        context: 'EditLineRepository',
      );
    } catch (e, stackTrace) {
      await logError(
        'Failed to load preferences',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.loadAllPreferences',
      );

      return EditLinePreferences.defaults();
    }
  }

  /// Parse color from hex string
  Color? _parseColorFromHex(String hex) {
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (e) {
      return null;
    }
  }

  /// Save individual preference
  Future<void> savePreference(String key, dynamic value) async {
    try {
      final handled = await _preferences.savePreference(key, value);
      if (!handled) {
        await logWarning(
          'Unknown preference key: $key',
          context: 'EditLineRepository.savePreference',
        );
      }
    } catch (e, stackTrace) {
      await logError(
        'Failed to save preference $key',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.savePreference',
      );
    }
  }

  /// Save video path for collection
  Future<void> saveVideoPath(Id collectionId, String path) async {
    await logInfo(
      'Saving video path for collection $collectionId',
      context: 'EditLineRepository.saveVideoPath',
    );

    try {
      await _preferences.saveVideoPath(collectionId, path);
      await logInfo(
        'Successfully saved video path',
        context: 'EditLineRepository.saveVideoPath',
      );
    } catch (e, stackTrace) {
      await logError(
        'Failed to save video path',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.saveVideoPath',
      );
    }
  }

  /// Remove video path for collection
  Future<void> removeVideoPath(Id collectionId) async {
    await logInfo(
      'Removing video path for collection $collectionId',
      context: 'EditLineRepository.removeVideoPath',
    );

    try {
      await _preferences.removeVideoPath(collectionId);
      await logInfo(
        'Successfully removed video path',
        context: 'EditLineRepository.removeVideoPath',
      );
    } catch (e, stackTrace) {
      await logError(
        'Failed to remove video path',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.removeVideoPath',
      );
    }
  }

  /// Save color history
  Future<void> saveColorHistory(List<Color> colors) async {
    try {
      final colorStrings = colors
          .map((color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}')
          .toList();
      await _preferences.saveColorHistory(colorStrings);
    } catch (e, stackTrace) {
      await logError(
        'Failed to save color history',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.saveColorHistory',
      );
    }
  }

  // ============================================
  // FILE OPERATIONS
  // ============================================

  /// Save subtitle content to file using 3-strategy approach
  /// 
  /// Strategy 1: Try originalFileUri (SAF URI)
  /// Strategy 2: Try filePath
  /// Strategy 3: Ask user to pick new location
  /// 
  /// Returns true if save was successful
  Future<bool> saveSrtFile({
    required String content,
    required String? originalFileUri,
    required String? filePath,
    required Function() onPickNewLocation,
  }) async {
    await logInfo(
      'Attempting to save SRT file with 3-strategy approach',
      context: 'EditLineRepository.saveSrtFile',
    );

    try {
      return await logPerformance(
        'Save SRT file',
        () async {
          // Strategy 1: Try SAF URI
          if (originalFileUri != null && originalFileUri.isNotEmpty) {
            await logInfo(
              'Strategy 1: Attempting to save using SAF URI',
              context: 'EditLineRepository.saveSrtFile',
            );

            try {
              final success = await PlatformFileHandler.writeFile(
                content: content,
                filePath: originalFileUri,
                mimeType: 'application/x-subrip',
              );

              if (success) {
                await logInfo(
                  'Strategy 1 successful: Saved via SAF URI',
                  context: 'EditLineRepository.saveSrtFile',
                );
                return true;
              }
            } catch (e) {
              await logWarning(
                'Strategy 1 failed: SAF URI write error',
                context: 'EditLineRepository.saveSrtFile',
              );
            }
          }

          // Strategy 2: Try direct file path
          if (filePath != null && filePath.isNotEmpty) {
            await logInfo(
              'Strategy 2: Attempting to save using file path',
              context: 'EditLineRepository.saveSrtFile',
            );

            try {
              final file = File(filePath);
              if (await file.exists()) {
                await file.writeAsString(content);
                await logInfo(
                  'Strategy 2 successful: Saved via direct file path',
                  context: 'EditLineRepository.saveSrtFile',
                );
                return true;
              } else {
                await logWarning(
                  'Strategy 2 failed: File does not exist',
                  context: 'EditLineRepository.saveSrtFile',
                );
              }
            } catch (e) {
              await logWarning(
                'Strategy 2 failed: File write error: $e',
                context: 'EditLineRepository.saveSrtFile',
              );
            }
          }

          // Strategy 3: Ask user to pick new location
          await logInfo(
            'Strategy 3: Requesting user to pick new save location',
            context: 'EditLineRepository.saveSrtFile',
          );

          onPickNewLocation();
          return false;
        },
        context: 'EditLineRepository',
      );
    } catch (e, stackTrace) {
      await logError(
        'Fatal error during file save',
        error: e,
        stackTrace: stackTrace,
        context: 'EditLineRepository.saveSrtFile',
      );
      return false;
    }
  }
}

/// Preferences model for EditLineScreen
/// 
/// Encapsulates all preference data in a single immutable object
/// for better state management and testability
class EditLinePreferences {
  final bool isMsoneEnabled;
  final bool showOriginalLine;
  final bool autoSaveWithNavigation;
  final bool saveToFileEnabled;
  final bool autoResizeOnKeyboard;
  final int maxLineLength;
  final bool showOriginalTextField;
  final String? videoPath;
  final double resizeRatio;
  final double mobileVideoResizeRatio;
  final String layoutPreference;
  final List<Color> colorHistory;

  const EditLinePreferences({
    required this.isMsoneEnabled,
    required this.showOriginalLine,
    required this.autoSaveWithNavigation,
    required this.saveToFileEnabled,
    required this.autoResizeOnKeyboard,
    required this.maxLineLength,
    required this.showOriginalTextField,
    this.videoPath,
    required this.resizeRatio,
    required this.mobileVideoResizeRatio,
    required this.layoutPreference,
    required this.colorHistory,
  });

  /// Default preferences factory
  factory EditLinePreferences.defaults() {
    return const EditLinePreferences(
      isMsoneEnabled: false,
      showOriginalLine: false,
      autoSaveWithNavigation: true,
      saveToFileEnabled: false,
      autoResizeOnKeyboard: true,
      maxLineLength: 32,
      showOriginalTextField: true,
      videoPath: null,
      resizeRatio: 0.35,
      mobileVideoResizeRatio: 0.4,
      layoutPreference: 'layout1',
      colorHistory: [],
    );
  }

  EditLinePreferences copyWith({
    bool? isMsoneEnabled,
    bool? showOriginalLine,
    bool? autoSaveWithNavigation,
    bool? saveToFileEnabled,
    bool? autoResizeOnKeyboard,
    int? maxLineLength,
    bool? showOriginalTextField,
    String? videoPath,
    double? resizeRatio,
    double? mobileVideoResizeRatio,
    String? layoutPreference,
    List<Color>? colorHistory,
  }) {
    return EditLinePreferences(
      isMsoneEnabled: isMsoneEnabled ?? this.isMsoneEnabled,
      showOriginalLine: showOriginalLine ?? this.showOriginalLine,
      autoSaveWithNavigation:
          autoSaveWithNavigation ?? this.autoSaveWithNavigation,
      saveToFileEnabled: saveToFileEnabled ?? this.saveToFileEnabled,
      autoResizeOnKeyboard: autoResizeOnKeyboard ?? this.autoResizeOnKeyboard,
      maxLineLength: maxLineLength ?? this.maxLineLength,
      showOriginalTextField:
          showOriginalTextField ?? this.showOriginalTextField,
      videoPath: videoPath ?? this.videoPath,
      resizeRatio: resizeRatio ?? this.resizeRatio,
      mobileVideoResizeRatio:
          mobileVideoResizeRatio ?? this.mobileVideoResizeRatio,
      layoutPreference: layoutPreference ?? this.layoutPreference,
      colorHistory: colorHistory ?? this.colorHistory,
    );
  }
}
