import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/dictionary_search_action.dart';

void main() {
  for (final skin in StudioSkin.values) {
    for (final appearance in StudioAppearance.values) {
      testWidgets('Dictionary search follows $skin/$appearance contrast',
          (tester) async {
        final theme = StudioThemeFactory.resolve(skin, appearance);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(body: DictionarySearchAction(onPressed: () {})),
        ));
        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.style?.backgroundColor?.resolve({}),
            theme.colorScheme.primary);
        expect(button.style?.foregroundColor?.resolve({}),
            theme.colorScheme.onPrimary);
        expect(tester.widget<Icon>(find.byIcon(Icons.search)).color, isNull);
        expect(tester.widget<Text>(find.text('Search')).style?.color, isNull);
      });
    }
  }
}
