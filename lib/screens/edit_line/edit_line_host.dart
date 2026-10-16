import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_state.dart';
import 'package:subtitle_studio/screens/screen_edit_line.dart' as legacy;
import 'package:subtitle_studio/utils/subtitle_parser.dart';

/// Compatibility wrapper for [legacy.EditSubtitleScreen].
///
/// This host scopes the single-line editor's Riverpod providers.
class EditSubtitleScreenHost extends StatefulWidget {
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
  State<EditSubtitleScreenHost> createState() =>
      _EditSubtitleScreenHostState();
}

class _EditSubtitleScreenHostState extends State<EditSubtitleScreenHost> {
  // Do not recreate Riverpod configuration overrides when the app theme
  // changes. An override update would tear down EditLineController and the
  // inner editing screen, potentially dropping unsaved text and listeners.
  late List<Override> _stableOverrides;

  @override
  void initState() {
    super.initState();
    _resetOverrides();
  }

  void _resetOverrides() {
    _stableOverrides = [
      editLineConfigurationProvider.overrideWithValue(
        EditLineConfiguration(
          subtitleCollectionId: widget.subtitleId,
          lineIndex: widget.index,
          sessionId: widget.sessionId,
          isNewSubtitle: widget.isNewSubtitle,
          isEditMode: widget.editMode,
          videoPath: widget.videoPath,
          isVideoLoaded: widget.isVideoLoaded,
          secondarySubtitles: widget.secondarySubtitles,
        ),
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant EditSubtitleScreenHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitleId != widget.subtitleId ||
        oldWidget.index != widget.index ||
        oldWidget.sessionId != widget.sessionId ||
        oldWidget.isNewSubtitle != widget.isNewSubtitle ||
        oldWidget.editMode != widget.editMode ||
        oldWidget.videoPath != widget.videoPath ||
        oldWidget.isVideoLoaded != widget.isVideoLoaded ||
        !identical(oldWidget.secondarySubtitles, widget.secondarySubtitles)) {
      _resetOverrides();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey('edit-line-scope-${widget.sessionId}-${widget.subtitleId}-${widget.index}'),
      overrides: _stableOverrides,
      child: _EditLineRiverpodHost(
        subtitleId: widget.subtitleId,
        index: widget.index,
        sessionId: widget.sessionId,
        isNewSubtitle: widget.isNewSubtitle,
        editMode: widget.editMode,
        videoPath: widget.videoPath,
        isVideoLoaded: widget.isVideoLoaded,
        startVideoPosition: widget.startVideoPosition,
        secondarySubtitles: widget.secondarySubtitles,
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
