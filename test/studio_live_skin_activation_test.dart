import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_skin_catalog.dart';
import 'package:subtitle_studio/themes/theme_controller.dart';

void main() {
  test('live ThemeState resolves all nine palettes through shared catalog', () {
    final catalog = StudioSkinCatalog();
    for (final skin in StudioSkin.values) {
      for (final mode in StudioAppearance.values) {
        final selected = StudioSkinId.builtIn(skin);
        final state = ThemeState(skinId: selected, appearance: mode);
        final theme = state.themeDataFor(catalog);
        final palette = StudioPalette.resolve(skin, mode);
        expect(theme.colorScheme.primary, palette.accent);
        expect(theme.scaffoldBackgroundColor, palette.canvas);
        expect(theme.extension<StudioDesignTokens>()?.onSurface,
            palette.onSurface);
        expect(state.skinId, selected);
        expect(state.appearance, mode);
      }
    }
  });

  test('uninstalled community ID is retained; installed skin takes effect', () {
    final saved = StudioSkinId.community('my-workspace-001');
    const appearance = StudioAppearance.classic;
    final state = ThemeState(skinId: saved, appearance: appearance);
    final before = state.themeDataFor(StudioSkinCatalog());
    expect(before.colorScheme.primary,
        StudioPalette.resolve(StudioSkin.carbonJade, appearance).accent);

    final definition = StudioSkinDefinition(
      id: saved,
      name: 'Community test skin',
      palettes: {
        for (final mode in StudioAppearance.values)
          mode: StudioPalette.resolve(StudioSkin.copperCinema, mode),
      },
    );
    final installed = StudioSkinCatalog().install(definition);
    final after = state.themeDataFor(installed);
    expect(after.colorScheme.primary,
        StudioPalette.resolve(StudioSkin.copperCinema, appearance).accent);
    expect(state.skinId, saved);
  });

  testWidgets('live skin switches retain selection, focus and undo controller',
      (tester) async {
    final text = TextEditingController(text: 'മലയാളം مرحبا');
    text.selection = const TextSelection.collapsed(offset: 4);
    final focus = FocusNode();
    final undo = UndoHistoryController();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    addTearDown(undo.dispose);
    final combinations = [
      for (final skin in StudioSkin.values)
        for (final mode in StudioAppearance.values)
          (skin, mode),
    ];
    var index = 0;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setAppearance) {
        final (skin, mode) = combinations[index];
        return MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeState(
            skinId: StudioSkinId.builtIn(skin),
            appearance: mode,
          ).themeDataFor(StudioSkinCatalog()),
          home: Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const ValueKey('cycle-live-skin'),
                  onPressed: () => setAppearance(
                    () => index = (index + 1) % combinations.length,
                  ),
                  child: const Text('Change appearance'),
                ),
                TextField(
                  key: const ValueKey('editing-cue'),
                  controller: text,
                  focusNode: focus,
                  undoController: undo,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      },
    ));
    await tester.tap(find.byKey(const ValueKey('editing-cue')));
    await tester.pump();
    for (var i = 0; i < combinations.length; i++) {
      final previous = text.text;
      await tester.tap(find.byKey(const ValueKey('cycle-live-skin')));
      await tester.pumpAndSettle();
      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('editing-cue')));
      expect(field.controller, same(text));
      expect(field.undoController, same(undo));
      expect(text.text, previous);
      expect(tester.takeException(), isNull);
    }
    expect(text.text, 'മലയാളം مرحبا');
  });
}
