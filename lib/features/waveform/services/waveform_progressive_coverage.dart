import 'dart:math' as math;

import 'package:subtitle_studio/features/waveform/services/waveform_window_preview.dart';

/// One bounded request in absolute media time, never relative to scroll x.
///
/// A request token is valid only for its originating source/track generation.
class WaveformProgressiveRequest {
  WaveformProgressiveRequest({
    required Object owner,
    required this.generation,
    required this.index,
    required this.start,
    required this.end,
  }) : _owner = owner;

  // Prevent callbacks from an entirely different coverage instance with
  // matching generation/index from publishing into this instance.
  final Object _owner;
  final int generation;
  final int index;
  final Duration start;
  final Duration end;
}

/// Sparse coverage of the requested timeline: missing audio is *unknown*,
/// never silence, even where the previously loaded sections are silent.
class WaveformProgressiveExtent {
  const WaveformProgressiveExtent({
    required this.start,
    required this.end,
    required this.preview,
  });

  final Duration start;
  final Duration end;
  final WaveformWindowPreview? preview;

  bool get isKnown => preview != null;
}

/// Experimental R11 in-memory orchestration, not yet connected to the editor.
///
/// Never writes Isar, caches or source paths. A caller must supply a stable
/// source revision and selected stream identity and must use a unique session
/// revision for SAF providers with no trustworthy version metadata.
class WaveformProgressiveCoverage {
  WaveformProgressiveCoverage({
    required String sourceRevision,
    required String trackIdentity,
    required this.mediaDuration,
    this.windowDuration = const Duration(seconds: 30),
  }) : _sourceRevision = sourceRevision,
       _trackIdentity = trackIdentity {
    _validate(sourceRevision, trackIdentity, mediaDuration, windowDuration);
  }

  String _sourceRevision;
  String _trackIdentity;
  final Duration mediaDuration;
  final Duration windowDuration;
  final Object _owner = Object();
  int _generation = 0;
  final Map<int, WaveformWindowPreview> _ready = {};
  final Set<int> _pending = {};

  int get loadedWindowCount => _ready.length;
  int get pendingWindowCount => _pending.length;
  String get sourceRevision => _sourceRevision;
  String get trackIdentity => _trackIdentity;

  static void _validate(String source, String track,
      Duration media, Duration window) {
    if (source.trim().isEmpty || track.trim().isEmpty ||
        media <= Duration.zero || window <= Duration.zero ||
        window > const Duration(seconds: 60)) {
      throw ArgumentError('Invalid progressive source, stream or duration.');
    }
  }

  /// Identity changes invalidate both in-flight requests and decoded data.
  /// Same-identity calls preserve already validated transient windows.
  void retarget({
    required String sourceRevision,
    required String trackIdentity,
  }) {
    _validate(sourceRevision, trackIdentity, mediaDuration, windowDuration);
    if (sourceRevision == _sourceRevision && trackIdentity == _trackIdentity) {
      return;
    }
    _sourceRevision = sourceRevision;
    _trackIdentity = trackIdentity;
    _generation++;
    _ready.clear();
    _pending.clear();
  }

  Duration _start(int index) =>
      Duration(microseconds: index * windowDuration.inMicroseconds);

  Duration _end(int index) => Duration(
      microseconds: math.min(mediaDuration.inMicroseconds,
          (index + 1) * windowDuration.inMicroseconds));

  void _validateViewport(Duration start, Duration end) {
    if (start.isNegative || end <= start || end > mediaDuration) {
      throw RangeError('Invalid absolute media viewport.');
    }
  }

