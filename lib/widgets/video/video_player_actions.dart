part of '../video_player_widget.dart';

extension VideoPlayerActions on VideoPlayerWidgetState {
  void seekTo(Duration position) {
    _player.seek(position);
  }
  
  void pause() {
    _player.pause();
  }
  
  void play() {
    _player.play();
  }
  
  void playOrPause() {
    if (_player.state.playing) {
      pause();
    } else {
      play();
    }
  }
  
  void updateVideo(String newPath) async {
    _cachedFramerate = null;
    _framerateFuture = null;
    _audioTrackRestoreInProgress = false;
  
    // Reset track restoration state for the new media.
    if (mounted) {
      _setVideoState(() {
        _isInitializingTracks = true;
        _availableAudioTracks = [];
        _availableSubtitleTracks = [];
      });
    }
    
    _player.stop();
    _player.open(Media(newPath));
    
    // Clear audio track selection when video changes
    try {
      await _preferencesRepository.clearSelectedAudioTrack(widget.subtitleCollectionId);
      debugPrint('Cleared audio track selection for new video');
    } catch (e) {
      debugPrint('Error clearing audio track selection: $e');
    }
  
  }
  
  void updateSubtitles(List<Subtitle> newSubtitles) {
    // Avoid unnecessary updates if subtitles haven't actually changed
    if (_currentSubtitles.length == newSubtitles.length) {
      bool hasChanges = false;
      for (int i = 0; i < _currentSubtitles.length; i++) {
        if (_currentSubtitles[i].index != newSubtitles[i].index ||
            _currentSubtitles[i].text != newSubtitles[i].text ||
            _currentSubtitles[i].start != newSubtitles[i].start ||
            _currentSubtitles[i].end != newSubtitles[i].end ||
            _currentSubtitles[i].marked != newSubtitles[i].marked) {
          hasChanges = true;
          // Debug marked state changes specifically
          if (_currentSubtitles[i].marked != newSubtitles[i].marked) {
            debugPrint('VideoPlayer: Subtitle ${newSubtitles[i].index} marked status changed: ${_currentSubtitles[i].marked} -> ${newSubtitles[i].marked}');
          }
          break;
        }
      }
      if (!hasChanges) {
        return; // No changes detected, skip update
      }
    }
    
    // Update subtitle data WITHOUT calling setState to avoid rebuilding the video player
    _currentSubtitles = newSubtitles;
    _primarySubtitleIndex = SubtitleTimelineIndex(newSubtitles);
    // Reset active subtitle cache when subtitles update
    _currentActiveSubtitles = [];
    _currentActiveSecondarySubtitles = [];
    
    // Notify external components without rebuilding this widget
    if (widget.onSubtitlesUpdated != null) {
      widget.onSubtitlesUpdated!();
    }
    
    // Force immediate recalculation of active subtitles for current position
    // This ensures the active subtitle index is correct after structural changes
    final currentPosition = _player.state.position;
    _updateActiveSubtitles(currentPosition);
    
    // Force rebuild of fullscreen overlay to update mark button states (debounced)
    if (_fullscreenOverlay != null) {
      // Use a future to avoid excessive rebuilds during rapid subtitle updates
      Future.microtask(() {
        if (_fullscreenOverlay != null && mounted) {
          _fullscreenOverlay!.markNeedsBuild();
        }
      });
    }
  }
  
  void updateSecondarySubtitles(List<Subtitle> newSubtitles) {
    // Update secondary subtitle data WITHOUT calling setState to avoid rebuilding the video player
    _currentSecondarySubtitles = newSubtitles;
    _secondarySubtitleIndex = SubtitleTimelineIndex(newSubtitles);
    // Reset secondary subtitle cache
    _currentActiveSecondarySubtitles = [];
    
    // Force immediate recalculation of active subtitles for current position
    final currentPosition = _player.state.position;
    _updateActiveSubtitles(currentPosition);
  }
  
