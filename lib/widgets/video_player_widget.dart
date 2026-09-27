// Subtitle Studio v3 - Video Player Widget with Subtitle Overlay
//
// This widget provides comprehensive video playback functionality with integrated
// subtitle display and synchronization. It serves as the core component for
// video-based subtitle editing workflows.
//
// Key Features:
// - Multi-format video playback using Media Kit
// - Real-time subtitle overlay rendering
// - Dual subtitle track support (primary + secondary)
// - Playback controls with frame-accurate seeking
// - Subtitle synchronization with video timeline
// - Custom subtitle styling and positioning
// - Performance optimized for large subtitle files
// - Fullscreen mode with responsive subtitle positioning
//
// Technical Implementation:
// - Media Kit integration for cross-platform video support
// - Custom subtitle rendering with text styling
// - Efficient subtitle lookup using time-based indexing
// - Memory management for long video sessions
// - Thread-safe subtitle updates
// - Responsive UI that adapts to fullscreen mode
//
// iOS Port Considerations:
// - Replace Media Kit with AVPlayer and AVPlayerViewController
// - Use iOS native video controls and AVPlayerLayer
// - Implement subtitle overlay with CATextLayer or UILabel
// - Handle iOS-specific video formats and codecs
// - Adapt to iOS background/foreground lifecycle
// - Use iOS native subtitle rendering if available

import 'package:flutter/material.dart';      // Flutter UI framework
import 'package:flutter/services.dart';     // System services integration
import 'package:flutter/foundation.dart';   // Flutter foundation for kDebugMode
import 'package:flutter/gestures.dart';     // Gesture detection and pointer events
import 'dart:async';                         // Timer functionality
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart'; // Duration utilities
import 'package:subtitle_studio/widgets/loader.dart';           // Loading indicators
import 'package:subtitle_studio/widgets/positioned_subtitle_widget.dart'; // Positioned subtitle rendering
import 'package:subtitle_studio/widgets/comment_dialog.dart';    // Comment dialog for marked lines
import 'package:media_kit/media_kit.dart';                   // Media Kit core functionality
import 'package:media_kit_video/media_kit_video.dart';       // Media Kit video widgets
import 'package:subtitle_studio/utils/ffmpeg_helper.dart';      // FFmpeg integration utilities
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';  // File picker utilities
import 'package:subtitle_studio/utils/platform_file_handler.dart';  // Platform file handler utilities
import 'package:subtitle_studio/utils/saf_path_converter.dart';   // SAF path conversion utilities
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// FontLoader is available via flutter services import above
import 'package:subtitle_studio/database/models/preferences_model.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/utils/responsive_layout.dart'; // Import responsive layout utilities
import 'package:subtitle_studio/screens/screen_edit_line.dart'; // Import EditSubtitleScreenState
import 'package:subtitle_studio/widgets/video/subtitle.dart';
import 'package:subtitle_studio/widgets/video/subtitle_timeline_index.dart';
import 'package:subtitle_studio/widgets/video/repeat_range_dialog.dart';
export 'package:subtitle_studio/widgets/video/repeat_range_dialog.dart';
export 'package:subtitle_studio/widgets/video/subtitle.dart';
part 'video/custom_video_controls.dart';
part 'video/fullscreen_controls.dart';
part 'video/player_track_speed_controls.dart';
part 'video/player_volume_controls.dart';
part 'video/player_toggle_controls.dart';
part 'video/player_settings_button.dart';
part 'video/video_track_actions.dart';
part 'video/video_playback_navigation.dart';
part 'video/video_dialog_helpers.dart';
part 'video/video_fullscreen_actions.dart';
part 'video/video_subtitle_preferences.dart';
part 'video/video_player_actions.dart';

Future<void> _awaitCallbackResult(dynamic result) async {
  if (result is Future) {
    await result;
  }
}

