import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/studio_dock_demo.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();
  }

  testWidgets('palette can mark selected demo cue without saving project',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('desktop-command-palette')));
    await tester.pumpAndSettle();
    expect(find.text('Studio Dock commands'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('palette-search')),
        'toggle review mark');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toggle review mark'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inspector-tab-Notes')));
    await tester.pumpAndSettle();
    expect(find.text('No review mark on this subtitle.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid selection and keyboard cue navigation remain separate',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-5')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('#06'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl click selects an additional cue for preview mark action',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-5')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-4')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop-command-palette')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('palette-search')), 'toggle review');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toggle review mark'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inspector-tab-Notes')));
    await tester.pumpAndSettle();
    expect(find.text('Review unresolved · this subtitle needs attention.'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-5')));
    await tester.pumpAndSettle();
    expect(find.text('No review mark on this subtitle.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
