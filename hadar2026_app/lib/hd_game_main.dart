import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/game_session.dart';
import 'application/menu_flows.dart';
import 'application/tile_event_dispatcher.dart';
import 'domain/game_option.dart';
import 'domain/map/map_model.dart';
import 'domain/party/party.dart';
import 'application/ports/movement_host.dart';
import 'application/ports/ui_host.dart';
import 'presentation/host/flutter_ui_host.dart';
import 'presentation/input/input_dispatcher.dart';
import 'presentation/input/input_mode.dart';
import 'presentation/window_manager.dart';

export 'application/ports/ui_host.dart';
export 'presentation/host/flutter_ui_host.dart' show HDMenu;
export 'presentation/input/input_mode.dart';

class GameReloadException implements Exception {
  final String message;
  GameReloadException([this.message = "Game reloaded"]);
}

/// Thin facade over the layered subsystems:
/// - `HDGameSession`        session state (party, map, options, init flow)
/// - `HDFlutterUiHost`      console/menu/key-wait + `UiHost` impl
/// - `HDInputDispatcher`    keyboard routing
/// - `HDTileEventDispatcher`, `HDMenuFlows`  use-cases
///
/// Kept as a singleton so existing `HDGameMain()`/`ListenableBuilder` call
/// sites (and the original C++ port shape) keep working unchanged. Forwards
/// `notifyListeners()` from both the session and the host so a single
/// listenable still drives the whole UI.
class HDGameMain with ChangeNotifier implements UiHost, PartyMovementHost {
  static final HDGameMain _instance = HDGameMain._internal();
  factory HDGameMain() => _instance;

  final HDFlutterUiHost _host = HDFlutterUiHost();
  final HDGameSession _session = HDGameSession();

  // --- session facade ---
  int get sessionId => _session.sessionId;
  set sessionId(int v) => _session.sessionId = v;
  MapModel? get map => _session.map;
  String? get errorMessage => _session.errorMessage;
  int get mapVersion => _session.mapVersion;
  set mapVersion(int v) => _session.mapVersion = v;
  HDParty get party => _session.party;
  HDGameOption get gameOption => _session.gameOption;
  void setNewMap(MapModel newMap) => _session.setNewMap(newMap);
  Future<bool> loadMapFromFile(String fileName) =>
      _session.loadMapFromFile(fileName);

  /// Tracks the last `mapVersion` we cleared progress for. Used by the
  /// session listener below.
  int _lastObservedMapVersion = 0;

  bool get isScriptRunning => HDTileEventDispatcher().isScriptRunning;

  // --- UI host facade ---
  HDMenu? get activeMenu => _host.activeMenu;
  set activeMenu(HDMenu? v) => _host.activeMenu = v;

  List<String> get progressLogs => _host.consoleLog.progress;
  List<String> get eventLogs => _host.consoleLog.events;
  HDConsoleViewMode get viewMode => _host.viewMode;
  bool get isWaitingForKey => _host.isWaitingForKey;

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) =>
      _host.addLog(message, isDialogue: isDialogue);

  @override
  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  }) => _host.showMenu(
    items,
    initialChoice: initialChoice,
    enabledCount: enabledCount,
    clearLogs: clearLogs,
  );

  @override
  Future<void> waitForAnyKey() => _host.waitForAnyKey();

  @override
  void clearLogs() => _host.clearLogs();

  @override
  void beginNarrative() => _host.beginNarrative();

  @override
  Future<void> endNarrative({String? summary, bool autoFlush = true}) =>
      _host.endNarrative(summary: summary, autoFlush: autoFlush);

  @override
  Future<void> preloadAssets() => _host.preloadAssets();

  @override
  Future<void> animatePartyMove(int dx, int dy) =>
      _host.animatePartyMove(dx, dy);

  void dismissKeyWait() => _host.dismissKeyWait();

  HDInputMode get currentInputMode {
    if (HDWindowManager().windows.isNotEmpty) return HDInputMode.window;
    if (activeMenu != null) return HDInputMode.menu;
    if (isWaitingForKey) return HDInputMode.dialogue;
    return HDInputMode.map;
  }

  void refresh() => notifyListeners();

  HDGameMain._internal() {
    HDInputDispatcher().registerGlobalHandler();
    _lastObservedMapVersion = _session.mapVersion;
    // Forward host + session changes so a single ListenableBuilder on
    // HDGameMain catches both.
    _host.addListener(notifyListeners);
    _session.addListener(_onSessionChanged);
  }

  /// Bridges session-level state changes into facade listeners *and*
  /// performs a side-effect that crosses the application/presentation
  /// boundary: on map transitions, the per-map progress scrollback is
  /// cleared (map = natural context boundary).
  void _onSessionChanged() {
    if (_session.mapVersion != _lastObservedMapVersion) {
      _lastObservedMapVersion = _session.mapVersion;
      _host.consoleLog.clearProgress();
    }
    notifyListeners();
  }

  bool processKey(LogicalKeyboardKey key) =>
      HDInputDispatcher().process(key);

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) super.notifyListeners();
    });
  }

  /// Boot sequence: ask the host to preload its rendering assets, then
  /// hand off to `HDGameSession.init()` for the gameplay boot. The
  /// facade no longer names Flame/Bonfire — the host owns its surfaces.
  Future<void> init() async {
    await _host.preloadAssets();
    await _session.init();
  }

  void update(double dt) {
    // Main loop update
  }

  void render() {
    // Main loop render (Bonfire handles most)
  }

  // --- menu flow facade (delegates to HDMenuFlows) ---
  Future<void> showBattleMenu() => HDMenuFlows().showBattleMenu();
  Future<void> showMainMenu() => HDMenuFlows().showMainMenu();
  Future<void> showPartyStatus() => HDMenuFlows().showPartyStatus();
  Future<void> showHealthStatus() => HDMenuFlows().showHealthStatus();
  Future<void> showCharacterStatus() => HDMenuFlows().showCharacterStatus();
  Future<void> restHere() => HDMenuFlows().restHere();
  Future<void> selectGameOption() => HDMenuFlows().selectGameOption();
  Future<void> selectDifficulty() => HDMenuFlows().selectDifficulty();
  Future<bool> selectLoadMenu() => HDMenuFlows().selectLoadMenu();
  Future<bool> selectSaveMenu() => HDMenuFlows().selectSaveMenu();
  Future<void> processGameOver(int exitCode) =>
      HDMenuFlows().processGameOver(exitCode);

  Future<void> checkTileEvent(
    int x,
    int y, {
    bool isInteraction = false,
  }) => HDTileEventDispatcher().check(
    map: map,
    party: party,
    host: this,
    x: x,
    y: y,
    isInteraction: isInteraction,
  );
}
