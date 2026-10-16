import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_skin_catalog.dart';
import 'package:subtitle_studio/themes/theme_controller.dart';

void main() {
  test('live ThemeState resolves all twelve palettes through shared catalog', () {
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
        StudioPalette.resolve(StudioSkin.carbonZero, appearance).accent);

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
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(ValueListenableBuilder<int>(
      valueListenable: selected,
      builder: (context, index, child) {
        final (skin, mode) = combinations[index];
        return MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeState(
            skinId: StudioSkinId.builtIn(skin),
            appearance: mode,
          ).themeDataFor(StudioSkinCatalog()),
          home: Scaffold(
            body: TextField(
              key: const ValueKey('editing-cue'),
              controller: text,
              focusNode: focus,
              undoController: undo,
              maxLines: 2,
            ),
          ),
        );
      },
    ));
    await tester.tap(find.byKey(const ValueKey('editing-cue')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    text.selection = TextSelection.collapsed(offset: text.text.length);
    final originalSelection = text.selection;

    for (var i = 0; i < combinations.length; i++) {
      selected.value = i;
      await tester.pumpAndSettle();
      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('editing-cue')));
      expect(field.controller, same(text));
      expect(field.undoController, same(undo));
      expect(focus.hasFocus, isTrue,
          reason: 'Palette changes must retain active editing focus');
      expect(text.selection, originalSelection);
      expect(text.text, 'മലയാളം مرحبا');
      expect(tester.takeException(), isNull);
    }
    expect(text.text, 'മലയാളം مرحبا');
  });
}