/// Advanced video player widget with integrated subtitle overlay system
/// 
/// This widget combines video playback with sophisticated subtitle rendering:
/// 
/// **Video Playback Features:**
/// - Support for multiple video formats (MP4, AVI, MKV, etc.)
/// - Hardware-accelerated decoding where available
/// - Smooth seeking and frame-accurate positioning
/// - Playback speed control and audio management
/// - Fullscreen mode with orientation handling
/// 
/// **Subtitle Integration:**
/// - Real-time subtitle synchronization with video timeline
/// - Dual subtitle track support for language learning
/// - Custom subtitle styling (font, color, outline, shadow)
/// - Subtitle positioning and alignment options
/// - Performance-optimized rendering for long files
/// 
/// **User Interaction:**
/// - Touch controls for play/pause and seeking
/// - Timeline scrubbing with subtitle preview
/// - Volume and brightness gesture controls
/// - Keyboard shortcuts for precise control
/// 
/// **Callback System:**
/// - Position change notifications for external synchronization
/// - Subtitle update callbacks for editing integration
/// - Error handling and recovery notifications
/// 
/// **iOS Port Implementation:**
/// - Replace with AVPlayerViewController for native iOS experience
/// - Use AVPlayerItem with custom subtitle tracks
/// - Implement subtitle overlay with Core Animation layers
/// - Handle iOS-specific video lifecycle and interruptions
/// - Integrate with iOS media center and lock screen controls
class VideoPlayerWidget extends StatefulWidget {
  /// Path to the video file for playback
  /// Supports local files and remote URLs
  final String videoPath;
  
  /// Subtitle collection ID for managing per-video preferences
  /// Used to save/restore audio track selection and other video-specific settings
  final int subtitleCollectionId;
  
  /// Primary subtitle track for display overlay
  /// Contains all subtitle entries with timing information
  final List<Subtitle> subtitles;
  
  /// Optional secondary subtitle track for dual language support
  /// Displayed below or alongside primary subtitles
  final List<Subtitle> secondarySubtitles;
  
  /// Callback fired when video position changes
  /// Used for external synchronization and progress tracking
  final Function(Duration)? onPositionChanged;
  
  /// Callback fired when subtitle data is updated
  /// Allows external components to react to subtitle changes
  final Function()? onSubtitlesUpdated;
  
  /// Callback fired when a subtitle line is marked/unmarked
  /// Parameters: (subtitleIndex, isMarked)
  final Function(int, bool)? onSubtitleMarked;

  /// Callback fired when a comment is added/updated for a subtitle line
  /// Parameters: (subtitleIndex, comment)
  final Function(int, String?)? onSubtitleCommentUpdated;

  /// Callback fired when the active subtitle changes
  /// Parameters: (arrayIndex) - The array index of the active subtitle, or -1 if none
  final Function(int)? onActiveSubtitleChanged;

  /// Callback fired when video play/pause state changes
  /// Parameters: (isPlaying)
  final Function(bool)? onPlayStateChanged;

  /// Callback fired when repeat mode is toggled
  /// Parameters: (isRepeatEnabled)
  final Function(bool)? onRepeatModeToggled;

  /// Whether repeat mode is currently enabled
  final bool isRepeatModeEnabled;

  /// Callback fired when fullscreen mode is exited
  /// Used to trigger subtitle list refresh or other UI updates
  final VoidCallback? onFullscreenExited;

  const VideoPlayerWidget({
    super.key,
    required this.videoPath,                      // Video file path (required)
    required this.subtitleCollectionId,           // Subtitle collection ID for preferences (required)
    required this.subtitles,                      // Primary subtitle track (required)
    this.secondarySubtitles = const [],           // Secondary track (optional)
    this.onPositionChanged,                       // Position callback (optional)
    this.onSubtitlesUpdated,                      // Update callback (optional)
    this.onSubtitleMarked,                        // Mark callback (optional)
    this.onSubtitleCommentUpdated,                // Comment callback (optional)
    this.onActiveSubtitleChanged,                 // Active subtitle callback (optional)
    this.onPlayStateChanged,                      // Play state callback (optional)
    this.onRepeatModeToggled,                     // Repeat mode callback (optional)
    this.isRepeatModeEnabled = false,             // Repeat mode state (optional)
    this.onFullscreenExited,                      // Fullscreen exit callback (optional)
  });

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

/// State management class for VideoPlayerWidget
/// 
/// Handles all video playback operations, subtitle synchronization,
/// and user interface updates for the video player component.
/// 
/// **Core Responsibilities:**
/// - Media Kit player lifecycle management
/// - Subtitle timing and display synchronization
/// - User interface state management
/// - Error handling and recovery
/// - Performance optimization for smooth playback
class VideoPlayerWidgetState extends State<VideoPlayerWidget> with AutomaticKeepAliveClientMixin {
  void _setVideoState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  // Media Kit player instances for video playback
  late final Player _player;           // Core media player
  late final VideoController _controller; // Video-specific controller
  
