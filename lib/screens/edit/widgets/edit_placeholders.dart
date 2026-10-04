import 'package:flutter/material.dart';

const List<String> editScreenInstructions = [
  'Tap any subtitle line to seek video to that exact time.',
  'Double-tap or swipe a line to the right to edit the subtitle text.',
  'Long press a line to enter selection mode for batch operations.',
  'Use the menu (⋮) in the top right corner to access video loading, save, search & replace, and more features.',
  'The app does not save the changes to the file. Use the "Save" or "Save File As" option in the menu to save your changes to file.',
  'Selected lines can be copied, deleted, or have their timecodes shifted together.',
];

class EditorEmptySubtitleView extends StatelessWidget {
  final Future<void> Function() onAddSubtitle;

  const EditorEmptySubtitleView({
    super.key,
    required this.onAddSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.subtitles_outlined,
            size: 80,
            color: Color(0xFF0A9396),
          ),
          const SizedBox(height: 24),
          const Text(
            'No subtitles yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get started by adding your first subtitle line',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              onAddSubtitle();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color.fromARGB(255, 1, 54, 64),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
            label: const Text(
              'Add Subtitle Line',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
