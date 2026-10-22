import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_media_request_coordinator.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_video_path_write_queue.dart';

void main() {
  group('Edit Line media request lifecycle', () {
    test('a newer seek supersedes a delayed older player readiness result',
        () async {
      final coordinator = EditLineMediaRequestCoordinator();
      final firstReady = Completer<void>();
      var staleSeekApplied = false;
      final firstToken = coordinator.beginSeek();
      final first = () async {
        await firstReady.future;
        if (coordinator.isCurrentSeek(firstToken)) staleSeekApplied = true;
      }();
      final latestToken = coordinator.beginSeek();
      expect(coordinator.isCurrentSeek(firstToken), isFalse);
      expect(coordinator.isCurrentSeek(latestToken), isTrue);
      firstReady.complete();
      await first;
      expect(staleSeekApplied, isFalse);
    });

    test('video replacement cancels old seek and player-state callbacks', () {
      final coordinator = EditLineMediaRequestCoordinator();
      final seek = coordinator.beginSeek();
      final media = coordinator.captureMedia();
      coordinator.invalidateMedia();
      expect(coordinator.isCurrentSeek(seek), isFalse);
      expect(coordinator.isCurrentMedia(media), isFalse);
      expect(coordinator.isCurrentMedia(coordinator.captureMedia()), isTrue);
    });

    test('unload invalidates an unfinished picker selection', () {
      final coordinator = EditLineMediaRequestCoordinator();
      final picked = coordinator.beginPicker();
      expect(coordinator.isCurrentPicker(picked), isTrue);
      coordinator.invalidatePicker();
      expect(coordinator.isCurrentPicker(picked), isFalse);
      expect(coordinator.isCurrentPicker(coordinator.beginPicker()), isTrue);
    });

    test('only the most recently opened file picker result is accepted', () {
      final coordinator = EditLineMediaRequestCoordinator();
      final old = coordinator.beginPicker();
      final latest = coordinator.beginPicker();
      expect(coordinator.isCurrentPicker(old), isFalse);
      expect(coordinator.isCurrentPicker(latest), isTrue);
    });

    test('disposing the route prevents all late media/picker callbacks', () {
      final coordinator = EditLineMediaRequestCoordinator();
      final seek = coordinator.beginSeek();
      final media = coordinator.captureMedia();
      final picker = coordinator.beginPicker();
      coordinator.dispose();
      expect(coordinator.isCurrentSeek(seek), isFalse);
      expect(coordinator.isCurrentMedia(media), isFalse);
      expect(coordinator.isCurrentPicker(picker), isFalse);
      expect(coordinator.beginSeek(), isNull);
      expect(coordinator.captureMedia(), isNull);
      expect(coordinator.beginPicker(), isNull);
      coordinator.invalidateMedia();
      coordinator.invalidatePicker();
    });
  });

  group('Edit Line video path writes', () {
    test('Unload waits for a pending save and wins in storage order', () async {
      final gate = Completer<void>();
      final operations = <String>[];
      final queue = EditLineVideoPathWriteQueue(
        save: (path) async {
          await gate.future;
          operations.add('save:$path');
        },
        clear: () async => operations.add('clear'),
      );
      final saving = queue.savePath('movie.mkv');
      final unloading = queue.clearPath();
      await Future<void>.delayed(Duration.zero);
      expect(operations, isEmpty);
      gate.complete();
      await Future.wait([saving, unloading]);
      expect(operations, ['save:movie.mkv', 'clear']);
    });

    test('a failed path save does not block a subsequent Unload', () async {
      final operations = <String>[];
      final queue = EditLineVideoPathWriteQueue(
        save: (_) async => throw StateError('not writable'),
        clear: () async => operations.add('clear'),
      );
      await expectLater(queue.savePath('movie.mkv'), throwsStateError);
      await queue.clearPath();
      expect(operations, ['clear']);
    });

    test('multiple replacements and Unload preserve user operation order',
        () async {
      final operations = <String>[];
      final queue = EditLineVideoPathWriteQueue(
        save: (path) async => operations.add(path),
        clear: () async => operations.add('unloaded'),
      );
      await Future.wait([
        queue.savePath('A'),
        queue.savePath('B'),
        queue.clearPath(),
        queue.savePath('C'),
      ]);
      expect(operations, ['A', 'B', 'unloaded', 'C']);
    });
  });
}
