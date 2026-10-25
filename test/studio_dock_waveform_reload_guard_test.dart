import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_waveform_reload_guard.dart';

void main() {
  test('reload selection is tied to session, media and exact audio stream', () {
    final playback = StudioDockPlaybackLink();
    final replacement = StudioDockPlaybackLink();
    addTearDown(playback.dispose);
    addTearDown(replacement.dispose);
    playback.updateAudioReady('audio-2', 'ffmpeg:stream:3');
    replacement.updateAudioReady('audio-2', 'ffmpeg:stream:3');

    final selected = StudioDockWaveformReloadSelection(
      playback: playback,
      videoPath: 'original.mkv',
      collectionId: 12,
      trackId: 'audio-2',
      streamSelector: 'ffmpeg:stream:3',
    );
    bool matches({
      StudioDockPlaybackLink? link,
      String path = 'original.mkv',
      int collection = 12,
    }) => selected.matches(
      playback: link ?? playback,
      videoPath: path,
      collectionId: collection,
    );

    expect(matches(), isTrue);
    expect(matches(link: replacement), isFalse);
    expect(matches(path: 'another.mkv'), isFalse);
    expect(matches(collection: 13), isFalse);
    playback.prepareAudio();
    expect(matches(), isFalse);
    playback.updateAudioReady('audio-2', 'ffmpeg:stream:4');
    expect(matches(), isFalse);
    playback.updateAudioReady('audio-3', 'ffmpeg:stream:3');
    expect(matches(), isFalse);
    playback.updateAudioUnavailable('audio-2', 'Track unavailable');
    expect(matches(), isFalse);
  });

  test('valid reload clears cache, clears old waveform, then loads once', () async {
    final actions = <String>[];
    final completed = await StudioDockWaveformReloadGuard.run(
      isCurrent: () => true,
      clearCache: () async => actions.add('cache'),
      clearWaveform: () async => actions.add('clear'),
      loadWaveform: () async => actions.add('load'),
    );
    expect(completed, isTrue);
    expect(actions, ['cache', 'clear', 'load']);
  });

  test('track switch during cache removal does not clear or reload', () async {
    var current = true;
    final cacheGate = Completer<void>();
    final actions = <String>[];
    final reload = StudioDockWaveformReloadGuard.run(
      isCurrent: () => current,
      clearCache: () {
        actions.add('cache');
        return cacheGate.future;
      },
      clearWaveform: () async => actions.add('clear'),
      loadWaveform: () async => actions.add('load'),
    );
    current = false;
    cacheGate.complete();
    expect(await reload, isFalse);
    expect(actions, ['cache']);
  });

  test('track switch after clear does not start obsolete waveform decode',
      () async {
    var current = true;
    final clearGate = Completer<void>();
    final actions = <String>[];
    final reload = StudioDockWaveformReloadGuard.run(
      isCurrent: () => current,
      clearCache: () async => actions.add('cache'),
      clearWaveform: () {
        actions.add('clear');
        return clearGate.future;
      },
      loadWaveform: () async => actions.add('load'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(actions, ['cache', 'clear']);
    current = false;
    clearGate.complete();
    expect(await reload, isFalse);
    expect(actions, ['cache', 'clear']);
  });

  test('already invalidated reload performs no destructive work', () async {
    final actions = <String>[];
    final completed = await StudioDockWaveformReloadGuard.run(
      isCurrent: () => false,
      clearCache: () async => actions.add('cache'),
      clearWaveform: () async => actions.add('clear'),
      loadWaveform: () async => actions.add('load'),
    );
    expect(completed, isFalse);
    expect(actions, isEmpty);
  });
}
