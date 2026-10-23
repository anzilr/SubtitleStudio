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
      WidgetBuilder? classicHomeBuilder,
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
          classicHomeBuilder: classicHomeBuilder,
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

  testWidgets('classic import unmounts the desktop media owner until return',
      (tester) async {
    var activeOwners = 0;
    var totalMounts = 0;
    await launch(
      tester,
      StudioDockSessionCatalog([session(1, 'Original.srt')], 1),
      sessionBuilder: (selected, choose) => _TrackedSessionView(
        title: selected.fileName,
        onSwitch: choose,
        onMount: () {
          activeOwners++;
          totalMounts++;
        },
        onDispose: () => activeOwners--,
      ),
      classicHomeBuilder: (_) => Scaffold(
        body: Center(child: TextButton(
          key: const ValueKey('return-from-classic'),
          onPressed: () => Navigator.of(_).pop(),
          child: const Text('Return from classic'),
        )),
      ),
    );
    expect(activeOwners, 1);
    await tester.tap(find.byKey(const ValueKey('studio-dock-switch-project')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-dock-classic-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('return-from-classic')),
        findsOneWidget);
    expect(activeOwners, 0,
      reason: 'Root Studio Dock must release native player before classic Home');
    await tester.tap(find.byKey(const ValueKey('return-from-classic')));
    await tester.pumpAndSettle();
    expect(activeOwners, 1);
    expect(totalMounts, 2);
    expect(find.text('Original.srt'), findsOneWidget);
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

class _TrackedSessionView extends StatefulWidget {
  const _TrackedSessionView({
    required this.title,
    required this.onSwitch,
    required this.onMount,
    required this.onDispose,
  });
  final String title;
  final VoidCallback onSwitch;
  final VoidCallback onMount;
  final VoidCallback onDispose;

  @override
  State<_TrackedSessionView> createState() => _TrackedSessionViewState();
}

class _TrackedSessionViewState extends State<_TrackedSessionView> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      Text(widget.title),
      TextButton(
        key: const ValueKey('studio-dock-switch-project'),
        onPressed: widget.onSwitch,
        child: const Text('Switch project'),
      ),
    ]),
  );
}
