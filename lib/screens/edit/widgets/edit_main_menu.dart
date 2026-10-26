import 'package:flutter/material.dart';
import 'package:subtitle_studio/themes/studio_menu_item.dart';

Future<String?> showEditMainMenu({
  required BuildContext context,
  required bool isSourceView,
  required bool isVideoLoaded,
  required bool floatingControlsEnabled,
  required bool isWaveformLoaded,
  required bool isWaveformVisible,
  required bool hasSecondarySubtitles,
  required bool showSecondarySubtitles,
  required bool isMsoneEnabled,
}) async {
  // A pop result resolves before the popup's EXIT animation finishes.
  // The modal barrier can still intercept taps at that point. Capture
  // the popup route from its MSone menu item and wait for completed.
  ModalRoute<dynamic>? popupRoute;
  final selection = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      MediaQuery.of(context).size.width - 10,
      kToolbarHeight + 10,
      10,
      0,
    ),
    items: isSourceView
        ? _sourceViewItems()
        : _timelineItems(
            isVideoLoaded: isVideoLoaded,
            floatingControlsEnabled: floatingControlsEnabled,
            isWaveformLoaded: isWaveformLoaded,
            isWaveformVisible: isWaveformVisible,
            hasSecondarySubtitles: hasSecondarySubtitles,
            showSecondarySubtitles: showSecondarySubtitles,
            isMsoneEnabled: isMsoneEnabled,
            onMenuRouteMounted: (route) => popupRoute = route,
          ),
  );
  if (selection == 'submit_msone' && popupRoute != null) {
    await popupRoute!.completed;
    debugPrint('MSone flow: main menu modal barrier removed');
  }
  return selection;
}

