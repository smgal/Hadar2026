import 'dart:async';

import 'game_window.dart';

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
}
