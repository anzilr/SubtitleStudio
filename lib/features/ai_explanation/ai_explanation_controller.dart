import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/preferences_model.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

import 'ai_explanation_state.dart';

final aiExplanationControllerProvider =
    NotifierProvider<AiExplanationController, AiExplanationState>(
  AiExplanationController.new,
);

class AiExplanationController extends Notifier<AiExplanationState> {
  @override
  AiExplanationState build() => const AiExplanationInitial();

  Future<void> getExplanation({
    required String currentLine,
    List<String>? previousLines,
    List<String>? nextLines,
    String? modelName,
    String? customPrompt,
  }) async {
    String? model;
    String prompt = '';

    try {
      final apiKey = await PreferencesModel.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        state = const AiExplanationNoApiKey();
        return;
      }

      state = const AiExplanationLoading();

      Gemini.init(apiKey: apiKey);
      final gemini = Gemini.instance;

      model = modelName ?? await PreferencesModel.getGeminiModel();

      logInfo('Selected Gemini model: $model');

      final promptTemplate =
          customPrompt ?? await PreferencesModel.getAiExplanationPrompt();

      prompt = _buildPrompt(
        currentLine: currentLine,
        previousLines: previousLines ?? [],
        nextLines: nextLines ?? [],
        promptTemplate: promptTemplate,
      );

      logInfo('Requesting AI explanation using model: $model');

      final response = await gemini.text(prompt, modelName: model);

      if (response?.output == null || response!.output!.isEmpty) {
        state = const AiExplanationError(
          'No explanation received from AI. Please try again.',
        );
        return;
      }

      logInfo('Received AI explanation successfully');
      state = AiExplanationSuccess(response.output!);
    } catch (e, stackTrace) {
      logError('Error getting AI explanation: $e');
      logError('Stack trace: $stackTrace');
      logError('Model used: $model');
      logError('Prompt length: ${prompt.length} characters');

      String errorMessage = 'Failed to get explanation. ';

      if (e.runtimeType.toString().contains('GeminiException')) {
        logError('GeminiException details: $e');
        final errorString = e.toString();

        if (errorString.contains('429')) {
          errorMessage +=
              'Rate limit exceeded (429). You have made too many requests to the Gemini API.\n\n';
          errorMessage += 'Solutions:\n';
          errorMessage += '• Wait a few minutes before trying again\n';
          errorMessage += '• Check your API quota in Google Cloud Console\n';
          errorMessage +=
              '• Consider upgrading your API plan for higher limits\n';
          errorMessage +=
              '• Free tier limits depend on the currently configured Gemini model and API plan.';
        } else if (errorString.contains('API_KEY_INVALID') ||
            errorString.contains('invalid api key')) {
          errorMessage +=
              'Your API key is invalid. Please check your Gemini API key in settings.';
        } else if (errorString.contains('MODEL_NOT_FOUND') ||
            errorString.contains('model not found')) {
          errorMessage +=
              'The model "$model" was not found. Select another available model in settings.';
        } else if (errorString.contains('PERMISSION_DENIED') ||
            errorString.contains('permission denied')) {
          errorMessage +=
              'Permission denied. Your API key may not have access to the model "$model". Check your Google Cloud Console settings.';
        } else if (errorString.contains('RESOURCE_EXHAUSTED') ||
            errorString.contains('quota')) {
          errorMessage +=
              'API quota exceeded. Please check your quota limits in Google Cloud Console or try again later.';
        } else if (errorString.contains('400')) {
          errorMessage += 'Bad Request (400). This usually means:\n\n';
          errorMessage += '• The selected model may not be available\n';
          errorMessage +=
              '• Your API key may lack permissions for this model\n';
          errorMessage += '• The request format may be rejected\n\n';
          errorMessage +=
              'Check the configured model and API key, then try again.\n\n';
          errorMessage +=
              'Full error: ${_truncate(e.toString(), 200)}...';
        } else {
          errorMessage +=
              'Unexpected error.\n\nError details: ${_truncate(errorString, 300)}...';
        }
      } else {
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('401') ||
            errorString.contains('unauthorized')) {
          errorMessage +=
              'Unauthorized (401). Your API key is invalid or expired.';
        } else if (errorString.contains('403') ||
            errorString.contains('forbidden')) {
          errorMessage +=
              'Access forbidden (403). Your API key may not have permission to use this model.';
        } else if (errorString.contains('404')) {
          errorMessage +=
              'Model not found (404). The configured model does not exist.';
        } else if (errorString.contains('429')) {
          errorMessage +=
              'Rate limit exceeded (429). Too many requests. Please wait and try again.';
        } else if (errorString.contains('500') ||
            errorString.contains('503')) {
          errorMessage +=
              'Gemini service is temporarily unavailable. Please try again later.';
        } else if (errorString.contains('network') ||
            errorString.contains('connection') ||
            errorString.contains('socket')) {
          errorMessage +=
              'Network error. Please check your internet connection.';
        } else {
          errorMessage +=
              'Unexpected error occurred.\n\nError: ${_truncate(e.toString(), 300)}';
        }
      }

      state = AiExplanationError(errorMessage);
    }
  }

  String _buildPrompt({
    required String currentLine,
    required List<String> previousLines,
    required List<String> nextLines,
    String? promptTemplate,
  }) {
    final template = promptTemplate ??
        '''You are a helpful assistant that explains dialogue in movies, TV shows, or videos.
Analyze the following dialogue and provide a clear, concise explanation:

{CONTEXT}

Please provide:
1. The meaning of the dialogue in simple terms
2. Any cultural references, idioms, or wordplay explained
3. The emotional tone or subtext if relevant
4. How it relates to the surrounding context

Keep the explanation concise and easy to understand.''';

    final contextBuffer = StringBuffer();

    if (previousLines.isNotEmpty) {
      contextBuffer.writeln('Previous dialogue (for context):');
      for (final line in previousLines) {
        contextBuffer.writeln('- $line');
      }
      contextBuffer.writeln();
    }

    contextBuffer.writeln('Current dialogue (explain this):');
    contextBuffer.writeln('>>> $currentLine');
    contextBuffer.writeln();

    if (nextLines.isNotEmpty) {
      contextBuffer.writeln('Following dialogue (for context):');
      for (final line in nextLines) {
        contextBuffer.writeln('- $line');
      }
      contextBuffer.writeln();
    }

    return template.replaceAll(
      '{CONTEXT}',
      contextBuffer.toString().trim(),
    );
  }

  String _truncate(String value, int maxLength) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }

  void reset() {
    state = const AiExplanationInitial();
  }
}
