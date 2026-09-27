part of '../video_player_widget.dart';

class _VolumeSliderButton extends StatefulWidget {
  const _VolumeSliderButton();

  @override
  _VolumeSliderButtonState createState() => _VolumeSliderButtonState();
}

class _VolumeSliderButtonState extends State<_VolumeSliderButton> with TickerProviderStateMixin {
  // Static field to track if any volume slider is currently in use across all instances
  static bool _isAnyVolumeSliderInUse = false;
  
  bool _showSlider = false;
  bool _isSliding = false; // Track if user is actively sliding
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  OverlayEntry? _overlayEntry; // Use overlay for higher z-index
  Timer? _hideTimer; // Timer to auto-hide slider

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideSlider();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (!mounted) return;
    
    try {
      final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
      final player = videoPlayerState?._player;
      
      if (player != null) {
        final currentVolume = videoPlayerState?._currentVolume ?? 100.0;
        if (currentVolume > 0) {
          _setVolume(0);
        } else {
          _setVolume(100);
        }
      }
    } catch (e) {
      debugPrint('Volume slider error in _toggleMute: $e');
    }
  }

  void _setVolume(double volume) async {
    // Check mounted state before accessing context
    if (!mounted) return;
    
    try {
      final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
      final player = videoPlayerState?._player;
      
      if (player != null && mounted) {
        player.setVolume(volume);
        // Update the global volume state
        if (videoPlayerState != null && videoPlayerState.mounted) {
          videoPlayerState.setState(() {
            videoPlayerState._currentVolume = volume;
          });
        }
        // Rebuild the overlay to show updated volume
        if (_overlayEntry != null && mounted) {
          _overlayEntry!.markNeedsBuild();
        }
        // Save volume to preferences
        await _preferencesRepository.setVideoVolume(volume);
      }
    } catch (e) {
      debugPrint('Volume slider error in _setVolume: $e');
    }
  }

  void _toggleSlider() {
    if (!mounted) return;
    
    try {
      setState(() {
        _showSlider = !_showSlider;
      });
      
      if (_showSlider) {
        _showVolumeSlider();
        _animationController.forward();
        _startHideTimer();
      } else {
        _hideSlider();
        _animationController.reverse();
        _cancelHideTimer();
      }
    } catch (e) {
      // Silently handle setState errors during widget disposal
    }
  }

  void _startHideTimer() {
    _cancelHideTimer();
    if (!_isSliding && mounted) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isSliding) {
          _hideSlider();
        }
      });
    }
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _showVolumeSlider() {
    if (_overlayEntry != null || !mounted) return;

    try {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      
      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: position.dx + (size.width / 2) - 25, // Center the slider over the button
          bottom: MediaQuery.of(context).size.height - position.dy + 8, // Position above button
          child: Material(
            color: Colors.transparent,
            child: _buildVerticalVolumeSlider(),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    } catch (e) {
      debugPrint('Volume slider error in _showVolumeSlider: $e');
    }
  }

  void _hideSlider() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    // Clear global flag when hiding slider
    _VolumeSliderButtonState._isAnyVolumeSliderInUse = false;
    
    // Check mounted before attempting setState to avoid lifecycle errors during rebuilds
    if (!mounted) return;
    
    try {
      setState(() {
        _showSlider = false;
      });
      _animationController.reverse();
    } catch (e) {
      // Silently handle setState errors during widget disposal
      // This can happen when keyboard animations trigger parent rebuilds
    }
  }

  void _onSliderStart() {
    if (!mounted) return;
    
    try {
      setState(() {
        _isSliding = true;
      });
    } catch (e) {
      // Silently handle setState errors during widget disposal
    }
    
    // Set global flag to prevent main controls from hiding
    _VolumeSliderButtonState._isAnyVolumeSliderInUse = true;
    _cancelHideTimer(); // Don't hide while sliding
    debugPrint('Volume slider: Started sliding - keeping controls visible');
  }

  void _onSliderEnd() {
    if (!mounted) return;
    
    try {
      setState(() {
        _isSliding = false;
      });
    } catch (e) {
      // Silently handle setState errors during widget disposal
    }
    
    // Clear global flag to allow main controls to hide again
    _VolumeSliderButtonState._isAnyVolumeSliderInUse = false;
    _startHideTimer(); // Resume hide timer after sliding
    debugPrint('Volume slider: Finished sliding');
  }

  // Getter to check if volume slider is being used (for external components)
  bool get isSliding => _isSliding;

  Widget _buildVerticalVolumeSlider() {
    // Check mounted state before accessing context
    if (!mounted) {
      return const SizedBox.shrink();
    }
    
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    final currentVolume = videoPlayerState?._currentVolume ?? 100.0;
    final isMuted = currentVolume <= 0;
    final volumePercentage = isMuted ? 0 : currentVolume.round();

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.scale(
          scaleY: _slideAnimation.value,
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: _slideAnimation.value,
            child: MouseRegion(
              onEnter: (_) {
                // Set global flag to prevent main controls from hiding while hovering
                _VolumeSliderButtonState._isAnyVolumeSliderInUse = true;
                _cancelHideTimer(); // Keep visible while hovering
              },
              onExit: (_) {
                if (!_isSliding) {
                  // Clear global flag when not hovering and not sliding
                  _VolumeSliderButtonState._isAnyVolumeSliderInUse = false;
                  _startHideTimer(); // Resume timer when not hovering
                }
              },
              child: Container(
                width: 50,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9), // Higher opacity for better visibility
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Volume percentage text
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$volumePercentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // Vertical slider
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: RotatedBox(
                          quarterTurns: 3, // Rotate to make it vertical
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                              trackHeight: 3.0,
                            ),
                            child: Slider(
                              value: isMuted ? 0.0 : currentVolume,
                              min: 0.0,
                              max: 100.0,
                              divisions: 100,
                              onChangeStart: (value) {
                                _onSliderStart();
                              },
                              onChanged: (value) {
                                _setVolume(value);
                              },
                              onChangeEnd: (value) {
                                _onSliderEnd();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      return const SizedBox.shrink();
    }
    
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    final player = videoPlayerState?._player;
    
    if (player == null) {
      return const SizedBox.shrink();
    }
    
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snapshot) {
        final currentVolume = videoPlayerState?._currentVolume ?? 100.0;
        final isMuted = currentVolume <= 0;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Volume button (slider is now in overlay)
            GestureDetector(
              onTap: _toggleSlider,
              onSecondaryTap: _toggleMute, // Right click to mute/unmute
              child: Container(
                width: 40,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (_showSlider || _isSliding) ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isMuted ? Icons.volume_off : 
                  currentVolume < 33 ? Icons.volume_down :
                  currentVolume < 66 ? Icons.volume_up : Icons.volume_up,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Fullscreen volume slider button - similar to _VolumeSliderButton but with direct state access
class _FullscreenVolumeSliderButton extends StatefulWidget {
  final Player player;
  final VideoPlayerWidgetState? videoPlayerState;
  final VoidCallback onShowControls;

  const _FullscreenVolumeSliderButton({
    required this.player,
    required this.videoPlayerState,
    required this.onShowControls,
  });

  @override
  _FullscreenVolumeSliderButtonState createState() => _FullscreenVolumeSliderButtonState();
}

class _FullscreenVolumeSliderButtonState extends State<_FullscreenVolumeSliderButton> with TickerProviderStateMixin {
  bool _showSlider = false;
  bool _isSliding = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideSlider();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (!mounted) return;
    
    try {
      final videoPlayerState = widget.videoPlayerState;
      if (videoPlayerState != null && videoPlayerState.mounted) {
        videoPlayerState.toggleMute();
        widget.onShowControls();
      }
    } catch (e) {
      debugPrint('Fullscreen volume slider error in _toggleMute: $e');
    }
  }

  void _setVolume(double volume) async {
    if (!mounted) return;
    
    try {
      widget.player.setVolume(volume);
      
      final videoPlayerState = widget.videoPlayerState;
      if (videoPlayerState != null && videoPlayerState.mounted) {
        videoPlayerState.setState(() {
          videoPlayerState._currentVolume = volume;
        });
      }
      if (_overlayEntry != null && mounted) {
        _overlayEntry!.markNeedsBuild();
      }
      await _preferencesRepository.setVideoVolume(volume);
    } catch (e) {
      debugPrint('Fullscreen volume slider error in _setVolume: $e');
    }
  }

  void _toggleSlider() {
    if (mounted) {
      try {
        if (_showSlider) {
          // If slider is currently shown, hide it
          _hideSlider();
        } else {
          // If slider is currently hidden, show it
          setState(() {
            _showSlider = true;
          });
          _showVolumeSlider();
        }
        widget.onShowControls();
      } catch (e) {
        debugPrint('Fullscreen volume slider error in _toggleSlider: $e');
      }
    }
  }

  void _startHideTimer() {
    _cancelHideTimer();
    if (!_isSliding && mounted) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isSliding) {
          _hideSlider();
        }
      });
    }
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _showVolumeSlider() {
    if (_overlayEntry != null || !mounted) return;

    try {
      _overlayEntry = OverlayEntry(
        builder: (context) => _buildVerticalVolumeSlider(),
      );
      Overlay.of(context).insert(_overlayEntry!);
      // Start hide timer after showing the slider
      _startHideTimer();
    } catch (e) {
      debugPrint('Fullscreen volume slider error in _showVolumeSlider: $e');
    }
  }

  void _hideSlider() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _VolumeSliderButtonState._isAnyVolumeSliderInUse = false;
    
    if (!mounted) return;
    
    try {
      setState(() {
        _showSlider = false;
        _isSliding = false;
      });
      _animationController.reverse();
    } catch (e) {
      // Silently handle setState errors during widget disposal
    }
  }

  void _onSliderStart() {
    if (mounted) {
      try {
        setState(() {
          _isSliding = true;
        });
      } catch (e) {
        debugPrint('Fullscreen volume slider error in _onSliderStart: $e');
      }
    }
    _VolumeSliderButtonState._isAnyVolumeSliderInUse = true;
    _cancelHideTimer();
    debugPrint('Fullscreen volume slider: Started sliding - keeping controls visible');
  }

  void _onSliderEnd() {
    if (mounted) {
      try {
        setState(() {
          _isSliding = false;
        });
      } catch (e) {
        debugPrint('Fullscreen volume slider error in _onSliderEnd: $e');
      }
    }
    _VolumeSliderButtonState._isAnyVolumeSliderInUse = false;
    _startHideTimer();
    debugPrint('Fullscreen volume slider: Finished sliding');
  }

  Widget _buildVerticalVolumeSlider() {
    if (!mounted) {
      return const SizedBox.shrink();
    }
    
    final videoPlayerState = widget.videoPlayerState;
    final currentVolume = videoPlayerState?._currentVolume ?? 100.0;
    final isMuted = currentVolume <= 0;
    final volumePercentage = isMuted ? 0 : currentVolume.round();

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: 120,
          left: 50,
          child: MouseRegion(
            onEnter: (_) {
              _VolumeSliderButtonState._isAnyVolumeSliderInUse = true;
              _cancelHideTimer();
            },
            onExit: (_) {
              _VolumeSliderButtonState._isAnyVolumeSliderInUse = false;
              _startHideTimer();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 50,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '$volumePercentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            trackHeight: 4.0,
                          ),
                          child: Slider(
                            value: isMuted ? 0.0 : currentVolume,
                            min: 0.0,
                            max: 100.0,
                            divisions: 100,
                            onChangeStart: (_) => _onSliderStart(),
                            onChangeEnd: (_) => _onSliderEnd(),
                            onChanged: (value) {
                              _setVolume(value);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      return const SizedBox.shrink();
    }
    
    final videoPlayerState = widget.videoPlayerState;
    final currentVolume = videoPlayerState?._currentVolume ?? 100.0;
    final isMuted = currentVolume <= 0;
    
    return StreamBuilder<double>(
      stream: widget.player.stream.volume,
      initialData: widget.player.state.volume,
      builder: (context, snapshot) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleSlider,
              onSecondaryTap: _toggleMute,
              child: Container(
                width: 40,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (_showSlider || _isSliding) ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isMuted ? Icons.volume_off : 
                  currentVolume < 33 ? Icons.volume_down :
                  currentVolume < 66 ? Icons.volume_up : Icons.volume_up,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Subtitle toggle button
