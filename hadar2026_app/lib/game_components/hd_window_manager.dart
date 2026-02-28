import 'package:flutter/foundation.dart';
import '../models/hd_window.dart';

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

  bool handleInput(dynamic event) {
    // Pass input to the top-most visible window
    // Iterate backwards to find top-most
    for (int i = _windows.length - 1; i >= 0; i--) {
      if (_windows[i].isVisible) {
        if (_windows[i].handleInput(event)) {
          return true;
        }
      }
    }
    return false;
  }
}
