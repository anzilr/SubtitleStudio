import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/repositories/session_repository.dart';
import 'package:subtitle_studio/screens/screen_home.dart';

import 'studio_dock_read_only_session_view.dart';

/// The default Windows/Linux/macOS entry screen. Unlike the original Home
/// route, this opens the *real* Studio Dock for the most recently used session.
///
/// Uses real checkpoint-backed text edits and the existing native video player.
/// Import/create still uses the existing Home flow until DS5.
class StudioDockDesktopHome extends ConsumerStatefulWidget {
  const StudioDockDesktopHome({
    super.key,
    this.loadSessions,
    this.sessionViewBuilder,
  });

  /// Injectable boundaries for desktop-route tests. Production uses the
  /// existing Isar-backed SessionRepository and real Studio Dock view.
  final Future<StudioDockSessionCatalog> Function()? loadSessions;
  final Widget Function(Session, VoidCallback)? sessionViewBuilder;

  @override
  ConsumerState<StudioDockDesktopHome> createState() =>
      _StudioDockDesktopHomeState();
}

class _StudioDockDesktopHomeState extends ConsumerState<StudioDockDesktopHome> {
  late Future<StudioDockSessionCatalog> _sessionsFuture;
  int? _chosenSessionId;
  bool _classicFlowActive = false;
  int _reloadRevision = 0;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
  }

  Future<StudioDockSessionCatalog> _loadSessions() async {
    if (widget.loadSessions != null) return widget.loadSessions!();
    final repository = SessionRepository(ref.read(isarProvider));
    final sessions = await repository.fetchAllSessions();
    final lastId = await repository.getLastEditedSessionId();
    return StudioDockSessionCatalog(sessions, lastId);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _reloadRevision++;
      _sessionsFuture = _loadSessions();
    });
  }

  Future<void> _openClassicHome() async {
    // The live read-only pane remains mounted behind the legacy route.
    // This is the standalone desktop host: no parent Editor callbacks are
    // suppressed. The legacy route may use the existing hotkeys normally.
    // Unmount the Studio Dock player *before* classic Home can push an Editor
    // route. Exactly one native player is allowed to own the session.
    setState(() => _classicFlowActive = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(),
      ));
    } finally {
      if (mounted) {
        setState(() => _classicFlowActive = false);
        _refresh();
      }
    }
  }

  Future<void> _chooseProject(StudioDockSessionCatalog snapshot) async {
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
              'Text editing is enabled. Video playback is available when a saved media file exists.',
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
                    subtitle: Text('Session ${session.id} · text editing'),
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
      await _openClassicHome();
      return;
    }
    if (snapshot.sessions.any((session) => session.id == selectedId)) {
      setState(() => _chosenSessionId = selectedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudioDockSessionCatalog>(
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

        final choose = () => _chooseProject(snapshot);
        if (widget.sessionViewBuilder != null) {
          return widget.sessionViewBuilder!(active, choose);
        }
        return StudioDockReadOnlySessionView(
          key: ValueKey('studio-dock-active-session-$activeId-$_reloadRevision'),
          sessionId: active.id,
          collectionId: active.subtitleCollectionId,
          onChooseProject: choose,
          enableTextEditing: true,
          allowNativePlayback: !_classicFlowActive,
          suppressParentEditorHotkeys: false,
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

class StudioDockSessionCatalog {
  const StudioDockSessionCatalog(this.sessions, this.lastId);
  final List<Session> sessions;
  final int? lastId;
}
