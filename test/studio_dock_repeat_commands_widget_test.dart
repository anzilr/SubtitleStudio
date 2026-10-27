import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_layout_preferences.dart';
import 'package:subtitle_studio/widgets/video/repeat_range_dialog.dart';
import 'package:subtitle_studio/widgets/video/subtitle.dart';

const _cues = [
  StudioDockCue(id: 1, start: '00:00:01,000', end: '00:00:02,000',
      original: 'First', edited: ''),
  StudioDockCue(id: 2, start: '00:00:03,000', end: '00:00:04,000',
      original: 'Second', edited: ''),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
    StudioDockLayoutPreferences.prefix + 'videoOpen': true,
  }));

  Future<void> openView(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-media-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('View repeat actions target mounted media without remounting',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final link = StudioDockPlaybackLink()..attach((_) {});
    var toggleCount = 0;
    var rangeCount = 0;
    var enabled = false;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (context, update) => StudioDockWorkspace(
        isLiveSession: true,
        initialCues: _cues,
        playback: link,
        videoSurface: const Center(child: Text('Single player')),
        onToggleRepeat: () {
          toggleCount++;
          update(() => enabled = !enabled);
        },
        onOpenRepeatRange: () => rangeCount++,
        repeatEnabled: enabled,
      ),
    )));
    await tester.pumpAndSettle();
    await openView(tester);
    await tester.tap(find.text('Repeat selected subtitle'));
    await tester.pumpAndSettle();
    expect(toggleCount, 1);
    await openView(tester);
    expect(find.text('Stop subtitle repeat'), findsOneWidget);
    await tester.tap(find.text('Repeat subtitle range…'));
    await tester.pumpAndSettle();
    expect(rangeCount, 1);
    expect(find.text('Single player'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    link.dispose();
  });

  testWidgets('Repeat commands are gated without a video surface',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final link = StudioDockPlaybackLink();
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: _cues,
      playback: link,
      onToggleRepeat: () => fail('No media'),
      onOpenRepeatRange: () => fail('No media'),
    )));
    await tester.pumpAndSettle();
    await openView(tester);
    // Typed PopupMenuItem<T> does not match find.byType(PopupMenuItem).
    // Assert the public disabled behavior through the visible labels.
    expect(find.text('Repeat selected subtitle'), findsOneWidget);
    expect(find.text('Repeat subtitle range…'), findsOneWidget);
    await tester.tap(find.text('Repeat selected subtitle'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat selected subtitle'), findsOneWidget);
    await tester.tap(find.text('Repeat subtitle range…'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat subtitle range…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    link.dispose();
  });

  testWidgets('Shared range picker accepts zero-based inclusive bounds',
      (tester) async {
    const subtitles = [
      Subtitle(index: 1, start: Duration(seconds: 1),
          end: Duration(seconds: 2), text: 'First'),
      Subtitle(index: 2, start: Duration(seconds: 3),
          end: Duration(seconds: 4), text: 'Second'),
      Subtitle(index: 3, start: Duration(seconds: 5),
          end: Duration(seconds: 6), text: 'Third'),
    ];
    (int, int)? selected;
    var normal = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<void>(context: context,
          builder: (_) => RepeatRangeDialog(
            subtitles: subtitles,
            onNormalRepeat: () => normal++,
            onCustomRangeSelected: (first, last) => selected = (first, last),
          )),
        child: const Text('Open picker'),
      ),
    ))));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '2');
    await tester.enterText(fields.last, '3');
    await tester.tap(find.text('Apply Range'));
    await tester.pumpAndSettle();
    expect(selected, (1, 2));
    expect(normal, 0);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Normal Repeat'));
    await tester.pumpAndSettle();
    expect(normal, 1);
  });
}
