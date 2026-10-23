import 'package:flutter/material.dart';

/// Keeps the frequent editing actions visible on narrow portrait phones.
///
/// The caller supplies Flex-compatible children with their existing handlers.
/// Tools are only hidden in compact mode; wide layouts retain the same order
/// and action widgets as before. This widget owns only the expansion toggle.
class EditLineActionStrip extends StatefulWidget {
  const EditLineActionStrip({
    super.key,
    required this.compact,
    required this.previous,
    required this.dictionary,
    required this.formatting,
    required this.save,
    required this.next,
    this.subtitleActions,
    this.playPause,
  });

  final bool compact;
  final Widget previous;
  final Widget dictionary;
  final Widget formatting;
  final Widget? subtitleActions;
  final Widget save;
  final Widget? playPause;
  final Widget next;

  @override
  State<EditLineActionStrip> createState() => _EditLineActionStripState();
}

class _EditLineActionStripState extends State<EditLineActionStrip> {
  bool _toolsExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          widget.previous,
          widget.dictionary,
          widget.formatting,
          if (widget.subtitleActions != null) widget.subtitleActions!,
          widget.save,
          if (widget.playPause != null) widget.playPause!,
          widget.next,
        ],
      );
    }

    return Column(
      key: const ValueKey('edit-line-compact-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            widget.previous,
            widget.save,
            if (widget.playPause != null) widget.playPause!,
            widget.next,
            Flexible(
              child: IconButton(
                key: const ValueKey('edit-line-tools-toggle'),
                tooltip: _toolsExpanded
                    ? 'Hide editing tools'
                    : 'Show editing tools',
                onPressed: () => setState(() => _toolsExpanded = !_toolsExpanded),
                icon: Icon(
                  _toolsExpanded ? Icons.expand_less : Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (_toolsExpanded)
          Row(
            key: const ValueKey('edit-line-extra-tools'),
            children: [
              widget.dictionary,
              widget.formatting,
              if (widget.subtitleActions != null) widget.subtitleActions!,
            ],
          ),
      ],
    );
  }
}
