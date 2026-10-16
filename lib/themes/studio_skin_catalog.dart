import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'studio_palette.dart';
import 'studio_skin.dart';
import 'studio_skin_validator.dart';

/// Immutable skin definition shared by built-ins, future import, and a web
/// editor. All modes are required, so a user never receives an unrelated
/// fallback palette when switching Light/Dark/Classic.
@immutable
class StudioSkinDefinition {
  StudioSkinDefinition({
    required this.id,
    required this.name,
    required Map<StudioAppearance, StudioPalette> palettes,
    this.author,
    this.description,
  }) : palettes = UnmodifiableMapView(Map.of(palettes)) {
    if (name.trim().isEmpty || name.length > 80) {
      throw ArgumentError.value(name, 'name', 'Skin name must be 1–80 characters');
    }
    for (final appearance in StudioAppearance.values) {
      final palette = palettes[appearance];
      if (palette == null || palette.appearance != appearance) {
        throw ArgumentError.value(
          appearance,
          'palettes',
          'Every skin must define a matching Light, Dark, and Classic palette',
        );
      }
    }
    if (palettes.length != StudioAppearance.values.length) {
      throw ArgumentError.value(palettes, 'palettes', 'Unknown appearance mode');
    }
  }

  final StudioSkinId id;
  final String name;
  final String? author;
  final String? description;
  final Map<StudioAppearance, StudioPalette> palettes;

  StudioPalette paletteFor(StudioAppearance appearance) => palettes[appearance]!;

  factory StudioSkinDefinition.builtIn(StudioSkin skin) =>
      StudioSkinDefinition(
        id: StudioSkinId.builtIn(skin),
        name: skin.label,
        palettes: {
          for (final mode in StudioAppearance.values)
            mode: StudioPalette.resolve(skin, mode),
        },
      );
}

/// Explicitly injected catalog. No global mutable registry or arbitrary
/// code-loading capability: a future importer will validate data and create
/// another immutable catalog with its newly installed definitions.
@immutable
class StudioSkinCatalog {
  StudioSkinCatalog({Iterable<StudioSkinDefinition> communitySkins = const []})
      : _definitions = _buildDefinitions(communitySkins);

  final Map<StudioSkinId, StudioSkinDefinition> _definitions;

  static Map<StudioSkinId, StudioSkinDefinition> _buildDefinitions(
    Iterable<StudioSkinDefinition> custom,
  ) {
    final result = <StudioSkinId, StudioSkinDefinition>{
      for (final skin in StudioSkin.values)
        StudioSkinId.builtIn(skin): StudioSkinDefinition.builtIn(skin),
    };
    for (final definition in custom) {
      if (definition.id.isBuiltIn || result.containsKey(definition.id)) {
        throw ArgumentError.value(
          definition.id.value,
          'communitySkins',
          'Cannot override a built-in skin or install a duplicate ID',
        );
      }
      StudioSkinValidator.validate(
        id: definition.id,
        palettes: definition.palettes,
        author: definition.author,
        description: definition.description,
      );
      result[definition.id] = definition;
    }
    return UnmodifiableMapView(result);
  }

  Iterable<StudioSkinDefinition> get skins => _definitions.values;

  StudioSkinDefinition? find(StudioSkinId id) => _definitions[id];

  StudioSkinDefinition resolveOrDefault(StudioSkinId? id) =>
      _definitions[id] ?? _definitions[StudioSkinId.carbonJade]!;

  /// Returns a new catalog. The old one remains safe for existing consumers.
  StudioSkinCatalog install(StudioSkinDefinition definition) {
    if (_definitions.containsKey(definition.id) || definition.id.isBuiltIn) {
      throw ArgumentError.value(definition.id.value, 'definition', 'ID already exists');
    }
    return StudioSkinCatalog(
      communitySkins: [
        ..._definitions.values.where((skin) => !skin.id.isBuiltIn),
        definition,
      ],
    );
  }
}
