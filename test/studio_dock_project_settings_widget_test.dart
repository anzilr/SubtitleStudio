import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

const _cue = StudioDockCue(
  id: 1, start: '00:00:01,000', end: '00:00:02,000',
  original: 'Original', edited: 'Translation',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    bool empty = false,
    Future<void> Function(BuildContext)? open,
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
        onOpenProjectSettings: open == null ? null : () => open(context),
      ),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> chooseSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-file-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('read-only Dock does not advertise project configuration',
      (tester) async {
    await launch(tester);
    expect(find.byKey(const ValueKey('studio-toolbar-project-settings')),
        findsNothing);
    expect(find.byKey(const ValueKey('studio-file-menu')), findsNothing);
  });

  testWidgets('File popup clears before shared settings dialog and Back',
      (tester) async {
    var opened = 0;
    await launch(tester, open: (context) {
      opened++;
      return showDialog<void>(context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Shared project settings'),
          actions: [TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Done'),
          )],
        ));
    });
    await chooseSettings(tester);
    expect(find.text('Shared project settings'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Shared project settings'), findsNothing);
    await chooseSettings(tester);
    expect(opened, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel protects an unsaved cue before Project Settings',
      (tester) async {
    var opened = 0;
    await launch(tester, open: (_) async { opened++; });
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Pending edit');
    await tester.pump();
    await chooseSettings(tester);
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    await chooseSettings(tester);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Discard'),
    ));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty scratch project can access configuration',
      (tester) async {
    var opened = 0;
    await launch(tester, empty: true, open: (_) async { opened++; });
    await tester.tap(find.byKey(
        const ValueKey('studio-empty-project-settings')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
