import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_builder.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line({
  required int index,
  required String original,
  String? edited,
  bool marked = false,
  String? comment,
  bool resolved = false,
}) =>
    SubtitleLine()
      ..index = index
      ..startTime = '00:00:0$index,000'
      ..endTime = '00:00:0$index,900'
      ..original = original
      ..edited = edited
      ..marked = marked
      ..comment = comment
      ..resolved = resolved;

void main() {
  late TestIsarHarness harness;

  setUp(() async {
    harness = await TestIsarHarness.open();
  });

  tearDown(() async {
    await harness.close();
  });

  test('serialized .msone preserves blank cues and detached named refs',
      () async {
    const sourceSessionId = 55;
    const sourceCollectionId = 77;
    final lines = [
      _line(index: 1, original: '', edited: '', marked: true,
          comment: 'Intentional empty cue', resolved: false),
      _line(index: 2, original: 'മലയാളം', edited: 'മലയാളം\nSecond line',
          comment: 'Review', resolved: true),
    ];
    final session = Session(
      fileName: 'portable.srt',
      subtitleCollectionId: sourceCollectionId,
      lastEditedIndex: 2,
      editMode: true,
    )..id = sourceSessionId;
    final collection = SubtitleCollection(
      fileName: 'portable.srt',
      filePath: '/source/portable.srt',
      originalFileUri: 'content://source.example/document/portable',
      encoding: 'UTF-16LE BOM',
      lines: lines,
    )..id = sourceCollectionId;
    Checkpoint snapshot(int id, {int? parent, required bool active}) =>
        Checkpoint(
          sessionId: sourceSessionId,
          subtitleCollectionId: sourceCollectionId,
          timestamp: DateTime.utc(2026, 10, 23, id == 101 ? 9 : 10),
          operationType: 'snapshot',
          description: id == 101 ? 'Initial' : 'Reviewed',
          parentCheckpointId: parent,
          isActive: active,
          checkpointType: 'snapshot',
          deltas: const [],
          snapshot: lines,
        )..id = id;
    final checkpoints = [
      snapshot(101, active: false),
      snapshot(102, parent: 101, active: true),
    ];
    final now = DateTime.utc(2026, 10, 23);
    HistoryRef reference(String name, String kind, int target) => HistoryRef(
          sessionId: sourceSessionId,
          subtitleCollectionId: sourceCollectionId,
          name: name,
          kind: kind,
          targetCheckpointId: target,
          // An explicit null HEAD attachment means detached history.
          symbolicBranchName: null,
          createdAt: now,
          updatedAt: now,
        );
    final exported = ProjectDocumentBuilder.build(
      session: session,
      subtitleCollection: collection,
      checkpoints: checkpoints,
      persistentReferences: [
        reference('HEAD', 'head', 102),
        reference('refs/heads/main', 'branch', 101),
        reference('refs/heads/review', 'branch', 101),
        reference('refs/bookmarks/approved', 'bookmark', 102),
      ],
      projectVersion: '2.0',
      appVersion: '3.0.0',
      now: now,
    );

    final archive = ProjectDocumentCodec.decode(
      ProjectDocumentCodec.encode(exported),
    );
    expect(archive.historyReferences!.entries.first.attachmentSpecified,
        isTrue);
    expect(archive.historyReferences!.entries.first.symbolicBranchName,
        isNull);

    final imported = await SessionProjectImportRepository(harness.isar)
        .importAsNewSession(
          projectDocument: archive,
          srtFileInfo: const {'useImportingFile': 'true'},
          originalProjectUri: '/destination/portable.msone',
        );
    final storedSession = (await harness.isar.sessions.get(imported.id))!;
    final stored = (await harness.isar.subtitleCollections
        .get(storedSession.subtitleCollectionId))!;
    expect(storedSession.projectFilePath, '/destination/portable.msone');
    expect(storedSession.lastEditedIndex, 2);
    expect(stored.encoding, 'UTF-16LE BOM');
    expect(stored.originalFileUri,
        'content://source.example/document/portable');
    expect(stored.lines, hasLength(2));
    expect(stored.lines.first.original, '');
    expect(stored.lines.first.edited, '');
    expect(stored.lines.first.marked, isTrue);
    expect(stored.lines.first.comment, 'Intentional empty cue');
    expect(stored.lines.last.original, 'മലയാളം');
    expect(stored.lines.last.edited, 'മലയാളം\nSecond line');
    expect(stored.lines.last.resolved, isTrue);

    final savedHistory = await harness.isar.checkpoints.filter()
        .sessionIdEqualTo(imported.id).findAll();
    expect(savedHistory, hasLength(2));
    final root = savedHistory.singleWhere((cp) => cp.description == 'Initial');
    final reviewed = savedHistory.singleWhere(
      (cp) => cp.description == 'Reviewed',
    );
    expect(reviewed.parentCheckpointId, root.id);
    expect(reviewed.isActive, isTrue);

    final refs = await harness.isar.historyRefs.filter()
        .sessionIdEqualTo(imported.id).findAll();
    final byName = {for (final ref in refs) ref.name: ref};
    expect(byName.keys.toSet(), {
      'HEAD', 'refs/heads/main', 'refs/heads/review',
      'refs/bookmarks/approved',
    });
    expect(byName['HEAD']!.targetCheckpointId, reviewed.id);
    expect(byName['HEAD']!.symbolicBranchName, isNull);
    expect(byName['refs/heads/main']!.targetCheckpointId, root.id);
    expect(byName['refs/heads/review']!.targetCheckpointId, root.id);
    expect(byName['refs/bookmarks/approved']!.targetCheckpointId, reviewed.id);
  });

  test('legacy .msone without history refs retains blank lines on import',
      () async {
    final legacy = ProjectDocumentCodec.decode('''
      {
        "version": "1.0",
        "session": {"fileName": "old.srt", "editMode": true},
        "subtitleCollection": {
          "fileName": "old.srt",
          "encoding": "UTF-8 BOM",
          "lines": [
            {"index": 1, "startTime": "00:00:01,000",
             "endTime": "00:00:01,900", "original": "", "edited": ""},
            {"index": 2, "startTime": "00:00:02,000",
             "endTime": "00:00:02,900", "original": "Text", "edited": null}
          ]
        }
      }
    ''');
    expect(legacy.historyReferences, isNull);
    final session = await SessionProjectImportRepository(harness.isar)
        .importAsNewSession(
          projectDocument: legacy,
          srtFileInfo: const {'useImportingFile': 'true'},
          originalProjectUri: '/projects/old.msone',
        );
    final collection = (await harness.isar.subtitleCollections
        .get(session.subtitleCollectionId))!;
    expect(collection.encoding, 'UTF-8 BOM');
    expect(collection.lines.map((line) => line.original), ['', 'Text']);
    expect(collection.lines.first.edited, '');
    expect(await harness.isar.checkpoints.count(), 0);
    expect(await harness.isar.historyRefs.count(), 0);
  });
}
