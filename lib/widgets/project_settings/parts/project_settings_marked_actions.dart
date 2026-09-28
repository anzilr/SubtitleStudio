part of '../../project_settings_sheet.dart';

extension _ProjectSettingsMarkedActions on _ProjectSettingsSheetState {
  void _showMarkedLines() async {
    // Get both marked lines and all lines with comments
    final allLinesWithComments = await getAllSubtitleLinesWithComments(widget.session.subtitleCollectionId);
    
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
              await updateSubtitleLineComment(widget.session.subtitleCollectionId, index, comment);
              // Refresh marked lines list
              _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
              setState(() {}); // Trigger rebuild to show updated comments
              
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
              await unmarkSubtitleLine(widget.session.subtitleCollectionId, index);
              // Refresh marked lines list
              _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
              setState(() {}); // Trigger rebuild to remove unmarked line
              
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
              await updateSubtitleLineResolved(widget.session.subtitleCollectionId, index, resolved);
              // Refresh marked lines list
              _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
              setState(() {}); // Trigger rebuild to show updated resolved status
              
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
              // Get the subtitle line from database
              final subtitle = await isar.subtitleCollections.get(widget.session.subtitleCollectionId);
              if (subtitle != null && index < subtitle.lines.length) {
                final updatedLine = subtitle.lines[index];
                updatedLine.edited = newText;
                
                // Save to database
                await saveSubtitleChangesToDatabase(
                  widget.session.subtitleCollectionId,
                  updatedLine,
                  (String time) {
                    // Parse time format "HH:mm:ss,SSS" to DateTime
                    final parts = time.split(',');
                    final hms = parts[0].split(':');
                    return DateTime(0, 1, 1, 
                      int.parse(hms[0]), 
                      int.parse(hms[1]), 
                      int.parse(hms[2]), 
                      int.parse(parts[1]));
                  },
                  sessionId: widget.session.id,
                );
                
                // Refresh marked lines list
                _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
                setState(() {}); // Trigger rebuild to show updated text
                
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
        final session = await isar.sessions.get(widget.session.id);
        if (session != null) {
          session.fileName = newProjectName;
          await isar.writeTxn(() async {
            await isar.sessions.put(session);
          });
        }
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
