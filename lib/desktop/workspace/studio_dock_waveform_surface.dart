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
  });

  final String videoPath;
  final int collectionId;
  final List<SubtitleLine> subtitles;
  final StudioDockPlaybackLink playback;

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: _WaveformBody(
      videoPath: videoPath,
      collectionId: collectionId,
      subtitles: subtitles,
      playback: playback,
    ),
  );
}

class _WaveformBody extends ConsumerStatefulWidget {
  const _WaveformBody({
    required this.videoPath,
    required this.collectionId,
    required this.subtitles,
    required this.playback,
  });

  final String videoPath;
  final int collectionId;
  final List<SubtitleLine> subtitles;
  final StudioDockPlaybackLink playback;

  @override
  ConsumerState<_WaveformBody> createState() => _WaveformBodyState();
}

class _WaveformBodyState extends ConsumerState<_WaveformBody> {
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant _WaveformBody old) {
    super.didUpdateWidget(old);
    if (old.videoPath != widget.videoPath ||
        old.collectionId != widget.collectionId) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    final revision = ++_loadRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _loadRevision) return;
      // Retain production caching and FFmpeg loading progress, and never
      // decode again merely because the user resizes Studio Dock.
      unawaited(ref.read(waveformControllerProvider.notifier).dispatch(
        LoadAudioFile(
          widget.videoPath,
          subtitleCollectionId: widget.collectionId,
        ),
      ));
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
          // Changes to timing and cue insertion must use a guarded history
          // transaction in a future checkpoint, never waveform direct writes.
          subtitleCollectionId: null,
          sessionId: null,
        ),
      ),
    ),
  );
}
