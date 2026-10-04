part of '../../project_settings_sheet.dart';

extension _ProjectSettingsSections on _ProjectSettingsSheetState {
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Basic Information', Icons.info_outline, Colors.blue),
        _buildEditableField(
          'Project Name',
          _projectNameController,
          'Enter project name',
          onChanged: (value) {
            // Auto-save project name changes
          },
        ),
      ],
    );
  }

  Widget _buildFileManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('File Management', Icons.folder_outlined, Colors.orange),
        
        // SRT File Path
        _buildPathCard(
          'SRT File',
          widget.subtitleCollection.filePath,
          'No SRT file path available',
          Icons.subtitles,
          Colors.blue,
          onLocate: _locateSrtFile,
          onReplace: null, // SRT files are managed through other workflows
          onClear: null,   // SRT files shouldn't be cleared
          showReplaceButton: false, // Don't show Replace button for SRT files
        ),
        
        const SizedBox(height: 12),
        
        // Project File Path
        _buildPathCard(
          'Project File',
          _getDisplayProjectFilePath(),
          'No project file saved',
          Icons.description,
          Colors.teal,
          onLocate: _locateProjectFile,
          onReplace: _saveProjectFile, // Save project when "Add" is pressed
          onClear: null,   // Project files shouldn't be cleared
          showReplaceButton: false, // Don't show Replace/Add button for Project files
        ),
      ],
    );
  }

  Widget _buildMediaPathsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Media Paths', Icons.video_library_outlined, Colors.purple),
        
        // Video Path
        _buildPathCard(
          'Video File',
          _getDisplayVideoFilePath(),
          'No video file loaded',
          Icons.video_file,
          Colors.purple,
          onLocate: _locateVideoFile,
          onReplace: _replaceVideoFile,
          onClear: _clearVideoFile,
        ),
        
        const SizedBox(height: 12),
        
        // Secondary Subtitle Path
        _buildPathCard(
          'Secondary Subtitle',
          _isSecondaryFromOriginal 
            ? 'Original text (loaded from current subtitles)' 
            : _getDisplaySecondarySubtitlePath(),
          'No secondary subtitle loaded',
          Icons.subtitles,
          Colors.green,
          onLocate: _isSecondaryFromOriginal ? null : _locateSecondarySubtitle,
          onReplace: _replaceSecondarySubtitle,
          onClear: _clearSecondarySubtitle,
          isOriginalText: _isSecondaryFromOriginal,
        ),
      ],
    );
  }

  Widget _buildEncodingSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = onSurfaceColor.withValues(alpha: 0.12);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Text Encoding', Icons.text_format, Colors.indigo),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Character Encoding',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEncoding,
                    isExpanded: true,
                    items: _availableEncodings.map((encoding) {
                      return DropdownMenuItem(
                        value: encoding,
                        child: Text(encoding),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _setProjectSettingsState(() {
                          _selectedEncoding = value;
                        });
                        _updateEncoding(value);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectStatsSection() {
    if (_sessionInfo == null) return const SizedBox.shrink();
    
    final stats = _sessionInfo!;
    final progress = stats['progress'] as double;
    final totalLines = stats['totalLines'] as int;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Project Statistics', Icons.analytics_outlined, Colors.teal),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Editing Progress',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Stats Grid (total lines, last edited, language)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      Icons.format_list_numbered,
                      'Total Lines',
                      '$totalLines',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.edit_note,
                      'Edited Lines',
                      '${stats['editedLines'] ?? 0}',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      Icons.edit_location,
                      'Last Edited Line',
                      widget.session.lastEditedIndex != null 
                        ? '#${widget.session.lastEditedIndex! + 1}'
                        : 'None',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.language,
                      'Language',
                      _detectLanguage(),
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      height: 65, // Fixed height to keep all stat cards the same size
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis, // Handle long text
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis, // Handle long text
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkedLinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Marked Lines', Icons.bookmark_added, Colors.red),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showMarkedLines,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bookmark_added,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bookmarked Lines',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_markedLines.length} line${_markedLines.length == 1 ? '' : 's'} marked',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save, size: 20),
                SizedBox(width: 8),
                Text(
                  'Save Changes',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.close,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    String hint, {
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = onSurfaceColor.withValues(alpha: 0.12);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPathCard(
    String title,
    String? path,
    String emptyText,
    IconData icon,
    Color color, {
    VoidCallback? onLocate,
    VoidCallback? onReplace,
    VoidCallback? onClear,
    bool isOriginalText = false,
    bool showReplaceButton = true,
  }) {
    final hasPath = path != null && path.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasPath ? path : emptyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasPath 
                ? Theme.of(context).textTheme.bodyMedium?.color 
                : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontStyle: hasPath ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          if (hasPath || isOriginalText) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onLocate != null)
                  TextButton.icon(
                    onPressed: onLocate,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Locate'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      foregroundColor: Colors.indigo,
                    ),
                  ),
                if (showReplaceButton && onReplace != null)
                  TextButton.icon(
                    onPressed: onReplace,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Replace'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      foregroundColor: Colors.orange,
                    ),
                  ),
                if (onClear != null)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onReplace,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                foregroundColor: Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Detects the language from subtitle content - same as HomeScreen

}
