import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/widgets/source_view_pane.dart';
import 'package:subtitle_studio/screens/screen_help.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';

void main() {
  testWidgets('Source View preserves multilingual edits when cycling nine skins',
      (tester) async {
    final entry = SubtitleEntry(
      index: '1',
      startTime: '00:00:01,000',
      endTime: '00:00:04,000',
      text: 'മലയാളം مرحبا',
    );
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var changes = 0;
    for (final skin in StudioSkin.values) {
      for (final appearance in StudioAppearance.values) {
        final tokens = StudioPalette.resolve(skin, appearance).tokens;
        await tester.pumpWidget(MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: StudioThemeFactory.resolve(skin, appearance),
          home: Scaffold(
            body: SourceViewPane(
              entries: [entry],
              scrollController: scroll,
              onChanged: () => changes++,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(4));
        expect(tester.widget<TextFormField>(fields.at(0)).style?.color,
            tokens.primaryAction);
        expect(tester.widget<TextFormField>(fields.at(3)).style?.color,
            tokens.onSurface);
        expect(tester.takeException(), isNull);
      }
    }

    await tester.enterText(find.byType(TextFormField).at(3), 'പുതിയത് مرحبا');
    await tester.pump();
    expect(entry.text, 'പുതിയത് مرحبا');
    expect(changes, 1);
  });

  testWidgets('Help selected category uses each skin on-action foreground',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final skin in StudioSkin.values) {
      for (final appearance in StudioAppearance.values) {
        final tokens = StudioPalette.resolve(skin, appearance).tokens;
        await tester.pumpWidget(MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: StudioThemeFactory.resolve(skin, appearance),
          home: const HelpScreen(),
        ));
        await tester.pumpAndSettle();
        final all = find.text('All');
        expect(all, findsOneWidget);
        expect(tester.widget<Text>(all).style?.color, tokens.onPrimaryAction);
        final chip = find.ancestor(
          of: all,
          matching: find.byType(AnimatedContainer),
        );
        expect(chip, findsOneWidget);
        final decoration =
            tester.widget<AnimatedContainer>(chip).decoration! as BoxDecoration;
        expect(decoration.color, tokens.primaryAction);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
