/// The portable history-reference naming rules shared by storage and UI.
///
/// Keep these rules stable: branch and bookmark names are persisted in .msone
/// projects, and invalid names must be rejected before opening a transaction.
class HistoryReferenceNaming {
  const HistoryReferenceNaming._();

  static String? validationError(String name, String kind) {
    if (kind == 'head') return name == 'HEAD' ? null : 'Invalid history name.';
    final prefix = switch (kind) {
      'branch' => 'refs/heads/',
      'bookmark' => 'refs/bookmarks/',
      _ => '',
    };
    if (prefix.isEmpty || !name.startsWith(prefix)) {
      return 'Invalid history name.';
    }
    final suffix = name.substring(prefix.length);
    if (suffix.isEmpty) return 'Enter a name for this ${kind == 'branch' ? 'branch' : 'bookmark'}.';
    if (name.length > 180) return 'Name is too long (180 characters maximum).';
    if (suffix.contains(RegExp(r'\s'))) {
      return 'Use hyphens or underscores instead of spaces.';
    }
    final validPart = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$');
    for (final part in suffix.split('/')) {
      if (part == '.' || part == '..' || part.endsWith('.lock') ||
          !validPart.hasMatch(part)) {
        return 'Each name part must start with a letter or number and use only letters, numbers, dots, hyphens or underscores.';
      }
    }
    return null;
  }

  static bool isValid(String name, String kind) =>
      validationError(name, kind) == null;
}
