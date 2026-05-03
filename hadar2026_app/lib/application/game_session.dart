import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/game_option.dart';
import '../domain/map/map_model.dart';
import '../domain/party/party.dart';
import '../hd_config.dart';
import 'map_loader.dart';
import 'map_navigation.dart';
import 'scripting/native_script_runner.dart';
import 'scripting/script_engine_adapter.dart';

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
  final HDGameOption gameOption = HDGameOption();
  final HDMapLoader mapLoader = HDMapLoader();

  void setNewMap(MapModel newMap) {
    map = newMap;
    mapVersion++;
    notifyListeners();
  }

  /// Boots the in-game world (party position + scripts). Asset preload
  /// (Flame images) lives in the host because it's a rendering concern.
  Future<void> init() async {
    await HDNativeScriptRunner().startNewGame();
    party.setPosition(15, 15); // Default start pos for town1
    await HDScriptEngine().loadScript(HDConfig.startupScript);
    HDScriptEngine().setScriptMode(0);
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
    return true;
  }

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) super.notifyListeners();
    });
  }
}
