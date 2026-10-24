import 'dart:io';

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
import 'studio_dock_file_actions.dart';
import 'studio_dock_project_save_actions.dart';
import 'studio_dock_history_service.dart';
import 'studio_dock_source_view_service.dart';
import 'studio_dock_notes_service.dart';
import 'studio_dock_cue_edit_service.dart';
import 'studio_dock_bulk_review_service.dart';
import 'studio_dock_search_service.dart';
import 'studio_dock_bulk_tools_service.dart';

/// Live Studio Dock host backed by the shared project, subtitle, history,
/// native media and file services.
class StudioDockSessionView extends ConsumerStatefulWidget {
  const StudioDockSessionView({
    super.key,
    required this.sessionId,
    required this.collectionId,
    this.onChooseProject,
    this.onImportFile,
    this.onNewProject,
    this.enableEditing = false,
    this.allowNativePlayback = false,
    this.suppressParentEditorHotkeys = true,
  });

  final int sessionId;
  final int collectionId;
  final VoidCallback? onChooseProject;
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
  final StudioDockPlaybackLink _playback = StudioDockPlaybackLink();

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
              original: cue.original, edited: cue.edited, marked: cue.marked,
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
      List<int> cueNumbers, bool marked, int preferredCue) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableEditing) return null;
    try {
      final updated = await StudioDockBulkReviewService(
        ref.read(projectRepositoryProvider),
        ref.read(subtitleRepositoryProvider),
      ).apply(
        baseline: baseline,
        cueNumbers: cueNumbers.toSet(),
        marked: marked,
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
      return actions.writeToPath(
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
  }

  @override
  void dispose() {
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

  Future<StudioDockSessionSnapshot> _load() {
    final loader = StudioDockSessionLoader(
      ref.read(projectRepositoryProvider),
      ref.read(subtitleRepositoryProvider),
    );
    return loader.load(
      sessionId: widget.sessionId,
      collectionId: widget.collectionId,
    );
  }

  @override
  void didUpdateWidget(covariant StudioDockSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId ||
        widget.collectionId != oldWidget.collectionId) {
      _latestBaseline = null;
      _snapshot = _load();
      _videoPath = widget.allowNativePlayback ? _resolveVideoPath() : null;
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
            marked: line.marked,
            comment: line.comment,
            resolved: line.resolved,
          ),
      ];
      Widget buildDock(String? validVideoPath) => StudioDockWorkspace(
        key: ValueKey('studio-dock-session-${session.sessionId}'),
        initialCues: cues,
        playback: widget.allowNativePlayback ? _playback : null,
        isLiveSession: true,
        projectTitle: session.fileName,
        encoding: session.encoding,
        onChooseProject: widget.onChooseProject,
        onImportFile: widget.onImportFile,
        onNewProject: widget.onNewProject,
        onChooseVideo: widget.allowNativePlayback ? _chooseVideo : null,
        onApplyCueText: widget.enableEditing ? _applyText : null,
        onApplyCueTiming: widget.enableEditing ? _applyTiming : null,
        onApplyCueTextAndTiming:
            widget.enableEditing ? _applyCueContent : null,
        onApplyCueNotes: widget.enableEditing ? _applyNotes : null,
        onApplyBulkReview:
            widget.enableEditing ? _applyBulkReview : null,
        onFindCues: _findCues,
        onReplaceMatches: widget.enableEditing ? _replaceMatches : null,
        onShiftAllCues: widget.enableEditing ? _shiftAllCues : null,
        onClearAllFormatting:
            widget.enableEditing ? _clearAllFormatting : null,
        onInsertCue: widget.enableEditing ? _insertCue : null,
        onDeleteCue: widget.enableEditing ? _deleteCue : null,
        onSplitCue: widget.enableEditing ? _splitCue : null,
        onMergeCue: widget.enableEditing ? _mergeCue : null,
        onLoadHistory: widget.enableEditing ? _loadHistory : null,
        onRestoreHistory: widget.enableEditing ? _restoreHistory : null,
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
                subtitles: StudioDockMediaPlan.overlayCues(session),
                playback: _playback,
              ),
        waveformSurface: validVideoPath == null || !widget.allowNativePlayback
            ? null
            : StudioDockWaveformSurface(
                key: ValueKey('studio-dock-waveform-${session.collectionId}-$validVideoPath'),
                videoPath: validVideoPath,
                collectionId: session.collectionId,
                playback: _playback,
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
