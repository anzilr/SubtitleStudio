import 'package:equatable/equatable.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';

/// States for waveform controller
abstract class WaveformState extends Equatable {
  const WaveformState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no waveform loaded
class WaveformInitial extends WaveformState {
  const WaveformInitial();
}

/// Loading audio file and processing
class WaveformLoading extends WaveformState {
  final String filePath;
  final double progress; // 0.0 to 1.0
  /// FFmpeg media timeline processed so far; not a percentage of total duration.
  final Duration? processedAudioTime;
  /// Optional duration from the player for this source. Unknown for a
  /// standalone file or when the player has not established its timeline.
  final Duration? totalAudioTime;

  const WaveformLoading(this.filePath, {
    this.progress = 0.0,
    this.processedAudioTime,
    this.totalAudioTime,
  });

  /// Only a valid, known source duration permits determinate extraction UI.
  /// The later zoom-building phase has its own independent stage progress.
  double? get extractedFraction {
    final processed = processedAudioTime;
    final total = totalAudioTime;
    if (processed == null || total == null || total <= Duration.zero) {
      return null;
    }
    return (processed.inMicroseconds / total.inMicroseconds)
        .clamp(0.0, 1.0).toDouble();
  }

  /// Extraction fills 85% of the visual track, followed by real zoom-build
  /// progress for the remainder. No percentage is exposed for an unknown
  /// extraction duration, as stage weights are only presentation guidance.
  double? get waveformFillFraction {
    if (progress >= 0.35) {
      return 0.85 + (progress - 0.35).clamp(0.0, 0.65) / 0.65 * 0.15;
    }
    final extraction = extractedFraction;
    return extraction == null ? null : extraction * 0.85;
  }

  @override
  List<Object?> get props => [filePath, progress, processedAudioTime, totalAudioTime];
}

/// Waveform loaded and ready
class WaveformReady extends WaveformState {
  final WaveformBuffer buffer;
  final int currentZoomIndex;
  final double scrollPosition; // in pixels
  final Duration playbackPosition;
  final bool autoScroll;
  final double viewportWidth; // in pixels
  final String? sourceFilePath;
  /// Identity used for this specific PCM/peak extraction.
  final String? audioTrackId;
  final double verticalZoom; // 1.0 = 100%, 2.0 = 200% amplitude
  final int? subtitleCollectionId; // For saving zoom preferences
  
  // Time edit mode fields
  final bool isEditMode;
  final int? editingSubtitleIndex;
  final Duration? tempStartTime;
  final Duration? tempEndTime;
  
  // Add line mode fields
  final bool isAddLineMode;
  final Duration? addLineStartTime;
  final Duration? addLineEndTime;
  
  // Overlap toggle
  final bool allowOverlap;
  
  // Magnet snap toggle
  final bool magnetSnapEnabled;

  const WaveformReady({
    required this.buffer,
    required this.currentZoomIndex,
    this.scrollPosition = 0.0,
    this.playbackPosition = Duration.zero,
    this.autoScroll = true,
    this.viewportWidth = 800.0,
    this.sourceFilePath,
    this.audioTrackId,
    this.verticalZoom = 1.7, // Default 170% for better visibility
    this.subtitleCollectionId,
    this.isEditMode = false,
    this.editingSubtitleIndex,
    this.tempStartTime,
    this.tempEndTime,
    this.isAddLineMode = false,
    this.addLineStartTime,
    this.addLineEndTime,
    this.allowOverlap = false, // Default: prevent overlap
    this.magnetSnapEnabled = true, // Default: magnet snap enabled
  });

  /// Get current zoom level
  ZoomLevel get currentZoomLevel => buffer.zoomLevels[currentZoomIndex];

  /// Get samples per pixel for current zoom
  int get samplesPerPixel => currentZoomLevel.samplesPerPixel;

  /// Get total width in pixels at current zoom
  double get totalWidth =>
      (buffer.rawData.totalSamples / samplesPerPixel).toDouble();

  /// Allow half a viewport of empty *visual* space on either side. This lets
  /// the center editing cursor reach exactly 0 and the final audio sample,
  /// even when the entire waveform is shorter than the viewport.
  double get minScrollPosition => -viewportWidth / 2;

  double get maxScrollPosition => totalWidth - viewportWidth / 2;

  double clampScrollPosition(double requested) =>
      requested.clamp(minScrollPosition, maxScrollPosition);

  /// The time actually shown at the center after scroll clamping.
  Duration centerTimeForScroll(double requested) {
    final centerPixel = (clampScrollPosition(requested) + viewportWidth / 2)
        .clamp(0.0, totalWidth);
    return pixelToTime(centerPixel);
  }

