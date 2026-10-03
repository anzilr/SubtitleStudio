part of 'waveform_widget.dart';

extension _WaveformEditing on WaveformWidgetState {
  Duration _applyMagnetSnap(Duration time, WaveformReady state, {bool isStart = true, int? excludeIndex}) {
    if (!state.magnetSnapEnabled) return time;
    
    const snapThreshold = Duration(milliseconds: 150); // 150ms snap threshold (reverted to original)
    const minGap = Duration(milliseconds: 25); // 0.025s minimum gap between subtitles after snapping
    Duration closestTime = time;
    Duration minDistance = snapThreshold + const Duration(milliseconds: 1); // Set slightly higher to allow equal distance snaps
    bool snappedToPlayhead = false;
    
    // Check snap to playhead first (priority)
    final playheadTime = state.playbackPosition;
    final playheadDistance = (time - playheadTime).abs();
    if (playheadDistance <= snapThreshold) {
      closestTime = playheadTime;
      minDistance = playheadDistance;
      snappedToPlayhead = true;
    }
    
    // Check snap to subtitle boundaries with minimum gap enforcement
    // Only override playhead if subtitle boundary is significantly closer (at least 20ms closer)
    const playheadPriorityMargin = Duration(milliseconds: 20);
    for (int i = 0; i < _currentSubtitles.length; i++) {
      // Skip the subtitle being edited
      if (excludeIndex != null && i == excludeIndex) continue;
      
      final subtitle = _currentSubtitles[i];
      final subStart = parseTimeString(subtitle.startTime);
      final subEnd = parseTimeString(subtitle.endTime);
      
      // Check distance to start
      final startDistance = (time - subStart).abs();
      final requiredDistance = snappedToPlayhead ? minDistance - playheadPriorityMargin : minDistance;
      if (startDistance < requiredDistance) {
        // Apply minimum gap: if we're snapping start time to a subtitle boundary,
        // snap to end + minGap; if snapping end time, snap to start - minGap
        if (isStart) {
          closestTime = subEnd + minGap;
        } else {
          closestTime = subStart - minGap;
        }
        minDistance = startDistance;
        snappedToPlayhead = false;
      }
      
      // Check distance to end
      final endDistance = (time - subEnd).abs();
      final requiredDistanceEnd = snappedToPlayhead ? minDistance - playheadPriorityMargin : minDistance;
      if (endDistance < requiredDistanceEnd) {
        // Apply minimum gap: if we're snapping start time to a subtitle boundary,
        // snap to end + minGap; if snapping end time, snap to start - minGap
        if (isStart) {
          closestTime = subEnd + minGap;
        } else {
          closestTime = subStart - minGap;
        }
        minDistance = endDistance;
        snappedToPlayhead = false;
      }
    }
    
    return closestTime;
  }

  /// Constrain time range to avoid overlap (if allowOverlap is false)
  /// Returns adjusted start and end times
  (Duration, Duration) _constrainTimeRange(
    Duration startTime, 
    Duration endTime, 
    WaveformReady state, 
    {int? excludeIndex, 
    bool isMovingOverlay = false}
  ) {
    if (state.allowOverlap) {
      // Apply magnet snap if enabled
      final snappedStart = _applyMagnetSnap(startTime, state, isStart: true, excludeIndex: excludeIndex);
      final snappedEnd = _applyMagnetSnap(endTime, state, isStart: false, excludeIndex: excludeIndex);
      return (snappedStart, snappedEnd);
    }
    
    Duration constrainedStart = startTime;
    Duration constrainedEnd = endTime;
    
    // Find the closest boundaries that would cause overlap
    Duration? maxAllowedStart;
    Duration? minAllowedEnd;
    
    for (int i = 0; i < _currentSubtitles.length; i++) {
      // Skip the subtitle being edited
      if (excludeIndex != null && i == excludeIndex) continue;
      
      final subtitle = _currentSubtitles[i];
      final subStart = parseTimeString(subtitle.startTime);
      final subEnd = parseTimeString(subtitle.endTime);
      
      // Check if this subtitle would overlap with our range
      if (startTime < subEnd && endTime > subStart) {
        // There's an overlap - constrain the range
        if (isMovingOverlay) {
          // When moving entire overlay, stop at the nearest boundary
          if (startTime < subStart && endTime > subStart) {
            // Moving forward into a subtitle - stop at its start
            constrainedStart = startTime;
            constrainedEnd = subStart;
            return (constrainedStart, constrainedEnd);
          } else if (startTime < subEnd && endTime > subEnd) {
            // Moving backward into a subtitle - stop at its end
            constrainedStart = subEnd;
            constrainedEnd = endTime;
            return (constrainedStart, constrainedEnd);
          }
        } else {
          // When adjusting individual boundaries
          if (subEnd <= startTime) {
            // Subtitle is before our range - update max start
            maxAllowedStart = maxAllowedStart == null ? subEnd : (subEnd > maxAllowedStart ? subEnd : maxAllowedStart);
          }
          if (subStart >= endTime) {
            // Subtitle is after our range - update min end
            minAllowedEnd = minAllowedEnd == null ? subStart : (subStart < minAllowedEnd ? subStart : minAllowedEnd);
          } else if (subStart > startTime && subStart < endTime) {
            // Subtitle starts within our range - constrain end
            minAllowedEnd = subStart;
          } else if (subEnd > startTime && subEnd < endTime) {
            // Subtitle ends within our range - constrain start
            maxAllowedStart = subEnd;
          }
        }
      }
    }
    
    // Apply constraints
    if (maxAllowedStart != null && constrainedStart < maxAllowedStart) {
      constrainedStart = maxAllowedStart;
    }
    if (minAllowedEnd != null && constrainedEnd > minAllowedEnd) {
      constrainedEnd = minAllowedEnd;
    }
    
    // Ensure start < end
    if (constrainedStart >= constrainedEnd) {
      // If they cross, keep the original end and adjust start
      constrainedStart = constrainedEnd - const Duration(milliseconds: 100);
    }
    
    // Apply magnet snap to constrained values
    constrainedStart = _applyMagnetSnap(constrainedStart, state, isStart: true, excludeIndex: excludeIndex);
    constrainedEnd = _applyMagnetSnap(constrainedEnd, state, isStart: false, excludeIndex: excludeIndex);
    
    return (constrainedStart, constrainedEnd);
  }

