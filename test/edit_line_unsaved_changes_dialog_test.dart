import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_dialogs.dart';

void main() {
  Future<void> showPrompt(
    WidgetTester tester, {
    required Future<bool> Function() onSave,
    required VoidCallback onDiscard,
    required VoidCallback onSaved,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUnsavedChangesDialog(
                context: context,
                onLeaveWithoutSaving: onDiscard,
                onSave: onSave,
                onSavedAndLeave: onSaved,
              ),
              child: const Text('Exit editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Exit editor'));
    await tester.pumpAndSettle();
  }

  testWidgets('unsaved edits use a centered popup, not a bottom sheet',
      (tester) async {
    var saved = 0;
    var discarded = 0;
    await showPrompt(
      tester,
      onSave: () async => true,
      onDiscard: () => discarded++,
      onSaved: () => saved++,
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Unsaved Changes'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saved, 0);
    expect(discarded, 0);
  });

  testWidgets('discard confirms leaving without saving exactly once',
      (tester) async {
    var saveCalls = 0;
    var discarded = 0;
    await showPrompt(
      tester,
      onSave: () async {
        saveCalls++;
        return true;
      },
      onDiscard: () => discarded++,
      onSaved: () {},
    );

    await tester.tap(find.text('Leave Without Saving'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(discarded, 1);
    expect(saveCalls, 0);
  });

  testWidgets('failed save keeps popup open so the user can retry',
      (tester) async {
    var saveCalls = 0;
    var saved = 0;
    await showPrompt(
      tester,
      onSave: () async => ++saveCalls == 2,
      onDiscard: () {},
      onSaved: () => saved++,
    );

    await tester.tap(find.text('Save & Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Save & Leave'), findsOneWidget);
    expect(saved, 0);

    await tester.tap(find.text('Save & Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saveCalls, 2);
    expect(saved, 1);
  });

  testWidgets('pending save disables conflicting actions and repeated saves',
      (tester) async {
    final saveResult = Completer<bool>();
    var saveCalls = 0;
    var discarded = 0;
    var saved = 0;
    await showPrompt(
      tester,
      onSave: () {
        saveCalls++;
        return saveResult.future;
      },
      onDiscard: () => discarded++,
      onSaved: () => saved++,
    );

    await tester.tap(find.text('Save & Leave'));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
        .onPressed, isNull);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Leave Without Saving'))
            .onPressed,
        isNull);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    expect(saveCalls, 1);

    saveResult.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saveCalls, 1);
    expect(discarded, 0);
    expect(saved, 1);
  });
}
