import 'dart:io';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/models/session_summary.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

/// Repository for managing subtitle editing sessions
/// 
/// This repository abstracts database operations and business logic
/// from the UI layer, following the Repository Pattern for clean architecture.
/// 
/// Responsibilities:
/// - Fetch all sessions from database
/// - Get last edited session information
/// - Delete sessions and related data
/// - Update session metadata
/// - Analyze session content (line counts, languages, etc.)
/// 
/// Benefits:
/// - Single source of truth for session data
/// - Testable business logic separate from UI
/// - Consistent error handling and logging
/// - Easy to mock for testing
class SessionRepository {
  final Isar _isar;

  SessionRepository(this._isar);
  
  /// Fetches all sessions from the database in reverse chronological order
  /// 
  /// Returns a list of sessions sorted with newest first.
  /// Logs errors and returns empty list on failure.
  Future<List<Session>> fetchAllSessions() async {
    try {
      await logInfo('SessionRepository: Fetching all sessions from database');
      
      final sessions = await _isar.sessions.where().findAll();
      final reversedSessions = sessions.reversed.toList();
      
      await logInfo('SessionRepository: Successfully fetched ${reversedSessions.length} sessions');
      return reversedSessions;
    } catch (e, stackTrace) {
      await logError(
        'SessionRepository: Error fetching sessions',
        context: 'fetchAllSessions',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
  
  /// Gets the ID of the last edited session
  /// 
  /// Returns null if no session has been edited or if there's an error.
  Future<int?> getLastEditedSessionId() async {
    try {
      await logInfo('SessionRepository: Fetching last edited session ID');
      
      final preferences = await _isar.preferences.where().findFirst();
      final lastEditedId = preferences?.lastEditedSession;
      
      if (lastEditedId != null) {
        await logInfo('SessionRepository: Last edited session ID: $lastEditedId');
      } else {
        await logInfo('SessionRepository: No last edited session found');
      }
      
      return lastEditedId;
    } catch (e, stackTrace) {
      await logError(
        'SessionRepository: Error fetching last edited session ID',
        context: 'getLastEditedSessionId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
  
  /// Finds the last edited session from a list of sessions
  /// 
  /// Parameters:
  /// - [sessions]: List of all available sessions
  /// - [lastEditedId]: ID of the last edited session
  /// 
  /// Returns the session if found, null otherwise.
  Session? findLastEditedSession(List<Session> sessions, int? lastEditedId) {
    if (lastEditedId == null) return null;
    
    try {
      final session = sessions.firstWhere(
        (session) => session.id == lastEditedId,
      );
      
      logInfo('SessionRepository: Found last edited session: ${session.fileName}');
      return session;
    } catch (e) {
      logWarning(
        'SessionRepository: Last edited session with ID $lastEditedId not found in list',
        context: 'findLastEditedSession',
      );
      return null;
    }
  }
  
  /// Deletes a session and all its associated data
  /// 
  /// This permanently removes:
  /// - The session record
  /// - All subtitle lines
  /// - Related metadata
  /// 
  /// Parameters:
  /// Clear all session-owned persistence while preserving dictionary data and
  /// application preferences.
  Future<void> clearAllSessions() async {
    await logInfo('SessionRepository: Clearing all sessions');

    try {
      await _isar.writeTxn(() async {
        await _isar.sessions.clear();
        await _isar.subtitleCollections.clear();
        await _isar.checkpoints.clear();
        await _isar.videoPreferences.clear();
      });

      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final waveformDir = Directory('${appDocDir.path}/waveforms');
        if (await waveformDir.exists()) {
          await waveformDir.delete(recursive: true);
        }
      } catch (e, stackTrace) {
        await logError(
          'SessionRepository: Failed to clear waveform cache',
          context: 'clearAllSessions',
          error: e,
          stackTrace: stackTrace,
        );
      }

      await logInfo('SessionRepository: Cleared all sessions');
    } catch (e, stackTrace) {
      await logError(
        'SessionRepository: Failed to clear all sessions',
        context: 'clearAllSessions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// - [session]: Session to delete
  /// 
  /// Throws an exception if deletion fails.
  Future<void> removeSession(Session session) async {
    try {
      await logInfo(
        'SessionRepository: Deleting session: ${session.fileName}',
        context: 'removeSession',
      );
      
      await _isar.writeTxn(() async {
        await _isar.subtitleCollections.delete(session.subtitleCollectionId);
        await _isar.sessions.delete(session.id);
      });
      
      await logInfo(
        'SessionRepository: Successfully deleted session: ${session.fileName}',
        context: 'removeSession',
      );
    } catch (e, stackTrace) {
      await logError(
        'SessionRepository: Error deleting session: ${session.fileName}',
        context: 'removeSession',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// Updates the last edited session ID
  /// 
  /// Parameters:
  /// - [sessionId]: ID of the session to mark as last edited
  Future<void> setLastEditedSession(int sessionId) async {
    try {
      await logInfo(
        'SessionRepository: Updating last edited session to ID: $sessionId',
        context: 'setLastEditedSession',
      );
      
      if (sessionId <= 0) {
        throw ArgumentError.value(sessionId, 'sessionId', 'Must be positive');
      }

      await _isar.writeTxn(() async {
        final preferences =
            await _isar.preferences.where().findFirst() ??
            Preferences(autoSave: true);
        preferences.lastEditedSession = sessionId;
        await _isar.preferences.put(preferences);
      });
      
      await logInfo(
        'SessionRepository: Successfully updated last edited session',
        context: 'setLastEditedSession',
      );
    } catch (e, stackTrace) {
      await logError(
        'SessionRepository: Error updating last edited session',
        context: 'setLastEditedSession',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// Loads all Home-card summaries with one Isar bulk collection read.
  Future<Map<int, SessionSummary>> fetchSessionSummaries(
    List<Session> sessions,
  ) async {
    if (sessions.isEmpty) return const {};

    try {
      final collectionIds = sessions
          .map((session) => session.subtitleCollectionId)
          .toList(growable: false);
      final collections = await _isar.subtitleCollections.getAll(collectionIds);

      final summaries = <int, SessionSummary>{};
      for (int i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        final collection = i < collections.length ? collections[i] : null;
        summaries[session.id] = collection == null
            ? SessionSummary.empty(session)
            : SessionSummaryAnalyzer.analyze(session, collection.lines);
      }
      return summaries;
    } catch (e, stackTrace) {
      await logError(
        'SessionRepository: Error loading session summaries',
        context: 'fetchSessionSummaries',
        error: e,
        stackTrace: stackTrace,
      );

      return {
        for (final session in sessions)
          session.id: SessionSummary.empty(session),
      };
    }
  }

  /// Compatibility helper for callers that need one session summary.
  Future<SessionSummary> getSessionSummary(Session session) async {
    final summaries = await fetchSessionSummaries([session]);
    return summaries[session.id] ?? SessionSummary.empty(session);
  }

  Future<Map<String, dynamic>> getSessionInfo(Session session) async {
    final summary = await getSessionSummary(session);
    return {
      'totalLines': summary.totalLines,
      'editedLines': summary.editedLines,
      'lastEditedIndex': summary.lastEditedIndex,
      'languageCodes': summary.languageCodes,
      'languages': summary.languages,
    };
  }

  Future<bool> isMSoneSubtitle(Session session) async {
    final summary = await getSessionSummary(session);
    return summary.isMsoneSubtitle;
  }


  /// Reads the persisted Home session sort preference.
  Future<SessionSortOption> getSessionSortOption() async {
    final preferences = await _isar.preferences.where().findFirst();
    return preferences?.sessionSortOption ?? SessionSortOption.lastOpened;
  }

  /// Persists the Home session sort preference without global database access.
  Future<void> setSessionSortOption(SessionSortOption value) async {
    final existing = await _isar.preferences.where().findFirst();
    final preferences = existing ?? Preferences(autoSave: true);
    preferences.sessionSortOption = value;

    await _isar.writeTxn(() async {
      await _isar.preferences.put(preferences);
    });
  }

}
