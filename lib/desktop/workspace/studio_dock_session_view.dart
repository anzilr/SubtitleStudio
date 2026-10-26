import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/editor_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/video_repository.dart';
import 'package:subtitle_studio/screens/edit/providers/subtitle_repository_provider.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';
import 'package:subtitle_studio/screens/screen_help.dart';
import 'package:subtitle_studio/widgets/settings_sheet.dart';
import 'package:subtitle_studio/widgets/project_settings_sheet.dart';
import 'package:subtitle_studio/widgets/import_comments_sheet.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_tool_sheets.dart';
import 'package:subtitle_studio/screens/edit/services/hearing_impaired_cleanup_service.dart';
import 'package:subtitle_studio/screens/msone_submission_flow.dart';
import 'package:subtitle_studio/screens/edit/services/editor_secondary_subtitle_service.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/widgets/secondary_subtitle_sheet.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_panel.dart';
import 'package:subtitle_studio/widgets/marked_lines_sheet.dart';
import 'package:subtitle_studio/operations/subtitle_effect_operations.dart';
import 'package:subtitle_studio/operations/srt_effect_frames.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';

import 'studio_dock_workspace.dart';
import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';
import 'studio_dock_text_edit_service.dart';
import 'studio_dock_timing_edit_service.dart';
import 'studio_dock_cue_structure_service.dart';
import 'studio_dock_insert_cue_dialog.dart';
import 'studio_dock_split_cue_dialog.dart';
import 'studio_dock_media_plan.dart';
import 'studio_dock_video_surface.dart';
import 'studio_dock_waveform_surface.dart';
import 'studio_dock_playback_link.dart';
import 'studio_dock_repeat_controller.dart';
import 'studio_dock_file_actions.dart';
import 'studio_dock_project_save_actions.dart';
import 'studio_dock_history_service.dart';
import 'studio_dock_source_view_service.dart';
import 'studio_dock_notes_service.dart';
import 'studio_dock_cue_edit_service.dart';
import 'studio_dock_bulk_review_service.dart';
import 'studio_dock_search_service.dart';
import 'studio_dock_bulk_tools_service.dart';
import 'studio_dock_waveform_edit_plan.dart';

/// Live Studio Dock host backed by the shared project, subtitle, history,
/// native media and file services.
class StudioDockSessionView extends ConsumerStatefulWidget {
  const StudioDockSessionView({
    super.key,
    required this.sessionId,
    required this.collectionId,
    this.onChooseProject,
    this.projects = const [],
    this.activeProjectId,
    this.onSelectProject,
    this.onImportFile,
    this.onNewProject,
    this.enableEditing = false,
    this.allowNativePlayback = false,
    this.suppressParentEditorHotkeys = true,
  });

  final int sessionId;
  final int collectionId;
  final VoidCallback? onChooseProject;
  final List<StudioDockProjectEntry> projects;
  final int? activeProjectId;
  final ValueChanged<int>? onSelectProject;
  final VoidCallback? onImportFile;
  final VoidCallback? onNewProject;
  /// Opt in to checkpoint-backed edits for an existing session.
  final bool enableEditing;
  /// Only true for the standalone native desktop Home. An Editor-hosted route
  /// leaves this false, avoiding a second player behind the classic Editor.
  final bool allowNativePlayback;
  /// Enable only when opened *over* a still-mounted classic Editor route.
  final bool suppressParentEditorHotkeys;

  @override
  ConsumerState<StudioDockSessionView> createState() =>
      _StudioDockSessionViewState();
}

