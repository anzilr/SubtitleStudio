import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester,
      {ValueChanged<int>? onSelectedCueChanged}) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        onSelectedCueChanged: onSelectedCueChanged,
        initialCues: const [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:03,000', original: 'First original',
              edited: 'First subtitle'),
          StudioDockCue(id: 2, start: '00:00:02,800',
              end: '00:00:04,000', original: 'Second original',
              edited: 'Overlapping subtitle'),
          StudioDockCue(id: 3, start: '00:00:05,000',
              end: '00:00:05,500', original: 'Third original',
              edited: 'A subtitle that is excessively long and hard to read'),
        ],
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openQuality(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check subtitle quality…'));
    await tester.pumpAndSettle();
  }

  testWidgets('quality checker opens via Tools and reports without edits',
      (tester) async {
    await launch(tester);
    await openQuality(tester);

    expect(find.text('Subtitle Quality'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-quality-summary')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('studio-quality-issue-2-overlap')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('studio-quality-issue-3-fastReading')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('studio-quality-close')));
    await tester.pumpAndSettle();
    expect(find.text('Subtitle Quality'), findsNothing);
    expect(find.byKey(const ValueKey('desktop-cue-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quality issue navigates to offending cue', (tester) async {
    final selectedIds = <int>[];
    await launch(tester, onSelectedCueChanged: selectedIds.add);
    await openQuality(tester);

    await tester.tap(
        find.byKey(const ValueKey('studio-quality-issue-2-overlap')));
    await tester.pumpAndSettle();

    expect(find.text('Subtitle Quality'), findsNothing);
    expect(selectedIds.last, 2);
    expect(tester.takeException(), isNull);
  });
}
