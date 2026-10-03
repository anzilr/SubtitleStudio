part of 'waveform_widget.dart';

extension _WaveformInteractions on WaveformWidgetState {
  void _handleScroll(PointerScrollEvent event, WaveformReady state) {
    // Handle mouse wheel scroll
    if (event.scrollDelta.dy != 0) {
      // Horizontal scroll with mouse wheel
      final newScrollPosition =
          state.scrollPosition + event.scrollDelta.dy * 0.5;
      ref.read(waveformControllerProvider.notifier).dispatch(
            ScrollSeekToTime(newScrollPosition),
          );
      
      // Calculate center viewport time and seek video
      final centerPixel = newScrollPosition + state.viewportWidth / 2;
      final centerTime = state.pixelToTime(centerPixel);
      widget.onSeek?.call(centerTime);
    }
  }

  // Waveform drag-scrolling handlers (also handles bar dragging and overlay moving)
  void _handleWaveformPanStart(DragStartDetails details, WaveformReady state) {
    final panX = details.localPosition.dx;
    const barTolerance = 20.0;
    
    // Check if we're in edit mode and starting pan near a draggable bar
    if (state.isEditMode && state.editingSubtitleIndex != null) {
      final subtitle = _currentSubtitles[state.editingSubtitleIndex!];
      final startTime = state.tempStartTime ?? parseTimeString(subtitle.startTime);
      final endTime = state.tempEndTime ?? parseTimeString(subtitle.endTime);
      
      final startPixel = state.timeToPixel(startTime) - state.scrollPosition;
      final endPixel = state.timeToPixel(endTime) - state.scrollPosition;
      
      // If pan starts near a bar, enable bar dragging mode
      if ((panX - startPixel).abs() < barTolerance) {
        _mutateLocalState(() => _isDraggingStartBar = true);
        return;
      } else if ((panX - endPixel).abs() < barTolerance) {
        _mutateLocalState(() => _isDraggingEndBar = true);
        return;
      }
      
      // Check if pan starts inside the overlay (for moving entire overlay)
      if (panX >= startPixel && panX <= endPixel) {
        _mutateLocalState(() {
          _isMovingEditOverlay = true;
          _overlayDragStartX = panX;
          _overlayDragOriginalStart = startTime;
          _overlayDragOriginalEnd = endTime;
        });
        return;
      }
    }
    
    // Check if we're in add line mode and starting pan near a draggable bar
    if (state.isAddLineMode && state.addLineStartTime != null && state.addLineEndTime != null) {
      final startPixel = state.timeToPixel(state.addLineStartTime!) - state.scrollPosition;
      final endPixel = state.timeToPixel(state.addLineEndTime!) - state.scrollPosition;
      
      // If pan starts near a bar, enable bar dragging mode
      if ((panX - startPixel).abs() < barTolerance) {
        _mutateLocalState(() => _isDraggingAddLineStartBar = true);
        return;
      } else if ((panX - endPixel).abs() < barTolerance) {
        _mutateLocalState(() => _isDraggingAddLineEndBar = true);
        return;
      }
      
      // Check if pan starts inside the overlay (for moving entire overlay)
      if (panX >= startPixel && panX <= endPixel) {
        _mutateLocalState(() {
          _isMovingAddLineOverlay = true;
          _overlayDragStartX = panX;
          _overlayDragOriginalStart = state.addLineStartTime;
          _overlayDragOriginalEnd = state.addLineEndTime;
        });
        return;
      }
    }
    
    // Normal waveform scrolling
    _lastScrollDragPosition = details.globalPosition.dx;
  }

