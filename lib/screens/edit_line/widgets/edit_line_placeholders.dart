import 'package:flutter/material.dart';

const List<String> editLineInstructions = [
  'Use the text field to edit the subtitle line.',
  'Tap the "Edit Time" button to edit timing (start/end times) for the subtitle.',
  'Navigate between subtitle lines using the arrow buttons or the line number input.',
  'The changes will be saved automatically while navigating, or you can save manually using the save button.',
  'Enable "Auto-Save to File" in the settings to save changes directly to the file.',
  'Use the formatting menu to apply text styles like bold, italic and color.',
  'The palette icon opens the color picker for text formatting.',
];

class NoVideoPlaceholder extends StatelessWidget {
  final VoidCallback onLoadVideo;

  const NoVideoPlaceholder({
    super.key,
    required this.onLoadVideo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 80,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No video loaded',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onLoadVideo,
            icon: const Icon(Icons.video_file),
            label: const Text('Load Video'),
          ),
        ],
      ),
    );
  }
}

class EmptySubtitleView extends StatelessWidget {
  final Future<void> Function() onAddSubtitle;

  const EmptySubtitleView({
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
