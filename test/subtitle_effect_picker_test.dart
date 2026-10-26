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

    expect(find.byType(ChoiceChip), findsNWidgets(14));
    for (final id in const [
      'karaoke', 'typewriter', 'wordReveal', 'movingKaraoke',
      'activeTypewriter', 'backspace', 'lineReveal', 'colorTransition',
      'blinkFlash', 'rainbowText', 'scrambleReveal',
      'spotlightKaraoke', 'typewriterCursor', 'centerOutReveal',
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

  testWidgets('moving karaoke character option is sent in apply configuration',
      (tester) async {
    String? submittedEffect;
    Map<String, dynamic>? submittedConfig;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SubtitleEffectsSheet(
        selectedIndices: const [0],
        lineText: 'കാ👩‍👩‍👧‍👦 text',
        onApplyEffect: (effect, config) {
          submittedEffect = effect;
          submittedConfig = config;
        },
      )),
    ));
    final moving = find.byKey(const ValueKey('srt-effect-movingKaraoke'));
    await tester.ensureVisible(moving);
    await tester.tap(moving);
    await tester.pump();

    final characters = find.byKey(
        const ValueKey('moving-karaoke-unit-character'));
    await tester.ensureVisible(characters);
    await tester.tap(characters);
    await tester.pump();

    expect(find.byKey(const ValueKey('moving-karaoke-unit-word')),
        findsOneWidget);
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(submittedEffect, 'movingKaraoke');
    expect(submittedConfig?['unit'], 'character');
    expect(tester.takeException(), isNull);
  });
}
