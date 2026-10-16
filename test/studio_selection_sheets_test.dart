import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_selection_dialogs.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/delete_confirmation_sheet.dart';

Widget _host(ThemeData theme, void Function(BuildContext) openSheet) {
  return MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => openSheet(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Batch delete warning uses the danger role in all nine modes',
      (tester) async {
    for (final skin in StudioSkin.values) {
      for (final appearance in StudioAppearance.values) {
        var confirmed = 0;
        final tokens = StudioPalette.resolve(skin, appearance).tokens;
        await tester.pumpWidget(_host(
          StudioThemeFactory.resolve(skin, appearance),
          (context) => showBatchDeleteConfirmationSheet(
            context: context,
            selectedCount: 3,
            onConfirm: () async { confirmed++; },
          ),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.textContaining('3 subtitle lines'), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.warning_outlined)).color,
          tokens.dangerText,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(confirmed, 0);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Batch delete confirms once and closes before invoking callback',
      (tester) async {
    var count = 0;
    await tester.pumpWidget(_host(
      StudioThemeFactory.resolve(
        StudioSkin.carbonJade,
        StudioAppearance.dark,
      ),
      (context) => showBatchDeleteConfirmationSheet(
        context: context,
        selectedCount: 2,
        onConfirm: () async { count++; },
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(find.text('Delete Selected Subtitles'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Index range returns zero-based inclusive indices and validates',
      (tester) async {
    Future<List<int>?>? result;
    await tester.pumpWidget(_host(
      StudioThemeFactory.resolve(
        StudioSkin.asterViolet,
        StudioAppearance.classic,
      ),
      (context) => result = showSelectByIndexSheet(
        context: context,
        totalLines: 10,
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '0');
    await tester.enterText(find.byType(TextField).at(1), '4');
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invalid range'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '2');
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(await result, [1, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shift sheet forwards time strings and honors async close flag',
      (tester) async {
    var applied = 0;
    final times = <String>[];
    await tester.pumpWidget(_host(
      StudioThemeFactory.resolve(
        StudioSkin.copperCinema,
        StudioAppearance.light,
      ),
      (context) => showShiftSelectedTimesSheet(
        context: context,
        initialStartTime: '00:00:01,000',
        initialEndTime: '00:00:04,000',
        onApply: (start, end) async {
          applied++;
          times..add(start)..add(end);
          return applied > 1;
        },
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Shift Selected Subtitles'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first)
          .controller?.text,
      '00:00:01,000',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, 1);
    expect(find.text('Shift Selected Subtitles'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, 2);
    expect(times, [
      '00:00:01,000', '00:00:04,000',
      '00:00:01,000', '00:00:04,000',
    ]);
    expect(find.text('Shift Selected Subtitles'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Single delete preserves caller-managed navigation and callback',
      (tester) async {
    var deleted = 0;
    final tokens = StudioPalette.resolve(
      StudioSkin.asterViolet, StudioAppearance.dark,
    ).tokens;
    await tester.pumpWidget(_host(
      StudioThemeFactory.resolve(
        StudioSkin.asterViolet,
        StudioAppearance.dark,
      ),
      (context) => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => DeleteConfirmationSheet(
          lineIndex: 12,
          onConfirm: () {
            deleted++;
            Navigator.pop(sheetContext);
          },
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Line 12 will'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
      tokens.dangerText,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(find.text('Delete Subtitle Line'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
