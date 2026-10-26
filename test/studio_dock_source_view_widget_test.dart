import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

const _initial = '1\n00:00:01,000 --> 00:00:02,000\nFirst line';
const _edited = '1\n00:00:01,000 --> 00:00:02,000\nEdited from source';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    Future<String> Function()? load,
    Future<StudioDockCueUpdate?> Function(String)? apply,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'First line', edited: '',
      )],
      isLiveSession: true,
      onLoadSourceView: load ?? () async => _initial,
      onApplySourceView: apply,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> openSource(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('rail-5')));
    await tester.pumpAndSettle();
    expect(find.text('Source View'), findsOneWidget);
  }

  testWidgets('Source View uses existing single raw SRT editor',
      (tester) async {
    await launch(tester, apply: (_) async => null);
    await openSource(tester);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('raw-srt-editor')))
        .controller!.text, _initial);
    expect(find.byKey(const ValueKey('studio-source-apply')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed source is rejected without calling persistence',
      (tester) async {
    var applied = 0;
    await launch(tester, apply: (_) async {
      applied++;
      return null;
    });
    await openSource(tester);
    await tester.enterText(find.byKey(const ValueKey('raw-srt-editor')),
        '1\nInvalid timecode');
    await tester.pump();
    expect(find.text('Unsaved source changes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-source-apply')));
    await tester.pumpAndSettle();
    expect(applied, 0);
    expect(find.textContaining('Invalid SRT cue'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('raw-srt-editor')))
        .controller!.text, '1\nInvalid timecode');
  });

  testWidgets('Cancel keeps dirty source; Discard returns to editor',
      (tester) async {
    await launch(tester, apply: (_) async => null);
    await openSource(tester);
    await tester.enterText(find.byKey(const ValueKey('raw-srt-editor')),
        _edited);
    await tester.tap(find.byKey(const ValueKey('rail-0')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved Source View changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-source-view')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rail-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-source-view')), findsNothing);
    expect(find.byKey(const ValueKey('studio-subtitle-count')), findsOneWidget);
  });

  testWidgets('Apply refreshes complete cue list and source baseline',
      (tester) async {
    String live = _initial;
    var saves = 0;
    await launch(tester,
      load: () async => live,
      apply: (raw) async {
        saves++;
        live = raw;
        return const StudioDockCueUpdate(
          cues: [StudioDockCue(
            id: 1, start: '00:00:01,000', end: '00:00:02,000',
            original: 'First line', edited: 'Edited from source',
          )],
          selectedCueId: 1,
        );
      },
    );
    await openSource(tester);
    await tester.enterText(find.byKey(const ValueKey('raw-srt-editor')),
        _edited);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-source-apply')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Unsaved source changes'), findsNothing);
    expect(tester.widget<FilledButton>(
        find.byKey(const ValueKey('studio-source-apply'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('rail-0')));
    await tester.pumpAndSettle();
    expect(find.text('Edited from source'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed persistence retains a dirty raw draft', (tester) async {
    await launch(tester, apply: (_) async => null);
    await openSource(tester);
    await tester.enterText(find.byKey(const ValueKey('raw-srt-editor')),
        _edited);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-source-apply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('project may have changed'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('raw-srt-editor')))
        .controller!.text, _edited);
    expect(find.text('Unsaved source changes'), findsOneWidget);
  });

  testWidgets('read-only Source View is selectable but cannot commit',
      (tester) async {
    await launch(tester);
    await openSource(tester);
    expect(find.textContaining('First line'), findsWidgets);
    expect(find.byKey(const ValueKey('raw-srt-editor')), findsNothing);
    expect(find.byKey(const ValueKey('studio-source-apply')), findsNothing);
  });
}
