import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester,
      {ValueChanged<int>? onSelectedCueChanged,
      Future<StudioDockCueUpdate?> Function(List<SubtitleQualityFix>)?
          onApplyQualityFixes}) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        onSelectedCueChanged: onSelectedCueChanged,
        onApplyQualityFixes: onApplyQualityFixes,
        initialCues: const [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:03,000', original: 'First original',
              edited: 'First subtitle'),
          StudioDockCue(id: 2, start: '00:00:02,800',
              end: '00:00:04,000', original: 'Second original',
              edited: 'Overlapping  subtitle '),
          StudioDockCue(id: 3, start: '00:00:05,000',
              end: '00:00:05,500', original: 'Third original',
              edited: 'A subtitle that is excessively long and hard to read'),
        ],
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openQuality(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check subtitle quality…'));
    await tester.pumpAndSettle();
  }

  testWidgets('quality checker opens via Tools and reports without edits',
      (tester) async {
    await launch(tester);
    await openQuality(tester);

    expect(find.text('Subtitle Quality'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-quality-summary')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('studio-quality-issue-2-overlap')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('studio-quality-issue-3-fastReading')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('studio-quality-close')));
    await tester.pumpAndSettle();
    expect(find.text('Subtitle Quality'), findsNothing);
    expect(find.byKey(const ValueKey('desktop-cue-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quality issue navigates to offending cue', (tester) async {
    final selectedIds = <int>[];
    await launch(tester, onSelectedCueChanged: selectedIds.add);
    await openQuality(tester);

    await tester.tap(
        find.byKey(const ValueKey('studio-quality-issue-2-overlap')));
    await tester.pumpAndSettle();

    expect(find.text('Subtitle Quality'), findsNothing);
    expect(selectedIds.last, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile choice is remembered across quality dialogs',
      (tester) async {
    await launch(tester);
    await openQuality(tester);
    await tester.tap(find.byKey(const ValueKey('studio-quality-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Streaming').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-quality-close')));
    await tester.pumpAndSettle();
    await openQuality(tester);
    final dropdown = tester.widget<DropdownButton<SubtitleQualityPreset>>(
        find.byKey(const ValueKey('studio-quality-profile')));
    expect(dropdown.value, SubtitleQualityPreset.streaming);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom rules validate and persist across quality dialogs',
      (tester) async {
    await launch(tester);
    await openQuality(tester);
    await tester.tap(find.byKey(const ValueKey('studio-quality-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('studio-quality-edit-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Custom quality limits'), findsOneWidget);
    final cps = find.byKey(const ValueKey('quality-custom-reading-speed'));
    await tester.enterText(cps, '12.5');
    final save = find.byKey(const ValueKey('quality-custom-save'));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Custom quality limits'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('studio-quality-close')));
    await tester.pumpAndSettle();
    await openQuality(tester);
    final dropdown = tester.widget<DropdownButton<SubtitleQualityPreset>>(
        find.byKey(const ValueKey('studio-quality-profile')));
    expect(dropdown.value, SubtitleQualityPreset.custom);
    await tester.tap(find.byKey(const ValueKey('studio-quality-edit-profile')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(cps).controller!.text, '12.5');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('safe fix preview requires explicit selection before apply',
      (tester) async {
    final applied = <List<SubtitleQualityFix>>[];
    await launch(tester, onApplyQualityFixes: (fixes) async {
      applied.add(fixes);
      return const StudioDockCueUpdate(
        selectedCueId: 2,
        cues: [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:03,000', original: 'First original',
              edited: 'First subtitle'),
          StudioDockCue(id: 2, start: '00:00:02,800',
              end: '00:00:04,000', original: 'Second original',
              edited: 'Overlapping subtitle'),
          StudioDockCue(id: 3, start: '00:00:05,000',
              end: '00:00:05,500', original: 'Third original',
              edited: 'A subtitle that is excessively long and hard to read'),
        ],
      );
    });
    await openQuality(tester);
    await tester.tap(find.byKey(const ValueKey('studio-quality-fixes-tab')));
    await tester.pumpAndSettle();
    final applyButton = find.byKey(const ValueKey('studio-quality-apply-fixes'));
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNull);
    expect(find.textContaining('Before: Overlapping'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-quality-fix-2')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNotNull);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();
    expect(applied, hasLength(1));
    expect(applied.single.single.before, 'Overlapping  subtitle ');
    expect(applied.single.single.after, 'Overlapping subtitle');
    expect(tester.takeException(), isNull);
  });
}
