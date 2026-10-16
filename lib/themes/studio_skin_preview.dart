import 'package:flutter/material.dart';

import 'studio_palette.dart';
import 'studio_skin.dart';

/// A small, read-only theme preview for the future Appearance Settings.
/// It uses the same nine palette definitions as StudioThemeFactory.
class StudioSkinPreviewTile extends StatelessWidget {
  const StudioSkinPreviewTile({
    super.key,
    required this.skin,
    required this.appearance,
  });

  final StudioSkin skin;
  final StudioAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.resolve(skin, appearance);
    return Semantics(
      label: '${skin.label}, ${appearance.label} appearance preview',
      image: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.canvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.fieldBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appearance.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 49,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.fieldSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aa',
                    style: TextStyle(
                      color: palette.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 4,
                    width: 33,
                    decoration: BoxDecoration(
                      color: palette.mutedText,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 9,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nine static swatches; selection controls will be owned by SKIN-3 Settings.
///
/// Keep this read-only while the production theme controller uses the legacy
/// preference shape. It must not update Isar or rebuild an Editor route.
class StudioSkinPreviewGallery extends StatelessWidget {
  const StudioSkinPreviewGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final skin in StudioSkin.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              skin.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final appearance in StudioAppearance.values) ...[
                if (appearance != StudioAppearance.light)
                  const SizedBox(width: 8),
                Expanded(
                  child: StudioSkinPreviewTile(
                    skin: skin,
                    appearance: appearance,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
