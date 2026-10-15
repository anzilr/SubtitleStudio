import 'package:flutter/material.dart';
import 'package:subtitle_studio/themes/studio_components.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
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
    final tokens = StudioDesignTokens.of(context);
    final isAvailable = options.contains(selected);

    return StudioSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudioSectionHeader(
            title: 'Character Encoding',
            icon: Icons.language,
          ),
          const SizedBox(height: StudioSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('project-encoding-picker'),
              onPressed: isLoading || isSaving ? null : () => _choose(context),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: tokens.onSurface,
                backgroundColor: tokens.fieldSurface,
                side: BorderSide(color: tokens.outline),
                minimumSize: const Size(0, StudioSizing.touchTarget),
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioSpacing.md,
                  vertical: StudioSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(StudioRadius.input),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.text_format, size: StudioSizing.icon,
                      color: tokens.primaryAction),
                  const SizedBox(width: StudioSpacing.sm),
                  Expanded(
                    child: Text(
                      selected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLoading || isSaving)
                    SizedBox(
                      height: StudioSizing.icon,
                      width: StudioSizing.icon,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.primaryAction,
                      ),
                    )
                  else
                    Icon(Icons.search, size: StudioSizing.icon,
                        color: tokens.primaryAction),
                ],
              ),
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          if (isLoading)
            const StudioStatusMessage(
              message: 'Checking supported encodings on this device…',
            )
          else if (isSaving)
            const StudioStatusMessage(
              message: 'Saving project encoding…',
            )
          else if (!isAvailable)
            const StudioStatusMessage(
              tone: StudioStatusTone.caution,
              message: 'The saved encoding is unavailable on this device. '
                  'Select a supported encoding before exporting.',
            )
          else
            StudioStatusMessage(
              message: '${options.length} encodings available on this device. '
                  'Search to choose a different encoding.',
            ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            'This setting controls the project’s preferred output encoding. '
            'It does not reinterpret subtitle text already loaded into the editor.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
          ),
        ],
      ),
    );
  }
}
