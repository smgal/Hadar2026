import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/game_option.dart';
import '../domain/map/map_model.dart';
import '../domain/party/party.dart';
import '../hd_config.dart';
import 'battle.dart';
import 'map_loader.dart';
import 'map_navigation.dart';
import 'scripting/native_script_runner.dart';
import 'scripting/script_engine_adapter.dart';
import '../domain/system/game_system.dart';

/// Resolves a `MapInfos.json#cm2` reference to a bundle asset path.
String _resolveCm2Asset(String cm2Ref) =>
    cm2Ref.startsWith('assets/') ? cm2Ref : 'assets/$cm2Ref';

/// Session-wide game state: which map is loaded, the party, options, the
/// scripting/loading boot sequence. Lives in `application/` because it
/// composes domain objects (party, map, options) with infrastructure
/// (loaders, script engine) — and stays free of `flutter/material` or
/// rendering libraries.
///
/// `HDGameMain` exposes session fields/methods as facade getters so
/// existing call sites (`HDGameMain().party`, `HDGameMain().sessionId`,
/// `HDGameMain().init()`, `HDGameMain().loadMapFromFile(...)`) keep
/// working.
class HDGameSession extends ChangeNotifier {
  static final HDGameSession _instance = HDGameSession._internal();
  factory HDGameSession() => _instance;
  HDGameSession._internal();

  /// Bumped on every successful `loadGame` so listeners can drop caches
  /// keyed on the previous run.
  int sessionId = 0;

  /// Current map data; null until the first map is loaded.
  MapModel? map;

  /// Last load error message, surfaced by `main.dart` when `map` is null.
  String? errorMessage;

  /// Bumped on every `setNewMap`, used by viewport keys to force a
  /// fresh `_HDMapViewportState`.
  int mapVersion = 0;

  final HDParty party = HDParty();
  final HDGameSystem gameSystem = HDGameSystem();
  final HDGameOption gameOption = HDGameOption();
  final HDMapLoader mapLoader = HDMapLoader();

  void setNewMap(MapModel newMap) {
    map = newMap;
    mapVersion++;
    notifyListeners();
  }

  /// Boots the in-game world (party position + scripts). Asset preload
  /// (Flame images) lives in the host because it's a rendering concern.
  ///
  /// Party position is intentionally NOT set here — `startup.cm2` runs
  /// `LoadScript(<name>, x, y)` which resolves the map via
  /// `MapInfos.json` and assigns the start coords through the
  /// `LoadScript` command handler.
  Future<void> init() async {
    await HDNativeScriptRunner().startNewGame();
    await HDScriptEngine().loadScript(HDConfig.startupScript);
    // Redundant in the boot path: `ScriptEngine.scriptMode` defaults to
    // 0 and `clearRuntimeState` (called by `loadScript`) does not reset
    // it, so this is a no-op on first run. Kept commented to document
    // the contract that `startup.cm2`'s `if (Equal(ScriptMode(), 0))`
    // branch is the intended entry point.
    // HDScriptEngine().setScriptMode(0);
    await HDScriptEngine().run();
  }

  /// Path to the cm2 script paired with the currently loaded map (via
  /// `MapInfos.json#cm2`). Null when the map has no paired cm2.
  /// The dispatcher consults this when running per-tile cm2 events
  /// (wired in step 3 of the migration).
  String? currentMapCm2Path;

  Future<bool> loadMapFromFile(String fileName) async {
    final bundle = await HDMapNavigation().loadByName(fileName);
    errorMessage = HDMapNavigation().errorMessage;
    if (bundle == null) return false;

    // Tear down lingering battle state from the previous map so that
    // enemies/playerCommands registered but never consumed don't leak
    // across transitions. (Window stack is cleared one layer up in
    // `HDGameMain.loadMapFromFile` since it's a presentation concern.)
    HDBattle().init();

    if (bundle.json != null) {
      setNewMap(bundle.json!);
    }
    currentMapCm2Path = bundle.cm2Path;
    if (bundle.cm2Path != null) {
      // Load the paired cm2 into the script engine so that subsequent
      // tile dispatches (`HDScriptEngine().run()`) execute this map's
      // script, not whatever was previously loaded. Note: this clears
      // `ScriptEngine.variables`/contexts — globals are not preserved
      // across map transitions in the new model.
      await HDScriptEngine().loadScript(_resolveCm2Asset(bundle.cm2Path!));
    }

    // Swap the native map script in lockstep with the map transition.
    // Both entry points — cm2 `LoadScript` command and
    // `HDNativeScriptRunner.loadMapScript` — funnel through here, so
    // this is the single place that keeps `currentMapScript` aligned
    // with the loaded map. Without this, transitioning native → cm2
    // map would leave a stale handler registered (and tile dispatch
    // would fire on the wrong map).
    final native = HDNativeScriptRunner();
    if (native.currentMapScript != null) {
      native.currentMapScript!.onUnload();
    }
    final factory = native.mapScriptFactory[bundle.mapName];
    if (factory != null) {
      native.currentMapScript = factory();
      native.currentMapScript!.onPrepare();
      native.currentMapScript!.onLoad(bundle.mapName, 0, 0);
    } else {
      native.currentMapScript = null;
    }

    return true;
  }

  /// Releases all current map resources without loading a new one.
  /// Called by the LoadScript handler before storing pending navigation,
  /// so the widget layer sees map == null and can show a loading state.
  void clearCurrentMap() {
    HDBattle().init();
    final native = HDNativeScriptRunner();
    native.currentMapScript?.onUnload();
    native.currentMapScript = null;
    currentMapCm2Path = null;
    map = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) super.notifyListeners();
    });
  }
}
