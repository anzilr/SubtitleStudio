part of '../../screen_edit.dart';

extension _EditSubtitleActions on _EditScreenState {
  Future<void> _applyEffectToSingleLineFromBottomSheet(BuildContext context, int index, String effectType, Map<String, dynamic> effectConfig) async {
    try {
      final currentLine = subtitleLines[index];
      List<SubtitleLine> effectLines = [];
      
      if (effectType == 'karaoke') {
        final colorHex = effectConfig['color'] as String;
        final color = colorHex.substring(2); // Remove alpha channel
        final endDelay = effectConfig['endDelay'] as double? ?? 0.0;
        final effectTypeKaraoke = effectConfig['effectType'] as String? ?? 'word';
        
        // Extract text selection parameters
        final hasTextSelection = effectConfig['hasTextSelection'] as bool? ?? false;
        final selectionStart = effectConfig['selectionStart'] as int? ?? 0;
        final selectionEnd = effectConfig['selectionEnd'] as int? ?? 0;
        final selectedText = effectConfig['selectedText'] as String? ?? '';
        final fullText = effectConfig['fullText'] as String? ?? '';
        
        effectLines = await SubtitleEffectOperations.generateKaraokeEffect(
          originalLine: currentLine,
          color: color,
          effectType: effectTypeKaraoke,
          endDelay: endDelay,
          hasTextSelection: hasTextSelection,
          selectionStart: selectionStart,
          selectionEnd: selectionEnd,
          selectedText: selectedText,
          fullText: fullText,
        );
      } else if (effectType == 'typewriter') {
        final colorHex = effectConfig['color'] as String;
        final color = colorHex.substring(2); // Remove alpha channel
        final endDelay = effectConfig['endDelay'] as double? ?? 0.0;
        
        effectLines = await SubtitleEffectOperations.generateTypewriterEffect(
          originalLine: currentLine,
          color: color,
          endDelay: endDelay,
        );
      }
      
      if (effectLines.isNotEmpty) {
        // Apply the effect to the database
        final success = await SubtitleEffectOperations.applyEffectToSubtitleCollection(
          subtitleCollectionId: widget.subtitleCollectionId,
          originalLineIndex: index, // Convert to 0-based
          effectLines: effectLines,
        );
        
        if (success) {
          // Create a checkpoint for the effect
          await CheckpointManager.createCheckpoint(
            sessionId: widget.sessionId,
            subtitleCollectionId: widget.subtitleCollectionId,
            operationType: 'effect',
            description: 'Applied $effectType effect to line ${index + 1} (${effectLines.length} lines)',
            deltas: [], // Effects don't use deltas
            forceSnapshot: true, // IMPORTANT: Force snapshot because effects replace entire sections
          );
          
          // Update the last edited index to the first effect line
          if (effectLines.isNotEmpty) {
            final firstEffectLineIndex = effectLines.first.index;
            await updateLastEditedIndex(widget.sessionId, firstEffectLineIndex);
          }
          
          // Close the sheet and refresh
          Navigator.of(context).pop();
          await _refreshSubtitleLines();
          
          // Scroll to the first effect line to show where the effect was applied
          if (effectLines.isNotEmpty) {
            final firstEffectLineIndex = effectLines.first.index;
            await _scrollToIndexWithLoading(firstEffectLineIndex);
          }
          
          // Show success message
          SnackbarHelper.showSuccess(
            context,
            '$effectType effect applied successfully! Generated ${effectLines.length} subtitle lines.',
            duration: const Duration(seconds: 3),
          );
        } else {
          throw Exception('Failed to apply effect to database');
        }
      } else {
        throw Exception('No effect lines generated');
      }
    } catch (e) {
      // Show error message
      SnackbarHelper.showError(
        context,
        'Could not apply the subtitle effect. Please try again.',
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _openAddLineSheetWithTimes(Duration startTime, Duration endTime) async {
    final startTimeStr = _formatDurationToSRT(startTime);
    final endTimeStr = _formatDurationToSRT(endTime);
    
    if (subtitleCollection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle collection not loaded'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }
    
    try {
      // Find the correct insertion position based on the start time
      int insertIndex = subtitleLines.length; // Default to end
      int displayIndex = subtitleLines.length + 1; // 1-based display index
      
      for (int i = 0; i < subtitleLines.length; i++) {
        final lineStartTime = parseTimeString(subtitleLines[i].startTime);
        if (startTime.inMilliseconds < lineStartTime.inMilliseconds) {
          insertIndex = i;
          displayIndex = i + 1;
          break;
        }
      }
      
      // Create a new line with the selected times from waveform
      final newLine = SubtitleLine()
        ..index = displayIndex
        ..original = ''
        ..edited = null
        ..startTime = startTimeStr
        ..endTime = endTimeStr;
      
      // Create checkpoint before adding
      await CheckpointManager.createAddCheckpoint(
        sessionId: widget.sessionId,
        subtitleCollectionId: widget.subtitleCollectionId,
        addedLine: newLine,
        insertIndex: insertIndex, // 0-based insertion index
      );
      
      // Add the line to database
      final success = await addSubtitleLine(
        widget.subtitleCollectionId, 
        newLine, 
        insertIndex, // 0-based insertion index
      );
      
      if (success) {
        // Refresh the subtitle lines
        await _refreshSubtitleLines();
        
        // Navigate to the new line (0-based index)
        _navigateToIndex(insertIndex);
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New line added successfully at line $displayIndex'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } else {
        throw Exception('Failed to add new line to database');
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not add the subtitle line. Please try again.'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  Future<void> _toggleMarkLine(int index) async {
    // Store the current highlighted index to maintain scroll position
    final previousHighlightedIndex = _highlightedIndex;
    
    // Riverpod migration - delegate to the Riverpod controller which handles all business logic
    await _controller.markLine(index);
    
    // Update local state from controller state
    final state = _editState;
    _setEditorState(() {
      subtitleLines = state.subtitleLines;
      // Restore the highlighted index to prevent unwanted scrolling
      _highlightedIndex = previousHighlightedIndex;
    });
    
    // Update the controller
    if (index >= 0 && index < subtitleLines.length) {
      _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
    }
    
    // Regenerate subtitles for video player
    _updateSubtitlesWithVersion(subtitleLines);
    
    // Update video player with new subtitles (for fullscreen mark button state)
    if (_videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
    }
    
    // Show feedback based on controller state
    if (!mounted) return;
    if (index >= 0 && index < subtitleLines.length) {
      final marked = subtitleLines[index].marked;
      SnackbarHelper.showSuccess(
        context,
        marked ? 'Line marked' : 'Line unmarked',
        duration: const Duration(seconds: 1),
      );
    }
  }

  Future<void> _handleVideoPlayerMarkToggle(int subtitleIndex, bool isMarked) async {
    try {
      final success = await _controller.setLineMarked(subtitleIndex, isMarked);
      if (success) {
        // Update the subtitle line in the list
        if (subtitleIndex < subtitleLines.length) {
          _setEditorState(() {
            subtitleLines[subtitleIndex].marked = isMarked;
          });
          
          // Update the controller
          _controller.updateSubtitleLineLocally(subtitleIndex, subtitleLines[subtitleIndex]);
          
          // Update all subtitle displays (video + waveform)
          _updateAllSubtitleDisplays();
        }
        
        // Show success message
        SnackbarHelper.showSuccess(
          context,
          isMarked ? 'Line marked' : 'Line unmarked',
          duration: const Duration(seconds: 1),
        );
      } else {
        SnackbarHelper.showError(context, 'Failed to update mark status');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not update the mark. Please try again.');
    }
  }

  Future<void> _navigateToEditSubtitleScreen(int index) async {
    // Unregister EditScreen hotkeys to prevent conflicts with EditSubtitleScreen
    await hotkey.MSoneHotkeyManager.instance.unregisterMainEditScreenShortcuts();
    
    // Fetch the session's edit mode before navigating
    final isEditMode = await getSessionEditMode(widget.sessionId);
    
    if (!mounted) return;
    
    // Pause the video before navigating
    if (_videoPlayerKey.currentState != null &&
        _videoPlayerKey.currentState!.isInitialized()) {
      _videoPlayerKey.currentState!.pause();
    }
    
    // Calculate start video position based on subtitle line timing
    Duration? startVideoPosition;
    if (_isVideoLoaded && index >= 0 && index < subtitleLines.length) {
      startVideoPosition = parseTimeString(subtitleLines[index].startTime);
    }
    
    final result = await Navigator.push<int?>(
      context,
      MaterialPageRoute(        builder: (context) => EditSubtitleScreenHost(
          subtitleId: widget.subtitleCollectionId,
          index: index + 1,
          sessionId: widget.sessionId,
          editMode: isEditMode, // Pass the session's edit mode
          videoPath: _selectedVideoPath,
          isVideoLoaded: _isVideoLoaded,
          startVideoPosition: startVideoPosition,
          secondarySubtitles: _originalSecondarySubtitles.isNotEmpty ? _originalSecondarySubtitles : null,
        ),
      ),
    );

    // Re-register hotkey shortcuts after returning from EditSubtitleScreen
    // This is necessary because EditSubtitleScreen unregisters some shortcuts on dispose
    debugPrint('DEBUG: Re-registering EditScreen hotkeys after returning from EditSubtitleScreen');
    await _registerHotkeyShortcuts();
    
    // Force re-register shared shortcuts that might have been overridden
    debugPrint('DEBUG: Force re-registering shared shortcuts');
    await hotkey.MSoneHotkeyManager.instance.forceRegisterSharedShortcuts(
      onHelp: _handleHelpShortcut,
      onSettings: _handleSettingsShortcut,
      onNextLine: _handleNextLineShortcut,
      onPreviousLine: _handlePreviousLineShortcut,
    );
    debugPrint('DEBUG: Hotkey re-registration complete');

    if (result != null) {
      _refreshSubtitleLines();
      // Use the returned index from EditSubtitleScreen (result is 0-based, so add 1)
      await _scrollToIndexWithLoading(result + 1);
    }
    
    // Reload secondary subtitles after returning from EditSubtitleScreen
    // This ensures any changes made in EditSubtitleScreen are reflected here
    await _loadSavedSecondarySubtitle(subtitleLines);
  }

  Future<void> _addInitialSubtitleLine() async {
    try {
      // Create an empty subtitle line
      final newLine = SubtitleLine()
        ..index = 1
        ..original = ""
        ..startTime = "00:00:00,000"
        ..endTime = "00:00:02,000";

      // Add to database
      final success = await addSubtitleLine(widget.subtitleCollectionId, newLine, 0);
      
      if (success) {
        // Navigate to the editor to edit this new line
        if (!mounted) return;
        
        // Unregister EditScreen hotkeys to prevent conflicts with EditSubtitleScreen
        await hotkey.MSoneHotkeyManager.instance.unregisterMainEditScreenShortcuts();
        
        // Pause video if it's playing
        if (_videoPlayerKey.currentState != null &&
            _videoPlayerKey.currentState!.isInitialized()) {
          _videoPlayerKey.currentState!.pause();
        }
        
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(            builder: (context) => EditSubtitleScreenHost(
              subtitleId: widget.subtitleCollectionId,
              index: 1, // First subtitle
              sessionId: widget.sessionId,
              isNewSubtitle: true, // Mark as new subtitle
              videoPath: _selectedVideoPath,
              isVideoLoaded: _isVideoLoaded,
              secondarySubtitles: _originalSecondarySubtitles.isNotEmpty ? _originalSecondarySubtitles : null,
            ),
          ),
        );

        // Re-register hotkey shortcuts after returning from EditSubtitleScreen
        // This is necessary because EditSubtitleScreen unregisters some shortcuts on dispose
        debugPrint('DEBUG: Re-registering EditScreen hotkeys after returning from EditSubtitleScreen (new subtitle path)');
        await _registerHotkeyShortcuts();
        
        // Force re-register shared shortcuts that might have been overridden
        debugPrint('DEBUG: Force re-registering shared shortcuts (new subtitle path)');
        await hotkey.MSoneHotkeyManager.instance.forceRegisterSharedShortcuts(
          onHelp: _handleHelpShortcut,
          onSettings: _handleSettingsShortcut,
        );
        debugPrint('DEBUG: Hotkey re-registration complete (new subtitle path)');

        if (result == true) {
          // Force complete refresh of the subtitle data
          final updatedSubtitles = await fetchSubtitleLines(widget.subtitleCollectionId);
          
          if (!mounted) return;
          
          // Update state with new data
          _setEditorState(() {
            subtitleLines = updatedSubtitles;
            _controller.replaceSubtitleLinesLocally(updatedSubtitles);
            _subtitles = _generateSubtitles(updatedSubtitles);
            
            // Recreate the FutureBuilder's future to force it to rebuild
            subtitleLinesFuture = Future.value(updatedSubtitles);
          });
          
          // Refresh the collection reference as well
          subtitleCollection = (await fetchSubtitle(widget.subtitleCollectionId))!;
          
          await WidgetsBinding.instance.endOfFrame;
          final lastIndex = await getLastEditedIndex(widget.sessionId);
          
          if (lastIndex != null && mounted) {
            await _scrollToIndexWithLoading(lastIndex);
          }
        }
      } else {
        if (!mounted) return;
        SnackbarHelper.showError(context, 'Failed to add subtitle line');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Something went wrong. Please try again.');
    }
  }

  Future<void> _removeHearingImpairedLines() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Hearing Impaired Text'),
        content: const Text(
          'This will remove hearing impaired annotations such as:\n'
          '• Text in square brackets [like this]\n'
          '• Sound effects and music notes ♪\n'
          '• Speaker labels (NAME:)\n'
          '• Sound descriptions in parentheses\n\n'
          'Lines that become empty after removal will be deleted.\n\n'
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    var loadingVisible = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing subtitles...'),
                ],
              ),
            ),
          ),
        ),
      );
      loadingVisible = true;

      final result = await HearingImpairedCleanupService.execute(
        sessionId: widget.sessionId,
        subtitleCollectionId: widget.subtitleCollectionId,
        currentLines: subtitleLines,
      );

      await _refreshSubtitleLines();

      if (!mounted) return;
      if (loadingVisible && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        loadingVisible = false;
      }

      SnackbarHelper.showSuccess(
        context,
        result.summaryMessage,
      );
    } catch (e) {
      if (!mounted) return;
      if (loadingVisible && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      SnackbarHelper.showError(
        context,
        'Could not remove hearing-impaired text. Please try again.',
      );
    }
  }
}