  // Stream subscriptions for proper cleanup
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<Track>? _trackSubscription;
  StreamSubscription<int?>? _widthSubscription;
  
  // Public getter for external access to player instance
  Player get player => _player;
  
  List<Subtitle> _currentSubtitles = [];
  List<Subtitle> _currentSecondarySubtitles = [];

  // Active subtitle caches belong to the State object. Extension methods can
  // mutate them, but Dart extensions cannot declare instance fields.
  List<Subtitle> _currentActiveSubtitles = [];
  List<Subtitle> _currentActiveSecondarySubtitles = [];
  SubtitleTimelineIndex _primarySubtitleIndex =
      const SubtitleTimelineIndex.empty();
  SubtitleTimelineIndex _secondarySubtitleIndex =
      const SubtitleTimelineIndex.empty();

  // Cached framerate value and in-flight probe. Keeping the Future prevents
  // multiple FFmpeg processes from being started before the first probe ends.
  double? _cachedFramerate;
  Future<double?>? _framerateFuture;

  // Custom font handling
  String? _subtitleFontFamily; // family name used in TextStyle
  String? _subtitleFontFilePath; // stored/copy path for display
  double _subtitleFontSize = 16.0; // default size for mobile devices, loaded from prefs

  // Subtitle position management
  double _primarySubtitleVerticalPosition = 0.0; // Vertical position offset for primary subtitles
  double _secondarySubtitleVerticalPosition = 0.0; // Vertical position offset for secondary subtitles

  // Subtitle background toggle
  bool _showSubtitleBackground = true;

  // Track loading and player readiness state
  bool _isLoading = true;
  bool _areSubtitlesEnabled = true;
  
  // Track current playback speed
  double _currentSpeed = 1.0;
  
  // Skip duration (loaded from preferences)
  int _skipDurationSeconds = 10;
  
  // Custom fullscreen management
  bool _isCustomFullscreen = false;
  OverlayEntry? _fullscreenOverlay;
  BuildContext? _originalContext; // Store original context for dialogs
  final GlobalKey<_FullscreenControlsWidgetState> _fullscreenControlsKey = GlobalKey();
  
  // Audio track management
  /// List of available audio tracks in the current video
  /// Updated automatically when tracks are detected
  List<AudioTrack> _availableAudioTracks = [];
  
  /// Currently selected audio track
  /// Null if no track is selected or available
  AudioTrack? _currentAudioTrack;
  
  // Subtitle track management
  /// List of available subtitle tracks in the current video
  /// Updated automatically when tracks are detected
  List<SubtitleTrack> _availableSubtitleTracks = [];
  
  /// Currently selected subtitle track
  /// Null if no track is selected or available
  SubtitleTrack? _currentSubtitleTrack;
  
  // Volume state management
  /// Current volume level (0-100) shared between normal and fullscreen modes
  double _currentVolume = 100.0;
  
  // Audio track initialization state
  /// Flag to prevent saving during initial track setup.
  bool _isInitializingTracks = true;
  bool _audioTrackRestoreInProgress = false;
  
  // Removed rebuild counter for better performance
  // int _buildCounter = 0;

  Duration getDuration() {
    return _player.state.duration;
  }

