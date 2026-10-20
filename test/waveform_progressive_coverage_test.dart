import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_progressive_coverage.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_window_preview.dart';

WaveformWindowPreview segment(WaveformProgressiveRequest request,
    {int sampleRate = 10}) {
  final samples = request.end.inMicroseconds ~/
      1000000 * sampleRate -
      request.start.inMicroseconds ~/ 1000000 * sampleRate;
  final pcm = Int16List.fromList(List<int>.generate(samples,
      (index) => index.isEven ? -1200 : 2400));
  return WaveformWindowPreview.fromPcm(
    start: request.start,
    pcm: pcm,
    sampleRate: sampleRate,
  );
}

void main() {
  test('plan nearest viewport windows without duplicating in-flight work', () {
    final service = WaveformProgressiveCoverage(
      sourceRevision: 'stable-file-v1',
      trackIdentity: 'ffmpeg:stream:4',
      mediaDuration: const Duration(minutes: 5),
    );
    final first = service.claimVisible(
      start: const Duration(seconds: 45),
      end: const Duration(seconds: 125),
      playhead: const Duration(seconds: 90),
    );
    expect(first.map((w) => w.index).toList(), [2, 3, 1]);
    expect(service.pendingWindowCount, 3);
    expect(service.claimVisible(
      start: const Duration(seconds: 45),
      end: const Duration(seconds: 125),
      playhead: const Duration(seconds: 90),
    ).map((w) => w.index), [4]);
    expect(service.claimVisible(
      start: const Duration(seconds: 45),
      end: const Duration(seconds: 125),
    ), isEmpty);
  });

  test('partial coverage never represents unknown regions as silence', () {
    final service = WaveformProgressiveCoverage(
      sourceRevision: 'clip-v1',
      trackIdentity: 'auto',
      mediaDuration: const Duration(seconds: 100),
    );
    final selected = service.claimVisible(
      start: Duration.zero,
      end: const Duration(seconds: 70),
      playhead: const Duration(seconds: 2),
      limit: 1,
    ).single;
    expect(selected.index, 0);
    expect(service.publish(selected, segment(selected)), isTrue);

    final covers = service.coverage(
      start: const Duration(seconds: 15),
      end: const Duration(seconds: 75),
    );
    expect(covers.length, 3);
    expect(covers[0].isKnown, isTrue);
    expect(covers[0].start, const Duration(seconds: 15));
    expect(covers[0].end, const Duration(seconds: 30));
    expect(covers[1].isKnown, isFalse);
    expect(covers[1].preview, isNull);
    expect(covers[2].isKnown, isFalse);
    expect(covers[2].end, const Duration(seconds: 75));
  });

  test('different stream/source invalidates ready and in-flight windows', () {
    final service = WaveformProgressiveCoverage(
      sourceRevision: 'file-revision-a',
      trackIdentity: 'auto',
      mediaDuration: const Duration(minutes: 2),
    );
    final old = service.claimVisible(
      start: Duration.zero,
      end: const Duration(seconds: 40),
    );
    expect(service.publish(old.first, segment(old.first)), isTrue);
    expect(service.loadedWindowCount, 1);
    service.retarget(sourceRevision: 'file-revision-a',
        trackIdentity: 'ffmpeg:stream:5');
    expect(service.loadedWindowCount, 0);
    expect(service.pendingWindowCount, 0);
    expect(service.publish(old.last, segment(old.last)), isFalse);
    final current = service.claimVisible(
      start: Duration.zero,
      end: const Duration(seconds: 40),
    );
    expect(current.map((r) => r.index), [0, 1]);
    service.retarget(sourceRevision: 'file-revision-a',
        trackIdentity: 'ffmpeg:stream:5');
    expect(service.pendingWindowCount, 2,
        reason: 'Same source and track keep their active work');
    service.retarget(sourceRevision: 'file-revision-b',
        trackIdentity: 'ffmpeg:stream:5');
    expect(service.pendingWindowCount, 0);
  });

  test('last window is clamped at media end and cannot be truncated', () {
    final service = WaveformProgressiveCoverage(
      sourceRevision: 'short-clip',
      trackIdentity: 'auto',
      mediaDuration: const Duration(seconds: 95),
    );
    final last = service.claimVisible(
      start: const Duration(seconds: 90),
      end: const Duration(seconds: 95),
    ).single;
    expect(last.start, const Duration(seconds: 90));
    expect(last.end, const Duration(seconds: 95));
    final invalid = WaveformWindowPreview.fromPcm(
      start: last.start,
      pcm: Int16List(30),
      sampleRate: 10,
    );
    expect(() => service.publish(last, invalid, sampleRate: 10),
        throwsFormatException);
    expect(service.loadedWindowCount, 0);
    service.cancel(last);
    expect(service.pendingWindowCount, 0);
    final retry = service.claimVisible(
      start: const Duration(seconds: 90),
      end: const Duration(seconds: 95),
    ).single;
    expect(service.publish(retry, segment(retry), sampleRate: 10), isTrue);
    expect(service.coverage(
      start: const Duration(seconds: 94),
      end: const Duration(seconds: 95),
    ).single.isKnown, isTrue);
  });

  test('claims never exceed eight concurrent native windows', () {
    final service = WaveformProgressiveCoverage(
      sourceRevision: 'memory-safe',
      trackIdentity: 'auto',
      mediaDuration: const Duration(minutes: 10),
    );
    final first = service.claimVisible(
      start: Duration.zero,
      end: const Duration(minutes: 10),
      limit: 8,
    );
    expect(first, hasLength(8));
    expect(service.claimVisible(
      start: Duration.zero,
      end: const Duration(minutes: 10),
      limit: 8,
    ), isEmpty);
    service.cancel(first.first);
    expect(service.claimVisible(
      start: Duration.zero,
      end: const Duration(minutes: 10),
      limit: 8,
    ), hasLength(1));
    expect(service.pendingWindowCount, 8);
  });

  test('requests from another coverage instance cannot publish or cancel',
      () {
    WaveformProgressiveCoverage makeCoverage() =>
        WaveformProgressiveCoverage(
          sourceRevision: 'same',
          trackIdentity: 'auto',
          mediaDuration: const Duration(minutes: 1),
        );
    final old = makeCoverage();
    final current = makeCoverage();
    final oldToken = old.claimVisible(
      start: Duration.zero,
      end: const Duration(seconds: 30),
    ).single;
    current.claimVisible(
      start: Duration.zero,
      end: const Duration(seconds: 30),
    );
    current.cancel(oldToken);
    expect(current.pendingWindowCount, 1);
    expect(current.publish(oldToken, segment(oldToken)), isFalse);
    expect(current.loadedWindowCount, 0);
  });

  test('reject invalid viewports and source identities before scheduling', () {
    expect(() => WaveformProgressiveCoverage(
      sourceRevision: ' ',
      trackIdentity: 'auto',
      mediaDuration: const Duration(seconds: 60),
    ), throwsArgumentError);
    final service = WaveformProgressiveCoverage(
      sourceRevision: 'stable',
      trackIdentity: 'auto',
      mediaDuration: const Duration(seconds: 60),
    );
    expect(() => service.claimVisible(
      start: const Duration(seconds: 25),
      end: const Duration(seconds: 25),
    ), throwsRangeError);
    expect(() => service.coverage(
      start: Duration.zero,
      end: const Duration(seconds: 61),
    ), throwsRangeError);
    expect(() => service.claimVisible(
      start: Duration.zero,
      end: const Duration(seconds: 60),
      limit: 100,
    ), throwsRangeError);
  });
}
