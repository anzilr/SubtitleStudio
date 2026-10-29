import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_export_dialog.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';

void main() {
  Future<void> launch(WidgetTester tester, {
    bool isEditMode = false,
    required ValueChanged<StudioDockExportOptions?> onResult,
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async => onResult(
          await showDialog<StudioDockExportOptions>(
            context: context,
            builder: (_) => StudioDockExportDialog(
              isEditMode: isEditMode,
              currentEncoding: 'UTF-8',
              availableEncodings: () async => ['UTF-8', 'ISO-8859-1'],
            ),
          ),
        ),
        child: const Text('Open export'),
      )),
    )));
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel does not export', (tester) async {
    StudioDockExportOptions? result;
    var returned = false;
    await launch(tester, onResult: (choice) {
      returned = true;
      result = choice;
    });
    await tester.tap(find.byKey(const ValueKey('studio-export-cancel')));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
  });

  testWidgets('translation export chooses text, encoding and filename tag',
      (tester) async {
    StudioDockExportOptions? result;
    await launch(tester, onResult: (choice) => result = choice);
    await tester.tap(find.byKey(const ValueKey('studio-export-original')));
    await tester.enterText(
      find.byKey(const ValueKey('studio-export-custom-tag')), 'Review');
    await tester.tap(find.byKey(const ValueKey('studio-export-encoding')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('encoding-choice-ISO-8859-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-export-confirm')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.originalOnly, isTrue);
    expect(result!.encoding, 'ISO-8859-1');
    expect(result!.customTag, 'Review');
  });

  testWidgets('Edit Mode exports edited text without translation choice',
      (tester) async {
    StudioDockExportOptions? result;
    await launch(tester,
      isEditMode: true, onResult: (choice) => result = choice);
    expect(find.byKey(const ValueKey('studio-export-original')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('studio-export-confirm')));
    await tester.pumpAndSettle();
    expect(result!.originalOnly, isFalse);
    expect(result!.encoding, 'UTF-8');
  });
}
