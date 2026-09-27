part of '../../screen_edit.dart';

extension _EditInitializationHelpers on _EditScreenState {
  Future<void> _createInitialCheckpoint() async {
    try {
      await CheckpointManager.createInitialSnapshot(
        sessionId: widget.sessionId,
        subtitleCollectionId: widget.subtitleCollectionId,
      );
      if (kDebugMode) {
        print('Initial checkpoint snapshot created for session ${widget.sessionId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create initial checkpoint snapshot: $e');
      }
    }
  }

  // Ensure video player gets subtitles after widget initialization.
  void _ensureVideoPlayerSubtitles() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_updateVideoPlayerWhenReady());
    });
  }

  Future<void> _updateVideoPlayerWhenReady() async {
    final player = await waitForVideoPlayerReady(_videoPlayerKey);
    if (!mounted || player == null || _subtitles.isEmpty) return;
    _updateVideoPlayerSubtitles();
  }

  // Helper method to update video player subtitles
  void _updateVideoPlayerSubtitles() {
    if (_videoPlayerKey.currentState != null && _subtitles.isNotEmpty) {
      _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
      
      // Also update secondary subtitles if they exist
      if (_secondarySubtitles.isNotEmpty && _showSecondarySubtitles) {
        _videoPlayerKey.currentState!.updateSecondarySubtitles(_secondarySubtitles);
      }
    }
    
    // Update waveform with subtitle lines
    if (_waveformKey.currentState != null && subtitleLines.isNotEmpty) {
      _waveformKey.currentState!.updateSubtitles(subtitleLines);
    }
  }

  // Helper method to update both video and waveform when subtitles change
  void _updateAllSubtitleDisplays() {
    // Regenerate subtitles for video player if needed
    if (subtitleLines.isNotEmpty) {
      _subtitles = _generateSubtitles(subtitleLines);
    }
    
    // Update video player
    if (_videoPlayerKey.currentState != null) {
      _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
    }
    
    // Update waveform
    if (_waveformKey.currentState != null) {
      _waveformKey.currentState!.updateSubtitles(subtitleLines);
    }
  }

  // Build subtitle list interface

}
