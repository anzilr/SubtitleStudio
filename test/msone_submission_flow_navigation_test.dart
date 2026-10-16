import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/msone_submission_flow.dart';
import 'package:subtitle_studio/widgets/isolated_loader.dart';

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
  testWidgets('stale full-screen editor loader is removed when MSone returns',
      (tester) async {
    var resumeCount = 0;
    var editorTaps = 0;
    late BuildContext editorContext;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            editorContext = context;
            return ElevatedButton(
              onPressed: () {
                editorTaps++;
                unawaited(showMsoneSubmissionFlow(
                  context: context,
                  subtitleCollectionId: 42,
                  onReturnToEditor: () {
                    resumeCount++;
                    IsolatedLoaderController.hide();
                  },
                  destinationBuilder: (_, mode) =>
                      Scaffold(appBar: AppBar(title: Text('MSone $mode'))),
                ));
              },
              child: const Text('Editor action'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('Editor action'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing Translator'));
    await tester.pumpAndSettle();
    expect(find.text('MSone main'), findsOneWidget);
    // Simulate a long-running editor cue-scroll loader that was left on the
    // Navigator's overlay. It would absorb ALL editor touch events on return.
    IsolatedLoaderController.show(editorContext);
    expect(IsolatedLoaderController.isVisible, isTrue);
    await tester.binding.handlePopRoute();
    // First pump advances the route-pop animation; settle the transition
    // before checking hit testing, or the editor remains translated offscreen.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(resumeCount, 1);
    expect(IsolatedLoaderController.isVisible, isFalse);
    expect(find.text('Editor action'), findsOneWidget);
    await tester.tap(find.text('Editor action'));
    await tester.pumpAndSettle();
    expect(editorTaps, 2);
    expect(tester.takeException(), isNull);
    IsolatedLoaderController.hide();
  });

}
