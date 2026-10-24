import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Future<void> Function(BuildContext)? banners,
    Future<void> Function(BuildContext)? normalize,
    Future<void> Function()? submit,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => StudioDockWorkspace(
        isLiveSession: true,
        initialCues: const [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:02,000', original: 'Source', edited: 'മലയാളം'),
        ],
        onApplyCueText: (_, __) async => true,
        onSubmitToMsone: submit,
        onInsertMsoneBanners: banners == null ? null : () => banners(context),
        onNormalizeMalayalam: normalize == null ? null : () => normalize(context),
      ),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String menuLabel) async {
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(menuLabel).last);
    await tester.pumpAndSettle();
  }

  Future<void> Function(BuildContext) modal(String title) =>
      (context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SizedBox(
          height: 300,
          child: Column(children: [
            Text(title),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Close sheet'),
            ),
          ]),
        ),
      );

  testWidgets('MSone-specific tools remain hidden with feature setting off',
      (tester) async {
    await launch(tester, submit: () async {});
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Insert MSone Banners…'), findsNothing);
    expect(find.text('Malayalam Normalize…'), findsNothing);
    expect(find.text('Submit to MSone'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-tool-msone-banners')), findsNothing);
    expect(find.byKey(const ValueKey('studio-tool-msone-normalize')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools popup closes before banner/normalizer shared sheets',
      (tester) async {
    var openedBanner = 0;
    var openedNormalize = 0;
    await launch(tester,
      banners: (context) { openedBanner++; return modal('Banner sheet')(context); },
      normalize: (context) {
        openedNormalize++;
        return modal('Normalization sheet')(context);
      },
    );
    await choose(tester, 'Insert MSone Banners…');
    expect(find.text('Banner sheet'), findsOneWidget);
    await tester.tap(find.text('Close sheet'));
    await tester.pumpAndSettle();
    await choose(tester, 'Malayalam Normalize…');
    expect(find.text('Normalization sheet'), findsOneWidget);
    await tester.tap(find.text('Close sheet'));
    await tester.pumpAndSettle();
    expect(openedBanner, 1);
    expect(openedNormalize, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unsaved edit Cancel prevents opening either MSone tool',
      (tester) async {
    var opened = 0;
    await launch(tester, banners: (_) async { opened++; },
        normalize: (_) async { opened++; });
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Unsaved subtitle change');
    await tester.pump();
    await choose(tester, 'Malayalam Normalize…');
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.text('Unsaved subtitle change'), findsWidgets);
    await choose(tester, 'Insert MSone Banners…');
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools panel opens both gated operations', (tester) async {
    var banners = 0;
    var normalizations = 0;
    await launch(tester,
      banners: (_) async { banners++; },
      normalize: (_) async { normalizations++; },
    );
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    final banner = find.byKey(const ValueKey('studio-tool-msone-banners'));
    await tester.ensureVisible(banner);
    await tester.pumpAndSettle();
    await tester.tap(banner);
    await tester.pumpAndSettle();
    final normalize = find.byKey(const ValueKey('studio-tool-msone-normalize'));
    await tester.ensureVisible(normalize);
    await tester.pumpAndSettle();
    await tester.tap(normalize);
    await tester.pumpAndSettle();
    expect(banners, 1);
    expect(normalizations, 1);
    expect(tester.takeException(), isNull);
  });
}
