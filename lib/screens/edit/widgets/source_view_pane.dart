import 'package:flutter/material.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';
import 'package:subtitle_studio/utils/unicode_text_input_formatter.dart';

/// Direct SRT-style source editor used by the main Editor screen.
///
/// The entries remain owned by the parent Editor. This widget only renders and
/// mutates the provided entry objects, then notifies the parent that content
/// changed. Keeping persistence outside this widget preserves the existing
/// behavior while reducing the size of screen_edit.dart.
class SourceViewPane extends StatelessWidget {
  final List<SubtitleEntry> entries;
  final ScrollController scrollController;
  final VoidCallback onChanged;

  const SourceViewPane({
    super.key,
    required this.entries,
    required this.scrollController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Source View - ${entries.length} Subtitles',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Direct text editing mode',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              thickness: 8,
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return _SourceViewSubtitleTile(
                    entry: entries[index],
                    onChanged: onChanged,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceViewSubtitleTile extends StatelessWidget {
  final SubtitleEntry entry;
  final VoidCallback onChanged;

  const _SourceViewSubtitleTile({
    required this.entry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: entry.index,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                entry.index = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicWidth(
                child: TextFormField(
                  initialValue: entry.startTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.secondary,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    entry.startTime = value;
                    onChanged();
                  },
                ),
              ),
              Text(
                ' --> ',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
              ),
              IntrinsicWidth(
                child: TextFormField(
                  initialValue: entry.endTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.secondary,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    entry.endTime = value;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: entry.text,
            maxLines: null,
            inputFormatters: [
              UnicodeTextInputFormatter(),
            ],
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              entry.text = value;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
