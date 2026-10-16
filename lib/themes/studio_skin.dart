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

/// Independent skin + mode selection, shared by Settings and the theme resolver.
@immutable
class StudioAppearanceSelection {
  const StudioAppearanceSelection({
    required this.skin,
    required this.mode,
  });

  final StudioSkin skin;
  final StudioAppearance mode;

  static const defaultSelection = StudioAppearanceSelection(
    skin: StudioSkin.carbonJade,
    mode: StudioAppearance.dark,
  );

  StudioAppearanceSelection copyWith({
    StudioSkin? skin,
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
