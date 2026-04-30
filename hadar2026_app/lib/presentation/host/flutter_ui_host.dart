import 'dart:async';

import 'package:bonfire/bonfire.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/game_session.dart';
import '../../application/ports/movement_host.dart';
import '../../application/ports/ui_host.dart';
import '../../domain/console/console_log.dart';
import '../../hd_config.dart';
import '../../utils/hd_text_utils.dart';
import '../panels/player_sprite.dart';

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
class HDFlutterUiHost extends ChangeNotifier
    implements UiHost, PartyMovementHost {
  static final HDFlutterUiHost _instance = HDFlutterUiHost._internal();
  factory HDFlutterUiHost() => _instance;
  HDFlutterUiHost._internal();

  /// Bonfire game ref captured by the map viewport on `onReady`. Stays
  /// inside the presentation layer so application/script code never
  /// names a Bonfire/Flame type.
  BonfireGameInterface? _bonfireGame;
  BonfireGameInterface? get bonfireGame => _bonfireGame;
  void attachBonfireGame(BonfireGameInterface? game) {
    _bonfireGame = game;
  }

  // --- console wrap settings (view concerns; live with the Flutter host) ---
  static const int _maxLinesPerPage = HDConfig.maxLinesPerPage;
  static const int _maxProgressLines = HDConfig.maxProgressLines;
  static const double _consoleWidth =
      HDConfig.consoleWidth - 32.0; // Subtract padding
  static const TextStyle _consoleStyle = TextStyle(
    fontSize: HDConfig.consoleFontSize,
    height: HDConfig.consoleLineHeight,
  );

  // --- state ---
  final HDConsoleLog consoleLog = HDConsoleLog();
  HDMenu? activeMenu;

  /// True between [beginNarrative] and [endNarrative]. Holds the overlay
  /// open even when events briefly empty (page flush during a long
  /// dialogue, or a menu→message cycle that hasn't pushed events yet).
  bool _narrativeActive = false;

  Completer<void>? _keyWaitCompleter;
  bool get isWaitingForKey => _keyWaitCompleter != null;

  /// Stack-overlay model: base layer is the progress log; the overlay is
  /// shown when a narrative cycle is active OR a menu is up OR there are
  /// pending event lines.
  HDConsoleViewMode get viewMode =>
      (_narrativeActive ||
              activeMenu != null ||
              consoleLog.events.isNotEmpty)
          ? HDConsoleViewMode.overlay
          : HDConsoleViewMode.progress;

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
        consoleLog.appendProgress(line, maxLinesPerPage: _maxProgressLines);
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

  @override
  void beginNarrative() {
    if (_narrativeActive) return;
    _narrativeActive = true;
    notifyListeners();
  }

  @override
  Future<void> endNarrative({String? summary, bool autoFlush = true}) async {
    // If the script left a one-shot message on screen (e.g. a sign whose
    // dialogLines were rendered without a PressAnyKey), give the user a
    // chance to read it before tearing the overlay down. Skipping this
    // would make the text flash and disappear immediately.
    if (autoFlush && consoleLog.events.isNotEmpty) {
      await waitForAnyKey();
    }
    consoleLog.clearEvents();
    if (summary != null && summary.isNotEmpty) {
      // Wrap the summary the same way addLog() does, so it survives
      // word-wrap at the panel width and renders identically to other
      // progress lines.
      final lines = HDTextUtils.splitToRawLines(
        summary,
        _consoleWidth,
        _consoleStyle,
      );
      for (final line in lines) {
        consoleLog.appendProgress(line, maxLinesPerPage: _maxProgressLines);
      }
    }
    _narrativeActive = false;
    notifyListeners();
  }

  /// Reset all observable state. Singleton means the fields persist
  /// across tests; this method gives a unit test a clean slate.
  @visibleForTesting
  void resetForTest() {
    consoleLog.clearEvents();
    consoleLog.clearProgress();
    activeMenu = null;
    _narrativeActive = false;
    _keyWaitCompleter = null;
    _bonfireGame = null;
  }

  @override
  Future<void> preloadAssets() async {
    try {
      await Flame.images.loadAll([
        HDConfig.mainSpriteSheet,
        HDConfig.mainTileSheet,
      ]);
    } catch (e) {
      debugPrint("Pre-cache error: $e");
    }
  }

  @override
  Future<void> animatePartyMove(int dx, int dy) async {
    final player = _bonfireGame?.player;
    if (player is HDPlayerSprite) {
      // forceMove drives the sprite tween and syncs domain coords on
      // each tile boundary.
      await player.forceMove(dx, dy);
      return;
    }
    // No viewport attached (headless / CLI / pre-onReady): bump domain
    // coordinates directly so script flow stays consistent.
    HDGameSession().party.move(dx, dy);
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
