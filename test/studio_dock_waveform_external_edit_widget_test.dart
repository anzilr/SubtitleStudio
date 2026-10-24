import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('waveform history updates do not discard a pending text draft',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dockKey = GlobalKey<StudioDockWorkspaceState>();
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      key: dockKey,
      isLiveSession: true,
      onApplyCueText: (_, __) async => true,
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Translation',
      )],
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Unapplied draft');
    await tester.pump();

    final canceled = dockKey.currentState!.prepareForExternalEdit();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await canceled, isFalse);

    final confirmed = dockKey.currentState!.prepareForExternalEdit();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog), matching: find.text('Discard')));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);

    dockKey.currentState!.acceptExternalCueUpdate(const StudioDockCueUpdate(
      cues: [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:03,000',
        original: 'Original', edited: 'Translation',
      )],
      selectedCueId: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.text('00:00:03,000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
