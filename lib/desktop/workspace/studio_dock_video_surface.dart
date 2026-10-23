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
  });

  final int collectionId;
  final String videoPath;
  final List<Subtitle> subtitles;
  final StudioDockPlaybackLink playback;

  @override
  State<StudioDockVideoSurface> createState() => _StudioDockVideoSurfaceState();
}

class _StudioDockVideoSurfaceState extends State<StudioDockVideoSurface> {
  final _playerKey = GlobalKey<VideoPlayerWidgetState>();

  void _seek(Duration time) => _playerKey.currentState?.seekTo(time);

  @override
  void initState() {
    super.initState();
    widget.playback.attach(_seek);
  }

  @override
  void didUpdateWidget(covariant StudioDockVideoSurface old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.detach();
      widget.playback.attach(_seek);
    }
  }

  @override
  void dispose() {
    widget.playback.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VideoPlayerSection(
    videoPlayerKey: _playerKey,
    subtitleCollectionId: widget.collectionId,
    videoPath: widget.videoPath,
    subtitles: widget.subtitles,
    secondarySubtitles: const <Subtitle>[],
    subtitleVersion: 0,
    onPositionChanged: widget.playback.updatePosition,
    onPlayStateChanged: widget.playback.updatePlaying,
  );
}
