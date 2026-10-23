import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'studio_dock_geometry.dart';
import 'studio_dock_layout_preferences.dart';
import '../../utils/msone_hotkey_manager.dart';

/// Demo-only cue; this screen intentionally does not persist any user data.
@immutable
class WorkspaceDemoCue {
  const WorkspaceDemoCue({
    required this.id,
    required this.start,
    required this.end,
    required this.original,
    required this.edited,
    this.marked = false,
  });

  final int id;
  final String start;
  final String end;
  final String original;
  final String edited;
  final bool marked;

  WorkspaceDemoCue copyWith({String? edited, bool? marked}) =>
      WorkspaceDemoCue(
        id: id, start: start, end: end, original: original,
        edited: edited ?? this.edited, marked: marked ?? this.marked,
      );
}

/// Desktop-first, data-isolated workspace design. Domain logic is intentionally
/// absent: shared Editor, Isar, checkpoints, media and file-access providers
/// remain authoritative in the refactoring branch.
class DesktopWorkspacePreview extends StatefulWidget {
  const DesktopWorkspacePreview({
    super.key,
    this.initialCues,
    this.liveReadOnly = false,
    this.projectTitle,
    this.encoding,
    this.onChooseProject,
    this.onImportFile,
    this.onNewProject,
    this.onApplyCueText,
    this.videoSurface,
    this.manageLiveHotkeys = false,
  });

  /// Supplied only by the DS3 real-session loader. Demo mode still owns its
  /// original sample cues and never touches a database.
  final List<WorkspaceDemoCue>? initialCues;
  final bool liveReadOnly;
  final String? projectTitle;
  final String? encoding;
  final VoidCallback? onChooseProject;
  final VoidCallback? onImportFile;
  final VoidCallback? onNewProject;
  /// Non-null only when the production checkpoint-backed edit bridge is ready.
  final Future<bool> Function(int cueNumber, String editedText)? onApplyCueText;
  /// Optional existing native-player surface. Only the standalone desktop
  /// host may provide it; the classic Editor preview must leave it null.
  final Widget? videoSurface;
  /// Standalone desktop is allowed to own shared application callbacks;
  /// an overlay on the classic Editor must not override its registrations.
  final bool manageLiveHotkeys;

  @override
  State<DesktopWorkspacePreview> createState() =>
      _DesktopWorkspacePreviewState();
}

class _DesktopWorkspacePreviewState extends State<DesktopWorkspacePreview> {
  static const _accent = Color(0xFF2A9D8F);
  static const _border = Color(0xFF30363D);
  static const _muted = Color(0xFF98A2AD);

