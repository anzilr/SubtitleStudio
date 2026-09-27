part of '../../screen_edit.dart';

extension _EditDialogActions on _EditScreenState {
  void _showBatchDeleteConfirmation() {
    showBatchDeleteConfirmationSheet(
      context: context,
      selectedCount: _selectedIndices.length,
      onConfirm: () async {
        await _deleteSelectedSubtitles();
        _clearSelection();
      },
    );
  }

  void _showCommentDialogForLine(int index) {
    if (index < 0 || index >= subtitleLines.length) return;
    
    final line = subtitleLines[index];
    
    // Check if video player is in fullscreen mode for different user experience
    final videoPlayerState = _videoPlayerKey.currentState;
    final isInFullscreenMode = videoPlayerState?.isInFullscreenMode() ?? false;
    
    if (isInFullscreenMode) {
      debugPrint('Showing comment dialog for fullscreen mode - line $index');
      
      // In fullscreen mode, find corresponding subtitle and use video player's fullscreen comment dialog
      if (index < _subtitles.length && videoPlayerState != null) {
        final subtitle = _subtitles[index];
        
        // Create a subtitle with current comment for the fullscreen dialog
        final subtitleWithComment = Subtitle(
          index: subtitle.index,
          start: subtitle.start,
          end: subtitle.end,
          text: subtitle.text,
          comment: line.comment,
        );
        
        // Fullscreen controls own their dialog-open lifecycle and duplicate guard.
        videoPlayerState.showFullscreenCommentDialog(
          subtitleWithComment,
          originalText: line.original,
          editedText: line.edited,
        );
        return;
      }
    } else {
      debugPrint('Showing comment dialog for normal mode - line $index');
    }
    
    // Store the current playing state before showing dialog (for normal mode)
    bool wasPlaying = false;
    if (videoPlayerState != null && !isInFullscreenMode) {
      wasPlaying = videoPlayerState.isPlaying();
      debugPrint('Comment dialog opening in normal mode - video was ${wasPlaying ? 'playing' : 'paused'}');
      
      // Pause video if it was playing when comment dialog opens
      if (wasPlaying) {
        videoPlayerState.pause();
        debugPrint('Paused video for comment input in edit screen');
      }
    }
    
    // Flag to track if video has been resumed to prevent double resuming
    bool hasResumed = false;
    
    // Mark dialog as open
    _setEditorState(() => _isCommentDialogOpen = true);
    
    // Normal mode or fallback - use the standard comment dialog
    CommentDialog.show(
      context,
      existingComment: line.comment,
      originalText: line.original,
      editedText: line.edited,
      subtitleIndex: line.index,
      onCommentSaved: (comment) async {
        // If the line is not marked, mark it first
        if (!line.marked) {
          await _toggleMarkLine(index);
        }
        
        // Riverpod migration - delegate to the Riverpod controller which handles all business logic
        await _controller.updateComment(index, comment);
        
        // Update local state from controller state
        final state = _editState;
        _setEditorState(() {
          subtitleLines = state.subtitleLines;
        });
        
        // Update controller
        if (index >= 0 && index < subtitleLines.length) {
          _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
        }
        
        // Update all subtitle displays (video + waveform)
        _updateAllSubtitleDisplays();
        
        if (!mounted) return;
        final modeText = isInFullscreenMode ? 'fullscreen' : 'normal';
        SnackbarHelper.showSuccess(context, 'Comment updated ($modeText mode)');
        
        // Resume video if it was playing before dialog opened and not already resumed
        if (wasPlaying && videoPlayerState != null && !hasResumed) {
          hasResumed = true;
          videoPlayerState.play();
          debugPrint('Resumed video after comment save in edit screen');
        }
      },
      onCommentDeleted: line.comment?.isNotEmpty == true ? () async {
        // Riverpod migration - delegate to the Riverpod controller which handles all business logic
        await _controller.updateComment(index, null);
        
        // Update local state from controller state
        final state = _editState;
        _setEditorState(() {
          subtitleLines = state.subtitleLines;
        });
        
        // Update controller
        if (index >= 0 && index < subtitleLines.length) {
          _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
        }
        
        // Update all subtitle displays (video + waveform)
        _updateAllSubtitleDisplays();
        
        if (!mounted) return;
        SnackbarHelper.showSuccess(context, 'Comment deleted');
        
        // Resume video if it was playing before dialog opened and not already resumed
        if (wasPlaying && videoPlayerState != null && !hasResumed) {
          hasResumed = true;
          videoPlayerState.play();
          debugPrint('Resumed video after comment delete in edit screen');
        }
      } : null,
    ).then((_) {
      // Mark dialog as closed when dismissed
      if (mounted) {
        _setEditorState(() => _isCommentDialogOpen = false);
      }
      
      // This executes when the dialog is dismissed (by canceling without save/delete)
      // Resume video if it was playing before dialog opened and we haven't already resumed it
      if (wasPlaying && videoPlayerState != null && !hasResumed) {
        videoPlayerState.play();
        debugPrint('Resumed video after comment dialog dismissed in edit screen');
      }
    });
  }

