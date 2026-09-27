part of '../../screen_edit.dart';

extension _EditResponsiveLayout on _EditScreenState {
                    return _buildResponsiveContent(snapshot.data!);
                  }
                },
              ),
            ),
          ),

          // Add floating play/pause button when enabled (hide in source view)
          if (!_isSourceView && _floatingControlsEnabled && _isVideoVisible && _isVideoLoaded && _videoPlayerKey.currentState != null)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                heroTag: 'floatingPlayPause',
                onPressed: () {
                  if (_videoPlayerKey.currentState!.isInitialized()) {
                    _videoPlayerKey.currentState!.playOrPause();
                  }
                }
}
