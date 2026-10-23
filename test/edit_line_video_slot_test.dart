import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/widgets/edit_line_video_slot.dart';

void main() {
  test('removes the inline player by key at all responsive heights', () {
    for (final height in [170.0, 200.0, 240.0]) {
      final playerSlot = SizedBox(
        key: EditLineVideoSlot.inlinePlayer,
        height: height,
        child: const Placeholder(),
      );
      const videoGap = SizedBox(
        key: EditLineVideoSlot.inlineSpacing,
        height: 1,
      );
      const otherBox = SizedBox(height: 240);
      const otherGap = SizedBox(height: 1);
      const editor = Text('Subtitle editor');

      final remaining = EditLineVideoSlot.withoutInlineVideo([
        playerSlot,
        videoGap,
        otherBox,
        otherGap,
        editor,
      ]);

      expect(remaining, hasLength(3));
      expect(remaining[0], same(otherBox));
      expect(remaining[1], same(otherGap));
      expect(remaining[2], same(editor));
    }
  });

  testWidgets('fixed and resizable layouts never mount the video GlobalKey twice',
      (tester) async {
    final playerKey = GlobalKey(debugLabel: 'only-video-player');

    Widget build({required bool resizable, required double videoHeight}) {
      final inlineContent = Column(
        children: [
          SizedBox(
            key: EditLineVideoSlot.inlinePlayer,
            height: videoHeight,
            child: Placeholder(key: playerKey),
          ),
          const SizedBox(key: EditLineVideoSlot.inlineSpacing, height: 1),
          const Expanded(child: Text('Editor controls')),
        ],
      );

      return MaterialApp(
        home: Scaffold(
          body: resizable
              ? Column(
                  children: [
                    SizedBox(
                      height: videoHeight,
                      child: Placeholder(key: playerKey),
                    ),
                    Expanded(
                      child: Column(
                        children: EditLineVideoSlot.withoutInlineVideo(
                          inlineContent.children,
                        ),
                      ),
                    ),
                  ],
                )
              : inlineContent,
        ),
      );
    }

    await tester.pumpWidget(build(resizable: false, videoHeight: 200));
    expect(find.byKey(playerKey), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(build(resizable: true, videoHeight: 200));
    expect(find.byKey(playerKey), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(build(resizable: true, videoHeight: 240));
    expect(find.byKey(playerKey), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(build(resizable: false, videoHeight: 170));
    expect(find.byKey(playerKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
