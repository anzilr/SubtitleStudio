import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_state.dart';
import 'package:subtitle_studio/screens/screen_edit_line.dart' as legacy;
import 'package:subtitle_studio/utils/subtitle_parser.dart';

/// Compatibility wrapper for [legacy.EditSubtitleScreen].
///
/// This host scopes the single-line editor's Riverpod providers.
class EditSubtitleScreenHost extends StatelessWidget {
  final int subtitleId;
  final int index;
  final int sessionId;
  final bool isNewSubtitle;
  final bool editMode;
  final String? videoPath;
  final bool isVideoLoaded;
  final Duration? startVideoPosition;
  final List<SimpleSubtitleLine>? secondarySubtitles;

  const EditSubtitleScreenHost({
    super.key,
    required this.subtitleId,
    required this.index,
    required this.sessionId,
    this.isNewSubtitle = false,
    this.editMode = false,
    this.videoPath,
    this.isVideoLoaded = false,
    this.startVideoPosition,
    this.secondarySubtitles,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        editLineConfigurationProvider.overrideWithValue(
          EditLineConfiguration(
            subtitleCollectionId: subtitleId,
            lineIndex: index,
            sessionId: sessionId,
            isNewSubtitle: isNewSubtitle,
            isEditMode: editMode,
            videoPath: videoPath,
            isVideoLoaded: isVideoLoaded,
            secondarySubtitles: secondarySubtitles,
          ),
        ),
      ],
      child: _EditLineRiverpodHost(
        subtitleId: subtitleId,
        index: index,
        sessionId: sessionId,
        isNewSubtitle: isNewSubtitle,
        editMode: editMode,
        videoPath: videoPath,
        isVideoLoaded: isVideoLoaded,
        startVideoPosition: startVideoPosition,
        secondarySubtitles: secondarySubtitles,
      ),
    );
  }
}

class _EditLineRiverpodHost extends ConsumerStatefulWidget {
  final int subtitleId;
  final int index;
  final int sessionId;
  final bool isNewSubtitle;
  final bool editMode;
  final String? videoPath;
  final bool isVideoLoaded;
  final Duration? startVideoPosition;
  final List<SimpleSubtitleLine>? secondarySubtitles;

  const _EditLineRiverpodHost({
    required this.subtitleId,
    required this.index,
    required this.sessionId,
    required this.isNewSubtitle,
    required this.editMode,
    required this.videoPath,
    required this.isVideoLoaded,
    required this.startVideoPosition,
    required this.secondarySubtitles,
  });

  @override
  ConsumerState<_EditLineRiverpodHost> createState() =>
      _EditLineRiverpodHostState();
}

class _EditLineRiverpodHostState extends ConsumerState<_EditLineRiverpodHost> {
  bool _initializationStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initializationStarted) return;
    _initializationStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(editLineControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editLineControllerProvider);

    ref.listen<EditLineState>(editLineControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(editLineControllerProvider.notifier).clearError();
      }
    });

    if (state.isLoading && !state.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isNewSubtitle ? 'New Subtitle' : 'Loading...'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading subtitle...'),
            ],
          ),
        ),
      );
    }

    return legacy.EditSubtitleScreen(
      subtitleId: widget.subtitleId,
      index: widget.index,
      sessionId: widget.sessionId,
      isNewSubtitle: widget.isNewSubtitle,
      editMode: widget.editMode,
      videoPath: widget.videoPath,
      isVideoLoaded: widget.isVideoLoaded,
      startVideoPosition: widget.startVideoPosition,
      secondarySubtitles: widget.secondarySubtitles,
    );
  }
}
