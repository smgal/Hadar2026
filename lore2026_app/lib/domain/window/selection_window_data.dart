import 'dart:async';
import 'dart:math' as math;
import 'game_window.dart';

class HDSelectionWindow extends HDWindow {
  final List<String> choices;
  int selectedIndex;
  final int enabledCount;
  final Completer<int> _completer = Completer<int>();

  final int maxVisibleItems = 6;
  int displayStartIndex = 1;

  Future<int> get result => _completer.future;

  HDSelectionWindow({
    required this.choices,
    this.selectedIndex = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  }) : enabledCount = (enabledCount == -1) ? choices.length - 1 : enabledCount {
    this.x = x ?? 200;
    this.y = y ?? 100;
    w = 400;
    int displayCount = math.min(this.enabledCount, maxVisibleItems);
    // Fixed chrome: outer padding 16 + header ~36 (Korean bold + border + padding) + spacer 8 = ~60.
    // Each ListView row renders at ~33 (Korean fontSize-16 text or 16px icon + 4px vertical padding).
    h = 60 + (displayCount * 34);
    isVisible = true;
    _adjustDisplayWindow();
  }

  bool get hasMoreAbove => displayStartIndex > 1;
  bool get hasMoreBelow =>
      (displayStartIndex + maxVisibleItems - 1) < enabledCount;

  void _adjustDisplayWindow() {
    if (selectedIndex < displayStartIndex) {
      displayStartIndex = selectedIndex;
    } else if (selectedIndex >= displayStartIndex + maxVisibleItems) {
      displayStartIndex = selectedIndex - maxVisibleItems + 1;
    }
  }

  void moveCursor(int delta) {
    if (enabledCount <= 0) return;
    selectedIndex += delta;
    if (selectedIndex < 1) {
      selectedIndex = enabledCount;
    } else if (selectedIndex > enabledCount) {
      selectedIndex = 1;
    }
    _adjustDisplayWindow();
    notifyListeners();
  }

  void confirm() {
    _completer.complete(selectedIndex);
  }

  void cancel() {
    _completer.complete(0); // 0 is usually ESC/Cancel
  }
}
