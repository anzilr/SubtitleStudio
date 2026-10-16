import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/widgets/project_settings/project_encoding_selector.dart';

void main() {
  test('project encoding candidate catalogue is broader than legacy dropdown', () {
    expect(SubtitleTextCodec.supportedEncodings, contains('UTF-16LE BOM'));
    expect(SubtitleExtendedEncodingService.extendedEncodings,
        containsAll(['Windows-1256', 'Shift_JIS', 'EUC-KR', 'GB18030']));
    expect(
      SubtitleTextCodec.supportedEncodings.length +
          SubtitleExtendedEncodingService.extendedEncodings.length,
      greaterThan(5),
    );
  });

  testWidgets('project selector searches device-verified encoding options',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectEncodingSelector(
          selected: 'UTF-8',
          options: const ['UTF-8', 'UTF-16LE BOM', 'Windows-1256', 'GB18030'],
          isLoading: false,
          isSaving: false,
          onSelected: (value) async { chosen = value; },
        ),
      ),
    ));

    expect(find.text('4 encodings available on this device. '
        'Search to choose a different encoding.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-encoding-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Project text encoding'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('encoding-search-field')),
      '1256',
    );
    await tester.pumpAndSettle();
    expect(find.text('Windows-1256'), findsOneWidget);
    expect(find.text('GB18030'), findsNothing);

    await tester.tap(find.byKey(
      const ValueKey('encoding-choice-Windows-1256'),
    ));
    await tester.pumpAndSettle();
    expect(chosen, 'Windows-1256');
  });

  testWidgets('unavailable stored charset stays visible and can be corrected',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectEncodingSelector(
          selected: 'Shift_JIS',
          options: const ['UTF-8', 'Windows-1252'],
          isLoading: false,
          isSaving: false,
          onSelected: (value) async { chosen = value; },
        ),
      ),
    ));

    expect(find.text('Shift_JIS'), findsOneWidget);
    expect(find.textContaining('saved encoding is unavailable'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-encoding-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('encoding-choice-Shift_JIS')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('encoding-choice-UTF-8')));
    await tester.pumpAndSettle();
    expect(chosen, 'UTF-8');
  });

  testWidgets('project selector is disabled while probing or saving',
      (tester) async {
    Future<void> unused(String _) async {}
    Future<void> render({required bool loading, required bool saving}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProjectEncodingSelector(
            selected: 'UTF-8',
            options: const ['UTF-8', 'ISO-8859-1'],
            isLoading: loading,
            isSaving: saving,
            onSelected: unused,
          ),
        ),
      ));
    }

    await render(loading: true, saving: false);
    expect(find.textContaining('Checking supported encodings'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('project-encoding-picker')),
    );
    expect(button.onPressed, isNull);

    await render(loading: false, saving: true);
    expect(find.textContaining('Saving project encoding'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('project-encoding-picker')),
    ).onPressed, isNull);
  });
}
