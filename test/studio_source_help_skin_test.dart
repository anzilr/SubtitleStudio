import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/widgets/source_view_pane.dart';
import 'package:subtitle_studio/screens/screen_help.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';

void main() {
  testWidgets('Source View preserves multilingual edits when cycling twelve appearances',
      (tester) async {
    final entry = SubtitleEntry(
      index: '1',
      startTime: '00:00:01,000',
      endTime: '00:00:04,000',
      text: 'മലയാളം مرحبا',
    );
    final entries = <SubtitleEntry>[entry];
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
              entries: entries,
              scrollController: scroll,
              onChanged: () => changes++,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final editor = find.byKey(const ValueKey('raw-srt-editor'));
        expect(editor, findsOneWidget);
        expect(find.byType(TextFormField), findsNothing,
            reason: 'Raw source is not a GUI with per-cue fields');
        expect(tester.widget<TextField>(editor).style?.color, tokens.onSurface);
        expect(tester.takeException(), isNull);
      }
    }

    await tester.enterText(find.byKey(const ValueKey('raw-srt-editor')),
        '1\n00:00:01,000 --> 00:00:04,000\nപുതിയത് مرحبا');
    await tester.pump();
    expect(entries.single.text, 'പുതിയത് مرحبا');
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
