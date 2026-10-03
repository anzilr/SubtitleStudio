part of '../video_player_widget.dart';

extension VideoPlayerTrackActions on VideoPlayerWidgetState {
  // Audio track management methods
  
  /// Save selected audio track to preferences
  Future<void> _saveAudioTrackSelection(AudioTrack track) async {
    try {
      debugPrint('Saving audio track for collection ${widget.subtitleCollectionId}: ${track.title} (${track.language}) [ID: ${track.id}]');
      await _preferencesRepository.saveSelectedAudioTrack(
        widget.subtitleCollectionId,
        trackId: track.id,
        trackTitle: track.title,
        trackLanguage: track.language,
      );
      debugPrint('✓ Audio track saved successfully');
    } catch (e) {
      debugPrint('✗ Error saving audio track selection: $e');
    }
  }
  
  /// Restore the saved audio track after Media Kit reports tracks.
  Future<void> _restoreSavedAudioTrack(
    List<AudioTrack> availableTracks,
  ) async {
    if (!_isInitializingTracks ||
        _audioTrackRestoreInProgress ||
        availableTracks.isEmpty) {
      return;
    }
  
    _audioTrackRestoreInProgress = true;
  
    try {
      final savedTrack = await _preferencesRepository.getSelectedAudioTrack(
        widget.subtitleCollectionId,
      );
      if (!mounted) return;
  
      final savedTrackId = savedTrack.id;
      if (savedTrackId == null) {
        debugPrint('No saved audio track found, using default');
        return;
      }
  
      final matchingTrack = availableTracks.firstWhere(
        (track) => track.id == savedTrackId,
        orElse: () => availableTracks.first,
      );
  
      if (matchingTrack.id != _currentAudioTrack?.id) {
        await _player.setAudioTrack(matchingTrack);
        debugPrint(
          'Restored audio track: '
          '${matchingTrack.title} (${matchingTrack.language})',
        );
      }
    } catch (e) {
      debugPrint('Error restoring saved audio track: $e');
    } finally {
      _audioTrackRestoreInProgress = false;
      if (mounted) {
        _setVideoState(() {
          _isInitializingTracks = false;
        });
      }
    }
  }
  
  /// Get all available audio tracks in the current video
  /// Returns empty list if no tracks are available or video is not loaded
  List<AudioTrack> getAvailableAudioTracks() {
    return _availableAudioTracks;
  }
  
  /// Get the currently selected audio track
  /// Returns null if no track is selected
  AudioTrack? getCurrentAudioTrack() {
    return _currentAudioTrack;
  }
  
  /// Switch to a specific audio track
  /// [track] The audio track to switch to
  Future<void> setAudioTrack(AudioTrack track) async {
    await _player.setAudioTrack(track);
  }
  
  // Subtitle track management methods
  
  /// Get all available subtitle tracks in the current video
  /// Returns empty list if no tracks are available or video is not loaded
  List<SubtitleTrack> getAvailableSubtitleTracks() {
    return _availableSubtitleTracks;
  }
  
  /// Get the currently selected subtitle track
  /// Returns null if no track is selected
  SubtitleTrack? getCurrentSubtitleTrack() {
    return _currentSubtitleTrack;
  }
  
