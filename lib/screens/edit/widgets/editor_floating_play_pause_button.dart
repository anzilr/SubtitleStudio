import 'package:flutter/material.dart';

/// Editor's optional floating transport action. Playback logic stays with the
/// media player; colors come from the selected skin in every appearance mode.
class EditorFloatingPlayPauseButton extends StatelessWidget {
  const EditorFloatingPlayPauseButton({
    super.key,
    required this.playing,
    required this.initiallyPlaying,
    required this.onPressed,
  });

  final Stream<bool> playing;
  final bool initiallyPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      heroTag: 'floatingPlayPause',
      onPressed: onPressed,
      tooltip: 'Play or pause video',
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: StreamBuilder<bool>(
        stream: playing,
        initialData: initiallyPlaying,
        builder: (context, snapshot) => Icon(
          snapshot.data == true ? Icons.pause : Icons.play_arrow,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
