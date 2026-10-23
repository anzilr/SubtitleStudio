/// Immutable subtitle cue projection used by the read-only Studio Dock
/// integration. Domain storage and rendering are deliberately separate.
class StudioDockLoadedCue {
  const StudioDockLoadedCue({
    required this.index,
    required this.start,
    required this.end,
    required this.original,
    required this.edited,
    required this.marked,
    this.storedEdited,
    this.comment,
    this.resolved = false,
  });

  final int index;
  final String start;
  final String end;
  final String original;
  final String edited;
  final bool marked;
  // Original persisted values preserved for optimistic concurrency checking.
  final String? storedEdited;
  final String? comment;
  final bool resolved;
}

class StudioDockSessionSnapshot {
  StudioDockSessionSnapshot({
    required this.sessionId,
    required this.collectionId,
    required this.fileName,
    required this.encoding,
    required List<StudioDockLoadedCue> cues,
  }) : cues = List<StudioDockLoadedCue>.unmodifiable(cues);

  final int sessionId;
  final int collectionId;
  final String fileName;
  final String encoding;
  final List<StudioDockLoadedCue> cues;
}
