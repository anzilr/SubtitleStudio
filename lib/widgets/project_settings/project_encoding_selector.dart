import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/subtitle_encoding_picker.dart';

/// Project-level encoding choice. The caller supplies the same
/// runtime-verified charset list used by subtitle import and export.
/// The persisted selection is displayed even when a native codec is absent.
class ProjectEncodingSelector extends StatelessWidget {
  const ProjectEncodingSelector({
    super.key,
    required this.selected,
    required this.options,
    required this.isLoading,
    required this.isSaving,
    required this.onSelected,
  });

  final String selected;
  final List<String> options;
  final bool isLoading;
  final bool isSaving;
  final Future<void> Function(String) onSelected;

  Future<void> _choose(BuildContext context) async {
    final next = await SubtitleEncodingPicker.show(
      context: context,
      title: 'Project text encoding',
      options: options,
      selected: selected,
    );
    if (!context.mounted || next == null || next == selected) return;
    if (!options.contains(next)) return;
    await onSelected(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAvailable = options.contains(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Character Encoding',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('project-encoding-picker'),
            onPressed: isLoading || isSaving ? null : () => _choose(context),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.text_format, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selected,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading || isSaving)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.search, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Text('Checking supported encodings on this device…')
        else if (isSaving)
          const Text('Saving project encoding…')
        else if (!isAvailable)
          Text(
            'The saved encoding is unavailable on this device. '
            'Select a supported encoding before exporting.',
            style: TextStyle(color: scheme.error),
          )
        else
          Text(
            '${options.length} encodings available on this device. '
            'Search to choose a different encoding.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 4),
        Text(
          'This setting controls the project’s preferred output encoding. '
          'It does not reinterpret subtitle text already loaded into the editor.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
