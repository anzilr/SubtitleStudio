import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_components.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/themes/theme.dart';
import 'package:subtitle_studio/widgets/project_settings/project_encoding_selector.dart';

double contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a < b ? a : b;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('light dark and classic themes supply contrast-aware Studio tokens', () {
    for (final theme in [
      AppThemes.lightTheme,
      AppThemes.darkTheme,
      AppThemes.classicTheme,
    ]) {
      final colors = theme.extension<StudioDesignTokens>();
      expect(colors, isNotNull);
      expect(contrastRatio(colors!.primaryAction, colors.onPrimaryAction),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(colors.editingAccent, colors.onEditingAccent),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(colors.onSurface, colors.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(colors.mutedText, colors.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(colors.dangerText, colors.surface),
          greaterThanOrEqualTo(4.5));
    }
  });

  test('Studio theme tokens support interpolation and selective overrides', () {
    final light = StudioDesignTokens.light;
    final dark = StudioDesignTokens.dark;

    expect(light.lerp(dark, 0).primaryAction, light.primaryAction);
    expect(light.lerp(dark, 1).primaryAction, dark.primaryAction);
    final middle = light.lerp(dark, 0.5);
    expect(middle.primaryAction, isNot(light.primaryAction));
    expect(middle.primaryAction, isNot(dark.primaryAction));

    const alternate = Color(0xFF123456);
    final modified = light.copyWith(historyAlternate: alternate);
    expect(modified.historyAlternate, alternate);
    expect(modified.primaryAction, light.primaryAction);
    expect(light.historyAlternate, isNot(alternate));
  });

  testWidgets('shared Studio components render semantic controls',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppThemes.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const StudioSurface(
                child: StudioSectionHeader(
                  title: 'Test section',
                  icon: Icons.history,
                ),
              ),
              StudioPrimaryAction(
                label: 'Save version',
                icon: Icons.save,
                onPressed: () => presses++,
              ),
              const StudioStatusMessage(
                message: 'Saved version is unavailable.',
                tone: StudioStatusTone.caution,
              ),
            ],
          ),
        ),
      ),
    ));
    expect(find.text('Test section'), findsOneWidget);
    expect(find.text('Save version'), findsOneWidget);
    expect(find.text('Saved version is unavailable.'), findsOneWidget);

    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(StudioSizing.touchTarget));
    await tester.tap(find.text('Save version'));
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('encoding pilot uses Studio surfaces in existing dark theme',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppThemes.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProjectEncodingSelector(
            selected: 'UTF-8',
            options: const ['UTF-8', 'Windows-1256', 'GB18030'],
            isLoading: false,
            isSaving: false,
            onSelected: (next) async {},
          ),
        ),
      ),
    ));

    expect(find.byType(StudioSurface), findsOneWidget);
    expect(find.byType(StudioSectionHeader), findsOneWidget);
    expect(find.byType(StudioStatusMessage), findsOneWidget);
    expect(find.textContaining('3 encodings available'), findsOneWidget);
    expect(tester.getSize(
      find.byKey(const ValueKey('project-encoding-picker'))).height,
      greaterThanOrEqualTo(StudioSizing.touchTarget));
    expect(tester.takeException(), isNull);
  });
}
