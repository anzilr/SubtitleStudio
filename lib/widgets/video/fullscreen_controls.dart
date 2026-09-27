part of '../video_player_widget.dart';

// Custom fullscreen controls widget with auto-hide functionality
class _FullscreenControlsWidget extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String videoPath;
  final bool areSubtitlesEnabled;
  final double currentSpeed;
  final List<AudioTrack> availableAudioTracks;
  final List<Subtitle> subtitles;
  final List<Subtitle> secondarySubtitles;
  final VoidCallback onExitFullscreen;
  final VoidCallback onToggleSubtitles;
  final Function(double) onSeek;
  final VoidCallback onPlayPause;
  final Function(Duration) onSeekRelative;
  final VoidCallback onToggleMute;
  final Function(double) onSpeedChange;
  final Function(AudioTrack) onAudioTrackChange;
  final VoidCallback onSeekToPreviousSubtitle;
  final VoidCallback onSeekToNextSubtitle;
  final String Function(Duration) formatDuration;
  final Function(int, bool)? onSubtitleMarked;
  final Function(int, String?)? onSubtitleCommentUpdated;
  final Player player;
  final BuildContext? originalContext; // For showing dialogs over fullscreen
  final int skipDurationSeconds; // Skip duration parameter
  final VideoPlayerWidgetState? videoPlayerState; // Video player state for volume control

  const _FullscreenControlsWidget({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.videoPath,
    required this.areSubtitlesEnabled,
    required this.currentSpeed,
    required this.availableAudioTracks,
    required this.subtitles,
    required this.secondarySubtitles,
    required this.onExitFullscreen,
    required this.onToggleSubtitles,
    required this.onSeek,
    required this.onPlayPause,
    required this.onSeekRelative,
    required this.onToggleMute,
    required this.onSpeedChange,
    required this.onAudioTrackChange,
    required this.onSeekToPreviousSubtitle,
    required this.onSeekToNextSubtitle,
    required this.formatDuration,
    this.onSubtitleMarked,
    this.onSubtitleCommentUpdated,
    required this.player,
    this.originalContext, // For showing dialogs over fullscreen
    required this.skipDurationSeconds, // Add to constructor
    this.videoPlayerState, // Add video player state parameter
  });

  @override
  _FullscreenControlsWidgetState createState() => _FullscreenControlsWidgetState();
}

