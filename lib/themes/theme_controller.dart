import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';

import 'studio_skin.dart';
import 'theme.dart';
import 'theme_preferences_repository.dart';

final themePreferencesRepositoryProvider = Provider<ThemePreferencesStore>(
  (ref) => ThemePreferencesRepository(ref.watch(isarProvider)),
);

final themeControllerProvider = NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);

/// Application appearance preferences, independent of the bundled palette.
///
/// The legacy UI will continue rendering AppThemes until SKIN-4 migrates its
/// hard-coded white-on-primary editing fields. This checkpoint only migrates
/// persistence and provides typed skin/mode state without changing the editor.
@immutable
class ThemeState {
  const ThemeState({
    this.skinId = StudioSkinId.carbonJade,
    this.appearance = StudioAppearance.classic,
    this.customFontPath,
    this.customFontName,
    this.fontFamily,
    this.isLoaded = false,
  });

  final StudioSkinId skinId;
  final StudioAppearance appearance;
  final String? customFontPath;
  final String? customFontName;
  final String? fontFamily;
  final bool isLoaded;

  StudioAppearanceSelection get selection =>
      StudioAppearanceSelection(skin: skinId, mode: appearance);

  /// Compatibility getter for the current button and MainApp. Core state
  /// stores Classic as a real StudioAppearance, not ThemeMode.system.
  ThemeMode get themeMode => switch (appearance) {
        StudioAppearance.light => ThemeMode.light,
        StudioAppearance.dark => ThemeMode.dark,
        StudioAppearance.classic => ThemeMode.system,
      };

  ThemeState copyWith({
    StudioSkinId? skinId,
    StudioAppearance? appearance,
    String? customFontPath,
    String? customFontName,
    String? fontFamily,
    bool clearFont = false,
    bool? isLoaded,
  }) =>
      ThemeState(
        skinId: skinId ?? this.skinId,
        appearance: appearance ?? this.appearance,
        customFontPath: clearFont ? null : customFontPath ?? this.customFontPath,
        customFontName: clearFont ? null : customFontName ?? this.customFontName,
        fontFamily: clearFont ? null : fontFamily ?? this.fontFamily,
        isLoaded: isLoaded ?? this.isLoaded,
      );

  /// Temporary legacy rendering boundary. Activate StudioThemeFactory only
  /// after SKIN-4 replaces white-on-primary Editor/Edit Line input boxes.
  ThemeData get themeData {
    final baseTheme = switch (appearance) {
      StudioAppearance.light => AppThemes.lightTheme,
      StudioAppearance.dark => AppThemes.darkTheme,
      StudioAppearance.classic => AppThemes.classicTheme,
    };

    final family = fontFamily;
    if (family == null) return baseTheme;
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: family),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: family),
    );
  }
}

class ThemeController extends Notifier<ThemeState> {
  int _fontCounter = 0;
  int _skinRevision = 0;
  int _appearanceRevision = 0;
  int _fontRevision = 0;
  // Serialize each preference independently so rapid taps cannot cause an
  // older async write to finish after and overwrite the latest selection.
  Future<void> _skinWrites = Future<void>.value();
  Future<void> _appearanceWrites = Future<void>.value();

  Future<void> _queueSkin(String id) {
    final next = _skinWrites.then((_) => _preferences.saveSkinId(id));
    _skinWrites = next.then<void>((_) {}, onError: (Object _, StackTrace trace) {});
    return next;
  }

  Future<void> _queueAppearance(String id) {
    final next = _appearanceWrites.then((_) => _preferences.saveThemeMode(id));
    _appearanceWrites = next.then<void>((_) {}, onError: (Object _, StackTrace trace) {});
    return next;
  }


  ThemePreferencesStore get _preferences =>
      ref.read(themePreferencesRepositoryProvider);

  @override
  ThemeState build() {
    unawaited(_loadInitialState());
    // Keep old Classic startup appearance until preferences are loaded.
    return const ThemeState();
  }

