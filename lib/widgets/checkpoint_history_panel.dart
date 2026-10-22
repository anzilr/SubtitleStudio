import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/services/checkpoint_history_actions.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_history_labels.dart';
import 'package:subtitle_studio/services/checkpoint_history_lane_layout.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_rail.dart';

/// Mobile presentation for the shared Git-inspired checkpoint graph.
class CheckpointHistoryPanel extends ConsumerStatefulWidget {
  final int sessionId;
  final int refreshVersion;
  final HistoryGraphCommands? commands;
  final VoidCallback onCheckpointRestored;

  const CheckpointHistoryPanel({
    super.key,
    required this.sessionId,
    required this.onCheckpointRestored,
    this.refreshVersion = 0,
    this.commands,
  });

  @override
  ConsumerState<CheckpointHistoryPanel> createState() =>
      _CheckpointHistoryPanelState();
}

class _CheckpointHistoryPanelState extends ConsumerState<CheckpointHistoryPanel> {
  CheckpointHistoryGraph? _graph;
  CheckpointHistoryLaneLayout? _lanes;
  String? _error;
  bool _busy = true;
  // Reserve dialogs too, so two actions cannot both receive confirmation.
  bool _dialogPending = false;
  int _generation = 0;

  HistoryGraphCommands get _actions => widget.commands ?? CheckpointHistoryActions(
    ref.read(checkpointRepositoryProvider), sessionId: widget.sessionId);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CheckpointHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      _reload();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_generation;
    setState(() { _busy = true; _error = null; });
    try {
      final loaded = await _actions.load();
      if (!mounted || request != _generation) return;
      setState(() {
        _graph = loaded;
        _lanes = CheckpointHistoryLaneLayout.fromGraph(loaded);
        _busy = false;
      });
    } catch (_) {
      if (!mounted || request != _generation) return;
      setState(() {
        _graph = null;
        _lanes = null;
        _busy = false;
        _error = 'Cannot display inconsistent checkpoint history.';
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<CheckpointHistoryGraph> Function() operation) async {
    if (_busy) return;
    final request = ++_generation;
    setState(() => _busy = true);
    try {
      final updated = await operation();
      if (!mounted || request != _generation) return;
      setState(() {
        _graph = updated;
        _lanes = CheckpointHistoryLaneLayout.fromGraph(updated);
        _busy = false;
      });
    } catch (_) {
      if (!mounted || request != _generation) return;
      setState(() => _busy = false);
      _notify('History operation could not be completed. Reloading the latest state.');
      await _reload();
    }
  }

  String _shortName(HistoryGraphReference historyRef) =>
      CheckpointHistoryLabels.referenceName(historyRef);

  Future<String?> _enterName(String title, String prefix,
      {String initial = ''}) async {
    var entered = initial;
    final suffix = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          onChanged: (value) => entered = value,
          key: const ValueKey('history-ref-name'),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            helperText: 'Letters, digits, /, dot, dash or underscore',
          ),
          onFieldSubmitted: (value) => Navigator.pop(dialog, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, entered),
              child: const Text('Save')),
        ],
      ),
    );
    if (suffix == null || suffix.trim().isEmpty) return null;
    return prefix + suffix.trim();
  }

  Future<bool> _confirm(String title, String message, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: Text(action)),
        ],
      ),
    ) == true;

  Future<void> _checkout({
    required String target,
    required bool branch,
    required Future<CheckpointHistoryGraph?> Function(int expectedHeadId) action,
  }) async {
    if (_busy || _dialogPending || _graph?.headCheckpointId == null) return;
    _dialogPending = true;
    try {
    final expectedHeadId = _graph!.headCheckpointId!;
    final confirmed = await _confirm(
      CheckpointHistoryLabels.checkoutTitle(branch: branch),
      CheckpointHistoryLabels.checkoutMessage(
        branch: branch,
        target: target,
      ),
      branch ? 'Switch' : 'Restore',
    );
    if (!confirmed || !mounted) return;
    final request = ++_generation;
    setState(() => _busy = true);
    try {
      final result = await action(expectedHeadId);
      if (!mounted || request != _generation) return;
      if (result == null) {
        setState(() => _busy = false);
        _notify('History changed before the restore. Showing the latest versions.');
        await _reload();
        return;
      }
      setState(() {
        _graph = result;
        _lanes = CheckpointHistoryLaneLayout.fromGraph(result);
        _busy = false;
      });
      // The owning sheet closes itself before invoking the editor callback.
      widget.onCheckpointRestored();
    } catch (_) {
      if (!mounted || request != _generation) return;
      setState(() => _busy = false);
      _notify('Could not restore this version. Refreshing saved history.');
      await _reload();
    }
    } finally {
      _dialogPending = false;
    }
  }

  Future<void> _create(String kind, int checkpointId) async {
    if (_busy || _dialogPending) return;
    _dialogPending = true;
    try {
    final branch = kind == 'branch';
    final name = await _enterName(
      branch ? 'Name new branch' : 'Name bookmark',
      branch ? 'refs/heads/' : 'refs/bookmarks/',
    );
    if (name == null || !mounted) return;
    await _run(() => branch
      ? _actions.createBranch(name: name, checkpointId: checkpointId)
      : _actions.createBookmark(name: name, checkpointId: checkpointId));
    } finally {
      _dialogPending = false;
    }
  }

  Future<void> _referenceAction(String command,
      HistoryGraphReference historyRef) async {
    if (_busy || _dialogPending) return;
    if (command == 'switch') {
      await _checkout(target: 'branch "' + _shortName(historyRef) + '"',
        branch: true,
        action: (headId) => _actions.checkoutBranch(
          historyRef.name,
          ifCurrentHeadId: headId,
          ifBranchTipId: historyRef.checkpointId,
        ));
    } else if (command == 'checkout') {
      await _checkout(target: 'version #' + historyRef.checkpointId.toString(),
        branch: false,
        action: (headId) => _actions.checkoutCommit(
          historyRef.checkpointId, ifCurrentHeadId: headId));
    } else if (command == 'rename' && historyRef.canRename) {
      _dialogPending = true;
      try {
      final name = await _enterName(
        historyRef.kind == 'branch' ? 'Rename branch' : 'Rename bookmark',
        historyRef.kind == 'branch' ? 'refs/heads/' : 'refs/bookmarks/',
        initial: _shortName(historyRef));
      if (name != null && mounted && name != historyRef.name) {
        await _run(() => _actions.renameReference(
          name: historyRef.name, newName: name));
      }
      } finally {
        _dialogPending = false;
      }
    } else if (command == 'delete' && historyRef.canDelete) {
      _dialogPending = true;
      try {
      final yes = await _confirm('Remove saved name?',
        'Remove "' + _shortName(historyRef) + '"? The saved version '
        'is not deleted immediately, but could become eligible for '
        'cleanup later if no branch or bookmark keeps it.',
        'Remove');
      if (yes && mounted) {
        await _run(() => _actions.deleteReference(historyRef.name));
      }
      } finally {
        _dialogPending = false;
      }
    }
  }

  Widget _refMenu(HistoryGraphReference historyRef) {
    final label = _shortName(historyRef);
    return PopupMenuButton<String>(
      key: ValueKey('history-ref-menu-' + historyRef.name),
      tooltip: label + ' options',
      enabled: !_busy && historyRef.kind != 'head',
      onSelected: (value) => _referenceAction(value, historyRef),
      itemBuilder: (_) => [
        if (historyRef.kind == 'branch')
          const PopupMenuItem(value: 'switch',
              child: Text('Switch to branch')),
        if (historyRef.kind == 'bookmark')
          const PopupMenuItem(value: 'checkout',
              child: Text('Restore bookmarked version')),
        if (historyRef.canRename)
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (historyRef.canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(historyRef.kind == 'head' ? Icons.adjust
          : historyRef.kind == 'branch' ? Icons.call_split : Icons.bookmark,
          size: 16),
        label: Text(CheckpointHistoryLabels.referenceLabel(historyRef)),
      ),
    );
  }

  Widget _commitRow(CheckpointHistoryLaneRow row, int laneCount) {
    final node = row.node;
    final label = '#' + node.checkpointId.toString();
    final railWidth = CheckpointHistoryRailPainter.railWidth(laneCount);
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: ValueKey('history-rail-' + node.checkpointId.toString()),
            painter: CheckpointHistoryRailPainter(
              row: row,
              laneCount: laneCount,
              colors: Theme.of(context).colorScheme,
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: railWidth),
        child: Card(
      key: ValueKey('history-commit-' + node.checkpointId.toString()),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.description, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(CheckpointHistoryLabels.versionDetails(node),
                style: Theme.of(context).textTheme.bodySmall),
              if (node.references.isNotEmpty)
                Wrap(spacing: 5, children: [
                  for (final historyRef in node.references)
                    ActionChip(
                      label: Text(CheckpointHistoryLabels.referenceLabel(
                          historyRef)),
                      onPressed: _busy || historyRef.kind == 'head' ? null : () {
                        _referenceAction(historyRef.kind == 'branch'
                          ? 'switch' : 'checkout', historyRef);
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
            ],
          )),
          PopupMenuButton<String>(
            key: ValueKey('history-node-menu-' + node.checkpointId.toString()),
            enabled: !_busy,
            tooltip: 'Checkpoint actions',
            onSelected: (value) {
              if (value == 'checkout') {
                _checkout(target: 'version ' + label, branch: false,
                  action: (headId) => _actions.checkoutCommit(
                    node.checkpointId, ifCurrentHeadId: headId));
              } else {
                _create(value, node.checkpointId);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'checkout', child: Text('Restore this version')),
              PopupMenuItem(value: 'branch', child: Text('Start a branch here')),
              PopupMenuItem(value: 'bookmark', child: Text('Bookmark this version')),
            ],
          ),
        ]),
      ),
      ),
    ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_graph == null && _busy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center),
        TextButton(onPressed: _reload, child: const Text('Retry')),
      ]));
    }
    final graph = _graph;
    if (graph == null || graph.nodes.isEmpty) {
      return Center(child: TextButton.icon(
        onPressed: _reload, icon: const Icon(Icons.refresh),
        label: const Text('No history yet · Refresh')));
    }
    // The lane layout is cached alongside each loaded history snapshot,
    // avoiding repeated full-graph work on busy/refresh widget rebuilds.
    final lanes = _lanes ?? CheckpointHistoryLaneLayout.fromGraph(graph);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(child: Text(
            CheckpointHistoryLabels.status(graph),
            key: const ValueKey('history-head-status'),
            maxLines: 2,
            style: Theme.of(context).textTheme.titleSmall)),
          IconButton(tooltip: 'Refresh history',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh)),
        ]),
      ),
      const SizedBox(
        height: 36,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            key: ValueKey('history-legend'),
            children: [
              Icon(Icons.radio_button_checked, size: 16),
              SizedBox(width: 4),
              Text('Current version'),
              SizedBox(width: 16),
              Icon(Icons.linear_scale, size: 16),
              SizedBox(width: 4),
              Text('Earlier versions'),
              SizedBox(width: 16),
              Icon(Icons.call_split, size: 16),
              SizedBox(width: 4),
              Text('Branch point'),
            ],
          ),
        ),
      ),
      SizedBox(height: 56, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: graph.references.length,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(child: _refMenu(graph.references[index])),
        ),
      )),
      if (_busy) const LinearProgressIndicator(),
      Expanded(child: ListView.builder(
        key: const ValueKey('history-graph-list'),
        padding: const EdgeInsets.all(12),
        itemCount: lanes.rows.length,
        itemBuilder: (_, index) =>
            _commitRow(lanes.rows[index], lanes.laneCount),
      )),
    ]);
  }
}
