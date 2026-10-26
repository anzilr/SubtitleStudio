import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/subtitle_effects_sheet.dart';

void main() {
  testWidgets('all legacy and new SRT effects share compact choice chips',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SubtitleEffectsSheet(
          selectedIndices: const [0],
          lineText: 'കാ👩‍👩‍👧‍👦 Sample',
          onApplyEffect: (effect, settings) {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(ChoiceChip), findsNWidgets(11));
    for (final id in const [
      'karaoke', 'typewriter', 'wordReveal', 'movingKaraoke',
      'activeTypewriter', 'backspace', 'lineReveal', 'colorTransition',
      'blinkFlash', 'rainbowText', 'scrambleReveal',
    ]) {
      expect(find.byKey(ValueKey('srt-effect-$id')), findsOneWidget);
    }

    final rainbow = find.byKey(const ValueKey('srt-effect-rainbowText'));
    await tester.ensureVisible(rainbow);
    await tester.pumpAndSettle();
    await tester.tap(rainbow);
    await tester.pump();
    expect(find.textContaining('Seven bright colors'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
