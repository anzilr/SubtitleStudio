import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const cues = [
    StudioDockCue(id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'First', edited: 'First translation'),
    StudioDockCue(id: 2, start: '00:00:03,000', end: '00:00:04,000',
        original: 'Second', edited: 'Second translation'),
    StudioDockCue(id: 3, start: '00:00:05,000', end: '00:00:06,000',
        original: 'Third', edited: 'Third translation'),
  ];

  Future<void> launch(WidgetTester tester, {
    Future<bool> Function(int, String)? text,
    Future<StudioDockCueUpdate?> Function(List<int>, String, String, int)? shift,
    Future<StudioDockCueUpdate?> Function(List<int>, int)? deleteSelected,
    Future<StudioDockCueUpdate?> Function(int)? deleteCue,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: cues,
      onApplyCueText: text,
      onShiftSelectedCues: shift,
      onDeleteSelectedCues: deleteSelected,
      onDeleteCue: deleteCue,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> contextMenu(WidgetTester tester, int cue) async {
    final row = find.byKey(ValueKey('desktop-cue-$cue'));
    await tester.ensureVisible(row);
    await tester.tapAt(tester.getCenter(row), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
  }

  Future<void> selectLastTwo(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-edit-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select subtitles by index…').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('studio-range-start')), '2');
    await tester.enterText(find.byKey(const ValueKey('studio-range-end')), '3');
    await tester.tap(find.byKey(const ValueKey('studio-range-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('Multi-selection right click exposes mobile selected actions',
      (tester) async {
    await launch(tester,
      shift: (_, __, ___, ____) async => null,
      deleteSelected: (_, __) async => null,
      deleteCue: (_) async => null,
    );
    await selectLastTwo(tester);
    await contextMenu(tester, 2);
    expect(find.text('Copy selected subtitles (2)'), findsOneWidget);
    expect(find.text('Shift selected times (2)…'), findsOneWidget);
    expect(find.text('Delete selected subtitles (2)…'), findsOneWidget);
    expect(find.text('Select subtitles by index…'), findsOneWidget);
    expect(find.text('Select subtitle range'), findsOneWidget);
    expect(find.text('Delete subtitle…'), findsNothing);
    expect(find.text('Edit subtitle…'), findsNothing);
    await tester.tap(find.text('Delete selected subtitles (2)…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 selected subtitles?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 3 subtitles selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Right-clicking another cue targets only that cue for deletion',
      (tester) async {
    final deleted = <List<int>>[];
    await launch(tester,
      deleteSelected: (ids, _) async {
        deleted.add(ids);
        return StudioDockCueUpdate(cues: [cues[1], cues[2]],
            selectedCueId: 2);
      },
    );
    await selectLastTwo(tester);
    await contextMenu(tester, 1);
    expect(find.text('Delete selected subtitles (1)…'), findsOneWidget);
    await tester.tap(find.text('Delete selected subtitles (1)…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 selected subtitles?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-confirm-delete-selected')));
    await tester.pumpAndSettle();
    expect(deleted, [[1]]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dirty cue draft Cancel prevents context action targeting',
      (tester) async {
    var saved = 0;
    await launch(tester, text: (_, __) async { saved++; return true; });
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Unapplied draft');
    await tester.pump();
    await contextMenu(tester, 3);
    await tester.tap(find.text('Edit subtitle…'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unapplied draft'), findsWidgets);
    expect(saved, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Context copy of unselected cue preserves other selected rows',
      (tester) async {
    String? copied;
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
        SystemChannels.platform, null));
    await launch(tester);
    await selectLastTwo(tester);
    await contextMenu(tester, 1);
    await tester.tap(find.text('Copy subtitle text'));
    await tester.pumpAndSettle();
    expect(copied, 'First translation');
    expect(find.textContaining('2 of 3 subtitles selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
