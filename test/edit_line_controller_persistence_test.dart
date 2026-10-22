import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String original, String? edited, String start,
    String end) =>
    SubtitleLine()
      ..index = index
      ..original = original
      ..edited = edited
      ..startTime = start
      ..endTime = end
      ..marked = index == 1
      ..comment = index == 1 ? 'Check this cue' : null
      ..resolved = false;

Future<({int collectionId, int sessionId})> _seed(TestIsarHarness harness) async {
  final collection = SubtitleCollection(
    fileName: 'controller-test.srt',
    encoding: 'UTF-8',
    lines: [
      _line(1, 'First', 'Initial', '00:00:01,000', '00:00:01,900'),
      _line(2, 'Second', null, '00:00:02,000', '00:00:02,900'),
    ],
  );
  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(collection);
  });
  final session = Session(
    fileName: 'controller-test.srt',
    subtitleCollectionId: collectionId,
  );
  late int sessionId;
  await harness.isar.writeTxn(() async {
    sessionId = await harness.isar.sessions.put(session);
  });
  return (collectionId: collectionId, sessionId: sessionId);
}

class _DelayedRepository extends EditLineRepository {
  _DelayedRepository(super.isar, super.preferences);

  Completer<void>? blockedRead;

  @override
  Future<SubtitleCollection?> fetchSubtitleCollection(int id) async {
    final blocker = blockedRead;
    if (blocker != null) await blocker.future;
    return super.fetchSubtitleCollection(id);
  }
}

