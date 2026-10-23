import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/screens/edit/providers/subtitle_repository_provider.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';

import 'desktop_workspace_preview.dart';
import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// DS3 R1 opt-in production-data view. It intentionally never opens a
/// media player or exposes editing actions until the write/undo transaction
/// boundary has been separately accepted.
class StudioDockReadOnlySessionView extends ConsumerStatefulWidget {
  const StudioDockReadOnlySessionView({
    super.key,
    required this.sessionId,
    required this.collectionId,
    this.onChooseProject,
  });

  final int sessionId;
  final int collectionId;
  final VoidCallback? onChooseProject;

  @override
  ConsumerState<StudioDockReadOnlySessionView> createState() =>
      _StudioDockReadOnlySessionViewState();
}

class _StudioDockReadOnlySessionViewState
    extends ConsumerState<StudioDockReadOnlySessionView> {
  late Future<StudioDockSessionSnapshot> _snapshot;

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
      );
    },
  );
}
