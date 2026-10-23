import 'package:flutter/material.dart';
import 'package:subtitle_studio/screens/edit/widgets/video_player_section.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';

/// Exactly one player widget is owned by this state for the life of a desktop
/// session. Splitter changes only resize it; no GlobalKey is shared with the
/// classic Editor, and no native media controller is created by this wrapper.
class StudioDockVideoSurface extends StatefulWidget {
  const StudioDockVideoSurface({
    super.key,
    required this.collectionId,
    required this.videoPath,
    required this.subtitles,
  });

  final int collectionId;
  final String videoPath;
  final List<Subtitle> subtitles;

  @override
  State<StudioDockVideoSurface> createState() => _StudioDockVideoSurfaceState();
}

class _StudioDockVideoSurfaceState extends State<StudioDockVideoSurface> {
  final _playerKey = GlobalKey<VideoPlayerWidgetState>();

  @override
  Widget build(BuildContext context) => VideoPlayerSection(
    videoPlayerKey: _playerKey,
    subtitleCollectionId: widget.collectionId,
    videoPath: widget.videoPath,
    subtitles: widget.subtitles,
    secondarySubtitles: const <Subtitle>[],
    subtitleVersion: 0,
  );
}
