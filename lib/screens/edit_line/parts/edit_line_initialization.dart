part of '../../screen_edit_line.dart';

extension _EditLineInitialization on EditSubtitleScreenState {
  void _hydrateFromControllerState() {
    final state = _editLineState;
    final collection = state.subtitleCollection;
    if (collection == null) {
      throw StateError(
        'EditLineController completed without a subtitle collection.',
      );
    }

    _subtitle = collection;
    _isEditMode = state.isEditMode;
    isEditingEnabled = state.isEditingEnabled;
    _isTimeVisible = state.isTimeVisible;
    isRawEnabled = state.isRawEnabled;

    _startTimeError = state.startTimeError;
    _endTimeError = state.endTimeError;
    _timeOrderError = state.timeOrderError;

    _isMsoneEnabled = state.preferences.isMsoneEnabled;
    _showOriginalLine = state.showOriginalLine;
    _autoSaveWithNavigation = state.preferences.showOriginalLine
        ? state.preferences.autoSaveWithNavigation
        : true;
    _isSaveToFileEnabled = state.preferences.saveToFileEnabled;
    _autoResizeOnKeyboard = state.preferences.autoResizeOnKeyboard;
    _showOriginalTextField = state.showOriginalTextField;

    _resizeRatio = state.resizeRatio;
    _isResizeRatioLoaded = true;
    _mobileVideoResizeRatio = state.mobileVideoResizeRatio;
    _isMobileResizeRatioLoaded = true;
    _layoutPreference = state.layoutPreference;
    _colorHistory
      ..clear()
      ..addAll(state.colorHistory);

    _selectedVideoPath = state.videoPath;
    _isVideoLoaded = state.isVideoLoaded;
    _isVideoVisible = state.isVideoVisible;
    _isVideoPlaying = state.isVideoPlaying;
    _subtitles = List<Subtitle>.from(state.subtitles);

    _secondarySubtitles =
        List<SimpleSubtitleLine>.from(state.secondarySubtitles);
    _secondarySubtitlesForPlayer =
        List<Subtitle>.from(state.secondarySubtitlesForPlayer);
    _showSecondarySubtitles = state.showSecondarySubtitles;

    _isRepeatModeEnabled = state.isRepeatModeEnabled;
    _isCustomRangeMode = state.isCustomRangeMode;
    _customRangeStartIndex = state.customRangeStartIndex;
    _customRangeEndIndex = state.customRangeEndIndex;

    var line = state.subtitleLine;
    if (line == null && (state.isNewSubtitle || state.isEditMode)) {
      line = SubtitleLine()
        ..index = collection.lines.isEmpty ? 1 : collection.lines.length + 1
        ..startTime = state.startTime
        ..endTime = state.endTime
        ..original = state.originalText
        ..edited = state.editedText;
    }
    _subtitleLine = line;

    _originalController.text = line?.original ?? state.originalText;
    _editedController.text =
        (line?.edited ?? state.editedText).replaceAll('<br>', '\n');
    _startTimeController.text = line?.startTime ?? state.startTime;
    _endTimeController.text = line?.endTime ?? state.endTime;
    _currentIndexController.text =
        (line?.index ?? (collection.lines.length + 1)).toString();

    _parseTimeString(_startTimeController.text, true);
    _parseTimeString(_endTimeController.text, false);
    _applyShowOriginalLine();
    _storeInitialValues();

    _needSubtitleRegeneration = false;

    if (_isVideoLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_syncVideoPlayerWhenReady());
        _seekVideoToSubtitle();
      });
    }

    _instantCharacterCountUpdate();
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
