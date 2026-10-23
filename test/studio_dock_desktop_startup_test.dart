import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_desktop_home.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _cue(String original) => SubtitleLine()
  ..index = 1
  ..startTime = '00:00:01,000'
  ..endTime = '00:00:02,000'
  ..original = original
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

Future<Session> _seed(TestIsarHarness db, String name) async {
  final collection = SubtitleCollection(
    fileName: name, encoding: 'UTF-8', lines: [_cue(name)],
  );
  late Session session;
  await db.isar.writeTxn(() async {
    await db.isar.subtitleCollections.put(collection);
    session = Session(
      fileName: name, subtitleCollectionId: collection.id,
    );
    await db.isar.sessions.put(session);
  });
  return session;
}

void main() {
  late TestIsarHarness db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await TestIsarHarness.open();
  });
  tearDown(() async => db.close());

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [isarProvider.overrideWithValue(db.isar)],
      child: const MaterialApp(home: StudioDockDesktopHome()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('native desktop host directly opens the last session in Studio Dock',
      (tester) async {
    await _seed(db, 'First.srt');
    final last = await _seed(db, 'Last.srt');
    await db.isar.writeTxn(() async {
      await db.isar.preferences.put(
        Preferences(autoSave: false, lastEditedSession: last.id),
      );
    });

    await launch(tester);
    expect(find.text('LIVE · TEXT EDIT'), findsOneWidget);
    expect(find.text('Last.srt'), findsWidgets);
    expect(find.byKey(const ValueKey('studio-dock-switch-project')),
        findsOneWidget);
    expect(find.text('First.srt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switch project opens real sessions without returning to old Home',
      (tester) async {
    final first = await _seed(db, 'First.srt');
    await _seed(db, 'Second.srt');
    await launch(tester);

    await tester.tap(find.byKey(const ValueKey('studio-dock-switch-project')));
    await tester.pumpAndSettle();
    expect(find.text('Studio Dock — Projects'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('studio-dock-project-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text('First.srt'), findsWidgets);
    expect(find.text('LIVE · TEXT EDIT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty desktop database shows Studio Dock welcome, not classic Home',
      (tester) async {
    await launch(tester);
    expect(find.text('Welcome to Studio Dock'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-dock-import-first')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
