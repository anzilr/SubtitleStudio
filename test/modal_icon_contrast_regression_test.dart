import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/subtitle_tracks_sheet.dart';

void main() {
  for (final skin in StudioSkin.values) {
    for (final appearance in StudioAppearance.values) {
      testWidgets('Subtitle Tracks icon uses onPrimary in $skin $appearance',
          (tester) async {
        final theme = StudioThemeFactory.resolve(skin, appearance);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(body: SubtitleTracksSheet(
            subtitleTracks: <Map<String,dynamic>>[
              {'title':'Test','language':'en','codec':'subrip','index':0},
            ],
            onTrackSelected: (_) {},
          )),
        ));
        final icon = tester.widget<Icon>(find.byIcon(Icons.download));
        expect(icon.color, theme.colorScheme.onPrimary);
      });
    }
  }

  test('accent-surface icon badges never force white glyphs', () {
    const scoped = [
      'lib/widgets/video/player_settings_button.dart',
      'lib/widgets/secondary_subtitle_sheet.dart',
      'lib/widgets/export_file_widget.dart',
      'lib/widgets/project_settings/parts/project_settings_sections.dart',
      'lib/widgets/subtitle_tracks_sheet.dart',
      'lib/widgets/subtitle_import_options_sheet.dart',
    ];
    for (final path in scoped) {
      final text = File(path).readAsStringSync();
      expect(RegExp(r'\bcolor:\s*Colors\.white\b').hasMatch(text), isFalse,
          reason: 'Primary/tertiary badge icon must use matching onColor in $path');
    }
  });
}
