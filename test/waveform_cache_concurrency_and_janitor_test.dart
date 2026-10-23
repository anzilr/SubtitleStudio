import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_cache_coordinator.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_peak_cache_janitor.dart';

void main() {
  group('source-scoped cache coordination', () {
    test('same cache never overlaps, FIFO waiters share a queued key', () async {
      final manager = WaveformCacheCoordinator.shared;
      final held = Completer<void>();
      final arrived = Completer<void>();
      final events = <String>[];
      final first = manager.runExclusive('waveform/one', () async {
        events.add('first:begin');
        arrived.complete();
        await held.future;
        events.add('first:end');
        return 42;
      });
      await arrived.future;
      final second = manager.runExclusive('waveform/one', () async {
        events.add('second:begin');
        return 24;
      });
      expect(manager.pendingKeys, greaterThan(0));
      await Future<void>.delayed(Duration.zero);
      expect(events, ['first:begin']);
      held.complete();
      expect(await first, 42);
      expect(await second, 24);
      expect(events, ['first:begin', 'first:end', 'second:begin']);
      expect(manager.pendingKeys, 0);
    });

    test('different media cache keys are independent', () async {
      final manager = WaveformCacheCoordinator.shared;
      final gate = Completer<void>();
      final initial = Completer<void>();
      final hold = manager.runExclusive('song-a', () async {
        initial.complete();
        await gate.future;
      });
      await initial.future;
      final other = await manager.runExclusive('song-b', () async => 'ready');
      expect(other, 'ready');
      gate.complete();
      await hold;
      expect(manager.pendingKeys, 0);
    });

    test('failed writer unblocks next waiter and lock is released', () async {
      final manager = WaveformCacheCoordinator.shared;
      final entered = Completer<void>();
      final gate = Completer<void>();
      final failed = manager.runExclusive('error-key', () async {
        entered.complete();
        await gate.future;
        throw const FormatException('Broken old extraction');
      });
      await entered.future;
      final recovered = manager.runExclusive('error-key', () async => 7);
      gate.complete();
      await expectLater(failed, throwsFormatException);
      expect(await recovered, 7);
      expect(manager.pendingKeys, 0);
    });

    test('superseded waiter never writes after reaching the lock', () async {
      final manager = WaveformCacheCoordinator.shared;
      final gate = Completer<void>();
      final held = Completer<void>();
      final first = manager.runExclusive('epoch-key', () async {
        held.complete();
        await gate.future;
      });
      await held.future;
      var epoch = 1;
      var built = false;
      final waiting = manager.runExclusive('epoch-key', () async {
        if (epoch != 1) throw StateError('Cancelled while queued');
        built = true;
      });
      epoch = 2;
      gate.complete();
      await first;
      await expectLater(waiting, throwsStateError);
      expect(built, false);
    });
  });

  group('conservative cache janitor', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('waveform_janitor_');
    });
    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    Future<File> make(String name, {int daysOld = 0}) async {
      final file = File(directory.path + Platform.pathSeparator + name);
      await file.writeAsBytes([1, 2, 3]);
      if (daysOld > 0) {
        await file.setLastModified(
            DateTime.now().subtract(Duration(days: daysOld)));
      }
      return file;
    }

    test('only old owned cache and abandoned partials are removed', () async {
      final expired = await make('waveform_audio_11_deadbeef.pk1', daysOld: 40);
      final partial = await make(
          'waveform_audio_11_deadbeef.pk1.partial.12345', daysOld: 3);
      final fresh = await make('waveform_audio_11_feedface.pk1');
      final raw = await make('waveform_audio_11_deadbeef.raw', daysOld: 40);
      final unrelated = await make('birthday_audio.pk1', daysOld: 40);
      final removed = await const WaveformPeakCacheJanitor().clean(directory);
      expect(removed, 2);
      expect(await expired.exists(), isFalse);
      expect(await partial.exists(), isFalse);
      expect(await fresh.exists(), isTrue);
      expect(await raw.exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
    });

    test('protected cache is retained even if old', () async {
      final active = await make(
          'waveform_audio_3_12345678.pk1', daysOld: 90);
      final removed = await const WaveformPeakCacheJanitor().clean(directory,
          protectedPaths: {active.path});
      expect(removed, 0);
      expect(await active.exists(), isTrue);
    });

    test('scan limit rejects invalid input and bounds directory traversal',
        () async {
      final first = await make(
          'waveform_audio_5_deadbeef.pk1', daysOld: 50);
      final file = await make(
          'waveform_audio_6_deadbeef.pk1', daysOld: 50);
      await expectLater(
        const WaveformPeakCacheJanitor().clean(directory, scanLimit: 0),
        throwsArgumentError,
      );
      final removed = await const WaveformPeakCacheJanitor().clean(
          directory, scanLimit: 1);
      expect(removed, lessThanOrEqualTo(1));
      expect(await first.exists() || await file.exists(), isTrue);
    });
  });
}
