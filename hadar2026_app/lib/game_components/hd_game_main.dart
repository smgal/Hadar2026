import 'package:flutter/services.dart';
import 'dart:async';
import '../domain/map/map_model.dart';
import '../domain/party/party.dart';
import '../domain/game_option.dart';
import '../application/map_loader.dart';
import '../application/scripting/script_engine_adapter.dart';
import '../application/scripting/native_script_runner.dart';
import 'package:flutter/material.dart';
import '../presentation/window_manager.dart';
import 'package:flame/flame.dart'; // For image caching
import 'package:bonfire/bonfire.dart';
import '../hd_config.dart';
import '../domain/console/console_log.dart';
import '../application/menu_flows.dart';
import '../application/map_navigation.dart';
import '../application/tile_event_dispatcher.dart';
import '../presentation/input/input_mode.dart';
import '../presentation/input/input_dispatcher.dart';
import '../presentation/host/ui_host.dart';
import '../presentation/host/flutter_ui_host.dart';
export '../presentation/input/input_mode.dart';
export '../presentation/host/ui_host.dart';
export '../presentation/host/flutter_ui_host.dart' show HDMenu;

class GameReloadException implements Exception {
  final String message;
  GameReloadException([this.message = "Game reloaded"]);
}

class HDGameMain with ChangeNotifier implements UiHost {
  static final HDGameMain _instance = HDGameMain._internal();
  factory HDGameMain() => _instance;

  // --- UI host facade (backed by HDFlutterUiHost) ---
  final HDFlutterUiHost _host = HDFlutterUiHost();

  HDMenu? get activeMenu => _host.activeMenu;
  set activeMenu(HDMenu? v) => _host.activeMenu = v;

  HDConsoleLog get consoleLog => _host.consoleLog;
  List<TextSpan> get progressLogs => _host.consoleLog.progress;
  List<TextSpan> get eventLogs => _host.consoleLog.events;
  bool get isEventMode => _host.isEventMode;
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

  void dismissKeyWait() => _host.dismissKeyWait();

  // --- session/game state ---
  int sessionId = 0;
  MapModel? map;
  String? errorMessage;
  int mapVersion = 0;
  BonfireGameInterface? mapViewGameRef;
  final HDParty party = HDParty();
  final HDGameOption gameOption = HDGameOption();
  final HDMapLoader mapLoader = HDMapLoader();
  bool get isScriptRunning => HDTileEventDispatcher().isScriptRunning;

  HDInputMode get currentInputMode {
    if (HDWindowManager().windows.isNotEmpty) return HDInputMode.window;
    if (activeMenu != null) return HDInputMode.menu;
    if (isWaitingForKey) return HDInputMode.dialogue;
    return HDInputMode.map;
  }

  void refresh() => notifyListeners();

  HDGameMain._internal() {
    HDInputDispatcher().registerGlobalHandler();
    // Forward host changes (menu/log/keyWait) so existing listeners that
    // watch HDGameMain keep working without rewiring.
    _host.addListener(notifyListeners);
  }

  bool processKey(LogicalKeyboardKey key) =>
      HDInputDispatcher().process(key);

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        super.notifyListeners();
      }
    });
  }

  void setNewMap(MapModel newMap) {
    map = newMap;
    mapVersion++;
    notifyListeners();
  }

  // Core methods from original C++
  Future<void> init() async {
    // Pre-cache images to avoid flicker during load
    try {
      await Flame.images.loadAll([
        HDConfig.mainSpriteSheet,
        HDConfig.mainTileSheet,
      ]);
    } catch (e) {
      print("Pre-cache error: $e");
    }

    // Initialization logic
    party.setPosition(15, 15); // Default start pos for town1

    // Load Script
    await HDScriptEngine().loadScript(HDConfig.startupScript);

    // Ensure backwards compat if cm2 triggers something, but mainly we use Native
    HDScriptEngine().setScriptMode(0);

    // Start native dart scripts
    await HDNativeScriptRunner().startNewGame();
  }

  void update(double dt) {
    // Main loop update
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

  void render() {
    // Main loop render (if needed, Bonfire handles most)
  }

  Future<bool> loadMapFromFile(String fileName) async {
    final newMap = await HDMapNavigation().loadByName(fileName);
    errorMessage = HDMapNavigation().errorMessage;
    if (newMap == null) return false;
    setNewMap(newMap);
    return true;
  }
}
