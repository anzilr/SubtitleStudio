import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/desktop_workspace_preview.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    required Future<bool> Function(int, String) apply,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: DesktopWorkspacePreview(
        liveReadOnly: true,
        onApplyCueText: apply,
        initialCues: const [
          WorkspaceDemoCue(
            id: 1, start: '00:00:01,000', end: '00:00:02,000',
            original: 'Original 1', edited: 'Earlier edit',
          ),
          WorkspaceDemoCue(
            id: 2, start: '00:00:03,000', end: '00:00:04,000',
            original: 'Original 2', edited: '',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Apply is the only action that invokes persistence callback',
      (tester) async {
    final calls = <String>[];
    await launch(tester, apply: (number, text) async {
      calls.add('$number:$text');
      return true;
    });
    expect(find.text('LIVE · TEXT EDIT'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('studio-edit-1-0')), 'New draft');
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(calls, ['1:New draft']);
    expect(find.text('New draft'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirty cue selection supports Cancel and Discard',
      (tester) async {
    await launch(tester, apply: (_, __) async => true);
    await tester.enterText(
      find.byKey(const ValueKey('studio-edit-1-0')), 'Keep this draft');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Original 2'), findsWidgets);
    expect(find.text('Keep this draft'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed Apply retains draft and does not advance selection',
      (tester) async {
    await launch(tester, apply: (_, __) async => false);
    await tester.enterText(
      find.byKey(const ValueKey('studio-edit-1-0')), 'Conflicted draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    // Inspect before the transient SnackBar auto-dismisses; pumpAndSettle
    // otherwise advances the full notification lifetime.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Conflicted draft'), findsWidgets);
    expect(find.byKey(const ValueKey('studio-discard-cue')), findsOneWidget);
    expect(find.textContaining('Could not apply this edit'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
