import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/msone_submission_flow.dart';

void main() {
  testWidgets('after pop, navigation logs a returned-to-editor frame',
      (tester) async {
    // This verifies page restoration. Native mpv hot-restart cannot be
    // reproduced by a Flutter widget test.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMsoneSubmissionFlow(
              context: context,
              subtitleCollectionId: 7,
              destinationBuilder: (_, mode) =>
                  Scaffold(appBar: AppBar(title: Text(mode))),
            ),
            child: const Text('Editor'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing Translator'));
    await tester.pumpAndSettle();
    expect(find.text('main'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
