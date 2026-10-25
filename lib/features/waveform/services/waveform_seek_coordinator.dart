import 'dart:async';

import 'package:flutter/foundation.dart';

/// Batches manual waveform scrubbing without delaying the painted scroll.
///
/// Drag updates may arrive every frame; native media decoders should receive
/// bounded preview seeks and one exact final position when the drag ends.
/// Mouse-wheel bursts receive the same previews plus an idle final seek.
final class WaveformSeekCoordinator {
  WaveformSeekCoordinator({
    required void Function() onBegin,
    required void Function(Duration) onPreview,
    required void Function(Duration) onComplete,
    required void Function() onCancel,
    this.shouldPreview,
    this.previewInterval = const Duration(milliseconds: 180),
    this.wheelIdleInterval = const Duration(milliseconds: 220),
  })  : _onBegin = onBegin,
        _onPreview = onPreview,
        _onComplete = onComplete,
        _onCancel = onCancel;

  final void Function() _onBegin;
  final void Function(Duration) _onPreview;
  final void Function(Duration) _onComplete;
  final void Function() _onCancel;
  /// A paused player only needs the exact final seek on release.
  final bool Function()? shouldPreview;
  final Duration previewInterval;
  final Duration wheelIdleInterval;

  Timer? _previewCooldown;
  Timer? _wheelIdle;
  Duration? _latestTarget;
  bool _active = false;
  bool _previewAllowed = true;
  int _updates = 0;
  int _previews = 0;

  void startDrag() {
    // A wheel burst is a separate gesture. It may have preview-seeked to its
    // last target, but a subsequent drag must not inherit that target or
    // release a stale wheel final seek if the pointer has not moved yet.
    if (_wheelIdle != null) cancel();
    _begin();
  }

  void updateDrag(Duration target) {
    if (!_active) startDrag();
    _update(target);
  }

  void finishDrag() => _complete();

  void scrollWheel(Duration target) {
    _begin();
    _update(target);
    _wheelIdle?.cancel();
    _wheelIdle = Timer(wheelIdleInterval, _complete);
  }

  void cancel() {
    _wheelIdle?.cancel();
    _previewCooldown?.cancel();
    _wheelIdle = null;
    _previewCooldown = null;
    _latestTarget = null;
    _previewAllowed = true;
    if (_active) {
      _active = false;
      _onCancel();
    }
  }

  /// Cancels pending timers without invoking callbacks on an unmounted widget.
  void dispose() {
    _wheelIdle?.cancel();
    _previewCooldown?.cancel();
    _wheelIdle = null;
    _previewCooldown = null;
    _active = false;
    _latestTarget = null;
  }

  void _begin() {
    if (_active) return;
    _active = true;
    _updates = 0;
    _previews = 0;
    _latestTarget = null;
    _previewAllowed = true;
    _previewCooldown?.cancel();
    _onBegin();
  }

  void _update(Duration target) {
    // At coarse zoom, many physical pixel updates map to the same audio
    // sample. Avoid redundant native previews for an unchanged target, while
    // retaining the exact target for the eventual final seek.
    if (_latestTarget == target) return;
    _latestTarget = target;
    _updates++;
    if (!_previewAllowed || (shouldPreview?.call() == false)) return;
    _previewAllowed = false;
    _previews++;
    _onPreview(target);
    _previewCooldown?.cancel();
    _previewCooldown = Timer(previewInterval, () {
      _previewAllowed = true;
    });
  }

  void _complete() {
    if (!_active) return;
    final target = _latestTarget;
    _wheelIdle?.cancel();
    _previewCooldown?.cancel();
    _wheelIdle = null;
    _previewCooldown = null;
    _active = false;
    _latestTarget = null;
    _previewAllowed = true;
    if (target == null) {
      _onCancel();
      return;
    }
    // Register the hold before the final native seek can issue a stale
    // playback-position notification.
    _onComplete(target);
    _onPreview(target);
    if (kProfileMode) {
      debugPrint('Waveform scrub: updates=$_updates previewSeeks=$_previews '
          'finalSeekMs=${target.inMilliseconds}');
    }
  }
}
