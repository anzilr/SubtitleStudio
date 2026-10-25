/// A subtitle interval used only for waveform gesture constraints.
class WaveformTimeBoundary {
  const WaveformTimeBoundary(this.start, this.end);

  final Duration start;
  final Duration end;
}

enum WaveformTimeDrag { startHandle, endHandle, move }

/// Pure timing rules shared by the mobile and Studio Dock waveform widgets.
/// Snapping always proposes a complete interval and never bypasses the
/// non-overlap and positive-duration checks.
class WaveformTimeRangePlanner {
  const WaveformTimeRangePlanner._();

  static const _minSpan = Duration(milliseconds: 1);
  static const _snapThreshold = Duration(milliseconds: 150);
  static const _minSnapGap = Duration(milliseconds: 25);
  static const _playheadPriority = Duration(milliseconds: 20);

  static (Duration, Duration) constrain({
    required Duration start,
    required Duration end,
    required Duration playhead,
    required Iterable<WaveformTimeBoundary> neighbors,
    required WaveformTimeDrag drag,
    required bool allowOverlap,
    required bool magnetSnapEnabled,
    Duration? originalStart,
  }) {
    final others = neighbors.where((cue) => cue.end > cue.start).toList();
    var constrainedStart = start;
    var constrainedEnd = end;

    switch (drag) {
      case WaveformTimeDrag.startHandle:
        constrainedEnd = _max(end, _minSpan);
        constrainedStart = _max(Duration.zero,
            _min(start, constrainedEnd - _minSpan));
        if (!allowOverlap) {
          for (final cue in others) {
            if (constrainedStart < cue.end && constrainedEnd > cue.start) {
              constrainedStart = _max(constrainedStart, cue.end);
            }
          }
          constrainedStart = _min(constrainedStart,
              constrainedEnd - _minSpan);
        }
      case WaveformTimeDrag.endHandle:
        constrainedStart = _max(start, Duration.zero);
        constrainedEnd = _max(end, constrainedStart + _minSpan);
        if (!allowOverlap) {
          for (final cue in others) {
            if (constrainedStart < cue.end && constrainedEnd > cue.start) {
              constrainedEnd = _min(constrainedEnd, cue.start);
            }
          }
          constrainedEnd = _max(constrainedEnd,
              constrainedStart + _minSpan);
        }
      case WaveformTimeDrag.move:
        final span = _max(end - start, _minSpan);
        constrainedStart = _clampMoveStart(
          proposed: start,
          original: originalStart ?? start,
          span: span,
          neighbors: others,
          allowOverlap: allowOverlap,
        );
        constrainedEnd = constrainedStart + span;
    }

    final base = (constrainedStart, constrainedEnd);
    if (!magnetSnapEnabled) return base;

    final proposals = <_SnapProposal>[];
    void propose(Duration nextStart, Duration nextEnd,
        Duration change, bool playheadCandidate) {
      final distance = change.abs();
      if (distance > _snapThreshold) return;
      if (!_valid(nextStart, nextEnd, others, allowOverlap)) return;
      if (drag == WaveformTimeDrag.move && !allowOverlap &&
          _clampMoveStart(
            proposed: nextStart,
            original: originalStart ?? start,
            span: constrainedEnd - constrainedStart,
            neighbors: others,
            allowOverlap: false,
          ) != nextStart) return;
      proposals.add(_SnapProposal(nextStart, nextEnd,
          distance - (playheadCandidate ? _playheadPriority : Duration.zero)));
    }

    switch (drag) {
      case WaveformTimeDrag.startHandle:
        propose(playhead, constrainedEnd, playhead - constrainedStart, true);
        for (final cue in others) {
          final target = cue.end + _minSnapGap;
          propose(target, constrainedEnd, target - constrainedStart, false);
        }
      case WaveformTimeDrag.endHandle:
        propose(constrainedStart, playhead, playhead - constrainedEnd, true);
        for (final cue in others) {
          final target = cue.start - _minSnapGap;
          propose(constrainedStart, target, target - constrainedEnd, false);
        }
      case WaveformTimeDrag.move:
        final span = constrainedEnd - constrainedStart;
        void snapStart(Duration target, bool isPlayhead) => propose(
            target, target + span, target - constrainedStart, isPlayhead);
        void snapEnd(Duration target, bool isPlayhead) => propose(
            target - span, target, target - constrainedEnd, isPlayhead);
        snapStart(playhead, true);
        snapEnd(playhead, true);
        for (final cue in others) {
          snapStart(cue.end + _minSnapGap, false);
          snapEnd(cue.start - _minSnapGap, false);
        }
    }

    if (proposals.isEmpty) return base;
    proposals.sort((a, b) => a.score.compareTo(b.score));
    return (proposals.first.start, proposals.first.end);
  }

  static Duration _clampMoveStart({
    required Duration proposed,
    required Duration original,
    required Duration span,
    required List<WaveformTimeBoundary> neighbors,
    required bool allowOverlap,
  }) {
    var result = _max(proposed, Duration.zero);
    if (allowOverlap) return result;
    if (result > original) {
      for (final cue in neighbors) {
        final barrier = cue.start - span;
        if (barrier >= original && result > barrier) {
          result = _min(result, barrier);
        }
      }
    } else if (result < original) {
      for (final cue in neighbors) {
        if (cue.end <= original && result < cue.end) {
          result = _max(result, cue.end);
        }
      }
    }
    return _max(result, Duration.zero);
  }

  static bool _valid(Duration start, Duration end,
      List<WaveformTimeBoundary> neighbors, bool allowOverlap) {
    if (start.isNegative || end - start < _minSpan) return false;
    return allowOverlap || neighbors.every((cue) =>
        end <= cue.start || start >= cue.end);
  }

  static Duration _min(Duration a, Duration b) => a < b ? a : b;
  static Duration _max(Duration a, Duration b) => a > b ? a : b;
}

class _SnapProposal {
  const _SnapProposal(this.start, this.end, this.score);

  final Duration start;
  final Duration end;
  final Duration score;
}
