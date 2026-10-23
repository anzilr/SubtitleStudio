import 'package:flutter/widgets.dart';

/// Identifies the inline player slot independently of its responsive height.
///
/// The resizable video layout owns its own presentation slot but shares the
/// actual VideoPlayerWidget GlobalKey. Only one slot may enter the widget tree.
class EditLineVideoSlot {
  const EditLineVideoSlot._();

  static const Key inlinePlayer = ValueKey('edit-line-inline-video');
  static const Key inlineSpacing = ValueKey('edit-line-inline-video-spacing');

  static List<Widget> withoutInlineVideo(List<Widget> children) => [
    for (final child in children)
      if (child.key != inlinePlayer && child.key != inlineSpacing) child,
  ];
}
