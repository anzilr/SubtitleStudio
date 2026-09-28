import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/edit_controller.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';

void main() {
  testWidgets(
    'editor controller uses configuration from nested ProviderScope',
    (tester) async {
      int? collectionId;
      int? sessionId;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProviderScope(
              overrides: [
                editConfigurationProvider.overrideWithValue(
                  const EditConfiguration(
                    subtitleCollectionId: 123,
                    sessionId: 456,
                  ),
                ),
              ],
              child: Consumer(
                builder: (context, ref, child) {
                  final controller =
                      ref.watch(editControllerProvider.notifier);
                  collectionId = controller.subtitleCollectionId;
                  sessionId = controller.sessionId;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(collectionId, 123);
      expect(sessionId, 456);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edit-line controller uses configuration from nested ProviderScope',
    (tester) async {
      int? sessionId;
      bool? isNewSubtitle;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProviderScope(
              overrides: [
                editLineConfigurationProvider.overrideWithValue(
                  const EditLineConfiguration(
                    subtitleCollectionId: 12,
                    lineIndex: 3,
                    sessionId: 789,
                    isNewSubtitle: true,
                    isEditMode: true,
                  ),
                ),
              ],
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(editLineControllerProvider);
                  sessionId = state.sessionId;
                  isNewSubtitle = state.isNewSubtitle;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(sessionId, 789);
      expect(isNewSubtitle, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
