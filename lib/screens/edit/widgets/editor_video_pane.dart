import 'dart:io';

import 'package:flutter/material.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';
import 'package:subtitle_studio/screens/edit/widgets/video_player_section.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';

/// Video + waveform composition for the main Editor.
///
/// State mutations remain in the parent Editor; this widget only owns layout
/// composition so screen_edit.dart does not also carry player presentation.
class EditorVideoPane extends StatelessWidget {
  final bool isVideoVisible;
  final String? videoPath;
  final bool isWaveformVisible;
  final GlobalKey<VideoPlayerWidgetState> videoPlayerKey;
  final GlobalKey<WaveformWidgetState> waveformKey;
  final int subtitleCollectionId;
  final int sessionId;
  final List<Subtitle> subtitles;
  final List<Subtitle> secondarySubtitles;
  final List<SubtitleLine> subtitleLines;
  final int subtitleVersion;
  final Duration playbackPosition;
  final int? highlightedSubtitleIndex;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<int>? onActiveSubtitleChanged;
  final VoidCallback? onSubtitlesUpdated;
  final VoidCallback? onFullscreenExited;
  final void Function(int, bool)? onSubtitleMarked;
  final void Function(int, String?)? onSubtitleCommentUpdated;
  final VoidCallback onLoadVideo;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<int> onSubtitleHighlight;
  final Future<void> Function() onWaveformSubtitlesUpdated;
  final void Function(Duration startTime, Duration endTime)
      onAddLineConfirmed;

  const EditorVideoPane({
    super.key,
    required this.isVideoVisible,
    required this.videoPath,
    required this.isWaveformVisible,
    required this.videoPlayerKey,
    required this.waveformKey,
    required this.subtitleCollectionId,
    required this.sessionId,
    required this.subtitles,
    required this.secondarySubtitles,
    required this.subtitleLines,
    required this.subtitleVersion,
    required this.playbackPosition,
    required this.highlightedSubtitleIndex,
    required this.onPositionChanged,
    required this.onActiveSubtitleChanged,
    required this.onSubtitlesUpdated,
    required this.onFullscreenExited,
    required this.onSubtitleMarked,
    required this.onSubtitleCommentUpdated,
    required this.onLoadVideo,
    required this.onSeek,
    required this.onSubtitleHighlight,
    required this.onWaveformSubtitlesUpdated,
    required this.onAddLineConfirmed,
  });

  bool get _useDesktopWaveformHeight =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isVideoVisible && videoPath != null)
          Expanded(
            child: isWaveformVisible
                ? _buildVideoWithWaveform(context)
                : VideoPlayerSection(
                    videoPlayerKey: videoPlayerKey,
                    videoPath: videoPath!,
                    subtitleCollectionId: subtitleCollectionId,
                    subtitles: subtitles,
                    secondarySubtitles: secondarySubtitles,
                    subtitleVersion: subtitleVersion,
                    onPositionChanged: onPositionChanged,
                    onActiveSubtitleChanged: onActiveSubtitleChanged,
                    onSubtitlesUpdated: onSubtitlesUpdated,
                    onFullscreenExited: onFullscreenExited,
                    onSubtitleMarked: onSubtitleMarked,
                    onSubtitleCommentUpdated: onSubtitleCommentUpdated,
                  ),
          )
        else
          Expanded(
            child: _buildNoVideoPlaceholder(context),
          ),
      ],
    );
  }

  Widget _buildVideoWithWaveform(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final waveformHeight = _useDesktopWaveformHeight ? 240.0 : 180.0;
        final availableVideoHeight =
            constraints.maxHeight - waveformHeight - 1;
        final videoHeight = availableVideoHeight > 0
            ? availableVideoHeight
            : constraints.maxHeight * 0.7;

        return Column(
          children: [
            SizedBox(
              height: videoHeight,
              child: VideoPlayerSection(
                videoPlayerKey: videoPlayerKey,
                videoPath: videoPath!,
                subtitleCollectionId: subtitleCollectionId,
                subtitles: subtitles,
                secondarySubtitles: secondarySubtitles,
                subtitleVersion: subtitleVersion,
                onPositionChanged: onPositionChanged,
                onActiveSubtitleChanged: onActiveSubtitleChanged,
                onSubtitlesUpdated: onSubtitlesUpdated,
                onFullscreenExited: onFullscreenExited,
                onSubtitleMarked: onSubtitleMarked,
                onSubtitleCommentUpdated: onSubtitleCommentUpdated,
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: waveformHeight,
              child: WaveformWidget(
                key: waveformKey,
                subtitles: subtitleLines,
                playbackPosition: playbackPosition,
                subtitleCollectionId: subtitleCollectionId,
                sessionId: sessionId,
                highlightedSubtitleIndex: highlightedSubtitleIndex,
                onSeek: onSeek,
                onSubtitleHighlight: onSubtitleHighlight,
                onSubtitlesUpdated: () {
                  onWaveformSubtitlesUpdated();
                },
                onAddLineConfirmed: onAddLineConfirmed,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoVideoPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 80,
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No video loaded',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onLoadVideo,
            icon: const Icon(Icons.video_file),
            label: const Text('Load Video'),
          ),
        ],
      ),
    );
  }
}
