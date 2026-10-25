import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/studio_dock_demo.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearAllTestValues();
  });

  testWidgets('wide desktop renders unified workspace and demo warning',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('SubtitleStudio'), findsOneWidget);
    expect(find.text('PROJECT'), findsOneWidget);
    expect(find.text('VIDEO PREVIEW'), findsNothing);
    expect(find.text('WAVEFORM'), findsNothing);
    expect(find.text('SUBTITLE LINES'), findsOneWidget);
    expect(find.text('LINE INSPECTOR'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters cue table and selecting a line updates inspector',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.enterText(
        find.byKey(const ValueKey('desktop-cue-search')), 'midnight');
    await tester.pumpAndSettle();

    expect(find.text('1 / 12'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-cue-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-cue-10')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-11')));
    await tester.pumpAndSettle();

    expect(find.text('00:00:56,900'), findsWidgets);
    expect(find.text('It is almost midnight.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspector toggles and navigation returns to editor',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('toggle-inspector')));
    await tester.pumpAndSettle();
    expect(find.text('LINE INSPECTOR'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-inspector')));
    await tester.pumpAndSettle();
    expect(find.text('LINE INSPECTOR'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rail-1')));
    await tester.pumpAndSettle();
    expect(find.text('Version history'), findsOneWidget);
    await tester.tap(find.text('Back to editor'));
    await tester.pumpAndSettle();
    expect(find.text('VIDEO PREVIEW'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow desktop collapses nonessential side panels',
      (tester) async {
    tester.view.physicalSize = const Size(820, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();
    expect(find.text('PROJECT'), findsNothing);
    expect(find.text('LINE INSPECTOR'), findsNothing);
    expect(find.text('VIDEO PREVIEW'), findsNothing);
    expect(find.text('SUBTITLE LINES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
