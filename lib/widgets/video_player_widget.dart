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
part 'video/player_control_widgets.dart';

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

  Future<void> _loadSubtitlePreferences() async {
    try {
      final savedSize = await PreferencesModel.getSubtitleFontSize();
      final savedPath = await PreferencesModel.getSubtitleFontPath();
      final skipDuration = await PreferencesModel.getSkipDurationSeconds();
      final primaryPosition = await PreferencesModel.getPrimarySubtitleVerticalPosition();
      final secondaryPosition = await PreferencesModel.getSecondarySubtitleVerticalPosition();
      final savedVolume = await PreferencesModel.getVideoVolume();
      final showBackground = await PreferencesModel.getShowSubtitleBackground();
      setState(() {
        _subtitleFontSize = savedSize;
        _skipDurationSeconds = skipDuration;
        _primarySubtitleVerticalPosition = primaryPosition;
        _secondarySubtitleVerticalPosition = secondaryPosition;
        _currentVolume = savedVolume;
        _showSubtitleBackground = showBackground;
      });
      if (savedPath != null) {
        // If file exists at saved path, attempt to load it, else clear pref
        final f = File(savedPath);
        if (await f.exists()) {
          await _loadFontFromFile(f);
        } else {
          await PreferencesModel.setSubtitleFontPath(null);
        }
      }
    } catch (e) {
      // ignore errors and keep defaults
    }
  }

  Future<void> _loadFontFromFile(File file) async {
    try {
      final fileName = file.uri.pathSegments.last;
      final family = 'CustomSubtitleFont_${fileName.hashCode}';

      final bytes = await file.readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();

      setState(() {
        _subtitleFontFamily = family;
        _subtitleFontFilePath = file.path;
      });
      await PreferencesModel.setSubtitleFontPath(file.path);
      // Rebuild any custom fullscreen overlay if present
      _fullscreenOverlay?.markNeedsBuild();
    } catch (e) {
      // ignore load failure
    }
  }

  /// Get responsive subtitle font size based on layout
  double _getResponsiveSubtitleFontSize() {
    return ResponsiveLayout.getSubtitleFontSize(context, _subtitleFontSize);
  }

  /// Pick and save a custom font file for subtitle rendering
  /// 
  /// Uses platform-specific file access:
  /// - Android: Storage Access Framework (SAF) for secure font file selection
  /// - Desktop: Traditional file picker with direct file system access
  /// 
  /// Supported font formats: TTF, OTF
  /// The selected font is copied to the app's documents directory and loaded
  /// for use in subtitle rendering across the application.
  Future<void> _pickAndSaveFont(BuildContext context) async {
    // Capture parent context and messenger before awaiting to avoid using deactivated contexts
    final BuildContext parentContext = context;
    
    try {
      PlatformFileInfo? fontFileInfo;
      
      if (Platform.isAndroid) {
        // Use SAF on Android for secure file access
        fontFileInfo = await PlatformFileHandler.readFile(
          mimeTypes: ['font/ttf', 'font/otf', 'application/x-font-ttf', 'application/x-font-opentype', 'application/octet-stream'],
        );
      } else {
        // Use traditional file picker on desktop platforms
        final fontFilePath = await FilePickerSAF.pickFile(
          context: context,
          title: 'Select Font File',
          allowedExtensions: ['.ttf', '.otf'],
        );
        
        if (fontFilePath != null) {
          // Read the file content for desktop platforms
          final sourceFile = File(fontFilePath);
          final content = await sourceFile.readAsBytes();
          
          fontFileInfo = PlatformFileInfo(
            path: fontFilePath,
            content: content,
            isFromSaf: false,
            safUri: null,
          );
        }
      }
      
      if (fontFileInfo == null) return;

      // Create fonts directory in app documents
      final appDoc = await getApplicationDocumentsDirectory();
      final fontsDir = Directory('${appDoc.path}${Platform.pathSeparator}fonts');
      if (!await fontsDir.exists()) await fontsDir.create(recursive: true);
      
      // Generate destination file path
      final fileName = fontFileInfo.fileName;
      final dest = File('${fontsDir.path}${Platform.pathSeparator}$fileName');

      // If a previous custom font exists, delete it to replace with new one
      try {
        final prevPath = await PreferencesModel.getSubtitleFontPath();
        if (prevPath != null && prevPath.isNotEmpty) {
          final prevFile = File(prevPath);
          if (await prevFile.exists()) {
            await prevFile.delete();
          }
        }
      } catch (e) {
        // ignore deletion errors
      }

      // Write font data to destination using bytes from PlatformFileInfo
      await dest.writeAsBytes(fontFileInfo.content);

      // Load the font from the saved file
      await _loadFontFromFile(dest);
      
      if (mounted) {
        setState(() {});
        _fullscreenOverlay?.markNeedsBuild();
      }
      
      // Show success message
      SnackbarHelper.showSuccess(parentContext, 'Font loaded successfully');
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(parentContext, 'Failed to load font: $e');
      }
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
      setState(() {
        _isInitializingTracks = true;
        _availableAudioTracks = [];
        _availableSubtitleTracks = [];
      });
    }
    
    _player.stop();
    _player.open(Media(newPath));
    
    // Clear audio track selection when video changes
    try {
      await PreferencesModel.clearSelectedAudioTrack(widget.subtitleCollectionId);
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
        setState(() {
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
        setState(() {
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
        setState(() {
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

  // Performance optimization: Track current active subtitles to avoid unnecessary rebuilds
  // Changed to lists to support multiple overlapping subtitles with same timecode
  List<Subtitle> _currentActiveSubtitles = [];
  List<Subtitle> _currentActiveSecondarySubtitles = [];
  
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
    setState(() {
      _areSubtitlesEnabled = !_areSubtitlesEnabled;
    });
  }

  // Set playback speed
  void setPlaybackSpeed(double speed) {
    setState(() {
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

  // Audio track management methods
  
  /// Save selected audio track to preferences
  Future<void> _saveAudioTrackSelection(AudioTrack track) async {
    try {
      debugPrint('Saving audio track for collection ${widget.subtitleCollectionId}: ${track.title} (${track.language}) [ID: ${track.id}]');
      await PreferencesModel.saveSelectedAudioTrack(
        widget.subtitleCollectionId,
        trackId: track.id,
        trackTitle: track.title,
        trackLanguage: track.language,
      );
      debugPrint('✓ Audio track saved successfully');
    } catch (e) {
      debugPrint('✗ Error saving audio track selection: $e');
    }
  }
  
  /// Restore the saved audio track after Media Kit reports tracks.
  Future<void> _restoreSavedAudioTrack(
    List<AudioTrack> availableTracks,
  ) async {
    if (!_isInitializingTracks ||
        _audioTrackRestoreInProgress ||
        availableTracks.isEmpty) {
      return;
    }

    _audioTrackRestoreInProgress = true;

    try {
      final savedTrack = await PreferencesModel.getSelectedAudioTrack(
        widget.subtitleCollectionId,
      );
      if (!mounted) return;

      final savedTrackId = savedTrack['id'];
      if (savedTrackId == null) {
        debugPrint('No saved audio track found, using default');
        return;
      }

      final matchingTrack = availableTracks.firstWhere(
        (track) => track.id == savedTrackId,
        orElse: () => availableTracks.first,
      );

      if (matchingTrack.id != _currentAudioTrack?.id) {
        await _player.setAudioTrack(matchingTrack);
        debugPrint(
          'Restored audio track: '
          '${matchingTrack.title} (${matchingTrack.language})',
        );
      }
    } catch (e) {
      debugPrint('Error restoring saved audio track: $e');
    } finally {
      _audioTrackRestoreInProgress = false;
      if (mounted) {
        setState(() {
          _isInitializingTracks = false;
        });
      }
    }
  }

  /// Get all available audio tracks in the current video
  /// Returns empty list if no tracks are available or video is not loaded
  List<AudioTrack> getAvailableAudioTracks() {
    return _availableAudioTracks;
  }

  /// Get the currently selected audio track
  /// Returns null if no track is selected
  AudioTrack? getCurrentAudioTrack() {
    return _currentAudioTrack;
  }

  /// Switch to a specific audio track
  /// [track] The audio track to switch to
  Future<void> setAudioTrack(AudioTrack track) async {
    await _player.setAudioTrack(track);
  }

  // Subtitle track management methods
  
  /// Get all available subtitle tracks in the current video
  /// Returns empty list if no tracks are available or video is not loaded
  List<SubtitleTrack> getAvailableSubtitleTracks() {
    return _availableSubtitleTracks;
  }

  /// Get the currently selected subtitle track
  /// Returns null if no track is selected
  SubtitleTrack? getCurrentSubtitleTrack() {
    return _currentSubtitleTrack;
  }

  /// Switch to a specific subtitle track
  /// [track] The subtitle track to switch to
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
  }

  /// Get the current video file path
  /// Returns the original video path, not the converted file descriptor URI
  String? getVideoPath() {
    // Return the original video path from the widget constructor
    // This ensures we get the content URI for Android SAF support
    // rather than the converted file descriptor URI from media kit
    return widget.videoPath;
  }

  /// Get detailed subtitle track information using FFmpeg
  /// This provides more detailed information than media_kit tracks
  Future<List<Map<String, dynamic>>> getDetailedSubtitleTracks() async {
    final videoPath = getVideoPath();
    if (videoPath == null) return [];
    
    try {
      final ffmpeg = FFmpegHelper();
      return await ffmpeg.getSubtitleTracks(videoPath);
    } catch (e) {
      debugPrint('Error getting detailed subtitle tracks: $e');
      return [];
    }
  }

  /// Extract subtitle content from a specific track
  /// [trackIndex] The subtitle index (0-based) for FFmpeg extraction (not the stream index)
  /// Returns the content as a string, or null if extraction fails
  Future<String?> extractSubtitleTrackContent(int trackIndex) async {
    final videoPath = getVideoPath();
    if (videoPath == null) return null;
    
    try {
      final ffmpeg = FFmpegHelper();
      // Create a temporary directory for extraction
      final tempDir = Directory.systemTemp;
      
      final extractedPath = await ffmpeg.extractSubtitle(
        videoPath,
        tempDir.path,
        trackIndex,
      );
      
      // Read the extracted subtitle content
      final extractedFile = File(extractedPath);
      if (await extractedFile.exists()) {
        final content = await extractedFile.readAsString();
        // Clean up the temporary file
        await extractedFile.delete();
        return content;
      }
    } catch (e) {
      debugPrint('Error extracting subtitle track content: $e');
    }
    
    return null;
  }

  /// Show dialog to select from available audio tracks
  /// Displays a snackbar message if no additional tracks are available
  void showAudioTrackDialog(BuildContext context) {
    // Use the State's context as a safe parent context and guard against disposed state
    if (!mounted) return;
    final BuildContext safeContext = this.context;

    if (_availableAudioTracks.isEmpty || _availableAudioTracks.length <= 1) {
      final messenger = ScaffoldMessenger.maybeOf(safeContext) ?? ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No additional audio tracks available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Ensure state still mounted before showing dialog
    if (!mounted) return;

    showDialog(
      context: safeContext,
      builder: (BuildContext context) {
        return AlertDialog(
          scrollable: true,
          title: Row(
            children: [
              Icon(Icons.audiotrack, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Audio Track'),
            ],
          ),
          content: SizedBox(
            width: double.minPositive,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _availableAudioTracks.map((track) {
                return _buildAudioTrackOption(context, track);
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAudioTrackOption(BuildContext context, AudioTrack track) {
    final isSelected = _currentAudioTrack?.id == track.id;
    
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
    
    return InkWell(
      onTap: () {
        setAudioTrack(track);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Theme.of(context).primaryColor) : null,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: track.id,
              groupValue: _currentAudioTrack?.id,
              onChanged: (String? value) {
                if (value != null) {
                  setAudioTrack(track);
                  Navigator.of(context).pop();
                }
              },
              activeColor: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trackName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.onSurface : null,
                    ),
                  ),
                  if (track.language?.isNotEmpty == true && track.title?.isNotEmpty == true)
                    Text(
                      'Language: ${track.language}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // Show speed selection dialog
  void showSpeedDialog(BuildContext context) {
    // Prefer using the state's context to avoid passing a potentially disposed child context
    if (!mounted) return;
    final BuildContext safeContext = this.context;

    showDialog(
      context: safeContext,
      builder: (BuildContext context) {
        return AlertDialog(
          scrollable: true,
          title: Row(
            children: [
              Icon(Icons.speed, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Playback Speed'),
            ],
          ),
          content: SizedBox(
            width: double.minPositive,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSpeedOption(context, 0.25, '0.25x'),
                _buildSpeedOption(context, 0.5, '0.5x'),
                _buildSpeedOption(context, 0.75, '0.75x'),
                _buildSpeedOption(context, 1.0, '1.0x (Normal)'),
                _buildSpeedOption(context, 1.25, '1.25x'),
                _buildSpeedOption(context, 1.5, '1.5x'),
                _buildSpeedOption(context, 1.75, '1.75x'),
                _buildSpeedOption(context, 2.0, '2.0x'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpeedOption(BuildContext context, double speed, String label) {
    final isSelected = _currentSpeed == speed;
    return InkWell(
      onTap: () {
        setPlaybackSpeed(speed);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha:0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Theme.of(context).primaryColor) : null,
        ),
        child: Row(
          children: [
            Radio<double>(
              value: speed,
              groupValue: _currentSpeed,
              onChanged: (double? value) {
                if (value != null) {
                  setPlaybackSpeed(value);
                  Navigator.of(context).pop();
                }
              },
              activeColor: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).colorScheme.onSurface : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // Toggle mute
  void toggleMute() async {
    if (_currentVolume > 0) {
      _player.setVolume(0);
      setState(() {
        _currentVolume = 0;
      });
      await PreferencesModel.setVideoVolume(0);
    } else {
      _player.setVolume(100);
      setState(() {
        _currentVolume = 100;
      });
      await PreferencesModel.setVideoVolume(100);
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

  // Show a temporary indicator when seeking forward/backward
  void _showSeekIndicator(BuildContext context, bool isForward) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(
              isForward ? Icons.skip_next : Icons.skip_previous,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Remove after a short duration
    Future.delayed(const Duration(milliseconds: 500), () {
      overlayEntry.remove();
    });
  }

  // Method to show comment dialog for marked subtitle (for non-fullscreen mode)
  void showCommentDialog(Subtitle subtitle, BuildContext dialogContext) {
    if (_isCustomFullscreen) {
      // For fullscreen mode, this shouldn't be called as it's handled by _FullscreenControlsWidget
      debugPrint('Warning: showCommentDialog called in fullscreen mode, use _FullscreenControlsWidget instead');
      return;
    }
    
    // Store the current playing state before showing dialog
    final wasPlaying = _player.state.playing;
    debugPrint('Comment dialog opening - video was ${wasPlaying ? 'playing' : 'paused'}');
    
    // Pause video if it was playing when comment dialog opens
    if (wasPlaying) {
      _player.pause();
      debugPrint('Paused video for comment input');
    }
    
    // Flag to track if video has been resumed to prevent double resuming
    bool hasResumed = false;
    
    // For normal mode, use the standard CommentDialog.show() which handles orientation automatically
    CommentDialog.show(
      dialogContext,
      existingComment: subtitle.comment,
      onCommentSaved: (comment) async {
        // If the subtitle is not marked, mark it first
        if (!subtitle.marked && widget.onSubtitleMarked != null) {
          try {
            debugPrint('Marking subtitle before saving comment in normal mode');
            await _awaitCallbackResult(
              widget.onSubtitleMarked!(subtitle.index, true),
            );
          } catch (e) {
            debugPrint('Error marking subtitle: $e');
          }
        }
        
        if (mounted && widget.onSubtitleCommentUpdated != null) {
          try {
            await _awaitCallbackResult(
              widget.onSubtitleCommentUpdated!(subtitle.index, comment),
            );
          } catch (e) {
            debugPrint('Error updating subtitle comment: $e');
          }
        }

        if (wasPlaying && mounted && !hasResumed) {
          hasResumed = true;
          _player.play();
          debugPrint('Resumed video after comment save');
        }
      },
      onCommentDeleted: () async {
        if (mounted && widget.onSubtitleCommentUpdated != null) {
          try {
            await _awaitCallbackResult(
              widget.onSubtitleCommentUpdated!(subtitle.index, null),
            );
          } catch (e) {
            debugPrint('Error deleting subtitle comment: $e');
          }
        }

        if (wasPlaying && mounted && !hasResumed) {
          hasResumed = true;
          _player.play();
          debugPrint('Resumed video after comment delete');
        }
      },
    ).then((_) {
      // This executes when the dialog is dismissed (by canceling without save/delete)
      // Resume video if it was playing before dialog opened and we haven't already resumed it
      if (wasPlaying && mounted && !hasResumed) {
        _player.play();
        debugPrint('Resumed video after comment dialog dismissed');
      }
    });
  }
}
