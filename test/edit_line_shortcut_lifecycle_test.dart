import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_shortcut_lifecycle.dart';

void main() {
  test('route closed during Home handoff never registers Edit Line', () async {
    final preparing = Completer<void>();
    final events = <String>[];
    final lifecycle = EditLineShortcutLifecycle();
    final activation = lifecycle.activate(
      prepare: () async {
        events.add('prepare');
        await preparing.future;
      },
      register: () async => events.add('register'),
    );
    expect(events, ['prepare']);

    final closing = lifecycle.close(() async => events.add('unregister'));
    expect(lifecycle.isActive, isFalse);
    preparing.complete();
    await Future.wait([activation, closing]);
    expect(events, ['prepare', 'unregister']);
  });

  test('teardown waits until an in-progress desktop registration finishes',
      () async {
    final registering = Completer<void>();
    final events = <String>[];
    final lifecycle = EditLineShortcutLifecycle();
    final activation = lifecycle.activate(
      prepare: () async => events.add('prepare'),
      register: () async {
        events.add('register-start');
        await registering.future;
        events.add('register-end');
      },
    );
    await Future<void>.delayed(Duration.zero);
    final closing = lifecycle.close(() async => events.add('unregister'));
    expect(events, ['prepare', 'register-start']);
    registering.complete();
    await Future.wait([activation, closing]);
    expect(events,
        ['prepare', 'register-start', 'register-end', 'unregister']);
  });

  test('closing a never-opened route remains safe and idempotent', () async {
    final lifecycle = EditLineShortcutLifecycle();
    var cleanupCount = 0;
    final first = lifecycle.close(() async { cleanupCount++; });
    final second = lifecycle.close(() async { cleanupCount++; });
    await Future.wait([first, second]);
    expect(cleanupCount, 1);
    expect(lifecycle.isActive, isFalse);
    var registered = false;
    await lifecycle.activate(
      prepare: () async { registered = true; },
      register: () async { registered = true; },
    );
    expect(registered, isFalse);
  });

  test('failed partial registration still runs cleanup exactly once',
      () async {
    final lifecycle = EditLineShortcutLifecycle();
    final activation = lifecycle.activate(
      prepare: () async {},
      register: () async => throw StateError('partial registration'),
    );
    await expectLater(activation, throwsStateError);
    var released = 0;
    await lifecycle.close(() async { released++; });
    await lifecycle.close(() async { released++; });
    expect(released, 1);
  });

  test('callbacks associated with a closed screen cannot act', () async {
    final lifecycle = EditLineShortcutLifecycle();
    var calls = 0;
    void callback() {
      if (lifecycle.isActive) calls++;
    }
    callback();
    expect(calls, 1);
    await lifecycle.close(() async {});
    callback();
    expect(calls, 1);
  });

  test('repeated activation is not allowed to register twice', () async {
    final lifecycle = EditLineShortcutLifecycle();
    var prepared = 0;
    var registered = 0;
    final first = lifecycle.activate(
      prepare: () async { prepared++; },
      register: () async { registered++; },
    );
    final second = lifecycle.activate(
      prepare: () async { prepared++; },
      register: () async { registered++; },
    );
    await Future.wait([first, second]);
    expect(prepared, 1);
    expect(registered, 1);
    await lifecycle.close(() async {});
  });
}
