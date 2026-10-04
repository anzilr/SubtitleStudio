import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Low-level persistence boundary for [VideoPreferences].
///
/// [VideoPreferences.subtitleCollectionId] is unique. Performing lookup,
/// creation, mutation, and put within a single write transaction avoids races
/// between independently injected feature repositories.
class VideoPreferencesStore {
  final Isar _isar;

  const VideoPreferencesStore(this._isar);

  Future<VideoPreferences> getOrCreate(int subtitleCollectionId) async {
    final existing = await _isar.videoPreferences
        .filter()
        .subtitleCollectionIdEqualTo(subtitleCollectionId)
        .findFirst();
    if (existing != null) return existing;

    late VideoPreferences preferences;
    await _isar.writeTxn(() async {
      preferences = await _isar.videoPreferences
              .filter()
              .subtitleCollectionIdEqualTo(subtitleCollectionId)
              .findFirst() ??
          VideoPreferences(subtitleCollectionId: subtitleCollectionId);

      if (preferences.id == Isar.autoIncrement) {
        await _isar.videoPreferences.put(preferences);
      }
    });

    return preferences;
  }

  Future<void> update(
    int subtitleCollectionId,
    void Function(VideoPreferences preferences) update,
  ) async {
    await _isar.writeTxn(() async {
      final preferences = await _isar.videoPreferences
              .filter()
              .subtitleCollectionIdEqualTo(subtitleCollectionId)
              .findFirst() ??
          VideoPreferences(subtitleCollectionId: subtitleCollectionId);

      update(preferences);
      await _isar.videoPreferences.put(preferences);
    });
  }
}