class _StudioDockSessionViewState
    extends ConsumerState<StudioDockSessionView> {
  late Future<StudioDockSessionSnapshot> _snapshot;
  Future<String?>? _videoPath;
  bool _selectingVideo = false;
  StudioDockSessionSnapshot? _latestBaseline;
  SubtitleCollection? _loadedCollection;
  final StudioDockPlaybackLink _playback = StudioDockPlaybackLink();
  late final StudioDockRepeatController _repeat =
      StudioDockRepeatController(_playback);
  GlobalKey<StudioDockWorkspaceState> _dockKey =
      GlobalKey<StudioDockWorkspaceState>();
  bool _waveformEditBusy = false;
  bool _fullscreenReviewBusy = false;
  bool _msoneEnabled = false;
  int _msonePreferenceRevision = 0;
  EditorLineDisplayPreferences _lineDisplay =
      const EditorLineDisplayPreferences(
        showOriginalLine: false,
        autoSaveWithNavigation: true,
        showOriginalTextField: true,
      );
  int _lineDisplayRevision = 0;
  EditorSecondarySubtitleSource _secondarySource =
      EditorSecondarySubtitleSource.none;
  List<SimpleSubtitleLine> _externalSecondary = const [];
  bool _showSecondary = true;
  int _secondaryRevision = 0;
  VideoPlayerWidgetState? _nativePlayerState;

  VideoRepository get _videoRepository => VideoRepository(
      EditorPreferencesRepository(ref.read(isarProvider)));

  Future<void> _refreshLineDisplay() async {
    final revision = ++_lineDisplayRevision;
    try {
      final options = await EditorPreferencesRepository(
          ref.read(isarProvider)).getLineDisplayPreferences();
      if (mounted && revision == _lineDisplayRevision) {
        setState(() => _lineDisplay = options);
      }
    } catch (_) {
      // The live editor remains usable with safe defaults if settings fail.
    }
  }

  Future<bool> _saveLineDisplayPreference(
      StudioDockEditPreference preference, bool value) async {
    final repository = EditorPreferencesRepository(ref.read(isarProvider));
    try {
      switch (preference) {
        case StudioDockEditPreference.showOriginalLine:
          await repository.setShowOriginalLine(value);
        case StudioDockEditPreference.autoSaveWithNavigation:
          await repository.setAutoSaveWithNavigation(value);
        case StudioDockEditPreference.showOriginalTextField:
          await repository.setShowOriginalTextField(value);
      }
      if (!mounted) return false;
      await _refreshLineDisplay();
      return mounted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshSavedSecondary() async {
    final revision = ++_secondaryRevision;
    final collectionId = widget.collectionId;
    final secondary = await _videoRepository.loadSavedSecondarySubtitle(collectionId);
    if (!mounted || revision != _secondaryRevision ||
        collectionId != widget.collectionId) return;
    setState(() {
      if (secondary == null) {
        _secondarySource = EditorSecondarySubtitleSource.none;
        _externalSecondary = const [];
      } else if (secondary.useOriginal) {
        _secondarySource = EditorSecondarySubtitleSource.originalText;
        _externalSecondary = const [];
      } else {
        _secondarySource = EditorSecondarySubtitleSource.external;
        _externalSecondary = List.unmodifiable(
            secondary.subtitles ?? const <SimpleSubtitleLine>[]);
      }
      _showSecondary = true;
    });
  }

  List<SubtitleLine> _primaryLines(StudioDockSessionSnapshot session) => [
    for (final cue in session.cues)
      SubtitleLine()
        ..index = cue.index
        ..startTime = cue.start
        ..endTime = cue.end
        ..original = cue.original
        ..edited = cue.storedEdited,
  ];

  List<Subtitle> _secondaryOverlay(StudioDockSessionSnapshot session) {
    if (!_showSecondary || _secondarySource == EditorSecondarySubtitleSource.none) {
      return const <Subtitle>[];
    }
    final lines = _secondarySource == EditorSecondarySubtitleSource.originalText
        ? EditorSecondarySubtitleService.fromOriginal(_primaryLines(session))
        : _externalSecondary;
    try {
      return ref.read(subtitleRepositoryProvider).generateSimpleSubtitles(lines);
    } catch (_) {
      return const <Subtitle>[];
    }
  }

  void _setSecondaryLocally(List<SimpleSubtitleLine> lines,
      {required bool fromOriginal}) {
    if (!mounted) return;
    ++_secondaryRevision; // A completed picker wins over any pending load.
    setState(() {
      _secondarySource = fromOriginal
          ? EditorSecondarySubtitleSource.originalText
          : EditorSecondarySubtitleSource.external;
      _externalSecondary = fromOriginal ? const [] : List.unmodifiable(lines);
      _showSecondary = true;
    });
  }

  void _toggleSecondaryVisibility() {
    if (!mounted || _secondarySource == EditorSecondarySubtitleSource.none) return;
    setState(() => _showSecondary = !_showSecondary);
  }

  void _clearSecondaryLocally() {
    if (!mounted) return;
    ++_secondaryRevision;
    setState(() {
      _secondarySource = EditorSecondarySubtitleSource.none;
      _externalSecondary = const [];
      _showSecondary = false;
    });
  }

  Future<void> _openSecondaryPicker() async {
    if (!mounted || _latestBaseline == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 610,
            maxHeight: MediaQuery.sizeOf(dialog).height - 64,
          ),
          child: SingleChildScrollView(
            child: SecondarySubtitleSheet(
              originalSubtitles: _primaryLines(_latestBaseline!),
              subtitleCollectionId: widget.collectionId,
              videoPlayerState: _nativePlayerState,
              onSecondarySubtitlesLoaded: _setSecondaryLocally,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshMsonePreference() async {
    final revision = ++_msonePreferenceRevision;
    var enabled = false;
    try {
      enabled = await EditorPreferencesRepository(
        ref.read(isarProvider)).getMsoneEnabled();
    } catch (_) {
      // A missing settings database must never expose a submission action.
    }
    if (mounted && revision == _msonePreferenceRevision) {
      setState(() => _msoneEnabled = enabled);
    }
  }

  void _toggleExistingPlayback() {
    final native = _nativePlayerState;
    if (!widget.allowNativePlayback || native == null) return;
    if (native.player.state.playing) {
      unawaited(native.player.pause());
    } else {
      unawaited(native.player.play());
    }
  }

  void _toggleExistingFullscreen() {
    if (!widget.allowNativePlayback) return;
    // Reuse the mounted player and its fullscreen OverlayEntry; do not build
    // another Video or detach the waveform's shared playback coordinator.
    _nativePlayerState?.toggleCustomFullscreen();
  }

  void _toggleRepeatCurrent() {
    if (!widget.allowNativePlayback || _nativePlayerState == null) return;
    final cue = _dockKey.currentState?.selectedCueNumber ?? -1;
    setState(() => _repeat.toggleCurrent(cue));
  }

  void _setRepeatMode(bool enabled) {
    if (!widget.allowNativePlayback || _nativePlayerState == null) return;
    final cue = _dockKey.currentState?.selectedCueNumber ?? -1;
    setState(() {
      if (enabled) {
        _repeat.setNormal(cue);
      } else {
        _repeat.stop();
      }
    });
  }

  void _openRepeatRange() {
    if (!mounted || !widget.allowNativePlayback ||
        _nativePlayerState == null || _latestBaseline == null) return;
    final subtitles = StudioDockMediaPlan.overlayCues(_latestBaseline!);
    if (subtitles.isEmpty) return;
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => RepeatRangeDialog(
        subtitles: subtitles,
        onNormalRepeat: () {
          final cue = _dockKey.currentState?.selectedCueNumber ?? -1;
          setState(() => _repeat.setNormal(cue));
        },
        onCustomRangeSelected: (first, last) {
          setState(() => _repeat.setRange(first, last));
        },
      ),
    ));
  }

  Future<void> _submitToMsone() async {
    if (!mounted || !_msoneEnabled) return;
    // Reuse the production mobile choice sheet, form and route cleanup.
    // Submission itself requires explicit confirmation in that form.
    await showMsoneSubmissionFlow(
      context: context,
      subtitleCollectionId: widget.collectionId,
    );
  }

  StudioDockHistoryService get _history => StudioDockHistoryService(
    StudioDockSessionLoader(
      ref.read(projectRepositoryProvider), ref.read(subtitleRepositoryProvider)),
    ref.read(checkpointRepositoryProvider),
  );

  Future<CheckpointHistoryGraph> _loadHistory() =>
      _history.load(widget.sessionId);

  Future<StudioDockCueUpdate?> _restoreHistory(
    int targetCheckpointId, int expectedHeadId, int preferredCueId,
  ) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final transition = await _history.checkout(
        baseline: baseline, expectedHeadId: expectedHeadId,
        targetCheckpointId: targetCheckpointId,
      );
      if (transition == null || !mounted) return null;
      final restored = transition.snapshot;
      final cueId = restored.cues.any((cue) => cue.index == preferredCueId)
          ? preferredCueId
          : restored.cues.isEmpty ? -1 : restored.cues.last.index;
      setState(() => _latestBaseline = restored);
      return StudioDockCueUpdate(
        cues: [
          for (final cue in restored.cues)
            StudioDockCue(
              id: cue.index, start: cue.start, end: cue.end,
              original: cue.original, edited: cue.edited,
              storedEdited: cue.storedEdited, marked: cue.marked,
              comment: cue.comment, resolved: cue.resolved,
            ),
        ],
        selectedCueId: cueId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _applyText(int cueNumber, String editedText) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return false;
    final service = StudioDockTextEditService(
      ref.read(projectRepositoryProvider),
      ref.read(subtitleRepositoryProvider),
    );
    try {
      final updated = await service.apply(
        baseline: baseline,
        cueNumber: cueNumber,
        editedText: editedText,
      );
      if (!mounted || updated == null) return false;
      setState(() => _latestBaseline = updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _applyOriginalText(int cueNumber, String originalText) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return false;
    final service = StudioDockTextEditService(
      ref.read(projectRepositoryProvider),
      ref.read(subtitleRepositoryProvider),
    );
    try {
      final updated = await service.applyOriginal(
        baseline: baseline,
        cueNumber: cueNumber,
        originalText: originalText,
      );
      if (!mounted || updated == null) return false;
      setState(() => _latestBaseline = updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _applyTiming(int cueNumber, String start, String end) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return false;
    final service = StudioDockTimingEditService(
      ref.read(projectRepositoryProvider),
      ref.read(subtitleRepositoryProvider),
    );
    try {
      final updated = await service.apply(
        baseline: baseline,
        cueNumber: cueNumber,
        start: start,
        end: end,
      );
      if (!mounted || updated == null) return false;
      setState(() => _latestBaseline = updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _applyWaveformTime(
      int cueNumber, String start, String end) async {
    if (_waveformEditBusy || !widget.enableEditing) return false;
    _waveformEditBusy = true;
    try {
      // A waveform drag must not discard an unsaved inspector/source draft.
      if (await _dockKey.currentState?.prepareForExternalEdit() != true ||
          !mounted) return false;
      final saved = await _applyTiming(cueNumber, start, end);
      final snapshot = _latestBaseline;
      if (saved && mounted && snapshot != null) {
        _dockKey.currentState?.acceptExternalCueUpdate(
            _snapshotUpdate(snapshot, cueNumber));
      }
      return saved;
    } finally {
      _waveformEditBusy = false;
    }
  }

  void _requestWaveformCue(Duration start, Duration end) =>
      unawaited(_insertWaveformCue(start, end));

  Future<void> _insertWaveformCue(Duration start, Duration end) async {
    if (_waveformEditBusy || !widget.enableEditing) return;
    _waveformEditBusy = true;
    try {
      final formattedStart = StudioDockWaveformEditPlan.formatTime(start);
      final formattedEnd = StudioDockWaveformEditPlan.formatTime(end);
      if (formattedStart == null || formattedEnd == null ||
          StudioDockTimingEditService.validate(formattedStart, formattedEnd) != null) {
        _showWaveformError('Select a valid subtitle time range.');
        return;
      }
      if (await _dockKey.currentState?.prepareForExternalEdit() != true ||
          !mounted) return;
      final baseline = _latestBaseline;
      if (baseline == null) return;
      final position = StudioDockWaveformEditPlan.insertionPosition(
          [for (final cue in baseline.cues) cue.start], start);
      final afterCueNumber = position == 0
          ? null : baseline.cues[position - 1].index;
      final inserted = await _insertCue(afterCueNumber, StudioDockNewCueDraft(
        start: formattedStart, end: formattedEnd,
        original: '', edited: '',
      ));
      if (!mounted) return;
      if (inserted == null) {
        _showWaveformError('Could not add the subtitle line. Try again.');
        return;
      }
      _dockKey.currentState?.acceptExternalCueUpdate(inserted);
      _dockKey.currentState?.highlightCueFromWaveform(inserted.selectedCueId);
    } finally {
      _waveformEditBusy = false;
    }
  }

  void _showWaveformError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)));
  }

  Future<bool> _applyCueContent(
      int cueNumber, String editedText, String start, String end) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return false;
    try {
      final updated = await StudioDockCueEditService(
        ref.read(projectRepositoryProvider),
        ref.read(subtitleRepositoryProvider),
      ).apply(
        baseline: baseline,
        cueNumber: cueNumber,
        editedText: editedText,
        start: start,
        end: end,
      );
      if (!mounted || updated == null) return false;
      setState(() => _latestBaseline = updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  StudioDockSourceViewService get _sourceView => StudioDockSourceViewService(
    ref.read(projectRepositoryProvider),
    ref.read(subtitleRepositoryProvider),
  );

  Future<String> _loadRawSource() async {
    final baseline = _latestBaseline;
    if (baseline == null) {
      throw StateError('The subtitle session has not loaded.');
    }
    return StudioDockSourceViewService.compose(baseline);
  }

  Future<StudioDockCueUpdate?> _applyRawSource(String rawSource) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await _sourceView.apply(
        baseline: baseline,
        rawSource: rawSource,
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      final selection = updated.cues.any((cue) => cue.index == 1)
          ? 1 : updated.cues.isEmpty ? -1 : updated.cues.first.index;
      return _snapshotUpdate(updated, selection);
    } catch (_) {
      return null;
    }
  }

  /// Review actions from the existing fullscreen player share the Notes
  /// inspector's optimistic, checkpoint-backed transaction. One confirmation
  /// and one history point cover the comment and its new review mark.
  Future<bool> _applyFullscreenReview(int cueNumber, {
    String? comment,
    bool? marked,
    bool? resolved,
    bool removeComment = false,
  }) async {
    if (!mounted || !widget.enableEditing || _fullscreenReviewBusy) return false;
    _fullscreenReviewBusy = true;
    try {
      if (await _dockKey.currentState?.prepareForExternalEdit() != true ||
          !mounted) return false;
      final baseline = _latestBaseline;
      if (baseline == null) return false;
      final matching = baseline.cues.where((c) => c.index == cueNumber);
      if (matching.length != 1) return false;
      final cue = matching.single;
      final newMarked = marked ?? cue.marked;
      final newComment = removeComment ? null : comment ?? cue.comment;
      final newResolved = resolved ?? cue.resolved;
      final update = await _applyNotes(
        cueNumber, newMarked ? newComment : null, newMarked,
        newMarked && newResolved,
      );
      if (!mounted || update == null) {
        if (mounted) _fullscreenReviewError();
        return false;
      }
      _dockKey.currentState?.acceptExternalCueUpdate(update);
      final latest = _latestBaseline;
      if (latest != null) {
        _nativePlayerState?.updateSubtitles(
            StudioDockMediaPlan.overlayCues(latest));
      }
      return true;
    } finally {
      _fullscreenReviewBusy = false;
    }
  }

  void _fullscreenReviewError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Could not update this review. The project may have '
          'changed elsewhere; refresh before retrying.'),
    ));
  }

  Future<void> _markFromFullscreen(int cueNumber, bool marked) async {
    await _applyFullscreenReview(cueNumber,
        marked: marked, removeComment: !marked, resolved: marked ? null : false);
  }

  Future<void> _resolveFromFullscreen(int cueNumber, bool resolved) async {
    await _applyFullscreenReview(cueNumber, marked: true, resolved: resolved);
  }

  Future<bool> _saveFullscreenComment(
      int cueNumber, String? comment, bool marked, bool resolved) =>
      _applyFullscreenReview(cueNumber,
          comment: comment, marked: marked, resolved: resolved,
          removeComment: comment == null);

  Future<StudioDockCueUpdate?> _applyNotes(
    int cueNumber, String? comment, bool marked, bool resolved,
  ) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await StudioDockNotesService(
        ref.read(projectRepositoryProvider),
        ref.read(subtitleRepositoryProvider),
      ).apply(
        baseline: baseline,
        cueNumber: cueNumber,
        comment: comment,
        marked: marked,
        resolved: resolved,
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, cueNumber);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _applyBulkReview(
      List<int> cueNumbers, StudioDockReviewAction action,
      int preferredCue) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await StudioDockBulkReviewService(
        ref.read(projectRepositoryProvider),
        ref.read(subtitleRepositoryProvider),
      ).apply(
        baseline: baseline,
        cueNumbers: cueNumbers.toSet(),
        action: action,
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      final existing = updated.cues.map((cue) => cue.index).toSet();
      return StudioDockCueUpdate(
        cues: _snapshotUpdate(updated, preferredCue).cues,
        selectedCueId: preferredCue,
        selectedCueIds: cueNumbers.where(existing.contains).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  StudioDockSearchService get _search => StudioDockSearchService(
    ref.read(projectRepositoryProvider),
    ref.read(subtitleRepositoryProvider),
  );

  List<StudioDockSearchHit> _findCues(
      String term, bool caseSensitive, bool wholeWord) {
    final baseline = _latestBaseline;
    if (baseline == null) return const [];
    return StudioDockSearchService.findSnapshot(
      snapshot: baseline,
      term: term,
      caseSensitive: caseSensitive,
      wholeWord: wholeWord,
    );
  }

  Future<StudioDockCueUpdate?> _replaceMatches(
      List<StudioDockSearchHit> hits, String searchTerm,
      String replacement, bool caseSensitive) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await _search.replace(
        baseline: baseline,
        matches: hits,
        searchTerm: searchTerm,
        replacement: replacement,
        caseSensitive: caseSensitive,
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, hits.first.cueNumber);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _applyQualityFixes(
      List<SubtitleQualityFix> fixes) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing || fixes.isEmpty) return null;
    try {
      final updated = await _bulkTools.applyQualityFixes(
        baseline: baseline, fixes: fixes,
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, fixes.first.cueId);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _applyQualityTimingSuggestions(
      List<SubtitleQualityTimingSuggestion> suggestions) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing || suggestions.isEmpty) {
      return null;
    }
    try {
      final updated = await _bulkTools.applyQualityTimingSuggestions(
        baseline: baseline, suggestions: suggestions,
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, suggestions.first.cueId);
    } catch (_) {
      return null;
    }
  }

  StudioDockBulkToolsService get _bulkTools => StudioDockBulkToolsService(
    ref.read(projectRepositoryProvider),
    ref.read(subtitleRepositoryProvider),
  );

  Future<StudioDockCueUpdate?> _shiftAllCues(
      int selectedCueNumber, int deltaMilliseconds) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await _bulkTools.shiftAll(
        baseline: baseline, deltaMilliseconds: deltaMilliseconds);
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, selectedCueNumber);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _syncAnchoredCues(
      int selectedCueNumber, String newStart, String newEnd) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await _bulkTools.syncAnchored(
        baseline: baseline, newStart: newStart, newEnd: newEnd);
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, selectedCueNumber);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _convertFramerateCues(
      int selectedCueNumber, double sourceFps, double targetFps) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await _bulkTools.convertFramerate(
        baseline: baseline, sourceFps: sourceFps, targetFps: targetFps);
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, selectedCueNumber);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _shiftSelectedCues(
      List<int> cueNumbers, String newStart, String newEnd,
      int preferredCue) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing || cueNumbers.isEmpty) {
      return null;
    }
    try {
      final updated = await _bulkTools.shiftSelected(
        baseline: baseline,
        cueNumbers: cueNumbers.toSet(),
        newStart: newStart,
        newEnd: newEnd,
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return StudioDockCueUpdate(
        cues: _snapshotUpdate(updated, preferredCue).cues,
        selectedCueId: preferredCue,
        selectedCueIds: cueNumbers,
      );
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _deleteSelectedCues(
      List<int> cueNumbers, int preferredCue) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing || cueNumbers.isEmpty) {
      return null;
    }
    try {
      final position = baseline.cues.indexWhere(
          (cue) => cue.index == preferredCue);
      final updated = await _bulkTools.deleteSelected(
        baseline: baseline,
        cueNumbers: cueNumbers.toSet(),
      );
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      final surviving = updated.cues;
      final nextSelected = surviving.isEmpty ? -1 :
          surviving[position.clamp(0, surviving.length - 1).toInt()].index;
      return _snapshotUpdate(updated, nextSelected);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _clearAllFormatting(
      int selectedCueNumber) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await _bulkTools.clearFormatting(baseline: baseline);
      if (!mounted || updated == null) return null;
      setState(() => _latestBaseline = updated);
      return _snapshotUpdate(updated, selectedCueNumber);
    } catch (_) {
      return null;
    }
  }

  /// Runs the same checkpoint-backed cleanup as mobile, refusing stale
  /// desktop state before starting a destructive whole-project operation.
  Future<StudioDockCueUpdate?> _removeHearingImpaired(
      int selectedCueNumber) async {
    final baseline = _latestBaseline;
    if (!mounted || !widget.enableEditing || baseline == null) return null;
    try {
      final current = await _load();
      if (!mounted || current.sessionId != baseline.sessionId ||
          current.collectionId != baseline.collectionId ||
          current.cues.length != baseline.cues.length) return null;
      for (var i = 0; i < current.cues.length; i++) {
        final before = baseline.cues[i];
        final now = current.cues[i];
        if (before.index != now.index || before.start != now.start ||
            before.end != now.end || before.original != now.original ||
            before.storedEdited != now.storedEdited ||
            before.marked != now.marked ||
            before.comment != now.comment ||
            before.resolved != now.resolved) return null;
      }
      await HearingImpairedCleanupService.execute(
        isar: ref.read(isarProvider),
        sessionId: widget.sessionId,
        subtitleCollectionId: widget.collectionId,
      );
      if (!mounted) return null;
      final refreshed = await _load();
      if (!mounted) return null;
      setState(() => _latestBaseline = refreshed);
      final preferredPosition = baseline.cues.indexWhere(
          (cue) => cue.index == selectedCueNumber);
      final nextSelected = refreshed.cues.isEmpty ? -1 :
          refreshed.cues[preferredPosition.clamp(
              0, refreshed.cues.length - 1).toInt()].index;
      return _snapshotUpdate(refreshed, nextSelected);
    } catch (_) {
      return null;
    }
  }

  StudioDockCueStructureService get _structure => StudioDockCueStructureService(
    ref.read(projectRepositoryProvider),
    ref.read(subtitleRepositoryProvider),
  );

  StudioDockCueUpdate _snapshotUpdate(
      StudioDockSessionSnapshot snapshot, int selectedCueNumber) =>
      StudioDockCueUpdate(
        cues: [
          for (final cue in snapshot.cues)
            StudioDockCue(
              id: cue.index,
              start: cue.start,
              end: cue.end,
              original: cue.original,
              edited: cue.edited,
              storedEdited: cue.storedEdited,
              marked: cue.marked,
              comment: cue.comment,
              resolved: cue.resolved,
            ),
        ],
        selectedCueId: selectedCueNumber,
      );

  StudioDockCueUpdate _toWorkspaceUpdate(StudioDockStructureChange change) =>
      _snapshotUpdate(change.snapshot, change.selectedCueNumber);

  Future<StudioDockCueUpdate?> _insertCue(
    int? afterCueNumber,
    StudioDockNewCueDraft draft,
  ) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final change = await _structure.insert(
        baseline: baseline,
        afterCueNumber: afterCueNumber,
        start: draft.start,
        end: draft.end,
        original: draft.original,
        edited: draft.edited,
      );
      if (!mounted || change == null) return null;
      setState(() => _latestBaseline = change.snapshot);
      return _toWorkspaceUpdate(change);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _deleteCue(int cueNumber) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final change = await _structure.delete(
        baseline: baseline, cueNumber: cueNumber);
      if (!mounted || change == null) return null;
      setState(() => _latestBaseline = change.snapshot);
      return _toWorkspaceUpdate(change);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _splitCue(
    int cueNumber, StudioDockSplitCueDraft draft,
  ) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final change = await _structure.split(
        baseline: baseline,
        cueNumber: cueNumber,
        splitAt: draft.splitAt,
        firstOriginal: draft.firstOriginal,
        secondOriginal: draft.secondOriginal,
        firstEdited: draft.firstEdited,
        secondEdited: draft.secondEdited,
      );
      if (!mounted || change == null) return null;
      setState(() => _latestBaseline = change.snapshot);
      return _toWorkspaceUpdate(change);
    } catch (_) {
      return null;
    }
  }

  Future<StudioDockCueUpdate?> _mergeCue(
    int cueNumber, bool withPrevious,
  ) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final change = await _structure.merge(
        baseline: baseline, cueNumber: cueNumber,
        withPrevious: withPrevious,
      );
      if (!mounted || change == null) return null;
      setState(() => _latestBaseline = change.snapshot);
      return _toWorkspaceUpdate(change);
    } catch (_) {
      return null;
    }
  }

  StudioDockFileActions get _fileActions => StudioDockFileActions(
    ref.read(projectRepositoryProvider),
    ref.read(subtitleRepositoryProvider),
  );

  StudioDockProjectSaveActions get _projectActions => StudioDockProjectSaveActions(
    ref.read(projectRepositoryProvider),
    ref.read(subtitleRepositoryProvider),
    ref.read(projectSaveCoordinatorProvider),
  );

  Future<StudioDockFileResult> _saveProjectDocument() async {
    try {
      return await _projectActions.saveExisting(
        sessionId: widget.sessionId, collectionId: widget.collectionId);
    } catch (_) {
      return StudioDockFileResult.failed;
    }
  }

  Future<StudioDockFileResult> _saveProjectDocumentAs() async {
    try {
      final actions = _projectActions;
      final prepared = await actions.prepare(
        sessionId: widget.sessionId, collectionId: widget.collectionId);
      if (prepared == null || !mounted) return StudioDockFileResult.failed;
      final picked = await fp.FilePicker.platform.saveFile(
        dialogTitle: 'Save SubtitleStudio Project As',
        fileName: prepared.fileName,
        type: fp.FileType.custom,
        allowedExtensions: const ['msone'],
      );
      if (picked == null || picked.isEmpty || !mounted) {
        return StudioDockFileResult.canceled;
      }
      var outcome = await actions.writeToPath(
        prepared: prepared, selectedPath: picked);
      if (outcome != StudioDockFileResult.alreadyExists || !mounted) {
        return outcome;
      }
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Replace existing project file?'),
          content: const Text('The chosen .msone project already exists. '
              'Replacing it will overwrite the saved project and its '
              'checkpoint history at that location.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep existing project'),
            ),
            FilledButton(
              key: const ValueKey('studio-confirm-project-overwrite'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Replace project'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return StudioDockFileResult.canceled;
      return await actions.writeToPath(
        prepared: prepared, selectedPath: picked, replaceExisting: true);
    } catch (_) {
      return StudioDockFileResult.failed;
    }
  }

  Future<StudioDockFileResult> _saveSubtitleFile() async {
    try {
      return await _fileActions.saveExisting(
        sessionId: widget.sessionId, collectionId: widget.collectionId);
    } on FormatException {
      return StudioDockFileResult.invalidEncoding;
    } on UnsupportedError {
      return StudioDockFileResult.invalidEncoding;
    } catch (_) {
      return StudioDockFileResult.failed;
    }
  }

  Future<StudioDockFileResult> _saveAsSubtitleFile() =>
      _pickAndWriteFile(relink: true);

  Future<StudioDockFileResult> _exportSubtitleFile(bool originalOnly) =>
      _pickAndWriteFile(relink: false, originalOnly: originalOnly);

  Future<StudioDockFileResult> _pickAndWriteFile({
    required bool relink,
    bool originalOnly = false,
  }) async {
    try {
      final actions = _fileActions;
      final prepared = relink
          ? await actions.prepareSaveAs(
              sessionId: widget.sessionId, collectionId: widget.collectionId)
          : await actions.prepareExport(
              sessionId: widget.sessionId, collectionId: widget.collectionId,
              originalOnly: originalOnly);
      if (prepared == null || !mounted) return StudioDockFileResult.failed;
      final picked = await fp.FilePicker.platform.saveFile(
        dialogTitle: relink ? 'Save Subtitle As' : 'Export Subtitle',
        fileName: prepared.plan.fileName,
        type: fp.FileType.custom,
        allowedExtensions: const ['srt'],
      );
      if (picked == null || picked.isEmpty) return StudioDockFileResult.canceled;
      if (!mounted) return StudioDockFileResult.canceled;
      var outcome = await actions.writeToPath(
        prepared: prepared, selectedPath: picked);
      if (outcome != StudioDockFileResult.alreadyExists || !mounted) {
        return outcome;
      }
      // The system Save dialog may show its own replacement warning. Keep an
      // explicit in-app confirmation as well, including for plugin variants
      // that do not present a native warning.
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Replace existing subtitle file?'),
          content: const Text('The chosen file already exists. Replacing it '
              'will overwrite its contents with these subtitles.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep existing file'),
            ),
            FilledButton(
              key: const ValueKey('studio-confirm-overwrite'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Replace file'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return StudioDockFileResult.canceled;
      outcome = await actions.writeToPath(
        prepared: prepared, selectedPath: picked, replaceExisting: true);
      return outcome;
    } on FormatException {
      return StudioDockFileResult.invalidEncoding;
    } on UnsupportedError {
      return StudioDockFileResult.invalidEncoding;
    } catch (_) {
      return StudioDockFileResult.failed;
    }
  }


  @override
  void initState() {
    super.initState();
    // Suppress the still-mounted Editor's native in-app hotkeys while this
    // embedded route is visible, then restore them on disposal.
    if (widget.suppressParentEditorHotkeys) {
      MSoneHotkeyManager.instance.suspendCallbacks();
    }
    _snapshot = _load();
    _videoPath = widget.allowNativePlayback ? _resolveVideoPath() : null;
    unawaited(_refreshMsonePreference());
    unawaited(_refreshLineDisplay());
    unawaited(_refreshSavedSecondary());
  }

  @override
  void dispose() {
    _repeat.dispose();
    _playback.dispose();
    if (widget.suppressParentEditorHotkeys) {
      MSoneHotkeyManager.instance.resumeCallbacks();
    }
    super.dispose();
  }

  /// Add/change media from Studio Dock itself, never using classic Editor.
  /// Cancel and failed persistence leave the current playback untouched.
  Future<void> _chooseVideo() async {
    if (_selectingVideo || !widget.allowNativePlayback) return;
    setState(() => _selectingVideo = true);
    try {
      final path = await FilePickerSAF.pickFile(
        context: context,
        title: 'Select Studio Dock video',
        allowedExtensions: const [
          'mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v',
        ],
      );
      if (!mounted || path == null) return;
      if (!await File(path).exists()) {
        throw const FileSystemException('Selected video is unavailable.');
      }
      final repo = VideoRepository(EditorPreferencesRepository(ref.read(isarProvider)));
      await repo.saveVideoPath(widget.collectionId, path);
      if (!mounted) return;
      setState(() => _videoPath = Future<String?>.value(path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not attach this video. Check media access and retry.'),
      ));
    } finally {
      if (mounted) setState(() => _selectingVideo = false);
    }
  }

  /// Mirrors mobile Unload Video through the already-injected video
  /// repository. Unlink the stored path before changing the mounted player;
  /// a failed database write must leave playback and waveform untouched.
  Future<bool> _unloadVideo() async {
    if (_selectingVideo || !widget.allowNativePlayback) return false;
    setState(() => _selectingVideo = true);
    try {
      final current = await _videoPath;
      if (!mounted || current == null) return false;
      final repo = VideoRepository(
        EditorPreferencesRepository(ref.read(isarProvider)),
      );
      await repo.removeVideoPath(widget.collectionId);
      if (!mounted) return false;
      setState(() {
        _repeat.stop();
        _videoPath = Future<String?>.value(null);
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _selectingVideo = false);
    }
  }

  Future<String?> _resolveVideoPath() async {
    final repo = VideoRepository(EditorPreferencesRepository(ref.read(isarProvider)));
    try {
      return await StudioDockMediaPlan.resolveVideoPath(
        collectionId: widget.collectionId,
        getSavedPath: repo.getSavedVideoPath,
        exists: (path) => File(path).exists(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAppSettings() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SizedBox(
          width: 860,
          height: (MediaQuery.sizeOf(dialog).height - 64)
              .clamp(240.0, 840.0).toDouble(),
          child: SettingsSheet(onSettingsChanged: () {
            if (mounted) {
              setState(() {});
              unawaited(_refreshMsonePreference());
              unawaited(_refreshLineDisplay());
            }
          }),
        ),
      ),
    );
    if (mounted) await _refreshMsonePreference();
    if (mounted) await _refreshLineDisplay();
  }

  Future<void> _saveProjectFromSettings() async {
    var result = await _saveProjectDocument();
    if (result == StudioDockFileResult.needsLocation) {
      result = await _saveProjectDocumentAs();
    }
    if (!mounted || result == StudioDockFileResult.canceled) return;
    final message = switch (result) {
      StudioDockFileResult.saved => 'Project file saved successfully.',
      StudioDockFileResult.savedButUnlinked =>
        'Project file written, but the project path could not be linked.',
      StudioDockFileResult.stale =>
        'The project changed during Save. Refresh and try again.',
      _ => 'Could not save the project file. Please try again.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshAfterProjectSettings() async {
    final preferredCue = _dockKey.currentState?.selectedCueNumber ?? -1;
    try {
      final refreshed = await _load();
      final resolvedVideo = widget.allowNativePlayback
          ? await _resolveVideoPath() : null;
      String? oldVideo;
      try {
        oldVideo = await _videoPath;
      } catch (_) {
        // An unavailable previous media link should not block project reload.
      }
      if (!mounted) return;
      setState(() {
        _latestBaseline = refreshed;
        // Keep the initial FutureBuilder completed: replacing its Future
        // would briefly remount the whole Dock and native media surface.
        if (widget.allowNativePlayback && resolvedVideo != oldVideo) {
          _videoPath = Future<String?>.value(resolvedVideo);
        }
      });
      final selected = refreshed.cues.any((cue) => cue.index == preferredCue)
          ? preferredCue
          : refreshed.cues.isEmpty ? -1 : refreshed.cues.first.index;
      _dockKey.currentState?.acceptExternalCueUpdate(
          _snapshotUpdate(refreshed, selected));
      await _refreshSavedSecondary();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not refresh Project Settings. Reopen the project before editing.'),
        ));
      }
    }
  }

  Future<void> _refreshAfterCheckpointRestore() async {
    // Shared history actions already committed the HEAD transition. Reload
    // the authoritative session before permitting further text edits.
    await _refreshAfterProjectSettings();
    if (mounted) {
      await _dockKey.currentState?.reloadHistoryFromSession();
    }
  }

  Future<void> _openProjectSettings() async {
    if (!mounted) return;
    try {
      // The embedded subtitle collection can be large. Open the route first
      // and perform independent reads concurrently, so clicking Settings
      // never freezes the workspace while storage is being queried.
      final projectData = Future.wait<Object?>([
        ref.read(projectRepositoryProvider).getSession(widget.sessionId),
        _collectionForSettings(),
      ]);
      await showDialog<void>(
        context: context,
        builder: (dialog) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 880,
            height: (MediaQuery.sizeOf(dialog).height - 64)
                .clamp(240.0, 840.0).toDouble(),
            child: FutureBuilder<List<Object?>>(
              future: projectData,
              builder: (context, result) {
                if (result.hasError) {
                  return Center(child: Text(
                    'Could not load Project Settings. Please try again.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ));
                }
                if (!result.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final session = result.data![0] as Session?;
                final collection = result.data![1] as SubtitleCollection?;
                if (session == null || collection == null ||
                    session.subtitleCollectionId != collection.id) {
                  return const Center(child: Text(
                      'The active subtitle project is unavailable.'));
                }
                return ProjectSettingsSheet(
                  session: session,
                  subtitleCollection: collection,
                  // Mutations are still reconciled with the live editor after
                  // the route closes, preserving project-data consistency.
                  onProjectUpdated: () {},
                  onSecondarySubtitlesLoaded: _setSecondaryLocally,
                  onSecondarySubtitlesCleared: _clearSecondaryLocally,
                  onSaveProject: _saveProjectFromSettings,
                  onLoadVideo: _chooseVideo,
                );
              },
            ),
          ),
        ),
      );
    } catch (error, stack) {
      debugPrint('Studio Dock Project Settings failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Project Settings could not open. '
              'See the debug output for details.'),
        ));
      }
    } finally {
      if (mounted) await _refreshAfterProjectSettings();
    }
  }

  /// Reuse the collection already read when the project opened. Settings
  /// previously fetched all embedded subtitle lines a second time before
  /// showing anything. Project text edits are reflected from the authoritative
  /// live snapshot; file metadata comes from the original loaded collection.
  Future<SubtitleCollection?> _collectionForSettings() async {
    final cached = _loadedCollection;
    final baseline = _latestBaseline;
    if (cached == null || baseline == null ||
        cached.id != widget.collectionId ||
        baseline.collectionId != widget.collectionId) {
      return ref.read(subtitleRepositoryProvider)
          .fetchSubtitleCollection(widget.collectionId);
    }
    final lines = <SubtitleLine>[
      for (final cue in baseline.cues)
        (SubtitleLine()
          ..index = cue.index
          ..startTime = cue.start
          ..endTime = cue.end
          ..original = cue.original
          ..edited = cue.edited.isEmpty ? null : cue.edited
          ..marked = cue.marked
          ..comment = cue.comment
          ..resolved = cue.resolved),
    ];
    return SubtitleCollection(
      fileName: cached.fileName,
      filePath: cached.filePath,
      originalFileUri: cached.originalFileUri,
      encoding: baseline.encoding,
      macOsSrtBookmark: cached.macOsSrtBookmark,
      lines: lines,
    )..id = cached.id;
  }

  Future<void> _refreshAfterCommentImport() async {
    final priorSelection = _dockKey.currentState?.selectedCueNumbers ?? const <int>[];
    final preferredCue = _dockKey.currentState?.selectedCueNumber ?? -1;
    try {
      final refreshed = await _load();
      if (!mounted) return;
      setState(() => _latestBaseline = refreshed);
      final surviving = refreshed.cues.map((cue) => cue.index).toSet();
      final selected = surviving.contains(preferredCue)
          ? preferredCue
          : refreshed.cues.isEmpty ? -1 : refreshed.cues.first.index;
      final update = _snapshotUpdate(refreshed, selected);
      _dockKey.currentState?.acceptExternalCueUpdate(StudioDockCueUpdate(
        cues: update.cues,
        selectedCueId: selected,
        selectedCueIds: priorSelection.where(surviving.contains).toList(),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not refresh imported comments. Reopen the project before editing.'),
        ));
      }
    }
  }

  Future<void> _openImportComments() async {
    if (!mounted) return;
    final session = await ref.read(projectRepositoryProvider)
        .getSession(widget.sessionId);
    if (!mounted) return;
    if (session == null || session.subtitleCollectionId != widget.collectionId) {
      throw StateError('The active subtitle project is unavailable.');
    }
    var imported = false;
    await showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 800,
          height: (MediaQuery.sizeOf(dialog).height - 64)
              .clamp(240.0, 760.0).toDouble(),
          child: ImportCommentsSheet(
            subtitleCollectionId: widget.collectionId,
            onCommentsImported: () => imported = true,
          ),
        ),
      ),
    );
    if (imported && mounted) await _refreshAfterCommentImport();
  }

  List<SubtitleLine> _msoneToolLines(StudioDockSessionSnapshot snapshot) => [
    for (final cue in snapshot.cues)
      SubtitleLine()
        ..index = cue.index
        ..startTime = cue.start
        ..endTime = cue.end
        ..original = cue.original
        ..edited = cue.storedEdited
        ..marked = cue.marked
        ..comment = cue.comment
        ..resolved = cue.resolved,
  ];

  Future<void> _runMsoneEditorTool({required bool banners}) async {
    if (!mounted || !widget.enableEditing || !_msoneEnabled) return;
    final session = await ref.read(projectRepositoryProvider)
        .getSession(widget.sessionId);
    if (!mounted || session == null ||
        session.subtitleCollectionId != widget.collectionId) {
      throw StateError('The MSone subtitle project is unavailable.');
    }
    final current = await _load();
    if (!mounted || current.cues.isEmpty) return;
    bool applied = false;
    final lines = _msoneToolLines(current);
    try {
      if (banners) {
        await showEditorBannerSheet(
          context: context,
          subtitleCollectionId: widget.collectionId,
          sessionId: widget.sessionId,
          subtitleLines: lines,
          onBannersInserted: () async { applied = true; },
        );
      } else {
        await showEditorNormalizationSheet(
          context: context,
          subtitleCollectionId: widget.collectionId,
          sessionId: widget.sessionId,
          subtitleLines: lines,
          onNormalizationComplete: () async { applied = true; },
        );
      }
    } finally {
      if (applied && mounted) {
        // The original mobile sheets commit the operation into shared
        // checkpoint history. Reflect every changed cue without remounting
        // the current native player or replacing Studio Dock State.
        final selection = _dockKey.currentState?.selectedCueNumbers
            ?? const <int>[];
        final preferred = _dockKey.currentState?.selectedCueNumber ?? -1;
        try {
          final updated = await _load();
          if (mounted) {
            setState(() => _latestBaseline = updated);
            final indices = updated.cues.map((cue) => cue.index).toSet();
            final selected = indices.contains(preferred)
                ? preferred : updated.cues.isEmpty ? -1
                : updated.cues.first.index;
            final next = _snapshotUpdate(updated, selected);
            _dockKey.currentState?.acceptExternalCueUpdate(
              StudioDockCueUpdate(
                cues: next.cues,
                selectedCueId: selected,
                selectedCueIds: selection.where(indices.contains).toList(),
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not refresh the MSone tool changes. '
                  'Reopen the project before further editing.'),
            ));
          }
        }
      }
    }
  }

  Future<void> _openMsoneBanners() =>
      _runMsoneEditorTool(banners: true);

  Future<void> _openMalayalamNormalize() =>
      _runMsoneEditorTool(banners: false);

  Future<void> _openHelp() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const HelpScreen(),
    ));
  }

  Future<StudioDockSessionSnapshot> _load() {
    final loader = StudioDockSessionLoader(
      ref.read(projectRepositoryProvider),
      ref.read(subtitleRepositoryProvider),
    );
    return loader.load(
      sessionId: widget.sessionId,
      collectionId: widget.collectionId,
      onCollectionLoaded: (collection) {
        if (widget.collectionId == collection.id) {
          _loadedCollection = collection;
        }
      },
    );
  }

  Future<bool> _changeProjectEncoding(String encoding) async {
    if (!widget.enableEditing) return false;
    try {
      final supported = await SubtitleExtendedEncodingService.standard
          .availableEncodings();
      if (!supported.contains(encoding)) return false;
      final updated = await ref.read(subtitleRepositoryProvider).updateEncoding(
        collectionId: widget.collectionId,
        sessionId: widget.sessionId,
        encoding: encoding,
      );
      if (!updated || !mounted) return false;
      final refreshed = await _load();
      if (!mounted) return false;
      setState(() => _latestBaseline = refreshed);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateMarkedSheetReview(int zeroBasedIndex, {
      String? comment, bool changeComment = false,
      bool? marked, bool? resolved}) async {
    final baseline = _latestBaseline;
    if (!widget.enableEditing || baseline == null) return;
    final matching = baseline.cues.where(
        (cue) => cue.index == zeroBasedIndex + 1);
    if (matching.isEmpty) return;
    final cue = matching.first;
    final updated = await _applyNotes(cue.index,
        changeComment ? comment : cue.comment,
        marked ?? cue.marked, resolved ?? cue.resolved);
    if (updated != null && mounted) {
      _dockKey.currentState?.acceptExternalCueUpdate(updated);
    }
  }

  Future<void> _openMarkedLinesSheet(int preferredCue) async {
    if (!mounted) return;
    final collection = await ref.read(subtitleRepositoryProvider)
        .fetchSubtitleCollection(widget.collectionId);
    if (collection == null || !mounted) return;
    final marked = collection.lines.where((line) => line.marked).toList();
    final withComments = collection.lines.where((line) =>
        line.marked || (line.comment?.trim().isNotEmpty ?? false)).toList();
    await showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          key: const ValueKey('studio-marked-lines-sheet'),
          width: 960,
          height: (MediaQuery.sizeOf(dialog).height - 48)
              .clamp(260.0, 860.0).toDouble(),
          child: MarkedLinesSheet(
            markedLines: marked,
            allLinesWithComments: withComments,
            allSubtitleLines: collection.lines,
            initialHighlightLineIndex: preferredCue > 0 ? preferredCue : null,
            onLineSelected: (index) {
              Navigator.pop(dialog);
              _dockKey.currentState?.highlightCueFromWaveform(index + 1);
            },
            onCommentUpdated: !widget.enableEditing ? null :
                (index, comment) => unawaited(_updateMarkedSheetReview(index,
                    comment: comment, changeComment: true)),
            onLineUnmarked: !widget.enableEditing ? null :
                (index) => unawaited(_updateMarkedSheetReview(index,
                    comment: null, changeComment: true, marked: false)),
            onGroupUnmarked: !widget.enableEditing ? null :
                _unmarkEffectFromMarkedSheet,
            onResolvedUpdated: !widget.enableEditing ? null :
                (index, resolved) => unawaited(_updateMarkedSheetReview(index,
                    resolved: resolved)),
            onTextEdited: !widget.enableEditing ? null :
                (index, text) => unawaited(_updateMarkedSheetText(index, text)),
          ),
        ),
      ),
    );
  }

  Future<bool> _unmarkEffectFromMarkedSheet(
      List<int> zeroBasedIndices) async {
    if (zeroBasedIndices.isEmpty) return false;
    final indices = [for (final index in zeroBasedIndices) index + 1];
    final update = await _applyBulkReview(indices,
        StudioDockReviewAction.unmark, indices.first);
    if (update == null || !mounted) return false;
    _dockKey.currentState?.acceptExternalCueUpdate(update);
    return true;
  }

  Future<void> _updateMarkedSheetText(int zeroBasedIndex, String text) async {
    if (!await _applyText(zeroBasedIndex + 1, text) || !mounted) return;
    final baseline = _latestBaseline;
    if (baseline != null) {
      _dockKey.currentState?.acceptExternalCueUpdate(
          _snapshotUpdate(baseline, zeroBasedIndex + 1));
    }
  }

  Future<StudioDockCueUpdate?> _applyEffect(
      int cueNumber, String type, Map<String, dynamic> config) async {
    final baseline = _latestBaseline;
    if (!widget.enableEditing || baseline == null ||
        !baseline.cues.any((line) => line.index == cueNumber)) return null;
    final colorValue = config['color'];
    final delayValue = config['endDelay'];
    if (colorValue is! String ||
        !RegExp(r'^[a-fA-F0-9]{8}$').hasMatch(colorValue) ||
        delayValue is! num || !delayValue.toDouble().isFinite ||
        delayValue < 0) return null;
    try {
      final repository = ref.read(subtitleRepositoryProvider);
      final current = await repository.fetchSubtitleCollection(widget.collectionId);
      if (current == null) return null;
      final index = current.lines.indexWhere((line) => line.index == cueNumber);
      if (index < 0) return null;
      final source = current.lines[index];
      // Effects must not be generated from a stale desktop selection.
      final observed = baseline.cues.firstWhere((cue) => cue.index == cueNumber);
      if (source.startTime != observed.start ||
          source.endTime != observed.end ||
          source.original != observed.original ||
          source.edited != observed.storedEdited) return null;
      final color = colorValue.substring(2);
      final List<SubtitleLine> generated;
      switch (type) {
        case 'karaoke':
          generated = await SubtitleEffectOperations.generateKaraokeEffect(
            originalLine: source,
            color: color,
            endDelay: delayValue.toDouble(),
            effectType: config['effectType'] == 'character'
                ? 'character' : 'word',
            hasTextSelection: config['hasTextSelection'] == true,
            selectionStart: config['selectionStart'] is int
                ? config['selectionStart'] as int : 0,
            selectionEnd: config['selectionEnd'] is int
                ? config['selectionEnd'] as int : 0,
            selectedText: config['selectedText'] is String
                ? config['selectedText'] as String : null,
            fullText: config['fullText'] is String
                ? config['fullText'] as String : null,
          );
        case 'typewriter':
          generated = await SubtitleEffectOperations.generateTypewriterEffect(
            originalLine: source,
            color: color,
            endDelay: delayValue.toDouble(),
          );
        case final String effect when SrtEffectFrames.supported.contains(effect):
          final alternate = config['alternateColor'];
          generated = await SubtitleEffectOperations.generateSrtEffect(
            originalLine: source, effect: effect, color: color,
            alternateColor: alternate is String &&
                RegExp(r'^[a-fA-F0-9]{8}$').hasMatch(alternate)
                    ? alternate.substring(2) : 'FFFF00',
            endDelay: delayValue.toDouble(),
          );
        default:
          return null;
      }
      if (generated.isEmpty) return null;
      final committed = await repository.replaceLineWithGeneratedLinesWithHistory(
        collectionId: widget.collectionId,
        originalIndex: index,
        replacementLines: generated,
        sessionId: widget.sessionId,
        description: 'Applied $type effect to line $cueNumber '
            '(${generated.length} lines)',
      );
      if (!committed || !mounted) return null;
      final refreshed = await _load();
      if (!mounted) return null;
      setState(() => _latestBaseline = refreshed);
      return _snapshotUpdate(refreshed, cueNumber);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant StudioDockSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId ||
        widget.collectionId != oldWidget.collectionId) {
      _latestBaseline = null;
      _loadedCollection = null;
      _dockKey = GlobalKey<StudioDockWorkspaceState>();
      _snapshot = _load();
      _videoPath = widget.allowNativePlayback ? _resolveVideoPath() : null;
      _nativePlayerState = null;
      _secondarySource = EditorSecondarySubtitleSource.none;
      _externalSecondary = const [];
      _showSecondary = true;
      unawaited(_refreshSavedSecondary());
      unawaited(_refreshLineDisplay());
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StudioDockSessionSnapshot>(
    future: _snapshot,
    builder: (context, state) {
      if (state.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (state.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Studio Dock')),
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Could not load this subtitle session.'),
              const SizedBox(height: 14),
              if (widget.onChooseProject != null)
                OutlinedButton.icon(
                  onPressed: widget.onChooseProject,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose another project'),
                ),
            ]),
          ),
        );
      }
      final loaded = state.requireData;
      _latestBaseline ??= loaded;
      final session = _latestBaseline!;
      final cues = [
        for (final line in session.cues)
          StudioDockCue(
            id: line.index,
            start: line.start,
            end: line.end,
            original: line.original,
            edited: line.edited,
            storedEdited: line.storedEdited,
            marked: line.marked,
            comment: line.comment,
            resolved: line.resolved,
          ),
      ];
      final videoCues = StudioDockMediaPlan.overlayCues(session);
      _repeat.updateCues(videoCues);
      Widget buildDock(String? validVideoPath) => StudioDockWorkspace(
        key: _dockKey,
        initialCues: cues,
        playback: widget.allowNativePlayback ? _playback : null,
        isLiveSession: true,
        projectTitle: session.fileName,
        encoding: session.encoding,
        onChangeEncoding:
            widget.enableEditing ? _changeProjectEncoding : null,
        isEditMode: session.isEditMode,
        showOriginalLine: _lineDisplay.showOriginalLine,
        autoSaveWithNavigation: _lineDisplay.autoSaveWithNavigation,
        showOriginalTextField: _lineDisplay.showOriginalTextField,
        maxLineLength: _lineDisplay.maxLineLength,
        onSaveEditPreference: _saveLineDisplayPreference,
        onChooseProject: widget.onChooseProject,
        projects: widget.projects,
        activeProjectId: widget.activeProjectId,
        onSelectProject: widget.onSelectProject,
        onImportFile: widget.onImportFile,
        onNewProject: widget.onNewProject,
        onChooseVideo: widget.allowNativePlayback ? _chooseVideo : null,
        onUnloadVideo: widget.allowNativePlayback ? _unloadVideo : null,
        onTogglePlayback:
            widget.allowNativePlayback ? _toggleExistingPlayback : null,
        onToggleFullscreen:
            widget.allowNativePlayback ? _toggleExistingFullscreen : null,
        onToggleRepeat:
            widget.allowNativePlayback ? _toggleRepeatCurrent : null,
        onOpenRepeatRange:
            widget.allowNativePlayback ? _openRepeatRange : null,
        onSelectedCueChanged: _repeat.selectCue,
        repeatEnabled: _repeat.enabled,
        onOpenAppSettings: _openAppSettings,
        onOpenProjectSettings:
            widget.enableEditing && widget.allowNativePlayback
                ? _openProjectSettings : null,
        onOpenMarkedLines: _openMarkedLinesSheet,
        onImportComments: widget.enableEditing ? _openImportComments : null,
        onRemoveHearingImpaired:
            widget.enableEditing ? _removeHearingImpaired : null,
        onOpenHelp: _openHelp,
        onSubmitToMsone: _msoneEnabled ? _submitToMsone : null,
        onInsertMsoneBanners: widget.enableEditing && _msoneEnabled
            ? _openMsoneBanners : null,
        onNormalizeMalayalam: widget.enableEditing && _msoneEnabled
            ? _openMalayalamNormalize : null,
        onLoadSecondarySubtitles: _openSecondaryPicker,
        onToggleSecondarySubtitles:
            _secondarySource == EditorSecondarySubtitleSource.none
                ? null : _toggleSecondaryVisibility,
        showSecondarySubtitles: _showSecondary,
        onApplyCueText: widget.enableEditing ? _applyText : null,
        onApplyCueOriginal: widget.enableEditing ? _applyOriginalText : null,
        onApplyCueTiming: widget.enableEditing ? _applyTiming : null,
        onApplyCueTextAndTiming:
            widget.enableEditing ? _applyCueContent : null,
        onApplyCueNotes: widget.enableEditing ? _applyNotes : null,
        onApplyBulkReview:
            widget.enableEditing ? _applyBulkReview : null,
        onFindCues: _findCues,
        onReplaceMatches: widget.enableEditing ? _replaceMatches : null,
        onApplyQualityFixes:
            widget.enableEditing ? _applyQualityFixes : null,
        onApplyQualityTimingSuggestions:
            widget.enableEditing ? _applyQualityTimingSuggestions : null,
        onShiftAllCues: widget.enableEditing ? _shiftAllCues : null,
        onSyncAnchoredCues: widget.enableEditing ? _syncAnchoredCues : null,
        onConvertFramerate: widget.enableEditing ? _convertFramerateCues : null,
        getVideoFramerate: () => _nativePlayerState?.getFrameRate(),
        onShiftSelectedCues:
            widget.enableEditing ? _shiftSelectedCues : null,
        onDeleteSelectedCues:
            widget.enableEditing ? _deleteSelectedCues : null,
        onClearAllFormatting:
            widget.enableEditing ? _clearAllFormatting : null,
        onApplyEffect: widget.enableEditing ? _applyEffect : null,
        onInsertCue: widget.enableEditing ? _insertCue : null,
        onDeleteCue: widget.enableEditing ? _deleteCue : null,
        onSplitCue: widget.enableEditing ? _splitCue : null,
        onMergeCue: widget.enableEditing ? _mergeCue : null,
        onLoadHistory: widget.enableEditing ? _loadHistory : null,
        onRestoreHistory: widget.enableEditing ? _restoreHistory : null,
        checkpointHistoryPanel: widget.enableEditing
            ? CheckpointHistoryPanel(
                key: ValueKey('studio-dock-checkpoint-graph-${widget.sessionId}'),
                sessionId: widget.sessionId,
                onCheckpointRestored: () =>
                    unawaited(_refreshAfterCheckpointRestore()),
              ) : null,
        onLoadSourceView: _loadRawSource,
        onApplySourceView: widget.enableEditing ? _applyRawSource : null,
        onSaveFile: widget.enableEditing && widget.allowNativePlayback
            ? _saveSubtitleFile : null,
        onSaveAsFile: widget.enableEditing && widget.allowNativePlayback
            ? _saveAsSubtitleFile : null,
        onExportFile: widget.enableEditing && widget.allowNativePlayback
            ? _exportSubtitleFile : null,
        onSaveProject: widget.enableEditing && widget.allowNativePlayback
            ? _saveProjectDocument : null,
        onSaveProjectAs: widget.enableEditing && widget.allowNativePlayback
            ? _saveProjectDocumentAs : null,
        manageLiveHotkeys: !widget.suppressParentEditorHotkeys,
        videoSurface: validVideoPath == null || !widget.allowNativePlayback
            ? null
            : StudioDockVideoSurface(
                key: ValueKey('studio-dock-player-${session.collectionId}-$validVideoPath'),
                collectionId: session.collectionId,
                videoPath: validVideoPath,
                subtitles: videoCues,
                secondarySubtitles: _secondaryOverlay(session),
                onPlayerStateChanged: (player) => _nativePlayerState = player,
                onSubtitleMarked: widget.enableEditing
                    ? _markFromFullscreen : null,
                onSubtitleReviewSaved: widget.enableEditing
                    ? _saveFullscreenComment : null,
                onSubtitleResolvedChanged: widget.enableEditing
                    ? _resolveFromFullscreen : null,
                onRepeatModeToggled: _setRepeatMode,
                isRepeatModeEnabled: _repeat.enabled,
                onOpenRepeatRange: _openRepeatRange,
                playback: _playback,
              ),
        waveformSurface: validVideoPath == null || !widget.allowNativePlayback
            ? null
            : StudioDockWaveformSurface(
                key: ValueKey('studio-dock-waveform-${session.collectionId}-$validVideoPath'),
                videoPath: validVideoPath,
                collectionId: session.collectionId,
                playback: _playback,
                onApplyTimeEdit:
                    widget.enableEditing ? _applyWaveformTime : null,
                onAddLineConfirmed:
                    widget.enableEditing ? _requestWaveformCue : null,
                onSubtitleHighlight: (cueNumber) =>
                    _dockKey.currentState?.highlightCueFromWaveform(cueNumber),
                subtitles: [
                  for (final line in session.cues)
                    SubtitleLine()
                      ..index = line.index
                      ..startTime = line.start
                      ..endTime = line.end
                      ..original = line.original
                      ..edited = line.storedEdited
                      ..marked = line.marked
                      ..comment = line.comment
                      ..resolved = line.resolved,
                ],
              ),
      );
      final mediaFuture = _videoPath;
      if (mediaFuture == null) return buildDock(null);
      return FutureBuilder<String?>(
        future: mediaFuture,
        builder: (context, video) =>
            buildDock(video.connectionState == ConnectionState.done &&
                    !video.hasError ? video.data : null),
      );
    },
  );
}
