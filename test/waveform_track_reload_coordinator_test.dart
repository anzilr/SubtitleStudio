import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_track_reload_coordinator.dart';

void main() {
  test('immediately invalidates previous track before slow resolution',
      () async {
    final queue = WaveformTrackReloadCoordinator();
    final pending = Completer<String?>();
    final events = <String>[];
    var sourceOpen = true;
    final task = queue.reload(
      invalidate: () => events.add('clear'),
      resolveStream: () => pending.future,
      isCurrentSource: () => sourceOpen,
      load: (id) async => events.add('load:$id'),
      fail: (error) => events.add('fail'),
    );
    expect(events, ['clear']);
    expect(queue.generation, 1);
    pending.complete('ffmpeg:stream:3');
    await task;
    expect(events, ['clear', 'load:ffmpeg:stream:3']);
    sourceOpen = false;
  });

  test('rapid track changes never load older resolved stream', () async {
    final queue = WaveformTrackReloadCoordinator();
    final firstResolution = Completer<String?>();
    final secondResolution = Completer<String?>();
    final events = <String>[];
    Future<void> reload(Completer<String?> value) => queue.reload(
      invalidate: () => events.add('clear'),
      resolveStream: () => value.future,
      isCurrentSource: () => true,
      load: (id) async => events.add('load:$id'),
      fail: (error) => events.add('error'),
    );
    final first = reload(firstResolution);
    final second = reload(secondResolution);
    expect(events, ['clear', 'clear']);
    secondResolution.complete('ffmpeg:stream:5');
    await second;
    firstResolution.complete('ffmpeg:stream:2');
    await first;
    expect(events, ['clear', 'clear', 'load:ffmpeg:stream:5']);
  });

  test('Auto selection is explicit, not missing saved preference', () async {
    final calls = <String>[];
    await WaveformTrackReloadCoordinator().reload(
      invalidate: () => calls.add('clear'),
      resolveStream: () async => null,
      isCurrentSource: () => true,
      load: (id) async => calls.add(id),
      fail: (_) => calls.add('error'),
    );
    expect(calls, ['clear', 'auto']);
  });

  test('mapping failure never reuses old track or submits load', () async {
    final calls = <String>[];
    await WaveformTrackReloadCoordinator().reload(
      invalidate: () => calls.add('clear'),
      resolveStream: () async => throw const FormatException('Missing ff-index'),
      isCurrentSource: () => true,
      load: (id) async => calls.add('load:$id'),
      fail: (error) => calls.add('error'),
    );
    expect(calls, ['clear', 'error']);
  });

  test('failure from obsolete mapping request is ignored', () async {
    final queue = WaveformTrackReloadCoordinator();
    final slow = Completer<String?>();
    final calls = <String>[];
    final first = queue.reload(
      invalidate: () => calls.add('clear'),
      resolveStream: () => slow.future,
      isCurrentSource: () => true,
      load: (id) async => calls.add('load:$id'),
      fail: (error) => calls.add('error'),
    );
    await queue.reload(
      invalidate: () => calls.add('clear'),
      resolveStream: () async => 'ffmpeg:stream:6',
      isCurrentSource: () => true,
      load: (id) async => calls.add('load:$id'),
      fail: (error) => calls.add('error'),
    );
    slow.completeError(StateError('Old track no longer exists'));
    await first;
    expect(calls, ['clear', 'clear', 'load:ffmpeg:stream:6']);
  });

  test('hidden source cancels slow mapping and prevents stale failure', () async {
    final queue = WaveformTrackReloadCoordinator();
    final mapping = Completer<String?>();
    var visible = true;
    final events = <String>[];
    final loading = queue.reload(
      invalidate: () => events.add('clear'),
      resolveStream: () => mapping.future,
      isCurrentSource: () => visible,
      load: (id) async => events.add('load:$id'),
      fail: (e) => events.add('error'),
    );
    visible = false;
    queue.cancel();
    mapping.complete('ffmpeg:stream:4');
    await loading;
    expect(events, ['clear']);
  });

  test('disposal ignores late resolution and future reload requests', () async {
    final queue = WaveformTrackReloadCoordinator();
    final mapping = Completer<String?>();
    final events = <String>[];
    final task = queue.reload(
      invalidate: () => events.add('clear'),
      resolveStream: () => mapping.future,
      isCurrentSource: () => true,
      load: (id) async => events.add('load:$id'),
      fail: (error) => events.add('error'),
    );
    queue.dispose();
    mapping.complete('ffmpeg:stream:2');
    await task;
    await queue.reload(
      invalidate: () => events.add('clear2'),
      resolveStream: () async => 'ffmpeg:stream:1',
      isCurrentSource: () => true,
      load: (id) async => events.add('load:$id'),
      fail: (_) => events.add('error2'),
    );
    expect(events, ['clear']);
  });

  test('request with invalid source after invalidation cannot publish', () async {
    final events = <String>[];
    await WaveformTrackReloadCoordinator().reload(
      invalidate: () => events.add('clear'),
      resolveStream: () async => 'ffmpeg:stream:0',
      isCurrentSource: () => false,
      load: (id) async => events.add('load:$id'),
      fail: (_) => events.add('error'),
    );
    expect(events, ['clear']);
  });
}
