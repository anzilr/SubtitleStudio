import 'package:flutter/material.dart';

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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    color: Theme.of(context).cardColor,
    elevation: 8,
    items: <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'settings',
        child: _EditLineMenuItem(
          icon: Icons.settings,
          title: 'Settings',
          color: Colors.blue,
        ),
      ),
      if (isEditMode || isNewSubtitle) ...[
        const PopupMenuDivider(),
        if (!isVideoLoaded)
          const PopupMenuItem<String>(
            value: 'loadVideo',
            child: _EditLineMenuItem(
              icon: Icons.video_file,
              title: 'Load Video',
              color: Colors.purple,
            ),
          ),
        if (isVideoLoaded)
          const PopupMenuItem<String>(
            value: 'unloadVideo',
            child: _EditLineMenuItem(
              icon: Icons.video_camera_back,
              title: 'Unload Video',
              color: Colors.deepOrange,
            ),
          ),
      ],
      if (isVideoLoaded) ...[
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'loadSecondarySubtitle',
          child: _EditLineMenuItem(
            icon: Icons.subtitles,
            title: 'Load Secondary Subtitle',
            color: Colors.teal,
          ),
        ),
        if (hasSecondarySubtitles)
          PopupMenuItem<String>(
            value: 'toggleSecondarySubtitle',
            child: _EditLineMenuItem(
              icon: showSecondarySubtitles
                  ? Icons.visibility
                  : Icons.visibility_off,
              title: showSecondarySubtitles
                  ? 'Hide Secondary'
                  : 'Show Secondary',
              color: Colors.cyan,
            ),
          ),
      ],
      if (isVideoLoaded && isMobilePlatform) ...[
        if (!hasSecondarySubtitles) const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'autoResizeOnKeyboard',
          child: _EditLineMenuItem(
            icon: autoResizeOnKeyboard
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            title: 'Resize Player on Keyboard',
            color: Colors.green,
          ),
        ),
      ],
      if (!isEditMode) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'showOriginal',
          child: _EditLineMenuItem(
            icon: showOriginalLine
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            title: 'Show Original Line',
            color: Colors.orange,
          ),
        ),
        if (showOriginalLine)
          PopupMenuItem<String>(
            value: 'autoSave',
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: _EditLineMenuItem(
                icon: autoSaveWithNavigation
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                title: 'Auto-save with navigation',
                color: Colors.green,
              ),
            ),
          ),
      ],
      PopupMenuItem<String>(
        value: 'toggleOriginalField',
        child: _EditLineMenuItem(
          icon: showOriginalTextField
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          title: 'Show Original Text Field',
          color: Colors.blue,
        ),
      ),
      PopupMenuItem<String>(
        value: 'toggleFormatted',
        child: _EditLineMenuItem(
          icon: isFormattedView
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          title: 'Formatted View',
          color: Colors.green,
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'markLine',
        child: _EditLineMenuItem(
          icon: isMarked
              ? Icons.bookmark_remove
              : Icons.bookmark_add,
          title: isMarked ? 'Unmark Line' : 'Mark Line',
          color: isMarked ? Colors.grey : Colors.red,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'showMarkedLines',
        child: _EditLineMenuItem(
          icon: Icons.bookmark,
          title: 'Show in Marked Lines',
          color: Colors.red,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'checkpointHistory',
        child: _EditLineMenuItem(
          icon: Icons.history,
          title: 'Edit History',
          color: Colors.deepPurple,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'jumpToLine',
        child: _EditLineMenuItem(
          icon: Icons.arrow_upward_rounded,
          title: 'Jump to Line',
          color: Colors.orange,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: _EditLineMenuItem(
          icon: Icons.delete,
          title: 'Delete Subtitle Line',
          color: Colors.red,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'help',
        child: _EditLineMenuItem(
          icon: Icons.help_outline,
          title: 'Help & Documentation',
          color: Colors.purple,
        ),
      ),
    ],
  );
}

class _EditLineMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _EditLineMenuItem({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
