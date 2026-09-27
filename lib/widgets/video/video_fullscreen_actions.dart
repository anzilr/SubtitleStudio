part of '../video_player_widget.dart';

extension _VideoFullscreenActions on VideoPlayerWidgetState {
  void _enterCustomFullscreen() {
    if (_isCustomFullscreen) return;
    
    // Store original context for dialogs
    _originalContext = context;
    
    setState(() {
      _isCustomFullscreen = true;
    });
  
    // Force a refresh of the widget state to ensure proper marked status display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // This refresh ensures all subtitle states are correctly synchronized in fullscreen
        });
      }
    });
    
    // Hide system UI for true fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Set orientation based on video aspect ratio
    final videoAspectRatio = _getVideoAspectRatio();
    if (videoAspectRatio > 1.0) {
      // Wide video - prefer landscape
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Tall video - prefer portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    
    // Create fullscreen overlay
    _fullscreenOverlay = OverlayEntry(
      builder: (context) => _buildCustomFullscreenWidget(),
    );
    
    // Insert overlay
    Overlay.of(context).insert(_fullscreenOverlay!);
  }
  
  /// Exit custom fullscreen mode
  void _exitCustomFullscreen() {
    if (!_isCustomFullscreen || !mounted) return;
    
    // Remove overlay safely
    _fullscreenOverlay?.remove();
    _fullscreenOverlay = null;
    
    // Clear original context
    _originalContext = null;
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    
    // Reset orientation to allow all orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Update state only if widget is still mounted
    if (mounted) {
      setState(() {
        _isCustomFullscreen = false;
      });
      
      // Notify parent widget that fullscreen has been exited
      widget.onFullscreenExited?.call();
    }
  }
  
  /// Toggle custom fullscreen mode
  void toggleCustomFullscreen() {
    if (_isCustomFullscreen) {
      _exitCustomFullscreen();
    } else {
      _enterCustomFullscreen();
    }
  }
  
  /// Toggle custom fullscreen mode (private method for internal use)
  void _toggleCustomFullscreen() {
    toggleCustomFullscreen();
  }
  
  /// Build the custom fullscreen widget with complete control
  Widget _buildCustomFullscreenWidget() {
    return Material(
      color: Colors.black,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          // Handle back button/gesture manually
          if (!didPop && mounted && _isCustomFullscreen) {
            _exitCustomFullscreen();
          }
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                _exitCustomFullscreen();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
                _exitCustomFullscreen();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.space) {
                playOrPause();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _seekRelative(const Duration(seconds: -5));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _seekRelative(const Duration(seconds: 5));
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player taking full screen
              SizedBox.expand(
                child: GestureDetector(
                  // Remove conflicting onTap - let controls handle tap-to-show/hide
                  onDoubleTapDown: (details) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final tapPosition = details.globalPosition.dx;
                    
                    if (tapPosition < screenWidth / 2) {
                      _seekRelative(const Duration(seconds: -10));
                      _showSeekIndicator(context, false);
                    } else {
                      _seekRelative(const Duration(seconds: 10));
                      _showSeekIndicator(context, true);
                    }
                  },
                  child: Video(
                    controller: _controller,
                    controls: NoVideoControls, // No built-in controls in fullscreen
                    subtitleViewConfiguration: const SubtitleViewConfiguration(
                      visible: false, // Disable built-in subtitles
                    ),
                    fit: BoxFit.contain, // This will maintain aspect ratio while filling available space
                  ),
                ),
              ),
              
              // Subtitle overlay for fullscreen (behind controls)
              if (_areSubtitlesEnabled) _buildFullscreenSubtitles(),
              
              // Custom fullscreen controls overlay (on top)
              _buildFullscreenControls(),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Get video aspect ratio for fullscreen display
  double _getVideoAspectRatio() {
    final width = _player.state.width;
    final height = _player.state.height;
    if (width != null && height != null && height > 0) {
      return width / height;
    }
    return 16 / 9; // Default aspect ratio
  }
  
  /// Build fullscreen controls overlay
  Widget _buildFullscreenControls() {
    return StreamBuilder<bool>(
      stream: _player.stream.playing,
      builder: (context, playingSnapshot) {
        return StreamBuilder<Duration>(
          stream: _player.stream.position,
          builder: (context, positionSnapshot) {
            return StreamBuilder<Duration>(
              stream: _player.stream.duration,
              builder: (context, durationSnapshot) {
                final isPlaying = playingSnapshot.data ?? _player.state.playing;
                final position = positionSnapshot.data ?? Duration.zero;
                final duration = durationSnapshot.data ?? _player.state.duration;
                
                return _FullscreenControlsWidget(
                  key: _fullscreenControlsKey,
                  isPlaying: isPlaying,
                  position: position,
                  duration: duration,
                  videoPath: widget.videoPath,
                  areSubtitlesEnabled: _areSubtitlesEnabled,
                  currentSpeed: _currentSpeed,
                  availableAudioTracks: _availableAudioTracks,
                  subtitles: _currentSubtitles,
                  secondarySubtitles: _currentSecondarySubtitles,
                  onExitFullscreen: _exitCustomFullscreen,
                  onToggleSubtitles: () {
                    setState(() {
                      _areSubtitlesEnabled = !_areSubtitlesEnabled;
                    });
                    if (_fullscreenOverlay != null) {
                      _fullscreenOverlay!.markNeedsBuild();
                    }
                  },
                  onSeek: (value) {
                    final newPosition = Duration(
                      milliseconds: (value * duration.inMilliseconds).round(),
                    );
                    _player.seek(newPosition);
                  },
                  onPlayPause: playOrPause,
                  onSeekRelative: _seekRelative,
                  onToggleMute: toggleMute,
                  onSpeedChange: (speed) {
                    setPlaybackSpeed(speed);
                    // Force rebuild of fullscreen overlay to update speed button display
                    if (_fullscreenOverlay != null) {
                      _fullscreenOverlay!.markNeedsBuild();
                    }
                  },
                  onAudioTrackChange: setAudioTrack,
                  onSeekToPreviousSubtitle: _seekToPreviousSubtitle,
                  onSeekToNextSubtitle: _seekToNextSubtitle,
                  formatDuration: _formatDuration,
                  onSubtitleMarked: widget.onSubtitleMarked,
                  onSubtitleCommentUpdated: widget.onSubtitleCommentUpdated,
                  player: _player,
                  originalContext: _originalContext, // Pass original context for dialogs
                  skipDurationSeconds: _skipDurationSeconds, // Pass skip duration
                  videoPlayerState: this, // Pass the video player state directly
                );
              },
            );
          },
        );
      },
    );
  }
  
  /// Build fullscreen subtitles overlay
  Widget _buildFullscreenSubtitles() {
    return StreamBuilder<Duration>(
      key: ValueKey('fullscreen_subtitle_${_subtitleFontSize}_$_subtitleFontFamily'),
      stream: _player.stream.position,
      builder: (context, snapshot) {
        // Use cached active subtitles (now lists) instead of recalculating
        final activeSubtitles = _currentActiveSubtitles;
        final activeSecondarySubtitles = _currentActiveSecondarySubtitles;
        
        final responsiveFontSize = _getResponsiveSubtitleFontSize();
        
        // Use new MultipleOverlappingSubtitlesWidget for intelligent positioning
        return Stack(
          children: [
            // Primary subtitles with intelligent positioning
            if (activeSubtitles.isNotEmpty)
              MultipleOverlappingSubtitlesWidget(
                subtitleTexts: activeSubtitles.map((s) => s.text).toList(),
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: responsiveFontSize + 4.0,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  fontFamily: _subtitleFontFamily,
                  background: _showSubtitleBackground
                  ? (Paint()..color = const Color.fromARGB(180, 0, 0, 0))
                  : null,
                  shadows: const [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                horizontalPadding: 40.0,
                verticalPadding: 30.0,
                topPadding: 30.0,
                isFullscreen: true,
                verticalOffset: _primarySubtitleVerticalPosition,
              ),
            
            // Secondary subtitles (always at top) - also handle positioning if needed
            if (activeSecondarySubtitles.isNotEmpty)
              MultipleOverlappingSubtitlesWidget(
                subtitleTexts: activeSecondarySubtitles.map((s) => s.text).toList(),
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: responsiveFontSize + 4.0,
                  fontWeight: FontWeight.normal,
                  height: 1.3,
                  fontFamily: _subtitleFontFamily,
                  background:
                      _showSubtitleBackground
                          ? (Paint()
                            ..color = const Color.fromARGB(180, 0, 0, 0))
                          : null,
                  shadows: const [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                horizontalPadding: 40.0,
                verticalPadding: 30.0,
                topPadding: 30.0,
                isFullscreen: true,
                verticalOffset: _secondarySubtitleVerticalPosition,
                forceTopPosition: true, // Always display secondary subtitles at top
                primarySubtitleTexts: activeSubtitles.map((s) => s.text).toList(), // Pass for collision detection
              ),
          ],
        );
      },
    );
  }
}