  /// Format Duration to SRT timecode string (HH:mm:ss,SSS)
  String _formatDurationToSRT(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  /// Apply time changes to database
  Future<void> _applyTimeChanges(WaveformReady state) async {
    if (!state.isEditMode || state.editingSubtitleIndex == null) return;
    if (widget.subtitleCollectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot update: No subtitle collection ID',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFFD32F2F),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final subtitleIndex = state.editingSubtitleIndex!;
    if (subtitleIndex < 0 || subtitleIndex >= _currentSubtitles.length) return;
    
    final subtitle = _currentSubtitles[subtitleIndex];
    final currentStartTime = parseTimeString(subtitle.startTime);
    final currentEndTime = parseTimeString(subtitle.endTime);
    final newStartTime = state.tempStartTime ?? currentStartTime;
    final newEndTime = state.tempEndTime ?? currentEndTime;
    
    // Validate times
    if (newStartTime >= newEndTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Start time must be before end time',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFFD32F2F),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Create a copy of the subtitle with BEFORE state for checkpoint
    final beforeSubtitle = SubtitleLine()
      ..index = subtitle.index
      ..startTime = subtitle.startTime
      ..endTime = subtitle.endTime
      ..original = subtitle.original
      ..edited = subtitle.edited
      ..marked = subtitle.marked
      ..comment = subtitle.comment
      ..resolved = subtitle.resolved;
    
    // Update subtitle with new times (AFTER state)
    final afterSubtitle = SubtitleLine()
      ..index = subtitle.index
      ..startTime = _formatDurationToSRT(newStartTime)
      ..endTime = _formatDurationToSRT(newEndTime)
      ..original = subtitle.original
      ..edited = subtitle.edited
      ..marked = subtitle.marked
      ..comment = subtitle.comment
      ..resolved = subtitle.resolved;
    
    // Update subtitle in database
    try {
      // Create checkpoint BEFORE updating (if sessionId is provided)
      if (widget.sessionId != null) {
        await ref.read(checkpointRepositoryProvider).createEditCheckpoint(
          sessionId: widget.sessionId!,
          subtitleCollectionId: widget.subtitleCollectionId!,
          beforeLine: beforeSubtitle,
          afterLine: afterSubtitle,
        );
      }
      
      // Apply changes to the actual subtitle
      subtitle.startTime = afterSubtitle.startTime;
      subtitle.endTime = afterSubtitle.endTime;
      
      final success = await ref
          .read(waveformSubtitleRepositoryProvider)
          .updateLines(
            widget.subtitleCollectionId!,
            [subtitle],
          );
      
      if (!success) {
        throw Exception('Failed to update subtitle in database');
      }
      
      // Update internal cache
      _mutateLocalState(() {
        _currentSubtitles[subtitleIndex] = subtitle;
      });
      
      // Notify parent to refresh subtitle list and video player
      widget.onSubtitlesUpdated?.call();
      
      // Exit edit mode
      if (mounted) {
        ref.read(waveformControllerProvider.notifier).dispatch(const ExitTimeEditMode());
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Time updated successfully',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF323232),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating time: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Confirm add line and call callback with selected times
  void _confirmAddLine(WaveformReady state) {
    // Validate that both start and end times are set
    if (state.addLineStartTime == null || state.addLineEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please drag to select start and end times',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFFD32F2F),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Exit add line mode
    ref.read(waveformControllerProvider.notifier).dispatch(const ExitAddLineMode());
    
    // Call the callback with selected times
    widget.onAddLineConfirmed?.call(
      state.addLineStartTime!,
      state.addLineEndTime!,
    );
  }

  /// Trigger add line mode from toolbar button
  void _triggerAddLineMode(WaveformReady state) {
    // Use viewport center time (where user is currently looking)
    final startTime = _getViewportCenterTime(state);
    final endTime = startTime + const Duration(seconds: 2);
    
    ref.read(waveformControllerProvider.notifier).dispatch(const EnterAddLineMode());
    ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineStartTime(startTime));
    ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineEndTime(endTime));
  }
}
