import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/isolated_loader.dart';

void main() {
  testWidgets('hiding a route-owned loader restores taps to the previous screen',
      (tester) async {
    var homeTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => homeTapCount++,
                  child: const Text('Home action'),
                ),
                TextButton(
                  onPressed: () => IsolatedLoaderController.show(context),
                  child: const Text('Show loader'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show loader'));
    await tester.pump();
    expect(find.byType(IsolatedLoader), findsOneWidget);

    // The editor's loader lives in the Navigator overlay, not in the editor
    // subtree; it must be explicitly cleared before the Home route resumes.
    IsolatedLoaderController.hide();
    await tester.pump();
    expect(find.byType(IsolatedLoader), findsNothing);

    await tester.tap(find.text('Home action'));
    await tester.pump();
    expect(homeTapCount, 1);
  });
}