  void _handleWaveformPanUpdate(DragUpdateDetails details, WaveformReady state) {
    final tapX = details.localPosition.dx;
    final pixelPosition = state.scrollPosition + tapX;
    final newTime = state.pixelToTime(pixelPosition);
    
    // Handle moving edit overlay
    if (_isMovingEditOverlay && _overlayDragStartX != null && _overlayDragOriginalStart != null && _overlayDragOriginalEnd != null) {
      final dragDelta = tapX - _overlayDragStartX!;
      final timeDelta = state.pixelToTime(state.scrollPosition + dragDelta) - state.pixelToTime(state.scrollPosition);
      
      var newStart = _overlayDragOriginalStart! + timeDelta;
      var newEnd = _overlayDragOriginalEnd! + timeDelta;
      
      // Apply overlap prevention and magnet snap
      final constrained = _constrainTimeRange(
        newStart, 
        newEnd, 
        state, 
        excludeIndex: state.editingSubtitleIndex,
        isMovingOverlay: true,
      );
      newStart = constrained.$1;
      newEnd = constrained.$2;
      
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateTempStartTime(newStart));
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateTempEndTime(newEnd));
      return;
    }
    
    // Handle moving add line overlay
    if (_isMovingAddLineOverlay && _overlayDragStartX != null && _overlayDragOriginalStart != null && _overlayDragOriginalEnd != null) {
      final dragDelta = tapX - _overlayDragStartX!;
      final timeDelta = state.pixelToTime(state.scrollPosition + dragDelta) - state.pixelToTime(state.scrollPosition);
      
      var newStart = _overlayDragOriginalStart! + timeDelta;
      var newEnd = _overlayDragOriginalEnd! + timeDelta;
      
      // Apply overlap prevention and magnet snap
      final constrained = _constrainTimeRange(
        newStart, 
        newEnd, 
        state,
        isMovingOverlay: true,
      );
      newStart = constrained.$1;
      newEnd = constrained.$2;
      
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineStartTime(newStart));
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineEndTime(newEnd));
      return;
    }
    
    // Handle edit mode bar dragging
    if (_isDraggingStartBar) {
      var adjustedTime = newTime;
      
      // Get current end time
      final currentEnd = state.tempEndTime ?? (state.editingSubtitleIndex != null 
          ? parseTimeString(_currentSubtitles[state.editingSubtitleIndex!].endTime)
          : Duration.zero);
      
      // Apply overlap prevention and magnet snap
      final constrained = _constrainTimeRange(
        adjustedTime, 
        currentEnd, 
        state,
        excludeIndex: state.editingSubtitleIndex,
      );
      adjustedTime = constrained.$1;
      
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateTempStartTime(adjustedTime));
      return;
    } else if (_isDraggingEndBar) {
      var adjustedTime = newTime;
      
      // Get current start time
      final currentStart = state.tempStartTime ?? (state.editingSubtitleIndex != null 
          ? parseTimeString(_currentSubtitles[state.editingSubtitleIndex!].startTime)
          : Duration.zero);
      
      // Apply overlap prevention and magnet snap
      final constrained = _constrainTimeRange(
        currentStart, 
        adjustedTime, 
        state,
        excludeIndex: state.editingSubtitleIndex,
      );
      adjustedTime = constrained.$2;
      
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateTempEndTime(adjustedTime));
      return;
    }
    
    // Handle add line mode bar dragging
    if (_isDraggingAddLineStartBar) {
      var adjustedTime = newTime;
      
      // Get current end time
      final currentEnd = state.addLineEndTime ?? newTime + const Duration(seconds: 2);
      
      // Apply overlap prevention and magnet snap
      final constrained = _constrainTimeRange(
        adjustedTime, 
        currentEnd, 
        state,
      );
      adjustedTime = constrained.$1;
      
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineStartTime(adjustedTime));
      return;
    } else if (_isDraggingAddLineEndBar) {
      var adjustedTime = newTime;
      
      // Get current start time
      final currentStart = state.addLineStartTime ?? Duration.zero;
      
      // Apply overlap prevention and magnet snap
      final constrained = _constrainTimeRange(
        currentStart, 
        adjustedTime, 
        state,
      );
      adjustedTime = constrained.$2;
      
      ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineEndTime(adjustedTime));
      return;
    }
    
    // Normal waveform scrolling
    if (_lastScrollDragPosition == null) return;
    
    final delta = details.globalPosition.dx - _lastScrollDragPosition!;
    final newScrollPosition = state.scrollPosition - delta;
    
    // Update scroll position and seek video to center viewport time
    ref.read(waveformControllerProvider.notifier).dispatch(
      ScrollSeekToTime(newScrollPosition),
    );
    
    // Calculate center viewport time and seek video
    final centerPixel = newScrollPosition + state.viewportWidth / 2;
    final centerTime = state.pixelToTime(centerPixel);
    widget.onSeek?.call(centerTime);

    _lastScrollDragPosition = details.globalPosition.dx;
  }

  void _handleWaveformPanEnd() {
    // Reset all dragging flags
    if (_isMovingEditOverlay || _isMovingAddLineOverlay || 
        _isDraggingStartBar || _isDraggingEndBar ||
        _isDraggingAddLineStartBar || _isDraggingAddLineEndBar) {
      _mutateLocalState(() {
        _isMovingEditOverlay = false;
        _isMovingAddLineOverlay = false;
        _isDraggingStartBar = false;
        _isDraggingEndBar = false;
        _isDraggingAddLineStartBar = false;
        _isDraggingAddLineEndBar = false;
        _overlayDragStartX = null;
        _overlayDragOriginalStart = null;
        _overlayDragOriginalEnd = null;
      });
      return;
    }
    
    // Normal waveform scrolling cleanup
    _lastScrollDragPosition = null;
  }

  // Handle mouse click (for double-click detection to seek/highlight/add line)
  void _handleMouseClick(PointerDownEvent event, WaveformReady state) {
    final now = DateTime.now();
    final position = event.localPosition;
    
    // Check if click is on playhead
    if (position.dy <= 12) {
      final playheadX = _getPlayheadXPosition(state);
      
      if ((position.dx - playheadX).abs() <= 16) {
        // Click on playhead - check for double-click
        if (WaveformWidgetState._staticLastMouseClickTime != null &&
            WaveformWidgetState._staticLastMouseClickPosition != null &&
            now.difference(WaveformWidgetState._staticLastMouseClickTime!) < const Duration(milliseconds: 500) &&
            (position - WaveformWidgetState._staticLastMouseClickPosition!).distance < 20) {
          // Double-click on playhead - enter add line mode with 2-second default duration
          // Use viewport center time (where playhead visually appears)
          final startTime = _getViewportCenterTime(state);
          final endTime = startTime + const Duration(seconds: 2);
          
          ref.read(waveformControllerProvider.notifier).dispatch(const EnterAddLineMode());
          ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineStartTime(startTime));
          ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineEndTime(endTime));
          WaveformWidgetState._staticLastMouseClickTime = null;
          WaveformWidgetState._staticLastMouseClickPosition = null;
          WaveformWidgetState._staticLastMouseClickSubtitleIndex = null;
          return;
        } else {
          // Single click - remember for potential double-click
          WaveformWidgetState._staticLastMouseClickTime = now;
          WaveformWidgetState._staticLastMouseClickPosition = position;
          WaveformWidgetState._staticLastMouseClickSubtitleIndex = null;
          return;
        }
      }
    }
    
    // Regular mouse click logic
    final subtitleIndex = _getSubtitleAtPosition(position, state);
    
    // Check for double-click (within 500ms, at similar position, and on same subtitle)
    if (WaveformWidgetState._staticLastMouseClickTime != null &&
        WaveformWidgetState._staticLastMouseClickPosition != null &&
        now.difference(WaveformWidgetState._staticLastMouseClickTime!) < const Duration(milliseconds: 500) &&
        (position - WaveformWidgetState._staticLastMouseClickPosition!).distance < 20 &&
        subtitleIndex == WaveformWidgetState._staticLastMouseClickSubtitleIndex) {
      // Double-click detected
      
      if (subtitleIndex != null) {
        // Double-click on subtitle - seek and highlight
        final subtitle = _currentSubtitles[subtitleIndex];
        final startTime = parseTimeString(subtitle.startTime);
        widget.onSeek?.call(startTime);
        ref.read(waveformControllerProvider.notifier).dispatch(SeekToTime(startTime));
        // Pass 1-based index (subtitle.index) for highlighting
        widget.onSubtitleHighlight?.call(subtitle.index);
      } else {
        // Double-click on waveform
        if (state.isEditMode) {
          // Exit edit mode if we're in it
          ref.read(waveformControllerProvider.notifier).dispatch(const ExitTimeEditMode());
        } else if (state.isAddLineMode) {
          // Exit add line mode if we're in it
          ref.read(waveformControllerProvider.notifier).dispatch(const ExitAddLineMode());
        } else {
          // Seek to position if not in edit mode
          _seekToPosition(position, state);
        }
      }
      
      // Reset for next potential double-click
      WaveformWidgetState._staticLastMouseClickTime = null;
      WaveformWidgetState._staticLastMouseClickPosition = null;
      WaveformWidgetState._staticLastMouseClickSubtitleIndex = null;
    } else {
      // Single click - just remember for potential double-click
      WaveformWidgetState._staticLastMouseClickTime = now;
      WaveformWidgetState._staticLastMouseClickPosition = position;
      WaveformWidgetState._staticLastMouseClickSubtitleIndex = subtitleIndex;
    }
  }

  // Handle mouse right-click (for entering edit mode on subtitle)
  void _handleMouseRightClick(PointerDownEvent event, WaveformReady state) {
    final position = event.localPosition;
    final subtitleIndex = _getSubtitleAtPosition(position, state);
    
    if (subtitleIndex != null) {
      // Right-click on subtitle - enter edit mode
      ref.read(waveformControllerProvider.notifier).dispatch(EnterTimeEditMode(subtitleIndex));
    }
  }

  // Handle tap up - GestureDetector fires this only for actual taps (not after pans)
  void _handleTapUp(TapUpDetails details, WaveformReady state) {
    // Skip if this is a mouse click (handled by _handleMouseClick)
    // GestureDetector will fire onTapUp for both touch and mouse
    if (details.kind == PointerDeviceKind.mouse) {
      return;
    }
    
    final position = details.localPosition;
    final subtitleIndex = _getSubtitleAtPosition(position, state);
    
    if (subtitleIndex != null) {
      // Tapped on a subtitle box - check for double tap
      _handleSubtitleTapAtPosition(position, state, subtitleIndex);
    } else {
      // Tapped on empty area (waveform) - check for double tap
      _handleWaveformTapAtPosition(position, state);
    }
  }

  // Handle long press start - enter edit mode on subtitle or add line mode on playhead
  void _handleLongPressStart(LongPressStartDetails details, WaveformReady state) {
    final position = details.localPosition;
    
    // Check if long press is on the playhead arrow area (top 12 pixels)
    if (position.dy <= 12) {
      final playheadX = _getPlayheadXPosition(state);
      
      // Check if long press is within 16 pixels of the playhead
      if ((position.dx - playheadX).abs() <= 16) {
        // Long press on playhead - enter add line mode with 2-second default duration
        // Use viewport center time (where playhead visually appears)
        final startTime = _getViewportCenterTime(state);
        final endTime = startTime + const Duration(seconds: 2);
        
        ref.read(waveformControllerProvider.notifier).dispatch(const EnterAddLineMode());
        ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineStartTime(startTime));
        ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineEndTime(endTime));
        return;
      }
    }
    
    // Check if long press is on a subtitle
    final subtitleIndex = _getSubtitleAtPosition(position, state);
    
    if (subtitleIndex != null) {
      // Long press on subtitle - enter edit mode
      ref.read(waveformControllerProvider.notifier).dispatch(EnterTimeEditMode(subtitleIndex));
    }
  }

  // Handle long press move - not used in new implementation
  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details, WaveformReady state) {
    // Empty - we handle dragging in pan handlers
  }

  // Handle long press end - not used in new implementation
  void _handleLongPressEnd(LongPressEndDetails details, WaveformReady state) {
    // Empty - we handle cleanup in pan end
  }

  // Get playhead X position on screen
  double _getPlayheadXPosition(WaveformReady state) {
    final pixelsPerSec = state.buffer.sampleRate / state.samplesPerPixel;
    final playbackPixel = (state.playbackPosition.inMilliseconds / 1000.0) * pixelsPerSec;
    final centerPosition = state.viewportWidth / 2;
    final totalWidth = state.currentZoomLevel.pixelCount.toDouble();
    
    double playheadX;
    if (playbackPixel <= centerPosition) {
      playheadX = playbackPixel - state.scrollPosition;
    } else if (playbackPixel >= totalWidth - centerPosition) {
      playheadX = playbackPixel - state.scrollPosition;
    } else {
      playheadX = centerPosition;
    }
    return playheadX.clamp(0.0, state.viewportWidth);
  }

  // Get viewport center time
  Duration _getViewportCenterTime(WaveformReady state) {
    final centerPixel = state.scrollPosition + state.viewportWidth / 2;
    final centerSample = (centerPixel * state.samplesPerPixel).round();
    final centerMilliseconds = (centerSample * 1000 / state.buffer.sampleRate).round();
    return Duration(milliseconds: centerMilliseconds);
  }

  // Handle tap on waveform (empty area) - double tap to seek or exit edit mode or enter add line mode on playhead
  void _handleWaveformTapAtPosition(Offset localPosition, WaveformReady state) {
    final now = DateTime.now();
    
    // Check if tap is on playhead
    if (localPosition.dy <= 12) {
      final playheadX = _getPlayheadXPosition(state);
      
      if ((localPosition.dx - playheadX).abs() <= 16) {
        // Tap on playhead - check for double tap
        if (_lastPlayheadTapTime != null &&
            now.difference(_lastPlayheadTapTime!) < WaveformWidgetState._doubleTapDuration) {
          // Double tap on playhead - enter add line mode with 2-second default duration
          // Use viewport center time (where playhead visually appears)
          final startTime = _getViewportCenterTime(state);
          final endTime = startTime + const Duration(seconds: 2);
          
          ref.read(waveformControllerProvider.notifier).dispatch(const EnterAddLineMode());
          ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineStartTime(startTime));
          ref.read(waveformControllerProvider.notifier).dispatch(UpdateAddLineEndTime(endTime));
          _lastPlayheadTapTime = null;
          return;
        } else {
          // Single tap - remember for potential double tap
          _lastPlayheadTapTime = now;
          return;
        }
      }
    }
    
    // Regular waveform double tap logic
    if (_lastWaveformTapTime != null &&
        now.difference(_lastWaveformTapTime!) < WaveformWidgetState._doubleTapDuration) {
      // Double tap on waveform
      if (state.isEditMode) {
        // Exit edit mode if we're in it
        ref.read(waveformControllerProvider.notifier).dispatch(const ExitTimeEditMode());
      } else if (state.isAddLineMode) {
        // Exit add line mode if we're in it
        ref.read(waveformControllerProvider.notifier).dispatch(const ExitAddLineMode());
      } else {
        // Seek to position if not in edit mode
        _seekToPosition(localPosition, state);
      }
      _lastWaveformTapTime = null;
    } else {
      // Single tap - just remember for potential double tap
      _lastWaveformTapTime = now;
    }
  }

  /// Format the display time based on playback position or viewport center
  String _formatDisplayTime(WaveformReady state) {
    // Always show viewport center time (where user is looking)
    final centerPixel = state.scrollPosition + state.viewportWidth / 2;
    final centerSample = (centerPixel * state.samplesPerPixel).round();
    final centerMilliseconds = (centerSample * 1000 / state.buffer.sampleRate).round();
    final displayTime = Duration(milliseconds: centerMilliseconds);
    
    // Format time as HH:mm:ss,SSS (matching subtitle format with comma)
    final hours = displayTime.inHours.toString().padLeft(2, '0');
    final minutes = (displayTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (displayTime.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (displayTime.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  /// Copy the current time position to clipboard
  void _copyTimeToClipboard(WaveformReady state) {
    final timeString = _formatDisplayTime(state);
    Clipboard.setData(ClipboardData(text: timeString));
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Time copied: $timeString',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF323232), // Dark gray background
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 250,
      ),
    );
  }

  /// Open waveform settings in the settings sheet
  void _openWaveformSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SettingsSheet(initialSection: 'waveform'),
    );
  }

  /// Handle tap on subtitle box area (double tap seeks/highlights, long press enters edit mode)
  void _handleSubtitleTapAtPosition(Offset localPosition, WaveformReady state, int subtitleIndex) {
    final now = DateTime.now();
    final subtitle = _currentSubtitles[subtitleIndex];
    final startTime = parseTimeString(subtitle.startTime);
    
    // Check for double tap to seek and highlight
    if (_lastTappedSubtitleIndex == subtitleIndex &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < WaveformWidgetState._doubleTapDuration) {
      // Double tap - seek to subtitle start and highlight in list
      widget.onSeek?.call(startTime);
      ref.read(waveformControllerProvider.notifier).dispatch(SeekToTime(startTime));
      // Pass 1-based index (subtitle.index) for highlighting
      widget.onSubtitleHighlight?.call(subtitle.index);
      
      _lastTappedSubtitleIndex = null;
      _lastTapTime = null;
    } else {
      // Single tap - just remember for potential double tap
      _lastTappedSubtitleIndex = subtitleIndex;
      _lastTapTime = now;
    }
  }

  /// Seek to the tapped position
  void _seekToPosition(Offset localPosition, WaveformReady state) {
    final tapX = localPosition.dx;
    final pixelPosition = state.scrollPosition + tapX;
    final time = state.pixelToTime(pixelPosition);

    // Notify parent
    widget.onSeek?.call(time);

    // Update state
    ref.read(waveformControllerProvider.notifier).dispatch(SeekToTime(time));
  }

  /// Detect which subtitle was tapped (returns subtitle index or null)
  int? _getSubtitleAtPosition(Offset localPosition, WaveformReady state) {
    final tapX = localPosition.dx;
    final pixelPosition = state.scrollPosition + tapX;
    final time = state.pixelToTime(pixelPosition);
    
    // Find subtitle that contains this time
    for (int i = 0; i < _currentSubtitles.length; i++) {
      final subtitle = _currentSubtitles[i];
      final startTime = parseTimeString(subtitle.startTime);
      final endTime = parseTimeString(subtitle.endTime);
      if (time >= startTime && time <= endTime) {
        return i;
      }
    }
    return null;
  }

  /// Apply magnet snap to nearby playhead or subtitle boundaries
  /// Returns adjusted time if snap occurred, or original time if no snap
}
