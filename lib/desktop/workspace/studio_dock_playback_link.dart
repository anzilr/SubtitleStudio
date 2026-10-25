import 'package:flutter/widgets.dart';

enum StudioDockAudioStatus { waiting, ready, unavailable }

/// Selected mpv track identity and the explicitly resolved FFmpeg global
/// stream selector. Null selector is meaningful only for ready/auto.
class StudioDockAudioSource {
  const StudioDockAudioSource.waiting()
      : status = StudioDockAudioStatus.waiting,
        trackId = null,
        streamSelector = null,
        error = null;

  const StudioDockAudioSource.ready(this.trackId, this.streamSelector)
      : status = StudioDockAudioStatus.ready,
        error = null;

  const StudioDockAudioSource.unavailable(this.trackId, this.error)
      : status = StudioDockAudioStatus.unavailable,
        streamSelector = null;

  final StudioDockAudioStatus status;
  final String? trackId;
  final String? streamSelector;
  final String? error;
}

/// One session-scoped exchange between the existing media_kit video owner
/// and Studio Dock's waveform. Neither side constructs its own second player.
class StudioDockPlaybackLink {
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> playing = ValueNotifier(false);
  /// Explicit attachment signal: a paused player can detach without changing
  /// the playing notifier, but floating controls must still disable.
  final ValueNotifier<bool> attached = ValueNotifier(false);
  final ValueNotifier<StudioDockAudioSource> audio =
      ValueNotifier(const StudioDockAudioSource.waiting());

  void Function(Duration)? _seek;
  bool _disposed = false;
  int _attachmentRevision = 0;

  bool get isAttached => _seek != null;
  int get attachmentRevision => _attachmentRevision;

  /// Attach only the native player's existing seek API.
  void attach(void Function(Duration) seek) {
    if (_disposed) return;
    _attachmentRevision++;
    _seek = seek;
    attached.value = true;
  }

  /// A retiring video surface must not detach its replacement. This is used
  /// by the surface's post-frame lifecycle cleanup, after the widget tree is
  /// unlocked and it is safe to notify ValueListenableBuilder listeners.
  void detachIfCurrent(int attachmentRevision) {
    if (_disposed || attachmentRevision != _attachmentRevision) return;
    detach();
  }

  /// Safe from State.dispose(), including the tree-finalization phase. The
  /// notifier reset runs only after Flutter finishes unmounting this frame.
  void detachAfterFrame() {
    if (_disposed) return;
    final revision = _attachmentRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      detachIfCurrent(revision);
    });
  }

  void detach() {
    _seek = null;
    if (!_disposed) {
      attached.value = false;
      playing.value = false;
      audio.value = const StudioDockAudioSource.waiting();
    }
  }

  void prepareAudio() {
    if (_disposed || audio.value.status == StudioDockAudioStatus.waiting) return;
    audio.value = const StudioDockAudioSource.waiting();
  }

  void updateAudioReady(String trackId, String? selector) {
    if (_disposed) return;
    final current = audio.value;
    if (current.status == StudioDockAudioStatus.ready &&
        current.trackId == trackId && current.streamSelector == selector) {
      return;
    }
    audio.value = StudioDockAudioSource.ready(trackId, selector);
  }

  void updateAudioUnavailable(String trackId, String message) {
    if (_disposed) return;
    final current = audio.value;
    if (current.status == StudioDockAudioStatus.unavailable &&
        current.trackId == trackId && current.error == message) {
      return;
    }
    audio.value = StudioDockAudioSource.unavailable(trackId, message);
  }

  void updatePosition(Duration value) {
    if (!_disposed && position.value != value) position.value = value;
  }

  void updatePlaying(bool value) {
    if (!_disposed && playing.value != value) playing.value = value;
  }

  /// The waveform seek coordinator already owns throttling and final seeks.
  /// Do not apply another debouncer or call into a disposed player.
  void seek(Duration value) {
    if (_disposed) return;
    _seek?.call(value.isNegative ? Duration.zero : value);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _seek = null;
    position.dispose();
    playing.dispose();
    attached.dispose();
    audio.dispose();
  }
}
