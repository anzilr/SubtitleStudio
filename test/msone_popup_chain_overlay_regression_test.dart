import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_main_menu.dart';
import 'package:subtitle_studio/screens/msone_submission_flow.dart';

void main() {
  testWidgets(
    'real popup menu -> selection sheet -> form Back retains '
    'editor and home touch handling',
    (tester) async {
      var editorTaps = 0;
      var homeTaps = 0;
      var formReturns = 0;
      var choiceComplete = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: Builder(builder: (homeContext) {
            return ElevatedButton(
              onPressed: () {
                homeTaps++;
                unawaited(Navigator.of(homeContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (editorContext) => Scaffold(
                      appBar: AppBar(title: const Text('Editor')),
                      body: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              unawaited(showEditMainMenu(
                                context: editorContext,
                                isSourceView: false,
                                isVideoLoaded: false,
                                floatingControlsEnabled: false,
                                isWaveformLoaded: false,
                                isWaveformVisible: false,
                                hasSecondarySubtitles: false,
                                showSecondarySubtitles: false,
                                isMsoneEnabled: true,
                              ).then((selection) async {
                                if (selection != 'submit_msone') return;
                                await showMsoneSubmissionFlow(
                                  context: editorContext,
                                  subtitleCollectionId: 42,
                                  onReturnToEditor: () {
                                    formReturns++;
                                    choiceComplete = true;
                                  },
                                  destinationBuilder: (_, mode) =>
                                      Scaffold(
                                    appBar: AppBar(title: Text('MSone $mode')),
                                    body: const Text('Form content'),
                                  ),
                                );
                              }));
                            },
                            child: const Text('Open main menu'),
                          ),
                          ElevatedButton(
                            onPressed: () => editorTaps++,
                            child: const Text('Tap editor'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
              },
              child: const Text('Open editor'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open main menu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit to Msone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit to Msone'));
      await tester.pumpAndSettle();

      expect(find.text('Existing Translator'), findsOneWidget);
      await tester.tap(find.text('Existing Translator'));
      await tester.pumpAndSettle();

      expect(find.text('MSone main'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(choiceComplete, isTrue);
      expect(formReturns, 1);
      expect(find.text('Editor'), findsOneWidget);

      // App navigation alone is insufficient: actual pointer taps must work.
      await tester.tap(find.text('Tap editor'));
      await tester.pumpAndSettle();
      expect(editorTaps, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(homeTaps, 2);
      expect(find.text('Editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
