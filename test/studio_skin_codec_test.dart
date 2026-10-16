import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_skin_catalog.dart';
import 'package:subtitle_studio/themes/studio_skin_codec.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';

StudioSkinDefinition _sampleSkin({
  String id = 'community.example-skin-123',
}) =>
    StudioSkinDefinition(
      id: StudioSkinId.parse(id)!,
      name: 'My Subtitle Skin',
      author: 'Open-source contributor',
      description: 'Created with the future SubtitleStudio web editor',
      palettes: {
        for (final appearance in StudioAppearance.values)
          appearance: StudioPalette.resolve(StudioSkin.carbonJade, appearance),
      },
    );

void main() {
  test('community IDs are distinct from built-ins and block path-like IDs', () {
    expect(StudioSkinId.parse('carbonJade'), StudioSkinId.carbonJade);
    expect(StudioSkinId.parse('builtin.carbonJade'), StudioSkinId.carbonJade);
    expect(StudioSkinId.parse('copperCinema'), StudioSkinId.copperCinema);
    expect(StudioSkinId.parse('community.example-skin-123'),
        StudioSkinId.community('example-skin-123'));
    expect(StudioSkinId.parse('community.a'), isNull);
    expect(StudioSkinId.parse('community.../escape'), isNull);
    expect(StudioSkinId.parse('community.../../evil'), isNull);
    expect(StudioSkinId.parse('https://example.com/file.json'), isNull);
    expect(StudioSkinId.parse('builtin.my-custom-theme'), isNull);
    expect(() => StudioSkinId.community('../outside'), throwsArgumentError);
  });

  test('community skin selection survives separate mode and skin changes', () {
    final id = StudioSkinId.community('local-theme-001');
    final selection = StudioAppearanceSelection.defaultSelection
        .copyWith(skin: id);
    expect(selection.skin, id);
    expect(selection.mode, StudioAppearance.dark);
    expect(selection.copyWith(mode: StudioAppearance.classic).skin, id);
    expect(selection.copyWith(skin: StudioSkinId.asterViolet).mode,
        StudioAppearance.dark);
  });

  test('portable v1 colors-only JSON round trips and renders every mode', () {
    final definition = _sampleSkin();
    final source = StudioSkinCodec.encode(definition);
    final obj = jsonDecode(source) as Map<String, dynamic>;
    expect(obj['format'], 'subtitlestudio.skin');
    expect(obj['schemaVersion'], 1);
    expect(obj['palettes'], hasLength(3));
    final imported = StudioSkinCodec.decode(source);
    expect(imported.name, definition.name);
    expect(imported.id, definition.id);
    expect(imported.author, definition.author);

    final catalog = StudioSkinCatalog().install(imported);
    expect(catalog.skins.length, 4);
    expect(catalog.find(imported.id), isNotNull);
    for (final appearance in StudioAppearance.values) {
      final result =
          StudioThemeFactory.fromDefinition(imported, appearance);
      expect(result.colorScheme.primary, imported.paletteFor(appearance).accent);
      expect(result.scaffoldBackgroundColor,
          imported.paletteFor(appearance).canvas);
    }
    expect(StudioSkinCatalog().find(imported.id), isNull,
        reason: 'Registry is immutable, without process-global state');
  });

  test('community import never replaces a built-in or duplicate ID', () {
    final catalog = StudioSkinCatalog().install(_sampleSkin());
    expect(
      () => catalog.install(_sampleSkin()),
      throwsArgumentError,
    );
    expect(
      () => StudioSkinCatalog().install(
        StudioSkinDefinition.builtIn(StudioSkin.carbonJade),
      ),
      throwsArgumentError,
    );
    expect(
      catalog.resolveOrDefault(StudioSkinId.community('unknown-skin')),
      catalog.find(StudioSkinId.carbonJade),
    );
  });

  test('rejects missing modes, unsupported versions and executable extensions',
      () {
    final good = jsonDecode(StudioSkinCodec.encode(_sampleSkin()))
        as Map<String, dynamic>;

    Map<String, dynamic> fresh() => jsonDecode(jsonEncode(good))
        as Map<String, dynamic>;

    final missingMode = fresh();
    (missingMode['palettes'] as Map<String, dynamic>).remove('classic');
    expect(
      () => StudioSkinCodec.decode(jsonEncode(missingMode)),
      throwsFormatException,
    );

    final futureVersion = fresh()..['schemaVersion'] = 99;
    expect(
      () => StudioSkinCodec.decode(jsonEncode(futureVersion)),
      throwsFormatException,
    );

    final sourceInjection = fresh()..['script'] = 'alert(1)';
    expect(
      () => StudioSkinCodec.decode(jsonEncode(sourceInjection)),
      throwsFormatException,
    );

    final cssInjection = fresh();
    ((cssInjection['palettes'] as Map<String, dynamic>)['dark']
        as Map<String, dynamic>)['customCss'] = 'body {display: none}';
    expect(
      () => StudioSkinCodec.decode(jsonEncode(cssInjection)),
      throwsFormatException,
    );

    final reservedId = fresh()..['id'] = 'builtin.carbonJade';
    expect(
      () => StudioSkinCodec.decode(jsonEncode(reservedId)),
      throwsFormatException,
    );
  });

  test('rejects low contrast, transparent input, oversized files and bad hex',
      () {
    final good = jsonDecode(StudioSkinCodec.encode(_sampleSkin()))
        as Map<String, dynamic>;

    Map<String, dynamic> fresh() => jsonDecode(jsonEncode(good))
        as Map<String, dynamic>;

    final unreadable = fresh();
    ((unreadable['palettes'] as Map<String, dynamic>)['dark']
        as Map<String, dynamic>)['onSurface'] = '#213135';
    expect(
      () => StudioSkinCodec.decode(jsonEncode(unreadable)),
      throwsFormatException,
    );

    final transparent = fresh();
    ((transparent['palettes'] as Map<String, dynamic>)['light']
        as Map<String, dynamic>)['surface'] = '#FFFFFFFF';
    expect(
      () => StudioSkinCodec.decode(jsonEncode(transparent)),
      throwsFormatException,
    );

    final badHex = fresh();
    ((badHex['palettes'] as Map<String, dynamic>)['dark']
        as Map<String, dynamic>)['fieldBorder'] = '#GGGGGG';
    expect(
      () => StudioSkinCodec.decode(jsonEncode(badHex)),
      throwsFormatException,
    );

    expect(
      () => StudioSkinCodec.decode('{' + ' ' * (StudioSkinCodec.maxBytes + 1)),
      throwsFormatException,
    );
  });

  test('missing appearances cannot create a community skin definition', () {
    expect(
      () => StudioSkinDefinition(
        id: StudioSkinId.community('missing-light'),
        name: 'Incomplete skin',
        palettes: {
          StudioAppearance.dark:
              StudioPalette.resolve(StudioSkin.carbonJade, StudioAppearance.dark),
          StudioAppearance.classic: StudioPalette.resolve(
              StudioSkin.carbonJade, StudioAppearance.classic),
        },
      ),
      throwsArgumentError,
    );
  });

  testWidgets('imported community skin is a normal Flutter theme',
      (tester) async {
    final custom = StudioSkinCodec.decode(
      StudioSkinCodec.encode(_sampleSkin()),
    );
    await tester.pumpWidget(MaterialApp(
      theme: StudioThemeFactory.fromDefinition(
        custom,
        StudioAppearance.dark,
      ),
      home: const Scaffold(
        body: Center(child: Text('Hello from the community')),
      ),
    ));
    expect(find.text('Hello from the community'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
