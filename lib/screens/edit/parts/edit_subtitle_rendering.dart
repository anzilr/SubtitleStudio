part of '../../screen_edit.dart';

extension _EditSubtitleRendering on _EditScreenState {
  /// Update subtitles and increment version to trigger VideoPlayerSection rebuild
  /// This helper ensures consistent version tracking across all subtitle updates
  void _updateSubtitlesWithVersion(List<SubtitleLine> subtitleLines) {
    _subtitleVersion++;

    // Update waveform if it exists
    if (_waveformKey.currentState != null) {
      _waveformKey.currentState!.updateSubtitles(subtitleLines);
    }
  }

}