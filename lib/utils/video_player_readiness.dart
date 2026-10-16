import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';

/// Waits until a keyed VideoPlayerWidget exists and reports initialized.
///
/// This uses rendered frames rather than arbitrary wall-clock sleeps, keeping
/// readiness behavior consistent across Android, iOS, macOS, Windows and Linux.
Future<VideoPlayerWidgetState?> waitForVideoPlayerReady(
  GlobalKey<VideoPlayerWidgetState> key, {
  int maxFrames = 120,
}) async {
  for (int frame = 0; frame < maxFrames; frame++) {
    final state = key.currentState;
    if (state != null && state.isInitialized()) {
      return state;
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  final state = key.currentState;
  return state != null && state.isInitialized() ? state : null;
}
