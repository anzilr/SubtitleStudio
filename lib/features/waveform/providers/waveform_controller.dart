import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/features/waveform/bloc/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/bloc/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/services/audio_processor.dart';
import 'package:subtitle_studio/database/models/preferences_model.dart';

/// Disposable audio processor dependency for the Waveform feature.
final waveformAudioProcessorProvider = Provider<AudioProcessor>((ref) {
  final processor = AudioProcessor();
  ref.onDispose(processor.dispose);
  return processor;
});

final waveformControllerProvider =
    NotifierProvider<WaveformController, WaveformState>(
  WaveformController.new,
);

/// Riverpod state controller for waveform processing and interaction.
///
/// Event classes are retained during migration so gesture behavior can move
/// from BLoC without simultaneously rewriting every caller.
class WaveformController extends Notifier<WaveformState> {
  bool _disposed = false;

  AudioProcessor get _audioProcessor =>
      ref.read(waveformAudioProcessorProvider);

  @override
  WaveformState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
    });
    return const WaveformInitial();
  }

  void _setState(WaveformState nextState) {
    if (!_disposed) {
      state = nextState;
    }
  }

  Future<void> dispatch(WaveformEvent event) async {
    if (event is LoadAudioFile) {
      await _onLoadAudioFile(event);
      return;
    }
    if (event is ZoomIn) {
      _onZoomIn(event);
      return;
    }
    if (event is ZoomOut) {
      _onZoomOut(event);
      return;
    }
    if (event is SetZoomLevel) {
      _onSetZoomLevel(event);
      return;
    }
    if (event is UpdateScrollPosition) {
      _onUpdateScrollPosition(event);
      return;
    }
    if (event is UpdatePlaybackPosition) {
      _onUpdatePlaybackPosition(event);
      return;
    }
    if (event is SeekToTime) {
      _onSeekToTime(event);
      return;
    }
    if (event is ToggleAutoScroll) {
      _onToggleAutoScroll(event);
      return;
    }
    if (event is UpdateVerticalZoom) {
      _onUpdateVerticalZoom(event);
      return;
    }
    if (event is ClearWaveform) {
      _onClearWaveform(event);
      return;
    }
    if (event is UpdateViewportWidth) {
      _onUpdateViewportWidth(event);
      return;
    }
    if (event is EnterTimeEditMode) {
      _onEnterTimeEditMode(event);
      return;
    }
    if (event is ExitTimeEditMode) {
      _onExitTimeEditMode(event);
      return;
    }
    if (event is UpdateTempStartTime) {
      _onUpdateTempStartTime(event);
      return;
    }
    if (event is UpdateTempEndTime) {
      _onUpdateTempEndTime(event);
      return;
    }
    if (event is ApplyTimeChanges) {
      _onApplyTimeChanges(event);
      return;
    }
    if (event is ForceRepaint) {
      _onForceRepaint(event);
      return;
    }
    if (event is EnterAddLineMode) {
      _onEnterAddLineMode(event);
      return;
    }
    if (event is ExitAddLineMode) {
      _onExitAddLineMode(event);
      return;
    }
    if (event is UpdateAddLineStartTime) {
      _onUpdateAddLineStartTime(event);
      return;
    }
    if (event is UpdateAddLineEndTime) {
      _onUpdateAddLineEndTime(event);
      return;
    }
    if (event is ToggleOverlapMode) {
      _onToggleOverlapMode(event);
      return;
    }
    if (event is ToggleMagnetSnap) {
      _onToggleMagnetSnap(event);
      return;
    }
    if (event is ScrollSeekToTime) {
      _onScrollSeekToTime(event);
      return;
    }
    throw UnsupportedError('Unsupported waveform event: ${event.runtimeType}');
  }

  /// Load audio file and generate waveform
  Future<void> _onLoadAudioFile(
    LoadAudioFile event,
  ) async {
    try {
      _setState(WaveformLoading(event.filePath, progress: 0.0));

      // Get selected audio track ID if available
      String? audioTrackId = event.audioTrackId;
      if (audioTrackId == null && event.subtitleCollectionId != null) {
        // Try to fetch from saved preferences
        audioTrackId = await PreferencesModel.getSelectedAudioTrackId(
          event.subtitleCollectionId!,
        );
      }

      // Process audio in background (with caching if subtitle collection ID provided)
      final buffer = await _audioProcessor.processAudioFile(
        event.filePath,
        subtitleCollectionId: event.subtitleCollectionId,
        audioTrackId: audioTrackId,
        onProgress: (progress) {
          // Emit loading progress updates
          if (!_disposed) {
            _setState(WaveformLoading(event.filePath, progress: progress));
          }
        },
      );

      // Start with zoom level 7 (default)
      int defaultZoomIndex = 7.clamp(0, buffer.zoomLevelCount - 1);
      double defaultVerticalZoom = 1.7; // Default 170% for better visibility
      
      // Try to load saved zoom levels if subtitle collection ID is provided
      if (event.subtitleCollectionId != null) {
        final savedZoom = await PreferencesModel.getWaveformZoomLevels(
          event.subtitleCollectionId!,
        );
        if (savedZoom != null) {
          defaultZoomIndex = (savedZoom['zoomIndex'] as int).clamp(0, buffer.zoomLevelCount - 1);
          defaultVerticalZoom = (savedZoom['verticalZoom'] as double).clamp(0.5, 3.0);
        }
      }

      _setState(WaveformReady(
        buffer: buffer,
        currentZoomIndex: defaultZoomIndex,
        scrollPosition: 0.0,
        playbackPosition: Duration.zero,
        autoScroll: true,
        viewportWidth: 800.0,
        sourceFilePath: event.filePath,
        verticalZoom: defaultVerticalZoom,
        subtitleCollectionId: event.subtitleCollectionId,
      ));
    } catch (e) {
      _setState(WaveformError(
        'Failed to load audio: ${e.toString()}',
        filePath: event.filePath,
      ));
    }
  }

  /// Zoom in (increase detail = go to lower zoom level index)
  void _onZoomIn(ZoomIn event) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      if (currentState.canZoomIn) {
        final newZoomIndex = currentState.currentZoomIndex - 1; // Decrease index for more detail
        final centerPixel = currentState.scrollPosition +
            currentState.viewportWidth / 2;
        
        // Adjust scroll to keep center position
        final centerTime = currentState.pixelToTime(centerPixel);
        final newState = currentState.copyWith(currentZoomIndex: newZoomIndex);
        final newCenterPixel = newState.timeToPixel(centerTime);
        final newScroll = newCenterPixel - currentState.viewportWidth / 2;
        
        // Calculate max scroll, ensuring it's not negative
        final maxScroll = (newState.totalWidth - currentState.viewportWidth).clamp(0.0, double.infinity);
        
        _setState(newState.copyWith(
          scrollPosition: newScroll.clamp(0.0, maxScroll),
        ));
        
        // Save zoom level to database
        _saveZoomLevels(newState);
      }
    }
  }

  /// Zoom out (decrease detail = go to higher zoom level index)
  void _onZoomOut(ZoomOut event) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      if (currentState.canZoomOut) {
        final newZoomIndex = currentState.currentZoomIndex + 1; // Increase index for less detail
        final centerPixel = currentState.scrollPosition +
            currentState.viewportWidth / 2;
        
        // Adjust scroll to keep center position
        final centerTime = currentState.pixelToTime(centerPixel);
        final newState = currentState.copyWith(currentZoomIndex: newZoomIndex);
        final newCenterPixel = newState.timeToPixel(centerTime);
        final newScroll = newCenterPixel - currentState.viewportWidth / 2;
        
        // Calculate max scroll, ensuring it's not negative
        final maxScroll = (newState.totalWidth - currentState.viewportWidth).clamp(0.0, double.infinity);
        
        _setState(newState.copyWith(
          scrollPosition: newScroll.clamp(0.0, maxScroll),
        ));
        
        // Save zoom level to database
        _saveZoomLevels(newState);
      }
    }
  }

  /// Set specific zoom level
  void _onSetZoomLevel(SetZoomLevel event) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      if (event.zoomIndex >= 0 &&
          event.zoomIndex < currentState.buffer.zoomLevelCount) {
        final newState = currentState.copyWith(currentZoomIndex: event.zoomIndex);
        _setState(newState);
        
        // Save zoom level to database
        _saveZoomLevels(newState);
      }
    }
  }

  /// Update scroll position
  void _onUpdateScrollPosition(
    UpdateScrollPosition event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      final maxScroll = (currentState.totalWidth - currentState.viewportWidth).clamp(0.0, double.infinity);
      final clampedScroll = event.scrollPosition.clamp(0.0, maxScroll);
      _setState(currentState.copyWith(scrollPosition: clampedScroll));
    }
  }

  /// Update playback position
  void _onUpdatePlaybackPosition(
    UpdatePlaybackPosition event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(playbackPosition: event.position));

      // Auto-scroll if enabled - smart scrolling behavior
      if (currentState.autoScroll) {
        final playbackPixel = currentState.timeToPixel(event.position);
        final centerPosition = currentState.viewportWidth / 2;
        final maxScroll = (currentState.totalWidth - currentState.viewportWidth).clamp(0.0, double.infinity);
        
        // Smart scrolling:
        // - Before center: indicator moves from left to center (no scroll)
        // - After center to near end: indicator fixed at center, waveform scrolls
        // - Near end: indicator moves from center to right edge (no scroll)
        
        if (playbackPixel <= centerPosition) {
          // Beginning: indicator moves from left, no scroll
          _onUpdateScrollPosition(UpdateScrollPosition(0.0));
        } else if (playbackPixel >= currentState.totalWidth - centerPosition) {
          // Near end: indicator moves to right, scroll to max
          _onUpdateScrollPosition(UpdateScrollPosition(maxScroll));
        } else {
          // Middle: keep indicator centered, scroll waveform
          final newScroll = playbackPixel - centerPosition;
          _onUpdateScrollPosition(UpdateScrollPosition(newScroll.clamp(0.0, maxScroll)));
        }
      }
    }
  }

  /// Seek to specific time
  void _onSeekToTime(SeekToTime event) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      final targetPixel = currentState.timeToPixel(event.time);
      final newScroll = targetPixel - currentState.viewportWidth / 2;
      final maxScroll = (currentState.totalWidth - currentState.viewportWidth).clamp(0.0, double.infinity);

      _setState(currentState.copyWith(
        playbackPosition: event.time,
        scrollPosition: newScroll.clamp(0.0, maxScroll),
      ));
    }
  }

  /// Toggle auto-scroll
  void _onToggleAutoScroll(
    ToggleAutoScroll event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(autoScroll: !currentState.autoScroll));
    }
  }

  /// Update vertical zoom (amplitude)
  void _onUpdateVerticalZoom(
    UpdateVerticalZoom event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      // Clamp zoom between 0.5x and 3.0x
      final clampedZoom = event.zoom.clamp(0.5, 3.0);
      final newState = currentState.copyWith(verticalZoom: clampedZoom);
      _setState(newState);
      
      // Save zoom level to database
      _saveZoomLevels(newState);
    }
  }

  /// Clear waveform
  void _onClearWaveform(ClearWaveform event) {
    _setState(const WaveformInitial());
  }

  /// Update viewport width
  void _onUpdateViewportWidth(
    UpdateViewportWidth event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(viewportWidth: event.width));
    }
  }

  /// Enter time edit mode for a subtitle
  void _onEnterTimeEditMode(
    EnterTimeEditMode event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(
        isEditMode: true,
        editingSubtitleIndex: event.subtitleIndex,
        tempStartTime: null,
        tempEndTime: null,
        clearTempStartTime: true,
        clearTempEndTime: true,
      ));
    }
  }

  /// Exit time edit mode without saving
  void _onExitTimeEditMode(
    ExitTimeEditMode event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(
        isEditMode: false,
        clearEditingSubtitleIndex: true,
        clearTempStartTime: true,
        clearTempEndTime: true,
      ));
    }
  }

  /// Update temporary start time during edit
  void _onUpdateTempStartTime(
    UpdateTempStartTime event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      if (currentState.isEditMode) {
        _setState(currentState.copyWith(tempStartTime: event.startTime));
      }
    }
  }

  /// Update temporary end time during edit
  void _onUpdateTempEndTime(
    UpdateTempEndTime event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      if (currentState.isEditMode) {
        _setState(currentState.copyWith(tempEndTime: event.endTime));
      }
    }
  }

  /// Apply time changes (handled in widget as it needs database access)
  void _onApplyTimeChanges(
    ApplyTimeChanges event,
  ) {
    // This event is primarily for signaling - actual save is handled in widget
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(
        isEditMode: false,
        clearEditingSubtitleIndex: true,
        clearTempStartTime: true,
        clearTempEndTime: true,
      ));
    }
  }

  /// Force waveform repaint by emitting a new state
  void _onForceRepaint(
    ForceRepaint event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      // Emit a copy of the state to trigger rebuild
      _setState(currentState.copyWith());
    }
  }

  /// Enter add line mode
  void _onEnterAddLineMode(
    EnterAddLineMode event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(
        isAddLineMode: true,
        addLineStartTime: null,
        addLineEndTime: null,
        clearAddLineStartTime: true,
        clearAddLineEndTime: true,
      ));
    }
  }

  /// Exit add line mode without adding
  void _onExitAddLineMode(
    ExitAddLineMode event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(
        isAddLineMode: false,
        clearAddLineStartTime: true,
        clearAddLineEndTime: true,
      ));
    }
  }

  /// Update add line start time during drag
  void _onUpdateAddLineStartTime(
    UpdateAddLineStartTime event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      if (currentState.isAddLineMode) {
        _setState(currentState.copyWith(addLineStartTime: event.startTime));
      }
    }
  }

  /// Update add line end time during drag
  void _onUpdateAddLineEndTime(
    UpdateAddLineEndTime event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      if (currentState.isAddLineMode) {
        _setState(currentState.copyWith(addLineEndTime: event.endTime));
      }
    }
  }

  /// Toggle overlap mode (allow overlapping with other subtitles)
  void _onToggleOverlapMode(
    ToggleOverlapMode event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(allowOverlap: !currentState.allowOverlap));
    }
  }

  /// Toggle magnet snap (snap to nearby playhead or subtitle)
  void _onToggleMagnetSnap(
    ToggleMagnetSnap event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _setState(currentState.copyWith(magnetSnapEnabled: !currentState.magnetSnapEnabled));
    }
  }

  /// Update scroll position during manual scrolling (for video seeking)
  /// This is separate from UpdateScrollPosition to handle video syncing
  void _onScrollSeekToTime(
    ScrollSeekToTime event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      final maxScroll = (currentState.totalWidth - currentState.viewportWidth).clamp(0.0, double.infinity);
      final clampedScroll = event.scrollPosition.clamp(0.0, maxScroll);
      _setState(currentState.copyWith(scrollPosition: clampedScroll));
      // Video seeking is handled in the widget via widget.onSeek callback
    }
  }

  /// Save zoom levels to database
  void _saveZoomLevels(WaveformReady state) {
    // Only save if we have a subtitle collection ID
    if (state.subtitleCollectionId != null) {
      // Use fire-and-forget pattern to avoid blocking
      PreferencesModel.saveWaveformZoomLevels(
        subtitleCollectionId: state.subtitleCollectionId!,
        zoomIndex: state.currentZoomIndex,
        verticalZoom: state.verticalZoom,
      ).catchError((error) {
        // Silently catch errors - zoom preferences are not critical
        // ignore: avoid_print
        print('Failed to save waveform zoom levels: $error');
      });
    }
  }

}