  @override
  void initState() {
    super.initState();
    _currentSubtitles = widget.subtitles;
    _currentSecondarySubtitles = widget.secondarySubtitles;
    _primarySubtitleIndex = SubtitleTimelineIndex(widget.subtitles);
    _secondarySubtitleIndex = SubtitleTimelineIndex(widget.secondarySubtitles);
    _loadSubtitlePreferences();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update subtitles when the widget is updated with new data
    if (widget.subtitles != oldWidget.subtitles) {
      // Removed excessive logging causing performance issues during rebuilds
      // debugPrint('VideoPlayer: Updating subtitles due to widget change');
      updateSubtitles(widget.subtitles);
    }
    
    if (widget.secondarySubtitles != oldWidget.secondarySubtitles) {
      // Removed excessive logging causing performance issues during rebuilds
      // debugPrint('VideoPlayer: Updating secondary subtitles due to widget change');
      updateSecondarySubtitles(widget.secondarySubtitles);
    }

    // Reuse the existing Player when the media path changes. _player and
    // _controller are late final and must only be initialized once.
    if (widget.videoPath != oldWidget.videoPath) {
      debugPrint('VideoPlayer: Video path changed, opening new media');
      updateVideo(widget.videoPath);
    }
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _tracksSubscription?.cancel();
    _trackSubscription?.cancel();
    _widthSubscription?.cancel();
    
    // Clean up fullscreen overlay if active before disposing player
    if (_isCustomFullscreen) {
      _fullscreenOverlay?.remove();
      _fullscreenOverlay = null;
      _isCustomFullscreen = false;
      
      // Restore system UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    _player.dispose();
    super.dispose();
  }

  // Custom fullscreen management methods
  
  /// Enter custom fullscreen mode with our own overlay
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // Removed rebuild counter logging for better performance
    // _buildCounter++;
    // if (_buildCounter % 25 == 0) {
    //   debugPrint('VideoPlayerWidget rebuild count: $_buildCounter');
    // }
    
    return RepaintBoundary(
      child: Container(
        color: Colors.black,
        child: _player.state.duration > Duration.zero
          ? Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  // Speed control shortcuts
                  if (event.logicalKey == LogicalKeyboardKey.minus) {
                    // Decrease speed
                    final newSpeed = (_currentSpeed - 0.25).clamp(0.25, 2.0);
                    setPlaybackSpeed(newSpeed);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.equal || 
                             event.logicalKey == LogicalKeyboardKey.add) {
                    // Increase speed
                    final newSpeed = (_currentSpeed + 0.25).clamp(0.25, 2.0);
                    setPlaybackSpeed(newSpeed);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
                    // Reset to normal speed
                    setPlaybackSpeed(1.0);
                    return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                    // Exit fullscreen with Escape key
                    if (_isCustomFullscreen) {
                      _exitCustomFullscreen();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Stack(
                children: [
                  // Video player
                  MouseRegion(
                    onEnter: (_) {
                      // MaterialVideoControls handles this automatically
                    },
                    onExit: (_) {
                      // MaterialVideoControls handles this automatically
                    },
                    onHover: (_) {
                      // MaterialVideoControls handles this automatically
                    },
                    child: GestureDetector(
                      onTap: () {
                        // MaterialVideoControls handles tap-to-show/hide
                      },
                      onDoubleTapDown: (details) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final tapPosition = details.globalPosition.dx;
                        
                        // If tap is on left side, seek backward; if on right side, seek forward
                        if (tapPosition < screenWidth / 2) {
                          _seekRelative(const Duration(seconds: -10));
                          _showSeekIndicator(context, false);
                        } else {
                          _seekRelative(const Duration(seconds: 10));
                          _showSeekIndicator(context, true);
                        }
                      },
                    child: Stack(
                      children: [
                        // Video player without controls
                        Video(
                          controller: _controller,
                          controls: NoVideoControls, // Disable built-in controls
                          subtitleViewConfiguration: const SubtitleViewConfiguration(
                            visible: false, // Disable built-in subtitles
                          ),
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                ), // Close GestureDetector
              ), // Close MouseRegion

              // Subtitle overlay for normal (non-fullscreen) mode only
              // Positioned BELOW controls so controls appear above subtitles
              if (_areSubtitlesEnabled && !_isCustomFullscreen)
                IgnorePointer( // Allow touches to pass through to video controls
                  child: StreamBuilder<Duration>(
                    key: ValueKey('subtitle_${_subtitleFontSize}_$_subtitleFontFamily'),
                    stream: _player.stream.position,
                    builder: (context, snapshot) {
                      // Use cached active subtitles (now lists) instead of recalculating
                      final activeSubtitles = _currentActiveSubtitles;
                      final activeSecondarySubtitles = _currentActiveSecondarySubtitles;
                      
                      // Use standard positioning for normal mode
                      final mediaQuery = MediaQuery.of(context);
                      final topPadding = 30.0 + mediaQuery.viewPadding.top;
                      
                      // Use new MultipleOverlappingSubtitlesWidget for intelligent positioning
                      return Stack(
                        children: [
                          // Primary subtitles with intelligent positioning
                          if (activeSubtitles.isNotEmpty)
                            MultipleOverlappingSubtitlesWidget(
                              subtitleTexts: activeSubtitles.map((s) => s.text).toList(),
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: _getResponsiveSubtitleFontSize(),
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                fontFamily: _subtitleFontFamily,
                                background: _showSubtitleBackground
                                ? (Paint()..color = const Color.fromARGB(180, 0, 0, 0))
                                : null,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 3.0,
                                    color: Colors.black,
                                    offset: Offset(2.0, 2.0),
                                  ),
                                  Shadow(
                                    blurRadius: 1.0,
                                    color: Colors.black,
                                    offset: Offset(1.0, 1.0),
                                  ),
                                ],
                              ),
                              horizontalPadding: 30.0,
                              verticalPadding: 30.0,
                              topPadding: topPadding,
                              isFullscreen: false,
                              verticalOffset: _primarySubtitleVerticalPosition,
                            ),
                          
                          // Secondary subtitles (also handle positioning if needed)
                          if (activeSecondarySubtitles.isNotEmpty)
                            MultipleOverlappingSubtitlesWidget(
                              subtitleTexts: activeSecondarySubtitles.map((s) => s.text).toList(),
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: _getResponsiveSubtitleFontSize(),
                                fontWeight: FontWeight.normal,
                                height: 1.3,
                                fontFamily: _subtitleFontFamily,
                                background: Paint()..color = const Color.fromARGB(156, 0, 0, 0),
                                shadows: const [
                                  Shadow(
                                    blurRadius: 3.0,
                                    color: Colors.black,
                                    offset: Offset(2.0, 2.0),
                                  ),
                                  Shadow(
                                    blurRadius: 1.0,
                                    color: Colors.black,
                                    offset: Offset(1.0, 1.0),
                                  ),
                                ],
                              ),
                              horizontalPadding: 30.0,
                              verticalPadding: 30.0,
                              topPadding: topPadding,
                              isFullscreen: false,
                              verticalOffset: _secondarySubtitleVerticalPosition,
                              forceTopPosition: true, // Always display secondary subtitles at top
                              primarySubtitleTexts: activeSubtitles.map((s) => s.text).toList(), // Pass for collision detection
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // Custom controls overlay - positioned ABOVE subtitles
                CustomVideoControls(
                  player: _player,
                  subtitles: _currentSubtitles,
                  secondarySubtitles: _currentSecondarySubtitles,
                  onSubtitleMarked: widget.onSubtitleMarked,
                  onSubtitleCommentUpdated: widget.onSubtitleCommentUpdated,
                  onPlayStateChanged: widget.onPlayStateChanged,
                  onRepeatModeToggled: widget.onRepeatModeToggled,
                  isRepeatModeEnabled: widget.isRepeatModeEnabled,
                  skipDurationSeconds: _skipDurationSeconds,
                ),
                  
                // Loading overlay (shows only while loading)
                if (_isLoading)
                  const Center(child: Loader13()),
              ],
            ),
          )
          : const Center(child: Loader13()),
      ),
    );
  }


}
