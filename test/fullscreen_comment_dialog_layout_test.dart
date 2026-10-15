import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/comment_dialog.dart';

void main() {
  testWidgets('comment editor can open and cancel in a short landscape window',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: CommentDialog(
                  originalText: 'Example subtitle line',
                  subtitleIndex: 3,
                  onCommentSaved: (_) {},
                ),
              ),
            ),
          ),
          child: const Text('Open comment editor'),
        )),
      ),
    ));

    await tester.tap(find.text('Open comment editor'));
    await tester.pumpAndSettle();

    expect(find.text('Add Comment'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Add Comment'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
