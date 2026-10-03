// Checkpoint Manager - Hybrid Snapshot + Delta System
//
// This service implements a reliable checkpoint system using a hybrid approach:
// - Snapshots: Full state stored periodically (every 10 checkpoints, at branch points, initial state)
// - Deltas: Only changes stored between snapshots
//
// Key Features:
// - Snapshot-based accuracy: Full state stored periodically for 100% accuracy
// - Delta-based efficiency: Only changes stored between snapshots
// - Git-style branching: restoring history moves one HEAD reference without
//   deleting alternate descendants
// - Automatic checkpoint creation: On major operations (delete, add, split, merge, effect)
// - Manual checkpoints: User can create checkpoints on demand
// - Efficient restoration: Apply deltas from nearest snapshot
//
// Storage Strategy:
// - Initial checkpoint: Always a snapshot (captures starting state)
// - Every 10th checkpoint: Snapshot (ensures max 9 deltas to traverse)
// - Branch points: Snapshot (ensures accuracy when branching)
// - Regular checkpoints: Deltas only (space-efficient)
//
// Legacy Restoration Semantics:
// 1. Find the target checkpoint and its nearest ancestor snapshot.
// 2. Validate the parent chain.
// 3. Reconstruct using strict deltas.
// 4. Move the single HEAD marker to the target without deleting descendants.
// 5. Existing checkpoints still represent PRE-operation state until the v2
//    state-after-operation migration is completed.
//
// Storage Efficiency:
// - A typical subtitle file with 1000 lines might be ~50KB
// - Snapshot every 10 checkpoints: 10% are 50KB, 90% are ~100 bytes
// - 100 checkpoints = 10 snapshots (500KB) + 90 deltas (9KB) = ~509KB
// - vs Pure snapshots: 5MB (10x reduction)
// - vs Pure deltas: Potential accuracy issues (now solved!)

import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/checkpoint_policy.dart';
import 'package:subtitle_studio/services/checkpoint_timeline.dart';
import 'package:subtitle_studio/services/checkpoint_preferences_repository.dart';
import 'package:subtitle_studio/services/checkpoint_store.dart';
import 'dart:convert';

class CheckpointManager {
  final CheckpointStore _store;
  final CheckpointPreferencesRepository _preferences;

  CheckpointManager(Isar isar)
      : _store = CheckpointStore(isar),
        _preferences = CheckpointPreferencesRepository(isar);

  // Get maximum checkpoints from preferences (0 = unlimited)
  Future<int> getMaxCheckpoints() {
    return _preferences.getMaxCheckpoints();
  }

  // Get snapshot interval from preferences
  Future<int> getSnapshotInterval() {
    return _preferences.getSnapshotInterval();
  }

  // Get checkpoint strategy from preferences ('hybrid', 'snapshot', or 'delta')
  Future<String> getCheckpointStrategy() {
    return _preferences.getCheckpointStrategy();
  }
  
  /// Creates initial snapshot of the database state
  /// This should be called when opening a session for the first time
  Future<int> createInitialSnapshot({
    required int sessionId,
    required int subtitleCollectionId,
  }) async {
    try {
      final collection = await _store.getSubtitleCollection(subtitleCollectionId);
      if (collection == null) {
        logWarning('Subtitle collection not found for initial snapshot: $subtitleCollectionId');
        return 0; // Return 0 to indicate no snapshot was created
      }
      
      // Check if initial snapshot already exists
      final existingInitial = await _store.findInitialSnapshot(
        sessionId: sessionId,
        subtitleCollectionId: subtitleCollectionId,
      );
      
      if (existingInitial != null) {
        logInfo('Initial snapshot already exists: ${existingInitial.id}');
        return existingInitial.id;
      }

      final currentHead = await _getCurrentHeadCheckpoint(sessionId);
      if (currentHead != null) {
        logWarning(
          'Refusing to create an initial snapshot in non-empty history '
          'for session $sessionId.',
        );
        return 0;
      }
      
      // Create initial snapshot
      final checkpoint = Checkpoint(
        sessionId: sessionId,
        subtitleCollectionId: subtitleCollectionId,
        timestamp: DateTime.now(),
        operationType: 'snapshot',
        description: 'Initial state',
        parentCheckpointId: null,
        isActive: true,
        checkpointType: 'snapshot',
        deltas: [], // No deltas for snapshot
        snapshot: collection.lines.map((line) => CheckpointStateReducer.copyLine(line)).toList(),
        metadata: jsonEncode({'reason': 'initial', 'lineCount': collection.lines.length}),
      );
      
      final checkpointId = await _store.insertAsHead(
        sessionId: sessionId,
        expectedHeadId: null,
        checkpoint: checkpoint,
      );
      
      logInfo('Initial snapshot created: ID $checkpointId with ${collection.lines.length} lines');
      return checkpointId;
    } catch (e) {
      logWarning('Failed to create initial snapshot: $e');
      return 0; // Return 0 to indicate no snapshot was created
    }
  }
  
