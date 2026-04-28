import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/window/game_window.dart';
import '../domain/window/magic_window_data.dart';
import '../domain/window/message_window_data.dart';

/// Stack of overlay windows + per-type key dispatch.
///
/// Window data classes (in `domain/window/`) used to own their own
/// `handleInput`. That coupled the domain model to Flutter's [KeyEvent].
/// Now the manager looks at the runtime type of the top window and routes
/// the key event to the right domain method (`close`, `moveCursor`, etc.).
class HDWindowManager extends ChangeNotifier {
  static final HDWindowManager _instance = HDWindowManager._internal();
  factory HDWindowManager() => _instance;
  HDWindowManager._internal();

  final List<HDWindow> _windows = [];

  List<HDWindow> get windows => List.unmodifiable(_windows);

  void addWindow(HDWindow window) {
    print(
      "HDWindowManager: Adding window $window. Total: ${_windows.length + 1}",
    );
    _windows.add(window);
    notifyListeners();
  }

  void removeWindow(HDWindow window) {
    _windows.remove(window);
    notifyListeners();
  }

  void clear() {
    _windows.clear();
    notifyListeners();
  }

  /// Hides the topmost visible window and notifies listeners.
  /// Returns true if a window was hidden.
  bool hideTopWindow() {
    if (_windows.isEmpty) return false;
    _windows.last.isVisible = false;
    notifyListeners();
    return true;
  }

  bool handleInput(dynamic event) {
    for (int i = _windows.length - 1; i >= 0; i--) {
      if (_windows[i].isVisible) {
        if (_dispatch(_windows[i], event)) return true;
      }
    }
    return false;
  }

  bool _dispatch(HDWindow window, dynamic event) {
    if (window is HDMessageWindow) return _handleMessage(window, event);
    if (window is HDMagicSelectionWindow) return _handleMagic(window, event);
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
}
