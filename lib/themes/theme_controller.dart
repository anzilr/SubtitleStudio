import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/themes/theme_preferences_repository.dart';
import 'package:subtitle_studio/themes/theme.dart';

final themePreferencesRepositoryProvider =
    Provider<ThemePreferencesRepository>(
  (ref) => ThemePreferencesRepository(ref.watch(isarProvider)),
);

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);

class ThemeState {
  final ThemeMode themeMode;
  final String? customFontPath;
  final String? customFontName;
  final String? fontFamily;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.customFontPath,
    this.customFontName,
    this.fontFamily,
  });

  ThemeData get themeData {
    late final ThemeData baseTheme;
    switch (themeMode) {
      case ThemeMode.light:
        baseTheme = AppThemes.lightTheme;
        break;
      case ThemeMode.dark:
        baseTheme = AppThemes.darkTheme;
        break;
      case ThemeMode.system:
        baseTheme = AppThemes.classicTheme;
        break;
    }

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

  ThemePreferencesRepository get _preferences =>
      ref.read(themePreferencesRepositoryProvider);

  @override
  ThemeState build() {
    unawaited(_loadInitialState());
    return const ThemeState();
  }

  Future<void> _loadInitialState() async {
    final savedTheme = await _preferences.getThemeMode();
    final fontPath = await _preferences.getAppFontPath();
    final fontName = await _preferences.getAppFontName();

    String? family;
    if (fontPath != null) {
      _fontCounter++;
      family = 'CustomFont_$_fontCounter';
      final loaded = await _loadFontFromPath(fontPath, family);
      if (!loaded) {
        family = null;
      }
    }

    state = ThemeState(
      themeMode: _themeModeFromString(savedTheme),
      customFontPath: family == null ? null : fontPath,
      customFontName: family == null ? null : fontName,
      fontFamily: family,
    );
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = ThemeState(
      themeMode: mode,
      customFontPath: state.customFontPath,
      customFontName: state.customFontName,
      fontFamily: state.fontFamily,
    );
    await _preferences.saveThemeMode(_themeModeToString(mode));
  }

  Future<void> setCustomFont(String? path) async {
    if (path == null) {
      await _preferences.setAppFontPath(null);
      await _preferences.setAppFontName(null);
      state = ThemeState(themeMode: state.themeMode);
      return;
    }

    final fontName = path.split(Platform.pathSeparator).last;
    _fontCounter++;
    final family = 'CustomFont_$_fontCounter';

    if (!await _loadFontFromPath(path, family)) {
      return;
    }

    await _preferences.setAppFontPath(path);
    await _preferences.setAppFontName(fontName);

    state = ThemeState(
      themeMode: state.themeMode,
      customFontPath: path,
      customFontName: fontName,
      fontFamily: family,
    );
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

  ThemeMode _themeModeFromString(String? mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'classic':
      case null:
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'classic';
    }
  }
}
