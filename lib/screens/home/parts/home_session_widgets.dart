part of '../../screen_home.dart';

extension _HomeSessionWidgets on _HomeScreenContentState {
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your subtitle sessions...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
  
  Widget _buildWelcomeHeader(HomeState state) {
    final hasLastEdited = state.lastEditedSession != null;
    final isFirstTime = !state.hasSessions;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.subtitles_outlined,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFirstTime ? 'Welcome to Subtitle Studio!' : 'Ready to continue editing?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasLastEdited) ...[
            Text(
              'Continue with: ${state.lastEditedSession!.fileName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _navigateToEditScreen(state.lastEditedSession!),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Continue Editing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ] else ...[
            Text(
              isFirstTime 
                  ? 'Start creating your first subtitle project'
                  : 'Ready to start your next subtitle project',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSearchBar(HomeState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => ref.read(homeControllerProvider.notifier).updateSearchQuery(value),
        decoration: InputDecoration(
          hintText: 'Search subtitle files...',
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          suffixIcon: state.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(homeControllerProvider.notifier).clearSearch();
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
  
  Widget _buildSessionsList(HomeState state) {
    final filteredSessions = state.filteredSessions;
    
    if (filteredSessions.isEmpty) {
      return _buildEmptyState(state);
    }
  
    // Use responsive layout to determine if we should show grid or list
    if (ResponsiveLayout.shouldUseDesktopLayout(context)) {
      // Desktop layout: use grid view
      final columns = ResponsiveLayout.getGridColumns(context);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 180, // Fixed height that fits the content properly
        ),
        itemCount: filteredSessions.length,
        itemBuilder: (context, index) {
          final session = filteredSessions[index];
          return _buildSessionCard(session, index, state);
        },
      );
    } else {
      // Mobile layout: use list view
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: filteredSessions.length,
        itemBuilder: (context, index) {
          final session = filteredSessions[index];
          return _buildSessionCard(session, index, state);
        },
      );
    }
  }
  
  Widget _buildEmptyState(HomeState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            state.searchQuery.isNotEmpty ? Icons.search_off : Icons.subtitles_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            state.searchQuery.isNotEmpty 
                ? 'No subtitle files match your search'
                : 'No subtitle sessions found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            state.searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Create your first subtitle project to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          if (state.searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleImport,
              icon: Icon(Icons.file_open, color: Theme.of(context).colorScheme.onPrimary,),
              label: const Text('Open SRT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                fixedSize: Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _handleCreate,
              icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary,),
              label: const Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                fixedSize: Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSessionCard(Session session, int index, HomeState state) {
    final summary =
        state.sessionSummaries[session.id] ?? SessionSummary.empty(session);
  
    return SessionCard(
      session: session,
      summary: summary,
      isLastEdited: state.lastEditedSession?.id == session.id,
      onTap: () => _navigateToEditScreen(session),
      onDelete: () => _showDeleteConfirmation(session),
    );
  }
}
