import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/utils/srt_compiler.dart';
import 'package:subtitle_studio/utils/platform_file_handler.dart';
import 'package:subtitle_studio/operations/subtitle_sync_operations.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/widgets/goto_line_sheet.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';
import 'package:subtitle_studio/screens/edit/widgets/editor_video_pane.dart';
import 'package:subtitle_studio/screens/screen_help.dart';
import 'package:subtitle_studio/utils/responsive_layout.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/themes/theme_switcher_button.dart';
import 'package:subtitle_studio/utils/project_manager.dart';
import 'package:subtitle_studio/widgets/export_file_widget.dart';
import 'package:subtitle_studio/widgets/project_settings_sheet.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_host.dart'; // EditSubtitleScreenHost wrapper
import 'package:subtitle_studio/utils/time_parser.dart';
import 'package:subtitle_studio/utils/subtitle_index.dart';
import 'package:subtitle_studio/utils/video_player_readiness.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:subtitle_studio/widgets/bottom_modal_sheet.dart';
import 'package:subtitle_studio/operations/subtitle_operations.dart';
import 'package:subtitle_studio/widgets/search_replace_sheet.dart';
import 'package:subtitle_studio/widgets/isolated_loader.dart';
import 'package:subtitle_studio/widgets/secondary_subtitle_sheet.dart';
import 'package:subtitle_studio/widgets/first_time_instructions.dart';
import 'package:subtitle_studio/widgets/scrolling_title_widget.dart';
import 'package:subtitle_studio/widgets/marked_lines_sheet.dart';
import 'package:subtitle_studio/widgets/checkpoint_sheet.dart';
import 'package:subtitle_studio/widgets/subtitle_effects_sheet.dart';
import 'package:subtitle_studio/widgets/comment_dialog.dart';
import 'package:subtitle_studio/widgets/import_comments_sheet.dart';
import 'package:subtitle_studio/operations/subtitle_effect_operations.dart';
import 'package:subtitle_studio/utils/macos_bookmark_manager.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart' as hotkey;
import 'msone_submission_screen.dart';
import 'package:subtitle_studio/screens/edit/edit_controller.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/widgets/source_view_pane.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_main_menu.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_placeholders.dart';
import 'package:subtitle_studio/screens/edit/widgets/subtitle_card.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_selection_dialogs.dart';
import 'package:subtitle_studio/screens/edit/widgets/editor_custom_scrollbar.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_tool_sheets.dart';
import 'package:subtitle_studio/screens/edit/services/hearing_impaired_cleanup_service.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

part 'edit/parts/edit_dialog_actions.dart';
part 'edit/parts/edit_responsive_layout.dart';
part 'edit/parts/edit_project_actions.dart';
part 'edit/parts/edit_subtitle_actions.dart';
part 'edit/parts/edit_source_view_actions.dart';
part 'edit/parts/edit_navigation.dart';
part 'edit/parts/edit_shortcuts.dart';
part 'edit/parts/edit_media_preferences.dart';
part 'edit/parts/edit_media_actions.dart';
part 'edit/parts/edit_subtitle_rendering.dart';
part 'edit/parts/edit_selection_actions.dart';
part 'edit/parts/edit_menu_actions.dart';
part 'edit/parts/edit_initialization_helpers.dart';
part 'edit/parts/edit_interface_builders.dart';

enum _SourceLeaveChoice { save, discard, cancel }

class EditScreen extends riverpod.ConsumerStatefulWidget {
  final int subtitleCollectionId;
  final int? lastEditedIndex;
  final int sessionId;

  const EditScreen({
    super.key,
    required this.subtitleCollectionId,
    this.lastEditedIndex,
    required this.sessionId,
  });