  void _initializePlayer() {
    // Initialize the player
    _player = Player();
    _controller = VideoController(_player);
    
    // Open the media file with autoplay disabled
    _player.open(Media(widget.videoPath), play: false);
    
    // Track when player is ready by listening to width stream directly
    _widthSubscription = _player.stream.width.listen((width) {
      // Check if mounted and still loading, and width is valid (non-null and > 0)
      if (mounted && _isLoading && width != null && width > 0) {
        _setVideoState(() {
          _isLoading = false;
        });
        
        // Apply volume after player is ready (second attempt, ensures proper application)
        // This guarantees the volume from preferences is applied after the player
        // has fully initialized, addressing timing issues with early volume setting
        _player.setVolume(_currentVolume);
      }
    });
    
    // Set up position listener with throttling for better performance
    Duration lastPositionUpdate = Duration.zero;
    DateTime lastCallTime = DateTime.now();
    _positionSubscription = _player.stream.position.listen((position) {
      // Safety checks: ensure widget is mounted and position is valid
      if (!mounted || position.isNegative) return;
      
      try {
        // Additional throttling: prevent excessive calls in short time periods
        final now = DateTime.now();
        if (now.difference(lastCallTime).inMilliseconds < 50) return; // Minimum 50ms between calls
        
        // Throttle position updates to reduce excessive callbacks
        if ((position - lastPositionUpdate).inMilliseconds.abs() >= 100) { // Update max every 100ms
          lastPositionUpdate = position;
          lastCallTime = now;
          
          if (widget.onPositionChanged != null) {
            widget.onPositionChanged!(position);
          }
          _updateActiveSubtitles(position);
        }
      } catch (e) {
        debugPrint('Error in position listener: $e');
      }
    });
    
    // Set up playback state listener
    _playingSubscription = _player.stream.playing.listen((isPlaying) {
      if (!mounted) return;
      try {
        // Notify external components of play state changes
        if (widget.onPlayStateChanged != null) {
          widget.onPlayStateChanged!(isPlaying);
        }
      } catch (e) {
        debugPrint('Error in playing state listener: $e');
      }
    });
    
    // Set up audio tracks listener. Saved audio selection is restored only
    // after the player reports actual tracks, avoiding fixed-delay races.
    _tracksSubscription = _player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      try {
        _setVideoState(() {
          _availableAudioTracks = tracks.audio;
          _availableSubtitleTracks = tracks.subtitle;
        });
  
        if (_isInitializingTracks && tracks.audio.isNotEmpty) {
          unawaited(_restoreSavedAudioTrack(tracks.audio));
        }
      } catch (e) {
        debugPrint('Error in tracks listener: $e');
      }
    });
    
    // Set up current audio track listener with persistence
    _trackSubscription = _player.stream.track.listen((track) {
      if (!mounted) return;
      try {
        final previousAudioTrack = _currentAudioTrack;
        _setVideoState(() {
          _currentAudioTrack = track.audio;
          _currentSubtitleTrack = track.subtitle;
        });
        
        // Save audio track selection when it changes (user selection)
        // Skip saving during initialization to preserve saved preferences
        if (!_isInitializingTracks && track.audio.id != previousAudioTrack?.id) {
          _saveAudioTrackSelection(track.audio);
        }
      } catch (e) {
        debugPrint('Error in track listener: $e');
      }
    });
    
    // Set initial volume from saved preferences (early attempt)
    // Note: This is called immediately, but volume may not be fully applied
    // until the player is ready. A second call is made in the width listener.
    _player.setVolume(_currentVolume);
  
  }
  
  void _updateActiveSubtitles(Duration position) {
    // Safety check: don't update if widget is disposed or not mounted
    if (!mounted) return;
    
    try {
      // Find all active subtitles at current position (supports overlapping subtitles)
      final newActiveSubtitles = _primarySubtitleIndex.findActive(position);
      final newActiveSecondarySubtitles =
          _secondarySubtitleIndex.findActive(position);
      
      
      // Check if primary subtitles changed (compare list contents)
      if (!_areSubtitleListsEqual(_currentActiveSubtitles, newActiveSubtitles)) {
        _currentActiveSubtitles = newActiveSubtitles;
        
        // Notify external components of the active subtitle array index
        // Use the first subtitle in the list for callback (if any)
        // Only call this callback when IN fullscreen mode so video player navigation 
        // only works in fullscreen, preventing interference with EditScreen shortcuts in normal mode
        if (widget.onActiveSubtitleChanged != null) {
          if (newActiveSubtitles.isNotEmpty) {
            // Find the array index of the first subtitle in the current list
            final arrayIndex = _currentSubtitles.indexOf(newActiveSubtitles.first);
            widget.onActiveSubtitleChanged!(arrayIndex >= 0 ? arrayIndex : -1);
          } else {
            widget.onActiveSubtitleChanged!(-1); // No active subtitle
          }
        }
      }
      
      // Check if secondary subtitles changed
      if (!_areSubtitleListsEqual(_currentActiveSecondarySubtitles, newActiveSecondarySubtitles)) {
        _currentActiveSecondarySubtitles = newActiveSecondarySubtitles;
      }
      
      // DO NOT call setState here - subtitle rendering is handled by StreamBuilder in build()
      // Calling setState here causes excessive rebuilds and frame drops during video playback
      // The subtitle overlay is already reactive through the position stream
      // Only update internal state for external callbacks
    } catch (e) {
      // Log error and continue gracefully
      debugPrint('Error updating active subtitles: $e');
    }
  }
  
  // Helper method to compare two subtitle lists for equality
  bool _areSubtitleListsEqual(List<Subtitle> list1, List<Subtitle> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].index != list2[i].index || list1[i].text != list2[i].text) {
        return false;
      }
    }
    
    return true;
  }
  
  Duration getCurrentPosition() {
    try {
      // Safety check to prevent accessing disposed player
      if (!mounted) return Duration.zero;
      return _player.state.position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return Duration.zero;
    }
  }
  
  bool isPlaying() {
    try {
      // Safety check to prevent accessing disposed player
      if (!mounted) return false;
      return _player.state.playing;
    } catch (e) {
      debugPrint('Error checking playing state: $e');
      return false;
    }
  }
  
  bool isInitialized() {
    try {
      // Safety check to prevent accessing disposed player
      if (!mounted) return false;
      // Check if media is loaded by ensuring a valid duration exists
      return _player.state.duration > Duration.zero;
    } catch (e) {
      debugPrint('Error checking initialization state: $e');
      return false;
    }
  }
  
  // Method to get video framerate
  Future<double?> _getFramerateInternal() async {
    try {
      final ffmpegHelper = FFmpegHelper();
      return await ffmpegHelper.getVideoFramerate(widget.videoPath);
    } catch (e) {
      debugPrint('Error getting framerate: $e');
      return null;
    }
  }
  
  // Public method to access the framerate
  double? getFrameRate() {
    final cached = _cachedFramerate;
    if (cached != null) {
      return cached;
    }
  
    _framerateFuture ??= _getFramerateInternal().then((value) {
      if (value != null && mounted) {
        _cachedFramerate = value;
      }
      return value;
    }).whenComplete(() {
      _framerateFuture = null;
    });
  
    // Keep the existing synchronous API and fallback while probing.
    return 25.0;
  }
  
  // Toggle subtitles visibility
  void toggleSubtitles() {
    _setVideoState(() {
      _areSubtitlesEnabled = !_areSubtitlesEnabled;
    });
  }
  
  // Set playback speed
  void setPlaybackSpeed(double speed) {
    _setVideoState(() {
      _currentSpeed = speed;
    });
    _player.setRate(speed);
  }
  
  // Get current playback speed
  double getCurrentSpeed() {
    return _currentSpeed;
  }
  
  // Fullscreen state and subtitle seeking methods for external access
  
  /// Check if the video player is currently in fullscreen mode
  bool isInFullscreenMode() {
    return _isCustomFullscreen;
  }
  
  /// Seek to the previous subtitle start time
  /// This method provides external access to the fullscreen skip functionality
  void seekToPreviousSubtitle() {
    _seekToPreviousSubtitle();
  }
  
  /// Seek to the next subtitle start time  
  /// This method provides external access to the fullscreen skip functionality
  void seekToNextSubtitle() {
    _seekToNextSubtitle();
  }
  
  /// Show comment dialog for a specific subtitle in fullscreen mode
  /// This method provides external access to fullscreen comment dialog functionality
  void showFullscreenCommentDialog(Subtitle subtitle, {
    String? originalText,
    String? editedText,
  }) {
    if (_isCustomFullscreen && _fullscreenControlsKey.currentState != null) {
      debugPrint('showFullscreenCommentDialog: Triggering fullscreen comment dialog for subtitle ${subtitle.index}');
      _fullscreenControlsKey.currentState!.showCommentDialogForSubtitle(subtitle, 
        originalText: originalText, editedText: editedText);
    } else if (_isCustomFullscreen) {
      debugPrint('showFullscreenCommentDialog: Warning - fullscreen controls state is null');
    } else {
      debugPrint('showFullscreenCommentDialog: Not in fullscreen mode, falling back to regular comment dialog');
      showCommentDialog(subtitle, _originalContext ?? context);
    }
  }
}
