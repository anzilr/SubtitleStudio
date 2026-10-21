import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/services/editor_resize_preference_coordinator.dart';

void main() {
  testWidgets('desktop drags keep only the latest value after 300ms',
      (tester) async {
    final desktopWrites = <double>[];
    final mobileWrites = <double>[];
    final coordinator = EditorResizePreferenceCoordinator(
      saveDesktop: (value) async => desktopWrites.add(value),
      saveMobile: (value) async => mobileWrites.add(value),
    );

    coordinator.scheduleDesktop(0.40);
    await tester.pump(const Duration(milliseconds: 200));
    coordinator.scheduleDesktop(0.55);
    await tester.pump(const Duration(milliseconds: 299));
    expect(desktopWrites, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(desktopWrites, [0.55]);
    expect(mobileWrites, isEmpty);
    await coordinator.flushAndDispose();
  });

  testWidgets('mobile ratio uses its own 500ms timer', (tester) async {
    final desktopWrites = <double>[];
    final mobileWrites = <double>[];
    final coordinator = EditorResizePreferenceCoordinator(
      saveDesktop: (value) async => desktopWrites.add(value),
      saveMobile: (value) async => mobileWrites.add(value),
    );

    coordinator.scheduleMobile(0.44);
    coordinator.scheduleDesktop(0.63);
    await tester.pump(const Duration(milliseconds: 300));
    expect(desktopWrites, [0.63]);
    expect(mobileWrites, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    expect(mobileWrites, [0.44]);
    await coordinator.flushAndDispose();
  });

  testWidgets('closing route flushes both pending ratios once',
      (tester) async {
    final writes = <String>[];
    final coordinator = EditorResizePreferenceCoordinator(
      saveDesktop: (value) async => writes.add('desktop:$value'),
      saveMobile: (value) async => writes.add('mobile:$value'),
    );

    coordinator.scheduleDesktop(0.39);
    coordinator.scheduleDesktop(0.41);
    coordinator.scheduleMobile(0.72);
    await coordinator.flushAndDispose();
    expect(writes, containsAllInOrder(['desktop:0.41', 'mobile:0.72']));
    expect(writes, hasLength(2));

    await tester.pump(const Duration(seconds: 1));
    await coordinator.flushAndDispose();
    coordinator.scheduleDesktop(0.99);
    expect(writes, hasLength(2));
  });

  testWidgets('an in-flight desktop write cannot overwrite a newer value',
      (tester) async {
    final firstCompletion = Completer<void>();
    final writes = <double>[];
    final coordinator = EditorResizePreferenceCoordinator(
      saveDesktop: (value) {
        writes.add(value);
        return writes.length == 1 ? firstCompletion.future : Future.value();
      },
      saveMobile: (_) async {},
    );

    coordinator.scheduleDesktop(0.31);
    await tester.pump(const Duration(milliseconds: 300));
    expect(writes, [0.31]);

    coordinator.scheduleDesktop(0.61);
    await tester.pump(const Duration(milliseconds: 300));
    expect(writes, [0.31]);

    firstCompletion.complete();
    await coordinator.flushAndDispose();
    expect(writes, [0.31, 0.61]);
  });

  testWidgets('a failed write is reported without blocking future values',
      (tester) async {
    final saved = <double>[];
    final errors = <Object>[];
    final coordinator = EditorResizePreferenceCoordinator(
      saveDesktop: (value) async {
        if (value == 0.2) throw StateError('temporary failure');
        saved.add(value);
      },
      saveMobile: (_) async {},
      onSaveError: (error, _) => errors.add(error),
    );

    coordinator.scheduleDesktop(0.2);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    coordinator.scheduleDesktop(0.5);
    await coordinator.flushAndDispose();
    expect(errors, hasLength(1));
    expect(saved, [0.5]);
  });
}
