part of '../../project_settings_sheet.dart';

extension _ProjectSettingsMarkedActions on _ProjectSettingsSheetState {
  void _showMarkedLines() async {
    // Get both marked lines and all lines with comments
    final allLinesWithComments = await ref
        .read(subtitleRepositoryProvider)
        .getLinesWithComments(widget.session.subtitleCollectionId);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => MarkedLinesSheet(
          markedLines: _markedLines,
          allLinesWithComments: allLinesWithComments,
          onLineSelected: (index) {
            // This could navigate to the specific line in the editor
            Navigator.pop(context); // Close project settings
          },
          onCommentUpdated: (index, comment) async {
            // Update comment in database and refresh marked lines
            try {
              await ref
                  .read(subtitleRepositoryProvider)
                  .updateComment(widget.session.subtitleCollectionId, index, comment);
              // Refresh marked lines list
              _markedLines = await ref.read(subtitleRepositoryProvider).getMarkedLines(widget.session.subtitleCollectionId);
              _setProjectSettingsState(() {}); // Trigger rebuild to show updated comments
              
              SnackbarHelper.showSuccess(context, 
                comment != null ? 'Comment updated' : 'Comment deleted');
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to update comment: $e');
              }
              SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
            }
          },
          onLineUnmarked: (index) async {
            // Unmark line and delete comment
            try {
              await ref
                  .read(subtitleRepositoryProvider)
                  .unmarkLine(widget.session.subtitleCollectionId, index);
              // Refresh marked lines list
              _markedLines = await ref.read(subtitleRepositoryProvider).getMarkedLines(widget.session.subtitleCollectionId);
              _setProjectSettingsState(() {}); // Trigger rebuild to remove unmarked line
              
              SnackbarHelper.showSuccess(context, 'Line unmarked and comment deleted');
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to unmark subtitle line: $e');
              }
              SnackbarHelper.showError(context, 'Could not unmark the subtitle line. Please try again.');
            }
          },
          onResolvedUpdated: (index, resolved) async {
            // Update resolved status in database
            try {
              await ref
                  .read(subtitleRepositoryProvider)
                  .updateResolved(widget.session.subtitleCollectionId, index, resolved);
              // Refresh marked lines list
              _markedLines = await ref.read(subtitleRepositoryProvider).getMarkedLines(widget.session.subtitleCollectionId);
              _setProjectSettingsState(() {}); // Trigger rebuild to show updated resolved status
              
              SnackbarHelper.showSuccess(context, 
                resolved ? 'Comment marked as resolved' : 'Comment marked as unresolved');
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to update resolved status: $e');
              }
              SnackbarHelper.showError(context, 'Could not update the resolved status. Please try again.');
            }
          },
          onTextEdited: (index, newText) async {
            // Update edited text in database and refresh marked lines
            try {
              final repository = ref.read(subtitleRepositoryProvider);
              final subtitle = await repository.fetchSubtitleCollection(
                widget.session.subtitleCollectionId,
              );
              if (subtitle != null && index < subtitle.lines.length) {
                final updatedLine = subtitle.lines[index];
                updatedLine.edited = newText;

                final saved = await repository.saveLineChanges(
                  widget.session.subtitleCollectionId,
                  updatedLine,
                  sessionId: widget.session.id,
                );
                if (!saved) {
                  throw StateError('Subtitle line update failed');
                }

                _markedLines = await repository.getMarkedLines(
                  widget.session.subtitleCollectionId,
                );
                _setProjectSettingsState(() {});

                SnackbarHelper.showSuccess(context, 'Subtitle text updated');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to update subtitle text: $e');
              }
              SnackbarHelper.showError(context, 'Could not update the subtitle text. Please try again.');
            }
          },
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    try {
      // Save project name
      final newProjectName = _projectNameController.text.trim();
      if (newProjectName.isNotEmpty && newProjectName != widget.session.fileName) {
        await ref.read(projectRepositoryProvider).updateSessionFileName(
          sessionId: widget.session.id,
          fileName: newProjectName,
        );
        widget.session.fileName = newProjectName;
      }

      widget.onProjectUpdated();
      
      SnackbarHelper.showSnackBar(
        context,
        'Changes saved successfully',
        backgroundColor: Colors.green,
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Project Settings failed to save project changes: $e');
      }
      SnackbarHelper.showSnackBar(
        context,
        'Could not save the project changes. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

}
