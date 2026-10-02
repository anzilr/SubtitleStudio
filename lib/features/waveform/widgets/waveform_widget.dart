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
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/settings_sheet.dart';
import 'package:subtitle_studio/utils/time_parser.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

part 'waveform_rendering.dart';
part 'waveform_interactions.dart';
part 'waveform_editing.dart';

/// Main waveform visualization widget with interaction support
class WaveformWidget extends riverpod.ConsumerStatefulWidget {
  final List<SubtitleLine> subtitles;
  final Duration? playbackPosition;
  final Function(Duration)? onSeek;
  final Function(int)? onSubtitleHighlight; // Callback to highlight subtitle in list
  final Function()? onSubtitlesUpdated; // Callback when subtitles are updated (for refreshing parent)
  final Function(Duration startTime, Duration endTime)? onAddLineConfirmed; // Callback when add line is confirmed with selected times
  final double height;
  final int? subtitleCollectionId; // For database updates
  final int? sessionId; // For checkpoint creation
  final int? highlightedSubtitleIndex; // Index of currently highlighted subtitle (0-based)

  const WaveformWidget({
    super.key,
    required this.subtitles,
    this.playbackPosition,
    this.onSeek,
    this.onSubtitleHighlight,
    this.onSubtitlesUpdated,
    this.onAddLineConfirmed,
    this.height = 180.0,
    this.subtitleCollectionId,
    this.sessionId,
    this.highlightedSubtitleIndex,
  });

  @override
  riverpod.ConsumerState<WaveformWidget> createState() => WaveformWidgetState();
}

class WaveformWidgetState extends riverpod.ConsumerState<WaveformWidget> {
  // Cache current subtitles for change detection
  List<SubtitleLine> _currentSubtitles = [];
  
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
  
  // Static variables for mouse double-click (persist across rebuilds)
  static DateTime? _staticLastMouseClickTime;
  static Offset? _staticLastMouseClickPosition;
  static int? _staticLastMouseClickSubtitleIndex;

  @override
  void initState() {
    super.initState();
    // Initialize current subtitles from widget
    _currentSubtitles = List.from(widget.subtitles);
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update playback position if changed
    if (widget.playbackPosition != oldWidget.playbackPosition &&
        widget.playbackPosition != null) {
      ref.read(waveformControllerProvider.notifier).dispatch(
            UpdatePlaybackPosition(widget.playbackPosition!),
          );
    }
    
    // Check if subtitles changed and update internal cache
    if (widget.subtitles != oldWidget.subtitles) {
      _updateSubtitlesInternal(widget.subtitles);
    }
  }
  
  /// Update subtitles and force repaint
  /// This method should be called externally when subtitle list changes
  void updateSubtitles(List<SubtitleLine> newSubtitles) {
    if (!mounted) return;
    
    _updateSubtitlesInternal(newSubtitles);
  }
  
  /// Internal method to update subtitles and trigger repaint
  void _updateSubtitlesInternal(List<SubtitleLine> newSubtitles) {
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
      setState(() {
        _currentSubtitles = List.from(newSubtitles);
      });
      
      // Force waveform repaint
      ref.read(waveformControllerProvider.notifier).dispatch(const ForceRepaint());
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
