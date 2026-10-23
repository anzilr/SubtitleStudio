import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_navigation_guard.dart';

void main() {
  test('latest asynchronous load wins, even when older request ends last',
      () async {
    final guard = EditLineNavigationGuard();
    final first = Completer<void>();
    final second = Completer<void>();

    Future<String?> load(String cue, Completer<void> pending) async {
      final generation = guard.beginLoad();
      await pending.future;
      return guard.isCurrent(generation) ? cue : null;
    }

    final a = load('first', first);
    final b = load('second', second);
    second.complete();
    expect(await b, 'second');
    first.complete();
    expect(await a, isNull);
  });

  test('navigation is exclusive across delayed save and reload', () async {
    final guard = EditLineNavigationGuard();
    final pending = Completer<void>();
    final executed = <String>[];

    final first = guard.runExclusive(() async {
      executed.add('save start');
      await pending.future;
      executed.add('load after save');
    });
    expect(guard.isNavigating, isTrue);
    await guard.runExclusive(() async { executed.add('second tap'); });
    expect(executed, ['save start']);
    pending.complete();
    await first;
    expect(executed, ['save start', 'load after save']);
    expect(guard.isNavigating, isFalse);
    await guard.runExclusive(() async { executed.add('third tap'); });
    expect(executed.last, 'third tap');
  });

  test('route disposal invalidates pending loads and later actions', () async {
    final guard = EditLineNavigationGuard();
    final generation = guard.beginLoad();
    final pending = Completer<void>();
    var applied = false;
    final load = () async {
      await pending.future;
      if (guard.isCurrent(generation)) applied = true;
    }();
    guard.dispose();
    pending.complete();
    await load;
    expect(applied, isFalse);
    expect(guard.beginLoad(), isNull);
    await guard.runExclusive(() async { applied = true; });
    expect(applied, isFalse);
  });

  test('navigation lock releases after a failing callback', () async {
    final guard = EditLineNavigationGuard();
    await expectLater(
      guard.runExclusive(() async { throw StateError('save failed'); }),
      throwsStateError,
    );
    expect(guard.isNavigating, isFalse);
    var retried = false;
    await guard.runExclusive(() async { retried = true; });
    expect(retried, isTrue);
  });

  test('an old load token is invalid even if no new load completes',
      () async {
    final guard = EditLineNavigationGuard();
    final oldToken = guard.beginLoad();
    final newToken = guard.beginLoad();
    expect(guard.isCurrent(oldToken), isFalse);
    expect(guard.isCurrent(newToken), isTrue);
    guard.dispose();
    expect(guard.isCurrent(newToken), isFalse);
  });
}
