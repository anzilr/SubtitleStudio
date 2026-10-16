import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/theme_controller.dart';
import 'package:subtitle_studio/themes/theme_preferences_repository.dart';

class _FakeThemeStore implements ThemePreferencesStore {
  final initial = Completer<ThemePreferenceSnapshot>();
  String? savedSkin;
  String? savedMode;
  String? fontPath;
  String? fontName;
  bool rejectMode = false;
  bool rejectSkin = false;
  Completer<void>? holdFirstModeWrite;
  final modeWriteAttempts = <String>[];

  @override
  Future<ThemePreferenceSnapshot> load() => initial.future;

  @override
  Future<void> saveSkinId(String id) async {
    if (rejectSkin) throw StateError('Skin persistence failed');
    savedSkin = id;
  }

  @override
  Future<void> saveThemeMode(String mode) async {
    modeWriteAttempts.add(mode);
    if (modeWriteAttempts.length == 1 && holdFirstModeWrite != null) {
      await holdFirstModeWrite!.future;
    }
    if (rejectMode) throw StateError('Appearance persistence failed');
    savedMode = mode;
  }

  @override
  Future<void> setAppFontPath(String? path) async => fontPath = path;

  @override
  Future<void> setAppFontName(String? name) async => fontName = name;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('late startup load cannot overwrite either independently edited value',
      () async {
    final prefs = _FakeThemeStore();
    final container = ProviderContainer(overrides: [
      themePreferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(themeControllerProvider.notifier);
    expect(container.read(themeControllerProvider).isLoaded, isFalse);

    final community = StudioSkinId.community('custom-workspace-123');
    await notifier.setSkin(community);
    await notifier.setAppearance(StudioAppearance.light);

    prefs.initial.complete(const ThemePreferenceSnapshot(
      exists: true,
      skinId: 'builtin.asterViolet',
      themeMode: 'classic',
    ));
    await _flush();
    final state = container.read(themeControllerProvider);
    expect(state.isLoaded, isTrue);
    expect(state.skinId, community);
    expect(state.appearance, StudioAppearance.light);
    expect(prefs.savedSkin, community.value);
    expect(prefs.savedMode, 'light');
  });

  test('explicit fallback choice wins over a stale startup preference', () async {
    final prefs = _FakeThemeStore();
    final container = ProviderContainer(overrides: [
      themePreferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(themeControllerProvider.notifier);
    // These choices intentionally equal the startup fallback values.
    await notifier.setSkin(StudioSkinId.carbonZero);
    await notifier.setAppearance(StudioAppearance.classic);
    prefs.initial.complete(const ThemePreferenceSnapshot(
      exists: true,
      skinId: 'builtin.asterViolet',
      themeMode: 'light',
    ));
    await _flush();
    final selected = container.read(themeControllerProvider);
    expect(selected.skinId, StudioSkinId.carbonZero);
    expect(selected.appearance, StudioAppearance.classic);
    expect(prefs.savedSkin, StudioSkinId.carbonZero.value);
    expect(prefs.savedMode, 'classic');
  });

  test('rapid appearance changes commit to disk in user action order',
      () async {
    final prefs = _FakeThemeStore()
      ..holdFirstModeWrite = Completer<void>()
      ..initial.complete(const ThemePreferenceSnapshot(
        exists: true,
        skinId: 'builtin.carbonJade',
        themeMode: 'light',
      ));
    final container = ProviderContainer(overrides: [
      themePreferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(themeControllerProvider.notifier);
    await _flush();
    final first = notifier.setAppearance(StudioAppearance.dark);
    final second = notifier.setAppearance(StudioAppearance.classic);
    await _flush();
    expect(prefs.modeWriteAttempts, ['dark']);
    expect(container.read(themeControllerProvider).appearance,
        StudioAppearance.classic);

    prefs.holdFirstModeWrite!.complete();
    await Future.wait([first, second]);
    expect(prefs.modeWriteAttempts, ['dark', 'classic']);
    expect(prefs.savedMode, 'classic');
  });

  test('legacy modes remain exact and a missing skin becomes Carbon Zero',
      () async {
    for (final mode in ['light', 'dark', 'classic']) {
      final prefs = _FakeThemeStore()
        ..initial.complete(ThemePreferenceSnapshot(
          exists: true,
          themeMode: mode,
        ));
      final container = ProviderContainer(overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(prefs),
      ]);
      container.read(themeControllerProvider);
      await _flush();
      final state = container.read(themeControllerProvider);
      expect(state.appearance.storageId, mode);
      expect(state.skinId, StudioSkinId.carbonZero);
      expect(state.isLoaded, isTrue);
      container.dispose();
    }
  });

  test('existing null theme uses Classic; brand new record defaults to Dark',
      () async {
    for (final exists in [true, false]) {
      final prefs = _FakeThemeStore()
        ..initial.complete(ThemePreferenceSnapshot(exists: exists));
      final container = ProviderContainer(overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(prefs),
      ]);
      container.read(themeControllerProvider);
      await _flush();
      expect(container.read(themeControllerProvider).appearance,
          exists ? StudioAppearance.classic : StudioAppearance.dark);
      container.dispose();
    }
  });

  test('skin changes do not change mode and removing font does not reset either',
      () async {
    final prefs = _FakeThemeStore()
      ..initial.complete(const ThemePreferenceSnapshot(
        exists: true,
        skinId: 'community.my-custom-skin',
        themeMode: 'classic',
      ));
    final container = ProviderContainer(overrides: [
      themePreferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(themeControllerProvider.notifier);
    await _flush();
    expect(container.read(themeControllerProvider).themeMode, ThemeMode.system);
    await notifier.setAppearance(StudioAppearance.dark);
    await notifier.setSkin(StudioSkinId.asterViolet);
    await notifier.setCustomFont(null);
    final state = container.read(themeControllerProvider);
    expect(state.skinId, StudioSkinId.asterViolet);
    expect(state.appearance, StudioAppearance.dark);
    expect(state.fontFamily, isNull);
    expect(state.customFontPath, isNull);
  });

  test('failed setting persists never keeps a phantom new selection', () async {
    final prefs = _FakeThemeStore()
      ..initial.complete(const ThemePreferenceSnapshot(
        exists: true,
        themeMode: 'dark',
        skinId: 'builtin.carbonJade',
      ));
    final container = ProviderContainer(overrides: [
      themePreferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(themeControllerProvider.notifier);
    await _flush();
    prefs.rejectMode = true;
    await expectLater(
      notifier.setAppearance(StudioAppearance.classic),
      throwsStateError,
    );
    expect(container.read(themeControllerProvider).appearance,
        StudioAppearance.dark);

    prefs.rejectSkin = true;
    await expectLater(
      notifier.setSkin(StudioSkinId.copperCinema),
      throwsStateError,
    );
    expect(container.read(themeControllerProvider).skinId,
        StudioSkinId.carbonJade);
  });

  test('legacy setTheme API still cycles Classic but internal mode is typed',
      () async {
    final prefs = _FakeThemeStore()
      ..initial.complete(const ThemePreferenceSnapshot(
        exists: true,
        themeMode: 'light',
      ));
    final container = ProviderContainer(overrides: [
      themePreferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(themeControllerProvider.notifier);
    await _flush();
    await notifier.setTheme(ThemeMode.system);
    expect(container.read(themeControllerProvider).appearance,
        StudioAppearance.classic);
    expect(prefs.savedMode, 'classic');
  });
}