class _FullscreenControlsWidgetState extends State<_FullscreenControlsWidget> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _isCommentDialogOpen = false; // Track if comment dialog is currently visible
  
  // Cache active subtitle to avoid expensive searches every frame
  Subtitle? _cachedActiveSubtitle;
  Duration _cachedPosition = Duration.zero;
  SubtitleTimelineIndex _fullscreenSubtitleIndex =
      const SubtitleTimelineIndex.empty();

  @override
  void initState() {
    super.initState();
    _fullscreenSubtitleIndex = SubtitleTimelineIndex(widget.subtitles);
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_FullscreenControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.subtitles != oldWidget.subtitles) {
      _fullscreenSubtitleIndex = SubtitleTimelineIndex(widget.subtitles);
      _cachedActiveSubtitle = null;
      _cachedPosition = const Duration(milliseconds: -1000);
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    
    // Check if any volume slider is currently in use
    if (_VolumeSliderButtonState._isAnyVolumeSliderInUse) {
      debugPrint('Fullscreen controls: Volume slider in use, restarting timer instead of hiding');
      // Restart timer instead of hiding immediately
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_VolumeSliderButtonState._isAnyVolumeSliderInUse) {
          setState(() {
            _controlsVisible = false;
          });
        } else if (mounted) {
          // If volume slider still in use, restart timer again
          _resetHideTimer();
        }
      });
      return;
    }
    
    _hideTimer = Timer(const Duration(seconds: 4), () { // Increased from 3 to 4 seconds for better mouse hover experience
      if (mounted && !_VolumeSliderButtonState._isAnyVolumeSliderInUse) {
        setState(() {
          _controlsVisible = false;
        });
      } else if (mounted) {
        // If volume slider started during timer, restart timer
        _resetHideTimer();
      }
    });
  }

  void _toggleControls() {
    if (mounted) {
      setState(() {
        _controlsVisible = !_controlsVisible;
      });
      if (_controlsVisible) {
        _resetHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    }
  }

  void _showControls() {
    if (mounted) {
      setState(() {
        _controlsVisible = true;
      });
      _resetHideTimer();
    }
  }

  String _getFileName() {
    final path = widget.videoPath;
    
    // Handle SAF content URIs on Android
    if (Platform.isAndroid && path.startsWith('content://')) {
      try {
        // Convert SAF URI to display path, then extract filename
        final displayPath = SafPathConverter.normalizePath(path);
        
        if (kDebugMode) {
          print('VideoPlayer _getFileName: originalPath=$path');
          print('VideoPlayer _getFileName: displayPath=$displayPath');
        }
        
        // Extract filename from the normalized path
        final lastSlash = displayPath.lastIndexOf('/');
        final lastBackslash = displayPath.lastIndexOf('\\');
        final lastSeparator = lastSlash > lastBackslash ? lastSlash : lastBackslash;
        
        if (lastSeparator != -1 && lastSeparator < displayPath.length - 1) {
          final fileName = displayPath.substring(lastSeparator + 1);
          if (kDebugMode) {
            print('VideoPlayer _getFileName: extracted fileName=$fileName');
          }
          return fileName;
        }
        
        // If no separators found in display path, try to extract from original URI
        if (displayPath == path) {
          // Fallback: extract filename from URI path segments
          final uri = Uri.parse(path);
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            // Get the last segment and decode any URL encoding
            final lastSegment = Uri.decodeFull(pathSegments.last);
            // If it looks like a filename with extension, return it
            if (lastSegment.contains('.')) {
              if (kDebugMode) {
                print('VideoPlayer _getFileName: fallback fileName=$lastSegment');
              }
              return lastSegment;
            }
          }
        }
        
        return displayPath;
      } catch (e) {
        if (kDebugMode) {
          print('VideoPlayer _getFileName: SAF conversion error: $e');
        }
        // If SAF conversion fails, fall back to basic URI parsing
        try {
          final uri = Uri.parse(path);
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            final fallbackName = Uri.decodeFull(pathSegments.last);
            if (kDebugMode) {
              print('VideoPlayer _getFileName: URI fallback fileName=$fallbackName');
            }
            return fallbackName;
          }
        } catch (e2) {
          if (kDebugMode) {
            print('VideoPlayer _getFileName: URI parsing error: $e2');
          }
          // Ultimate fallback: return the path as-is
        }
      }
    }
    
    // Handle regular file paths
    final lastSlash = path.lastIndexOf('/');
    final lastBackslash = path.lastIndexOf('\\');
    final lastSeparator = lastSlash > lastBackslash ? lastSlash : lastBackslash;
    if (lastSeparator != -1 && lastSeparator < path.length - 1) {
      final fileName = path.substring(lastSeparator + 1);
      if (kDebugMode && Platform.isAndroid) {
        print('VideoPlayer _getFileName: regular path fileName=$fileName');
      }
      return fileName;
    }
    
    if (kDebugMode && Platform.isAndroid) {
      print('VideoPlayer _getFileName: returning original path=$path');
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showControls(), // Show controls on mouse hover
      onExit: (_) => _resetHideTimer(), // Reset hide timer when mouse leaves
      onHover: (_) => _showControls(), // Show controls on mouse movement
      child: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        onDoubleTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPosition = details.globalPosition.dx;
          
          // Left third of screen - skip backward
          if (tapPosition < screenWidth / 3) {
            final currentPosition = widget.player.state.position;
            final newPosition = currentPosition - Duration(seconds: widget.skipDurationSeconds);
            widget.player.seek(newPosition.isNegative ? Duration.zero : newPosition);
            _showControls();
          } 
          // Right third of screen - skip forward
          else if (tapPosition > (2 * screenWidth / 3)) {
            final currentPosition = widget.player.state.position;
            final duration = widget.player.state.duration;
            final newPosition = currentPosition + Duration(seconds: widget.skipDurationSeconds);
            widget.player.seek(newPosition > duration ? duration : newPosition);
            _showControls();
          }
          // Middle third - do nothing (let center controls handle play/pause)
        },
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
              child: Stack(
            children: [
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Reduced horizontal from 16 to 8
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: widget.onExitFullscreen,
                        ),
                        const SizedBox(width: 8), // Reduced from 16 to 8
                        Expanded(
                          child: Text(
                            _getFileName(),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Center play/pause and skip buttons
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Previous subtitle skip
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40),
                      onPressed: () {
                        debugPrint('FullscreenControls: Previous subtitle button pressed');
                        widget.onSeekToPreviousSubtitle();
                        _showControls();
                      },
                    ),
                    
                    // Skip backward
                    _FullscreenSkipButton(
                      icon: Icons.fast_rewind,
                      size: 48,
                      onPressed: () {
                        widget.onSeekRelative(Duration(seconds: -widget.skipDurationSeconds));
                        _showControls();
                      },
                      onHoldSkip: () {
                        widget.onSeekRelative(const Duration(milliseconds: -500));
                        _showControls();
                      },
                    ),
                    
                    // Play/Pause
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: StreamBuilder<bool>(
                        stream: widget.player.stream.playing,
                        initialData: widget.player.state.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? widget.player.state.playing;
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 60,
                            ),
                            onPressed: () {
                              widget.onPlayPause();
                              _showControls();
                            },
                          );
                        },
                      ),
                    ),
                    
                    // Skip forward
                    _FullscreenSkipButton(
                      icon: Icons.fast_forward,
                      size: 48,
                      onPressed: () {
                        widget.onSeekRelative(Duration(seconds: widget.skipDurationSeconds));
                        _showControls();
                      },
                      onHoldSkip: () {
                        widget.onSeekRelative(const Duration(milliseconds: 500));
                        _showControls();
                      },
                    ),
                    
                    // Next subtitle skip
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white, size: 40),
                      onPressed: () {
                        debugPrint('FullscreenControls: Next subtitle button pressed');
                        widget.onSeekToNextSubtitle();
                        _showControls();
                      },
                    ),
                  ],
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Reduced from 16.0 to 8.0 for low-res displays
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Seek bar
                        Row(
                          children: [
                            Text(
                              widget.formatDuration(widget.position),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(width: 8), // Reduced from 16 to 8
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.blue,
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                  thumbColor: Colors.blue,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                ),
                                child: Slider(
                                  value: widget.duration.inMilliseconds > 0 
                                      ? (widget.position.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: (value) {
                                    widget.onSeek(value);
                                    _showControls();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8), // Reduced from 16 to 8
                            Text(
                              widget.formatDuration(widget.duration),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12), // Reduced from 16 to 12
                        
                        // Control buttons
                        Row(
                          children: [
                            // Left side buttons: volume, subtitle, audio track, speed control
                            // Volume slider control (vertical slider like normal controls)
                            _buildVolumeButton(),
                            
                            const SizedBox(width: 8),
                            
                            // Subtitle toggle
                            IconButton(
                              icon: Icon(
                                widget.areSubtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                widget.onToggleSubtitles();
                                _showControls();
                              },
                            ),
                            
                            // Audio track control - wrapped in StreamBuilder for state updates
                            StreamBuilder<Track>(
                              stream: widget.player.stream.track,
                              builder: (context, trackSnapshot) {
                                return _buildAudioTrackButton();
                              },
                            ),
                            
                            const SizedBox(width: 4), // Reduced from 8 to 4
                            
                            // Speed control - will update when state changes
                            _buildSpeedButton(),
                            
                            const SizedBox(width: 4), // Reduced from 8 to 4
                            
                            // Mark/Unmark current subtitle line button
                            _buildMarkButton(),
                            
                            const Spacer(), // Push fullscreen button to the right
                            
                            // Fullscreen exit button on the right
                            IconButton(
                              icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                              onPressed: () {
                                widget.onExitFullscreen();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    ); // Close MouseRegion
  }

  /// Build speed control button that cycles through speeds
  Widget _buildSpeedButton() {
    String speedText = '${widget.currentSpeed}x';
    if (widget.currentSpeed == 1.0) {
      speedText = '1x';
    } else if (widget.currentSpeed == widget.currentSpeed.toInt().toDouble()) {
      speedText = '${widget.currentSpeed.toInt()}x';
    }

    return GestureDetector(
      onTap: () {
        _cycleSpeed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.currentSpeed != 1.0 ? Theme.of(context).primaryColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              speedText,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleSpeed() {
    // Available speed options
    final speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    
    // Find current speed index
    int currentIndex = speedOptions.indexWhere((speed) => speed == widget.currentSpeed);
    
    // If not found, default to normal speed (1.0x)
    if (currentIndex == -1) {
      currentIndex = 3; // 1.0x is at index 3
    }
    
    // Move to next speed, cycling back to start if at end
    int nextIndex = (currentIndex + 1) % speedOptions.length;
    double nextSpeed = speedOptions[nextIndex];
    
    // Apply the new speed
    widget.onSpeedChange(nextSpeed);
    
    // Force a rebuild to update the speed button display
    if (mounted) {
      setState(() {});
    }
    
    _showControls();
  }

  /// Get cached active subtitle to avoid expensive searches every frame
  /// When multiple subtitles overlap, returns the first one for marking operations
  Subtitle? _getCachedActiveSubtitle() {
    final positionDiff =
        (widget.position - _cachedPosition).inMilliseconds.abs();

    if (positionDiff > 100) {
      final activeSubtitles =
          _fullscreenSubtitleIndex.findActive(widget.position);
      _cachedActiveSubtitle =
          activeSubtitles.isEmpty ? null : activeSubtitles.first;
      _cachedPosition = widget.position;
    }

    return _cachedActiveSubtitle;
  }

  /// Build mark/unmark control button for current subtitle line
  Widget _buildMarkButton() {
    // Use cached active subtitle to avoid expensive searches every frame
    final activeSubtitle = _getCachedActiveSubtitle();
    final isMarked = activeSubtitle?.marked ?? false;
    
    // Minimal debug logging (only when subtitle changes)
    if (activeSubtitle != null && activeSubtitle != _cachedActiveSubtitle) {
      debugPrint('FullscreenMark: subtitle ${activeSubtitle.index} marked=$isMarked at position ${widget.position.inSeconds}s');
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          // Handle mouse right-click for comment dialog
          if (event.kind == PointerDeviceKind.mouse && 
              event.buttons == kSecondaryMouseButton && 
              activeSubtitle != null && isMarked) {
            _showCommentDialog(activeSubtitle);
          }
        },
        child: GestureDetector(
          onTap: activeSubtitle != null ? () {
            // Toggle mark status and trigger rebuild
            _toggleMarkCurrentSubtitle(activeSubtitle);
          } : null,
          onLongPress: activeSubtitle != null && isMarked ? () {
            // Show comment dialog for marked lines (touch devices)
            _showCommentDialog(activeSubtitle);
          } : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMarked ? Icons.bookmark_added : Icons.bookmark_add_outlined,
              color: activeSubtitle != null 
                ? (isMarked ? Colors.red : Colors.white) 
                : Colors.grey,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
  
  // Method to toggle mark status using the callback
  void _toggleMarkCurrentSubtitle(Subtitle subtitle) {
    debugPrint('_toggleMarkCurrentSubtitle: Toggling subtitle ${subtitle.index}');
    debugPrint('  - Current marked state: ${subtitle.marked}');
    debugPrint('  - Will change to: ${!subtitle.marked}');
    debugPrint('  - Callback exists: ${widget.onSubtitleMarked != null}');
    
    if (widget.onSubtitleMarked != null) {
      final newMarked = !subtitle.marked;
      debugPrint('  - Calling onSubtitleMarked callback with index ${subtitle.index} and marked=$newMarked');
      widget.onSubtitleMarked!(subtitle.index, newMarked);
    } else {
      debugPrint('  - WARNING: No onSubtitleMarked callback provided!');
    }
    
    // Show the controls to provide visual feedback
    _showControls();
  }

  // Public method to trigger comment dialog from external keyboard shortcuts
  void showCommentDialogForSubtitle(Subtitle subtitle, {
    String? originalText,
    String? editedText,
  }) {
    // Don't open a new dialog if one is already visible
    if (_isCommentDialogOpen) {
      return;
    }
    
    debugPrint('showCommentDialogForSubtitle: Triggering fullscreen comment dialog for subtitle ${subtitle.index}');
    _showCommentDialog(subtitle, originalText: originalText, editedText: editedText);
  }

  // Method to show comment dialog for marked subtitle
  void _showCommentDialog(Subtitle subtitle, {
    String? originalText,
    String? editedText,
  }) {
    debugPrint('_showCommentDialog: Opening comment dialog for subtitle ${subtitle.index} - "${subtitle.text.substring(0, subtitle.text.length.clamp(0, 30))}..."');
    _showControls(); // Keep controls visible during dialog
    
    // Use original context if available, otherwise use current context
    final dialogContext = widget.originalContext ?? context;
    
    // Since we're in _FullscreenControlsWidget, we're already in fullscreen mode
    // So we always need to use the fullscreen comment dialog with orientation handling
    _showFullscreenCommentDialog(subtitle, dialogContext, 
      originalText: originalText, editedText: editedText);
  }

  // Method to show comment dialog specifically for fullscreen mode using custom overlay
  void _showFullscreenCommentDialog(Subtitle subtitle, BuildContext dialogContext, {
    String? originalText,
    String? editedText,
  }) async {
    // Mark dialog as open
    setState(() => _isCommentDialogOpen = true);
    
    // Store the current playing state before showing dialog
    final wasPlaying = widget.player.state.playing;
    debugPrint('Fullscreen comment dialog opening - video was ${wasPlaying ? 'playing' : 'paused'}');
    debugPrint('Comment dialog subtitle data:');
    debugPrint('  - originalText: ${originalText ?? 'null'}');
    debugPrint('  - editedText: ${editedText ?? 'null'}');
    debugPrint('  - subtitle.text: ${subtitle.text}');
    
    // Pause video if it was playing when comment dialog opens
    if (wasPlaying) {
      widget.player.pause();
      debugPrint('Paused video for fullscreen comment input');
    }
    
    // Store current orientation preferences before changing to portrait for better comment input
    List<DeviceOrientation>? originalOrientations;
    
    // Check if we're in landscape (likely fullscreen)
    final orientation = MediaQuery.of(dialogContext).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    // If in landscape, store current orientations and switch to portrait
    if (isLandscape) {
      originalOrientations = [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
      
      debugPrint('Switching to portrait for comment dialog');
      // Force portrait orientation for better comment input experience
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Wait for the first frame rendered with the new orientation.
      await WidgetsBinding.instance.endOfFrame;
    }

    // Create overlay entry for the bottom modal sheet to ensure it appears above fullscreen
    OverlayEntry? dialogOverlay;
    
    // Helper function to safely remove overlay and restore orientation
    Future<void> safeRemoveOverlay() async {
      try {
        dialogOverlay?.remove();
        dialogOverlay = null;
        debugPrint('Removed dialog overlay');
      } catch (e) {
        // Ignore removal errors (overlay might already be removed)
        debugPrint('Error removing dialog overlay: $e');
      }
      
      // Mark dialog as closed
      if (mounted) {
        setState(() => _isCommentDialogOpen = false);
      }
      
      // Resume video if it was playing before dialog opened
      if (wasPlaying) {
        widget.player.play();
        debugPrint('Resumed video after fullscreen comment dialog closed');
      }
      
      // Restore original orientation when dialog is dismissed.
      // Capture the nullable value before the async gap so Dart can keep a
      // non-nullable local reference across the await.
      final orientationsToRestore = originalOrientations;
      if (orientationsToRestore != null) {
        try {
          // Let overlay removal render before restoring the prior orientation.
          await WidgetsBinding.instance.endOfFrame;
          await SystemChrome.setPreferredOrientations(orientationsToRestore);
          debugPrint('Restored original orientation after comment dialog');
        } catch (e) {
          debugPrint('Error restoring orientation: $e');
        }
      }
    }
    
    dialogOverlay = OverlayEntry(
      builder: (overlayContext) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Handle escape key to close the comment dialog
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            debugPrint('Escape key pressed - dismissing fullscreen comment dialog');
            unawaited(safeRemoveOverlay());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              // Dismiss dialog when tapping outside
              debugPrint('Dismissing comment dialog via background tap');
              unawaited(safeRemoveOverlay());
            },
            child: Container(
              color: Colors.black54, // Semi-transparent background
              child: GestureDetector(
                onTap: () {}, // Prevent tap from propagating to parent
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(overlayContext).viewInsets.bottom + 20, // Add extra space above keyboard
                      left: 16,
                      right: 16,
                      top: MediaQuery.of(overlayContext).padding.top + 50, // Add top padding to prevent dialog from going offscreen
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 600, // Restore normal width constraint
                        maxHeight: MediaQuery.of(overlayContext).size.height * 0.8, // Limit height to 80% of screen
                      ),
                      child: CommentDialog(
                      existingComment: subtitle.comment,
                      isOverlayMode: true, // Indicate this is used in overlay mode
                      originalText: originalText ?? subtitle.text, // Use passed originalText or fallback to subtitle.text
                      editedText: editedText, // Use passed editedText if available
                      subtitleIndex: subtitle.index, // Pass subtitle index
                      onCommentSaved: (comment) async {
                        debugPrint('═══════════════════════════════════');
                        debugPrint('FULLSCREEN COMMENT SAVE CALLBACK TRACE:');
                        debugPrint('  ► Original subtitle passed to dialog:');
                        debugPrint('    - subtitle.index: ${subtitle.index}');
                        debugPrint('    - subtitle.text: "${subtitle.text.substring(0, subtitle.text.length.clamp(0, 50))}..."');
                        debugPrint('    - subtitle.marked: ${subtitle.marked}');
                        debugPrint('    - subtitle object hashCode: ${subtitle.hashCode}');
                        debugPrint('  ► Comment being saved: "$comment"');
                        debugPrint('  ► Callback status:');
                        debugPrint('    - onSubtitleCommentUpdated exists: ${widget.onSubtitleCommentUpdated != null}');
                        debugPrint('    - Widget mounted: $mounted');
                        debugPrint('  ► About to call parent callback...');
                        
                        // If the subtitle is not marked, mark it first
                        if (mounted && !subtitle.marked && widget.onSubtitleMarked != null) {
                          try {
                            debugPrint('  ► Marking subtitle before saving comment');
                            await _awaitCallbackResult(
                              widget.onSubtitleMarked!(subtitle.index, true),
                            );
                          } catch (e) {
                            debugPrint('  ► ERROR marking subtitle: $e');
                          }
                        }
                        
                        // Update subtitle comment immediately 
                        if (mounted && widget.onSubtitleCommentUpdated != null) {
                          try {
                            debugPrint('  ► CALLING PARENT CALLBACK:');
                            debugPrint('    - Index parameter: ${subtitle.index}');
                            debugPrint('    - Comment parameter: "$comment"');
                            
                            await _awaitCallbackResult(
                              widget.onSubtitleCommentUpdated!(
                                subtitle.index,
                                comment,
                              ),
                            );

                            debugPrint('  ► Parent callback completed successfully');
                          } catch (e) {
                            debugPrint('  ► ERROR in parent callback: $e');
                          }
                        } else {
                          debugPrint('  ► CALLBACK NOT CALLED - mounted=$mounted, callback exists=${widget.onSubtitleCommentUpdated != null}');
                        }
                        debugPrint('═══════════════════════════════════');
                        
                        debugPrint('Closing comment dialog overlay after save');
                        await safeRemoveOverlay();
                      },
                      onCommentDeleted: () async {
                        debugPrint(
                          'Comment delete initiated: subtitleIndex=${subtitle.index}',
                        );

                        if (mounted && widget.onSubtitleCommentUpdated != null) {
                          try {
                            await _awaitCallbackResult(
                              widget.onSubtitleCommentUpdated!(
                                subtitle.index,
                                null,
                              ),
                            );
                            debugPrint(
                              'Fullscreen comment deleted successfully from database',
                            );
                          } catch (e) {
                            debugPrint('Error deleting subtitle comment: $e');
                          }
                        }

                        debugPrint('Closing comment dialog overlay after delete');
                        await safeRemoveOverlay();
                      },
                      onCancelled: () {
                        debugPrint('Comment dialog cancelled by user');
                        unawaited(safeRemoveOverlay());
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
        )
    );
    
    // Insert the dialog overlay above the fullscreen overlay
    try {
      if (dialogOverlay != null) {
        Overlay.of(dialogContext, rootOverlay: true).insert(dialogOverlay!);
      }
    } catch (e) {
      debugPrint('Error inserting dialog overlay: $e');
      safeRemoveOverlay();
    }
  }

  /// Build audio track control button that cycles through tracks
  Widget _buildAudioTrackButton() {
    final hasMultipleTracks = widget.availableAudioTracks.length > 1;

    if (!hasMultipleTracks) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audiotrack, color: Colors.grey, size: 16),
            SizedBox(width: 4),
            Text('1 track', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    // Get current track info for display
    final currentTrack = widget.player.state.track.audio;
    String displayText = 'Track ${currentTrack.id}';
    if (currentTrack.id == 'auto') {
      displayText = 'Auto';
    } else if (currentTrack.id == 'no') {
      displayText = 'Off';
    } else if (currentTrack.language?.isNotEmpty == true) {
      displayText = currentTrack.language!.toUpperCase();
    } else if (currentTrack.title?.isNotEmpty == true) {
      displayText = currentTrack.title!;
    }

    return GestureDetector(
      onTap: () {
        _cycleAudioTrack();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audiotrack, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(displayText, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _cycleAudioTrack() {
    if (widget.availableAudioTracks.length <= 1) return;
    
    // Find current track index
    final currentTrack = widget.player.state.track.audio;
    int currentIndex = widget.availableAudioTracks.indexWhere((track) => track.id == currentTrack.id);
    
    // If not found, start from first track
    if (currentIndex == -1) {
      currentIndex = 0;
    } else {
      // Move to next track, cycling back to start if at end
      currentIndex = (currentIndex + 1) % widget.availableAudioTracks.length;
    }
    
    // Apply the new audio track
    final nextTrack = widget.availableAudioTracks[currentIndex];
    widget.onAudioTrackChange(nextTrack);
    _showControls();
  }

  /// Build volume control with vertical slider (similar to normal player controls)
  Widget _buildVolumeButton() {
    return _FullscreenVolumeSliderButton(
      player: widget.player,
      videoPlayerState: widget.videoPlayerState,
      onShowControls: _showControls,
    );
  }
}

// Repeat mode button for video controls
class _RepeatButton extends StatefulWidget {
  const _RepeatButton();

  @override
  _RepeatButtonState createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton> {
  bool _isLongPressing = false;
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    
    if (videoPlayerState == null) {
      return const SizedBox.shrink();
    }
    
    // Use StatefulBuilder to force rebuilds when state changes
    return StatefulBuilder(
      builder: (context, setButtonState) {
        final isRepeatEnabled = videoPlayerState.widget.isRepeatModeEnabled;
        
        return MouseRegion(
          onEnter: (_) => setButtonState(() => _isHovered = true),
          onExit: (_) => setButtonState(() => _isHovered = false),
          child: GestureDetector(
            onTap: () {
              if (!_isLongPressing && videoPlayerState.widget.onRepeatModeToggled != null) {
                videoPlayerState.widget.onRepeatModeToggled!(!isRepeatEnabled);
                // Force immediate rebuild using StatefulBuilder
                setButtonState(() {});
              }
            },
            onDoubleTap: () async {
              setButtonState(() {
                _isLongPressing = true;
              });
              try {
                await _showRepeatRangeDialog(context);
              } finally {
                if (mounted) {
                  setButtonState(() {
                    _isLongPressing = false;
                  });
                }
              }
            },
            onLongPress: () async {
              setButtonState(() {
                _isLongPressing = true;
              });
              try {
                await _showRepeatRangeDialog(context);
              } finally {
                if (mounted) {
                  setButtonState(() {
                    _isLongPressing = false;
                  });
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32, // Increased size for better usability
              height: 32, // Increased size for better usability
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLongPressing 
                  ? Colors.orange.withValues(alpha: 0.3) 
                  : _isHovered 
                    ? Colors.white.withValues(alpha: 0.2) 
                    : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.repeat_one,
                size: 22, // Increased icon size
                color: isRepeatEnabled 
                  ? Colors.orange 
                  : _isHovered 
                    ? Colors.blue.shade200 
                    : Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _showRepeatRangeDialog(BuildContext context) async {
    final editScreenState =
        context.findAncestorStateOfType<EditSubtitleScreenState>();
    if (editScreenState == null) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => RepeatRangeDialog(
        editScreenState: editScreenState,
      ),
    );
  }
}
