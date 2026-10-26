import 'package:flutter/material.dart';
import 'package:subtitle_studio/services/subtitle_quality_checker.dart';
import 'studio_dock_quality_profile_dialog.dart';

enum _QualityView { issues, fixes, timing }

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

class StudioDockQualityApplyTiming extends StudioDockQualityResult {
  const StudioDockQualityApplyTiming(this.suggestions);
  final List<SubtitleQualityTimingSuggestion> suggestions;
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
    this.canApplyTiming = false,
  });

  final List<SubtitleQualityCue> cues;
  final SubtitleQualityPreset initialPreset;
  final SubtitleQualityProfile customProfile;
  final ValueChanged<SubtitleQualityPreset>? onPresetChanged;
  final ValueChanged<SubtitleQualityProfile>? onCustomProfileChanged;
  final bool canApply;
  final bool canApplyTiming;

  @override
  State<StudioDockQualityDialog> createState() =>
      _StudioDockQualityDialogState();
}

class _StudioDockQualityDialogState extends State<StudioDockQualityDialog> {
  SubtitleQualityIssueType? _filter;
  late SubtitleQualityPreset _preset = widget.initialPreset;
  late SubtitleQualityProfile _customProfile = widget.customProfile;
  _QualityView _view = _QualityView.issues;
  final Set<int> _selectedFixCueIds = {};
  final Set<int> _selectedTimingCueIds = {};

  Future<void> _editCustomProfile() async {
    final updated = await showDialog<SubtitleQualityProfile>(
      context: context,
      builder: (_) => StudioDockQualityProfileDialog(profile: _customProfile),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _customProfile = updated;
      _filter = null;
      _selectedFixCueIds.clear();
      _selectedTimingCueIds.clear();
    });
    widget.onCustomProfileChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _preset == SubtitleQualityPreset.custom
        ? _customProfile : _preset.profile;
    final report = SubtitleQualityChecker.scan(
      widget.cues,
      profile: profile,
    );
    final suggestions = SubtitleQualityChecker.proposeSafeFixes(
        widget.cues, profile: profile);
    final timingIdeas = SubtitleQualityChecker.proposeTimingSuggestions(
        widget.cues, profile: profile);
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
    final selectedTiming = timingIdeas
        .where((idea) => _selectedTimingCueIds.contains(idea.cueId))
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
                    _selectedFixCueIds.clear();
                    _selectedTimingCueIds.clear();
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
            Wrap(spacing: 8, runSpacing: 2, children: [
              TextButton.icon(
                key: const ValueKey('studio-quality-issues-tab'),
                onPressed: () => setState(() => _view = _QualityView.issues),
                icon: Icon(_view != _QualityView.issues
                    ? Icons.list_alt_outlined : Icons.fact_check_outlined),
                label: Text('Issues (${report.issues.length})'),
              ),
              TextButton.icon(
                key: const ValueKey('studio-quality-fixes-tab'),
                onPressed: () => setState(() => _view = _QualityView.fixes),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text('Suggested fixes (${suggestions.length})'),
              ),
              TextButton.icon(
                key: const ValueKey('studio-quality-timing-tab'),
                onPressed: () => setState(() => _view = _QualityView.timing),
                icon: const Icon(Icons.schedule_outlined),
                label: Text('Timing ideas (${timingIdeas.length})'),
              ),
            ]),
            if (_view == _QualityView.issues && types.isNotEmpty)
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
            Flexible(child: _view == _QualityView.fixes
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
                : _view == _QualityView.timing
                    ? timingIdeas.isEmpty
                        ? const Center(child: Text(
                            'No conservative timing suggestions available.'))
                        : ListView.separated(
                            key: const ValueKey('studio-quality-timing-ideas'),
                            shrinkWrap: true,
                            itemCount: timingIdeas.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final idea = timingIdeas[index];
                              final title = Text('#${idea.cueId} · End-time preview');
                              final details = Text(
                                'END: ${idea.beforeEnd} → ${idea.proposedEnd}'
                                '\n${idea.detail}'
                                '\n${widget.canApplyTiming
                                    ? 'Select to apply, or inspect manually.'
                                    : 'Preview only — tap to inspect manually.'}',
                              );
                              if (widget.canApplyTiming) {
                                return CheckboxListTile(
                                  key: ValueKey('studio-quality-timing-${idea.cueId}'),
                                  dense: true,
                                  value: _selectedTimingCueIds.contains(idea.cueId),
                                  onChanged: (checked) => setState(() {
                                    if (checked == true) {
                                      _selectedTimingCueIds.add(idea.cueId);
                                    } else {
                                      _selectedTimingCueIds.remove(idea.cueId);
                                    }
                                  }),
                                  secondary: IconButton(
                                    key: ValueKey('studio-quality-timing-open-${idea.cueId}'),
                                    tooltip: 'Inspect subtitle ${idea.cueId}',
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () => Navigator.pop(context,
                                        StudioDockQualityNavigate(idea.cueId)),
                                  ),
                                  title: title,
                                  subtitle: details,
                                );
                              }
                              return ListTile(
                                key: ValueKey('studio-quality-timing-${idea.cueId}'),
                                dense: true,
                                leading: const Icon(Icons.schedule_outlined),
                                title: title,
                                subtitle: details,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(context,
                                    StudioDockQualityNavigate(idea.cueId)),
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
              if (_view == _QualityView.fixes) ...[
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
              if (_view == _QualityView.timing && widget.canApplyTiming) ...[
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('studio-quality-apply-timing'),
                  onPressed: selectedTiming.isNotEmpty
                      ? () => Navigator.pop(context,
                          StudioDockQualityApplyTiming(selectedTiming))
                      : null,
                  child: Text('Apply ${selectedTiming.length} timing changes'),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
