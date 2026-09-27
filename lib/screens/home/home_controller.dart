import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/models/preferences_model.dart';
import 'package:subtitle_studio/screens/home/home_state.dart';
import 'package:subtitle_studio/screens/home/models/session_summary.dart';
import 'package:subtitle_studio/screens/home/repositories/session_repository.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

/// Provides the session repository used by the Riverpod Home controller.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(isarProvider)),
);

/// Riverpod controller for Home screen state and session workflows.
final homeControllerProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

class HomeController extends Notifier<HomeState> {
  SessionRepository get _repository => ref.read(sessionRepositoryProvider);

  @override
  HomeState build() {
    logInfo('HomeController: Initialized');
    ref.onDispose(() {
      logInfo('HomeController: Disposed');
    });
    return HomeState.initial();
  }

  Future<void> loadSessions() async {
    try {
      await logInfo('HomeController: Starting to load sessions');

      state = state.copyWith(isLoading: true, clearError: true);

      final sessions = await _repository.fetchAllSessions();
      final lastEditedId = await _repository.getLastEditedSessionId();
      final sortOption = await PreferencesModel.getSessionSortOption();
      final sessionSummaries = await _repository.fetchSessionSummaries(sessions);

      await logInfo(
        'HomeController: Fetched ${sessions.length} sessions, '
        'lastEditedId: $lastEditedId, sortOption: $sortOption',
      );

      final lastEditedSession = _repository.findLastEditedSession(
        sessions,
        lastEditedId,
      );

      if (lastEditedSession != null) {
        await logInfo(
          'HomeController: Last edited session: '
          '${lastEditedSession.fileName}',
        );
      } else {
        await logInfo('HomeController: No last edited session found');
      }

      state = state.copyWith(
        isLoading: false,
        recentSessions: sessions,
        lastEditedSession: lastEditedSession,
        sessionSummaries: sessionSummaries,
        sortOption: sortOption,
        clearError: true,
      );

      await logInfo('HomeController: Successfully loaded sessions');
    } catch (e, stackTrace) {
      await logError(
        'HomeController: Error loading sessions',
        context: 'loadSessions',
        error: e,
        stackTrace: stackTrace,
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load recent sessions. Please try again.',
      );
    }
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    logInfo('HomeController: Clearing search query');
    state = state.copyWith(searchQuery: '');
  }

  Future<void> changeSortOption(SessionSortOption sortOption) async {
    try {
      logInfo('HomeController: Changing sort option to: $sortOption');

      state = state.copyWith(sortOption: sortOption);
      await PreferencesModel.setSessionSortOption(sortOption);

      logInfo(
        'HomeController: Successfully changed sort option to: $sortOption',
      );
    } catch (e, stackTrace) {
      await logError(
        'HomeController: Error changing sort option',
        context: 'changeSortOption',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void toggleFabExpansion() {
    final newState = !state.isFabExpanded;
    logInfo('HomeController: Toggling FAB expansion to: $newState');
    state = state.copyWith(isFabExpanded: newState);
  }

  void collapseFab() {
    if (state.isFabExpanded) {
      logInfo('HomeController: Collapsing FAB');
      state = state.copyWith(isFabExpanded: false);
    }
  }

  Future<void> deleteSession(Session session) async {
    try {
      await logInfo(
        'HomeController: Deleting session: ${session.fileName}',
      );

      await _repository.removeSession(session);

      final updatedSessions = List<Session>.from(state.recentSessions)
        ..removeWhere((item) => item.id == session.id);

      final shouldClearLastEdited =
          state.lastEditedSession?.id == session.id;
      final updatedSummaries = Map<int, SessionSummary>.from(
        state.sessionSummaries,
      )..remove(session.id);

      state = state.copyWith(
        recentSessions: updatedSessions,
        sessionSummaries: updatedSummaries,
        clearLastEditedSession: shouldClearLastEdited,
        clearError: true,
      );

      await logInfo(
        'HomeController: Successfully deleted session: '
        '${session.fileName}',
      );
    } catch (e, stackTrace) {
      await logError(
        'HomeController: Error deleting session: ${session.fileName}',
        context: 'deleteSession',
        error: e,
        stackTrace: stackTrace,
      );

      state = state.copyWith(
        errorMessage: 'Could not delete the session. Please try again.',
      );

      rethrow;
    }
  }

  Future<void> updateLastEditedSession(int sessionId) async {
    try {
      await logInfo(
        'HomeController: Updating last edited session to: $sessionId',
      );

      await _repository.setLastEditedSession(sessionId);

      await logInfo(
        'HomeController: Successfully updated last edited session',
      );
    } catch (e, stackTrace) {
      await logError(
        'HomeController: Error updating last edited session',
        context: 'updateLastEditedSession',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> getSessionInfo(Session session) async {
    try {
      return await _repository.getSessionInfo(session);
    } catch (e, stackTrace) {
      await logError(
        'HomeController: Error getting session info',
        context: 'getSessionInfo',
        error: e,
        stackTrace: stackTrace,
      );

      return {
        'totalLines': 0,
        'editedLines': 0,
        'lastEditedIndex': 1,
        'languageCodes': 'EN',
        'languages': ['EN'],
      };
    }
  }

  Future<bool> isMSoneSubtitle(Session session) async {
    try {
      return await _repository.isMSoneSubtitle(session);
    } catch (e, stackTrace) {
      await logError(
        'HomeController: Error checking MSone subtitle',
        context: 'isMSoneSubtitle',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void clearError() {
    logInfo('HomeController: Clearing error message');
    state = state.copyWith(clearError: true);
  }
}
