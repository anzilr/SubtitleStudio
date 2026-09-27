import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists lightweight per-session activity metadata without changing Isar.
///
/// Timestamps are stored as UTC epoch milliseconds keyed by session ID.
class SessionActivityStore {
  static const _lastOpenedKey = 'session_last_opened_v1';

  Future<Map<int, int>> loadLastOpened({
    Set<int>? validSessionIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_lastOpenedKey);
    if (encoded == null || encoded.isEmpty) return {};

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return {};

      final result = <int, int>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key);
        final value = entry.value;
        final epochMs = value is int ? value : int.tryParse('$value');

        if (id == null || epochMs == null) continue;
        if (validSessionIds != null && !validSessionIds.contains(id)) {
          continue;
        }
        result[id] = epochMs;
      }

      if (validSessionIds != null && result.length != decoded.length) {
        await _save(result);
      }

      return result;
    } catch (_) {
      return {};
    }
  }

  Future<int> markOpened(
    int sessionId, {
    DateTime? openedAt,
  }) async {
    if (sessionId <= 0) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'Session ID must be positive.',
      );
    }

    final entries = await loadLastOpened();
    final epochMs =
        (openedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    entries[sessionId] = epochMs;
    await _save(entries);
    return epochMs;
  }

  Future<void> removeSession(int sessionId) async {
    final entries = await loadLastOpened();
    if (entries.remove(sessionId) != null) {
      await _save(entries);
    }
  }

  Future<void> _save(Map<int, int> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      entries.map((key, value) => MapEntry('$key', value)),
    );
    await prefs.setString(_lastOpenedKey, encoded);
  }
}
