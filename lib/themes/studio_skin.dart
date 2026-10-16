import 'package:flutter/foundation.dart';

/// The visual family. A skin does not imply a particular brightness.
enum StudioSkin {
  carbonJade('carbonJade', 'Carbon & Jade'),
  copperCinema('copperCinema', 'Copper Cinema'),
  asterViolet('asterViolet', 'Aster Violet');

  const StudioSkin(this.storageId, this.label);

  /// Stable identifier; never persist localized display labels.
  final String storageId;
  final String label;

  static StudioSkin? fromStorageId(String? id) {
    for (final skin in values) {
      if (skin.storageId == id) return skin;
    }
    return null;
  }
}

/// Light, comfortable dark, and near-black Classic are separate modes.
///
/// Classic must never be represented by Flutter's ThemeMode.system.
enum StudioAppearance {
  light('light', 'Light'),
  dark('dark', 'Dark'),
  classic('classic', 'Classic');

  const StudioAppearance(this.storageId, this.label);

  final String storageId;
  final String label;

  static StudioAppearance? fromStorageId(String? id) {
    for (final appearance in values) {
      if (appearance.storageId == id) return appearance;
    }
    return null;
  }
}

/// Stable identity for built-in or independently installed community skins.
///
/// Legacy built-in preference values remain readable. New persistent values
/// are namespaced so installed skins never require adding an enum case.
@immutable
class StudioSkinId {
  const StudioSkinId._(this.value);

  final String value;

  static const carbonJade = StudioSkinId._('builtin.carbonJade');
  static const copperCinema = StudioSkinId._('builtin.copperCinema');
  static const asterViolet = StudioSkinId._('builtin.asterViolet');

  static StudioSkinId builtIn(StudioSkin skin) => switch (skin) {
        StudioSkin.carbonJade => carbonJade,
        StudioSkin.copperCinema => copperCinema,
        StudioSkin.asterViolet => asterViolet,
      };

  /// Community IDs use a compact opaque key (e.g. a generated UUID).
  /// They contain no paths, extensions, locale-dependent names or URLs.
  static StudioSkinId community(String key) {
    final result = parse('community.$key');
    if (result == null) {
      throw ArgumentError.value(key, 'key', 'Invalid community skin key');
    }
    return result;
  }

  static StudioSkinId? parse(String? raw) {
    switch (raw) {
      case 'carbonJade':
      case 'builtin.carbonJade':
        return carbonJade;
      case 'copperCinema':
      case 'builtin.copperCinema':
        return copperCinema;
      case 'asterViolet':
      case 'builtin.asterViolet':
        return asterViolet;
    }
    if (raw != null &&
        RegExp(r'^community\.[a-z0-9][a-z0-9_-]{2,63}$').hasMatch(raw)) {
      return StudioSkinId._(raw);
    }
    return null;
  }

  bool get isBuiltIn => value.startsWith('builtin.');

  @override
  bool operator ==(Object other) =>
      other is StudioSkinId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Independent skin + mode selection for built-ins and future imported skins.
@immutable
class StudioAppearanceSelection {
  const StudioAppearanceSelection({
    required this.skin,
    required this.mode,
  });

  final StudioSkinId skin;
  final StudioAppearance mode;

  static const defaultSelection = StudioAppearanceSelection(
    skin: StudioSkinId.carbonJade,
    mode: StudioAppearance.dark,
  );

  StudioAppearanceSelection copyWith({
    StudioSkinId? skin,
    StudioAppearance? mode,
  }) =>
      StudioAppearanceSelection(
        skin: skin ?? this.skin,
        mode: mode ?? this.mode,
      );

  @override
  bool operator ==(Object other) =>
      other is StudioAppearanceSelection &&
      other.skin == skin &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(skin, mode);
}
