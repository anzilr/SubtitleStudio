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

    test('lastOpened sorts by recorded open time then falls back to newest ID', () {
      final state = HomeState(
        isLoading: false,
        recentSessions: [
          _session(1, 'one.srt'),
          _session(5, 'five.srt'),
          _session(2, 'two.srt'),
          _session(3, 'three.srt'),
        ],
        sessionLastOpenedEpochMs: const {
          2: 3000,
          3: 2000,
        },
        sortOption: SessionSortOption.lastOpened,
      );

      expect(
        state.filteredSessions.map((session) => session.id),
        [2, 3, 5, 1],
      );
    });

    test('lastOpened uses deterministic newest-ID order before tracking exists', () {
      final state = HomeState(
        isLoading: false,
        recentSessions: [
          _session(1, 'one.srt'),
          _session(5, 'five.srt'),
          _session(2, 'two.srt'),
          _session(3, 'three.srt'),
        ],
        sortOption: SessionSortOption.lastOpened,
      );

      expect(
        state.filteredSessions.map((session) => session.id),
        [5, 3, 2, 1],
      );
    });
  });
}