  /// Shared projection for the painter and hit testing. Playback naturally
  /// moves left-to-center, then center-to-right at the edges as the timeline
  /// scrolls; manual scrolling may also position either endpoint at center.
  double get playheadViewportX =>
      (timeToPixel(playbackPosition) - scrollPosition)
          .clamp(0.0, viewportWidth);

  /// Get visible time range based on scroll position and viewport
  Duration get visibleStartTime {
    final startSample = (scrollPosition * samplesPerPixel).round();
    return Duration(
      microseconds: (startSample * 1000000 / buffer.sampleRate).round(),
    );
  }

  Duration get visibleEndTime {
    final endSample =
        ((scrollPosition + viewportWidth) * samplesPerPixel).round();
    return Duration(
      microseconds: (endSample * 1000000 / buffer.sampleRate).round(),
    );
  }

  /// Convert time to pixel position
  double timeToPixel(Duration time) {
    final sample = (time.inMicroseconds * buffer.sampleRate / 1000000).round();
    return sample / samplesPerPixel;
  }

  /// Convert pixel position to time
  Duration pixelToTime(double pixel) {
    final sample = (pixel * samplesPerPixel).round();
    return Duration(
      microseconds: (sample * 1000000 / buffer.sampleRate).round(),
    );
  }

  /// Check if can zoom in (increase detail = decrease index, go to lower zoom levels)
  bool get canZoomIn => currentZoomIndex > 0;

  /// Check if can zoom out (decrease detail = increase index, go to higher zoom levels)
  bool get canZoomOut => currentZoomIndex < buffer.zoomLevelCount - 1;

  WaveformReady copyWith({
    WaveformBuffer? buffer,
    int? currentZoomIndex,
    double? scrollPosition,
    Duration? playbackPosition,
    bool? autoScroll,
    double? viewportWidth,
    String? sourceFilePath,
    String? audioTrackId,
    double? verticalZoom,
    int? subtitleCollectionId,
    bool? isEditMode,
    int? editingSubtitleIndex,
    Duration? tempStartTime,
    Duration? tempEndTime,
    bool? isAddLineMode,
    Duration? addLineStartTime,
    Duration? addLineEndTime,
    bool? allowOverlap,
    bool? magnetSnapEnabled,
    bool clearEditingSubtitleIndex = false,
    bool clearTempStartTime = false,
    bool clearTempEndTime = false,
    bool clearAddLineStartTime = false,
    bool clearAddLineEndTime = false,
  }) {
    return WaveformReady(
      buffer: buffer ?? this.buffer,
      currentZoomIndex: currentZoomIndex ?? this.currentZoomIndex,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      autoScroll: autoScroll ?? this.autoScroll,
      viewportWidth: viewportWidth ?? this.viewportWidth,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      audioTrackId: audioTrackId ?? this.audioTrackId,
      verticalZoom: verticalZoom ?? this.verticalZoom,
      subtitleCollectionId: subtitleCollectionId ?? this.subtitleCollectionId,
      isEditMode: isEditMode ?? this.isEditMode,
      editingSubtitleIndex: clearEditingSubtitleIndex ? null : (editingSubtitleIndex ?? this.editingSubtitleIndex),
      tempStartTime: clearTempStartTime ? null : (tempStartTime ?? this.tempStartTime),
      tempEndTime: clearTempEndTime ? null : (tempEndTime ?? this.tempEndTime),
      isAddLineMode: isAddLineMode ?? this.isAddLineMode,
      addLineStartTime: clearAddLineStartTime ? null : (addLineStartTime ?? this.addLineStartTime),
      addLineEndTime: clearAddLineEndTime ? null : (addLineEndTime ?? this.addLineEndTime),
      allowOverlap: allowOverlap ?? this.allowOverlap,
      magnetSnapEnabled: magnetSnapEnabled ?? this.magnetSnapEnabled,
    );
  }

  @override
  List<Object?> get props => [
        buffer,
        currentZoomIndex,
        scrollPosition,
        playbackPosition,
        autoScroll,
        viewportWidth,
        sourceFilePath,
        audioTrackId,
        verticalZoom,
        subtitleCollectionId,
        isEditMode,
        editingSubtitleIndex,
        tempStartTime,
        tempEndTime,
        isAddLineMode,
        addLineStartTime,
        addLineEndTime,
        allowOverlap,
        magnetSnapEnabled,
      ];
}

/// Error state
class WaveformError extends WaveformState {
  final String message;
  final String? filePath;

  const WaveformError(this.message, {this.filePath});

  @override
  List<Object?> get props => [message, filePath];
}
