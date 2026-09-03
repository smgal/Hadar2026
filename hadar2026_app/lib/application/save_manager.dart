import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/game_option.dart';
import '../domain/map/map_model.dart';
import '../application/scripting/script_engine_adapter.dart';
import 'game_session.dart';
import 'ports/host_binding.dart';

class HDSaveManager {
  static const String _savePrefix = 'hadar_save_';

  static Future<bool> saveGame(int index) async {
    final session = HDGameSession();
    try {
      final prefs = await SharedPreferences.getInstance();

      // v2 는 소지품(party.backpack)과 부위별 장비(player.equip)를 더한다.
      // **되돌리기는 없다** — v1 코드가 v2 세이브를 읽으면 두 키를 무시하고
      // 정수 3칸만 보므로 아이템이 사라진다. 그래서 v1 로는 저장하지 않는다.
      // 읽기는 양방향이다: fromJson 이 'equip' 키의 유무로 판정해
      // v1 페이로드를 슬롯으로 마이그레이션한다.
      final Map<String, dynamic> data = {
        'version': 2,
        'party': session.party.toJson(),
        'gameSystem': session.gameSystem.toJson(),
        'gameOption': session.gameOption.toJson(),
        'map': session.map?.toJson(),
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
    final session = HDGameSession();
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
        session.party.fromJson(data['party']);
        savedX = session.party.x;
        savedY = session.party.y;
        savedFaced = session.party.faced;
      }

      if (data['gameSystem'] != null) {
        session.gameSystem.fromJson(data['gameSystem']);
      }

      // 2. Load Script definition first (to get named variables/constants)
      if (data['gameOption'] != null) {
        final savedOption = HDGameOption.fromJson(data['gameOption']);
        if (savedOption.scriptFile.isNotEmpty) {
          await HDScriptEngine().loadScript(savedOption.scriptFile);
        }

        // 3. Restore Saved Options (Flags, Variables) AFTER script init
        // so that saved states overwrite any default assignments in script
        session.gameOption.flags = savedOption.flags;
        session.gameOption.variables = savedOption.variables;
        session.gameOption.mapType = savedOption.mapType;
        session.gameOption.scriptFile = savedOption.scriptFile;
      }

      // 4. Script definitions are already loaded via loadScript in step 2.
      // We skip the explicit run() call to avoid re-initializing state.

      // 5. Restore Map Tiles
      // We do this LAST because Script Mode 0 (Map::Init) might have reset the map
      if (data['map'] != null) {
        final loadedMap = MapModel.fromJson(data['map']);
        session.setNewMap(loadedMap);
      }

      // 6. Final Position Restoration
      // We do this LAST because Script Mode 0 (Map::Init/Map::SetStartPos) might have reset the position
      if (savedX != null && savedY != null) {
        session.party.setPosition(savedX, savedY);
        session.party.faced = savedFaced ?? 0;
      }

      session.mapVersion++;
      HDHosts().ui.refresh();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Failed to load game: $e");
      }
      return false;
    }
  }
}
