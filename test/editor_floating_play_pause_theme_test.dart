import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/widgets/editor_floating_play_pause_button.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';

void main() {
  for (final skin in StudioSkin.values) {
    for (final mode in StudioAppearance.values) {
      testWidgets('Editor floating playback follows ${skin.name} ${mode.name}',
          (tester) async {
        final playing = StreamController<bool>.broadcast();
        addTearDown(playing.close);
        var tapped = 0;
        final theme = StudioThemeFactory.resolve(skin, mode);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: EditorFloatingPlayPauseButton(
                playing: playing.stream,
                initiallyPlaying: false,
                onPressed: () => tapped++,
              ),
            ),
          ),
        ));
        expect(tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        ).backgroundColor, theme.colorScheme.primary);
        expect(tester.widget<Icon>(find.byIcon(Icons.play_arrow)).color,
            theme.colorScheme.onPrimary);

        await tester.tap(find.byType(FloatingActionButton));
        expect(tapped, 1);
        playing.add(true);
        await tester.pump();
        expect(tester.widget<Icon>(find.byIcon(Icons.pause)).color,
            theme.colorScheme.onPrimary);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
