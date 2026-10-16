import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'studio_palette.dart';
import 'studio_skin.dart';
import 'studio_skin_catalog.dart';
import 'studio_skin_catalog_provider.dart';
import 'studio_skin_preview.dart';
import 'studio_theme_factory.dart';
import 'theme_controller.dart';

/// SKIN-3 appearance picker.
///
/// Mode switching already updates the current legacy app theme. Skin changes
/// are saved independently but are preview-only until SKIN-4 replaces the
/// white-on-primary Edit Line fields and activates StudioThemeFactory globally.
class StudioAppearanceSettings extends ConsumerWidget {
  const StudioAppearanceSettings({super.key});

  Future<void> _selectSkin(
    BuildContext context,
    WidgetRef ref,
    StudioSkinId skinId,
  ) async {
    try {
      await ref.read(themeControllerProvider.notifier).setSkin(skinId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not save the skin selection.')),
      );
    }
  }

  Future<void> _selectMode(
    BuildContext context,
    WidgetRef ref,
    StudioAppearance mode,
  ) async {
    try {
      await ref.read(themeControllerProvider.notifier).setAppearance(mode);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not save the appearance mode.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themeControllerProvider);
    final catalog = ref.watch(studioSkinCatalogProvider);
    final missing = catalog.find(state.skinId) == null;
    final selected = catalog.resolveOrDefault(state.skinId);
    final builtIn = catalog.skins.where((skin) => skin.id.isBuiltIn);
    final installed = catalog.skins.where((skin) => !skin.id.isBuiltIn);
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('studio-appearance-settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Appearance',
                  style: theme.textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a skin and a theme mode separately.',
          style: theme.textTheme.bodySmall,
        ),
        if (!state.isLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(
              key: ValueKey('studio-appearance-loading'),
            ),
          ),
        const SizedBox(height: 18),
        Text('Theme mode', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<StudioAppearance>(
          key: const ValueKey('studio-appearance-mode-selector'),
          showSelectedIcon: false,
          segments: [
            for (final mode in StudioAppearance.values)
              ButtonSegment<StudioAppearance>(
                value: mode,
                label: Text(mode.label),
              ),
          ],
          selected: {state.appearance},
          onSelectionChanged: state.isLoaded
              ? (values) => _selectMode(context, ref, values.first)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          'Theme mode changes the app immediately. Classic is a distinct '
          'near-black appearance.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Text('Built-in skins', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final definition in builtIn) ...[
          _SkinChoiceCard(
            definition: definition,
            selected: definition.id == state.skinId,
            enabled: state.isLoaded,
            onTap: () => _selectSkin(context, ref, definition.id),
          ),
          const SizedBox(height: 8),
        ],
        Text('My skins', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (installed.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'No community skins installed. Importing and exporting '
              'skins will be available in a future update.',
              key: ValueKey('studio-community-skins-empty'),
            ),
          )
        else
          for (final definition in installed) ...[
            _SkinChoiceCard(
              definition: definition,
              selected: definition.id == state.skinId,
              enabled: state.isLoaded,
              onTap: () => _selectSkin(context, ref, definition.id),
            ),
            const SizedBox(height: 8),
          ],
        if (missing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Your saved skin is not installed. Showing Carbon & Jade '
              'in the app; the saved skin ID is preserved.',
              key: const ValueKey('studio-missing-skin-warning'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('Selected skin preview', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _EditorAppearancePreview(
          key: const ValueKey('studio-editor-preview'),
          definition: selected,
          appearance: state.appearance,
          fontFamily: state.fontFamily,
        ),
        const SizedBox(height: 10),
        Text(
          'Skin and theme mode changes apply throughout the app. '
          'Your saved selection is restored when you reopen SubtitleStudio.',
          key: const ValueKey('studio-live-skin-notice'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SkinChoiceCard extends StatelessWidget {
  const _SkinChoiceCard({
    required this.definition,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final StudioSkinDefinition definition;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: 'Select ${definition.name} skin',
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('studio-skin-${definition.id.value}'),
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        definition.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary,
                          semanticLabel: 'Selected'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final mode in StudioAppearance.values) ...[
                      if (mode != StudioAppearance.light)
                        const SizedBox(width: 6),
                      Expanded(
                        child: StudioSkinDefinitionPreviewTile(
                          definition: definition,
                          appearance: mode,
                        ),
                      ),
                    ],
                  ],
                ),
                if (definition.author != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'By ${definition.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scoped theme: this preview never changes MaterialApp or an editor route.
class _EditorAppearancePreview extends StatelessWidget {
  const _EditorAppearancePreview({
    super.key,
    required this.definition,
    required this.appearance,
    required this.fontFamily,
  });

  final StudioSkinDefinition definition;
  final StudioAppearance appearance;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final palette = definition.paletteFor(appearance);
    return Theme(
      data: StudioThemeFactory.fromDefinition(
        definition,
        appearance,
        fontFamily: fontFamily,
      ),
      child: Builder(builder: (context) {
        final type = Theme.of(context).textTheme;
        return Container(
          decoration: BoxDecoration(
            color: palette.canvas,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${definition.name} · ${appearance.label}',
                style: type.titleSmall?.copyWith(color: palette.onSurface),
              ),
              const SizedBox(height: 12),
              Text(
                'ORIGINAL',
                style: type.labelSmall?.copyWith(color: palette.mutedText),
              ),
              const SizedBox(height: 5),
              _CuePreviewField(
                text: 'We can try another way.',
                palette: palette,
              ),
              const SizedBox(height: 10),
              Text(
                'EDITED',
                style: type.labelSmall?.copyWith(color: palette.mutedText),
              ),
              const SizedBox(height: 5),
              _CuePreviewField(
                text: 'നമുക്ക് മറ്റൊരു വഴി പരീക്ഷിക്കാം.',
                palette: palette,
                focused: true,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10,
                  ),
                  child: Text(
                    'Save line',
                    style: type.labelLarge?.copyWith(
                      color: palette.onAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CuePreviewField extends StatelessWidget {
  const _CuePreviewField({
    required this.text,
    required this.palette,
    this.focused = false,
  });

  final String text;
  final StudioPalette palette;
  final bool focused;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: palette.fieldSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? palette.accent : palette.fieldBorder,
            width: focused ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.onSurface,
              ),
        ),
      );
}
