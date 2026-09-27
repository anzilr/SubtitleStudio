import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:isar_community/isar.dart';
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
part 'edit_line/parts/edit_line_video_actions.dart';
part 'edit_line/parts/edit_line_navigation.dart';
part 'edit_line/parts/edit_line_preferences.dart';
part 'edit_line/parts/edit_line_time_helpers.dart';
part 'edit_line/parts/edit_line_shortcuts.dart';
part 'edit_line/parts/edit_line_initialization.dart';
part 'edit_line/parts/edit_line_actions.dart';

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
  void _setEditLineState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

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

  // Video subtitle cache invalidation flag. This must remain real State
  // storage because extensions cannot own instance fields.
  bool _needSubtitleRegeneration = true;

  void _markSubtitlesForRegeneration() {
    _needSubtitleRegeneration = true;
  }

  /// Public bridge used by the repeat-range dialog.
  List<Subtitle> get subtitles => _subtitles;

  bool get isRepeatModeEnabled => _isRepeatModeEnabled;

  void setCustomRepeatRange(int startIndex, int endIndex) {
    if (startIndex <= endIndex &&
        startIndex >= 0 &&
        endIndex < _subtitles.length) {
      _isCustomRangeMode = true;
      _customRangeStartIndex = startIndex;
      _customRangeEndIndex = endIndex;

      if (_isRepeatModeEnabled) {
        _startRepeatPlayback();
      }
    }
  }

  void clearCustomRepeatRange() {
    _isCustomRangeMode = false;
    _customRangeStartIndex = null;
    _customRangeEndIndex = null;

    if (_isRepeatModeEnabled) {
      _startRepeatPlayback();
    }
  }

  void toggleRepeatMode() => _toggleRepeatMode();

  void startRepeatPlayback() => _startRepeatPlayback();

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

  /// Build video player widget with consistent configuration
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
                                                              Theme.of(context).brightness == Brightness.light
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
                                                              Theme.of(context).brightness == Brightness.light
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
                                                              Theme.of(context).brightness == Brightness.light
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
                                                                Theme.of(context).brightness == Brightness.light
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
                                                              Theme.of(context).brightness == Brightness.light
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
