import 'package:flutter/material.dart';

/// Storage for the dialogue/event console.
///
/// Note: this currently holds pre-wrapped [TextSpan] lines because the
/// wrapping (which uses Flutter's [TextPainter]) has not yet been pushed out
/// to the view layer. Once the wrap step moves into the UiHost
/// implementation, the type here will become `List<String>` (raw text with
/// `@X..@@` color tags).
class HDConsoleLog {
  /// Story / event lines (paginated; cleared on overflow).
  final List<TextSpan> events = [];

  /// System / progress lines (auto-scrolled).
  final List<TextSpan> progress = [];

  void clearEvents() {
    events.clear();
  }

  void appendEvent(TextSpan line) {
    events.add(line);
  }

  void appendProgress(TextSpan line, {required int maxLinesPerPage}) {
    if (progress.length >= maxLinesPerPage) {
      progress.removeAt(0);
    }
    progress.add(line);
  }
}
