import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/game_option.dart';
import '../domain/map/map_model.dart';
import '../application/scripting/script_engine_adapter.dart';
import '../game_components/hd_game_main.dart';

class HDSaveManager {
  static const String _savePrefix = 'hadar_save_';

  static Future<bool> saveGame(int index) async {
    final gameMain = HDGameMain();
    try {
      final prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> data = {
        'version': 1,
        'party': gameMain.party.toJson(),
        'gameOption': gameMain.gameOption.toJson(),
        'map': gameMain.map?.toJson(),
      };

      final jsonString = jsonEncode(data);
      await prefs.setString('${_savePrefix}$index', jsonString);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Failed to save game: $e");
      }
      return false;
    }
  }

  static Future<bool> loadGame(int index) async {
    final gameMain = HDGameMain();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('${_savePrefix}$index');

      if (jsonString == null || jsonString.isEmpty) {
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(jsonString);

      // 1. Restore Party (includes position)
      int? savedX;
      int? savedY;
      int? savedFaced;
      if (data['party'] != null) {
        gameMain.party.fromJson(data['party']);
        savedX = gameMain.party.x;
        savedY = gameMain.party.y;
        savedFaced = gameMain.party.faced;
      }

      // 2. Load Script definition first (to get named variables/constants)
      if (data['gameOption'] != null) {
        final savedOption = HDGameOption.fromJson(data['gameOption']);
        if (savedOption.scriptFile.isNotEmpty) {
          await HDScriptEngine().loadScript(savedOption.scriptFile);
        }

        // 3. Restore Saved Options (Flags, Variables) AFTER script init
        // so that saved states overwrite any default assignments in script
        gameMain.gameOption.flags = savedOption.flags;
        gameMain.gameOption.variables = savedOption.variables;
        gameMain.gameOption.mapType = savedOption.mapType;
        gameMain.gameOption.scriptFile = savedOption.scriptFile;
      }

      // 4. Script definitions are already loaded via loadScript in step 2.
      // We skip the explicit run() call to avoid re-initializing state.

      // 5. Restore Map Tiles
      // We do this LAST because Script Mode 0 (Map::Init) might have reset the map
      if (data['map'] != null) {
        final loadedMap = MapModel.fromJson(data['map']);
        gameMain.setNewMap(loadedMap);
      }

      // 6. Final Position Restoration
      // We do this LAST because Script Mode 0 (Map::Init/Map::SetStartPos) might have reset the position
      if (savedX != null && savedY != null) {
        gameMain.party.setPosition(savedX, savedY);
        gameMain.party.faced = savedFaced ?? 0;
      }

      gameMain.mapVersion++;
      gameMain.notifyListeners();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Failed to load game: $e");
      }
      return false;
    }
  }
}
