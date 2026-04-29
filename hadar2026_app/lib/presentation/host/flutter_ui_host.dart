import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/console/console_log.dart';
import '../../hd_config.dart';
import '../../utils/hd_text_utils.dart';
import 'ui_host.dart';

/// One-shot menu request: a title row plus N selectable choices.
/// Lives in the host because it is purely a render/input artifact —
/// domain code talks to [UiHost.showMenu] and never sees this type.
class HDMenu {
  final List<String> items; // Index 0 is title, items 1+ are choices
  int selectedIndex;
  int enabledCount;
  final bool clearLogs;
  final Completer<int> completer = Completer<int>();

  HDMenu(
    this.items, {
    int initialChoice = 1,
    int enabledCount = -1,
    this.clearLogs = true,
  }) : selectedIndex = initialChoice,
       enabledCount = (enabledCount == -1) ? items.length - 1 : enabledCount;
}

/// Concrete [UiHost] backed by the 800×480 Flutter console panel.
///
/// Owns the console log, the active menu, and the "waiting for any key"
/// completer. Word-wrap of dialog lines (which uses [TextPainter]) happens
/// here, so the domain only sees raw `@X..@@` tagged strings — keeping the
/// option open to swap in a different host (headless tester, alternate
/// layout) without touching the domain.
class HDFlutterUiHost extends ChangeNotifier implements UiHost {
  static final HDFlutterUiHost _instance = HDFlutterUiHost._internal();
  factory HDFlutterUiHost() => _instance;
  HDFlutterUiHost._internal();

  // --- console wrap settings (view concerns; live with the Flutter host) ---
  static const int _maxLinesPerPage = HDConfig.maxLinesPerPage;
  static const double _consoleWidth =
      HDConfig.consoleWidth - 32.0; // Subtract padding
  static const TextStyle _consoleStyle = TextStyle(
    fontSize: HDConfig.consoleFontSize,
    height: HDConfig.consoleLineHeight,
  );

  // --- state ---
  final HDConsoleLog consoleLog = HDConsoleLog();
  HDMenu? activeMenu;

  Completer<void>? _keyWaitCompleter;
  bool get isWaitingForKey => _keyWaitCompleter != null;
  bool get isEventMode => activeMenu != null || consoleLog.events.isNotEmpty;

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) super.notifyListeners();
    });
  }

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    // Wrap with a color-less base style so the raw serializer can tell
    // "no color tag" from "default color".
    final newLines = HDTextUtils.splitToRawLines(
      message,
      _consoleWidth,
      _consoleStyle,
    );

    for (final line in newLines) {
      if (isDialogue) {
        if (consoleLog.events.length >= _maxLinesPerPage) {
          // Dialogue: wait for key and clear all
          await waitForAnyKey();
          clearLogs();
          await Future.delayed(Duration.zero);
        }
        consoleLog.appendEvent(line);
      } else {
        consoleLog.appendProgress(line, maxLinesPerPage: _maxLinesPerPage);
      }

      notifyListeners();
      // Allow UI to render the added line
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  }) async {
    if (clearLogs) this.clearLogs();
    final menu = HDMenu(
      items,
      initialChoice: initialChoice,
      enabledCount: enabledCount,
      clearLogs: clearLogs,
    );
    activeMenu = menu;
    notifyListeners();
    return await menu.completer.future;
  }

  @override
  Future<void> waitForAnyKey() {
    if (_keyWaitCompleter != null) return _keyWaitCompleter!.future;
    _keyWaitCompleter = Completer<void>();
    notifyListeners();
    return _keyWaitCompleter!.future;
  }

  @override
  void clearLogs() {
    consoleLog.clearEvents();
    notifyListeners();
  }

  /// Called by the input dispatcher when a key arrives during dialogue.
  void dismissKeyWait() {
    if (_keyWaitCompleter != null && !_keyWaitCompleter!.isCompleted) {
      _keyWaitCompleter!.complete();
      _keyWaitCompleter = null;
      notifyListeners();
    }
  }
}
