/// Converts a user-visible 1-based subtitle cue number to a zero-based
/// in-memory list index.
///
/// Returns null for missing or invalid cue numbers so callers can reject stale
/// persisted values without throwing during startup/navigation.
int? cueNumberToListIndex(int? cueNumber) {
  if (cueNumber == null || cueNumber < 1) return null;
  return cueNumber - 1;
}

/// Converts a zero-based in-memory list index to a persisted/display cue number.
int listIndexToCueNumber(int listIndex) {
  if (listIndex < 0) {
    throw RangeError.value(
      listIndex,
      'listIndex',
      'Subtitle list indexes must be zero or greater.',
    );
  }
  return listIndex + 1;
}
