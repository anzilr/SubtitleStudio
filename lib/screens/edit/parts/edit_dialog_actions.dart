part of '../../screen_edit.dart';

extension _EditDialogActions on _EditScreenState {
  _showBatchDeleteConfirmation();
        break;
      case 'select_by_index':
        _showSelectByIndexDialog();
        break;
      case 'range_selection':
        _toggleRangeSelectionMode();
        break;
    }
  }

  // Helper methods for menu actions
  void _showGoToLineModal() {
    showGotToLineModal(
      context: context,
      initialValue: '',
      hintText: subtitleLines.length,
      title: 'Go to line',
      onSubmitted: (value) async {
        final lineNumber = int.tryParse(value.trim());
        if (lineNumber == null ||
            lineNumber < 1 ||
            lineNumber > subtitleLines.length) {
          SnackbarHelper.showError(
            context,
            'Enter a line number between 1 and ${subtitleLines.length}',
          );
          return;
        }

        await _scrollToIndexWithLoading(lineNumber);
        _highlightIndex(lineNumber - 1);

        if (_isVideoLoaded) {
          _seekToSubtitle(lineNumber - 1);
        }
      },
    );
  }

  _showCommentDialogForLine(targetIndex);
  }

  void _handleFindReplaceShortcut() {
    _showFindReplaceModal();
  }

  _showMarkedLinesModal();
        break;
      case 'checkpoint_history':
        _showCheckpointHistoryModal();
        break;
      case 'import_comments':
        _showImportCommentsModal();
        break;
      case 'secondary_subtitle':
        _showSecondarySubtitleModal();
        break;
      case 'toggle_secondary':
        _toggleSecondarySubtitles(!_showSecondarySubtitles);
        break;
      case 'sync':
        _showSyncModal();
        break;
      case 'remove_hearing_impaired':
        _removeHearingImpairedLines();
        break;
      case 'banners':
        _showInsertBannersModal();
        break;
      case 'malayalam_normalize':
        _showMalayalamNormalizationModal();
        break;
      case 'submit_msone':
        _showSubmitToMsoneModal();
        break;
      case 'settings':
        _showSettingsModal();
        break;
      case 'help':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpScreen()),
        );
        break;
    }
  }

  // Selection menu popup
  void _showSelectionMenuModal({Offset? position}

  _showMarkedLinesModalWithHighlight(subtitleLines[index].index);
        } : null,
        isMarked: isMarked,
      ),
    );
  }

  void _showEffectsForSingleLine(int index) {
    final currentLine = subtitleLines[index];
    final lineText = currentLine.edited ?? currentLine.original;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SubtitleEffectsSheet(
          selectedIndices: [index], // Convert to 0-based index
          onApplyEffect: (effectType, effectConfig) {
            _applyEffectToSingleLineFromBottomSheet(context, index, effectType, effectConfig);
          },
          subtitleLines: [currentLine], // Pass the current line
          lineText: lineText, // Pass the line text
        );
      },
    );
  }

  _showCheckpointHistoryModal();
        break;
      case 'import_comments':
        _showImportCommentsModal();
        break;
      case 'secondary_subtitle':
        _showSecondarySubtitleModal();
        break;
      case 'toggle_secondary':
        _toggleSecondarySubtitles(!_showSecondarySubtitles);
        break;
      case 'sync':
        _showSyncModal();
        break;
      case 'remove_hearing_impaired':
        _removeHearingImpairedLines();
        break;
      case 'banners':
        _showInsertBannersModal();
        break;
      case 'malayalam_normalize':
        _showMalayalamNormalizationModal();
        break;
      case 'submit_msone':
        _showSubmitToMsoneModal();
        break;
      case 'settings':
        _showSettingsModal();
        break;
      case 'help':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpScreen()),
        );
        break;
    }
  }

  // Selection menu popup
  void _showSelectionMenuModal({Offset? position}
}