  static const List<WorkspaceDemoCue> _demoCues = [
    const WorkspaceDemoCue(id: 1, start: '00:00:08,200', end: '00:00:11,400',
      original: 'The city always looks different at night.',
      edited: 'The city always looks different at night.'),
    const WorkspaceDemoCue(id: 2, start: '00:00:12,100', end: '00:00:15,800',
      original: 'Especially when there is nowhere to go.',
      edited: 'Especially when there is nowhere to go.'),
    const WorkspaceDemoCue(id: 3, start: '00:00:17,300', end: '00:00:20,500',
      original: 'I thought we had more time.',
      edited: 'I thought we had more time.'),
    const WorkspaceDemoCue(id: 4, start: '00:00:21,800', end: '00:00:24,700',
      original: 'The last train left an hour ago.',
      edited: 'The last train left an hour ago.'),
    const WorkspaceDemoCue(id: 5, start: '00:00:26,100', end: '00:00:29,300',
      original: 'Meet me where the lights end.',
      edited: 'Meet me where the lights end.', marked: true),
    const WorkspaceDemoCue(id: 6, start: '00:00:30,000', end: '00:00:33,900',
      original: 'Every road leads somewhere.',
      edited: 'Every road leads somewhere.'),
    const WorkspaceDemoCue(id: 7, start: '00:00:35,500', end: '00:00:38,600',
      original: 'Not every story has an ending.',
      edited: 'Not every story has an ending.'),
    const WorkspaceDemoCue(id: 8, start: '00:00:40,200', end: '00:00:43,700',
      original: 'We could begin again.',
      edited: 'We could begin again.'),
    const WorkspaceDemoCue(id: 9, start: '00:00:44,900', end: '00:00:48,000',
      original: 'Are you coming with me?',
      edited: 'Are you coming with me?'),
    const WorkspaceDemoCue(id: 10, start: '00:00:50,500', end: '00:00:53,600',
      original: 'Only if we take the long way.',
      edited: 'Only if we take the long way.'),
    const WorkspaceDemoCue(id: 11, start: '00:00:56,900', end: '00:01:00,000',
      original: 'It is almost midnight.',
      edited: 'It is almost midnight.'),
    const WorkspaceDemoCue(id: 12, start: '00:01:01,200', end: '00:01:04,700',
      original: 'Then let us not waste another minute.',
      edited: 'Then let us not waste another minute.'),
  ];
  late final List<WorkspaceDemoCue> _cues;
  int _selectedId = 5;
  int _selectionAnchor = 5;
  final Set<int> _selectedIds = {5};
  final StudioDockLayoutPreferences _layoutPreferences = StudioDockLayoutPreferences();
  Timer? _layoutSaveTimer;
  bool _layoutChangedSinceMount = false;
  final FocusNode _gridFocus = FocusNode(debugLabel: 'Studio Dock grid');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'Studio Dock search');
  final TextEditingController _commandSearch = TextEditingController();
  int _section = 0;
  bool _playing = false;
  bool _inspectorOpen = true;
  bool _explorerOpen = true;
  bool _explorerOverlayOpen = false;
  bool _inspectorOverlayOpen = false;
  int _inspectorTab = 0;
  double _videoShare = .43;
  double _waveformShare = .13;
  String _query = '';
  int? _draftCueId;
  String? _draftText;
  int _draftRevision = 0;
  bool _savingDraft = false;
  double _sidebarWidth = 240;
  double _inspectorWidth = 320;

  WorkspaceDemoCue get _selected =>
      _cues.firstWhere((cue) => cue.id == _selectedId);
  List<WorkspaceDemoCue> get _visible => _cues.where((cue) {
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
    HotkeyAction.markLine,
  ];

  @override
  void initState() {
    super.initState();
    _cues = List<WorkspaceDemoCue>.from(
        widget.initialCues ?? _demoCues);
    if (widget.initialCues != null) {
      _selectedId = _cues.isEmpty ? -1 : _cues.first.id;
      _selectionAnchor = _selectedId;
      _selectedIds
        ..clear()
        ..addAll(_selectedId > 0 ? [_selectedId] : <int>[]);
    }
    // Desktop entrypoint initializes the application's existing hotkey manager.
    // Direct widget previews do not initialize native plugins.
    // The live read-only viewer may be nested in an already-running Editor.
    // Never override its registered MSoneHotkeyManager callbacks.
    if (!widget.liveReadOnly || widget.manageLiveHotkeys) {
      unawaited(_installManagedHotkeys());
    }
    unawaited(_restoreLayout());
  }

  Future<void> _installManagedHotkeys() async {
    final manager = MSoneHotkeyManager.instance;
    for (final action in _managedActions) {
      if (widget.liveReadOnly &&
          action != HotkeyAction.nextLine &&
          action != HotkeyAction.previousLine &&
          action != HotkeyAction.findReplace) continue;
      if (!mounted) return;
      await manager.registerCallback(action, () {
        if (mounted && !_isEditingText) _dispatchManagedAction(action);
      });
    }
  }

  @override
  void dispose() {
    _layoutSaveTimer?.cancel();
    if (_layoutChangedSinceMount) unawaited(_persistLayout());
    if (!widget.liveReadOnly || widget.manageLiveHotkeys) {
      for (final action in _managedActions) {
        if (widget.liveReadOnly &&
            action != HotkeyAction.nextLine &&
            action != HotkeyAction.previousLine &&
            action != HotkeyAction.findReplace) continue;
        unawaited(MSoneHotkeyManager.instance.unregisterCallback(action));
      }
    }
    _commandSearch.dispose();
    _gridFocus.dispose();
    _searchFocus.dispose();
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
      _videoShare = .43;
      _waveformShare = .13;
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
        if (!widget.liveReadOnly) {
          setState(() => _playing = !_playing);
        }
      case HotkeyAction.findReplace:
        _searchFocus.requestFocus();
      case HotkeyAction.markLine:
        _toggleMarkedSelection();
      default:
        break;
    }
  }

  void _toggleMarkedSelection() {
    if (widget.liveReadOnly || _selectedIds.isEmpty) return;
    setState(() {
      for (var i = 0; i < _cues.length; i++) {
        final cue = _cues[i];
        if (_selectedIds.contains(cue.id)) {
          _cues[i] = cue.copyWith(marked: !cue.marked);
        }
      }
    });
  }

  bool get _hasDirtyDraft => widget.onApplyCueText != null &&
      _draftCueId == _selectedId &&
      _draftText != null && _draftText != _selected.edited;

  void _discardDraft() {
    setState(() {
      _draftCueId = null;
      _draftText = null;
      _draftRevision++;
    });
  }

  Future<bool> _applyDraft() async {
    final callback = widget.onApplyCueText;
    if (callback == null || _savingDraft) return false;
    if (!_hasDirtyDraft) return true;
    final cueId = _selectedId;
    final text = _draftText!;
    setState(() => _savingDraft = true);
    bool applied;
    try {
      applied = await callback(cueId, text);
    } catch (_) {
      applied = false;
    }
    if (!mounted) return false;
    setState(() {
      _savingDraft = false;
      if (applied) {
        final i = _cues.indexWhere((cue) => cue.id == cueId);
        if (i >= 0) _cues[i] = _cues[i].copyWith(edited: text);
        _draftCueId = null;
        _draftText = null;
        _draftRevision++;
      }
    });
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not apply this edit. The subtitle may have '
            'changed elsewhere. Your draft is preserved.'),
      ));
    }
    return applied;
  }

  Future<bool> _confirmDraftBeforeLeaving() async {
    if (_savingDraft) return false;
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

  Future<void> _chooseProjectSafely() async {
    if (await _confirmDraftBeforeLeaving() && mounted) {
      widget.onChooseProject?.call();
    }
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
    final keyboard = HardwareKeyboard.instance;
    _selectCue(id,
        range: keyboard.isShiftPressed,
        toggle: keyboard.isControlPressed || keyboard.isMetaPressed);
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

  void _replaceCue(WorkspaceDemoCue updated) {
    if (widget.liveReadOnly) return;
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
    if (widget.initialCues != null && _cues.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(widget.projectTitle ?? 'Studio Dock'),
          actions: [
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
            const Icon(Icons.subtitles_outlined, size: 58, color: _muted),
            const SizedBox(height: 12),
            const Text('This project has no subtitle cues yet.'),
            const SizedBox(height: 8),
            const Text('Add-cue editing is planned for a future checkpoint.',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
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
      canPop: !_hasDirtyDraft && !_savingDraft,
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
        // Only palette chord is new: the other shortcuts belong to
        // MSoneHotkeyManager and must not be duplicated here.
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showCommandPalette,
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
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final label in const [
          'File', 'Edit', 'Subtitle', 'Timing', 'Tools', 'View', 'Help'
        ])
          Padding(
            padding: const EdgeInsets.only(right: 23),
            child: Text(label, style: const TextStyle(
              fontSize: 11, color: _muted)),
          ),
      ]),
    ),
  );


  Widget _topBar() => Container(
    height: 55,
    padding: const EdgeInsets.symmetric(horizontal: 17),
    decoration: const BoxDecoration(border:
        Border(bottom: BorderSide(color: _border))),
    child: Row(children: [
      const Icon(Icons.subtitles_rounded, color: _accent, size: 22),
      const SizedBox(width: 10),
      const Text('SubtitleStudio', style:
          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(width: 16),
      Container(width: 1, height: 23, color: _border),
      const SizedBox(width: 15),
      Flexible(child: Text(
        widget.projectTitle ?? 'Night Drive  /  Main subtitles',
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 12),
      )),
      const Spacer(),
      Text(widget.onApplyCueText != null ? 'LIVE · TEXT EDIT' : (widget.liveReadOnly ? 'LIVE · READ ONLY' : 'DEMO WORKSPACE'),
        style: const TextStyle(
          color: _muted, letterSpacing: 1, fontSize: 10)),
      if (widget.onImportFile != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-import'),
          icon: const Icon(Icons.file_open_outlined),
          tooltip: 'Import subtitles or project',
          onPressed: widget.onImportFile,
        ),
      if (widget.onNewProject != null)
        IconButton(
          key: const ValueKey('studio-dock-toolbar-new'),
          icon: const Icon(Icons.add_box_outlined),
          tooltip: 'New project',
          onPressed: widget.onNewProject,
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
        onPressed: () {
          if (MediaQuery.sizeOf(context).width < 1600) {
            setState(() {
              _explorerOverlayOpen = !_explorerOverlayOpen;
              _inspectorOverlayOpen = false;
            });
          } else {
            setState(() => _explorerOpen = !_explorerOpen);
            _queueLayoutSave(now: true);
          }
        },
      ),
      IconButton(
        key: const ValueKey('toggle-inspector'),
        icon: Icon(_inspectorOpen
            ? Icons.view_sidebar_outlined : Icons.view_sidebar),
        tooltip: 'Toggle inspector',
        onPressed: () {
          if (MediaQuery.sizeOf(context).width < 1250) {
            setState(() {
              _inspectorOverlayOpen = !_inspectorOverlayOpen;
              _explorerOverlayOpen = false;
            });
          } else {
            setState(() => _inspectorOpen = !_inspectorOpen);
            _queueLayoutSave(now: true);
          }
        },
      ),
      const SizedBox(width: 7),
      const Icon(Icons.circle, size: 9, color: _accent),
      const SizedBox(width: 7),
      Text(widget.onApplyCueText != null ? 'Text editing' : (widget.liveReadOnly ? 'Read-only' : 'Preview'),
          style: const TextStyle(fontSize: 12)),
    ]),
  );

  Widget _navigationRail() => Container(
    width: 61,
    decoration: const BoxDecoration(border:
      Border(right: BorderSide(color: _border))),
    child: Column(children: [
      const SizedBox(height: 13),
      _railItem(0, Icons.movie_creation_outlined, 'Editor'),
      _railItem(1, Icons.account_tree_outlined, 'History'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: _section == index ? _accent.withValues(alpha: .18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          key: ValueKey('rail-$index'),
          borderRadius: BorderRadius.circular(9),
          onTap: () => setState(() {
            _section = index;
            _explorerOverlayOpen = false;
            _inspectorOverlayOpen = false;
          }),
          child: SizedBox(width: 44, height: 43,
            child: Icon(icon, size: 21,
              color: _section == index ? _accent : _muted)),
        ),
      ),
    ),
  );

  Widget _projectSidebar() => widget.liveReadOnly
      ? _readOnlyProjectSidebar()
      : Container(
    decoration: const BoxDecoration(border:
        Border(right: BorderSide(color: _border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paneHeader(Icons.folder_open_rounded, 'PROJECT', trailing: 'DEMO'),
        const SizedBox(height: 10),
        _sidebarRow(Icons.folder_rounded, 'Night Drive', selected: true),
        const Padding(padding: EdgeInsets.fromLTRB(17, 20, 12, 7),
          child: Text('PROJECT FILES', style:
            TextStyle(fontSize: 10, color: _muted, letterSpacing: 1.2))),
        _sidebarRow(Icons.subtitles_rounded, 'Main subtitles.srt',
            selected: true, indent: 15),
        _sidebarRow(Icons.subtitles_outlined, 'Secondary subtitles',
            indent: 15),
        _sidebarRow(Icons.movie_outlined, 'Night Drive.mp4', indent: 15),
        const Padding(padding: EdgeInsets.fromLTRB(17, 23, 12, 7),
          child: Text('VERSIONS', style:
            TextStyle(fontSize: 10, color: _muted, letterSpacing: 1.2))),
        _sidebarRow(Icons.fork_right_rounded, 'Current version'),
        _sidebarRow(Icons.bookmark_border_rounded, 'Pinned versions'),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text('Preview project\nNo local files are opened.',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.5)),
        ),
      ],
    ),
  );

  Widget _readOnlyProjectSidebar() => Container(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: _border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _paneHeader(Icons.folder_open_rounded, 'PROJECT',
          trailing: 'READ ONLY'),
      const SizedBox(height: 10),
      _sidebarRow(Icons.subtitles_rounded,
          widget.projectTitle ?? 'Subtitle session',
          selected: true),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Showing the current subtitle snapshot. Media, attachments, '
          'versions and additional tracks are not connected in this preview.',
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: .12) : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: selected ? _accent : _muted),
          const SizedBox(width: 9),
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
          child: const SizedBox(width: 5,
              child: ColoredBox(color: _border)),
        ),
      );

  Widget _paneHeader(IconData icon, String title, {String? trailing}) =>
      Container(
        height: 43,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .7)),
          const Spacer(),
          if (trailing != null) Text(trailing,
              style: const TextStyle(color: _muted, fontSize: 10)),
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
            _waveformShare = (_waveformShare - change).clamp(.11, .26);
          }),
          onReset: () => setState(() {
            _videoShare = .43;
            _waveformShare = .13;
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
                .clamp(.11, .26)),
          onReset: () => setState(() {
            _videoShare = .43;
            _waveformShare = .13;
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
      child: const SizedBox(
        height: StudioDockBands.splitter,
        child: ColoredBox(color: _border),
      ),
    ),
  );

  Widget _videoPanel() => Container(
    padding: const EdgeInsets.all(14),
    color: const Color(0xFF131619),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.videocam_outlined, size: 16, color: _muted),
        const SizedBox(width: 9),
        const Text('VIDEO PREVIEW',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        const Spacer(),
        const Icon(Icons.aspect_ratio, size: 15, color: _muted),
        const SizedBox(width: 8),
        Text(widget.liveReadOnly ? 'Media not connected' : '16:9 · Demo clip',
            style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 10),
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
                child: Text(widget.liveReadOnly
                    ? 'REAL CUES · VIDEO NOT CONNECTED'
                    : 'DEMO VIDEO · PLACEHOLDER',
                  style: const TextStyle(fontSize: 10,
                    color: Color(0xFFACB6BD), letterSpacing: 1))),
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(widget.liveReadOnly
                    ? (_selected.edited.isEmpty
                        ? _selected.original : _selected.edited)
                    : _selected.edited,
                  maxLines: 2, textAlign: TextAlign.center,
                  style: const TextStyle(
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
    decoration: const BoxDecoration(border: Border(
      top: BorderSide(color: _border),
      bottom: BorderSide(color: _border),
    )),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 19),
        tooltip: 'Previous cue',
        onPressed: () => _selectRelative(-1)),
      IconButton(
        key: const ValueKey('preview-play'),
        icon: Icon(_playing ? Icons.pause_circle_filled_rounded
            : Icons.play_circle_fill_rounded, color: _accent, size: 25),
        tooltip: widget.liveReadOnly
            ? 'Media playback is not connected in this preview'
            : 'Toggle simulated playback',
        onPressed: widget.liveReadOnly ? null
            : () => _dispatchManagedAction(HotkeyAction.playPause)),
      IconButton(icon: const Icon(Icons.skip_next_rounded, size: 19),
        tooltip: 'Next cue', onPressed: () => _selectRelative(1)),
      const SizedBox(width: 14),
      Text(_selected.start, style: const TextStyle(
          fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
      Text(widget.liveReadOnly ? ' / no media' : ' / 00:12:45',
        style: const TextStyle(color: _muted, fontSize: 12)),
      const Spacer(),
      const Text('1.0×', style: TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(width: 12),
      const Icon(Icons.volume_up_outlined, size: 17, color: _muted),
    ]),
  );

  Widget _waveformPanel() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    color: const Color(0xFF171B20),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.graphic_eq, size: 15, color: _accent),
        const SizedBox(width: 8),
        const Text('WAVEFORM', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8)),
        const SizedBox(width: 10),
        Text(widget.liveReadOnly ? 'Audio not connected' : 'Audio track: Auto',
            style: const TextStyle(fontSize: 10, color: _muted)),
        const Spacer(),
        const Text('–  00:30  +', style:
            TextStyle(color: _muted, fontSize: 10)),
      ]),
      const SizedBox(height: 7),
      Expanded(child: widget.liveReadOnly
          ? const Center(child: Text('Waveform integration pending',
              style: TextStyle(color: _muted, fontSize: 11)))
          : SizedBox.expand(
              child: CustomPaint(painter: _DemoWaveformPainter(
                cueIndex: _selectedId, accent: _accent)))),
    ]),
  );

  Widget _subtitleTable() => Column(children: [
    _paneHeader(Icons.view_list_outlined, 'SUBTITLE LINES',
        trailing: _visible.length.toString() + ' / ' + _cues.length.toString()),
    SizedBox(height: 43, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      child: TextField(
        key: const ValueKey('desktop-cue-search'),
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
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: _gridCells(null),
            ),
            Expanded(child: Focus(
              focusNode: _gridFocus,
              onKeyEvent: _handleGridKey,
              child: _visible.isEmpty
              ? const Center(child: Text('No matching subtitle lines',
                  style: TextStyle(color: _muted)))
              : ListView.builder(
                  itemCount: _visible.length,
                  itemExtent: 40,
                  itemBuilder: (context, i) {
                    final cue = _visible[i];
                    final selected = _selectedIds.contains(cue.id);
                    return Material(
                      color: selected ? _accent.withValues(alpha: .14)
                          : i.isOdd
                              ? const Color(0xFF1B1F23)
                              : Colors.transparent,
                      child: InkWell(
                        key: ValueKey('desktop-cue-' + cue.id.toString()),
                        onTap: () => _selectFromPointer(cue.id),
                        onSecondaryTapDown: (details) =>
                            _showCueContextMenu(cue, details.globalPosition),
                        child: Container(
                          decoration: const BoxDecoration(border: Border(
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
      WorkspaceDemoCue cue, Offset position) async {
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
        if (!widget.liveReadOnly)
          const PopupMenuItem(value: 'mark',
              child: Text('Toggle review mark')),
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
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: cue.start + ' --> ' + cue.end),
        );
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
            MapEntry('Find subtitle', () => _searchFocus.requestFocus()),
            MapEntry('Next cue', () => _selectRelative(1)),
            MapEntry('Previous cue', () => _selectRelative(-1)),
            if (!widget.liveReadOnly)
              MapEntry('Toggle playback preview',
                  () => _dispatchManagedAction(HotkeyAction.playPause)),
            if (!widget.liveReadOnly)
              MapEntry('Toggle review mark', _toggleMarkedSelection),
            MapEntry('Reset workspace layout', _resetLayout),
            MapEntry('Show Inspector: Text', () => setState(() {
              _inspectorTab = 0;
              _inspectorOpen = true;
              _inspectorOverlayOpen = true;
            })),
            MapEntry('Show Inspector: Timing', () => setState(() {
              _inspectorTab = 1;
              _inspectorOpen = true;
              _inspectorOverlayOpen = true;
            })),
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

  Widget _gridCells(WorkspaceDemoCue? cue) {
    final heading = cue == null;
    Text cell(String value, {bool primary = false}) => Text(
      value, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: heading ? 10 : 11,
        color: heading ? _muted : primary ? Colors.white : _muted),
    );
    return Row(children: [
      SizedBox(width: 32, child: cell(heading ? '#' : cue.id.toString())),
      SizedBox(width: 108, child: cell(heading ? 'START' : cue.start)),
      SizedBox(width: 108, child: cell(heading ? 'END' : cue.end)),
      SizedBox(width: 84, child: cell(heading
          ? 'DURATION' : _cueDuration(cue))),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: cell(heading ? 'ORIGINAL' : cue.original, primary: true),
      )),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: cell(heading ? 'EDITED' : cue.edited, primary: true),
      )),
      SizedBox(width: 55, child: heading
          ? cell('STATUS')
          : cue.marked
              ? const Icon(Icons.bookmark, color: Color(0xFFE9C46A),
                  size: 14)
              : const SizedBox.shrink()),
    ]);
  }

  String _cueDuration(WorkspaceDemoCue cue) {
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
    const tabs = <String>['Text', 'Timing', 'Style', 'Notes'];
    return Container(
      color: const Color(0xFF191D21),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _paneHeader(Icons.tune_outlined, 'LINE INSPECTOR',
            trailing: '#' + _selectedId.toString().padLeft(2, '0')),
        SizedBox(height: 43, child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(child: TextButton(
              key: ValueKey('inspector-tab-' + tabs[i]),
              onPressed: () => setState(() => _inspectorTab = i),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Text(widget.onApplyCueText != null
              ? 'Apply updates the local project with checkpoint history'
              : (widget.liveReadOnly
                  ? 'Read-only session · no changes are saved'
                  : 'Demo only · changes are not saved to files'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 11)),
        ),
      ]),
    );
  }

  List<Widget> _inspectorFields() {
    switch (_inspectorTab) {
      case 0:
        return [
          _fieldLabel('ORIGINAL TEXT'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(_selected.original,
              style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 17),
          _fieldLabel(widget.onApplyCueText != null
              ? 'EDITED TEXT · UNSAVED UNTIL APPLIED'
              : (widget.liveReadOnly
                  ? 'EDITED TEXT · READ ONLY'
                  : 'EDITED TEXT · DEMO ONLY')),
          TextFormField(
            key: widget.onApplyCueText == null
                ? ValueKey('desktop-edit-' + _selected.id.toString())
                : ValueKey('studio-edit-' + _selected.id.toString() +
                    '-' + _draftRevision.toString()),
            initialValue: _draftCueId == _selectedId && _draftText != null
                ? _draftText : _selected.edited,
            readOnly: _savingDraft ||
                (widget.liveReadOnly && widget.onApplyCueText == null),
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
          if (widget.onApplyCueText != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton.icon(
                key: const ValueKey('studio-apply-cue'),
                onPressed: _hasDirtyDraft && !_savingDraft
                    ? () => unawaited(_applyDraft()) : null,
                icon: const Icon(Icons.check, size: 16),
                label: Text(_savingDraft ? 'Applying…' : 'Apply'),
              )),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const ValueKey('studio-discard-cue'),
                onPressed: _hasDirtyDraft && !_savingDraft
                    ? _discardDraft : null,
                child: const Text('Discard'),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: widget.liveReadOnly ? null : () => _replaceCue(
                _selected.copyWith(edited: _selected.original)),
            icon: const Icon(Icons.restore, size: 15),
            label: const Text('Reset to original'),
          ),
        ];
      case 1:
        return [
          _fieldLabel('START TIMECODE'),
          _readonlyField(_selected.start),
          const SizedBox(height: 13),
          _fieldLabel('END TIMECODE'),
          _readonlyField(_selected.end),
          const SizedBox(height: 13),
          _fieldLabel('DURATION'),
          _readonlyField(_cueDuration(_selected)),
          const SizedBox(height: 16),
          const Text('Time editing will use the shared editor timing '
              'commands during production integration.',
              style: TextStyle(fontSize: 11, color: _muted)),
        ];
      case 2:
        return [
          _fieldLabel('SUBTITLE STYLE'),
          const Text('Color, alignment, placement and formatting '
              'will reuse existing SubtitleStudio actions.',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.5)),
          const SizedBox(height: 12),
          const Text('Preview only · no simulated formatting saves',
              style: TextStyle(fontSize: 11, color: _muted)),
        ];
      default:
        return [
          _fieldLabel('REVIEW NOTES'),
          Text(_selected.marked
              ? 'This subtitle is marked for review.'
              : 'No review mark on this subtitle.',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            key: const ValueKey('desktop-mark-cue'),
            onPressed: widget.liveReadOnly ? null : () => _replaceCue(_selected.copyWith(
                marked: !_selected.marked)),
            icon: Icon(_selected.marked
                ? Icons.bookmark : Icons.bookmark_outline, size: 15),
            label: Text(_selected.marked ? 'Unmark' : 'Mark for review'),
          ),
          const SizedBox(height: 15),
          const Text('Project comments will connect to shared '
              'checkpoint and comment services.',
              style: TextStyle(fontSize: 11, color: _muted, height: 1.5)),
        ];
    }
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(
      color: _muted, fontSize: 10, letterSpacing: .8,
      fontWeight: FontWeight.w600)),
  );
  Widget _readonlyField(String text) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFF121518),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(text, style: const TextStyle(
      fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
  );

  Widget _secondarySection() {
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
          style: const TextStyle(color: _muted, height: 1.6)),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: () =>
            setState(() => _section = 0), child: const Text('Back to editor')),
      ]),
    ));
  }

  Widget _statusBar() => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: const BoxDecoration(border:
        Border(top: BorderSide(color: _border))),
    child: Row(children: [
      const Icon(Icons.info_outline, color: _accent, size: 13),
      const SizedBox(width: 8),
      Expanded(child: Text(widget.onApplyCueText != null
          ? 'Real session · text edits require Apply · checkpoint-backed'
          : (widget.liveReadOnly
              ? 'Real session · read only · no database changes'
              : 'Demo workspace · no files are modified'),
        style: const TextStyle(color: _muted, fontSize: 10))),
      Text(widget.encoding == null
          ? 'Desktop prototype  •  Windows / macOS / Linux'
          : 'Encoding: ' + widget.encoding!,
        style: const TextStyle(color: _muted, fontSize: 10)),
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
