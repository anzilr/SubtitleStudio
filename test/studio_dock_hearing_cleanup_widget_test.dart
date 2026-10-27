import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Future<StudioDockCueUpdate?> Function(int)? cleanup,
    bool empty = false,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        initialCues: empty ? const [] : const [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:02,000', original: '[SOUND] Hello', edited: ''),
          StudioDockCue(id: 2, start: '00:00:03,000',
              end: '00:00:04,000', original: 'Goodbye', edited: ''),
        ],
        onApplyCueText: (_, __) async => true,
        onRemoveHearingImpaired: cleanup,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> chooseFromMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-subtitle-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Hearing Impaired…').last);
    await tester.pumpAndSettle();
  }

  testWidgets('Read-only and empty sessions do not expose cleanup',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-subtitle-menu')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove Hearing Impaired'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-tool-hearing-cleanup')),
        findsNothing);
    expect(tester.takeException(), isNull);

    // A new project mounts a fresh workspace State; do not reuse the
    // previous populated project's local cue projection in this widget test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await launch(tester, empty: true,
        cleanup: (_) async => null);
    // The empty-project landing does not mount the editor's Subtitle menu.
    expect(find.byKey(const ValueKey('studio-subtitle-menu')), findsNothing);
    expect(find.byKey(const ValueKey('studio-tool-hearing-cleanup')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu cleanup requires confirmation and refreshes cues on success',
      (tester) async {
    var calls = 0;
    await launch(tester, cleanup: (selected) async {
      calls++;
      expect(selected, 1);
      return const StudioDockCueUpdate(cues: [
        StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'Hello', edited: ''),
        StudioDockCue(id: 2, start: '00:00:03,000',
            end: '00:00:04,000', original: 'Goodbye', edited: ''),
      ], selectedCueId: 1);
    });
    await chooseFromMenu(tester);
    expect(find.text('Remove hearing-impaired annotations'), findsOneWidget);
    expect(find.textContaining('Lines left empty may be deleted'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(calls, 0);

    await chooseFromMenu(tester);
    await tester.tap(find.byKey(const ValueKey('studio-tool-confirm')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Hello'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unsaved subtitle draft blocks cleanup on Cancel',
      (tester) async {
    var calls = 0;
    await launch(tester, cleanup: (_) async { calls++; return null; });
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Unapplied translation');
    await tester.pump();
    await chooseFromMenu(tester);
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Unapplied translation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools panel reuses same action and shows failures',
      (tester) async {
    var calls = 0;
    await launch(tester, cleanup: (_) async { calls++; return null; });
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('studio-tool-hearing-cleanup'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-tool-confirm')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Could not apply this tool'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
