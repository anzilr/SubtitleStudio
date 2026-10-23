import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_desktop_home.dart';

Session session(int id, String fileName) =>
    Session(fileName: fileName, subtitleCollectionId: id * 10)..id = id;

void main() {
  Future<void> launch(WidgetTester tester,
      StudioDockSessionCatalog catalog, {
      Widget Function(Session, VoidCallback)? sessionBuilder,
      Future<String?> Function(BuildContext)? pickFile,
    }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: StudioDockDesktopHome(
          loadSessions: () async => catalog,
          // Test only the desktop startup and project-selection policy.
          // Separate Isar integration tests verify actual repository reads.
          pickFile: pickFile,
          sessionViewBuilder: sessionBuilder ?? (active, onChoose) => Scaffold(
            body: Column(children: [
              const Text('LIVE · TEXT EDIT'),
              Text(active.fileName),
              TextButton(
                key: const ValueKey('studio-dock-switch-project'),
                onPressed: onChoose,
                child: const Text('Switch project'),
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop starts in Studio Dock with the last session',
      (tester) async {
    await launch(tester, StudioDockSessionCatalog(
      [session(1, 'First.srt'), session(2, 'Last.srt')], 2));
    expect(find.text('LIVE · TEXT EDIT'), findsOneWidget);
    expect(find.text('Last.srt'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-dock-switch-project')),
        findsOneWidget);
    expect(find.text('First.srt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project selection stays within the desktop host',
      (tester) async {
    await launch(tester, StudioDockSessionCatalog(
      [session(1, 'First.srt'), session(2, 'Second.srt')], 2));
    await tester.tap(find.byKey(const ValueKey('studio-dock-switch-project')));
    await tester.pumpAndSettle();
    expect(find.text('Studio Dock — Projects'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-dock-project-1')));
    await tester.pumpAndSettle();
    expect(find.text('First.srt'), findsOneWidget);
    expect(find.text('LIVE · TEXT EDIT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project dialog contains only Studio Dock import/create flows',
      (tester) async {
    await launch(tester, StudioDockSessionCatalog(
      [session(1, 'Original.srt')], 1), pickFile: (_) async => null);
    await tester.tap(find.byKey(const ValueKey('studio-dock-switch-project')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-dock-classic-home')),
        findsNothing);
    expect(find.byKey(const ValueKey('studio-dock-import-project')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('studio-dock-create-project')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-dock-import-project')));
    await tester.pumpAndSettle();
    expect(find.text('Original.srt'), findsOneWidget,
      reason: 'Cancelling a file picker must leave current project unchanged');
    expect(tester.takeException(), isNull);
  });

  testWidgets('new project requires explicit Create; cancel does not persist',
      (tester) async {
    await launch(tester, const StudioDockSessionCatalog([], null));
    await tester.tap(find.byKey(const ValueKey('studio-dock-create-first')));
    await tester.pumpAndSettle();
    expect(find.text('New Studio Dock project'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Studio Dock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty desktop catalog shows Studio Dock landing',
      (tester) async {
    await launch(tester, const StudioDockSessionCatalog([], null));
    expect(find.text('Welcome to Studio Dock'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-dock-import-first')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

