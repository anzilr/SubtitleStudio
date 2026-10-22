/// Coordinates asynchronous Edit Line media requests without owning a
/// VideoPlayerWidget or any native media resources.
///
/// Every new seek supersedes pending readiness waits for older cues. Removing
/// or replacing the video also invalidates all pending seeks, old media-state
/// synchronization, and in-flight picker results. Disposal is terminal.
class EditLineMediaRequestCoordinator {
  int _mediaEpoch = 0;
  int _seekEpoch = 0;
  int _pickerEpoch = 0;
  bool _disposed = false;

  int? beginSeek() => _disposed ? null : ++_seekEpoch;

  bool isCurrentSeek(int? token) =>
      !_disposed && token != null && token == _seekEpoch;

  int? captureMedia() => _disposed ? null : _mediaEpoch;

  bool isCurrentMedia(int? token) =>
      !_disposed && token != null && token == _mediaEpoch;

  int? beginPicker() => _disposed ? null : ++_pickerEpoch;

  bool isCurrentPicker(int? token) =>
      !_disposed && token != null && token == _pickerEpoch;

  void invalidateMedia() {
    if (_disposed) return;
    ++_mediaEpoch;
    ++_seekEpoch;
  }

  void invalidatePicker() {
    if (_disposed) return;
    ++_pickerEpoch;
  }

  void dispose() {
    if (_disposed) return;
    invalidateMedia();
    invalidatePicker();
    _disposed = true;
  }
}
