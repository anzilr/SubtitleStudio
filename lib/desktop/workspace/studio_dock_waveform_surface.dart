import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

import 'studio_dock_playback_link.dart';

/// Waveform uses its own session-scoped Riverpod controller and the existing
/// waveform/seek coordinator, but NEVER creates a media_kit player.
class StudioDockWaveformSurface extends StatelessWidget {
  const StudioDockWaveformSurface({
    super.key,
    required this.videoPath,
    required this.collectionId,
    required this.subtitles,
    required this.playback,
    this.onApplyTimeEdit,
    this.onAddLineConfirmed,
    this.onSubtitleHighlight,
  });

  final String videoPath;
  final int collectionId;
  final List<SubtitleLine> subtitles;
  final StudioDockPlaybackLink playback;
  final Future<bool> Function(int cueNumber, String start, String end)?
      onApplyTimeEdit;
  final void Function(Duration start, Duration end)? onAddLineConfirmed;
  final ValueChanged<int>? onSubtitleHighlight;

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: _WaveformBody(
      videoPath: videoPath,
      collectionId: collectionId,
      subtitles: subtitles,
      playback: playback,
      onApplyTimeEdit: onApplyTimeEdit,
      onAddLineConfirmed: onAddLineConfirmed,
      onSubtitleHighlight: onSubtitleHighlight,
    ),
  );
}

class _WaveformBody extends ConsumerStatefulWidget {
  const _WaveformBody({
    required this.videoPath,
    required this.collectionId,
    required this.subtitles,
    required this.playback,
    this.onApplyTimeEdit,
    this.onAddLineConfirmed,
    this.onSubtitleHighlight,
  });

  final String videoPath;
  final int collectionId;
  final List<SubtitleLine> subtitles;
  final StudioDockPlaybackLink playback;
  final Future<bool> Function(int cueNumber, String start, String end)?
      onApplyTimeEdit;
  final void Function(Duration start, Duration end)? onAddLineConfirmed;
  final ValueChanged<int>? onSubtitleHighlight;

  @override
  ConsumerState<_WaveformBody> createState() => _WaveformBodyState();
}

class _WaveformBodyState extends ConsumerState<_WaveformBody> {
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    widget.playback.audio.addListener(_scheduleLoad);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant _WaveformBody old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.audio.removeListener(_scheduleLoad);
      widget.playback.audio.addListener(_scheduleLoad);
    }
    if (old.videoPath != widget.videoPath ||
        old.collectionId != widget.collectionId ||
        old.playback != widget.playback) {
      _scheduleLoad();
    }
  }

  @override
  void dispose() {
    _loadRevision++;
    widget.playback.audio.removeListener(_scheduleLoad);
    super.dispose();
  }

  void _scheduleLoad() {
    final revision = ++_loadRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _loadRevision) return;
      final selection = widget.playback.audio.value;
      final controller = ref.read(waveformControllerProvider.notifier);
      switch (selection.status) {
        case StudioDockAudioStatus.waiting:
          // Do not display a previous audio track during mpv track changes.
          unawaited(controller.dispatch(const ClearWaveform()));
        case StudioDockAudioStatus.unavailable:
          unawaited(controller.dispatch(WaveformTrackSelectionFailed(
            selection.error ?? 'Audio track metadata is unavailable.',
            filePath: widget.videoPath,
          )));
        case StudioDockAudioStatus.ready:
          // A player-resolved null selector means *auto*, not the older
          // saved FFmpeg preference for this subtitle collection.
          unawaited(controller.dispatch(LoadAudioFile(
            widget.videoPath,
            subtitleCollectionId: widget.collectionId,
            audioTrackId: selection.streamSelector,
            useSavedAudioTrackPreference: false,
          )));
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) => ValueListenableBuilder<Duration>(
      valueListenable: widget.playback.position,
      builder: (context, position, _) => ClipRect(
        child: WaveformWidget(
          key: const ValueKey('studio-dock-live-waveform'),
          subtitles: widget.subtitles,
          playbackPosition: position,
          onSeek: widget.playback.seek,
          isVideoPlaying: () => widget.playback.playing.value,
          height: limits.maxHeight,
          compact: true,
          enableTimeEditing: widget.onApplyTimeEdit != null &&
              widget.onAddLineConfirmed != null,
          onApplyTimeEdit: widget.onApplyTimeEdit,
          onAddLineConfirmed: widget.onAddLineConfirmed,
          onSubtitleHighlight: widget.onSubtitleHighlight,
          // Native Studio Dock owns the guarded history transaction; never
          // let the waveform fall back to unguarded direct database writes.
          subtitleCollectionId: null,
          sessionId: null,
        ),
      ),
    ),
  );
}
