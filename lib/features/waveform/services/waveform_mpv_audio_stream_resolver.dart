/// Resolves a selected libmpv audio track ID to its actual FFmpeg global
/// stream index (mpv track-list/N/ff-index). This is NOT an audio ordinal.
typedef MpvPropertyReader = Future<String> Function(String property);

class WaveformMpvAudioStreamResolver {
  const WaveformMpvAudioStreamResolver();

  /// Returns an explicit FFmpeg *global* stream selector such as
  /// ffmpeg:stream:3. Never invents a match when mpv lacks metadata.
  Future<String> resolve({
    required String selectedMpvId,
    required MpvPropertyReader getProperty,
  }) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(selectedMpvId)) {
      throw FormatException('Audio selection is not an mpv track ID: '
          '$selectedMpvId');
    }
    final countText = (await getProperty('track-list/count')).trim();
    final count = int.tryParse(countText);
    if (count == null || count < 1 || count > 256) {
      throw FormatException('Invalid mpv track-list count: $countText');
    }
    int? match;
    for (var i = 0; i < count; i++) {
      final prefix = 'track-list/$i/';
      final type = (await getProperty('${prefix}type')).trim();
      if (type != 'audio') continue;
      final id = (await getProperty('${prefix}id')).trim();
      if (id != selectedMpvId) continue;
      if (match != null) {
        throw StateError('Duplicate mpv audio track ID $selectedMpvId');
      }
      final streamText = (await getProperty('${prefix}ff-index')).trim();
      final streamIndex = int.tryParse(streamText);
      if (streamIndex == null || streamIndex < 0 ||
          streamIndex > 100000 ||
          !RegExp(r'^[0-9]+$').hasMatch(streamText)) {
        throw FormatException(
            'Selected audio track lacks a verified FFmpeg stream index.');
      }
      match = streamIndex;
    }
    if (match == null) {
      throw StateError('Selected mpv audio track $selectedMpvId not found.');
    }
    return 'ffmpeg:stream:$match';
  }
}
