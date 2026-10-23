import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/editor_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/video_repository.dart';
import 'package:subtitle_studio/screens/edit/providers/subtitle_repository_provider.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';

import 'desktop_workspace_preview.dart';
import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';
import 'studio_dock_text_edit_service.dart';
import 'studio_dock_timing_edit_service.dart';
import 'studio_dock_cue_structure_service.dart';
import 'studio_dock_insert_cue_dialog.dart';
import 'studio_dock_media_plan.dart';
import 'studio_dock_video_surface.dart';
import 'studio_dock_waveform_surface.dart';
import 'studio_dock_playback_link.dart';

/// Shared live-session Studio Dock host. In DS3 R2 it can optionally expose
/// text-only editing through the existing atomic history transaction.
/// Media, timing changes and external file export remain disconnected.
class StudioDockReadOnlySessionView extends ConsumerStatefulWidget {
  const StudioDockReadOnlySessionView({
    super.key,
    required this.sessionId,
    required this.collectionId,
    this.onChooseProject,
    this.onImportFile,
    this.onNewProject,
    this.enableTextEditing = false,
    this.allowNativePlayback = false,
    this.suppressParentEditorHotkeys = true,
  });

  final int sessionId;
  final int collectionId;
  final VoidCallback? onChooseProject;
  final VoidCallback? onImportFile;
  final VoidCallback? onNewProject;
  /// Opt in to checkpoint-backed text edits; the old Editor preview stays read-only.
  final bool enableTextEditing;
  /// Only true for the standalone native desktop Home. An Editor-hosted route
  /// leaves this false, avoiding a second player behind the classic Editor.
  final bool allowNativePlayback;
  /// Enable only when opened *over* a still-mounted classic Editor route.
  final bool suppressParentEditorHotkeys;

  @override
  ConsumerState<StudioDockReadOnlySessionView> createState() =>
      _StudioDockReadOnlySessionViewState();
}

class _StudioDockReadOnlySessionViewState
    extends ConsumerState<StudioDockReadOnlySessionView> {
  late Future<StudioDockSessionSnapshot> _snapshot;
  Future<String?>? _videoPath;
  bool _selectingVideo = false;
  StudioDockSessionSnapshot? _latestBaseline;
  final StudioDockPlaybackLink _playback = StudioDockPlaybackLink();

  Future<bool> _applyText(int cueNumber, String editedText) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableTextEditing) return false;
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
    if (baseline == null || !widget.enableTextEditing) return false;
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

  StudioDockCueStructureService get _structure => StudioDockCueStructureService(
    ref.read(projectRepositoryProvider),
    ref.read(subtitleRepositoryProvider),
  );

  WorkspaceCueUpdate _toWorkspaceUpdate(StudioDockStructureChange change) =>
      WorkspaceCueUpdate(
        cues: [
          for (final cue in change.snapshot.cues)
            WorkspaceDemoCue(
              id: cue.index,
              start: cue.start,
              end: cue.end,
              original: cue.original,
              edited: cue.edited,
              marked: cue.marked,
            ),
        ],
        selectedCueId: change.selectedCueNumber,
      );

  Future<WorkspaceCueUpdate?> _insertCue(
    int? afterCueNumber,
    StudioDockNewCueDraft draft,
  ) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableTextEditing) return null;
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

  Future<WorkspaceCueUpdate?> _deleteCue(int cueNumber) async {
    final baseline = _latestBaseline;
    if (baseline == null || !widget.enableTextEditing) return null;
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


  @override
  void initState() {
    super.initState();
    // Suppress the still-mounted Editor's native in-app hotkeys while this
    // read-only route is visible, then restore them on disposal.
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
  void didUpdateWidget(covariant StudioDockReadOnlySessionView oldWidget) {
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
          WorkspaceDemoCue(
            id: line.index,
            start: line.start,
            end: line.end,
            original: line.original,
            edited: line.edited,
            marked: line.marked,
          ),
      ];
      Widget buildDock(String? validVideoPath) => DesktopWorkspacePreview(
        key: ValueKey('studio-dock-session-${session.sessionId}'),
        initialCues: cues,
        liveReadOnly: true,
        projectTitle: session.fileName,
        encoding: session.encoding,
        onChooseProject: widget.onChooseProject,
        onImportFile: widget.onImportFile,
        onNewProject: widget.onNewProject,
        onChooseVideo: widget.allowNativePlayback ? _chooseVideo : null,
        onApplyCueText: widget.enableTextEditing ? _applyText : null,
        onApplyCueTiming: widget.enableTextEditing ? _applyTiming : null,
        onInsertCue: widget.enableTextEditing ? _insertCue : null,
        onDeleteCue: widget.enableTextEditing ? _deleteCue : null,
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
