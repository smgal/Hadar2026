import 'package:flutter/foundation.dart';

import '../domain/window/game_window.dart';

/// Stack of overlay windows.
///
/// Holds only the stack — push/pop/clear plus visibility. Key routing
/// used to live here too, which forced `application/` code that opens a
/// window (magic selection, battle menus) to import from
/// `presentation/`. Input is a rendering-surface concern, so it now
/// lives in `presentation/input/window_key_dispatcher.dart`; what remains
/// is pure state over `domain/window/` types and belongs in the
/// application layer.
class HDWindowManager extends ChangeNotifier {
  static final HDWindowManager _instance = HDWindowManager._internal();
  factory HDWindowManager() => _instance;
  HDWindowManager._internal();

  final List<HDWindow> _windows = [];

  List<HDWindow> get windows => List.unmodifiable(_windows);

  void addWindow(HDWindow window) {
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
}
