import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_waveform_surface.dart';

void main() {
  Future<void> mount(WidgetTester tester, {
    required bool visible,
    required bool ready,
    required bool busy,
    required VoidCallback onVisibility,
    required VoidCallback onRegenerate,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(
          width: 440, height: 40,
          child: StudioDockWaveformToolbar(
            visible: visible, canRegenerate: ready, busy: busy,
            onToggleVisibility: onVisibility, onRegenerate: onRegenerate,
          ),
        )),
      ),
    ));
  }

  testWidgets('visible waveform can be hidden without regenerating audio',
      (tester) async {
    var visibilityCalls = 0;
    var regenerationCalls = 0;
    await mount(tester, visible: true, ready: true, busy: false,
      onVisibility: () => visibilityCalls++,
      onRegenerate: () => regenerationCalls++,
    );
    expect(find.text('Hide'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-waveform-visibility')));
    expect(visibilityCalls, 1);
    expect(regenerationCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden waveform exposes Generate and direct Regenerate',
      (tester) async {
    var shown = 0;
    var regenerated = 0;
    await mount(tester, visible: false, ready: true, busy: false,
      onVisibility: () => shown++,
      onRegenerate: () => regenerated++,
    );
    expect(find.text('Generate'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-waveform-visibility')));
    await tester.tap(find.byKey(const ValueKey('studio-waveform-regenerate')));
    expect(shown, 1);
    expect(regenerated, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('regeneration is unavailable before audio track resolution',
      (tester) async {
    var regenerations = 0;
    await mount(tester, visible: true, ready: false, busy: false,
      onVisibility: () {},
      onRegenerate: () => regenerations++,
    );
    final button = tester.widget<TextButton>(
        find.byKey(const ValueKey('studio-waveform-regenerate')));
    expect(button.onPressed, isNull);
    expect(regenerations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy waveform disables commands without losing progress',
      (tester) async {
    var calls = 0;
    await mount(tester, visible: true, ready: true, busy: true,
      onVisibility: () => calls++,
      onRegenerate: () => calls++,
    );
    final visibility = tester.widget<TextButton>(
        find.byKey(const ValueKey('studio-waveform-visibility')));
    final regenerate = tester.widget<TextButton>(
        find.byKey(const ValueKey('studio-waveform-regenerate')));
    expect(visibility.onPressed, isNull);
    expect(regenerate.onPressed, isNull);
    expect(find.text('Loading…'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
