import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/screens/edit/services/raw_srt_document.dart';
import 'package:subtitle_studio/screens/edit/widgets/source_view_pane.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';
import 'package:subtitle_studio/utils/text_formatting.dart';
import 'package:subtitle_studio/widgets/dictionary_search_widget.dart';
import 'package:subtitle_studio/widgets/olam_dictionary_widget.dart';
import 'package:subtitle_studio/widgets/urban_dictionary_widget.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_history_labels.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';
import 'studio_dock_geometry.dart';
import 'studio_dock_playback_link.dart';
import 'studio_dock_layout_preferences.dart';
import 'studio_dock_timing_edit_service.dart';
import 'studio_dock_insert_cue_dialog.dart';
import 'studio_dock_split_cue_dialog.dart';
import 'studio_dock_go_to_line_dialog.dart';
import 'studio_dock_file_actions.dart';
import 'studio_dock_style_actions.dart';
import 'studio_dock_style_color_dialog.dart';
import 'studio_dock_search_service.dart';
import 'studio_dock_quality_dialog.dart';
import 'studio_dock_bulk_review_service.dart';
import '../../utils/msone_hotkey_manager.dart';

enum _StudioDockReviewFilter { all, marked, unresolved, resolved }

enum _StudioDockToolbarOverflow {
  merge, delete, attachVideo, import, newProject, projectSettings,
}

/// Same persisted switches used by mobile Edit Line; formatted preview is
/// intentionally session-only (mobile also does not persist its toggle).
enum StudioDockEditPreference {
  showOriginalLine,
  autoSaveWithNavigation,
  showOriginalTextField,
}

enum _StudioDockMenuAction {
  undo, redo, find, copySelected, selectAll, addCue, deleteCue, splitCue, mergeCue, notes,
  timing, shiftTools, showTools, qualityCheck, showMarkedLines, syncSubtitles,
  sourceView,
  history, submitMsone,
  loadSecondary, toggleSecondary,
  shiftSelected, deleteSelected, selectByIndex, rangeSelection, goToLine,
  importComments, removeHearingImpaired, insertMsoneBanners, normalizeMalayalam,
  boldFormat, italicFormat, colorPicker, pasteOriginal,
  msoneDictionary, olamDictionary, urbanDictionary,
  explorer, inspector, toggleFullscreen, floatingPlayback, unloadVideo,
  repeatCurrent, repeatRange, settings, help,
  showOriginalLine, autoSaveWithNavigation, showOriginalTextField,
  formattedView,
}

/// One subtitle row displayed in the Studio Dock workspace.
@immutable
class StudioDockCue {
  const StudioDockCue({
    required this.id,
    required this.start,
    required this.end,
    required this.original,
    required this.edited,
    this.storedEdited,
    this.marked = false,
    this.comment,
    this.resolved = false,
  });

  final int id;
  final String start;
  final String end;
  final String original;
  final String edited;
  /// The actual nullable persisted edit. Null means "use original" when
  /// copying/exporting effective text; an explicit empty edit stays empty.
  final String? storedEdited;
  final bool marked;
  final String? comment;
  final bool resolved;

  StudioDockCue copyWith({
    String? start, String? end, String? original, String? edited, bool? marked,
    String? comment, bool clearComment = false, bool? resolved,
  }) =>
      StudioDockCue(
        id: id, start: start ?? this.start, end: end ?? this.end,
        original: original ?? this.original,
        edited: edited ?? this.edited,
        storedEdited: edited ?? storedEdited,
        marked: marked ?? this.marked,
        comment: clearComment ? null : comment ?? this.comment,
        resolved: resolved ?? this.resolved,
      );
}

/// Complete refreshed cue list after a structural history transaction.
/// Structural commands can renumber every later cue; never patch just one row.
class StudioDockCueUpdate {
  const StudioDockCueUpdate({
    required this.cues,
    required this.selectedCueId,
    this.selectedCueIds,
  });

  final List<StudioDockCue> cues;
  final int selectedCueId;
  /// Optional multi-selection restored by a group operation. Legacy single-
  /// cue edits continue selecting only [selectedCueId].
  final List<int>? selectedCueIds;
}

/// A saved project in the desktop sidebar, backed by the same session list as
/// the mobile project selector. No new database or synthetic project copies.
@immutable
class StudioDockProjectEntry {
  const StudioDockProjectEntry({
    required this.id,
    required this.title,
    required this.isEditMode,
  });

  final int id;
  final String title;
  final bool isEditMode;
}

enum _StudioDockFileMenuAction {
  save, saveAs, export, saveProject, saveProjectAs, projectSettings,
}

/// Desktop workspace UI. Persisted changes are handled by injected callbacks
/// to the shared editor, history, media and file services.
class StudioDockWorkspace extends StatefulWidget {
  const StudioDockWorkspace({
    super.key,
    required this.initialCues,
    this.initialSelectedCueId,
    this.isLiveSession = false,
    this.isEditMode = false,
    this.showOriginalLine = false,
    this.autoSaveWithNavigation = false,
    this.showOriginalTextField = true,
    this.onSaveEditPreference,
    this.projectTitle,
    this.encoding,
    this.onChooseProject,
    this.projects = const [],
    this.activeProjectId,
    this.onSelectProject,
    this.onImportFile,
    this.onNewProject,
    this.onApplyCueText,
    this.onApplyCueOriginal,
    this.onApplyCueTiming,
    this.onApplyCueTextAndTiming,
    this.onApplyCueNotes,
    this.onApplyBulkReview,
    this.onFindCues,
    this.onReplaceMatches,
    this.onApplyQualityFixes,
    this.onShiftAllCues,
    this.onSyncAnchoredCues,
    this.onConvertFramerate,
    this.getVideoFramerate,
    this.onShiftSelectedCues,
    this.onDeleteSelectedCues,
    this.onClearAllFormatting,
    this.onInsertCue,
    this.onDeleteCue,
    this.onSplitCue,
    this.onMergeCue,
    this.onLoadHistory,
    this.onRestoreHistory,
    this.checkpointHistoryPanel,
    this.onLoadSourceView,
    this.onApplySourceView,
    this.onSaveFile,
    this.onSaveAsFile,
    this.onExportFile,
    this.onSaveProject,
    this.onSaveProjectAs,
    this.videoSurface,
    this.waveformSurface,
    this.playback,
    this.onChooseVideo,
    this.onUnloadVideo,
    this.onTogglePlayback,
    this.onToggleFullscreen,
    this.onToggleRepeat,
    this.onOpenRepeatRange,
    this.onSelectedCueChanged,
    this.repeatEnabled = false,
    this.onOpenAppSettings,
    this.onOpenProjectSettings,
    this.onImportComments,
    this.onRemoveHearingImpaired,
    this.onOpenHelp,
    this.onSubmitToMsone,
    this.onInsertMsoneBanners,
    this.onNormalizeMalayalam,
    this.onLoadSecondarySubtitles,
    this.onToggleSecondarySubtitles,
    this.showSecondarySubtitles = true,
    this.manageLiveHotkeys = false,
  });

  /// The real session supplies its persisted cues; a development harness can
  /// inject explicit sample cues. The production widget contains no fixture.
  final List<StudioDockCue> initialCues;
  /// Initial selection if present in [initialCues]; otherwise the first cue.
  final int? initialSelectedCueId;
  /// Distinguishes a session connected to shared services from a local demo.
  final bool isLiveSession;
  /// Scratch-created subtitles have one editable text track, unlike translation.
  final bool isEditMode;
  final bool showOriginalLine;
  final bool autoSaveWithNavigation;
  final bool showOriginalTextField;
  /// Null in previews/harnesses without shared persisted Edit Line settings.
  final Future<bool> Function(StudioDockEditPreference preference, bool value)?
      onSaveEditPreference;
  final String? projectTitle;
  final String? encoding;
  final VoidCallback? onChooseProject;
  final List<StudioDockProjectEntry> projects;
  final int? activeProjectId;
  final ValueChanged<int>? onSelectProject;
  final VoidCallback? onImportFile;
  final VoidCallback? onNewProject;
  /// Non-null only when the production checkpoint-backed edit bridge is ready.
  final Future<bool> Function(int cueNumber, String editedText)? onApplyCueText;
  /// Explicit source-text editing is separate from translation editing.
  final Future<bool> Function(int cueNumber, String originalText)?
      onApplyCueOriginal;
  /// Production timing changes use the same optimistic history boundary as
  /// text edits. Null when timing edits are unavailable.
  final Future<bool> Function(int cueNumber, String start, String end)?
      onApplyCueTiming;
  /// Saves simultaneous Text-inspector changes as one optimistic checkpoint.
  final Future<bool> Function(
      int cueNumber, String editedText, String start, String end)?
      onApplyCueTextAndTiming;
  /// One atomic review-note/mark/resolution commit through shared history.
  final Future<StudioDockCueUpdate?> Function(
      int cueNumber, String? comment, bool marked, bool resolved)?
      onApplyCueNotes;
  final Future<StudioDockCueUpdate?> Function(
      List<int> cueNumbers, StudioDockReviewAction action,
      int preferredCue)? onApplyBulkReview;
  /// Read-only query from the authoritative loaded session snapshot.
  final List<StudioDockSearchHit> Function(
      String term, bool caseSensitive, bool wholeWord)? onFindCues;
  /// Atomic, guarded replacement of selected search-time match snapshots.
  final Future<StudioDockCueUpdate?> Function(
      List<StudioDockSearchHit> matches, String term,
      String replacement, bool caseSensitive)? onReplaceMatches;
  /// Whitespace suggestions are checked against the current source and
  /// committed in a single checkpoint by the live session bridge.
  final Future<StudioDockCueUpdate?> Function(List<SubtitleQualityFix> fixes)?
      onApplyQualityFixes;
  final Future<StudioDockCueUpdate?> Function(
      int selectedCueNumber, int deltaMilliseconds)? onShiftAllCues;
  /// Mobile Sync Subtitles: first/last anchors, duration-preserving scaling.
  final Future<StudioDockCueUpdate?> Function(
      int selectedCueNumber, String newStart, String newEnd)? onSyncAnchoredCues;
  /// Mobile framerate conversion: scale both cue boundaries by source/target.
  final Future<StudioDockCueUpdate?> Function(
      int selectedCueNumber, double sourceFps, double targetFps)?
      onConvertFramerate;
  /// Current native player frame rate when available, otherwise use 25 fps.
  final double? Function()? getVideoFramerate;
  /// Selected time stretch uses the mobile first-start/last-end anchor model.
  final Future<StudioDockCueUpdate?> Function(
      List<int> cueNumbers, String newStart, String newEnd, int preferredCue)?
      onShiftSelectedCues;
  /// Guarded, atomic multi-delete; returns complete reindexed cue state.
  final Future<StudioDockCueUpdate?> Function(
      List<int> cueNumbers, int preferredCue)? onDeleteSelectedCues;
  final Future<StudioDockCueUpdate?> Function(
      int selectedCueNumber)? onClearAllFormatting;
  final Future<StudioDockCueUpdate?> Function(
      int? afterCueNumber, StudioDockNewCueDraft draft)? onInsertCue;
  final Future<StudioDockCueUpdate?> Function(int cueNumber)? onDeleteCue;
  final Future<StudioDockCueUpdate?> Function(
      int cueNumber, StudioDockSplitCueDraft draft)? onSplitCue;
  final Future<StudioDockCueUpdate?> Function(
      int cueNumber, bool withPrevious)? onMergeCue;
  /// The shared checkpoint graph is authoritative; never infer Undo/Redo
  /// availability from the workspace's local cue list.
  final Future<CheckpointHistoryGraph> Function()? onLoadHistory;
  /// Restores a saved point with the HEAD observed by this window. Returns
  /// complete persisted cues, not a partial UI-only edit.
  final Future<StudioDockCueUpdate?> Function(
      int targetCheckpointId, int expectedHeadId, int preferredCueId)?
      onRestoreHistory;
  /// Live desktop uses the same full graph/bookmark/branch interface as mobile.
  /// Demos without a session continue using the local history preview.
  final Widget? checkpointHistoryPanel;
  /// Loads the authoritative raw SRT snapshot once the inspector is clean.
  final Future<String> Function()? onLoadSourceView;
  /// One guarded full-document history commit; null for read-only sessions.
  final Future<StudioDockCueUpdate?> Function(String rawSrt)? onApplySourceView;
  /// File Save is separate from the already checkpoint-backed inspector Apply.
  final Future<StudioDockFileResult> Function()? onSaveFile;
  final Future<StudioDockFileResult> Function()? onSaveAsFile;
  final Future<StudioDockFileResult> Function(bool originalOnly)? onExportFile;
  /// Complete .msone document with checkpoint graph, separate from SRT Save.
  final Future<StudioDockFileResult> Function()? onSaveProject;
  final Future<StudioDockFileResult> Function()? onSaveProjectAs;
  /// Optional existing native-player surface, supplied by the session host.
  final Widget? videoSurface;
  /// The real production waveform shares a seek/position link with video.
  final Widget? waveformSurface;
  final StudioDockPlaybackLink? playback;
  /// Select/change media with the existing native picker and video repository.
  final VoidCallback? onChooseVideo;
  /// Removes the persisted video link, leaving the original media file intact.
  /// The live host owns the existing player and repository transaction.
  final Future<bool> Function()? onUnloadVideo;
  /// Toggle the already-mounted native player; never create another player.
  final VoidCallback? onTogglePlayback;
  /// Toggle fullscreen on the same mounted native video player.
  final VoidCallback? onToggleFullscreen;
  /// The shared native player repeats the currently selected subtitle.
  final VoidCallback? onToggleRepeat;
  /// Opens the shared mobile repeat-range dialog for the native player.
  final VoidCallback? onOpenRepeatRange;
  final ValueChanged<int>? onSelectedCueChanged;
  final bool repeatEnabled;
  /// Opens the production shared SettingsSheet instead of a parallel desktop
  /// preferences implementation. The host owns provider-dependent UI.
  final Future<void> Function()? onOpenAppSettings;
  /// Hosts the existing ProjectSettingsSheet on native desktop. The live
  /// session refreshes paths, encoding, cues and history when it closes.
  final Future<void> Function()? onOpenProjectSettings;
  /// Opens the mobile project's .msone comment importer in a native desktop
  /// dialog and refreshes the shared checkpoint-backed session afterward.
  final Future<void> Function()? onImportComments;
  /// Shared hearing-impaired cleanup, persisted in a single history transaction.
  final Future<StudioDockCueUpdate?> Function(int selectedCueNumber)?
      onRemoveHearingImpaired;
  /// Opens the existing HelpScreen, shared with the mobile editor.
  final Future<void> Function()? onOpenHelp;
  /// Opens the established MSone submission flow after the current draft is
  /// resolved. The host checks the persisted MSone-features preference.
  final Future<void> Function()? onSubmitToMsone;
  /// Existing mobile MSone banner configuration/history service.
  final Future<void> Function()? onInsertMsoneBanners;
  /// Existing mobile Malayalam normalizer preview/history service.
  final Future<void> Function()? onNormalizeMalayalam;
  /// Uses the mobile secondary-track picker and persisted track preference.
  final Future<void> Function()? onLoadSecondarySubtitles;
  /// The host owns the current track; this is only a visibility toggle.
  final VoidCallback? onToggleSecondarySubtitles;
  final bool showSecondarySubtitles;
  /// Standalone desktop may manage hotkeys; an embedded host must not override
  /// callbacks owned by its parent.
  final bool manageLiveHotkeys;

  @override
  StudioDockWorkspaceState createState() => StudioDockWorkspaceState();
}

class StudioDockWorkspaceState extends State<StudioDockWorkspace> {
  static const double _cueRowHeight = 28;

  int get selectedCueNumber => _selectedId;
  List<int> get selectedCueNumbers => List.unmodifiable(_selectedIds);

  Color get _accent => Theme.of(context).colorScheme.primary;
  Color get _border => Theme.of(context).colorScheme.outlineVariant;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;

