import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/providers/subtitle_repository_provider.dart';
import 'package:subtitle_studio/screens/edit/repositories/editor_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/video_repository.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:subtitle_studio/utils/subtitle_index.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/services/editor_secondary_subtitle_service.dart';

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

final editorPreferencesRepositoryProvider =
    Provider<EditorPreferencesRepository>((ref) {
  return EditorPreferencesRepository(ref.watch(isarProvider));
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository(
    ref.watch(editorPreferencesRepositoryProvider),
  );
});

final editControllerProvider = NotifierProvider<EditController, EditState>(
  EditController.new,
  dependencies: [editConfigurationProvider],
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
      
      _setState(state.copyWith(isLoading: true, clearErrorMessage: true));

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
      var secondarySubtitleSource = EditorSecondarySubtitleSource.none;
      final secondaryData = await _videoRepo.loadSavedSecondarySubtitle(subtitleCollectionId);
      
      if (secondaryData != null) {
        if (secondaryData.useOriginal) {
          secondarySubtitleSource = EditorSecondarySubtitleSource.originalText;
          originalSecondarySubtitles =
              EditorSecondarySubtitleService.fromOriginal(lines);
          secondarySubtitles = _subtitleRepo.generateSimpleSubtitles(originalSecondarySubtitles);
        } else if (secondaryData.subtitles != null) {
          // Use external subtitle file
          secondarySubtitleSource = EditorSecondarySubtitleSource.external;
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
        isVideoVisible: isVideoLoaded,
        isVideoLoaded: isVideoLoaded,
        secondarySubtitles: secondarySubtitles,
        originalSecondarySubtitles: originalSecondarySubtitles,
        secondarySubtitleSource: secondarySubtitleSource,
        highlightedIndex: cueNumberToListIndex(lastEditedIndex),
        floatingControlsEnabled: floatingControlsEnabled,
        isMsoneEnabled: isMsoneEnabled,
        isLayout1: layout == 'layout1',
        resizeRatio: resizeRatio,
        mobileVideoResizeRatio: mobileResizeRatio,
        isLoading: false,
        isInitialized: true,
        isResizeRatioLoaded: true,
        isMobileResizeRatioLoaded: true,
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
        errorMessage: 'Could not open the editor. Please try again.',
      ));
    }
  }

  /// Replace the in-memory subtitle list without writing to persistence.
  ///
  /// Used by legacy Editor UI paths that have already performed the database
  /// mutation themselves. This keeps Riverpod as the single render-state owner
  /// while those operations are migrated incrementally.
  void replaceSubtitleLinesLocally(List<SubtitleLine> lines) {
    final immutableLines = List<SubtitleLine>.unmodifiable(lines);
    _setPrimaryLines(immutableLines);
  }

  /// Replace one in-memory subtitle line without writing to persistence.
  void updateSubtitleLineLocally(int index, SubtitleLine line) {
    if (index < 0 || index >= state.subtitleLines.length) {
      logWarning(
        'EditController: Ignoring local line update for invalid index $index',
      );
      return;
    }

    final updatedLines = List<SubtitleLine>.from(state.subtitleLines);
    updatedLines[index] = line;
    _setPrimaryLines(updatedLines);
  }

  void _setPrimaryLines(List<SubtitleLine> lines) {
    // Keep the original-text overlay in sync even while it is hidden.
    // External tracks never derive their contents from the primary cue list.
    final refreshedOriginal = EditorSecondarySubtitleService.refreshedOriginal(
      source: state.secondarySubtitleSource,
      primaryLines: lines,
    );
    _setState(state.copyWith(
      subtitleLines: lines,
      generatedSubtitles: _subtitleRepo.generateSubtitles(lines),
      originalSecondarySubtitles: refreshedOriginal,
      secondarySubtitles: refreshedOriginal == null
          ? null
          : _subtitleRepo.generateSimpleSubtitles(refreshedOriginal),
    ));
  }

  /// Refresh subtitle lines from database
  /// 
  /// Used after operations that modify the database directly
  /// (e.g., checkpoint restore, batch operations)
  Future<void> refreshSubtitleLines() async {
    try {
      logInfo('EditController: Refreshing subtitle lines');

      final lines = await _subtitleRepo.fetchLines(subtitleCollectionId);
      _setPrimaryLines(lines);

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

  Future<List<SubtitleLine>> loadSubtitleLines() {
    return _subtitleRepo.fetchLines(subtitleCollectionId);
  }

  Future<SubtitleCollection?> loadSubtitleCollection() {
    return _subtitleRepo.fetchSubtitleCollection(subtitleCollectionId);
  }

  Future<Session?> loadSession([int? targetSessionId]) {
    return _subtitleRepo.fetchSession(targetSessionId ?? sessionId);
  }

  Future<List<SubtitleLine>> loadMarkedLines() {
    return _subtitleRepo.getMarkedLines(subtitleCollectionId);
  }

  Future<List<SubtitleLine>> loadLinesWithComments() {
    return _subtitleRepo.getLinesWithComments(subtitleCollectionId);
  }

  Future<bool> addSubtitleLine(SubtitleLine line, int insertIndex) async {
    final success = await _subtitleRepo.addLineWithHistory(
      collectionId: subtitleCollectionId,
      line: line,
      insertIndex: insertIndex,
      sessionId: sessionId,
    );
    if (success) {
      await refreshSubtitleLines();
    }
    return success;
  }

  Future<bool> addSubtitleLineWithHistory(
    SubtitleLine line,
    int insertIndex,
  ) async {
    final success = await _subtitleRepo.addLineWithHistory(
      collectionId: subtitleCollectionId,
      line: line,
      insertIndex: insertIndex,
      sessionId: sessionId,
    );
    if (success) {
      await refreshSubtitleLines();
    }
    return success;
  }

  Future<bool> saveLineChanges(
    SubtitleLine updatedLine, {
    SubtitleLine? beforeLine,
  }) async {
    final saved = await _subtitleRepo.saveLineChanges(
      subtitleCollectionId,
      updatedLine,
      sessionId: sessionId,
      beforeLine: beforeLine,
    );

    if (saved) {
      await refreshSubtitleLines();
    }
    return saved;
  }

  Future<bool> saveSubtitleCollection(SubtitleCollection collection) {
    return _subtitleRepo.updateCollection(collection);
  }

  Future<bool> updateOriginalFileUri(String originalFileUri) {
    return _subtitleRepo.updateOriginalFileUri(
      collectionId: subtitleCollectionId,
      originalFileUri: originalFileUri,
    );
  }

  Future<bool> updateLastEditedIndex(int index) {
    return _subtitleRepo.updateLastEditedIndex(sessionId, index);
  }

  Future<int?> getLastEditedIndex() {
    return _subtitleRepo.getLastEditedIndex(sessionId);
  }

  Future<bool> getSessionEditMode() {
    return _subtitleRepo.getSessionEditMode(sessionId);
  }

  Future<void> clearWaveformCache() {
    return ref
        .read(editorPreferencesRepositoryProvider)
        .clearWaveformCache(subtitleCollectionId);
  }

  /// Set a subtitle line's mark state explicitly.
  Future<bool> setLineMarked(int index, bool marked) async {
    if (index < 0 || index >= state.subtitleLines.length) return false;

    try {
      final success = await _subtitleRepo.markLine(
        subtitleCollectionId,
        index,
        marked,
        sessionId: sessionId,
      );
      if (!success) return false;

      final line = state.subtitleLines[index];
      final updatedLines = List<SubtitleLine>.from(state.subtitleLines);
      updatedLines[index] = SubtitleLine()
        ..index = line.index
        ..startTime = line.startTime
        ..endTime = line.endTime
        ..original = line.original
        ..edited = line.edited
        ..marked = marked
        ..comment = line.comment
        ..resolved = line.resolved;

      _setState(
        state.copyWith(
          subtitleLines: updatedLines,
          generatedSubtitles: _subtitleRepo.generateSubtitles(updatedLines),
        ),
      );
      return true;
    } catch (e, stackTrace) {
      logError(
        'EditController: Error setting line mark state',
        context: 'setLineMarked',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Toggle a subtitle line's marked status.
  Future<bool> markLine(int index) async {
    if (index < 0 || index >= state.subtitleLines.length) return false;
    return setLineMarked(index, !state.subtitleLines[index].marked);
  }

  /// Update comment for a subtitle line.
  Future<bool> updateComment(int index, String? comment) async {
    if (index < 0 || index >= state.subtitleLines.length) return false;

    try {
      final success = await _subtitleRepo.updateComment(
        subtitleCollectionId,
        index,
        comment,
        sessionId: sessionId,
      );
      if (!success) return false;

      final line = state.subtitleLines[index];
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

      _setState(
        state.copyWith(
          subtitleLines: updatedLines,
          generatedSubtitles: _subtitleRepo.generateSubtitles(updatedLines),
        ),
      );
      return true;
    } catch (e, stackTrace) {
      logError(
        'EditController: Error updating comment',
        context: 'updateComment',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Unmark a line and clear its associated comment/resolved state.
  Future<bool> unmarkLine(int index) async {
    if (index < 0 || index >= state.subtitleLines.length) return false;

    try {
      final success = await _subtitleRepo.unmarkLine(
        subtitleCollectionId,
        index,
        sessionId: sessionId,
      );
      if (!success) return false;

      final line = state.subtitleLines[index];
      final updatedLines = List<SubtitleLine>.from(state.subtitleLines);
      updatedLines[index] = SubtitleLine()
        ..index = line.index
        ..startTime = line.startTime
        ..endTime = line.endTime
        ..original = line.original
        ..edited = line.edited
        ..marked = false
        ..comment = null
        ..resolved = false;

      _setState(
        state.copyWith(
          subtitleLines: updatedLines,
          generatedSubtitles: _subtitleRepo.generateSubtitles(updatedLines),
        ),
      );
      return true;
    } catch (e, stackTrace) {
      logError(
        'EditController: Error unmarking subtitle line',
        context: 'unmarkLine',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Update a subtitle comment's resolved status.
  Future<bool> updateResolved(int index, bool resolved) async {
    if (index < 0 || index >= state.subtitleLines.length) return false;

    try {
      final success = await _subtitleRepo.updateResolved(
        subtitleCollectionId,
        index,
        resolved,
        sessionId: sessionId,
      );
      if (!success) return false;

      final line = state.subtitleLines[index];
      final updatedLines = List<SubtitleLine>.from(state.subtitleLines);
      updatedLines[index] = SubtitleLine()
        ..index = line.index
        ..startTime = line.startTime
        ..endTime = line.endTime
        ..original = line.original
        ..edited = line.edited
        ..marked = line.marked
        ..comment = line.comment
        ..resolved = resolved;

      _setState(
        state.copyWith(
          subtitleLines: updatedLines,
          generatedSubtitles: _subtitleRepo.generateSubtitles(updatedLines),
        ),
      );
      return true;
    } catch (e, stackTrace) {
      logError(
        'EditController: Error updating resolved state',
        context: 'updateResolved',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Delete a single subtitle line with checkpoint
  Future<void> deleteLine(int index) async {
    try {
      logInfo('EditController: Deleting line at index $index');

      final deleted = await _subtitleRepo.deleteLineWithHistory(
        collectionId: subtitleCollectionId,
        index: index,
        sessionId: sessionId,
      );
      if (!deleted) {
        throw StateError('Atomic subtitle delete failed.');
      }

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
        errorMessage: 'Could not delete the subtitle line. Please try again.',
      ));
    }
  }

  /// Delete all currently selected lines in one repository transaction.
  ///
  /// Returns the repository success/failure counts so the UI can report the
  /// actual result without issuing one delete/refresh cycle per selected cue.
  Future<Map<String, int>> deleteSelectedLines() async {
    final selectedCount = state.selectedIndices.length;

    try {
      logInfo(
        'EditController: Deleting $selectedCount selected lines',
      );

      if (selectedCount == 0) {
        logWarning('EditController: No lines selected for deletion');
        return const {'success': 0, 'failed': 0};
      }

      final indices = state.selectedIndices.toList(growable: false);
      final result = await _subtitleRepo.batchDeleteLines(
        subtitleCollectionId,
        indices,
        sessionId: sessionId,
      );

      _setState(
        state.copyWith(
          selectedIndices: {},
          isSelectionMode: false,
          isRangeSelectionActive: false,
        ),
      );

      await refreshSubtitleLines();

      logInfo(
        'EditController: Batch delete completed - '
        'success: ${result['success']}, failed: ${result['failed']}',
      );
      return result;
    } catch (e, stackTrace) {
      logError(
        'EditController: Error deleting selected lines',
        context: 'deleteSelectedLines',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(
        state.copyWith(
          errorMessage:
              'Could not delete the selected subtitles. Please try again.',
        ),
      );

      return {
        'success': 0,
        'failed': selectedCount,
      };
    }
  }

  /// Toggle selection for a subtitle line
  void toggleSelection(int index) {
    final newState = state.toggleSelection(index);
    _setState(newState);

  }

  /// Clear all selections
  void clearSelection() {
    _setState(state.clearSelection());
  }

  /// Enter or exit selection mode without changing selection content.
  void setSelectionMode(bool enabled) {
    if (!enabled) {
      clearSelection();
      return;
    }

    if (!state.isSelectionMode) {
      _setState(state.copyWith(isSelectionMode: true));
    }
  }

  void toggleRangeSelectionMode() {
    final enabled = !state.isRangeSelectionActive;
    _setState(
      state.copyWith(
        isRangeSelectionActive: enabled,
        clearRangeStartIndex: true,
      ),
    );
  }

  void setRangeSelectionStart(int index) {
    if (index < 0 || index >= state.subtitleLines.length) {
      logWarning(
        'EditController: Ignoring invalid range start index $index',
      );
      return;
    }

    _setState(
      state.copyWith(
        isRangeSelectionActive: true,
        rangeStartIndex: index,
      ),
    );
  }

  void cancelRangeSelection() {
    if (!state.isRangeSelectionActive && state.rangeStartIndex == null) {
      return;
    }

    _setState(
      state.copyWith(
        isRangeSelectionActive: false,
        clearRangeStartIndex: true,
      ),
    );
  }

  /// Replace the selected set with a contiguous zero-based range.
  void selectRange(int startIndex, int endIndex) {
    if (startIndex < 0 ||
        endIndex < startIndex ||
        endIndex >= state.subtitleLines.length) {
      logWarning(
        'EditController: Ignoring invalid selection range '
        '$startIndex..$endIndex',
      );
      return;
    }

    final selected = <int>{
      for (int index = startIndex; index <= endIndex; index++) index,
    };

    _setState(
      state.copyWith(
        selectedIndices: selected,
        isSelectionMode: selected.isNotEmpty,
        isRangeSelectionActive: false,
        clearRangeStartIndex: true,
      ),
    );
  }

  /// Select all subtitle lines
  void selectAll() {
    final allIndices = List.generate(state.subtitleLines.length, (i) => i).toSet();
    
    _setState(state.copyWith(
      selectedIndices: allIndices,
      isSelectionMode: true,
    ));
  }

  /// Navigate to a specific index (for video sync and goto)
  void navigateToIndex(int index) {
    if (index < 0 || index >= state.subtitleLines.length) {
      logWarning('EditController: Invalid navigation index: $index');
      return;
    }

    _setState(state.copyWith(highlightedIndex: index));
  }

  /// Toggle card expansion state
  void toggleCardExpansion(int index) {
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
        isVideoVisible: true,
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
        errorMessage: 'Could not load the selected video. Please try another file.',
      ));
    }
  }

  /// Unload video and clear saved path
  Future<void> unloadVideo() async {
    try {
      logInfo('EditController: Unloading video');

      await _videoRepo.removeVideoPath(subtitleCollectionId);

      _setState(state.copyWith(
        clearSelectedVideoPath: true,
        isVideoVisible: false,
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

  /// Toggle whether the loaded video pane is visible.
  void toggleVideoVisibility() {
    if (!state.isVideoLoaded) return;
    _setState(
      state.copyWith(
        isVideoVisible: !state.isVideoVisible,
      ),
    );
  }

  /// Toggle secondary subtitles visibility.
  void toggleSecondarySubtitles() {
    setSecondarySubtitlesVisible(!state.showSecondarySubtitles);
  }

  /// Set secondary subtitle visibility explicitly.
  void setSecondarySubtitlesVisible(bool visible) {
    if (state.showSecondarySubtitles == visible) return;
    _setState(state.copyWith(showSecondarySubtitles: visible));
  }

  /// Adopt already-parsed secondary subtitle data without persisting it.
  ///
  /// Legacy sheets still own the path/original preference write. This keeps
  /// Riverpod as the sole in-memory owner until those persistence paths are
  /// migrated behind repositories.
  void setSecondarySubtitlesLocally(
    List<SimpleSubtitleLine> originalSubtitles, {
    bool show = true,
    bool fromOriginal = false,
  }) {
    final immutableOriginals =
        List<SimpleSubtitleLine>.unmodifiable(originalSubtitles);
    final generated =
        _subtitleRepo.generateSimpleSubtitles(immutableOriginals);

    _setState(
      state.copyWith(
        originalSecondarySubtitles: immutableOriginals,
        secondarySubtitles: generated,
        showSecondarySubtitles: show,
        secondarySubtitleSource: fromOriginal
            ? EditorSecondarySubtitleSource.originalText
            : EditorSecondarySubtitleSource.external,
      ),
    );
  }

  /// Clear in-memory secondary subtitle state.
  void clearSecondarySubtitlesLocally() {
    _setState(
      state.copyWith(
        originalSecondarySubtitles: const [],
        secondarySubtitles: const [],
        showSecondarySubtitles: false,
        secondarySubtitleSource: EditorSecondarySubtitleSource.none,
      ),
    );
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
        secondarySubtitleSource: EditorSecondarySubtitleSource.external,
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
        errorMessage: 'Could not load the secondary subtitle file.',
      ));
    }
  }

  /// Use original text as secondary subtitle
  Future<void> useOriginalAsSecondary() async {
    try {
      logInfo('EditController: Using original text as secondary subtitle');

      await _videoRepo.setUseOriginalAsSecondary(subtitleCollectionId, true);

      final originalSecondarySubtitles =
          EditorSecondarySubtitleService.fromOriginal(state.subtitleLines);

      final secondarySubtitles = _subtitleRepo.generateSimpleSubtitles(
        originalSecondarySubtitles,
      );

      _setState(state.copyWith(
        originalSecondarySubtitles: originalSecondarySubtitles,
        secondarySubtitles: secondarySubtitles,
        showSecondarySubtitles: true,
        secondarySubtitleSource: EditorSecondarySubtitleSource.originalText,
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
        errorMessage: 'Could not use the original subtitle as secondary.',
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
        secondarySubtitleSource: EditorSecondarySubtitleSource.none,
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
        sessionId: sessionId,
      );

      // Refresh the canonical subtitle state but keep the current view.
      // The UI decides whether this save is a normal Save action or a
      // Save-and-leave transition.
      await refreshSubtitleLines();

      _setState(
        state.copyWith(
          sourceViewEntries: _subtitleRepo.convertToSourceViewEntries(
            state.subtitleLines,
          ),
        ),
      );

      logInfo('EditController: Source view synced to database');
    } catch (e, stackTrace) {
      logError(
        'EditController: Error syncing source view',
        context: 'syncSourceViewToDatabase',
        error: e,
        stackTrace: stackTrace,
      );

      _setState(state.copyWith(
        errorMessage: 'Could not save Source View changes. Please try again.',
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
    await _videoRepo.saveEditScreenResizeRatio(ratio);
    _setState(state.copyWith(resizeRatio: ratio));
  }

  /// Update mobile video resize ratio
  Future<void> updateMobileResizeRatio(double ratio) async {
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
    _setState(state.copyWith(clearErrorMessage: true));
  }
}
