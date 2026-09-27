import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';

class VideoPlayerStoredPreferences {
  final double subtitleFontSize;
  final String? subtitleFontPath;
  final int skipDurationSeconds;
  final double primarySubtitleVerticalPosition;
  final double secondarySubtitleVerticalPosition;
  final double videoVolume;
  final bool showSubtitleBackground;

  const VideoPlayerStoredPreferences({
    required this.subtitleFontSize,
    required this.subtitleFontPath,
    required this.skipDurationSeconds,
    required this.primarySubtitleVerticalPosition,
    required this.secondarySubtitleVerticalPosition,
    required this.videoVolume,
    required this.showSubtitleBackground,
  });
}

class SavedAudioTrack {
  final String? id;
  final String? title;
  final String? language;

  const SavedAudioTrack({
    this.id,
    this.title,
    this.language,
  });
}

/// Isar-backed persistence used by VideoPlayerWidget.
class VideoPlayerPreferencesRepository {
  final Isar _isar;

  const VideoPlayerPreferencesRepository(this._isar);

  Future<Preferences> _getPreferences() async {
    final existing = await _isar.preferences.where().findFirst();
    if (existing != null) return existing;

    final created = Preferences(autoSave: true);
    await _isar.writeTxn(() async {
      await _isar.preferences.put(created);
    });
    return created;
  }

  Future<void> _updatePreferences(
    void Function(Preferences preferences) update,
  ) async {
    final existing = await _isar.preferences.where().findFirst();
    final preferences = existing ?? Preferences(autoSave: true);
    update(preferences);

    await _isar.writeTxn(() async {
      await _isar.preferences.put(preferences);
    });
  }

  Future<VideoPreferences> _getVideoPreferences(
    int subtitleCollectionId,
  ) async {
    final existing = await _isar.videoPreferences
        .filter()
        .subtitleCollectionIdEqualTo(subtitleCollectionId)
        .findFirst();

    if (existing != null) return existing;

    final created = VideoPreferences(
      subtitleCollectionId: subtitleCollectionId,
    );
    await _isar.writeTxn(() async {
      await _isar.videoPreferences.put(created);
    });
    return created;
  }

  Future<void> _updateVideoPreferences(
    int subtitleCollectionId,
    void Function(VideoPreferences preferences) update,
  ) async {
    final existing = await _isar.videoPreferences
        .filter()
        .subtitleCollectionIdEqualTo(subtitleCollectionId)
        .findFirst();
    final preferences = existing ??
        VideoPreferences(subtitleCollectionId: subtitleCollectionId);
    update(preferences);

    await _isar.writeTxn(() async {
      await _isar.videoPreferences.put(preferences);
    });
  }

  Future<VideoPlayerStoredPreferences> loadPlayerPreferences() async {
    final preferences = await _getPreferences();

    return VideoPlayerStoredPreferences(
      subtitleFontSize: preferences.subtitleFontSize,
      subtitleFontPath: preferences.subtitleFontPath,
      skipDurationSeconds: preferences.skipDurationSeconds,
      primarySubtitleVerticalPosition:
          preferences.primarySubtitleVerticalPosition,
      secondarySubtitleVerticalPosition:
          preferences.secondarySubtitleVerticalPosition,
      videoVolume: preferences.videoVolume,
      showSubtitleBackground: preferences.showSubtitleBackground,
    );
  }

  Future<String?> getSubtitleFontPath() async {
    return (await _getPreferences()).subtitleFontPath;
  }

  Future<void> setSubtitleFontPath(String? path) =>
      _updatePreferences((p) => p.subtitleFontPath = path);

  Future<void> setSubtitleFontSize(double size) =>
      _updatePreferences((p) => p.subtitleFontSize = size);

  Future<void> setVideoVolume(double volume) =>
      _updatePreferences((p) => p.videoVolume = volume);

  Future<void> setShowSubtitleBackground(bool value) =>
      _updatePreferences((p) => p.showSubtitleBackground = value);

  Future<void> setPrimarySubtitleVerticalPosition(double position) =>
      _updatePreferences(
        (p) => p.primarySubtitleVerticalPosition = position,
      );

  Future<void> setSecondarySubtitleVerticalPosition(double position) =>
      _updatePreferences(
        (p) => p.secondarySubtitleVerticalPosition = position,
      );

  Future<SavedAudioTrack> getSelectedAudioTrack(
    int subtitleCollectionId,
  ) async {
    final preferences = await _getVideoPreferences(subtitleCollectionId);
    return SavedAudioTrack(
      id: preferences.selectedAudioTrackId,
      title: preferences.selectedAudioTrackTitle,
      language: preferences.selectedAudioTrackLanguage,
    );
  }

  Future<void> saveSelectedAudioTrack(
    int subtitleCollectionId, {
    required String trackId,
    String? trackTitle,
    String? trackLanguage,
  }) async {
    await _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.selectedAudioTrackId = trackId;
      preferences.selectedAudioTrackTitle = trackTitle;
      preferences.selectedAudioTrackLanguage = trackLanguage;
    });
  }

  Future<void> clearSelectedAudioTrack(int subtitleCollectionId) async {
    await _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.selectedAudioTrackId = null;
      preferences.selectedAudioTrackTitle = null;
      preferences.selectedAudioTrackLanguage = null;
    });
  }
}

final videoPlayerPreferencesRepositoryProvider =
    Provider<VideoPlayerPreferencesRepository>((ref) {
  return VideoPlayerPreferencesRepository(ref.watch(isarProvider));
});
