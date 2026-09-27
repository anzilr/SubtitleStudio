part of '../../screen_edit.dart';

extension _EditSubtitleRendering on _EditScreenState {
  List<Subtitle> _generateSubtitles(List<SubtitleLine> subtitleLines) {
    return subtitleLines.asMap().entries.map((entry) {
      final index = entry.key; // Use array index instead of database index
      final line = entry.value;
      return Subtitle(
        index: index, // This ensures video player uses same indexing as list
        start: parseTimeString(line.startTime),
        end: parseTimeString(line.endTime),
        text: line.edited ?? line.original,
        marked: line.marked,
      );
    }).toList();
  }

  /// Update subtitles and increment version to trigger VideoPlayerSection rebuild
  /// This helper ensures consistent version tracking across all subtitle updates
  void _updateSubtitlesWithVersion(List<SubtitleLine> subtitleLines) {
    _subtitles = _generateSubtitles(subtitleLines);
    _subtitleVersion++;
    
    // Update waveform if it exists
    if (_waveformKey.currentState != null) {
      _waveformKey.currentState!.updateSubtitles(subtitleLines);
    }
  }

  // Add this method to generate subtitles from SimpleSubtitleLine
  List<Subtitle> _generateSimpleSubtitles(List<SimpleSubtitleLine> subtitleLines) {
    return subtitleLines.asMap().entries.map((entry) {
      final index = entry.key; // Use array index instead of database index
      final line = entry.value;
      return Subtitle(
        index: index, // This ensures video player uses same indexing as list
        start: parseTimeString(line.startTime),
        end: parseTimeString(line.endTime),
        text: line.text,
        marked: false, // SimpleSubtitleLine doesn't have marked field
      );
    }).toList();
  }


}
