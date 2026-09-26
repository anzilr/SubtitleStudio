part of '../video_player_widget.dart';

// Custom buttons for video controls

// Audio track button
class _AudioTrackButton extends StatefulWidget {
  const _AudioTrackButton();

  @override
  _AudioTrackButtonState createState() => _AudioTrackButtonState();
}

class _AudioTrackButtonState extends State<_AudioTrackButton> {
  @override
  Widget build(BuildContext context) {
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    
    if (videoPlayerState == null) {
      return const SizedBox.shrink();
    }
    
  final availableTracks = videoPlayerState.getAvailableAudioTracks();
  // Exclude pseudo-tracks like 'auto' and 'no' from the user-facing count
  final realTracks = availableTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
  final hasMultipleTracks = realTracks.length > 1;
    
    return InkWell(
      onTap: () {
        videoPlayerState.showAudioTrackDialog(context);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: hasMultipleTracks ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: hasMultipleTracks ? 0.5 : 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.audiotrack,
              color: Colors.white.withValues(alpha: hasMultipleTracks ? 1.0 : 0.6),
              size: 16,
            ),
              if (hasMultipleTracks) ...[
              const SizedBox(width: 4),
              Text(
                '${realTracks.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Font size expandable control widget
class _FontSizeExpandableControl extends StatefulWidget {
  final VideoPlayerWidgetState videoPlayerState;
  final Color primaryColor;
  final Color onSurfaceColor;
  final bool isDark;
  final BuildContext sheetContext;

  const _FontSizeExpandableControl({
    required this.videoPlayerState,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.isDark,
    required this.sheetContext,
  });

  @override
  _FontSizeExpandableControlState createState() => _FontSizeExpandableControlState();
}

class _FontSizeExpandableControlState extends State<_FontSizeExpandableControl> with TickerProviderStateMixin {
  bool _isExpanded = false;
  late double _tempFontSize;

  @override
  void initState() {
    super.initState();
    _tempFontSize = widget.videoPlayerState._subtitleFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main font size item
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: widget.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.format_size,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtitle Font Size',
                          style: Theme.of(widget.sheetContext).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.videoPlayerState._subtitleFontSize.toStringAsFixed(1)} pt',
                          style: Theme.of(widget.sheetContext).textTheme.bodySmall?.copyWith(
                            color: Theme.of(widget.sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: widget.primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Expandable content with preview and slider
        AnimatedCrossFade(
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? widget.onSurfaceColor.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.onSurfaceColor.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.onSurfaceColor.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    'Preview: The quick brown fox – 12345',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _tempFontSize,
                      fontFamily: widget.videoPlayerState._subtitleFontFamily,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          blurRadius: 3.0,
                          color: Colors.black,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Slider control
                SliderTheme(
                  data: SliderTheme.of(widget.sheetContext).copyWith(
                    activeTrackColor: widget.primaryColor.withValues(alpha: 0.80),
                    inactiveTrackColor: widget.onSurfaceColor.withValues(alpha: 0.20),
                    thumbColor: widget.primaryColor,
                    overlayColor: widget.primaryColor.withValues(alpha: 0.12),
                    valueIndicatorColor: widget.primaryColor,
                  ),
                  child: Slider(
                    min: 8.0,
                    max: 48.0,
                    divisions: 40,
                    value: _tempFontSize,
                    label: _tempFontSize.toStringAsFixed(1),
                    onChanged: (v) {
                      setState(() => _tempFontSize = v);
                    },
                    onChangeEnd: (v) async {
                      // Apply the new font size
                      await PreferencesModel.setSubtitleFontSize(v);
                      if (widget.videoPlayerState.mounted) {
                        widget.videoPlayerState.setState(() {
                          widget.videoPlayerState._subtitleFontSize = v;
                        });
                        widget.videoPlayerState._updateActiveSubtitles(widget.videoPlayerState.getCurrentPosition());
                        widget.videoPlayerState._fullscreenOverlay?.markNeedsBuild();
                      }
                    },
                  ),
                ),
                
                // Control row with reset button and value display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _tempFontSize = 16.0);
                        // Also apply the reset immediately
                        PreferencesModel.setSubtitleFontSize(16.0).then((_) {
                          if (widget.videoPlayerState.mounted) {
                            widget.videoPlayerState.setState(() {
                              widget.videoPlayerState._subtitleFontSize = 16.0;
                            });
                            widget.videoPlayerState._updateActiveSubtitles(widget.videoPlayerState.getCurrentPosition());
                            widget.videoPlayerState._fullscreenOverlay?.markNeedsBuild();
                          }
                        });
                      },
                      child: Text('Reset', 
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    Text(
                      '${_tempFontSize.toStringAsFixed(1)} pt', 
                      style: Theme.of(widget.sheetContext).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.primaryColor,
                      )
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Speed button
class _SpeedButton extends StatefulWidget {
  const _SpeedButton();

  @override
  _SpeedButtonState createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<_SpeedButton> {
  @override
  Widget build(BuildContext context) {
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    
    if (videoPlayerState == null) {
      return const SizedBox.shrink();
    }
    
    final currentSpeed = videoPlayerState.getCurrentSpeed();
    String speedText = '${currentSpeed}x';
    if (currentSpeed == 1.0) {
      speedText = '1x';
    } else if (currentSpeed == currentSpeed.toInt().toDouble()) {
      speedText = '${currentSpeed.toInt()}x';
    }
    
    return InkWell(
      onTap: () {
        videoPlayerState.showSpeedDialog(context);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: currentSpeed != 1.0 ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              speedText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Volume slider button with seeking functionality
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
        await PreferencesModel.setVideoVolume(volume);
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
                  color: Colors.black.withOpacity(0.9), // Higher opacity for better visibility
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
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
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
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
                  color: (_showSlider || _isSliding) ? Colors.white.withOpacity(0.2) : Colors.transparent,
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
      await PreferencesModel.setVideoVolume(volume);
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
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
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
                            inactiveTrackColor: Colors.white.withOpacity(0.3),
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
                  color: (_showSlider || _isSliding) ? Colors.white.withOpacity(0.2) : Colors.transparent,
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
class _SubtitleToggleButton extends StatefulWidget {
  const _SubtitleToggleButton();

  @override
  _SubtitleToggleButtonState createState() => _SubtitleToggleButtonState();
}

class _SubtitleToggleButtonState extends State<_SubtitleToggleButton> with WidgetsBindingObserver {
  bool _subtitlesEnabled = true;
  bool _isHovered = false;
  VideoPlayerWidgetState? _videoPlayerState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Schedule a post-frame callback to capture the initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSubtitleState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateSubtitleState();
    }
  }

  void _updateSubtitleState() {
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    if (videoPlayerState != null && mounted) {
      _videoPlayerState = videoPlayerState;
      if (_subtitlesEnabled != videoPlayerState._areSubtitlesEnabled) {
        setState(() {
          _subtitlesEnabled = videoPlayerState._areSubtitlesEnabled;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videoPlayerState == null) {
      _videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
      if (_videoPlayerState != null) {
        _subtitlesEnabled = _videoPlayerState!._areSubtitlesEnabled;
      } else {
        return const SizedBox.shrink();
      }
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          // Toggle local state immediately for instant UI feedback
          setState(() {
            _subtitlesEnabled = !_subtitlesEnabled;
          });
          
          // Then update the actual player state
          _videoPlayerState!.toggleSubtitles();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, // Increased size for better usability
          height: 32, // Increased size for better usability
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovered ? Colors.white.withOpacity(0.2) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Icon(
            _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
            color: _isHovered ? Colors.blue.shade200 : Colors.white,
            size: 22, // Increased icon size
          ),
        ),
      ),
    );
  }
}

// Settings button - combines audio track and speed controls
class _SettingsButton extends StatefulWidget {
  const _SettingsButton();

  @override
  _SettingsButtonState createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    
    if (videoPlayerState == null) {
      return const SizedBox.shrink();
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          _showSettingsMenu(context, videoPlayerState);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, // Increased size for better usability
          height: 32, // Increased size for better usability
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.tune, // Configuration/settings icon
            color: _isHovered ? Colors.blue.shade200 : Colors.white,
            size: 22, // Increased icon size
            shadows: const [
              Shadow(
                blurRadius: 3.0,
                color: Colors.black,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context, VideoPlayerWidgetState videoPlayerState) {
    // Capture parent context so inner builders can call dialogs/snackbars safely after the sheet is popped
    final BuildContext parentContext = context;
    // Show settings sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Use a distinct name for the sheet's builder context to avoid shadowing the parent
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            // Dynamic color variables for adaptive theming
            final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
            final primaryColor = Theme.of(sheetContext).primaryColor;
            final surfaceColor = Theme.of(sheetContext).colorScheme.surface;
            final onSurfaceColor = Theme.of(sheetContext).colorScheme.onSurface;
            final mutedColor = onSurfaceColor.withValues(alpha: 0.6);

            return Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.settings,
                                color: primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Video Settings',
                                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Adjust playback and subtitle settings',
                                    style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
              
                      
                      // Playback Speed Section
                      StatefulBuilder(
                        builder: (BuildContext context, StateSetter setSpeedState) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.speed,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Playback Speed',
                                        style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${videoPlayerState.getCurrentSpeed()}x',
                                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<double>(
                                  onSelected: (double value) {
                                    videoPlayerState.setPlaybackSpeed(value);
                                    setSpeedState(() {}); // Trigger rebuild of this section
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: onSurfaceColor.withValues(alpha: 0.12),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.arrow_drop_down,
                                      color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.6),
                                      size: 18,
                                    ),
                                  ),
                                  itemBuilder: (BuildContext context) {
                                    final speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
                                    return speedOptions.map((double speed) {
                                      final isSelected = videoPlayerState.getCurrentSpeed() == speed;
                                      String label = '${speed}x';
                                      if (speed == 1.0) label = '1x (Normal)';
                                      
                                      return PopupMenuItem<double>(
                                        value: speed,
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                              color: isSelected ? primaryColor : onSurfaceColor.withValues(alpha: 0.6),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                color: isSelected ? primaryColor : onSurfaceColor,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      
                      // Audio Track Section
                      Builder(
                        builder: (context) {
                          final availableTracks = videoPlayerState.getAvailableAudioTracks();
                          // Exclude pseudo-tracks 'auto' and 'no' when reporting available tracks
                          final realTracks = availableTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
                          final hasMultipleTracks = realTracks.length > 1;
                          
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.audiotrack,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Audio Track',
                                        style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        hasMultipleTracks 
                                          ? '${realTracks.length} tracks available'
                                          : 'Default track',
                                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                hasMultipleTracks 
                                  ? PopupMenuButton<AudioTrack>(
                                      onSelected: (AudioTrack track) async {
                                        await videoPlayerState.setAudioTrack(track);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: onSurfaceColor.withValues(alpha: 0.12),
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          Icons.arrow_drop_down,
                                          color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.6),
                                          size: 18,
                                        ),
                                      ),
                                      itemBuilder: (BuildContext context) {
                                        final currentTrack = videoPlayerState.getCurrentAudioTrack();
                                        return availableTracks.map((AudioTrack track) {
                                          final isSelected = currentTrack?.id == track.id;
                                          
                                          // Get track display name
                                          String trackName = 'Track ${track.id}';
                                          if (track.id == 'auto') {
                                            trackName = 'Auto';
                                          } else if (track.id == 'no') {
                                            trackName = 'Off';
                                          } else if (track.title?.isNotEmpty == true) {
                                            trackName = track.title!;
                                          } else if (track.language?.isNotEmpty == true) {
                                            trackName = 'Track ${track.id} (${track.language})';
                                          }
                                          
                                          return PopupMenuItem<AudioTrack>(
                                            value: track,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                                  color: isSelected ? Colors.orange : onSurfaceColor.withValues(alpha: 0.6),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    trackName,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.orange : onSurfaceColor,
                                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList();
                                      },
                                    )
                                  : Icon(
                                      Icons.not_interested,
                                      color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.3),
                                      size: 18,
                                    ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Custom font loader
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            // Close sheet first (use sheetContext) then call pick using captured parentContext so lookups are safe
                            Navigator.pop(sheetContext);
                            await videoPlayerState._pickAndSaveFont(parentContext);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.font_download,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Load Custom Subtitle Font',
                                        style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        videoPlayerState._subtitleFontFilePath != null
                                            ? videoPlayerState._subtitleFontFilePath!.split(Platform.pathSeparator).last
                                            : 'No custom font',
                                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.3),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Font size adjustment with expandable preview
                      _FontSizeExpandableControl(
                        videoPlayerState: videoPlayerState,
                        primaryColor: primaryColor,
                        onSurfaceColor: onSurfaceColor,
                        isDark: isDark,
                        sheetContext: sheetContext,
                      ),
                      const SizedBox(height: 16),
                      // Subtitle background toggle
                      StatefulBuilder(
                        builder: (
                          BuildContext context,
                          StateSetter setSheetState,
                        ) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final newValue =
                                    !videoPlayerState._showSubtitleBackground;
                                await PreferencesModel.setShowSubtitleBackground(
                                  newValue,
                                );
                                videoPlayerState.setState(() {
                                  videoPlayerState._showSubtitleBackground =
                                      newValue;
                                });
                                setSheetState(() {}); // Update sheet UI
                                videoPlayerState._updateActiveSubtitles(
                                  videoPlayerState.getCurrentPosition(),
                                );
                                videoPlayerState._fullscreenOverlay
                                    ?.markNeedsBuild();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.text_fields,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Subtitle Background',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            videoPlayerState
                                                    ._showSubtitleBackground
                                                ? 'Enabled'
                                                : 'Disabled',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(sheetContext)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.6),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value:
                                          videoPlayerState
                                              ._showSubtitleBackground,
                                      onChanged: (value) async {
                                        await PreferencesModel.setShowSubtitleBackground(
                                          value,
                                        );
                                        videoPlayerState.setState(() {
                                          videoPlayerState
                                              ._showSubtitleBackground = value;
                                        });
                                        setSheetState(() {}); // Update sheet UI
                                        videoPlayerState._updateActiveSubtitles(
                                          videoPlayerState.getCurrentPosition(),
                                        );
                                        videoPlayerState._fullscreenOverlay
                                            ?.markNeedsBuild();
                                      },
                                      activeColor: primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Primary subtitle position adjustment
                      StatefulBuilder(
                        builder: (BuildContext context, StateSetter setSheetState) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: onSurfaceColor.withValues(alpha: 0.12),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.vertical_align_bottom,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Primary Subtitle Position',
                                            style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Adjust vertical position: ${videoPlayerState._primarySubtitleVerticalPosition.round()}px',
                                            style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                              color: mutedColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                  // Adjustment buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Down button
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._primarySubtitleVerticalPosition - 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setPrimarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._primarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_down, size: 18),
                                      ),
                                      // Position display
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: surfaceColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: onSurfaceColor.withValues(alpha: 0.12),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${videoPlayerState._primarySubtitleVerticalPosition.round()}px',
                                          style: TextStyle(
                                            color: onSurfaceColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Up button
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._primarySubtitleVerticalPosition + 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setPrimarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._primarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_up, size: 18),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Secondary subtitle position adjustment (only show if secondary subtitles are loaded)
                      if (videoPlayerState._currentSecondarySubtitles.isNotEmpty)
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setSheetState) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: onSurfaceColor.withValues(alpha: 0.12),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.vertical_align_top,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Secondary Subtitle Position',
                                              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Adjust vertical position: ${videoPlayerState._secondarySubtitleVerticalPosition.round()}px',
                                              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                                color: mutedColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Adjustment buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Down button (moves up due to swapped functionality)
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._secondarySubtitleVerticalPosition + 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setSecondarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._secondarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_down, size: 18),
                                      ),
                                      // Position display
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: surfaceColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: onSurfaceColor.withValues(alpha: 0.12),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${videoPlayerState._secondarySubtitleVerticalPosition.round()}px',
                                          style: TextStyle(
                                            color: onSurfaceColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Up button (moves down due to swapped functionality)
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._secondarySubtitleVerticalPosition - 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setSecondarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._secondarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_up, size: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Fullscreen button
class _FullscreenButton extends StatefulWidget {
  const _FullscreenButton();

  @override
  _FullscreenButtonState createState() => _FullscreenButtonState();
}

class _FullscreenButtonState extends State<_FullscreenButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    
    if (videoPlayerState == null) {
      return const SizedBox.shrink();
    }
    
    // Use our custom fullscreen toggle instead of Material Design button
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          videoPlayerState._toggleCustomFullscreen();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, // Increased size for better usability
          height: 32, // Increased size for better usability
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovered ? Colors.white.withOpacity(0.2) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Icon(
            videoPlayerState._isCustomFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: _isHovered ? Colors.blue.shade200 : Colors.white,
            size: 22, // Increased icon size
          ),
        ),
      ),
    );
  }
}