void main() {
  late TestIsarHarness harness;
  late EditLineRepository repository;
  late ProviderContainer providers;
  late ({int collectionId, int sessionId}) ids;

  Future<EditLineController> createController({
    bool newCue = false,
    bool editMode = false,
  }) async {
    providers = ProviderContainer(
      overrides: [
        editLineConfigurationProvider.overrideWithValue(
          EditLineConfiguration(
            subtitleCollectionId: ids.collectionId,
            lineIndex: 1,
            sessionId: ids.sessionId,
            isNewSubtitle: newCue,
            isEditMode: editMode,
          ),
        ),
        editLineRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final controller = providers.read(editLineControllerProvider.notifier);
    await controller.initialize();
    expect(providers.read(editLineControllerProvider).isInitialized, isTrue);
    return controller;
  }

  setUp(() async {
    harness = await TestIsarHarness.open();
    ids = await _seed(harness);
    repository = EditLineRepository(
      harness.isar,
      EditLinePreferencesRepository(harness.isar),
    );
  });

  tearDown(() async {
    providers.dispose();
    await harness.close();
  });

  test('direct controller save preserves blank edit and post-sort selection',
      () async {
    final controller = await createController();
    final before = providers.read(editLineControllerProvider);
    controller.updateEditedText('');
    await controller.updateStartTime('00:00:03,000');
    await controller.updateEndTime('00:00:03,900');

    expect(await controller.saveSubtitle(), isTrue);

    final after = providers.read(editLineControllerProvider);
    expect(after.subtitleLine!.index, 2);
    expect(after.subtitleLine!.original, 'First');
    expect(after.subtitleLine!.edited, '');
    expect(after.subtitleLine!.comment, 'Check this cue');
    expect(after.editedText, '');
    expect(after.hasUnsavedChanges, isFalse);
    expect(after.subtitleCollection!.lines.map((l) => l.original),
        ['Second', 'First']);
    expect(before.subtitleCollection!.lines.map((l) => l.original),
        ['First', 'Second']);
    final persisted = await repository.fetchSubtitleCollection(ids.collectionId);
    expect(persisted!.lines.last.original, 'First');
    expect(persisted.lines.last.edited, '');
    expect(persisted.lines.last.index, 2);
  });

  test('direct Save refuses invalid time without changing database',
      () async {
    final controller = await createController();
    await controller.updateStartTime('not-a-time');
    expect(await controller.saveSubtitle(), isFalse);
    final after = providers.read(editLineControllerProvider);
    expect(after.startTimeError, isNotNull);
    expect(after.hasUnsavedChanges, isTrue);
    final persisted = await repository.fetchSubtitleCollection(ids.collectionId);
    expect(persisted!.lines.first.startTime, '00:00:01,000');
  });

  test('controller navigation protects drafts then updates complete state',
      () async {
    final controller = await createController();
    controller.updateEditedText('Unsaved edits');
    await controller.navigateToLine(2);

    var state = providers.read(editLineControllerProvider);
    expect(state.subtitleLine!.index, 1);
    expect(state.editedText, 'Unsaved edits');
    expect(state.hasUnsavedChanges, isTrue);
    expect(state.errorMessage, contains('Save or discard'));

    controller.updateEditedText('Initial');
    await controller.navigateToLine(2);
    state = providers.read(editLineControllerProvider);
    expect(state.subtitleLine!.index, 2);
    expect(state.subtitleLine!.original, 'Second');
    expect(state.hasUnsavedChanges, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.subtitleCollection!.lines, hasLength(2));

    await controller.navigateNext();
    expect(providers.read(editLineControllerProvider).subtitleLine!.index, 2);
    await controller.navigatePrevious();
    expect(providers.read(editLineControllerProvider).subtitleLine!.index, 1);
  });

  test('controller navigation reads new Isar order after external reorder',
      () async {
    final controller = await createController();
    final before = providers.read(editLineControllerProvider);
    final moved = _line(
      1, 'First', 'Initial', '00:00:04,000', '00:00:04,900',
    );
    final saved = await repository.saveSubtitleLineChangesResolved(
      collectionId: ids.collectionId,
      updatedLine: moved,
      sessionId: ids.sessionId,
    );
    expect(saved, isNotNull);
    await controller.navigateToLine(1);
    final after = providers.read(editLineControllerProvider);
    expect(after.subtitleLine!.original, 'Second');
    expect(after.subtitleCollection!.lines.map((l) => l.original),
        ['Second', 'First']);
    expect(before.subtitleCollection!.lines.map((l) => l.original),
        ['First', 'Second']);
  });

  test('late controller read cannot overwrite a newer selected cue',
      () async {
    repository = _DelayedRepository(
      harness.isar,
      EditLinePreferencesRepository(harness.isar),
    );
    final controller = await createController();
    final initial = providers.read(editLineControllerProvider);
    final delayed = repository as _DelayedRepository;
    delayed.blockedRead = Completer<void>();
    final stale = controller.navigateToLine(2);
    // Complete a more recent route selection while the direct controller read
    // is pending. Its epoch must invalidate the earlier navigation.
    controller.synchronizeLoadedCue(
      collection: initial.subtitleCollection!,
      line: initial.subtitleCollection!.lines.first,
      visibleEditedText: 'Initial',
    );
    delayed.blockedRead!.complete();
    await stale;
    final after = providers.read(editLineControllerProvider);
    expect(after.subtitleLine!.index, 1);
    expect(after.isLoading, isFalse);
  });

  test('new cue direct Save inserts once and clears new-subtitle state',
      () async {
    final controller = await createController(newCue: true, editMode: true);
    expect(providers.read(editLineControllerProvider).subtitleLine, isNull);
    controller.updateOriginalText('New source');
    controller.updateEditedText('');
    await controller.updateStartTime('00:00:03,500');
    await controller.updateEndTime('00:00:04,000');
    expect(await controller.saveSubtitle(), isTrue);
    var current = providers.read(editLineControllerProvider);
    expect(current.subtitleLine!.original, 'New source');
    expect(current.subtitleLine!.edited, '');
    expect(current.subtitleCollection!.lines, hasLength(3));
    expect(current.isNewSubtitle, isFalse);
    expect(await controller.saveSubtitle(), isTrue);
    current = providers.read(editLineControllerProvider);
    expect(current.subtitleCollection!.lines, hasLength(3));
  });
}
