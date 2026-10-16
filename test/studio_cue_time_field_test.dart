import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_cue_field.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/themes/studio_time_field.dart';

void main() {
  testWidgets('all nine cue fields show legible text with neutral surfaces',
      (tester) async {
    final ctrl = TextEditingController(
      text: 'മലയാളം · العربية · English 😀',
    );
    addTearDown(ctrl.dispose);
    for (final skin in StudioSkin.values) {
      for (final mode in StudioAppearance.values) {
        final palette = StudioPalette.resolve(skin, mode);
        await tester.pumpWidget(MaterialApp(
          theme: StudioThemeFactory.resolve(skin, mode),
          home: Scaffold(
            body: StudioCueFieldSurface(
              child: TextField(
                key: const ValueKey('subtitle-cue'),
                controller: ctrl,
                expands: true,
                maxLines: null,
                decoration: StudioCueFieldStyle.decoration(
                  padding: const EdgeInsets.all(8),
                ),
                style: StudioCueFieldStyle.text(
                    // The current context above the MaterialApp is not a
                    // descendant of its theme; Builder supplies the new one.
                    tester.element(find.byType(Scaffold)) as BuildContext),
              ),
            ),
          ),
        ));
        await tester.pump();
        final field = tester.widget<TextField>(
            find.byKey(const ValueKey('subtitle-cue')));
        expect(field.controller, same(ctrl));
        expect(field.style?.color, palette.onSurface);
        expect(field.decoration?.filled, isFalse);
        expect(field.decoration?.border, isA<InputBorder>());
        expect(ctrl.text, 'മലയാളം · العربية · English 😀');
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('focused cue border changes without replacing controller/selection',
      (tester) async {
    final ctrl = TextEditingController(text: 'مرحبا');
    ctrl.selection = const TextSelection.collapsed(offset: 3);
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: StudioThemeFactory.resolve(
          StudioSkin.carbonJade, StudioAppearance.dark),
      home: Scaffold(
        body: StudioCueFieldSurface(
          child: Builder(builder: (context) => TextField(
            key: const ValueKey('cue'),
            controller: ctrl,
            maxLines: null,
            expands: true,
            decoration: StudioCueFieldStyle.decoration(
              padding: const EdgeInsets.all(8),
            ),
            style: StudioCueFieldStyle.text(context),
          )),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('cue')));
    await tester.pump();
    expect(ctrl.text, 'مرحبا');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('cue')))
        .controller, same(ctrl));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nine time fields retain time input and share semantic error roles',
      (tester) async {
    final controller = TextEditingController(text: '01:22:33,444');
    addTearDown(controller.dispose);
    for (final skin in StudioSkin.values) {
      for (final mode in StudioAppearance.values) {
        final palette = StudioPalette.resolve(skin, mode);
        await tester.pumpWidget(MaterialApp(
          theme: StudioThemeFactory.resolve(skin, mode),
          home: Scaffold(
            body: StudioTimeField(
              controller: controller,
              label: 'Start Time',
              hasError: true,
              onChanged: (_) {},
              onEditingComplete: () {},
            ),
          ),
        ));
        await tester.pump();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller, same(controller));
        expect(field.style?.color, palette.danger);
        expect(field.decoration?.fillColor, palette.fieldSurface);
        expect(controller.text, '01:22:33,444');
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('cue edits and theme switches preserve controller and undo object',
      (tester) async {
    final controller = TextEditingController(text: 'Original');
    final history = UndoHistoryController();
    addTearDown(controller.dispose);
    addTearDown(history.dispose);
    var mode = StudioAppearance.light;

    Widget build() => MaterialApp(
          theme: StudioThemeFactory.resolve(
              StudioSkin.carbonJade, mode),
          home: Scaffold(
            body: StudioCueFieldSurface(
              child: Builder(builder: (context) => TextField(
                controller: controller,
                undoController: history,
                expands: true,
                maxLines: null,
                decoration: StudioCueFieldStyle.decoration(
                    padding: const EdgeInsets.all(8)),
                style: StudioCueFieldStyle.text(context),
              )),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.enterText(find.byType(TextField), 'Edited മലയാളം');
    expect(controller.text, 'Edited മലയാളം');

    mode = StudioAppearance.classic;
    await tester.pumpWidget(build());
    expect(controller.text, 'Edited മലയാളം');
    expect(tester.widget<TextField>(find.byType(TextField)).undoController,
        same(history));
    expect(tester.takeException(), isNull);
  });
}
