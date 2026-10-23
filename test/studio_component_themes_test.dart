import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/themes/theme.dart';

void main() {
  final themes = <ThemeData>[
    AppThemes.lightTheme,
    AppThemes.darkTheme,
    AppThemes.classicTheme,
    for (final skin in StudioSkin.values)
      for (final appearance in StudioAppearance.values)
        StudioThemeFactory.resolve(skin, appearance),
  ];

  test('one control geometry and semantic contract across legacy and skins',
      () {
    for (final theme in themes) {
      final tokens = theme.extension<StudioDesignTokens>()!;
      final context = '${theme.brightness} / ${tokens.primaryAction}';
      final sheet = theme.bottomSheetTheme.shape;
      final dialog = theme.dialogTheme.shape;
      final popup = theme.popupMenuTheme.shape;

      expect(sheet, isA<RoundedRectangleBorder>(), reason: context);
      expect(dialog, isA<RoundedRectangleBorder>(), reason: context);
      expect(popup, isA<RoundedRectangleBorder>(), reason: context);
      final sheetRadius =
          (sheet! as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr);
      final dialogRadius =
          (dialog! as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr);
      final popupRadius =
          (popup! as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr);
      expect(sheetRadius.topLeft.x, StudioRadius.sheet, reason: context);
      expect(sheetRadius.bottomLeft.x, 0, reason: context);
      expect(dialogRadius.topLeft.x, StudioRadius.sheet, reason: context);
      expect(popupRadius.topLeft.x, StudioRadius.card, reason: context);

      expect(theme.bottomSheetTheme.modalBackgroundColor, tokens.surface,
          reason: context);
      expect(theme.dialogTheme.backgroundColor, tokens.surface,
          reason: context);
      expect(theme.popupMenuTheme.color, tokens.raisedSurface,
          reason: context);

      expect(theme.sliderTheme.activeTrackColor, tokens.primaryAction,
          reason: context);
      expect(theme.sliderTheme.thumbColor, tokens.primaryAction,
          reason: context);
      expect(theme.sliderTheme.inactiveTrackColor, tokens.outline,
          reason: context);

      final filled = theme.filledButtonTheme.style!;
      final outlined = theme.outlinedButtonTheme.style!;
      final elevated = theme.elevatedButtonTheme.style!;
      final text = theme.textButtonTheme.style!;
      final icon = theme.iconButtonTheme.style!;
      final segmented = theme.segmentedButtonTheme.style!;
      for (final style in [
        filled, outlined, elevated, text, icon, segmented,
      ]) {
        final min = style.minimumSize!.resolve({});
        expect(min!.height, StudioSizing.touchTarget, reason: context);
      }
      expect(
        filled.backgroundColor!.resolve({}),
        tokens.primaryAction,
        reason: context,
      );
      expect(
        filled.foregroundColor!.resolve({}),
        tokens.onPrimaryAction,
        reason: context,
      );
      expect(
        outlined.foregroundColor!.resolve({}),
        tokens.primaryAction,
        reason: context,
      );
      expect(theme.dropdownMenuTheme.menuStyle, isNotNull, reason: context);
      expect(theme.menuTheme.style, isNotNull, reason: context);
    }
  });

  testWidgets('bottom sheets and dialogs inherit the same component contract',
      (tester) async {
    for (final theme in [
      AppThemes.lightTheme,
      StudioThemeFactory.resolve(
        StudioSkin.carbonJade,
        StudioAppearance.dark,
      ),
      StudioThemeFactory.resolve(
        StudioSkin.copperCinema,
        StudioAppearance.classic,
      ),
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              Builder(builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) =>
                          const Padding(
                            padding: EdgeInsets.all(StudioSpacing.md),
                            child: Text('Shared bottom sheet'),
                          ),
                    ),
                    child: const Text('Open sheet'),
                  )),
              Builder(builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('Shared dialog'),
                        content: Text('Confirm action'),
                      ),
                    ),
                    child: const Text('Open dialog'),
                  )),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Shared bottom sheet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.text('Shared bottom sheet'), findsNothing);
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Shared dialog'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Shared dialog'), findsNothing);
    }
  });
}
