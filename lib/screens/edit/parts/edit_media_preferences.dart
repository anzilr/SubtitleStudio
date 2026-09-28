part of '../../screen_edit.dart';

extension _EditMediaPreferences on _EditScreenState {
  // Save resize ratio preference with debouncing
  Future<void> _saveResizeRatio(double ratio) async {
    if (mounted) {
      _setEditorState(() {
        _resizeRatio = ratio;
      });
    }
    
    // Cancel any existing timer
    _resizeRatioSaveTimer?.cancel();
    
    // Start a new timer to save after a short delay
    _resizeRatioSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      // Riverpod migration - delegate to the Riverpod controller
      if (mounted) {
        await _controller.updateResizeRatio(ratio);
      }
    });
  }

  /// Save mobile video resize ratio with debouncing
  void _saveMobileResizeRatio(double ratio) {
    if (mounted) {
      _setEditorState(() {
        _mobileVideoResizeRatio = ratio;
      });
    }
    
    // Cancel any existing timer
    _mobileResizeRatioSaveTimer?.cancel();
    
    // Set up a new timer with 500ms delay
    _mobileResizeRatioSaveTimer = Timer(Duration(milliseconds: 500), () async {
      // Riverpod migration - delegate to the Riverpod controller
      if (mounted) {
        await _controller.updateMobileResizeRatio(ratio);
      }
    });
  }

  // Toggle floating controls
  void _toggleFloatingControls(bool value) {
    _controller.updateFloatingControls(value);
  }

  /// Toggle waveform visibility
  void _toggleWaveform() async {
    if (!_isVideoLoaded || _selectedVideoPath == null) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Please load a video first');
      }
      return;
    }

    if (mounted) {
      _setEditorState(() {
        _isWaveformVisible = !_isWaveformVisible;
      });
    }

    // Only load audio if showing waveform and it's not already loaded for this video
    if (_isWaveformVisible && mounted) {
      final currentState = ref.read(waveformControllerProvider);
      final isAlreadyLoaded = currentState is WaveformReady && 
                              currentState.sourceFilePath == _selectedVideoPath;
      
      if (!isAlreadyLoaded) {
        ref.read(waveformControllerProvider.notifier).dispatch(LoadAudioFile(
          _selectedVideoPath!,
          subtitleCollectionId: widget.subtitleCollectionId,
        ));
      }
    }
  }

  /// Register hotkey shortcuts using MSoneHotkeyManager
  Future<void> _registerHotkeyShortcuts() async {
    debugPrint('DEBUG: _registerHotkeyShortcuts() called in EditScreen');
    
    // Unregister HomeScreen shortcuts to prevent conflicts (e.g., Ctrl+E)
    await hotkey.MSoneHotkeyManager.instance.unregisterHomeScreenShortcuts();
    
    await hotkey.MSoneHotkeyManager.instance.registerMainEditScreenShortcuts(
      onPlayPause: _handlePlayPauseShortcut,
      onToggleSelection: _handleToggleSelectionModeShortcut,
      onDelete: _handleDeleteSelectionShortcut,
      onSave: _handleSaveShortcut,
      onCopy: _handleCopyShortcut,
      // Navigation shortcuts
      onNextLine: _handleNextLineShortcut,
      onPreviousLine: _handlePreviousLineShortcut,
      // New shortcuts
      onEditCurrentLine: _handleEditCurrentLineShortcut,
      onMarkLine: _handleMarkLineShortcut,
      onMarkLineAndComment: _handleMarkLineAndCommentShortcut,
      onFindReplace: _handleFindReplaceShortcut,
      onGotoLine: _handleGotoLineShortcut,
      onHelp: _handleHelpShortcut,
      onSettings: _handleSettingsShortcut,
      onSaveProject: _handleSaveProject,
      onPopScreen: _handlePopScreenShortcut,
      // Video playback shortcuts (only fullscreen)
      onToggleFullscreen: _handleToggleFullscreenShortcut,
      // Marked lines sheet shortcut
      onShowMarkedLines: _showMarkedLinesModal,
    );
    debugPrint('DEBUG: _registerHotkeyShortcuts() completed in EditScreen');
  }


}
