import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_toolbar.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

/// Standalone waveform section.
///
/// A nested [ProviderScope] preserves the old behavior where each standalone
/// section owned its own WaveformBloc instance. The main Editor does not use
/// this wrapper; it shares one screen-scoped waveform controller instead.
class WaveformSection extends StatelessWidget {
  final List<SubtitleLine> subtitles;
  final Duration? playbackPosition;
  final Function(Duration)? onSeek;
  final double height;
  final String? videoPath;

  const WaveformSection({
    super.key,
    required this.subtitles,
    this.playbackPosition,
    this.onSeek,
    this.height = 180.0,
    this.videoPath,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _WaveformSectionContent(
        subtitles: subtitles,
        playbackPosition: playbackPosition,
        onSeek: onSeek,
        height: height,
      ),
    );
  }
}

class _WaveformSectionContent extends ConsumerWidget {
  final List<SubtitleLine> subtitles;
  final Duration? playbackPosition;
  final Function(Duration)? onSeek;
  final double height;

  const _WaveformSectionContent({
    required this.subtitles,
    required this.playbackPosition,
    required this.onSeek,
    required this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WaveformToolbar(
          onLoadAudio: () => _handleLoadAudio(context, ref),
        ),
        SizedBox(
          height: height,
          child: WaveformWidget(
            subtitles: subtitles,
            playbackPosition: playbackPosition,
            onSeek: onSeek,
            height: height,
          ),
        ),
      ],
    );
  }

  Future<void> _handleLoadAudio(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'aac',
          'm4a',
          'ogg',
          'flac',
          'mp4',
          'mkv',
          'avi',
          'mov',
        ],
        dialogTitle: 'Select audio/video file for waveform',
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      await ref
          .read(waveformControllerProvider.notifier)
          .dispatch(LoadAudioFile(filePath));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
