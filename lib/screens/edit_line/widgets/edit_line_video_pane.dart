import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';

/// Isolated video player composition for the Edit Line screen.
///
/// The parent remains responsible for persistence and navigation. This widget
/// only forwards player events so screen_edit_line.dart does not also carry the
/// full player construction details.
class EditLineVideoPane extends StatelessWidget {
  final GlobalKey<VideoPlayerWidgetState> videoPlayerKey;
  final String videoPath;
  final int subtitleCollectionId;
  final List<Subtitle> subtitles;
  final List<Subtitle> secondarySubtitles;
  final bool isRepeatModeEnabled;
  final VoidCallback onSubtitlesUpdated;
  final Future<void> Function(int subtitleIndex, bool isMarked)
      onSubtitleMarked;
  final Future<void> Function(int subtitleIndex, String? comment)
      onSubtitleCommentUpdated;
  final ValueChanged<bool> onPlayStateChanged;
  final ValueChanged<bool> onRepeatModeToggled;

  const EditLineVideoPane({
    super.key,
    required this.videoPlayerKey,
    required this.videoPath,
    required this.subtitleCollectionId,
    required this.subtitles,
    required this.secondarySubtitles,
    required this.isRepeatModeEnabled,
    required this.onSubtitlesUpdated,
    required this.onSubtitleMarked,
    required this.onSubtitleCommentUpdated,
    required this.onPlayStateChanged,
    required this.onRepeatModeToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: VideoPlayerWidget(
        key: videoPlayerKey,
        videoPath: videoPath,
        subtitleCollectionId: subtitleCollectionId,
        subtitles: subtitles,
        secondarySubtitles: secondarySubtitles,
        onSubtitlesUpdated: onSubtitlesUpdated,
        onSubtitleMarked: onSubtitleMarked,
        onSubtitleCommentUpdated: onSubtitleCommentUpdated,
        onPlayStateChanged: onPlayStateChanged,
        onRepeatModeToggled: onRepeatModeToggled,
        isRepeatModeEnabled: isRepeatModeEnabled,
      ),
    );
  }
}
