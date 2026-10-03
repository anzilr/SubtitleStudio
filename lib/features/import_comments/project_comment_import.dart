import 'package:subtitle_studio/services/project_document_codec.dart';

class ProjectCommentImportEntry {
  final int index;
  final String comment;
  final bool marked;
  final bool resolved;

  const ProjectCommentImportEntry({
    required this.index,
    required this.comment,
    required this.marked,
    required this.resolved,
  });
}

class ProjectCommentImportPlan {
  final List<ProjectCommentImportEntry> entries;

  const ProjectCommentImportPlan(this.entries);

  int get count => entries.length;

  factory ProjectCommentImportPlan.fromDocument(ProjectDocument document) {
    final entries = <ProjectCommentImportEntry>[];

    for (final line in document.subtitleCollection.lines) {
      final index = line.validIndex;
      final comment = line.comment;
      if (index == null || comment == null || comment.trim().isEmpty) {
        continue;
      }

      entries.add(
        ProjectCommentImportEntry(
          index: index,
          comment: comment,
          marked: line.marked,
          resolved: line.resolved,
        ),
      );
    }

    return ProjectCommentImportPlan(entries);
  }
}