List<PopupMenuEntry<String>> _timelineItems({
  required bool isVideoLoaded,
  required bool floatingControlsEnabled,
  required bool isWaveformLoaded,
  required bool isWaveformVisible,
  required bool hasSecondarySubtitles,
  required bool showSecondarySubtitles,
  required bool isMsoneEnabled,
  required ValueChanged<ModalRoute<dynamic>> onMenuRouteMounted,
}) {
  return <PopupMenuEntry<String>>[
    const PopupMenuItem<String>(
      value: 'switch_to_source',
      child: StudioMenuItemContent(
        icon: Icons.code,
        title: 'Switch to Source View',
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem<String>(
      value: 'load_video',
      child: StudioMenuItemContent(
        icon: isVideoLoaded ? Icons.videocam_off : Icons.video_file,
        title: isVideoLoaded ? 'Unload Video' : 'Load Video',
      ),
    ),
    if (isVideoLoaded)
      PopupMenuItem<String>(
        value: 'toggle_controls',
        child: StudioMenuItemContent(
          icon: floatingControlsEnabled
              ? Icons.close_fullscreen
              : Icons.open_in_full,
          title: floatingControlsEnabled
              ? 'Hide Floating Controls'
              : 'Show Floating Controls',
        ),
      ),
    if (isVideoLoaded)
      PopupMenuItem<String>(
        value: 'generate_waveform',
        child: StudioMenuItemContent(
          icon: Icons.graphic_eq,
          title: isWaveformLoaded
              ? (isWaveformVisible ? 'Hide Waveform' : 'Show Waveform')
              : 'Generate Waveform',
        ),
      ),
    if (isVideoLoaded && isWaveformLoaded)
      const PopupMenuItem<String>(
        value: 'regenerate_waveform',
        child: StudioMenuItemContent(
          icon: Icons.refresh,
          title: 'Regenerate Waveform',
        ),
      ),
    const PopupMenuItem<String>(
      value: 'secondary_subtitle',
      child: StudioMenuItemContent(
        icon: Icons.subtitles,
        title: 'Load Secondary Subtitle',
      ),
    ),
    if (hasSecondarySubtitles)
      PopupMenuItem<String>(
        value: 'toggle_secondary',
        child: StudioMenuItemContent(
          icon: showSecondarySubtitles
              ? Icons.visibility
              : Icons.visibility_off,
          title: showSecondarySubtitles
              ? 'Hide Secondary'
              : 'Show Secondary',
        ),
      ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'save',
      child: StudioMenuItemContent(
        icon: Icons.save,
        title: 'Save',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'save_file_as',
      child: StudioMenuItemContent(
        icon: Icons.file_open_outlined,
        title: 'Save File As',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'save_project',
      child: StudioMenuItemContent(
        icon: Icons.save_alt,
        title: 'Save Project',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'project_settings',
      child: StudioMenuItemContent(
        icon: Icons.settings,
        assetIcon: 'assets/project_settings.svg',
        title: 'Project Settings',
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'goto',
      child: StudioMenuItemContent(
        icon: Icons.menu_open,
        title: 'Go to Line',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'find_replace',
      child: StudioMenuItemContent(
        icon: Icons.find_replace,
        title: 'Find & Replace',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'marked_lines',
      child: StudioMenuItemContent(
        icon: Icons.bookmark_added,
        title: 'Show Marked Lines',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'checkpoint_history',
      child: StudioMenuItemContent(
        icon: Icons.history,
        title: 'Edit History',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'import_comments',
      child: StudioMenuItemContent(
        icon: Icons.comment_outlined,
        title: 'Import Comments',
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'sync',
      child: StudioMenuItemContent(
        icon: Icons.sync,
        title: 'Sync Subtitles',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'remove_hearing_impaired',
      child: StudioMenuItemContent(
        icon: Icons.hearing_disabled,
        title: 'Remove Hearing Impaired',
      ),
    ),
    if (isMsoneEnabled) ...[
      const PopupMenuItem<String>(
        value: 'banners',
        child: StudioMenuItemContent(
          icon: Icons.add_box,
          title: 'Insert Banners',
        ),
      ),
      const PopupMenuItem<String>(
        value: 'malayalam_normalize',
        child: StudioMenuItemContent(
          icon: Icons.translate,
          title: 'Malayalam Normalize',
        ),
      ),
      PopupMenuItem<String>(
        value: 'submit_msone',
        child: Builder(
          builder: (menuContext) {
            // This context belongs to PopupMenuRoute rather than the editor.
            final menuRoute = ModalRoute.of(menuContext);
            if (menuRoute != null) onMenuRouteMounted(menuRoute);
            return const StudioMenuItemContent(
              icon: Icons.cloud_upload,
              title: 'Submit to Msone',
            );
          },
        ),
      ),
    ],
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'settings',
      child: StudioMenuItemContent(
        icon: Icons.settings,
        title: 'Settings',
      ),
    ),
    const PopupMenuItem<String>(
      value: 'help',
      child: StudioMenuItemContent(
        icon: Icons.help_outline,
        title: 'Help & Documentation',
      ),
    ),
  ];
}

List<PopupMenuEntry<String>> _sourceViewItems() {
  return const <PopupMenuEntry<String>>[
    PopupMenuItem<String>(
      value: 'switch_to_timeline',
      child: StudioMenuItemContent(
        icon: Icons.timeline,
        title: 'Switch to Timeline View',
      ),
    ),
    PopupMenuDivider(),
    PopupMenuItem<String>(
      value: 'save',
      child: StudioMenuItemContent(
        icon: Icons.save,
        title: 'Save',
      ),
    ),
    PopupMenuDivider(),
    PopupMenuItem<String>(
      value: 'settings',
      child: StudioMenuItemContent(
        icon: Icons.settings,
        title: 'Settings',
      ),
    ),
    PopupMenuItem<String>(
      value: 'help',
      child: StudioMenuItemContent(
        icon: Icons.help_outline,
        title: 'Help & Documentation',
      ),
    ),
  ];
}

Future<String?> showEditSelectionMenu({
  required BuildContext context,
  Offset? position,
}) {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;

  final RelativeRect menuPosition;
  if (position != null && overlay != null) {
    menuPosition = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    );
  } else {
    menuPosition = RelativeRect.fromLTRB(
      MediaQuery.of(context).size.width - 10,
      kToolbarHeight + 10,
      10,
      0,
    );
  }

  return showMenu<String>(
    context: context,
    position: menuPosition,
    items: const <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'copy',
        child: StudioMenuItemContent(
          icon: Icons.content_copy,
          title: 'Copy Selected',
        ),
      ),
      PopupMenuItem<String>(
        value: 'shift_times',
        child: StudioMenuItemContent(
          icon: Icons.timer,
          title: 'Shift Times',
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        child: StudioMenuItemContent(
          icon: Icons.delete,
          title: 'Delete Selected',
          tone: StudioMenuItemTone.destructive,
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'select_by_index',
        child: StudioMenuItemContent(
          icon: Icons.format_list_numbered,
          title: 'Select by Index',
        ),
      ),
      PopupMenuItem<String>(
        value: 'range_selection',
        child: StudioMenuItemContent(
          icon: Icons.format_line_spacing,
          title: 'Select by Range',
        ),
      ),
    ],
  );
}

