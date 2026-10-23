import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';

/// Compile-time regression for the fullscreen-comment entry point.
///
/// These calls appear in EditScreen and EditSubtitleScreen. If another
/// extension declares the same public method on VideoPlayerWidgetState,
/// this test fails to compile with ambiguous_extension_member_access.
void _invokeFullscreenComment(
  VideoPlayerWidgetState state,
  Subtitle subtitle,
) {
  state.showFullscreenCommentDialog(subtitle);
  state.showFullscreenCommentDialog(
    subtitle,
    originalText: 'Original',
    editedText: 'Edited',
  );
}

void main() {
  test('public fullscreen comment API resolves to one extension', () {
    expect(_invokeFullscreenComment, isA<Function>());
  });
}
