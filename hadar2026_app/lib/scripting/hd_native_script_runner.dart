import 'dart:async';
import '../game_components/hd_game_main.dart';
import 'maps/town1_map_script.dart';
import 'maps/ground1_map_script.dart';
import 'maps/town2_map_script.dart';
import 'maps/den1_map_script.dart';
import 'hd_map_script.dart';

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
    // Equivalent. Initialize player, party, and load first map (CastleLore/TOWN1)
    final gameModel = HDGameMain();
    gameModel.party.faced = 1;

    flags.clear();
    variables.clear();

    await loadMapScript('LORE_EP', targetX: 32, targetY: 25);
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

    await gameModel.loadMapFromFile('$scriptName.json');

    if (currentMapScript != null) {
      currentMapScript!.onUnload();
    }

    if (mapScriptFactory.containsKey(scriptName)) {
      currentMapScript = mapScriptFactory[scriptName]!();
      currentMapScript!.onPrepare();
      currentMapScript!.onLoad(scriptName, 0, 0);
    } else {
      currentMapScript = null; // No native script for this map yet
    }
  }

  Future<bool> processMapEvent(int actType, int x, int y) async {
    final gameModel = HDGameMain();

    // Check if there is a JSON-defined event at (x, y)
    if (gameModel.map != null) {
      try {
        final ev = gameModel.map!.events.firstWhere(
          (e) => e.x == x && e.y == y,
        );
        if (ev.dialogLines.isNotEmpty) {
          bool isDialogue = (actType == 1 || actType == 2); // Talk or Sign
          for (var line in ev.dialogLines) {
            if (line.isNotEmpty) {
              await gameModel.addLog(line, isDialogue: isDialogue);
            }
          }
        }
      } catch (_) {
        // No MapEvent found at this tile
      }
    }

    if (currentMapScript == null) return true;

    currentMapScript!.tx = x;
    currentMapScript!.ty = y;

    // Based on ACT_TYPE
    // 0 = ACTION_NONE/EVENT
    // 1 = ACTION_TALK
    // 2 = ACTION_SIGN
    // 3 = ACTION_EVENT
    // 4 = ACTION_ENTER

    switch (actType) {
      case 1: // Talk
        await currentMapScript!.onTalk(0);
        break;
      case 2: // Sign
        await currentMapScript!.onSign(0);
        break;
      case 3: // Event
        return await currentMapScript!.onEvent(0);
      case 4: // Enter
        return await currentMapScript!.onEnter(0);
    }

    return true;
  }

  bool isFlagSet(int flagId) {
    return flags[flagId] ?? false;
  }

  void setFlag(int flagId) {
    flags[flagId] = true;
  }
}
