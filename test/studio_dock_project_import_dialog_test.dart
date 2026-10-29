import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_project_actions.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_project_import_dialog.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';

ProjectDocument _document() => ProjectDocument.create(
  version: '2.0',
  session: ProjectSessionData.create(
    fileName: 'imported.srt', lastEditedIndex: 1,
    editMode: true, projectFilePath: null,
  ),
  subtitleCollection: ProjectSubtitleCollectionData.create(
    fileName: 'imported.srt', filePath: '/old/computer/imported.srt',
    originalFileUri: '/old/computer/imported.srt', encoding: 'UTF-8',
    lines: [ProjectSubtitleLineData.create(
      index: 1, startTime: '00:00:01,000', endTime: '00:00:02,000',
      original: 'Hello', edited: null, marked: false,
      comment: null, resolved: false,
    )],
  ),
  checkpoints: const [],
  metadata: ProjectMetadataData.create(
    totalLines: 1, editedLines: 0, markedLines: 0,
    lastSaved: '2026-10-27T10:00:00Z',
  ),
);

void main() {
  Future<void> openDialog(WidgetTester tester, {
    required List<StudioDockProjectImportTarget> targets,
    bool archiveAvailable = false,
    Map<int, bool> existingAvailability = const {},
    Future<String?> Function(BuildContext)? pickSrtFile,
    required void Function(StudioDockProjectImportPlan?) onChoice,
  }) async {
    tester.view.physicalSize = const Size(950, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => Center(
        child: FilledButton(
          onPressed: () async {
            onChoice(await showDialog<StudioDockProjectImportPlan>(
              context: context,
              builder: (_) => StudioDockProjectImportDialog(
                document: _document(), targets: targets,
                archiveSrtAvailable: archiveAvailable,
                existingSrtAvailability: existingAvailability,
                pickSrtFile: pickSrtFile,
              ),
            ));
          },
          child: const Text('Open preview'),
        ),
      ))),
    ));
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
  }

  testWidgets('missing archive path is not selectable; new import is unlinked',
      (tester) async {
    StudioDockProjectImportPlan? selected;
    await openDialog(tester, targets: const [],
      onChoice: (choice) => selected = choice);
    expect(find.text('Import SubtitleStudio project'), findsOneWidget);
    expect(find.text('1 subtitle lines · 0 history points'), findsOneWidget);
    final archiveTile = tester.widget<ListTile>(find.byKey(
      const ValueKey('studio-dock-msone-source-archive')));
    expect(archiveTile.enabled, isFalse);
    expect(tester.widget<ChoiceChip>(find.byKey(
      const ValueKey('studio-dock-msone-replace'))).onSelected, isNull);
    await tester.ensureVisible(find.byKey(
      const ValueKey('studio-dock-msone-confirm')));
    await tester.tap(find.byKey(const ValueKey('studio-dock-msone-confirm')));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(selected!.replaceSessionId, isNull);
    expect(selected!.source, StudioDockProjectSrtSource.unlinked);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement destination and existing SRT are explicit',
      (tester) async {
    StudioDockProjectImportPlan? selected;
    final existing = Session(fileName: 'work.srt', subtitleCollectionId: 9)
      ..id = 7;
    await openDialog(tester,
      targets: [StudioDockProjectImportTarget(
        session: existing, srtPath: '/projects/work.srt')],
      existingAvailability: const {7: true},
      onChoice: (choice) => selected = choice);
    await tester.tap(find.byKey(const ValueKey('studio-dock-msone-replace')));
    await tester.pumpAndSettle();
    expect(find.text('Project to replace'), findsOneWidget);
    await tester.ensureVisible(find.byKey(
      const ValueKey('studio-dock-msone-source-existingSession')));
    await tester.tap(find.byKey(
      const ValueKey('studio-dock-msone-source-existingSession')));
    await tester.ensureVisible(find.byKey(
      const ValueKey('studio-dock-msone-confirm')));
    await tester.tap(find.byKey(const ValueKey('studio-dock-msone-confirm')));
    await tester.pumpAndSettle();
    expect(selected!.replaceSessionId, 7);
    expect(selected!.source, StudioDockProjectSrtSource.existingSession);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browsing a local SRT associates that path', (tester) async {
    final directory = await Directory.systemTemp.createTemp('msone-preview-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/new-source.srt');
    await source.writeAsString('1\n00:00:01,000 --> 00:00:02,000\nHello\n');
    StudioDockProjectImportPlan? selected;
    await openDialog(tester, targets: const [],
      pickSrtFile: (_) async => source.path,
      onChoice: (choice) => selected = choice);
    await tester.ensureVisible(find.byKey(
      const ValueKey('studio-dock-msone-browse')));
    await tester.tap(find.byKey(const ValueKey('studio-dock-msone-browse')));
    await tester.pumpAndSettle();
    expect(find.text(source.path), findsOneWidget);
    await tester.ensureVisible(find.byKey(
      const ValueKey('studio-dock-msone-confirm')));
    await tester.tap(find.byKey(const ValueKey('studio-dock-msone-confirm')));
    await tester.pumpAndSettle();
    expect(selected!.source, StudioDockProjectSrtSource.locatedFile);
    expect(selected!.locatedSrtPath, source.path);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel closes preflight without a selected import',
      (tester) async {
    StudioDockProjectImportPlan? selected;
    var called = false;
    await openDialog(tester, targets: const [], onChoice: (choice) {
      called = true;
      selected = choice;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });
}
