part of '../../screen_edit.dart';

extension _EditMediaActions on _EditScreenState {
  /// Ensure hotkeys are properly registered when returning to this screen
  Future<void> _ensureHotkeysRegistered() async {
    if (_hotkeysRegistered) return; // Guard against multiple registrations
    
    try {
      // Force re-register shared shortcuts that might have been affected
      await hotkey.MSoneHotkeyManager.instance.forceRegisterSharedShortcuts(
        onHelp: _handleHelpShortcut,
        onSettings: _handleSettingsShortcut,
        onNextLine: _handleNextLineShortcut,
        onPreviousLine: _handlePreviousLineShortcut,
      );
      
      // Also ensure mark line shortcuts are re-registered (Ctrl+M and Ctrl+Shift+M)
      await hotkey.MSoneHotkeyManager.instance.registerCallback(
        hotkey.HotkeyAction.markLine,
        _handleMarkLineShortcut,
      );
      await hotkey.MSoneHotkeyManager.instance.registerCallback(
        hotkey.HotkeyAction.markLineAndComment,
        _handleMarkLineAndCommentShortcut,
      );
      await hotkey.MSoneHotkeyManager.instance.registerCallback(
        hotkey.HotkeyAction.showMarkedLines,
        _showMarkedLinesModal,
      );
      
      _hotkeysRegistered = true; // Mark as registered
      debugPrint('DEBUG: Hotkeys registered successfully');
    } catch (e) {
      debugPrint('DEBUG: Failed to ensure hotkeys in didChangeDependencies: $e');
    }
  }

  Future<List<SubtitleLine>> _fetchSubtitleLines() async {
    final subtitles = await _controller.loadSubtitleLines();
    _controller.replaceSubtitleLinesLocally(subtitles);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setEditorState(() {
          _subtitles = _generateSubtitles(subtitles);
        });

        if (_isVideoLoaded) {
          _updateVideoPlayerSubtitles();
        }
      }
    });
    return subtitles;
  }

  Future<void> _loadSavedVideoPath() async {
    // Riverpod migration - video path already loaded by controller initialization
    // Just sync local state from controller state
    final state = _editState;
    if (!mounted) return;
    
    _setEditorState(() {
      _selectedVideoPath = state.selectedVideoPath;
      _isVideoVisible = state.selectedVideoPath != null;
      _isVideoLoaded = state.isVideoLoaded;
    });
    
    // Ensure video player gets subtitles after video is loaded
    _ensureVideoPlayerSubtitles();
  }

  Future<void> _restoreVideoPositionWhenReady() async {
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted || player == null || !_isVideoVisible) return;
    player.seekTo(_lastVideoPosition);
    _updateVideoPlayerSubtitles();
  }

  Future<void> _pickVideoFile() async {
    final filePath = await FilePickerConvenience.pickVideoFile(context: context);

    if (filePath != null) {
      // Clear waveform cache and reset waveform state when loading new video
      await _controller.clearWaveformCache();
      ref.read(waveformControllerProvider.notifier).dispatch(const ClearWaveform());
      _setEditorState(() {
        _isWaveformVisible = false;
      });
      
      // Riverpod migration - delegate to the Riverpod controller
      await _controller.loadVideo(filePath);
      
      // Update local state from controller state
      final state = _editState;
      if (!mounted) return;
      
      _setEditorState(() {
        _selectedVideoPath = state.selectedVideoPath;
        _isVideoVisible = true;
        _isVideoLoaded = state.isVideoLoaded;
      });
      
      // Ensure video player gets subtitles after video is loaded
      _ensureVideoPlayerSubtitles();
    }
  }
  Future<void> _unloadVideo() async {
    // Riverpod migration - delegate to the Riverpod controller
    await _controller.unloadVideo();
    
    // Update local state from controller state
    final state = _editState;
    if (!mounted) return;
    
    _setEditorState(() {
      _selectedVideoPath = state.selectedVideoPath;
      _isVideoVisible = false;
      _isVideoLoaded = state.isVideoLoaded;
    });
  }


}
