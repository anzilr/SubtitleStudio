import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:subtitle_studio/database/models/models.dart';
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
part 'edit_line/parts/edit_line_layout.dart';

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
    // Avoid reading MediaQuery.viewInsets here; keyboard animation frames must
    // not rebuild the full editor. Focus listeners own that state instead.
    final shouldShowVideo =
        _isVideoVisible && _selectedVideoPath != null;
    return _buildEditLineLayout(context, shouldShowVideo);
  }

  // Method to add the initial subtitle line
  /// Enhanced file save with three-strategy approach
  Future<bool?> _showSaveLocationDialog() {
    return showSaveLocationSheet(context);
  }

}
