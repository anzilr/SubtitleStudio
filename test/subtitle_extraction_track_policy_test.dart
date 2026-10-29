import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_extraction_track_policy.dart';

void main() {
  test('text extraction accepts SRT-compatible subtitle codecs', () {
    final tracks = [
      {'codec': 'subrip', 'subtitle_index': 0},
      {'codec': 'ASS', 'subtitle_index': 1},
      {'codec': 'webvtt', 'subtitle_index': 2},
      {'codec': 'mov_text', 'subtitle_index': 3},
    ];
    expect(SubtitleExtractionTrackPolicy.textTracks(tracks), tracks);
  });

  test('bitmap streams cannot be offered for text-based SRT extraction', () {
    final tracks = [
      {'codec': 'dvbsub'},
      {'codec': 'dvb_subtitle'},
      {'codec': 'hdmv_pgs_subtitle'},
      {'codec': 'dvd_subtitle'},
      {'codec': 'xsub'},
      {'codec': null},
    ];
    expect(SubtitleExtractionTrackPolicy.textTracks(tracks), isEmpty);
  });

  test('mixed video keeps only convertible text tracks in source order', () {
    final tracks = [
      {'codec': 'hdmv_pgs_subtitle', 'subtitle_index': 0},
      {'codec': 'subrip', 'subtitle_index': 1},
      {'codec': 'dvd_subtitle', 'subtitle_index': 2},
      {'codec': 'ass', 'subtitle_index': 3},
    ];
    expect(SubtitleExtractionTrackPolicy.textTracks(tracks), [
      tracks[1], tracks[3],
    ]);
  });
}
