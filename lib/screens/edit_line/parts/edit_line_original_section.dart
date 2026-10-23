part of '../../screen_edit_line.dart';

extension _EditLineOriginalSection on EditSubtitleScreenState {
  List<Widget> _buildOriginalTextSection(BuildContext context) {
    return [

                                            // Show title row and checkboxes only when original text field is visible
                                            if (_showOriginalTextField) ...[
                                              // Empty space where the labels and controls used to be
                                              const SizedBox(height: 0),
                                            ],
                                            // Original text field - conditionally displayed
                                            if (_showOriginalTextField) ...[
                                              Stack(
                                                children: [
                                                  StudioCueFieldSurface(
                                                    height: EditLinePortraitMetrics.of(context).originalCueHeight,
                                                    child:
                                                        isRawEnabled
                                                            ? CustomHtmlText(
                                                              htmlContent:
                                                                  _originalController
                                                                      .text
                                                                      .replaceAll(
                                                                        '\n',
                                                                        '<br>',
                                                                      ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              defaultStyle: StudioCueFieldStyle.text(context),
                                                            )
                                                            : TextField(
                                                              controller:
                                                                  _originalController,
                                                              undoController:
                                                                  _undoHistoryController,
                                                              keyboardType:
                                                                  TextInputType
                                                                      .multiline,
                                                              readOnly:
                                                                  !isEditingEnabled,
                                                              maxLines: null,
                                                              expands: true,
                                                              inputFormatters: [
                                                                UnicodeTextInputFormatter(),
                                                              ],
                                                              decoration: StudioCueFieldStyle.decoration(padding: const EdgeInsets.fromLTRB(8, 8, 60, 8)),
                                                              style: StudioCueFieldStyle.text(context),
                                                              scrollPhysics:
                                                                  const ClampingScrollPhysics(), // Enable scrolling
                                                              // Ultra-optimized settings for maximum keyboard responsiveness
                                                              autocorrect:
                                                                  false, // Critical: Disable autocorrect for instant typing
                                                              enableSuggestions:
                                                                  false, // Critical: Disable suggestions to reduce processing
                                                              smartDashesType:
                                                                  SmartDashesType
                                                                      .disabled, // Disable smart dashes
                                                              smartQuotesType:
                                                                  SmartQuotesType
                                                                      .disabled, // Disable smart quotes
                                                              textInputAction:
                                                                  TextInputAction
                                                                      .newline, // Optimize for multiline
                                                              enableIMEPersonalizedLearning:
                                                                  false, // Critical: Disable IME learning for faster response
                                                              enableInteractiveSelection:
                                                                  true, // Enable text selection
                                                              showCursor:
                                                                  true, // Keep cursor visible
                                                            ),
                                                  ),
                                                  // Character count positioned at bottom-right (with margin from buttons)
                                                  Positioned(
                                                    bottom: 1,
                                                    right: 4,
                                                    child: riverpod.Consumer(
                                                      builder: (context, ref, child) {
                                                        final characterState = ref.watch(
                                                          editLineControllerProvider.select(
                                                            (state) => (
                                                              state.isInitialized,
                                                              state.originalCharCount,
                                                              state.originalHasLongLine,
                                                            ),
                                                          ),
                                                        );

                                                        final charCount = characterState.$1
                                                            ? characterState.$2
                                                            : _originalCharCount;
                                                        final hasLongLine = characterState.$1
                                                            ? characterState.$3
                                                            : _originalHasLongLine;

                                                        return CharacterCountWidget(
                                                          count: charCount,
                                                          hasLongLine: hasLongLine,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  // "Original" title positioned at top-left
                                                  Positioned(
                                                    top: 1,
                                                    left: 4,
                                                    child: Text(
                                                      'Original',
                                                      style: StudioCueFieldStyle.label(context),
                                                    ),
                                                  ),
                                                  // Index/total count positioned at bottom-left
                                                  Positioned(
                                                    bottom: 1,
                                                    left: 4,
                                                    child: Text(
                                                      "${_subtitleLine?.index ?? 1}/${_subtitle?.lines.length ?? 0}",
                                                      style: StudioCueFieldStyle.index(context),
                                                    ),
                                                  ),
                                                  // Copy button and edit button positioned at top-right as a column
                                                  Positioned(
                                                    top: 1,
                                                    right: 1,
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          constraints:
                                                              const BoxConstraints(
                                                                minWidth: 24,
                                                                minHeight: 24,
                                                              ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          onPressed: () {
                                                            Clipboard.setData(
                                                              ClipboardData(
                                                                text:
                                                                    _originalController
                                                                        .text,
                                                              ),
                                                            );
                                                            SnackbarHelper.showSuccess(
                                                              context,
                                                              'Copied to clipboard',
                                                              duration:
                                                                  const Duration(
                                                                    seconds: 2,
                                                                  ),
                                                            );
                                                          },
                                                          icon: const Icon(
                                                            Icons.copy,
                                                            size: 16,
                                                          ),
                                                          color: StudioDesignTokens.of(context).primaryAction,
                                                        ),
                                                        IconButton(
                                                          constraints:
                                                              const BoxConstraints(
                                                                minWidth: 24,
                                                                minHeight: 24,
                                                              ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          onPressed: () {
                                                            _setEditLineState(() {
                                                              isEditingEnabled =
                                                                  !isEditingEnabled;
                                                            });
                                                          },
                                                          icon: const Icon(
                                                            Icons.edit,
                                                            size: 16,
                                                          ),
                                                          color: StudioDesignTokens.of(context).primaryAction,
                                                          tooltip:
                                                              "Toggle Edit Mode",
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                          
    ];
  }
}
