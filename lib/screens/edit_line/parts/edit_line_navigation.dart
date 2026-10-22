part of '../../screen_edit_line.dart';

extension _EditLineNavigation on EditSubtitleScreenState {
  void _seekVideoToSubtitle() {
    if (_isVideoLoaded &&
        _videoPlayerKey.currentState != null &&
        _subtitleLine != null) {
      final startTime = parseTimeString(_subtitleLine!.startTime);
      // Add 50ms offset to ensure subtitle is visible after seeking
      // This prevents the subtitle from disappearing when seeking to exact start time
      final seekPosition = startTime + const Duration(milliseconds: 50);

      // Check if video player is initialized
      if (_videoPlayerKey.currentState!.isInitialized()) {
        _videoPlayerKey.currentState!.seekTo(seekPosition);
        // Pause video if repeat mode is enabled to prevent autoplay on navigation
        if (_isRepeatModeEnabled) {
          _videoPlayerKey.currentState!.pause();
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_seekWhenVideoPlayerReady(seekPosition));
        });
      }
    }
  }

  void _nextSubtitle(subtitleId, int _lineIndex) {
    unawaited(_navigateRelative(subtitleId, 1));
  }

  void _prevSubtitle(subtitleId, int _lineIndex) {
    unawaited(_navigateRelative(subtitleId, -1));
  }

  /// A single navigation owns the save, reload and selection transition.
  /// Additional taps cannot concurrently save a half-loaded cue.
  Future<void> _navigateRelative(Object? subtitleId, int direction) {
    return _navigationGuard.runExclusive(() async {
      if (!mounted || _subtitleLine == null || _subtitle == null) return;
      if (_hasValidationErrors()) {
        SnackbarHelper.showError(
          context,
          'Please fix validation errors before navigating',
          duration: const Duration(seconds: 2),
        );
        return;
      }

      if (_autoSaveWithNavigation || !_showOriginalLine) {
        if (!await _updateSubtitleSilently()) return;
      }
      if (!mounted || _subtitleLine == null || _subtitle == null) return;

      // The current cue may have changed index after the saved timing edit.
      final target = _subtitleLine!.index + direction;
      if (target < 1 || target > _subtitle!.lines.length) {
        SnackbarHelper.showWarning(
          context,
          direction > 0 ? 'This is the last subtitle'
                        : 'This is the first subtitle',
          duration: const Duration(seconds: 1),
        );
        return;
      }

      if (_isRepeatModeEnabled && _isCustomRangeMode &&
          (_customRangeStartIndex == null ||
           _customRangeEndIndex == null ||
           target - 1 < _customRangeStartIndex! ||
           target - 1 > _customRangeEndIndex!)) {
        _stopRepeatPlayback();
      }

      if (!await _fetchSubtitleLine(subtitleId, target - 1) || !mounted) {
        return;
      }
      _resumeRepeatAfterLineNavigation();
    });
  }

  /// Go-to-line, marked-line selection and keyboard navigation all honor
  /// the same unsaved-change and lifecycle checks.
  void _skipToLine(subtitleId, int lineIndex) {
    unawaited(_navigationGuard.runExclusive(() async {
      if (!mounted || _subtitle == null || _subtitleLine == null) return;
      if (lineIndex < 0 || lineIndex >= _subtitle!.lines.length) return;

      if (_hasValidationErrors()) {
        SnackbarHelper.showError(
          context,
          'Please fix validation errors before navigating',
          duration: const Duration(seconds: 2),
        );
        return;
      }
      if (_autoSaveWithNavigation || !_showOriginalLine) {
        if (!await _updateSubtitleSilently()) return;
      }
      if (!mounted || _subtitle == null) return;
      if (lineIndex >= _subtitle!.lines.length) return;

      if (_isRepeatModeEnabled && _isCustomRangeMode &&
          (_customRangeStartIndex == null ||
           _customRangeEndIndex == null ||
           lineIndex < _customRangeStartIndex! ||
           lineIndex > _customRangeEndIndex!)) {
        _stopRepeatPlayback();
      }

      if (!await _fetchSubtitleLine(subtitleId, lineIndex) || !mounted) return;
      _resumeRepeatAfterLineNavigation();
    }));
  }

  void _resumeRepeatAfterLineNavigation() {
    if (!_isRepeatModeEnabled || _isCustomRangeMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isRepeatModeEnabled && !_isCustomRangeMode) {
        _updateRepeatTiming();
      }
    });
  }

  void _handleNextLineShortcut() {
    // If video is loaded and in fullscreen mode, use video skip function
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final videoPlayer = _videoPlayerKey.currentState!;
      if (videoPlayer.isInFullscreenMode()) {
        logInfo(
          'Ctrl+. pressed in fullscreen mode - using video skip to next subtitle',
          context: 'EditSubtitleScreen._handleNextLineShortcut',
        );
        videoPlayer.seekToNextSubtitle();
        return;
      }
    }
    
    // Otherwise, use normal subtitle line navigation
    logInfo(
      'Ctrl+. pressed - using normal line navigation',
      context: 'EditSubtitleScreen._handleNextLineShortcut',
    );
    if (_subtitleLine != null) {
      _nextSubtitle(widget.subtitleId, _subtitleLine!.index + 1);
    }
  }

  void _handlePreviousLineShortcut() {
    // If video is loaded and in fullscreen mode, use video skip function
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final videoPlayer = _videoPlayerKey.currentState!;
      if (videoPlayer.isInFullscreenMode()) {
        logInfo(
          'Ctrl+, pressed in fullscreen mode - using video skip to previous subtitle',
          context: 'EditSubtitleScreen._handlePreviousLineShortcut',
        );
        videoPlayer.seekToPreviousSubtitle();
        return;
      }
    }
    
    // Otherwise, use normal subtitle line navigation
    logInfo(
      'Ctrl+, pressed - using normal line navigation',
      context: 'EditSubtitleScreen._handlePreviousLineShortcut',
    );
    if (_subtitleLine != null && _subtitleLine!.index > 1) {
      _prevSubtitle(widget.subtitleId, _subtitleLine!.index - 1);
    }
  }
}
