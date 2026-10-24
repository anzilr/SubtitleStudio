import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/screens/msone_submission_flow.dart';

const _cue = StudioDockCue(
  id: 1, start: '00:00:01,000', end: '00:00:02,000',
  original: 'Source', edited: 'Translated',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    bool empty = false,
    Future<void> Function(BuildContext)? submit,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => StudioDockWorkspace(
        isLiveSession: true,
        initialCues: empty ? const [] : const [_cue],
        onApplyCueText: (_, __) async => true,
        onSubmitToMsone: submit == null ? null : () => submit(context),
      ),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> chooseSubmission(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit to MSone'));
    await tester.pumpAndSettle();
  }

  testWidgets('MSone tools remain hidden while its setting is disabled',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Submit to MSone'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop reuses the existing MSone choice and route cleanup',
      (tester) async {
    await launch(tester, submit: (context) => showMsoneSubmissionFlow(
      context: context,
      subtitleCollectionId: 42,
      destinationBuilder: (_, mode) => Scaffold(
        appBar: AppBar(title: Text('Submission $mode')),
      ),
    ));
    await chooseSubmission(tester);
    expect(find.text('Existing Translator'), findsOneWidget);
    expect(find.text('Fresher'), findsOneWidget);
    await tester.tap(find.text('Existing Translator'));
    await tester.pumpAndSettle();
    expect(find.text('Submission main'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Submission main'), findsNothing);
    await chooseSubmission(tester);
    await tester.tap(find.text('Fresher'));
    await tester.pumpAndSettle();
    expect(find.text('Submission fresher'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Submission fresher'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel protects an unsaved cue before MSone submission',
      (tester) async {
    var submissions = 0;
    await launch(tester, submit: (_) async { submissions++; });
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Unsaved translation');
    await tester.pump();
    await chooseSubmission(tester);
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(submissions, 0);
    await chooseSubmission(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty project exposes MSone submission without a classic route',
      (tester) async {
    var submissions = 0;
    await launch(tester, empty: true,
      submit: (_) async { submissions++; });
    await tester.tap(find.byKey(const ValueKey('studio-empty-submit-msone')));
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(tester.takeException(), isNull);
  });
}
