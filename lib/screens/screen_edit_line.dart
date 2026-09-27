import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:isar_community/isar.dart';
import 'package:provider/provider.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/database_helper.dart';
import 'package:subtitle_studio/themes/theme_switcher_button.dart';
import 'package:subtitle_studio/utils/srt_compiler.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:subtitle_studio/utils/platform_file_handler.dart';
import 'package:subtitle_studio/operations/subtitle_sync_operations.dart';

import 'package:subtitle_studio/operations/subtitle_operations.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';
import 'package:subtitle_studio/widgets/formatting_menu.dart';

import 'package:subtitle_studio/widgets/subtitle_actions_menu.dart';
import 'package:subtitle_studio/database/models/preferences_model.dart';
import 'package:subtitle_studio/screens/screen_help.dart';
import 'package:subtitle_studio/widgets/settings_sheet.dart';
import 'package:subtitle_studio/widgets/first_time_instructions.dart';
import 'package:subtitle_studio/widgets/secondary_subtitle_sheet.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';
import 'package:subtitle_studio/utils/responsive_layout.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart' as hotkey;
import 'package:subtitle_studio/widgets/scrolling_title_widget.dart';
import 'package:subtitle_studio/widgets/marked_lines_sheet.dart';
import 'package:subtitle_studio/widgets/checkpoint_sheet.dart';
import 'package:subtitle_studio/widgets/comment_dialog.dart';
import 'package:subtitle_studio/widgets/goto_line_sheet.dart';
import 'package:subtitle_studio/utils/time_parser.dart';
import 'package:subtitle_studio/utils/video_player_readiness.dart';
import 'package:subtitle_studio/utils/text_formatting.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/utils/unicode_text_input_formatter.dart';
import 'package:subtitle_studio/themes/theme_provider.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_text_field.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/time_component_field.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_video_pane.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_color_picker_sheet.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/save_location_sheet.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_dialogs.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_menu.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_placeholders.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/dictionary_sheets.dart';
import 'package:subtitle_studio/screens/edit_line/services/ai_context_builder.dart';
import 'package:subtitle_studio/widgets/ai_explanation_sheet.dart';

part 'edit_line/parts/edit_line_dialog_actions.dart';
part 'edit_line/parts/edit_line_persistence.dart';
part 'edit_line/parts/edit_line_responsive_layout.dart';
part 'edit_line/parts/edit_line_repeat_engine.dart';

// Edit subtitle line screen with video player integration
// Uses Riverpod for state management, character counting, and time validation
// Supports keyboard shortcuts, formatting, and responsive layouts

class EditSubtitleScreen extends riverpod.ConsumerStatefulWidget {
  final Id subtitleId; // ID of the subtitle collection
  final int index; // Index of the subtitle line
  final int sessionId;
  final bool isNewSubtitle; // Indicates if this is a new subtitle
  final bool editMode; // New parameter to indicate if session is in edit mode
  // Video-related parameters
  final String? videoPath;
  final bool isVideoLoaded;
  final Duration? startVideoPosition;
  // Secondary subtitle parameters
  final List<SimpleSubtitleLine>? secondarySubtitles;

  const EditSubtitleScreen({
    super.key,
    required this.subtitleId,
    required this.index,
    required this.sessionId,
    this.isNewSubtitle = false,
    this.editMode =
        false, // Default to false (translation mode) for backward compatibility
    this.videoPath,
    this.isVideoLoaded = false,
    this.startVideoPosition,
    this.secondarySubtitles,
  });

  @override
  riverpod.ConsumerState<EditSubtitleScreen> createState() => EditSubtitleScreenState();
}

class EditSubtitleScreenState extends riverpod.ConsumerState<EditSubtitleScreen> {
  late TextEditingController _originalController;
  late TextEditingController _editedController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _currentIndexController;
  late ScrollController _scrollController;
  final FocusNode _focusNode = FocusNode();
  final UndoHistoryController _undoHistoryController = UndoHistoryController();
  final List<Color> _colorHistory = []; // Maintain color history
  SubtitleLine? _subtitleLine; // To hold the fetched subtitle line
  SubtitleCollection? _subtitle; // To hold the fetched subtitle collection
  bool isEditingEnabled = false;
  bool _isTimeVisible = false;
  bool isRawEnabled = false;
  bool _isMsoneEnabled = false; // Will be set from SharedPreferences
  bool _isEditMode = false; // Add a mode toggle
  bool _showOriginalLine =
      false; // Track if original line should be shown when edited is empty
  bool _showOriginalTextField =
      true; // Control visibility of original text field
  bool _autoSaveWithNavigation = true; // Default to true now
  bool _isSaveToFileEnabled =
      false; // New variable to track if we should save to file directly
  // Video player related variables
  final GlobalKey<VideoPlayerWidgetState> _videoPlayerKey = GlobalKey();
  bool _isVideoVisible = false;
  bool _isVideoLoaded = false;
  String? _selectedVideoPath;
  List<Subtitle> _subtitles = [];
  bool _autoResizeOnKeyboard = true; // Auto resize video when keyboard appears
  // Removed _isKeyboardVisible to prevent rebuild storms during keyboard animations
  bool _isVideoPlaying = false; // Track video play state

  // Repeat playback feature for current subtitle
  bool _isRepeatModeEnabled = false; // Track if repeat mode is enabled
  Timer? _repeatPlaybackTimer; // Timer for repeat playback monitoring

  // Custom range repeat feature
  bool _isCustomRangeMode = false; // Track if custom range mode is enabled
  int? _customRangeStartIndex; // Start subtitle index for custom range
  int? _customRangeEndIndex; // End subtitle index for custom range

  // Secondary subtitle support
  List<SimpleSubtitleLine> _secondarySubtitles = [];
  List<Subtitle> _secondarySubtitlesForPlayer = [];
  bool _showSecondarySubtitles = false;

  // Resize ratio for desktop layout
  double _resizeRatio = 0.35;
  Timer? _resizeRatioSaveTimer; // Timer for debouncing resize ratio saves
  double? _lastLoggedRatio; // Track last logged ratio to reduce debug noise
  bool _isResizeRatioLoaded =
      false; // Track if resize ratio has been loaded from preferences

  // Mobile video resize state variables
  double _mobileVideoResizeRatio = 0.4;
  Timer? _mobileResizeRatioSaveTimer; // Timer for debouncing mobile resize ratio saves
  bool _isMobileResizeRatioLoaded = false; // Track if mobile resize ratio has been loaded from preferences

  // Layout preference for desktop
  String _layoutPreference = 'layout1'; // Default to layout1

  // Variables to track initial values for unsaved changes detection
  String _initialOriginalText = '';
  String _initialEditedText = '';
  String _initialStartTime = '';
  bool _isCommentDialogOpen = false; // Track if comment dialog is currently visible
  String _initialEndTime = '';

  // Variables to track time validation errors
  String? _startTimeError;
  String? _endTimeError;
  String? _timeOrderError;
  Timer? _characterCountTimer; // Debounce timer for character counting
  Timer? _timeUpdateTimer; // Debounce timer for time field updates
  Timer? _subtitleUpdateTimer; // Debounce timer for subtitle updates

  // Character count and validation variables
  final int _originalCharCount = 0;
  final int _editedCharCount = 0;
  final bool _originalHasLongLine = false;
  final bool _editedHasLongLine = false;

  // Character count update with 50ms debounce
  void _instantCharacterCountUpdate() {
    _characterCountTimer?.cancel();
    _characterCountTimer = Timer(const Duration(milliseconds: 50), () {
      // Character counting handled by EditLineController
    });
  }

  @override
  void initState() {
    super.initState();
    _originalController = TextEditingController();
    _editedController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
    _currentIndexController = TextEditingController();
    _scrollController = ScrollController();

    // Keep Riverpod character-count state synchronized with the text fields.
    _originalController.addListener(() {
      ref
          .read(editLineControllerProvider.notifier)
          .updateOriginalText(_originalController.text);
    });

    _editedController.addListener(() {
      ref
          .read(editLineControllerProvider.notifier)
          .updateEditedText(_editedController.text);
    });

    // Initialize error tracking variables
    _startTimeError = null;
    _endTimeError = null;
    _timeOrderError = null;

    // Initialize edit mode from widget property
    _isEditMode = widget.editMode || widget.isNewSubtitle;

    // Make time visible for new subtitles or in edit mode
    if (widget.isNewSubtitle || _isEditMode) {
      _isTimeVisible = true;
    }

    // Initialize video player state
    _initializeVideoPlayer();

    // Register hotkey shortcuts
    _registerHotkeyShortcuts();

    // Batch all async initialization operations for better performance
    _initializeAsyncData();
  }

  // Optimized async initialization with batched operations
  Future<void> _initializeAsyncData() async {
    try {
      // Run all independent async operations in parallel
      final futures = <Future>[
        _loadColorHistory(),
        _loadMsoneStatus(),
        _loadShowOriginalLine(),
        _loadAutoSaveWithNavigation(),
        _loadSaveToFileEnabled(),
        _loadAutoResizeOnKeyboard(),
        // _loadMaxLineLength() removed - maxLineLength now handled by EditLineRepository
        _loadShowOriginalTextField(),
        _loadResizeRatio(), // Load resize ratio
        _loadMobileResizeRatio(), // Load mobile resize ratio
        _loadLayoutPreference(), // Load layout preference
        if (_isEditMode) _loadSavedVideoPath(),
        _fetchSubtitleLine(widget.subtitleId, widget.index - 1),
      ];

      await Future.wait(futures);

      // Initialize character counts
      _instantCharacterCountUpdate();
    } catch (e) {
      await logError(
        'Error during initialization',
        error: e,
        context: 'EditSubtitleScreen._initializeAsync',
      );
    }
  }

