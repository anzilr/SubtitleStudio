import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/comment_dialog.dart';

void main() {
  testWidgets('portrait comment modal replaces the fullscreen overlay and returns',
      (tester) async {
    final controlsKey = GlobalKey();
    late BuildContext editorContext;
    OverlayEntry makeFullscreenEntry() => OverlayEntry(
      builder: (_) => Material(
        key: controlsKey,
        color: Colors.black,
        child: const Center(child: Text('Fullscreen player')),
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            editorContext = context;
            return const Center(child: Text('Editor beneath player'));
          },
        ),
      ),
    ));

    var videoOverlay = makeFullscreenEntry();
    Overlay.of(editorContext).insert(videoOverlay);
    await tester.pump();
    expect(find.text('Fullscreen player'), findsOneWidget);

    // The overlay inserted manually by the player must be removed before
    // a modal route and its keyboard can take the foreground.
    videoOverlay.remove();
    videoOverlay.dispose();
    await tester.pump();
    expect(find.text('Fullscreen player'), findsNothing);

    final dialogFuture = showGeneralDialog<void>(
      context: editorContext,
      barrierDismissible: true,
      barrierLabel: 'Dismiss comment',
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) => Dialog(
        child: CommentDialog(
          isOverlayMode: true,
          subtitleIndex: 4,
          originalText: 'Example line',
          onCommentSaved: (_) {},
          onCancelled: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add Comment'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await dialogFuture;

    // Fullscreen controls can safely reuse their GlobalKey after the route
    // and the previous video overlay are fully unmounted.
    videoOverlay = makeFullscreenEntry();
    Overlay.of(editorContext).insert(videoOverlay);
    await tester.pump();
    expect(find.text('Fullscreen player'), findsOneWidget);
    expect(tester.takeException(), isNull);
    videoOverlay.remove();
    videoOverlay.dispose();
    await tester.pump();
  });
}
