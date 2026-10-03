import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/dictionary_search_widget.dart';
import 'package:subtitle_studio/widgets/olam_dictionary_widget.dart';
import 'package:subtitle_studio/widgets/urban_dictionary_widget.dart';

Future<void> showOlamDictionarySheet({
  required BuildContext context,
  required String initialSearchTerm,
  required ValueChanged<String> onSelectTranslation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => OlamDictionaryWidget(
      onSelectTranslation: (text) {
        onSelectTranslation(text);
        Navigator.pop(sheetContext);
      },
      initialSearchTerm: initialSearchTerm,
    ),
  );
}

Future<void> showUrbanDictionarySheet({
  required BuildContext context,
  required String initialSearchTerm,
  required ValueChanged<String> onSelectTranslation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => UrbanDictionaryWidget(
      onSelectTranslation: (text) {
        onSelectTranslation(text);
        Navigator.pop(sheetContext);
      },
      initialSearchTerm: initialSearchTerm,
    ),
  );
}

Future<void> showMsoneDictionarySheet({
  required BuildContext context,
  required String initialSearchTerm,
  required ValueChanged<String> onSelectTranslation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.95,
      child: DictionarySearchWidget(
        onSelectTranslation: (text) {
          onSelectTranslation(text);
          Navigator.pop(sheetContext);
        },
        initialSearchTerm: initialSearchTerm,
      ),
    ),
  );
}
