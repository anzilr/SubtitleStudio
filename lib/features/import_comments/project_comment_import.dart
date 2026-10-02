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
    final rawLines = document.subtitleCollection['lines'];
    if (rawLines is! List) return const ProjectCommentImportPlan([]);

    final entries = <ProjectCommentImportEntry>[];
    for (final rawLine in rawLines) {
      if (rawLine is! Map) continue;

      final line = Map<String, dynamic>.from(rawLine);
      final index = line['index'];
      final comment = line['comment'];

      if (index is! int ||
          comment is! String ||
          comment.trim().isEmpty) {
        continue;
      }

      entries.add(
        ProjectCommentImportEntry(
          index: index,
          comment: comment,
          marked: line['marked'] is bool ? line['marked'] as bool : false,
          resolved:
              line['resolved'] is bool ? line['resolved'] as bool : false,
        ),
      );
    }

    return ProjectCommentImportPlan(entries);
  }
}