  Future<void> _showMarkedLinesModal() async {
    try {
      final markedLines = await _controller.loadMarkedLines();
      final allLinesWithComments = await _controller.loadLinesWithComments();
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (modalContext) => SizedBox(
          height: MediaQuery.of(modalContext).size.height,
          child: MarkedLinesSheet(
            markedLines: markedLines,
            allLinesWithComments: allLinesWithComments,
            onLineSelected: (index) async {
              // Close the modal first using the modal's context
              Navigator.of(modalContext).pop();
              
              // Let the route removal/layout update settle before scrolling.
              await WidgetsBinding.instance.endOfFrame;

              if (!mounted) return;
              
              // Navigate to the selected line
              await _scrollToIndexWithLoading(index + 1); // Convert back to 1-based index
              _highlightIndex(index);
              
              // Seek video to the selected subtitle if video is loaded
              if (_isVideoLoaded) {
                _seekToSubtitle(index);
              }
            },
            onCommentUpdated: (index, comment) async {
              // Update comment in database and refresh UI
              try {
                final success = await _controller.updateComment(index, comment);
                if (!success) throw StateError('Comment update failed');
                // Refresh the subtitle line in UI
                if (index < subtitleLines.length) {
                  _setEditorState(() {
                    subtitleLines[index].comment = comment;
                  });
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
                  
                  // Update all subtitle displays (video + waveform)
                  _updateAllSubtitleDisplays();
                }
                
                SnackbarHelper.showSuccess(context, 
                  comment != null ? 'Comment updated' : 'Comment deleted');
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
              }
            },
            onLineUnmarked: (index) async {
              // Unmark line and delete comment
              try {
                final success = await _controller.unmarkLine(index);
                if (!success) throw StateError('Unmark failed');
                // Refresh the subtitle line in UI
                if (index < subtitleLines.length) {
                  _setEditorState(() {
                    subtitleLines[index].marked = false;
                    subtitleLines[index].comment = null;
                    subtitleLines[index].resolved = false;
                  });
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
                  
                  // Update all subtitle displays (video + waveform)
                  _updateAllSubtitleDisplays();
                }
                
                SnackbarHelper.showSuccess(context, 'Line unmarked and comment deleted');
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the mark. Please try again.');
              }
            },
            onResolvedUpdated: (index, resolved) async {
              // Update resolved status in database
              try {
                final success = await _controller.updateResolved(index, resolved);
                if (!success) throw StateError('Resolved-state update failed');
                // Refresh the subtitle line in UI
                if (index < subtitleLines.length) {
                  _setEditorState(() {
                    subtitleLines[index].resolved = resolved;
                  });
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
                }
                
                SnackbarHelper.showSuccess(context, 
                  resolved ? 'Comment marked as resolved' : 'Comment marked as unresolved');
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the comment status. Please try again.');
              }
            },
            onTextEdited: (index, newText) async {
              // Update edited text in database and refresh UI
              try {
                // Update the subtitle line
                if (index < subtitleLines.length) {
                  final updatedLine = subtitleLines[index];
                  updatedLine.edited = newText;
                  
                  // Save to database
                  await _controller.saveLineChanges(updatedLine);
                  
                  // Update UI
                  _setEditorState(() {
                    subtitleLines[index] = updatedLine;
                  });
                  
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, updatedLine);
                  
                  // Update all subtitle displays (video + waveform)
                  _updateAllSubtitleDisplays();
                  
                  SnackbarHelper.showSuccess(context, 'Subtitle text updated');
                }
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the subtitle text. Please try again.');
              }
            },
          ),
        ),
      );
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not load marked subtitles. Please try again.');
    }
  }

  Future<void> _showMarkedLinesModalWithHighlight(int databaseIndex) async {
    try {
      final markedLines = await _controller.loadMarkedLines();
      final allLinesWithComments = await _controller.loadLinesWithComments();
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => MarkedLinesSheet(
            markedLines: markedLines,
            allLinesWithComments: allLinesWithComments,
            initialHighlightLineIndex: databaseIndex, // Pass the database index to highlight
            onLineSelected: (index) {
              Navigator.of(modalContext).pop();
              _navigateToIndex(index);
              _seekToSubtitle(index);
            },
            onCommentUpdated: (index, comment) async {
              // Update comment in database
              try {
                final success = await _controller.updateComment(index, comment);
                if (!success) throw StateError('Comment update failed');
                // Refresh the subtitle line in UI
                if (index < subtitleLines.length) {
                  _setEditorState(() {
                    subtitleLines[index].comment = comment;
                  });
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
                  
                  // Update all subtitle displays (video + waveform)
                  _updateAllSubtitleDisplays();
                }
                
                SnackbarHelper.showSuccess(context, 
                  comment != null ? 'Comment updated' : 'Comment deleted');
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
              }
            },
            onLineUnmarked: (index) async {
              // Unmark line and delete comment
              try {
                final success = await _controller.unmarkLine(index);
                if (!success) throw StateError('Unmark failed');
                // Refresh the subtitle line in UI
                if (index < subtitleLines.length) {
                  _setEditorState(() {
                    subtitleLines[index].marked = false;
                    subtitleLines[index].comment = null;
                    subtitleLines[index].resolved = false;
                  });
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
                  
                  // Update all subtitle displays (video + waveform)
                  _updateAllSubtitleDisplays();
                }
                
                SnackbarHelper.showSuccess(context, 'Line unmarked and comment deleted');
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the mark. Please try again.');
              }
            },
            onResolvedUpdated: (index, resolved) async {
              // Update resolved status in database
              try {
                final success = await _controller.updateResolved(index, resolved);
                if (!success) throw StateError('Resolved-state update failed');
                // Refresh the subtitle line in UI
                if (index < subtitleLines.length) {
                  _setEditorState(() {
                    subtitleLines[index].resolved = resolved;
                  });
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, subtitleLines[index]);
                }
                
                SnackbarHelper.showSuccess(context, 
                  resolved ? 'Comment marked as resolved' : 'Comment marked as unresolved');
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the comment status. Please try again.');
              }
            },
            onTextEdited: (index, newText) async {
              // Update edited text in database and refresh UI
              try {
                // Update the subtitle line
                if (index < subtitleLines.length) {
                  final updatedLine = subtitleLines[index];
                  updatedLine.edited = newText;
                  
                  // Save to database
                  await _controller.saveLineChanges(updatedLine);
                  
                  // Update UI
                  _setEditorState(() {
                    subtitleLines[index] = updatedLine;
                  });
                  
                  // Update controller
                  _controller.updateSubtitleLineLocally(index, updatedLine);
                  
                  // Update all subtitle displays (video + waveform)
                  _updateAllSubtitleDisplays();
                  
                  SnackbarHelper.showSuccess(context, 'Subtitle text updated');
                }
              } catch (e) {
                SnackbarHelper.showError(context, 'Could not update the subtitle text. Please try again.');
              }
            },
          ),
        ),
      );
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not load marked subtitles. Please try again.');
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
              subtitleCollectionId: widget.subtitleCollectionId,
              onCheckpointRestored: () async {
                // Reload subtitle lines after checkpoint restoration
                _setEditorState(() {
                  subtitleLinesFuture = _controller.loadSubtitleLines();
                });
                
                // Wait for the future to complete and update the UI
                final lines = await subtitleLinesFuture;
                _setEditorState(() {
                  subtitleLines = lines;
                  _controller.replaceSubtitleLinesLocally(lines);
                });
                
                // Update all subtitle displays (video + waveform)
                _updateAllSubtitleDisplays();
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
            subtitleCollectionId: widget.subtitleCollectionId,
            onCheckpointRestored: () async {
              // Reload subtitle lines after checkpoint restoration
              _setEditorState(() {
                subtitleLinesFuture = _controller.loadSubtitleLines();
              });
              
              // Wait for the future to complete and update the UI
              final lines = await subtitleLinesFuture;
              _setEditorState(() {
                subtitleLines = lines;
                _controller.replaceSubtitleLinesLocally(lines);
              });
              
              // Update all subtitle displays (video + waveform)
              _updateAllSubtitleDisplays();
            },
          ),
        ),
      );
    }
  }
}
