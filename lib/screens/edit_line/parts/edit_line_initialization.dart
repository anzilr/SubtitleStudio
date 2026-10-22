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

  Future<void> _seekWhenVideoPlayerReady(
    Duration position, {
    required int seekToken,
    required String videoPath,
  }) async {
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted ||
        !_isVideoLoaded ||
        _selectedVideoPath != videoPath ||
        !_mediaRequests.isCurrentSeek(seekToken) ||
        player == null ||
        !identical(player, _videoPlayerKey.currentState)) return;
    player.seekTo(position);
    if (_isRepeatModeEnabled) player.pause();
  }

  /// Stale shortcut callbacks must never touch a disposed Edit Line route.
  void Function() _guardShortcut(void Function() callback) => () {
    if (mounted && _shortcutLifecycle.isActive) callback();
  };

  Future<void> _registerHotkeyShortcuts() async {
    final manager = hotkey.MSoneHotkeyManager.instance;
    try {
      await _shortcutLifecycle.activate(
        prepare: manager.unregisterHomeScreenShortcuts,
        register: () => manager.registerEditSubtitleScreenShortcuts(
          onSave: _guardShortcut(_handleSaveShortcut),
          onNextLine: _guardShortcut(_handleNextLineShortcut),
          onPreviousLine: _guardShortcut(_handlePreviousLineShortcut),
          onTextFormatting: (format) {
            if (mounted && _shortcutLifecycle.isActive) {
              _handleTextFormattingShortcut(format);
            }
          },
          onDelete: _guardShortcut(_handleDeleteCurrentShortcut),
          onPlayPause: _guardShortcut(_handlePlayPauseShortcut),
          onMsoneDictionary: _guardShortcut(_showMsoneDictionary),
          onOlamDictionary: _guardShortcut(_showOlamDictionary),
          onUrbanDictionary: _guardShortcut(_showUrbanDictionary),
          onColorPicker: _guardShortcut(_handleColorPickerShortcut),
          onMarkLine: _guardShortcut(_handleMarkLineShortcut),
          onMarkLineAndComment: _guardShortcut(_handleMarkLineAndCommentShortcut),
          onJumpToLine: _guardShortcut(_handleJumpToLineShortcut),
          onHelp: _guardShortcut(_handleHelpShortcut),
          onSettings: _guardShortcut(_handleSettingsShortcut),
          onPopScreen: _guardShortcut(_handlePopScreenShortcut),
          onToggleRepeat: _guardShortcut(_handleToggleRepeatShortcut),
          onToggleRepeatRange: _guardShortcut(_handleToggleRepeatRangeShortcut),
          onToggleFullscreen: _guardShortcut(_handleToggleFullscreenShortcut),
          onSplitLine: _guardShortcut(_handleSplitLineShortcut),
          onMergeLine: _guardShortcut(_handleMergeLineShortcut),
          onSyncWithVideo: _guardShortcut(() {
            unawaited(_syncWithVideoPosition());
          }),
          onShowMarkedLines: _guardShortcut(_showMarkedLinesModal),
          onPasteOriginal: _guardShortcut(_handlePasteOriginalShortcut),
        ),
      );
    } catch (error, stackTrace) {
      await logError(
        'Could not register Edit Line shortcuts',
        error: error,
        stackTrace: stackTrace,
        context: 'EditSubtitleScreen._registerHotkeyShortcuts',
      );
    }
  }

  Future<void> _syncVideoPlayerWhenReady() async {
    final mediaToken = _mediaRequests.captureMedia();
    final videoPath = _selectedVideoPath;
    if (mediaToken == null || videoPath == null) return;
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted ||
        !_isVideoLoaded ||
        _selectedVideoPath != videoPath ||
        !_mediaRequests.isCurrentMedia(mediaToken) ||
        player == null ||
        !identical(player, _videoPlayerKey.currentState)) return;
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
    _mediaRequests.invalidateMedia();
    _mediaRequests.invalidatePicker();
    _stopRepeatPlayback();
    _setEditLineState(() {
      _selectedVideoPath = null;
      _isVideoVisible = false;
      _isVideoLoaded = false;
      _isVideoPlaying = false;
    });

    await _videoPathWrites.clearPath();
    if (!mounted) return;
    SnackbarHelper.showInfo(
      context,
      'Video unloaded',
      duration: const Duration(seconds: 2),
    );
  }


}
