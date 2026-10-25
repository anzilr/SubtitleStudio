import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_layout_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
    StudioDockLayoutPreferences.prefix + 'videoOpen': true,
  }));

  Future<void> launch(WidgetTester tester, {
    bool videoAttached = true,
    Future<bool> Function()? onUnload,
    Future<bool> Function(int, String)? onText,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [
        StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'Original', edited: 'Draft'),
      ],
      videoSurface: videoAttached
          ? const SizedBox(key: ValueKey('test-video-surface'),
              child: Text('Mounted video')) : null,
      onUnloadVideo: onUnload,
      onApplyCueText: onText,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> openUnload(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unload video…'));
    await tester.pumpAndSettle();
  }

  testWidgets('Unload is exposed only when live video and host are present',
      (tester) async {
    await launch(tester, onUnload: () async => true, videoAttached: false);
    await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Unload video…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Unload video…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel keeps the media, Confirm invokes unlink exactly once',
      (tester) async {
    var unlinks = 0;
    await launch(tester, onUnload: () async {
      unlinks++;
      return true;
    });
    await openUnload(tester);
    expect(find.text('Unload this video?'), findsOneWidget);
    expect(find.textContaining('will not be deleted'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(unlinks, 0);
    expect(find.byKey(const ValueKey('test-video-surface')), findsOneWidget);
    await openUnload(tester);
    await tester.tap(find.byKey(const ValueKey('studio-confirm-unload-video')));
    await tester.pumpAndSettle();
    expect(unlinks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed unlink preserves mounted media and explains the error',
      (tester) async {
    await launch(tester, onUnload: () async => false);
    await openUnload(tester);
    await tester.tap(find.byKey(const ValueKey('studio-confirm-unload-video')));
    await tester.pump();
    expect(find.textContaining('Could not unlink this video'), findsOneWidget);
    expect(find.byKey(const ValueKey('test-video-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unsaved cue draft must be handled before any video unlink',
      (tester) async {
    var unlinks = 0;
    var saved = 0;
    await launch(tester,
      onUnload: () async { unlinks++; return true; },
      onText: (_, __) async { saved++; return true; },
    );
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Unsaved editor text');
    await tester.pump();
    await openUnload(tester);
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    expect(find.text('Unload this video?'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(unlinks, 0);
    expect(saved, 0);
    expect(find.text('Unsaved editor text'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
