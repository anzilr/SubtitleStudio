part of '../../screen_edit_line.dart';

extension _EditLineTimeSection on EditSubtitleScreenState {
  Widget _buildEditLineTimeSection() {
    return Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () {
                                                      _setEditLineState(() {
                                                        _isTimeVisible =
                                                            !_isTimeVisible;
                                                      });

                                                      // Auto-scroll to bottom when time fields are shown
                                                      if (_isTimeVisible) {
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback((
                                                              _,
                                                            ) {
                                                              _scrollController.animateTo(
                                                                _scrollController
                                                                    .position
                                                                    .maxScrollExtent,
                                                                duration:
                                                                    const Duration(
                                                                      milliseconds:
                                                                          300,
                                                                    ),
                                                                curve:
                                                                    Curves
                                                                        .easeInOut,
                                                              );
                                                            });
                                                      }
                                                    },
                                                    label: Text(
                                                      "Edit Time",
                                                      style: TextStyle(
                                                        color: StudioDesignTokens.of(context).primaryAction,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    icon: Icon(
                                                      _isTimeVisible
                                                          ? Icons
                                                              .keyboard_arrow_down
                                                          : Icons.chevron_right,
                                                      size: 32,
                                                      color: StudioDesignTokens.of(context).primaryAction,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_isTimeVisible)
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                                  child: EditLineTimeFieldsLayout(
                                                    startField: _buildTimeComponentFields(
                                                      'Start Time', true,
                                                    ),
                                                    endField: _buildTimeComponentFields(
                                                      'End Time', false,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
  }
}
