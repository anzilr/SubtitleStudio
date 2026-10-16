import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness harness;
  late ProjectRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = ProjectRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  test('round-trips project path and renamed session file name', () async {
    final session = Session(
      fileName: 'original.srt',
      subtitleCollectionId: 42,
    );

    late int sessionId;
    await harness.isar.writeTxn(() async {
      sessionId = await harness.isar.sessions.put(session);
    });

    expect(await repository.getProjectFilePath(sessionId), isNull);

    await repository.updateSessionProjectPath(
      sessionId: sessionId,
      projectFilePath: '/projects/example.msone',
    );
    await repository.updateSessionFileName(
      sessionId: sessionId,
      fileName: 'renamed.srt',
    );

    final stored = await repository.getSession(sessionId);
    expect(stored, isNotNull);
    expect(stored!.projectFilePath, '/projects/example.msone');
    expect(stored.fileName, 'renamed.srt');
  });

  test('updating a missing session fails explicitly', () async {
    expect(
      () => repository.updateSessionProjectPath(
        sessionId: 999999,
        projectFilePath: '/missing.msone',
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      () => repository.updateSessionFileName(
        sessionId: 999999,
        fileName: 'missing.srt',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
