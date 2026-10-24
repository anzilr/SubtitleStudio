import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';

const _cue = StudioDockCue(
  id: 1, start: '00:00:01,000', end: '00:00:02,000',
  original: 'Original', edited: 'Old edit',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    required Future<StudioDockFileResult> Function() save,
    Future<StudioDockFileResult> Function()? saveAs,
    Future<StudioDockFileResult> Function(bool)? exportFile,
    Future<StudioDockFileResult> Function()? saveProject,
    Future<StudioDockFileResult> Function()? saveProjectAs,
    Future<bool> Function(int, String)? edit,
    bool isEditMode = false,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      isEditMode: isEditMode,
      initialCues: const [_cue],
      onSaveFile: save,
      onSaveAsFile: saveAs,
      onExportFile: exportFile,
      onSaveProject: saveProject,
      onSaveProjectAs: saveProjectAs,
      onApplyCueText: edit,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('Save calls file boundary and shows success only on success',
      (tester) async {
    var writes = 0;
    await launch(tester, save: () async {
      writes++;
      return StudioDockFileResult.saved;
    });
    await tester.tap(find.byKey(const ValueKey('studio-dock-save-file')));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Subtitle file saved successfully.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A missing direct-save location opens Save As, Cancel is not saved',
      (tester) async {
    var saveAsCalls = 0;
    await launch(tester,
      save: () async => StudioDockFileResult.needsLocation,
      saveAs: () async {
        saveAsCalls++;
        return StudioDockFileResult.canceled;
      },
    );
    await tester.tap(find.byKey(const ValueKey('studio-dock-save-file')));
    await tester.pumpAndSettle();
    expect(saveAsCalls, 1);
    expect(find.text('Subtitle file saved successfully.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('File menu exposes Save As and both export text choices',
      (tester) async {
    var saveAsCalls = 0;
    final choices = <bool>[];
    await launch(tester,
      save: () async => StudioDockFileResult.saved,
      saveAs: () async {
        saveAsCalls++;
        return StudioDockFileResult.saved;
      },
      exportFile: (original) async {
        choices.add(original);
        return StudioDockFileResult.saved;
      },
    );

    Future<void> pick(String label) async {
      await tester.tap(find.byKey(const ValueKey('studio-file-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await pick('Save As…');
    expect(saveAsCalls, 1);
    await pick('Export SRT…');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(choices, isEmpty);

    await pick('Export SRT…');
    await tester.tap(find.byKey(const ValueKey('studio-export-original')));
    await tester.pumpAndSettle();
    await pick('Export SRT…');
    await tester.tap(find.byKey(const ValueKey('studio-export-edited')));
    await tester.pumpAndSettle();
    expect(choices, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scratch Edit Mode exports subtitle text without a translation choice',
      (tester) async {
    final choices = <bool>[];
    await launch(tester,
      isEditMode: true,
      save: () async => StudioDockFileResult.saved,
      exportFile: (originalOnly) async {
        choices.add(originalOnly);
        return StudioDockFileResult.saved;
      });
    await tester.tap(find.byKey(const ValueKey('studio-file-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export SRT…').last);
    await tester.pumpAndSettle();
    expect(find.text('Export subtitle file'), findsNothing);
    expect(choices, [false]);
  });

  testWidgets('Dirty inspector draft blocks Save until Apply or Discard',
      (tester) async {
    var writes = 0;
    var applied = 0;
    await launch(tester,
      save: () async { writes++; return StudioDockFileResult.saved; },
      edit: (_, value) async { applied++; return true; },
    );
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
      'Uncommitted edit');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-dock-save-file')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(applied, 0);

    await tester.tap(find.byKey(const ValueKey('studio-dock-save-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog), matching: find.text('Apply')));
    await tester.pumpAndSettle();
    expect(applied, 1);
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('While saving, a second Save is disabled', (tester) async {
    final pending = Completer<StudioDockFileResult>();
    var calls = 0;
    await launch(tester, save: () {
      calls++;
      return pending.future;
    });
    await tester.tap(find.byKey(const ValueKey('studio-dock-save-file')));
    await tester.pump();
    expect(calls, 1);
    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('studio-dock-save-file')));
    expect(button.onPressed, isNull);
    pending.complete(StudioDockFileResult.saved);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Project menu Save falls back to Save Project As',
      (tester) async {
    var directCalls = 0;
    var asCalls = 0;
    await launch(tester,
      save: () async => StudioDockFileResult.saved,
      saveProject: () async {
        directCalls++;
        return StudioDockFileResult.needsLocation;
      },
      saveProjectAs: () async {
        asCalls++;
        return StudioDockFileResult.saved;
      },
    );
    await tester.tap(find.byKey(const ValueKey('studio-file-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save project (.msone)'));
    await tester.pumpAndSettle();
    expect(directCalls, 1);
    expect(asCalls, 1);
    expect(find.text('Project and checkpoint history saved successfully.'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Project Save As cancel does not show saved feedback',
      (tester) async {
    var calls = 0;
    await launch(tester,
      save: () async => StudioDockFileResult.saved,
      saveProject: () async => StudioDockFileResult.saved,
      saveProjectAs: () async {
        calls++;
        return StudioDockFileResult.canceled;
      },
    );
    await tester.tap(find.byKey(const ValueKey('studio-file-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save project as…'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Project and checkpoint history saved successfully.'),
      findsNothing);
    expect(tester.takeException(), isNull);
  });
}
