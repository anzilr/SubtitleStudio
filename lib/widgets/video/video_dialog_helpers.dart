part of '../video_player_widget.dart';

extension _VideoDialogHelpers on VideoPlayerWidgetState {
  // Show a temporary indicator when seeking forward/backward
  void _showSeekIndicator(BuildContext context, bool isForward) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(
              isForward ? Icons.skip_next : Icons.skip_previous,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Remove after a short duration
    Future.delayed(const Duration(milliseconds: 500), () {
      overlayEntry.remove();
    });
  }
  
  // Method to show comment dialog for marked subtitle (for non-fullscreen mode)
  void showCommentDialog(Subtitle subtitle, BuildContext dialogContext) {
    if (_isCustomFullscreen) {
      // For fullscreen mode, this shouldn't be called as it's handled by _FullscreenControlsWidget
      debugPrint('Warning: showCommentDialog called in fullscreen mode, use _FullscreenControlsWidget instead');
      return;
    }
    
    // Store the current playing state before showing dialog
    final wasPlaying = _player.state.playing;
    debugPrint('Comment dialog opening - video was ${wasPlaying ? 'playing' : 'paused'}');
    
    // Pause video if it was playing when comment dialog opens
    if (wasPlaying) {
      _player.pause();
      debugPrint('Paused video for comment input');
    }
    
    // Flag to track if video has been resumed to prevent double resuming
    bool hasResumed = false;
    
    // For normal mode, use the standard CommentDialog.show() which handles orientation automatically
    CommentDialog.show(
      dialogContext,
      existingComment: subtitle.comment,
      onCommentSaved: (comment) async {
        // If the subtitle is not marked, mark it first
        if (!subtitle.marked && widget.onSubtitleMarked != null) {
          try {
            debugPrint('Marking subtitle before saving comment in normal mode');
            await _awaitCallbackResult(
              widget.onSubtitleMarked!(subtitle.index, true),
            );
          } catch (e) {
            debugPrint('Error marking subtitle: $e');
          }
        }
        
        if (mounted && widget.onSubtitleCommentUpdated != null) {
          try {
            await _awaitCallbackResult(
              widget.onSubtitleCommentUpdated!(subtitle.index, comment),
            );
          } catch (e) {
            debugPrint('Error updating subtitle comment: $e');
          }
        }
  
        if (wasPlaying && mounted && !hasResumed) {
          hasResumed = true;
          _player.play();
          debugPrint('Resumed video after comment save');
        }
      },
      onCommentDeleted: () async {
        if (mounted && widget.onSubtitleCommentUpdated != null) {
          try {
            await _awaitCallbackResult(
              widget.onSubtitleCommentUpdated!(subtitle.index, null),
            );
          } catch (e) {
            debugPrint('Error deleting subtitle comment: $e');
          }
        }
  
        if (wasPlaying && mounted && !hasResumed) {
          hasResumed = true;
          _player.play();
          debugPrint('Resumed video after comment delete');
        }
      },
    ).then((_) {
      // This executes when the dialog is dismissed (by canceling without save/delete)
      // Resume video if it was playing before dialog opened and we haven't already resumed it
      if (wasPlaying && mounted && !hasResumed) {
        _player.play();
        debugPrint('Resumed video after comment dialog dismissed');
      }
    });
  }
}
