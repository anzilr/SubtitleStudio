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

  void _nextSubtitle(subtitleId, lineIndex) async {
    // Don't stop repeat mode when navigating - let it continue
    // Only stop if we're outside the custom range
    if (_isRepeatModeEnabled && _isCustomRangeMode) {
      final nextIndex = _subtitleLine?.index ?? 0;
      if (_customRangeEndIndex != null && nextIndex > _customRangeEndIndex!) {
        // We're going beyond the custom range, keep repeat but pause it temporarily
        _stopRepeatPlayback();
      }
    }

    // Check for validation errors first
    if (_hasValidationErrors()) {
      SnackbarHelper.showError(
        context,
        'Please fix validation errors before navigating',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Verify the next index is within bounds before navigating
    if (lineIndex > 0 && lineIndex <= _subtitle!.lines.length) {
      // Save changes if auto-save is enabled or we're in normal mode
      if (_autoSaveWithNavigation || !_showOriginalLine) {
        final saveSuccess = await _updateSubtitleSilently();
        if (!saveSuccess) {
          // Don't navigate if save failed
          return;
        }
      }
      // Navigate to next subtitle
      await _fetchSubtitleLine(subtitleId, lineIndex - 1);

      // Resume repeat if enabled
      if (_isRepeatModeEnabled) {
        final currentIndex =
            (_subtitleLine?.index ?? 1) - 1; // Convert to 0-based
        if (!_isCustomRangeMode) {
          // For normal repeat mode, update to the new subtitle line
          // This will update repeat timing with the new subtitle without changing play/pause state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateRepeatTiming();
          });
        } else if (_customRangeStartIndex != null &&
            _customRangeEndIndex != null &&
            currentIndex >= _customRangeStartIndex! &&
            currentIndex <= _customRangeEndIndex!) {
          // For custom range mode, only restart if we're still in range
          // Video is already paused by _seekVideoToSubtitle when repeat mode is enabled
          // User needs to manually start playback
        }
      }
    } else {
      // Show a message when there's no next subtitle
      SnackbarHelper.showWarning(
        context,
        'This is the last subtitle',
        duration: const Duration(seconds: 1),
      );
    }
  }

  void _prevSubtitle(subtitleId, lineIndex) async {
    // Don't stop repeat mode when navigating - let it continue
    // Only stop if we're outside the custom range
    if (_isRepeatModeEnabled && _isCustomRangeMode) {
      final prevIndex =
          (_subtitleLine?.index ?? 2) - 2; // Previous index in 0-based
      if (_customRangeStartIndex != null &&
          prevIndex < _customRangeStartIndex!) {
        // We're going before the custom range, keep repeat but pause it temporarily
        _stopRepeatPlayback();
      }
    }

    // Check for validation errors first
    if (_hasValidationErrors()) {
      SnackbarHelper.showError(
        context,
        'Please fix validation errors before navigating',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (lineIndex > 0 && lineIndex <= _subtitle!.lines.length) {
      // Save changes if auto-save is enabled or we're in normal mode
      if (_autoSaveWithNavigation || !_showOriginalLine) {
        final saveSuccess = await _updateSubtitleSilently();
        if (!saveSuccess) {
          // Don't navigate if save failed
          return;
        }
      }
      // Navigate to the previous subtitle line (lineIndex is 1-based, convert to 0-based for array access)
      await _fetchSubtitleLine(subtitleId, lineIndex - 1);

      // Resume repeat if we're in range and it was enabled
      if (_isRepeatModeEnabled) {
        final currentIndex =
            (_subtitleLine?.index ?? 1) - 1; // Convert to 0-based
        if (!_isCustomRangeMode) {
          // For normal repeat mode, update to the new subtitle line
          // This will update repeat timing with the new subtitle without changing play/pause state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateRepeatTiming();
          });
        } else if (_customRangeStartIndex != null &&
            _customRangeEndIndex != null &&
            currentIndex >= _customRangeStartIndex! &&
            currentIndex <= _customRangeEndIndex!) {
          // For custom range mode, only restart if we're still in range
          // Video is already paused by _seekVideoToSubtitle when repeat mode is enabled
          // User needs to manually start playback
        }
      }
    } else {
      // Show a message when there's no previous subtitle
      SnackbarHelper.showWarning(
        context,
        'This is the first subtitle',
        duration: const Duration(seconds: 1),
      );
    }
  }

  void _skipToLine(subtitleId, lineIndex) {
    // Check if we're navigating outside custom range
    if (_isRepeatModeEnabled && _isCustomRangeMode) {
      if (_customRangeStartIndex != null &&
          _customRangeEndIndex != null &&
          (lineIndex < _customRangeStartIndex! ||
              lineIndex > _customRangeEndIndex!)) {
        // We're going outside the custom range, pause repeat temporarily
        _stopRepeatPlayback();
      }
    }

    // Navigate to the specified subtitle line
    setState(() {
      _fetchSubtitleLine(subtitleId, lineIndex);
    });

    // Resume repeat if we're in range and it was enabled
    if (_isRepeatModeEnabled) {
      if (!_isCustomRangeMode) {
        // For normal repeat mode, update to the new subtitle line
        // This will update repeat timing with the new subtitle without changing play/pause state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateRepeatTiming();
        });
      } else if (_customRangeStartIndex != null &&
          _customRangeEndIndex != null &&
          lineIndex >= _customRangeStartIndex! &&
          lineIndex <= _customRangeEndIndex!) {
        // For custom range mode, only restart if we're still in range
        // Video is already paused by _seekVideoToSubtitle when repeat mode is enabled
        // User needs to manually start playback
      }
    }
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
