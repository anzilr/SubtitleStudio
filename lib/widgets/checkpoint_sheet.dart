import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/screens/screen_help.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_panel.dart';
import 'package:subtitle_studio/services/checkpoint_timeline.dart';
import 'package:subtitle_studio/services/checkpoint_history_labels.dart';

/// Edit History Sheet - User-friendly undo/redo interface
/// 
/// This sheet displays the editing history for a session with:
/// - Timeline view showing all changes
/// - Easy undo to any point
/// - Save points for important states
/// - Automatic history tracking
class CheckpointSheet extends ConsumerStatefulWidget {
  final int sessionId;
  final int subtitleCollectionId;
  final Function() onCheckpointRestored;

  const CheckpointSheet({
    super.key,
    required this.sessionId,
    required this.subtitleCollectionId,
    required this.onCheckpointRestored,
  });

  @override
  ConsumerState<CheckpointSheet> createState() => _CheckpointSheetState();
}

/// Tree node representing a checkpoint in the tree structure
class CheckpointNode {
  final Checkpoint checkpoint;
  final List<CheckpointNode> children;
  final int depth;
  final Color branchColor;
  
  CheckpointNode({
    required this.checkpoint,
    required this.children,
    required this.depth,
    required this.branchColor,
  });
}

class _CheckpointSheetState extends ConsumerState<CheckpointSheet> {
  List<Checkpoint> _checkpoints = [];
  bool _isLoading = true;
  bool _showGraph = true;
  bool _classicCheckoutPending = false;
  int _graphRefreshVersion = 0;
  int _historyLoadGeneration = 0;
  List<CheckpointNode> _treeNodes = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  
  @override
  void dispose() {
    _historyLoadGeneration++;
    _scrollController.dispose();
    super.dispose();
  }
  
  /// Build timeline from history entries
  /// SIMPLIFIED: Linear timeline with no branching
  void _buildTree() {
    if (_checkpoints.isEmpty) {
      _treeNodes = [];
      return;
    }
    
    // Sort by timestamp (chronological order)
    final sortedCheckpoints = List<Checkpoint>.from(_checkpoints);
    sortedCheckpoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Convert to flat list - all same color (blue)
    _treeNodes = sortedCheckpoints.map((checkpoint) {
      return CheckpointNode(
        checkpoint: checkpoint,
        children: [], // No nested children in simplified view
        depth: 0, // All at same depth (linear)
        branchColor: Theme.of(context).colorScheme.primary,
      );
    }).toList();
  }
  
  int? _currentCheckpointId; // Track the current/latest point in history
  
