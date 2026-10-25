import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

class _PreferencesHost extends StatefulWidget {
  const _PreferencesHost({
    required this.savedText,
    this.isEditMode = false,
    this.rejectTextSave = false,
    this.rejectPreferenceSave = false,
  });

  final List<String> savedText;
  final bool isEditMode;
  final bool rejectTextSave;
  final bool rejectPreferenceSave;

  @override
  State<_PreferencesHost> createState() => _PreferencesHostState();
}

class _PreferencesHostState extends State<_PreferencesHost> {
  bool originalLine = false;
  bool autoSave = true;
  bool originalField = true;

  Future<bool> _save(StudioDockEditPreference preference, bool value) async {
    if (widget.rejectPreferenceSave) return false;
    setState(() {
      switch (preference) {
        case StudioDockEditPreference.showOriginalLine:
          originalLine = value;
          autoSave = !value;
        case StudioDockEditPreference.autoSaveWithNavigation:
          autoSave = value;
        case StudioDockEditPreference.showOriginalTextField:
          originalField = value;
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) => StudioDockWorkspace(
    isLiveSession: true,
    isEditMode: widget.isEditMode,
    showOriginalLine: originalLine,
    autoSaveWithNavigation: autoSave,
    showOriginalTextField: originalField,
    onSaveEditPreference: _save,
    onApplyCueText: (id, text) async {
      widget.savedText.add('$id:$text');
      return !widget.rejectTextSave;
    },
    initialCues: const [
      StudioDockCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', original: '<b>Original first</b>',
          edited: 'Existing edit'),
      StudioDockCue(id: 2, start: '00:00:03,000',
          end: '00:00:04,000', original: 'Second original', edited: ''),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, List<String> saves, {
    bool isEditMode = false,
    bool rejectTextSave = false,
    bool rejectPreferenceSave = false,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: _PreferencesHost(
      savedText: saves,
      isEditMode: isEditMode,
      rejectTextSave: rejectTextSave,
      rejectPreferenceSave: rejectPreferenceSave,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> viewMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('navigation auto-saves only an actual edited draft',
      (tester) async {
    final saves = <String>[];
    await launch(tester, saves);
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Checkpointed through navigation');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsNothing);
    expect(saves, ['1:Checkpointed through navigation']);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed navigation save preserves draft and selected cue',
      (tester) async {
    final saves = <String>[];
    await launch(tester, saves, rejectTextSave: true);
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Do not lose this draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pump();
    expect(saves, ['1:Do not lose this draft']);
    expect(find.text('Do not lose this draft'), findsWidgets);
    expect(find.byKey(const ValueKey('studio-edit-1-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Show Original Line requires consent and disables auto-save',
      (tester) async {
    final saves = <String>[];
    await launch(tester, saves);
    await viewMenu(tester);
    await tester.tap(find.text('Show Original Line'));
    await tester.pumpAndSettle();
    expect(find.text('Show original line when edit is empty?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await viewMenu(tester);
    expect(find.text('Auto-save with navigation'), findsNothing);
    await tester.tap(find.text('Show Original Line'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-confirm-original-line')));
    await tester.pumpAndSettle();
    await viewMenu(tester);
    expect(find.text('Auto-save with navigation'), findsOneWidget);
    await tester.tap(find.text('Auto-save with navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pumpAndSettle();
    // Display-only original fallback must not write a replacement edit.
    expect(saves, isEmpty);
    expect(tester.widget<TextFormField>(find.byKey(
        const ValueKey('studio-edit-2-1'))).initialValue,
        'Second original');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Original field and formatted preview are optional and safe',
      (tester) async {
    await launch(tester, <String>[]);
    await viewMenu(tester);
    await tester.tap(find.text('Show Original Text Field'));
    await tester.pumpAndSettle();
    expect(find.text('ORIGINAL TEXT'), findsNothing);
    expect(find.text('Original text is hidden'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-show-original-text')));
    await tester.pumpAndSettle();
    expect(find.text('ORIGINAL TEXT'), findsOneWidget);
    expect(find.text('Original text is hidden'), findsNothing);
    await viewMenu(tester);
    await tester.tap(find.text('Formatted View'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-formatted-preview')),
        findsOneWidget);
    // The editor always remains editable even when formatted preview is on.
    expect(find.byKey(const ValueKey('studio-edit-1-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('original-line safety mode asks before navigating dirty text',
      (tester) async {
    final saves = <String>[];
    await launch(tester, saves);
    await viewMenu(tester);
    await tester.tap(find.text('Show Original Line'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-confirm-original-line')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-1')),
        'Unapplied translation');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    expect(saves, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unapplied translation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit Mode does not advertise translation-only controls',
      (tester) async {
    await launch(tester, <String>[], isEditMode: true);
    await viewMenu(tester);
    expect(find.text('Show Original Line'), findsNothing);
    expect(find.text('Auto-save with navigation'), findsNothing);
    expect(find.text('Show Original Text Field'), findsOneWidget);
    expect(find.text('Formatted View'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed preference write retains the prior display setting',
      (tester) async {
    await launch(tester, <String>[], rejectPreferenceSave: true);
    await viewMenu(tester);
    await tester.tap(find.text('Show Original Text Field'));
    await tester.pump();
    expect(find.text('ORIGINAL TEXT'), findsOneWidget);
    expect(find.textContaining('Could not save the Edit Line preference'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
