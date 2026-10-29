import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/repositories/session_repository.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/widgets/subtitle_extract_options_sheet.dart';
import 'package:subtitle_studio/widgets/session_selection/project_history_import_plan.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';

import 'studio_dock_project_actions.dart';
import 'studio_dock_project_import_dialog.dart';
import 'studio_dock_srt_import_dialog.dart';

import 'studio_dock_session_view.dart';
import 'studio_dock_workspace.dart';

/// Exclusive native desktop shell for Windows, Linux and macOS.
/// Projects, imports, text editing and media remain in Studio Dock; the
/// classic mobile Home and Editor are not navigable from this host.
class StudioDockDesktopHome extends ConsumerStatefulWidget {
  const StudioDockDesktopHome({
    super.key,
    this.loadSessions,
    this.sessionViewBuilder,
    this.initialFilePath,
    this.pickFile,
    this.extractionSheetBuilder,
  });

  /// Injectable boundaries for desktop-route tests. Production uses the
  /// existing Isar-backed SessionRepository and real Studio Dock view.
  final Future<StudioDockSessionCatalog> Function()? loadSessions;
  final Widget Function(Session, VoidCallback)? sessionViewBuilder;
  /// File-association source; accepted formats are checked by the importer.
  final String? initialFilePath;
  /// Testable desktop system picker; production uses the existing file picker.
  final Future<String?> Function(BuildContext)? pickFile;
  /// Injectable only for desktop navigation tests. Production reuses the
  /// mobile extraction sheet and its FFmpeg/SRT processing workflow.
  final Widget Function(ValueChanged<Session> onExtracted)?
      extractionSheetBuilder;

  @override
  ConsumerState<StudioDockDesktopHome> createState() =>
      _StudioDockDesktopHomeState();
}

