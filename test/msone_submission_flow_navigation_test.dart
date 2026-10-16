import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/msone_submission_flow.dart';

void main() {
  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (editorContext) => Center(
            child: ElevatedButton(
              onPressed: () => unawaited(showMsoneSubmissionFlow(
                context: editorContext,
                subtitleCollectionId: 42,
                destinationBuilder: (context, mode) => Scaffold(
                  appBar: AppBar(title: Text('MSone $mode')),
                  body: const Center(child: Text('Submission form')),
                ),
              )),
              child: const Text('Editor active'),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('picker returns main, then Android back returns to editor',
      (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Editor active'));
    await tester.pumpAndSettle();
    expect(find.text('Existing Translator'), findsOneWidget);
    await tester.tap(find.text('Existing Translator'));
    await tester.pumpAndSettle();
    expect(find.text('MSone main'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Editor active'), findsOneWidget);
    expect(find.text('MSone main'), findsNothing);
    expect(tester.takeException(), isNull);

    // A second consecutive entry must not leave stale modal routes behind.
    await tester.tap(find.text('Editor active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fresher'));
    await tester.pumpAndSettle();
    expect(find.text('MSone fresher'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Editor active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back dismisses choice sheet without pushing form',
      (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Editor active'));
    await tester.pumpAndSettle();
    expect(find.text('Submit to Msone'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Submit to Msone'), findsNothing);
    expect(find.text('Submission form'), findsNothing);
    expect(find.text('Editor active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
