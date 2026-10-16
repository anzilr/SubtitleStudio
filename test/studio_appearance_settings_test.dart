import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_appearance_settings.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_skin_catalog.dart';
import 'package:subtitle_studio/themes/studio_skin_catalog_provider.dart';
import 'package:subtitle_studio/themes/studio_skin_preview.dart';
import 'package:subtitle_studio/themes/theme_controller.dart';
import 'package:subtitle_studio/themes/theme_preferences_repository.dart';
import 'package:subtitle_studio/themes/theme_switcher_button.dart';

class _AppearanceStore implements ThemePreferencesStore {
  _AppearanceStore({
    this.initialSkin,
    this.initialMode = 'dark',
    this.failSkinSave = false,
    this.failModeSave = false,
  });

  final String? initialSkin;
  final String? initialMode;
  bool failSkinSave;
  bool failModeSave;
  String? savedSkin;
  String? savedMode;

  @override
  Future<ThemePreferenceSnapshot> load() async => ThemePreferenceSnapshot(
        exists: true,
        skinId: initialSkin,
        themeMode: initialMode,
      );

  @override
  Future<void> saveSkinId(String id) async {
    if (failSkinSave) throw StateError('write failed');
    savedSkin = id;
  }

  @override
  Future<void> saveThemeMode(String mode) async {
    if (failModeSave) throw StateError('write failed');
    savedMode = mode;
  }

  @override
  Future<void> setAppFontName(String? name) async {}

  @override
  Future<void> setAppFontPath(String? path) async {}
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _AppearanceStore store, {
  StudioSkinCatalog? catalog,
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      themePreferencesRepositoryProvider.overrideWithValue(store),
      if (catalog != null)
        studioSkinCatalogProvider.overrideWithValue(catalog),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: StudioAppearanceSettings(),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapSkin(WidgetTester tester, StudioSkinId id) async {
  final finder = find.byKey(ValueKey('studio-skin-${id.value}'));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapMode(WidgetTester tester, StudioAppearance mode) async {
  final control = find.byKey(const ValueKey('studio-appearance-mode-selector'));
  final choice = find.descendant(
    of: control,
    matching: find.text(mode.label),
  );
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows nine built-in swatches and an honest preview-only notice',
      (tester) async {
    final store = _AppearanceStore();
    await _pumpSettings(tester, store, width: 320);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Built-in skins'), findsOneWidget);
    expect(find.text('My skins'), findsOneWidget);
    expect(find.byType(StudioSkinDefinitionPreviewTile), findsNWidgets(9));
    expect(find.byKey(const ValueKey('studio-community-skins-empty')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('studio-editor-preview')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('studio-preview-only-notice')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skin selection persists without changing appearance mode',
      (tester) async {
    final store = _AppearanceStore(initialMode: 'classic');
    await _pumpSettings(tester, store);

    await _tapSkin(tester, StudioSkinId.copperCinema);
    expect(store.savedSkin, StudioSkinId.copperCinema.value);
    expect(store.savedMode, isNull);

    final segment = tester.widget<SegmentedButton<StudioAppearance>>(
        find.byKey(const ValueKey('studio-appearance-mode-selector')));
    expect(segment.selected, {StudioAppearance.classic});

    await _tapMode(tester, StudioAppearance.light);
    expect(store.savedMode, 'light');
    expect(store.savedSkin, StudioSkinId.copperCinema.value);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all appearance modes can be selected in the same skin',
      (tester) async {
    final store = _AppearanceStore(initialMode: 'light');
    await _pumpSettings(tester, store);
    await _tapSkin(tester, StudioSkinId.asterViolet);

    await _tapMode(tester, StudioAppearance.dark);
    expect(store.savedMode, 'dark');
    await _tapMode(tester, StudioAppearance.classic);
    expect(store.savedMode, 'classic');
    await _tapMode(tester, StudioAppearance.light);
    expect(store.savedMode, 'light');
    expect(store.savedSkin, StudioSkinId.asterViolet.value);
    expect(tester.takeException(), isNull);
  });

  testWidgets('future community skins use the same setting tile and renderer',
      (tester) async {
    final community = StudioSkinDefinition(
      id: StudioSkinId.community('open-source-001'),
      name: 'My Film Skin',
      author: 'Community author',
      palettes: {
        for (final mode in StudioAppearance.values)
          mode: StudioPalette.resolve(StudioSkin.carbonJade, mode),
      },
    );
    final store = _AppearanceStore();
    await _pumpSettings(
      tester,
      store,
      catalog: StudioSkinCatalog(communitySkins: [community]),
    );
    expect(find.byType(StudioSkinDefinitionPreviewTile), findsNWidgets(12));
    expect(find.byKey(const ValueKey('studio-community-skins-empty')),
        findsNothing);

    await _tapSkin(tester, community.id);
    expect(store.savedSkin, community.id.value);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable saved skin retains its ID and previews fallback',
      (tester) async {
    final store = _AppearanceStore(
      initialSkin: 'community.not-installed-001',
      initialMode: 'dark',
    );
    await _pumpSettings(tester, store);
    expect(find.byKey(const ValueKey('studio-missing-skin-warning')),
        findsOneWidget);
    expect(store.savedSkin, isNull,
        reason: 'The UI must not erase an absent community skin ID');
    expect(find.textContaining('Carbon & Jade · Dark'), findsOneWidget);
  });

  testWidgets('failed skin write reports error and rolls back selection',
      (tester) async {
    final store = _AppearanceStore(failSkinSave: true);
    await _pumpSettings(tester, store);

    await _tapSkin(tester, StudioSkinId.copperCinema);
    expect(find.text('Could not save the skin selection.'), findsOneWidget);
    expect(store.savedSkin, isNull);

    final card = tester.widget<Semantics>(
        find.ancestor(
          of: find.byKey(const ValueKey('studio-skin-builtin.carbonJade')),
          matching: find.byType(Semantics),
        ).first);
    expect(card.properties.selected, true);
  });

  testWidgets('the existing theme-cycle button keeps the selected skin',
      (tester) async {
    final store = _AppearanceStore(
      initialSkin: 'builtin.copperCinema',
      initialMode: 'light',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ThemeSwitcherButton(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ThemeSwitcherButton));
    await tester.pumpAndSettle();
    expect(store.savedMode, 'dark');
    expect(store.savedSkin, isNull);

    await tester.tap(find.byType(ThemeSwitcherButton));
    await tester.pumpAndSettle();
    expect(store.savedMode, 'classic');

    await tester.tap(find.byType(ThemeSwitcherButton));
    await tester.pumpAndSettle();
    expect(store.savedMode, 'light');
    expect(find.byTooltip('Theme: Light. Tap to switch mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
