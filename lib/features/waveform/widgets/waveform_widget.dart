import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_painter.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_control_colors.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_loading_bars.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_tile_source.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_decode_progress.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_seek_coordinator.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_time_range_planner.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/settings_sheet.dart';
import 'package:subtitle_studio/utils/time_parser.dart';

part 'waveform_rendering.dart';
part 'waveform_interactions.dart';
part 'waveform_editing.dart';

/// Main waveform visualization widget with interaction support
class WaveformWidget extends riverpod.ConsumerStatefulWidget {
  final List<SubtitleLine> subtitles;
  final Duration? playbackPosition;
  final Function(Duration)? onSeek;
  /// Report whether video is running. Paused scrubs seek only on release.
  final bool Function()? isVideoPlaying;
  final Function(int)? onSubtitleHighlight; // Callback to highlight subtitle in list
  final Function()? onSubtitlesUpdated; // Callback when subtitles are updated (for refreshing parent)
  final Function(Duration startTime, Duration endTime)? onAddLineConfirmed; // Callback when add line is confirmed with selected times
  /// Optional host-owned guarded history transaction for waveform time edits.
  /// When absent, the existing mobile repository write remains unchanged.
  final Future<bool> Function(int cueNumber, String start, String end)?
      onApplyTimeEdit;
  final double height;
  /// Opt-in minimal toolbar/zoom UI when embedded in a short desktop band.
  /// The full-sized mobile and classic waveform remains unchanged.
  final bool compact;
  /// Keep waveform timing/add-cue edit gestures unavailable until the caller
  /// supplies a checkpoint-backed persistence flow. Mobile defaults unchanged.
  final bool enableTimeEditing;
  final int? subtitleCollectionId; // For database updates
  final int? sessionId; // For checkpoint creation
  final int? highlightedSubtitleIndex; // Index of currently highlighted subtitle (0-based)
  /// Opt in to tile-backed painting; false preserves the current UI.
  final bool useTiledWaveform;
  /// Experimental split static/dynamic render layers (default disabled).
  final bool useLayeredWaveform;

  const WaveformWidget({
    super.key,
    required this.subtitles,
    this.playbackPosition,
    this.onSeek,
    this.isVideoPlaying,
    this.onSubtitleHighlight,
    this.onSubtitlesUpdated,
    this.onAddLineConfirmed,
    this.onApplyTimeEdit,
    this.height = 180.0,
    this.compact = false,
    this.enableTimeEditing = true,
    this.subtitleCollectionId,
    this.sessionId,
    this.highlightedSubtitleIndex,
    // Runtime experimentation: flutter run --dart-define=MS_ONE_TILED_WAVEFORM=true
    // Legacy eager painter is the shipping default on all platforms.
    this.useTiledWaveform = const bool.fromEnvironment(
      'MS_ONE_TILED_WAVEFORM', defaultValue: false),
    this.useLayeredWaveform = const bool.fromEnvironment(
      'MS_ONE_LAYERED_WAVEFORM', defaultValue: false),

  });

  @override
  riverpod.ConsumerState<WaveformWidget> createState() => WaveformWidgetState();
}

class WaveformWidgetState extends riverpod.ConsumerState<WaveformWidget> {
  // Cache current subtitles for change detection
  List<SubtitleLine> _currentSubtitles = [];
  WaveformBuffer? _tileBuffer;
  WaveformTileSource? _tileSource;

  WaveformTileSource? _tilesFor(WaveformReady state) {
    // Metadata-only zoom descriptors have no eager channel arrays.
    // Always supply a tile source even if this widget was instantiated
    // with its explicit compatibility flag disabled.
    if (!widget.useTiledWaveform &&
        !state.currentZoomLevel.isMetadataOnly) return null;
    if (!identical(_tileBuffer, state.buffer)) {
      _tileBuffer = state.buffer;
      _tileSource = WaveformTileSource(
        data: state.buffer.rawData,
        sourceIdentity: state.sourceFilePath ?? 'waveform',
      );
    }
    return _tileSource;
  }
  
  // For detecting double taps on subtitle boxes (single tap → double tap now)
  int? _lastTappedSubtitleIndex;
  DateTime? _lastTapTime;
  static const _doubleTapDuration = Duration(milliseconds: 500);
  
  // For detecting double taps on empty waveform areas
  DateTime? _lastWaveformTapTime;
  
  // For detecting double taps/clicks on playhead
  DateTime? _lastPlayheadTapTime;
  
  // For dragging time adjustment bars (edit mode)
  bool _isDraggingStartBar = false;
  bool _isDraggingEndBar = false;
  
