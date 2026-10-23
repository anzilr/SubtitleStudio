/// Subtitle data structure for video overlay rendering.
///
/// Kept independent from the video widget so timing/index algorithms can be
/// tested without importing the complete player UI. video_player_widget.dart
/// re-exports this type for backwards compatibility with existing imports.
class Subtitle {
  final int index;
  final Duration start;
  final Duration end;
  final String text;
  final bool marked;
  final String? comment;

  const Subtitle({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
    this.marked = false,
    this.comment,
  });
}
