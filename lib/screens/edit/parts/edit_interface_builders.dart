part of '../../screen_edit.dart';

extension _EditInterfaceBuilders on _EditScreenState {
  Widget _buildSubtitleListInterface(List<SubtitleLine> subtitleLines) {
    return Column(
      children: [
        // Title bar for subtitle list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.subtitles,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Subtitle Lines',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${subtitleLines.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Subtitle list
        Expanded(
          child: riverpod.Consumer(
                    builder: (context, ref, _) {
                      final reactiveSubtitleLines = ref.watch(
                        editControllerProvider.select(
                          (state) => state.subtitleLines,
                        ),
                      );
                      return Stack(
              children: [
                ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    bottom: 16, 
                    top: 8,
                    left: 8,
                    right: 8,
                  ),
                  itemCount: reactiveSubtitleLines.length,
                  itemBuilder: (context, index) {
                    final line = reactiveSubtitleLines[index];
                    final textContent = line.edited ?? line.original;
                    return _buildSubtitleCard(line, index, textContent);
                  },
                ),
                _buildCustomScrollbar(),
              ],
            );
          }),
        ),
      ],
    );
  }

  // Build video player interface
  Widget _buildVideoPlayerInterface(List<SubtitleLine> subtitleLines) {
    return EditorVideoPane(
      isVideoVisible: _isVideoVisible,
      videoPath: _selectedVideoPath,
      isWaveformVisible: _isWaveformVisible,
      videoPlayerKey: _videoPlayerKey,
      waveformKey: _waveformKey,
      subtitleCollectionId: widget.subtitleCollectionId,
      sessionId: widget.sessionId,
      subtitles: _subtitles,
      secondarySubtitles: _secondarySubtitles,
      subtitleLines: subtitleLines,
      subtitleVersion: _subtitleVersion,
      playbackPosition: _lastVideoPosition,
      highlightedSubtitleIndex: _highlightedIndex,
      onPositionChanged: _onVideoPositionChanged,
      onActiveSubtitleChanged: _onActiveSubtitleChangedStable,
      onSubtitlesUpdated: _onSubtitlesUpdatedStable,
      onFullscreenExited: _onFullscreenExitedStable,
      onSubtitleMarked: _onSubtitleMarkedStable,
      onSubtitleCommentUpdated: _onSubtitleCommentUpdatedStable,
      onLoadVideo: _pickVideoFile,
      onSeek: (position) {
        _videoPlayerKey.currentState?.seekTo(position);
      },
      onSubtitleHighlight: (index) {
        _scrollToIndexWithLoading(index);
        _setEditorState(() {
          _highlightedIndex = index;
        });
      },
      onWaveformSubtitlesUpdated: _refreshSubtitleLines,
      onAddLineConfirmed: _openAddLineSheetWithTimes,
    );
  }

  // // Build editing interface without video (for layout2)
  // Widget _buildEditingInterfaceWithoutVideo(List<SubtitleLine> subtitleLines) {
  //   return Column(
  //     children: [
  //       // Title bar for editing interface
  //       Container(
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: Theme.of(context).colorScheme.surfaceContainer,
  //           border: Border(
  //             bottom: BorderSide(
  //               color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
  //             ),
  //           ),
  //         ),
  //         child: Row(
  //           children: [
  //             Icon(
  //               Icons.edit,
  //               size: 20,
  //               color: Theme.of(context).colorScheme.primary,
  //             ),
  //             const SizedBox(width: 8),
  //             Text(
  //               'Editing Interface',
  //               style: Theme.of(context).textTheme.titleSmall?.copyWith(
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       // Placeholder for editing interface - this would be your custom editing interface
  //       Expanded(
  //         child: Center(
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Icon(
  //                 Icons.edit_note,
  //                 size: 80,
  //                 color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
  //               ),
  //               const SizedBox(height: 16),
  //               Text(
  //                 'Editing Interface',
  //                 style: Theme.of(context).textTheme.titleMedium?.copyWith(
  //                   color: Theme.of(context).colorScheme.outline,
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 'This is where your custom editing interface would go',
  //                 textAlign: TextAlign.center,
  //                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  //                   color: Theme.of(context).colorScheme.outline.withOpacity(0.6),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }


}
