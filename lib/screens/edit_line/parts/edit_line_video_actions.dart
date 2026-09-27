part of '../../screen_edit_line.dart';

extension _EditLineVideoActions on EditSubtitleScreenState {
  void _initializeVideoPlayer() {
    _isVideoLoaded = widget.isVideoLoaded;
    _selectedVideoPath = widget.videoPath;
    _isVideoVisible = _isVideoLoaded; // Show video by default if loaded

    // Initialize video playing state
    _isVideoPlaying = false;

    // Initialize secondary subtitles if provided
    if (widget.secondarySubtitles != null &&
        widget.secondarySubtitles!.isNotEmpty) {
      _secondarySubtitles = widget.secondarySubtitles!;
      _showSecondarySubtitles = true;
      _generateSecondarySubtitles();
    } else {
      _showSecondarySubtitles = false;
    }

    // Generate initial subtitles if subtitle data is available
    if (_subtitle != null) {
      _markSubtitlesForRegeneration();
      _generateSubtitles();
    }

    if (_isVideoLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_syncVideoPlayerWhenReady());
      });
    }
  }

  void _generateSubtitles() {
    if (_subtitle?.lines != null && _needSubtitleRegeneration) {
      final newSubtitles =
          _subtitle!.lines.asMap().entries.map((entry) {
            final index =
                entry.key; // Use array index instead of database index
            final line = entry.value;
            return Subtitle(
              index:
                  index, // This ensures video player uses same indexing as list
              start: parseTimeString(line.startTime),
              end: parseTimeString(line.endTime),
              text:
                  line.edited?.replaceAll('<br>', '\n') ??
                  line.original.replaceAll('<br>', '\n'),
              marked: line.marked,
            );
          }).toList();

      setState(() {
        _subtitles = newSubtitles;
        _needSubtitleRegeneration = false;
      });

      // Update video player with new subtitles (this will check for changes internally)
      if (_videoPlayerKey.currentState != null) {
        _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
      }
    }
  }

  Future<void> _pickVideoFile() async {
    final filePath = await FilePickerConvenience.pickVideoFile(
      context: context,
    );

    if (filePath != null) {
      setState(() {
        _selectedVideoPath = filePath;
        _isVideoVisible = true;
        _isVideoLoaded = true;
      });

      // Save video path to preferences for this subtitle collection
      await PreferencesModel.saveVideoPath(widget.subtitleId, filePath);

      // Generate subtitles for video player
      _markSubtitlesForRegeneration();
      _generateSubtitles();

      // Seek to current subtitle if available
      if (_subtitleLine != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _seekVideoToSubtitle();
        });
      }

      // Show success message
      SnackbarHelper.showSuccess(
        context,
        'Video loaded successfully',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _syncWithVideoPosition() async {
    if (!_isVideoLoaded || 
        _videoPlayerKey.currentState == null || 
        !_videoPlayerKey.currentState!.isInitialized() ||
        _subtitle?.lines == null) {
      SnackbarHelper.showError(
        context,
        'Video player not ready or no subtitles available',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    try {
      // Get current video position
      final currentPosition = _videoPlayerKey.currentState!.getCurrentPosition();
      
      await logInfo(
        'Sync: Current video position: ${currentPosition.toString()}, subtitle line: ${_subtitleLine!.toString()}',
        context: 'EditSubtitleScreen._handleVideoSync',
      );
      
      // Find the nearest subtitle line
      int nearestIndex = _findNearestSubtitleIndex(currentPosition);
      
      if (nearestIndex == -1) {
        SnackbarHelper.showInfo(
          context,
          'No subtitle found near current video position',
          duration: const Duration(seconds: 2),
        );
        return;
      }
      
      await logInfo(
        'Sync: Found nearest subtitle at index: $nearestIndex (0-based)',
        context: 'EditSubtitleScreen._handleVideoSync',
      );
      
      // Check if the current subtitle line position is the same as the nearest index
      // If so, skip the operation to avoid unnecessary navigation
      if (_subtitleLine != null && _subtitleLine!.index - 1 == nearestIndex) {
        await logInfo(
          'Sync: Current subtitle position is same as nearest index, skipping operation',
          context: 'EditSubtitleScreen._handleVideoSync',
        );
        SnackbarHelper.showInfo(
          context,
          'Already on the nearest subtitle line',
          duration: const Duration(seconds: 1),
        );
        return;
      }
      
      // Check if we need to save current changes before navigating
      if (_hasUnsavedChanges()) {
        final shouldSave = await _showUnsavedChangesDialog();
        if (!shouldSave) return; // User chose to leave without saving or cancelled
      }
      
      // Navigate to the found subtitle line
      // nearestIndex is 0-based, but _skipToLine expects 0-based index
      _skipToLine(widget.subtitleId, nearestIndex);
      
      SnackbarHelper.showSuccess(
        context,
        'Synced to subtitle line ${nearestIndex + 1}',
        duration: const Duration(seconds: 2),
      );
      
    } catch (e) {
      await logError(
        'Error during video sync',
        error: e,
        context: 'EditSubtitleScreen._handleVideoSync',
      );
      SnackbarHelper.showError(
        context,
        'Failed to sync with video position',
        duration: const Duration(seconds: 2),
      );
    }
  }

  int _findNearestSubtitleIndex(Duration currentPosition) {
    if (_subtitle?.lines == null || _subtitle!.lines.isEmpty) {
      return -1;
    }

    int nearestIndex = -1;
    Duration smallestDistance = const Duration(hours: 24); // Large initial value
    
    for (int i = 0; i < _subtitle!.lines.length; i++) {
      final line = _subtitle!.lines[i];
      
      try {
        // Parse subtitle times
        final startTime = _parseSubtitleTime(line.startTime);
        final endTime = _parseSubtitleTime(line.endTime);
        
        final startDuration = Duration(
          hours: startTime.hour,
          minutes: startTime.minute,
          seconds: startTime.second,
          milliseconds: startTime.millisecond,
        );
        
        final endDuration = Duration(
          hours: endTime.hour,
          minutes: endTime.minute,
          seconds: endTime.second,
          milliseconds: endTime.millisecond,
        );
        
        // Check if current position is within subtitle time range
        if (currentPosition >= startDuration && currentPosition <= endDuration) {
          // Direct match - current position is within this subtitle's timing
          return i;
        }
        
        // Calculate distance to subtitle start time
        final distanceToStart = (currentPosition - startDuration).abs();
        
        // Update nearest if this is closer
        if (distanceToStart < smallestDistance) {
          smallestDistance = distanceToStart;
          nearestIndex = i;
        }
        
        // Also check distance to end time for better accuracy
        final distanceToEnd = (currentPosition - endDuration).abs();
        if (distanceToEnd < smallestDistance) {
          smallestDistance = distanceToEnd;
          nearestIndex = i;
        }
        
      } catch (e) {
        logWarning(
          'Error parsing time for subtitle $i: $e',
          context: 'EditSubtitleScreen._findNearestSubtitleIndex',
        );
        continue;
      }
    }
    
    return nearestIndex;
  }

  void _generateSecondarySubtitles() {
    setState(() {
      _secondarySubtitlesForPlayer =
          _secondarySubtitles.asMap().entries.map((entry) {
            final index =
                entry.key; // Use array index instead of database index
            final line = entry.value;
            return Subtitle(
              index:
                  index, // This ensures video player uses same indexing as list
              start: parseTimeString(line.startTime),
              end: parseTimeString(line.endTime),
              text: line.text.replaceAll('<br>', '\n'),
              marked: false, // Secondary subtitles don't have marked field
            );
          }).toList();
    });

    // Update video player with new secondary subtitles
    if (_videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.updateSecondarySubtitles(
        _secondarySubtitlesForPlayer,
      );
    }
  }

  void _toggleSecondarySubtitles() {
    // Toggle visibility
    setState(() {
      _showSecondarySubtitles = !_showSecondarySubtitles;
    });

    // Ensure secondary subtitles are loaded from constructor if available but not yet initialized
    if (_showSecondarySubtitles &&
        _secondarySubtitles.isEmpty &&
        widget.secondarySubtitles != null &&
        widget.secondarySubtitles!.isNotEmpty) {
      _secondarySubtitles = widget.secondarySubtitles!;
      _generateSecondarySubtitles();
    }

    // Update video player with secondary subtitles based on visibility
    if (_videoPlayerKey.currentState != null) {
      if (_showSecondarySubtitles && _secondarySubtitlesForPlayer.isNotEmpty) {
        _videoPlayerKey.currentState!.updateSecondarySubtitles(
          _secondarySubtitlesForPlayer,
        );
      } else {
        _videoPlayerKey.currentState!.updateSecondarySubtitles([]);
      }
    }
  }

  Future<void> _showSecondarySubtitleModal() async {
    if (!mounted) return;

    // Get the current subtitle lines
    List<SubtitleLine> originalSubtitles = [];
    if (_subtitle?.lines != null) {
      originalSubtitles = _subtitle!.lines;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      builder: (context) {
        return SecondarySubtitleSheet(
          originalSubtitles: originalSubtitles,
          subtitleCollectionId: widget.subtitleId,
          videoPlayerState: _videoPlayerKey.currentState,
          onSecondarySubtitlesLoaded: (secondarySubtitles) {
            setState(() {
              _secondarySubtitles = secondarySubtitles;
              _showSecondarySubtitles = true;
              _generateSecondarySubtitles();
            });
            if (mounted) {
              SnackbarHelper.showSuccess(context, 'Secondary subtitles loaded');
            }
          },
        );
      },
    );
  }

  Future<void> _handleVideoPlayerMarkToggle(
    int subtitleIndex,
    bool isMarked,
  ) async {
    logInfo(
      'HandleVideoPlayerMarkToggle: subtitleIndex=$subtitleIndex (0-based array index), isMarked=$isMarked',
      context: 'EditSubtitleScreen._handleVideoPlayerMarkToggle',
    );
    
    try {
      final success = await markSubtitleLine(
        widget.subtitleId,
        subtitleIndex, // subtitleIndex is already 0-based array index
        isMarked,
      );
      if (success) {
        // Update the current subtitle line if it matches
        // Note: _subtitleLine.index is 1-based, so we need to check subtitleIndex + 1
        if (_subtitleLine != null && _subtitleLine!.index == subtitleIndex + 1) {
          setState(() {
            _subtitleLine!.marked = isMarked;
          });
        }

        // Refresh subtitle collection data from database to ensure all data is current
        _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;

        // Update the subtitles list for video player
        _markSubtitlesForRegeneration();
        _generateSubtitles();

        // Show success message
        SnackbarHelper.showSuccess(
          context,
          isMarked ? 'Line marked' : 'Line unmarked',
          duration: const Duration(seconds: 1),
        );
      } else {
        SnackbarHelper.showError(context, 'Failed to update mark status - check debug log for details');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not update mark status. Please try again.');
    }
  }

  Widget _buildVideoPlayerWidget() {
    return EditLineVideoPane(
      videoPlayerKey: _videoPlayerKey,
      videoPath: _selectedVideoPath!,
      subtitleCollectionId: widget.subtitleId,
      subtitles: _subtitles,
      secondarySubtitles:
          _showSecondarySubtitles ? _secondarySubtitlesForPlayer : const [],
      isRepeatModeEnabled: _isRepeatModeEnabled,
      onSubtitlesUpdated: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _markSubtitlesForRegeneration();
            _generateSubtitles();
          });
        });
      },
      onSubtitleMarked: _handleVideoPlayerMarkToggle,
      onSubtitleCommentUpdated: _handleVideoPlayerCommentUpdated,
      onPlayStateChanged: (isPlaying) {
        if (!mounted) return;
        setState(() {
          _isVideoPlaying = isPlaying;
        });
      },
      onRepeatModeToggled: (isEnabled) {
        if (isEnabled != _isRepeatModeEnabled) {
          _toggleRepeatMode();
        }
      },
    );
  }

  Future<void> _handleVideoPlayerCommentUpdated(
    int subtitleIndex,
    String? comment,
  ) async {
    try {
      await updateSubtitleLineComment(
        widget.subtitleId,
        subtitleIndex,
        comment,
      );
      _subtitle =
          (await isar.subtitleCollections.get(widget.subtitleId))!;

      if (_subtitleLine != null &&
          _subtitleLine!.index == subtitleIndex + 1) {
        setState(() {
          _subtitleLine!.comment = comment;
        });
      }

      _markSubtitlesForRegeneration();
      _generateSubtitles();

      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        comment != null ? 'Comment updated' : 'Comment deleted',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        'Could not update the comment. Please try again.',
      );
    }
  }
}