  late final List<StudioDockCue> _cues;
  int _selectedId = -1;
  int _selectionAnchor = -1;
  final Set<int> _selectedIds = {};
  bool _rangeSelectionMode = false;
  int? _rangeStartCueId;
  bool _runningSelectedBatch = false;
  final StudioDockLayoutPreferences _layoutPreferences = StudioDockLayoutPreferences();
  Timer? _layoutSaveTimer;
  bool _layoutChangedSinceMount = false;
  final ScrollController _cueScroll = ScrollController();
  int? _playingCueId;
  bool _followPlayback = true;
  final List<Color> _styleColorHistory = [];
  final FocusNode _gridFocus = FocusNode(debugLabel: 'Studio Dock grid');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'Studio Dock search');
  final FocusNode _findFocus = FocusNode(debugLabel: 'Studio Dock Find');
  final FocusNode _cueTextFocus = FocusNode(debugLabel: 'Studio Dock cue text');
  int? _focusEditorCueOnMount;
  final TextEditingController _commandSearch = TextEditingController();
  final TextEditingController _tableSearch = TextEditingController();
  final TextEditingController _findInput = TextEditingController();
  final TextEditingController _replaceInput = TextEditingController();
  final TextEditingController _shiftMillisecondsInput =
      TextEditingController(text: '1000');
  List<StudioDockSearchHit> _findResults = const [];
  final Set<int> _selectedFindResults = {};
  bool _findCaseSensitive = false;
  bool _findWholeWord = false;
  bool _searched = false;
  bool _replacingMatches = false;
  bool _runningTool = false;
  bool _openingMsoneSubmission = false;
  bool _openingMsoneTools = false;
  ModalRoute<dynamic>? _msoneBannerMenuRoute;
  ModalRoute<dynamic>? _msoneNormalizeMenuRoute;
  bool _floatingPlaybackVisible = false;
  bool _openingProjectSettings = false;
  bool _openingCommentImport = false;
  bool _openingHearingCleanup = false;
  ModalRoute<dynamic>? _hearingMenuRoute;
  ModalRoute<dynamic>? _msoneMenuRoute;
  ModalRoute<dynamic>? _secondaryMenuRoute;
  ModalRoute<dynamic>? _dictionaryMenuRoute;
  ModalRoute<dynamic>? _unloadVideoMenuRoute;
  ModalRoute<dynamic>? _projectSettingsMenuRoute;
  ModalRoute<dynamic>? _commentsMenuRoute;
  ModalRoute<dynamic>? _markedLinesMenuRoute;
  ModalRoute<dynamic>? _qualityMenuRoute;
  bool _applyingQualityFixes = false;
  String? _findError;
  String? _toolsError;
  int _section = 0;
  bool _playing = false;
  bool _inspectorOpen = true;
  bool _explorerOpen = true;
  bool _projectsSidebar = false;
  bool _explorerOverlayOpen = false;
  bool _inspectorOverlayOpen = false;
  int _inspectorTab = 0;
  double _videoShare = StudioDockBands.defaultVideoShare;
  double _waveformShare = StudioDockBands.defaultWaveformShare;
  bool _showVideo = false;
  bool _showWaveform = false;
  String _query = '';
  _StudioDockReviewFilter _reviewFilter = _StudioDockReviewFilter.all;
  int? _draftCueId;
  String? _draftText;
  bool _originalEditing = false;
  int? _draftOriginalCueId;
  String? _draftOriginal;
  int? _draftTimingCueId;
  String? _draftStart;
  String? _draftEnd;
  String? _durationError;
  int _timingFieldRevision = 0;
  int _durationFieldRevision = 0;
  int? _draftNotesCueId;
  String? _draftNoteText;
  bool? _draftMarked;
  bool? _draftResolved;
  int _draftRevision = 0;
  bool _savingDraft = false;
  bool _changingStructure = false;
  bool _savingFile = false;
  bool _unloadingVideo = false;
  bool _updatingEditPreference = false;
  bool _formattedView = false;
  bool _navigatingCue = false;
  ModalRoute<dynamic>? _editPreferenceMenuRoute;
  bool _historyBusy = false;
  bool _historyLoading = false;
  String _sourceText = '';
  String _sourceBaseline = '';
  String? _sourceError;
  bool _sourceLoading = false;
  bool _sourceSaving = false;
  bool get _sourceDirty => _sourceText != _sourceBaseline;
  String? _historyError;
  CheckpointHistoryGraph? _history;
  int _historyRequest = 0;
  double _sidebarWidth = 240;
  double _inspectorWidth = 320;

  StudioDockCue get _selected =>
      _cues.firstWhere((cue) => cue.id == _selectedId);
  List<StudioDockCue> get _visible => _cues.where((cue) {
    final included = switch (_reviewFilter) {
      _StudioDockReviewFilter.all => true,
      _StudioDockReviewFilter.marked => cue.marked,
      _StudioDockReviewFilter.unresolved => cue.marked && !cue.resolved,
      _StudioDockReviewFilter.resolved => cue.marked && cue.resolved,
    };
    if (!included) return false;
    final q = _query.trim().toLowerCase();
    return q.isEmpty || cue.original.toLowerCase().contains(q) ||
        cue.edited.toLowerCase().contains(q) ||
        cue.start.contains(q) || cue.id.toString() == q;
  }).toList(growable: false);

  String get _subtitleCountLabel {
    final total = _cues.length;
    if (total == 0) return '0 subtitles';
    final shown = _visible.length;
    final selected = _selectedIds.length;
    if (shown != total) {
      return selected > 1
          ? '$shown of $total shown · $selected selected'
          : '$shown of $total shown';
    }
    return selected > 1
        ? '$selected selected · $total subtitles'
        : '$total subtitles';
  }


  static const _managedActions = <HotkeyAction>[
    HotkeyAction.nextLine,
    HotkeyAction.previousLine,
    HotkeyAction.playPause,
    HotkeyAction.toggleFullscreen,
    HotkeyAction.toggleRepeat,
    HotkeyAction.toggleRepeatRange,
    HotkeyAction.boldFormat,
    HotkeyAction.italicFormat,
    HotkeyAction.colorPicker,
    HotkeyAction.pasteOriginal,
    HotkeyAction.msoneDictionary,
    HotkeyAction.olamDictionary,
    HotkeyAction.urbanDictionary,
    HotkeyAction.delete,
    HotkeyAction.editCurrentLine,
    HotkeyAction.showMarkedLines,
    HotkeyAction.findReplace,
    HotkeyAction.gotoLine,
    HotkeyAction.markLine,
    HotkeyAction.splitLine,
    HotkeyAction.mergeLine,
    HotkeyAction.save,
    HotkeyAction.saveAs,
    HotkeyAction.saveProject,
    HotkeyAction.markLineAndComment,
    HotkeyAction.help,
    HotkeyAction.settings,
  ];

  bool _allowedLiveHotkey(HotkeyAction action) =>
      action == HotkeyAction.nextLine ||
      action == HotkeyAction.previousLine ||
      action == HotkeyAction.playPause && widget.onTogglePlayback != null ||
      action == HotkeyAction.toggleFullscreen &&
          widget.onToggleFullscreen != null ||
      action == HotkeyAction.toggleRepeat && widget.onToggleRepeat != null ||
      action == HotkeyAction.toggleRepeatRange &&
          widget.onOpenRepeatRange != null ||
      (action == HotkeyAction.boldFormat ||
          action == HotkeyAction.italicFormat ||
          action == HotkeyAction.colorPicker ||
          action == HotkeyAction.msoneDictionary ||
          action == HotkeyAction.olamDictionary ||
          action == HotkeyAction.urbanDictionary) &&
          widget.onApplyCueText != null ||
      action == HotkeyAction.pasteOriginal &&
          widget.onApplyCueText != null && !widget.isEditMode ||
      action == HotkeyAction.delete &&
          (widget.onDeleteSelectedCues != null || widget.onDeleteCue != null) ||
      action == HotkeyAction.editCurrentLine &&
          widget.onApplyCueText != null ||
      action == HotkeyAction.showMarkedLines && _cues.isNotEmpty ||
      action == HotkeyAction.findReplace ||
      action == HotkeyAction.gotoLine ||
      action == HotkeyAction.markLine && widget.onApplyBulkReview != null ||
      action == HotkeyAction.markLineAndComment &&
          widget.onApplyCueNotes != null ||
      action == HotkeyAction.splitLine && widget.onSplitCue != null ||
      action == HotkeyAction.mergeLine && widget.onMergeCue != null ||
      action == HotkeyAction.save && widget.onSaveFile != null ||
      action == HotkeyAction.saveAs && widget.onSaveAsFile != null ||
      action == HotkeyAction.saveProject && widget.onSaveProject != null ||
      action == HotkeyAction.help && widget.onOpenHelp != null ||
      action == HotkeyAction.settings && widget.onOpenAppSettings != null;

  @override
  void initState() {
    super.initState();
    _cues = List<StudioDockCue>.from(widget.initialCues);
    _selectedId = _cues.isEmpty ? -1 :
        _cues.any((cue) => cue.id == widget.initialSelectedCueId)
            ? widget.initialSelectedCueId! : _cues.first.id;
    _selectionAnchor = _selectedId;
    _selectedIds.addAll(_selectedId > 0 ? [_selectedId] : <int>[]);
    // Desktop entrypoint initializes the application's existing hotkey manager.
    // Direct widget tests do not initialize native plugins.
    // An embedded host may be nested in an already-running Editor.
    // Never override its registered MSoneHotkeyManager callbacks.
    if (!widget.isLiveSession || widget.manageLiveHotkeys) {
      unawaited(_installManagedHotkeys());
    }
    widget.playback?.position.addListener(_onPlaybackPosition);
    unawaited(_restoreLayout());
    unawaited(_reloadHistory());
  }

  Future<void> _installManagedHotkeys() async {
    final manager = MSoneHotkeyManager.instance;
    for (final action in _managedActions) {
      if (widget.isLiveSession && !_allowedLiveHotkey(action)) continue;
      if (!mounted) return;
      await manager.registerCallback(action, () {
        // Only the topmost editor route may run an in-app shortcut.
        // In particular, never save or change cues behind a modal sheet.
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
        if (_isEditingText) {
          // Keep clipboard/native editing and other fields independent. Only
          // the actual subtitle text field receives format/dictionary/paste
          // commands; timing, find, notes and search never do.
          if (action != HotkeyAction.save &&
              action != HotkeyAction.saveAs &&
              action != HotkeyAction.saveProject &&
              !(_cueTextFocus.hasFocus && _isCueTextShortcut(action))) return;
        }
        _dispatchManagedAction(action);
      });
    }
  }

  @override
  void didUpdateWidget(covariant StudioDockWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEditMode != widget.isEditMode ||
        oldWidget.activeProjectId != widget.activeProjectId) {
      // A project switch must not carry the previous editor's draft or
      // translation/edit-mode form state into the newly selected project.
      _draftCueId = null;
      _draftText = null;
      _draftOriginalCueId = null;
      _draftOriginal = null;
      _originalEditing = false;
      _draftTimingCueId = null;
      _draftStart = null;
      _draftEnd = null;
      _durationError = null;
      _draftRevision++;
      _cues
        ..clear()
        ..addAll(widget.initialCues);
      _selectedId = _cues.any((line) => line.id == widget.initialSelectedCueId)
          ? widget.initialSelectedCueId!
          : _cues.isEmpty ? -1 : _cues.first.id;
      _selectedIds
        ..clear()
        ..addAll(_selectedId < 0 ? <int>[] : [_selectedId]);
      _selectionAnchor = _selectedId;
      _inspectorTab = 0;
    }
    if (oldWidget.showOriginalLine != widget.showOriginalLine &&
        !_hasDirtyTextDraft) {
      // TextFormField.initialValue must be reloaded when the original fallback
      // changes, without replacing a user's still-unapplied edit.
      _draftRevision++;
    }
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback?.position.removeListener(_onPlaybackPosition);
      widget.playback?.position.addListener(_onPlaybackPosition);
      _onPlaybackPosition();
    }
    if (oldWidget.onLoadHistory != widget.onLoadHistory) {
      unawaited(_reloadHistory());
    }
  }

  void _onPlaybackPosition() {
    if (!mounted || widget.playback == null || _cues.isEmpty) return;
    final millis = widget.playback!.position.value.inMilliseconds;
    int? active;
    for (final cue in _cues) {
      final start = TimeValidator.timeStringToMilliseconds(cue.start);
      final end = TimeValidator.timeStringToMilliseconds(cue.end);
      if (millis >= start && millis < end) { active = cue.id; break; }
    }
    if (active == _playingCueId) return;
    setState(() => _playingCueId = active);
    if (!_followPlayback || active == null || _query.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cueScroll.hasClients || !_followPlayback) return;
      final index = _visible.indexWhere((cue) => cue.id == active);
      if (index < 0) return;
      final target = (index * _cueRowHeight -
              _cueScroll.position.viewportDimension / 2 +
              _cueRowHeight / 2)
          .clamp(0.0, _cueScroll.position.maxScrollExtent).toDouble();
      _cueScroll.animateTo(target,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _historyRequest++;
    widget.playback?.position.removeListener(_onPlaybackPosition);
    _cueScroll.dispose();
    _layoutSaveTimer?.cancel();
    if (_layoutChangedSinceMount) unawaited(_persistLayout());
    if (!widget.isLiveSession || widget.manageLiveHotkeys) {
      for (final action in _managedActions) {
        if (widget.isLiveSession && !_allowedLiveHotkey(action)) continue;
        unawaited(MSoneHotkeyManager.instance.unregisterCallback(action));
      }
    }
    _commandSearch.dispose();
    _tableSearch.dispose();
    _findInput.dispose();
    _replaceInput.dispose();
    _shiftMillisecondsInput.dispose();
    _gridFocus.dispose();
    _searchFocus.dispose();
    _findFocus.dispose();
    _cueTextFocus.dispose();
    super.dispose();
  }


  Future<void> _restoreLayout() async {
    try {
      final saved = await _layoutPreferences.load();
      if (!mounted || _layoutChangedSinceMount) return;
      setState(() {
        _sidebarWidth = saved.explorerWidth;
        _inspectorWidth = saved.inspectorWidth;
        _videoShare = saved.videoShare;
        _waveformShare = saved.waveformShare;
        _explorerOpen = saved.explorerOpen;
        _inspectorOpen = saved.inspectorOpen;
        _showVideo = saved.videoOpen;
        _showWaveform = saved.waveformOpen;
      });
    } catch (error) {
      debugPrint('Studio Dock layout preferences unavailable: $error');
    }
  }

  StudioDockLayoutSnapshot get _layoutSnapshot => StudioDockLayoutSnapshot(
    explorerWidth: _sidebarWidth,
    inspectorWidth: _inspectorWidth,
    videoShare: _videoShare,
    waveformShare: _waveformShare,
    explorerOpen: _explorerOpen,
    inspectorOpen: _inspectorOpen,
    videoOpen: _showVideo,
    waveformOpen: _showWaveform,
  );

  Future<void> _persistLayout() async {
    final snapshot = _layoutSnapshot;
    try {
      await _layoutPreferences.save(snapshot);
    } catch (error) {
      debugPrint('Could not persist Studio Dock layout: $error');
    }
  }

  void _queueLayoutSave({bool now = false}) {
    _layoutChangedSinceMount = true;
    _layoutSaveTimer?.cancel();
    if (now) {
      unawaited(_persistLayout());
    } else {
      _layoutSaveTimer = Timer(const Duration(milliseconds: 350),
          () => unawaited(_persistLayout()));
    }
  }

  void _resetLayout() {
    setState(() {
      _sidebarWidth = 240;
      _inspectorWidth = 320;
      _videoShare = StudioDockBands.defaultVideoShare;
      _waveformShare = StudioDockBands.defaultWaveformShare;
      _explorerOpen = true;
      _inspectorOpen = true;
      _showVideo = false;
      _showWaveform = false;
      _projectsSidebar = false;
      _explorerOverlayOpen = false;
      _inspectorOverlayOpen = false;
    });
    _queueLayoutSave(now: true);
  }

  bool get _isEditingText {
    final c = FocusManager.instance.primaryFocus?.context;
    return c != null &&
        c.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  static bool _isCueTextShortcut(HotkeyAction action) =>
      action == HotkeyAction.boldFormat ||
      action == HotkeyAction.italicFormat ||
      action == HotkeyAction.colorPicker ||
      action == HotkeyAction.pasteOriginal ||
      action == HotkeyAction.msoneDictionary ||
      action == HotkeyAction.olamDictionary ||
      action == HotkeyAction.urbanDictionary;

  void _dispatchManagedAction(HotkeyAction action) {
    switch (action) {
      case HotkeyAction.nextLine:
        unawaited(_selectRelativeWithPlayback(1));
      case HotkeyAction.previousLine:
        unawaited(_selectRelativeWithPlayback(-1));
      case HotkeyAction.playPause:
        if (widget.isLiveSession) {
          widget.onTogglePlayback?.call();
        } else {
          setState(() => _playing = !_playing);
        }
      case HotkeyAction.toggleFullscreen:
        widget.onToggleFullscreen?.call();
      case HotkeyAction.toggleRepeat:
        widget.onToggleRepeat?.call();
      case HotkeyAction.toggleRepeatRange:
        widget.onOpenRepeatRange?.call();
      case HotkeyAction.boldFormat:
        _formatCueShortcut('b');
      case HotkeyAction.italicFormat:
        _formatCueShortcut('i');
      case HotkeyAction.colorPicker:
        unawaited(_pickStyleColor());
      case HotkeyAction.pasteOriginal:
        _pasteOriginalDraft();
      case HotkeyAction.msoneDictionary:
      case HotkeyAction.olamDictionary:
      case HotkeyAction.urbanDictionary:
        unawaited(_openDictionary(action));
      case HotkeyAction.delete:
        if (_selectedIds.length > 1 && widget.onDeleteSelectedCues != null) {
          unawaited(_deleteSelectedSafely());
        } else if (widget.onDeleteCue != null) {
          unawaited(_deleteCueSafely());
        } else if (widget.onDeleteSelectedCues != null) {
          unawaited(_deleteSelectedSafely());
        }
      case HotkeyAction.editCurrentLine:
        if (widget.onApplyCueText != null && _cues.isNotEmpty) {
          unawaited(_toggleInspectorFromShortcut(0));
        }
      case HotkeyAction.showMarkedLines:
        unawaited(_showMarkedLinesFromShortcut());
      case HotkeyAction.findReplace:
        unawaited(_openFind());
      case HotkeyAction.gotoLine:
        unawaited(_goToLineSafely());
      case HotkeyAction.markLineAndComment:
        if (widget.onApplyCueNotes != null) {
          if (_section == 0 && _inspectorOpen && _inspectorTab == 2) {
            unawaited(_toggleInspectorFromShortcut(2));
          } else {
            unawaited(_openReviewNotesForHotkey());
          }
        }
      case HotkeyAction.markLine:
        if (widget.onApplyBulkReview != null) {
          unawaited(_toggleReviewSelection());
        } else {
          _toggleMarkedSelection();
        }
      case HotkeyAction.splitLine:
        unawaited(_splitCueSafely());
      case HotkeyAction.mergeLine:
        unawaited(_mergeCueSafely());
      case HotkeyAction.save:
        unawaited(_saveFileSafely());
      case HotkeyAction.saveAs:
        unawaited(_saveAsFileSafely());
      case HotkeyAction.saveProject:
        unawaited(_saveProjectSafely());
      case HotkeyAction.help:
        final help = widget.onOpenHelp;
        if (help != null) unawaited(help());
      case HotkeyAction.settings:
        unawaited(_switchSection(4));
      default:
        break;
    }
  }

  Future<void> _reloadHistory() async {
    final request = ++_historyRequest;
    final load = widget.onLoadHistory;
    if (load == null) {
      if (mounted) setState(() {
        _history = null;
        _historyError = null;
        _historyLoading = false;
      });
      return;
    }
    if (mounted) setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final graph = await load();
      if (!mounted || request != _historyRequest) return;
      setState(() {
        _history = graph;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _historyRequest) return;
      setState(() {
        _history = null;
        _historyLoading = false;
        _historyError = 'Could not load the saved editing history.';
      });
    }
  }

  /// Refresh Undo/Redo pointers after an externally restored checkpoint.
  Future<void> reloadHistoryFromSession() => _reloadHistory();

  HistoryGraphNode? get _currentHistoryPoint {
    final graph = _history;
    if (graph == null) return null;
    for (final node in graph.nodes) {
      if (node.checkpointId == graph.headCheckpointId) return node;
    }
    return null;
  }

  bool get _historyNavigationBlocked => _historyBusy || _historyLoading ||
      _changingStructure || _savingDraft || _savingFile || _sourceSaving;

  Future<void> _restoreHistoryPoint(int targetCheckpointId) async {
    final restore = widget.onRestoreHistory;
    final expectedHead = _history?.headCheckpointId;
    if (restore == null || expectedHead == null ||
        expectedHead == targetCheckpointId || _historyNavigationBlocked) return;
    if (!await _confirmDraftBeforeLeaving() || !mounted) return;
    setState(() => _historyBusy = true);
    StudioDockCueUpdate? update;
    try {
      update = await restore(targetCheckpointId, expectedHead, _selectedId);
    } catch (_) {
      update = null;
    }
    if (!mounted) return;
    setState(() => _historyBusy = false);
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not restore this version. The project may '
            'have changed in another window. Reload history and retry.'),
      ));
      unawaited(_reloadHistory());
      return;
    }
    _acceptStructure(update);
  }

  Future<void> _undoHistory() async {
    final parentId = _currentHistoryPoint?.parentCheckpointId;
    if (parentId != null) await _restoreHistoryPoint(parentId);
  }

  Future<void> _redoHistory() async {
    final current = _currentHistoryPoint;
    if (current == null || current.childCheckpointIds.isEmpty ||
        _historyNavigationBlocked) return;
    final choices = current.childCheckpointIds;
    int? target = choices.singleOrNull;
    if (target == null) {
      // A history fork has no uniquely correct Redo. Let the user choose the
      // saved path instead of silently picking the newest timestamp.
      target = await showDialog<int>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Choose a version to redo'),
          content: SizedBox(width: 420, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final childId in choices)
                ListTile(
                  key: ValueKey('studio-redo-choice-$childId'),
                  title: Text(_historyTitle(childId)),
                  subtitle: Text('History point #$childId'),
                  onTap: () => Navigator.pop(dialog, childId),
                ),
            ],
          )),
          actions: [TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          )],
        ),
      );
    }
    if (target != null && mounted) await _restoreHistoryPoint(target);
  }

  String _historyTitle(int checkpointId) {
    final graph = _history;
    if (graph == null) return 'Saved version';
    for (final node in graph.nodes) {
      if (node.checkpointId == checkpointId) {
        return CheckpointHistoryLabels.entryTitle(
          operationType: node.operationType, description: node.description);
      }
    }
    return 'Saved version';
  }

  void _toggleMarkedSelection() {
    if (widget.isLiveSession || _selectedIds.isEmpty) return;
    setState(() {
      for (var i = 0; i < _cues.length; i++) {
        final cue = _cues[i];
        if (_selectedIds.contains(cue.id)) {
          _cues[i] = cue.copyWith(marked: !cue.marked);
        }
      }
    });
  }

  Future<void> _toggleReviewSelection() async {
    final ids = _selectedIds.isNotEmpty
        ? _selectedIds.toList()
        : (_selectedId > 0 ? [_selectedId] : <int>[]);
    if (ids.isEmpty) return;
    final chosen = _cues.where((cue) => ids.contains(cue.id));
    await _applyReviewSelection(ids, action: chosen.every((cue) => cue.marked)
        ? StudioDockReviewAction.unmark : StudioDockReviewAction.mark);
  }

  Future<void> _applyReviewSelection(
      List<int> cueNumbers, {required StudioDockReviewAction action}) async {
    final apply = widget.onApplyBulkReview;
    if (apply == null || _changingStructure || _savingDraft ||
        cueNumbers.isEmpty) return;
    if (!await _confirmDraftBeforeLeaving() || !mounted) return;
    final chosen = _cues.where((cue) => cueNumbers.contains(cue.id)).toList();
    if (chosen.length != cueNumbers.toSet().length) return;
    final clearsNotes = action == StudioDockReviewAction.unmark && chosen.any((cue) =>
        cue.comment?.isNotEmpty == true || cue.resolved);
    final marksUnmarked = action == StudioDockReviewAction.resolve &&
        chosen.any((cue) => !cue.marked);
    final name = switch (action) {
      StudioDockReviewAction.mark => 'Mark',
      StudioDockReviewAction.unmark => 'Unmark',
      StudioDockReviewAction.resolve => 'Resolve',
      StudioDockReviewAction.reopen => 'Reopen',
    };
    final prompt = switch (action) {
      StudioDockReviewAction.mark =>
        'Mark ${cueNumbers.length} selected subtitles for review?',
      StudioDockReviewAction.unmark =>
        'Remove review marks from ${cueNumbers.length} subtitles? '
        '${clearsNotes ? 'Their comments and resolved flags will also be cleared.' : ''}',
      StudioDockReviewAction.resolve =>
        'Resolve ${cueNumbers.length} selected subtitles? '
        '${marksUnmarked ? 'Unmarked subtitles will also be marked for review. ' : ''}'
        'Comments will be kept.',
      StudioDockReviewAction.reopen =>
        'Reopen ${cueNumbers.length} selected reviews? '
        'Marks and comments will be kept.',
    };
    if (cueNumbers.length > 1 || clearsNotes || marksUnmarked) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => _modalKeys<bool>(dialog,
          confirm: true, cancel: false, child: AlertDialog(
          title: Text('$name selected subtitles?'),
          content: Text('$prompt One history point will be saved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel')),
            FilledButton(
              key: const ValueKey('studio-bulk-review-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(name),
            ),
          ],
        )),
      );
      if (approved != true || !mounted) return;
    }
    final selected = cueNumbers.contains(_selectedId)
        ? _selectedId : cueNumbers.first;
    setState(() => _changingStructure = true);
    StudioDockCueUpdate? update;
    try {
      update = await apply(cueNumbers, action, selected);
    } catch (_) {
      update = null;
    }
    if (!mounted) return;
    setState(() => _changingStructure = false);
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not update reviews. The subtitles may '
            'have changed elsewhere. Please refresh before retrying.'),
      ));
      return;
    }
    _acceptStructure(update);
  }

  bool get _hasDirtyTextDraft => widget.onApplyCueText != null &&
      _draftCueId == _selectedId &&
      _draftText != null && _draftText != _selected.edited;

  bool get _hasDirtyTimingDraft => widget.onApplyCueTiming != null &&
      _draftTimingCueId == _selectedId &&
      (_draftStart != null && _draftStart != _selected.start ||
       _draftEnd != null && _draftEnd != _selected.end ||
       _durationError != null);

  static String? _normalizeNote(String? text) =>
      text == null || text.trim().isEmpty ? null : text;

  String get _noteText => _draftNotesCueId == _selectedId &&
      _draftNoteText != null ? _draftNoteText! : _selected.comment ?? '';
  bool get _noteMarked => _draftNotesCueId == _selectedId &&
      _draftMarked != null ? _draftMarked! : _selected.marked;
  bool get _noteResolved => _draftNotesCueId == _selectedId &&
      _draftResolved != null ? _draftResolved! : _selected.resolved;
  bool get _hasDirtyNotesDraft => widget.onApplyCueNotes != null &&
      _cues.isNotEmpty && _draftNotesCueId == _selectedId &&
      (_draftNoteText != null &&
          _normalizeNote(_draftNoteText) != _normalizeNote(_selected.comment) ||
       _draftMarked != null && _draftMarked != _selected.marked ||
       _draftResolved != null && _draftResolved != _selected.resolved);

  bool get _hasDirtyDraft => _hasDirtyTextDraft || _hasDirtyTimingDraft ||
      _hasDirtyNotesDraft || _hasDirtyOriginalDraft;

  bool get _hasDirtyOriginalDraft => widget.onApplyCueOriginal != null &&
      _draftOriginalCueId == _selectedId && _draftOriginal != null &&
      _draftOriginal != _selected.original;

  bool get _canApplyContentDraft =>
      (_hasDirtyTextDraft || _hasDirtyTimingDraft || _hasDirtyOriginalDraft) &&
      (!_hasDirtyTextDraft || !_hasDirtyTimingDraft ||
          widget.onApplyCueTextAndTiming != null) &&
      !_savingDraft && !_savingFile &&
      (!_hasDirtyTimingDraft || _timingError == null);

  String get _timingStart => _draftTimingCueId == _selectedId
      ? _draftStart ?? _selected.start : _selected.start;
  String get _timingEnd => _draftTimingCueId == _selectedId
      ? _draftEnd ?? _selected.end : _selected.end;
  String? get _timingError =>
      (_draftTimingCueId == _selectedId ? _durationError : null) ??
      StudioDockTimingEditService.validate(_timingStart, _timingEnd);

  String get _styleText => _draftCueId == _selectedId && _draftText != null
      ? _draftText!
      : _selected.edited.isNotEmpty ? _selected.edited : _selected.original;

  void _setStyleDraft(String text) {
    if (widget.onApplyCueText == null || _savingDraft || _cues.isEmpty) return;
    setState(() {
      _draftCueId = _selectedId;
      _draftText = text;
      // TextFormField.initialValue is only read when its state is mounted.
      // Recreate it after external actions, not after every user keystroke.
      _draftRevision++;
    });
  }

  TextEditingController? get _focusedCueController {
    if (!_cueTextFocus.hasFocus) return null;
    return _cueTextFocus.context
        ?.findAncestorStateOfType<EditableTextState>()?.widget.controller;
  }

  void _replaceEditedDraft(String replacement) {
    if (_cues.isEmpty || widget.onApplyCueText == null || _savingDraft) return;
    final focused = _focusedCueController;
    if (focused == null) {
      _setStyleDraft(replacement);
      return;
    }
    focused.value = TextEditingValue(
      text: replacement,
      selection: TextSelection.collapsed(offset: replacement.length),
    );
    setState(() {
      _draftCueId = _selectedId;
      _draftText = replacement;
    });
  }

  void _formatCueShortcut(String tag) {
    if (_cues.isEmpty || widget.onApplyCueText == null || _savingDraft) return;
    final controller = _focusedCueController;
    if (controller == null) {
      _toggleStyleTag(tag);
      return;
    }
    toggleTextFormatting(controller: controller, tag: tag);
    setState(() {
      _draftCueId = _selectedId;
      _draftText = controller.text;
    });
  }

  Widget _studioTextContextMenu(
      BuildContext context, EditableTextState editable,
      {required bool original}) {
    final canFormat = !_savingDraft &&
        (original ? _originalEditing && widget.onApplyCueOriginal != null
                  : widget.onApplyCueText != null);
    void format(String tag) {
      toggleTextFormatting(controller: editable.widget.controller, tag: tag);
      setState(() {
        if (original) {
          _draftOriginalCueId = _selectedId;
          _draftOriginal = editable.widget.controller.text;
        } else {
          _draftCueId = _selectedId;
          _draftText = editable.widget.controller.text;
        }
      });
      ContextMenuController.removeAny();
    }
    final items = <ContextMenuButtonItem>[
      ...editable.contextMenuButtonItems,
      if (canFormat) for (final (name, tag) in const [
        ('Bold', 'b'), ('Italic', 'i'), ('Underline', 'u'),
      ])
        ContextMenuButtonItem(
          label: name,
          onPressed: () => format(tag),
        ),
      if (canFormat) ContextMenuButtonItem(
        label: 'Text color',
        onPressed: () {
          final controller = editable.widget.controller;
          ContextMenuController.removeAny();
          unawaited(_pickContextTextColor(controller, original: original));
        },
      ),
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editable.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Future<void> _pickContextTextColor(TextEditingController controller,
      {required bool original}) async {
    final selection = controller.selection;
    final text = controller.text;
    final selected = selection.isValid && !selection.isCollapsed
        ? selection.textInside(text) : text;
    if (selected.isEmpty) return;
    final selectedLine = _selectedId;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => StudioDockStyleColorDialog(
        text: selected,
        initialColor: Theme.of(context).colorScheme.onSurface,
        colorHistory: _styleColorHistory,
      ),
    );
    if (chosen == null || !mounted || selectedLine != _selectedId) return;
    final begin = selection.isValid && !selection.isCollapsed ? selection.start : 0;
    final end = selection.isValid && !selection.isCollapsed ? selection.end : text.length;
    controller.value = TextEditingValue(
      text: text.replaceRange(begin, end, chosen),
      selection: TextSelection.collapsed(offset: begin + chosen.length),
    );
    setState(() {
      if (original) {
        _draftOriginalCueId = selectedLine;
        _draftOriginal = controller.text;
      } else {
        _draftCueId = selectedLine;
        _draftText = controller.text;
      }
    });
  }

  void _pasteOriginalDraft() {
    // Original text is a separate source only in translation mode.
    if (!widget.isEditMode && _cues.isNotEmpty) {
      _replaceEditedDraft(_selected.original);
    }
  }

  Future<void> _openDictionary(HotkeyAction action,
      {ModalRoute<dynamic>? afterMenu}) async {
    if (afterMenu != null) await afterMenu.completed;
    if (!mounted || _cues.isEmpty || widget.onApplyCueText == null ||
        _savingDraft) return;
    final selectedCue = _selectedId;
    final lookup = !widget.isEditMode && _selected.original.isNotEmpty
        ? _selected.original : _styleText;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 720,
          height: (MediaQuery.sizeOf(dialogContext).height - 64)
              .clamp(260.0, 760.0).toDouble(),
          child: switch (action) {
            HotkeyAction.msoneDictionary => DictionarySearchWidget(
                initialSearchTerm: lookup,
                onSelectTranslation: (text) =>
                    Navigator.of(dialogContext).pop(text),
              ),
            HotkeyAction.olamDictionary => OlamDictionaryWidget(
                initialSearchTerm: lookup,
                enableResultSelection: true,
                onSelectTranslation: (text) =>
                    Navigator.of(dialogContext).pop(text),
              ),
            HotkeyAction.urbanDictionary => UrbanDictionaryWidget(
                initialSearchTerm: lookup,
                enableResultSelection: true,
                onSelectTranslation: (text) =>
                    Navigator.of(dialogContext).pop(text),
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
    // Modal opening and closing should not commit the project or overwrite a
    // different cue when a host selection changed while the lookup was open.
    if (mounted && chosen != null && selectedCue == _selectedId) {
      _replaceEditedDraft(chosen);
    }
  }

  void _toggleStyleTag(String tag) => _setStyleDraft(
    StudioDockStyleActions.toggleTag(_styleText, tag),
  );

  Future<void> _pickStyleColor() async {
    if (widget.onApplyCueText == null || _savingDraft) return;
    final current = _styleText;
    final body = StudioDockStyleActions.body(current);
    if (body.isEmpty) return;
    final prefix = current.substring(0, current.length - body.length);
    final initialColor = Theme.of(context).colorScheme.onSurface;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => StudioDockStyleColorDialog(
        text: body,
        initialColor: initialColor,
        colorHistory: _styleColorHistory,
      ),
    );
    if (chosen != null && mounted) _setStyleDraft(prefix + chosen);
  }

  void _discardDraft() {
    setState(() {
      _draftCueId = null;
      _draftText = null;
      _draftOriginalCueId = null;
      _draftOriginal = null;
      _originalEditing = false;
      _draftTimingCueId = null;
      _draftStart = null;
      _draftEnd = null;
      _durationError = null;
      _draftNotesCueId = null;
      _draftNoteText = null;
      _draftMarked = null;
      _draftResolved = null;
      _draftRevision++;
    });
  }

  Future<bool> _applyDraft() async {
    if (_savingDraft || _savingFile) return false;
    if (!_hasDirtyDraft) return true;
    if (_hasDirtyOriginalDraft && !await _applyOriginalDraft()) return false;
    if (!_hasDirtyTextDraft && !_hasDirtyTimingDraft &&
        !_hasDirtyNotesDraft) return true;
    if (_hasDirtyNotesDraft) {
      if (_hasDirtyTextDraft || _hasDirtyTimingDraft) return false;
      return _applyNotesDraft();
    }
    // Text and Timing share one inspector: if both changed, committing them
    // separately would create a partial save and lose the draft boundary.
    if (_hasDirtyTextDraft && _hasDirtyTimingDraft &&
        widget.onApplyCueTextAndTiming == null) return false;
    final cueId = _selectedId;
    final timing = _hasDirtyTimingDraft;
    final textChanged = _hasDirtyTextDraft;
    final text = _draftText;
    final start = _timingStart;
    final end = _timingEnd;
    if (timing && _timingError != null) return false;
    setState(() => _savingDraft = true);
    bool applied;
    try {
      if (timing && textChanged) {
        applied = await widget.onApplyCueTextAndTiming?.call(
            cueId, text!, start, end) ?? false;
      } else if (timing) {
        applied = await widget.onApplyCueTiming?.call(cueId, start, end) ?? false;
      } else {
        applied = await widget.onApplyCueText?.call(cueId, text!) ?? false;
      }
    } catch (_) {
      applied = false;
    }
    if (!mounted) return false;
    setState(() {
      _savingDraft = false;
      if (applied) {
        final i = _cues.indexWhere((cue) => cue.id == cueId);
        if (i >= 0) {
          _cues[i] = _cues[i].copyWith(
            edited: textChanged ? text : null,
            start: timing ? start : null,
            end: timing ? end : null,
          );
        }
        _draftCueId = null;
        _draftText = null;
        _draftTimingCueId = null;
        _draftStart = null;
        _draftEnd = null;
        _durationError = null;
        _draftRevision++;
      }
    });
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not apply this edit. The subtitle may have '
            'changed elsewhere. Your draft is preserved.'),
      ));
    }
    if (applied) unawaited(_reloadHistory());
    return applied;
  }

  Future<bool> _applyOriginalDraft() async {
    final apply = widget.onApplyCueOriginal;
    final text = _draftOriginal;
    if (apply == null || text == null || !_hasDirtyOriginalDraft ||
        _savingDraft) return false;
    final cueId = _selectedId;
    setState(() => _savingDraft = true);
    bool saved;
    try { saved = await apply(cueId, text); }
    catch (_) { saved = false; }
    if (!mounted) return false;
    setState(() {
      _savingDraft = false;
      if (saved) {
        final index = _cues.indexWhere((cue) => cue.id == cueId);
        if (index >= 0) {
          _cues[index] = _cues[index].copyWith(original: text);
        }
        _draftOriginal = null;
        _draftOriginalCueId = null;
        _originalEditing = false;
        _draftRevision++;
      }
    });
    if (saved) unawaited(_reloadHistory());
    return saved;
  }

  /// Explicit Shift+Enter workflow in the Text inspector: commit the current
  /// text/timing draft before navigating. A failed save must never advance.
  Future<void> _applyDraftAndAdvance() async {
    if (widget.onApplyCueText == null || _savingDraft || _navigatingCue ||
        _visible.isEmpty) return;
    final visibleIds = _visible.map((cue) => cue.id).toList();
    final position = visibleIds.indexOf(_selectedId);
    if (position < 0) return;
    if (_hasDirtyDraft && !await _applyDraft()) return;
    if (!mounted) return;
    if (position + 1 < visibleIds.length) {
      // The previous TextFormField is disposed when its cue key changes.
      // Let the *new* field claim keyboard focus on mount, rather than
      // requesting focus on the old field during the navigation frame.
      // A shared FocusNode can remain marked focused while its EditableText
      // and input connection are replaced. Explicitly blur it first so the
      // newly mounted editor opens its own keyboard connection.
      _cueTextFocus.unfocus();
      _focusEditorCueOnMount = visibleIds[position + 1];
      _applyCueSelection(visibleIds[position + 1]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusEditorCueOnMount != _selectedId) return;
        _cueTextFocus.requestFocus();
        _focusEditorCueOnMount = null;
      });
    }
  }

  Future<bool> _applyNotesDraft() async {
    final apply = widget.onApplyCueNotes;
    if (apply == null || _savingDraft) return false;
    final cueId = _selectedId;
    final marked = _noteMarked;
    final resolved = marked && _noteResolved;
    final comment = marked ? _normalizeNote(_noteText) : null;
    setState(() => _savingDraft = true);
    StudioDockCueUpdate? update;
    try {
      update = await apply(cueId, comment, marked, resolved);
    } catch (_) {
      update = null;
    }
    if (!mounted) return false;
    setState(() => _savingDraft = false);
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save review notes. The subtitle may have '
            'changed elsewhere. Your draft is preserved.'),
      ));
      return false;
    }
    _acceptStructure(update);
    return true;
  }

  Future<bool> _confirmDraftBeforeLeaving() async {
    if (_savingDraft || _changingStructure || _savingFile ||
        _sourceSaving || _sourceLoading) return false;
    if (_section == 5 && _sourceDirty) {
      return _confirmSourceDraftBeforeLeaving();
    }
    if (!_hasDirtyDraft) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _modalKeys<String>(dialogContext,
        confirm: 'apply', cancel: 'cancel', child: AlertDialog(
        title: const Text('Unsaved subtitle edit'),
        content: const Text('Apply this line edit before leaving it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'apply'),
            child: const Text('Apply'),
          ),
        ],
      )),
    );
    if (!mounted) return false;
    if (choice == 'discard') {
      _discardDraft();
      return true;
    }
    if (choice == 'apply') return _applyDraft();
    return false;
  }

  /// Explicit desktop dialog actions: Enter activates the primary confirm
  /// button, Escape takes the safe cancellation path. Focused text inputs
  /// retain normal editing in dialogs that do not opt into this wrapper.
  Widget _modalKeys<T>(BuildContext dialogContext, {
    required T confirm,
    required T cancel,
    required Widget child,
  }) => _modalActions(
    onConfirm: () => Navigator.of(dialogContext).pop<T>(confirm),
    onCancel: () => Navigator.of(dialogContext).pop<T>(cancel),
    child: child,
  );

  /// Data-entry dialogs pass their validation/async actions here instead of
  /// returning a result directly. Enter must never bypass a failed validation
  /// or invoke a disabled Apply button while an operation is in flight.
  Widget _modalActions({
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    required Widget child,
  }) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter):
          onConfirm,
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          onConfirm,
      const SingleActivator(LogicalKeyboardKey.escape):
          onCancel,
    },
    // AlertDialog does not always have an initially focused descendant.
    // Own a focus target inside the shortcut scope so Enter works immediately
    // even before the user tabs to a button. Editable fields can take focus.
    child: Focus(autofocus: true, child: child),
  );

  /// Only cue-to-cue navigation follows Edit Line's auto-save preference.
  /// File, project, source, review and media transitions always retain their
  /// explicit draft confirmation boundary.
  Future<bool> _prepareForCueNavigation() async {
    if (_savingDraft || _savingFile || _changingStructure) return false;
    if (!_hasDirtyDraft) return true;
    final mayAutoSave = widget.onSaveEditPreference != null &&
        (!widget.showOriginalLine || widget.autoSaveWithNavigation);
    if (mayAutoSave && !_hasDirtyNotesDraft) return _applyDraft();
    return _confirmDraftBeforeLeaving();
  }

  Future<void> _setEditPreference(StudioDockEditPreference preference,
      {ModalRoute<dynamic>? afterMenu}) async {
    if (afterMenu != null) await afterMenu.completed;
    final save = widget.onSaveEditPreference;
    if (!mounted || save == null || _updatingEditPreference) return;
    if (preference == StudioDockEditPreference.showOriginalLine &&
        !await _confirmDraftBeforeLeaving()) return;
    if (!mounted) return;
    final current = switch (preference) {
      StudioDockEditPreference.showOriginalLine => widget.showOriginalLine,
      StudioDockEditPreference.autoSaveWithNavigation =>
        widget.autoSaveWithNavigation,
      StudioDockEditPreference.showOriginalTextField =>
        widget.showOriginalTextField,
    };
    final next = !current;
    if (preference == StudioDockEditPreference.showOriginalLine) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => _modalKeys<bool>(dialog,
          confirm: true, cancel: false, child: AlertDialog(
          title: Text(next ? 'Show original line when edit is empty?'
              : 'Stop showing original line in empty edits?'),
          content: Text(next
              ? 'Empty edits will display the original text. To prevent '
                  'unintended edits, automatic saving on navigation will be '
                  'turned off until you re-enable it.'
              : 'Empty edits will remain empty. Automatic saving on '
                  'navigation will be enabled, as in mobile Edit Line.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel')),
            FilledButton(
              key: const ValueKey('studio-confirm-original-line'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Continue'),
            ),
          ],
        )),
      );
      if (approved != true || !mounted) return;
    }
    setState(() => _updatingEditPreference = true);
    bool saved;
    try {
      saved = await save(preference, next);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() => _updatingEditPreference = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save the Edit Line preference. Try again.'),
      ));
    }
  }

  Future<bool> _confirmSourceDraftBeforeLeaving() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => _modalKeys<String>(dialog,
        confirm: 'apply', cancel: 'cancel', child: AlertDialog(
        title: const Text('Unsaved Source View changes'),
        content: const Text('Apply the raw SRT changes before leaving Source View?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, 'cancel'),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialog, 'discard'),
            child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.pop(dialog, 'apply'),
            child: const Text('Apply')),
        ],
      )),
    );
    if (!mounted) return false;
    if (choice == 'discard') {
      _discardSourceDraft();
      return true;
    }
    if (choice == 'apply') return _applySourceView();
    return false;
  }

  void _discardSourceDraft() => setState(() {
    _sourceText = _sourceBaseline;
    _sourceError = null;
  });

  Future<bool> _applySourceView() async {
    final apply = widget.onApplySourceView;
    if (apply == null || _sourceSaving || _sourceLoading) return false;
    if (!_sourceDirty) return true;
    try {
      RawSrtDocument.parseStrict(_sourceText);
    } on FormatException catch (error) {
      if (mounted) setState(() => _sourceError = error.message);
      return false;
    }

    setState(() { _sourceSaving = true; _sourceError = null; });
    StudioDockCueUpdate? update;
    try {
      update = await apply(_sourceText);
    } catch (_) {
      update = null;
    }
    if (!mounted) return false;
    if (update == null) {
      setState(() {
        _sourceSaving = false;
        _sourceError = 'Could not apply Source View. The project may have '
            'changed in another window. Your draft is preserved.';
      });
      return false;
    }
    _acceptStructure(update);
    var canonical = _sourceText;
    try {
      canonical = await widget.onLoadSourceView?.call() ?? _sourceText;
    } catch (_) {
      // The database commit succeeded; retain the submitted document as the
      // clean baseline if the follow-up display refresh is unavailable.
    }
    if (!mounted) return false;
    setState(() {
      _sourceText = canonical;
      _sourceBaseline = canonical;
      _sourceSaving = false;
      _sourceError = null;
    });
    return true;
  }

  Future<void> _changeInspectorTab(int tab) async {
    if (tab == _inspectorTab) return;
    if (!await _confirmDraftBeforeLeaving() || !mounted) return;
    setState(() => _inspectorTab = tab);
  }

  Future<void> _selectSidebarProject(int id) async {
    if (id >= 0 && id == widget.activeProjectId) return;
    if (!await _confirmDraftBeforeLeaving() || !mounted) return;
    switch (id) {
      case -1:
        widget.onChooseProject?.call();
      case -2:
        widget.onNewProject?.call();
      case -3:
        widget.onImportFile?.call();
      default:
        widget.onSelectProject?.call(id);
    }
  }
  Future<void> _importFileSafely() async {
    if (await _confirmDraftBeforeLeaving() && mounted) {
      widget.onImportFile?.call();
    }
  }

  Future<void> _chooseVideoSafely() async {
    if (await _confirmDraftBeforeLeaving() && mounted) {
      widget.onChooseVideo?.call();
    }
  }

  Future<void> _unloadVideoSafely(
      {ModalRoute<dynamic>? afterMenu}) async {
    if (afterMenu != null) await afterMenu.completed;
    final unload = widget.onUnloadVideo;
    if (unload == null || widget.videoSurface == null || _unloadingVideo ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool>(dialog,
        confirm: true, cancel: false, child: AlertDialog(
        title: const Text('Unload this video?'),
        content: const Text('The video will be detached from this project. '
            'The original video file will not be deleted. You can attach '
            'it again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('studio-confirm-unload-video'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Unload video'),
          ),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unloadingVideo = true);
    var succeeded = false;
    try {
      succeeded = await unload();
    } catch (_) {
      succeeded = false;
    } finally {
      if (mounted) setState(() => _unloadingVideo = false);
    }
    if (!mounted || succeeded) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Could not unlink this video. The project is unchanged.'),
    ));
  }

  Future<void> _newProjectSafely() async {
    if (await _confirmDraftBeforeLeaving() && mounted) {
      widget.onNewProject?.call();
    }
  }

  Future<void> _submitMsoneSafely({ModalRoute<dynamic>? afterMenu}) async {
    final submit = widget.onSubmitToMsone;
    if (submit == null || _openingMsoneSubmission) return;
    setState(() => _openingMsoneSubmission = true);
    try {
      // Match the mobile fix: a popup's barrier must be gone before the
      // choice sheet and submission route enter the same Navigator overlay.
      if (afterMenu != null) await afterMenu.completed;
      if (!mounted || !await _confirmDraftBeforeLeaving() || !mounted) return;
      await submit();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open MSone submission. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingMsoneSubmission = false);
    }
  }

  Future<void> _openMsoneToolSafely(
      Future<void> Function()? open, {
      required String name,
      ModalRoute<dynamic>? afterMenu,
  }) async {
    if (open == null || _openingMsoneTools || _cues.isEmpty) return;
    setState(() => _openingMsoneTools = true);
    try {
      // Dismiss the Tools popup before opening a real modal bottom sheet,
      // and never abandon an inspector/Source View draft silently.
      if (afterMenu != null) await afterMenu.completed;
      if (!mounted || !await _confirmDraftBeforeLeaving() || !mounted) return;
      await open();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open $name. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingMsoneTools = false);
    }
  }

  Future<void> _openProjectSettingsSafely({ModalRoute<dynamic>? afterMenu}) async {
    final open = widget.onOpenProjectSettings;
    if (open == null || _openingProjectSettings) return;
    setState(() => _openingProjectSettings = true);
    try {
      // Keep the shared settings route clear of the outgoing File popup.
      if (afterMenu != null) await afterMenu.completed;
      if (!mounted || !await _confirmDraftBeforeLeaving() || !mounted) return;
      await open();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open Project Settings. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingProjectSettings = false);
    }
  }

  Future<void> _removeHearingSafely({ModalRoute<dynamic>? afterMenu}) async {
    final remove = widget.onRemoveHearingImpaired;
    if (remove == null || _openingHearingCleanup || _cues.isEmpty) return;
    setState(() => _openingHearingCleanup = true);
    try {
      if (afterMenu != null) await afterMenu.completed;
      if (!mounted) return;
      await _runBulkTool(
        title: 'Remove hearing-impaired annotations',
        detail: 'Clean bracketed descriptions, sound effects, music notes, '
            'speaker labels, and parenthesized descriptions from source '
            'subtitle text. Lines left empty may be deleted. Stored '
            'translations and review metadata on surviving lines are kept. '
            'Continue?',
        apply: () => remove(_selectedId),
      );
    } finally {
      if (mounted) setState(() => _openingHearingCleanup = false);
    }
  }

  Future<void> _importCommentsSafely({ModalRoute<dynamic>? afterMenu}) async {
    final openImport = widget.onImportComments;
    if (openImport == null || _openingCommentImport || _cues.isEmpty) return;
    setState(() => _openingCommentImport = true);
    try {
      // File picker and dialog must not compete with the departing Tools
      // popup's barrier or accidentally bypass an unsaved inspector edit.
      if (afterMenu != null) await afterMenu.completed;
      if (!mounted || !await _confirmDraftBeforeLeaving() || !mounted) return;
      await openImport();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not import project comments. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingCommentImport = false);
    }
  }

  Future<void> _loadSecondarySafely({ModalRoute<dynamic>? afterMenu}) async {
    final load = widget.onLoadSecondarySubtitles;
    if (load == null) return;
    // Let the popup barrier leave the Navigator before opening the picker.
    if (afterMenu != null) await afterMenu.completed;
    if (mounted) await load();
  }

  void _acceptStructure(StudioDockCueUpdate update) {
    setState(() {
      _cues..clear()..addAll(update.cues);
      _selectedId = update.selectedCueId;
      _selectionAnchor = _selectedId;
      _selectedIds
        ..clear()
        ..addAll(update.selectedCueIds ??
            (_selectedId > 0 ? [_selectedId] : <int>[]));
      _rangeSelectionMode = false;
      _rangeStartCueId = null;
      _query = '';
      _tableSearch.clear();
      _draftCueId = null;
      _draftText = null;
      _draftTimingCueId = null;
      _draftStart = null;
      _draftEnd = null;
      _durationError = null;
      _draftNotesCueId = null;
      _draftNoteText = null;
      _draftMarked = null;
      _draftResolved = null;
      _draftRevision++;
    });
    widget.onSelectedCueChanged?.call(_selectedId);
    unawaited(_reloadHistory());
  }

  /// The native waveform shares this exact draft gate with other desktop
  /// navigation/structure actions; a pending inspector edit is never erased.
  Future<bool> prepareForExternalEdit() async =>
      mounted && !_changingStructure &&
      await _confirmDraftBeforeLeaving() && mounted;

  /// A guarded host transaction succeeded: reconcile every cue and history
  /// in the current editor instead of retaining an outdated local snapshot.
  void acceptExternalCueUpdate(StudioDockCueUpdate update) {
    if (mounted) _acceptStructure(update);
  }

  /// A waveform double-click selects the matching subtitle in the Dock grid.
  /// All existing selection/draft protections remain in effect.
  void highlightCueFromWaveform(int cueId) {
    if (!mounted) return;
    _selectCue(cueId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cueScroll.hasClients) return;
      final index = _visible.indexWhere((cue) => cue.id == cueId);
      if (index < 0) return;
      final target = (index * _cueRowHeight -
              _cueScroll.position.viewportDimension / 2 +
              _cueRowHeight / 2)
          .clamp(0.0, _cueScroll.position.maxScrollExtent).toDouble();
      _cueScroll.animateTo(target,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  String _formatCueTime(int millis) {
    final hours = millis ~/ 3600000;
    final minutes = (millis ~/ 60000) % 60;
    final seconds = (millis ~/ 1000) % 60;
    final fraction = millis % 1000;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},'
        '${fraction.toString().padLeft(3, '0')}';
  }

  Future<void> _addCueSafely() async {
    if (widget.onInsertCue == null || _changingStructure ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    // The initial two-second span is a convenience, not a write: the user
    // confirms both times in the dialog before creating a checkpoint.
    const latestStart = 86397999; // 23:59:57,999: leave room for 2s.
    final requested = _cues.isEmpty ? 0 :
        TimeValidator.timeStringToMilliseconds(_selected.end);
    final start = requested.clamp(0, latestStart).toInt();
    setState(() => _changingStructure = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StudioDockInsertCueDialog(
          isEditMode: widget.isEditMode,
          initialStart: _formatCueTime(start),
          initialEnd: _formatCueTime(start + 2000),
          onSubmit: (draft) async {
            final update = await widget.onInsertCue?.call(
              _cues.isEmpty ? null : _selectedId, draft);
            if (!mounted || update == null) return false;
            _acceptStructure(update);
            return true;
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _changingStructure = false);
    }
  }

  Future<void> _deleteCueSafely() async {
    if (widget.onDeleteCue == null || _cues.isEmpty ||
        _changingStructure || !await _confirmDraftBeforeLeaving() ||
        !mounted) return;
    final cueNumber = _selectedId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool>(dialog,
        confirm: true, cancel: false, child: AlertDialog(
        title: Text('Delete subtitle line #$cueNumber?'),
        content: const Text('This removes the selected line from the project. '
            'The change will be recorded in checkpoint history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('studio-confirm-delete'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete line'),
          ),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _changingStructure = true);
    try {
      final update = await widget.onDeleteCue?.call(cueNumber);
      if (!mounted) return;
      if (update != null) {
        _acceptStructure(update);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete this line. The project may have '
              'changed elsewhere. No line was removed.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _changingStructure = false);
    }
  }

  Future<void> _splitCueSafely() async {
    if (widget.onSplitCue == null || _cues.isEmpty || _changingStructure ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    final cue = _selected;
    setState(() => _changingStructure = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StudioDockSplitCueDialog(
          isEditMode: widget.isEditMode,
          cueNumber: cue.id,
          start: cue.start,
          end: cue.end,
          original: cue.original,
          edited: cue.edited,
          onSubmit: (draft) async {
            final update = await widget.onSplitCue?.call(cue.id, draft);
            if (!mounted || update == null) return false;
            _acceptStructure(update);
            return true;
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _changingStructure = false);
    }
  }

  Future<void> _mergeCueSafely() async {
    if (widget.onMergeCue == null || _cues.length < 2 || _changingStructure ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    final cueNumber = _selectedId;
    final index = _cues.indexWhere((cue) => cue.id == cueNumber);
    final withPrevious = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool?>(dialog,
        confirm: index < _cues.length - 1 ? false : true,
        cancel: null, child: AlertDialog(
        title: Text('Combine subtitle line #$cueNumber'),
        content: Text('Choose an adjacent line to combine. '
            '${widget.isEditMode ? 'Subtitle text' : 'Original and edited lines'}, '
            'timing, and review notes will be combined in one checkpoint.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            key: const ValueKey('studio-merge-previous'),
            onPressed: index > 0 ? () => Navigator.pop(dialog, true) : null,
            child: const Text('With previous'),
          ),
          FilledButton(
            key: const ValueKey('studio-merge-next'),
            onPressed: index < _cues.length - 1
                ? () => Navigator.pop(dialog, false) : null,
            child: const Text('With next'),
          ),
        ],
      )),
    );
    if (withPrevious == null || !mounted) return;
    setState(() => _changingStructure = true);
    try {
      final update = await widget.onMergeCue?.call(cueNumber, withPrevious);
      if (!mounted) return;
      if (update != null) {
        _acceptStructure(update);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not combine the lines. The project may have '
              'changed elsewhere. No lines were removed.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _changingStructure = false);
    }
  }

  Future<void> _runFileAction(
    Future<StudioDockFileResult> Function() action, {
    bool draftAlreadyHandled = false,
    bool projectDocument = false,
  }) async {
    if (_savingFile || _changingStructure) return;
    if (!draftAlreadyHandled && !await _confirmDraftBeforeLeaving()) return;
    if (!mounted) return;
    setState(() => _savingFile = true);
    StudioDockFileResult result;
    try {
      result = await action();
    } catch (_) {
      result = StudioDockFileResult.failed;
    } finally {
      if (mounted) setState(() => _savingFile = false);
    }
    if (!mounted || result == StudioDockFileResult.canceled) return;
    final feedback = switch (result) {
      StudioDockFileResult.saved => projectDocument
          ? 'Project and checkpoint history saved successfully.'
          : 'Subtitle file saved successfully.',
      StudioDockFileResult.needsLocation =>
        projectDocument
          ? 'No writable project file. Use Save Project As to choose a destination.'
          : 'No writable source file. Use Save As to choose a destination.',
      StudioDockFileResult.alreadyExists =>
        'Existing file was kept. No bytes were overwritten.',
      StudioDockFileResult.stale =>
        'The project changed while the dialog was open. '
        'Nothing was written; please retry.',
      StudioDockFileResult.savedButUnlinked =>
        'File saved, but its new location could not be linked to this project.',
      StudioDockFileResult.invalidEncoding =>
        'The selected encoding cannot represent this subtitle text. '
        'Choose a compatible encoding in Project Settings.',
      StudioDockFileResult.failed =>
        projectDocument
          ? 'Could not save the .msone project. Check the destination and retry.'
          : 'Could not save this subtitle file. Check the destination and retry.',
      StudioDockFileResult.canceled => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(feedback),
      backgroundColor: result == StudioDockFileResult.saved ? null
          : Theme.of(context).colorScheme.errorContainer,
    ));
  }

  Future<void> _saveFileSafely() async {
    if (widget.onSaveFile == null) return;
    await _runFileAction(() async {
      final result = await widget.onSaveFile!();
      if (result == StudioDockFileResult.needsLocation &&
          widget.onSaveAsFile != null) {
        // The user explicitly asked for Save, so a missing/revoked location
        // can open Save As, without reporting a canceled picker as success.
        return widget.onSaveAsFile!();
      }
      return result;
    });
  }

  Future<void> _saveAsFileSafely() async {
    if (widget.onSaveAsFile == null) return;
    await _runFileAction(widget.onSaveAsFile!);
  }

  Future<void> _saveProjectSafely() async {
    if (widget.onSaveProject == null) return;
    await _runFileAction(() async {
      final result = await widget.onSaveProject!();
      if (result == StudioDockFileResult.needsLocation &&
          widget.onSaveProjectAs != null) {
        return widget.onSaveProjectAs!();
      }
      return result;
    }, projectDocument: true);
  }

  Future<void> _saveProjectAsSafely() async {
    if (widget.onSaveProjectAs == null) return;
    await _runFileAction(
      widget.onSaveProjectAs!, projectDocument: true);
  }

  Future<void> _exportFileSafely() async {
    if (widget.onExportFile == null || _savingFile ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    // A scratch-created project has no source/translation pair to choose from.
    if (widget.isEditMode) {
      await _runFileAction(
        () => widget.onExportFile!(false), draftAlreadyHandled: true);
      return;
    }
    final originalOnly = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool?>(dialog,
        confirm: false, cancel: null, child: AlertDialog(
        title: const Text('Export subtitle file'),
        content: const Text('Choose which text to include in the SRT. '
            'Export does not change the current project or its save location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            key: const ValueKey('studio-export-original'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Original text'),
          ),
          FilledButton(
            key: const ValueKey('studio-export-edited'),
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Edited text'),
          ),
        ],
      )),
    );
    if (originalOnly == null || !mounted) return;
    await _runFileAction(
      () => widget.onExportFile!(originalOnly), draftAlreadyHandled: true);
  }


  Future<void> _selectCueAfterConfirmation(int id,
      {bool range = false, bool toggle = false}) async {
    if (_navigatingCue) return;
    _navigatingCue = true;
    try {
      if (await _prepareForCueNavigation() && mounted) {
        _applyCueSelection(id, range: range, toggle: toggle);
      }
    } finally {
      _navigatingCue = false;
    }
  }

  void _selectCue(int id, {bool range = false, bool toggle = false}) {
    if (_navigatingCue) return;
    if (id != _selectedId && _hasDirtyDraft) {
      unawaited(_selectCueAfterConfirmation(
          id, range: range, toggle: toggle));
      return;
    }
    _applyCueSelection(id, range: range, toggle: toggle);
  }

  void _applyCueSelection(int id, {bool range = false, bool toggle = false}) {
    final visibleIds = _visible.map((cue) => cue.id).toList();
    if (!visibleIds.contains(id)) return;
    setState(() {
      if (range) {
        final from = visibleIds.indexOf(_selectionAnchor);
        final to = visibleIds.indexOf(id);
        if (from < 0) {
          _selectedIds..clear()..add(id);
        } else {
          _selectedIds
            ..clear()
            ..addAll(visibleIds.sublist(math.min(from, to),
                math.max(from, to) + 1));
        }
      } else if (toggle) {
        if (!_selectedIds.remove(id)) _selectedIds.add(id);
        _selectionAnchor = id;
      } else {
        _selectedIds..clear()..add(id);
        _selectionAnchor = id;
      }
      _selectedId = id;
    });
    widget.onSelectedCueChanged?.call(id);
  }

  void _selectFromPointer(int id) {
    if (_rangeSelectionMode) {
      unawaited(_selectRangePointerSafely(id));
      _gridFocus.requestFocus();
      return;
    }
    final keyboard = HardwareKeyboard.instance;
    _selectCue(id,
        range: keyboard.isShiftPressed,
        toggle: keyboard.isControlPressed || keyboard.isMetaPressed);
    if (!widget.repeatEnabled && !keyboard.isShiftPressed &&
        !keyboard.isControlPressed && !keyboard.isMetaPressed) {
      final cue = _cues.where((item) => item.id == id).firstOrNull;
      if (cue != null) widget.playback?.seek(Duration(milliseconds: TimeValidator.timeStringToMilliseconds(cue.start)));
    }
    _gridFocus.requestFocus();
  }

  KeyEventResult _handleGridKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _isEditingText || _visible.isEmpty) {
      return KeyEventResult.ignored;
    }
    final change = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (change == 0) return KeyEventResult.ignored;
    final ids = _visible.map((cue) => cue.id).toList();
    final current = ids.indexOf(_selectedId);
    final target = ids[(current + change).clamp(0, ids.length - 1)];
    _selectCue(target, range: HardwareKeyboard.instance.isShiftPressed);
    return KeyEventResult.handled;
  }

  void _replaceCue(StudioDockCue updated) {
    if (widget.isLiveSession) return;
    final i = _cues.indexWhere((cue) => cue.id == updated.id);
    if (i < 0) return;
    setState(() => _cues[i] = updated);
  }

  Future<void> _selectRelativeWithPlayback(int change) async {
    if (_visible.isEmpty ||
        !await _confirmDraftBeforeLeaving() || !mounted ||
        _visible.isEmpty) return;
    final index = _visible.indexWhere((cue) => cue.id == _selectedId);
    final targetIndex = (index + change).clamp(0, _visible.length - 1);
    final cue = _visible[targetIndex];
    _applyCueSelection(cue.id);
    final playback = widget.playback;
    if (playback?.isAttached == true) {
      playback!.seek(Duration(milliseconds:
          TimeValidator.timeStringToMilliseconds(cue.start)));
    }
    _gridFocus.requestFocus();
  }

  Future<void> _showMarkedLinesFromShortcut(
      {ModalRoute<dynamic>? afterMenu}) async {
    if (afterMenu != null) await afterMenu.completed;
    if (!mounted) return;
    if (_cues.isEmpty || !await _confirmDraftBeforeLeaving() || !mounted) return;
    final wasShowingMarked = _section == 0 &&
        _reviewFilter == _StudioDockReviewFilter.marked;
    await _switchSection(0);
    if (!mounted || _section != 0) return;
    setState(() {
      _reviewFilter = wasShowingMarked
          ? _StudioDockReviewFilter.all
          : _StudioDockReviewFilter.marked;
      _query = '';
      _tableSearch.clear();
      final matches = _visible;
      if (matches.isNotEmpty && !matches.any((cue) => cue.id == _selectedId)) {
        _selectedId = matches.first.id;
        _selectionAnchor = _selectedId;
        _selectedIds..clear()..add(_selectedId);
      }
    });
  }

  Future<void> _openQualityReview({ModalRoute<dynamic>? afterMenu}) async {
    if (afterMenu != null) await afterMenu.completed;
    if (!mounted || _cues.isEmpty ||
        _applyingQualityFixes ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    final cues = [
      for (final cue in _cues)
        SubtitleQualityCue(
          id: cue.id, start: cue.start, end: cue.end, text: cue.edited,
        ),
    ];
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      // Quality review works with defaults even when preferences are absent.
    }
    if (!mounted) return;
    final savedPreferences = preferences;
    const presetKey = 'studio_quality_preset';
    final stored = savedPreferences?.getString(presetKey);
    final preset = SubtitleQualityPreset.values.firstWhere(
      (item) => item.name == stored,
      orElse: () => SubtitleQualityPreset.general,
    );
    final result = await showDialog<StudioDockQualityResult>(
      context: context,
      builder: (_) => StudioDockQualityDialog(
        cues: cues,
        initialPreset: preset,
        canApply: widget.onApplyQualityFixes != null,
        onPresetChanged: (chosen) {
          if (savedPreferences != null) {
            unawaited(savedPreferences
                .setString(presetKey, chosen.name)
                .then<void>((_) {}, onError: (Object _) {}));
          }
        },
      ),
    );
    if (!mounted || result == null) return;
    if (result is StudioDockQualityApply) {
      final apply = widget.onApplyQualityFixes;
      if (apply == null || result.fixes.isEmpty) return;
      setState(() => _applyingQualityFixes = true);
      try {
        final update = await apply(result.fixes);
        if (!mounted) return;
        if (update == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Quality fixes were not applied. '
                'Refresh the project and review the suggestions again.'),
          ));
        } else {
          _acceptStructure(update);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Applied ${result.fixes.length} quality fixes.'),
          ));
        }
      } finally {
        if (mounted) setState(() => _applyingQualityFixes = false);
      }
      return;
    }
    if (result is! StudioDockQualityNavigate ||
        !_cues.any((cue) => cue.id == result.cueId)) return;
    await _switchSection(0);
    if (!mounted || _section != 0) return;
    setState(() {
      _reviewFilter = _StudioDockReviewFilter.all;
      _query = '';
      _tableSearch.clear();
    });
    _selectCue(result.cueId);
    _gridFocus.requestFocus();
  }

  Future<void> _changeReviewFilterSafely(
      _StudioDockReviewFilter filter) async {
    if (filter == _reviewFilter ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    setState(() => _reviewFilter = filter);
  }

  Future<void> _openReviewNotesForHotkey() async {
    if (_cues.isEmpty) return;
    await _openInspectorTab(2);
    if (mounted && _inspectorTab == 2 && !_noteMarked &&
        widget.onApplyCueNotes != null) {
      // Mobile Ctrl+Shift+M marks when the note is saved. A desktop draft
      // should likewise only persist the mark when the user applies it.
      setState(() {
        _draftNotesCueId = _selectedId;
        _draftMarked = true;
      });
    }
  }

  void _selectRelative(int change) {
    if (_visible.isEmpty) return;
    final index = _visible.indexWhere((cue) => cue.id == _selectedId);
    final target = (index + change).clamp(0, _visible.length - 1).toInt();
    _selectCue(_visible[target].id);
    _gridFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_cues.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(widget.projectTitle ?? 'Studio Dock'),
          actions: [
            if (widget.onRestoreHistory != null) ...[
              IconButton(
                key: const ValueKey('studio-empty-undo'),
                tooltip: 'Undo last edit',
                icon: const Icon(Icons.undo),
                onPressed: _historyNavigationBlocked ||
                        _currentHistoryPoint?.parentCheckpointId == null
                    ? null : () => unawaited(_undoHistory()),
              ),
              IconButton(
                key: const ValueKey('studio-empty-redo'),
                tooltip: 'Redo edit',
                icon: const Icon(Icons.redo),
                onPressed: _historyNavigationBlocked ||
                        (_currentHistoryPoint?.childCheckpointIds.isEmpty ?? true)
                    ? null : () => unawaited(_redoHistory()),
              ),
            ],
            if (widget.onInsertCue != null)
              IconButton(
                key: const ValueKey('studio-empty-insert-cue'),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Insert first subtitle line',
                onPressed: _changingStructure ? null :
                    () => unawaited(_addCueSafely()),
              ),
            if (widget.onSubmitToMsone != null)
              IconButton(
                key: const ValueKey('studio-empty-submit-msone'),
                icon: const Icon(Icons.cloud_upload_outlined),
                tooltip: 'Submit to MSone',
                onPressed: _openingMsoneSubmission ? null :
                    () => unawaited(_submitMsoneSafely()),
              ),
            if (widget.onOpenProjectSettings != null)
              IconButton(
                key: const ValueKey('studio-empty-project-settings'),
                icon: const Icon(Icons.settings_applications_outlined),
                tooltip: 'Project Settings',
                onPressed: _openingProjectSettings ? null :
                    () => unawaited(_openProjectSettingsSafely()),
              ),
            if (widget.onChooseProject != null)
              IconButton(
                key: const ValueKey('studio-dock-switch-project'),
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Open or create another project',
                onPressed: widget.onChooseProject,
              ),
          ],
        ),
        body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subtitles_outlined, size: 58, color: _muted),
            const SizedBox(height: 12),
            const Text('This project has no subtitle lines yet.'),
            SizedBox(height: 8),
            Text(widget.onInsertCue != null
                ? 'Insert the first line or import a subtitle file.'
                : 'Line insertion is unavailable in this preview.',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
            if (widget.onInsertCue != null)
              FilledButton.icon(
                key: const ValueKey('studio-empty-create-cue'),
                onPressed: _changingStructure ? null :
                    () => unawaited(_addCueSafely()),
                icon: const Icon(Icons.add),
                label: const Text('Insert first line'),
              ),
            if (widget.onInsertCue != null) const SizedBox(height: 10),
            if (widget.onChooseProject != null)
              OutlinedButton.icon(
                onPressed: widget.onChooseProject,
                icon: const Icon(Icons.folder_open),
                label: const Text('Projects and import'),
              ),
          ],
        )),
      );
    }
    return PopScope(
      canPop: !_hasDirtyDraft && !_sourceDirty && !_savingDraft &&
          !_changingStructure && !_savingFile && !_sourceSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_savingDraft) {
          unawaited(_confirmDraftBeforeLeaving().then((allowed) {
            if (allowed && mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }));
        }
      },
      child: CallbackShortcuts(
      bindings: {
        // Undo/Redo stay in Flutter's focused shortcut tree, so the inner
        // EditableText retains its own native text-draft Undo/Redo. Other
        // desktop actions continue through MSoneHotkeyManager.
        // Clipboard shortcuts stay in Flutter's focus tree: a native in-app
        // Ctrl+C registration would consume Copy before EditableText receives
        // it. Only the focused subtitle grid copies selected cues.
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            () { if (!_isEditingText) unawaited(_copySelectedSubtitleText()); },
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            () { if (!_isEditingText) unawaited(_copySelectedSubtitleText()); },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showCommandPalette,
        if (widget.onRestoreHistory != null) ...{
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              () => unawaited(_undoHistory()),
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
              () => unawaited(_undoHistory()),
          const SingleActivator(LogicalKeyboardKey.keyZ,
              control: true, shift: true):
              () => unawaited(_redoHistory()),
          const SingleActivator(LogicalKeyboardKey.keyZ,
              meta: true, shift: true):
              () => unawaited(_redoHistory()),
          const SingleActivator(LogicalKeyboardKey.keyY, control: true):
              () => unawaited(_redoHistory()),
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: LayoutBuilder(builder: (context, bounds) {
            final wide = bounds.maxWidth >= 1600;
            final explorerVisible = wide && _explorerOpen && _section == 0;
            final inspectorVisible = bounds.maxWidth >= 1250 &&
                _inspectorOpen && _section == 0;
            final explorerOverlay = !wide && _explorerOverlayOpen &&
                _section == 0;
            final inspectorOverlay = bounds.maxWidth < 1250 &&
                _inspectorOverlayOpen && _section == 0;
            return Column(children: [
              _menuBar(),
              _topBar(),
              Expanded(child: Stack(children: [
                Row(children: [
                  _navigationRail(),
                  if (explorerVisible)
                    SizedBox(width: _sidebarWidth, child: _activeSidebar()),
                  if (explorerVisible)
                    _dragHandle(onDelta: (dx) => setState(() =>
                        _sidebarWidth = (_sidebarWidth + dx)
                            .clamp(200.0, 340.0).toDouble())),
                  Expanded(
                    key: const ValueKey('studio-dock-center'),
                    child: IndexedStack(
                    index: _section == 0 ? 0 : 1,
                    children: [
                      _editingWorkspace(),
                      _secondarySection(),
                    ],
                  )),
                  if (inspectorVisible)
                    _dragHandle(onDelta: (dx) => setState(() =>
                        _inspectorWidth = (_inspectorWidth - dx)
                            .clamp(280.0, 440.0).toDouble())),
                  if (inspectorVisible)
                    SizedBox(width: _inspectorWidth, child: _inspector()),
                ]),
                if (explorerOverlay)
                  Positioned(
                    top: 0, bottom: 0, left: 61,
                    width: _sidebarWidth,
                    child: Material(elevation: 12, child: _activeSidebar()),
                  ),
                if (inspectorOverlay)
                  Positioned(
                    top: 0, bottom: 0, right: 0,
                    width: _inspectorWidth,
                    child: Material(elevation: 12, child: _inspector()),
                  ),
              ])),
              _statusBar(),
            ]);
          }),
        ),
      ),
      ),
    );
  }

  Widget _menuBar() => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        if (widget.onSaveFile != null || widget.onSaveProject != null ||
            widget.onOpenProjectSettings != null)
          PopupMenuButton<_StudioDockFileMenuAction>(
            key: const ValueKey('studio-file-menu'),
            tooltip: 'File actions',
            enabled: !_savingFile && !_changingStructure &&
                !_openingProjectSettings,
            onSelected: (action) {
              switch (action) {
                case _StudioDockFileMenuAction.save:
                  unawaited(_saveFileSafely());
                case _StudioDockFileMenuAction.saveAs:
                  unawaited(_saveAsFileSafely());
                case _StudioDockFileMenuAction.export:
                  unawaited(_exportFileSafely());
                case _StudioDockFileMenuAction.saveProject:
                  unawaited(_saveProjectSafely());
                case _StudioDockFileMenuAction.saveProjectAs:
                  unawaited(_saveProjectAsSafely());
                case _StudioDockFileMenuAction.projectSettings:
                  final menuRoute = _projectSettingsMenuRoute;
                  _projectSettingsMenuRoute = null;
                  unawaited(_openProjectSettingsSafely(afterMenu: menuRoute));
              }
            },
            itemBuilder: (_) => [
              if (widget.onSaveFile != null) ...const [
                PopupMenuItem(height: 34, value: _StudioDockFileMenuAction.save,
                  child: Text('Save subtitle file')),
                PopupMenuItem(height: 34, value: _StudioDockFileMenuAction.saveAs,
                  child: Text('Save As…')),
                PopupMenuItem(height: 34, value: _StudioDockFileMenuAction.export,
                  child: Text('Export SRT…')),
              ],
              if (widget.onSaveProject != null) ...const [
                PopupMenuDivider(),
                PopupMenuItem(height: 34, value: _StudioDockFileMenuAction.saveProject,
                  child: Text('Save project (.msone)')),
                PopupMenuItem(height: 34, value: _StudioDockFileMenuAction.saveProjectAs,
                  child: Text('Save project as…')),
              ],
              if (widget.onOpenProjectSettings != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem(height: 34,
                  value: _StudioDockFileMenuAction.projectSettings,
                  child: Builder(builder: (popupContext) {
                    _projectSettingsMenuRoute = ModalRoute.of(popupContext);
                    return const Text('Project Settings');
                  }),
                ),
              ],
            ],
            child: const Padding(
              padding: EdgeInsets.only(right: 23),
              child: Text('File', style: TextStyle(fontSize: 14)),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(right: 23),
            child: Text('File', style: TextStyle(fontSize: 14)),
          ),
        _desktopMenu('Edit', const ValueKey('studio-edit-menu'), [
          PopupMenuItem(height: 34, value: _StudioDockMenuAction.undo,
              enabled: !_historyNavigationBlocked &&
                  _currentHistoryPoint?.parentCheckpointId != null,
              child: const Text('Undo')),
          PopupMenuItem(height: 34, value: _StudioDockMenuAction.redo,
              enabled: !_historyNavigationBlocked &&
                  (_currentHistoryPoint?.childCheckpointIds.isNotEmpty ?? false),
              child: const Text('Redo')),
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.find,
              child: Text('Find & Replace')),
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.selectAll,
              child: Text('Select all visible subtitles')),
          PopupMenuItem(height: 34, value: _StudioDockMenuAction.goToLine,
              enabled: _cues.isNotEmpty,
              child: const Text('Go to Line…')),
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.selectByIndex,
              child: Text('Select subtitles by index…')),
          PopupMenuItem(height: 34, value: _StudioDockMenuAction.rangeSelection,
              child: Text(_rangeSelectionMode
                  ? 'Cancel range selection' : 'Select subtitle range')),
          PopupMenuItem(height: 34, value: _StudioDockMenuAction.copySelected,
              enabled: _selectedIds.isNotEmpty,
              child: const Text('Copy selected subtitles')),
          if (!widget.isEditMode && widget.onApplyCueText != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.pasteOriginal,
                enabled: _cues.isNotEmpty && !_savingDraft,
                child: const Text('Paste original text (Alt+V)')),
        ]),
        _desktopMenu('Subtitle', const ValueKey('studio-subtitle-menu'), [
          if (widget.onInsertCue != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.addCue,
                child: Text('Add subtitle')),
          if (widget.onDeleteCue != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.deleteCue,
                child: Text('Delete subtitle')),
          if (widget.onDeleteSelectedCues != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.deleteSelected,
                enabled: _selectedIds.isNotEmpty && !_runningSelectedBatch,
                child: Text('Delete selected subtitles (${_selectedIds.length})')),
          if (widget.onSplitCue != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.splitCue,
                child: Text('Split subtitle')),
          if (widget.onMergeCue != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.mergeCue,
                child: Text('Combine subtitles')),
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.notes,
              child: Text('Review notes')),
          if (widget.onApplyCueText != null) ...[
            const PopupMenuDivider(),
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.boldFormat,
                enabled: _cues.isNotEmpty && !_savingDraft,
                child: const Text('Bold (Ctrl+B)')),
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.italicFormat,
                enabled: _cues.isNotEmpty && !_savingDraft,
                child: const Text('Italic (Ctrl+I)')),
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.colorPicker,
                enabled: _cues.isNotEmpty && !_savingDraft,
                child: const Text('Text color (Alt+C)…')),
          ],
        ]),
        _desktopMenu('Timing', const ValueKey('studio-timing-menu'), [
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.timing,
              child: Text('Edit start and end time')),
          if (widget.onSyncAnchoredCues != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.syncSubtitles,
                child: Text('Sync subtitles…')),
          if (widget.onShiftAllCues != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.shiftTools,
                child: Text('Shift subtitle timecodes')),
          if (widget.onShiftSelectedCues != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.shiftSelected,
                enabled: _selectedIds.isNotEmpty && !_runningSelectedBatch,
                child: Text('Shift selected subtitles (${_selectedIds.length})')),
        ]),
        _desktopMenu('Tools', const ValueKey('studio-tools-menu'), [
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.find,
              child: Text('Find & Replace')),
          PopupMenuItem(height: 34, value: _StudioDockMenuAction.qualityCheck,
              enabled: _cues.isNotEmpty,
              child: Builder(builder: (popupContext) {
                _qualityMenuRoute = ModalRoute.of(popupContext);
                return const Text('Check subtitle quality…');
              })),
          if (widget.onApplyCueText != null) ...[
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.msoneDictionary,
              enabled: _cues.isNotEmpty && !_savingDraft,
              child: Builder(builder: (popupContext) {
                _dictionaryMenuRoute = ModalRoute.of(popupContext);
                return const Text('MSone Dictionary (Alt+M)…');
              })),
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.olamDictionary,
              enabled: _cues.isNotEmpty && !_savingDraft,
              child: Builder(builder: (popupContext) {
                _dictionaryMenuRoute = ModalRoute.of(popupContext);
                return const Text('Olam Dictionary (Alt+O)…');
              })),
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.urbanDictionary,
              enabled: _cues.isNotEmpty && !_savingDraft,
              child: Builder(builder: (popupContext) {
                _dictionaryMenuRoute = ModalRoute.of(popupContext);
                return const Text('Urban Dictionary (Alt+U)…');
              })),
          ],
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.showTools,
              child: Text('Subtitle tools')),
          PopupMenuItem(height: 34, value: _StudioDockMenuAction.showMarkedLines,
            enabled: _cues.isNotEmpty,
            child: Builder(builder: (popupContext) {
              _markedLinesMenuRoute = ModalRoute.of(popupContext);
              return const Text('Show marked lines');
            })),
          if (widget.onRemoveHearingImpaired != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.removeHearingImpaired,
              enabled: !_openingHearingCleanup && _cues.isNotEmpty,
              child: Builder(builder: (popupContext) {
                _hearingMenuRoute = ModalRoute.of(popupContext);
                return const Text('Remove Hearing Impaired…');
              })),
          if (widget.onImportComments != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.importComments,
              enabled: !_openingCommentImport && _cues.isNotEmpty,
              child: Builder(builder: (popupContext) {
                _commentsMenuRoute = ModalRoute.of(popupContext);
                return const Text('Import Comments (.msone)…');
              })),
          if (widget.onLoadSecondarySubtitles != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.loadSecondary,
              child: Builder(builder: (popupContext) {
                _secondaryMenuRoute = ModalRoute.of(popupContext);
                return const Text('Load secondary subtitles');
              })),
          if (widget.onToggleSecondarySubtitles != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.toggleSecondary,
              child: Text(widget.showSecondarySubtitles
                  ? 'Hide secondary subtitles'
                  : 'Show secondary subtitles')),
          if (widget.onLoadSourceView != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.sourceView,
                child: Text('Source View')),
          if (widget.onLoadHistory != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.history,
                child: Text('Edit history')),
          if (widget.onInsertMsoneBanners != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.insertMsoneBanners,
              enabled: !_openingMsoneTools && _cues.isNotEmpty,
              child: Builder(builder: (popupContext) {
                _msoneBannerMenuRoute = ModalRoute.of(popupContext);
                return const Text('Insert MSone Banners…');
              })),
          if (widget.onNormalizeMalayalam != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.normalizeMalayalam,
              enabled: !_openingMsoneTools && _cues.isNotEmpty,
              child: Builder(builder: (popupContext) {
                _msoneNormalizeMenuRoute = ModalRoute.of(popupContext);
                return const Text('Malayalam Normalize…');
              })),
          if (widget.onSubmitToMsone != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.submitMsone,
              enabled: !_openingMsoneSubmission,
              child: Builder(builder: (popupContext) {
                _msoneMenuRoute = ModalRoute.of(popupContext);
                return const Text('Submit to MSone');
              })),
        ]),
        _desktopMenu('View', const ValueKey('studio-view-menu'), [
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.explorer,
              child: Text('Toggle project explorer')),
          const PopupMenuItem(height: 34, value: _StudioDockMenuAction.inspector,
              child: Text('Toggle line inspector')),
          if (widget.onSaveEditPreference != null) ...[
            const PopupMenuDivider(),
            if (!widget.isEditMode) ...[
              PopupMenuItem(height: 34,
                value: _StudioDockMenuAction.showOriginalLine,
                enabled: !_updatingEditPreference,
                child: Builder(builder: (popupContext) {
                  _editPreferenceMenuRoute = ModalRoute.of(popupContext);
                  return Row(children: [
                    Icon(widget.showOriginalLine
                        ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 18),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Show Original Line',
                        overflow: TextOverflow.ellipsis)),
                  ]);
                }),
              ),
              if (widget.showOriginalLine)
                CheckedPopupMenuItem(height: 34,
                  value: _StudioDockMenuAction.autoSaveWithNavigation,
                  enabled: !_updatingEditPreference,
                  checked: widget.autoSaveWithNavigation,
                  child: const Text('Auto-save with navigation'),
                ),
            ],
            CheckedPopupMenuItem(height: 34,
              value: _StudioDockMenuAction.showOriginalTextField,
              enabled: !_updatingEditPreference,
              checked: widget.showOriginalTextField,
              child: const Text('Show Original Text Field'),
            ),
          ],
          CheckedPopupMenuItem(height: 34,
            value: _StudioDockMenuAction.formattedView,
            checked: _formattedView,
            child: const Text('Formatted View'),
          ),
          if (widget.onToggleFullscreen != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.toggleFullscreen,
                enabled: widget.videoSurface != null,
                child: const Text('Toggle video fullscreen')),
          if (widget.onUnloadVideo != null && widget.videoSurface != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.unloadVideo,
                enabled: !_unloadingVideo && !_savingFile,
                child: Builder(builder: (popupContext) {
                  _unloadVideoMenuRoute = ModalRoute.of(popupContext);
                  return const Text('Unload video…');
                })),
          if (widget.onToggleRepeat != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.repeatCurrent,
                enabled: widget.videoSurface != null && _cues.isNotEmpty,
                child: Text(widget.repeatEnabled
                    ? 'Stop subtitle repeat'
                    : 'Repeat selected subtitle')),
          if (widget.onOpenRepeatRange != null)
            PopupMenuItem(height: 34, value: _StudioDockMenuAction.repeatRange,
                enabled: widget.videoSurface != null && _cues.isNotEmpty,
                child: const Text('Repeat subtitle range…')),
          if (widget.videoSurface != null &&
              widget.onTogglePlayback != null && widget.playback != null)
            PopupMenuItem(height: 34,
              value: _StudioDockMenuAction.floatingPlayback,
              child: Text(_floatingPlaybackVisible
                  ? 'Hide floating playback button'
                  : 'Show floating playback button'),
            ),
          if (widget.onOpenAppSettings != null)
            const PopupMenuItem(height: 34, value: _StudioDockMenuAction.settings,
                child: Text('Settings')),
        ]),
        if (widget.onOpenHelp != null)
          TextButton(
            key: const ValueKey('studio-help-menu'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(right: 23),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => unawaited(widget.onOpenHelp!()),
            child: Text('Help', style: TextStyle(
              fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
          ),
      ]),
    ),
  );

  Widget _desktopMenu(String title, Key key,
      List<PopupMenuEntry<_StudioDockMenuAction>> items) =>
      PopupMenuButton<_StudioDockMenuAction>(
        key: key,
        tooltip: '$title menu',
        onSelected: _handleDesktopMenuAction,
        itemBuilder: (_) => items,
        child: Padding(
          padding: const EdgeInsets.only(right: 23),
          child: Text(title, style: const TextStyle(fontSize: 14)),
        ),
      );

  void _handleDesktopMenuAction(_StudioDockMenuAction action) {
    switch (action) {
      case _StudioDockMenuAction.undo:
        unawaited(_undoHistory());
      case _StudioDockMenuAction.redo:
        unawaited(_redoHistory());
      case _StudioDockMenuAction.find:
        unawaited(_openFind());
      case _StudioDockMenuAction.selectAll:
        _selectAllVisibleCues();
      case _StudioDockMenuAction.goToLine:
        unawaited(_goToLineSafely());
      case _StudioDockMenuAction.selectByIndex:
        unawaited(_selectByIndexSafely());
      case _StudioDockMenuAction.rangeSelection:
        _toggleRangeSelectionMode();
      case _StudioDockMenuAction.copySelected:
        unawaited(_copySelectedSubtitleText());
      case _StudioDockMenuAction.pasteOriginal:
        _pasteOriginalDraft();
      case _StudioDockMenuAction.boldFormat:
        _formatCueShortcut('b');
      case _StudioDockMenuAction.italicFormat:
        _formatCueShortcut('i');
      case _StudioDockMenuAction.colorPicker:
        unawaited(_pickStyleColor());
      case _StudioDockMenuAction.msoneDictionary:
      case _StudioDockMenuAction.olamDictionary:
      case _StudioDockMenuAction.urbanDictionary:
        final route = _dictionaryMenuRoute;
        _dictionaryMenuRoute = null;
        final hotkeyAction = switch (action) {
          _StudioDockMenuAction.msoneDictionary => HotkeyAction.msoneDictionary,
          _StudioDockMenuAction.olamDictionary => HotkeyAction.olamDictionary,
          _ => HotkeyAction.urbanDictionary,
        };
        unawaited(_openDictionary(hotkeyAction, afterMenu: route));
      case _StudioDockMenuAction.addCue:
        unawaited(_addCueSafely());
      case _StudioDockMenuAction.deleteCue:
        unawaited(_deleteCueSafely());
      case _StudioDockMenuAction.deleteSelected:
        unawaited(_deleteSelectedSafely());
      case _StudioDockMenuAction.splitCue:
        unawaited(_splitCueSafely());
      case _StudioDockMenuAction.mergeCue:
        unawaited(_mergeCueSafely());
      case _StudioDockMenuAction.notes:
        unawaited(_openInspectorTab(2));
      case _StudioDockMenuAction.timing:
        unawaited(_openInspectorTab(0));
      case _StudioDockMenuAction.shiftTools:
      case _StudioDockMenuAction.syncSubtitles:
      case _StudioDockMenuAction.showTools:
        unawaited(_switchSection(3));
      case _StudioDockMenuAction.shiftSelected:
        unawaited(_shiftSelectedSafely());
      case _StudioDockMenuAction.sourceView:
        unawaited(_switchSection(5));
      case _StudioDockMenuAction.showMarkedLines:
        final menuRoute = _markedLinesMenuRoute;
        _markedLinesMenuRoute = null;
        unawaited(_showMarkedLinesFromShortcut(afterMenu: menuRoute));
      case _StudioDockMenuAction.qualityCheck:
        final menuRoute = _qualityMenuRoute;
        _qualityMenuRoute = null;
        unawaited(_openQualityReview(afterMenu: menuRoute));
      case _StudioDockMenuAction.history:
        unawaited(_switchSection(1));
      case _StudioDockMenuAction.removeHearingImpaired:
        final route = _hearingMenuRoute;
        _hearingMenuRoute = null;
        unawaited(_removeHearingSafely(afterMenu: route));
      case _StudioDockMenuAction.importComments:
        final menuRoute = _commentsMenuRoute;
        _commentsMenuRoute = null;
        unawaited(_importCommentsSafely(afterMenu: menuRoute));
      case _StudioDockMenuAction.insertMsoneBanners:
        final route = _msoneBannerMenuRoute;
        _msoneBannerMenuRoute = null;
        unawaited(_openMsoneToolSafely(widget.onInsertMsoneBanners,
          name: 'MSone banner configuration', afterMenu: route));
      case _StudioDockMenuAction.normalizeMalayalam:
        final route = _msoneNormalizeMenuRoute;
        _msoneNormalizeMenuRoute = null;
        unawaited(_openMsoneToolSafely(widget.onNormalizeMalayalam,
          name: 'Malayalam normalization', afterMenu: route));
      case _StudioDockMenuAction.submitMsone:
        final menuRoute = _msoneMenuRoute;
        _msoneMenuRoute = null;
        unawaited(_submitMsoneSafely(afterMenu: menuRoute));
      case _StudioDockMenuAction.loadSecondary:
        final menuRoute = _secondaryMenuRoute;
        _secondaryMenuRoute = null;
        unawaited(_loadSecondarySafely(afterMenu: menuRoute));
      case _StudioDockMenuAction.toggleSecondary:
        widget.onToggleSecondarySubtitles?.call();
      case _StudioDockMenuAction.explorer:
        _toggleExplorerPanel();
      case _StudioDockMenuAction.inspector:
        _toggleInspectorPanel();
      case _StudioDockMenuAction.floatingPlayback:
        if (widget.videoSurface != null && widget.playback != null &&
            widget.onTogglePlayback != null) {
          setState(() => _floatingPlaybackVisible = !_floatingPlaybackVisible);
        }
      case _StudioDockMenuAction.toggleFullscreen:
        if (widget.videoSurface != null) widget.onToggleFullscreen?.call();
      case _StudioDockMenuAction.unloadVideo:
        final route = _unloadVideoMenuRoute;
        _unloadVideoMenuRoute = null;
        unawaited(_unloadVideoSafely(afterMenu: route));
      case _StudioDockMenuAction.showOriginalLine:
        final route = _editPreferenceMenuRoute;
        _editPreferenceMenuRoute = null;
        unawaited(_setEditPreference(
            StudioDockEditPreference.showOriginalLine, afterMenu: route));
      case _StudioDockMenuAction.autoSaveWithNavigation:
        unawaited(_setEditPreference(
            StudioDockEditPreference.autoSaveWithNavigation));
      case _StudioDockMenuAction.showOriginalTextField:
        unawaited(_setEditPreference(
            StudioDockEditPreference.showOriginalTextField));
      case _StudioDockMenuAction.formattedView:
        setState(() => _formattedView = !_formattedView);
      case _StudioDockMenuAction.repeatCurrent:
        if (widget.videoSurface != null && _cues.isNotEmpty) {
          widget.onToggleRepeat?.call();
        }
      case _StudioDockMenuAction.repeatRange:
        if (widget.videoSurface != null && _cues.isNotEmpty) {
          widget.onOpenRepeatRange?.call();
        }
      case _StudioDockMenuAction.settings:
        unawaited(_switchSection(4));
      case _StudioDockMenuAction.help:
        final open = widget.onOpenHelp;
        if (open != null) unawaited(open());
    }
  }

  void _selectAllVisibleCues() {
    if (_visible.isEmpty) return;
    setState(() => _selectedIds
      ..clear()
      ..addAll(_visible.map((cue) => cue.id)));
  }

  Future<void> _goToLineSafely() async {
    if (_cues.isEmpty || !await _confirmDraftBeforeLeaving() || !mounted) {
      return;
    }
    // Applying a dirty Source View may replace the entire cue list.
    if (_cues.isEmpty) return;
    final initialIndex = _cues.indexWhere((cue) => cue.id == _selectedId);
    final lineNumber = await showDialog<int>(
      context: context,
      builder: (_) => StudioDockGoToLineDialog(
        lineCount: _cues.length,
        initialLine: initialIndex < 0 ? 1 : initialIndex + 1,
      ),
    );
    if (!mounted || lineNumber == null ||
        lineNumber < 1 || lineNumber > _cues.length) return;

    final cue = _cues[lineNumber - 1];
    setState(() {
      // Mobile Go to Line indexes the full subtitle document. Reveal rows
      // hidden by the desktop-only review filter or search before scrolling.
      _section = 0;
      _reviewFilter = _StudioDockReviewFilter.all;
      _query = '';
      _tableSearch.clear();
      _selectedId = cue.id;
      _selectionAnchor = cue.id;
      _selectedIds..clear()..add(cue.id);
      _rangeSelectionMode = false;
      _rangeStartCueId = null;
    });
    widget.onSelectedCueChanged?.call(cue.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cueScroll.hasClients) return;
      final visibleIndex = _visible.indexWhere((item) => item.id == cue.id);
      if (visibleIndex < 0) return;
      final target = (visibleIndex * _cueRowHeight + _cueRowHeight / 2 -
              _cueScroll.position.viewportDimension / 2)
          .clamp(0.0, _cueScroll.position.maxScrollExtent).toDouble();
      _cueScroll.jumpTo(target);
    });

    // Match mobile's +50ms margin so the selected subtitle is active at the
    // destination. No player exists until the host attaches its shared link.
    if (!widget.repeatEnabled && (widget.playback?.isAttached ?? false)) {
      final startMs = TimeValidator.timeStringToMilliseconds(cue.start);
      widget.playback!.seek(Duration(milliseconds: startMs + 50));
    }
  }

  void _applyIndexRange(int start, int end) {
    if (start < 1 || end < start || end > _cues.length) return;
    setState(() {
      // The mobile index dialog selects underlying project rows, not only
      // those left visible by a search or review filter.
      _reviewFilter = _StudioDockReviewFilter.all;
      _query = '';
      _tableSearch.clear();
      _selectedIds
        ..clear()
        ..addAll(_cues.sublist(start - 1, end).map((cue) => cue.id));
      _selectedId = _cues[end - 1].id;
      _selectionAnchor = _cues[start - 1].id;
      _rangeSelectionMode = false;
      _rangeStartCueId = null;
    });
    widget.onSelectedCueChanged?.call(_selectedId);
  }

  Future<void> _selectByIndexSafely() async {
    if (_cues.isEmpty || !await _confirmDraftBeforeLeaving() || !mounted) return;
    var firstText = '1';
    var lastText = '${_cues.length}';
    String? error;
    var submitted = false;
    final chosen = await showDialog<List<int>>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (dialog, refresh) {
        void submit() {
          if (submitted) return;
          final start = int.tryParse(firstText.trim());
          final end = int.tryParse(lastText.trim());
          if (start == null || end == null || start < 1 ||
              end < start || end > _cues.length) {
            refresh(() => error =
                'Enter indices between 1 and ${_cues.length} in order.');
            return;
          }
          submitted = true;
          Navigator.pop(dialog, <int>[start, end]);
        }
        return _modalActions(
          onConfirm: submit,
          onCancel: () => Navigator.pop(dialog),
          child: AlertDialog(
        title: const Text('Select subtitles by index'),
        content: SizedBox(width: 390, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select an inclusive range from 1 to ${_cues.length}.'),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('studio-range-start'),
              initialValue: firstText,
              onChanged: (value) => firstText = value,
              onFieldSubmitted: (_) => submit(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'First line', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey('studio-range-end'),
              initialValue: lastText,
              onChanged: (value) => lastText = value,
              onFieldSubmitted: (_) => submit(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Last line', border: OutlineInputBorder()),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(error!, style: TextStyle(
                color: Theme.of(dialog).colorScheme.error)),
            ),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('studio-range-confirm'),
            onPressed: submit,
            child: const Text('Select range'),
          ),
        ],
      ));
      }),
    );
    if (chosen == null || !mounted) return;
    _applyIndexRange(chosen[0], chosen[1]);
  }

  void _toggleRangeSelectionMode() {
    setState(() {
      _rangeSelectionMode = !_rangeSelectionMode;
      _rangeStartCueId = null;
    });
    if (_rangeSelectionMode) {
      // Tools replaces the subtitle grid; the two range-endpoint taps must
      // happen in the editor where subtitle rows are visible.
      if (_section != 0) unawaited(_switchSection(0));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select the first subtitle, then the last subtitle in the range.'),
      ));
    }
  }

  Future<void> _selectRangePointerSafely(int cueId) async {
    if (!await _confirmDraftBeforeLeaving() || !mounted ||
        !_rangeSelectionMode) return;
    if (_rangeStartCueId == null) {
      setState(() {
        _rangeStartCueId = cueId;
        _selectedId = cueId;
        _selectedIds..clear()..add(cueId);
      });
      widget.onSelectedCueChanged?.call(cueId);
      return;
    }
    final first = _cues.indexWhere((cue) => cue.id == _rangeStartCueId);
    final last = _cues.indexWhere((cue) => cue.id == cueId);
    if (first < 0 || last < 0) return;
    _applyIndexRange(math.min(first, last) + 1, math.max(first, last) + 1);
  }

  Future<void> _shiftSelectedSafely() async {
    final apply = widget.onShiftSelectedCues;
    if (apply == null || _selectedIds.isEmpty || _runningSelectedBatch ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    final selected = [for (final cue in _cues)
      if (_selectedIds.contains(cue.id)) cue];
    if (selected.isEmpty) return;
    final cueNumbers = selected.map((cue) => cue.id).toList();
    var firstText = selected.first.start;
    var lastText = selected.last.end;
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (dialog, refresh) {
        Future<void> submit() async {
          if (saving) return;
          final start = firstText.trim();
          final end = lastText.trim();
          final validation = StudioDockTimingEditService.validate(start, end);
          if (validation != null) {
            refresh(() => error = validation);
            return;
          }
          refresh(() { saving = true; error = null; });
          StudioDockCueUpdate? updated;
          try {
            updated = await apply(cueNumbers, start, end, _selectedId);
          } catch (_) {
            updated = null;
          }
          if (!mounted || !dialog.mounted) return;
          if (updated == null) {
            refresh(() {
              saving = false;
              error = 'The time shift could not be saved. The project may '
                  'have changed or a line would exceed the SRT time range.';
            });
            return;
          }
          Navigator.pop(dialog);
          _acceptStructure(updated);
        }
        return _modalActions(
          onConfirm: () { if (!saving) unawaited(submit()); },
          onCancel: () { if (!saving) Navigator.pop(dialog); },
          child: PopScope(
        canPop: !saving,
        child: AlertDialog(
          title: Text('Shift ${selected.length} selected subtitles'),
          content: SizedBox(width: 420, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set a new start for the first selected line and an end '
                  'anchor for the last. Relative starts scale; durations stay unchanged.'),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('studio-selected-start'),
                initialValue: firstText,
                onChanged: (value) => firstText = value,
                onFieldSubmitted: (_) { if (!saving) unawaited(submit()); },
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'First selected start', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('studio-selected-end'),
                initialValue: lastText,
                onChanged: (value) => lastText = value,
                onFieldSubmitted: (_) { if (!saving) unawaited(submit()); },
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Last selected end anchor', border: OutlineInputBorder()),
              ),
              if (error != null) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error!, style: TextStyle(
                  color: Theme.of(dialog).colorScheme.error)),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialog),
                child: const Text('Cancel')),
            FilledButton(
              key: const ValueKey('studio-selected-shift-apply'),
              onPressed: saving ? null : () => unawaited(submit()),
              child: Text(saving ? 'Applying…' : 'Apply selected shift'),
            ),
          ],
        ),
      ));
      }),
    );
  }

  Future<void> _deleteSelectedSafely() async {
    final remove = widget.onDeleteSelectedCues;
    if (remove == null || _selectedIds.isEmpty || _runningSelectedBatch ||
        !await _confirmDraftBeforeLeaving() || !mounted) return;
    final ids = [for (final cue in _cues)
      if (_selectedIds.contains(cue.id)) cue.id];
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool>(dialog,
        confirm: true, cancel: false, child: AlertDialog(
        title: Text('Delete ${ids.length} selected subtitles?'),
        content: const Text('This removes all selected lines in one undoable '
            'checkpoint. You can restore them using Undo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('studio-confirm-delete-selected'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete selected'),
          ),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _runningSelectedBatch = true);
    try {
      final updated = await remove(ids, _selectedId);
      if (!mounted) return;
      if (updated != null) {
        _acceptStructure(updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selected subtitles were not deleted. Refresh the project and retry.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _runningSelectedBatch = false);
    }
  }

  Future<void> _copySelectedSubtitleText({Set<int>? cueIds}) async {
    final ids = cueIds ?? _selectedIds;
    final selected = _cues.where((cue) => ids.contains(cue.id));
    // The mobile editor copies `line.edited ?? line.original`; these values
    // are not interchangeable when an edit was intentionally made blank.
    final contents = selected.map((cue) =>
        (cue.storedEdited ?? (cue.edited.isEmpty
            ? cue.original : cue.edited)).trim())
        .join('\n\n').trim();
    if (contents.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: contents));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied ${ids.length} subtitles to clipboard'),
    ));
  }


  // Daily edits first, media/view controls second, project management last.
  // Less frequent actions move into More on laptop-width windows instead of
  // forcing the entire toolbar (or the title) off-screen.
  Widget _topBar() => LayoutBuilder(builder: (context, limits) {
    final showSecondary = limits.maxWidth >= 1500;
    final showBrand = limits.maxWidth >= 960;
    return IconButtonTheme(
      data: IconButtonThemeData(style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
      )),
      child: Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(border:
        Border(bottom: BorderSide(color: _border))),
    child: Row(children: [
      Icon(Icons.subtitles_rounded, color: _accent, size: 22),
      if (showBrand) ...[
        const SizedBox(width: 8),
        const Text('SubtitleStudio', style:
            TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 10),
        Container(width: 1, height: 20, color: _border),
        const SizedBox(width: 10),
        Flexible(child: Text(
          widget.projectTitle ?? 'Night Drive  /  Main subtitles',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _muted, fontSize: 12),
        )),
      ],
      const Spacer(),
      if (widget.onSaveFile != null)
        IconButton(
          key: const ValueKey('studio-dock-save-file'),
          icon: _savingFile
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          tooltip: 'Save subtitle file (Ctrl/Cmd+S)',
          onPressed: _savingFile || _changingStructure ? null
              : () => unawaited(_saveFileSafely()),
        ),
      if (widget.onRestoreHistory != null) ...[
        IconButton(
          key: const ValueKey('studio-dock-undo'),
          icon: const Icon(Icons.undo),
          tooltip: 'Undo (Ctrl/Cmd+Z)',
          onPressed: _historyNavigationBlocked ||
                  _currentHistoryPoint?.parentCheckpointId == null
              ? null : () => unawaited(_undoHistory()),
        ),
        IconButton(
          key: const ValueKey('studio-dock-redo'),
          icon: const Icon(Icons.redo),
          tooltip: 'Redo (Ctrl/Cmd+Shift+Z)',
          onPressed: _historyNavigationBlocked ||
                  (_currentHistoryPoint?.childCheckpointIds.isEmpty ?? true)
              ? null : () => unawaited(_redoHistory()),
        ),
      ],
      if (widget.isLiveSession && widget.onApplyCueText == null)
        Text('READ ONLY', style: TextStyle(
          color: _muted, letterSpacing: .7, fontSize: 12)),
      if (widget.onInsertCue != null)
        IconButton(
          key: const ValueKey('studio-dock-insert-cue'),
          icon: const Icon(Icons.add_comment_outlined),
          tooltip: 'Insert subtitle line',
          onPressed: _changingStructure ? null :
              () => unawaited(_addCueSafely()),
        ),
      if (widget.onSplitCue != null)
        IconButton(
          key: const ValueKey('studio-dock-split-cue'),
          icon: const Icon(Icons.call_split_outlined),
          tooltip: 'Split selected subtitle line',
          onPressed: _changingStructure || _cues.isEmpty ? null :
              () => unawaited(_splitCueSafely()),
        ),
      if (showSecondary && widget.onMergeCue != null)
        IconButton(
          key: const ValueKey('studio-dock-merge-cue'),
          icon: const Icon(Icons.merge_outlined),
          tooltip: 'Combine selected line with adjacent line',
          onPressed: _changingStructure || _cues.length < 2 ? null :
              () => unawaited(_mergeCueSafely()),
        ),
      if (showSecondary && widget.onDeleteCue != null)
        IconButton(
          key: const ValueKey('studio-dock-delete-cue'),
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete selected subtitle line',
          onPressed: _changingStructure || _cues.isEmpty ? null :
              () => unawaited(_deleteCueSafely()),
        ),
      const SizedBox(width: 6),
      Container(width: 1, height: 20, color: _border),
      const SizedBox(width: 6),
      IconButton(
        key: const ValueKey('studio-toggle-video-panel'),
        tooltip: _showVideo ? 'Hide video player' : 'Show video player',
        onPressed: widget.videoSurface == null ? null : () {
          setState(() => _showVideo = !_showVideo);
          _queueLayoutSave(now: true);
        },
        icon: Icon(_showVideo ? Icons.videocam : Icons.videocam_off_outlined,
            color: _showVideo ? _accent : _muted),
      ),
      IconButton(
        key: const ValueKey('studio-toggle-waveform-panel'),
        tooltip: _showWaveform ? 'Hide waveform' : 'Show waveform',
        onPressed: widget.waveformSurface == null ? null : () {
          setState(() => _showWaveform = !_showWaveform);
          _queueLayoutSave(now: true);
        },
        icon: Icon(Icons.graphic_eq,
            color: _showWaveform ? _accent : _muted),
      ),
      const SizedBox(width: 6),
      Container(width: 1, height: 20, color: _border),
      const SizedBox(width: 6),
      if (showSecondary && widget.onChooseVideo != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-video'),
          icon: const Icon(Icons.video_file_outlined),
          tooltip: 'Attach or change video',
          onPressed: () => unawaited(_chooseVideoSafely()),
        ),
      if (showSecondary && widget.onImportFile != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-import'),
          icon: const Icon(Icons.file_open_outlined),
          tooltip: 'Import subtitles or project',
          onPressed: () => unawaited(_importFileSafely()),
        ),
      if (showSecondary && widget.onNewProject != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-new'),
          icon: const Icon(Icons.add_box_outlined),
          tooltip: 'New project',
          onPressed: () => unawaited(_newProjectSafely()),
        ),
      if (showSecondary && widget.onOpenProjectSettings != null)
        IconButton(
          key: const ValueKey('studio-toolbar-project-settings'),
          icon: const Icon(Icons.settings_applications_outlined),
          tooltip: 'Project Settings',
          onPressed: _openingProjectSettings ? null :
              () => unawaited(_openProjectSettingsSafely()),
        ),
      if (!showSecondary) _toolbarOverflowMenu(),
      const SizedBox(width: 6),
      IconButton(
        key: const ValueKey('desktop-command-palette'),
        icon: const Icon(Icons.keyboard_command_key),
        tooltip: 'Command palette (Ctrl/Cmd+K)',
        onPressed: _showCommandPalette,
      ),
      const SizedBox(width: 5),
      IconButton(
        key: const ValueKey('toggle-explorer'),
        icon: const Icon(Icons.folder_open_outlined),
        tooltip: 'Toggle project explorer',
        onPressed: _toggleExplorerPanel,
      ),
      IconButton(
        key: const ValueKey('toggle-inspector'),
        icon: Icon(_inspectorOpen
            ? Icons.view_sidebar_outlined : Icons.view_sidebar),
        tooltip: 'Toggle inspector',
        onPressed: _toggleInspectorPanel,
      ),
      const SizedBox(width: 7),
      Icon(Icons.circle, size: 9, color: _accent),
    ]),
  ));
  });

  Widget _toolbarOverflowMenu() => PopupMenuButton<_StudioDockToolbarOverflow>(
    key: const ValueKey('studio-dock-toolbar-more'),
    tooltip: 'More subtitle and project actions',
    icon: const Icon(Icons.more_horiz),
    onSelected: (action) {
      switch (action) {
        case _StudioDockToolbarOverflow.merge:
          unawaited(_mergeCueSafely());
        case _StudioDockToolbarOverflow.delete:
          unawaited(_deleteCueSafely());
        case _StudioDockToolbarOverflow.attachVideo:
          unawaited(_chooseVideoSafely());
        case _StudioDockToolbarOverflow.import:
          unawaited(_importFileSafely());
        case _StudioDockToolbarOverflow.newProject:
          unawaited(_newProjectSafely());
        case _StudioDockToolbarOverflow.projectSettings:
          unawaited(_openProjectSettingsSafely());
      }
    },
    itemBuilder: (_) => [
      if (widget.onMergeCue != null)
        PopupMenuItem(value: _StudioDockToolbarOverflow.merge,
          enabled: !_changingStructure && _cues.length >= 2,
          child: const Text('Merge with adjacent line')),
      if (widget.onDeleteCue != null)
        PopupMenuItem(value: _StudioDockToolbarOverflow.delete,
          enabled: !_changingStructure && _cues.isNotEmpty,
          child: const Text('Delete selected line')),
      if (widget.onChooseVideo != null)
        const PopupMenuItem(value: _StudioDockToolbarOverflow.attachVideo,
          child: Text('Attach or change video')),
      if (widget.onImportFile != null)
        const PopupMenuItem(value: _StudioDockToolbarOverflow.import,
          child: Text('Import subtitles or project')),
      if (widget.onNewProject != null)
        const PopupMenuItem(value: _StudioDockToolbarOverflow.newProject,
          child: Text('New project')),
      if (widget.onOpenProjectSettings != null)
        PopupMenuItem(value: _StudioDockToolbarOverflow.projectSettings,
          enabled: !_openingProjectSettings,
          child: const Text('Project settings')),
    ],
  );

  void _toggleExplorerPanel() {
    _toggleSidebar(projects: false);
  }

  void _toggleProjectsPanel() {
    _toggleSidebar(projects: true);
  }

  void _toggleSidebar({required bool projects}) {
    if (MediaQuery.sizeOf(context).width < 1600) {
      setState(() {
        final samePanelOpen = _explorerOverlayOpen &&
            _projectsSidebar == projects;
        _projectsSidebar = projects;
        _explorerOverlayOpen = !samePanelOpen;
        _inspectorOverlayOpen = false;
      });
    } else {
      setState(() {
        final samePanelOpen = _explorerOpen &&
            _projectsSidebar == projects;
        _projectsSidebar = projects;
        _explorerOpen = !samePanelOpen;
      });
      _queueLayoutSave(now: true);
    }
  }

  void _toggleInspectorPanel() {
    if (MediaQuery.sizeOf(context).width < 1250) {
      setState(() {
        _inspectorOverlayOpen = !_inspectorOverlayOpen;
        _explorerOverlayOpen = false;
      });
    } else {
      setState(() => _inspectorOpen = !_inspectorOpen);
      _queueLayoutSave(now: true);
    }
  }

  Widget _navigationRail() => Container(
    width: 61,
    decoration: BoxDecoration(border:
      Border(right: BorderSide(color: _border))),
    child: Column(children: [
      const SizedBox(height: 8),
      if (widget.onChooseProject != null || widget.projects.isNotEmpty) ...[
        Tooltip(
          message: 'Projects · ${widget.projects.length} saved',
          child: IconButton(
            key: const ValueKey('studio-dock-sidebar-projects'),
            tooltip: 'Projects',
            icon: Icon(Icons.folder_copy_outlined, color: _accent),
            onPressed: _toggleProjectsPanel,
          ),
        ),
        Divider(color: _border, indent: 10, endIndent: 10),
      ],
      _railItem(0, Icons.movie_creation_outlined, 'Editor'),
      _railItem(1, Icons.account_tree_outlined, 'History'),
      if (widget.onLoadSourceView != null)
        _railItem(5, Icons.code_rounded, 'Source View'),
      _railItem(2, Icons.search_rounded, 'Find'),
      _railItem(3, Icons.tune_rounded, 'Tools'),
      const Spacer(),
      _railItem(4, Icons.settings_outlined, 'Settings'),
      const SizedBox(height: 8),
    ]),
  );

  Widget _railItem(int index, IconData icon, String title) => Tooltip(
    message: title,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: _section == index ? _accent.withValues(alpha: .18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          key: ValueKey('rail-$index'),
          borderRadius: BorderRadius.circular(9),
          onTap: () => unawaited(_switchSection(index)),
          child: SizedBox(width: 44, height: 43,
            child: Icon(icon, size: 21,
              color: _section == index ? _accent : _muted)),
        ),
      ),
    ),
  );

  Future<void> _switchSection(int index) async {
    if (index == 4 && widget.onOpenAppSettings != null) {
      // Settings is a modal over the editor: never discard a subtitle draft.
      await widget.onOpenAppSettings!();
      return;
    }
    if (index == _section) return;
    if (!await _confirmDraftBeforeLeaving() || !mounted) return;
    if (index == 5) {
      final load = widget.onLoadSourceView;
      if (load == null) return;
      setState(() => _sourceLoading = true);
      try {
        final raw = await load();
        if (!mounted) return;
        setState(() {
          _sourceText = raw;
          _sourceBaseline = raw;
          _sourceError = null;
          _section = 5;
          _explorerOverlayOpen = false;
          _inspectorOverlayOpen = false;
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load the raw subtitle source.'),
        ));
      } finally {
        if (mounted) setState(() => _sourceLoading = false);
      }
      return;
    }
    setState(() {
      _section = index;
      _explorerOverlayOpen = false;
      _inspectorOverlayOpen = false;
    });
  }

  Future<void> _openFind() async {
    if (_section == 2) {
      await _switchSection(0);
      return;
    }
    await _switchSection(2);
    if (mounted && _section == 2) _findFocus.requestFocus();
  }

  Future<void> _toggleInspectorFromShortcut(int tab) async {
    if (_section == 0 && _inspectorOpen && _inspectorTab == tab) {
      setState(() {
        _inspectorOpen = false;
        _inspectorOverlayOpen = false;
      });
      _queueLayoutSave(now: true);
      return;
    }
    await _openInspectorTab(tab);
  }

  Future<void> _openInspectorTab(int tab) async {
    await _switchSection(0);
    if (!mounted || _section != 0) return;
    await _changeInspectorTab(tab);
    if (!mounted || _inspectorTab != tab) return;
    setState(() {
      _inspectorOpen = true;
      _inspectorOverlayOpen = MediaQuery.sizeOf(context).width < 1250;
    });
    if (!_inspectorOverlayOpen) _queueLayoutSave(now: true);
  }

  void _invalidateFind() => setState(() {
    _searched = false;
    _findResults = const [];
    _selectedFindResults.clear();
    _findError = null;
  });

  void _runFind() {
    final term = _findInput.text.trim();
    if (term.isEmpty) {
      _invalidateFind();
      return;
    }
    try {
      final found = widget.onFindCues?.call(
          term, _findCaseSensitive, _findWholeWord) ?? const <StudioDockSearchHit>[];
      setState(() {
        _searched = true;
        _findResults = found;
        _selectedFindResults.clear();
        _findError = null;
      });
    } catch (_) {
      setState(() {
        _searched = true;
        _findResults = const [];
        _selectedFindResults.clear();
        _findError = 'Could not search this subtitle session.';
      });
    }
  }

  Future<void> _openSearchHit(StudioDockSearchHit hit) async {
    await _switchSection(0);
    if (!mounted || _section != 0) return;
    if (_query.isNotEmpty) {
      _tableSearch.clear();
      setState(() => _query = '');
    }
    _selectCue(hit.cueNumber);
    final cue = _cues.where((line) => line.id == hit.cueNumber).firstOrNull;
    if (cue != null) widget.playback?.seek(Duration(
        milliseconds: TimeValidator.timeStringToMilliseconds(cue.start)));
  }

  Future<void> _replaceFound({required bool selectedOnly}) async {
    final apply = widget.onReplaceMatches;
    if (apply == null || _replacingMatches || _changingStructure ||
        _findResults.isEmpty) return;
    final hits = [
      for (var i = 0; i < _findResults.length; i++)
        if (!selectedOnly || _selectedFindResults.contains(i)) _findResults[i],
    ];
    if (hits.isEmpty) return;
    final term = _findInput.text.trim();
    final replacement = _replaceInput.text;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool>(dialog,
        confirm: true, cancel: false, child: AlertDialog(
        title: const Text('Replace subtitle text?'),
        content: Text('Replace ${hits.length} occurrence(s) of "$term" '
            'with "$replacement"? This will create one saved history point.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          FilledButton(key: const ValueKey('studio-replace-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Replace')),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _replacingMatches = true);
    StudioDockCueUpdate? update;
    try {
      update = await apply(hits, term, replacement, _findCaseSensitive);
    } catch (_) {
      update = null;
    }
    if (!mounted) return;
    setState(() => _replacingMatches = false);
    if (update == null) {
      setState(() => _findError = 'Could not replace these matches. '
          'The subtitles may have changed; run Find again.');
      return;
    }
    _acceptStructure(update);
    _runFind();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Replaced ${hits.length} occurrence(s) in subtitle history.'),
    ));
  }

  Future<void> _syncAnchoredSafely() async {
    final sync = widget.onSyncAnchoredCues;
    if (sync == null || _cues.isEmpty || _runningTool) return;
    var start = _cues.first.start;
    var end = _cues.last.end;
    String? error;
    var submitted = false;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) {
          void submit() {
            if (submitted) return;
            final validation = StudioDockTimingEditService.validate(
                start.trim(), end.trim());
            if (validation != null) {
              refresh(() => error = validation);
              return;
            }
            submitted = true;
            Navigator.pop(dialog, [start.trim(), end.trim()]);
          }
          return _modalActions(
            onConfirm: submit,
            onCancel: () => Navigator.pop(dialog),
            child: AlertDialog(
          title: const Text('Sync subtitles using time anchors'),
          content: SizedBox(width: 430, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set the new first subtitle start and last subtitle '
                  'end. Relative line starts scale; each duration is preserved.'),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('studio-sync-start'),
                initialValue: start,
                decoration: const InputDecoration(
                    labelText: 'First subtitle start (HH:MM:SS,mmm)',
                    border: OutlineInputBorder()),
                onChanged: (v) => start = v,
                onFieldSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('studio-sync-end'),
                initialValue: end,
                decoration: const InputDecoration(
                    labelText: 'Last subtitle end (HH:MM:SS,mmm)',
                    border: OutlineInputBorder()),
                onChanged: (v) => end = v,
                onFieldSubmitted: (_) => submit(),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(
                    color: Theme.of(dialog).colorScheme.error)),
              ],
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel')),
            FilledButton(
              key: const ValueKey('studio-sync-anchor-next'),
              onPressed: submit,
              child: const Text('Continue'),
            ),
          ],
        ));
        },
      ),
    );
    if (result == null || !mounted) return;
    await _runBulkTool(
      title: 'Synchronize subtitle timecodes',
      detail: 'Apply first/last anchors to ${_cues.length} subtitles '
          'while preserving each duration?',
      apply: () => sync(_selectedId, result[0], result[1]),
    );
  }

  Future<void> _convertFramerateSafely() async {
    final convert = widget.onConvertFramerate;
    if (convert == null || widget.videoSurface == null ||
        _cues.isEmpty || _runningTool) return;
    var source = '23.976';
    final detected = widget.getVideoFramerate?.call();
    var target = detected != null && detected.isFinite && detected > 0
        ? detected.toStringAsFixed(3) : '25.000';
    String? error;
    var submitted = false;
    final result = await showDialog<List<double>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) {
          void submit() {
            if (submitted) return;
            final a = double.tryParse(source.trim());
            final b = double.tryParse(target.trim());
            if (a == null || b == null || !a.isFinite || !b.isFinite ||
                a <= 0 || b <= 0) {
              refresh(() => error = 'Enter positive, finite framerates.');
              return;
            }
            submitted = true;
            Navigator.pop(dialog, [a, b]);
          }
          return _modalActions(
            onConfirm: submit,
            onCancel: () => Navigator.pop(dialog),
            child: AlertDialog(
          title: const Text('Adjust subtitle framerate'),
          content: SizedBox(width: 430, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Convert all line start and end times by the source '
                  'framerate divided by the target framerate.'),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('studio-sync-source-fps'),
                initialValue: source,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Source FPS', border: OutlineInputBorder()),
                onChanged: (v) => source = v,
                onFieldSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('studio-sync-target-fps'),
                initialValue: target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Target FPS', border: OutlineInputBorder()),
                onChanged: (v) => target = v,
                onFieldSubmitted: (_) => submit(),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(
                    color: Theme.of(dialog).colorScheme.error)),
              ],
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel')),
            FilledButton(
              key: const ValueKey('studio-sync-fps-next'),
              onPressed: submit,
              child: const Text('Continue'),
            ),
          ],
        ));
        },
      ),
    );
    if (result == null || !mounted) return;
    await _runBulkTool(
      title: 'Convert subtitle framerate',
      detail: 'Convert ${_cues.length} subtitles from '
          '${result[0]} FPS to ${result[1]} FPS?',
      apply: () => convert(_selectedId, result[0], result[1]),
    );
  }

  Future<void> _runBulkTool({
    required String title,
    required String detail,
    required Future<StudioDockCueUpdate?> Function() apply,
  }) async {
    if (_runningTool || _changingStructure || _savingDraft) return;
    if (!await _confirmDraftBeforeLeaving() || !mounted ||
        _runningTool || _changingStructure) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool>(dialog,
        confirm: true, cancel: false, child: AlertDialog(
        title: Text(title),
        content: Text('$detail One saved history point will be created. '
            'The original subtitle file will not be overwritten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          FilledButton(key: const ValueKey('studio-tool-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Apply')),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _runningTool = true; _toolsError = null; });
    StudioDockCueUpdate? updated;
    try {
      updated = await apply();
    } catch (_) {
      updated = null;
    }
    if (!mounted) return;
    setState(() => _runningTool = false);
    if (updated == null) {
      setState(() => _toolsError = 'Could not apply this tool. '
          'Check the time range or refresh a subtitle edited elsewhere.');
      return;
    }
    _acceptStructure(updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$title completed in project history.'),
    ));
  }

  Widget _activeSidebar() => _projectsSidebar
      ? _projectsListSidebar()
      : _projectSidebar();

  Widget _projectsListSidebar() => Container(
    decoration: BoxDecoration(border: Border(right: BorderSide(color: _border))),
    child: Column(children: [
      _paneHeader(Icons.folder_copy_outlined, 'PROJECTS',
          trailing: '${widget.projects.length} available'),
      Expanded(child: widget.projects.isEmpty
        ? Center(child: Text('No saved projects',
            style: TextStyle(color: _muted, fontSize: 14)))
        : ListView.builder(
            key: const ValueKey('studio-projects-list'),
            itemCount: widget.projects.length,
            itemBuilder: (context, index) {
              final project = widget.projects[index];
              final selected = project.id == widget.activeProjectId;
              return ListTile(
                key: ValueKey('studio-dock-project-option-${project.id}'),
                dense: true,
                selected: selected,
                leading: Icon(selected ? Icons.folder_open : Icons.folder_outlined,
                    size: 19, color: selected ? _accent : _muted),
                title: Text(project.title, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(project.isEditMode ? 'Edit mode' : 'Translation mode',
                    style: const TextStyle(fontSize: 12)),
                onTap: () => unawaited(_selectSidebarProject(project.id)),
              );
            },
          )),
      const Divider(height: 1),
      if (widget.onChooseProject != null)
        ListTile(dense: true, leading: const Icon(Icons.folder_open),
            title: const Text('Browse projects'),
            onTap: () => unawaited(_selectSidebarProject(-1))),
      if (widget.onNewProject != null)
        ListTile(dense: true, leading: const Icon(Icons.add_box_outlined),
            title: const Text('New project'),
            onTap: () => unawaited(_selectSidebarProject(-2))),
      if (widget.onImportFile != null)
        ListTile(dense: true, leading: const Icon(Icons.file_open_outlined),
            title: const Text('Import project'),
            onTap: () => unawaited(_selectSidebarProject(-3))),
    ]),
  );

  Widget _projectSidebar() => widget.isLiveSession
      ? _readOnlyProjectSidebar()
      : Container(
    decoration: BoxDecoration(border:
        Border(right: BorderSide(color: _border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paneHeader(Icons.folder_open_rounded, 'PROJECT', trailing: 'DEMO'),
        SizedBox(height: 6),
        _sidebarRow(Icons.folder_rounded, 'Night Drive', selected: true),
        Padding(padding: EdgeInsets.fromLTRB(14, 12, 10, 5),
          child: Text('PROJECT FILES', style:
            TextStyle(fontSize: 12, color: _muted, letterSpacing: .8))),
        _sidebarRow(Icons.subtitles_rounded, 'Main subtitles.srt',
            selected: true, indent: 15),
        _sidebarRow(Icons.subtitles_outlined, 'Secondary subtitles',
            indent: 15),
        _sidebarRow(Icons.movie_outlined, 'Night Drive.mp4', indent: 15),
        Padding(padding: EdgeInsets.fromLTRB(14, 14, 10, 5),
          child: Text('VERSIONS', style:
            TextStyle(fontSize: 12, color: _muted, letterSpacing: .8))),
        _sidebarRow(Icons.fork_right_rounded, 'Current version'),
        _sidebarRow(Icons.bookmark_border_rounded, 'Pinned versions'),
        const Spacer(),
        Padding(
          padding: EdgeInsets.all(10),
          child: Text('Preview project\nNo local files are opened.',
            style: TextStyle(fontSize: 13, color: _muted, height: 1.5)),
        ),
      ],
    ),
  );

  Widget _readOnlyProjectSidebar() => Container(
    decoration: BoxDecoration(
      border: Border(right: BorderSide(color: _border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _paneHeader(Icons.folder_open_rounded, 'PROJECT',
          trailing: widget.isEditMode ? 'EDIT MODE' : 'TRANSLATION'),
      const SizedBox(height: 6),
      _sidebarRow(Icons.subtitles_rounded,
          widget.projectTitle ?? 'Subtitle session',
          selected: true),
      Padding(
        padding: EdgeInsets.all(10),
        child: Text(
          widget.isEditMode
              ? 'Subtitle creation mode · enter subtitle text and timing. '
                  'No original/translation pair is required.'
              : 'Translation mode · keep the original text alongside your '
                  'edited translation.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
      ),
    ]),
  );

  Widget _sidebarRow(IconData icon, String label,
      {bool selected = false, double indent = 0}) =>
    Padding(
      padding: EdgeInsets.fromLTRB(8 + indent, 1, 8, 1),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: .12) : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: selected ? _accent : _muted),
          SizedBox(width: 7),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14,
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface : _muted))),
        ]),
      ),
    );

  Widget _dragHandle({required ValueChanged<double> onDelta}) =>
      MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            onDelta(details.delta.dx);
            _queueLayoutSave();
          },
          onHorizontalDragEnd: (_) => _queueLayoutSave(now: true),
          child: SizedBox(width: 5,
              child: ColoredBox(color: _border)),
        ),
      );

  Widget _paneHeader(IconData icon, String title,
      {String? trailing, Key? trailingKey, double height = 42}) =>
      Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .4)),
          const Spacer(),
          if (trailing != null) Flexible(child: Text(trailing,
              key: trailingKey,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _muted, fontSize: 12))),
        ]),
      );

  Widget _editingWorkspace() => LayoutBuilder(
    builder: (context, limits) {
      final videoVisible = _showVideo && widget.videoSurface != null;
      final waveformVisible = _showWaveform && widget.waveformSurface != null;
      final bands = StudioDockBands.resolve(
        limits.maxHeight,
        videoShare: _videoShare,
        waveformShare: _waveformShare,
      );
      return Column(children: [
        // The waveform resolves its audio stream through the shared player.
        // Keep exactly one native video surface mounted, offstage, when only
        // the waveform is shown. This preserves playback and avoids mounting
        // the same player GlobalKey in two visible widgets.
        if (!videoVisible && waveformVisible && widget.videoSurface != null)
          Offstage(
            child: SizedBox(width: 640, height: 360,
                child: widget.videoSurface!),
          ),
        if (videoVisible)
        SizedBox(
          key: const ValueKey('dock-video-band'),
          height: waveformVisible ? bands.video
              : math.min(limits.maxHeight * _videoShare,
                  math.max(0.0, limits.maxHeight - StudioDockBands.splitter - 80)),
          child: Column(children: [
            Expanded(child: Stack(children: [
              Positioned.fill(child: widget.videoSurface ?? _videoPanel()),
              if (_floatingPlaybackVisible &&
                  widget.videoSurface != null &&
                  widget.onTogglePlayback != null &&
                  widget.playback != null)
                Positioned(
                  right: 18,
                  bottom: 14,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: widget.playback!.attached,
                    builder: (context, attached, _) =>
                        ValueListenableBuilder<bool>(
                      valueListenable: widget.playback!.playing,
                      builder: (context, playing, _) => IconButton.filled(
                        key: const ValueKey('studio-floating-playback'),
                        tooltip: playing ? 'Pause video' : 'Play video',
                        onPressed: attached ? widget.onTogglePlayback : null,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      ),
                    ),
                  ),
                ),
            ])),
            if (widget.videoSurface == null) _transport(),
          ]),
        ),
        if (videoVisible && waveformVisible)
          _horizontalSplitter(
          key: const ValueKey('splitter-video-waveform'),
          onDelta: (dy) => setState(() {
            final change = dy / limits.maxHeight;
            _videoShare = (_videoShare + change)
                .clamp(StudioDockBands.minVideoShare, .62);
            _waveformShare = (_waveformShare - change)
                .clamp(StudioDockBands.minWaveformShare, .38);
          }),
          onReset: () => setState(() {
            _videoShare = StudioDockBands.defaultVideoShare;
            _waveformShare = StudioDockBands.defaultWaveformShare;
          }),
        ),
        if (waveformVisible)
        SizedBox(
          key: const ValueKey('dock-waveform-band'),
          height: videoVisible ? bands.waveform
              : math.min(limits.maxHeight * _waveformShare,
                  math.max(0.0, limits.maxHeight - StudioDockBands.splitter - 80)),
          child: _waveformPanel(),
        ),
        if (videoVisible || waveformVisible)
        _horizontalSplitter(
          key: const ValueKey('splitter-waveform-table'),
          onDelta: (dy) => setState(() {
            if (videoVisible && !waveformVisible) {
              _videoShare = (_videoShare + dy / limits.maxHeight)
                  .clamp(StudioDockBands.minVideoShare, .62);
            } else {
              _waveformShare = (_waveformShare + dy / limits.maxHeight)
                  .clamp(StudioDockBands.minWaveformShare, .38);
            }
          }),
          onReset: () => setState(() {
            _videoShare = StudioDockBands.defaultVideoShare;
            _waveformShare = StudioDockBands.defaultWaveformShare;
          }),
        ),
        Expanded(
          child: KeyedSubtree(
            key: const ValueKey('dock-table-band'),
            child: _subtitleTable(),
          ),
        ),
      ]);
    },
  );

  Widget _horizontalSplitter({
    required Key key,
    required ValueChanged<double> onDelta,
    required VoidCallback onReset,
  }) => MouseRegion(
    key: key,
    cursor: SystemMouseCursors.resizeRow,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        onDelta(details.delta.dy);
        _queueLayoutSave();
      },
      onVerticalDragEnd: (_) => _queueLayoutSave(now: true),
      onDoubleTap: () {
        onReset();
        _queueLayoutSave(now: true);
      },
      child: SizedBox(
        height: StudioDockBands.splitter,
        child: ColoredBox(color: _border),
      ),
    ),
  );

  Widget _videoPanel() => Container(
    padding: const EdgeInsets.all(8),
    color: Theme.of(context).colorScheme.surface,
    child: Column(children: [
      Row(children: [
        Icon(Icons.videocam_outlined, size: 16, color: _muted),
        const SizedBox(width: 9),
        const Text('VIDEO PREVIEW',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        const Spacer(),
        Icon(Icons.aspect_ratio, size: 15, color: _muted),
        const SizedBox(width: 8),
        Text(widget.isLiveSession ? 'Media not connected' : '16:9 · Demo clip',
            style: TextStyle(fontSize: 11, color: _muted)),
      ]),
      SizedBox(height: 6),
      Expanded(
        child: Center(child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF232C36), Color(0xFF10151B), Color(0xFF06090D)],
              ),
            ),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(
                painter: const _DemoHorizonPainter())),
              Positioned(left: 17, top: 13,
                child: Text(widget.isLiveSession
                    ? 'SUBTITLE LINES · VIDEO NOT CONNECTED'
                    : 'DEMO VIDEO · PLACEHOLDER',
                  style: const TextStyle(fontSize: 10,
                    color: Color(0xFFACB6BD), letterSpacing: 1))),
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(widget.isLiveSession
                    ? (_selected.edited.isEmpty
                        ? _selected.original : _selected.edited)
                    : _selected.edited,
                  maxLines: 2, textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, height: 1.4, fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  )),
              )),
            ]),
          ),
        )),
      ),
    ]),
  );

  Widget _transport() => Container(
    height: 45,
    decoration: BoxDecoration(border: Border(
      top: BorderSide(color: _border),
      bottom: BorderSide(color: _border),
    )),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(children: [
      IconButton(icon: Icon(Icons.skip_previous_rounded, size: 19),
        tooltip: 'Previous line',
        onPressed: () => _selectRelative(-1)),
      IconButton(
        key: const ValueKey('preview-play'),
        icon: Icon(_playing ? Icons.pause_circle_filled_rounded
            : Icons.play_circle_fill_rounded, color: _accent, size: 25),
        tooltip: widget.isLiveSession
            ? 'Media playback is not connected in this preview'
            : 'Toggle simulated playback',
        onPressed: widget.isLiveSession ? null
            : () => _dispatchManagedAction(HotkeyAction.playPause)),
      IconButton(icon: const Icon(Icons.skip_next_rounded, size: 19),
        tooltip: 'Next line', onPressed: () => _selectRelative(1)),
      const SizedBox(width: 14),
      Text(_selected.start, style: const TextStyle(
          fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
      Text(widget.isLiveSession ? ' / no media' : ' / 00:12:45',
        style: TextStyle(color: _muted, fontSize: 12)),
      const Spacer(),
      Text('1.0×', style: TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(width: 12),
      Icon(Icons.volume_up_outlined, size: 17, color: _muted),
    ]),
  );

  Widget _waveformPanel() => Container(
    padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(children: [
      if (widget.waveformSurface == null) ...[
        Row(children: [
          Icon(Icons.graphic_eq, size: 15, color: _accent),
          const SizedBox(width: 8),
          const Text('WAVEFORM', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8)),
          const SizedBox(width: 10),
          Text(widget.isLiveSession ? 'Audio not connected' : 'Audio track: Auto',
              style: TextStyle(fontSize: 10, color: _muted)),
        ]),
        const SizedBox(height: 7),
      ],
      Expanded(child: widget.waveformSurface ?? (widget.isLiveSession
          ? Center(child: Text('Waveform integration pending',
              style: TextStyle(color: _muted, fontSize: 11)))
          : SizedBox.expand(
              child: CustomPaint(painter: _DemoWaveformPainter(
                cueIndex: _selectedId, accent: _accent))))),
    ]),
  );

  Widget _subtitleTable() => LayoutBuilder(builder: (context, tableLimits) {
    final searchOnSecondRow = tableLimits.maxWidth < 850;
    return Column(children: [
    SizedBox(height: 34, child: Row(children: [
      Expanded(child: _paneHeader(Icons.view_list_outlined, 'SUBTITLE LINES',
        trailing: _subtitleCountLabel,
        trailingKey: const ValueKey('studio-subtitle-count'),
        height: 30)),
      if (!searchOnSecondRow)
        SizedBox(
          width: (tableLimits.maxWidth * .27)
              .clamp(190.0, 300.0).toDouble(),
          child: _subtitleSearchField(),
        ),
      IconButton(
        key: const ValueKey('studio-go-to-line'),
        tooltip: 'Go to subtitle line',
        icon: const Icon(Icons.numbers, size: 19),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: EdgeInsets.zero,
        onPressed: _cues.isEmpty ? null : () => unawaited(_goToLineSafely()),
      ),
      DropdownButtonHideUnderline(child: DropdownButton<_StudioDockReviewFilter>(
        key: const ValueKey('studio-review-filter'),
        value: _reviewFilter,
        isDense: true,
        style: TextStyle(fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface),
        items: const [
          DropdownMenuItem(value: _StudioDockReviewFilter.all,
              child: Text('All lines')),
          DropdownMenuItem(value: _StudioDockReviewFilter.marked,
              child: Text('Marked')),
          DropdownMenuItem(value: _StudioDockReviewFilter.unresolved,
              child: Text('Unresolved')),
          DropdownMenuItem(value: _StudioDockReviewFilter.resolved,
              child: Text('Resolved')),
        ],
        onChanged: (filter) {
          if (filter != null) unawaited(_changeReviewFilterSafely(filter));
        },
      )),
      if (widget.onApplyBulkReview != null)
        PopupMenuButton<StudioDockReviewAction>(
          key: const ValueKey('studio-bulk-review-menu'),
          tooltip: 'Review selected subtitles',
          enabled: _selectedIds.isNotEmpty && !_changingStructure,
          icon: const Icon(Icons.bookmarks_outlined),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: EdgeInsets.zero,
          onSelected: (action) => unawaited(_applyReviewSelection(
              _selectedIds.toList(), action: action)),
          itemBuilder: (_) => const [
            PopupMenuItem(height: 34, value: StudioDockReviewAction.mark,
                child: Text('Mark selected for review')),
            PopupMenuItem(height: 34, value: StudioDockReviewAction.unmark,
                child: Text('Unmark selected')),
            PopupMenuItem(height: 34, value: StudioDockReviewAction.resolve,
                child: Text('Resolve selected')),
            PopupMenuItem(height: 34, value: StudioDockReviewAction.reopen,
                child: Text('Reopen selected')),
          ],
        ),
      if (widget.playback != null) IconButton(
        key: const ValueKey('studio-dock-follow-playback'),
        tooltip: _followPlayback ? 'Pause subtitle follow' : 'Follow playback',
        icon: Icon(_followPlayback ? Icons.my_location : Icons.location_disabled),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: EdgeInsets.zero,
        onPressed: () { setState(() => _followPlayback = !_followPlayback); _onPlaybackPosition(); },
      ),
    ])),
    if (searchOnSecondRow)
      SizedBox(height: 34, child: _subtitleSearchField()),
    Expanded(child: LayoutBuilder(builder: (context, limits) {
      final gridWidth = math.max(850.0, limits.maxWidth);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: gridWidth,
          height: limits.maxHeight,
          child: Column(children: [
            Container(
              height: 26,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: _gridCells(null),
            ),
            Expanded(child: Focus(
              focusNode: _gridFocus,
              onKeyEvent: _handleGridKey,
              child: _visible.isEmpty
              ? Center(child: Text('No matching subtitle lines',
                  style: TextStyle(color: _muted)))
              : ListView.builder(
                  controller: _cueScroll,
                  itemCount: _visible.length,
                  itemExtent: _cueRowHeight,
                  itemBuilder: (context, i) {
                    final cue = _visible[i];
                    final selected = _selectedIds.contains(cue.id);
                    return Material(
                      color: selected ? _accent.withValues(alpha: .14)
                          : cue.id == _playingCueId ? _accent.withValues(alpha: .09)
                          : i.isOdd
                              ? Theme.of(context).colorScheme.surfaceContainerLow
                              : Colors.transparent,
                      child: InkWell(
                        key: ValueKey('desktop-cue-' + cue.id.toString()),
                        onTap: () => _selectFromPointer(cue.id),
                        onSecondaryTapDown: (details) =>
                            _showCueContextMenu(cue, details.globalPosition),
                        child: Container(
                          decoration: BoxDecoration(border: Border(
                            bottom: BorderSide(color: _border, width: .4),
                          )),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _gridCells(cue),
                        ),
                      ),
                    );
                  },
                ),
            )),
          ]),
        ),
      );
    })),
  ]);
  });

  Widget _subtitleSearchField() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    child: TextField(
      key: const ValueKey('desktop-cue-search'),
      controller: _tableSearch,
      focusNode: _searchFocus,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Find subtitle, timecode or line number…',
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 16),
        prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        contentPadding: const EdgeInsets.symmetric(vertical: 7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (value) => setState(() => _query = value),
    ),
  );


  /// Right-click actions share the same guarded entry points as the menubar.
  /// The active multi-selection is preserved when the clicked cue belongs to
  /// it. A non-selected cue becomes a single-cue target only after its draft
  /// confirmation succeeds, never before the user chooses a menu action.
  Future<bool> _targetCueFromContext(int cueId) async {
    if (!mounted || !_visible.any((cue) => cue.id == cueId)) return false;
    if (_selectedId == cueId && _selectedIds.length == 1) return true;
    if (!await _confirmDraftBeforeLeaving() || !mounted) return false;
    _applyCueSelection(cueId);
    return true;
  }

  Future<bool> _prepareContextBatch(int cueId) async {
    if (_selectedIds.contains(cueId)) return true;
    return _targetCueFromContext(cueId);
  }

  Future<void> _showCueContextMenu(
      StudioDockCue cue, Offset position) async {
    final renderObject = Overlay.of(context).context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final batchSize = _selectedIds.contains(cue.id) ? _selectedIds.length : 1;
    ModalRoute<dynamic>? popupRoute;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & renderObject.size,
      ),
      items: [
        PopupMenuItem(height: 34, value: 'select', child: Builder(
          builder: (popupContext) {
            popupRoute = ModalRoute.of(popupContext);
            return const Text('Select subtitle');
          },
        )),
        if (widget.onApplyCueText != null)
          const PopupMenuItem(height: 34, value: 'edit',
              child: Text('Edit subtitle…')),
        if (widget.onApplyCueNotes != null)
          const PopupMenuItem(height: 34, value: 'notes', child: Text('Review notes')),
        if (widget.onInsertCue != null || widget.onSplitCue != null ||
            widget.onMergeCue != null || widget.onDeleteCue != null) ...[
          const PopupMenuDivider(),
          if (widget.onInsertCue != null)
            const PopupMenuItem(height: 34, value: 'insert',
                child: Text('Insert subtitle after…')),
          if (widget.onSplitCue != null)
            const PopupMenuItem(height: 34, value: 'split',
                child: Text('Split subtitle…')),
          if (widget.onMergeCue != null && _cues.length > 1)
            const PopupMenuItem(height: 34, value: 'merge',
                child: Text('Combine adjacent subtitles…')),
          if (widget.onDeleteCue != null && batchSize == 1)
            const PopupMenuItem(height: 34, value: 'delete-cue',
                child: Text('Delete subtitle…')),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(height: 34, value: 'copy-selected',
            child: Text(batchSize == 1
                ? 'Copy subtitle text'
                : 'Copy selected subtitles ($batchSize)')),
        const PopupMenuItem(height: 34, value: 'copy', child: Text('Copy timecodes')),
        if (widget.onShiftSelectedCues != null)
          PopupMenuItem(height: 34, value: 'shift-selected',
              enabled: !_runningSelectedBatch,
              child: Text('Shift selected times ($batchSize)…')),
        if (widget.onDeleteSelectedCues != null)
          PopupMenuItem(height: 34, value: 'delete-selected',
              enabled: !_runningSelectedBatch,
              child: Text('Delete selected subtitles ($batchSize)…')),
        const PopupMenuItem(height: 34, value: 'select-by-index',
            child: Text('Select subtitles by index…')),
        PopupMenuItem(height: 34, value: 'select-range',
            child: Text(_rangeSelectionMode
                ? 'Cancel range selection' : 'Select subtitle range')),
        if (widget.onApplyBulkReview != null) ...const [
          PopupMenuDivider(),
          PopupMenuItem(height: 34, value: 'mark-selected',
              child: Text('Mark selected for review')),
          PopupMenuItem(height: 34, value: 'unmark-selected',
              child: Text('Unmark selected')),
          PopupMenuItem(height: 34, value: 'resolve-selected',
              child: Text('Resolve selected')),
          PopupMenuItem(height: 34, value: 'reopen-selected',
              child: Text('Reopen selected')),
        ],
        if (!widget.isLiveSession)
          const PopupMenuItem(height: 34, value: 'mark',
              child: Text('Toggle review mark')),
      ],
    );
    if (!mounted) return;
    // showMenu's selection future resolves before its exit animation ends.
    // Wait for the popup barrier to leave before showing a second dialog.
    if (result != null && popupRoute != null) await popupRoute!.completed;
    if (!mounted) return;
    switch (result) {
      case 'select':
        _selectCue(cue.id);
      case 'edit':
        if (await _targetCueFromContext(cue.id)) {
          await _openInspectorTab(0);
        }
      case 'notes':
        if (await _targetCueFromContext(cue.id)) {
          await _openInspectorTab(2);
        }
      case 'insert':
        if (await _targetCueFromContext(cue.id)) await _addCueSafely();
      case 'split':
        if (await _targetCueFromContext(cue.id)) await _splitCueSafely();
      case 'merge':
        if (await _targetCueFromContext(cue.id)) await _mergeCueSafely();
      case 'delete-cue':
        if (await _targetCueFromContext(cue.id)) await _deleteCueSafely();
      case 'shift-selected':
        if (await _prepareContextBatch(cue.id)) await _shiftSelectedSafely();
      case 'delete-selected':
        if (await _prepareContextBatch(cue.id)) await _deleteSelectedSafely();
      case 'select-by-index':
        await _selectByIndexSafely();
      case 'select-range':
        _toggleRangeSelectionMode();
      case 'mark':
        if (await _targetCueFromContext(cue.id)) _toggleMarkedSelection();
      case 'mark-selected':
        if (await _prepareContextBatch(cue.id)) {
          await _applyReviewSelection(_selectedIds.toList(),
              action: StudioDockReviewAction.mark);
        }
      case 'unmark-selected':
        if (await _prepareContextBatch(cue.id)) {
          await _applyReviewSelection(_selectedIds.toList(),
              action: StudioDockReviewAction.unmark);
        }
      case 'resolve-selected':
        if (await _prepareContextBatch(cue.id)) {
          await _applyReviewSelection(_selectedIds.toList(),
              action: StudioDockReviewAction.resolve);
        }
      case 'reopen-selected':
        if (await _prepareContextBatch(cue.id)) {
          await _applyReviewSelection(_selectedIds.toList(),
              action: StudioDockReviewAction.reopen);
        }
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: cue.start + ' --> ' + cue.end),
        );
      case 'copy-selected':
        // A right-click on a non-selected row acts on that row only.
        await _copySelectedSubtitleText(cueIds: _selectedIds.contains(cue.id)
            ? null : {cue.id});
      default:
        break;
    }
  }

  void _showCommandPalette() {
    _commandSearch.clear();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) {
          final commands = <MapEntry<String, VoidCallback>>[
            MapEntry('Find subtitle', () => unawaited(_openFind())),
            MapEntry('Replace subtitle text', () => unawaited(_openFind())),
            MapEntry('Subtitle tools', () =>
                unawaited(_switchSection(3))),
            MapEntry('Next line', () => _selectRelative(1)),
            MapEntry('Previous line', () => _selectRelative(-1)),
            MapEntry('Select all visible subtitles', _selectAllVisibleCues),
            if (_selectedIds.isNotEmpty)
              MapEntry('Copy selected subtitles', () =>
                  unawaited(_copySelectedSubtitleText())),
            if (_currentHistoryPoint?.parentCheckpointId != null)
              MapEntry('Undo subtitle edit', () => unawaited(_undoHistory())),
            if (_currentHistoryPoint?.childCheckpointIds.isNotEmpty ?? false)
              MapEntry('Redo subtitle edit', () => unawaited(_redoHistory())),
            if (widget.onLoadHistory != null)
              MapEntry('Show editing history', () =>
                  setState(() => _section = 1)),
            if (!widget.isLiveSession)
              MapEntry('Toggle playback preview',
                  () => _dispatchManagedAction(HotkeyAction.playPause)),
            if (widget.onApplyBulkReview != null) ...[
              MapEntry('Mark selected for review', () => unawaited(
                  _applyReviewSelection(_selectedIds.toList(),
                      action: StudioDockReviewAction.mark))),
              MapEntry('Unmark selected subtitles', () => unawaited(
                  _applyReviewSelection(_selectedIds.toList(),
                      action: StudioDockReviewAction.unmark))),
              MapEntry('Resolve selected reviews', () => unawaited(
                  _applyReviewSelection(_selectedIds.toList(),
                      action: StudioDockReviewAction.resolve))),
              MapEntry('Reopen selected reviews', () => unawaited(
                  _applyReviewSelection(_selectedIds.toList(),
                      action: StudioDockReviewAction.reopen))),
            ] else if (!widget.isLiveSession)
              MapEntry('Toggle review mark', _toggleMarkedSelection),
            MapEntry('Reset workspace layout', _resetLayout),
            if (widget.onOpenAppSettings != null)
              MapEntry('Settings', () => unawaited(_switchSection(4))),
            if (widget.onOpenHelp != null)
              MapEntry('Help and documentation', () =>
                  unawaited(widget.onOpenHelp!())),
            MapEntry('Show Inspector: Text and Timing', () =>
                unawaited(_openInspectorTab(0))),
            MapEntry('Show Inspector: Style', () =>
                unawaited(_openInspectorTab(1))),
            MapEntry('Show Inspector: Notes', () =>
                unawaited(_openInspectorTab(2))),
          ];
          final filter = _commandSearch.text.trim().toLowerCase();
          final visible = commands.where((item) =>
              item.key.toLowerCase().contains(filter)).toList();
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  () => Navigator.of(dialogContext).pop(),
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  () => Navigator.of(dialogContext).pop(),
            },
            child: AlertDialog(
            title: const Text('Studio Dock commands'),
            content: SizedBox(
              width: 420,
              height: 300,
              child: Column(children: [
                TextField(
                  key: const ValueKey('palette-search'),
                  controller: _commandSearch,
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search commands',
                  ),
                  onChanged: (_) => refresh(() {}),
                ),
                Expanded(child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) => ListTile(
                    key: ValueKey('palette-command-' + i.toString()),
                    dense: true,
                    title: Text(visible[i].key),
                    trailing: _paletteShortcut(visible[i].key) == null
                        ? null
                        : Text(_paletteShortcut(visible[i].key)!,
                            key: ValueKey('palette-shortcut-${visible[i].key}'),
                            style: TextStyle(color: _muted, fontSize: 11,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      visible[i].value();
                    },
                  ),
                )),
              ]),
            ),
            ),
          );
        },
      ),
    );
  }

  String? _paletteShortcut(String command) {
    final primary = defaultTargetPlatform == TargetPlatform.macOS
        ? 'Cmd' : 'Ctrl';
    return switch (command) {
      'Find subtitle' || 'Replace subtitle text' => 'Ctrl+F',
      'Next line' => '$primary+.',
      'Previous line' => '$primary+,',
      'Undo subtitle edit' => '$primary+Z',
      'Redo subtitle edit' => '$primary+Shift+Z',
      'Toggle playback preview' =>
          defaultTargetPlatform == TargetPlatform.macOS
              ? 'Shift+Space' : 'Ctrl+Space',
      'Toggle review mark' => '$primary+M',
      'Settings' => 'Alt+S',
      'Help and documentation' =>
          defaultTargetPlatform == TargetPlatform.macOS
              ? 'Cmd+Shift+H' : 'Ctrl+H',
      _ => null,
    };
  }

  Widget _gridCells(StudioDockCue? cue) {
    final heading = cue == null;
    Text cell(String value, {bool primary = false}) => Text(
      value, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: heading ? 11 : 13,
        height: 1.2,
        color: heading ? _muted : primary
            ? Theme.of(context).colorScheme.onSurface : _muted),
    );
    return Row(children: [
      SizedBox(width: 30, child: cell(heading ? '#' : cue.id.toString())),
      SizedBox(width: 100, child: cell(heading ? 'START' : cue.start)),
      SizedBox(width: 100, child: cell(heading ? 'END' : cue.end)),
      SizedBox(width: 76, child: cell(heading
          ? 'DURATION' : _cueDuration(cue))),
      if (!widget.isEditMode)
        Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: cell(heading ? 'ORIGINAL' : cue.original, primary: true),
        )),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: cell(heading ? (widget.isEditMode ? 'SUBTITLE TEXT' : 'EDITED')
            : cue.edited, primary: true),
      )),
      SizedBox(width: 48, child: heading
          ? cell('STATUS')
          : cue.resolved
              ? Tooltip(message: 'Review resolved', child: Icon(
                  Icons.check_circle_outline, color: _accent, size: 16))
              : cue.marked
              ? Tooltip(message: 'Needs review', child: Icon(
                  Icons.bookmark_outline,
                  color: Theme.of(context).colorScheme.tertiary, size: 16))
              : cue.comment?.trim().isNotEmpty == true
              ? Tooltip(message: 'Comment without review mark', child: Icon(
                  Icons.chat_bubble_outline, color: _muted, size: 16))
              : const SizedBox.shrink()),
    ]);
  }

  String _cueDuration(StudioDockCue cue) {
    int parse(String value) {
      final parts = value.split(RegExp('[:,]'));
      if (parts.length != 4) return 0;
      final values = parts.map(int.tryParse).toList();
      if (values.any((element) => element == null)) return 0;
      return (values[0]! * 3600 + values[1]! * 60 + values[2]!) * 1000
          + values[3]!;
    }
    final millis = math.max(0, parse(cue.end) - parse(cue.start));
    return (millis / 1000).toStringAsFixed(3) + 's';
  }

  Widget _inspector() {
    const tabs = <String>['Text', 'Style', 'Notes'];
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _paneHeader(Icons.tune_outlined, 'LINE INSPECTOR',
            trailing: '#' + _selectedId.toString().padLeft(2, '0')),
        SizedBox(height: 38, child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(child: TextButton(
              key: ValueKey('inspector-tab-' + tabs[i]),
              onPressed: () => unawaited(_changeInspectorTab(i)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: _inspectorTab == i ? _accent : _muted,
                backgroundColor: _inspectorTab == i
                    ? _accent.withValues(alpha: .10) : Colors.transparent,
              ),
              child: Text(tabs[i],
                  style: const TextStyle(fontSize: 14)),
            )),
        ])),
        Expanded(child: ListView(
          key: ValueKey('inspector-page-' + _inspectorTab.toString()),
          padding: const EdgeInsets.all(8),
          children: _inspectorFields(),
        )),
        if (_inspectorTab == 0 &&
            (widget.onApplyCueText != null ||
                widget.onApplyCueTiming != null))
          Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
            decoration: BoxDecoration(border: Border(
              top: BorderSide(color: _border),
            )),
            child: Row(children: [
              Expanded(child: FilledButton.icon(
                key: const ValueKey('studio-apply-cue'),
                onPressed: _canApplyContentDraft
                    ? () => unawaited(_applyDraft()) : null,
                icon: const Icon(Icons.check, size: 16),
                label: Text(_savingDraft ? 'Applying…' : 'Apply changes'),
              )),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const ValueKey('studio-discard-cue'),
                onPressed: (_hasDirtyTextDraft || _hasDirtyOriginalDraft ||
                        _hasDirtyTimingDraft) &&
                        !_savingDraft ? _discardDraft : null,
                child: const Text('Discard'),
              ),
            ]),
          ),
      ]),
    );
  }

  List<Widget> _inspectorFields() {
    switch (_inspectorTab) {
      case 0:
        return [
          if (!widget.isEditMode && widget.showOriginalTextField) ...[
            Row(children: [
              Expanded(child: _fieldLabel('ORIGINAL TEXT')),
              if (widget.onApplyCueOriginal != null) IconButton(
                key: const ValueKey('studio-original-edit-toggle'),
                tooltip: _originalEditing
                    ? 'Save original text' : 'Edit original text',
                onPressed: _savingDraft ? null : () {
                  if (_originalEditing) {
                    if (_hasDirtyOriginalDraft) {
                      unawaited(_applyOriginalDraft());
                    } else {
                      setState(() => _originalEditing = false);
                    }
                  } else {
                    setState(() {
                      _originalEditing = true;
                      _formattedView = false;
                    });
                  }
                },
                icon: Icon(_originalEditing
                    ? Icons.check_rounded : Icons.edit_outlined, size: 18),
              ),
              IconButton(
                key: const ValueKey('studio-inspector-formatted-view'),
                tooltip: _formattedView ? 'Plain text view' : 'Formatted view',
                onPressed: _originalEditing ? null :
                    () => setState(() => _formattedView = !_formattedView),
                icon: Icon(Icons.code, size: 18,
                    color: _formattedView ? _accent : _muted),
              ),
              IconButton(
                key: const ValueKey('studio-inspector-paste-original'),
                tooltip: 'Paste original text',
                onPressed: widget.onApplyCueText != null && !_savingDraft
                    ? _pasteOriginalDraft
                    : widget.isLiveSession ? null : () => _replaceCue(
                        _selected.copyWith(edited: _selected.original)),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
              ),
            ]),
            SizedBox(
              height: 112,
              child: _originalEditing
                  ? TextFormField(
                      key: ValueKey('studio-original-$_selectedId-$_draftRevision'),
                      initialValue: _draftOriginalCueId == _selectedId &&
                              _draftOriginal != null
                          ? _draftOriginal : _selected.original,
                      enabled: !_savingDraft,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(8),
                      ),
                      contextMenuBuilder: (context, editable) =>
                          _studioTextContextMenu(context, editable,
                              original: true),
                      onChanged: (text) => setState(() {
                        _draftOriginalCueId = _selectedId;
                        _draftOriginal = text;
                      }),
                    )
                  : !_formattedView
                    ? TextFormField(
                        key: ValueKey('studio-original-readonly-$_selectedId'),
                        initialValue: _selected.original,
                        readOnly: true,
                        enableInteractiveSelection: true,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(8),
                        ),
                        contextMenuBuilder: (context, editable) =>
                            _studioTextContextMenu(context, editable,
                                original: true),
                      )
                  : Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: SingleChildScrollView(
                  child: SelectionArea(child: _formattedView
                      ? CustomHtmlText(
                          key: const ValueKey('studio-formatted-original'),
                          htmlContent: _selected.original.replaceAll('\n', '<br>'),
                          defaultStyle: const TextStyle(fontSize: 15, height: 1.5),
                        )
                      : Text(_selected.original,
                          style: const TextStyle(fontSize: 15, height: 1.5))),
                ),
              ),
            ),
            const SizedBox(height: 7),
          ],
          if (!widget.isEditMode && !widget.showOriginalTextField) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text('Original text is hidden',
                    style: TextStyle(color: _muted, fontSize: 13))),
                TextButton.icon(
                  key: const ValueKey('studio-show-original-text'),
                  onPressed: widget.onSaveEditPreference == null ||
                          _updatingEditPreference
                      ? null
                      : () => unawaited(_setEditPreference(
                          StudioDockEditPreference.showOriginalTextField)),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('Show original'),
                ),
              ]),
            ),
          ],
          _fieldLabel(widget.isEditMode ? 'SUBTITLE TEXT' : 'EDITED TEXT'),
          SizedBox(height: 112, child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                  () => unawaited(_applyDraftAndAdvance()),
            },
            child: TextFormField(
            focusNode: _cueTextFocus,
            autofocus: _focusEditorCueOnMount == _selectedId,
            key: widget.onApplyCueText == null
                ? ValueKey('desktop-edit-' + _selected.id.toString())
                : ValueKey('studio-edit-' + _selected.id.toString() +
                    '-' + _draftRevision.toString()),
            initialValue: _draftCueId == _selectedId && _draftText != null
                ? _draftText : _selected.edited,
            readOnly: _savingDraft ||
                (widget.isLiveSession && widget.onApplyCueText == null),
            expands: true,
            minLines: null, maxLines: null,
            style: const TextStyle(fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7)),
            ),
            contextMenuBuilder: (context, editable) =>
                _studioTextContextMenu(context, editable, original: false),
            onChanged: (value) {
              if (widget.onApplyCueText != null) {
                setState(() {
                  _draftCueId = _selectedId;
                  _draftText = value;
                });
              } else {
                _replaceCue(_selected.copyWith(edited: value));
              }
            },
            ),
          )),
          if (_formattedView) ...[
            const SizedBox(height: 8),
            _fieldLabel('FORMATTED PREVIEW · READ ONLY'),
            Container(
              key: const ValueKey('studio-formatted-preview'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: CustomHtmlText(
                htmlContent: (_draftCueId == _selectedId && _draftText != null
                    ? _draftText!
                    : _selected.edited)
                    .replaceAll('\n', '<br>'),
                defaultStyle: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 7),
          Divider(color: _border),
          const SizedBox(height: 3),
          _fieldLabel('TIMING'),
          const SizedBox(height: 3),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fieldLabel('START'),
                if (widget.onApplyCueTiming == null)
                  _readonlyField(_selected.start)
                else
                  TextFormField(
                    key: ValueKey('studio-timing-start-$_selectedId-$_draftRevision'),
                    initialValue: _timingStart,
                    enabled: !_savingDraft,
                    keyboardType: TextInputType.datetime,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 7, vertical: 12),
                    ),
                    onChanged: (value) => setState(() {
                      _durationError = null;
                      _durationFieldRevision++;
                      _draftTimingCueId = _selectedId;
                      _draftStart = value;
                    }),
                  ),
              ],
            )),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fieldLabel('END'),
                if (widget.onApplyCueTiming == null)
                  _readonlyField(_selected.end)
                else
                  TextFormField(
                    key: ValueKey('studio-timing-end-$_selectedId-$_draftRevision'
                        '${_timingFieldRevision == 0 ? '' : '-$_timingFieldRevision'}'),
                    initialValue: _timingEnd,
                    enabled: !_savingDraft,
                    keyboardType: TextInputType.datetime,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 7, vertical: 12),
                    ),
                    onChanged: (value) => setState(() {
                      _durationError = null;
                      _durationFieldRevision++;
                      _draftTimingCueId = _selectedId;
                      _draftEnd = value;
                    }),
                  ),
              ],
            )),
          ]),
          const SizedBox(height: 7),
          _fieldLabel('DURATION'),
          if (widget.onApplyCueTiming == null)
            _readonlyField(_cueDuration(_selected.copyWith(
              start: _timingStart, end: _timingEnd)))
          else
            TextFormField(
              key: ValueKey('studio-timing-duration-$_selectedId-$_draftRevision-$_durationFieldRevision'),
              initialValue: _cueDuration(_selected.copyWith(
                  start: _timingStart, end: _timingEnd)).replaceAll('s', ''),
              enabled: !_savingDraft,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                suffixText: 'seconds',
                hintText: '1.500',
              ),
              onChanged: (value) {
                final result = StudioDockTimingEditService.endFromDuration(
                    _timingStart, value);
                setState(() {
                  // Even an invalid duration is an unsaved form edit: it must
                  // be fixed or explicitly discarded before changing cues.
                  _draftTimingCueId = _selectedId;
                  _durationError = result.error;
                  if (result.endMilliseconds != null) {
                    _timingFieldRevision++;
                    _draftEnd = _formatCueTime(result.endMilliseconds!);
                  }
                });
              },
            ),
          const SizedBox(height: 7),
          if (widget.onApplyCueTiming != null && _timingError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_timingError!,
                key: const ValueKey('studio-timing-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error,
                    fontSize: 12)),
            ),
        ];
      case 1:
        return [
          _fieldLabel('TEXT FORMATTING'),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final (tag, label, icon) in const [
              ('b', 'Bold', Icons.format_bold),
              ('i', 'Italic', Icons.format_italic),
              ('u', 'Underline', Icons.format_underline),
            ])
              OutlinedButton.icon(
                key: ValueKey('studio-style-$tag'),
                onPressed: widget.onApplyCueText != null && !_savingDraft
                    ? () => _toggleStyleTag(tag) : null,
                icon: Icon(icon, size: 16),
                label: Text(label, style: const TextStyle(fontSize: 13)),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              key: const ValueKey('studio-style-color'),
              onPressed: widget.onApplyCueText != null && !_savingDraft
                  ? () => unawaited(_pickStyleColor()) : null,
              icon: const Icon(Icons.palette_outlined, size: 16),
              label: const Text('Text color'),
            )),
            const SizedBox(width: 6),
            OutlinedButton(
              key: const ValueKey('studio-style-clear'),
              onPressed: widget.onApplyCueText != null && !_savingDraft
                  ? () => _setStyleDraft(
                      StudioDockStyleActions.clearSupportedTags(_styleText))
                  : null,
              child: const Text('Clear tags'),
            ),
          ]),
          const SizedBox(height: 20),
          _fieldLabel('POSITION'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 2.1,
            children: [
              for (final (code, label, symbol) in const [
                (7, 'Top left', '↖'), (8, 'Top center', '↑'),
                (9, 'Top right', '↗'), (4, 'Middle left', '←'),
                (5, 'Center', '•'), (6, 'Middle right', '→'),
                (1, 'Bottom left', '↙'), (2, 'Bottom center', '↓'),
                (3, 'Bottom right', '↘'),
              ])
                Tooltip(
                  message: label,
                  child: OutlinedButton(
                    key: ValueKey('studio-style-align-$code'),
                    onPressed: widget.onApplyCueText != null && !_savingDraft
                        ? () => _setStyleDraft(
                            StudioDockStyleActions.setAlignment(_styleText, code))
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: StudioDockStyleActions.alignment(
                                  _styleText) == code
                          ? _accent.withValues(alpha: .14) : null,
                    ),
                    child: Text(symbol, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _fieldLabel('DRAFT PREVIEW'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: CustomHtmlText(
              htmlContent: StudioDockStyleActions.body(
                  _styleText).replaceAll('\n', '<br>'),
              defaultStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 9),
          SelectableText(_styleText, style: TextStyle(
            fontFamily: 'monospace', fontSize: 13, color: _muted)),
          const SizedBox(height: 13),
          if (widget.onApplyCueText != null) Row(children: [
            Expanded(child: FilledButton.icon(
              key: const ValueKey('studio-apply-style'),
              onPressed: _hasDirtyTextDraft && !_savingDraft
                  ? () => unawaited(_applyDraft()) : null,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Apply style'),
            )),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey('studio-discard-style'),
              onPressed: _hasDirtyTextDraft && !_savingDraft
                  ? _discardDraft : null,
              child: const Text('Discard'),
            ),
          ]),
        ];
      default:
        return [
          _fieldLabel('REVIEW NOTES'),
          Text(_noteMarked
              ? (_noteResolved
                  ? 'Review resolved · mark and comments are kept.'
                  : 'Review unresolved · this subtitle needs attention.')
              : 'No review mark on this subtitle.',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          if (widget.onApplyCueNotes != null) ...[
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                key: const ValueKey('studio-notes-mark'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark for review'),
                value: _noteMarked,
                onChanged: _savingDraft ? null : (marked) => setState(() {
                  _draftNotesCueId = _selectedId;
                  _draftMarked = marked;
                  if (!marked) {
                    _draftNoteText = '';
                    _draftResolved = false;
                    _draftRevision++;
                  }
                }),
              ),
            ),
            const SizedBox(height: 12),
            _fieldLabel('COMMENT'),
            TextFormField(
              key: ValueKey('studio-notes-comment-$_selectedId-$_draftRevision'),
              initialValue: _noteText,
              enabled: !_savingDraft,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Add a note or reference for this subtitle',
              ),
              onChanged: (value) => setState(() {
                _draftNotesCueId = _selectedId;
                _draftNoteText = value;
                if (value.trim().isNotEmpty) _draftMarked = true;
              }),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                key: const ValueKey('studio-notes-resolved'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Review resolved'),
                value: _noteResolved,
                onChanged: _savingDraft || !_noteMarked ? null
                    : (resolved) => setState(() {
                        _draftNotesCueId = _selectedId;
                        _draftResolved = resolved;
                      }),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton.icon(
                key: const ValueKey('studio-apply-notes'),
                onPressed: _hasDirtyNotesDraft && !_savingDraft
                    ? () => unawaited(_applyDraft()) : null,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Apply notes'),
              )),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const ValueKey('studio-discard-notes'),
                onPressed: _hasDirtyNotesDraft && !_savingDraft
                    ? _discardDraft : null,
                child: const Text('Discard'),
              ),
            ]),
          ] else ...[
            if (!widget.isLiveSession)
              OutlinedButton.icon(
                key: const ValueKey('desktop-mark-cue'),
                onPressed: () => _replaceCue(_selected.copyWith(
                    marked: !_selected.marked)),
                icon: Icon(_selected.marked
                    ? Icons.bookmark : Icons.bookmark_outline, size: 15),
                label: Text(_selected.marked ? 'Unmark' : 'Mark for review'),
              ),
            const SizedBox(height: 15),
            _fieldLabel('COMMENT'),
            Text(_selected.comment?.isNotEmpty == true
                ? _selected.comment! : 'No comment on this subtitle.',
                style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 12),
            Text(_selected.resolved ? 'Review resolved' : 'Review unresolved',
                style: TextStyle(fontSize: 12, color: _muted)),
          ],
        ];
    }
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: TextStyle(
      color: _muted, fontSize: 12, letterSpacing: .5,
      fontWeight: FontWeight.w600)),
  );
  Widget _readonlyField(String text) => Container(
    padding: EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(text, style: const TextStyle(
      fontSize: 14, fontFeatures: [FontFeature.tabularFigures()])),
  );

  Widget _secondarySection() {
    if (_section == 5) return _sourceViewSection();
    if (_section == 1 &&
        (widget.onLoadHistory != null || widget.checkpointHistoryPanel != null)) {
      return _historySection();
    }
    if (_section == 2) return _findSection();
    if (_section == 3) return _toolsSection();
    const screens = ['Editor', 'Version history', 'Search', 'Tools', 'Settings'];
    const descriptions = [
      '',
      'Visual Git-style history will reuse the shared checkpoint repository.',
      'Cross-project and in-project subtitle search will use the shared search services.',
      'Timing, formatting, encoding and audio tools will use shared commands.',
      'Desktop appearance and shortcuts will reuse app preferences.',
    ];
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 470),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon([Icons.movie_creation_outlined, Icons.account_tree_outlined,
          Icons.search, Icons.tune, Icons.settings][_section],
          color: _accent, size: 38),
        const SizedBox(height: 14),
        Text(screens[_section], style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 9),
        Text(descriptions[_section], textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.6)),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: () =>
            unawaited(_switchSection(0)), child: const Text('Back to editor')),
      ]),
    ));
  }

  Widget _findSection() => Padding(
    key: const ValueKey('studio-find-section'),
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.search, color: _accent),
        const SizedBox(width: 11),
        const Text('Find and replace', style: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${_findResults.length} matches',
            style: TextStyle(color: _muted, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      Text('Search the effective subtitle text in this project. '
          'Replacement is saved as one undoable history point.',
          style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 13),
      TextField(
        key: const ValueKey('studio-find-input'),
        controller: _findInput,
        focusNode: _findFocus,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search), labelText: 'Find text',
          border: OutlineInputBorder(), isDense: true,
        ),
        onChanged: (_) => _invalidateFind(),
        onSubmitted: (_) => _runFind(),
      ),
      const SizedBox(height: 9),
      Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
        FilterChip(
          key: const ValueKey('studio-find-case'),
          label: const Text('Case sensitive'),
          selected: _findCaseSensitive,
          onSelected: (value) {
            setState(() => _findCaseSensitive = value);
            _invalidateFind();
          },
        ),
        FilterChip(
          key: const ValueKey('studio-find-word'),
          label: const Text('Whole word'),
          selected: _findWholeWord,
          onSelected: (value) {
            setState(() => _findWholeWord = value);
            _invalidateFind();
          },
        ),
        FilledButton.icon(
          key: const ValueKey('studio-find-run'),
          onPressed: _findInput.text.trim().isNotEmpty && !_replacingMatches
              ? _runFind : null,
          icon: const Icon(Icons.search, size: 17),
          label: const Text('Find'),
        ),
      ]),
      const SizedBox(height: 11),
      if (widget.onReplaceMatches != null) ...[
        TextField(
          key: const ValueKey('studio-replace-input'),
          controller: _replaceInput,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.find_replace), labelText: 'Replace with',
            border: OutlineInputBorder(), isDense: true,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(
            key: const ValueKey('studio-replace-selected'),
            onPressed: _selectedFindResults.isNotEmpty && !_replacingMatches
                ? () => unawaited(_replaceFound(selectedOnly: true)) : null,
            icon: const Icon(Icons.checklist, size: 17),
            label: Text('Replace selected (${_selectedFindResults.length})'),
          ),
          FilledButton.icon(
            key: const ValueKey('studio-replace-all'),
            onPressed: _findResults.isNotEmpty && !_replacingMatches
                ? () => unawaited(_replaceFound(selectedOnly: false)) : null,
            icon: const Icon(Icons.done_all, size: 17),
            label: const Text('Replace all matches'),
          ),
        ]),
      ],
      if (_replacingMatches) const LinearProgressIndicator(),
      if (_findError != null) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_findError!, style: TextStyle(
            color: Theme.of(context).colorScheme.error)),
      ),
      const SizedBox(height: 12),
      Expanded(child: Card(
        clipBehavior: Clip.antiAlias,
        child: !_searched
            ? Center(child: Text(widget.onFindCues == null
                ? 'Open a subtitle project to search its contents.'
                : 'Enter text and choose Find to see matching subtitles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted)))
            : _findResults.isEmpty
                ? Center(child: Text('No matching subtitles.',
                    style: TextStyle(color: _muted)))
                : ListView.builder(
                    key: const ValueKey('studio-find-results'),
                    itemCount: _findResults.length,
                    itemBuilder: (context, index) {
                      final hit = _findResults[index];
                      return ListTile(
                        key: ValueKey('studio-find-hit-$index'),
                        dense: true,
                        leading: widget.onReplaceMatches == null
                            ? const Icon(Icons.subtitles_outlined)
                            : Checkbox(
                                key: ValueKey('studio-find-select-$index'),
                                value: _selectedFindResults.contains(index),
                                onChanged: _replacingMatches ? null : (checked) =>
                                    setState(() {
                                      if (checked == true) {
                                        _selectedFindResults.add(index);
                                      } else {
                                        _selectedFindResults.remove(index);
                                      }
                                    }),
                              ),
                        title: Text('Subtitle #${hit.cueNumber} '
                            '· characters ${hit.start + 1}–${hit.end}'),
                        subtitle: Text(hit.content.replaceAll('\n', ' ↵ '),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 13),
                        onTap: () => unawaited(_openSearchHit(hit)),
                      );
                    },
                  ),
      )),
    ]),
  );

  Widget _toolsSection() {
    final delta = int.tryParse(_shiftMillisecondsInput.text.trim()) ?? 0;
    final canEdit = !_runningTool && _cues.isNotEmpty;
    return Padding(
      key: const ValueKey('studio-tools-section'),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: ListView(children: [
        Row(children: [
          Icon(Icons.tune_rounded, color: _accent),
          const SizedBox(width: 11),
          const Text('Subtitle tools', style: TextStyle(
              fontSize: 21, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text('Batch operations use the project’s shared checkpoint history. '
            'They do not write the external SRT until you choose Save.',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 18),
        if (widget.onSyncAnchoredCues != null) ...[
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subtitle Synchronization',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                Text('Match the mobile first/last timecode anchors, or '
                    'convert framerates when a video is loaded. Both use '
                    'editing history and preserve subtitle text.',
                    style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const ValueKey('studio-tool-sync-anchors'),
                    onPressed: canEdit
                        ? () => unawaited(_syncAnchoredSafely()) : null,
                    icon: const Icon(Icons.sync, size: 17),
                    label: const Text('Sync by first/last timecodes'),
                  ),
                  if (widget.onConvertFramerate != null)
                    OutlinedButton.icon(
                      key: const ValueKey('studio-tool-sync-fps'),
                      onPressed: canEdit && widget.videoSurface != null
                          ? () => unawaited(_convertFramerateSafely()) : null,
                      icon: const Icon(Icons.speed, size: 17),
                      label: const Text('Adjust framerate'),
                    ),
                ]),
                if (widget.videoSurface == null)
                  Padding(padding: const EdgeInsets.only(top: 8),
                    child: Text('Attach a video to enable framerate conversion.',
                        style: TextStyle(color: _muted, fontSize: 12))),
              ],
            ),
          )),
          const SizedBox(height: 12),
        ],
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Shift all subtitle timecodes', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 7),
            Text('Positive milliseconds delay every subtitle; negative '
                'milliseconds move them earlier. Durations stay unchanged.',
                style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: TextField(
                key: const ValueKey('studio-tool-shift-input'),
                controller: _shiftMillisecondsInput,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true),
                decoration: const InputDecoration(
                  labelText: 'Milliseconds (+ or −)',
                  border: OutlineInputBorder(), isDense: true,
                ),
                onChanged: (_) => setState(() => _toolsError = null),
              ),
            ),
            const SizedBox(height: 11),
            FilledButton.icon(
              key: const ValueKey('studio-tool-shift'),
              onPressed: widget.onShiftAllCues != null && canEdit &&
                      delta != 0
                  ? () => unawaited(_runBulkTool(
                      title: 'Shift all subtitles',
                      detail: 'Shift ${_cues.length} subtitles by '
                          '$delta milliseconds?',
                      apply: () => widget.onShiftAllCues!(_selectedId, delta)))
                  : null,
              icon: const Icon(Icons.more_time, size: 17),
              label: const Text('Apply time shift'),
            ),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Clear supported subtitle formatting',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 7),
            Text('Remove bold, italic, underline, font color and nine-grid '
                'alignment tags. Original text and review notes are kept.',
                style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 11),
            OutlinedButton.icon(
              key: const ValueKey('studio-tool-clear-formatting'),
              onPressed: widget.onClearAllFormatting != null && canEdit
                  ? () => unawaited(_runBulkTool(
                      title: 'Clear subtitle formatting',
                      detail: 'Remove supported style tags from this '
                          'project’s edited subtitles?',
                      apply: () => widget.onClearAllFormatting!(_selectedId)))
                  : null,
              icon: const Icon(Icons.format_clear, size: 17),
              label: const Text('Clear formatting tags'),
            ),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Selected subtitle operations', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 7),
            Text('${_selectedIds.length} of ${_cues.length} subtitles selected. '
                'Use Ctrl/Cmd-click, Shift-click, indices or range selection.',
                style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                key: const ValueKey('studio-tool-select-indices'),
                onPressed: _cues.isEmpty ? null :
                    () => unawaited(_selectByIndexSafely()),
                icon: const Icon(Icons.format_list_numbered, size: 17),
                label: const Text('Select by index'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('studio-tool-select-range'),
                onPressed: _cues.isEmpty ? null : _toggleRangeSelectionMode,
                icon: const Icon(Icons.select_all, size: 17),
                label: Text(_rangeSelectionMode
                    ? 'Cancel range selection' : 'Range selection'),
              ),
              if (widget.onShiftSelectedCues != null)
                FilledButton.icon(
                  key: const ValueKey('studio-tool-shift-selected'),
                  onPressed: _selectedIds.isEmpty || _runningSelectedBatch
                      ? null : () => unawaited(_shiftSelectedSafely()),
                  icon: const Icon(Icons.more_time, size: 17),
                  label: const Text('Shift selected'),
                ),
              if (widget.onDeleteSelectedCues != null)
                OutlinedButton.icon(
                  key: const ValueKey('studio-tool-delete-selected'),
                  onPressed: _selectedIds.isEmpty || _runningSelectedBatch
                      ? null : () => unawaited(_deleteSelectedSafely()),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('Delete selected'),
                ),
            ]),
          ]),
        )),
        if (widget.onRemoveHearingImpaired != null) ...[
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hearing-impaired annotation cleanup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                Text('Clean descriptions, effects, and speaker labels from '
                    'source text. Empty lines may be deleted. Surviving '
                    'translations and review notes remain; Undo is available '
                    'in editing history.',
                    style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('studio-tool-hearing-cleanup'),
                  onPressed: !_runningTool && !_openingHearingCleanup &&
                          _cues.isNotEmpty
                      ? () => unawaited(_removeHearingSafely()) : null,
                  icon: const Icon(Icons.hearing_disabled, size: 17),
                  label: const Text('Remove Hearing Impaired'),
                ),
              ],
            ),
          )),
        ],
        if (widget.onImportComments != null) ...[
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Project review annotations', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                Text('Import comments and marked/resolved status from an '
                    'existing .msone project by subtitle line number. '
                    'Changes are saved to editing history.',
                    style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('studio-tool-import-comments'),
                  onPressed: _openingCommentImport || _cues.isEmpty
                      ? null : () => unawaited(_importCommentsSafely()),
                  icon: const Icon(Icons.comment_outlined, size: 17),
                  label: const Text('Import Comments (.msone)'),
                ),
              ],
            ),
          )),
        ],
        if (widget.onInsertMsoneBanners != null ||
            widget.onNormalizeMalayalam != null) ...[
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MSone subtitle tools',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                Text('Use the original mobile banner editor and Malayalam '
                    'normalization preview. Both preserve checkpoint history.',
                    style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  if (widget.onInsertMsoneBanners != null)
                    OutlinedButton.icon(
                      key: const ValueKey('studio-tool-msone-banners'),
                      onPressed: _openingMsoneTools || _cues.isEmpty
                          ? null : () => unawaited(_openMsoneToolSafely(
                              widget.onInsertMsoneBanners,
                              name: 'MSone banner configuration')),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                      label: const Text('Insert Banners'),
                    ),
                  if (widget.onNormalizeMalayalam != null)
                    OutlinedButton.icon(
                      key: const ValueKey('studio-tool-msone-normalize'),
                      onPressed: _openingMsoneTools || _cues.isEmpty
                          ? null : () => unawaited(_openMsoneToolSafely(
                              widget.onNormalizeMalayalam,
                              name: 'Malayalam normalization')),
                      icon: const Icon(Icons.translate, size: 17),
                      label: const Text('Malayalam Normalize'),
                    ),
                ]),
              ],
            ),
          )),
        ],
        if (_runningTool) const LinearProgressIndicator(),
        if (_toolsError != null) Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_toolsError!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
        ),
        if (widget.onShiftAllCues == null &&
            widget.onSyncAnchoredCues == null &&
            widget.onConvertFramerate == null &&
            widget.onClearAllFormatting == null &&
            widget.onImportComments == null &&
            widget.onRemoveHearingImpaired == null &&
            widget.onInsertMsoneBanners == null &&
            widget.onNormalizeMalayalam == null)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Tools are read-only for this session.',
                style: TextStyle(color: _muted)),
          ),
      ]),
    );
  }

  Widget _sourceViewSection() => Padding(
    key: const ValueKey('studio-source-view'),
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.code_rounded, color: _accent),
        const SizedBox(width: 10),
        const Text('Source View', style: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_sourceDirty)
          Text('Unsaved source changes', style: TextStyle(
              color: Theme.of(context).colorScheme.error, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      Text('Edit the raw SRT document. Apply records one saved history point.',
        style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 14),
      if (_sourceSaving || _sourceLoading) const LinearProgressIndicator(),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: _border)),
          child: widget.onApplySourceView == null
              ? SingleChildScrollView(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(_sourceText, style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 14, height: 1.4)),
                ))
              : RawSrtEditor(
                  key: const ValueKey('studio-source-editor'),
                  initialText: _sourceText,
                  onChanged: (value) => setState(() {
                    _sourceText = value;
                    _sourceError = null;
                  }),
                ),
        ),
      )),
      if (_sourceError != null) Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(_sourceError!, style: TextStyle(
            color: Theme.of(context).colorScheme.error, fontSize: 12)),
      ),
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton.icon(
          onPressed: () => unawaited(_switchSection(0)),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to editor'),
        ),
        const Spacer(),
        if (widget.onApplySourceView != null) ...[
          OutlinedButton(
            key: const ValueKey('studio-source-discard'),
            onPressed: _sourceDirty && !_sourceSaving
                ? _discardSourceDraft : null,
            child: const Text('Discard changes'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const ValueKey('studio-source-apply'),
            onPressed: _sourceDirty && !_sourceSaving
                ? () => unawaited(_applySourceView()) : null,
            icon: const Icon(Icons.check),
            label: const Text('Apply source'),
          ),
        ],
      ]),
    ]),
  );

  Future<void> _confirmRestorePoint(HistoryGraphNode node) async {
    if (node.isHead || _historyNavigationBlocked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => _modalKeys<bool>(dialog,
        confirm: true, cancel: false, child: AlertDialog(
        title: const Text('Restore this saved version?'),
        content: const Text('The subtitles will return to this history '
            'point. Other saved versions will remain in history. '
            'New edits can continue from the restored point.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('studio-history-confirm-restore'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restore version'),
          ),
        ],
      )),
    );
    if (confirmed == true && mounted) {
      await _restoreHistoryPoint(node.checkpointId);
    }
  }

  Widget _historySection() {
    if (widget.checkpointHistoryPanel != null) {
      return widget.checkpointHistoryPanel!;
    }
    final graph = _history;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history, color: _accent),
          const SizedBox(width: 12),
          const Text('Editing history', style: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            key: const ValueKey('studio-history-refresh'),
            tooltip: 'Refresh history',
            icon: const Icon(Icons.refresh),
            onPressed: _historyNavigationBlocked ? null
                : () => unawaited(_reloadHistory()),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Restore a saved version without deleting later edits.',
          style: TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 16),
        if (_historyLoading || _historyBusy)
          const LinearProgressIndicator(),
        if (_historyError != null)
          Padding(padding: const EdgeInsets.all(12),
              child: Text(_historyError!, style: TextStyle(
                color: Theme.of(context).colorScheme.error))),
        Expanded(child: graph == null || graph.nodes.isEmpty
            ? Center(child: Text(_historyLoading
                ? 'Loading editing history…' : 'No saved history points yet.',
                style: TextStyle(color: _muted)))
            : ListView.builder(
                key: const ValueKey('studio-history-list'),
                itemCount: graph.newestFirst.length,
                itemBuilder: (context, index) {
                  final node = graph.newestFirst[index];
                  return Card(
                    key: ValueKey('studio-history-point-${node.checkpointId}'),
                    child: ListTile(
                      leading: Icon(node.isHead ? Icons.radio_button_checked
                          : Icons.history_toggle_off,
                          color: node.isHead ? _accent : _muted),
                      title: Text(CheckpointHistoryLabels.entryTitle(
                        operationType: node.operationType,
                        description: node.description,
                      )),
                      subtitle: Text(CheckpointHistoryLabels.versionDetails(node)),
                      trailing: node.isHead
                          ? const Text('Current version')
                          : OutlinedButton(
                              key: ValueKey('studio-history-restore-${node.checkpointId}'),
                              onPressed: _historyNavigationBlocked ? null
                                  : () => unawaited(_confirmRestorePoint(node)),
                              child: const Text('Restore'),
                            ),
                    ),
                  );
                },
              )),
      ]),
    );
  }

  Widget _statusBar() => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(border:
        Border(top: BorderSide(color: _border))),
    child: Row(children: [
      Icon(Icons.info_outline, color: _accent, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(widget.projectTitle ?? 'Ready',
        style: TextStyle(color: _muted, fontSize: 12))),
      Text(widget.encoding == null
          ? 'Desktop prototype  •  Windows / macOS / Linux'
          : 'Encoding: ' + widget.encoding!,
        style: TextStyle(color: _muted, fontSize: 12)),
    ]),
  );
}

