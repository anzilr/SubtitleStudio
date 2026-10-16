import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin_preview.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = a.computeLuminance() <= b.computeLuminance() ? a : b;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void main() {
  test('skin and appearance have independent stable serialization', () {
    expect(StudioSkin.values, hasLength(4));
    expect(StudioAppearance.values, hasLength(3));

    for (final skin in StudioSkin.values) {
      expect(StudioSkin.fromStorageId(skin.storageId), skin);
      expect(skin.label, isNotEmpty);
    }
    for (final appearance in StudioAppearance.values) {
      expect(StudioAppearance.fromStorageId(appearance.storageId), appearance);
    }
    expect(StudioSkin.fromStorageId('madeUp'), isNull);
    expect(StudioAppearance.fromStorageId(null), isNull);
    expect(StudioAppearance.fromStorageId('system'), isNull,
        reason: 'Classic is not a disguised Flutter system theme');

    const start = StudioAppearanceSelection.defaultSelection;
    expect(start.skin, StudioSkinId.carbonZero);
    expect(start.mode, StudioAppearance.dark);
    final copper = start.copyWith(skin: StudioSkinId.copperCinema);
    expect(copper.skin, StudioSkinId.copperCinema);
    expect(copper.mode, StudioAppearance.dark);
    expect(copper.copyWith(mode: StudioAppearance.classic).skin,
        StudioSkinId.copperCinema);
    expect(copper.copyWith(skin: StudioSkinId.asterViolet).mode,
        StudioAppearance.dark);
    expect(start, const StudioAppearanceSelection(
      skin: StudioSkinId.carbonJade,
      mode: StudioAppearance.dark,
    ));
  });

  test('all twelve skins and appearances resolve independent readable roles', () {
    final ids = <String>{};
    for (final skin in StudioSkin.values) {
      for (final appearance in StudioAppearance.values) {
        final label = '${skin.label} / ${appearance.label}';
        ids.add('${skin.storageId}/${appearance.storageId}');
        final palette = StudioPalette.resolve(skin, appearance);
        final theme = StudioThemeFactory.resolve(skin, appearance);
        final tokens = theme.extension<StudioDesignTokens>();

        expect(palette.appearance, appearance, reason: label);
        expect(theme.colorScheme.brightness,
            appearance == StudioAppearance.light
                ? Brightness.light
                : Brightness.dark,
            reason: label);
        expect(theme.scaffoldBackgroundColor, palette.canvas, reason: label);
        expect(theme.colorScheme.surface, palette.surface, reason: label);
        expect(theme.colorScheme.primary, palette.accent, reason: label);
        expect(theme.colorScheme.onPrimary, palette.onAccent, reason: label);
        expect(tokens, isNotNull, reason: label);
        expect(tokens!.fieldSurface, palette.fieldSurface, reason: label);
        expect(tokens.fieldBorder, palette.fieldBorder, reason: label);
        expect(tokens.caret, palette.accent, reason: label);
        expect(tokens.focusBorder, palette.accent, reason: label);
        expect(tokens.selection.a, lessThan(1), reason: label);

        // AA body text, inactive metadata, prominent buttons and errors.
        expect(_contrast(palette.onSurface, palette.surface),
            greaterThanOrEqualTo(4.5), reason: '$label surface text');
        expect(_contrast(palette.onSurface, palette.fieldSurface),
            greaterThanOrEqualTo(4.5), reason: '$label field text');
        expect(_contrast(palette.mutedText, palette.fieldSurface),
            greaterThanOrEqualTo(4.5), reason: '$label field metadata');
        expect(_contrast(palette.accent, palette.onAccent),
            greaterThanOrEqualTo(4.5), reason: '$label button text');
        expect(_contrast(palette.danger, palette.surface),
            greaterThanOrEqualTo(4.5), reason: '$label error');
        expect(_contrast(palette.caution, palette.surface),
            greaterThanOrEqualTo(4.5), reason: '$label warning');
        expect(_contrast(palette.appBar, palette.onAppBar),
            greaterThanOrEqualTo(4.5), reason: '$label app bar');

        // Non-text input boundaries are visually distinguishable.
        expect(_contrast(palette.fieldBorder, palette.fieldSurface),
            greaterThanOrEqualTo(3.0), reason: '$label field border');
      }

      final dark = StudioPalette.resolve(skin, StudioAppearance.dark);
      final classic = StudioPalette.resolve(skin, StudioAppearance.classic);
      expect(classic.canvas, isNot(dark.canvas),
          reason: 'Classic must be a separate near-black design');
      expect(classic.fieldSurface, isNot(dark.fieldSurface));
      expect(classic.canvas.computeLuminance(),
          lessThan(dark.canvas.computeLuminance()));
    }
    expect(ids, hasLength(9));
  });

  test('new semantic tokens preserve interpolation and copyWith behavior', () {
    final a = StudioPalette.resolve(
      StudioSkin.carbonJade, StudioAppearance.light,
    ).tokens;
    final b = StudioPalette.resolve(
      StudioSkin.asterViolet, StudioAppearance.classic,
    ).tokens;
    expect(a.lerp(b, 0).fieldBorder, a.fieldBorder);
    expect(a.lerp(b, 1).focusBorder, b.focusBorder);
    expect(a.lerp(b, 0.5).selection, isNot(a.selection));
    expect(a.copyWith(caret: Colors.red).caret, Colors.red);
    expect(a.copyWith(caret: Colors.red).fieldSurface, a.fieldSurface);
  });

  test('custom font applies without changing the palette', () {
    final base = StudioThemeFactory.resolve(
      StudioSkin.carbonJade, StudioAppearance.dark,
    );
    final custom = StudioThemeFactory.resolve(
      StudioSkin.carbonJade, StudioAppearance.dark,
      fontFamily: 'TestTypeface',
    );
    expect(custom.textTheme.bodyMedium?.fontFamily, 'TestTypeface');
    expect(custom.colorScheme.primary, base.colorScheme.primary);
    expect(custom.extension<StudioDesignTokens>()?.onSurface,
        base.extension<StudioDesignTokens>()?.onSurface);
  });

  testWidgets('preview switches twelve themes without resetting a text controller',
      (tester) async {
    final controller = TextEditingController(
      text: 'മലയാളം subtitles – مرحبا',
    );
    addTearDown(controller.dispose);

    for (final skin in StudioSkin.values) {
      for (final appearance in StudioAppearance.values) {
        await tester.pumpWidget(MaterialApp(
          theme: StudioThemeFactory.resolve(skin, appearance),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Edited line'),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(find.text('Edited line'), findsOneWidget);
        expect(controller.text, 'മലയാളം subtitles – مرحبا');
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('all twelve preview tiles fit a narrow settings viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: StudioThemeFactory.resolve(
        StudioSkin.carbonJade, StudioAppearance.dark,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: StudioSkinPreviewGallery(),
          ),
        ),
      ),
    ));

    expect(find.byType(StudioSkinPreviewTile), findsNWidgets(12));
    expect(find.text('Carbon & Jade'), findsOneWidget);
    expect(find.text('Copper Cinema'), findsOneWidget);
    expect(find.text('Aster Violet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
