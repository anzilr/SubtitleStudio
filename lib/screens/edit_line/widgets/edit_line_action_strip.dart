import 'package:flutter/material.dart';

/// Preserves the original single-row action order across screen sizes.
/// All supplied tools remain directly accessible instead of using a
/// secondary expandable row on compact phones.
class EditLineActionStrip extends StatelessWidget {
  const EditLineActionStrip({
    super.key,
    required this.previous,
    required this.dictionary,
    required this.formatting,
    required this.save,
    required this.next,
    this.subtitleActions,
    this.playPause,
  });

  final Widget previous;
  final Widget dictionary;
  final Widget formatting;
  final Widget? subtitleActions;
  final Widget save;
  final Widget? playPause;
  final Widget next;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('edit-line-actions-row'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        previous,
        dictionary,
        formatting,
        if (subtitleActions != null) subtitleActions!,
        save,
        if (playPause != null) playPause!,
        next,
      ],
    );
  }
}
