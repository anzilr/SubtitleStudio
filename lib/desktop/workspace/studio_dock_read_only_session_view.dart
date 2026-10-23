import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/screens/edit/providers/subtitle_repository_provider.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';

import 'desktop_workspace_preview.dart';
import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';
import 'studio_dock_text_edit_service.dart';

/// Shared live-session Studio Dock host. In DS3 R2 it can optionally expose
/// text-only editing through the existing atomic history transaction.
/// Media, timing changes and external file export remain disconnected.
class StudioDockReadOnlySessionView extends ConsumerStatefulWidget {
  const StudioDockReadOnlySessionView({
    super.key,
    required this.sessionId,
    required this.collectionId,
    this.onChooseProject,
    this.enableTextEditing = false,
  });

  final int sessionId;
  final int collectionId;
  final VoidCallback? onChooseProject;
  /// Opt in to checkpoint-backed text edits; the old Editor preview stays read-only.
  final bool enableTextEditing;

  @override
  ConsumerState<StudioDockReadOnlySessionView> createState() =>
      _StudioDockReadOnlySessionViewState();
}

class _StudioDockReadOnlySessionViewState
    extends ConsumerState<StudioDockReadOnlySessionView> {
  late Future<StudioDockSessionSnapshot> _snapshot;
  StudioDockSessionSnapshot? _latestBaseline;

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
      _latestBaseline = updated;
      return true;
    } catch (_) {
      return false;
    }
  }


  @override
  void initState() {
    super.initState();
    // Suppress the still-mounted Editor's native in-app hotkeys while this
    // read-only route is visible, then restore them on disposal.
    MSoneHotkeyManager.instance.suspendCallbacks();
    _snapshot = _load();
  }

  @override
  void dispose() {
    MSoneHotkeyManager.instance.resumeCallbacks();
    super.dispose();
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
      final session = state.requireData;
      _latestBaseline ??= session;
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
      return DesktopWorkspacePreview(
        key: ValueKey('studio-dock-session-${session.sessionId}'),
        initialCues: cues,
        liveReadOnly: true,
        projectTitle: session.fileName,
        encoding: session.encoding,
        onChooseProject: widget.onChooseProject,
        onApplyCueText: widget.enableTextEditing ? _applyText : null,
      );
    },
  );
}
