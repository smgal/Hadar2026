import 'dart:async';
import 'package:flutter/services.dart';
import 'hd_window.dart';

class HDMessageWindow extends HDWindow {
  String text = "";
  Completer<void>? _closeCompleter;

  HDMessageWindow(String text) {
    this.text = text;
  }

  Future<void> waitForClose() {
    _closeCompleter = Completer<void>();
    return _closeCompleter!.future;
  }

  void close() {
    if (_closeCompleter != null && !_closeCompleter!.isCompleted) {
      _closeCompleter!.complete();
    }
    isVisible = false;
    notifyListeners();
  }

  @override
  bool handleInput(dynamic event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        close();
        return true;
      }
    }
    return false; // Propagate if not handled? Or block all input?
    // For modal dialog, we probably want to block all input.
    // So return true always?
    // Better to return true to consume input.
  }
}