class _StudioDockDesktopHomeState extends ConsumerState<StudioDockDesktopHome> {
  late Future<StudioDockSessionCatalog> _sessionsFuture;
  int? _chosenSessionId;
  bool _busy = false;
  String? _error;
  int _reloadRevision = 0;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _importFile(widget.initialFilePath);
      });
    }
  }

  Future<StudioDockSessionCatalog> _loadSessions() async {
    if (widget.loadSessions != null) return widget.loadSessions!();
    final repository = SessionRepository(ref.read(isarProvider));
    final sessions = await repository.fetchAllSessions();
    final lastId = await repository.getLastEditedSessionId();
    return StudioDockSessionCatalog(sessions, lastId);
  }

  Future<void> _rememberProject(int sessionId) async {
    // Injectable catalogs represent independent test data without an Isar
    // connection. Production remembers the selection across app launches.
    if (widget.loadSessions != null) return;
    try {
      await SessionRepository(ref.read(isarProvider))
          .setLastEditedSession(sessionId);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Project opened, but it could not be saved as the startup project.');
      }
    }
  }

  Future<void> _selectProject(int id, StudioDockSessionCatalog snapshot) async {
    if (_busy || !snapshot.sessions.any((session) => session.id == id)) return;
    setState(() => _chosenSessionId = id);
    await _rememberProject(id);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _reloadRevision++;
      _sessionsFuture = _loadSessions();
    });
  }

  StudioDockProjectActions get _actions => StudioDockProjectActions(
    subtitleImporter: ref.read(subtitleImportRepositoryProvider),
    projectImporter: SessionProjectImportRepository(ref.read(isarProvider)),
  );

  void _activateExtractedSession(Session session) {
    if (!mounted) return;
    _chosenSessionId = session.id;
    _refresh();
    unawaited(_rememberProject(session.id));
  }

  Future<void> _extractSubtitlesFromVideo() async {
    if (_busy || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => widget.extractionSheetBuilder?.call(
        _activateExtractedSession,
      ) ?? SubtitleExtractOptionsSheet(
        onSubtitleExtracted: _activateExtractedSession,
      ),
    );
  }

  Future<void> _importFile([String? initialPath]) async {
    if (_busy) return;
    final path = initialPath ?? await (widget.pickFile?.call(context) ??
        FilePickerSAF.pickFile(
          context: context,
          title: 'Open SRT or SubtitleStudio project',
          allowedExtensions: const ['srt', 'msone'],
        ));
    if (path == null || !mounted) return; // Cancellation makes no project.
    StudioDockSrtImportChoice? srtChoice;
    StudioDockProjectImportPlan? projectPlan;
    ProjectDocument? projectDocument;
    if (StudioDockProjectActions.extensionOf(path) == '.srt') {
      srtChoice = await showDialog<StudioDockSrtImportChoice>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StudioDockSrtImportDialog(filePath: path),
      );
      if (!mounted || srtChoice == null) return;
    } else if (StudioDockProjectActions.extensionOf(path) == '.msone') {
      try {
        projectDocument = await _actions.readProjectDocument(path);
        final targets = await _actions.importTargets();
        final archiveAvailable = await StudioDockProjectActions.isUsableSrtPath(
          StudioDockProjectActions.archivedSrtPath(projectDocument),
        );
        final existingAvailability = <int, bool>{};
        for (final target in targets) {
          existingAvailability[target.session.id] =
              await StudioDockProjectActions.isUsableSrtPath(target.srtPath);
        }
        if (!mounted) return;
        projectPlan = await showDialog<StudioDockProjectImportPlan>(
          context: context,
          barrierDismissible: false,
          builder: (_) => StudioDockProjectImportDialog(
            document: projectDocument!,
            targets: targets,
            archiveSrtAvailable: archiveAvailable,
            existingSrtAvailability: existingAvailability,
          ),
        );
        if (!mounted || projectPlan == null) return;
        if (projectPlan.replaceSessionId != null) {
          final target = targets.firstWhere(
            (entry) => entry.session.id == projectPlan!.replaceSessionId,
          );
          final approved = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Replace project?'),
              content: Text('Replace "${target.session.fileName}" with '
                  'the imported subtitles and history? This replaces the '
                  'current project data and its saved edit history. '
                  'The source SRT file itself will not be overwritten.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('studio-dock-msone-replace-approve'),
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Replace project'),
                ),
              ],
            ),
          );
          if (!mounted || approved != true) return;
        }
      } catch (e) {
        if (mounted) setState(() => _error = 'Unable to read project: $e');
        return;
      }
    }
    setState(() { _busy = true; _error = null; });
    try {
      late Session imported;
      if (projectPlan != null && projectDocument != null) {
        try {
          imported = await _actions.importProject(
            archivePath: path,
            document: projectDocument,
            plan: projectPlan,
          );
        } on ProjectHistoryImportException catch (error) {
          if (!mounted) return;
          final proceed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialog) => AlertDialog(
              title: const Text('Project history cannot be restored'),
              content: Text('${error.message}\n\n'
                  'No project has been changed. Importing subtitles only '
                  'discards the archive’s history. If replacing an existing '
                  'project, its current history will also be replaced.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('studio-dock-msone-subtitles-only'),
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Import subtitles only'),
                ),
              ],
            ),
          );
          if (!mounted || proceed != true) return;
          imported = await _actions.importProject(
            archivePath: path,
            document: projectDocument,
            plan: projectPlan,
            importSubtitlesOnly: true,
          );
        }
      } else {
        imported = await _actions.importFile(path,
            selectedEncoding: srtChoice?.encoding,
            removeHearingImpaired: srtChoice?.removeHearingImpaired ?? false,
            mergeOverlapping: srtChoice?.mergeOverlapping ?? false);
      }
      if (!mounted) return;
      _chosenSessionId = imported.id;
      _refresh();
      await _rememberProject(imported.id);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Unable to open project: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createProject() async {
    if (_busy) return;
    // A local string avoids disposing a TextEditingController while Flutter
    // is still animating the modal route out of the tree.
    var projectName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('New Studio Dock project'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Create subtitles from scratch in Edit Mode.'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('studio-dock-new-project-name'),
              onChanged: (value) => projectName = value,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Project name',
                hintText: 'Untitled subtitles',
              ),
              onSubmitted: (value) => Navigator.pop(dialog, value),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, projectName),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final created = await _actions.createEmpty(name);
      if (!mounted) return;
      _chosenSessionId = created.id;
      _refresh();
      await _rememberProject(created.id);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create project: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
              'Open a project in the Studio Dock workspace.',
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
                    subtitle: Text('Session ${session.id} · '
                        '${session.editMode ? 'Edit Mode' : 'Translation Mode'}'),
                    selected: session.id == _chosenSessionId,
                    onTap: () => Navigator.pop(dialogContext, session.id),
                  );
                },
              ),
            ),
          ]),
        ),
        actions: [
          TextButton.icon(
            key: const ValueKey('studio-dock-import-project'),
            icon: const Icon(Icons.file_open),
            onPressed: () => Navigator.pop(dialogContext, -2),
            label: const Text('Import file'),
          ),
          TextButton.icon(
            key: const ValueKey('studio-dock-extract-project'),
            icon: const Icon(Icons.subtitles_outlined),
            onPressed: () => Navigator.pop(dialogContext, -4),
            label: const Text('Extract from video'),
          ),
          TextButton.icon(
            key: const ValueKey('studio-dock-create-project'),
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.pop(dialogContext, -3),
            label: const Text('New project'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || selectedId == null) return;
    if (selectedId == -2) {
      await _importFile();
      return;
    }
    if (selectedId == -3) {
      await _createProject();
      return;
    }
    if (selectedId == -4) {
      await _extractSubtitlesFromVideo();
      return;
    }
    if (snapshot.sessions.any((session) => session.id == selectedId)) {
      await _selectProject(selectedId, snapshot);
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
            'Import SRT or .msone files, or create a new project.',
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
        return Stack(children: [
          StudioDockSessionView(
          key: ValueKey('studio-dock-active-session-$activeId-$_reloadRevision'),
          sessionId: active.id,
          collectionId: active.subtitleCollectionId,
          onChooseProject: choose,
          activeProjectId: activeId,
          projects: [
            for (final project in snapshot.sessions)
              StudioDockProjectEntry(
                id: project.id,
                title: project.fileName,
                isEditMode: project.editMode,
              ),
          ],
          onSelectProject: (id) => unawaited(_selectProject(id, snapshot)),
          onImportFile: () => _importFile(),
          onExtractSubtitles: () => unawaited(_extractSubtitlesFromVideo()),
          onNewProject: _createProject,
          enableEditing: true,
          allowNativePlayback: true,
          suppressParentEditorHotkeys: false,
        ),
          if (_busy)
            const Positioned.fill(child: ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            )),
          if (_error != null)
            Positioned(left: 24, right: 24, bottom: 32, child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Text(_error!)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _error = null),
                  ),
                ]),
              ),
            )),
        ]);
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
              onPressed: _busy ? null : _importFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Import subtitles or project'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('studio-dock-create-first'),
              onPressed: _busy ? null : _createProject,
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('studio-dock-extract-first'),
              onPressed: _busy ? null : _extractSubtitlesFromVideo,
              icon: const Icon(Icons.subtitles_outlined),
              label: const Text('Extract subtitles from video'),
            ),
            if (_busy) const CircularProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, textAlign: TextAlign.center)),
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
