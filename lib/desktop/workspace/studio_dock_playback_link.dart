import 'package:flutter/foundation.dart';

/// One session-scoped exchange between the existing media_kit video owner
/// and Studio Dock's waveform. Neither side constructs its own second player.
class StudioDockPlaybackLink {
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> playing = ValueNotifier(false);

  void Function(Duration)? _seek;
  bool _disposed = false;

  bool get isAttached => _seek != null;

  /// Attach only the native player's existing seek API.
  void attach(void Function(Duration) seek) {
    if (_disposed) return;
    _seek = seek;
  }

  void detach() {
    _seek = null;
    if (!_disposed) playing.value = false;
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
  }
}
