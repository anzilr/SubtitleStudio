part of '../../screen_edit_line.dart';

extension _EditLineRepeatEngine on EditSubtitleScreenState {
  void _toggleRepeatMode() {
    if (!_isVideoLoaded || _subtitleLine == null) {
      SnackbarHelper.showWarning(
        context,
        'Video or subtitle not available for repeat mode',
      );
      return;
    }

    _setEditLineState(() {
      _isRepeatModeEnabled = !_isRepeatModeEnabled;
    });

    if (_isRepeatModeEnabled) {
      _startRepeatPlayback();
      SnackbarHelper.showSuccess(
        context,
        'Repeat mode enabled for current subtitle',
      );
    } else {
      _stopRepeatPlayback();
      SnackbarHelper.showInfo(context, 'Repeat mode disabled');
    }
  }

  void _startRepeatPlayback() {
    if (!_isVideoLoaded || _videoPlayerKey.currentState == null) {
      return;
    }

    // Check if video is currently playing to preserve the play state
    final wasPlaying = _videoPlayerKey.currentState!.isPlaying();

    Duration startTime, endTime;

    if (_isCustomRangeMode &&
        _customRangeStartIndex != null &&
        _customRangeEndIndex != null) {
      // Custom range mode: use start time of start index and end time of end index
      final startSubtitle = _subtitles.firstWhere(
        (s) => s.index == _customRangeStartIndex! + 1,
      );
      final endSubtitle = _subtitles.firstWhere(
        (s) => s.index == _customRangeEndIndex! + 1,
      );

      startTime = startSubtitle.start - const Duration(milliseconds: 100);
      endTime = endSubtitle.end + const Duration(milliseconds: 100);
    } else {
      // Normal mode: use current subtitle
      if (_subtitleLine == null) return;
      startTime =
          parseTimeString(_subtitleLine!.startTime) -
          const Duration(milliseconds: 100);
      endTime =
          parseTimeString(_subtitleLine!.endTime) +
          const Duration(milliseconds: 100);
    }

    // Ensure start time is not negative
    final clampedStartTime = startTime.isNegative ? Duration.zero : startTime;

    // Seek to start position, but only play if video was already playing
    _videoPlayerKey.currentState!.seekTo(clampedStartTime);
    if (wasPlaying) {
      _videoPlayerKey.currentState!.play();
    }

    // Set up timer to monitor playback and repeat
    _repeatPlaybackTimer?.cancel();
    _repeatPlaybackTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted ||
          !_isRepeatModeEnabled ||
          _videoPlayerKey.currentState == null) {
        timer.cancel();
        return;
      }

      final currentPosition =
          _videoPlayerKey.currentState!.getCurrentPosition();

      // Loop back to start time if needed
      if (currentPosition >= endTime) {
        _videoPlayerKey.currentState!.seekTo(clampedStartTime);
        // Continue playing if video was playing
        if (_videoPlayerKey.currentState!.isPlaying()) {
          _videoPlayerKey.currentState!.play();
        }
      }
    });
  }

  void _stopRepeatPlayback() {
    _repeatPlaybackTimer?.cancel();
    _repeatPlaybackTimer = null;
    // Reset custom range when stopping repeat mode
    _isCustomRangeMode = false;
    _customRangeStartIndex = null;
    _customRangeEndIndex = null;
  }

  void _updateRepeatTiming() {
    if (!_isVideoLoaded ||
        _videoPlayerKey.currentState == null ||
        _subtitleLine == null) {
      return;
    }

    Duration startTime, endTime;

    if (_isCustomRangeMode &&
        _customRangeStartIndex != null &&
        _customRangeEndIndex != null) {
      // Custom range mode: use start time of start index and end time of end index
      final startSubtitle = _subtitles.firstWhere(
        (s) => s.index == _customRangeStartIndex! + 1,
      );
      final endSubtitle = _subtitles.firstWhere(
        (s) => s.index == _customRangeEndIndex! + 1,
      );

      startTime = startSubtitle.start - const Duration(milliseconds: 100);
      endTime = endSubtitle.end + const Duration(milliseconds: 100);
    } else {
      // Normal mode: use current subtitle
      startTime =
          parseTimeString(_subtitleLine!.startTime) -
          const Duration(milliseconds: 100);
      endTime =
          parseTimeString(_subtitleLine!.endTime) +
          const Duration(milliseconds: 100);
    }

    // Ensure start time is not negative
    final clampedStartTime = startTime.isNegative ? Duration.zero : startTime;

    // Seek to start position and pause (don't auto-play after navigation)
    _videoPlayerKey.currentState!.seekTo(clampedStartTime);
    _videoPlayerKey.currentState!.pause();

    // Set up timer to monitor playback and repeat
    _repeatPlaybackTimer?.cancel();
    _repeatPlaybackTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted ||
          !_isRepeatModeEnabled ||
          _videoPlayerKey.currentState == null) {
        timer.cancel();
        return;
      }

      final currentPosition =
          _videoPlayerKey.currentState!.getCurrentPosition();

      // If we've reached the end time, seek back to start and continue playing only if video is playing
      if (currentPosition >= endTime) {
        _videoPlayerKey.currentState!.seekTo(clampedStartTime);
        // Only continue playing if the video is currently playing
        if (_videoPlayerKey.currentState!.isPlaying()) {
          _videoPlayerKey.currentState!.play();
        }
      }
    });
  }
}
