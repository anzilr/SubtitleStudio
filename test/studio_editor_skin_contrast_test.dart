import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_main_menu.dart';
import 'package:subtitle_studio/screens/edit/widgets/subtitle_card.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_menu.dart';
import 'package:subtitle_studio/themes/studio_menu_item.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';
import 'package:subtitle_studio/widgets/unsaved_changes_sheet.dart';

void main() {
  testWidgets('Editor cards retain legible foregrounds in all nine appearances',
      (tester) async {
    final line = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:04,000'
      ..original = 'മലയാളം subtitle – مرحبا';
    for (final skin in StudioSkin.values) {
      for (final mode in StudioAppearance.values) {
        final tokens = StudioPalette.resolve(skin, mode).tokens;
        await tester.pumpWidget(MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: StudioThemeFactory.resolve(skin, mode),
          home: Scaffold(
            body: SubtitleCard(
              line: line,
              index: 0,
              textContent: line.original,
              formattedStart: line.startTime,
              formattedEnd: line.endTime,
              isSelected: true,
              isCardHighlighted: false,
              isCueHighlighted: true,
              isSelectionMode: false,
              isRangeSelectionActive: false,
              isLightTheme: mode == StudioAppearance.light,
              onEdit: () async {},
              onSelectRequested: () {},
              onRangeSelectionTap: () {},
              onToggleSelection: () {},
              onHighlightAndSeek: () {},
              onSelectionMenu: (_) {},
              onActionsMenu: () {},
              onComment: () {},
              onToggleMark: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(
          tester.widget<CustomHtmlText>(find.byType(CustomHtmlText))
              .defaultStyle?.color,
          tokens.onSurface,
        );
        expect(tester.widget<Card>(find.byType(Card)).color,
            tokens.primaryAction.withValues(alpha: 0.14));
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Editor and Edit Line use one popup menu row design',
      (tester) async {
    for (final skin in StudioSkin.values) {
      for (final mode in StudioAppearance.values) {
        final tokens = StudioPalette.resolve(skin, mode).tokens;
        await tester.pumpWidget(MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: StudioThemeFactory.resolve(skin, mode),
          home: Scaffold(
            body: Column(
              children: [
                StudioMenuItemContent(
                  icon: Icons.settings,
                  title: 'Ordinary action',
                ),
                const StudioMenuItemContent(
                  icon: Icons.delete,
                  title: 'Dangerous action',
                  tone: StudioMenuItemTone.destructive,
                ),
              ],
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.any((i) => i.icon == Icons.settings &&
            i.color == tokens.primaryAction), isTrue);
        expect(icons.any((i) => i.icon == Icons.delete &&
            i.color == tokens.dangerText), isTrue);
        expect(find.text('Ordinary action'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Editor popup keeps original selection values', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      theme: StudioThemeFactory.resolve(
          StudioSkin.carbonJade, StudioAppearance.dark),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            selected = await showEditMainMenu(
              context: context,
              isSourceView: true,
              isVideoLoaded: false,
              floatingControlsEnabled: false,
              isWaveformLoaded: false,
              isWaveformVisible: false,
              hasSecondarySubtitles: false,
              showSecondarySubtitles: false,
              isMsoneEnabled: false,
            );
          },
          child: const Text('Open Editor menu'),
        )),
      ),
    ));
    await tester.tap(find.text('Open Editor menu'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to Timeline View'), findsOneWidget);
    await tester.tap(find.text('Switch to Timeline View'));
    await tester.pumpAndSettle();
    expect(selected, 'switch_to_timeline');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit Line popup keeps its delete command and mode flags',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      theme: StudioThemeFactory.resolve(
          StudioSkin.asterViolet, StudioAppearance.classic),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            selected = await showEditLineMenu(
              context: context,
              isEditMode: true,
              isNewSubtitle: false,
              isVideoLoaded: false,
              hasSecondarySubtitles: false,
              showSecondarySubtitles: false,
              autoResizeOnKeyboard: true,
              isMobilePlatform: true,
              showOriginalLine: true,
              autoSaveWithNavigation: false,
              showOriginalTextField: true,
              isFormattedView: true,
              isMarked: false,
            );
          },
          child: const Text('Open Edit Line menu'),
        )),
      ),
    ));
    await tester.tap(find.text('Open Edit Line menu'));
    await tester.pumpAndSettle();
    final delete = find.text('Delete Subtitle Line');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(selected, 'delete');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsaved changes sheet actions stay wired after restyling',
      (tester) async {
    var saved = 0;
    var discarded = 0;
    await tester.pumpWidget(MaterialApp(
      theme: StudioThemeFactory.resolve(
          StudioSkin.copperCinema, StudioAppearance.light),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              builder: (_) => UnsavedChangesSheet(
                onConfirm: () => saved++,
                onDiscard: () => discarded++,
              ),
            );
          },
          child: const Text('Open unsaved sheet'),
        )),
      ),
    ));
    await tester.tap(find.text('Open unsaved sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and Exit'));
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(discarded, 0);
    await tester.tap(find.text('Open unsaved sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(discarded, 1);
    expect(tester.takeException(), isNull);
  });
}
