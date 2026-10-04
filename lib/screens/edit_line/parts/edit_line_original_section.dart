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
                                                  Container(
                                                    height: 100,
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(
                                                      8.0,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFF0A9396,
                                                        ),
                                                        width: 1.5,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4.0,
                                                          ),
                                                    ),
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
                                                              defaultStyle:
                                                                  TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .white,
                                                                    fontSize: 16,
                                                                  ),
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
                                                              decoration: const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                contentPadding:
                                                                    EdgeInsets.fromLTRB(
                                                                      8.0,
                                                                      8.0,
                                                                      60.0,
                                                                      8.0,
                                                                    ), // Add right padding for icon buttons
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize: 16,
                                                                    color: Color(
                                                                      0xFFFFFFFF,
                                                                    ),
                                                                  ),
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
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color.fromARGB(
                                                          100,
                                                          255,
                                                          255,
                                                          255,
                                                        ),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  // Index/total count positioned at bottom-left
                                                  Positioned(
                                                    bottom: 1,
                                                    left: 4,
                                                    child: Text(
                                                      "${_subtitleLine?.index ?? 1}/${_subtitle?.lines.length ?? 0}",
                                                      style: const TextStyle(
                                                        color: Color.fromARGB(
                                                          125,
                                                          255,
                                                          255,
                                                          255,
                                                        ),
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontSize: 12,
                                                      ),
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
                                                          color: const Color(
                                                            0xFFCA6702,
                                                          ),
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
                                                          color:
                                                              isEditingEnabled
                                                                  ? const Color(
                                                                    0xFFBB3E03,
                                                                  )
                                                                  : const Color(
                                                                    0xFFCA6702,
                                                                  ),
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
