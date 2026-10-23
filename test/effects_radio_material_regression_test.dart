import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/subtitle_effects_sheet.dart';

void main() {
  for (final mode in <StudioAppearance>[
    StudioAppearance.dark,
    StudioAppearance.classic,
  ]) {
    testWidgets('Karaoke radio choices build without ListTile ink assertion '
        'in Carbon Zero $mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: StudioThemeFactory.resolve(StudioSkin.carbonZero, mode),
        home: Scaffold(
          body: SubtitleEffectsSheet(
            selectedIndices: const [0],
            lineText: 'Sample subtitle',
            onApplyEffect: (effect, config) {},
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final labels = find.text('Character');
      await tester.ensureVisible(labels);
      await tester.tap(labels);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
