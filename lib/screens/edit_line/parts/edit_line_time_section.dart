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
                                                        color: Color(0xFFCA6702),
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    icon: Icon(
                                                      _isTimeVisible
                                                          ? Icons
                                                              .keyboard_arrow_down
                                                          : Icons.chevron_right,
                                                      size: 32,
                                                      color: Color(0xFFCA6702),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_isTimeVisible)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 16.0,
                                                      ),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                                                    children: [
                                                      Expanded(
                                                        child: _buildTimeComponentFields(
                                                          'Start Time',
                                                          true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: _buildTimeComponentFields(
                                                          'End Time',
                                                          false,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          );
  }
}
