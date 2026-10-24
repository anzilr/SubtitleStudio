import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Future<void> Function(BuildContext)? openImport,
    bool empty = false,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => StudioDockWorkspace(
        isLiveSession: true,
        initialCues: empty ? const [] : const [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:02,000', original: 'First', edited: ''),
          StudioDockCue(id: 2, start: '00:00:03,000',
              end: '00:00:04,000', original: 'Second', edited: ''),
        ],
        onApplyCueText: (_, __) async => true,
        onImportComments: openImport == null ? null : () => openImport(context),
      ),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> chooseComments(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import Comments (.msone)…').last);
    await tester.pumpAndSettle();
  }

  testWidgets('Read-only session does not offer project comment import',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Import Comments'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-tool-import-comments')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools popup dismisses before shared import dialog and Back',
      (tester) async {
    var opens = 0;
    await launch(tester, openImport: (context) {
      opens++;
      return showDialog<void>(context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Shared comment importer'),
          actions: [TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Done'),
          )],
        ));
    });
    await chooseComments(tester);
    expect(find.text('Shared comment importer'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Shared comment importer'), findsNothing);
    await chooseComments(tester);
    expect(opens, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dirty inspector draft cancels import or explicitly discards',
      (tester) async {
    var opens = 0;
    await launch(tester, openImport: (_) async { opens++; });
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Unsaved subtitle text');
    await tester.pump();
    await chooseComments(tester);
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opens, 0);
    expect(find.text('Unsaved subtitle text'), findsWidgets);

    await chooseComments(tester);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog), matching: find.text('Discard')));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools panel can open the same import route', (tester) async {
    var opens = 0;
    await launch(tester, openImport: (_) async { opens++; });
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('studio-tool-import-comments'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty scratch project does not offer an unusable import',
      (tester) async {
    var opens = 0;
    await launch(tester, empty: true, openImport: (_) async { opens++; });
    expect(find.byKey(const ValueKey('studio-tool-import-comments')),
        findsNothing);
    expect(find.byKey(const ValueKey('studio-tools-menu')), findsNothing);
    expect(opens, 0);
    expect(tester.takeException(), isNull);
  });
}
