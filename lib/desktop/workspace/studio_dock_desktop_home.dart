import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/repositories/session_repository.dart';
import 'package:subtitle_studio/screens/screen_home.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';

import 'studio_dock_read_only_session_view.dart';

/// The default Windows/Linux/macOS entry screen. Unlike the original Home
/// route, this opens the *real* Studio Dock for the most recently used session.
///
/// This is a desktop read-only integration checkpoint. Import/create still
/// uses the existing home flow until project creation is implemented here.
class StudioDockDesktopHome extends ConsumerStatefulWidget {
  const StudioDockDesktopHome({super.key});

  @override
  ConsumerState<StudioDockDesktopHome> createState() =>
      _StudioDockDesktopHomeState();
}

class _StudioDockDesktopHomeState extends ConsumerState<StudioDockDesktopHome> {
  late Future<_DesktopSessions> _sessionsFuture;
  int? _chosenSessionId;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
  }

  Future<_DesktopSessions> _loadSessions() async {
    final repository = SessionRepository(ref.read(isarProvider));
    final sessions = await repository.fetchAllSessions();
    final lastId = await repository.getLastEditedSessionId();
    return _DesktopSessions(sessions, lastId);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _sessionsFuture = _loadSessions());
  }

  Future<void> _openClassicHome({bool fromReadOnly = false}) async {
    // The live read-only pane remains mounted behind the legacy route.
    // Release its suppression while the legacy Home is the active route;
    // otherwise Home's shared MSoneHotkeyManager actions would be blocked.
    final manager = MSoneHotkeyManager.instance;
    if (fromReadOnly) manager.resumeCallbacks();
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(),
      ));
    } finally {
      if (mounted && fromReadOnly) manager.suspendCallbacks();
    }
    _refresh();
  }

  Future<void> _chooseProject(_DesktopSessions snapshot) async {
    final selectedId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Studio Dock — Projects'),
        content: SizedBox(
          width: 490,
          height: 390,
          child: Column(children: [
            const Text(
              'Choose a subtitle session to view in Studio Dock. '
              'Editing and playback are not connected yet.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: snapshot.sessions.length,
                itemBuilder: (_, index) {
                  final session = snapshot.sessions[index];
                  return ListTile(
                    key: ValueKey('studio-dock-project-${session.id}'),
                    leading: const Icon(Icons.subtitles_outlined),
                    title: Text(session.fileName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Session ${session.id} · read only'),
                    selected: session.id == _chosenSessionId,
                    onTap: () => Navigator.pop(dialogContext, session.id),
                  );
                },
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            key: const ValueKey('studio-dock-classic-home'),
            onPressed: () => Navigator.pop(dialogContext, -1),
            child: const Text('Import / Create (classic)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || selectedId == null) return;
    if (selectedId == -1) {
      await _openClassicHome(fromReadOnly: true);
      return;
    }
    if (snapshot.sessions.any((session) => session.id == selectedId)) {
      setState(() => _chosenSessionId = selectedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DesktopSessions>(
      future: _sessionsFuture,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.hasError) {
          return _landing(
            'Could not load projects',
            'Check the local database and retry.',
          );
        }

        final snapshot = state.requireData;
        if (snapshot.sessions.isEmpty) {
          return _landing(
            'Welcome to Studio Dock',
            'No subtitle sessions are available yet. '
            'Use the existing import workflow to add your first project.',
          );
        }

        final ids = snapshot.sessions.map((s) => s.id).toSet();
        final activeId = ids.contains(_chosenSessionId)
            ? _chosenSessionId!
            : ids.contains(snapshot.lastId)
                ? snapshot.lastId!
                : snapshot.sessions.first.id;
        final active = snapshot.sessions.firstWhere((s) => s.id == activeId);

        return StudioDockReadOnlySessionView(
          key: ValueKey('studio-dock-active-session-$activeId'),
          sessionId: active.id,
          collectionId: active.subtitleCollectionId,
          onChooseProject: () => _chooseProject(snapshot),
          enableTextEditing: true,
        );
      },
    );
  }

  Widget _landing(String title, String description) => Scaffold(
    appBar: AppBar(title: const Text('SubtitleStudio · Studio Dock')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.dashboard_customize_outlined,
              size: 62, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('studio-dock-import-first'),
              onPressed: _openClassicHome,
              icon: const Icon(Icons.folder_open),
              label: const Text('Import / Create a project'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _refresh,
              child: const Text('Refresh projects'),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _DesktopSessions {
  const _DesktopSessions(this.sessions, this.lastId);
  final List<Session> sessions;
  final int? lastId;
}
