import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/screen_repository.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';

/// Inputs that scope one Editor controller instance.
class EditConfiguration {
  final int subtitleCollectionId;
  final int sessionId;

  const EditConfiguration({
    required this.subtitleCollectionId,
    required this.sessionId,
  });
}

final editConfigurationProvider = Provider<EditConfiguration>((ref) {
  throw StateError(
    'editConfigurationProvider must be overridden for each Editor screen.',
  );
});

final subtitleRepositoryProvider = Provider<SubtitleRepository>((ref) {
  return SubtitleRepository();
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository();
});

final editControllerProvider = NotifierProvider<EditController, EditState>(
  EditController.new,
);

/// Riverpod controller for the main subtitle Editor.
///
/// This is intentionally a behavior-preserving migration of the former
/// EditCubit. Query/performance fixes are kept in separate commits so failures
/// can be attributed to one change at a time.
class EditController extends Notifier<EditState> {
  SubtitleRepository get _subtitleRepo => ref.read(subtitleRepositoryProvider);
  VideoRepository get _videoRepo => ref.read(videoRepositoryProvider);

  EditConfiguration get _configuration => ref.read(editConfigurationProvider);
  int get subtitleCollectionId => _configuration.subtitleCollectionId;
  int get sessionId => _configuration.sessionId;

  bool _disposed = false;

  @override
  EditState build() {
    final config = ref.watch(editConfigurationProvider);
    ref.onDispose(() {
      _disposed = true;
    });

    logInfo(
      'EditController: Initialized for collection '
      '${config.subtitleCollectionId}, session ${config.sessionId}',
    );

    return EditState.initial();
  }

  void _setState(EditState nextState) {
    if (!_disposed) {
      state = nextState;
    }
  }

