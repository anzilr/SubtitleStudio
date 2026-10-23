import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_portrait_layout.dart';

void main() {
  test('compact portrait gives edited text room without changing wider layouts', () {
    final narrow = EditLinePortraitMetrics.fromSize(const Size(320, 720));
    expect(narrow.isCompactPortrait, isTrue);
    expect(narrow.videoHeight, closeTo(187.2, 0.0001));
    expect(narrow.contentPadding, 10);
    expect(narrow.originalCueHeight, 76);
    expect(narrow.editedCueHeight, 120);

    final shortPhone = EditLinePortraitMetrics.fromSize(const Size(390, 600));
    expect(shortPhone.isCompactPortrait, isTrue);
    expect(shortPhone.videoHeight, 170);

    for (final size in [const Size(900, 600), const Size(700, 1000)]) {
      final wider = EditLinePortraitMetrics.fromSize(size);
      expect(wider.isCompactPortrait, isFalse);
      expect(wider.videoHeight, 240);
      expect(wider.contentPadding, 16);
      expect(wider.originalCueHeight, 100);
      expect(wider.editedCueHeight, 100);
    }
  });

  testWidgets('start and end time stay side by side at phone widths',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const startKey = ValueKey('start-time-field');
    const endKey = ValueKey('end-time-field');

    Widget build() => const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(10),
              child: EditLineTimeFieldsLayout(
                startField: SizedBox(
                  key: startKey,
                  height: 52,
                ),
                endField: SizedBox(
                  key: endKey,
                  height: 52,
                ),
              ),
            ),
          ),
        );

    tester.view.physicalSize = const Size(320, 720);
    await tester.pumpWidget(build());
    expect(find.byKey(const ValueKey('edit-line-time-side-by-side')),
        findsOneWidget);
    final narrowStart = tester.getRect(find.byKey(startKey));
    final narrowEnd = tester.getRect(find.byKey(endKey));
    expect(narrowStart.top, narrowEnd.top);
    expect(narrowEnd.left, greaterThan(narrowStart.right));
    expect(narrowStart.width, closeTo(142, 0.001));
    expect(narrowEnd.width, closeTo(142, 0.001));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(430, 800);
    await tester.pumpWidget(build());
    expect(find.byKey(const ValueKey('edit-line-time-side-by-side')),
        findsOneWidget);
    final wideStart = tester.getRect(find.byKey(startKey));
    final wideEnd = tester.getRect(find.byKey(endKey));
    expect(wideStart.top, wideEnd.top);
    expect(wideEnd.left, greaterThan(wideStart.right));
    expect(wideStart.width, greaterThan(190));
    expect(tester.takeException(), isNull);
  });
}
