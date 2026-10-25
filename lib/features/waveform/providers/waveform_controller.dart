import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/services/audio_processor.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_subtitle_repository.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';

/// Disposable audio processor dependency for the Waveform feature.
final waveformAudioProcessorProvider = Provider<AudioProcessor>((ref) {
  final processor = AudioProcessor(
    ref.watch(waveformPreferencesRepositoryProvider),
  );
  ref.onDispose(processor.dispose);
  return processor;
});

final waveformSubtitleRepositoryProvider =
    Provider<WaveformSubtitleRepository>(
  (ref) => WaveformSubtitleRepository(ref.watch(isarProvider)),
);

final waveformPreferencesRepositoryProvider =
    Provider<WaveformPreferencesRepository>(
  (ref) => WaveformPreferencesRepository(ref.watch(isarProvider)),
);

final waveformControllerProvider =
    NotifierProvider<WaveformController, WaveformState>(
  WaveformController.new,
);

/// Riverpod state controller for waveform processing and interaction.
///
/// Event classes are retained during migration so gesture behavior can move
/// from BLoC without simultaneously rewriting every caller.
class WaveformController extends Notifier<WaveformState> {
  int _desktopFineZoomCount = 0;

  /// Finer desktop zoom levels use on-demand peak tiles. Allocating eager
  /// full-track arrays here would multiply memory use for long recordings.
  static WaveformBuffer extendDesktopFineZoom(WaveformBuffer source) {
    if (source.zoomLevels.isEmpty || source.sampleRate <= 0) return source;
    final currentMinimum = source.zoomLevels.first.samplesPerPixel;
    // Approx. five seconds across an 850px editing viewport. Actual display
    // width is still accounted for by WaveformReady's time-to-pixel mapping.
    final target = (source.sampleRate * 5 ~/ 850).clamp(1, currentMinimum);
    if (target >= currentMinimum) return source;
    final finer = <int>[target];
    var next = target;
    while (next * 3 ~/ 2 < currentMinimum && finer.length < 16) {
      next = (next * 3 ~/ 2).clamp(next + 1, currentMinimum - 1);
      finer.add(next);
    }
    final newLevels = finer.toSet().toList()..sort();
    return WaveformBuffer(
      rawData: source.rawData,
      defaultZoomIndex: source.defaultZoomIndex + newLevels.length,
      zoomLevels: [
        for (final spp in newLevels)
          ZoomLevel.metadata(
            samplesPerPixel: spp,
            pixelCount: (source.rawData.totalSamples + spp - 1) ~/ spp,
            channels: source.channels,
          ),
        ...source.zoomLevels,
      ],
    );
  }

  bool _disposed = false;
  int _loadEpoch = 0;
  int _stateWriteGeneration = 0;
  bool _manualScrubActive = false;
  DateTime? _lastManualScrubUpdate;
  Duration? _pendingSeekPosition;
  DateTime? _pendingSeekAt;

  static const _seekSettleWindow = Duration(seconds: 2);
  static const _seekAckTolerance = Duration(milliseconds: 250);

  /// Manual movement owns the visible playhead until the final media seek
  /// settles. Native position callbacks during this period can describe an
  /// earlier seek, and must not drag the viewport backwards.
  void beginManualScrub() {
    if (state is! WaveformReady) return;
    _manualScrubActive = true;
    _lastManualScrubUpdate = DateTime.now();
    _pendingSeekPosition = null;
    _pendingSeekAt = null;
  }

  void completeManualScrub(Duration finalTarget) {
    if (!_manualScrubActive) return;
    _manualScrubActive = false;
    _lastManualScrubUpdate = null;
    _holdPositionUntilSettled(finalTarget);
  }

  void cancelManualScrub() {
    _manualScrubActive = false;
    _lastManualScrubUpdate = null;
    _pendingSeekPosition = null;
    _pendingSeekAt = null;
  }

  void _holdPositionUntilSettled(Duration position) {
    _pendingSeekPosition = position;
    _pendingSeekAt = DateTime.now();
  }

  AudioProcessor get _audioProcessor =>
      ref.read(waveformAudioProcessorProvider);

  WaveformPreferencesRepository get _preferences =>
      ref.read(waveformPreferencesRepositoryProvider);

  @override
  WaveformState build() {
    _disposed = false;
    // Resolve the dependency while provider access is valid; onDispose
    // callbacks may not call ref.read or modify the provider graph.
    final processor = ref.read(waveformAudioProcessorProvider);
    ref.onDispose(() {
      _disposed = true;
      _stateWriteGeneration++; // Ignore any queued build-phase emissions.
      _loadEpoch++; // Invalidate pending processing and progress callbacks.
      processor.cancelActive();
    });
    return const WaveformInitial();
  }

