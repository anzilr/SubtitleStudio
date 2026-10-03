import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';

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
    return Dismissible(
      key: ValueKey('subtitle_${line.index}_$index'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.green,
        ),
        child: const Icon(
          Icons.edit,
          color: Colors.white,
          size: 30,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.blue,
        ),
        child: const Icon(
          Icons.select_all,
          color: Colors.white,
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
            ? const Color(0xFF2A9D8F).withAlpha(77)
            : (isCardHighlighted
                ? (isLightTheme
                    ? const Color(0xFF6C757D)
                    : const Color(0xFF005F73))
                : null),
        margin: const EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
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
                              color: isLightTheme
                                  ? (isCueHighlighted
                                      ? const Color.fromARGB(
                                          200,
                                          244,
                                          163,
                                          97,
                                        )
                                      : const Color.fromARGB(
                                          158,
                                          0,
                                          45,
                                          54,
                                        ))
                                  : const Color.fromARGB(
                                      158,
                                      244,
                                      163,
                                      97,
                                    ),
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
                                    child: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 8,
                                        right: 4,
                                      ),
                                      child: Icon(
                                        Icons.bookmark_added,
                                        color: Colors.red,
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
                                  color: isLightTheme
                                      ? (isCueHighlighted
                                          ? const Color.fromARGB(
                                              200,
                                              244,
                                              163,
                                              97,
                                            )
                                          : const Color.fromARGB(
                                              158,
                                              0,
                                              45,
                                              54,
                                            ))
                                      : const Color.fromARGB(
                                          158,
                                          244,
                                          163,
                                          97,
                                        ),
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
                                color: isLightTheme
                                    ? (isCueHighlighted
                                        ? Colors.white
                                        : const Color.fromARGB(
                                            158,
                                            0,
                                            45,
                                            54,
                                          ))
                                    : Colors.white,
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
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: Icon(
                        Icons.check_circle,
                        color: Color(0xFF3A86FF),
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
