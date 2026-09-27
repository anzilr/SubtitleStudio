part of '../../screen_edit.dart';

extension _EditSelectionActions on _EditScreenState {
  void _clearSelection() {
    // Riverpod migration - delegate to the Riverpod controller
    // Riverpod listener handles state synchronization automatically
    _controller.clearSelection();
  }

  Future<void> _deleteSelectedSubtitles() async {
  if (_selectedIndices.isEmpty) {
    _clearSelection();
    return;
  }

  final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));

  // Create checkpoint before deletion
  final List<SubtitleLineDelta> batchDeltas = [];
  for (final index in sortedIndices) {
    if (index >= 0 && index < subtitleLines.length) {
      final line = subtitleLines[index];
      
      final lineCopy = SubtitleLine()
        ..index = line.index
        ..startTime = line.startTime
        ..endTime = line.endTime
        ..original = line.original
        ..edited = line.edited
        ..marked = line.marked
        ..comment = line.comment;
      
      final delta = SubtitleLineDelta()
        ..changeType = 'delete'
        ..lineIndex = index
        ..beforeState = lineCopy
        ..afterState = null;
      batchDeltas.add(delta);
    }
  }

  if (batchDeltas.isNotEmpty) {
    try {
      await CheckpointManager.createCheckpoint(
        sessionId: widget.sessionId,
        subtitleCollectionId: widget.subtitleCollectionId,
        operationType: 'delete',
        description: 'Batch deleted ${batchDeltas.length} lines',
        deltas: batchDeltas,
      );
    } catch (e) {
      if (kDebugMode) print('Error creating batch checkpoint: $e');
    }
  }

  // Delete all selected cues with one Isar transaction and one refresh.
  final result = await _controller.deleteSelectedLines();
  final successCount = result['success'] ?? 0;
  final failCount = result['failed'] ?? 0;
  // Repaint from the controller-owned subtitle state.
  _setEditorState(() {});

  // Regenerate subtitles for video player and update version
  _updateSubtitlesWithVersion(subtitleLines);

  // Update video player
  if (_videoPlayerKey.currentState != null) {
    _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
  }

  if (!mounted) return;

  final message = 'Deleted $successCount subtitles${failCount > 0 ? ' (Failed: $failCount)' : ''}';
  SubtitleOperations.showSuccessSnackbar(context, message);

  _clearSelection();
  }

  Future<void> _refreshSubtitleLines() async {
    // Riverpod migration - delegate to the Riverpod controller
    await _controller.refreshSubtitleLines();
    
    final updatedSubtitles = subtitleLines;

    if (!mounted) return;

    _setEditorState(() {});

    // Update the video player's subtitles directly
    if (_videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
    }
    
    // Update the waveform's subtitles
    if (_waveformKey.currentState != null) {
      _waveformKey.currentState!.updateSubtitles(updatedSubtitles);
    }
  }

  /// Open add line sheet with pre-filled start and end times from waveform
  /// Format Duration to SRT time string (HH:MM:SS,mmm)
  String _formatDurationToSRT(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  // Toggle mark status of a subtitle line
  // Show comment dialog for a specific line
  // Show marked lines modal
  // Show marked lines modal with specific line highlighted
  // Show Edit History modal (responsive dialog)
  // Show import comments modal
  void _showImportCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImportCommentsSheet(
        subtitleCollectionId: widget.subtitleCollectionId,
        onCommentsImported: () async {
          // Refresh the subtitle lines to show imported comments
          await _refreshSubtitleLines();
        },
      ),
    );
  }

  // Handle mark/unmark from video player fullscreen controls
  // Helper method to format Duration with only 3 millisecond digits
  String _formatDurationToThreeDigits(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = duration.inMilliseconds.remainder(1000);
    
    return '${hours.toString().padLeft(1, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}.'
           '${milliseconds.toString().padLeft(3, '0')}';
  }

  Widget _buildSubtitleCard(
    SubtitleLine line,
    int index,
    String textContent,
  ) {
    final formattedStart = _formatDurationToThreeDigits(
      parseTimeString(line.startTime),
    );
    final formattedEnd = _formatDurationToThreeDigits(
      parseTimeString(line.endTime),
    );
    final isSelected = _selectedIndices.contains(index);
    final isLightTheme =
        Theme.of(context).brightness == Brightness.light;

    return SubtitleCard(
      line: line,
      index: index,
      textContent: textContent,
      formattedStart: formattedStart,
      formattedEnd: formattedEnd,
      isSelected: isSelected,
      isCardHighlighted: _highlightedIndex == index,
      isCueHighlighted: _highlightedIndex == line.index - 1,
      isSelectionMode: _isSelectionMode,
      isRangeSelectionActive: _isRangeSelectionActive,
      isLightTheme: isLightTheme,
      onEdit: () async {
        if (_videoPlayerKey.currentState != null &&
            _videoPlayerKey.currentState!.isInitialized()) {
          _videoPlayerKey.currentState!.pause();
        }
        await _navigateToEditSubtitleScreen(index);
      },
      onSelectRequested: () {
        if (!_isSelectionMode) {
          _controller.setSelectionMode(true);
        }
        _toggleSelection(index);
      },
      onRangeSelectionTap: () => _handleRangeSelectionTap(index),
      onToggleSelection: () => _toggleSelection(index),
      onHighlightAndSeek: () {
        _highlightIndex(index);
        _seekToSubtitle(index);
      },
      onSelectionMenu: (position) =>
          _showSelectionMenuModal(position: position),
      onActionsMenu: () =>
          _showBottomModalSheet(context, index, textContent),
      onComment: () => _showCommentDialogForLine(index),
      onToggleMark: () => _toggleMarkLine(index),
    );
  }

  // Copy the text of all selected subtitles
  void _copySelectedSubtitles() {
    if (_selectedIndices.isEmpty) return;
    
    final List<int> sortedIndices = _selectedIndices.toList()..sort();
    final StringBuffer buffer = StringBuffer();
    
    for (final index in sortedIndices) {
      if (index < 0 || index >= subtitleLines.length) continue;
      final textContent = subtitleLines[index].edited ?? subtitleLines[index].original;
      buffer.write('${textContent.trim()}\n\n');
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    SnackbarHelper.showSuccess(context, '${sortedIndices.length} subtitles copied to clipboard', duration: const Duration(seconds: 2));
  }

  // Copy the highlighted line
  void _copyHighlightedLine() {
    if (_highlightedIndex == null || _highlightedIndex! < 0 || _highlightedIndex! >= subtitleLines.length) {
      SnackbarHelper.showError(context, 'No line highlighted to copy');
      return;
    }
    
    final textContent = subtitleLines[_highlightedIndex!].edited ?? subtitleLines[_highlightedIndex!].original;
    Clipboard.setData(ClipboardData(text: textContent.trim()));
    SnackbarHelper.showSuccess(context, 'Line ${_highlightedIndex! + 1} copied to clipboard', duration: const Duration(seconds: 2));
  }

  // Unified copy handler - copies selected lines in selection mode, highlighted line in normal mode
  void _handleCopyShortcut() {
    if (_isSelectionMode && _selectedIndices.isNotEmpty) {
      _copySelectedSubtitles();
    } else if (_highlightedIndex != null) {
      _copyHighlightedLine();
    } else {
      SnackbarHelper.showError(context, 'No line to copy. Select lines or highlight a line first.');
    }
  }

  // Show dialog to shift timecodes for only selected subtitles
  void _showShiftSelectedTimesDialog() {
    if (_selectedIndices.isEmpty) return;

    final selectedIndices = _selectedIndices.toList()..sort();
    final firstSelectedIndex = selectedIndices.first;
    final lastSelectedIndex = selectedIndices.last;

    showShiftSelectedTimesSheet(
      context: context,
      initialStartTime: subtitleLines[firstSelectedIndex].startTime,
      initialEndTime: subtitleLines[lastSelectedIndex].endTime,
      onApply: (newStartTime, newEndTime) async {
        final result =
            await SubtitleSyncOperations.shiftSelectedTimecodes(
          subtitleId: widget.subtitleCollectionId,
          allSubtitleLines: subtitleLines,
          selectedIndices: selectedIndices,
          newStartTime: newStartTime,
          newEndTime: newEndTime,
        );

        if (!mounted) return true;

        if (result.success) {
          await _refreshSubtitleLines();
          if (mounted) {
            SnackbarHelper.showSuccess(
              context,
              'Selected subtitles shifted successfully',
            );
          }
        } else {
          SnackbarHelper.showError(
            context,
            'Unable to shift selected subtitles: ${result.message}',
          );
        }

        return true;
      },
    );
  }

  // Show dialog to select subtitles by index range
  void _showSelectByIndexDialog() async {
    final range = await showSelectByIndexSheet(
      context: context,
      totalLines: subtitleLines.length,
    );
    if (range == null || !mounted) return;

    _controller.selectRange(range[0], range[1]);
  }

  // Toggle range selection mode
  void _toggleRangeSelectionMode() {
    _controller.toggleRangeSelectionMode();

    if (_isRangeSelectionActive) {
      SnackbarHelper.showInfo(
        context,
        'Tap on the first subtitle, then tap on the last subtitle',
        duration: const Duration(seconds: 5),
      );
    }
  }

  // Process tap during range selection mode
  void _handleRangeSelectionTap(int index) {
    final rangeStart = _rangeStartIndex;

    if (rangeStart == null) {
      _controller.setRangeSelectionStart(index);
      SnackbarHelper.showInfo(
        context,
        'Now tap on the last subtitle to select the range',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final start = min(rangeStart, index);
    final end = max(rangeStart, index);
    _controller.selectRange(start, end);
  }

  // Add this method to toggle secondary subtitle visibility
  void _toggleSecondarySubtitles(bool value) {
    // Visibility is transient presentation state; subtitle data itself remains Riverpod-owned.
    _setEditorState(() {
      _showSecondarySubtitles = value;
      if (_videoPlayerKey.currentState != null) {
        if (value) {
          // Use controller state for subtitles
          final state = _editState;
          _videoPlayerKey.currentState!.updateSecondarySubtitles(state.secondarySubtitles);
        } else {
          _videoPlayerKey.currentState!.updateSecondarySubtitles([]);
        }
      }
    });
  }

  // Main menu popup

}
