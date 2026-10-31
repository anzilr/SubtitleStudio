import 'package:flutter/material.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/utils/platform_check.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/utils/app_logger.dart';
import 'package:subtitle_studio/widgets/file_replace_dialog.dart';
import 'package:subtitle_studio/screens/edit/services/editor_export_service.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'dart:io';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/widgets/subtitle_encoding_picker.dart';
import '../database/models/models.dart';

class ExportBottomSheet extends StatefulWidget {
  final SubtitleCollection subtitle;
  final List<SubtitleLine> lines;
  final Function onExportComplete;

  const ExportBottomSheet({
    super.key,
    required this.subtitle,
    required this.lines,
    required this.onExportComplete,
  });

  @override
  ExportBottomSheetState createState() => ExportBottomSheetState();
}

class ExportBottomSheetState extends State<ExportBottomSheet> {
  late TextEditingController _fileNameController;
  late TextEditingController _filePathController;
  late TextEditingController _customTagController; // New controller for custom tag
  String _selectedEncoding = 'UTF-8'; // Explicit output charset/BOM.
  List<String> _availableEncodings = SubtitleTextCodec.supportedEncodings;
  bool _exportOriginalAsWell = false; // Track if original lines should be exported separately
  bool _isExporting = false;
  final EditorExportService _exportService = EditorExportService();

  @override
  void initState() {
    super.initState();
    // Preserve the stored source charset, even when not supported locally.
    _selectedEncoding = widget.subtitle.encoding.isEmpty
        ? 'UTF-8' : widget.subtitle.encoding;
    _fileNameController = TextEditingController(text: widget.subtitle.fileName);
    _filePathController = TextEditingController(
      text: Platform.isAndroid || Platform.isIOS
          ? ''
          : _exportService.suggestedFolder(
                originalFileUri: widget.subtitle.originalFileUri,
                legacyFilePath: widget.subtitle.filePath,
              ) ?? '',
    );
    _customTagController = TextEditingController(text: "MSone"); // Default tag value
    _loadEncodings();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _filePathController.dispose();
    _customTagController.dispose(); // Dispose the custom tag controller
    super.dispose();
  }

  Future<void> _loadEncodings() async {
    final choices = await SubtitleExtendedEncodingService.standard
        .availableEncodings();
    if (mounted) setState(() => _availableEncodings = choices);
  }

  Future<void> _chooseEncoding() async {
    final choice = await SubtitleEncodingPicker.show(
      context: context,
      title: 'Output subtitle encoding',
      options: _availableEncodings,
      selected: _selectedEncoding,
    );
    if (!mounted || choice == null) return;
    setState(() => _selectedEncoding = choice);
  }

  Future<void> _pickFolder() async {
    if (!context.mounted) return;
    final selectedFolder = await FilePickerConvenience.pickExportFolder(
        context: context);
    if (!mounted || selectedFolder == null || selectedFolder.isEmpty) return;
    setState(() => _filePathController.text = selectedFolder);
  }

  Future<void> _requestStoragePermission() async {
    // On Android with SAF, no permission requests needed
    // On iOS with file picker, no permission requests needed
    // On desktop platforms, request storage permissions
    if (!Platform.isAndroid && !Platform.isIOS) {
      final hasPermission = await requestStoragePermissions();
      
      if (!hasPermission) {
        throw Exception('Storage permission is required to export files. Please grant permission in app settings.');
      }
    }
  }

  Future<void> _exportSrt() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      await AppLogger.instance.info('Starting export process',
          context: 'ExportBottomSheet._exportSrt');
      if (!_availableEncodings.contains(_selectedEncoding)) {
        throw UnsupportedError('The source charset is unavailable on this '
            'device. Choose a supported export encoding.');
      }
      // Compile first: incompatible characters must not launch a picker,
      // request permissions, or touch an existing user's subtitle file.
      final plan = await _exportService.prepare(
        lines: widget.lines,
        encoding: _selectedEncoding,
        requestedName: _fileNameController.text,
        customTag: _customTagController.text,
        originalOnly: _exportOriginalAsWell,
      );
      await _requestStoragePermission();
      if (!mounted) return;

