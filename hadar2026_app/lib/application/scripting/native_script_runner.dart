import 'dart:async';
import 'maps/town1_map_script.dart';
import 'maps/ground1_map_script.dart';
import 'maps/town2_map_script.dart';
import 'maps/den1_map_script.dart';
import 'map_script.dart';
import '../../domain/map/tile_properties.dart';
import '../game_session.dart';
import '../window_manager.dart';

class HDNativeScriptRunner {
  static final HDNativeScriptRunner _instance =
      HDNativeScriptRunner._internal();
  factory HDNativeScriptRunner() => _instance;
  HDNativeScriptRunner._internal();

  HDMapScript? currentMapScript;

  // Equivalents to GameRes.flag and GameRes.variable in Unity
  // Script-owned state that must survive map transitions (per-map cm2
  // loads wipe `HDScriptEngine` globals), so it lives here, not there.
  Map<int, bool> flags = {};
  Map<int, int> variables = {};

  final Map<String, HDMapScript Function()> mapScriptFactory = {
    'TOWN1': () => Town1MapScript(),
    'GROUND1': () => Ground1MapScript(),
    'TOWN2': () => Town2MapScript(),
    'DEN1': () => Den1MapScript(),
  };

  Future<void> startNewGame() async {
    // Reset native-script state for a fresh run: clear flags/variables
    // and set the party's initial facing. The first map is loaded later
    // by `startup.cm2` via the `LoadScript` command, not here.
    final gameModel = HDGameSession();
    gameModel.party.faced = 1;

    flags.clear();
    variables.clear();
  }

  Future<void> loadMapScript(
    String scriptName, {
    int? targetX,
    int? targetY,
  }) async {
    final gameModel = HDGameSession();

    // Optionally update coordinates before loading the map
    if (targetX != null && targetY != null) {
      gameModel.party.x = targetX;
      gameModel.party.y = targetY;
    }

    // Native script swap (onUnload / factory / onLoad) lives inside
    // `HDGameSession.loadMapFromFile` so that the cm2 `LoadScript`
    // path stays in sync too. Don't duplicate it here.
    HDWindowManager().clear();
    await gameModel.loadMapFromFile('$scriptName.json');
  }

  /// Routes the tile action to the registered native handler. Returns
  /// `true` if the script handled the event at (x, y), `false` otherwise
  /// — the dispatcher uses this to fall through to cm2 / JSON tiers.
  ///
  /// ACT_TYPE: 1=Talk, 2=Sign, 3=Event, 4=Enter.
  Future<bool> processMapEvent(HDTileAction action, int x, int y) async {
    final script = currentMapScript;
    if (script == null) return false;

    script.tx = x;
    script.ty = y;

    // Exhaustive: a new HDTileAction that needs a hook will fail to
    // compile here instead of silently falling through to `false`.
    return switch (action) {
      HDTileAction.talk => await script.onTalk(0),
      HDTileAction.sign => await script.onSign(0),
      HDTileAction.event => await script.onEvent(0),
      HDTileAction.enter => await script.onEnter(0),
      HDTileAction.none ||
      HDTileAction.water ||
      HDTileAction.swamp ||
      HDTileAction.lava ||
      HDTileAction.cliff ||
      HDTileAction.move => false,
    };
  }

  bool isFlagSet(int flagId) {
    return flags[flagId] ?? false;
  }

  void setFlag(int flagId) {
    flags[flagId] = true;
  }
}
