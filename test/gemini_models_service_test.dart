import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/gemini_models_service.dart';

void main() {
  group('GeminiModelsService.getModelDisplayName', () {
    test('formats normal model identifiers', () {
      expect(
        GeminiModelsService.getModelDisplayName(
          'models/gemini-2.5-flash',
        ),
        'Gemini 2.5 Flash',
      );
    });

    test('handles empty or separator-only model names safely', () {
      expect(
        GeminiModelsService.getModelDisplayName(''),
        'Unknown model',
      );
      expect(
        GeminiModelsService.getModelDisplayName('models/---'),
        'Unknown model',
      );
    });
  });
}
