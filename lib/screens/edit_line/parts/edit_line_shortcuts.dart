part of '../../screen_edit_line.dart';

extension _EditLineShortcuts on EditSubtitleScreenState {
  // Keyboard shortcut handlers
  void _handlePlayPauseShortcut() {
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      // Get current play state and toggle it
      final isPlaying = _videoPlayerKey.currentState!.isPlaying();
      if (isPlaying) {
        _videoPlayerKey.currentState!.pause();
      } else {
        _videoPlayerKey.currentState!.play();
      }
    }
  }

  void _handleTextFormattingShortcut(hotkey.TextFormattingType type) {
    // Use the existing FormattingMenu's _toggleFormatting method logic
    String tag;
    switch (type) {
      case hotkey.TextFormattingType.bold:
        tag = 'b';
        break;
      case hotkey.TextFormattingType.italic:
        tag = 'i';
        break;
      case hotkey.TextFormattingType.underline:
        tag = 'u';
        break;
    }

    toggleTextFormatting(controller: _editedController, tag: tag);

    // Update character counts
    _instantCharacterCountUpdate();
  }

  void _handleSaveShortcut() async {
    // Use the same save function as the save button
    await _updateSubtitle(context);
    // The _updateSubtitle function already shows appropriate feedback
  }

  void _handleDeleteCurrentShortcut() {
    // Use the existing delete functionality directly (same as menu option)
    if (_subtitleLine == null) return;

    SubtitleOperations.showDeleteConfirmation(
      context: context,
      subtitleId: widget.subtitleId,
      currentLine: _subtitleLine!,
      collection: _subtitle!,
      onSuccess:
          () => _fetchSubtitleLine(widget.subtitleId, _subtitleLine!.index - 1),
      sessionId: widget.sessionId,
    );
  }

  void _handleColorPickerShortcut() {
    showEditLineColorPickerSheet(
      context: context,
      controller: _editedController,
      colorHistory: _colorHistory,
      onApply: _saveColorHistory,
    );
  }

  void _handleMarkLineShortcut() {
    // Use the existing mark/unmark functionality
    _toggleMarkLine();
  }

  void _handleMarkLineAndCommentShortcut() {
    // Don't open a new dialog if one is already visible
    if (_isCommentDialogOpen) {
      return;
    }
    
    // Show comment dialog without marking first
    // Marking will happen when user presses 'Add' button
    if (_subtitleLine != null) {
      _showCommentDialogForCurrentLine();
    }
  }

  void _handleJumpToLineShortcut() {
    // Use the same logic as the menu item - call _showJumpToLineModal()
    _showJumpToLineModal();
  }

  void _handleHelpShortcut() {
    // Navigate to help screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpScreen()),
    );
  }

  void _handleSettingsShortcut() {
    // Show settings sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder:
          (context) => SettingsSheet(
            onSettingsChanged: () {
              _reloadAllSettings();
            },
          ),
    );
  }

  void _handlePopScreenShortcut() async {
    // Use the same logic as the back button - check for unsaved changes
    if (_hasUnsavedChanges()) {
      final shouldPop = await _showUnsavedChangesDialog();
      if (shouldPop) {
        // Return the current active index (convert from 1-based to 0-based)
        final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
        Navigator.of(context).pop(currentIndex);
      }
    } else {
      // Return the current active index (convert from 1-based to 0-based)
      final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
      Navigator.of(context).pop(currentIndex);
    }
  }

  void _handleToggleRepeatShortcut() {
    // Toggle repeat mode
    _toggleRepeatMode();
  }

  void _handleToggleRepeatRangeShortcut() {
    // For now, set a simple range around current subtitle (current ± 2)
    if (_subtitleLine != null && _subtitle != null) {
      final currentIndex = (_subtitleLine!.index - 1); // Convert to 0-based
      final maxIndex = _subtitle!.lines.length - 1;

      final startIndex = (currentIndex - 2).clamp(0, maxIndex);
      final endIndex = (currentIndex + 2).clamp(0, maxIndex);

      // Enable repeat mode if not already enabled
      if (!_isRepeatModeEnabled) {
        _toggleRepeatMode();
      }

      // Set custom range
      setCustomRepeatRange(startIndex, endIndex);
    }
  }

  void _handleToggleFullscreenShortcut() {
    // Toggle fullscreen if video is loaded
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.toggleCustomFullscreen();
    }
  }

  // Split line shortcut handler
  void _handleSplitLineShortcut() {
    // Use the existing split functionality from SubtitleOperations
    if (_subtitleLine != null && _subtitle != null) {
      SubtitleOperations.handleSplitButton(
        context: context,
        editedController: _editedController,
        startTime: _startTimeController.text,
        endTime: _endTimeController.text,
        subtitleId: widget.subtitleId,
        currentLine: _subtitleLine!,
        refreshCallback:
            () => _fetchSubtitleLine(widget.subtitleId, _subtitleLine!.index),
        sessionId: widget.sessionId,
      );
    }
  }

  // Merge line shortcut handler
  void _handleMergeLineShortcut() {
    logInfo(
      '_handleMergeLineShortcut called',
      context: 'EditSubtitleScreen._handleMergeLineShortcut',
    );
    // Use the existing merge functionality from SubtitleOperations
    if (_subtitleLine != null && _subtitle != null) {
      logInfo(
        'Showing merge confirmation dialog',
        context: 'EditSubtitleScreen._handleMergeLineShortcut',
      );
      SubtitleOperations.showMergeConfirmation(
        context: context,
        currentLine: _subtitleLine!,
        collection: _subtitle!,
        subtitleId: widget.subtitleId,
        refreshCallback: (newLineIndex) =>
            _fetchSubtitleLine(widget.subtitleId, newLineIndex - 1),
        sessionId: widget.sessionId,
      );
    } else {
      logWarning(
        'Cannot merge - _subtitleLine: ${_subtitleLine != null}, _subtitle: ${_subtitle != null}',
        context: 'EditSubtitleScreen._handleMergeLineShortcut',
      );
    }
  }

  // Paste original shortcut handler
  void _handlePasteOriginalShortcut() {
    // Only allow in translation mode (not edit mode)
    if (!_isEditMode && mounted) {
      _setEditLineState(() {
        _editedController.text = _originalController.text;
      });
    }
  }


}
