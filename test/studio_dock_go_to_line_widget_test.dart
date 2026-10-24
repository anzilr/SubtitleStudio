import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_go_to_line_dialog.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  String timecode(int millis) {
    final hours = (millis ~/ 3600000).toString().padLeft(2, '0');
    final minutes = ((millis ~/ 60000) % 60).toString().padLeft(2, '0');
    final seconds = ((millis ~/ 1000) % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds,000';
  }

  List<StudioDockCue> cues(int count) => [
    for (var i = 0; i < count; i++)
      StudioDockCue(
        id: i + 1,
        start: timecode(1000 + i * 2000),
        end: timecode(2000 + i * 2000),
        original: 'Cue ${i + 1}',
        edited: '',
      ),
  ];

  Future<void> launch(WidgetTester tester, {
    int count = 3,
    StudioDockPlaybackLink? playback,
    Future<bool> Function(int, String)? edit,
  }) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: cues(count),
      playback: playback,
      onApplyCueText: edit,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-go-to-line')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseLine(WidgetTester tester, String line) async {
    await tester.enterText(
        find.byKey(const ValueKey('studio-go-to-line-input')), line);
    await tester.tap(find.byKey(const ValueKey('studio-go-to-line-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('Go to line scrolls a long grid and seeks media start plus 50ms',
      (tester) async {
    final link = StudioDockPlaybackLink();
    final positions = <Duration>[];
    link.attach(positions.add);
    addTearDown(link.dispose);
    await launch(tester, count: 200, playback: link);
    expect(find.byKey(const ValueKey('desktop-cue-180')), findsNothing);
    await openDialog(tester);
    await chooseLine(tester, '180');

    final state = tester.state<StudioDockWorkspaceState>(
        find.byType(StudioDockWorkspace));
    expect(state.selectedCueNumber, 180);
    expect(find.byKey(const ValueKey('desktop-cue-180')), findsOneWidget);
    expect(positions, [const Duration(milliseconds: 359050)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid line remains in dialog and Cancel preserves selection',
      (tester) async {
    final link = StudioDockPlaybackLink();
    final positions = <Duration>[];
    link.attach(positions.add);
    addTearDown(link.dispose);
    await launch(tester, playback: link);
    await openDialog(tester);
    await chooseLine(tester, '0');
    expect(find.textContaining('between 1 and 3'), findsOneWidget);
    await chooseLine(tester, '4');
    expect(find.textContaining('between 1 and 3'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.state<StudioDockWorkspaceState>(
        find.byType(StudioDockWorkspace)).selectedCueNumber, 1);
    expect(positions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Go to line clears a hiding search and avoids an unattached player',
      (tester) async {
    final link = StudioDockPlaybackLink();
    addTearDown(link.dispose);
    await launch(tester, count: 12, playback: link);
    await tester.enterText(
        find.byKey(const ValueKey('desktop-cue-search')), 'Cue 1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-cue-8')), findsNothing);
    await openDialog(tester);
    await chooseLine(tester, '8');
    expect(tester.state<StudioDockWorkspaceState>(
        find.byType(StudioDockWorkspace)).selectedCueNumber, 8);
    expect(find.byKey(const ValueKey('desktop-cue-8')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(
        const ValueKey('desktop-cue-search'))).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('An unsaved inspector draft cannot be bypassed by Go to line',
      (tester) async {
    await launch(tester, edit: (_, __) async => true);
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'My pending draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-go-to-line')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-go-to-line-input')), findsNothing);
    expect(find.text('My pending draft'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit menu also opens Go to Line without a new editor',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-edit-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Line…').last);
    await tester.pumpAndSettle();
    await chooseLine(tester, '3');
    expect(tester.state<StudioDockWorkspaceState>(
        find.byType(StudioDockWorkspace)).selectedCueNumber, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Slider and text input stay synchronized', (tester) async {
    int? chosen;
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => Scaffold(body: TextButton(
        onPressed: () async => chosen = await showDialog<int>(
          context: context,
          builder: (_) => const StudioDockGoToLineDialog(
            lineCount: 5, initialLine: 2),
        ),
        child: const Text('Open'),
      )),
    )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('studio-go-to-line-slider'));
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(
        const ValueKey('studio-go-to-line-input'))).controller!.text, '5');
    await tester.tap(find.byKey(const ValueKey('studio-go-to-line-confirm')));
    await tester.pumpAndSettle();
    expect(chosen, 5);
    expect(tester.takeException(), isNull);
  });
}
