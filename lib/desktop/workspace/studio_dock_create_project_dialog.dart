import 'dart:io';

import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:flutter/material.dart';

import 'studio_dock_project_actions.dart';

/// New-project settings are collected before any session or file is written.
/// The optional native pickers choose destinations but do not save content.
class StudioDockCreateProjectChoice {
  const StudioDockCreateProjectChoice({
    required this.name,
    required this.encoding,
    this.srtPath,
    this.projectPath,
  });

  final String name;
  final String encoding;
  final String? srtPath;
  final String? projectPath;

  bool get saveFilesNow => srtPath != null && projectPath != null;
}

class StudioDockCreateProjectDialog extends StatefulWidget {
  const StudioDockCreateProjectDialog({
    super.key,
    this.pickLocation,
  });

  /// Injectable for widget tests; production uses the native Save dialog.
  final Future<String?> Function(String extension, String fileName)?
      pickLocation;

  @override
  State<StudioDockCreateProjectDialog> createState() =>
      _StudioDockCreateProjectDialogState();
}

class _StudioDockCreateProjectDialogState
    extends State<StudioDockCreateProjectDialog> {
  String _name = '';
  String _encoding = 'UTF-8';
  bool _saveFilesNow = false;
  bool _choosingLocation = false;
  String? _srtPath;
  String? _projectPath;
  String? _error;

  String? get _validFileName {
    try {
      return StudioDockProjectActions.fileNameForNewProject(_name);
    } on FormatException {
      return null;
    }
  }

  bool get _canCreate => !_choosingLocation && _validFileName != null &&
      (!_saveFilesNow || (_srtPath != null && _projectPath != null));

  Future<void> _pick(String extension) async {
    final fileName = _validFileName;
    if (_choosingLocation || fileName == null) return;
    setState(() { _choosingLocation = true; _error = null; });
    try {
      final suggested = extension == 'srt'
          ? fileName
          : '${fileName.substring(0, fileName.length - 4)}.msone';
      final selected = await (widget.pickLocation?.call(extension, suggested) ??
          FilePickerSAF.pickDesktopSaveLocation(
            fileName: suggested,
            extension: extension,
          ));
      if (!mounted || selected == null || selected.isEmpty) return;
      if (!File(selected).isAbsolute ||
          !selected.toLowerCase().endsWith('.$extension')) {
        setState(() => _error = 'Choose an absolute .$extension file path.');
        return;
      }
      setState(() {
        if (extension == 'srt') {
          _srtPath = selected;
        } else {
          _projectPath = selected;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error =
          'Could not choose the file location. Please try again.');
    } finally {
      if (mounted) setState(() => _choosingLocation = false);
    }
  }

  void _finish() {
    if (!_canCreate) return;
    Navigator.pop(context, StudioDockCreateProjectChoice(
      name: _name.trim(),
      encoding: _encoding,
      srtPath: _saveFilesNow ? _srtPath : null,
      projectPath: _saveFilesNow ? _projectPath : null,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create subtitle project'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Start a new SRT subtitle project in Edit Mode.'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('studio-dock-new-project-name'),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Subtitle name',
              hintText: 'Untitled subtitles',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() { _name = value; _error = null; }),
            onSubmitted: (_) => _finish(),
          ),
          if (_name.isNotEmpty && _validFileName == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Use a valid SRT name without file-path characters.',
                  style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const ValueKey('studio-dock-new-project-encoding'),
            initialValue: _encoding,
            decoration: const InputDecoration(
              labelText: 'SRT text encoding',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'UTF-8', child: Text('UTF-8')),
              DropdownMenuItem(
                  value: 'ISO-8859-1', child: Text('ISO-8859-1')),
              DropdownMenuItem(
                  value: 'Windows-1252', child: Text('Windows-1252')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _encoding = value);
            },
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const ValueKey('studio-dock-new-project-save-now'),
            contentPadding: EdgeInsets.zero,
            value: _saveFilesNow,
            title: const Text('Save SRT and project files now'),
            subtitle: const Text('Choose separate locations for the .srt '
                'subtitle file and the .msone project file. Leave this off '
                'to create a project and choose save locations later.'),
            onChanged: _choosingLocation ? null : (value) => setState(() {
              _saveFilesNow = value ?? false;
              _error = null;
            }),
          ),
          if (_saveFilesNow) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('studio-dock-new-project-select-srt'),
              onPressed: _validFileName == null || _choosingLocation
                  ? null : () => _pick('srt'),
              icon: const Icon(Icons.subtitles_outlined),
              label: Text(_srtPath == null
                  ? 'Choose SRT file location'
                  : 'SRT: ${File(_srtPath!).uri.pathSegments.last}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('studio-dock-new-project-select-msone'),
              onPressed: _validFileName == null || _choosingLocation
                  ? null : () => _pick('msone'),
              icon: const Icon(Icons.folder_special_outlined),
              label: Text(_projectPath == null
                  ? 'Choose project file location'
                  : 'Project: ${File(_projectPath!).uri.pathSegments.last}'),
            ),
            const SizedBox(height: 4),
            const Text('Existing files will not be overwritten.',
                style: TextStyle(fontSize: 12)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(
                color: Theme.of(context).colorScheme.error)),
          ],
        ],
      )),
    ),
    actions: [
      TextButton(
        key: const ValueKey('studio-dock-new-project-cancel'),
        onPressed: _choosingLocation ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('studio-dock-new-project-confirm'),
        onPressed: _canCreate ? _finish : null,
        child: const Text('Create project'),
      ),
    ],
  );
}
