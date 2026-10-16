import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A lightweight source-level guard for the UI surfaces migrated during the
/// final theme consistency pass. Real subtitle color tags, authored palettes,
/// media artwork and fixed white-on-black video captions are *not* UI accents
/// and are covered by their separate rendering/integration tests.
void main() {
  test('audited UI surfaces do not reintroduce branded fixed accent colors',
      () {
    const auditedSurfaces = [
      'lib/widgets/dictionary_search_widget.dart',
      'lib/widgets/comment_dialog.dart',
      'lib/widgets/banner_configuration_sheet.dart',
      'lib/widgets/banner_configuration_sheet_new.dart',
      'lib/widgets/search_replace_sheet.dart',
      'lib/widgets/checkpoint_sheet.dart',
      'lib/widgets/feedback_widget.dart',
      'lib/widgets/log_management_widget.dart',
      'lib/widgets/malayalam_normalization_sheet.dart',
      'lib/widgets/export_file_widget.dart',
      'lib/widgets/import_comments_sheet.dart',
      'lib/widgets/import_project_sheet.dart',
      'lib/widgets/subtitle_import_options_sheet.dart',
      'lib/widgets/subtitle_extract_options_sheet.dart',
      'lib/widgets/subtitle_sync_sheet.dart',
      'lib/widgets/merge_confirmation_sheet.dart',
      'lib/widgets/split_confirmation_sheet.dart',
      'lib/widgets/add_line_confirmation_sheet.dart',
      'lib/widgets/file_replace_dialog.dart',
      'lib/widgets/create_subtitle_sheet.dart',
      'lib/widgets/secondary_subtitle_sheet.dart',
      'lib/widgets/session_selection/locate_srt_sheet.dart',
      'lib/widgets/video/repeat_range_dialog.dart',
      'lib/widgets/video/player_settings_button.dart',
      'lib/widgets/video/player_toggle_controls.dart',
      'lib/widgets/video/custom_video_controls.dart',
      'lib/widgets/video/fullscreen_controls.dart',
      'lib/features/waveform/widgets/waveform_rendering.dart',
      'lib/screens/home/widgets/session_card.dart',
      'lib/screens/edit/widgets/edit_placeholders.dart',
      'lib/screens/edit_line/widgets/edit_line_placeholders.dart',
    ];

    // Semantic action/error/warning colors must come from ColorScheme or
    // StudioDesignTokens, not unrelated blues, greens and oranges.
    final banned = RegExp(
      r'\bColors\.(?:blue|green|orange|red|purple|deepPurple|teal|indigo)\b'
      r'|\bColor\(0xFF(?:4A90E2|2A9D8F|0A9396|00695C)\)',
    );
    for (final path in auditedSurfaces) {
      final text = File(path).readAsStringSync();
      expect(
        banned.allMatches(text).isEmpty,
        isTrue,
        reason: 'Fixed decorative/status palette in $path. '
            'Use theme roles, or explicitly document a real media/content '
            'color exception outside this guard.',
      );
    }
  });
}