  /// Return nearest missing windows first, including the current playhead.
  ///
  /// A claimed window is marked in-flight. Repeated viewport builds never
  /// start duplicate FFmpeg work for the same request generation.
  List<WaveformProgressiveRequest> claimVisible({
    required Duration start,
    required Duration end,
    Duration? playhead,
    int limit = 3,
  }) {
    _validateViewport(start, end);
    if (limit < 1 || limit > 8) {
      throw RangeError('Invalid bounded progressive request count.');
    }
    final focus = playhead ?? Duration(
      microseconds: (start.inMicroseconds + end.inMicroseconds) ~/ 2);
    if (focus.isNegative || focus > mediaDuration) {
      throw RangeError('Invalid absolute playhead.');
    }
    final first = start.inMicroseconds ~/ windowDuration.inMicroseconds;
    final last = (end.inMicroseconds - 1) ~/ windowDuration.inMicroseconds;
    final remaining = 8 - _pending.length;
    if (remaining <= 0) return const [];
    final needed = <int>[];
    for (var index = first; index <= last; index++) {
      if (!_ready.containsKey(index) && !_pending.contains(index)) {
        needed.add(index);
      }
    }
    final focusMicros = focus.inMicroseconds;
    needed.sort((a, b) {
      final midpointA = (_start(a).inMicroseconds +
          _end(a).inMicroseconds) ~/ 2;
      final midpointB = (_start(b).inMicroseconds +
          _end(b).inMicroseconds) ~/ 2;
      final distance = (midpointA - focusMicros).abs().compareTo(
          (midpointB - focusMicros).abs());
      return distance != 0 ? distance : a.compareTo(b);
    });
    final requests = <WaveformProgressiveRequest>[];
    for (final index in needed.take(math.min(limit, remaining))) {
      _pending.add(index);
      requests.add(WaveformProgressiveRequest(
        owner: _owner,
        generation: _generation,
        index: index,
        start: _start(index),
        end: _end(index),
      ));
    }
    return List<WaveformProgressiveRequest>.unmodifiable(requests);
  }

  /// Returns false for obsolete/cancelled FFmpeg requests.
  ///
  /// No truncated or shifted PCM interval can masquerade as a complete tile.
  /// Permit at most one 2,756Hz sample of rounding at the right edge.
  bool publish(WaveformProgressiveRequest request,
      WaveformWindowPreview preview, {int sampleRate = 2756}) {
    if (!identical(request._owner, _owner) ||
        request.generation != _generation ||
        !_pending.contains(request.index)) {
      return false;
    }
    if (sampleRate <= 0 || request.index < 0 ||
        preview.minima.isEmpty ||
        preview.minima.length != preview.maxima.length ||
        request.start != _start(request.index) ||
        request.end != _end(request.index) ||
        preview.start != request.start ||
        (preview.end.inMicroseconds - request.end.inMicroseconds).abs() >
            (1000000 ~/ sampleRate) + 1) {
      throw FormatException(
          'Partial or shifted progressive window cannot become known.');
    }
    _ready[request.index] = preview;
    _pending.remove(request.index);
    return true;
  }

  /// Failures remain unknown and may be retried without stale cache reuse.
  void cancel(WaveformProgressiveRequest request) {
    if (identical(request._owner, _owner) &&
        request.generation == _generation) {
      _pending.remove(request.index);
    }
  }

  /// Covers exactly the requested viewport. Unknown spans are explicit nulls.
  List<WaveformProgressiveExtent> coverage({
    required Duration start,
    required Duration end,
  }) {
    _validateViewport(start, end);
    final first = start.inMicroseconds ~/ windowDuration.inMicroseconds;
    final last = (end.inMicroseconds - 1) ~/ windowDuration.inMicroseconds;
    final extents = <WaveformProgressiveExtent>[];
    for (var index = first; index <= last; index++) {
      extents.add(WaveformProgressiveExtent(
        start: Duration(microseconds:
            math.max(start.inMicroseconds, _start(index).inMicroseconds)),
        end: Duration(microseconds:
            math.min(end.inMicroseconds, _end(index).inMicroseconds)),
        preview: _ready[index],
      ));
    }
    return List<WaveformProgressiveExtent>.unmodifiable(extents);
  }
}
