import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/screen_help.dart';

void main() {
  testWidgets('expanded Help sections have a visible Material ink surface',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 850);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const HelpScreen(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The category expands to reveal several nested ExpansionTiles. The
    // decorated inner tiles previously threw framework assertions on build.
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsWidgets);
    expect(tester.takeException(), isNull);

    final innerTile = find.byType(ExpansionTile).at(1);
    await tester.ensureVisible(innerTile);
    await tester.tap(innerTile);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
