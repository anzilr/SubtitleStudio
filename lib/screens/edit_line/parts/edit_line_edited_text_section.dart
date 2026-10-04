part of '../../screen_edit_line.dart';

extension _EditLineEditedTextSection on EditSubtitleScreenState {
  Widget _buildEditedTextStack(BuildContext context) {
    return Stack(
                                            children: [
                                              Container(
                                                height:
                                                    100, // Set a fixed height for the TextField
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
                                                      BorderRadius.circular(4.0),
                                                ),
                                                child:
                                                    isRawEnabled &&
                                                            _editedController
                                                                .text
                                                                .isNotEmpty
                                                        ? CustomHtmlText(
                                                          htmlContent:
                                                              _editedController
                                                                  .text
                                                                  .replaceAll(
                                                                    '\n',
                                                                    '<br>',
                                                                  ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          defaultStyle: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                          ),
                                                        )
                                                        : TextField(
                                                          controller:
                                                              _editedController,
                                                          focusNode: _focusNode,
                                                          undoController:
                                                              _undoHistoryController,
                                                          keyboardType:
                                                              TextInputType
                                                                  .multiline,
                                                          readOnly:
                                                              false, // Original subtitle should not be editable
                                                          maxLines:
                                                              null, // Allow the text to wrap and grow if needed
                                                          expands:
                                                              true, // Make the TextField expand vertically to fit the height
                                                          inputFormatters: [
                                                            UnicodeTextInputFormatter(),
                                                          ],
                                                          decoration: const InputDecoration(
                                                            border:
                                                                InputBorder.none,
                                                            contentPadding:
                                                                EdgeInsets.fromLTRB(
                                                                  8.0,
                                                                  8.0,
                                                                  30.0,
                                                                  8.0,
                                                                ), // Add right padding for icon buttons
                                                          ),
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            color: Color(
                                                              0xFFFFFFFF,
                                                            ),
                                                          ),
                                                          scrollPhysics:
                                                              const ClampingScrollPhysics(), // Enable scrolling
                                                          // Balanced settings for normal keyboard with good performance
                                                          autocorrect:
                                                              false, // Keep disabled for performance
                                                          enableSuggestions:
                                                              true, // Enable to show normal keyboard with suggestions
                                                          smartDashesType:
                                                              SmartDashesType
                                                                  .disabled, // Keep disabled for performance
                                                          smartQuotesType:
                                                              SmartQuotesType
                                                                  .disabled, // Keep disabled for performance
                                                          textInputAction:
                                                              TextInputAction
                                                                  .newline, // Optimize for multiline
                                                          enableIMEPersonalizedLearning:
                                                              true, // Enable for normal keyboard behavior
                                                          enableInteractiveSelection:
                                                              true, // Keep text selection
                                                          showCursor:
                                                              true, // Keep cursor visible
                                                          // Remove any onChanged callback to prevent lag
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
                                                          state.editedCharCount,
                                                          state.editedHasLongLine,
                                                        ),
                                                      ),
                                                    );

                                                    final charCount = characterState.$1
                                                        ? characterState.$2
                                                        : _editedCharCount;
                                                    final hasLongLine = characterState.$1
                                                        ? characterState.$3
                                                        : _editedHasLongLine;

                                                    return CharacterCountWidget(
                                                      count: charCount,
                                                      hasLongLine: hasLongLine,
                                                    );
                                                  },
                                                ),
                                              ),
                                              // "Edited" title positioned at top-left
                                              Positioned(
                                                top: 1,
                                                left: 4,
                                                child: Text(
                                                  _isEditMode
                                                      ? 'Subtitle Text'
                                                      : 'Edited',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
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
                                                      120,
                                                      255,
                                                      255,
                                                      255,
                                                    ),
                                                    fontStyle: FontStyle.italic,
                                                    fontWeight: FontWeight.normal,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              // Copy/paste buttons positioned at top-right as a column
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 24,
                                                            minHeight: 24,
                                                          ),
                                                      padding: EdgeInsets.zero,
                                                      onPressed: () {
                                                        Clipboard.setData(
                                                          ClipboardData(
                                                            text:
                                                                _editedController
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
                                                    // Only show paste original button in translation mode
                                                    if (!_isEditMode)
                                                      IconButton(
                                                        constraints:
                                                            const BoxConstraints(
                                                              minWidth: 24,
                                                              minHeight: 24,
                                                            ),
                                                        padding: EdgeInsets.zero,
                                                        onPressed: () {
                                                          _setEditLineState(() {
                                                            _editedController
                                                                    .text =
                                                                _originalController
                                                                    .text;
                                                          });
                                                        },
                                                        icon: const Icon(
                                                          Icons.paste,
                                                          size: 16,
                                                        ),
                                                        color: const Color(
                                                          0xFFCA6702,
                                                        ),
                                                        tooltip: "Paste Original",
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
  }
}
