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
                      await _preferencesRepository.setSubtitleFontSize(v);
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
                        _preferencesRepository.setSubtitleFontSize(16.0).then((_) {
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
