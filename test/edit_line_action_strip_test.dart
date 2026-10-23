import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_action_strip.dart';

void main() {
  testWidgets('compact bar keeps primary actions visible and reveals tools',
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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => taps.add(id),
            icon: const Icon(Icons.circle_outlined),
          ),
        );

    Widget build({required bool compact, bool video = true}) => MaterialApp(
          home: Scaffold(
            body: EditLineActionStrip(
              compact: compact,
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

    await tester.pumpWidget(build(compact: true));
    expect(find.byKey(const ValueKey('edit-line-compact-actions')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('previous')), findsOneWidget);
    expect(find.byKey(const ValueKey('save')), findsOneWidget);
    expect(find.byKey(const ValueKey('play')), findsOneWidget);
    expect(find.byKey(const ValueKey('next')), findsOneWidget);
    expect(find.byKey(const ValueKey('dictionary')), findsNothing);
    expect(find.byKey(const ValueKey('formatting')), findsNothing);
    expect(find.byKey(const ValueKey('subtitle-actions')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.tap(find.byKey(const ValueKey('next')));
    expect(taps, ['save', 'next']);

    await tester.tap(find.byKey(const ValueKey('edit-line-tools-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('edit-line-extra-tools')), findsOneWidget);
    expect(find.byKey(const ValueKey('dictionary')), findsOneWidget);
    expect(find.byKey(const ValueKey('formatting')), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-actions')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dictionary')));
    expect(taps.last, 'dictionary');
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpWidget(build(compact: false));
    expect(find.byKey(const ValueKey('edit-line-compact-actions')), findsNothing);
    expect(find.byKey(const ValueKey('edit-line-tools-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('dictionary')), findsOneWidget);
    expect(find.byKey(const ValueKey('formatting')), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-actions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no-video compact toolbar retains access to every provided action',
      (tester) async {
    final tapped = <String>[];
    Widget action(String id) => Flexible(
          child: TextButton(
            key: ValueKey(id),
            onPressed: () => tapped.add(id),
            child: Text(id),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditLineActionStrip(
          compact: true,
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
    await tester.tap(find.byKey(const ValueKey('edit-line-tools-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('dictionary')), findsOneWidget);
    expect(find.byKey(const ValueKey('formatting')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-line-extra-tools')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-line-tools-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('edit-line-extra-tools')), findsNothing);
    expect(tapped, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