  Future<void> _loadHistory() async {
    final loadId = ++_historyLoadGeneration;
    setState(() => _isLoading = true);
    
    try {
      final checkpoints = await ref.read(checkpointRepositoryProvider).getCheckpointsForSession(widget.sessionId);

      // Find the currently active point
      Checkpoint? currentCheckpoint;
      if (checkpoints.isNotEmpty) {
        final activeCheckpoints = checkpoints
            .where((c) => c.isActive)
            .toList();
        if (activeCheckpoints.isNotEmpty) {
          // Sort by timestamp and get the most recent active one
          activeCheckpoints.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          currentCheckpoint = activeCheckpoints.first;
        }
      }

      if (!mounted || loadId != _historyLoadGeneration) return;

      setState(() {
        _checkpoints = checkpoints;
        _graphRefreshVersion++;
        _currentCheckpointId = currentCheckpoint?.id;
        _buildTree();
        _isLoading = false;
      });

      if (currentCheckpoint != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToCurrentCheckpoint();
          }
        });
      }
    } catch (e) {
      if (!mounted || loadId != _historyLoadGeneration) return;
      setState(() => _isLoading = false);
      SnackbarHelper.showError(
        context,
        'Could not load checkpoint history. Please try again.',
      );
    }
  }
  
  void _scrollToCurrentCheckpoint() {
    if (_currentCheckpointId == null || _treeNodes.isEmpty || !_scrollController.hasClients) {
      return;
    }
    
    // Find the index of the current checkpoint in the tree nodes
    final currentIndex = _treeNodes.indexWhere(
      (node) => node.checkpoint.id == _currentCheckpointId,
    );
    
    if (currentIndex == -1) {
      return;
    }
    
    // Calculate the scroll position (80 pixels per item + some padding)
    const itemHeight = 80.0;
    const topPadding = 16.0;
    final scrollPosition = (currentIndex * itemHeight) + topPadding;
    
    // Calculate the viewport height to center the item
    final viewportHeight = _scrollController.position.viewportDimension;
    final centeredPosition = scrollPosition - (viewportHeight / 2) + (itemHeight / 2);
    
    // Scroll to the position
    _scrollController.animateTo(
      centeredPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _restoreCheckpoint(Checkpoint checkpoint) async {
    if (_classicCheckoutPending) return;
    _classicCheckoutPending = true;
    try {
    // O(history size), cycle-bounded traversal, including alternate branches.
    final futureCheckpointsCount = CheckpointTimeline.descendantIds(
      checkpoints: _checkpoints,
      parentCheckpointId: checkpoint.id,
    ).length;
    
    // Show confirmation dialog with warning about future checkpoints
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      futureCheckpointsCount > 0 ? Icons.warning_amber : Icons.restore,
                      color: futureCheckpointsCount > 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Restore this point?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Go back to: ${CheckpointHistoryLabels.entryTitle(
                          operationType: checkpoint.operationType,
                          description: checkpoint.description,
                        )}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (futureCheckpointsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.tertiary),
                            const SizedBox(width: 8),
                            Text(
                              'Note',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$futureCheckpointsCount newer change${futureCheckpointsCount > 1 ? 's are' : ' is'} preserved as alternate history. Making a new edit from here creates a new branch.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    'You can move forward in history after undoing.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text('Restore point'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(checkpointRepositoryProvider).checkoutCheckpoint(
        checkpointId: checkpoint.id,
        sessionId: widget.sessionId,
        ifCurrentHeadId: _currentCheckpointId,
      );

      if (success && mounted) {
        // Reload history to update the current point indicator
        await _loadHistory();
        
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Restored successfully');
          Navigator.pop(context);
          widget.onCheckpointRestored();
        }
      } else if (mounted) {
        SnackbarHelper.showError(context, 'Failed to restore');
      }
    }
    } finally {
      _classicCheckoutPending = false;
    }
  }

  Future<void> _createManualCheckpoint() async {
    // Show dialog to get checkpoint name
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark_add, color: Theme.of(context).primaryColor, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Create Save Point',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'What is a Save Point?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saves a named version in this project\'s edit history, not a separate backup file. A bookmark can name an existing version without making a new one.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Before major changes',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  onSubmitted: (value) => Navigator.pop(context, value),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, nameController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      await ref.read(checkpointRepositoryProvider).createManualCheckpoint(
        sessionId: widget.sessionId,
        subtitleCollectionId: widget.subtitleCollectionId,
        customDescription: name,
      );

      await _loadHistory();
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Save point created: $name');
      }
    }
  }

  Future<void> _createSnapshot() async {
    // Show dialog to get snapshot name
    final nameController = TextEditingController(text: 'Snapshot');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.tertiary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Save Project Point',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Text(
                            'What is a Saved Point?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saves a complete version of your subtitles in Edit History. It does not create a separate backup file. Export the project if you need an independent copy.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Before major changes',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  onSubmitted: (value) => Navigator.pop(context, value),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, nameController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      await ref.read(checkpointRepositoryProvider).createManualCheckpoint(
        sessionId: widget.sessionId,
        subtitleCollectionId: widget.subtitleCollectionId,
        customDescription: name,
      );

      await _loadHistory();
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Project point saved: $name');
      }
    }
  }

  Icon _getOperationIcon(String operationType, Color neutralColor) {
    switch (operationType) {
      case 'delete':
        return Icon(Icons.delete, color: neutralColor, size: 20);
      case 'add':
        return Icon(Icons.add, color: neutralColor, size: 20);
      case 'split':
        return Icon(Icons.call_split, color: neutralColor, size: 20);
      case 'merge':
        return Icon(Icons.merge, color: neutralColor, size: 20);
      case 'edit':
        return Icon(Icons.edit, color: neutralColor, size: 20);
      case 'effect':
        return Icon(Icons.auto_fix_high, color: neutralColor, size: 20);
      case 'manual':
        return Icon(Icons.bookmark, color: neutralColor, size: 20);
      default:
        return Icon(Icons.info, color: neutralColor, size: 20);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    // Convert UTC to local time
    final localTime = timestamp.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as "MMM d, HH:mm" manually
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[localTime.month - 1];
      final day = localTime.day;
      final hour = localTime.hour.toString().padLeft(2, '0');
      final minute = localTime.minute.toString().padLeft(2, '0');
      return '$month $day, $hour:$minute';
    }
  }
  
  /// Lazily build the legacy cards rather than allocating every card eagerly.
  Widget _buildTreeView(BuildContext context, bool isDark,
      Color onSurfaceColor, Color mutedColor, Color borderColor) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _treeNodes.length,
      itemBuilder: (context, index) {
        final node = _treeNodes[index];
        return _buildTreeNode(
          context, node, isDark, onSurfaceColor, mutedColor, borderColor,
          isFirst: index == 0,
          isLast: index == _treeNodes.length - 1,
          showBranchLine: index + 1 < _treeNodes.length &&
              _treeNodes[index + 1].depth != node.depth,
        );
      },
    );
  }

  /// Get checkpoint type details (icon, color, size)
  Map<String, dynamic> _getCheckpointTypeDetails(String operationType, String checkpointType) {
    if (checkpointType == 'snapshot') {
      return {
        'icon': Icons.save, // Full Backup icon
        'color': Theme.of(context).colorScheme.tertiary,
        'size': 20.0,
      };
    } else if (operationType == 'manual') {
      return {
        'icon': Icons.bookmark_add, // Save Point icon
        'color': Theme.of(context).colorScheme.secondary,
        'size': 18.0,
      };
    } else {
      return {
        'icon': Icons.circle,
        'color': Theme.of(context).colorScheme.primary,
        'size': 12.0,
      };
    }
  }

  /// Build a single tree node (simplified linear view)
  Widget _buildTreeNode(
    BuildContext context,
    CheckpointNode node,
    bool isDark,
    Color onSurfaceColor,
    Color mutedColor,
    Color borderColor, {
    bool isFirst = false,
    bool isLast = false,
    bool showBranchLine = false,
  }) {
    final checkpoint = node.checkpoint;
    final isCurrentCheckpoint = checkpoint.id == _currentCheckpointId;
    final typeDetails = _getCheckpointTypeDetails(checkpoint.operationType, checkpoint.checkpointType);
    final dotSize = (typeDetails['size'] as double) + (isCurrentCheckpoint ? 4 : 0);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tree visualization column - Fixed width for alignment
        SizedBox(
          width: 40,
          height: 80, // Fixed height for the timeline segment
          child: Stack(
            children: [
              // Continuous vertical line - flows behind the icons
              Positioned(
                left: 19,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              // Hide line at top for first item
              if (isFirst)
                Positioned(
                  left: 19,
                  top: 0,
                  child: Container(
                    width: 2,
                    height: 8,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              // Hide line at bottom for last item
              if (isLast)
                Positioned(
                  left: 19,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    height: 64,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              // Checkpoint icon - centered on line (on top of the line)
              // Background circle to hide the line behind the icon
              Positioned(
                left: 20 - (dotSize / 2) - 2,
                top: 6,
                child: Container(
                  width: dotSize + 4,
                  height: dotSize + 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Actual icon on top
              Positioned(
                left: 20 - (dotSize / 2),
                top: 8,
                child: Icon(
                  typeDetails['icon'],
                  size: dotSize,
                  color: isCurrentCheckpoint 
                      ? Theme.of(context).colorScheme.tertiary 
                      : typeDetails['color'],
                  shadows: isCurrentCheckpoint ? [
                    Shadow(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ] : null,
                ),
              ),
            ],
          ),
        ),
            
        // Checkpoint card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 8),
            child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _restoreCheckpoint(checkpoint),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrentCheckpoint
                            ? (isDark ? onSurfaceColor.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surfaceContainerLow)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrentCheckpoint 
                              ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5)
                              : borderColor,
                          width: isCurrentCheckpoint ? 2 : 1,
                        ),
                        boxShadow: isCurrentCheckpoint ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ] : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: mutedColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _getOperationIcon(checkpoint.operationType, mutedColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CheckpointHistoryLabels.entryTitle(
                                    operationType: checkpoint.operationType,
                                    description: checkpoint.description,
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // Add label for snapshot checkpoints
                                    if (checkpoint.checkpointType == 'snapshot') ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: mutedColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: mutedColor.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.camera_alt,
                                              size: 10,
                                              color: mutedColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              CheckpointHistoryLabels.entryBadge(
                                                operationType: checkpoint.operationType,
                                                checkpointType: checkpoint.checkpointType,
                                              ),
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: mutedColor,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 9,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Add label for manual checkpoints
                                    if (checkpoint.operationType == 'manual' && checkpoint.checkpointType != 'snapshot') ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: mutedColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: mutedColor.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.diamond,
                                              size: 10,
                                              color: mutedColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              CheckpointHistoryLabels.entryBadge(
                                                operationType: checkpoint.operationType,
                                                checkpointType: checkpoint.checkpointType,
                                              ),
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: mutedColor,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 9,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],

                                    Text(
                                      _formatTimestamp(checkpoint.timestamp),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.restore,
                            size: 18,
                            color: mutedColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = onSurfaceColor.withValues(alpha: 0.6);
    final borderColor = onSurfaceColor.withValues(alpha: 0.12);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SafeArea(
      // Give PopupMenuButton, ActionChip and other interactive history
      // controls a real Material ancestor inside the bottom sheet.
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit History',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_checkpoints.length} saved point${_checkpoints.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _showGraph ? 'Show simple history list' : 'Show visual history',
                    onPressed: () => setState(() => _showGraph = !_showGraph),
                    icon: Icon(_showGraph ? Icons.view_timeline : Icons.account_tree_outlined),
                  ),
                  // Help button
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the checkpoint sheet first
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpScreen(
                            initialCategoryId: 'checkpoint-system',
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.help_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    tooltip: 'Help',
                  ),
                ],
              ),
            ),

          // Shared graph by default. The classic view remains available for
          // backwards-compatible mobile history interactions.
          Expanded(
            child: _showGraph
                ? CheckpointHistoryPanel(
                    sessionId: widget.sessionId,
                    refreshVersion: _graphRefreshVersion,
                    onCheckpointRestored: () {
                      // Close the sheet before allowing the editor callback
                      // to trigger route/state changes.
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      widget.onCheckpointRestored();
                    },
                  )
                : _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _checkpoints.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                size: 64,
                                color: mutedColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No history yet',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: mutedColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your changes will be automatically saved here',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: mutedColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildTreeView(
                        context, isDark, onSurfaceColor, mutedColor, borderColor),

          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                // On mobile, split space equally between snapshot and checkpoint (no close button)
                // On larger screens, show all three buttons equally
                if (!isMobile) ...[
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: onSurfaceColor,
                          side: BorderSide(color: borderColor),
                        ),
                        icon: Icon(Icons.close, size: 18),
                        label: const Text('Close'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _createSnapshot,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      icon: Icon(Icons.save, size: 18),
                      label: const Text('Save History'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _createManualCheckpoint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      icon: Icon(Icons.bookmark_add, size: 18),
                      label: const Text('Save Point'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
