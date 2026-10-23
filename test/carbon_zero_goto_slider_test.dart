import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/goto_line_sheet.dart';

void main() {
  for (final mode in StudioAppearance.values) {
    testWidgets('Go To Line slider uses Carbon Zero ${mode.label} foreground',
        (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: StudioThemeFactory.resolve(StudioSkin.carbonZero, mode),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGotToLineModal(
                context: context,
                initialValue: '4',
                hintText: 20,
                onSubmitted: (_) {},
              ),
              child: const Text('Open Go To Line'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Go To Line'));
      await tester.pumpAndSettle();
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      final theme = tester.widget<SliderTheme>(
          find.ancestor(of: slider, matching: find.byType(SliderTheme)).first);
      final palette = StudioPalette.resolve(StudioSkin.carbonZero, mode);
      expect(theme.data.activeTrackColor, palette.accent);
      expect(theme.data.thumbColor, palette.accent);
      expect(theme.data.inactiveTrackColor, palette.outline);
      expect(theme.data.valueIndicatorColor, palette.raisedSurface);
      expect(tester.takeException(), isNull);
    });
  }
}
