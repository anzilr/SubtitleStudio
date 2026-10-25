import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_geometry.dart';
import '../tool/studio_dock_demo.dart';

void main() {
  test('balanced dock geometry uses 38/24/38 proportions', () {
    final layout = StudioDockBands.resolve(1010);
    expect(layout.video, closeTo(380, .001));
    expect(layout.waveform, closeTo(240, .001));
    expect(layout.table, closeTo(380, .001));
  });

  test('short windows retain nonnegative panels without overflow', () {
    for (final height in [900.0, 700.0, 500.0, 380.0, 120.0]) {
      final b = StudioDockBands.resolve(height);
      expect(b.video, greaterThanOrEqualTo(0));
      expect(b.waveform, greaterThanOrEqualTo(0));
      expect(b.table, greaterThanOrEqualTo(0));
      expect(b.video + b.waveform + b.table +
          2 * StudioDockBands.splitter, closeTo(height, .001));
    }
  });

  testWidgets('wide workspace hides unconnected media and keeps subtitle columns',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dock-video-band')), findsNothing);
    expect(find.byKey(const ValueKey('dock-waveform-band')), findsNothing);
    final grid = tester.getSize(
        find.byKey(const ValueKey('dock-table-band'))).height;
    expect(grid, greaterThan(400));
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('EDITED'), findsOneWidget);
    // The grid and the combined Text/Timing inspector both show duration.
    expect(find.text('DURATION'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspector tab switches retain edited draft',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('desktop-edit-5')), 'Draft survives tabs');
    await tester.pump();
    expect(find.byKey(const ValueKey('inspector-tab-Timing')), findsNothing);
    expect(find.text('START'), findsWidgets);
    for (final tab in ['Style', 'Notes', 'Text']) {
      await tester.tap(find.byKey(ValueKey('inspector-tab-' + tab)));
      await tester.pumpAndSettle();
    }
    expect(find.text('Draft survives tabs'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow window opens inspector on demand',
      (tester) async {
    tester.view.physicalSize = const Size(820, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('LINE INSPECTOR'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-inspector')));
    await tester.pumpAndSettle();
    expect(find.text('LINE INSPECTOR'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-inspector')));
    await tester.pumpAndSettle();
    expect(find.text('LINE INSPECTOR'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
