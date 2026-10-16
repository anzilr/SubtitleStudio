part of '../video_player_widget.dart';

extension _VideoPlaybackNavigation on VideoPlayerWidgetState {
  // Toggle mute
  void toggleMute() async {
    if (_currentVolume > 0) {
      _player.setVolume(0);
      _setVideoState(() {
        _currentVolume = 0;
      });
      await _preferencesRepository.setVideoVolume(0);
    } else {
      _player.setVolume(100);
      _setVideoState(() {
        _currentVolume = 100;
      });
      await _preferencesRepository.setVideoVolume(100);
    }
  }
  
  // Skip forward or backward
  void _seekRelative(Duration offset) {
    final currentPosition = _player.state.position;
    final newPosition = currentPosition + offset;
    // Ensure we don't seek past video bounds
    final clampedPosition = newPosition.clamp(
      Duration.zero,
      _player.state.duration,
    );
    _player.seek(clampedPosition);
  }
  
  // Skip to previous subtitle start time
  void _seekToPreviousSubtitle() {
    if (!mounted) return;
    
    // Capture the current position immediately to prevent it from changing during playback
    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;
    
    // Pause the video first to ensure stable position reference
    if (wasPlaying) {
      _player.pause();
    }
    
    // Find the previous subtitle start time with better logic
    Duration? previousStart;
    
    // Special case: if we're very close to a subtitle start (within 1 second), 
    // go to the previous one instead of the current one
    final threshold = const Duration(milliseconds: 1000);
    final adjustedPosition = currentPosition - threshold;
    
    // Look through primary subtitles
    for (int i = _currentSubtitles.length - 1; i >= 0; i--) {
      final subtitle = _currentSubtitles[i];
      if (subtitle.start < adjustedPosition) {
        if (previousStart == null || subtitle.start > previousStart) {
          previousStart = subtitle.start;
        }
        break; // Found the closest previous subtitle
      }
    }
    
    // Also check secondary subtitles for a potentially closer previous subtitle
    for (int i = _currentSecondarySubtitles.length - 1; i >= 0; i--) {
      final subtitle = _currentSecondarySubtitles[i];
      if (subtitle.start < adjustedPosition) {
        if (previousStart == null || subtitle.start > previousStart) {
          previousStart = subtitle.start;
        }
        break; // Found the closest previous subtitle
      }
    }
    
    // Seek to the previous subtitle start time, or beginning if none found
    if (previousStart != null) {
      // Add 50ms offset to ensure subtitle is visible after seeking
      // This prevents the subtitle from disappearing when seeking to exact start time
      final seekPosition = previousStart + const Duration(milliseconds: 50);
      _player.seek(seekPosition);
      
      // Notify external components about the seek operation
      if (widget.onPositionChanged != null) {
        widget.onPositionChanged!(seekPosition);
      }
      
      // Resume playback if video was playing before, unless repeat mode is enabled
      if (widget.isRepeatModeEnabled) {
        _player.pause();
      } else if (wasPlaying) {
        _player.play();
      }
    } else {
      _player.seek(Duration.zero);
      
      // Notify external components about the seek operation
      if (widget.onPositionChanged != null) {
        widget.onPositionChanged!(Duration.zero);
      }
      
      // Resume playback if video was playing before, unless repeat mode is enabled
      if (widget.isRepeatModeEnabled) {
        _player.pause();
      } else if (wasPlaying) {
        _player.play();
      }
    }
  }
  
  // Skip to next subtitle start time
  void _seekToNextSubtitle() {
    if (!mounted) return;
    
    // Capture the current position immediately to prevent it from changing during playback
    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;
    
    // Pause the video first to ensure stable position reference
    if (wasPlaying) {
      _player.pause();
    }
    
    // Find the next subtitle start time with better logic
    Duration? nextStart;
    
    // Add small threshold to handle edge cases where we're exactly at subtitle start
    final threshold = const Duration(milliseconds: 100);
    final adjustedPosition = currentPosition + threshold;
    
    // Look through primary subtitles first
    for (int i = 0; i < _currentSubtitles.length; i++) {
      final subtitle = _currentSubtitles[i];
      if (subtitle.start > adjustedPosition) {
        if (nextStart == null || subtitle.start < nextStart) {
          nextStart = subtitle.start;
        }
        break; // Found the first next subtitle
      }
    }
    
    // Also check secondary subtitles for a potentially closer next subtitle
    for (int i = 0; i < _currentSecondarySubtitles.length; i++) {
      final subtitle = _currentSecondarySubtitles[i];
      if (subtitle.start > adjustedPosition) {
        if (nextStart == null || subtitle.start < nextStart) {
          nextStart = subtitle.start;
        }
        break; // Found the first next subtitle
      }
    }
    
    // Seek to the next subtitle start time, or end if none found
    if (nextStart != null) {
      // Add 50ms offset to ensure subtitle is visible after seeking
      // This prevents the subtitle from disappearing when seeking to exact start time
      final seekPosition = nextStart + const Duration(milliseconds: 50);
      _player.seek(seekPosition);
      
      // Notify external components about the seek operation
      if (widget.onPositionChanged != null) {
        widget.onPositionChanged!(seekPosition);
      }
      
      // Resume playback if video was playing before, unless repeat mode is enabled
      if (widget.isRepeatModeEnabled) {
        _player.pause();
      } else if (wasPlaying) {
        _player.play();
      }
    } else {
      final duration = _player.state.duration;
      _player.seek(duration);
      
      // Notify external components about the seek operation
      if (widget.onPositionChanged != null) {
        widget.onPositionChanged!(duration);
      }
      
      // Resume playback if video was playing before, unless repeat mode is enabled
      if (widget.isRepeatModeEnabled) {
        _player.pause();
      } else if (wasPlaying) {
        _player.play();
      }
    }
  }
  
  // Format duration to always show HH:MM:SS format
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    // Always include hours for consistent format
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
