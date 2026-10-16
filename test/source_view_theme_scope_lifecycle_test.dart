import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/source_view/source_view_controller.dart';
import 'package:subtitle_studio/screens/source_view/source_view_screen_host.dart';
import 'package:subtitle_studio/screens/source_view/source_view_state.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';

class _TrackingSourceController extends SourceViewController {
  static int builds = 0;

  @override
  SourceViewState build() {
    final config = ref.watch(sourceViewConfigProvider);
    builds++;
    return SourceViewState.initial(
      filePath: config.filePath,
      displayName: config.displayName,
      safUri: config.safUri,
    );
  }
}

void main() {
  testWidgets('Source View provider remains mounted through all nine modes',
      (tester) async {
    _TrackingSourceController.builds = 0;
    final selection = ValueNotifier<int>(0);
    addTearDown(selection.dispose);
    final modes = [
      for (final skin in StudioSkin.values)
        for (final appearance in StudioAppearance.values)
          (skin, appearance),
    ];

    await tester.pumpWidget(ProviderScope(
      child: ValueListenableBuilder<int>(
        valueListenable: selection,
        builder: (context, index, child) {
          final (skin, mode) = modes[index];
          return MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: StudioThemeFactory.resolve(skin, mode),
            home: Scaffold(
              body: SourceViewScreenHost(
                filePath: '/fixture/subtitle.srt',
                fileContent: '1\n00:00:01,000 --> 00:00:02,000\nമലയാളം',
                controllerFactory: _TrackingSourceController.new,
              ),
            ),
          );
        },
      ),
    ));
    await tester.pump();
    expect(_TrackingSourceController.builds, 1);
    for (var index = 1; index < modes.length; index++) {
      selection.value = index;
      await tester.pump(const Duration(milliseconds: 150));
      expect(_TrackingSourceController.builds, 1,
          reason: 'A new palette must not recreate the Source View scope');
      expect(tester.takeException(), isNull);
    }
  });
}
