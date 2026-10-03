part of '../video_player_widget.dart';

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
            color: _isHovered ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
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
            color: _isHovered ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
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
