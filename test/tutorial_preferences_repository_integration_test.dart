import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/tutorial_preferences_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  late TestIsarHarness harness;
  bool harnessOpened = false;
  late TutorialPreferencesRepository repository;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = TutorialPreferencesRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('TutorialPreferencesRepository', () {
    test('creates unseen status on first read', () async {
      expect(await repository.hasSeen('home'), isFalse);

      final rows = await harness.isar.tutorialStatus.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.screenName, 'home');
      expect(rows.single.hasSeenTutorial, isFalse);
    });

    test('first write creates and updates without nested transaction', () async {
      await repository.setHasSeen('editor', true);

      expect(await repository.hasSeen('editor'), isTrue);

      final rows = await harness.isar.tutorialStatus
          .filter()
          .screenNameEqualTo('editor')
          .findAll();
      expect(rows, hasLength(1));
      expect(rows.single.hasSeenTutorial, isTrue);
    });

    test('concurrent first reads keep one row per screen', () async {
      final results = await Future.wait(
        List.generate(20, (_) => repository.hasSeen('waveform')),
      );

      expect(results.every((value) => value == false), isTrue);

      final rows = await harness.isar.tutorialStatus
          .filter()
          .screenNameEqualTo('waveform')
          .findAll();
      expect(rows, hasLength(1));
    });
  });
}
