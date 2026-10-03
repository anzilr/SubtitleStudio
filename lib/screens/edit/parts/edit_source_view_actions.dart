part of '../../screen_edit.dart';

extension _EditSourceViewActions on _EditScreenState {
  // Source view methods
  void _switchToSourceView() {
    // Riverpod migration - delegate to the Riverpod controller
    _controller.switchToSourceView();
    
    // Update local state from controller
    final state = _editState;
    _setEditorState(() {
      _isSourceView = state.isSourceView;
      _sourceViewEntries = state.sourceViewEntries;
      _sourceViewDirty = false;
    });
  }

  Future<void> _switchToTimelineView() async {
    if (!await _resolveSourceChangesBeforeLeaving()) return;

    _controller.switchToCardsView();
    final state = _editState;

    if (!mounted) return;
    _setEditorState(() {
      _isSourceView = state.isSourceView;
      _sourceViewDirty = false;
    });
  }

  List<SubtitleEntry> _convertSubtitleLinesToEntries(List<SubtitleLine> lines) {
    return lines.asMap().entries.map((entry) {
      return SubtitleEntry.fromSubtitleLine(entry.value, entry.key);
    }).toList();
  }

  // String _convertEntriesToSrtContent() {
  //   final buffer = StringBuffer();
  //   for (int i = 0; i < _sourceViewEntries.length; i++) {
  //     if (i > 0) buffer.write('\n');
  //     buffer.write(_sourceViewEntries[i].toSrtString());
  //   }
  //   return buffer.toString();
  // }

  void _onSourceViewContentChanged() {
    if (_sourceViewDirty) return;
    _setEditorState(() {
      _sourceViewDirty = true;
    });
  }

  Future<bool> _resolveSourceChangesBeforeLeaving() async {
    if (!_isSourceView || !_sourceViewDirty) return true;

    final choice = await showDialog<_SourceLeaveChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved source changes'),
        content: const Text(
          'Save the Source View changes before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _SourceLeaveChoice.cancel,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _SourceLeaveChoice.discard,
            ),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _SourceLeaveChoice.save,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == _SourceLeaveChoice.cancel) {
      return false;
    }

    if (choice == _SourceLeaveChoice.save) {
      try {
        await _syncSourceViewToDatabase();
        if (!mounted) return false;
        SnackbarHelper.showSuccess(context, 'Source View changes saved');
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            'Could not save Source View changes',
          );
        }
        return false;
      }
    } else {
      final currentLines = _editState.subtitleLines;
      _sourceViewEntries = _convertSubtitleLinesToEntries(currentLines);
    }

    if (mounted) {
      _setEditorState(() {
        _sourceViewDirty = false;
      });
    }
    return true;
  }

  // Future<void> _saveSourceViewChanges() async {
  //   try {
  //     // Convert source view entries back to subtitle lines and save
  //     // This would integrate with your existing save logic
  //     await _handleSave();
  //     SnackbarHelper.showSuccess(context, 'Source view changes saved');
  //   } catch (e) {
  //     SnackbarHelper.showError(context, 'Failed to save source view changes: $e');
  //   }
  // }

  /// Sync source view entries back to the database
  Future<void> _syncSourceViewToDatabase() async {
    try {
      // Riverpod migration - delegate to the Riverpod controller
      await _controller.syncSourceViewToDatabase(_sourceViewEntries);

      await _refreshSubtitleLines();

      if (mounted) {
        _setEditorState(() {
          _sourceViewDirty = false;
        });
      }
      
    } catch (e) {
      throw Exception('Failed to sync source view to database: $e');
    }
  }


}
