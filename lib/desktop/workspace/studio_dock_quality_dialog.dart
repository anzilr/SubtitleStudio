import 'package:flutter/material.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';

/// Read-only quality report. Selecting an issue returns its cue ID to the
/// workspace, where existing guarded navigation handles any pending drafts.
class StudioDockQualityDialog extends StatefulWidget {
  const StudioDockQualityDialog({
    super.key,
    required this.report,
    required this.cueCount,
  });

  final SubtitleQualityReport report;
  final int cueCount;

  @override
  State<StudioDockQualityDialog> createState() =>
      _StudioDockQualityDialogState();
}

class _StudioDockQualityDialogState extends State<StudioDockQualityDialog> {
  SubtitleQualityIssueType? _filter;

  @override
  Widget build(BuildContext context) {
    final types = SubtitleQualityIssueType.values
        .where((type) => widget.report.count(type) > 0)
        .toList(growable: false);
    final visible = _filter == null
        ? widget.report.issues
        : widget.report.issues
            .where((issue) => issue.type == _filter)
            .toList(growable: false);
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 740,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.fact_check_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(child: Text('Subtitle Quality',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
              IconButton(
                key: const ValueKey('studio-quality-close'),
                tooltip: 'Close quality report',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.report.issues.isEmpty
                    ? 'No issues detected in ${widget.cueCount} subtitles.'
                    : '${widget.report.issues.length} issues in '
                        '${widget.report.affectedCues} of '
                        '${widget.cueCount} subtitles',
                key: const ValueKey('studio-quality-summary'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            if (types.isNotEmpty)
              Row(children: [
                const Text('Show: '),
                const SizedBox(width: 8),
                Expanded(child: DropdownButton<SubtitleQualityIssueType?>(
                  key: const ValueKey('studio-quality-filter'),
                  isExpanded: true,
                  value: _filter,
                  items: [
                    DropdownMenuItem<SubtitleQualityIssueType?>(
                      value: null,
                      child: Text('All issues (${widget.report.issues.length})'),
                    ),
                    for (final type in types)
                      DropdownMenuItem<SubtitleQualityIssueType?>(
                        value: type,
                        child: Text('${type.label} '
                            '(${widget.report.count(type)})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _filter = value),
                )),
              ]),
            const SizedBox(height: 8),
            Flexible(child: visible.isEmpty
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 45),
                    child: Text('No subtitle quality issues found.'),
                  ))
                : ListView.separated(
                    key: const ValueKey('studio-quality-issues'),
                    shrinkWrap: true,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final issue = visible[index];
                      return ListTile(
                        key: ValueKey('studio-quality-issue-'
                            '${issue.cueId}-${issue.type.name}'),
                        dense: true,
                        leading: SizedBox(
                          width: 45,
                          child: Center(child: Text('#${issue.cueId}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                        ),
                        title: Text(issue.type.label,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          issue.text.isEmpty
                              ? issue.detail
                              : '${issue.detail}\n${issue.text}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, issue.cueId),
                      );
                    },
                  )),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
