import 'package:flutter/services.dart';

import '../../application/window_manager.dart';
import '../../domain/window/game_window.dart';
import '../../domain/window/magic_window_data.dart';
import '../../domain/window/message_window_data.dart';
import '../../domain/window/selection_window_data.dart';

/// Per-type key dispatch for the overlay window stack.
///
/// Window data classes (in `domain/window/`) used to own their own
/// `handleInput`, which coupled the domain model to Flutter's [KeyEvent].
/// The stack itself (`HDWindowManager`) then carried the routing, which
/// coupled `application/` to `presentation/`. Both concerns now meet
/// here: the dispatcher looks at the runtime type of the topmost visible
/// window and calls the matching domain method (`close`, `moveCursor`, …).
class HDWindowKeyDispatcher {
  static final HDWindowKeyDispatcher _instance =
      HDWindowKeyDispatcher._internal();
  factory HDWindowKeyDispatcher() => _instance;
  HDWindowKeyDispatcher._internal();

  /// Routes [event] to the topmost visible window that accepts it.
  /// Returns true once a window has consumed the key.
  bool handleInput(dynamic event) {
    final windows = HDWindowManager().windows;
    for (int i = windows.length - 1; i >= 0; i--) {
      if (windows[i].isVisible) {
        if (_dispatch(windows[i], event)) return true;
      }
    }
    return false;
  }

  bool _dispatch(HDWindow window, dynamic event) {
    if (window is HDMessageWindow) return _handleMessage(window, event);
    if (window is HDMagicSelectionWindow) return _handleMagic(window, event);
    if (window is HDSelectionWindow) return _handleSelection(window, event);
    return false;
  }

  bool _handleMessage(HDMessageWindow window, dynamic event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.keyE ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyQ) {
      window.close();
      return true;
    }
    return false;
  }

  bool _handleMagic(HDMagicSelectionWindow window, dynamic event) {
    if (event is! KeyEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      window.moveCursor(-1);
      return true;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      window.moveCursor(1);
      return true;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyE) {
      window.confirm();
      return true;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyQ) {
      window.cancel();
      return true;
    }
    return false;
  }

  bool _handleSelection(HDSelectionWindow window, dynamic event) {
    if (event is! KeyEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      window.moveCursor(-1);
      return true;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      window.moveCursor(1);
      return true;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyE) {
      window.confirm();
      return true;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyQ) {
      window.cancel();
      return true;
    }
    return false;
  }
}
