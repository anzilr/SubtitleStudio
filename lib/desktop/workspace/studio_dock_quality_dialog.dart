import 'package:flutter/material.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';
import 'studio_dock_quality_profile_dialog.dart';

sealed class StudioDockQualityResult {
  const StudioDockQualityResult();
}

class StudioDockQualityNavigate extends StudioDockQualityResult {
  const StudioDockQualityNavigate(this.cueId);
  final int cueId;
}

class StudioDockQualityApply extends StudioDockQualityResult {
  const StudioDockQualityApply(this.fixes);
  final List<SubtitleQualityFix> fixes;
}

/// Studio Dock's quality review is a preview, not an editor. The parent owns
/// guarded navigation and the single-history-transaction apply callback.
class StudioDockQualityDialog extends StatefulWidget {
  const StudioDockQualityDialog({
    super.key,
    required this.cues,
    this.initialPreset = SubtitleQualityPreset.general,
    this.customProfile = const SubtitleQualityProfile(),
    this.onPresetChanged,
    this.onCustomProfileChanged,
    this.canApply = false,
  });

  final List<SubtitleQualityCue> cues;
  final SubtitleQualityPreset initialPreset;
  final SubtitleQualityProfile customProfile;
  final ValueChanged<SubtitleQualityPreset>? onPresetChanged;
  final ValueChanged<SubtitleQualityProfile>? onCustomProfileChanged;
  final bool canApply;

  @override
  State<StudioDockQualityDialog> createState() =>
      _StudioDockQualityDialogState();
}

class _StudioDockQualityDialogState extends State<StudioDockQualityDialog> {
  SubtitleQualityIssueType? _filter;
  late SubtitleQualityPreset _preset = widget.initialPreset;
  late SubtitleQualityProfile _customProfile = widget.customProfile;
  bool _showSuggestions = false;
  final Set<int> _selectedFixCueIds = {};

  Future<void> _editCustomProfile() async {
    final updated = await showDialog<SubtitleQualityProfile>(
      context: context,
      builder: (_) => StudioDockQualityProfileDialog(profile: _customProfile),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _customProfile = updated;
      _filter = null;
    });
    widget.onCustomProfileChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final report = SubtitleQualityChecker.scan(
      widget.cues,
      profile: _preset == SubtitleQualityPreset.custom
          ? _customProfile : _preset.profile,
    );
    final suggestions = SubtitleQualityChecker.proposeSafeFixes(widget.cues);
    final types = SubtitleQualityIssueType.values
        .where((type) => report.count(type) > 0)
        .toList(growable: false);
    final visible = _filter == null
        ? report.issues
        : report.issues
            .where((issue) => issue.type == _filter)
            .toList(growable: false);
    final selected = suggestions
        .where((fix) => _selectedFixCueIds.contains(fix.cueId))
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
            Row(children: [
              Expanded(child: Text(
                report.issues.isEmpty
                    ? 'No issues detected in ${widget.cues.length} subtitles.'
                    : '${report.issues.length} issues in '
                        '${report.affectedCues} of '
                        '${widget.cues.length} subtitles',
                key: const ValueKey('studio-quality-summary'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              )),
              const SizedBox(width: 12),
              DropdownButton<SubtitleQualityPreset>(
                key: const ValueKey('studio-quality-profile'),
                value: _preset,
                items: [
                  for (final preset in SubtitleQualityPreset.values)
                    DropdownMenuItem(value: preset, child: Text(preset.label)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _preset = value;
                    _filter = null;
                  });
                  widget.onPresetChanged?.call(value);
                },
              ),
              if (_preset == SubtitleQualityPreset.custom)
                IconButton(
                  key: const ValueKey('studio-quality-edit-profile'),
                  tooltip: 'Edit custom quality limits',
                  icon: const Icon(Icons.tune),
                  onPressed: _editCustomProfile,
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              TextButton.icon(
                key: const ValueKey('studio-quality-issues-tab'),
                onPressed: () => setState(() => _showSuggestions = false),
                icon: Icon(_showSuggestions
                    ? Icons.list_alt_outlined : Icons.fact_check_outlined),
                label: Text('Issues (${report.issues.length})'),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                key: const ValueKey('studio-quality-fixes-tab'),
                onPressed: () => setState(() => _showSuggestions = true),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text('Suggested fixes (${suggestions.length})'),
              ),
            ]),
            if (!_showSuggestions && types.isNotEmpty)
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
                      child: Text('All issues (${report.issues.length})'),
                    ),
                    for (final type in types)
                      DropdownMenuItem<SubtitleQualityIssueType?>(
                        value: type,
                        child: Text('${type.label} (${report.count(type)})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _filter = value),
                )),
              ]),
            const SizedBox(height: 8),
            Flexible(child: _showSuggestions
                ? suggestions.isEmpty
                    ? const Center(child: Text('No safe fixes to suggest.'))
                    : ListView.separated(
                        key: const ValueKey('studio-quality-suggestions'),
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final fix = suggestions[index];
                          return CheckboxListTile(
                            key: ValueKey('studio-quality-fix-${fix.cueId}'),
                            dense: true,
                            value: _selectedFixCueIds.contains(fix.cueId),
                            onChanged: widget.canApply
                                ? (checked) => setState(() {
                                    if (checked == true) {
                                      _selectedFixCueIds.add(fix.cueId);
                                    } else {
                                      _selectedFixCueIds.remove(fix.cueId);
                                    }
                                  })
                                : null,
                            title: Text('#${fix.cueId} · ${fix.description}'),
                            subtitle: Text(
                              'Before: ${fix.before}\nAfter: ${fix.after}',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      )
                : visible.isEmpty
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              issue.text.isEmpty
                                  ? issue.detail
                                  : '${issue.detail}\n${issue.text}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context,
                                StudioDockQualityNavigate(issue.cueId)),
                          );
                        },
                      )),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (_showSuggestions) ...[
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('studio-quality-apply-fixes'),
                  onPressed: widget.canApply && selected.isNotEmpty
                      ? () => Navigator.pop(context,
                          StudioDockQualityApply(selected))
                      : null,
                  child: Text('Apply ${selected.length} fixes'),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
