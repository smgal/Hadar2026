import 'dart:async';

import '../../hd_config.dart';
import 'game_window.dart';

/// Read-and-dismiss popup. Used for signs and similar one-shot messages —
/// shows [text] and closes on Enter/Esc (key handling lives in
/// `HDWindowManager._handleMessage`).
///
/// Width is fixed; height is capped at [HDConfig.messageWindowHeight]
/// so overlong messages clip rather than grow the box. Callers that need
/// scrolling/pagination should use the console dialogue path
/// (`UiHost.addLog` + `waitForAnyKey`) instead.
class HDMessageWindow extends HDWindow {
  String text = "";
  Completer<void>? _closeCompleter;

  HDMessageWindow(String text, {int? x, int? y}) {
    this.text = text;
    this.x = x ?? HDConfig.messageWindowX;
    this.y = y ?? HDConfig.messageWindowY;
    w = HDConfig.messageWindowWidth;
    h = HDConfig.messageWindowHeight;
    isVisible = true;
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