  Future<void> _loadInitialState() async {
    try {
      final saved = await _preferences.load();
      if (!ref.mounted) return;

      String? loadedFontFamily;
      final initialFontRevision = _fontRevision;
      if (initialFontRevision == 0 && saved.fontPath != null) {
        final nextFamily = 'CustomFont_${++_fontCounter}';
        if (await _loadFontFromPath(saved.fontPath!, nextFamily)) {
          loadedFontFamily = nextFamily;
        }
      }
      if (!ref.mounted) return;

      // Each independently edited field wins over an earlier startup read.
      // This is necessary when a user changes skin/mode during async startup.
      final fontChanged = _fontRevision != initialFontRevision;
      final current = state;
      state = ThemeState(
        skinId: _skinRevision == 0
            ? StudioSkinId.parse(saved.skinId) ?? StudioSkinId.carbonJade
            : current.skinId,
        appearance: _appearanceRevision == 0
            ? _appearanceFromSnapshot(saved)
            : current.appearance,
        customFontPath: fontChanged
            ? current.customFontPath
            : loadedFontFamily == null ? null : saved.fontPath,
        customFontName: fontChanged
            ? current.customFontName
            : loadedFontFamily == null ? null : saved.fontName,
        fontFamily: fontChanged ? current.fontFamily : loadedFontFamily,
        isLoaded: true,
      );
    } catch (error) {
      debugPrint('Could not load appearance preferences: $error');
      if (ref.mounted) state = state.copyWith(isLoaded: true);
    }
  }

  /// Fresh installs default to Dark. Legacy records without a mode preserve
  /// the old Classic default. Explicit light/dark/classic values are retained.
  StudioAppearance _appearanceFromSnapshot(ThemePreferenceSnapshot saved) =>
      StudioAppearance.fromStorageId(saved.themeMode) ??
      (saved.exists ? StudioAppearance.classic : StudioAppearance.dark);

  Future<void> setSkin(StudioSkinId skin) async {
    // A choice made during hydration must win even when it matches fallback.
    if (skin == state.skinId && state.isLoaded) return;
    final previous = state.skinId;
    final revision = ++_skinRevision;
    state = state.copyWith(skinId: skin);
    try {
      await _queueSkin(skin.value);
    } catch (_) {
      if (ref.mounted && _skinRevision == revision) {
        state = state.copyWith(skinId: previous);
      }
      rethrow;
    }
  }

  Future<void> setAppearance(StudioAppearance appearance) async {
    if (appearance == state.appearance && state.isLoaded) return;
    final previous = state.appearance;
    final revision = ++_appearanceRevision;
    state = state.copyWith(appearance: appearance);
    try {
      await _queueAppearance(appearance.storageId);
    } catch (_) {
      if (ref.mounted && _appearanceRevision == revision) {
        state = state.copyWith(appearance: previous);
      }
      rethrow;
    }
  }

  /// Compatibility for existing callers. Classic is represented by a typed
  /// StudioAppearance internally; system-following mode remains out of scope.
  Future<void> setTheme(ThemeMode mode) => setAppearance(switch (mode) {
        ThemeMode.light => StudioAppearance.light,
        ThemeMode.dark => StudioAppearance.dark,
        ThemeMode.system => StudioAppearance.classic,
      });

  Future<void> setCustomFont(String? path) async {
    final revision = ++_fontRevision;
    if (path == null) {
      await _preferences.setAppFontPath(null);
      await _preferences.setAppFontName(null);
      if (ref.mounted && _fontRevision == revision) {
        state = state.copyWith(clearFont: true);
      }
      return;
    }

    final fontName = path.split(Platform.pathSeparator).last;
    final family = 'CustomFont_${++_fontCounter}';
    if (!await _loadFontFromPath(path, family)) return;
    if (!ref.mounted || _fontRevision != revision) return;

    await _preferences.setAppFontPath(path);
    await _preferences.setAppFontName(fontName);
    if (ref.mounted && _fontRevision == revision) {
      state = state.copyWith(
        customFontPath: path,
        customFontName: fontName,
        fontFamily: family,
      );
    }
  }

  Future<bool> _loadFontFromPath(
    String path,
    String fontFamily,
  ) async {
    try {
      final bytes = await File(path).readAsBytes();
      final loader = FontLoader(fontFamily);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return true;
    } catch (error) {
      debugPrint('Error loading app font: $error');
      return false;
    }
  }
}
