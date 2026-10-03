part of '../../screen_edit.dart';

extension _EditShortcuts on _EditScreenState {
  void _handlePlayPauseShortcut() {
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final isPlaying = _videoPlayerKey.currentState!.isPlaying();
      if (isPlaying) {
        _videoPlayerKey.currentState!.pause();
      } else {
        _videoPlayerKey.currentState!.play();
      }
    }
  }

  void _handleSaveShortcut() {
    // Use the new save function for keyboard shortcut
    _handleSave();
  }

  void _handleToggleSelectionModeShortcut() {
    if (_isSelectionMode) {
      _controller.clearSelection();
    } else {
      _controller.setSelectionMode(true);
    }
  }

  void _handleDeleteSelectionShortcut() {
    // If in selection mode with selected items, use batch delete
    if (_isSelectionMode && _selectedIndices.isNotEmpty) {
      _showBatchDeleteConfirmation();
    } 
    // If there's a highlighted line, delete that specific line
    else if (_highlightedIndex != null && _highlightedIndex! < subtitleLines.length) {
      final lineToDelete = subtitleLines[_highlightedIndex!];
      if (subtitleCollection != null) {
        SubtitleOperations.showDeleteConfirmation(
          context: context,
          subtitleId: widget.subtitleCollectionId,
          currentLine: lineToDelete,
          collection: subtitleCollection!,
          onSuccess: _refreshSubtitleLines,
          sessionId: widget.sessionId,
        );
      }
    }
  }

  void _handleEditCurrentLineShortcut() {
    // Edit the highlighted line if available
    if (_highlightedIndex != null && _highlightedIndex! < subtitleLines.length) {
      _navigateToEditSubtitleScreen(_highlightedIndex!);
    }
    // If no highlighted line, edit the first line if available
    else if (subtitleLines.isNotEmpty) {
      _navigateToEditSubtitleScreen(0);
    }
  }

  void _handleMarkLineShortcut() {
    // Mark the highlighted line if available
    if (_highlightedIndex != null && _highlightedIndex! < subtitleLines.length) {
      _toggleMarkLine(_highlightedIndex!);
    }
    // If no highlighted line, mark the first line if available
    else if (subtitleLines.isNotEmpty) {
      _toggleMarkLine(0);
    }
  }

  void _handleMarkLineAndCommentShortcut() {
    // Don't open a new dialog if one is already visible
    if (_isCommentDialogOpen) {
      return;
    }
    
    int targetIndex;
    
    // Determine which line to operate on
    if (_highlightedIndex != null && _highlightedIndex! < subtitleLines.length) {
      targetIndex = _highlightedIndex!;
    } else if (subtitleLines.isNotEmpty) {
      targetIndex = 0;
    } else {
      return; // No lines available
    }

    // Always show comment dialog - marking happens when user presses 'Add' button
    _showCommentDialogForLine(targetIndex);
  }

  void _handleFindReplaceShortcut() {
    _showFindReplaceModal();
  }

  void _handleGotoLineShortcut() {
    _showGoToLineModal();
  }

  void _handleHelpShortcut() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpScreen()),
    );
  }

  void _handleSettingsShortcut() {
    _showSettingsModal();
  }

  void _handlePopScreenShortcut() {
    // Navigate back to the previous screen
    Navigator.of(context).pop();
  }

  // Navigation shortcut handlers for next/previous subtitle
  void _handleNextLineShortcut() {
    debugPrint('=== _handleNextLineShortcut CALLED ===');
    
    if (!_isVideoLoaded || _videoPlayerKey.currentState == null) {
      debugPrint('Ctrl+. pressed - video not loaded');
      return;
    }

    final videoPlayer = _videoPlayerKey.currentState!;
    
    // If in fullscreen mode, use video player's skip function
    if (videoPlayer.isInFullscreenMode()) {
      debugPrint('Ctrl+. pressed in fullscreen mode - using video skip to next subtitle');
      videoPlayer.seekToNextSubtitle();
      return;
    }
    
    // In normal mode, navigate to next subtitle and seek video
    debugPrint('Ctrl+. pressed in normal mode - navigating to next subtitle');
    
    int currentIndex = _highlightedIndex ?? -1; // Start from -1 if no highlighted index
    int nextIndex = currentIndex + 1;
    
    debugPrint('Navigation: current highlighted index = $currentIndex, next index = $nextIndex');
    
    // Navigate to next subtitle if valid index found
    if (nextIndex >= 0 && nextIndex < subtitleLines.length) {
      debugPrint('Navigating to subtitle at index $nextIndex (line ${subtitleLines[nextIndex].index})');
      // Use the direct navigation method to update highlighted index and scroll
      _navigateToIndex(nextIndex);
      
      // Seek video to the newly highlighted subtitle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seekVideoToHighlightedSubtitle();
      });
    } else {
      debugPrint('No next subtitle found (nextIndex: $nextIndex, total: ${subtitleLines.length})');
    }
    
    debugPrint('=== _handleNextLineShortcut COMPLETED ===');
  }

  void _handlePreviousLineShortcut() {
    if (!_isVideoLoaded || _videoPlayerKey.currentState == null) {
      debugPrint('Ctrl+, pressed - video not loaded');
      return;
    }

    final videoPlayer = _videoPlayerKey.currentState!;
    
    // If in fullscreen mode, use video player's skip function
    if (videoPlayer.isInFullscreenMode()) {
      debugPrint('Ctrl+, pressed in fullscreen mode - using video skip to previous subtitle');
      videoPlayer.seekToPreviousSubtitle();
      return;
    }
    
    // In normal mode, navigate to previous subtitle and seek video
    debugPrint('Ctrl+, pressed in normal mode - navigating to previous subtitle');
    
    int currentIndex = _highlightedIndex ?? 0;
    int prevIndex = currentIndex - 1;
    
    debugPrint('Navigation: current highlighted index = $currentIndex, previous index = $prevIndex');
    
    // Navigate to previous subtitle if valid index found
    if (prevIndex >= 0 && prevIndex < subtitleLines.length) {
      debugPrint('Navigating to subtitle at index $prevIndex (line ${subtitleLines[prevIndex].index})');
      // Use the direct navigation method to update highlighted index and scroll
      _navigateToIndex(prevIndex);
      
      // Seek video to the newly highlighted subtitle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seekVideoToHighlightedSubtitle();
      });
    } else {
      debugPrint('No previous subtitle found (prevIndex: $prevIndex, total: ${subtitleLines.length})');
    }
  }

  // Video playback shortcut handlers
  void _handleToggleFullscreenShortcut() {
    if (_videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.toggleCustomFullscreen();
    }
  }


}
