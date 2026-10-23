import 'package:equatable/equatable.dart';
import '../../database/models/models.dart';
import 'package:subtitle_studio/screens/home/models/session_summary.dart';

/// Represents the state of the Home Screen
/// 
/// This is an immutable state class that uses Equatable for value equality.
/// The state is managed by HomeController through Riverpod and drives the UI rendering.
/// 
/// State Properties:
/// - [isLoading]: Whether the screen is in loading state
/// - [recentSessions]: List of all sessions from database
/// - [lastEditedSession]: The most recently edited session
/// - [searchQuery]: Current search filter text
/// - [isFabExpanded]: Whether the custom FAB menu is expanded
/// - [sortOption]: Current sorting option for sessions
/// - [errorMessage]: Error message to display to user (if any)
/// 
/// State Flow:
/// 1. Initial state: loading = true, empty sessions
/// 2. Loaded state: loading = false, sessions populated
/// 3. Error state: loading = false, errorMessage set
class HomeState extends Equatable {
  final bool isLoading;
  final List<Session> recentSessions;
  final Session? lastEditedSession;
  final Map<int, SessionSummary> sessionSummaries;
  final Map<int, int> sessionLastOpenedEpochMs;
  final String searchQuery;
  final bool isFabExpanded;
  final SessionSortOption sortOption;
  final String? errorMessage;

  const HomeState({
    this.isLoading = true,
    this.recentSessions = const [],
    this.lastEditedSession,
    this.sessionSummaries = const {},
    this.sessionLastOpenedEpochMs = const {},
    this.searchQuery = '',
    this.isFabExpanded = false,
    this.sortOption = SessionSortOption.lastOpened,
    this.errorMessage,
  });

  /// Initial state when screen is first created
  factory HomeState.initial() => const HomeState(
        isLoading: true,
        recentSessions: [],
        lastEditedSession: null,
        sessionSummaries: {},
        sessionLastOpenedEpochMs: {},
        searchQuery: '',
        isFabExpanded: false,
        sortOption: SessionSortOption.lastOpened,
        errorMessage: null,
      );

  /// Creates a copy of this state with optional field overrides
  HomeState copyWith({
    bool? isLoading,
    List<Session>? recentSessions,
    Session? lastEditedSession,
    Map<int, SessionSummary>? sessionSummaries,
    Map<int, int>? sessionLastOpenedEpochMs,
    String? searchQuery,
    bool? isFabExpanded,
    SessionSortOption? sortOption,
    String? errorMessage,
    bool clearLastEditedSession = false,
    bool clearError = false,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      recentSessions: recentSessions ?? this.recentSessions,
      lastEditedSession: clearLastEditedSession
          ? null
          : (lastEditedSession ?? this.lastEditedSession),
      sessionSummaries: sessionSummaries ?? this.sessionSummaries,
      sessionLastOpenedEpochMs:
          sessionLastOpenedEpochMs ?? this.sessionLastOpenedEpochMs,
      searchQuery: searchQuery ?? this.searchQuery,
      isFabExpanded: isFabExpanded ?? this.isFabExpanded,
      sortOption: sortOption ?? this.sortOption,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Returns filtered sessions based on search query
  /// 
  /// Filters by case-insensitive substring match on fileName.
  /// Sorts results based on the selected sort option.
  List<Session> get filteredSessions {
    List<Session> sessions;
    
    if (searchQuery.isEmpty) {
      sessions = List.from(recentSessions);
    } else {
      sessions = recentSessions
          .where((session) =>
              session.fileName.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    // Apply sorting based on selected option
    switch (sortOption) {
      case SessionSortOption.lastOpened:
        sessions.sort((a, b) {
          final aOpened = sessionLastOpenedEpochMs[a.id];
          final bOpened = sessionLastOpenedEpochMs[b.id];

          if (aOpened != null && bOpened != null && aOpened != bOpened) {
            return bOpened.compareTo(aOpened);
          }
          if (aOpened != null && bOpened == null) return -1;
          if (aOpened == null && bOpened != null) return 1;

          // Existing sessions created before activity tracking fall back to
          // deterministic newest-ID order until they are opened once.
          return b.id.compareTo(a.id);
        });
        break;

      case SessionSortOption.lastCreated:
        // Isar auto-increment IDs are monotonic for newly inserted sessions.
        // Sort explicitly instead of relying on query iteration order.
        sessions.sort((a, b) => b.id.compareTo(a.id));
        break;
        
      case SessionSortOption.name:
        // Sort alphabetically by file name (A-Z)
        sessions.sort((a, b) => 
          a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
        break;
        
      case SessionSortOption.nameDesc:
        // Sort reverse alphabetically by file name (Z-A)
        sessions.sort((a, b) => 
          b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase()));
        break;
    }

    return sessions;
  }

  /// Whether the screen has sessions to display
  bool get hasSessions => recentSessions.isNotEmpty;

  /// Whether there's an active search with no results.
  ///
  /// Avoid calling [filteredSessions] here because that getter also sorts and
  /// allocates a list; the UI may already have requested it for the same build.
  bool get hasNoSearchResults {
    if (searchQuery.isEmpty) return false;
    final normalizedQuery = searchQuery.toLowerCase();
    return !recentSessions.any(
      (session) => session.fileName.toLowerCase().contains(normalizedQuery),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        recentSessions,
        lastEditedSession,
        sessionSummaries,
        sessionLastOpenedEpochMs,
        searchQuery,
        isFabExpanded,
        sortOption,
        errorMessage,
      ];

  @override
  String toString() {
    return 'HomeState(isLoading: $isLoading, '
        'sessionsCount: ${recentSessions.length}, '
        'lastEditedSession: ${lastEditedSession?.fileName}, '
        'searchQuery: "$searchQuery", '
        'isFabExpanded: $isFabExpanded, '
        'sortOption: $sortOption, '
        'hasError: ${errorMessage != null})';
  }
}
