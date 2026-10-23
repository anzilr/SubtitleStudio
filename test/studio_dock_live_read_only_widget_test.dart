import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/desktop_workspace_preview.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('live Studio Dock renders a real cue as read-only',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: DesktopWorkspacePreview(
        liveReadOnly: true,
        projectTitle: 'Live project.srt',
        encoding: 'UTF-8',
        initialCues: [
          WorkspaceDemoCue(
            id: 1,
            start: '00:00:00,000',
            end: '00:00:02,300',
            original: 'Original live cue',
            edited: 'Edited live cue',
            marked: true,
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('LIVE · READ ONLY'), findsOneWidget);
    expect(find.text('Live project.srt'), findsWidgets);
    expect(find.text('Night Drive.mp4'), findsNothing);
    expect(find.text('Original live cue'), findsWidgets);
    expect(find.text('Edited live cue'), findsWidgets);
    expect(find.text('Encoding: UTF-8'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.descendant(
        of: find.byKey(const ValueKey('desktop-edit-1')),
        matching: find.byType(EditableText),
      )).readOnly,
      isTrue,
    );
    expect(tester.widget<IconButton>(
      find.byKey(const ValueKey('preview-play'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('desktop-command-palette')));
    await tester.pumpAndSettle();
    expect(find.text('Toggle review mark'), findsNothing);
    expect(find.text('Toggle playback preview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty live session does not invent a subtitle cue',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DesktopWorkspacePreview(
        initialCues: [],
        liveReadOnly: true,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('This project has no subtitle cues yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
