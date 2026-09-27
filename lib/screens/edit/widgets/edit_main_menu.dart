import 'package:flutter/material.dart';

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
          ),
  );
}

List<PopupMenuEntry<String>> _timelineItems({
  required bool isVideoLoaded,
  required bool floatingControlsEnabled,
  required bool isWaveformLoaded,
  required bool isWaveformVisible,
  required bool hasSecondarySubtitles,
  required bool showSecondarySubtitles,
  required bool isMsoneEnabled,
}) {
  return <PopupMenuEntry<String>>[
    const PopupMenuItem<String>(
      value: 'switch_to_source',
      child: _MenuItem(
        icon: Icons.code,
        title: 'Switch to Source View',
        color: Colors.purple,
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem<String>(
      value: 'load_video',
      child: _MenuItem(
        icon: isVideoLoaded ? Icons.videocam_off : Icons.video_file,
        title: isVideoLoaded ? 'Unload Video' : 'Load Video',
        color: Colors.blue,
      ),
    ),
    if (isVideoLoaded)
      PopupMenuItem<String>(
        value: 'toggle_controls',
        child: _MenuItem(
          icon: floatingControlsEnabled
              ? Icons.close_fullscreen
              : Icons.open_in_full,
          title: floatingControlsEnabled
              ? 'Hide Floating Controls'
              : 'Show Floating Controls',
          color: Colors.indigo,
        ),
      ),
    if (isVideoLoaded)
      PopupMenuItem<String>(
        value: 'generate_waveform',
        child: _MenuItem(
          icon: Icons.graphic_eq,
          title: isWaveformLoaded
              ? (isWaveformVisible ? 'Hide Waveform' : 'Show Waveform')
              : 'Generate Waveform',
          color: Colors.deepPurple,
        ),
      ),
    if (isVideoLoaded && isWaveformLoaded)
      const PopupMenuItem<String>(
        value: 'regenerate_waveform',
        child: _MenuItem(
          icon: Icons.refresh,
          title: 'Regenerate Waveform',
          color: Colors.orange,
        ),
      ),
    const PopupMenuItem<String>(
      value: 'secondary_subtitle',
      child: _MenuItem(
        icon: Icons.subtitles,
        title: 'Load Secondary Subtitle',
        color: Colors.teal,
      ),
    ),
    if (hasSecondarySubtitles)
      PopupMenuItem<String>(
        value: 'toggle_secondary',
        child: _MenuItem(
          icon: showSecondarySubtitles
              ? Icons.visibility
              : Icons.visibility_off,
          title: showSecondarySubtitles
              ? 'Hide Secondary'
              : 'Show Secondary',
          color: Colors.cyan,
        ),
      ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'save',
      child: _MenuItem(
        icon: Icons.save,
        title: 'Save',
        color: Colors.green,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'save_file_as',
      child: _MenuItem(
        icon: Icons.file_open_outlined,
        title: 'Save File As',
        color: Colors.orange,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'save_project',
      child: _MenuItem(
        icon: Icons.save_alt,
        title: 'Save Project',
        color: Colors.blue,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'project_settings',
      child: _MenuItem(
        icon: Icons.settings,
        title: 'Project Settings',
        color: Colors.indigo,
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'goto',
      child: _MenuItem(
        icon: Icons.menu_open,
        title: 'Go to Line',
        color: Colors.orange,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'find_replace',
      child: _MenuItem(
        icon: Icons.find_replace,
        title: 'Find & Replace',
        color: Colors.purple,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'marked_lines',
      child: _MenuItem(
        icon: Icons.bookmark_added,
        title: 'Show Marked Lines',
        color: Colors.red,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'checkpoint_history',
      child: _MenuItem(
        icon: Icons.history,
        title: 'Edit History',
        color: Colors.deepPurple,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'import_comments',
      child: _MenuItem(
        icon: Icons.comment_outlined,
        title: 'Import Comments',
        color: Colors.green,
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'sync',
      child: _MenuItem(
        icon: Icons.sync,
        title: 'Sync Subtitles',
        color: Colors.amber,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'remove_hearing_impaired',
      child: _MenuItem(
        icon: Icons.hearing_disabled,
        title: 'Remove Hearing Impaired',
        color: Colors.brown,
      ),
    ),
    if (isMsoneEnabled) ...[
      const PopupMenuItem<String>(
        value: 'banners',
        child: _MenuItem(
          icon: Icons.add_box,
          title: 'Insert Banners',
          color: Colors.lightGreen,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'malayalam_normalize',
        child: _MenuItem(
          icon: Icons.translate,
          title: 'Malayalam Normalize',
          color: Colors.deepOrange,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'submit_msone',
        child: _MenuItem(
          icon: Icons.cloud_upload,
          title: 'Submit to Msone',
          color: Colors.pink,
        ),
      ),
    ],
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'settings',
      child: _MenuItem(
        icon: Icons.settings,
        title: 'Settings',
        color: Colors.grey,
      ),
    ),
    const PopupMenuItem<String>(
      value: 'help',
      child: _MenuItem(
        icon: Icons.help_outline,
        title: 'Help & Documentation',
        color: Colors.blueGrey,
      ),
    ),
  ];
}

List<PopupMenuEntry<String>> _sourceViewItems() {
  return const <PopupMenuEntry<String>>[
    PopupMenuItem<String>(
      value: 'switch_to_timeline',
      child: _MenuItem(
        icon: Icons.timeline,
        title: 'Switch to Timeline View',
        color: Colors.blue,
      ),
    ),
    PopupMenuDivider(),
    PopupMenuItem<String>(
      value: 'save',
      child: _MenuItem(
        icon: Icons.save,
        title: 'Save',
        color: Colors.green,
      ),
    ),
    PopupMenuDivider(),
    PopupMenuItem<String>(
      value: 'settings',
      child: _MenuItem(
        icon: Icons.settings,
        title: 'Settings',
        color: Colors.grey,
      ),
    ),
    PopupMenuItem<String>(
      value: 'help',
      child: _MenuItem(
        icon: Icons.help_outline,
        title: 'Help & Documentation',
        color: Colors.blueGrey,
      ),
    ),
  ];
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _MenuItem({
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
