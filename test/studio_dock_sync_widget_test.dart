import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Future<StudioDockCueUpdate?> Function(int, String, String)? anchored,
    Future<StudioDockCueUpdate?> Function(int, double, double)? framerate,
    bool hasVideo = false,
    Future<bool> Function(int, String)? onEdit,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        initialCues: const [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:02,000', original: 'One', edited: ''),
          StudioDockCue(id: 2, start: '00:00:03,000',
              end: '00:00:04,000', original: 'Two', edited: ''),
        ],
        onSyncAnchoredCues: anchored,
        onConvertFramerate: framerate,
        getVideoFramerate: () => 24.0,
        videoSurface: hasVideo ? const SizedBox() : null,
        onApplyCueText: onEdit,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openTools(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
  }

  Future<void> tapTool(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Time-anchor sync validates before saving and confirms once',
      (tester) async {
    final calls = <(int, String, String)>[];
    await launch(tester, anchored: (id, start, end) async {
      calls.add((id, start, end));
      return const StudioDockCueUpdate(cues: [
        StudioDockCue(id: 1, start: '00:00:02,000',
            end: '00:00:03,000', original: 'One', edited: ''),
        StudioDockCue(id: 2, start: '00:00:05,000',
            end: '00:00:06,000', original: 'Two', edited: ''),
      ], selectedCueId: 1);
    });
    await openTools(tester);
    await tapTool(tester, 'studio-tool-sync-anchors');
    await tester.enterText(find.byKey(const ValueKey('studio-sync-start')),
        'bad');
    await tester.tap(find.byKey(const ValueKey('studio-sync-anchor-next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('HH:mm:ss,SSS'), findsWidgets);
    expect(calls, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('studio-sync-start')),
        '00:00:02,000');
    await tester.enterText(find.byKey(const ValueKey('studio-sync-end')),
        '00:00:08,000');
    await tester.tap(find.byKey(const ValueKey('studio-sync-anchor-next')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('studio-tool-confirm')));
    await tester.pumpAndSettle();
    expect(calls, [(1, '00:00:02,000', '00:00:08,000')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Framerate conversion requires video and offers detected FPS',
      (tester) async {
    final calls = <(int, double, double)>[];
    Future<StudioDockCueUpdate?> convert(int id, double source,
        double target) async {
      calls.add((id, source, target));
      return null;
    }
    await launch(tester, anchored: (_, __, ___) async => null,
        framerate: convert);
    await openTools(tester);
    expect(tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('studio-tool-sync-fps'))).onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await launch(tester, anchored: (_, __, ___) async => null,
        framerate: convert, hasVideo: true);
    await openTools(tester);
    await tapTool(tester, 'studio-tool-sync-fps');
    final target = tester.widget<TextFormField>(
        find.byKey(const ValueKey('studio-sync-target-fps')));
    expect(target.initialValue, '24.000');
    await tester.enterText(find.byKey(const ValueKey('studio-sync-source-fps')),
        '0');
    await tester.tap(find.byKey(const ValueKey('studio-sync-fps-next')));
    await tester.pumpAndSettle();
    expect(find.text('Enter positive, finite framerates.'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('studio-sync-source-fps')),
        '25');
    await tester.tap(find.byKey(const ValueKey('studio-sync-fps-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-tool-confirm')));
    await tester.pumpAndSettle();
    expect(calls, [(1, 25.0, 24.0)]);
    expect(find.textContaining('Could not apply this tool'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dirty draft Cancel blocks synchronization transaction',
      (tester) async {
    var calls = 0;
    await launch(tester,
        onEdit: (_, __) async => true,
        anchored: (_, __, ___) async { calls++; return null; });
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Unsaved translation');
    await tester.pump();
    // Studio Dock protects the dirty inspector before switching to Tools.
    await tester.tap(find.byKey(const ValueKey('studio-timing-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync subtitles…').last);
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-tool-sync-anchors')), findsNothing);
    expect(calls, 0);
    expect(find.text('Unsaved translation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sync submenu routes to the Tools section', (tester) async {
    await launch(tester, anchored: (_, __, ___) async => null);
    await tester.tap(find.byKey(const ValueKey('studio-timing-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync subtitles…').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-tools-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-tool-sync-anchors')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
