part of '../video_player_widget.dart';

/// Custom video controls widget that matches MaterialVideoControls design
/// with proper mouse hover functionality
class CustomVideoControls extends StatefulWidget {
  final Player player;
  final List<Subtitle> subtitles;
  final List<Subtitle> secondarySubtitles;
  final Function(int, bool)? onSubtitleMarked;
  final Function(int, String?)? onSubtitleCommentUpdated;
  final Function(bool)? onPlayStateChanged;
  final Function(bool)? onRepeatModeToggled;
  final bool isRepeatModeEnabled;
  final int skipDurationSeconds;

  const CustomVideoControls({
    super.key,
    required this.player,
    required this.subtitles,
    required this.secondarySubtitles,
    this.onSubtitleMarked,
    this.onSubtitleCommentUpdated,
    this.onPlayStateChanged,
    this.onRepeatModeToggled,
    this.isRepeatModeEnabled = false,
    required this.skipDurationSeconds,
  });

  @override
  CustomVideoControlsState createState() => CustomVideoControlsState();
}

class CustomVideoControlsState extends State<CustomVideoControls> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _isHovering = false;
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_isHovering && !_isSeeking) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isHovering && !_isSeeking) {
          // Check if any volume slider is currently in use
          if (!_VolumeSliderButtonState._isAnyVolumeSliderInUse) {
            setState(() {
              _controlsVisible = false;
            });
          } else {
            // If volume slider is in use, restart the timer
            _resetHideTimer();
          }
        }
      });
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

  void _onHoverStart() {
    _isHovering = true;
    _showControls();
  }

  void _onHoverEnd() {
    _isHovering = false;
    _resetHideTimer();
  }

  void _onSeekStart() {
    _isSeeking = true;
    _showControls();
  }

  void _onSeekEnd() {
    _isSeeking = false;
    _resetHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverStart(),
      onExit: (_) => _onHoverEnd(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          debugPrint('CustomVideoControls: Single tap detected');
          if (_controlsVisible) {
            setState(() {
              _controlsVisible = false;
            });
          } else {
            _showControls();
          }
        },
        onDoubleTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPosition = details.globalPosition.dx;
          
          debugPrint('CustomVideoControls: Double tap at position ${tapPosition}, screen width: ${screenWidth}');
          debugPrint('CustomVideoControls: Skip duration: ${widget.skipDurationSeconds} seconds');
          
          // Left third of screen - skip backward
          if (tapPosition < screenWidth / 3) {
            debugPrint('CustomVideoControls: Skip backward by ${widget.skipDurationSeconds} seconds');
            final currentPosition = widget.player.state.position;
            final newPosition = currentPosition - Duration(seconds: widget.skipDurationSeconds);
            debugPrint('CustomVideoControls: Current position: ${currentPosition.inSeconds}s, new position: ${newPosition.inSeconds}s');
            widget.player.seek(newPosition.isNegative ? Duration.zero : newPosition);
            _showControls();
          } 
          // Right third of screen - skip forward
          else if (tapPosition > (2 * screenWidth / 3)) {
            debugPrint('CustomVideoControls: Skip forward by ${widget.skipDurationSeconds} seconds');
            final currentPosition = widget.player.state.position;
            final duration = widget.player.state.duration;
            final newPosition = currentPosition + Duration(seconds: widget.skipDurationSeconds);
            debugPrint('CustomVideoControls: Current position: ${currentPosition.inSeconds}s, new position: ${newPosition.inSeconds}s');
            widget.player.seek(newPosition > duration ? duration : newPosition);
            _showControls();
          }
          // Middle third - do nothing (let center controls handle play/pause)
          else {
            debugPrint('CustomVideoControls: Double tap in center area - ignoring');
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Stack(
            children: [
              // Always present invisible touch area for gestures
              Positioned.fill(
                child: Container(
                  color: Colors.transparent,
                ),
              ),
              // Controls that appear/disappear
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _controlsVisible ? _buildControls() : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Stack(
      children: [
        // Top controls
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Spacer(),
                _SettingsButton(),
                const SizedBox(width: 8),
                _FullscreenButton(),
              ],
            ),
          ),
        ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Control buttons - positioned on top with reduced spacing
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 1.0), // Reduced top padding from 8 to 4, bottom from 2 to 1
                  child: Row(
                    children: [
                      _TimeDisplay(),
                      const Spacer(),
                      if (widget.onRepeatModeToggled != null) _RepeatButton(),
                      if (widget.onRepeatModeToggled != null) const SizedBox(width: 8),
                      _VolumeSliderButton(),
                      const SizedBox(width: 8),
                      _SubtitleToggleButton(),
                    ],
                  ),
                ),
                // Progress bar - positioned at the bottom with reduced spacing
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0), // Reduced bottom margin from 8 to 4 for tighter layout
                  child: _buildProgressBar(),
                ),
              ],
            ),
          ),
        ),

        // Play/Pause and skip buttons in center
        Center(
          child: StreamBuilder<bool>(
            stream: widget.player.stream.playing,
            initialData: widget.player.state.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? widget.player.state.playing;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Backward button
                  _CenterControlButton(
                    icon: Icons.fast_rewind,
                    size: 40.0,
                    onTap: () {
                      final currentPosition = widget.player.state.position;
                      final newPosition = currentPosition - Duration(seconds: widget.skipDurationSeconds);
                      widget.player.seek(newPosition.isNegative ? Duration.zero : newPosition);
                    },
                    onHoldSkip: () {
                      final currentPosition = widget.player.state.position;
                      final newPosition = currentPosition - const Duration(milliseconds: 500);
                      widget.player.seek(newPosition.isNegative ? Duration.zero : newPosition);
                    },
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Play/Pause button (without background)
                  _CenterControlButton(
                    icon: isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 56.0,
                    extraShadows: true,
                    onTap: () {
                      if (isPlaying) {
                        widget.player.pause();
                      } else {
                        widget.player.play();
                      }
                      widget.onPlayStateChanged?.call(!isPlaying);
                    },
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Forward button
                  _CenterControlButton(
                    icon: Icons.fast_forward,
                    size: 40.0,
                    onTap: () {
                      final currentPosition = widget.player.state.position;
                      final duration = widget.player.state.duration;
                      final newPosition = currentPosition + Duration(seconds: widget.skipDurationSeconds);
                      widget.player.seek(newPosition > duration ? duration : newPosition);
                    },
                    onHoldSkip: () {
                      final currentPosition = widget.player.state.position;
                      final duration = widget.player.state.duration;
                      final newPosition = currentPosition + const Duration(milliseconds: 500);
                      widget.player.seek(newPosition > duration ? duration : newPosition);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: widget.player.stream.duration,
          builder: (context, durationSnapshot) {
            // Use fallback to player state if stream data is invalid
            final position = (positionSnapshot.data?.inMilliseconds ?? 0) > 0 
                ? positionSnapshot.data!
                : widget.player.state.position;
            final duration = (durationSnapshot.data?.inMilliseconds ?? 0) > 0 
                ? durationSnapshot.data!
                : widget.player.state.duration;
            
            // REMOVED: Excessive debug logging that fires on every video frame (~60fps)
            // This causes severe performance degradation and log spam
            // Re-enable only for specific debugging sessions with throttling
            
            final progress = duration.inMilliseconds > 0 
                ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                : 0.0;

            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                thumbColor: Colors.blue,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                trackHeight: 4.0,
              ),
              child: Slider(
                value: progress,
                onChanged: (value) {
                  _onSeekStart();
                  
                  // Ensure we have valid duration before seeking
                  if (duration.inMilliseconds > 0 && value >= 0.0 && value <= 1.0) {
                    final newPositionMs = (value * duration.inMilliseconds).round();
                    final newPosition = Duration(milliseconds: newPositionMs);
                    
                    if (kDebugMode) {
                      debugPrint('Seekbar - Seeking to: ${newPosition.inMilliseconds}ms (value: $value, duration: ${duration.inMilliseconds}ms)');
                    }
                    
                    widget.player.seek(newPosition);
                  } else {
                    if (kDebugMode) {
                      debugPrint('Seekbar - Invalid seek: value=$value, duration=${duration.inMilliseconds}ms');
                    }
                  }
                  _showControls();
                },
                onChangeEnd: (value) {
                  _onSeekEnd();
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Widget _TimeDisplay() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, positionSnapshot) {
        // Get current position, fallback to state.position if stream data is null or zero
        final position = (positionSnapshot.data?.inMilliseconds ?? 0) > 0 
            ? positionSnapshot.data!
            : widget.player.state.position;
        
        return StreamBuilder<Duration>(
          stream: widget.player.stream.duration,
          builder: (context, durationSnapshot) {
            // Use player.state.duration if stream value is zero or null
            final duration = (durationSnapshot.data?.inMilliseconds ?? 0) > 0 
                ? durationSnapshot.data! 
                : widget.player.state.duration;
            
            // Format the time strings
            final positionStr = _formatDuration(position);
            final durationStr = _formatDuration(duration);
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced padding for low-res displays
              child: Text(
                '$positionStr / $durationStr',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Custom center control button with hover effects and hold functionality
class _CenterControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onHoldSkip; // Callback for 1-second skips while holding
  final bool extraShadows;

  const _CenterControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.onHoldSkip,
    this.extraShadows = false,
  });

  @override
  _CenterControlButtonState createState() => _CenterControlButtonState();
}

class _CenterControlButtonState extends State<_CenterControlButton> {
  bool _isHovered = false;
  Timer? _holdTimer;

  void _startHolding() {
    if (widget.onHoldSkip != null) {
      // Immediately skip once, then continue with fast periodic skips
      widget.onHoldSkip!();
      _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        widget.onHoldSkip!();
      });
    }
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _stopHolding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: (_) => _startHolding(),
        onLongPressEnd: (_) => _stopHolding(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovered ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            color: _isHovered ? Colors.blue.shade200 : Colors.white,
            size: widget.size,
            shadows: widget.extraShadows ? [
              Shadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4.0,
                offset: const Offset(0, 1),
              ),
            ] : [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom fullscreen skip button with hold functionality
class _FullscreenSkipButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final VoidCallback onHoldSkip;

  const _FullscreenSkipButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    required this.onHoldSkip,
  });

  @override
  _FullscreenSkipButtonState createState() => _FullscreenSkipButtonState();
}

class _FullscreenSkipButtonState extends State<_FullscreenSkipButton> {
  Timer? _holdTimer;

  void _startHolding() {
    // Immediately skip once, then continue with fast periodic skips
    widget.onHoldSkip();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      widget.onHoldSkip();
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _stopHolding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onLongPressStart: (_) => _startHolding(),
      onLongPressEnd: (_) => _stopHolding(),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: widget.size,
        ),
      ),
    );
  }
}
