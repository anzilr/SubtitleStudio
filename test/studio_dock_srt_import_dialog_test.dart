import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_srt_import_dialog.dart';

void main() {
  late Directory directory;
  late File source;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('studio_srt_import_');
    source = File('${directory.path}/example.srt');
    source.writeAsBytesSync([
      ...'1\n00:00:01,000 --> 00:00:02,000\nIt'.codeUnits,
      0x92, ...'s a preview\n'.codeUnits,
    ]);
  });
  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<ValueNotifier<StudioDockSrtImportChoice?>> launch(
      WidgetTester tester) async {
    final result = ValueNotifier<StudioDockSrtImportChoice?>(null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final choice = await showDialog<StudioDockSrtImportChoice>(
            context: context,
            builder: (_) => StudioDockSrtImportDialog(
              filePath: source.path,
              readBytes: (_) async => Uint8List.fromList([
                ...'1\n00:00:01,000 --> 00:00:02,000\nIt'.codeUnits,
                0x92, ...'s a preview\n'.codeUnits,
              ]),
              availableEncodings: () async =>
                  const ['UTF-8', 'Windows-1252'],
            ),
          );
          result.value = choice;
        },
        child: const Text('Open import options'),
      ),
    ))));
    await tester.tap(find.text('Open import options'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Cancel leaves import untouched', (tester) async {
    final result = await launch(tester);
    expect(find.text('Import SRT'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-cancel')));
    await tester.pumpAndSettle();
    expect(result.value, isNull);
    expect(source.lengthSync(), greaterThan(0));
  });

  testWidgets('encoding selection drives preview and confirmed import choice',
      (tester) async {
    final result = await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-encoding')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Windows-1252').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-srt-import-preview-text')),
        findsOneWidget);
    expect(find.textContaining('It\u2019s a preview'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-confirm')));
    await tester.pumpAndSettle();
    expect(result.value?.encoding, 'Windows-1252');
    expect(result.value?.removeHearingImpaired, isFalse);
    expect(result.value?.mergeOverlapping, isFalse);
  });

  testWidgets('optional cleanup and overlap merge are explicit opt-ins',
      (tester) async {
    final result = await launch(tester);
    await tester.ensureVisible(find.byKey(
        const ValueKey('studio-srt-import-hearing-cleanup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-srt-import-hearing-cleanup')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(
        const ValueKey('studio-srt-import-merge-overlaps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-srt-import-merge-overlaps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-confirm')));
    await tester.pumpAndSettle();
    expect(result.value?.encoding, isNull);
    expect(result.value?.removeHearingImpaired, isTrue);
    expect(result.value?.mergeOverlapping, isTrue);
  });
}