  /// Initialize the edit screen
  /// 
  /// Loads:
  /// 1. Subtitle collection metadata
  /// 2. Subtitle lines
  /// 3. Video path (if saved)
  /// 4. Secondary subtitles (if configured)
  /// 5. Preferences (floating controls, MSone, layout, resize ratio)
  Future<void> initialize({int? lastEditedIndex}) async {
    try {
      logInfo('EditController: Starting initialization');
      
      _setState(state.copyWith(isLoading: true, errorMessage: null));

      // Load subtitle collection
      final collection = await _subtitleRepo.fetchSubtitleCollection(subtitleCollectionId);
      if (collection == null) {
        throw Exception('Subtitle collection not found: $subtitleCollectionId');
      }

      // Load subtitle lines
      final lines = await _subtitleRepo.fetchLines(subtitleCollectionId);
      
      // Generate subtitles for video player
      final generatedSubtitles = _subtitleRepo.generateSubtitles(lines);

      // Load video path
      final videoPath = await _videoRepo.getSavedVideoPath(subtitleCollectionId);
      final isVideoLoaded = videoPath != null;

      // Load secondary subtitles if configured
      List<Subtitle> secondarySubtitles = [];
      List<SimpleSubtitleLine> originalSecondarySubtitles = [];
      final secondaryData = await _videoRepo.loadSavedSecondarySubtitle(subtitleCollectionId);
      
      if (secondaryData != null) {
        if (secondaryData.useOriginal) {
          // Use original text as secondary
          originalSecondarySubtitles = lines.map((line) {
            return SimpleSubtitleLine(
              index: line.index,
              startTime: line.startTime,
              endTime: line.endTime,
              text: line.original,
            );
          }).toList();
          secondarySubtitles = _subtitleRepo.generateSimpleSubtitles(originalSecondarySubtitles);
        } else if (secondaryData.subtitles != null) {
          // Use external subtitle file
          originalSecondarySubtitles = secondaryData.subtitles!;
          secondarySubtitles = _subtitleRepo.generateSimpleSubtitles(originalSecondarySubtitles);
        }
      }

      // Load preferences
      final floatingControlsEnabled = await _videoRepo.getFloatingControlsEnabled();
      final isMsoneEnabled = await _videoRepo.getMsoneEnabled();
      final layout = await _videoRepo.getLayoutPreference();
      final resizeRatio = await _videoRepo.getEditScreenResizeRatio();
      final mobileResizeRatio = await _videoRepo.getMobileVideoResizeRatio();

      // Create initial checkpoint (non-critical, continue if it fails)
      try {
        await _subtitleRepo.createInitialSnapshot(sessionId, subtitleCollectionId);
      } catch (e) {
        logWarning('Could not create initial checkpoint: $e');
        // Continue without checkpoint - this is not critical for basic functionality
      }

      logInfo('EditController: Loaded ${lines.length} subtitle lines');

      _setState(EditState(
        subtitleCollection: collection,
        subtitleLines: lines,
        generatedSubtitles: generatedSubtitles,
        selectedVideoPath: videoPath,
        isVideoLoaded: isVideoLoaded,
        secondarySubtitles: secondarySubtitles,
        originalSecondarySubtitles: originalSecondarySubtitles,
        highlightedIndex: lastEditedIndex,
        floatingControlsEnabled: floatingControlsEnabled,
        isMsoneEnabled: isMsoneEnabled,
        isLayout1: layout == 'layout1',
        resizeRatio: resizeRatio,
        mobileVideoResizeRatio: mobileResizeRatio,
        isLoading: false,
      ));

      logInfo('EditController: Initialization complete');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error during initialization',
        context: 'initialize',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize: $e',
      ));
    }
  }

  /// Refresh subtitle lines from database
  /// 
  /// Used after operations that modify the database directly
  /// (e.g., checkpoint restore, batch operations)
  Future<void> refreshSubtitleLines() async {
    try {
      logInfo('EditController: Refreshing subtitle lines');

      final lines = await _subtitleRepo.fetchLines(subtitleCollectionId);
      final generatedSubtitles = _subtitleRepo.generateSubtitles(lines);

      // Update secondary subtitles if using original text
      List<Subtitle> secondarySubtitles = state.secondarySubtitles;
      List<SimpleSubtitleLine> originalSecondarySubtitles = state.originalSecondarySubtitles;
      
      if (state.showSecondarySubtitles && originalSecondarySubtitles.isNotEmpty) {
        // Check if using original text (by comparing first line)
        final isUsingOriginal = lines.isNotEmpty && 
            originalSecondarySubtitles.isNotEmpty &&
            originalSecondarySubtitles.first.text == lines.first.original;
        
        if (isUsingOriginal) {
          // Regenerate secondary from updated original text
          originalSecondarySubtitles = lines.map((line) {
            return SimpleSubtitleLine(
              index: line.index,
              startTime: line.startTime,
              endTime: line.endTime,
              text: line.original,
            );
          }).toList();
          secondarySubtitles = _subtitleRepo.generateSimpleSubtitles(originalSecondarySubtitles);
        }
      }

      _setState(state.copyWith(
        subtitleLines: lines,
        generatedSubtitles: generatedSubtitles,
        secondarySubtitles: secondarySubtitles,
        originalSecondarySubtitles: originalSecondarySubtitles,
      ));

      logInfo('EditController: Refreshed ${lines.length} subtitle lines');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error refreshing subtitle lines',
        context: 'refreshSubtitleLines',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Mark a subtitle line (toggle marked status)
  Future<void> markLine(int index) async {
    try {
      logInfo('EditController: Marking line at index $index');

      final line = state.subtitleLines[index];
      final newMarkedStatus = !line.marked;

      await _subtitleRepo.markLine(subtitleCollectionId, index, newMarkedStatus);

      // Update local state
      final updatedLines = List<SubtitleLine>.from(state.subtitleLines);
      updatedLines[index] = SubtitleLine()
        ..index = line.index
        ..startTime = line.startTime
        ..endTime = line.endTime
        ..original = line.original
        ..edited = line.edited
        ..marked = newMarkedStatus
        ..comment = line.comment
        ..resolved = line.resolved;

      _setState(state.copyWith(subtitleLines: updatedLines));

      logInfo('EditController: Line marked status: $newMarkedStatus');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error marking line',
        context: 'markLine',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update comment for a subtitle line
  Future<void> updateComment(int index, String? comment) async {
    try {
      logInfo('EditController: Updating comment for line at index $index');

      final line = state.subtitleLines[index];

      await _subtitleRepo.updateComment(subtitleCollectionId, index, comment);

      // Update local state
      final updatedLines = List<SubtitleLine>.from(state.subtitleLines);
      updatedLines[index] = SubtitleLine()
        ..index = line.index
        ..startTime = line.startTime
        ..endTime = line.endTime
        ..original = line.original
        ..edited = line.edited
        ..marked = line.marked
        ..comment = comment
        ..resolved = line.resolved;

      _setState(state.copyWith(subtitleLines: updatedLines));

      logInfo('EditController: Comment updated');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error updating comment',
        context: 'updateComment',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete a single subtitle line with checkpoint
  Future<void> deleteLine(int index) async {
    try {
      logInfo('EditController: Deleting line at index $index');

      await _subtitleRepo.deleteLine(subtitleCollectionId, index);

      // Refresh to get updated lines
      await refreshSubtitleLines();

      logInfo('EditController: Line deleted');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error deleting line',
        context: 'deleteLine',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        errorMessage: 'Failed to delete line: $e',
      ));
    }
  }

  /// Delete multiple selected lines with checkpoint
  Future<void> deleteSelectedLines() async {
    try {
      logInfo('EditController: Deleting ${state.selectedIndices.length} selected lines');

      if (state.selectedIndices.isEmpty) {
        logWarning('EditController: No lines selected for deletion');
        return;
      }

      // Convert selected indices to list
      final indices = state.selectedIndices.toList();

      await _subtitleRepo.batchDeleteLines(subtitleCollectionId, indices);

      // Clear selection and refresh
      _setState(state.copyWith(
        selectedIndices: {},
        isSelectionMode: false,
        isRangeSelectionActive: false,
      ));

      await refreshSubtitleLines();

      logInfo('EditController: Selected lines deleted');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error deleting selected lines',
        context: 'deleteSelectedLines',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        errorMessage: 'Failed to delete selected lines: $e',
      ));
    }
  }

  /// Toggle selection for a subtitle line
  void toggleSelection(int index) {
    logInfo('EditController: Toggling selection for index $index');

    final newState = state.toggleSelection(index);
    _setState(newState);

    logInfo('EditController: Selection mode: ${newState.isSelectionMode}, selected: ${newState.selectedIndices.length}');
  }

  /// Clear all selections
  void clearSelection() {
    logInfo('EditController: Clearing all selections');

    _setState(state.clearSelection());
  }

  /// Select all subtitle lines
  void selectAll() {
    logInfo('EditController: Selecting all ${state.subtitleLines.length} lines');

    final allIndices = List.generate(state.subtitleLines.length, (i) => i).toSet();
    
    _setState(state.copyWith(
      selectedIndices: allIndices,
      isSelectionMode: true,
    ));
  }

  /// Navigate to a specific index (for video sync and goto)
  void navigateToIndex(int index) {
    logInfo('EditController: Navigating to index $index');

    if (index < 0 || index >= state.subtitleLines.length) {
      logWarning('EditController: Invalid navigation index: $index');
      return;
    }

    _setState(state.copyWith(highlightedIndex: index));
  }

  /// Toggle card expansion state
  void toggleCardExpansion(int index) {
    logInfo('EditController: Toggling card expansion for index $index');

    final newState = state.toggleCardExpansion(index);
    _setState(newState);
  }

  /// Load video from path
  Future<void> loadVideo(String videoPath, {Duration? lastPosition}) async {
    try {
      logInfo('EditController: Loading video from: $videoPath');

      // Save video path
      await _videoRepo.saveVideoPath(subtitleCollectionId, videoPath);

      _setState(state.copyWith(
        selectedVideoPath: videoPath,
        isVideoLoaded: true,
        lastVideoPosition: lastPosition,
      ));

      logInfo('EditController: Video loaded successfully');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error loading video',
        context: 'loadVideo',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        errorMessage: 'Failed to load video: $e',
      ));
    }
  }

  /// Unload video and clear saved path
  Future<void> unloadVideo() async {
    try {
      logInfo('EditController: Unloading video');

      await _videoRepo.removeVideoPath(subtitleCollectionId);

      _setState(state.copyWith(
        selectedVideoPath: null,
        isVideoLoaded: false,
        lastVideoPosition: Duration.zero,
      ));

      logInfo('EditController: Video unloaded successfully');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error unloading video',
        context: 'unloadVideo',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update video position (for restoration)
  void updateVideoPosition(Duration position) {
    _setState(state.copyWith(lastVideoPosition: position));
  }

  /// Toggle secondary subtitles visibility
  void toggleSecondarySubtitles() {
    logInfo('EditController: Toggling secondary subtitles');

    final newShowState = !state.showSecondarySubtitles;
    _setState(state.copyWith(showSecondarySubtitles: newShowState));

    logInfo('EditController: Secondary subtitles visible: $newShowState');
  }

  /// Load secondary subtitle from external file
  Future<void> loadSecondarySubtitleFromFile(String path) async {
    try {
      logInfo('EditController: Loading secondary subtitle from file: $path');

      final secondaryData = await _videoRepo.saveAndLoadSecondarySubtitle(
        subtitleCollectionId,
        path,
      );

      final secondarySubtitles = _subtitleRepo.generateSimpleSubtitles(
        secondaryData.subtitles!,
      );

      _setState(state.copyWith(
        originalSecondarySubtitles: secondaryData.subtitles,
        secondarySubtitles: secondarySubtitles,
        showSecondarySubtitles: true,
      ));

      logInfo('EditController: Secondary subtitle loaded from file');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error loading secondary subtitle',
        context: 'loadSecondarySubtitleFromFile',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        errorMessage: 'Failed to load secondary subtitle: $e',
      ));
    }
  }

  /// Use original text as secondary subtitle
  Future<void> useOriginalAsSecondary() async {
    try {
      logInfo('EditController: Using original text as secondary subtitle');

      await _videoRepo.setUseOriginalAsSecondary(subtitleCollectionId, true);

      final originalSecondarySubtitles = state.subtitleLines.map((line) {
        return SimpleSubtitleLine(
          index: line.index,
          startTime: line.startTime,
          endTime: line.endTime,
          text: line.original,
        );
      }).toList();

      final secondarySubtitles = _subtitleRepo.generateSimpleSubtitles(
        originalSecondarySubtitles,
      );

      _setState(state.copyWith(
        originalSecondarySubtitles: originalSecondarySubtitles,
        secondarySubtitles: secondarySubtitles,
        showSecondarySubtitles: true,
      ));

      logInfo('EditController: Original text set as secondary subtitle');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error setting original as secondary',
        context: 'useOriginalAsSecondary',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        errorMessage: 'Failed to use original as secondary: $e',
      ));
    }
  }

  /// Clear secondary subtitles
  Future<void> clearSecondarySubtitles() async {
    try {
      logInfo('EditController: Clearing secondary subtitles');

      await _videoRepo.clearSecondarySubtitle(subtitleCollectionId);

      _setState(state.copyWith(
        originalSecondarySubtitles: [],
        secondarySubtitles: [],
        showSecondarySubtitles: false,
      ));

      logInfo('EditController: Secondary subtitles cleared');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error clearing secondary subtitles',
        context: 'clearSecondarySubtitles',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Switch to source view mode
  void switchToSourceView() {
    logInfo('EditController: Switching to source view mode');

    if (state.isSourceView) {
      logWarning('EditController: Already in source view mode');
      return;
    }

    // Convert subtitle lines to source view entries
    final sourceViewEntries = _subtitleRepo.convertToSourceViewEntries(
      state.subtitleLines,
    );

    _setState(state.copyWith(
      isSourceView: true,
      sourceViewEntries: sourceViewEntries,
    ));

    logInfo('EditController: Switched to source view mode');
  }

  /// Switch back to cards view mode
  void switchToCardsView() {
    logInfo('EditController: Switching to cards view mode');

    if (!state.isSourceView) {
      logWarning('EditController: Already in cards view mode');
      return;
    }

    _setState(state.copyWith(
      isSourceView: false,
      sourceViewEntries: [],
    ));

    logInfo('EditController: Switched to cards view mode');
  }

  /// Sync source view changes back to database
  Future<void> syncSourceViewToDatabase(List<SubtitleEntry> entries) async {
    try {
      logInfo('EditController: Syncing source view changes to database');

      await _subtitleRepo.syncSourceViewToDatabase(
        subtitleCollectionId,
        entries,
      );

      // Refresh subtitle lines and return to cards view
      await refreshSubtitleLines();
      
      _setState(state.copyWith(
        isSourceView: false,
        sourceViewEntries: [],
      ));

      logInfo('EditController: Source view synced to database');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error syncing source view',
        context: 'syncSourceViewToDatabase',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        errorMessage: 'Failed to sync source view: $e',
      ));
    }
  }

  /// Update floating controls preference
  Future<void> updateFloatingControls(bool enabled) async {
    logInfo('EditController: Updating floating controls: $enabled');

    await _videoRepo.saveFloatingControlsEnabled(enabled);
    _setState(state.copyWith(floatingControlsEnabled: enabled));
  }

  /// Update MSone features preference
  Future<void> updateMsoneFeatures(bool enabled) async {
    logInfo('EditController: Updating MSone features: $enabled');

    await _videoRepo.saveMsoneEnabled(enabled);
    _setState(state.copyWith(isMsoneEnabled: enabled));
  }

  /// Update layout preference
  Future<void> updateLayout(bool isLayout1) async {
    logInfo('EditController: Updating layout: ${isLayout1 ? 'layout1' : 'layout2'}');

    await _videoRepo.saveLayoutPreference(isLayout1 ? 'layout1' : 'layout2');
    _setState(state.copyWith(isLayout1: isLayout1));
  }

  /// Update resize ratio
  Future<void> updateResizeRatio(double ratio) async {
    logInfo('EditController: Updating resize ratio: $ratio');

    await _videoRepo.saveEditScreenResizeRatio(ratio);
    _setState(state.copyWith(resizeRatio: ratio));
  }

  /// Update mobile video resize ratio
  Future<void> updateMobileResizeRatio(double ratio) async {
    logInfo('EditController: Updating mobile resize ratio: $ratio');

    await _videoRepo.saveMobileVideoResizeRatio(ratio);
    _setState(state.copyWith(mobileVideoResizeRatio: ratio));
  }

  /// Update last edited session timestamp
  Future<void> updateLastEditedSession() async {
    try {
      await _subtitleRepo.updateLastEditedSession(sessionId);
      logInfo('EditController: Updated last edited session timestamp');
    } catch (e) {
      logWarning('EditController: Failed to update last edited session: $e');
    }
  }

  /// Reload preferences from database
  /// 
  /// Call this method when preferences are changed externally (e.g., from settings sheet)
  /// to sync the cubit state with the latest database values
  Future<void> reloadPreferences() async {
    try {
      logInfo('EditController: Reloading preferences from database');
      
      final floatingControlsEnabled = await _videoRepo.getFloatingControlsEnabled();
      final isMsoneEnabled = await _videoRepo.getMsoneEnabled();
      final layout = await _videoRepo.getLayoutPreference();
      final resizeRatio = await _videoRepo.getEditScreenResizeRatio();
      
      _setState(state.copyWith(
        floatingControlsEnabled: floatingControlsEnabled,
        isMsoneEnabled: isMsoneEnabled,
        isLayout1: layout == 'layout1',
        resizeRatio: resizeRatio,
      ));
      
      logInfo('EditController: Preferences reloaded successfully');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error reloading preferences',
        context: 'reloadPreferences',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clear error message
  void clearError() {
    _setState(state.copyWith(errorMessage: null));
  }
}
