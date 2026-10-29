import 'package:flutter/material.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';

import 'studio_dock_project_actions.dart';

/// A native desktop preflight for portable project import. It makes the
/// destination and SRT association explicit before any database writes.
class StudioDockProjectImportDialog extends StatefulWidget {
  const StudioDockProjectImportDialog({
    super.key,
    required this.document,
    required this.targets,
    required this.archiveSrtAvailable,
    required this.existingSrtAvailability,
    this.pickSrtFile,
    this.validateSrtFile,
  });

  final ProjectDocument document;
  final List<StudioDockProjectImportTarget> targets;
  final bool archiveSrtAvailable;
  final Map<int, bool> existingSrtAvailability;
  final Future<String?> Function(BuildContext)? pickSrtFile;
  /// Injectable for widget tests; production validates the real local path.
  final Future<bool> Function(String)? validateSrtFile;

  @override
  State<StudioDockProjectImportDialog> createState() =>
      _StudioDockProjectImportDialogState();
}

class _StudioDockProjectImportDialogState
    extends State<StudioDockProjectImportDialog> {
  bool _replace = false;
  int? _targetId;
  StudioDockProjectSrtSource _source = StudioDockProjectSrtSource.unlinked;
  String? _locatedSrtPath;
  String? _fileError;
  bool _selectingFile = false;

  StudioDockProjectImportTarget? get _target {
    for (final target in widget.targets) {
      if (target.session.id == _targetId) return target;
    }
    return null;
  }

  bool get _existingAvailable =>
      _replace && widget.existingSrtAvailability[_targetId] == true;

  bool get _canImport =>
      !_selectingFile && (!_replace || _targetId != null) &&
      (_source != StudioDockProjectSrtSource.archive ||
          widget.archiveSrtAvailable) &&
      (_source != StudioDockProjectSrtSource.existingSession ||
          _existingAvailable) &&
      (_source != StudioDockProjectSrtSource.locatedFile ||
          _locatedSrtPath != null);

  Future<void> _locateSrt() async {
    setState(() { _selectingFile = true; _fileError = null; });
    try {
      final path = await (widget.pickSrtFile?.call(context) ??
          FilePickerSAF.pickFile(
            context: context,
            title: 'Locate subtitle SRT',
            allowedExtensions: const ['srt'],
          ));
      if (!mounted || path == null) return;
      if (!await (widget.validateSrtFile?.call(path) ??
          StudioDockProjectActions.isUsableSrtPath(path))) {
        if (mounted) setState(() => _fileError =
            'Choose a local SRT file that still exists.');
        return;
      }
      setState(() {
        _locatedSrtPath = path;
        _source = StudioDockProjectSrtSource.locatedFile;
      });
    } catch (_) {
      if (mounted) setState(() => _fileError =
          'The subtitle file could not be selected.');
    } finally {
      if (mounted) setState(() => _selectingFile = false);
    }
  }

  Widget _sourceTile({
    required StudioDockProjectSrtSource source,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final selected = _source == source;
    return ListTile(
      dense: true,
      key: ValueKey('studio-dock-msone-source-${source.name}'),
      enabled: enabled,
      leading: Icon(selected ? Icons.radio_button_checked :
          Icons.radio_button_unchecked),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      selected: selected,
      onTap: enabled ? () => setState(() => _source = source) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.document.subtitleCollection;
    final archiveSrt = StudioDockProjectActions.archivedSrtPath(widget.document);
    final target = _target;
    return AlertDialog(
      title: const Text('Import SubtitleStudio project'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subtitle.fileName ?? widget.document.session.fileName ??
                  'Imported project',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('${widget.document.totalLines} subtitle lines · '
                  '${widget.document.checkpoints.length} history points'),
              const SizedBox(height: 16),
              Text('Import destination',
                style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                ChoiceChip(
                  key: const ValueKey('studio-dock-msone-new'),
                  label: const Text('Import as new'),
                  selected: !_replace,
                  onSelected: (_) => setState(() {
                    _replace = false;
                    if (_source == StudioDockProjectSrtSource.existingSession) {
                      _source = StudioDockProjectSrtSource.unlinked;
                    }
                  }),
                ),
                ChoiceChip(
                  key: const ValueKey('studio-dock-msone-replace'),
                  label: const Text('Replace existing'),
                  selected: _replace,
                  onSelected: widget.targets.isEmpty ? null : (_) => setState(() {
                    _replace = true;
                    _targetId ??= widget.targets.first.session.id;
                  }),
                ),
              ]),
              if (_replace) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey('studio-dock-msone-target'),
                  initialValue: _targetId,
                  decoration: const InputDecoration(labelText: 'Project to replace'),
                  isExpanded: true,
                  items: [
                    for (final entry in widget.targets)
                      DropdownMenuItem<int>(
                        value: entry.session.id,
                        child: Text(entry.session.fileName,
                          overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    _targetId = id;
                    if (_source == StudioDockProjectSrtSource.existingSession &&
                        !_existingAvailable) {
                      _source = StudioDockProjectSrtSource.unlinked;
                    }
                  }),
                ),
                const SizedBox(height: 8),
                Text('Replacing overwrites the selected project’s subtitle '
                    'lines and edit history. The original SRT file is not '
                    'overwritten by import.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              Text('Source subtitle file',
                style: Theme.of(context).textTheme.titleSmall),
              const Text('Choose which SRT the imported project should use.'),
              _sourceTile(
                source: StudioDockProjectSrtSource.archive,
                title: 'Use SRT recorded in archive',
                subtitle: widget.archiveSrtAvailable
                    ? (archiveSrt ?? '')
                    : 'Unavailable on this computer',
                enabled: widget.archiveSrtAvailable,
              ),
              _sourceTile(
                source: StudioDockProjectSrtSource.existingSession,
                title: 'Keep selected project’s SRT',
                subtitle: _existingAvailable
                    ? (target?.srtPath ?? '')
                    : 'Choose an existing project with an accessible SRT',
                enabled: _existingAvailable,
              ),
              _sourceTile(
                source: StudioDockProjectSrtSource.locatedFile,
                title: 'Use another local SRT',
                subtitle: _locatedSrtPath ?? 'Locate a file using Browse',
                enabled: _locatedSrtPath != null,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: OutlinedButton.icon(
                  key: const ValueKey('studio-dock-msone-browse'),
                  onPressed: _selectingFile ? null : _locateSrt,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Browse for SRT'),
                ),
              ),
              _sourceTile(
                source: StudioDockProjectSrtSource.unlinked,
                title: 'Import without linking an SRT',
                subtitle: 'Keep the archived subtitles and history; choose '
                    'a file later with Save As.',
              ),
              if (_fileError != null)
                Text(_fileError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _selectingFile ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('studio-dock-msone-confirm'),
          onPressed: !_canImport ? null : () => Navigator.pop(context,
              StudioDockProjectImportPlan(
                source: _source,
                replaceSessionId: _replace ? _targetId : null,
                locatedSrtPath: _locatedSrtPath,
              )),
          child: Text(_replace ? 'Review replacement' : 'Import project'),
        ),
      ],
    );
  }
}
