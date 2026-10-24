import 'package:flutter/material.dart';
import 'package:subtitle_studio/utils/subtitle_positioning_parser.dart';
import 'package:subtitle_studio/utils/text_formatting.dart';

/// Adapts the app's existing subtitle tag editors to a whole-cue Style tab.
/// Returned strings are drafts; callers persist them with the shared edited-
/// text checkpoint transaction, never with a separate style database field.
abstract final class StudioDockStyleActions {
  static String body(String text) =>
      SubtitlePositioningParser.removePositioningCode(text);

  static int alignment(String text) =>
      SubtitlePositioningParser.getPositionCode(text) ?? 2;

  static String setAlignment(String text, int code) {
    if (code < 1 || code > 9) throw RangeError.range(code, 1, 9, 'code');
    final clean = body(text);
    return '{\\an$code}$clean';
  }

  static String toggleTag(String text, String tag) {
    if (!const {'b', 'i', 'u'}.contains(tag)) {
      throw ArgumentError.value(tag, 'tag', 'Unsupported subtitle tag');
    }
    final positioning = SubtitlePositioningParser.getPositionCode(text);
    final raw = body(text);
    if (raw.isEmpty) return text;
    final controller = TextEditingController(text: raw)
      ..selection = TextSelection(baseOffset: 0, extentOffset: raw.length);
    try {
      toggleTextFormatting(controller: controller, tag: tag);
      return (positioning == null ? '' : '{\\an$positioning}') +
          controller.text;
    } finally {
      controller.dispose();
    }
  }

  static String clearSupportedTags(String text) => text.replaceAll(
    RegExp(r'</?(?:b|i|u)>|<font\b[^>]*>|</font>|\{\\an[1-9]\}',
        caseSensitive: false),
    '',
  );
}
