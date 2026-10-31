import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_create_project_dialog.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('studio_new_project_');
  });
  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<ValueNotifier<StudioDockCreateProjectChoice?>> launch(
    WidgetTester tester, {
    Future<String?> Function(String extension, String name)? pickLocation,
  }) async {
    tester.view.physicalSize = const Size(1120, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = ValueNotifier<StudioDockCreateProjectChoice?>(null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result.value = await showDialog<StudioDockCreateProjectChoice>(
            context: context,
            builder: (_) => StudioDockCreateProjectDialog(
              pickLocation: pickLocation,
            ),
          );
        },
        child: const Text('New project'),
      ),
    ))));
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('cancel and empty names cannot create a project', (tester) async {
    final result = await launch(tester);
    expect(find.text('Create subtitle project'), findsOneWidget);
    final create = find.byKey(const ValueKey('studio-dock-new-project-confirm'));
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    await tester.enterText(
        find.byKey(const ValueKey('studio-dock-new-project-name')), '../bad');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('studio-dock-new-project-cancel')));
    await tester.pumpAndSettle();
    expect(result.value, isNull);
    expect(directory.listSync(), isEmpty);
  });

  testWidgets('invalid Windows project names keep Create disabled',
      (tester) async {
    await launch(tester);
    final nameField =
        find.byKey(const ValueKey('studio-dock-new-project-name'));
    final create =
        find.byKey(const ValueKey('studio-dock-new-project-confirm'));
    for (final name in ['.srt', 'CON.srt', 'LPT1.srt']) {
      await tester.enterText(nameField, name);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(create).onPressed, isNull,
          reason: name);
    }
    await tester.enterText(nameField, 'Conversation');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('studio-dock-new-project-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('new unsaved Edit Mode project has a configurable encoding',
      (tester) async {
    final result = await launch(tester);
    await tester.enterText(
        find.byKey(const ValueKey('studio-dock-new-project-name')),
        'Episode 12');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-dock-new-project-encoding')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Windows-1252').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-dock-new-project-confirm')));
    await tester.pumpAndSettle();
    expect(result.value?.name, 'Episode 12');
    expect(result.value?.encoding, 'Windows-1252');
    expect(result.value?.saveFilesNow, isFalse);
    expect(result.value?.srtPath, isNull);
    expect(result.value?.projectPath, isNull);
    expect(directory.listSync(), isEmpty);
  });

  testWidgets('save-now requires both distinct file destinations before Create',
      (tester) async {
    final srtPath = '${directory.path}${Platform.pathSeparator}Episode.srt';
    final projectPath =
        '${directory.path}${Platform.pathSeparator}Episode.msone';
    final requests = <String>[];
    final result = await launch(tester, pickLocation: (extension, suggested) async {
      requests.add('$extension:$suggested');
      return extension == 'srt' ? srtPath : projectPath;
    });
    await tester.enterText(
        find.byKey(const ValueKey('studio-dock-new-project-name')), 'Episode');
    await tester.ensureVisible(find.byKey(
        const ValueKey('studio-dock-new-project-save-now')));
    await tester.tap(find.byKey(
        const ValueKey('studio-dock-new-project-save-now')));
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey('studio-dock-new-project-confirm'));
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    await tester.ensureVisible(find.byKey(
        const ValueKey('studio-dock-new-project-select-srt')));
    await tester.tap(find.byKey(
        const ValueKey('studio-dock-new-project-select-srt')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    await tester.ensureVisible(find.byKey(
        const ValueKey('studio-dock-new-project-select-msone')));
    await tester.tap(find.byKey(
        const ValueKey('studio-dock-new-project-select-msone')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(requests, ['srt:Episode.srt', 'msone:Episode.msone']);
    expect(result.value?.encoding, 'UTF-8');
    expect(result.value?.saveFilesNow, isTrue);
    expect(result.value?.srtPath, srtPath);
    expect(result.value?.projectPath, projectPath);
    expect(File(srtPath).existsSync(), isFalse);
    expect(File(projectPath).existsSync(), isFalse);
  });

  testWidgets('canceled native destination selection keeps creation pending',
      (tester) async {
    final result = await launch(tester,
        pickLocation: (extension, name) async => null);
    await tester.enterText(
        find.byKey(const ValueKey('studio-dock-new-project-name')), 'Draft');
    await tester.tap(find.byKey(
        const ValueKey('studio-dock-new-project-save-now')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-dock-new-project-select-srt')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(
        const ValueKey('studio-dock-new-project-confirm'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('studio-dock-new-project-cancel')));
    await tester.pumpAndSettle();
    expect(result.value, isNull);
    expect(directory.listSync(), isEmpty);
  });

  test('desktop destination selection never creates or replaces a file',
      () async {
    final selectedFile = File(
        '${directory.path}${Platform.pathSeparator}Existing.srt')
      ..writeAsStringSync('original subtitle');
    final selected = await FilePickerSAF.pickDesktopSaveLocation(
      fileName: 'Existing.srt',
      extension: 'srt',
      pickPath: () async => selectedFile.path,
    );
    expect(selected, selectedFile.path);
    expect(selectedFile.readAsStringSync(), 'original subtitle');

    final newPath = '${directory.path}${Platform.pathSeparator}New.msone';
    expect(
      await FilePickerSAF.pickDesktopSaveLocation(
        fileName: 'New.msone',
        extension: '.msone',
        pickPath: () async => newPath,
      ),
      newPath,
    );
    expect(File(newPath).existsSync(), isFalse);
  });

  test('desktop destination selection rejects mismatched or relative paths',
      () async {
    await expectLater(
      FilePickerSAF.pickDesktopSaveLocation(
        fileName: 'Episode.srt',
        extension: 'srt',
        pickPath: () async => 'relative.srt',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      FilePickerSAF.pickDesktopSaveLocation(
        fileName: 'Episode.srt',
        extension: 'srt',
        pickPath: () async => '${directory.path}/Episode.txt',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      FilePickerSAF.pickDesktopSaveLocation(
        fileName: 'Episode.srt',
        extension: 'msone',
        pickPath: () async => 'ignored',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      await FilePickerSAF.pickDesktopSaveLocation(
        fileName: 'Episode.srt',
        extension: 'srt',
        pickPath: () async => null,
      ),
      isNull,
    );
  });
}
