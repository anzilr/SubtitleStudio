import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/repositories/editor_preferences_repository.dart';

import 'support/test_isar_harness.dart';

void main() {
  test('desktop MSone availability uses the existing persisted feature flag',
      () async {
    final db = await TestIsarHarness.open();
    try {
      final prefs = EditorPreferencesRepository(db.isar);
      expect(await prefs.getMsoneEnabled(), isFalse);
      await prefs.setMsoneEnabled(true);
      expect(await EditorPreferencesRepository(db.isar).getMsoneEnabled(),
          isTrue);
      await prefs.setMsoneEnabled(false);
      expect(await EditorPreferencesRepository(db.isar).getMsoneEnabled(),
          isFalse);
    } finally {
      await db.close();
    }
  });
}
