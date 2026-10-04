import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/database/stores/video_preferences_store.dart';

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
  final PreferencesStore _preferencesStore;
  final VideoPreferencesStore _videoPreferencesStore;

  VideoPlayerPreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar),
        _videoPreferencesStore = VideoPreferencesStore(isar);

  Future<Preferences> _getPreferences() {
    return _preferencesStore.getOrCreate();
  }

  Future<void> _updatePreferences(
    void Function(Preferences preferences) update,
  ) {
    return _preferencesStore.update(update);
  }

  Future<VideoPreferences> _getVideoPreferences(
    int subtitleCollectionId,
  ) {
    return _videoPreferencesStore.getOrCreate(subtitleCollectionId);
  }

  Future<void> _updateVideoPreferences(
    int subtitleCollectionId,
    void Function(VideoPreferences preferences) update,
  ) {
    return _videoPreferencesStore.update(subtitleCollectionId, update);
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
