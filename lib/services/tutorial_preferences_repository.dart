import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Isar-backed tutorial completion persistence.
///
/// TutorialStatus is unique by screen name. Creation and mutation are kept in
/// one write transaction so first-run updates cannot create nested Isar
/// transactions or duplicate rows.
class TutorialPreferencesRepository {
  final Isar _isar;

  const TutorialPreferencesRepository(this._isar);

  Future<TutorialStatus> _getOrCreate(String screenName) async {
    final existing = await _isar.tutorialStatus
        .filter()
        .screenNameEqualTo(screenName)
        .findFirst();
    if (existing != null) return existing;

    late TutorialStatus status;
    await _isar.writeTxn(() async {
      status = await _isar.tutorialStatus
              .filter()
              .screenNameEqualTo(screenName)
              .findFirst() ??
          TutorialStatus(screenName: screenName);

      if (status.id == Isar.autoIncrement) {
        await _isar.tutorialStatus.put(status);
      }
    });
    return status;
  }

  Future<bool> hasSeen(String screenName) async {
    return (await _getOrCreate(screenName)).hasSeenTutorial;
  }

  Future<void> setHasSeen(String screenName, bool value) async {
    await _isar.writeTxn(() async {
      final status = await _isar.tutorialStatus
              .filter()
              .screenNameEqualTo(screenName)
              .findFirst() ??
          TutorialStatus(screenName: screenName);

      status.hasSeenTutorial = value;
      await _isar.tutorialStatus.put(status);
    });
  }
}
