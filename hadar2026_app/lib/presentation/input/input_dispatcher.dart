import 'package:flutter/services.dart';
import '../../game_components/hd_game_main.dart';
import '../window_manager.dart';
import 'input_mode.dart';

/// Routes hardware/virtual key events to the right subsystem based on the
/// current [HDInputMode]. Holds no game state of its own — reads/mutates
/// [HDGameMain] directly. Will become the host for per-mode strategies once
/// menu/window state moves out of [HDGameMain].
class HDInputDispatcher {
  static final HDInputDispatcher _instance = HDInputDispatcher._internal();
  factory HDInputDispatcher() => _instance;

  bool _registered = false;

  HDInputDispatcher._internal();

  /// Hooks into [HardwareKeyboard]. Idempotent — safe to call multiple times.
  void registerGlobalHandler() {
    if (_registered) return;
    _registered = true;
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event is! KeyDownEvent) return false;
      return process(event.logicalKey);
    });
  }

  bool process(LogicalKeyboardKey key) {
    final game = HDGameMain();
    final mode = game.currentInputMode;

    if (mode == HDInputMode.window) return _handleWindow(key);
    if (mode == HDInputMode.menu) return _handleMenu(key, game);
    if (mode == HDInputMode.dialogue) return _handleDialogue(key, game);
    if (mode == HDInputMode.map) return _handleMap(key, game);
    return false;
  }

  bool _handleWindow(LogicalKeyboardKey key) {
    final event = KeyDownEvent(
      physicalKey:
          PhysicalKeyboardKey.findKeyByCode(key.keyId) ??
          PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

    if (HDWindowManager().handleInput(event)) return true;

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyQ) {
      HDWindowManager().hideTopWindow();
      return true;
    }
    return true; // Consume all keys when windows are open
  }

  bool _handleMenu(LogicalKeyboardKey key, HDGameMain game) {
    final menu = game.activeMenu!;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      menu.selectedIndex--;
      if (menu.selectedIndex < 1) menu.selectedIndex = menu.enabledCount;
      game.refresh();
      return true;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      menu.selectedIndex++;
      if (menu.selectedIndex > menu.enabledCount) menu.selectedIndex = 1;
      game.refresh();
      return true;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.keyE ||
        key == LogicalKeyboardKey.space) {
      final result = menu.selectedIndex;
      game.activeMenu = null;
      menu.completer.complete(result);
      game.refresh();
      return true;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyQ) {
      game.activeMenu = null;
      menu.completer.complete(0);
      game.refresh();
      return true;
    }
    return true; // Consume all keys while menu is active
  }

  bool _handleDialogue(LogicalKeyboardKey key, HDGameMain game) {
    final isDirectional =
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyD;

    final isModifier =
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;

    if (!isDirectional && !isModifier) {
      game.dismissKeyWait();
      return true;
    }
    return false;
  }

  bool _handleMap(LogicalKeyboardKey key, HDGameMain game) {
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyQ ||
        key == LogicalKeyboardKey.space) {
      game.showMainMenu();
      return true;
    }

    // Test time control keys
    final party = game.party;
    if (key == LogicalKeyboardKey.insert) {
      party.hour = 5;
      party.min = 59;
      party.notifyListeners();
      return true;
    } else if (key == LogicalKeyboardKey.delete) {
      party.hour = 18;
      party.min = 9;
      party.notifyListeners();
      return true;
    } else if (key == LogicalKeyboardKey.home) {
      party.hour = 12;
      party.min = 0;
      party.notifyListeners();
      return true;
    } else if (key == LogicalKeyboardKey.end) {
      party.hour = 0;
      party.min = 0;
      party.notifyListeners();
      return true;
    }

    // Action (Enter/E) is handled by HDPlayerSprite for now to know
    // facing/position.
    return false;
  }
}
