part of '../../screen_edit_line.dart';

extension _EditLineDialogActions on EditSubtitleScreenState {
  void _handleEditLineMenuSelection(String? value) {
    if (value == null) return;

    switch (value) {
      case 'settings':
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
        break;
      case 'loadVideo':
        _pickVideoFile();
        break;
      case 'unloadVideo':
        _unloadVideo();
        break;
      case 'showOriginal':
        _showOriginalLineWarningDialog(!_showOriginalLine);
        break;
      case 'toggleOriginalField':
        _saveShowOriginalTextField(!_showOriginalTextField);
        break;
      case 'toggleFormatted':
        _setEditLineState(() {
          isRawEnabled = !isRawEnabled;
        });
        break;
      case 'autoSave':
        _saveAutoSaveWithNavigation(!_autoSaveWithNavigation);
        break;
      case 'loadSecondarySubtitle':
        _showSecondarySubtitleModal();
        break;
      case 'toggleSecondarySubtitle':
        _toggleSecondarySubtitles();
        break;
      case 'autoResizeOnKeyboard':
        _saveAutoResizeOnKeyboard(!_autoResizeOnKeyboard);
        break;
      case 'markLine':
        _toggleMarkLine();
        break;
      case 'showMarkedLines':
        _showMarkedLinesModal();
        break;
      case 'checkpointHistory':
        _showCheckpointHistoryModal();
        break;
      case 'jumpToLine':
        _showJumpToLineModal();
        break;
      case 'delete':
        if (_subtitleLine == null) return;

        SubtitleOperations.showDeleteConfirmation(
          context: context,
          subtitleId: widget.subtitleId,
          currentLine: _subtitleLine!,
          collection: _subtitle!,
          onSuccess:
              () => _fetchSubtitleLine(
                widget.subtitleId,
                _subtitleLine!.index - 1,
              ),
          sessionId: widget.sessionId,
        );
        break;
      case 'help':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpScreen()),
        );
        break;
    }
  }

  void _showCommentDialogForCurrentLine() {
    if (_subtitleLine == null) return;
    
    // Check if video player is in fullscreen mode
    final videoPlayerState = _videoPlayerKey.currentState;
    final isInFullscreenMode = videoPlayerState?.isInFullscreenMode() ?? false;
    
    if (isInFullscreenMode) {
      logInfo(
        'Showing comment dialog for fullscreen mode - current line',
        context: 'EditSubtitleScreen._showCommentDialogForCurrentLine',
      );
      
      // In fullscreen mode, find corresponding subtitle and use video player's fullscreen comment dialog
      final currentIndex = _subtitleLine!.index - 1; // Convert to 0-based index
      if (currentIndex >= 0 && currentIndex < _subtitles.length && videoPlayerState != null) {
        final subtitle = _subtitles[currentIndex];
        
        // Create a subtitle with current comment for the fullscreen dialog
        final subtitleWithComment = Subtitle(
          index: subtitle.index,
          start: subtitle.start,
          end: subtitle.end,
          text: subtitle.text,
          comment: _subtitleLine!.comment,
        );
        
        // Fullscreen controls own their dialog-open lifecycle and duplicate guard.
        videoPlayerState.showFullscreenCommentDialog(subtitleWithComment);
        return;
      }
    } else {
      logInfo(
        'Showing comment dialog for normal mode - current line',
        context: 'EditSubtitleScreen._showCommentDialogForCurrentLine',
      );
    }
    
    // Store the current playing state before showing dialog (for normal mode)
    bool wasPlaying = false;
    if (videoPlayerState != null && !isInFullscreenMode) {
      wasPlaying = videoPlayerState.isPlaying();
      logInfo(
        'Comment dialog opening in normal mode - video was ${wasPlaying ? 'playing' : 'paused'}',
        context: 'EditSubtitleScreen._showCommentDialogForCurrentLine',
      );
      
      // Pause video if it was playing when comment dialog opens
      if (wasPlaying) {
        videoPlayerState.pause();
        logInfo(
          'Paused video for comment input in line edit screen',
          context: 'EditSubtitleScreen._showCommentDialogForCurrentLine',
        );
      }
    }
    
    // Flag to track if video has been resumed to prevent double resuming
    bool hasResumed = false;
    
    // Mark dialog as open
    _setEditLineState(() => _isCommentDialogOpen = true);
    
    // Normal mode or fallback - use the standard comment dialog
    CommentDialog.show(
      context,
      existingComment: _subtitleLine!.comment,
      originalText: _subtitleLine!.original,
      editedText: _subtitleLine!.edited,
      subtitleIndex: _subtitleLine!.index,
      onCommentSaved: (comment) async {
        try {
          // If the line is not marked, mark it first
          if (!_subtitleLine!.marked) {
            await _toggleMarkLine();
          }
          
          // Update comment in database  
          final success = await _editLineController.updateLineComment(
            _subtitleLine!.index - 1,
            comment,
          );
          
          if (success) {
            _setEditLineState(() {
              _subtitleLine!.comment = comment;
            });
            
            // Refresh subtitle collection data and update video player
            _subtitle = (await _editLineController.loadSubtitleCollection())!;
            _markSubtitlesForRegeneration();
            _generateSubtitles();
            
            final modeText = isInFullscreenMode ? 'fullscreen' : 'normal';
            SnackbarHelper.showSuccess(context, 
              (comment.isNotEmpty) ? 'Comment updated ($modeText mode)' : 'Comment deleted ($modeText mode)');
          } else {
            SnackbarHelper.showError(context, 'Failed to update comment');
          }
          
          // Resume video if it was playing before dialog opened and not already resumed
          if (wasPlaying && videoPlayerState != null && !hasResumed) {
            hasResumed = true;
            videoPlayerState.play();
            logInfo(
              'Resumed video after comment save in line edit screen',
              context: 'EditSubtitleScreen._showCommentDialogForCurrentLine',
            );
          }
        } catch (e) {
          SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
        }
      },
      onCommentDeleted: () async {
        try {
          // If the line is not marked, mark it first (marking is required for comments)
          if (!_subtitleLine!.marked) {
            await _toggleMarkLine();
          }
          
          // Delete comment from database
          final success = await _editLineController.updateLineComment(
            _subtitleLine!.index - 1,
            null,
          );
          
          if (success) {
            _setEditLineState(() {
              _subtitleLine!.comment = null;
            });
            
            // Refresh subtitle collection data and update video player
            _subtitle = (await _editLineController.loadSubtitleCollection())!;
            _markSubtitlesForRegeneration();
            _generateSubtitles();
            
            final modeText = isInFullscreenMode ? 'fullscreen' : 'normal';
            SnackbarHelper.showSuccess(context, 'Comment deleted ($modeText mode)');
          } else {
            SnackbarHelper.showError(context, 'Failed to delete comment');
          }
          
          // Resume video if it was playing before dialog opened and not already resumed
          if (wasPlaying && videoPlayerState != null && !hasResumed) {
            hasResumed = true;
            videoPlayerState.play();
            logInfo(
              'Resumed video after comment delete in line edit screen',
              context: 'EditSubtitleScreen._showCommentDialogForCurrentLine',
            );
          }
        } catch (e) {
          SnackbarHelper.showError(context, 'Could not delete the comment. Please try again.');
        }
      },
    ).then((_) {
      // Mark dialog as closed when dismissed
      if (mounted) {
        _setEditLineState(() => _isCommentDialogOpen = false);
      }
      
      // This executes when the dialog is dismissed (by canceling without save/delete)
      // Resume video if it was playing before dialog opened and we haven't already resumed it
      if (wasPlaying && videoPlayerState != null && !hasResumed) {
        videoPlayerState.play();
        logInfo(
          'Resumed video after comment dialog dismissed in line edit screen',
          context: 'EditSubtitleScreen._showCommentDialogForCurrentLine',
        );
      }
    });
  }

  Future<void> _showMarkedLinesModal() async {
    try {
      final markedLines = await _editLineController.getMarkedSubtitleLines();
      
      // Get the current line's database index if it's marked
      int? initialHighlightIndex;
      if (_subtitleLine != null && _subtitleLine!.marked) {
        initialHighlightIndex = _subtitleLine!.index; // Database index (1-based)
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height,
          child: MarkedLinesSheet(
            markedLines: markedLines,
            initialHighlightLineIndex: initialHighlightIndex, // Pass the current line index to highlight
            onLineSelected: (index) {
              // Navigate to the selected line
              _skipToLine(widget.subtitleId, index);
            },
            onCommentUpdated: (index, comment) async {
              // Update comment in database and refresh UI
              try {
                await _editLineController.updateLineComment(index, comment);
                // Refresh the subtitle data from database
                _subtitle = (await _editLineController.loadSubtitleCollection())!;
                
                // Update current line if it matches
                if (_subtitleLine != null && _subtitleLine!.index == index + 1) {
                      _setEditLineState(() {
                        _subtitleLine!.comment = comment;
                      });
                    }
                    
                    // Regenerate subtitles for video player
                    _markSubtitlesForRegeneration();
                    _generateSubtitles();
                    
                    SnackbarHelper.showSuccess(context, 
                      comment != null ? 'Comment updated' : 'Comment deleted');
                  } catch (e) {
                    SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                  }
                },
            onResolvedUpdated: (index, resolved) async {
              // Update resolved status in database
              try {
                await _editLineController.updateLineResolved(index, resolved);
                // Refresh the subtitle data from database
                _subtitle = (await _editLineController.loadSubtitleCollection())!;
                
                // Update current line if it matches
                if (_subtitleLine != null && _subtitleLine!.index == index + 1) {
                  _setEditLineState(() {
                    _subtitleLine!.resolved = resolved;
                  });
                }
                
                // Regenerate subtitles for video player
                _markSubtitlesForRegeneration();
                _generateSubtitles();
                
                SnackbarHelper.showSuccess(context, 
                  resolved ? 'Comment marked as resolved' : 'Comment marked as unresolved');
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update comment status. Please try again.');
              }
            },
            onTextEdited: (index, newText) async {
              // Update edited text in database and refresh UI
              try {
                // Get the subtitle line from database
                final subtitle = await _editLineController.loadSubtitleCollection();
                if (subtitle != null && index < subtitle.lines.length) {
                  final updatedLine = subtitle.lines[index];
                  updatedLine.edited = newText;
                  
                  // Save to database
                  await _editLineController.saveCompleteLine(updatedLine);
                  
                  // Refresh the subtitle data from database
                  _subtitle = (await _editLineController.loadSubtitleCollection())!;
                  
                  // Update current line if it matches
                  if (_subtitleLine != null && _subtitleLine!.index == index + 1) {
                    _setEditLineState(() {
                      _subtitleLine!.edited = newText;
                    });
                  }
                  
                  // Regenerate subtitles for video player
                  _markSubtitlesForRegeneration();
                  _generateSubtitles();
                  
                  SnackbarHelper.showSuccess(context, 'Subtitle text updated');
                }
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update subtitle text. Please try again.');
              }
            },
              ),
        ),
      );
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not load marked lines. Please try again.');
    }
  }

  void _showCheckpointHistoryModal() {
    final isLargeScreen = MediaQuery.of(context).size.width > 800;
    
    if (isLargeScreen) {
      // Show as dialog on large screens
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
              maxHeight: 700,
            ),
            child: CheckpointSheet(
              sessionId: widget.sessionId,
              subtitleCollectionId: widget.subtitleId,
              onCheckpointRestored: () async {
                // Reload subtitle data after checkpoint restoration
                _subtitle = await _editLineController.loadSubtitleCollection();
                
                if (_subtitle != null && _subtitleLine != null) {
                  // Re-fetch the current subtitle line to get updated data
                  final currentIndex = _subtitleLine!.index - 1;
                  if (currentIndex >= 0 && currentIndex < _subtitle!.lines.length) {
                    _setEditLineState(() {
                      _subtitleLine = _subtitle!.lines[currentIndex];
                      _originalController.text = _subtitleLine!.original;
                      _editedController.text = _subtitleLine!.edited ?? '';
                      _startTimeController.text = _subtitleLine!.startTime;
                      _endTimeController.text = _subtitleLine!.endTime;
                    });
                    
                    // Regenerate subtitles for video player
                    _markSubtitlesForRegeneration();
                    _generateSubtitles();
                  }
                }
              },
            ),
          ),
        ),
      );
    } else {
      // Show fullscreen on mobile
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => CheckpointSheet(
            sessionId: widget.sessionId,
            subtitleCollectionId: widget.subtitleId,
            onCheckpointRestored: () async {
              // Reload subtitle data after checkpoint restoration
              _subtitle = await _editLineController.loadSubtitleCollection();
              
              if (_subtitle != null && _subtitleLine != null) {
                // Re-fetch the current subtitle line to get updated data
                final currentIndex = _subtitleLine!.index - 1;
                if (currentIndex >= 0 && currentIndex < _subtitle!.lines.length) {
                  _setEditLineState(() {
                    _subtitleLine = _subtitle!.lines[currentIndex];
                    _originalController.text = _subtitleLine!.original;
                    _editedController.text = _subtitleLine!.edited ?? '';
                    _startTimeController.text = _subtitleLine!.startTime;
                    _endTimeController.text = _subtitleLine!.endTime;
                  });
                  
                  // Regenerate subtitles for video player
                  _markSubtitlesForRegeneration();
                  _generateSubtitles();
                }
              }
            },
          ),
        ),
      );
    }
  }
}
