import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/edit_controller.dart';
import 'package:subtitle_studio/screens/edit/edit_screen_host.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_host.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_state.dart';
import 'package:subtitle_studio/themes/theme.dart';

// Use loading-only fake controllers: no Isar or video setup is necessary.
// The observed build count reflects disposal/reinitialization caused by
// replacing route-scoped overrides during an inherited theme rebuild.
class _TrackingEditController extends EditController {
  static int builds = 0;

  @override
  EditState build() {
    ref.watch(editConfigurationProvider);
    builds++;
    return EditState.initial();
  }

  @override
  Future<void> initialize({int? lastEditedIndex}) async {}
}

class _TrackingEditLineController extends EditLineController {
  static int builds = 0;

  @override
  EditLineState build() {
    final config = ref.watch(editLineConfigurationProvider);
    builds++;
    return EditLineState.initial(sessionId: config.sessionId);
  }

  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets('Editor theme rebuild does not restart route-scoped controller',
      (tester) async {
    _TrackingEditController.builds = 0;
    var dark = false;
    await tester.pumpWidget(ProviderScope(
      child: StatefulBuilder(builder: (context, setTheme) {
        return MaterialApp(
          theme: dark ? AppThemes.darkTheme : AppThemes.lightTheme,
          home: Scaffold(
            body: Column(children: [
              TextButton(
                key: const ValueKey('change-test-theme'),
                onPressed: () => setTheme(() => dark = !dark),
                child: const Text('Change theme'),
              ),
              Expanded(
                child: EditScreenHost(
                  subtitleCollectionId: 11,
                  sessionId: 9,
                  controllerFactory: _TrackingEditController.new,
                ),
              ),
            ]),
          ),
        );
      }),
    ));
    await tester.pump();
    expect(_TrackingEditController.builds, 1);
    expect(find.text('Loading...'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('change-test-theme')));
      // The fake keeps the loading spinner active intentionally; waiting for
      // all animations to settle would never finish.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_TrackingEditController.builds, 1,
          reason: 'Switching themes must not replace the Editor provider');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Edit Line theme rebuild preserves scoped controller',
      (tester) async {
    _TrackingEditLineController.builds = 0;
    var dark = false;
    await tester.pumpWidget(ProviderScope(
      child: StatefulBuilder(builder: (context, setTheme) {
        return MaterialApp(
          theme: dark ? AppThemes.darkTheme : AppThemes.lightTheme,
          home: Scaffold(
            body: Column(children: [
              TextButton(
                key: const ValueKey('change-line-theme'),
                onPressed: () => setTheme(() => dark = !dark),
                child: const Text('Change theme'),
              ),
              Expanded(
                child: EditSubtitleScreenHost(
                  subtitleId: 11,
                  index: 2,
                  sessionId: 9,
                  controllerFactory: _TrackingEditLineController.new,
                ),
              ),
            ]),
          ),
        );
      }),
    ));
    await tester.pump();
    expect(_TrackingEditLineController.builds, 1);
    expect(find.text('Loading subtitle...'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('change-line-theme')));
      // The fake keeps the loading spinner active intentionally; waiting for
      // all animations to settle would never finish.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_TrackingEditLineController.builds, 1,
          reason: 'Theme changes must not reset a line-editing session');
      expect(tester.takeException(), isNull);
    }
  });

  test('light Material surface is white and main accents stay consistent', () {
    final light = AppThemes.lightTheme;
    final dark = AppThemes.darkTheme;
    expect(light.scaffoldBackgroundColor, Colors.white);
    expect(light.colorScheme.surface, Colors.white);
    expect(light.colorScheme.primary, dark.colorScheme.primary);
    expect(light.colorScheme.onPrimary, Colors.white);
    expect(dark.colorScheme.onPrimary, Colors.white);
    expect(AppThemes.classicTheme.colorScheme.primary,
        dark.colorScheme.primary);
  });
}
