import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/home_state.dart';

Session _session(int id, String name) {
  return Session(
    fileName: name,
    subtitleCollectionId: id,
  )..id = id;
}

void main() {
  group('HomeState session sorting', () {
    test('lastCreated explicitly sorts newest session ID first', () {
      final state = HomeState(
        isLoading: false,
        recentSessions: [
          _session(2, 'two.srt'),
          _session(5, 'five.srt'),
          _session(1, 'one.srt'),
        ],
        sortOption: SessionSortOption.lastCreated,
      );

      expect(
        state.filteredSessions.map((session) => session.id),
        [5, 2, 1],
      );
    });

    test('lastOpened pins active session then uses stable newest-first fallback', () {
      final active = _session(2, 'two.srt');
      final state = HomeState(
        isLoading: false,
        recentSessions: [
          _session(1, 'one.srt'),
          _session(5, 'five.srt'),
          active,
          _session(3, 'three.srt'),
        ],
        lastEditedSession: active,
        sortOption: SessionSortOption.lastOpened,
      );

      expect(
        state.filteredSessions.map((session) => session.id),
        [2, 5, 3, 1],
      );
    });
  });
}