  /// Creates a new checkpoint for a given operation
  /// Automatically determines if this should be a snapshot or delta
  /// 
  /// Parameters:
  /// - [sessionId]: ID of the current editing session
  /// - [subtitleCollectionId]: ID of the subtitle collection being edited
  /// - [operationType]: Type of operation ('edit', 'delete', 'add', 'split', 'merge', 'effect', 'manual')
  /// - [description]: Human-readable description of the operation
  /// - [deltas]: List of changes made (before and after states)
  /// - [metadata]: Optional JSON metadata for operation-specific data
  /// - [forceSnapshot]: Force this to be a snapshot regardless of interval
  /// - [preOperationState]: Optional pre-operation state for snapshots (if null, current DB state is used)
  /// 
  /// Returns the ID of the created checkpoint
  Future<int> createCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required String operationType,
    required String description,
    required List<SubtitleLineDelta> deltas,
    Map<String, dynamic>? metadata,
    bool forceSnapshot = false,
    List<SubtitleLine>? preOperationState,
  }) async {
    try {
      // HEAD is a single movable reference. Existing descendants are never
      // deleted when the user creates a new change after restoring history;
      // the new checkpoint simply becomes another child of the restored HEAD.
      final sessionCheckpoints = await getCheckpointsForSession(sessionId);
      final currentHead = await _getCurrentHeadCheckpoint(sessionId);
      final parentCheckpointId = currentHead?.id;
      
      // Get checkpoint strategy and snapshot interval from preferences
      final checkpointStrategy = await getCheckpointStrategy();
      final snapshotInterval = await getSnapshotInterval();
      
      var checkpointsSinceSnapshot = 0;
      if (!forceSnapshot &&
          checkpointStrategy != 'snapshot' &&
          checkpointStrategy != 'delta') {
        checkpointsSinceSnapshot =
            CheckpointTimeline.countSinceNearestSnapshot(
          checkpoints: sessionCheckpoints,
          fromCheckpointId: parentCheckpointId,
        );
      }

      final shouldCreateSnapshot = CheckpointPolicy.shouldCreateSnapshot(
        forceSnapshot: forceSnapshot,
        strategy: checkpointStrategy,
        checkpointsSinceSnapshot: checkpointsSinceSnapshot,
        snapshotInterval: snapshotInterval,
      );
      
      // Get current subtitle collection state (for fallback if preOperationState not provided)
      final collection = await _store.getSubtitleCollection(subtitleCollectionId);
      if (collection == null) {
        throw Exception('Subtitle collection not found');
      }
      
      // Determine which state to use for snapshots
      List<SubtitleLine> stateToCapture;
      if (shouldCreateSnapshot) {
        if (preOperationState != null) {
          // Use provided pre-operation state (correct for snapshots)
          stateToCapture = preOperationState.map((line) => CheckpointStateReducer.copyLine(line)).toList();
        } else {
          // Fallback to current state (for manual checkpoints or when pre-state not available)
          stateToCapture = collection.lines.map((line) => CheckpointStateReducer.copyLine(line)).toList();
        }
      } else {
        stateToCapture = []; // Deltas don't need full snapshot
      }
      
      // Create checkpoint (snapshot or delta)
      final checkpoint = Checkpoint(
        sessionId: sessionId,
        subtitleCollectionId: subtitleCollectionId,
        timestamp: DateTime.now().toUtc(), // Store in UTC
        operationType: operationType,
        description: description,
        parentCheckpointId: parentCheckpointId,
        isActive: true,
        checkpointType: shouldCreateSnapshot ? 'snapshot' : 'delta',
        // Snapshot checkpoints still keep their operation delta. The snapshot
        // is the BEFORE state of that operation, so descendants need the delta
        // to advance past the snapshot boundary during reconstruction.
        deltas: deltas,
        snapshot: stateToCapture,
        metadata: metadata != null ? jsonEncode(metadata) : null,
      );
      
      final checkpointId = await _store.insertAsHead(
        sessionId: sessionId,
        expectedHeadId: currentHead?.id,
        checkpoint: checkpoint,
      );
      
      logInfo('Checkpoint created: $operationType - $description (ID: $checkpointId, Type: ${checkpoint.checkpointType})');
      
      // Auto-cleanup old checkpoints if needed
      await _autoCleanupCheckpoints(sessionId);
      
      return checkpointId;
    } catch (e) {
      logError('Failed to create checkpoint: $e');
      rethrow;
    }
  }
  
  /// Creates a checkpoint for a delete operation
  /// This should be called BEFORE the delete operation is performed
  Future<int> createDeleteCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine deletedLine,
    required int deletedIndex,
  }) async {
    // Get current state BEFORE delete operation
    final collection = await _store.getSubtitleCollection(subtitleCollectionId);
    if (collection == null) {
      throw Exception('Subtitle collection not found');
    }
    
    final delta = SubtitleLineDelta()
      ..changeType = 'delete'
      ..lineIndex = deletedIndex
      ..beforeState = CheckpointStateReducer.copyLine(deletedLine)
      ..afterState = null;
    
    return await createCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'delete',
      description: 'Deleted line ${deletedLine.index}',
      deltas: [delta],
      preOperationState: collection.lines, // Capture state BEFORE delete
    );
  }
  
  /// Creates a checkpoint for an add operation
  /// This should be called BEFORE the add operation is performed
  Future<int> createAddCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine addedLine,
    required int insertIndex,
    List<SubtitleLine>? preOperationState,
  }) async {
    // Get current state BEFORE add operation (if not provided)
    List<SubtitleLine>? stateBeforeAdd = preOperationState;
    if (stateBeforeAdd == null) {
      final collection = await _store.getSubtitleCollection(subtitleCollectionId);
      if (collection == null) {
        throw Exception('Subtitle collection not found');
      }
      stateBeforeAdd = collection.lines;
    }
    
    final delta = SubtitleLineDelta()
      ..changeType = 'add'
      ..lineIndex = insertIndex
      ..beforeState = null
      ..afterState = CheckpointStateReducer.copyLine(addedLine);
    
    return await createCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'add',
      description: 'Added line at position ${insertIndex + 1}',
      deltas: [delta],
      preOperationState: stateBeforeAdd, // Capture state BEFORE add
    );
  }
  
  /// Creates a checkpoint for an edit operation
  /// This should be called BEFORE the edit operation is performed
  Future<int> createEditCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine beforeLine,
    required SubtitleLine afterLine,
    List<SubtitleLine>? preOperationState,
  }) async {
    var stateBeforeEdit = preOperationState;
    if (stateBeforeEdit == null) {
      final collection =
          await _store.getSubtitleCollection(subtitleCollectionId);
      if (collection == null) {
        throw Exception('Subtitle collection not found');
      }
      stateBeforeEdit = CheckpointStateReducer.copyLines(collection.lines);
    }
    
    final delta = SubtitleLineDelta()
      ..changeType = 'modify'
      ..lineIndex = beforeLine.index - 1
      ..beforeState = CheckpointStateReducer.copyLine(beforeLine)
      ..afterState = CheckpointStateReducer.copyLine(afterLine);
    
    return await createCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'edit',
      description: 'Edited line ${beforeLine.index}',
      deltas: [delta],
      preOperationState: stateBeforeEdit,
    );
  }
  
  /// Creates a checkpoint for a split operation
  /// This should be called BEFORE the split operation is performed
  Future<int> createSplitCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine originalLine,
    required SubtitleLine firstPart,
    required SubtitleLine secondPart,
    List<SubtitleLine>? preOperationState,
  }) async {
    // Get current state BEFORE split operation (if not provided)
    List<SubtitleLine>? stateBeforeSplit = preOperationState;
    if (stateBeforeSplit == null) {
      final collection = await _store.getSubtitleCollection(subtitleCollectionId);
      if (collection == null) {
        throw Exception('Subtitle collection not found');
      }
      stateBeforeSplit = collection.lines;
    }
    
    final deltas = [
      SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = originalLine.index - 1
        ..beforeState = CheckpointStateReducer.copyLine(originalLine)
        ..afterState = CheckpointStateReducer.copyLine(firstPart),
      SubtitleLineDelta()
        ..changeType = 'add'
        ..lineIndex = originalLine.index
        ..beforeState = null
        ..afterState = CheckpointStateReducer.copyLine(secondPart),
    ];
    
    return await createCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'split',
      description: 'Split line ${originalLine.index}',
      deltas: deltas,
      preOperationState: stateBeforeSplit, // Capture state BEFORE split
    );
  }
  
  /// Creates a checkpoint for a merge operation
  /// This should be called BEFORE the merge operation is performed
  Future<int> createMergeCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine firstLine,
    required SubtitleLine secondLine,
    required SubtitleLine mergedLine,
    List<SubtitleLine>? preOperationState,
  }) async {
    // Get current state BEFORE merge operation (if not provided)
    List<SubtitleLine>? stateBeforeMerge = preOperationState;
    if (stateBeforeMerge == null) {
      final collection = await _store.getSubtitleCollection(subtitleCollectionId);
      if (collection == null) {
        throw Exception('Subtitle collection not found');
      }
      stateBeforeMerge = collection.lines;
    }
    
    final deltas = [
      SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = firstLine.index - 1
        ..beforeState = CheckpointStateReducer.copyLine(firstLine)
        ..afterState = CheckpointStateReducer.copyLine(mergedLine),
      SubtitleLineDelta()
        ..changeType = 'delete'
        ..lineIndex = secondLine.index - 1
        ..beforeState = CheckpointStateReducer.copyLine(secondLine)
        ..afterState = null,
    ];
    
    return await createCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'merge',
      description: 'Merged lines ${firstLine.index} and ${secondLine.index}',
      deltas: deltas,
      preOperationState: stateBeforeMerge, // Capture state BEFORE merge
    );
  }
  
  /// Creates a manual checkpoint (user-initiated)
  Future<int> createManualCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    String? customDescription,
  }) async {
    // Manual checkpoints don't store deltas - they're just markers
    return await createCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'manual',
      description: customDescription ?? 'Manual checkpoint',
      deltas: [],
    );
  }
  
  /// Moves HEAD to [checkpointId] and restores its exact historical state.
  ///
  /// Existing descendants are preserved as alternate history branches.
  /// Reconstruction fails closed if the parent chain or any delta is invalid.
  Future<bool> undoToCheckpoint({
    required int checkpointId,
    required int sessionId,
  }) async {
    try {
      final targetCheckpoint = await _store.getCheckpoint(checkpointId);
      if (targetCheckpoint == null) {
        logError('Checkpoint not found: $checkpointId');
        return false;
      }
      if (targetCheckpoint.sessionId != sessionId) {
        logError(
          'Checkpoint $checkpointId belongs to session '
          '${targetCheckpoint.sessionId}, not $sessionId',
        );
        return false;
      }

      final collection = await _store.getSubtitleCollection(
        targetCheckpoint.subtitleCollectionId,
      );
      if (collection == null) {
        logError('Subtitle collection not found');
        return false;
      }

      final nearestSnapshot = await _findNearestSnapshot(
        sessionId: sessionId,
        targetCheckpointId: checkpointId,
      );
      if (nearestSnapshot == null || nearestSnapshot.snapshot.isEmpty) {
        logError(
          'Cannot restore checkpoint $checkpointId: '
          'its ancestry has no valid snapshot.',
        );
        return false;
      }

      final restoredLines =
          CheckpointStateReducer.copyLines(nearestSnapshot.snapshot);

      // Legacy checkpoints represent the state BEFORE their operation.
      // When the snapshot is an ancestor rather than the target, its own
      // operation must be replayed before later deltas.
      if (nearestSnapshot.id != checkpointId &&
          nearestSnapshot.deltas.isNotEmpty) {
        CheckpointStateReducer.applyDeltasStrictInPlace(
          restoredLines,
          nearestSnapshot.deltas,
        );
      }

      if (nearestSnapshot.id != checkpointId) {
        final deltasToApply = await _getDeltaCheckpointsBetween(
          sessionId: sessionId,
          fromSnapshotId: nearestSnapshot.id,
          toCheckpointId: checkpointId,
          excludeTarget: true,
        );

        for (final checkpoint in deltasToApply) {
          CheckpointStateReducer.applyDeltasStrictInPlace(
            restoredLines,
            checkpoint.deltas,
          );
        }
      }

      collection.lines = restoredLines;
      CheckpointStateReducer.reindexExactOrder(collection);

      await _store.restoreCollectionAndActivateOnly(
        sessionId: sessionId,
        targetCheckpoint: targetCheckpoint,
        collection: collection,
      );

      logInfo(
        'Moved checkpoint HEAD to $checkpointId without deleting descendants',
      );
      return true;
    } on CheckpointIntegrityException catch (error) {
      logError('Checkpoint integrity validation failed: $error');
      return false;
    } on StateError catch (error) {
      logError('Checkpoint graph validation failed: $error');
      return false;
    } catch (error) {
      logError('Failed to restore to checkpoint: $error');
      return false;
    }
  }

  /// Redoes to a specific checkpoint (same as undo, just different terminology)
  /// Returns true if successful, false otherwise
  Future<bool> redoToCheckpoint({
    required int checkpointId,
    required int sessionId,
  }) async {
    // Redo is the same as undo in our tree-based system
    return await undoToCheckpoint(
      checkpointId: checkpointId,
      sessionId: sessionId,
    );
  }
  
  /// Gets all checkpoints for a session
  Future<List<Checkpoint>> getCheckpointsForSession(int sessionId) {
    return _store.getCheckpointsForSession(sessionId);
  }
  
  /// Deletes all checkpoints for a session (cleanup when session is deleted)
  Future<void> deleteCheckpointsForSession(int sessionId) async {
    await _store.deleteCheckpointsForSession(sessionId);
    logInfo('Deleted all checkpoints for session: $sessionId');
  }
  
  // ==================== Private Helper Methods ====================
  
  /// Finds the nearest snapshot at or before a target checkpoint
  /// Returns null if no snapshot found
  Future<Checkpoint?> _findNearestSnapshot({
    required int sessionId,
    required int targetCheckpointId,
  }) async {
    final checkpoints = await getCheckpointsForSession(sessionId);
    final snapshot = CheckpointTimeline.findNearestSnapshot(
      checkpoints: checkpoints,
      targetCheckpointId: targetCheckpointId,
    );

    if (snapshot == null) {
      logError('No snapshot found in path to checkpoint $targetCheckpointId');
    }
    return snapshot;
  }

  /// Gets all delta checkpoints between a snapshot and target checkpoint
  /// Returns checkpoints in chronological order (oldest first)
  /// 
  /// If [excludeTarget] is true, the target checkpoint itself is NOT included
  /// This is used when restoring to get the BEFORE state of a checkpoint
  Future<List<Checkpoint>> _getDeltaCheckpointsBetween({
    required int sessionId,
    required int fromSnapshotId,
    required int toCheckpointId,
    bool excludeTarget = false,
  }) async {
    final checkpoints = await getCheckpointsForSession(sessionId);
    return CheckpointTimeline.deltaPath(
      checkpoints: checkpoints,
      fromSnapshotId: fromSnapshotId,
      toCheckpointId: toCheckpointId,
      excludeTarget: excludeTarget,
    );
  }

  /// Gets the current head checkpoint (most recent active)
  Future<Checkpoint?> _getCurrentHeadCheckpoint(int sessionId) {
    return _store.getCurrentHeadCheckpoint(sessionId);
  }
  
  
  /// Auto-cleanup old checkpoints to prevent database bloat
  /// Preserves initial snapshot and manual checkpoints
  /// Uses limit-based cleanup only (no age-based cleanup)
  Future<void> _autoCleanupCheckpoints(int sessionId) async {
    try {
      final allCheckpoints = await getCheckpointsForSession(sessionId);
      final maxCheckpoints = await getMaxCheckpoints();
      
      final head = await _getCurrentHeadCheckpoint(sessionId);
      final toDelete = CheckpointPolicy.cleanupCandidates(
        checkpoints: allCheckpoints,
        maxCheckpoints: maxCheckpoints,
        headCheckpointId: head?.id,
      );

      if (toDelete.isNotEmpty) {
        await _store.deleteCheckpointIds(
          toDelete.map((checkpoint) => checkpoint.id),
        );

        logInfo(
          'Cleaned up ${toDelete.length} old checkpoints '
          '(limit: $maxCheckpoints, preserved initial snapshot and manual checkpoints)',
        );
      }
    } catch (e) {
      logError('Failed to cleanup checkpoints: $e');
    }
  }
}
