import 'package:flutter/material.dart';
import 'package:subtitle_studio/themes/studio_menu_item.dart';

Future<String?> showEditLineMenu({
  required BuildContext context,
  required bool isEditMode,
  required bool isNewSubtitle,
  required bool isVideoLoaded,
  required bool hasSecondarySubtitles,
  required bool showSecondarySubtitles,
  required bool autoResizeOnKeyboard,
  required bool isMobilePlatform,
  required bool showOriginalLine,
  required bool autoSaveWithNavigation,
  required bool showOriginalTextField,
  required bool isFormattedView,
  required bool isMarked,
}) {
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      MediaQuery.of(context).size.width - 10,
      kToolbarHeight + 10,
      10,
      0,
    ),
    items: <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'settings',
        child: StudioMenuItemContent(
          icon: Icons.settings,
          title: 'Settings',
        ),
      ),
      if (isEditMode || isNewSubtitle) ...[
        const PopupMenuDivider(),
        if (!isVideoLoaded)
          const PopupMenuItem<String>(
            value: 'loadVideo',
            child: StudioMenuItemContent(
              icon: Icons.video_file,
              title: 'Load Video',
            ),
          ),
        if (isVideoLoaded)
          const PopupMenuItem<String>(
            value: 'unloadVideo',
            child: StudioMenuItemContent(
              icon: Icons.video_camera_back,
              title: 'Unload Video',
            ),
          ),
      ],
      if (isVideoLoaded) ...[
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'loadSecondarySubtitle',
          child: StudioMenuItemContent(
            icon: Icons.subtitles,
            title: 'Load Secondary Subtitle',
          ),
        ),
        if (hasSecondarySubtitles)
          PopupMenuItem<String>(
            value: 'toggleSecondarySubtitle',
            child: StudioMenuItemContent(
              icon: showSecondarySubtitles
                  ? Icons.visibility
                  : Icons.visibility_off,
              title: showSecondarySubtitles
                  ? 'Hide Secondary'
                  : 'Show Secondary',
            ),
          ),
      ],
      if (isVideoLoaded && isMobilePlatform) ...[
        if (!hasSecondarySubtitles) const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'autoResizeOnKeyboard',
          child: StudioMenuItemContent(
            icon: autoResizeOnKeyboard
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            title: 'Resize Player on Keyboard',
          ),
        ),
      ],
      if (!isEditMode) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'showOriginal',
          child: StudioMenuItemContent(
            icon: showOriginalLine
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            title: 'Show Original Line',
          ),
        ),
        if (showOriginalLine)
          PopupMenuItem<String>(
            value: 'autoSave',
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: StudioMenuItemContent(
                icon: autoSaveWithNavigation
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                title: 'Auto-save with navigation',
              ),
            ),
          ),
      ],
      PopupMenuItem<String>(
        value: 'toggleOriginalField',
        child: StudioMenuItemContent(
          icon: showOriginalTextField
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          title: 'Show Original Text Field',
        ),
      ),
      PopupMenuItem<String>(
        value: 'toggleFormatted',
        child: StudioMenuItemContent(
          icon: isFormattedView
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          title: 'Formatted View',
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'markLine',
        child: StudioMenuItemContent(
          icon: isMarked
              ? Icons.bookmark_remove
              : Icons.bookmark_add,
          title: isMarked ? 'Unmark Line' : 'Mark Line',
        ),
      ),
      const PopupMenuItem<String>(
        value: 'showMarkedLines',
        child: StudioMenuItemContent(
          icon: Icons.bookmark,
          assetIcon: 'assets/marked_lines_sheet.svg',
          title: 'Show in Marked Lines',
        ),
      ),
      const PopupMenuItem<String>(
        value: 'checkpointHistory',
        child: StudioMenuItemContent(
          icon: Icons.history,
          title: 'Edit History',
        ),
      ),
      const PopupMenuItem<String>(
        value: 'jumpToLine',
        child: StudioMenuItemContent(
          icon: Icons.arrow_upward_rounded,
          title: 'Jump to Line',
        ),
      ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: StudioMenuItemContent(
          icon: Icons.delete,
          title: 'Delete Subtitle Line',
          tone: StudioMenuItemTone.destructive,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'help',
        child: StudioMenuItemContent(
          icon: Icons.help_outline,
          title: 'Help & Documentation',
        ),
      ),
    ],
  );
}

