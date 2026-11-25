import 'dart:async';

import 'game_window.dart';

/// A one-line text prompt (the character's name).
///
/// Holds no key handling of its own, like the other window data classes:
/// the view owns a text field and reports back through [submit] /
/// [cancel]. That keeps `application/` able to open it without importing
/// `presentation/`.
class HDTextInputWindow extends HDWindow {
  HDTextInputWindow({
    required this.prompt,
    this.maxLength = 8,
    this.initial = '',
    int? x,
    int? y,
  }) {
    this.x = x ?? 200;
    this.y = y ?? 140;
    w = 400;
    h = 132;
    isVisible = true;
  }

  final String prompt;
  final int maxLength;
  final String initial;

  final Completer<String?> _completer = Completer<String?>();

  Future<String?> get result => _completer.future;

  void submit(String text) {
    if (_completer.isCompleted) return;
    _completer.complete(text.trim());
  }

  void cancel() {
    if (_completer.isCompleted) return;
    _completer.complete(null);
  }
}
