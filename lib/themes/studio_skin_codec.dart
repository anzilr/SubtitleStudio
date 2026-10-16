import 'dart:convert';

import 'package:flutter/material.dart';

import 'studio_palette.dart';
import 'studio_skin.dart';
import 'studio_skin_catalog.dart';
import 'studio_skin_validator.dart';

/// Portable colors-only v1 format for a future web Skin Creator.
///
/// This parser is deliberately not connected to file pickers, networking,
/// Isar or application settings. Imported JSON is untrusted data, NEVER Dart
/// code, markup, CSS, fonts or URLs.
abstract final class StudioSkinCodec {
  static const format = 'subtitlestudio.skin';
  static const schemaVersion = 1;
  static const maxBytes = 64 * 1024;

  static StudioSkinDefinition decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('Skin file is larger than 64 KiB');
    }
    final dynamic root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Invalid skin JSON');
    }
    final object = _map(root, 'skin file');
    const allowedRoot = {
      'format', 'schemaVersion', 'id', 'name', 'author',
      'description', 'palettes',
    };
    if (object.keys.any((key) => !allowedRoot.contains(key))) {
      throw const FormatException('Unsupported skin file property');
    }
    if (object['format'] != format || object['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported skin file version');
    }
    final id = StudioSkinId.parse(_string(object, 'id'));
    if (id == null || id.isBuiltIn) {
      throw const FormatException('Skin ID must have a community namespace');
    }
    final name = _string(object, 'name');
    final author = _optionalString(object, 'author');
    final description = _optionalString(object, 'description');

    final variants = _map(object['palettes'], 'palettes');
    if (variants.length != StudioAppearance.values.length) {
      throw const FormatException('Skin file must contain exactly three modes');
    }

    final palettes = <StudioAppearance, StudioPalette>{};
    for (final mode in StudioAppearance.values) {
      final entry = _map(variants[mode.storageId], mode.label);
      const roles = {
        'canvas', 'surface', 'raisedSurface', 'fieldSurface',
        'onSurface', 'mutedText', 'outline', 'fieldBorder',
        'accent', 'onAccent', 'appBar', 'onAppBar',
      };
      if (entry.length != roles.length ||
          entry.keys.any((key) => !roles.contains(key))) {
        throw FormatException('${mode.label}: invalid or missing color role');
      }
      Color color(String role) {
        final raw = _string(entry, role);
        if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(raw)) {
          throw FormatException('${mode.label}: $role must be #RRGGBB');
        }
        return Color(int.parse('FF${raw.substring(1)}', radix: 16));
      }

      palettes[mode] = StudioPalette(
        appearance: mode,
        canvas: color('canvas'),
        surface: color('surface'),
        raisedSurface: color('raisedSurface'),
        fieldSurface: color('fieldSurface'),
        onSurface: color('onSurface'),
        mutedText: color('mutedText'),
        outline: color('outline'),
        fieldBorder: color('fieldBorder'),
        accent: color('accent'),
        onAccent: color('onAccent'),
        appBar: color('appBar'),
        onAppBar: color('onAppBar'),
      );
    }
    final definition = StudioSkinDefinition(
      id: id,
      name: name,
      author: author,
      description: description,
      palettes: palettes,
    );
    StudioSkinValidator.validate(
      id: definition.id,
      palettes: definition.palettes,
      author: definition.author,
      description: definition.description,
    );
    return definition;
  }

  static String encode(StudioSkinDefinition definition) {
    StudioSkinValidator.validate(
      id: definition.id,
      palettes: definition.palettes,
      author: definition.author,
      description: definition.description,
    );

    String hex(Color color) =>
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    Map<String, String> colors(StudioPalette palette) => {
          'canvas': hex(palette.canvas),
          'surface': hex(palette.surface),
          'raisedSurface': hex(palette.raisedSurface),
          'fieldSurface': hex(palette.fieldSurface),
          'onSurface': hex(palette.onSurface),
          'mutedText': hex(palette.mutedText),
          'outline': hex(palette.outline),
          'fieldBorder': hex(palette.fieldBorder),
          'accent': hex(palette.accent),
          'onAccent': hex(palette.onAccent),
          'appBar': hex(palette.appBar),
          'onAppBar': hex(palette.onAppBar),
        };

    final output = <String, dynamic>{
      'format': format,
      'schemaVersion': schemaVersion,
      'id': definition.id.value,
      'name': definition.name,
      if (definition.author != null) 'author': definition.author,
      if (definition.description != null)
        'description': definition.description,
      'palettes': {
        for (final mode in StudioAppearance.values)
          mode.storageId: colors(definition.paletteFor(mode)),
      },
    };
    final encoded = jsonEncode(output);
    if (utf8.encode(encoded).length > maxBytes) {
      throw const FormatException('Skin JSON exceeds 64 KiB');
    }
    return encoded;
  }

  static Map<String, dynamic> _map(Object? object, String path) {
    if (object is! Map<String, dynamic>) {
      throw FormatException('$path must be an object');
    }
    return object;
  }

  static String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a nonempty string');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key must be a string');
    return value;
  }
}