  // For dragging add line overlay bars
  bool _isDraggingAddLineStartBar = false;
  bool _isDraggingAddLineEndBar = false;
  
  // For moving entire overlays
  bool _isMovingEditOverlay = false;
  bool _isMovingAddLineOverlay = false;
  double? _overlayDragStartX;
  Duration? _overlayDragOriginalStart;
  Duration? _overlayDragOriginalEnd;
  
  // For waveform scrolling
  double? _lastScrollDragPosition;
  late final WaveformSeekCoordinator _seekCoordinator;
  
  // Static variables for mouse double-click (persist across rebuilds)
  static DateTime? _staticLastMouseClickTime;
  static Offset? _staticLastMouseClickPosition;
  static int? _staticLastMouseClickSubtitleIndex;

  @override
  void initState() {
    super.initState();
    // Initialize current subtitles from widget
    _currentSubtitles = List.from(widget.subtitles);
    _seekCoordinator = WaveformSeekCoordinator(
      shouldPreview: () => widget.isVideoPlaying?.call() ?? true,
      onBegin: () =>
          ref.read(waveformControllerProvider.notifier).beginManualScrub(),
      onPreview: (position) => widget.onSeek?.call(position),
      onComplete: (position) =>
          ref.read(waveformControllerProvider.notifier).completeManualScrub(position),
      onCancel: () =>
          ref.read(waveformControllerProvider.notifier).cancelManualScrub(),
    );
  }

  @override
  void dispose() {
    // In particular, a pending mouse-wheel idle timer may not seek after the
    // editor leaves the screen or changes its video surface.
    _seekCoordinator.dispose();
    super.dispose();
  }

  // Synchronize external playback updates only after the current Flutter
  // build completes. Riverpod forbids provider writes from didUpdateWidget.
  // Coalesce repeated parent updates and always apply the latest position.
  bool _playbackSyncScheduled = false;

  void _schedulePlaybackSync() {
    if (_playbackSyncScheduled) return;
    _playbackSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playbackSyncScheduled = false;
      if (!mounted) return;
      final position = widget.playbackPosition;
      if (position == null) return;
      ref.read(waveformControllerProvider.notifier)
          .dispatch(UpdatePlaybackPosition(position));
    });
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.playbackPosition != oldWidget.playbackPosition &&
        widget.playbackPosition != null) {
      _schedulePlaybackSync();
    }

    // Flutter is *already* rebuilding this widget. Never set local state
    // or write a Riverpod provider from this lifecycle callback.
    if (widget.subtitles != oldWidget.subtitles) {
      _updateSubtitlesInternal(widget.subtitles, duringWidgetUpdate: true);
    }
  }
  
  /// Update subtitles and force repaint
  /// This method should be called externally when subtitle list changes
  void updateSubtitles(List<SubtitleLine> newSubtitles) {
    if (!mounted) return;
    
    _updateSubtitlesInternal(newSubtitles);
  }
  
  /// Internal method to update subtitles and trigger repaint
  void _updateSubtitlesInternal(
    List<SubtitleLine> newSubtitles, {
    bool duringWidgetUpdate = false,
  }) {
    // Check if subtitles actually changed
    bool hasChanges = false;
    
    if (_currentSubtitles.length != newSubtitles.length) {
      hasChanges = true;
    } else {
      // Compare subtitle content for changes
      for (int i = 0; i < _currentSubtitles.length; i++) {
        final current = _currentSubtitles[i];
        final newSub = newSubtitles[i];
        
        if (current.index != newSub.index ||
            current.startTime != newSub.startTime ||
            current.endTime != newSub.endTime ||
            current.original != newSub.original ||
            current.edited != newSub.edited ||
            current.marked != newSub.marked) {
          hasChanges = true;
          break;
        }
      }
    }
    
    if (hasChanges) {
      // didUpdateWidget is itself a rebuild, so setState is unnecessary
      // (and a synchronous provider dispatch here violates Riverpod's
      // widget lifecycle rule). External updates still request a repaint.
      if (duringWidgetUpdate) {
        _currentSubtitles = List.from(newSubtitles);
      } else {
        setState(() {
          _currentSubtitles = List.from(newSubtitles);
        });
      }
    }
  }

  void _mutateLocalState(VoidCallback mutation) {
    if (!mounted) return;
    setState(mutation);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(waveformControllerProvider);

    if (state is WaveformInitial) {
      return _buildEmptyState();
    } else if (state is WaveformLoading) {
      return _buildLoadingState(state);
    } else if (state is WaveformError) {
      return _buildErrorState(state);
    } else if (state is WaveformReady) {
      return _buildWaveformView(state);
    }

    return const SizedBox.shrink();
  }


}
