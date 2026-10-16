import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/positioning_buttons_widget.dart';

void main() {
  testWidgets('positioning sheet scrolls rather than overflowing with keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: 'Subtitle');
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: StudioThemeFactory.resolve(
          StudioSkin.carbonZero, StudioAppearance.dark),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: PositioningButtonsWidget(controller: controller),
            ),
          ),
          child: const Text('Open positioning'),
        )),
      ),
    ));

    await tester.tap(find.text('Open positioning'));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Apply Position'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
