/// FFmpeg text subtitle codecs that can be converted into an editable SRT.
/// Bitmap/image-based subtitle streams must not be offered as text extraction.
class SubtitleExtractionTrackPolicy {
  const SubtitleExtractionTrackPolicy._();

  static const _textCodecs = <String>{
    'subrip', 'srt', 'ass', 'ssa', 'webvtt', 'vtt', 'mov_text',
    'text', 'txt', 'microdvd', 'subviewer', 'subviewer1',
    'mpl2', 'ttml', 'stl',
  };

  static bool isTextTrack(Map<String, dynamic> track) {
    final codec = (track['codec'] as String?)?.toLowerCase().trim();
    return codec != null && _textCodecs.contains(codec);
  }

  static List<Map<String, dynamic>> textTracks(
      Iterable<Map<String, dynamic>> tracks) =>
      tracks.where(isTextTrack).toList();
}
