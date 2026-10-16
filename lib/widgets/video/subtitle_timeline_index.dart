import 'package:subtitle_studio/widgets/video/subtitle.dart';

/// Immutable lookup index for subtitles ordered by start time.
///
/// A prefix maximum of cue end-times lets lookup stop as soon as no earlier
/// subtitle can still overlap the current playback position. This correctly
/// handles a long-running cue that spans several shorter cues.
class SubtitleTimelineIndex {
  final List<_IndexedSubtitle> _entries;
  final List<int> _prefixMaxEndMs;

  const SubtitleTimelineIndex.empty()
      : _entries = const [],
        _prefixMaxEndMs = const [];

  factory SubtitleTimelineIndex(List<Subtitle> subtitles) {
    if (subtitles.isEmpty) {
      return const SubtitleTimelineIndex.empty();
    }

    final entries = subtitles
        .asMap()
        .entries
        .map(
          (entry) => _IndexedSubtitle(
            subtitle: entry.value,
            originalIndex: entry.key,
          ),
        )
        .toList(growable: false);

    entries.sort((a, b) {
      final byStart = a.subtitle.start.compareTo(b.subtitle.start);
      return byStart != 0
          ? byStart
          : a.originalIndex.compareTo(b.originalIndex);
    });

    int maxEnd = -1;
    final prefixMaxEndMs = <int>[];
    for (final entry in entries) {
      final endMs = entry.subtitle.end.inMilliseconds;
      if (endMs > maxEnd) maxEnd = endMs;
      prefixMaxEndMs.add(maxEnd);
    }

    return SubtitleTimelineIndex._(
      List<_IndexedSubtitle>.unmodifiable(entries),
      List<int>.unmodifiable(prefixMaxEndMs),
    );
  }

  const SubtitleTimelineIndex._(
    this._entries,
    this._prefixMaxEndMs,
  );

  List<Subtitle> findActive(Duration position) {
    if (_entries.isEmpty) return const [];

    final positionMs = position.inMilliseconds;
    final lastStartedIndex = _findLastStarted(positionMs);
    if (lastStartedIndex < 0) return const [];

    final active = <_IndexedSubtitle>[];

    for (int i = lastStartedIndex; i >= 0; i--) {
      if (_prefixMaxEndMs[i] <= positionMs) break;

      final entry = _entries[i];
      if (entry.subtitle.end.inMilliseconds > positionMs) {
        active.add(entry);
      }
    }

    active.sort((a, b) => a.originalIndex.compareTo(b.originalIndex));
    return List<Subtitle>.unmodifiable(
      active.map((entry) => entry.subtitle),
    );
  }

  int _findLastStarted(int positionMs) {
    int left = 0;
    int right = _entries.length - 1;
    int result = -1;

    while (left <= right) {
      final mid = (left + right) >> 1;
      if (_entries[mid].subtitle.start.inMilliseconds <= positionMs) {
        result = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return result;
  }
}

class _IndexedSubtitle {
  final Subtitle subtitle;
  final int originalIndex;

  const _IndexedSubtitle({
    required this.subtitle,
    required this.originalIndex,
  });
}