  @override
  riverpod.ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends riverpod.ConsumerState<EditScreen> with TickerProviderStateMixin {
  // Riverpod integration helpers. Existing local UI fields are retained
  // temporarily while the Editor migration is completed incrementally.
  EditController get _controller => ref.read(editControllerProvider.notifier);
  EditState get _editState => ref.read(editControllerProvider);
  void _setEditorState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  
  Set<int> get _selectedIndices => _editState.selectedIndices;
  bool get _isSelectionMode => _editState.isSelectionMode;
  SubtitleCollection? subtitleCollection; // Make nullable to avoid late initialization error
  List<SubtitleLine> get subtitleLines => _editState.subtitleLines;
  late Future<List<SubtitleLine>> subtitleLinesFuture;
  String? get _selectedVideoPath => _editState.selectedVideoPath;
  bool get _isVideoVisible => _editState.isVideoVisible;
  bool get _isVideoLoaded => _editState.isVideoLoaded;
  List<Subtitle> get _subtitles => _editState.generatedSubtitles;
  List<Subtitle> get _secondarySubtitles => _editState.secondarySubtitles;
  List<SimpleSubtitleLine> get _originalSecondarySubtitles =>
      _editState.originalSecondarySubtitles;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  final ValueNotifier<double> _scrollbarThumbOffset = ValueNotifier<double>(0.0);
  bool _isDraggingScrollbar = false;
  int? _highlightedIndex;  final GlobalKey<VideoPlayerWidgetState> _videoPlayerKey = GlobalKey();
  final GlobalKey<WaveformWidgetState> _waveformKey =
      GlobalKey<WaveformWidgetState>();
  final bool _isLoading = false;
  Duration _lastVideoPosition = Duration.zero; // Add this to store video position
  late TextEditingController _goToController;
  bool get _showSecondarySubtitles => _editState.showSecondarySubtitles;
  bool get _isRangeSelectionActive => _editState.isRangeSelectionActive;
  int? get _rangeStartIndex => _editState.rangeStartIndex;
  bool get _floatingControlsEnabled => _editState.floatingControlsEnabled;
  bool get _isMsoneEnabled => _editState.isMsoneEnabled;
  double _resizeRatio = 0.35; // Track the resize ratio for desktop layout
  Timer? _resizeRatioSaveTimer; // Timer for debouncing resize ratio saves
  bool _isResizeRatioLoaded = false; // Track if resize ratio has been loaded from preferences
  bool _isCommentDialogOpen = false; // Track if comment dialog is currently visible
  
  // Mobile video resize support
  double _mobileVideoResizeRatio = 0.4; // Track the mobile video resize ratio
  Timer? _mobileResizeRatioSaveTimer; // Timer for debouncing mobile resize ratio saves
  
  // Subtitle change debouncer - reduces rebuilds during video playback
  Timer? _subtitleChangeDebouncer;
  bool _isMobileResizeRatioLoaded = false; // Track if mobile resize ratio has been loaded from preferences
  
  // Subtitle version tracking - increment to trigger VideoPlayerSection rebuild
  int _subtitleVersion = 0;
  
  // Store callbacks as late final members to prevent recreation and rebuilds
  late final Function(int) _onActiveSubtitleChangedStable;
  late final Function() _onSubtitlesUpdatedStable;
  late final Function() _onFullscreenExitedStable;
  late final Function(int, bool) _onSubtitleMarkedStable;
  late final Function(int, String?) _onSubtitleCommentUpdatedStable;

  // Navigation debouncing
  bool _isNavigating = false;

  // Source view support
  bool _isSourceView = false; // Track if we're in source view mode
  List<SubtitleEntry> _sourceViewEntries = []; // Store subtitle entries for source view
  bool _sourceViewDirty = false;
  final ScrollController _sourceScrollController = ScrollController(); // Separate scroll controller for source view

  // Layout switching support
  bool get _isLayout1 => _editState.isLayout1;
  
  // Waveform support
  bool _isWaveformVisible = false; // Track if waveform is visible
  
  // Hotkey registration guard - prevent repeated registration in didChangeDependencies
  bool _hotkeysRegistered = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize stable callbacks once to prevent rebuild cascades
    _onActiveSubtitleChangedStable = (arrayIndex) {
      if (arrayIndex >= 0 && arrayIndex < subtitleLines.length) {
        _onSubtitleChange(arrayIndex);
      }
    };
    
    _onSubtitlesUpdatedStable = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshSubtitleLines();
        }
      });
    };
    
    _onFullscreenExitedStable = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshSubtitleLines();
        }
      });
    };
    
    _onSubtitleMarkedStable = (subtitleIndex, isMarked) async {
      await _handleVideoPlayerMarkToggle(subtitleIndex, isMarked);
    };
    
    _onSubtitleCommentUpdatedStable = (subtitleIndex, comment) async {
      try {
        final success = await _controller.updateComment(subtitleIndex, comment);
        if (!success) throw StateError('Comment update failed');
        if (subtitleIndex < subtitleLines.length) {
          _setEditorState(() {});
          _updateSubtitlesWithVersion(subtitleLines);
          if (_videoPlayerKey.currentState != null) {
            _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
          }
        }
        if (mounted && context.mounted) {
          SnackbarHelper.showSuccess(context, 
            comment != null ? 'Comment updated' : 'Comment deleted');
        }
      } catch (e) {
        if (mounted && context.mounted) {
          SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
        } else {
          debugPrint('Failed to update comment (context unavailable): $e');
        }
      }
    };
    
    _goToController = TextEditingController();
    
    // Listen to scroll position changes to update custom scrollbar
    _itemPositionsListener.itemPositions.addListener(_updateScrollbarPosition);
    
    final initialEditorState = _editState;
    final subtitles = initialEditorState.subtitleLines;

    subtitleCollection = initialEditorState.subtitleCollection;
    _highlightedIndex = initialEditorState.highlightedIndex;
    _resizeRatio = initialEditorState.resizeRatio;
    _mobileVideoResizeRatio = initialEditorState.mobileVideoResizeRatio;
    _isResizeRatioLoaded = initialEditorState.isResizeRatioLoaded;
    _isMobileResizeRatioLoaded =
        initialEditorState.isMobileResizeRatioLoaded;
    subtitleLinesFuture = Future<List<SubtitleLine>>.value(subtitles);

    unawaited(_controller.updateLastEditedSession());
    unawaited(_registerHotkeyShortcuts());

    // Persistence and preference initialization is owned by EditController.
    // The compatibility widget only wires already-loaded state to local UI
    // handles such as scroll controllers and the video player.
    _ensureVideoPlayerSubtitles();

    final lastEditedCueNumber = widget.lastEditedIndex;
    final lastEditedListIndex = cueNumberToListIndex(lastEditedCueNumber);

    if (lastEditedCueNumber != null &&
        lastEditedListIndex != null &&
        lastEditedListIndex < subtitles.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        await _scrollToIndexWithLoading(lastEditedCueNumber);

        final startTime = parseTimeString(
          subtitles[lastEditedListIndex].startTime,
        );
        _lastVideoPosition = startTime;
        ref
            .read(waveformControllerProvider.notifier)
            .dispatch(UpdatePlaybackPosition(startTime));

        final player = await waitForVideoPlayerReady(_videoPlayerKey);
        if (mounted && player != null) {
          _seekToSubtitle(lastEditedListIndex);
        }
      });
    }

    // Check if tutorial should be shown
  }
  
  /// Creates initial checkpoint snapshot for accurate restoration
  @override
  void dispose() {
    _resizeRatioSaveTimer?.cancel(); // Cancel resize ratio save timer
    _mobileResizeRatioSaveTimer?.cancel(); // Cancel mobile resize ratio save timer
    _subtitleChangeDebouncer?.cancel(); // Cancel subtitle change debouncer
    
    // Unregister only this screen's hotkey shortcuts
    hotkey.MSoneHotkeyManager.instance.unregisterMainEditScreenShortcuts();
    
    _sourceScrollController.dispose(); // Dispose source view scroll controller
    _scrollbarThumbOffset.dispose();
    _goToController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure video player subtitles are updated when screen comes back into focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isVideoLoaded && _subtitles.isNotEmpty) {
        _updateVideoPlayerSubtitles();
      }
      // Only register hotkeys once, not on every dependency change
      if (!_hotkeysRegistered) {
        _ensureHotkeysRegistered();
      }
    });
  }

  void _showBottomModalSheet(BuildContext context, int index, String text) {
    final isMarked = subtitleLines[index].marked;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => BottomModalSheet(
        onEdit: () async {
          Navigator.pop(context);
          if (_videoPlayerKey.currentState != null &&
              _videoPlayerKey.currentState!.isInitialized()) {
            _videoPlayerKey.currentState!.pause(); // Pause the video
          }
          await _navigateToEditSubtitleScreen(index);
        },
        onAddLine: () async {
          Navigator.pop(context);
          if (subtitleCollection != null) {
            SubtitleOperations.showAddLineConfirmation(
              context: context,
              currentLine: _editState.subtitleLines[index],
              collection: subtitleCollection!,
              currentStartTime: _editState.subtitleLines[index].startTime,
              currentEndTime: _editState.subtitleLines[index].endTime,
              subtitleId: widget.subtitleCollectionId,
              refreshCallback: (newLineIndex) => _refreshSubtitleLines(), // Refresh list view
              sessionId: widget.sessionId,
              onBeforeAdd: () async => true, // No need to save anything in list view
              isVideoLoaded: _isVideoLoaded,
              getCurrentVideoPosition: _isVideoLoaded && _videoPlayerKey.currentState != null
                  ? () => _videoPlayerKey.currentState!.getCurrentPosition()
                  : null,
            );
          }
        },
        onDelete: () async {
          Navigator.pop(context);
          if (subtitleCollection != null) {
            SubtitleOperations.showDeleteConfirmation(
              context: context,
              subtitleId: widget.subtitleCollectionId,
              currentLine: _editState.subtitleLines[index],
              collection: subtitleCollection!,
              onSuccess: _refreshSubtitleLines,
              sessionId: widget.sessionId,
            );
          }
        },
        onSelect: () {
        Navigator.pop(context);
        _toggleSelection(index);
        },
        onCopy: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: text));
          SnackbarHelper.showSuccess(context, 'Copied to clipboard', duration: const Duration(seconds: 2));
        },
        onMark: () async {
          Navigator.pop(context);
          await _toggleMarkLine(index);
        },
        onEffects: () {
          Navigator.pop(context);
          _showEffectsForSingleLine(index);
        },
        onShowInMarkedLines: isMarked ? () {
          Navigator.pop(context);
          _showMarkedLinesModalWithHighlight(subtitleLines[index].index);
        } : null,
        isMarked: isMarked,
      ),
    );
  }

  void _showEffectsForSingleLine(int index) {
    final currentLine = subtitleLines[index];
    final lineText = currentLine.edited ?? currentLine.original;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SubtitleEffectsSheet(
          selectedIndices: [index], // Convert to 0-based index
          onApplyEffect: (effectType, effectConfig) {
            _applyEffectToSingleLineFromBottomSheet(context, index, effectType, effectConfig);
          },
          subtitleLines: [currentLine], // Pass the current line
          lineText: lineText, // Pass the line text
        );
      },
    );
  }

  void _showSubmitToMsoneModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Submit to Msone',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildSubmitButton(
              context: context,
              title: 'Existing Translator',
              subtitle: 'For translators with existing accounts',
              icon: Icons.person,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MsoneSubmissionScreen(
                      submissionType: 'main',
                      subtitleCollectionId: widget.subtitleCollectionId,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSubmitButton(
              context: context,
              title: 'Fresher',
              subtitle: 'For new translators',
              icon: Icons.person_add,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MsoneSubmissionScreen(
                      submissionType: 'fresher',
                      subtitleCollectionId: widget.subtitleCollectionId,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

    void _toggleSelection(int index) {
    // Riverpod migration - delegate to the Riverpod controller
    // Riverpod listener handles state synchronization automatically
    _controller.toggleSelection(index);
  }

  Widget _buildCustomScrollbar() {
    return EditorCustomScrollbar(
      thumbOffset: _scrollbarThumbOffset,
      itemCount: subtitleLines.length,
      itemScrollController: _itemScrollController,
      onDragStart: () => _isDraggingScrollbar = true,
      onDragEnd: () => _isDraggingScrollbar = false,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      editControllerProvider.select(
        (state) => (
          state.selectedIndices,
          state.isSelectionMode,
          state.isRangeSelectionActive,
          state.floatingControlsEnabled,
          state.isMsoneEnabled,
          state.isLayout1,
          state.selectedVideoPath,
          state.isVideoVisible,
          state.isVideoLoaded,
          state.showSecondarySubtitles,
          state.secondarySubtitles,
        ),
      ),
    );

    ref.listen<EditState>(editControllerProvider, (previous, next) {
      final resizeChanged =
          _resizeRatio != next.resizeRatio ||
          _mobileVideoResizeRatio != next.mobileVideoResizeRatio;

      if (!resizeChanged || !mounted) return;

      setState(() {
        _resizeRatio = next.resizeRatio;
        _mobileVideoResizeRatio = next.mobileVideoResizeRatio;
      });
    });

    return PopScope(
        canPop: !_isSelectionMode && !_isRangeSelectionActive && !_sourceViewDirty,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
        // Pause video when going back
        if (_videoPlayerKey.currentState != null &&
            _videoPlayerKey.currentState!.isInitialized()) {
          _videoPlayerKey.currentState!.pause();
        }
        
        if (_isRangeSelectionActive) {
          _controller.cancelRangeSelection();
        } else if (_isSelectionMode) {
          // Handle selection mode back press
          _clearSelection();
        } else {
          if (!didPop) {
            if (!await _resolveSourceChangesBeforeLeaving()) return;
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          }
        }
      },
        child: FirstTimeInstructions(
          screenName: 'edit',
          instructions: editScreenInstructions,
          child: Stack(
          children: [
          Scaffold(
            appBar: AppBar(
              leading: _isSelectionMode || _isRangeSelectionActive
              ? IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    if (_isRangeSelectionActive) {
                      _controller.cancelRangeSelection();
                    } else {
                      _clearSelection();
                    }
                  },
                )
              : IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (!await _resolveSourceChangesBeforeLeaving()) return;
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              title: _isRangeSelectionActive
                  ? Text('Select range: tap first & last')
                  : (_isSelectionMode
                     ? Text('${_selectedIndices.length} selected')
                     : Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           if (_isSourceView) ...[
                             Icon(
                               Icons.code,
                               size: 16,
                               color: Theme.of(context).colorScheme.primary,
                             ),
                             const SizedBox(width: 4),
                           ],
                           Flexible(
                             child: ScrollingTitleWidget(
                               title: subtitleCollection?.fileName ?? 'Subtitle Studio',
                               style: const TextStyle(fontSize: 16),
                               maxWidth: MediaQuery.of(context).size.width * 0.4,
                             ),
                           ),
                           if (_isSourceView) ...[
                             const SizedBox(width: 8),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: Text(
                                 'SOURCE',
                                 style: TextStyle(
                                   fontSize: 10,
                                   fontWeight: FontWeight.bold,
                                   color: Theme.of(context).colorScheme.primary,
                                 ),
                               ),
                             ),
                           ],
                         ],
                       )),
              actions: [
                if (_isSelectionMode) ...[
                  // Selection mode actions - now using modal sheet
                  IconButton(
                    tooltip: 'Selection options',
                    icon: Icon(Icons.more_vert),
                    onPressed: () => _showSelectionMenuModal(),
                  ),
                ] else ...[
                  // Normal mode actions (unchanged)
                  const ThemeSwitcherButton(),
                  if (_isVideoLoaded && !_isSourceView) // Hide video toggle in source view
                    IconButton(
                      onPressed: () {
                        if (_isVideoVisible &&
                            _videoPlayerKey.currentState != null) {
                          _lastVideoPosition = _videoPlayerKey
                              .currentState!
                              .getCurrentPosition();
                        }

                        _controller.toggleVideoVisibility();

                        if (_isVideoVisible) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            unawaited(_restoreVideoPositionWhenReady());
                          });
                        }
                      },
                      icon: _isVideoVisible
                          ? SvgPicture.asset(
                              'assets/movie_off.svg',
                              semanticsLabel: 'Movie off',
                              height: 25,
                              width: 35,
                            )                          : Icon(Icons.movie_outlined),
                    ),
                  if (_isVideoLoaded && !_isSourceView) // Hide waveform toggle in source view
                    IconButton(
                      tooltip: _isWaveformVisible ? 'Hide Waveform' : 'Show Waveform',
                      onPressed: _toggleWaveform,
                      icon: Icon(
                        _isWaveformVisible ? Icons.graphic_eq : Icons.graphic_eq_outlined,
                        color: Colors.white.withValues(alpha: _isWaveformVisible ? 1.0 : 0.5),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Main menu',
                    icon: const Icon(Icons.menu),
                    onPressed: () => _showMainMenuModal(),
                  ),
                ],
              ],
            ),
            body: SafeArea(
              child: FutureBuilder<List<SubtitleLine>>(
                future: subtitleLinesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: IsolatedLoader(isVisible: true,));
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return EditorEmptySubtitleView(onAddSubtitle: _addInitialSubtitleLine);
                  }
                  
                  // Switch between source view and timeline view
                  if (_isSourceView) {
                    return _buildSourceView(snapshot.data!);
                  } else {
                    return _buildResponsiveContent(snapshot.data!);
                  }
                },
              ),
            ),
          ),

          // Add floating play/pause button when enabled (hide in source view)
          if (!_isSourceView && _floatingControlsEnabled && _isVideoVisible && _isVideoLoaded && _videoPlayerKey.currentState != null)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                heroTag: 'floatingPlayPause',
                onPressed: () {
                  if (_videoPlayerKey.currentState!.isInitialized()) {
                    _videoPlayerKey.currentState!.playOrPause();
                  }
                },
                backgroundColor: Colors.blue,
                child: StreamBuilder<bool>(
                  stream: _videoPlayerKey.currentState!.player.stream.playing,
                  builder: (context, snapshot) {
                    // Use the player's current state as the fallback value
                    final isPlaying = snapshot.data ?? _videoPlayerKey.currentState!.player.state.playing;
                    return Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    );
                  },
                ),
              ),
            ),
            
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const IsolatedLoader(isVisible: true,), // Use the new loader
            ),
        ],
      ),
    ),
  );
  }

  // Method to add the initial subtitle line
  /// Build source view widget for direct text editing
  Widget _buildSourceView(List<SubtitleLine> subtitleLines) {
    if (_sourceViewEntries.isEmpty ||
        _sourceViewEntries.length != subtitleLines.length) {
      _sourceViewEntries = _convertSubtitleLinesToEntries(subtitleLines);
    }

    return SourceViewPane(
      entries: _sourceViewEntries,
      scrollController: _sourceScrollController,
      onChanged: _onSourceViewContentChanged,
    );
  }

}
