import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/widgets/edit_main_menu.dart';
import 'package:subtitle_studio/screens/msone_submission_flow.dart';

void main() {
  testWidgets(
    'completed MSone form Back balances an unfinished Navigator gesture '
    'and restores taps',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      var editorTaps = 0;
      var homeTaps = 0;
      var flowReturned = false;

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Builder(builder: (homeContext) => ElevatedButton(
            onPressed: () {
              homeTaps++;
              unawaited(Navigator.of(homeContext).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Editor')),
                    body: Column(children: [
                      ElevatedButton(
                        onPressed: () {
                          unawaited(showMsoneSubmissionFlow(
                            context: context,
                            subtitleCollectionId: 42,
                            destinationBuilder: (_, _) => Scaffold(
                              appBar: AppBar(title: const Text('MSone form')),
                            ),
                            onReturnToEditor: () => flowReturned = true,
                          ));
                        },
                        child: const Text('Submit to Msone'),
                      ),
                      ElevatedButton(
                        onPressed: () => editorTaps++,
                        child: const Text('Tap editor'),
                      ),
                    ]),
                  ),
                ),
              ));
            },
            child: const Text('Open editor'),
          )),
        ),
      ));

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit to Msone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Existing Translator'));
      await tester.pumpAndSettle();
      expect(find.text('MSone form'), findsOneWidget);

      // Simulate an Android back gesture whose start was delivered but
      // whose stop callback was lost during an outgoing page transition.
      navigatorKey.currentState!.didStartUserGesture();
      expect(navigatorKey.currentState!.userGestureInProgress, isTrue);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(flowReturned, isTrue);
      expect(navigatorKey.currentState!.userGestureInProgress, isFalse,
          reason: 'A completed route must not retain gesture input blocking');
      await tester.tap(find.text('Tap editor'));
      await tester.pumpAndSettle();
      expect(editorTaps, 1);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(homeTaps, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real popup menu -> selection sheet -> form Back retains '
    'editor and home touch handling',
    (tester) async {
      final routeObserver = _MsoneModalBarrierObserver();
      var editorTaps = 0;
      var homeTaps = 0;
      var formReturns = 0;
      var choiceComplete = false;
      var formOverlayGoneAtReturn = false;

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [routeObserver],
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
                                    formOverlayGoneAtReturn = routeObserver
                                        .submissionRoute!.overlayEntries
                                        .every((entry) => !entry.mounted);
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
      expect(routeObserver.menuBarrierGoneBeforeSheet, isTrue,
          reason: 'The popup menu barrier must exit before choice sheet opens');
      expect(routeObserver.sheetBarrierGoneBeforeForm, isTrue,
          reason: 'The choice sheet barrier must exit before form opens');
      expect(formOverlayGoneAtReturn, isTrue,
          reason: 'The form transition must finish before editor resumes');
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

class _MsoneModalBarrierObserver extends NavigatorObserver {
  Route<dynamic>? menuRoute;
  Route<dynamic>? sheetRoute;
  Route<dynamic>? submissionRoute;
  bool menuBarrierGoneBeforeSheet = false;
  bool sheetBarrierGoneBeforeForm = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      if (menuRoute == null) {
        menuRoute = route;
      } else if (sheetRoute == null) {
        menuBarrierGoneBeforeSheet = menuRoute!.overlayEntries
            .every((entry) => !entry.mounted);
        sheetRoute = route;
      }
      return;
    }

    if (route is MaterialPageRoute &&
        sheetRoute != null &&
        submissionRoute == null) {
      sheetBarrierGoneBeforeForm = sheetRoute!.overlayEntries
          .every((entry) => !entry.mounted);
      submissionRoute = route;
    }
  }
}
