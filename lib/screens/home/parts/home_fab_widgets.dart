part of '../../screen_home.dart';

extension _HomeFabWidgets on _HomeScreenContentState {
  Widget _buildCustomFAB(HomeState state) {
    return Positioned(
      bottom: 32,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expanded action buttons
          AnimatedBuilder(
            animation: _customFabAnimation,
            builder: (context, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_customFabAnimation),
                child: FadeTransition(
                  opacity: _customFabAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (state.isFabExpanded) ...[
                        _buildCustomFabButton(
                          key: _createButtonKey,
                          onPressed: () {
                            _toggleCustomFab();
                            _handleCreate();
                          },
                          icon: Icons.add,
                          label: 'Create',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildCustomFabButton(
                          onPressed: () {
                            _toggleCustomFab();
                            _handleExtract();
                          },
                          icon: Icons.video_collection,
                          label: 'Extract',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildCustomFabButton(
                          onPressed: () {
                            _toggleCustomFab();
                            _handleImportProject();
                          },
                          icon: Icons.unarchive,
                          label: 'Import',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildCustomFabButton(
                          onPressed: () {
                            _toggleCustomFab();
                            _handleImport();
                          },
                          icon: Icons.file_open,
                          label: 'Open',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildCustomFabButton(
                          onPressed: () {
                            _toggleCustomFab();
                            _handleSourceView();
                          },
                          icon: Icons.document_scanner,
                          label: 'View',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          // Main FAB button
          SizedBox(
            width: 120, // Same width as child buttons
            child: FloatingActionButton.extended(
              heroTag: "customMainFab",
              onPressed: _toggleCustomFab,
              backgroundColor: Theme.of(context).colorScheme.primary,
              icon: AnimatedRotation(
                turns: state.isFabExpanded ? 0.250 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  state.isFabExpanded ? Icons.close : Icons.menu,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              label: Text(
                'Menu',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _toggleCustomFab() {
    ref.read(homeControllerProvider.notifier).toggleFabExpansion();
    
    final isExpanded = ref.read(homeControllerProvider).isFabExpanded;
    if (isExpanded) {
      _customFabController.forward();
    } else {
      _customFabController.reverse();
    }
  }
  
  Widget _buildCustomFabButton({
    Key? key,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 120, // Fixed width to ensure alignment
      child: FloatingActionButton.extended(
        key: key,
        heroTag: "custom_$label",
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: color,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
