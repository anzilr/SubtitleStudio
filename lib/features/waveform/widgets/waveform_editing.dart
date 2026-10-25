part of 'waveform_widget.dart';

extension _WaveformEditing on WaveformWidgetState {
  /// Keep the dragged handle anchored to its opposite edge; moving a whole
  /// overlay must preserve its duration even when stopped by another cue.
  (Duration, Duration) _constrainTimeRange(
    Duration startTime,
    Duration endTime,
    WaveformReady state, {
    required WaveformTimeDrag drag,
    int? excludeIndex,
    Duration? originalStart,
  }) => WaveformTimeRangePlanner.constrain(
    start: startTime,
    end: endTime,
    playhead: state.playbackPosition,
    neighbors: [
      for (var i = 0; i < _currentSubtitles.length; i++)
        if (i != excludeIndex)
          WaveformTimeBoundary(
            parseTimeString(_currentSubtitles[i].startTime),
            parseTimeString(_currentSubtitles[i].endTime),
          ),
    ],
    drag: drag,
    allowOverlap: state.allowOverlap,
    magnetSnapEnabled: state.magnetSnapEnabled,
    originalStart: originalStart,
  );

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
    if (widget.onApplyTimeEdit == null && widget.subtitleCollectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot update: No subtitle collection ID',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
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
        SnackBar(
          content: Text(
            'Start time must be before end time',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
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
    
    // Update subtitle and history atomically.
    try {
      final apply = widget.onApplyTimeEdit;
      final bool success;
      if (apply != null) {
        // Native Studio Dock commits against its current guarded snapshot.
        // This also lets the host resolve an unsaved inspector draft first.
        success = await apply(
          subtitle.index, afterSubtitle.startTime, afterSubtitle.endTime);
      } else {
        final repository = ref.read(waveformSubtitleRepositoryProvider);
        success = widget.sessionId != null
            ? await repository.updateLinesWithHistory(
                subtitleCollectionId: widget.subtitleCollectionId!,
                sessionId: widget.sessionId!,
                updatedLines: [afterSubtitle],
                expectedLines: [subtitle],
              )
            : await repository.updateLines(
                widget.subtitleCollectionId!,
                [afterSubtitle],
              );
      }
      
      if (!success) {
        throw Exception('Failed to update subtitle in database');
      }
      
      // Only update cached timing after the database has accepted the edit.
      // A failed or stale save must leave the displayed cue untouched.
      subtitle.startTime = afterSubtitle.startTime;
      subtitle.endTime = afterSubtitle.endTime;
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
          SnackBar(
            content: Text(
              'Time updated successfully',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update subtitle time. Please try again.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
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
        SnackBar(
          content: Text(
            'Please drag to select start and end times',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
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