  /// Switch to a specific subtitle track
  /// [track] The subtitle track to switch to
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
  }
  
  /// Get the current video file path
  /// Returns the original video path, not the converted file descriptor URI
  String? getVideoPath() {
    // Return the original video path from the widget constructor
    // This ensures we get the content URI for Android SAF support
    // rather than the converted file descriptor URI from media kit
    return widget.videoPath;
  }
  
  /// Get detailed subtitle track information using FFmpeg
  /// This provides more detailed information than media_kit tracks
  Future<List<Map<String, dynamic>>> getDetailedSubtitleTracks() async {
    final videoPath = getVideoPath();
    if (videoPath == null) return [];
    
    try {
      final ffmpeg = FFmpegHelper();
      return await ffmpeg.getSubtitleTracks(videoPath);
    } catch (e) {
      debugPrint('Error getting detailed subtitle tracks: $e');
      return [];
    }
  }
  
  /// Extract subtitle content from a specific track
  /// [trackIndex] The subtitle index (0-based) for FFmpeg extraction (not the stream index)
  /// Returns the content as a string, or null if extraction fails
  Future<String?> extractSubtitleTrackContent(int trackIndex) async {
    final videoPath = getVideoPath();
    if (videoPath == null) return null;
    
    try {
      final ffmpeg = FFmpegHelper();
      // Create a temporary directory for extraction
      final tempDir = Directory.systemTemp;
      
      final extractedPath = await ffmpeg.extractSubtitle(
        videoPath,
        tempDir.path,
        trackIndex,
      );
      
      // Read the extracted subtitle content
      final extractedFile = File(extractedPath);
      if (await extractedFile.exists()) {
        final content = await extractedFile.readAsString();
        // Clean up the temporary file
        await extractedFile.delete();
        return content;
      }
    } catch (e) {
      debugPrint('Error extracting subtitle track content: $e');
    }
    
    return null;
  }
  
  /// Show dialog to select from available audio tracks
  /// Displays a snackbar message if no additional tracks are available
  void showAudioTrackDialog(BuildContext context) {
    // Use the State's context as a safe parent context and guard against disposed state
    if (!mounted) return;
    final BuildContext safeContext = this.context;
  
    if (_availableAudioTracks.isEmpty || _availableAudioTracks.length <= 1) {
      final messenger = ScaffoldMessenger.maybeOf(safeContext) ?? ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No additional audio tracks available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
  
    // Ensure state still mounted before showing dialog
    if (!mounted) return;
  
    showDialog(
      context: safeContext,
      builder: (BuildContext context) {
        return AlertDialog(
          scrollable: true,
          title: Row(
            children: [
              Icon(Icons.audiotrack, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Audio Track'),
            ],
          ),
          content: SizedBox(
            width: double.minPositive,
            child: RadioGroup<String>(
              groupValue: _currentAudioTrack?.id,
              onChanged: (value) {
                if (value == null) return;
                final track = _availableAudioTracks.firstWhere(
                  (candidate) => candidate.id == value,
                );
                setAudioTrack(track);
                Navigator.of(context).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _availableAudioTracks.map((track) {
                  return _buildAudioTrackOption(context, track);
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildAudioTrackOption(BuildContext context, AudioTrack track) {
    final isSelected = _currentAudioTrack?.id == track.id;
    
    // Get track display name
    String trackName = 'Track ${track.id}';
    if (track.id == 'auto') {
      trackName = 'Auto';
    } else if (track.id == 'no') {
      trackName = 'Off';
    } else if (track.title?.isNotEmpty == true) {
      trackName = track.title!;
    } else if (track.language?.isNotEmpty == true) {
      trackName = 'Track ${track.id} (${track.language})';
    }
    
    return InkWell(
      onTap: () {
        setAudioTrack(track);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Theme.of(context).primaryColor) : null,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: track.id,
              activeColor: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trackName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.onSurface : null,
                    ),
                  ),
                  if (track.language?.isNotEmpty == true && track.title?.isNotEmpty == true)
                    Text(
                      'Language: ${track.language}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
  
  // Show speed selection dialog
  void showSpeedDialog(BuildContext context) {
    // Prefer using the state's context to avoid passing a potentially disposed child context
    if (!mounted) return;
    final BuildContext safeContext = this.context;
  
    showDialog(
      context: safeContext,
      builder: (BuildContext context) {
        return AlertDialog(
          scrollable: true,
          title: Row(
            children: [
              Icon(Icons.speed, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Playback Speed'),
            ],
          ),
          content: SizedBox(
            width: double.minPositive,
            child: RadioGroup<double>(
              groupValue: _currentSpeed,
              onChanged: (value) {
                if (value == null) return;
                setPlaybackSpeed(value);
                Navigator.of(context).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSpeedOption(context, 0.25, '0.25x'),
                  _buildSpeedOption(context, 0.5, '0.5x'),
                  _buildSpeedOption(context, 0.75, '0.75x'),
                  _buildSpeedOption(context, 1.0, '1.0x (Normal)'),
                  _buildSpeedOption(context, 1.25, '1.25x'),
                  _buildSpeedOption(context, 1.5, '1.5x'),
                  _buildSpeedOption(context, 1.75, '1.75x'),
                  _buildSpeedOption(context, 2.0, '2.0x'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildSpeedOption(BuildContext context, double speed, String label) {
    final isSelected = _currentSpeed == speed;
    return InkWell(
      onTap: () {
        setPlaybackSpeed(speed);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha:0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Theme.of(context).primaryColor) : null,
        ),
        child: Row(
          children: [
            Radio<double>(
              value: speed,
              activeColor: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).colorScheme.onSurface : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
