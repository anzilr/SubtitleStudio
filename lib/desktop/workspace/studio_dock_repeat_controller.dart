import 'package:subtitle_studio/widgets/video/subtitle.dart';

import 'studio_dock_playback_link.dart';

/// Desktop adapter for the mobile Edit Line repeat semantics: a 100 ms lead-in
/// and tail, a current-cue loop or an inclusive custom cue range. The existing
/// media player remains the sole seek/position owner.
class StudioDockRepeatController {
  StudioDockRepeatController(this.playback) {
    playback.position.addListener(_onPosition);
    playback.attached.addListener(_onAttachment);
  }

  final StudioDockPlaybackLink playback;
  List<Subtitle> _cues = const [];
  int? _currentCue;
  int? _rangeFirst;
  int? _rangeLast;
  Duration? _start;
  Duration? _end;
  bool _loopSeekPending = false;
  bool _disposed = false;

  bool get enabled => _start != null && _end != null;
  bool get isCustomRange => enabled && _rangeFirst != null;

  /// Cue updates (including changed timings) cannot leave an old loop active.
  void updateCues(List<Subtitle> cues) {
    if (_disposed) return;
    if (_sameCues(cues)) return;
    _cues = List.unmodifiable(cues);
    if (enabled) _refreshInterval();
  }

  bool _sameCues(List<Subtitle> cues) {
    if (_cues.length != cues.length) return false;
    for (var i = 0; i < cues.length; i++) {
      if (_cues[i].index != cues[i].index ||
          _cues[i].start != cues[i].start ||
          _cues[i].end != cues[i].end) return false;
    }
    return true;
  }

  void selectCue(int cueIndex) {
    if (_disposed || _currentCue == cueIndex) return;
    _currentCue = cueIndex;
    if (enabled && !isCustomRange) {
      _refreshInterval();
      if (enabled) playback.seek(_start!);
    }
  }

  bool toggleCurrent(int cueIndex) {
    if (enabled) {
      stop();
      return false;
    }
    _currentCue = cueIndex;
    if (!playback.isAttached || !_refreshInterval(forceCurrent: true)) {
      stop();
      return false;
    }
    playback.seek(_start!);
    return true;
  }

  /// Positional, zero-based bounds match the existing mobile range dialog.
  bool setRange(int first, int last) {
    if (_disposed || !playback.isAttached || first < 0 ||
        last < first || last >= _cues.length) return false;
    _rangeFirst = _cues[first].index;
    _rangeLast = _cues[last].index;
    if (!_refreshInterval()) {
      stop();
      return false;
    }
    playback.seek(_start!);
    return true;
  }

  bool setNormal(int cueIndex) {
    stop();
    return toggleCurrent(cueIndex);
  }

  void stop() {
    _rangeFirst = null;
    _rangeLast = null;
    _start = null;
    _end = null;
    _loopSeekPending = false;
  }

  bool _refreshInterval({bool forceCurrent = false}) {
    final firstIndex = forceCurrent ? _currentCue : _rangeFirst ?? _currentCue;
    final lastIndex = forceCurrent ? _currentCue : _rangeLast ?? _currentCue;
    final first = _cues.where((cue) => cue.index == firstIndex).firstOrNull;
    final last = _cues.where((cue) => cue.index == lastIndex).firstOrNull;
    if (first == null || last == null || first.start >= last.end) {
      stop();
      return false;
    }
    final start = first.start - const Duration(milliseconds: 100);
    _start = start.isNegative ? Duration.zero : start;
    _end = last.end + const Duration(milliseconds: 100);
    _loopSeekPending = false;
    return true;
  }

  void _onPosition() {
    if (_disposed || !enabled || !playback.isAttached) return;
    final position = playback.position.value;
    if (position < _end!) {
      _loopSeekPending = false;
    } else if (!_loopSeekPending) {
      // The native seek is asynchronous. Wait until a fresh position below
      // the endpoint arrives before issuing another seek.
      _loopSeekPending = true;
      playback.seek(_start!);
    }
  }

  void _onAttachment() {
    if (!playback.isAttached) stop();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    playback.position.removeListener(_onPosition);
    playback.attached.removeListener(_onAttachment);
    stop();
  }
}
