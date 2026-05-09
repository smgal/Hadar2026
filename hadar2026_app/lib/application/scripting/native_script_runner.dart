import 'dart:async';
import '../../hd_game_main.dart';
import 'maps/town1_map_script.dart';
import 'maps/ground1_map_script.dart';
import 'maps/town2_map_script.dart';
import 'maps/den1_map_script.dart';
import 'map_script.dart';

class HDNativeScriptRunner {
  static final HDNativeScriptRunner _instance =
      HDNativeScriptRunner._internal();
  factory HDNativeScriptRunner() => _instance;
  HDNativeScriptRunner._internal();

  HDMapScript? currentMapScript;

  // Equivalents to GameRes.flag and GameRes.variable in Unity
  // They should be stored in HDGameMain eventually but we put them here for now
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
    final gameModel = HDGameMain();
    gameModel.party.faced = 1;

    flags.clear();
    variables.clear();
  }

  Future<void> loadMapScript(
    String scriptName, {
    int? targetX,
    int? targetY,
  }) async {
    final gameModel = HDGameMain();

    // Optionally update coordinates before loading the map
    if (targetX != null && targetY != null) {
      gameModel.party.x = targetX;
      gameModel.party.y = targetY;
    }

    // Native script swap (onUnload / factory / onLoad) lives inside
    // `HDGameSession.loadMapFromFile` so that the cm2 `LoadScript`
    // path stays in sync too. Don't duplicate it here.
    await gameModel.loadMapFromFile('$scriptName.json');
  }

  /// Routes the tile action to the registered native handler. Returns
  /// `true` if the script handled the event at (x, y), `false` otherwise
  /// — the dispatcher uses this to fall through to cm2 / JSON tiers.
  ///
  /// ACT_TYPE: 1=Talk, 2=Sign, 3=Event, 4=Enter.
  Future<bool> processMapEvent(int actType, int x, int y) async {
    if (currentMapScript == null) return false;

    currentMapScript!.tx = x;
    currentMapScript!.ty = y;

    switch (actType) {
      case 1:
        return await currentMapScript!.onTalk(0);
      case 2:
        return await currentMapScript!.onSign(0);
      case 3:
        return await currentMapScript!.onEvent(0);
      case 4:
        return await currentMapScript!.onEnter(0);
    }

    return false;
  }

  bool isFlagSet(int flagId) {
    return flags[flagId] ?? false;
  }

  void setFlag(int flagId) {
    flags[flagId] = true;
  }
}
