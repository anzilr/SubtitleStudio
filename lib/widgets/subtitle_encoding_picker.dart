import 'package:flutter/material.dart';

/// Searchable, keyboard-accessible charset chooser shared by import/export.
/// The caller passes the runtime-verified list; no unsupported codec is
/// presented as selectable.
class SubtitleEncodingPicker {
  const SubtitleEncodingPicker._();

  static Future<String?> show({
    required BuildContext context,
    required List<String> options,
    required String selected,
    String title = 'Text encoding',
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _EncodingPickerDialog(
        options: options,
        selected: selected,
        title: title,
      ),
    );
  }
}

class _EncodingPickerDialog extends StatefulWidget {
  const _EncodingPickerDialog({
    required this.options,
    required this.selected,
    required this.title,
  });

  final List<String> options;
  final String selected;
  final String title;

  @override
  State<_EncodingPickerDialog> createState() => _EncodingPickerDialogState();
}

class _EncodingPickerDialogState extends State<_EncodingPickerDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((item) =>
      item.toLowerCase().contains(_filter.trim().toLowerCase())).toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        height: 400,
        child: Column(children: [
          TextField(
            key: const ValueKey('encoding-search-field'),
            autofocus: true,
            onChanged: (value) => setState(() => _filter = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search encodings',
              hintText: 'Example: Windows-1256 or EUC-KR',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No matching encodings'))
                : ListView.builder(
                    key: const ValueKey('encoding-search-results'),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final name = filtered[index];
                      return ListTile(
                        key: ValueKey('encoding-choice-$name'),
                        dense: true,
                        title: Text(name),
                        selected: name == widget.selected,
                        trailing: name == widget.selected
                            ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.of(context).pop(name),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