/// A schematic video backdrop: no user video, no downloaded imagery.
class _DemoHorizonPainter extends CustomPainter {
  const _DemoHorizonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final road = Path()
      ..moveTo(size.width * .44, size.height * .66)
      ..lineTo(size.width * .56, size.height * .66)
      ..lineTo(size.width * .92, size.height)
      ..lineTo(size.width * .08, size.height)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF172029));
    canvas.drawLine(Offset(0, size.height * .67),
      Offset(size.width, size.height * .67),
      Paint()..color = const Color(0xFF445562)..strokeWidth = 1);
    final centerLine = Path()
      ..moveTo(size.width * .5, size.height * .7)
      ..lineTo(size.width * .5, size.height * .77);
    canvas.drawPath(centerLine, Paint()
      ..color = const Color(0xFFE9C46A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(_DemoHorizonPainter oldDelegate) => false;
}

class _DemoWaveformPainter extends CustomPainter {
  const _DemoWaveformPainter({required this.cueIndex, required this.accent});
  final int cueIndex;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = size.height * .55;
    final stroke = Paint()..strokeWidth = 1.5..color = accent;
    for (double x = 1; x < size.width; x += 3.6) {
      final wave = math.sin(x * .088) * math.sin(x * .23) +
          math.sin(x * .41) * .34;
      final amplitude = (wave.abs() * .45 + .08) * size.height * .55;
      canvas.drawLine(Offset(x, center - amplitude / 2),
        Offset(x, center + amplitude / 2), stroke);
    }
    final cursor = (cueIndex / 13) * size.width;
    canvas.drawLine(Offset(cursor, 0), Offset(cursor, size.height),
      Paint()..color = const Color(0xFFE9C46A)..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(_DemoWaveformPainter old) =>
      cueIndex != old.cueIndex || accent != old.accent;
}
