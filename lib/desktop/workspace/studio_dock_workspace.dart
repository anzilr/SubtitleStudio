import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subtitle_studio/screens/edit/services/raw_srt_document.dart';
import 'package:subtitle_studio/screens/edit/widgets/source_view_pane.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';
import 'package:subtitle_studio/utils/time_input_formatter.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_history_labels.dart';
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
import 'studio_dock_bulk_review_service.dart';
import '../../utils/msone_hotkey_manager.dart';

enum _StudioDockReviewFilter { all, marked, unresolved, resolved }

enum _StudioDockMenuAction {
  undo, redo, find, copySelected, selectAll, addCue, deleteCue, splitCue, mergeCue, notes,
  timing, shiftTools, showTools, sourceView, history, submitMsone,
  loadSecondary, toggleSecondary,
  shiftSelected, deleteSelected, selectByIndex, rangeSelection, goToLine,
  importComments,
  explorer, inspector, settings, help,
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
    String? start, String? end, String? edited, bool? marked,
    String? comment, bool clearComment = false, bool? resolved,
  }) =>
      StudioDockCue(
        id: id, start: start ?? this.start, end: end ?? this.end,
        original: original,
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
    this.projectTitle,
    this.encoding,
    this.onChooseProject,
    this.onImportFile,
    this.onNewProject,
    this.onApplyCueText,
    this.onApplyCueTiming,
    this.onApplyCueTextAndTiming,
    this.onApplyCueNotes,
    this.onApplyBulkReview,
    this.onFindCues,
    this.onReplaceMatches,
    this.onShiftAllCues,
    this.onShiftSelectedCues,
    this.onDeleteSelectedCues,
    this.onClearAllFormatting,
    this.onInsertCue,
    this.onDeleteCue,
    this.onSplitCue,
    this.onMergeCue,
    this.onLoadHistory,
    this.onRestoreHistory,
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
    this.onOpenAppSettings,
    this.onOpenProjectSettings,
    this.onImportComments,
    this.onOpenHelp,
    this.onSubmitToMsone,
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
  final String? projectTitle;
  final String? encoding;
  final VoidCallback? onChooseProject;
  final VoidCallback? onImportFile;
  final VoidCallback? onNewProject;
  /// Non-null only when the production checkpoint-backed edit bridge is ready.
  final Future<bool> Function(int cueNumber, String editedText)? onApplyCueText;
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
  final Future<StudioDockCueUpdate?> Function(
      int selectedCueNumber, int deltaMilliseconds)? onShiftAllCues;
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
  /// Opens the production shared SettingsSheet instead of a parallel desktop
  /// preferences implementation. The host owns provider-dependent UI.
  final Future<void> Function()? onOpenAppSettings;
  /// Hosts the existing ProjectSettingsSheet on native desktop. The live
  /// session refreshes paths, encoding, cues and history when it closes.
  final Future<void> Function()? onOpenProjectSettings;
  /// Opens the mobile project's .msone comment importer in a native desktop
  /// dialog and refreshes the shared checkpoint-backed session afterward.
  final Future<void> Function()? onImportComments;
  /// Opens the existing HelpScreen, shared with the mobile editor.
  final Future<void> Function()? onOpenHelp;
  /// Opens the established MSone submission flow after the current draft is
  /// resolved. The host checks the persisted MSone-features preference.
  final Future<void> Function()? onSubmitToMsone;
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
  bool _openingProjectSettings = false;
  bool _openingCommentImport = false;
  ModalRoute<dynamic>? _msoneMenuRoute;
  ModalRoute<dynamic>? _secondaryMenuRoute;
  ModalRoute<dynamic>? _projectSettingsMenuRoute;
  ModalRoute<dynamic>? _commentsMenuRoute;
  String? _findError;
  String? _toolsError;
  int _section = 0;
  bool _playing = false;
  bool _inspectorOpen = true;
  bool _explorerOpen = true;
  bool _explorerOverlayOpen = false;
  bool _inspectorOverlayOpen = false;
  int _inspectorTab = 0;
  double _videoShare = .38;
  double _waveformShare = .24;
  String _query = '';
  _StudioDockReviewFilter _reviewFilter = _StudioDockReviewFilter.all;
  int? _draftCueId;
  String? _draftText;
  int? _draftTimingCueId;
  String? _draftStart;
  String? _draftEnd;
  int? _draftNotesCueId;
  String? _draftNoteText;
  bool? _draftMarked;
  bool? _draftResolved;
  int _draftRevision = 0;
  bool _savingDraft = false;
  bool _changingStructure = false;
  bool _savingFile = false;
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


  static const _managedActions = <HotkeyAction>[
    HotkeyAction.nextLine,
    HotkeyAction.previousLine,
    HotkeyAction.playPause,
    HotkeyAction.findReplace,
    HotkeyAction.gotoLine,
    HotkeyAction.markLine,
    HotkeyAction.splitLine,
    HotkeyAction.mergeLine,
    HotkeyAction.save,
    HotkeyAction.saveAs,
  ];

  bool _allowedLiveHotkey(HotkeyAction action) =>
      action == HotkeyAction.nextLine ||
      action == HotkeyAction.previousLine ||
      action == HotkeyAction.findReplace ||
      action == HotkeyAction.gotoLine ||
      action == HotkeyAction.markLine && widget.onApplyBulkReview != null ||
      action == HotkeyAction.splitLine && widget.onSplitCue != null ||
      action == HotkeyAction.mergeLine && widget.onMergeCue != null ||
      action == HotkeyAction.save && widget.onSaveFile != null ||
      action == HotkeyAction.saveAs && widget.onSaveAsFile != null;

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
        if (mounted && (!_isEditingText ||
            action == HotkeyAction.save || action == HotkeyAction.saveAs)) {
          _dispatchManagedAction(action);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant StudioDockWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      final target = (index * 40.0 - _cueScroll.position.viewportDimension / 2 + 20)
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
      _videoShare = .38;
      _waveformShare = .24;
      _explorerOpen = true;
      _inspectorOpen = true;
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

  void _dispatchManagedAction(HotkeyAction action) {
    switch (action) {
      case HotkeyAction.nextLine:
        _selectRelative(1);
      case HotkeyAction.previousLine:
        _selectRelative(-1);
      case HotkeyAction.playPause:
        if (!widget.isLiveSession) {
          setState(() => _playing = !_playing);
        }
      case HotkeyAction.findReplace:
        unawaited(_openFind());
      case HotkeyAction.gotoLine:
        unawaited(_goToLineSafely());
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
        builder: (dialog) => AlertDialog(
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
        ),
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
       _draftEnd != null && _draftEnd != _selected.end);

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
      _hasDirtyNotesDraft;

  bool get _canApplyContentDraft =>
      (_hasDirtyTextDraft || _hasDirtyTimingDraft) &&
      (!_hasDirtyTextDraft || !_hasDirtyTimingDraft ||
          widget.onApplyCueTextAndTiming != null) &&
      !_savingDraft && !_savingFile &&
      (!_hasDirtyTimingDraft || _timingError == null);

  String get _timingStart => _draftTimingCueId == _selectedId
      ? _draftStart ?? _selected.start : _selected.start;
  String get _timingEnd => _draftTimingCueId == _selectedId
      ? _draftEnd ?? _selected.end : _selected.end;
  String? get _timingError =>
      StudioDockTimingEditService.validate(_timingStart, _timingEnd);

  String get _styleText => _draftCueId == _selectedId && _draftText != null
      ? _draftText!
      : _selected.edited.isNotEmpty ? _selected.edited : _selected.original;

  void _setStyleDraft(String text) {
    if (widget.onApplyCueText == null || _savingDraft) return;
    setState(() {
      _draftCueId = _selectedId;
      _draftText = text;
    });
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
      _draftTimingCueId = null;
      _draftStart = null;
      _draftEnd = null;
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved subtitle edit'),
        content: const Text('Apply this cue edit before leaving it?'),
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
      ),
    );
    if (!mounted) return false;
    if (choice == 'discard') {
      _discardDraft();
      return true;
    }
    if (choice == 'apply') return _applyDraft();
    return false;
  }

  Future<bool> _confirmSourceDraftBeforeLeaving() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
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
      ),
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

  Future<void> _chooseProjectSafely() async {
    if (await _confirmDraftBeforeLeaving() && mounted) {
      widget.onChooseProject?.call();
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
      _draftNotesCueId = null;
      _draftNoteText = null;
      _draftMarked = null;
      _draftResolved = null;
      _draftRevision++;
    });
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
      final target = (index * 40.0 - _cueScroll.position.viewportDimension / 2 + 20)
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
      builder: (dialog) => AlertDialog(
        title: Text('Delete subtitle cue #$cueNumber?'),
        content: const Text('This removes the selected cue from the project. '
            'The change will be recorded in checkpoint history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('studio-confirm-delete'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete cue'),
          ),
        ],
      ),
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
          content: Text('Could not delete this cue. The project may have '
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
      builder: (dialog) => AlertDialog(
        title: Text('Combine subtitle cue #$cueNumber'),
        content: Text('Choose an adjacent cue to combine. '
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
      ),
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
          content: Text('Could not combine the cues. The project may have '
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
      builder: (dialog) => AlertDialog(
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
      ),
    );
    if (originalOnly == null || !mounted) return;
    await _runFileAction(
      () => widget.onExportFile!(originalOnly), draftAlreadyHandled: true);
  }


  Future<void> _selectCueAfterConfirmation(int id,
      {bool range = false, bool toggle = false}) async {
    if (await _confirmDraftBeforeLeaving() && mounted) {
      _applyCueSelection(id, range: range, toggle: toggle);
    }
  }

  void _selectCue(int id, {bool range = false, bool toggle = false}) {
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
    if (!keyboard.isShiftPressed && !keyboard.isControlPressed && !keyboard.isMetaPressed) {
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
                tooltip: 'Insert first subtitle cue',
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
            const Text('This project has no subtitle cues yet.'),
            SizedBox(height: 8),
            Text(widget.onInsertCue != null
                ? 'Insert the first cue or import a subtitle file.'
                : 'Cue insertion is unavailable in this preview.',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
            if (widget.onInsertCue != null)
              FilledButton.icon(
                key: const ValueKey('studio-empty-create-cue'),
                onPressed: _changingStructure ? null :
                    () => unawaited(_addCueSafely()),
                icon: const Icon(Icons.add),
                label: const Text('Insert first cue'),
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
                    SizedBox(width: _sidebarWidth, child: _projectSidebar()),
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
                    child: Material(elevation: 12, child: _projectSidebar()),
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
    height: 27,
    padding: const EdgeInsets.symmetric(horizontal: 15),
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
                PopupMenuItem(value: _StudioDockFileMenuAction.save,
                  child: Text('Save subtitle file')),
                PopupMenuItem(value: _StudioDockFileMenuAction.saveAs,
                  child: Text('Save As…')),
                PopupMenuItem(value: _StudioDockFileMenuAction.export,
                  child: Text('Export SRT…')),
              ],
              if (widget.onSaveProject != null) ...const [
                PopupMenuDivider(),
                PopupMenuItem(value: _StudioDockFileMenuAction.saveProject,
                  child: Text('Save project (.msone)')),
                PopupMenuItem(value: _StudioDockFileMenuAction.saveProjectAs,
                  child: Text('Save project as…')),
              ],
              if (widget.onOpenProjectSettings != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
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
              child: Text('File', style: TextStyle(fontSize: 11)),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(right: 23),
            child: Text('File', style: TextStyle(fontSize: 11)),
          ),
        _desktopMenu('Edit', const ValueKey('studio-edit-menu'), [
          PopupMenuItem(value: _StudioDockMenuAction.undo,
              enabled: !_historyNavigationBlocked &&
                  _currentHistoryPoint?.parentCheckpointId != null,
              child: const Text('Undo')),
          PopupMenuItem(value: _StudioDockMenuAction.redo,
              enabled: !_historyNavigationBlocked &&
                  (_currentHistoryPoint?.childCheckpointIds.isNotEmpty ?? false),
              child: const Text('Redo')),
          const PopupMenuItem(value: _StudioDockMenuAction.find,
              child: Text('Find & Replace')),
          const PopupMenuItem(value: _StudioDockMenuAction.selectAll,
              child: Text('Select all visible subtitles')),
          PopupMenuItem(value: _StudioDockMenuAction.goToLine,
              enabled: _cues.isNotEmpty,
              child: const Text('Go to Line…')),
          const PopupMenuItem(value: _StudioDockMenuAction.selectByIndex,
              child: Text('Select subtitles by index…')),
          PopupMenuItem(value: _StudioDockMenuAction.rangeSelection,
              child: Text(_rangeSelectionMode
                  ? 'Cancel range selection' : 'Select subtitle range')),
          PopupMenuItem(value: _StudioDockMenuAction.copySelected,
              enabled: _selectedIds.isNotEmpty,
              child: const Text('Copy selected subtitles')),
        ]),
        _desktopMenu('Subtitle', const ValueKey('studio-subtitle-menu'), [
          if (widget.onInsertCue != null)
            const PopupMenuItem(value: _StudioDockMenuAction.addCue,
                child: Text('Add subtitle')),
          if (widget.onDeleteCue != null)
            const PopupMenuItem(value: _StudioDockMenuAction.deleteCue,
                child: Text('Delete subtitle')),
          if (widget.onDeleteSelectedCues != null)
            PopupMenuItem(value: _StudioDockMenuAction.deleteSelected,
                enabled: _selectedIds.isNotEmpty && !_runningSelectedBatch,
                child: Text('Delete selected subtitles (${_selectedIds.length})')),
          if (widget.onSplitCue != null)
            const PopupMenuItem(value: _StudioDockMenuAction.splitCue,
                child: Text('Split subtitle')),
          if (widget.onMergeCue != null)
            const PopupMenuItem(value: _StudioDockMenuAction.mergeCue,
                child: Text('Combine subtitles')),
          const PopupMenuItem(value: _StudioDockMenuAction.notes,
              child: Text('Review notes')),
        ]),
        _desktopMenu('Timing', const ValueKey('studio-timing-menu'), [
          const PopupMenuItem(value: _StudioDockMenuAction.timing,
              child: Text('Edit start and end time')),
          if (widget.onShiftAllCues != null)
            const PopupMenuItem(value: _StudioDockMenuAction.shiftTools,
                child: Text('Shift subtitle timecodes')),
          if (widget.onShiftSelectedCues != null)
            PopupMenuItem(value: _StudioDockMenuAction.shiftSelected,
                enabled: _selectedIds.isNotEmpty && !_runningSelectedBatch,
                child: Text('Shift selected subtitles (${_selectedIds.length})')),
        ]),
        _desktopMenu('Tools', const ValueKey('studio-tools-menu'), [
          const PopupMenuItem(value: _StudioDockMenuAction.find,
              child: Text('Find & Replace')),
          const PopupMenuItem(value: _StudioDockMenuAction.showTools,
              child: Text('Subtitle tools')),
          if (widget.onImportComments != null)
            PopupMenuItem(value: _StudioDockMenuAction.importComments,
              enabled: !_openingCommentImport && _cues.isNotEmpty,
              child: Builder(builder: (popupContext) {
                _commentsMenuRoute = ModalRoute.of(popupContext);
                return const Text('Import Comments (.msone)…');
              })),
          if (widget.onLoadSecondarySubtitles != null)
            PopupMenuItem(value: _StudioDockMenuAction.loadSecondary,
              child: Builder(builder: (popupContext) {
                _secondaryMenuRoute = ModalRoute.of(popupContext);
                return const Text('Load secondary subtitles');
              })),
          if (widget.onToggleSecondarySubtitles != null)
            PopupMenuItem(value: _StudioDockMenuAction.toggleSecondary,
              child: Text(widget.showSecondarySubtitles
                  ? 'Hide secondary subtitles'
                  : 'Show secondary subtitles')),
          if (widget.onLoadSourceView != null)
            const PopupMenuItem(value: _StudioDockMenuAction.sourceView,
                child: Text('Source View')),
          if (widget.onLoadHistory != null)
            const PopupMenuItem(value: _StudioDockMenuAction.history,
                child: Text('Edit history')),
          if (widget.onSubmitToMsone != null)
            PopupMenuItem(value: _StudioDockMenuAction.submitMsone,
              enabled: !_openingMsoneSubmission,
              child: Builder(builder: (popupContext) {
                _msoneMenuRoute = ModalRoute.of(popupContext);
                return const Text('Submit to MSone');
              })),
        ]),
        _desktopMenu('View', const ValueKey('studio-view-menu'), [
          const PopupMenuItem(value: _StudioDockMenuAction.explorer,
              child: Text('Toggle project explorer')),
          const PopupMenuItem(value: _StudioDockMenuAction.inspector,
              child: Text('Toggle line inspector')),
          if (widget.onOpenAppSettings != null)
            const PopupMenuItem(value: _StudioDockMenuAction.settings,
                child: Text('Settings')),
        ]),
        if (widget.onOpenHelp != null)
          _desktopMenu('Help', const ValueKey('studio-help-menu'), const [
            PopupMenuItem(value: _StudioDockMenuAction.help,
                child: Text('Help & Documentation')),
          ]),
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
          child: Text(title, style: const TextStyle(fontSize: 11)),
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
      case _StudioDockMenuAction.showTools:
        unawaited(_switchSection(3));
      case _StudioDockMenuAction.shiftSelected:
        unawaited(_shiftSelectedSafely());
      case _StudioDockMenuAction.sourceView:
        unawaited(_switchSection(5));
      case _StudioDockMenuAction.history:
        unawaited(_switchSection(1));
      case _StudioDockMenuAction.importComments:
        final menuRoute = _commentsMenuRoute;
        _commentsMenuRoute = null;
        unawaited(_importCommentsSafely(afterMenu: menuRoute));
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cueScroll.hasClients) return;
      final visibleIndex = _visible.indexWhere((item) => item.id == cue.id);
      if (visibleIndex < 0) return;
      final target = (visibleIndex * 40.0 + 20 -
              _cueScroll.position.viewportDimension / 2)
          .clamp(0.0, _cueScroll.position.maxScrollExtent).toDouble();
      _cueScroll.jumpTo(target);
    });

    // Match mobile's +50ms margin so the selected subtitle is active at the
    // destination. No player exists until the host attaches its shared link.
    if (widget.playback?.isAttached ?? false) {
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
  }

  Future<void> _selectByIndexSafely() async {
    if (_cues.isEmpty || !await _confirmDraftBeforeLeaving() || !mounted) return;
    var firstText = '1';
    var lastText = '${_cues.length}';
    String? error;
    final chosen = await showDialog<List<int>>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (dialog, refresh) => AlertDialog(
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'First line', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey('studio-range-end'),
              initialValue: lastText,
              onChanged: (value) => lastText = value,
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
            onPressed: () {
              final start = int.tryParse(firstText.trim());
              final end = int.tryParse(lastText.trim());
              if (start == null || end == null || start < 1 ||
                  end < start || end > _cues.length) {
                refresh(() => error = 'Enter indices between 1 and ${_cues.length} in order.');
                return;
              }
              Navigator.pop(dialog, <int>[start, end]);
            },
            child: const Text('Select range'),
          ),
        ],
      )),
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
      builder: (dialog) => StatefulBuilder(builder: (dialog, refresh) => PopScope(
        canPop: !saving,
        child: AlertDialog(
          title: Text('Shift ${selected.length} selected subtitles'),
          content: SizedBox(width: 420, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set a new start for the first selected cue and an end '
                  'anchor for the last. Relative starts scale; durations stay unchanged.'),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('studio-selected-start'),
                initialValue: firstText,
                onChanged: (value) => firstText = value,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'First selected start', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('studio-selected-end'),
                initialValue: lastText,
                onChanged: (value) => lastText = value,
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
              onPressed: saving ? null : () async {
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
                        'have changed or a cue would exceed the SRT time range.';
                  });
                  return;
                }
                Navigator.pop(dialog);
                _acceptStructure(updated);
              },
              child: Text(saving ? 'Applying…' : 'Apply selected shift'),
            ),
          ],
        ),
      )),
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
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${ids.length} selected subtitles?'),
        content: const Text('This removes all selected cues in one undoable '
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
      ),
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


  Widget _topBar() => Container(
    height: 55,
    padding: const EdgeInsets.symmetric(horizontal: 17),
    decoration: BoxDecoration(border:
        Border(bottom: BorderSide(color: _border))),
    child: Row(children: [
      Icon(Icons.subtitles_rounded, color: _accent, size: 22),
      const SizedBox(width: 10),
      const Text('SubtitleStudio', style:
          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      SizedBox(width: 16),
      Container(width: 1, height: 23, color: _border),
      const SizedBox(width: 15),
      Flexible(child: Text(
        widget.projectTitle ?? 'Night Drive  /  Main subtitles',
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _muted, fontSize: 12),
      )),
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
      Text(widget.onApplyCueText != null ? 'LIVE · TEXT EDIT' : (widget.isLiveSession ? 'LIVE · READ ONLY' : 'DEMO WORKSPACE'),
        style: TextStyle(
          color: _muted, letterSpacing: 1, fontSize: 10)),
      if (widget.onChooseVideo != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-video'),
          icon: const Icon(Icons.video_file_outlined),
          tooltip: 'Attach or change video',
          onPressed: () => unawaited(_chooseVideoSafely()),
        ),
      if (widget.onOpenProjectSettings != null)
        IconButton(
          key: const ValueKey('studio-toolbar-project-settings'),
          icon: const Icon(Icons.settings_applications_outlined),
          tooltip: 'Project Settings',
          onPressed: _openingProjectSettings ? null :
              () => unawaited(_openProjectSettingsSafely()),
        ),
      if (widget.onInsertCue != null)
        IconButton(
          key: const ValueKey('studio-dock-insert-cue'),
          icon: const Icon(Icons.add_comment_outlined),
          tooltip: 'Insert subtitle cue',
          onPressed: _changingStructure ? null :
              () => unawaited(_addCueSafely()),
        ),
      if (widget.onDeleteCue != null)
        IconButton(
          key: const ValueKey('studio-dock-delete-cue'),
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete selected subtitle cue',
          onPressed: _changingStructure || _cues.isEmpty ? null :
              () => unawaited(_deleteCueSafely()),
        ),
      if (widget.onSplitCue != null)
        IconButton(
          key: const ValueKey('studio-dock-split-cue'),
          icon: const Icon(Icons.call_split_outlined),
          tooltip: 'Split selected subtitle cue',
          onPressed: _changingStructure || _cues.isEmpty ? null :
              () => unawaited(_splitCueSafely()),
        ),
      if (widget.onMergeCue != null)
        IconButton(
          key: const ValueKey('studio-dock-merge-cue'),
          icon: const Icon(Icons.merge_outlined),
          tooltip: 'Combine selected cue with adjacent cue',
          onPressed: _changingStructure || _cues.length < 2 ? null :
              () => unawaited(_mergeCueSafely()),
        ),
      if (widget.onImportFile != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-import'),
          icon: const Icon(Icons.file_open_outlined),
          tooltip: 'Import subtitles or project',
          onPressed: () => unawaited(_importFileSafely()),
        ),
      if (widget.onNewProject != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-new'),
          icon: const Icon(Icons.add_box_outlined),
          tooltip: 'New project',
          onPressed: () => unawaited(_newProjectSafely()),
        ),
      if (widget.onChooseProject != null)
        IconButton(
          key: const ValueKey('studio-dock-switch-project'),
          icon: const Icon(Icons.folder_open_outlined),
          tooltip: 'Switch project',
          onPressed: () => unawaited(_chooseProjectSafely()),
        ),
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
      const SizedBox(width: 7),
      Text(widget.onApplyCueText != null ? 'Text editing' : (widget.isLiveSession ? 'Read-only' : 'Preview'),
          style: const TextStyle(fontSize: 12)),
    ]),
  );

  void _toggleExplorerPanel() {
    if (MediaQuery.sizeOf(context).width < 1600) {
      setState(() {
        _explorerOverlayOpen = !_explorerOverlayOpen;
        _inspectorOverlayOpen = false;
      });
    } else {
      setState(() => _explorerOpen = !_explorerOpen);
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
      const SizedBox(height: 13),
      _railItem(0, Icons.movie_creation_outlined, 'Editor'),
      _railItem(1, Icons.account_tree_outlined, 'History'),
      if (widget.onLoadSourceView != null)
        _railItem(5, Icons.code_rounded, 'Source View'),
      _railItem(2, Icons.search_rounded, 'Find'),
      _railItem(3, Icons.tune_rounded, 'Tools'),
      const Spacer(),
      _railItem(4, Icons.settings_outlined, 'Settings'),
      const SizedBox(height: 13),
    ]),
  );

  Widget _railItem(int index, IconData icon, String title) => Tooltip(
    message: title,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
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
    await _switchSection(2);
    if (mounted && _section == 2) _findFocus.requestFocus();
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
      builder: (dialog) => AlertDialog(
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
      ),
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

  Future<void> _runBulkTool({
    required String title,
    required String detail,
    required Future<StudioDockCueUpdate?> Function() apply,
  }) async {
    if (_runningTool || _changingStructure || _savingDraft) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
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
      ),
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

  Widget _projectSidebar() => widget.isLiveSession
      ? _readOnlyProjectSidebar()
      : Container(
    decoration: BoxDecoration(border:
        Border(right: BorderSide(color: _border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paneHeader(Icons.folder_open_rounded, 'PROJECT', trailing: 'DEMO'),
        SizedBox(height: 10),
        _sidebarRow(Icons.folder_rounded, 'Night Drive', selected: true),
        Padding(padding: EdgeInsets.fromLTRB(17, 20, 12, 7),
          child: Text('PROJECT FILES', style:
            TextStyle(fontSize: 10, color: _muted, letterSpacing: 1.2))),
        _sidebarRow(Icons.subtitles_rounded, 'Main subtitles.srt',
            selected: true, indent: 15),
        _sidebarRow(Icons.subtitles_outlined, 'Secondary subtitles',
            indent: 15),
        _sidebarRow(Icons.movie_outlined, 'Night Drive.mp4', indent: 15),
        Padding(padding: EdgeInsets.fromLTRB(17, 23, 12, 7),
          child: Text('VERSIONS', style:
            TextStyle(fontSize: 10, color: _muted, letterSpacing: 1.2))),
        _sidebarRow(Icons.fork_right_rounded, 'Current version'),
        _sidebarRow(Icons.bookmark_border_rounded, 'Pinned versions'),
        const Spacer(),
        Padding(
          padding: EdgeInsets.all(14),
          child: Text('Preview project\nNo local files are opened.',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.5)),
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
      const SizedBox(height: 10),
      _sidebarRow(Icons.subtitles_rounded,
          widget.projectTitle ?? 'Subtitle session',
          selected: true),
      Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          widget.isEditMode
              ? 'Subtitle creation mode · enter subtitle text and timing. '
                  'No original/translation pair is required.'
              : 'Translation mode · keep the original text alongside your '
                  'edited translation.',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
        ),
      ),
    ]),
  );

  Widget _sidebarRow(IconData icon, String label,
      {bool selected = false, double indent = 0}) =>
    Padding(
      padding: EdgeInsets.fromLTRB(8 + indent, 2, 8, 2),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: .12) : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: selected ? _accent : _muted),
          SizedBox(width: 9),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12,
                  color: selected ? Colors.white : _muted))),
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

  Widget _paneHeader(IconData icon, String title, {String? trailing}) =>
      Container(
        height: 43,
        padding: EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .7)),
          const Spacer(),
          if (trailing != null) Flexible(child: Text(trailing,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _muted, fontSize: 10))),
        ]),
      );

  Widget _editingWorkspace() => LayoutBuilder(
    builder: (context, limits) {
      final bands = StudioDockBands.resolve(
        limits.maxHeight,
        videoShare: _videoShare,
        waveformShare: _waveformShare,
      );
      return Column(children: [
        SizedBox(
          key: const ValueKey('dock-video-band'),
          height: bands.video,
          child: Column(children: [
            Expanded(child: widget.videoSurface ?? _videoPanel()),
            if (widget.videoSurface == null) _transport(),
          ]),
        ),
        _horizontalSplitter(
          key: const ValueKey('splitter-video-waveform'),
          onDelta: (dy) => setState(() {
            final change = dy / limits.maxHeight;
            _videoShare = (_videoShare + change).clamp(.24, .62);
            _waveformShare = (_waveformShare - change).clamp(.18, .38);
          }),
          onReset: () => setState(() {
            _videoShare = .38;
            _waveformShare = .24;
          }),
        ),
        SizedBox(
          key: const ValueKey('dock-waveform-band'),
          height: bands.waveform,
          child: _waveformPanel(),
        ),
        _horizontalSplitter(
          key: const ValueKey('splitter-waveform-table'),
          onDelta: (dy) => setState(() =>
            _waveformShare = (_waveformShare + dy / limits.maxHeight)
                .clamp(.18, .38)),
          onReset: () => setState(() {
            _videoShare = .38;
            _waveformShare = .24;
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
    padding: const EdgeInsets.all(14),
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
      SizedBox(height: 10),
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
                    ? 'REAL CUES · VIDEO NOT CONNECTED'
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
        tooltip: 'Previous cue',
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
        tooltip: 'Next cue', onPressed: () => _selectRelative(1)),
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
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(children: [
      Row(children: [
        Icon(Icons.graphic_eq, size: 15, color: _accent),
        const SizedBox(width: 8),
        const Text('WAVEFORM', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8)),
        const SizedBox(width: 10),
        Text(widget.waveformSurface != null ? 'Synced with video' :
            (widget.isLiveSession ? 'Audio not connected' : 'Audio track: Auto'),
            style: TextStyle(fontSize: 10, color: _muted)),
        const Spacer(),
        Text('–  00:30  +', style:
            TextStyle(color: _muted, fontSize: 10)),
      ]),
      SizedBox(height: 7),
      Expanded(child: widget.waveformSurface ?? (widget.isLiveSession
          ? Center(child: Text('Waveform integration pending',
              style: TextStyle(color: _muted, fontSize: 11)))
          : SizedBox.expand(
              child: CustomPaint(painter: _DemoWaveformPainter(
                cueIndex: _selectedId, accent: _accent))))),
    ]),
  );

  Widget _subtitleTable() => Column(children: [
    Row(children: [
      Expanded(child: _paneHeader(Icons.view_list_outlined, 'SUBTITLE LINES',
        trailing: _visible.length.toString() + ' / ' + _cues.length.toString())),
      IconButton(
        key: const ValueKey('studio-go-to-line'),
        tooltip: 'Go to subtitle line',
        icon: const Icon(Icons.numbers, size: 19),
        onPressed: _cues.isEmpty ? null : () => unawaited(_goToLineSafely()),
      ),
      DropdownButtonHideUnderline(child: DropdownButton<_StudioDockReviewFilter>(
        key: const ValueKey('studio-review-filter'),
        value: _reviewFilter,
        isDense: true,
        style: TextStyle(fontSize: 11,
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
          if (filter != null) setState(() => _reviewFilter = filter);
        },
      )),
      if (widget.onApplyBulkReview != null)
        PopupMenuButton<StudioDockReviewAction>(
          key: const ValueKey('studio-bulk-review-menu'),
          tooltip: 'Review selected subtitles',
          enabled: _selectedIds.isNotEmpty && !_changingStructure,
          icon: const Icon(Icons.bookmarks_outlined),
          onSelected: (action) => unawaited(_applyReviewSelection(
              _selectedIds.toList(), action: action)),
          itemBuilder: (_) => const [
            PopupMenuItem(value: StudioDockReviewAction.mark,
                child: Text('Mark selected for review')),
            PopupMenuItem(value: StudioDockReviewAction.unmark,
                child: Text('Unmark selected')),
            PopupMenuItem(value: StudioDockReviewAction.resolve,
                child: Text('Resolve selected')),
            PopupMenuItem(value: StudioDockReviewAction.reopen,
                child: Text('Reopen selected')),
          ],
        ),
      if (widget.playback != null) IconButton(
        key: const ValueKey('studio-dock-follow-playback'),
        tooltip: _followPlayback ? 'Pause subtitle follow' : 'Follow playback',
        icon: Icon(_followPlayback ? Icons.my_location : Icons.location_disabled),
        onPressed: () { setState(() => _followPlayback = !_followPlayback); _onPlaybackPosition(); },
      ),
    ]),
    SizedBox(height: 43, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      child: TextField(
        key: const ValueKey('desktop-cue-search'),
        controller: _tableSearch,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Find subtitle, timecode or line number…',
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 17),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
        ),
        style: const TextStyle(fontSize: 12),
        onChanged: (value) => setState(() => _query = value),
      ),
    )),
    Expanded(child: LayoutBuilder(builder: (context, limits) {
      final gridWidth = math.max(850.0, limits.maxWidth);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: gridWidth,
          height: limits.maxHeight,
          child: Column(children: [
            Container(
              height: 33,
              color: const Color(0xFF21262B),
              padding: EdgeInsets.symmetric(horizontal: 13),
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
                  itemExtent: 40,
                  itemBuilder: (context, i) {
                    final cue = _visible[i];
                    final selected = _selectedIds.contains(cue.id);
                    return Material(
                      color: selected ? _accent.withValues(alpha: .14)
                          : cue.id == _playingCueId ? _accent.withValues(alpha: .09)
                          : i.isOdd
                              ? const Color(0xFF1B1F23)
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
                          padding: const EdgeInsets.symmetric(horizontal: 13),
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


  Future<void> _showCueContextMenu(
      StudioDockCue cue, Offset position) async {
    final renderObject = Overlay.of(context).context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & renderObject.size,
      ),
      items: [
        const PopupMenuItem(value: 'select', child: Text('Select cue')),
        if (widget.onApplyBulkReview != null) ...const [
          PopupMenuItem(value: 'mark-selected',
              child: Text('Mark selected for review')),
          PopupMenuItem(value: 'unmark-selected',
              child: Text('Unmark selected')),
          PopupMenuItem(value: 'resolve-selected',
              child: Text('Resolve selected')),
          PopupMenuItem(value: 'reopen-selected',
              child: Text('Reopen selected')),
        ],
        if (!widget.isLiveSession)
          const PopupMenuItem(value: 'mark',
              child: Text('Toggle review mark')),
        const PopupMenuItem(value: 'copy-selected',
            child: Text('Copy selected subtitle text')),
        const PopupMenuItem(value: 'copy', child: Text('Copy timecodes')),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case 'select':
        _selectCue(cue.id);
      case 'mark':
        _selectCue(cue.id);
        _toggleMarkedSelection();
      case 'mark-selected':
        unawaited(_applyReviewSelection(
          _selectedIds.contains(cue.id) ? _selectedIds.toList() : [cue.id],
          action: StudioDockReviewAction.mark,
        ));
      case 'unmark-selected':
        unawaited(_applyReviewSelection(
          _selectedIds.contains(cue.id) ? _selectedIds.toList() : [cue.id],
          action: StudioDockReviewAction.unmark,
        ));
      case 'resolve-selected':
        unawaited(_applyReviewSelection(
          _selectedIds.contains(cue.id) ? _selectedIds.toList() : [cue.id],
          action: StudioDockReviewAction.resolve,
        ));
      case 'reopen-selected':
        unawaited(_applyReviewSelection(
          _selectedIds.contains(cue.id) ? _selectedIds.toList() : [cue.id],
          action: StudioDockReviewAction.reopen,
        ));
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
            MapEntry('Next cue', () => _selectRelative(1)),
            MapEntry('Previous cue', () => _selectRelative(-1)),
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
          return AlertDialog(
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
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      visible[i].value();
                    },
                  ),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _gridCells(StudioDockCue? cue) {
    final heading = cue == null;
    Text cell(String value, {bool primary = false}) => Text(
      value, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: heading ? 10 : 11,
        color: heading ? _muted : primary
            ? Theme.of(context).colorScheme.onSurface : _muted),
    );
    return Row(children: [
      SizedBox(width: 32, child: cell(heading ? '#' : cue.id.toString())),
      SizedBox(width: 108, child: cell(heading ? 'START' : cue.start)),
      SizedBox(width: 108, child: cell(heading ? 'END' : cue.end)),
      SizedBox(width: 84, child: cell(heading
          ? 'DURATION' : _cueDuration(cue))),
      if (!widget.isEditMode)
        Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: cell(heading ? 'ORIGINAL' : cue.original, primary: true),
        )),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: cell(heading ? (widget.isEditMode ? 'SUBTITLE TEXT' : 'EDITED')
            : cue.edited, primary: true),
      )),
      SizedBox(width: 55, child: heading
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
        SizedBox(height: 43, child: Row(children: [
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
                  style: const TextStyle(fontSize: 11)),
            )),
        ])),
        Expanded(child: ListView(
          key: ValueKey('inspector-page-' + _inspectorTab.toString()),
          padding: const EdgeInsets.all(15),
          children: _inspectorFields(),
        )),
        if (_inspectorTab == 0 &&
            (widget.onApplyCueText != null ||
                widget.onApplyCueTiming != null))
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
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
                onPressed: (_hasDirtyTextDraft || _hasDirtyTimingDraft) &&
                        !_savingDraft ? _discardDraft : null,
                child: const Text('Discard'),
              ),
            ]),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Text(widget.onApplyCueText != null ||
                  widget.onApplyCueTiming != null
              ? 'Apply updates the local project with checkpoint history'
              : (widget.isLiveSession
                  ? 'Read-only session · no changes are saved'
                  : 'Demo only · changes are not saved to files'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11)),
        ),
      ]),
    );
  }

  List<Widget> _inspectorFields() {
    switch (_inspectorTab) {
      case 0:
        return [
          if (!widget.isEditMode) ...[
            _fieldLabel('ORIGINAL TEXT'),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(_selected.original,
                style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 17),
          ],
          _fieldLabel(widget.isEditMode
              ? (widget.onApplyCueText != null
                  ? 'SUBTITLE TEXT · UNSAVED UNTIL APPLIED'
                  : (widget.isLiveSession
                      ? 'SUBTITLE TEXT · READ ONLY'
                      : 'SUBTITLE TEXT · DEMO ONLY'))
              : (widget.onApplyCueText != null
                  ? 'EDITED TEXT · UNSAVED UNTIL APPLIED'
                  : (widget.isLiveSession
                      ? 'EDITED TEXT · READ ONLY'
                      : 'EDITED TEXT · DEMO ONLY'))),
          TextFormField(
            key: widget.onApplyCueText == null
                ? ValueKey('desktop-edit-' + _selected.id.toString())
                : ValueKey('studio-edit-' + _selected.id.toString() +
                    '-' + _draftRevision.toString()),
            initialValue: _draftCueId == _selectedId && _draftText != null
                ? _draftText : _selected.edited,
            readOnly: _savingDraft ||
                (widget.isLiveSession && widget.onApplyCueText == null),
            minLines: 3, maxLines: 8,
            style: const TextStyle(fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7)),
            ),
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
          if (!widget.isEditMode) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: widget.isLiveSession ? null : () => _replaceCue(
                  _selected.copyWith(edited: _selected.original)),
              icon: const Icon(Icons.restore, size: 15),
              label: const Text('Reset to original'),
            ),
          ],
          const SizedBox(height: 22),
          Divider(color: _border),
          const SizedBox(height: 10),
          _fieldLabel('TIMING'),
          const SizedBox(height: 8),
          _fieldLabel('START TIMECODE'),
          if (widget.onApplyCueTiming == null)
            _readonlyField(_selected.start)
          else
            TextFormField(
              key: ValueKey('studio-timing-start-$_selectedId-$_draftRevision'),
              initialValue: _timingStart,
              enabled: !_savingDraft,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'HH:mm:ss,SSS',
              ),
              onChanged: (value) => setState(() {
                _draftTimingCueId = _selectedId;
                _draftStart = value;
              }),
            ),
          const SizedBox(height: 13),
          _fieldLabel('END TIMECODE'),
          if (widget.onApplyCueTiming == null)
            _readonlyField(_selected.end)
          else
            TextFormField(
              key: ValueKey('studio-timing-end-$_selectedId-$_draftRevision'),
              initialValue: _timingEnd,
              enabled: !_savingDraft,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'HH:mm:ss,SSS',
              ),
              onChanged: (value) => setState(() {
                _draftTimingCueId = _selectedId;
                _draftEnd = value;
              }),
            ),
          const SizedBox(height: 13),
          _fieldLabel('DURATION'),
          _readonlyField(_cueDuration(_selected.copyWith(
            start: _timingStart, end: _timingEnd))),
          const SizedBox(height: 12),
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
                label: Text(label, style: const TextStyle(fontSize: 11)),
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
          _fieldLabel('POSITION (9-GRID)'),
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
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 9),
          SelectableText(_styleText, style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, color: _muted)),
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
              style: const TextStyle(fontSize: 12)),
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
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: TextStyle(
      color: _muted, fontSize: 10, letterSpacing: .8,
      fontWeight: FontWeight.w600)),
  );
  Widget _readonlyField(String text) => Container(
    padding: EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(text, style: const TextStyle(
      fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
  );

  Widget _secondarySection() {
    if (_section == 5) return _sourceViewSection();
    if (_section == 1 && widget.onLoadHistory != null) {
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
        if (_runningTool) const LinearProgressIndicator(),
        if (_toolsError != null) Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_toolsError!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
        ),
        if (widget.onShiftAllCues == null &&
            widget.onClearAllFormatting == null &&
            widget.onImportComments == null)
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
      builder: (dialog) => AlertDialog(
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
      ),
    );
    if (confirmed == true && mounted) {
      await _restoreHistoryPoint(node.checkpointId);
    }
  }

  Widget _historySection() {
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
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(border:
        Border(top: BorderSide(color: _border))),
    child: Row(children: [
      Icon(Icons.info_outline, color: _accent, size: 13),
      const SizedBox(width: 8),
      Expanded(child: Text(widget.onApplyCueText != null
          ? 'Real session · text edits require Apply · checkpoint-backed'
          : (widget.isLiveSession
              ? 'Real session · read only · no database changes'
              : 'Demo workspace · no files are modified'),
        style: TextStyle(color: _muted, fontSize: 10))),
      Text(widget.encoding == null
          ? 'Desktop prototype  •  Windows / macOS / Linux'
          : 'Encoding: ' + widget.encoding!,
        style: TextStyle(color: _muted, fontSize: 10)),
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