      final bool exported;
      if (Platform.isAndroid) {
        exported = await _exportWithSAF(plan);
      } else if (Platform.isIOS) {
        exported = await _exportWithFilePicker(plan);
      } else {
        exported = await _exportTraditional(plan);
      }
      if (!exported || !mounted) return; // User cancelled or chose no replace.
      widget.onExportComplete();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ArgumentError {
      if (mounted) SnackbarHelper.showError(context,
          'Choose a valid file name and an accessible export folder.');
    } on FormatException {
      if (mounted) SnackbarHelper.showError(context,
          'Subtitle text cannot be represented in this output encoding.');
    } on UnsupportedError {
      if (mounted) SnackbarHelper.showError(context,
          'This encoding is unavailable. Choose another output encoding.');
    } catch (e) {
      await AppLogger.instance.error('Export failed (${e.runtimeType})',
          context: 'ExportBottomSheet._exportSrt');
      if (context.mounted) {
        SnackbarHelper.showError(context,
            'Could not export the subtitle file. Check the destination.');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<bool> _exportWithSAF(EditorExportPlan plan) async {
    final saved = await FilePickerConvenience.saveFile(
      context: context,
      bytes: plan.bytes,
      fileName: plan.fileName,
      mimeType: 'application/x-subrip',
    );
    return saved != null;
  }

  Future<bool> _exportWithFilePicker(EditorExportPlan plan) async {
    final saved = await fp.FilePicker.saveFile(
      dialogTitle: 'Save Subtitle File',
      fileName: plan.fileName,
      bytes: plan.bytes,
    );
    return saved != null;
  }

  Future<bool> _exportTraditional(EditorExportPlan plan) async {
    final folder = _filePathController.text.trim();
    if (folder.isEmpty) {
      SnackbarHelper.showError(context, 'Please select a folder to save the file.');
      return false;
    }

    var selectedPlan = plan;
    var replaceExisting = false;
    if (await _exportService.existsInFolder(folder, plan)) {
      if (!mounted) return false;
      String? renamedBase;
      bool confirmedReplace = false;
      await showFileReplaceDialog(
        context: context,
        fileName: plan.fileName,
        existingPath: folder,
        onRename: (newName) => renamedBase = newName,
        onReplace: () => confirmedReplace = true,
      );
      if (!mounted) return false;
      if (renamedBase == null && !confirmedReplace) return false;
      if (renamedBase != null) {
        selectedPlan = plan.renamed(_exportService.fileNameFor(
          requestedName: renamedBase!,
          customTag: _customTagController.text,
          originalOnly: _exportOriginalAsWell,
        ));
      } else {
        replaceExisting = true;
      }
    }

    final result = await _exportService.writeDesktop(
      folder: folder,
      plan: selectedPlan,
      replaceExisting: replaceExisting,
    );
    if (result == EditorExportWriteResult.alreadyExists) {
      // If Rename selected another existing name, it must never silently
      // overwrite that second file without an explicit Replace confirmation.
      if (mounted) SnackbarHelper.showError(context,
          'That filename already exists. Choose a different name.');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color variables for adaptive theming
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = onSurfaceColor.withValues(alpha: 0.6);
    final borderColor = onSurfaceColor.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.file_download_outlined,
                          color: primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Save File As",
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle.fileName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: mutedColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Folder Selection Card
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickFolder,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.folder_outlined,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Export Location",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _filePathController.text.isEmpty 
                                    ? (Platform.isAndroid 
                                        ? "Tap the Export button to select destination folder" 
                                        : "Select folder to save the file")
                                    : _filePathController.text,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: mutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: mutedColor,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // File Configuration Section
              // File Name Input
              Container(
                decoration: BoxDecoration(
                  color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _fileNameController,
                  decoration: InputDecoration(
                    labelText: 'File Name',
                    prefixIcon: Icon(
                      Icons.drive_file_rename_outline,
                      color: primaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    labelStyle: TextStyle(
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Custom Tag Input
              Container(
                decoration: BoxDecoration(
                  color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _customTagController,
                  decoration: InputDecoration(
                    labelText: 'Custom Tag',
                    hintText: 'MSone',
                    helperText: 'Added as .<tag>.srt to the filename',
                    prefixIcon: Icon(
                      Icons.label_outline,
                      color: primaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    labelStyle: TextStyle(
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Searchable encoding chooser replaces the long dropdown.
              OutlinedButton.icon(
                key: const ValueKey('output-encoding-picker'),
                onPressed: _chooseEncoding,
                icon: Icon(Icons.manage_search),
                label: Text(_availableEncodings.contains(_selectedEncoding)
                    ? 'Output encoding: ' + _selectedEncoding
                    : 'Unavailable on this device: ' + _selectedEncoding),
              ),
              const SizedBox(height: 20),

              // Export Options
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          "Export Options",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: Text(
                        "Export original lines only",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        "Uses .original.srt extension instead of custom tag",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: mutedColor,
                        ),
                      ),
                      value: _exportOriginalAsWell,
                      onChanged: (bool? value) {
                        if (value != null) {
                          setState(() {
                            _exportOriginalAsWell = value;
                          });
                        }
                      },
                      activeColor: primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isExporting ? null : _exportSrt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_download, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Save As",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      )
    );
  }
}
