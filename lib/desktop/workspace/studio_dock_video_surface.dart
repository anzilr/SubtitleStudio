import 'dart:async';

import 'package:flutter/material.dart';
import 'package:subtitle_studio/screens/edit/widgets/video_player_section.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';
import 'studio_dock_playback_link.dart';

/// Exactly one player widget is owned by this state for the life of a desktop
/// session. Splitter changes only resize it; no GlobalKey is shared with the
/// classic Editor, and no native media controller is created by this wrapper.
class StudioDockVideoSurface extends StatefulWidget {
  const StudioDockVideoSurface({
    super.key,
    required this.collectionId,
    required this.videoPath,
    required this.subtitles,
    required this.playback,
    this.secondarySubtitles = const <Subtitle>[],
    this.onPlayerStateChanged,
    this.onSubtitleMarked,
    this.onSubtitleReviewSaved,
    this.onSubtitleResolvedChanged,
    this.onRepeatModeToggled,
    this.isRepeatModeEnabled = false,
    this.onOpenRepeatRange,
  });

  final int collectionId;
  final String videoPath;
  final List<Subtitle> subtitles;
  final List<Subtitle> secondarySubtitles;
  final StudioDockPlaybackLink playback;
  /// Makes the existing player available to the shared secondary-track picker
  /// (including video-embedded text tracks), without creating a second player.
  final ValueChanged<VideoPlayerWidgetState?>? onPlayerStateChanged;
  final Future<void> Function(int, bool)? onSubtitleMarked;
  final Future<bool> Function(int, String?, bool, bool)? onSubtitleReviewSaved;
  final Future<void> Function(int, bool)? onSubtitleResolvedChanged;
  final ValueChanged<bool>? onRepeatModeToggled;
  final bool isRepeatModeEnabled;
  final VoidCallback? onOpenRepeatRange;

  @override
  State<StudioDockVideoSurface> createState() => _StudioDockVideoSurfaceState();
}

class _StudioDockVideoSurfaceState extends State<StudioDockVideoSurface> {
  final _playerKey = GlobalKey<VideoPlayerWidgetState>();
  int _audioRevision = 0;

  void _seek(Duration time) => _playerKey.currentState?.seekTo(time);

  void _onAudioTrackChanged(String trackId) {
    final revision = ++_audioRevision;
    widget.playback.prepareAudio();
    unawaited(_resolveSelectedTrack(trackId, revision));
  }

  Future<void> _resolveSelectedTrack(String trackId, int revision) async {
    final player = _playerKey.currentState;
    if (player == null) return;
    try {
      final selector = await player.resolveWaveformSelectedAudioStream();
      if (!mounted || revision != _audioRevision) return;
      // Non-auto tracks must resolve to an actual FFmpeg global stream index.
      if (trackId != 'auto' && selector == null) {
        widget.playback.updateAudioUnavailable(trackId,
            'The selected audio track could not be resolved for waveform use.');
      } else {
        widget.playback.updateAudioReady(trackId, selector);
      }
    } catch (_) {
      if (!mounted || revision != _audioRevision) return;
      widget.playback.updateAudioUnavailable(trackId,
          'The selected video audio track cannot be used for waveform decoding.');
    }
  }

  @override
  void initState() {
    super.initState();
    widget.playback.attach(_seek);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _playerKey.currentState;
      widget.onPlayerStateChanged?.call(state);
      if (_audioRevision != 0) return;
      if (state != null) _onAudioTrackChanged(state.player.state.track.audio.id);
    });
  }

  @override
  void didUpdateWidget(covariant StudioDockVideoSurface old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.detachAfterFrame();
      widget.playback.attach(_seek);
    }
  }

  @override
  void dispose() {
    _audioRevision++;
    widget.onPlayerStateChanged?.call(null);
    // Never notify waveform builders from State.dispose(): unmounting holds
    // BuildOwner's tree lock until frame finalization has completed.
    widget.playback.detachAfterFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VideoPlayerSection(
    videoPlayerKey: _playerKey,
    subtitleCollectionId: widget.collectionId,
    videoPath: widget.videoPath,
    subtitles: widget.subtitles,
    secondarySubtitles: widget.secondarySubtitles,
    subtitleVersion: 0,
    onPositionChanged: widget.playback.updatePosition,
    onPlayStateChanged: widget.playback.updatePlaying,
    onAudioTrackChanged: _onAudioTrackChanged,
    onSubtitleMarked: widget.onSubtitleMarked,
    onSubtitleReviewSaved: widget.onSubtitleReviewSaved,
    onSubtitleResolvedChanged: widget.onSubtitleResolvedChanged,
    onRepeatModeToggled: widget.onRepeatModeToggled,
    isRepeatModeEnabled: widget.isRepeatModeEnabled,
    onOpenRepeatRange: widget.onOpenRepeatRange,
    contentMargin: const EdgeInsets.all(4),
  );
}
