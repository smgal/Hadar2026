/// Storage for the dialogue/event console.
///
/// Lines are stored as raw text with `@X..@@` color tags (see
/// `HDTextUtils`). Wrap to a specific pixel width happens in the host
/// (`HDFlutterUiHost`) before [appendEvent] / [appendProgress] is called,
/// so each entry already represents one displayable line. The view layer
/// re-parses the raw string back into colored spans at render time.
class HDConsoleLog {
  /// Story / event lines (paginated; cleared on overflow).
  final List<String> events = [];

  /// System / progress lines (auto-scrolled).
  final List<String> progress = [];

  void clearEvents() {
    events.clear();
  }

  void clearProgress() {
    progress.clear();
  }

  void appendEvent(String line) {
    events.add(line);
  }

  void appendProgress(String line, {required int maxLinesPerPage}) {
    if (progress.length >= maxLinesPerPage) {
      progress.removeAt(0);
    }
    progress.add(line);
  }
}
