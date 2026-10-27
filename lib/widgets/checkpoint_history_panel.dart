import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/services/checkpoint_history_actions.dart';
import 'package:subtitle_studio/services/checkpoint_history_branch_view.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_history_labels.dart';
import 'package:subtitle_studio/services/checkpoint_history_lane_layout.dart';
import 'package:subtitle_studio/services/history_reference_naming.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_rail.dart';

class _HistoryRailStyle {
  final Color markerColor;
  final Map<int, Color> aboveColors;
  final Map<int, Color> belowColors;

  const _HistoryRailStyle(this.markerColor, this.aboveColors, this.belowColors);
}

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
  String? _operationMessage;
  bool _operationFailed = false;
  bool _busy = true;
  // Reserve dialogs too, so two actions cannot both receive confirmation.
  bool _dialogPending = false;
  bool _showVisualLanes = true;
  String? _selectedBranchName;
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
      if (oldWidget.sessionId != widget.sessionId) {
        _selectedBranchName = null;
      }
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
        if (!loaded.references.any((ref) =>
            ref.kind == 'branch' && ref.name == _selectedBranchName)) {
          _selectedBranchName = null;
        }
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

  Future<bool> _run(Future<CheckpointHistoryGraph> Function() operation,
      {String? focusCreatedBranch, String actionName = 'Update history'}) async {
    if (_busy) return false;
    final request = ++_generation;
    setState(() { _busy = true; _operationMessage = null; });
    try {
      final updated = await operation();
      if (!mounted || request != _generation) return false;
      if (focusCreatedBranch != null && !updated.references.any((ref) =>
          ref.kind == 'branch' && ref.name == focusCreatedBranch)) {
        throw StateError('Created branch was not found in refreshed history.');
      }
      setState(() {
        _graph = updated;
        _lanes = CheckpointHistoryLaneLayout.fromGraph(updated);
        if (focusCreatedBranch != null && updated.references.any((ref) =>
            ref.kind == 'branch' && ref.name == focusCreatedBranch)) {
          _selectedBranchName = focusCreatedBranch;
        } else if (!updated.references.any((ref) =>
            ref.kind == 'branch' && ref.name == _selectedBranchName)) {
          _selectedBranchName = null;
        }
        _busy = false;
      });
      return true;
    } catch (error) {
      if (!mounted || request != _generation) return false;
      setState(() => _busy = false);
      final message = _historyErrorMessage(error, actionName);
      await _reload();
      if (mounted && request + 1 == _generation) {
        setState(() {
          _operationMessage = message;
          _operationFailed = true;
        });
      }
      return false;
    }
  }

  String _historyErrorMessage(Object error, String actionName) {
    if (error is FormatException) {
      return '$actionName failed: invalid name. Use letters, numbers, hyphens or underscores.';
    }
    if (error is StateError) {
      final reason = error.message.toString();
      if (reason.contains('already exists') || reason.contains('overlaps')) {
        return '$actionName failed: that name is already in use. Choose another name.';
      }
      if (reason.contains('belongs to another session') ||
          reason.contains('missing')) {
        return '$actionName failed: the history point could not be verified. Reopen the project and try again.';
      }
    }
    return '$actionName could not be confirmed. Refresh history and try again.';
  }

  String _shortName(HistoryGraphReference historyRef) =>
      CheckpointHistoryLabels.referenceName(historyRef);

  void _focusBranch(HistoryGraphReference historyRef) {
    if (_busy || historyRef.kind != 'branch') return;
    setState(() => _selectedBranchName =
        _selectedBranchName == historyRef.name ? null : historyRef.name);
  }

  Map<String, Color> _branchColors(
      CheckpointHistoryGraph graph, ColorScheme scheme) {
    final branches = graph.references.where((ref) => ref.kind == 'branch')
        .map((ref) => ref.name).toList()..sort();
    final brightness = scheme.brightness;
    return {
      for (var index = 0; index < branches.length; index++)
        branches[index]: HSLColor.fromAHSL(
          1, (35 + index * 137.508) % 360, 0.68,
          brightness == Brightness.dark ? 0.67 : 0.39,
        ).toColor(),
      if (graph.isDetached)
        CheckpointHistoryBranchView.detachedPathOwner:
            HSLColor.fromAHSL(1, 215, 0.76,
                brightness == Brightness.dark ? 0.72 : 0.38).toColor(),
    };
  }

  List<_HistoryRailStyle> _railStyles(
      CheckpointHistoryGraph graph,
      CheckpointHistoryLaneLayout lanes,
      Map<String, Color> branchColors,
      ColorScheme scheme,
      String? selectedBranchName) {
    final owners = CheckpointHistoryBranchView.displayOwners(graph);
    final activeTracks = <int, Color>{};
    final styles = <_HistoryRailStyle>[];
    for (final row in lanes.rows) {
      final above = Map<int, Color>.of(activeTracks);
      for (final lane in row.joiningLanes) {
        activeTracks.remove(lane);
      }
      final owner = selectedBranchName ?? owners[row.node.checkpointId];
      final color = branchColors[owner] ?? scheme.outline;
      if (row.node.parentCheckpointId != null) {
        activeTracks[row.lane] = color;
      }
      styles.add(_HistoryRailStyle(
        color, Map<int, Color>.unmodifiable(above),
        Map<int, Color>.unmodifiable(activeTracks),
      ));
    }
    return styles;
  }

  Future<String?> _enterName(String title, String prefix,
      {String initial = ''}) async {
    var entered = initial;
    String? inputError;
    final kind = prefix == 'refs/heads/' ? 'branch' : 'bookmark';
    final suffix = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (dialog, updateDialog) {
        void save(String value) {
          final trimmed = value.trim();
          final error = HistoryReferenceNaming.validationError(
              '$prefix$trimmed', kind);
          if (error != null) {
            updateDialog(() => inputError = error);
            return;
          }
          Navigator.pop(dialog, trimmed);
        }
        return AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          onChanged: (value) {
            entered = value;
            if (inputError != null) {
              updateDialog(() => inputError = HistoryReferenceNaming
                  .validationError('$prefix${value.trim()}', kind));
            }
          },
          key: const ValueKey('history-ref-name'),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            helperText: 'Use review-fixes, not spaces',
          ).copyWith(errorText: inputError, errorMaxLines: 3),
          onFieldSubmitted: save,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => save(entered),
              child: const Text('Save')),
        ],
      );
      }),
    );
    return suffix == null ? null : prefix + suffix;
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
      branch ? 'Switch path' : 'Restore',
    );
    if (!confirmed || !mounted) return;
    final request = ++_generation;
    setState(() => _busy = true);
    try {
      final result = await action(expectedHeadId);
      if (!mounted || request != _generation) return;
      if (result == null) {
        setState(() => _busy = false);
        _notify('History changed before the restore. Showing the latest points.');
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
      _notify('Could not restore this point. Refreshing saved history.');
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
    final saved = await _run(() => branch
      ? _actions.createBranch(name: name, checkpointId: checkpointId)
      : _actions.createBookmark(name: name, checkpointId: checkpointId),
      focusCreatedBranch: branch ? name : null,
      actionName: branch ? 'Create branch' : 'Save bookmark');
    if (saved && mounted) {
      setState(() {
        _operationFailed = false;
        _operationMessage = branch
            ? 'Branch "${name.substring('refs/heads/'.length)}" created. Use Switch to this branch to edit there.'
            : 'Bookmark "${name.substring('refs/bookmarks/'.length)}" saved.';
      });
    }
    } finally {
      _dialogPending = false;
    }
  }

  Future<void> _referenceAction(String command,
      HistoryGraphReference historyRef) async {
    if (_busy || _dialogPending) return;
    if (command == 'switch') {
      await _checkout(target: '"' + _shortName(historyRef) + '"',
        branch: true,
        action: (headId) => _actions.checkoutBranch(
          historyRef.name,
          ifCurrentHeadId: headId,
          ifBranchTipId: historyRef.checkpointId,
        ));
    } else if (command == 'checkout') {
      await _checkout(target: 'point #' + historyRef.checkpointId.toString(),
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
        'Remove "' + _shortName(historyRef) + '"? The history point '
        'is not deleted immediately, but could become eligible for '
        'cleanup later if no editing path or bookmark keeps it.',
        'Remove');
      if (yes && mounted) {
        await _run(() => _actions.deleteReference(historyRef.name));
      }
      } finally {
        _dialogPending = false;
      }
    }
  }

  List<PopupMenuEntry<String>> _referenceMenuItems(
      HistoryGraphReference historyRef) => [
        if (historyRef.kind == 'branch')
          const PopupMenuItem(value: 'switch',
              child: Text('Switch to this path')),
        if (historyRef.kind == 'bookmark')
          const PopupMenuItem(value: 'checkout',
              child: Text('Restore bookmarked point')),
        if (historyRef.canRename)
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (historyRef.canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ];

  Future<void> _manageReferences() async {
    final graph = _graph;
    if (_busy || graph == null) return;
    final paths = graph.references
        .where((ref) => ref.kind == 'branch').toList();
    final bookmarks = graph.references
        .where((ref) => ref.kind == 'bookmark').toList();
    final branchColors = _branchColors(graph, Theme.of(context).colorScheme);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(children: [
                Expanded(child: Text('Branches & bookmarks',
                    style: Theme.of(sheetContext).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Close saved paths',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
            Expanded(child: ListView(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Branches'),
              ),
              for (final historyRef in paths)
                _managedReferenceTile(sheetContext, historyRef, branchColors),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Bookmarks'),
              ),
              if (bookmarks.isEmpty)
                const ListTile(title: Text('No bookmarks saved yet')),
              for (final historyRef in bookmarks)
                _managedReferenceTile(sheetContext, historyRef, branchColors),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _managedReferenceTile(BuildContext sheetContext,
      HistoryGraphReference historyRef, Map<String, Color> branchColors) {
    final color = branchColors[historyRef.name];
    return ListTile(
    key: ValueKey('history-manage-' + historyRef.name),
    leading: Icon(historyRef.kind == 'branch'
        ? Icons.call_split : Icons.bookmark_outline, color: color),
    title: Text(_shortName(historyRef)),
    subtitle: Text('Point #${historyRef.checkpointId}' +
        (historyRef.isAttached ? ' · In use' : '') +
        (historyRef.kind == 'branch' ? ' · Tap to filter' : '')),
    onTap: historyRef.kind == 'branch' ? () {
      Navigator.of(sheetContext).pop();
      _focusBranch(historyRef);
    } : null,
    trailing: PopupMenuButton<String>(
      key: ValueKey('history-manage-menu-' + historyRef.name),
      tooltip: '${_shortName(historyRef)} options',
      onSelected: (value) {
        Navigator.of(sheetContext).pop();
        _referenceAction(value, historyRef);
      },
      itemBuilder: (_) => _referenceMenuItems(historyRef),
    ),
  );
  }

  Widget _refMenu(HistoryGraphReference historyRef,
      Map<String, Color> branchColors) {
    final label = _shortName(historyRef);
    if (historyRef.kind == 'branch') {
      final color = branchColors[historyRef.name]!;
      final focused = _selectedBranchName == historyRef.name;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Tooltip(message: 'Show only ${_shortName(historyRef)} history',
          child: ChoiceChip(
          key: ValueKey('history-branch-filter-' + historyRef.name),
          label: Text(CheckpointHistoryLabels.referenceLabel(historyRef)),
          avatar: Icon(Icons.call_split, color: color, size: 16),
          // A branch's color identifies its path even when the filter is not
          // selected. The active HEAD branch should never look disabled.
          selected: focused,
          backgroundColor: color.withValues(alpha: 0.13),
          selectedColor: color.withValues(alpha: 0.27),
          disabledColor: color.withValues(alpha: 0.13),
          labelStyle: TextStyle(color: color,
              fontWeight: historyRef.isAttached || focused
                  ? FontWeight.w700 : FontWeight.w500),
          side: BorderSide(color: color.withValues(alpha: 0.75)),
          onSelected: _busy ? null : (_) => _focusBranch(historyRef),
          visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuButton<String>(
          key: ValueKey('history-ref-menu-' + historyRef.name),
          tooltip: '$label options',
          enabled: !_busy,
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (value) => _referenceAction(value, historyRef),
          itemBuilder: (_) => _referenceMenuItems(historyRef),
        ),
      ]);
    }
    return PopupMenuButton<String>(
      key: ValueKey('history-ref-menu-' + historyRef.name),
      tooltip: label + ' options',
      enabled: !_busy && historyRef.kind != 'head',
      onSelected: (value) => _referenceAction(value, historyRef),
      itemBuilder: (_) => _referenceMenuItems(historyRef),
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(historyRef.kind == 'head' ? Icons.adjust
          : historyRef.kind == 'branch' ? Icons.call_split : Icons.bookmark,
          size: 16),
        label: Text(CheckpointHistoryLabels.referenceLabel(historyRef)),
      ),
    );
  }

  /// Unlike the horizontal chips, this picker always exposes every branch,
  /// including names created beyond the edge of a narrow screen.
  Widget _branchPicker(List<HistoryGraphReference> branches,
      Map<String, Color> branchColors,
      HistoryGraphReference? selectedBranch) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(children: [
        Text('View branch', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 10),
        Expanded(child: PopupMenuButton<String>(
          key: const ValueKey('history-branch-picker'),
          tooltip: 'Choose branch to view',
          enabled: !_busy,
          onSelected: (name) => setState(() =>
              _selectedBranchName = name.isEmpty ? null : name),
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: '',
              child: Row(children: [
                const Icon(Icons.layers_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('All branches')),
                if (selectedBranch == null) const Icon(Icons.check, size: 18),
              ]),
            ),
            for (final branch in branches)
              PopupMenuItem<String>(
                value: branch.name,
                child: Row(children: [
                  Icon(Icons.call_split, size: 18,
                      color: branchColors[branch.name]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_shortName(branch),
                      overflow: TextOverflow.ellipsis)),
                  if (selectedBranch?.name == branch.name)
                    const Icon(Icons.check, size: 18),
                ]),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(selectedBranch == null
                  ? Icons.layers_outlined : Icons.call_split,
                  size: 18,
                  color: selectedBranch == null
                      ? scheme.onSurfaceVariant
                      : branchColors[selectedBranch.name]),
              const SizedBox(width: 8),
              Expanded(child: Text(selectedBranch == null
                  ? 'All branches' : _shortName(selectedBranch),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _commitRow(CheckpointHistoryLaneRow row, int laneCount,
      _HistoryRailStyle style, Map<String, Color> branchColors) {
    final node = row.node;
    final label = '#' + node.checkpointId.toString();
    final railWidth = CheckpointHistoryRailPainter.railWidth(laneCount);
    final card = Card(
      key: ValueKey('history-commit-' + node.checkpointId.toString()),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 3, height: 44, color: style.markerColor),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CheckpointHistoryLabels.entryTitle(
                  operationType: node.operationType,
                  description: node.description,
                ), maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(CheckpointHistoryLabels.versionDetails(node),
                style: Theme.of(context).textTheme.bodySmall),
              if (node.references.isNotEmpty)
                Wrap(spacing: 5, children: [
                  for (final historyRef in node.references)
                    ActionChip(
                      avatar: historyRef.kind == 'branch'
                          ? Icon(Icons.call_split, size: 15,
                              color: branchColors[historyRef.name])
                          : null,
                      label: Text(CheckpointHistoryLabels.referenceLabel(
                          historyRef)),
                      backgroundColor: historyRef.kind == 'branch'
                          ? branchColors[historyRef.name]?.withValues(alpha: 0.14)
                          : null,
                      labelStyle: historyRef.kind == 'branch'
                          ? TextStyle(color: branchColors[historyRef.name],
                              fontWeight: historyRef.isAttached
                                  ? FontWeight.w700 : FontWeight.w500)
                          : null,
                      side: historyRef.kind == 'branch'
                          ? BorderSide(color: (branchColors[historyRef.name] ??
                              Theme.of(context).colorScheme.outline)
                              .withValues(alpha: 0.7))
                          : null,
                      onPressed: _busy || historyRef.kind == 'head' ? null : () {
                        if (historyRef.kind == 'branch') {
                          _focusBranch(historyRef);
                        } else {
                          _referenceAction('checkout', historyRef);
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
            ],
          )),
          PopupMenuButton<String>(
            key: ValueKey('history-node-menu-' + node.checkpointId.toString()),
            enabled: !_busy,
            tooltip: 'History point options',
            onSelected: (value) {
              if (value == 'checkout') {
                _checkout(target: 'point ' + label, branch: false,
                  action: (headId) => _actions.checkoutCommit(
                    node.checkpointId, ifCurrentHeadId: headId));
              } else {
                _create(value, node.checkpointId);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'checkout', child: Text('Restore this point')),
              PopupMenuItem(value: 'branch', child: Text('Branch from this point')),
              PopupMenuItem(value: 'bookmark', child: Text('Bookmark this point')),
            ],
          ),
        ]),
      ),
    );
    if (!_showVisualLanes) return card;
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: ValueKey('history-rail-' + node.checkpointId.toString()),
            painter: CheckpointHistoryRailPainter(
              row: row,
              laneCount: laneCount,
              colors: Theme.of(context).colorScheme,
              markerColor: style.markerColor,
              aboveColors: style.aboveColors,
              belowColors: style.belowColors,
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: railWidth),
        child: card,
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
    final selectedRefs = graph.references.where((ref) =>
        ref.kind == 'branch' && ref.name == _selectedBranchName);
    final selectedBranch = selectedRefs.isEmpty ? null : selectedRefs.first;
    final selectedName = selectedBranch?.name;
    final visibleIds = selectedName == null ? null
        : CheckpointHistoryBranchView.ancestorIds(graph, selectedName);
    final lanes = visibleIds == null
        ? (_lanes ?? CheckpointHistoryLaneLayout.fromGraph(graph))
        : CheckpointHistoryLaneLayout.fromGraph(
            graph, visibleCheckpointIds: visibleIds);
    final scheme = Theme.of(context).colorScheme;
    final branchColors = _branchColors(graph, scheme);
    final railStyles = _railStyles(
        graph, lanes, branchColors, scheme, selectedName);
    // HEAD is already represented by the status and current-point marker;
    // leaving its noninteractive chip out keeps the first branch reachable
    // without horizontal scrolling on compact phones.
    final visibleRefs = graph.references
        .where((ref) => ref.kind != 'head').toList();
    final branches = graph.references
        .where((ref) => ref.kind == 'branch').toList();
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(child: Text('Branches & bookmarks · '
              '${graph.references.where((ref) => ref.kind != 'head').length}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall)),
          TextButton.icon(
            key: const ValueKey('history-manage-references'),
            onPressed: _busy ? null : _manageReferences,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Manage'),
          ),
          IconButton(
            key: const ValueKey('history-view-toggle'),
            tooltip: _showVisualLanes ? 'Show list view' : 'Show version map',
            onPressed: () => setState(() => _showVisualLanes = !_showVisualLanes),
            icon: Icon(_showVisualLanes ? Icons.view_list : Icons.account_tree),
          ),
        ]),
      ),
      _branchPicker(branches, branchColors, selectedBranch),
      if (_operationMessage != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            key: const ValueKey('history-operation-feedback'),
            padding: const EdgeInsets.fromLTRB(12, 5, 2, 5),
            decoration: BoxDecoration(
              color: _operationFailed
                  ? scheme.errorContainer : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(_operationFailed ? Icons.error_outline : Icons.check_circle_outline,
                  size: 18,
                  color: _operationFailed
                      ? scheme.onErrorContainer : scheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(_operationMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _operationFailed
                        ? scheme.onErrorContainer : scheme.onSecondaryContainer,
                  ))),
              IconButton(
                key: const ValueKey('history-dismiss-feedback'),
                tooltip: 'Dismiss history message',
                icon: const Icon(Icons.close, size: 18),
                color: _operationFailed
                    ? scheme.onErrorContainer : scheme.onSecondaryContainer,
                onPressed: () => setState(() => _operationMessage = null),
              ),
            ]),
          ),
        ),
      if (selectedBranch != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Icon(Icons.call_split, size: 16,
                color: branchColors[selectedBranch.name]),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Showing ${_shortName(selectedBranch)} · '
              '${lanes.rows.length} point${lanes.rows.length == 1 ? '' : 's'}',
              key: const ValueKey('history-filter-status'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            )),
            TextButton(
              key: const ValueKey('history-show-all'),
              onPressed: () => setState(() => _selectedBranchName = null),
              child: const Text('Show all'),
            ),
          ]),
        ),
      if (selectedBranch != null && !selectedBranch.isAttached)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('history-switch-selected-branch'),
              onPressed: _busy ? null : () =>
                  _referenceAction('switch', selectedBranch),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Switch to this branch'),
            ),
          ),
        ),
      if (_showVisualLanes && selectedBranch == null && lanes.laneCount > 6)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text('Many paths overlap here. Tap a branch to see its '
              'history clearly; the list keeps every point available.'),
        ),
      if (_showVisualLanes) SizedBox(
        height: 36,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            key: const ValueKey('history-legend'),
            children: [
              const Icon(Icons.radio_button_checked, size: 16),
              const SizedBox(width: 4),
              const Text('Current point'),
              const SizedBox(width: 16),
              const Icon(Icons.linear_scale, size: 16),
              const SizedBox(width: 4),
              const Text('Earlier points'),
              const SizedBox(width: 16),
              const Icon(Icons.call_split, size: 16),
              const SizedBox(width: 4),
              const Text('History split'),
              if (graph.isDetached) ...[
                const SizedBox(width: 16),
                Icon(Icons.alt_route, size: 16,
                  color: branchColors[
                      CheckpointHistoryBranchView.detachedPathOwner]),
                const SizedBox(width: 4),
                Text('Current separate path',
                  key: const ValueKey('history-detached-path-legend'),
                  style: TextStyle(color: branchColors[
                      CheckpointHistoryBranchView.detachedPathOwner])),
              ],
            ],
          ),
        ),
      ),
      SizedBox(height: 56, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: visibleRefs.length,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(child: _refMenu(visibleRefs[index], branchColors)),
        ),
      )),
      if (_busy) const LinearProgressIndicator(),
      Expanded(child: ListView.builder(
        key: const ValueKey('history-graph-list'),
        padding: const EdgeInsets.all(12),
        itemCount: lanes.rows.length,
        itemBuilder: (_, index) =>
            _commitRow(lanes.rows[index], lanes.laneCount,
                railStyles[index], branchColors),
      )),
    ]);
  }
}
