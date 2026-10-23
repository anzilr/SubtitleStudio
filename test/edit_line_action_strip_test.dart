import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_action_strip.dart';

void main() {
  testWidgets('compact and wide toolbars show all original actions in one row',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final taps = <String>[];
    Widget action(String id) => Flexible(
          child: IconButton(
            key: ValueKey(id),
            tooltip: id,
            constraints: const BoxConstraints(minWidth: 24, maxWidth: 36),
            onPressed: () => taps.add(id),
            icon: const Icon(Icons.circle_outlined),
          ),
        );

    Widget build({bool video = true}) => MaterialApp(
          home: Scaffold(
            body: EditLineActionStrip(
              previous: action('previous'),
              dictionary: action('dictionary'),
              formatting: action('formatting'),
              subtitleActions: action('subtitle-actions'),
              save: action('save'),
              playPause: video ? action('play') : null,
              next: action('next'),
            ),
          ),
        );

    await tester.pumpWidget(build());
    expect(find.byKey(const ValueKey('previous')), findsOneWidget);
    expect(find.byKey(const ValueKey('save')), findsOneWidget);
    expect(find.byKey(const ValueKey('play')), findsOneWidget);
    expect(find.byKey(const ValueKey('next')), findsOneWidget);
    expect(find.byKey(const ValueKey('dictionary')), findsOneWidget);
    expect(find.byKey(const ValueKey('formatting')), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-line-tools-toggle')), findsNothing);
    final toolbar = tester.widget<Row>(
      find.byKey(const ValueKey('edit-line-actions-row')),
    );
    expect(toolbar.children, hasLength(7));
    final previous = tester.getRect(find.byKey(const ValueKey('previous')));
    final dictionary = tester.getRect(find.byKey(const ValueKey('dictionary')));
    final formatting = tester.getRect(find.byKey(const ValueKey('formatting')));
    final subtitleActions = tester.getRect(find.byKey(const ValueKey('subtitle-actions')));
    final save = tester.getRect(find.byKey(const ValueKey('save')));
    final play = tester.getRect(find.byKey(const ValueKey('play')));
    final next = tester.getRect(find.byKey(const ValueKey('next')));
    expect(previous.right, lessThanOrEqualTo(dictionary.left));
    expect(dictionary.right, lessThanOrEqualTo(formatting.left));
    expect(formatting.right, lessThanOrEqualTo(subtitleActions.left));
    expect(subtitleActions.right, lessThanOrEqualTo(save.left));
    expect(save.right, lessThanOrEqualTo(play.left));
    expect(play.right, lessThanOrEqualTo(next.left));

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.tap(find.byKey(const ValueKey('next')));
    expect(taps, ['save', 'next']);

    await tester.tap(find.byKey(const ValueKey('dictionary')));
    expect(taps.last, 'dictionary');
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpWidget(build());
    expect(find.byKey(const ValueKey('edit-line-tools-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('dictionary')), findsOneWidget);
    expect(find.byKey(const ValueKey('formatting')), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-actions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar without video keeps dictionary and formatting visible',
      (tester) async {
    final tapped = <String>[];
    Widget action(String id) => Flexible(
          child: IconButton(
            key: ValueKey(id),
            tooltip: id,
            constraints: const BoxConstraints(minWidth: 24, maxWidth: 36),
            onPressed: () => tapped.add(id),
            icon: const Icon(Icons.circle_outlined),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditLineActionStrip(
          previous: action('prev'),
          dictionary: action('dictionary'),
          formatting: action('formatting'),
          save: action('save'),
          next: action('next'),
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('save')), findsOneWidget);
    expect(find.byKey(const ValueKey('next')), findsOneWidget);
    expect(find.byKey(const ValueKey('dictionary')), findsOneWidget);
    expect(find.byKey(const ValueKey('formatting')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-line-tools-toggle')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('formatting')));
    expect(tapped, ['formatting']);
    expect(tester.takeException(), isNull);
  });
}
