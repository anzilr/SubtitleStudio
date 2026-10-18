import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/msone_input_diagnostics.dart';

void main() {
  testWidgets('root probe describes the actual hit-tested modal barrier',
      (tester) async {
    final prints = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) prints.add(message);
    };
    try {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: MsoneInputDiagnostics.onRootPointer,
        onPointerUp: MsoneInputDiagnostics.onRootPointerUp,
        child: child!,
      ),
      home: Scaffold(
        body: Builder(builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const AlertDialog(
                title: Text('Blocking dialog'),
              ),
            ),
            child: const Text('Open dialog'),
          ),
        )),
      ),
    ));

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    MsoneInputDiagnostics.watchAfterReturn();
    await tester.tapAt(const Offset(30, 200));
    await tester.pump();
    expect(prints.any((line) => line.contains('MSone input: ROOT')), isTrue);
    expect(prints.any((line) => line.contains('MSone input: HITTEST')),
        isTrue);
    expect(prints.any((line) => line.contains('MSone input: ROOT pointer-up')),
        isTrue);
    expect(prints.any((line) => line.contains('ModalBarrier') ||
        line.contains('RenderPointerListener')), isTrue);
    } finally {
      // Flutter validates framework globals *before* addTearDown callbacks.
      // Restore this debugPrint override synchronously within the test body.
      debugPrint = oldDebugPrint;
    }
  });
}
