import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';

class SubtitleCard extends StatelessWidget {
  final SubtitleLine line;
  final int index;
  final String textContent;
  final String formattedStart;
  final String formattedEnd;
  final bool isSelected;
  final bool isCardHighlighted;
  final bool isCueHighlighted;
  final bool isSelectionMode;
  final bool isRangeSelectionActive;
  final bool isLightTheme;
  final Future<void> Function() onEdit;
  final VoidCallback onSelectRequested;
  final VoidCallback onRangeSelectionTap;
  final VoidCallback onToggleSelection;
  final VoidCallback onHighlightAndSeek;
  final ValueChanged<Offset> onSelectionMenu;
  final VoidCallback onActionsMenu;
  final VoidCallback onComment;
  final VoidCallback onToggleMark;

  const SubtitleCard({
    super.key,
    required this.line,
    required this.index,
    required this.textContent,
    required this.formattedStart,
    required this.formattedEnd,
    required this.isSelected,
    required this.isCardHighlighted,
    required this.isCueHighlighted,
    required this.isSelectionMode,
    required this.isRangeSelectionActive,
    required this.isLightTheme,
    required this.onEdit,
    required this.onSelectRequested,
    required this.onRangeSelectionTap,
    required this.onToggleSelection,
    required this.onHighlightAndSeek,
    required this.onSelectionMenu,
    required this.onActionsMenu,
    required this.onComment,
    required this.onToggleMark,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return Dismissible(
      key: ValueKey('subtitle_${line.index}_$index'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StudioRadius.card),
          color: tokens.primaryAction,
        ),
        child: Icon(
          Icons.edit,
          color: tokens.onPrimaryAction,
          size: 30,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StudioRadius.card),
          color: tokens.editingAccent,
        ),
        child: Icon(
          Icons.select_all,
          color: tokens.onEditingAccent,
          size: 30,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd &&
            !isSelectionMode) {
          await onEdit();
        } else if (direction == DismissDirection.endToStart) {
          onSelectRequested();
        }
        return false;
      },
      child: Card(
        color: isSelected
            ? tokens.primaryAction.withValues(alpha: 0.14)
            : isCardHighlighted
                ? tokens.raisedSurface
                : tokens.surface,
        margin: const EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioRadius.card),
        ),
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons != 2) return;

            if (isSelectionMode || isRangeSelectionActive) {
              onSelectionMenu(event.position);
            } else {
              onActionsMenu();
            }
          },
          child: InkWell(
            onTap: () {
              if (isRangeSelectionActive) {
                onRangeSelectionTap();
              } else if (isSelectionMode) {
                onToggleSelection();
              } else {
                onHighlightAndSeek();
              }
            },
            onDoubleTap: () async {
              if (isSelectionMode || isRangeSelectionActive) {
                return;
              }
              await onEdit();
            },
            onLongPress: () {
              if (isSelectionMode || isRangeSelectionActive) {
                return;
              }
              onActionsMenu();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$formattedStart -> $formattedEnd',
                            style: TextStyle(
                              color: isCueHighlighted
                                  ? tokens.primaryAction
                                  : tokens.mutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily:
                                  GoogleFonts.spaceMono().fontFamily,
                            ),
                            textAlign: TextAlign.end,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (line.marked) ...[
                                Listener(
                                  onPointerDown: (event) {
                                    if (event.kind ==
                                            PointerDeviceKind.mouse &&
                                        event.buttons ==
                                            kSecondaryMouseButton) {
                                      onComment();
                                    }
                                  },
                                  child: GestureDetector(
                                    onLongPress: onComment,
                                    onTap: onToggleMark,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        right: 4,
                                      ),
                                      child: Icon(
                                        Icons.bookmark_added,
                                        color: tokens.primaryAction,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '${line.index}',
                                style: TextStyle(
                                  color: isCueHighlighted
                                      ? tokens.primaryAction
                                      : tokens.mutedText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CustomHtmlText(
                              htmlContent:
                                  textContent.replaceAll('\n', '<br>'),
                              defaultStyle: TextStyle(
                                color: tokens.onSurface,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.start,
                              expanded: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isSelected)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Icon(
                        Icons.check_circle,
                        color: tokens.primaryAction,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