  void _setState(WaveformState nextState) {
    if (_disposed) return;
    final writeGeneration = ++_stateWriteGeneration;
    // ProviderContainer is also used in non-widget tests and services,
    // where the Flutter scheduler binding may not exist at all.
    SchedulerBinding? scheduler;
    try {
      scheduler = SchedulerBinding.instance;
    } catch (_) {
      scheduler = null;
    }
    if (scheduler?.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // A native audio callback or widget lifecycle hook can arrive while
      // Flutter is building. Riverpod forbids modifying providers here.
      // Retain only the latest state; ClearWaveform/new loads invalidate older
      // queued writes, and provider disposal invalidates the callback.
      scheduler!.addPostFrameCallback((_) {
        if (!_disposed && writeGeneration == _stateWriteGeneration) {
          state = nextState;
        }
      });
      return;
    }
    state = nextState;
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
    if (event is WaveformTrackSelectionFailed) {
      _onTrackSelectionFailed(event);
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
    cancelManualScrub();
    final epoch = ++_loadEpoch;
    bool isCurrent() => !_disposed && _loadEpoch == epoch;
    // Kill old platform decoding as well as ignoring late Riverpod results.
    _audioProcessor.cancelActive();
    var currentProgress = 0.0;
    Duration? processedAudioTime;
    try {
      _setState(WaveformLoading(event.filePath,
        progress: 0.0,
        totalAudioTime: event.mediaDuration,
      ));

      // Get selected audio track ID if available
      String? audioTrackId = event.audioTrackId;
      if (audioTrackId == null &&
          event.useSavedAudioTrackPreference &&
          event.subtitleCollectionId != null) {
        // Try to fetch from saved preferences
        audioTrackId = await _preferences.getSelectedAudioTrackId(
          event.subtitleCollectionId!,
        );
        if (!isCurrent()) return;
      }

      // Process audio in background (with caching if subtitle collection ID provided)
      final generatedBuffer = await _audioProcessor.processAudioFile(
        event.filePath,
        subtitleCollectionId: event.subtitleCollectionId,
        audioTrackId: audioTrackId,
        onProgress: (progress) {
          if (!isCurrent()) return;
          currentProgress = progress;
          _setState(WaveformLoading(event.filePath,
            progress: progress,
            processedAudioTime: processedAudioTime,
            totalAudioTime: event.mediaDuration,
          ));
        },
        onDecodedAudioTime: (time) {
          if (!isCurrent()) return;
          processedAudioTime = time;
          _setState(WaveformLoading(event.filePath,
            progress: currentProgress,
            processedAudioTime: time,
            totalAudioTime: event.mediaDuration,
          ));
        },
      );

      if (!isCurrent()) return;
      // Desktop Studio Dock gains fine-grained zoom without changing the
      // Android/mobile zoom ladder or its original eager samples.
      final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      final buffer = isDesktop
          ? extendDesktopFineZoom(generatedBuffer) : generatedBuffer;
      _desktopFineZoomCount = buffer.zoomLevelCount - generatedBuffer.zoomLevelCount;
      // Start with zoom level 7 (default)
      int defaultZoomIndex =
          7.clamp(0, generatedBuffer.zoomLevelCount - 1) + _desktopFineZoomCount;
      double defaultVerticalZoom = 1.7; // Default 170% for better visibility
      
      // Try to load saved zoom levels if subtitle collection ID is provided
      if (event.subtitleCollectionId != null) {
        final savedZoom = await _preferences.getWaveformZoomLevels(
          event.subtitleCollectionId!,
        );
        if (!isCurrent()) return;
        if (savedZoom != null) {
          defaultZoomIndex =
              savedZoom.zoomIndex.clamp(0, generatedBuffer.zoomLevelCount - 1) +
                  _desktopFineZoomCount;
          defaultVerticalZoom = savedZoom.verticalZoom.clamp(0.5, 8.0);
        }
      }

      if (!isCurrent()) return;
      _setState(WaveformReady(
        buffer: buffer,
        currentZoomIndex: defaultZoomIndex,
        scrollPosition: 0.0,
        playbackPosition: Duration.zero,
        autoScroll: true,
        viewportWidth: 800.0,
        sourceFilePath: event.filePath,
        audioTrackId: audioTrackId,
        verticalZoom: defaultVerticalZoom,
        subtitleCollectionId: event.subtitleCollectionId,
      ));
    } catch (e) {
      if (!isCurrent()) return;
      // Failed media adapters and repositories can throw path-bearing errors.
      // Only explicitly path-free processor failures may reach the UI.
      final detail = e is WaveformProcessingFailure
          ? e.message
          : 'Unable to load waveform audio. Check media access and try again.';
      _setState(WaveformError(
        'Failed to load audio: $detail',
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
        
        _setState(newState.copyWith(
          scrollPosition: newState.clampScrollPosition(newScroll),
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
        
        _setState(newState.copyWith(
          scrollPosition: newState.clampScrollPosition(newScroll),
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
      final clampedScroll = currentState.clampScrollPosition(event.scrollPosition);
      _setState(currentState.copyWith(scrollPosition: clampedScroll));
    }
  }

  /// Update playback position
  void _onUpdatePlaybackPosition(
    UpdatePlaybackPosition event,
  ) {
    if (state is! WaveformReady) return;
    final now = DateTime.now();
    if (_manualScrubActive) {
      // Avoid a permanent hold if a widget is removed mid-gesture without a
      // pan-cancel notification (normal completion clears this immediately).
      if (_lastManualScrubUpdate != null &&
          now.difference(_lastManualScrubUpdate!) < const Duration(seconds: 5)) {
        return;
      }
      cancelManualScrub();
    }
    final pending = _pendingSeekPosition;
    if (pending != null) {
      final acknowledged =
          (event.position - pending).abs() <= _seekAckTolerance;
      if (!acknowledged && _pendingSeekAt != null &&
          now.difference(_pendingSeekAt!) < _seekSettleWindow) {
        return;
      }
      _pendingSeekPosition = null;
      _pendingSeekAt = null;
    }
    final currentState = state as WaveformReady;
    var nextScroll = currentState.scrollPosition;

    if (currentState.autoScroll) {
      final playbackPixel = currentState.timeToPixel(event.position);
      final centerPosition = currentState.viewportWidth / 2;
      final maxScroll = (currentState.totalWidth - currentState.viewportWidth)
          .clamp(0.0, double.infinity);

      if (playbackPixel <= centerPosition) {
        nextScroll = 0.0;
      } else if (playbackPixel >=
          currentState.totalWidth - centerPosition) {
        nextScroll = maxScroll;
      } else {
        nextScroll = (playbackPixel - centerPosition)
            .clamp(0.0, maxScroll);
      }
    }

    // The playhead and auto-scroll belong to the *same* logical update.
    // Previously a second _setState could read the old state during a
    // build-phase deferral and silently overwrite the new playback time.
    _setState(currentState.copyWith(
      playbackPosition: event.position,
      scrollPosition: nextScroll,
    ));
  }

  /// Seek to specific time
  void _onSeekToTime(SeekToTime event) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      _holdPositionUntilSettled(event.time);
      final targetPixel = currentState.timeToPixel(event.time);
      final newScroll = targetPixel - currentState.viewportWidth / 2;
      _setState(currentState.copyWith(
        playbackPosition: event.time,
        scrollPosition: currentState.clampScrollPosition(newScroll),
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
      // Desktop compact controls expose more amplitude detail. The mobile UI
      // continues to stop at 3x.
      final clampedZoom = event.zoom.clamp(0.5, 8.0);
      final newState = currentState.copyWith(verticalZoom: clampedZoom);
      _setState(newState);
      
      // Save zoom level to database
      _saveZoomLevels(newState);
    }
  }

  /// Clear waveform
  void _onTrackSelectionFailed(WaveformTrackSelectionFailed event) {
    cancelManualScrub();
    _loadEpoch++;
    _audioProcessor.cancelActive();
    _setState(WaveformError(event.message, filePath: event.filePath));
  }

  void _onClearWaveform(ClearWaveform event) {
    cancelManualScrub();
    _loadEpoch++; // A cleared screen must not be repopulated by an old load.
    _audioProcessor.cancelActive();
    _setState(const WaveformInitial());
  }

  /// Update viewport width
  void _onUpdateViewportWidth(
    UpdateViewportWidth event,
  ) {
    if (state is WaveformReady) {
      final currentState = state as WaveformReady;
      final resized = currentState.copyWith(viewportWidth: event.width);
      _setState(resized.copyWith(
        scrollPosition: resized.clampScrollPosition(resized.scrollPosition),
      ));
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
      final clampedScroll = currentState.clampScrollPosition(event.scrollPosition);
      if (_manualScrubActive) {
        _lastManualScrubUpdate = DateTime.now();
        _setState(currentState.copyWith(
          scrollPosition: clampedScroll,
          playbackPosition: currentState.centerTimeForScroll(clampedScroll),
        ));
      } else {
        _setState(currentState.copyWith(scrollPosition: clampedScroll));
      }
      // Video seeking is handled in the widget via widget.onSeek callback
    }
  }

  /// Save zoom levels to database
  void _saveZoomLevels(WaveformReady state) {
    // Only save if we have a subtitle collection ID
    if (state.subtitleCollectionId != null) {
      // Use fire-and-forget pattern to avoid blocking
      _preferences.saveWaveformZoomLevels(
        subtitleCollectionId: state.subtitleCollectionId!,
        zoomIndex: (state.currentZoomIndex - _desktopFineZoomCount).clamp(
            0, state.buffer.zoomLevelCount - _desktopFineZoomCount - 1),
        verticalZoom: state.verticalZoom,
      ).catchError((_) {
        // Silently catch errors - zoom preferences are not critical
        // ignore: avoid_print
        print('Failed to save waveform zoom levels');
      });
    }
  }

}