  void _initializeVideoPlayer() {
    _isVideoLoaded = widget.isVideoLoaded;
    _selectedVideoPath = widget.videoPath;
    _isVideoVisible = _isVideoLoaded; // Show video by default if loaded

    // Initialize video playing state
    _isVideoPlaying = false;

    // Initialize secondary subtitles if provided
    if (widget.secondarySubtitles != null &&
        widget.secondarySubtitles!.isNotEmpty) {
      _secondarySubtitles = widget.secondarySubtitles!;
      _showSecondarySubtitles = true;
      _generateSecondarySubtitles();
    } else {
      _showSecondarySubtitles = false;
    }

    // Generate initial subtitles if subtitle data is available
    if (_subtitle != null) {
      _markSubtitlesForRegeneration();
      _generateSubtitles();
    }

    if (_isVideoLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_syncVideoPlayerWhenReady());
      });
    }
  }

  Future<void> _seekWhenVideoPlayerReady(Duration position) async {
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted || player == null) return;
    player.seekTo(position);
    if (_isRepeatModeEnabled) {
      player.pause();
    }
  }

  /// Register hotkey shortcuts using MSoneHotkeyManager
  Future<void> _registerHotkeyShortcuts() async {
    // Unregister HomeScreen shortcuts to prevent conflicts (e.g., Ctrl+E)
    await hotkey.MSoneHotkeyManager.instance.unregisterHomeScreenShortcuts();
    
    await hotkey.MSoneHotkeyManager.instance
        .registerEditSubtitleScreenShortcuts(
          onSave: _handleSaveShortcut,
          onNextLine: _handleNextLineShortcut,
          onPreviousLine: _handlePreviousLineShortcut,
          onTextFormatting: _handleTextFormattingShortcut,
          onDelete: _handleDeleteCurrentShortcut,
          onPlayPause: _handlePlayPauseShortcut,
          // New shortcuts
          onMsoneDictionary: _showMsoneDictionary,
          onOlamDictionary: _showOlamDictionary,
          onUrbanDictionary: _showUrbanDictionary,
          onColorPicker: _handleColorPickerShortcut,
          onMarkLine: _handleMarkLineShortcut,
          onMarkLineAndComment: _handleMarkLineAndCommentShortcut,
          onJumpToLine: _handleJumpToLineShortcut,
          onHelp: _handleHelpShortcut,
          onSettings: _handleSettingsShortcut,
          onPopScreen: _handlePopScreenShortcut,
          // Add video control shortcuts
          onToggleRepeat: _handleToggleRepeatShortcut,
          onToggleRepeatRange: _handleToggleRepeatRangeShortcut,
          onToggleFullscreen: _handleToggleFullscreenShortcut,
          // New split and merge shortcuts
          onSplitLine: _handleSplitLineShortcut,
          onMergeLine: _handleMergeLineShortcut,
          // Video sync shortcut
          onSyncWithVideo: () => _syncWithVideoPosition(),
          // Marked lines sheet shortcut
          onShowMarkedLines: _showMarkedLinesModal,
          // Paste original shortcut
          onPasteOriginal: _handlePasteOriginalShortcut,
        );
  }

  Future<void> _syncVideoPlayerWhenReady() async {
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted || player == null) return;
    _syncVideoPlayerState();
  }

  /// Sync the play/pause button state with the actual video player state
  void _syncVideoPlayerState() {
    if (_videoPlayerKey.currentState != null && mounted) {
      final actualPlayingState = _videoPlayerKey.currentState!.isPlaying();
      if (_isVideoPlaying != actualPlayingState) {
        setState(() {
          _isVideoPlaying = actualPlayingState;
        });
      }
    }
  } // Performance optimization: Track if subtitles need regeneration

  bool _needSubtitleRegeneration = true;

  void _generateSubtitles() {
    if (_subtitle?.lines != null && _needSubtitleRegeneration) {
      final newSubtitles =
          _subtitle!.lines.asMap().entries.map((entry) {
            final index =
                entry.key; // Use array index instead of database index
            final line = entry.value;
            return Subtitle(
              index:
                  index, // This ensures video player uses same indexing as list
              start: parseTimeString(line.startTime),
              end: parseTimeString(line.endTime),
              text:
                  line.edited?.replaceAll('<br>', '\n') ??
                  line.original.replaceAll('<br>', '\n'),
              marked: line.marked,
            );
          }).toList();

      setState(() {
        _subtitles = newSubtitles;
        _needSubtitleRegeneration = false;
      });

      // Update video player with new subtitles (this will check for changes internally)
      if (_videoPlayerKey.currentState != null) {
        _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
      }
    }
  }

  // Method to mark subtitles as needing regeneration
  void _markSubtitlesForRegeneration() {
    _needSubtitleRegeneration = true;
  }

  void _seekVideoToSubtitle() {
    if (_isVideoLoaded &&
        _videoPlayerKey.currentState != null &&
        _subtitleLine != null) {
      final startTime = parseTimeString(_subtitleLine!.startTime);
      // Add 50ms offset to ensure subtitle is visible after seeking
      // This prevents the subtitle from disappearing when seeking to exact start time
      final seekPosition = startTime + const Duration(milliseconds: 50);

      // Check if video player is initialized
      if (_videoPlayerKey.currentState!.isInitialized()) {
        _videoPlayerKey.currentState!.seekTo(seekPosition);
        // Pause video if repeat mode is enabled to prevent autoplay on navigation
        if (_isRepeatModeEnabled) {
          _videoPlayerKey.currentState!.pause();
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_seekWhenVideoPlayerReady(seekPosition));
        });
      }
    }
  }

  /// Toggle repeat playback mode for current subtitle
  /// Start repeat playback for current subtitle or custom range
  /// Stop repeat playback and reset custom range
  /// Update repeat timing for current subtitle without changing play/pause state
  /// Set custom repeat range
  void setCustomRepeatRange(int startIndex, int endIndex) {
    if (startIndex <= endIndex &&
        startIndex >= 0 &&
        endIndex < _subtitles.length) {
      _isCustomRangeMode = true;
      _customRangeStartIndex = startIndex;
      _customRangeEndIndex = endIndex;

      // If repeat mode is already enabled, restart with new range
      if (_isRepeatModeEnabled) {
        _startRepeatPlayback();
      }
    }
  }

  /// Clear custom repeat range and switch to normal repeat mode
  void clearCustomRepeatRange() {
    _isCustomRangeMode = false;
    _customRangeStartIndex = null;
    _customRangeEndIndex = null;

    // If repeat mode is enabled, restart with normal mode
    if (_isRepeatModeEnabled) {
      _startRepeatPlayback();
    }
  }

  // Public interface methods for video player widget

  /// Get subtitles list for external access
  List<Subtitle> get subtitles => _subtitles;

  /// Get repeat mode enabled state
  bool get isRepeatModeEnabled => _isRepeatModeEnabled;

  /// Toggle repeat mode (public method)
  void toggleRepeatMode() => _toggleRepeatMode();

  /// Start repeat playback (public method)
  void startRepeatPlayback() => _startRepeatPlayback();

  // Load video file for edit mode
  Future<void> _pickVideoFile() async {
    final filePath = await FilePickerConvenience.pickVideoFile(
      context: context,
    );

    if (filePath != null) {
      setState(() {
        _selectedVideoPath = filePath;
        _isVideoVisible = true;
        _isVideoLoaded = true;
      });

      // Save video path to preferences for this subtitle collection
      await PreferencesModel.saveVideoPath(widget.subtitleId, filePath);

      // Generate subtitles for video player
      _markSubtitlesForRegeneration();
      _generateSubtitles();

      // Seek to current subtitle if available
      if (_subtitleLine != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _seekVideoToSubtitle();
        });
      }

      // Show success message
      SnackbarHelper.showSuccess(
        context,
        'Video loaded successfully',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // Unload video (optimized single setState)
  Future<void> _unloadVideo() async {
    setState(() {
      _selectedVideoPath = null;
      _isVideoVisible = false;
      _isVideoLoaded = false;
    });

    await PreferencesModel.removeVideoPath(widget.subtitleId);
    SnackbarHelper.showInfo(
      context,
      'Video unloaded',
      duration: const Duration(seconds: 2),
    );
  }

  // Sync with current video position and find nearest subtitle
  Future<void> _syncWithVideoPosition() async {
    if (!_isVideoLoaded || 
        _videoPlayerKey.currentState == null || 
        !_videoPlayerKey.currentState!.isInitialized() ||
        _subtitle?.lines == null) {
      SnackbarHelper.showError(
        context,
        'Video player not ready or no subtitles available',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    try {
      // Get current video position
      final currentPosition = _videoPlayerKey.currentState!.getCurrentPosition();
      
      await logInfo(
        'Sync: Current video position: ${currentPosition.toString()}, subtitle line: ${_subtitleLine!.toString()}',
        context: 'EditSubtitleScreen._handleVideoSync',
      );
      
      // Find the nearest subtitle line
      int nearestIndex = _findNearestSubtitleIndex(currentPosition);
      
      if (nearestIndex == -1) {
        SnackbarHelper.showInfo(
          context,
          'No subtitle found near current video position',
          duration: const Duration(seconds: 2),
        );
        return;
      }
      
      await logInfo(
        'Sync: Found nearest subtitle at index: $nearestIndex (0-based)',
        context: 'EditSubtitleScreen._handleVideoSync',
      );
      
      // Check if the current subtitle line position is the same as the nearest index
      // If so, skip the operation to avoid unnecessary navigation
      if (_subtitleLine != null && _subtitleLine!.index - 1 == nearestIndex) {
        await logInfo(
          'Sync: Current subtitle position is same as nearest index, skipping operation',
          context: 'EditSubtitleScreen._handleVideoSync',
        );
        SnackbarHelper.showInfo(
          context,
          'Already on the nearest subtitle line',
          duration: const Duration(seconds: 1),
        );
        return;
      }
      
      // Check if we need to save current changes before navigating
      if (_hasUnsavedChanges()) {
        final shouldSave = await _showUnsavedChangesDialog();
        if (!shouldSave) return; // User chose to leave without saving or cancelled
      }
      
      // Navigate to the found subtitle line
      // nearestIndex is 0-based, but _skipToLine expects 0-based index
      _skipToLine(widget.subtitleId, nearestIndex);
      
      SnackbarHelper.showSuccess(
        context,
        'Synced to subtitle line ${nearestIndex + 1}',
        duration: const Duration(seconds: 2),
      );
      
    } catch (e) {
      await logError(
        'Error during video sync',
        error: e,
        context: 'EditSubtitleScreen._handleVideoSync',
      );
      SnackbarHelper.showError(
        context,
        'Failed to sync with video position',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // Find the nearest subtitle index based on video position
  int _findNearestSubtitleIndex(Duration currentPosition) {
    if (_subtitle?.lines == null || _subtitle!.lines.isEmpty) {
      return -1;
    }

    int nearestIndex = -1;
    Duration smallestDistance = const Duration(hours: 24); // Large initial value
    
    for (int i = 0; i < _subtitle!.lines.length; i++) {
      final line = _subtitle!.lines[i];
      
      try {
        // Parse subtitle times
        final startTime = _parseSubtitleTime(line.startTime);
        final endTime = _parseSubtitleTime(line.endTime);
        
        final startDuration = Duration(
          hours: startTime.hour,
          minutes: startTime.minute,
          seconds: startTime.second,
          milliseconds: startTime.millisecond,
        );
        
        final endDuration = Duration(
          hours: endTime.hour,
          minutes: endTime.minute,
          seconds: endTime.second,
          milliseconds: endTime.millisecond,
        );
        
        // Check if current position is within subtitle time range
        if (currentPosition >= startDuration && currentPosition <= endDuration) {
          // Direct match - current position is within this subtitle's timing
          return i;
        }
        
        // Calculate distance to subtitle start time
        final distanceToStart = (currentPosition - startDuration).abs();
        
        // Update nearest if this is closer
        if (distanceToStart < smallestDistance) {
          smallestDistance = distanceToStart;
          nearestIndex = i;
        }
        
        // Also check distance to end time for better accuracy
        final distanceToEnd = (currentPosition - endDuration).abs();
        if (distanceToEnd < smallestDistance) {
          smallestDistance = distanceToEnd;
          nearestIndex = i;
        }
        
      } catch (e) {
        logWarning(
          'Error parsing time for subtitle $i: $e',
          context: 'EditSubtitleScreen._findNearestSubtitleIndex',
        );
        continue;
      }
    }
    
    return nearestIndex;
  }

  // Optimized settings loading with single setState
  Future<void> _loadMsoneStatus() async {
    final msoneEnabled = await PreferencesModel.getMsoneEnabled();
    if (mounted) {
      setState(() {
        _isMsoneEnabled = msoneEnabled;
      });
    }
  }

  // Optimized settings reload with single setState
  Future<void> _reloadAllSettings() async {
    final results = await Future.wait([
      PreferencesModel.getMsoneEnabled(),
      PreferencesModel.getSaveToFileEnabled(),
      PreferencesModel.getAutoResizeOnKeyboard(),
      PreferencesModel.getMaxLineLength(),
    ]);

    if (mounted) {
      setState(() {
        _isMsoneEnabled = results[0] as bool;
        _isSaveToFileEnabled = results[1] as bool;
        _autoResizeOnKeyboard = results[2] as bool;
        // results[3] was _maxLineLength - no longer needed (handled by Bloc)
      });

      // Character counts will be recalculated by Cubit when text changes
    }
  }

  // Optimized color history loading
  Future<void> _loadColorHistory() async {
    final colorStrings = await PreferencesModel.getColorHistory();
    if (mounted) {
      setState(() {
        _colorHistory.clear();
        _colorHistory.addAll(
          colorStrings.map((color) => Color(int.parse(color))),
        );
      });
    }
  }

  Future<void> _saveColorHistory() async {
    final colorStrings =
        _colorHistory
            .map(
              (color) =>
                  '${(color.a * 255).round() << 24 | (color.r * 255).round() << 16 | (color.g * 255).round() << 8 | (color.b * 255).round()}',
            )
            .toList();
    await PreferencesModel.saveColorHistory(colorStrings);
  }

  Future<void> _loadShowOriginalLine() async {
    final showOriginalLine = await PreferencesModel.getShowOriginalLine();
    setState(() {
      _showOriginalLine = showOriginalLine;
    });
  }

  Future<void> _saveShowOriginalLine(bool value) async {
    setState(() {
      _showOriginalLine = value;
      // When enabling Show Original Line, default auto-save to false
      if (value) {
        _autoSaveWithNavigation = false;
      } else {
        _autoSaveWithNavigation =
            true; // Always true when Show Original Line is disabled
      }
    });

    await PreferencesModel.setShowOriginalLine(value);
    // Update the auto-save setting in preferences
    if (value) {
      await PreferencesModel.setAutoSaveWithNavigation(false);
    } else {
      await PreferencesModel.setAutoSaveWithNavigation(true);
    }

    _applyShowOriginalLine();
  }

  Future<void> _loadAutoSaveWithNavigation() async {
    final autoSave = await PreferencesModel.getAutoSaveWithNavigation();
    final showOriginal = await PreferencesModel.getShowOriginalLine();

    setState(() {
      // Auto-save is true by default unless Show Original Line is enabled
      if (showOriginal) {
        _autoSaveWithNavigation = autoSave;
      } else {
        _autoSaveWithNavigation = true; // Always true in normal mode
      }
    });
  }

  Future<void> _saveAutoSaveWithNavigation(bool value) async {
    setState(() {
      _autoSaveWithNavigation = value;
    });
    await PreferencesModel.setAutoSaveWithNavigation(value);
  }

  Future<void> _loadSaveToFileEnabled() async {
    final saveToFileEnabled =
        await PreferencesModel.getSaveToFileEnabled();
    setState(() {
      _isSaveToFileEnabled = saveToFileEnabled;
    });
  }

  Future<void> _loadAutoResizeOnKeyboard() async {
    final autoResizeOnKeyboard = await PreferencesModel.getAutoResizeOnKeyboard();
    setState(() {
      _autoResizeOnKeyboard = autoResizeOnKeyboard;
    });
  }

  // Load show original text field setting
  Future<void> _loadShowOriginalTextField() async {
    try {
      final showOriginalTextField =
          await PreferencesModel.getShowOriginalTextField();
      setState(() {
        _showOriginalTextField = showOriginalTextField;
      });
    } catch (e) {
      // Default to true if loading fails
      setState(() {
        _showOriginalTextField = true;
      });
    }
  }

  // Save show original text field setting
  Future<void> _saveShowOriginalTextField(bool value) async {
    try {
      await PreferencesModel.setShowOriginalTextField(value);
      setState(() {
        _showOriginalTextField = value;
      });
    } catch (e) {
      logError(
        'Failed to save show original text field setting',
        error: e,
        context: 'EditSubtitleScreen._saveShowOriginalTextField',
      );
    }
  }

  // Load saved video path for edit mode
  Future<void> _loadSavedVideoPath() async {
    if (_isEditMode || widget.isNewSubtitle) {
      final savedPath = await PreferencesModel.getVideoPath(
        widget.subtitleId,
      );
      if (savedPath != null && mounted) {
        setState(() {
          _selectedVideoPath = savedPath;
          _isVideoVisible = true;
          _isVideoLoaded = true;
        });
      }
    }
  }

  // Load resize ratio preference
  Future<void> _loadResizeRatio() async {
    final ratio = await PreferencesModel.getEditLineResizeRatio();
    await logInfo(
      'Loading resize ratio: $ratio',
      context: 'EditSubtitleScreen._loadResizeRatio',
    );
    if (mounted) {
      setState(() {
        _resizeRatio = ratio;
        _isResizeRatioLoaded = true;
      });
      await logInfo(
        'Updated _resizeRatio to: $_resizeRatio, loaded: $_isResizeRatioLoaded',
        context: 'EditSubtitleScreen._loadResizeRatio',
      );
    }
  }

  // Save resize ratio preference with debouncing
  Future<void> _saveResizeRatio(double ratio) async {
    // Only log when ratio changes significantly
    if (_lastLoggedRatio == null || (ratio - _lastLoggedRatio!).abs() > 0.05) {
      await logInfo(
        '_saveResizeRatio called with: $ratio',
        context: 'EditSubtitleScreen._saveResizeRatio',
      );
      _lastLoggedRatio = ratio;
    }

    setState(() {
      _resizeRatio = ratio;
    });

    // Cancel any existing timer
    _resizeRatioSaveTimer?.cancel();

    // Start a new timer to save after a short delay
    _resizeRatioSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      await logInfo(
        'Timer saving ratio to SharedPreferences: $ratio',
        context: 'EditSubtitleScreen._saveResizeRatio',
      );
      await PreferencesModel.setEditLineResizeRatio(ratio);
      await logInfo(
        'Save completed - verification: ${await PreferencesModel.getEditLineResizeRatio()}',
        context: 'EditSubtitleScreen._saveResizeRatio',
      );
    });
  }

  /// Load mobile video resize ratio from preferences
  Future<void> _loadMobileResizeRatio() async {
    if (!mounted) return;
    
    try {
      final ratio = await PreferencesModel.getMobileVideoResizeRatio();
      if (mounted) {
        setState(() {
          _mobileVideoResizeRatio = ratio;
          _isMobileResizeRatioLoaded = true;
        });
      }
    } catch (e) {
      logError(
        'Error loading mobile resize ratio',
        error: e,
        context: 'EditSubtitleScreen._loadMobileResizeRatio',
      );
      if (mounted) {
        setState(() {
          _mobileVideoResizeRatio = 0.4; // Default fallback
          _isMobileResizeRatioLoaded = true;
        });
      }
    }
  }

  /// Save mobile video resize ratio with debouncing
  void _saveMobileResizeRatio(double ratio) {
    // Cancel any existing timer
    _mobileResizeRatioSaveTimer?.cancel();
    
    // Set up a new timer with 500ms delay
    _mobileResizeRatioSaveTimer = Timer(Duration(milliseconds: 500), () async {
      try {
        await PreferencesModel.setMobileVideoResizeRatio(ratio);
      } catch (e) {
        logError(
          'Error saving mobile resize ratio',
          error: e,
          context: 'EditSubtitleScreen._saveMobileResizeRatio',
        );
      }
    });
  }

  /// Load layout preference for desktop layout switching
  Future<void> _loadLayoutPreference() async {
    final layout = await PreferencesModel.getSwitchLayout();
    if (mounted) {
      setState(() {
        _layoutPreference = layout;
      });
    }
  }

  Future<void> _saveAutoResizeOnKeyboard(bool value) async {
    setState(() {
      _autoResizeOnKeyboard = value;
    });
    await PreferencesModel.setAutoResizeOnKeyboard(value);
  }

  void _applyShowOriginalLine() {
    if (_showOriginalLine &&
        (_editedController.text.isEmpty || _editedController.text == '') &&
        _originalController.text.isNotEmpty) {
      setState(() {
        _editedController.text = _originalController.text;
      });
    }
  }

  // Store the initial values when a subtitle line is loaded
  void _storeInitialValues() {
    _initialOriginalText = _originalController.text;
    _initialEditedText = _editedController.text;
    _initialStartTime = _startTimeController.text;
    _initialEndTime = _endTimeController.text;
  }

  // Parse time string (HH:mm:ss,SSS) and set the corresponding controller
  void _parseTimeString(String timeString, bool isStartTime) {
    try {
      // If time string is valid, set it directly to the controller
      if (timeString.isNotEmpty) {
        if (isStartTime) {
          _startTimeController.text = timeString;
        } else {
          _endTimeController.text = timeString;
        }
      } else {
        // Set default values
        if (isStartTime) {
          _startTimeController.text = '00:00:00,000';
        } else {
          _endTimeController.text = '00:00:05,000';
        }
      }
    } catch (e) {
      // If parsing fails, set default values
      if (isStartTime) {
        _startTimeController.text = '00:00:00,000';
      } else {
        _endTimeController.text = '00:00:05,000';
      }
    }
  }

  // Get time string from the corresponding controller
  String _combineTimeComponents(bool isStartTime) {
    try {
      String timeString = isStartTime ? _startTimeController.text : _endTimeController.text;
      
      // If the controller is empty, return default time
      if (timeString.isEmpty) {
        return isStartTime ? '00:00:00,000' : '00:00:05,000';
      }
      
      return timeString;
    } catch (e) {
      // Return default time if there's an error
      return isStartTime ? '00:00:00,000' : '00:00:05,000';
    }
  }

  // Validate time components and show errors if any
  String? _validateTimeComponents(bool isStartTime) {
    try {
      String timeString = isStartTime ? _startTimeController.text : _endTimeController.text;
      return TimeValidator.validateTimeString(timeString);
    } catch (e) {
      return 'Invalid time format';
    }
  }

  // Validate that start time is less than end time
  String? _validateTimeOrder() {
    String startTime = _combineTimeComponents(true);
    String endTime = _combineTimeComponents(false);

    return TimeValidator.validateTimeOrder(startTime, endTime);
  }

  // Sync time from video for start time
  void _syncStartTimeFromVideo() {
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final currentPosition =
          _videoPlayerKey.currentState!.getCurrentPosition();
      final timeString = SubtitleSyncOperations.formatDuration(currentPosition);

      // Parse the time string into components
      _parseTimeString(timeString, true);

      // Update the combined controller
      _updateCombinedTimeControllers();

      // Show feedback to user
      SnackbarHelper.showSuccess(
        context,
        'Start time synced to current video position: $timeString',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // Sync time from video for end time
  void _syncEndTimeFromVideo() {
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final currentPosition =
          _videoPlayerKey.currentState!.getCurrentPosition();
      final timeString = SubtitleSyncOperations.formatDuration(currentPosition);

      // Parse the time string into components
      _parseTimeString(timeString, false);

      // Update the combined controller
      _updateCombinedTimeControllers();

      // Show feedback to user
      SnackbarHelper.showSuccess(
        context,
        'End time synced to current video position: $timeString',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // Instant time controller updates (removed debouncing for maximum responsiveness)
  void _updateCombinedTimeControllers({bool validateTime = false}) {
    // Cancel any pending timer and update immediately
    _timeUpdateTimer?.cancel();

    if (!mounted) return;

    // Preserve cursor positions before updating text
    final startCursor = _startTimeController.selection;
    final endCursor = _endTimeController.selection;

    final newStartText = _combineTimeComponents(true);
    final newEndText = _combineTimeComponents(false);

    // Only update text if it actually changed to avoid cursor reset
    if (_startTimeController.text != newStartText) {
      _startTimeController.text = newStartText;
    } else {
      // Text didn't change, restore cursor position that might have been affected
      _startTimeController.selection = startCursor;
    }

    if (_endTimeController.text != newEndText) {
      _endTimeController.text = newEndText;  
    } else {
      // Text didn't change, restore cursor position that might have been affected
      _endTimeController.selection = endCursor;
    }

    // If validation is explicitly requested, validate and set errors
    if (validateTime) {
      setState(() {
        _startTimeError = _validateTimeComponents(true);
        _endTimeError = _validateTimeComponents(false);
        _timeOrderError = _validateTimeOrder();
      });
    } else {
      // If there were previous validation errors, re-validate to potentially clear them
      // This allows real-time validation clearing when user fixes time values
      if (_startTimeError != null ||
          _endTimeError != null ||
          _timeOrderError != null) {
        setState(() {
          _startTimeError = _validateTimeComponents(true);
          _endTimeError = _validateTimeComponents(false);
          _timeOrderError = _validateTimeOrder();
        });
      }
    }
  }

  // Build simplified time input field
  Widget _buildTimeComponentFields(String label, bool isStartTime) {
    final timeController =
        isStartTime ? _startTimeController : _endTimeController;
    final componentError =
        isStartTime ? _startTimeError : _endTimeError;

    return TimeComponentField(
      label: label,
      isStartTime: isStartTime,
      timeController: timeController,
      isVideoLoaded: _isVideoLoaded,
      fallbackComponentError: componentError,
      fallbackOrderError: _timeOrderError,
      onSync: isStartTime
          ? _syncStartTimeFromVideo
          : _syncEndTimeFromVideo,
      onTimeChanged: () => _updateCombinedTimeControllers(),
      onEditingComplete: () =>
          _updateCombinedTimeControllers(validateTime: true),
    );
  }

  // Check if there are unsaved changes
  bool _hasUnsavedChanges() {
    // Check text field changes
    bool hasTextChanges =
        _originalController.text != _initialOriginalText ||
        _editedController.text != _initialEditedText;

    // Check time changes using combined controllers
    bool hasTimeChanges =
        _startTimeController.text != _initialStartTime ||
        _endTimeController.text != _initialEndTime;

    // Also check if current time component state differs from initial combined time
    // This ensures we catch cases where time components have changed but may not
    // have been reflected in combined controllers yet
    if (!hasTimeChanges) {
      String currentStartTime = _combineTimeComponents(true);
      String currentEndTime = _combineTimeComponents(false);
      hasTimeChanges =
          currentStartTime != _initialStartTime ||
          currentEndTime != _initialEndTime;
    }

    return hasTextChanges || hasTimeChanges;
  }

  // Show confirmation dialog for unsaved changes
  Future<bool> _showUnsavedChangesDialog() async {
    return showUnsavedChangesSheet(
      context: context,
      onLeaveWithoutSaving: () {
        final currentIndex =
            _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
        Navigator.of(context).pop(currentIndex);
      },
      onSave: () => _updateSubtitle(context),
      onSavedAndLeave: () {
        final currentIndex =
            _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
        Navigator.of(context).pop(currentIndex);
      },
    );
  }

  Future<void> _showOriginalLineWarningDialog(
    bool enableShowOriginal,
  ) async {
    await showOriginalLineWarningSheet(
      context: context,
      enableShowOriginal: enableShowOriginal,
      onContinue: () => _saveShowOriginalLine(enableShowOriginal),
    );
  }

  @override
  void dispose() {
    // Cancel any pending timers
    _characterCountTimer?.cancel();
    _timeUpdateTimer?.cancel();
    _subtitleUpdateTimer?.cancel();
    _repeatPlaybackTimer?.cancel(); // Cancel repeat playback timer
    _resizeRatioSaveTimer?.cancel(); // Cancel resize ratio save timer
    _mobileResizeRatioSaveTimer?.cancel(); // Cancel mobile resize ratio save timer

    // Dispose AI Explanation Cubit

    // Remove character count listeners before disposing
    _originalController.removeListener(_instantCharacterCountUpdate);
    _editedController.removeListener(_instantCharacterCountUpdate);

    _originalController.dispose();
    _editedController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _currentIndexController.dispose();
    _scrollController.dispose();

    _saveColorHistory(); // Save color history when the screen is disposed

    // Unregister only this screen's hotkey shortcuts (not all shortcuts globally)
    // This prevents breaking shortcuts in the parent EditScreen
    hotkey.MSoneHotkeyManager.instance.unregisterEditSubtitleScreenShortcuts();

    super.dispose();
  }

  /// Check if there are any validation errors that would prevent navigation
  bool _hasValidationErrors() {
    return _startTimeError != null ||
        _endTimeError != null ||
        _timeOrderError != null;
  }

  void _nextSubtitle(subtitleId, lineIndex) async {
    // Don't stop repeat mode when navigating - let it continue
    // Only stop if we're outside the custom range
    if (_isRepeatModeEnabled && _isCustomRangeMode) {
      final nextIndex = _subtitleLine?.index ?? 0;
      if (_customRangeEndIndex != null && nextIndex > _customRangeEndIndex!) {
        // We're going beyond the custom range, keep repeat but pause it temporarily
        _stopRepeatPlayback();
      }
    }

    // Check for validation errors first
    if (_hasValidationErrors()) {
      SnackbarHelper.showError(
        context,
        'Please fix validation errors before navigating',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Verify the next index is within bounds before navigating
    if (lineIndex > 0 && lineIndex <= _subtitle!.lines.length) {
      // Save changes if auto-save is enabled or we're in normal mode
      if (_autoSaveWithNavigation || !_showOriginalLine) {
        final saveSuccess = await _updateSubtitleSilently();
        if (!saveSuccess) {
          // Don't navigate if save failed
          return;
        }
      }
      // Navigate to next subtitle
      await _fetchSubtitleLine(subtitleId, lineIndex - 1);

      // Resume repeat if enabled
      if (_isRepeatModeEnabled) {
        final currentIndex =
            (_subtitleLine?.index ?? 1) - 1; // Convert to 0-based
        if (!_isCustomRangeMode) {
          // For normal repeat mode, update to the new subtitle line
          // This will update repeat timing with the new subtitle without changing play/pause state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateRepeatTiming();
          });
        } else if (_customRangeStartIndex != null &&
            _customRangeEndIndex != null &&
            currentIndex >= _customRangeStartIndex! &&
            currentIndex <= _customRangeEndIndex!) {
          // For custom range mode, only restart if we're still in range
          // Video is already paused by _seekVideoToSubtitle when repeat mode is enabled
          // User needs to manually start playback
        }
      }
    } else {
      // Show a message when there's no next subtitle
      SnackbarHelper.showWarning(
        context,
        'This is the last subtitle',
        duration: const Duration(seconds: 1),
      );
    }
  }

  void _prevSubtitle(subtitleId, lineIndex) async {
    // Don't stop repeat mode when navigating - let it continue
    // Only stop if we're outside the custom range
    if (_isRepeatModeEnabled && _isCustomRangeMode) {
      final prevIndex =
          (_subtitleLine?.index ?? 2) - 2; // Previous index in 0-based
      if (_customRangeStartIndex != null &&
          prevIndex < _customRangeStartIndex!) {
        // We're going before the custom range, keep repeat but pause it temporarily
        _stopRepeatPlayback();
      }
    }

    // Check for validation errors first
    if (_hasValidationErrors()) {
      SnackbarHelper.showError(
        context,
        'Please fix validation errors before navigating',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (lineIndex > 0 && lineIndex <= _subtitle!.lines.length) {
      // Save changes if auto-save is enabled or we're in normal mode
      if (_autoSaveWithNavigation || !_showOriginalLine) {
        final saveSuccess = await _updateSubtitleSilently();
        if (!saveSuccess) {
          // Don't navigate if save failed
          return;
        }
      }
      // Navigate to the previous subtitle line (lineIndex is 1-based, convert to 0-based for array access)
      await _fetchSubtitleLine(subtitleId, lineIndex - 1);

      // Resume repeat if we're in range and it was enabled
      if (_isRepeatModeEnabled) {
        final currentIndex =
            (_subtitleLine?.index ?? 1) - 1; // Convert to 0-based
        if (!_isCustomRangeMode) {
          // For normal repeat mode, update to the new subtitle line
          // This will update repeat timing with the new subtitle without changing play/pause state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateRepeatTiming();
          });
        } else if (_customRangeStartIndex != null &&
            _customRangeEndIndex != null &&
            currentIndex >= _customRangeStartIndex! &&
            currentIndex <= _customRangeEndIndex!) {
          // For custom range mode, only restart if we're still in range
          // Video is already paused by _seekVideoToSubtitle when repeat mode is enabled
          // User needs to manually start playback
        }
      }
    } else {
      // Show a message when there's no previous subtitle
      SnackbarHelper.showWarning(
        context,
        'This is the first subtitle',
        duration: const Duration(seconds: 1),
      );
    }
  }

  void _skipToLine(subtitleId, lineIndex) {
    // Check if we're navigating outside custom range
    if (_isRepeatModeEnabled && _isCustomRangeMode) {
      if (_customRangeStartIndex != null &&
          _customRangeEndIndex != null &&
          (lineIndex < _customRangeStartIndex! ||
              lineIndex > _customRangeEndIndex!)) {
        // We're going outside the custom range, pause repeat temporarily
        _stopRepeatPlayback();
      }
    }

    // Navigate to the specified subtitle line
    setState(() {
      _fetchSubtitleLine(subtitleId, lineIndex);
    });

    // Resume repeat if we're in range and it was enabled
    if (_isRepeatModeEnabled) {
      if (!_isCustomRangeMode) {
        // For normal repeat mode, update to the new subtitle line
        // This will update repeat timing with the new subtitle without changing play/pause state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateRepeatTiming();
        });
      } else if (_customRangeStartIndex != null &&
          _customRangeEndIndex != null &&
          lineIndex >= _customRangeStartIndex! &&
          lineIndex <= _customRangeEndIndex!) {
        // For custom range mode, only restart if we're still in range
        // Video is already paused by _seekVideoToSubtitle when repeat mode is enabled
        // User needs to manually start playback
      }
    }
  }

  // Helper function to parse subtitle time
  DateTime _parseSubtitleTime(String time) {
    // Assuming the time format is "HH:mm:ss,SSS" (e.g., "00:01:23,456")
    List<String> parts = time.split(',');
    List<String> hms = parts[0].split(':');
    int hours = int.parse(hms[0]);
    int minutes = int.parse(hms[1]);
    int seconds = int.parse(hms[2]);
    int milliseconds = int.parse(parts[1]);

    return DateTime(0, 1, 1, hours, minutes, seconds, milliseconds);
  }

  void _generateSecondarySubtitles() {
    setState(() {
      _secondarySubtitlesForPlayer =
          _secondarySubtitles.asMap().entries.map((entry) {
            final index =
                entry.key; // Use array index instead of database index
            final line = entry.value;
            return Subtitle(
              index:
                  index, // This ensures video player uses same indexing as list
              start: parseTimeString(line.startTime),
              end: parseTimeString(line.endTime),
              text: line.text.replaceAll('<br>', '\n'),
              marked: false, // Secondary subtitles don't have marked field
            );
          }).toList();
    });

    // Update video player with new secondary subtitles
    if (_videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.updateSecondarySubtitles(
        _secondarySubtitlesForPlayer,
      );
    }
  }

  void _toggleSecondarySubtitles() {
    // Toggle visibility
    setState(() {
      _showSecondarySubtitles = !_showSecondarySubtitles;
    });

    // Ensure secondary subtitles are loaded from constructor if available but not yet initialized
    if (_showSecondarySubtitles &&
        _secondarySubtitles.isEmpty &&
        widget.secondarySubtitles != null &&
        widget.secondarySubtitles!.isNotEmpty) {
      _secondarySubtitles = widget.secondarySubtitles!;
      _generateSecondarySubtitles();
    }

    // Update video player with secondary subtitles based on visibility
    if (_videoPlayerKey.currentState != null) {
      if (_showSecondarySubtitles && _secondarySubtitlesForPlayer.isNotEmpty) {
        _videoPlayerKey.currentState!.updateSecondarySubtitles(
          _secondarySubtitlesForPlayer,
        );
      } else {
        _videoPlayerKey.currentState!.updateSecondarySubtitles([]);
      }
    }
  }

  // Show edit line menu modal
  void _showEditLineMenuModal() {
    showEditLineMenu(
      context: context,
      isEditMode: _isEditMode,
      isNewSubtitle: widget.isNewSubtitle,
      isVideoLoaded: _isVideoLoaded,
      hasSecondarySubtitles: _secondarySubtitles.isNotEmpty,
      showSecondarySubtitles: _showSecondarySubtitles,
      autoResizeOnKeyboard: _autoResizeOnKeyboard,
      isMobilePlatform: ResponsiveLayout.isMobilePlatform(),
      showOriginalLine: _showOriginalLine,
      autoSaveWithNavigation: _autoSaveWithNavigation,
      showOriginalTextField: _showOriginalTextField,
      isFormattedView: isRawEnabled,
      isMarked: _subtitleLine?.marked ?? false,
    ).then(_handleEditLineMenuSelection);
  }

  // Handle edit line menu selection
  // Toggle mark status of the current subtitle line
  Future<void> _toggleMarkLine() async {
    if (_subtitleLine == null) return;

    final currentMarked = _subtitleLine!.marked;
    final newMarked = !currentMarked;
    final lineIndex = _subtitleLine!.index - 1;

    logInfo(
      'ToggleMarkLine: subtitleId=${widget.subtitleId}, subtitleIndex=${_subtitleLine!.index}, arrayIndex=$lineIndex, newMarked=$newMarked',
      context: 'EditSubtitleScreen._toggleMarkLine',
    );

    try {
      final success = await markSubtitleLine(
        widget.subtitleId,
        lineIndex,
        newMarked,
      );
      if (success) {
        setState(() {
          _subtitleLine!.marked = newMarked;
        });

        // Refresh subtitle collection data and update video player
        _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;
        _markSubtitlesForRegeneration();
        _generateSubtitles();

        // Show success message
        SnackbarHelper.showSuccess(
          context,
          newMarked ? 'Line marked' : 'Line unmarked',
          duration: const Duration(seconds: 1),
        );
      } else {
        SnackbarHelper.showError(context, 'Failed to update mark status - check debug log for details');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not update mark status. Please try again.');
    }
  }

  // Show comment dialog for current line
  // Show marked lines modal
  // Show Edit History modal (responsive dialog)
  // Show jump to line modal
  Future<void> _showJumpToLineModal() async {
    if (_subtitle?.lines == null || _subtitle!.lines.isEmpty) {
      SnackbarHelper.showError(context, 'No subtitle lines available');
      return;
    }

    final totalLines = _subtitle!.lines.length;
    final currentLine = _subtitleLine?.index.toString() ?? '1';

    showGotToLineModal(
      context: context,
      initialValue: currentLine,
      hintText: totalLines,
      title: 'Jump to Line',
      onSubmitted: (value) {
        final lineNumber = int.tryParse(value);
        if (lineNumber != null && lineNumber >= 1 && lineNumber <= totalLines) {
          // Convert 1-based line number to 0-based index for _skipToLine
          _skipToLine(widget.subtitleId, lineNumber - 1);
        }
      },
    );
  }

  String _selectedOrFullOriginalText() {
    final selection = _originalController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      return _originalController.text.substring(
        selection.start,
        selection.end,
      );
    }
    return _originalController.text;
  }

  void _showOlamDictionary() {
    showOlamDictionarySheet(
      context: context,
      initialSearchTerm: _selectedOrFullOriginalText(),
      onSelectTranslation: (text) {
        _editedController.text = text;
      },
    );
  }

  void _showUrbanDictionary() {
    showUrbanDictionarySheet(
      context: context,
      initialSearchTerm: _selectedOrFullOriginalText(),
      onSelectTranslation: (text) {
        _editedController.text = text;
      },
    );
  }

  void _showMsoneDictionary() {
    showMsoneDictionarySheet(
      context: context,
      initialSearchTerm: _selectedOrFullOriginalText(),
      onSelectTranslation: (text) {
        _editedController.text = text;
      },
    );
  }

  // Show Secondary Subtitle modal
  Future<void> _showSecondarySubtitleModal() async {
    if (!mounted) return;

    // Get the current subtitle lines
    List<SubtitleLine> originalSubtitles = [];
    if (_subtitle?.lines != null) {
      originalSubtitles = _subtitle!.lines;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      builder: (context) {
        return SecondarySubtitleSheet(
          originalSubtitles: originalSubtitles,
          subtitleCollectionId: widget.subtitleId,
          videoPlayerState: _videoPlayerKey.currentState,
          onSecondarySubtitlesLoaded: (secondarySubtitles) {
            setState(() {
              _secondarySubtitles = secondarySubtitles;
              _showSecondarySubtitles = true;
              _generateSecondarySubtitles();
            });
            if (mounted) {
              SnackbarHelper.showSuccess(context, 'Secondary subtitles loaded');
            }
          },
        );
      },
    );
  }

  // Show AI Explanation - triggers the AI explanation feature
  Future<void> _showAiExplanation() async {
    final currentText = _editedController.text.isEmpty
        ? _originalController.text
        : _editedController.text;

    final aiContext = EditLineAiContextBuilder.build(
      lines: _subtitle?.lines ?? const <SubtitleLine>[],
      currentIndex: (_subtitleLine?.index ?? 1) - 1,
      useEditedText: _isEditMode,
      contextRadius: 3,
    );

    if (!mounted) return;
    AiExplanationSheet.show(
      context: context,
      currentText: currentText,
      previousLines: aiContext.previousLines,
      nextLines: aiContext.nextLines,
      allLines: aiContext.allLines,
      currentIndex: aiContext.currentIndex,
      originalAllLines: aiContext.originalAllLines,
      editedAllLines: aiContext.editedAllLines,
    );
  }

  // Handle mark/unmark from video player fullscreen controls
  Future<void> _handleVideoPlayerMarkToggle(
    int subtitleIndex,
    bool isMarked,
  ) async {
    logInfo(
      'HandleVideoPlayerMarkToggle: subtitleIndex=$subtitleIndex (0-based array index), isMarked=$isMarked',
      context: 'EditSubtitleScreen._handleVideoPlayerMarkToggle',
    );
    
    try {
      final success = await markSubtitleLine(
        widget.subtitleId,
        subtitleIndex, // subtitleIndex is already 0-based array index
        isMarked,
      );
      if (success) {
        // Update the current subtitle line if it matches
        // Note: _subtitleLine.index is 1-based, so we need to check subtitleIndex + 1
        if (_subtitleLine != null && _subtitleLine!.index == subtitleIndex + 1) {
          setState(() {
            _subtitleLine!.marked = isMarked;
          });
        }

        // Refresh subtitle collection data from database to ensure all data is current
        _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;

        // Update the subtitles list for video player
        _markSubtitlesForRegeneration();
        _generateSubtitles();

        // Show success message
        SnackbarHelper.showSuccess(
          context,
          isMarked ? 'Line marked' : 'Line unmarked',
          duration: const Duration(seconds: 1),
        );
      } else {
        SnackbarHelper.showError(context, 'Failed to update mark status - check debug log for details');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not update mark status. Please try again.');
    }
  }

  Widget _buildContentWithoutVideo(Column originalContent) {
    // Create a modified version of the original content without the video player
    final children = originalContent.children;
    final modifiedChildren = <Widget>[];

    for (final child in children) {
      // Skip the video player widget (SizedBox with height 240 containing VideoPlayerWidget)
      if (child is SizedBox && child.height == 240) {
        continue; // Skip video player
      }
      // Skip the spacing after video player
      else if (modifiedChildren.isNotEmpty &&
          modifiedChildren.last is SizedBox &&
          child is SizedBox &&
          child.height == 1) {
        continue; // Skip spacing after video
      } else {
        modifiedChildren.add(child);
      }
    }

    return Column(children: modifiedChildren);
  }

  /// Build video player widget with consistent configuration
  Widget _buildVideoPlayerWidget() {
    return EditLineVideoPane(
      videoPlayerKey: _videoPlayerKey,
      videoPath: _selectedVideoPath!,
      subtitleCollectionId: widget.subtitleId,
      subtitles: _subtitles,
      secondarySubtitles:
          _showSecondarySubtitles ? _secondarySubtitlesForPlayer : const [],
      isRepeatModeEnabled: _isRepeatModeEnabled,
      onSubtitlesUpdated: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _markSubtitlesForRegeneration();
            _generateSubtitles();
          });
        });
      },
      onSubtitleMarked: _handleVideoPlayerMarkToggle,
      onSubtitleCommentUpdated: _handleVideoPlayerCommentUpdated,
      onPlayStateChanged: (isPlaying) {
        if (!mounted) return;
        setState(() {
          _isVideoPlaying = isPlaying;
        });
      },
      onRepeatModeToggled: (isEnabled) {
        if (isEnabled != _isRepeatModeEnabled) {
          _toggleRepeatMode();
        }
      },
    );
  }

  Future<void> _handleVideoPlayerCommentUpdated(
    int subtitleIndex,
    String? comment,
  ) async {
    try {
      await updateSubtitleLineComment(
        widget.subtitleId,
        subtitleIndex,
        comment,
      );
      _subtitle =
          (await isar.subtitleCollections.get(widget.subtitleId))!;

      if (_subtitleLine != null &&
          _subtitleLine!.index == subtitleIndex + 1) {
        setState(() {
          _subtitleLine!.comment = comment;
        });
      }

      _markSubtitlesForRegeneration();
      _generateSubtitles();

      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        comment != null ? 'Comment updated' : 'Comment deleted',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        'Could not update the comment. Please try again.',
      );
    }
  }

  // Keyboard shortcut handlers
  void _handlePlayPauseShortcut() {
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      // Get current play state and toggle it
      final isPlaying = _videoPlayerKey.currentState!.isPlaying();
      if (isPlaying) {
        _videoPlayerKey.currentState!.pause();
      } else {
        _videoPlayerKey.currentState!.play();
      }
    }
  }

  void _handleNextLineShortcut() {
    // If video is loaded and in fullscreen mode, use video skip function
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final videoPlayer = _videoPlayerKey.currentState!;
      if (videoPlayer.isInFullscreenMode()) {
        logInfo(
          'Ctrl+. pressed in fullscreen mode - using video skip to next subtitle',
          context: 'EditSubtitleScreen._handleNextLineShortcut',
        );
        videoPlayer.seekToNextSubtitle();
        return;
      }
    }
    
    // Otherwise, use normal subtitle line navigation
    logInfo(
      'Ctrl+. pressed - using normal line navigation',
      context: 'EditSubtitleScreen._handleNextLineShortcut',
    );
    if (_subtitleLine != null) {
      _nextSubtitle(widget.subtitleId, _subtitleLine!.index + 1);
    }
  }

  void _handlePreviousLineShortcut() {
    // If video is loaded and in fullscreen mode, use video skip function
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final videoPlayer = _videoPlayerKey.currentState!;
      if (videoPlayer.isInFullscreenMode()) {
        logInfo(
          'Ctrl+, pressed in fullscreen mode - using video skip to previous subtitle',
          context: 'EditSubtitleScreen._handlePreviousLineShortcut',
        );
        videoPlayer.seekToPreviousSubtitle();
        return;
      }
    }
    
    // Otherwise, use normal subtitle line navigation
    logInfo(
      'Ctrl+, pressed - using normal line navigation',
      context: 'EditSubtitleScreen._handlePreviousLineShortcut',
    );
    if (_subtitleLine != null && _subtitleLine!.index > 1) {
      _prevSubtitle(widget.subtitleId, _subtitleLine!.index - 1);
    }
  }

  void _handleTextFormattingShortcut(hotkey.TextFormattingType type) {
    // Use the existing FormattingMenu's _toggleFormatting method logic
    String tag;
    switch (type) {
      case hotkey.TextFormattingType.bold:
        tag = 'b';
        break;
      case hotkey.TextFormattingType.italic:
        tag = 'i';
        break;
      case hotkey.TextFormattingType.underline:
        tag = 'u';
        break;
    }

    toggleTextFormatting(controller: _editedController, tag: tag);

    // Update character counts
    _instantCharacterCountUpdate();
  }

  void _handleSaveShortcut() async {
    // Use the same save function as the save button
    await _updateSubtitle(context);
    // The _updateSubtitle function already shows appropriate feedback
  }

  void _handleDeleteCurrentShortcut() {
    // Use the existing delete functionality directly (same as menu option)
    if (_subtitleLine == null) return;

    SubtitleOperations.showDeleteConfirmation(
      context: context,
      subtitleId: widget.subtitleId,
      currentLine: _subtitleLine!,
      collection: _subtitle!,
      onSuccess:
          () => _fetchSubtitleLine(widget.subtitleId, _subtitleLine!.index - 1),
      sessionId: widget.sessionId,
    );
  }

  void _handleColorPickerShortcut() {
    showEditLineColorPickerSheet(
      context: context,
      controller: _editedController,
      colorHistory: _colorHistory,
      onApply: _saveColorHistory,
    );
  }

  void _handleMarkLineShortcut() {
    // Use the existing mark/unmark functionality
    _toggleMarkLine();
  }

  void _handleMarkLineAndCommentShortcut() {
    // Don't open a new dialog if one is already visible
    if (_isCommentDialogOpen) {
      return;
    }
    
    // Show comment dialog without marking first
    // Marking will happen when user presses 'Add' button
    if (_subtitleLine != null) {
      _showCommentDialogForCurrentLine();
    }
  }

  void _handleJumpToLineShortcut() {
    // Use the same logic as the menu item - call _showJumpToLineModal()
    _showJumpToLineModal();
  }

  void _handleHelpShortcut() {
    // Navigate to help screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpScreen()),
    );
  }

  void _handleSettingsShortcut() {
    // Show settings sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder:
          (context) => SettingsSheet(
            onSettingsChanged: () {
              _reloadAllSettings();
            },
          ),
    );
  }

  void _handlePopScreenShortcut() async {
    // Use the same logic as the back button - check for unsaved changes
    if (_hasUnsavedChanges()) {
      final shouldPop = await _showUnsavedChangesDialog();
      if (shouldPop) {
        // Return the current active index (convert from 1-based to 0-based)
        final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
        Navigator.of(context).pop(currentIndex);
      }
    } else {
      // Return the current active index (convert from 1-based to 0-based)
      final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
      Navigator.of(context).pop(currentIndex);
    }
  }

  void _handleToggleRepeatShortcut() {
    // Toggle repeat mode
    _toggleRepeatMode();
  }

  void _handleToggleRepeatRangeShortcut() {
    // For now, set a simple range around current subtitle (current ± 2)
    if (_subtitleLine != null && _subtitle != null) {
      final currentIndex = (_subtitleLine!.index - 1); // Convert to 0-based
      final maxIndex = _subtitle!.lines.length - 1;

      final startIndex = (currentIndex - 2).clamp(0, maxIndex);
      final endIndex = (currentIndex + 2).clamp(0, maxIndex);

      // Enable repeat mode if not already enabled
      if (!_isRepeatModeEnabled) {
        _toggleRepeatMode();
      }

      // Set custom range
      setCustomRepeatRange(startIndex, endIndex);
    }
  }

  void _handleToggleFullscreenShortcut() {
    // Toggle fullscreen if video is loaded
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.toggleCustomFullscreen();
    }
  }

  // Split line shortcut handler
  void _handleSplitLineShortcut() {
    // Use the existing split functionality from SubtitleOperations
    if (_subtitleLine != null && _subtitle != null) {
      SubtitleOperations.handleSplitButton(
        context: context,
        editedController: _editedController,
        startTime: _startTimeController.text,
        endTime: _endTimeController.text,
        subtitleId: widget.subtitleId,
        currentLine: _subtitleLine!,
        refreshCallback:
            () => _fetchSubtitleLine(widget.subtitleId, _subtitleLine!.index),
        sessionId: widget.sessionId,
      );
    }
  }

  // Merge line shortcut handler
  void _handleMergeLineShortcut() {
    logInfo(
      '_handleMergeLineShortcut called',
      context: 'EditSubtitleScreen._handleMergeLineShortcut',
    );
    // Use the existing merge functionality from SubtitleOperations
    if (_subtitleLine != null && _subtitle != null) {
      logInfo(
        'Showing merge confirmation dialog',
        context: 'EditSubtitleScreen._handleMergeLineShortcut',
      );
      SubtitleOperations.showMergeConfirmation(
        context: context,
        currentLine: _subtitleLine!,
        collection: _subtitle!,
        subtitleId: widget.subtitleId,
        refreshCallback: (newLineIndex) =>
            _fetchSubtitleLine(widget.subtitleId, newLineIndex - 1),
        sessionId: widget.sessionId,
      );
    } else {
      logWarning(
        'Cannot merge - _subtitleLine: ${_subtitleLine != null}, _subtitle: ${_subtitle != null}',
        context: 'EditSubtitleScreen._handleMergeLineShortcut',
      );
    }
  }

  // Paste original shortcut handler
  void _handlePasteOriginalShortcut() {
    // Only allow in translation mode (not edit mode)
    if (!_isEditMode && mounted) {
      setState(() {
        _editedController.text = _originalController.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL PERFORMANCE FIX: Do NOT read MediaQuery.viewInsets in build method!
    // Reading viewInsets causes rebuilds on every keyboard animation frame (60fps)
    // Instead, we listen to keyboard state in FocusNode listeners
    // The _isKeyboardVisible state is updated via FocusNode, not MediaQuery
    
    // Force video to always show to eliminate keyboard-related UI changes
    final shouldShowVideo = _isVideoVisible && _selectedVideoPath != null;

    return FirstTimeInstructions(
      screenName: 'edit_line',
      instructions: editLineInstructions,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          // Check for unsaved changes
          if (_hasUnsavedChanges()) {
            await _showUnsavedChangesDialog();
          } else {
            // Return the current active index (convert from 1-based to 0-based)
            final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
            Navigator.of(context).pop(currentIndex);
          }
        },
        child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () async {
                    // Check for unsaved changes
                    if (_hasUnsavedChanges()) {
                      await _showUnsavedChangesDialog();
                      // Note: _showUnsavedChangesDialog handles navigation internally
                    } else {
                      // Return the current active index (convert from 1-based to 0-based)
                      final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
                      Navigator.of(context).pop(currentIndex);
                    }
                  },
                ),
                title: Row(
                  children: [
                    Expanded(
                      child:
                          _subtitle != null
                              ? ScrollingTitleWidget(
                                title: _subtitle!.fileName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.4,
                              )
                              : const Text(
                                "Subtitle Studio",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                    ),
                    // Mark indicator for current subtitle line
                    if (_subtitleLine?.marked == true)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: Listener(
                          onPointerDown: (PointerDownEvent event) {
                            // Handle right-click on desktop platforms
                            if (event.kind == PointerDeviceKind.mouse && 
                                event.buttons == kSecondaryMouseButton) {
                              _showCommentDialogForCurrentLine();
                            }
                          },
                          child: GestureDetector(
                            onLongPress: () {
                              // Handle long press on touch devices
                              _showCommentDialogForCurrentLine();
                            },
                            onTap: () {
                              // Optional: quick toggle mark status on tap
                              _toggleMarkLine();
                            },
                            child: const Icon(
                              Icons.bookmark_added,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                iconTheme: const IconThemeData(
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                actions: [
                  const ThemeSwitcherButton(),
                  if (_isVideoLoaded)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isVideoVisible = !_isVideoVisible;
                        });

                        if (_isVideoVisible && _subtitleLine != null) {
                          final startTime =
                              parseTimeString(_subtitleLine!.startTime);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            unawaited(
                              _seekWhenVideoPlayerReady(startTime),
                            );
                          });
                        }
                      },
                      icon:
                          _isVideoVisible
                              ? SvgPicture.asset(
                                'assets/movie_off.svg',
                                semanticsLabel: 'Movie off',
                                height: 25,
                                width: 35,
                              )
                              : const Icon(Icons.movie_outlined),
                    ),
                  if (_isVideoLoaded && _isVideoVisible)
                    IconButton(
                      tooltip: 'Sync with video position',
                      icon: const Icon(Icons.sync),
                      onPressed: _syncWithVideoPosition,
                    ),
                  IconButton(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu),
                    onPressed: () => _showEditLineMenuModal(),
                  ),
                ],
              ),
              body:
                  _subtitle?.lines.isEmpty ?? false
                      ? EmptySubtitleView(onAddSubtitle: _addInitialSubtitleLine)
                      : GestureDetector(
                        onSecondaryTap:
                            () =>
                                _showEditLineMenuModal(), // Right-click opens menu
                        child: _buildResponsiveContent(
                          shouldShowVideo,
                          Column(
                            children: [
                              // Video player at the top
                              if (shouldShowVideo)
                                SizedBox(
                                  height: 240,
                                  child: VideoPlayerWidget(
                                    key: _videoPlayerKey,
                                    videoPath: _selectedVideoPath!,
                                    subtitleCollectionId: widget.subtitleId,
                                    subtitles: _subtitles,
                                    secondarySubtitles:
                                        _showSecondarySubtitles
                                            ? _secondarySubtitlesForPlayer
                                            : [],
                                    onSubtitlesUpdated: () {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(() {
                                                _markSubtitlesForRegeneration();
                                                _generateSubtitles();
                                              });
                                            }
                                          });
                                    },
                                    onSubtitleMarked: (
                                      subtitleIndex,
                                      isMarked,
                                    ) async {
                                      // Handle marking/unmarking from video player
                                      await _handleVideoPlayerMarkToggle(
                                        subtitleIndex,
                                        isMarked,
                                      );
                                    },
                                    onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                                      // Update comment in database and refresh UI
                                      try {
                                        await updateSubtitleLineComment(widget.subtitleId, subtitleIndex, comment);
                                        // Refresh the subtitle data from database
                                        _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;
                                        
                                        // Update current line if it matches
                                        if (_subtitleLine != null && _subtitleLine!.index == subtitleIndex + 1) {
                                          setState(() {
                                            _subtitleLine!.comment = comment;
                                          });
                                        }
                                        
                                        // Regenerate subtitles for video player
                                        _markSubtitlesForRegeneration();
                                        _generateSubtitles();
                                        
                                        SnackbarHelper.showSuccess(context, 
                                          comment != null ? 'Comment updated' : 'Comment deleted');
                                      } catch (e) {
                                        SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                                      }
                                    },
                                    onPlayStateChanged: (isPlaying) {
                                      // Update play/pause button state when video player state changes
                                      if (mounted) {
                                        setState(() {
                                          _isVideoPlaying = isPlaying;
                                        });
                                      }
                                    },
                                    onRepeatModeToggled: (isEnabled) {
                                      // Handle repeat mode toggle from video player
                                      if (isEnabled != _isRepeatModeEnabled) {
                                        _toggleRepeatMode();
                                      }
                                    },
                                    isRepeatModeEnabled: _isRepeatModeEnabled,
                                  ),
                                ),
                              // Add spacing after video when it's shown
                              if (shouldShowVideo) const SizedBox(height: 1),
                              // Main content in scrollable area
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // In edit mode, skip the original text field and related controls
                                        if (!_isEditMode) ...[
                                          // Show title row and checkboxes only when original text field is visible
                                          if (_showOriginalTextField) ...[
                                            // Empty space where the labels and controls used to be
                                            const SizedBox(height: 0),
                                          ],
                                          // Original text field - conditionally displayed
                                          if (_showOriginalTextField) ...[
                                            Stack(
                                              children: [
                                                Container(
                                                  height: 100,
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFF0A9396,
                                                      ),
                                                      width: 1.5,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4.0,
                                                        ),
                                                  ),
                                                  child:
                                                      isRawEnabled
                                                          ? CustomHtmlText(
                                                            htmlContent:
                                                                _originalController
                                                                    .text
                                                                    .replaceAll(
                                                                      '\n',
                                                                      '<br>',
                                                                    ),
                                                            textAlign:
                                                                TextAlign
                                                                    .center,
                                                            defaultStyle:
                                                                TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  fontSize: 16,
                                                                ),
                                                          )
                                                          : TextField(
                                                            controller:
                                                                _originalController,
                                                            undoController:
                                                                _undoHistoryController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .multiline,
                                                            readOnly:
                                                                !isEditingEnabled,
                                                            maxLines: null,
                                                            expands: true,
                                                            inputFormatters: [
                                                              UnicodeTextInputFormatter(),
                                                            ],
                                                            decoration: const InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              contentPadding:
                                                                  EdgeInsets.fromLTRB(
                                                                    8.0,
                                                                    8.0,
                                                                    60.0,
                                                                    8.0,
                                                                  ), // Add right padding for icon buttons
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 16,
                                                                  color: Color(
                                                                    0xFFFFFFFF,
                                                                  ),
                                                                ),
                                                            scrollPhysics:
                                                                const ClampingScrollPhysics(), // Enable scrolling
                                                            // Ultra-optimized settings for maximum keyboard responsiveness
                                                            autocorrect:
                                                                false, // Critical: Disable autocorrect for instant typing
                                                            enableSuggestions:
                                                                false, // Critical: Disable suggestions to reduce processing
                                                            smartDashesType:
                                                                SmartDashesType
                                                                    .disabled, // Disable smart dashes
                                                            smartQuotesType:
                                                                SmartQuotesType
                                                                    .disabled, // Disable smart quotes
                                                            textInputAction:
                                                                TextInputAction
                                                                    .newline, // Optimize for multiline
                                                            enableIMEPersonalizedLearning:
                                                                false, // Critical: Disable IME learning for faster response
                                                            enableInteractiveSelection:
                                                                true, // Enable text selection
                                                            showCursor:
                                                                true, // Keep cursor visible
                                                          ),
                                                ),
                                                // Character count positioned at bottom-right (with margin from buttons)
                                                Positioned(
                                                  bottom: 1,
                                                  right: 4,
                                                  child: riverpod.Consumer(
                                                    builder: (context, ref, child) {
                                                      final characterState = ref.watch(
                                                        editLineControllerProvider.select(
                                                          (state) => (
                                                            state.isInitialized,
                                                            state.originalCharCount,
                                                            state.originalHasLongLine,
                                                          ),
                                                        ),
                                                      );

                                                      final charCount = characterState.$1
                                                          ? characterState.$2
                                                          : _originalCharCount;
                                                      final hasLongLine = characterState.$1
                                                          ? characterState.$3
                                                          : _originalHasLongLine;

                                                      return CharacterCountWidget(
                                                        count: charCount,
                                                        hasLongLine: hasLongLine,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                // "Original" title positioned at top-left
                                                Positioned(
                                                  top: 1,
                                                  left: 4,
                                                  child: Text(
                                                    'Original',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color.fromARGB(
                                                        100,
                                                        255,
                                                        255,
                                                        255,
                                                      ),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                // Index/total count positioned at bottom-left
                                                Positioned(
                                                  bottom: 1,
                                                  left: 4,
                                                  child: Text(
                                                    "${_subtitleLine?.index ?? 1}/${_subtitle?.lines.length ?? 0}",
                                                    style: const TextStyle(
                                                      color: Color.fromARGB(
                                                        125,
                                                        255,
                                                        255,
                                                        255,
                                                      ),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                // Copy button and edit button positioned at top-right as a column
                                                Positioned(
                                                  top: 1,
                                                  right: 1,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        constraints:
                                                            const BoxConstraints(
                                                              minWidth: 24,
                                                              minHeight: 24,
                                                            ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        onPressed: () {
                                                          Clipboard.setData(
                                                            ClipboardData(
                                                              text:
                                                                  _originalController
                                                                      .text,
                                                            ),
                                                          );
                                                          SnackbarHelper.showSuccess(
                                                            context,
                                                            'Copied to clipboard',
                                                            duration:
                                                                const Duration(
                                                                  seconds: 2,
                                                                ),
                                                          );
                                                        },
                                                        icon: const Icon(
                                                          Icons.copy,
                                                          size: 16,
                                                        ),
                                                        color: const Color(
                                                          0xFFCA6702,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        constraints:
                                                            const BoxConstraints(
                                                              minWidth: 24,
                                                              minHeight: 24,
                                                            ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        onPressed: () {
                                                          setState(() {
                                                            isEditingEnabled =
                                                                !isEditingEnabled;
                                                          });
                                                        },
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          size: 16,
                                                        ),
                                                        color:
                                                            isEditingEnabled
                                                                ? const Color(
                                                                  0xFFBB3E03,
                                                                )
                                                                : const Color(
                                                                  0xFFCA6702,
                                                                ),
                                                        tooltip:
                                                            "Toggle Edit Mode",
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ],

                                        // Empty space where the labels and line count used to be
                                        const SizedBox(height: 0),
                                        const SizedBox(height: 5),
                                        Stack(
                                          children: [
                                            Container(
                                              height:
                                                  100, // Set a fixed height for the TextField
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF0A9396,
                                                  ),
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4.0),
                                              ),
                                              child:
                                                  isRawEnabled &&
                                                          _editedController
                                                              .text
                                                              .isNotEmpty
                                                      ? CustomHtmlText(
                                                        htmlContent:
                                                            _editedController
                                                                .text
                                                                .replaceAll(
                                                                  '\n',
                                                                  '<br>',
                                                                ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        defaultStyle: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                        ),
                                                      )
                                                      : TextField(
                                                        controller:
                                                            _editedController,
                                                        focusNode: _focusNode,
                                                        undoController:
                                                            _undoHistoryController,
                                                        keyboardType:
                                                            TextInputType
                                                                .multiline,
                                                        readOnly:
                                                            false, // Original subtitle should not be editable
                                                        maxLines:
                                                            null, // Allow the text to wrap and grow if needed
                                                        expands:
                                                            true, // Make the TextField expand vertically to fit the height
                                                        inputFormatters: [
                                                          UnicodeTextInputFormatter(),
                                                        ],
                                                        decoration: const InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              EdgeInsets.fromLTRB(
                                                                8.0,
                                                                8.0,
                                                                30.0,
                                                                8.0,
                                                              ), // Add right padding for icon buttons
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          color: Color(
                                                            0xFFFFFFFF,
                                                          ),
                                                        ),
                                                        scrollPhysics:
                                                            const ClampingScrollPhysics(), // Enable scrolling
                                                        // Balanced settings for normal keyboard with good performance
                                                        autocorrect:
                                                            false, // Keep disabled for performance
                                                        enableSuggestions:
                                                            true, // Enable to show normal keyboard with suggestions
                                                        smartDashesType:
                                                            SmartDashesType
                                                                .disabled, // Keep disabled for performance
                                                        smartQuotesType:
                                                            SmartQuotesType
                                                                .disabled, // Keep disabled for performance
                                                        textInputAction:
                                                            TextInputAction
                                                                .newline, // Optimize for multiline
                                                        enableIMEPersonalizedLearning:
                                                            true, // Enable for normal keyboard behavior
                                                        enableInteractiveSelection:
                                                            true, // Keep text selection
                                                        showCursor:
                                                            true, // Keep cursor visible
                                                        // Remove any onChanged callback to prevent lag
                                                      ),
                                            ),
                                            // Character count positioned at bottom-right (with margin from buttons)
                                            Positioned(
                                              bottom: 1,
                                              right: 4,
                                              child: riverpod.Consumer(
                                                builder: (context, ref, child) {
                                                  final characterState = ref.watch(
                                                    editLineControllerProvider.select(
                                                      (state) => (
                                                        state.isInitialized,
                                                        state.editedCharCount,
                                                        state.editedHasLongLine,
                                                      ),
                                                    ),
                                                  );

                                                  final charCount = characterState.$1
                                                      ? characterState.$2
                                                      : _editedCharCount;
                                                  final hasLongLine = characterState.$1
                                                      ? characterState.$3
                                                      : _editedHasLongLine;

                                                  return CharacterCountWidget(
                                                    count: charCount,
                                                    hasLongLine: hasLongLine,
                                                  );
                                                },
                                              ),
                                            ),
                                            // "Edited" title positioned at top-left
                                            Positioned(
                                              top: 1,
                                              left: 4,
                                              child: Text(
                                                _isEditMode
                                                    ? 'Subtitle Text'
                                                    : 'Edited',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color.fromARGB(
                                                    100,
                                                    255,
                                                    255,
                                                    255,
                                                  ),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            // Index/total count positioned at bottom-left
                                            Positioned(
                                              bottom: 1,
                                              left: 4,
                                              child: Text(
                                                "${_subtitleLine?.index ?? 1}/${_subtitle?.lines.length ?? 0}",
                                                style: const TextStyle(
                                                  color: Color.fromARGB(
                                                    120,
                                                    255,
                                                    255,
                                                    255,
                                                  ),
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            // Copy/paste buttons positioned at top-right as a column
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 24,
                                                          minHeight: 24,
                                                        ),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () {
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text:
                                                              _editedController
                                                                  .text,
                                                        ),
                                                      );
                                                      SnackbarHelper.showSuccess(
                                                        context,
                                                        'Copied to clipboard',
                                                        duration:
                                                            const Duration(
                                                              seconds: 2,
                                                            ),
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.copy,
                                                      size: 16,
                                                    ),
                                                    color: const Color(
                                                      0xFFCA6702,
                                                    ),
                                                  ),
                                                  // Only show paste original button in translation mode
                                                  if (!_isEditMode)
                                                    IconButton(
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 24,
                                                            minHeight: 24,
                                                          ),
                                                      padding: EdgeInsets.zero,
                                                      onPressed: () {
                                                        setState(() {
                                                          _editedController
                                                                  .text =
                                                              _originalController
                                                                  .text;
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons.paste,
                                                        size: 16,
                                                      ),
                                                      color: const Color(
                                                        0xFFCA6702,
                                                      ),
                                                      tooltip: "Paste Original",
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                // Calculate available width and adjust button sizes accordingly
                                                double availableWidth =
                                                    constraints.maxWidth;
                                                double buttonSize =
                                                    availableWidth < 400
                                                        ? 28
                                                        : 32; // Smaller icons for narrow screens
                                                double buttonPadding =
                                                    availableWidth < 400
                                                        ? 0.4
                                                        : 1.0; // Less padding for narrow screens

                                                return Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Flexible(
                                                      child: IconButton(
                                                        constraints:
                                                            BoxConstraints(
                                                              minWidth: 24,
                                                              maxWidth: 36,
                                                            ),
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal:
                                                                  buttonPadding,
                                                            ),
                                                        onPressed:
                                                            _subtitleLine !=
                                                                    null
                                                                ? () => _prevSubtitle(
                                                                  widget
                                                                      .subtitleId,
                                                                  _subtitleLine!
                                                                          .index -
                                                                      1,
                                                                )
                                                                : null,
                                                        icon: Icon(
                                                          Icons.skip_previous,
                                                          size: buttonSize,
                                                          color:
                                                              Provider.of<
                                                                        ThemeProvider
                                                                      >(
                                                                        context,
                                                                      ).themeMode ==
                                                                      ThemeMode
                                                                          .light
                                                                  ? const Color.fromARGB(
                                                                    255,
                                                                    0,
                                                                    45,
                                                                    54,
                                                                  )
                                                                  : const Color.fromARGB(
                                                                    255,
                                                                    233,
                                                                    216,
                                                                    166,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                    // Dictionary popup menu button (moved here - always visible)
                                                    Flexible(
                                                      child: PopupMenuButton<
                                                        String
                                                      >(
                                                        icon: Icon(
                                                          Icons.book,
                                                          size: buttonSize,
                                                          color:
                                                              Provider.of<
                                                                        ThemeProvider
                                                                      >(
                                                                        context,
                                                                      ).themeMode ==
                                                                      ThemeMode
                                                                          .light
                                                                  ? const Color.fromARGB(
                                                                    255,
                                                                    0,
                                                                    45,
                                                                    54,
                                                                  )
                                                                  : const Color.fromARGB(
                                                                    255,
                                                                    233,
                                                                    216,
                                                                    166,
                                                                  ),
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        elevation: 8,
                                                        offset: const Offset(
                                                          0,
                                                          8,
                                                        ),
                                                        tooltip: 'Dictionary',
                                                        onSelected: (
                                                          String value,
                                                        ) {
                                                          if (value == "olam") {
                                                            _showOlamDictionary();
                                                          } else if (value ==
                                                              "urban") {
                                                            _showUrbanDictionary();
                                                          } else if (value ==
                                                              "msone") {
                                                            _showMsoneDictionary();
                                                          } else if (value ==
                                                              "ai_explain") {
                                                            _showAiExplanation();
                                                          }
                                                        },
                                                        itemBuilder:
                                                            (
                                                              BuildContext
                                                              context,
                                                            ) => [
                                                              // MSone Dictionary option (moved from icon row)
                                                              if (_isMsoneEnabled)
                                                                PopupMenuItem(
                                                                  value:
                                                                      "msone",
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                    child: Row(
                                                                      children: [
                                                                        SvgPicture.asset(
                                                                          'assets/msone.svg',
                                                                          semanticsLabel:
                                                                              'Msone Logo',
                                                                          height:
                                                                              20,
                                                                          width:
                                                                              20,
                                                                          colorFilter: const ColorFilter.mode(
                                                                            Color(
                                                                              0xFF3A86FF,
                                                                            ),
                                                                            BlendMode.srcIn,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              16,
                                                                        ),
                                                                        Text(
                                                                          "MSone Dictionary",
                                                                          style: Theme.of(
                                                                            context,
                                                                          ).textTheme.bodyLarge?.copyWith(
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              // Show Olam Dictionary only if MSone is enabled
                                                              if (_isMsoneEnabled)
                                                                PopupMenuItem(
                                                                  value: "olam",
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .book,
                                                                          color: Color(
                                                                            0xFF9C27B0,
                                                                          ), // Purple color for Olam
                                                                          size:
                                                                              24,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              16,
                                                                        ),
                                                                        Text(
                                                                          "Olam Dictionary",
                                                                          style: Theme.of(
                                                                            context,
                                                                          ).textTheme.bodyLarge?.copyWith(
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              // Urban Dictionary is always available
                                                              PopupMenuItem(
                                                                value: "urban",
                                                                child: Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .forum,
                                                                        color: Color(
                                                                          0xFF4CAF50,
                                                                        ), // Green color for Urban Dictionary
                                                                        size:
                                                                            24,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            16,
                                                                      ),
                                                                      Text(
                                                                        "Urban Dictionary",
                                                                        style: Theme.of(
                                                                          context,
                                                                        ).textTheme.bodyLarge?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              // AI Explanation
                                                              PopupMenuItem(
                                                                value: "ai_explain",
                                                                child: Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .auto_awesome,
                                                                        color: Color(
                                                                          0xFF9C27B0,
                                                                        ), // Purple color for AI
                                                                        size:
                                                                            24,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            16,
                                                                      ),
                                                                      Text(
                                                                        "Explain with AI",
                                                                        style: Theme.of(
                                                                          context,
                                                                        ).textTheme.bodyLarge?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                      ),
                                                    ),
                                                    Flexible(
                                                      child: FormattingMenu(
                                                        controller:
                                                            _editedController,
                                                        colorHistory:
                                                            _colorHistory,
                                                        onColorHistoryUpdate:
                                                            _saveColorHistory,
                                                      ),
                                                    ),
                                                    if (_subtitleLine != null &&
                                                        _subtitle != null)
                                                      Flexible(
                                                        child: SubtitleActionsMenu(
                                                          editedController:
                                                              _editedController,
                                                          startTime:
                                                              _startTimeController
                                                                  .text,
                                                          endTime:
                                                              _endTimeController
                                                                  .text,
                                                          subtitleId:
                                                              widget.subtitleId,
                                                          currentLine:
                                                              _subtitleLine!,
                                                          collection:
                                                              _subtitle!,
                                                          refreshCallback:
                                                              () => _fetchSubtitleLine(
                                                                widget
                                                                    .subtitleId,
                                                                _subtitleLine!
                                                                    .index,
                                                              ),
                                                          refreshToLineCallback:
                                                              (newLineIndex) => _fetchSubtitleLine(
                                                                widget
                                                                    .subtitleId,
                                                                newLineIndex - 1, // Convert from 1-based to 0-based array index
                                                              ),
                                                          sessionId: widget.sessionId,
                                                          onBeforeAdd: _updateSubtitleSilently, // Save before adding new line
                                                          isVideoLoaded: _isVideoLoaded,
                                                          getCurrentVideoPosition: _isVideoLoaded && _videoPlayerKey.currentState != null
                                                              ? () => _videoPlayerKey.currentState!.getCurrentPosition()
                                                              : null,
                                                        ),
                                                      ),
                                                    Flexible(
                                                      child: IconButton(
                                                        constraints:
                                                            BoxConstraints(
                                                              minWidth: 24,
                                                              maxWidth: 36,
                                                            ),
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal:
                                                                  buttonPadding,
                                                            ),
                                                        icon: Icon(
                                                          Icons.save,
                                                          size: buttonSize,
                                                          color:
                                                              Provider.of<
                                                                        ThemeProvider
                                                                      >(
                                                                        context,
                                                                      ).themeMode ==
                                                                      ThemeMode
                                                                          .light
                                                                  ? const Color.fromARGB(
                                                                    255,
                                                                    0,
                                                                    45,
                                                                    54,
                                                                  )
                                                                  : const Color.fromARGB(
                                                                    255,
                                                                    233,
                                                                    216,
                                                                    166,
                                                                  ),
                                                        ),
                                                        onPressed: () async {
                                                          // Show loading state briefly for better UX
                                                          setState(() {
                                                            // Could add a loading indicator here if needed
                                                          });

                                                          // Perform save operation asynchronously
                                                          await Future.microtask(
                                                            () async {
                                                              await _updateSubtitle(
                                                                context,
                                                              );
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    // Play/Pause button for video
                                                    if (_isVideoLoaded)
                                                      Flexible(
                                                        child: IconButton(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal:
                                                                    buttonPadding,
                                                              ),
                                                          constraints:
                                                              BoxConstraints(
                                                                minWidth: 24,
                                                                maxWidth: 36,
                                                              ),
                                                          icon: Icon(
                                                            _isVideoPlaying
                                                                ? Icons.pause
                                                                : Icons
                                                                    .play_arrow,
                                                            size: buttonSize,
                                                            color:
                                                                Provider.of<
                                                                          ThemeProvider
                                                                        >(
                                                                          context,
                                                                        ).themeMode ==
                                                                        ThemeMode
                                                                            .light
                                                                    ? const Color.fromARGB(
                                                                      255,
                                                                      0,
                                                                      45,
                                                                      54,
                                                                    )
                                                                    : const Color.fromARGB(
                                                                      255,
                                                                      233,
                                                                      216,
                                                                      166,
                                                                    ),
                                                          ),
                                                          onPressed: () {
                                                            if (_videoPlayerKey
                                                                    .currentState !=
                                                                null) {
                                                              if (_isVideoPlaying) {
                                                                _videoPlayerKey
                                                                    .currentState!
                                                                    .pause();
                                                              } else {
                                                                _videoPlayerKey
                                                                    .currentState!
                                                                    .play();
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      ),

                                                    Flexible(
                                                      child: IconButton(
                                                        constraints:
                                                            BoxConstraints(
                                                              minWidth: 24,
                                                              maxWidth: 36,
                                                            ),
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal:
                                                                  buttonPadding,
                                                            ),
                                                        onPressed:
                                                            _subtitleLine !=
                                                                    null
                                                                ? () => _nextSubtitle(
                                                                  widget
                                                                      .subtitleId,
                                                                  _subtitleLine!
                                                                          .index +
                                                                      1,
                                                                )
                                                                : null,
                                                        icon: Icon(
                                                          Icons.skip_next,
                                                          size: buttonSize,
                                                          color:
                                                              Provider.of<
                                                                        ThemeProvider
                                                                      >(
                                                                        context,
                                                                      ).themeMode ==
                                                                      ThemeMode
                                                                          .light
                                                                  ? const Color.fromARGB(
                                                                    255,
                                                                    0,
                                                                    45,
                                                                    54,
                                                                  )
                                                                  : const Color.fromARGB(
                                                                    255,
                                                                    233,
                                                                    216,
                                                                    166,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 0),

                                        // Time fields section - update keyboard type for both fields
                                        Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () {
                                                    setState(() {
                                                      _isTimeVisible =
                                                          !_isTimeVisible;
                                                    });

                                                    // Auto-scroll to bottom when time fields are shown
                                                    if (_isTimeVisible) {
                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback((
                                                            _,
                                                          ) {
                                                            _scrollController.animateTo(
                                                              _scrollController
                                                                  .position
                                                                  .maxScrollExtent,
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        300,
                                                                  ),
                                                              curve:
                                                                  Curves
                                                                      .easeInOut,
                                                            );
                                                          });
                                                    }
                                                  },
                                                  label: Text(
                                                    "Edit Time",
                                                    style: TextStyle(
                                                      color: Color(0xFFCA6702),
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  icon: Icon(
                                                    _isTimeVisible
                                                        ? Icons
                                                            .keyboard_arrow_down
                                                        : Icons.chevron_right,
                                                    size: 32,
                                                    color: Color(0xFFCA6702),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_isTimeVisible)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16.0,
                                                    ),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                                                  children: [
                                                    Expanded(
                                                      child: _buildTimeComponentFields(
                                                        'Start Time',
                                                        true,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: _buildTimeComponentFields(
                                                        'End Time',
                                                        false,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            ); // Scaffold
          }, // builder (inner Builder)
        ), // Builder (inner - wraps Scaffold)
      ), // PopScope
    ); // FirstTimeInstructions
  }

  // Method to add the initial subtitle line
  /// Enhanced file save with three-strategy approach
  Future<bool?> _showSaveLocationDialog() {
    return showSaveLocationSheet(context);
  }

}
