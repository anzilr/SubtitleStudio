part of '../../screen_edit_line.dart';

extension _EditLineInitialization on EditSubtitleScreenState {
  Future<void> _initializeAsyncData() async {
    try {
      // Run all independent async operations in parallel
      final futures = <Future>[
        _loadColorHistory(),
        _loadMsoneStatus(),
        _loadShowOriginalLine(),
        _loadAutoSaveWithNavigation(),
        _loadSaveToFileEnabled(),
        _loadAutoResizeOnKeyboard(),
        // _loadMaxLineLength() removed - maxLineLength now handled by EditLineRepository
        _loadShowOriginalTextField(),
        _loadResizeRatio(), // Load resize ratio
        _loadMobileResizeRatio(), // Load mobile resize ratio
        _loadLayoutPreference(), // Load layout preference
        if (_isEditMode) _loadSavedVideoPath(),
        _fetchSubtitleLine(widget.subtitleId, widget.index - 1),
      ];

      await Future.wait(futures);

      // Initialize character counts
      _instantCharacterCountUpdate();
    } catch (e) {
      await logError(
        'Error during initialization',
        error: e,
        context: 'EditSubtitleScreen._initializeAsync',
      );
    }
  }

  Future<void> _seekWhenVideoPlayerReady(Duration position) async {
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted || player == null) return;
    player.seekTo(position);
    if (_isRepeatModeEnabled) {
      player.pause();
    }
  }

  /// Register hotkey shortcuts using MSoneHotkeyManager
  Future<void> _registerHotkeyShortcuts() async {
    // Unregister HomeScreen shortcuts to prevent conflicts (e.g., Ctrl+E)
    await hotkey.MSoneHotkeyManager.instance.unregisterHomeScreenShortcuts();
    
    await hotkey.MSoneHotkeyManager.instance
        .registerEditSubtitleScreenShortcuts(
          onSave: _handleSaveShortcut,
          onNextLine: _handleNextLineShortcut,
          onPreviousLine: _handlePreviousLineShortcut,
          onTextFormatting: _handleTextFormattingShortcut,
          onDelete: _handleDeleteCurrentShortcut,
          onPlayPause: _handlePlayPauseShortcut,
          // New shortcuts
          onMsoneDictionary: _showMsoneDictionary,
          onOlamDictionary: _showOlamDictionary,
          onUrbanDictionary: _showUrbanDictionary,
          onColorPicker: _handleColorPickerShortcut,
          onMarkLine: _handleMarkLineShortcut,
          onMarkLineAndComment: _handleMarkLineAndCommentShortcut,
          onJumpToLine: _handleJumpToLineShortcut,
          onHelp: _handleHelpShortcut,
          onSettings: _handleSettingsShortcut,
          onPopScreen: _handlePopScreenShortcut,
          // Add video control shortcuts
          onToggleRepeat: _handleToggleRepeatShortcut,
          onToggleRepeatRange: _handleToggleRepeatRangeShortcut,
          onToggleFullscreen: _handleToggleFullscreenShortcut,
          // New split and merge shortcuts
          onSplitLine: _handleSplitLineShortcut,
          onMergeLine: _handleMergeLineShortcut,
          // Video sync shortcut
          onSyncWithVideo: () => _syncWithVideoPosition(),
          // Marked lines sheet shortcut
          onShowMarkedLines: _showMarkedLinesModal,
          // Paste original shortcut
          onPasteOriginal: _handlePasteOriginalShortcut,
        );
  }

  Future<void> _syncVideoPlayerWhenReady() async {
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted || player == null) return;
    _syncVideoPlayerState();
  }

  /// Sync the play/pause button state with the actual video player state
  void _syncVideoPlayerState() {
    if (_videoPlayerKey.currentState != null && mounted) {
      final actualPlayingState = _videoPlayerKey.currentState!.isPlaying();
      if (_isVideoPlaying != actualPlayingState) {
        _setEditLineState(() {
          _isVideoPlaying = actualPlayingState;
        });
      }
    }
  } // Performance optimization: Track if subtitles need regeneration

  bool _needSubtitleRegeneration = true;

  // Method to mark subtitles as needing regeneration
  void _markSubtitlesForRegeneration() {
    _needSubtitleRegeneration = true;
  }

  /// Toggle repeat playback mode for current subtitle
  /// Start repeat playback for current subtitle or custom range
  /// Stop repeat playback and reset custom range
  /// Update repeat timing for current subtitle without changing play/pause state
  /// Set custom repeat range
  void setCustomRepeatRange(int startIndex, int endIndex) {
    if (startIndex <= endIndex &&
        startIndex >= 0 &&
        endIndex < _subtitles.length) {
      _isCustomRangeMode = true;
      _customRangeStartIndex = startIndex;
      _customRangeEndIndex = endIndex;

      // If repeat mode is already enabled, restart with new range
      if (_isRepeatModeEnabled) {
        _startRepeatPlayback();
      }
    }
  }

  /// Clear custom repeat range and switch to normal repeat mode
  void clearCustomRepeatRange() {
    _isCustomRangeMode = false;
    _customRangeStartIndex = null;
    _customRangeEndIndex = null;

    // If repeat mode is enabled, restart with normal mode
    if (_isRepeatModeEnabled) {
      _startRepeatPlayback();
    }
  }

  // Public interface methods for video player widget

  /// Get subtitles list for external access
  List<Subtitle> get subtitles => _subtitles;

  /// Get repeat mode enabled state
  bool get isRepeatModeEnabled => _isRepeatModeEnabled;

  /// Toggle repeat mode (public method)
  void toggleRepeatMode() => _toggleRepeatMode();

  /// Start repeat playback (public method)
  void startRepeatPlayback() => _startRepeatPlayback();

  // Load video file for edit mode
  // Unload video (optimized single setState)
  Future<void> _unloadVideo() async {
    _setEditLineState(() {
      _selectedVideoPath = null;
      _isVideoVisible = false;
      _isVideoLoaded = false;
    });

    await PreferencesModel.removeVideoPath(widget.subtitleId);
    SnackbarHelper.showInfo(
      context,
      'Video unloaded',
      duration: const Duration(seconds: 2),
    );
  }


}
