import 'dart:math';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Lightweight index scrollbar for the Editor subtitle list.
///
/// The thumb position is driven by a ValueNotifier so scrolling only rebuilds
/// this widget, not the full Editor screen.
class EditorCustomScrollbar extends StatelessWidget {
  final ValueNotifier<double> thumbOffset;
  final int itemCount;
  final ItemScrollController itemScrollController;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const EditorCustomScrollbar({
    super.key,
    required this.thumbOffset,
    required this.itemCount,
    required this.itemScrollController,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollableHeight = constraints.maxHeight;
          final thumbHeight = max(50.0, scrollableHeight * 0.1);
          final trackHeight = scrollableHeight - thumbHeight;

          return ValueListenableBuilder<double>(
            valueListenable: thumbOffset,
            builder: (context, offset, child) {
              final thumbTop = offset * trackHeight;

              return GestureDetector(
                onVerticalDragStart: (_) => onDragStart(),
                onVerticalDragUpdate: (details) {
                  if (itemCount <= 0) return;

                  final currentThumbHeight =
                      max(50.0, scrollableHeight * 0.1);
                  final currentTrackHeight =
                      scrollableHeight - currentThumbHeight;
                  if (currentTrackHeight <= 0) return;

                  final localY = details.localPosition.dy - 8;
                  final newOffset =
                      (localY / currentTrackHeight).clamp(0.0, 1.0);

                  thumbOffset.value = newOffset;

                  final targetIndex = (newOffset * itemCount)
                      .round()
                      .clamp(0, itemCount - 1);

                  if (itemScrollController.isAttached) {
                    itemScrollController.jumpTo(
                      index: targetIndex,
                      alignment: 0,
                    );
                  }
                },
                onVerticalDragEnd: (_) => onDragEnd(),
                onVerticalDragCancel: onDragEnd,
                child: Container(
                  width: 20,
                  margin: const EdgeInsets.only(
                    right: 0,
                    top: 8,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: thumbTop,
                        left: 4,
                        right: 4,
                        child: Container(
                          height: thumbHeight,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
