import 'dart:async';
import 'package:flutter/services.dart';
import 'hd_window.dart';
import 'hd_magic.dart';
import 'hd_player.dart';

class HDMagicSelectionWindow extends HDWindow {
  final HDPlayer player;
  final List<HDMagic> magics;
  final String title;
  int selectedIndex = 0;
  Completer<int> _completer = Completer<int>();
  Future<int> get result => _completer.future;

  void resetCompleter() {
    _completer = Completer<int>();
  }

  HDSelectionMode mode = HDSelectionMode.category;

  // Selected category range
  int minId = 0;
  int maxId = 0;
  List<HDMagic> currentOptions = [];

  HDMagicSelectionWindow({
    required this.player,
    required this.title,
    required this.magics,
  }) {
    x = 200;
    y = 100;
    w = 400;
    h = 240;
    isVisible = true;
  }

  void selectCategory(int min, int max, List<HDMagic> options) {
    minId = min;
    maxId = max;
    currentOptions = options;
    mode = HDSelectionMode.magic;
    selectedIndex = 0;
    notifyListeners();
  }

  @override
  bool handleInput(dynamic event) {
    if (event is! KeyEvent) return false;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      moveCursor(-1);
      return true;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      moveCursor(1);
      return true;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyE) {
      confirm();
      return true;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyQ) {
      cancel();
      return true;
    }
    return false;
  }

  void moveCursor(int delta) {
    int count = (mode == HDSelectionMode.category)
        ? 4
        : currentOptions.length + 1;

    selectedIndex = (selectedIndex + delta) % count;
    if (selectedIndex < 0) selectedIndex = count - 1;
    notifyListeners();
  }

  void confirm() {
    if (mode == HDSelectionMode.category) {
      if (selectedIndex == 3) {
        _completer.complete(-1);
        return;
      }

      // Instead of completing, we change mode and notify
      if (selectedIndex == 0) {
        final options = getAvailableSpells(player, 1, 18);
        selectCategory(1, 18, options);
      } else if (selectedIndex == 1) {
        final options = getAvailableSpells(player, 19, 32);
        selectCategory(19, 32, options);
      } else if (selectedIndex == 2) {
        final options = getAvailableSpells(player, 33, 39);
        selectCategory(33, 39, options);
      }
    } else {
      if (selectedIndex == currentOptions.length) {
        mode = HDSelectionMode.category;
        selectedIndex = 0;
        notifyListeners();
      } else {
        _completer.complete(currentOptions[selectedIndex].index);
      }
    }
  }

  List<HDMagic> getAvailableSpells(HDPlayer player, int minId, int maxId) {
    int availableSpells = (minId >= 40) ? player.level[2] : player.level[1];
    if (availableSpells > (maxId - minId + 1))
      availableSpells = (maxId - minId + 1);

    List<HDMagic> list = [];
    for (int i = 0; i < availableSpells; i++) {
      list.add(HDMagicMap.getMagic(minId + i));
    }
    return list;
  }

  void cancel() {
    if (mode == HDSelectionMode.magic) {
      mode = HDSelectionMode.category;
      selectedIndex = 0;
      notifyListeners();
    } else {
      _completer.complete(-1);
    }
  }
}

enum HDSelectionMode { category, magic, target }
