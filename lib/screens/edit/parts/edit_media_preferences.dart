part of '../../screen_edit.dart';

extension _EditMediaPreferences on _EditScreenState {
  // Apply immediately; the controller owns debounced persistence and exit flush.
  void _saveResizeRatio(double ratio) {
    if (mounted) {
      _setEditorState(() {
        _resizeRatio = ratio;
      });
    }
    
    _controller.scheduleResizeRatio(ratio);
  }

  /// Save mobile video resize ratio through the shared coordinator.
  void _saveMobileResizeRatio(double ratio) {
    if (mounted) {
      _setEditorState(() {
        _mobileVideoResizeRatio = ratio;
      });
    }
    
    _controller.scheduleMobileVideoResizeRatio(ratio);
  }

  // Toggle floating controls
  void _toggleFloatingControls(bool value) {
    _controller.updateFloatingControls(value);
  }

  /// Called for every actual audio-track change from the Media Kit player.
  /// Kept off by default until real Windows/Android multitrack qualification.
  void _onWaveformAudioTrackChanged(String mpvTrackId) {
    if (!_EditScreenState._experimentalWaveformTrackSync ||
        !mounted || !_isVideoLoaded || !_isWaveformVisible ||
        _selectedVideoPath == null) return;
    unawaited(_reloadWaveformForSelectedTrack(expectedMpvId: mpvTrackId));
  }

  Future<void> _reloadWaveformForSelectedTrack({String? expectedMpvId}) async {
    if (!mounted || !_isVideoLoaded || _selectedVideoPath == null) return;
    final source = _selectedVideoPath!;
    final processor = ref.read(waveformControllerProvider.notifier);
    await _waveformTrackReload.reload(
      invalidate: () {
        // Clear synchronously, including any ongoing FFmpeg extraction.
        unawaited(processor.dispatch(const ClearWaveform()));
      },
      isCurrentSource: () =>
          mounted && _isWaveformVisible && _selectedVideoPath == source &&
          (expectedMpvId == null ||
           _videoPlayerKey.currentState?.getCurrentAudioTrack()?.id ==
               expectedMpvId),
      resolveStream: () async {
        final player = _videoPlayerKey.currentState;
        if (player == null) {
          throw StateError('Video player is not ready for audio selection.');
        }
        return player.resolveWaveformSelectedAudioStream();
      },
      load: (selection) => processor.dispatch(LoadAudioFile(
        source,
        subtitleCollectionId: widget.subtitleCollectionId,
        audioTrackId: selection,
        mediaDuration: _videoPlayerKey.currentState?.getDuration(),
      )),
      fail: (_) {
        unawaited(processor.dispatch(WaveformTrackSelectionFailed(
          'Unable to identify the selected audio track. '
          'Try Auto or reopen the video.',
          filePath: source,
        )));
      },
    );
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

    if (_EditScreenState._experimentalWaveformTrackSync) {
      if (_isWaveformVisible && mounted) {
        await _reloadWaveformForSelectedTrack();
      } else {
        _waveformTrackReload.cancel();
        // Hidden waveforms must not finish a previous decode in the
        // background, especially if the player switches audio tracks.
        await ref.read(waveformControllerProvider.notifier)
            .dispatch(const ClearWaveform());
      }
      return;
    }

    // Preserve original loading in normal builds.
    if (_isWaveformVisible && mounted) {
      final currentState = ref.read(waveformControllerProvider);
      final isAlreadyLoaded = currentState is WaveformReady && 
                              currentState.sourceFilePath == _selectedVideoPath;
      
      if (!isAlreadyLoaded) {
        ref.read(waveformControllerProvider.notifier).dispatch(LoadAudioFile(
          _selectedVideoPath!,
          subtitleCollectionId: widget.subtitleCollectionId,
          mediaDuration: _videoPlayerKey.currentState?.getDuration(),
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
