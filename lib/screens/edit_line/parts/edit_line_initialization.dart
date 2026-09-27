part of '../../screen_edit_line.dart';

extension _EditLineInitialization on EditSubtitleScreenState {
  Future<void> _initializeAsyncData() async {
    try {
      // Preferences are loaded once through the injected repository instead of
      // issuing many independent global preference reads.
      final futures = <Future>[
        _loadAllUiPreferences(),
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
  }

  // Load video file for edit mode
  // Unload video (optimized single setState)
  Future<void> _unloadVideo() async {
    _setEditLineState(() {
      _selectedVideoPath = null;
      _isVideoVisible = false;
      _isVideoLoaded = false;
    });

    await _editLineController.removeVideoPath();
    SnackbarHelper.showInfo(
      context,
      'Video unloaded',
      duration: const Duration(seconds: 2),
    );
  }


}
