import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cm2_script/cm2_script.dart';

import '../../application/battle.dart';
import '../../hd_game_main.dart';
import '../../presentation/panels/player_sprite.dart';
import '../../application/select.dart';
import '../../hd_config.dart';
import '../../domain/map/map_model.dart';

/// Thin adapter over [ScriptEngine]: loads scripts from files/bundle and
/// registers Hadar-specific commands and functions.
class HDScriptEngine {
  static final HDScriptEngine _instance = HDScriptEngine._internal();
  factory HDScriptEngine() => _instance;

  late final ScriptEngine _engine;

  final Map<String, int> _tileMap = {};
  int _currentRow = 0;

  HDScriptEngine._internal() {
    _engine = ScriptEngine(
      contentLoader: (path) async {
        final assetPath = path.startsWith('assets/') ? path : 'assets/$path';
        if (!kIsWeb && await File(assetPath).exists()) {
          return File(assetPath).readAsString();
        }
        return rootBundle.loadString(assetPath);
      },
    );
    _registerHadarCommands();
    _registerHadarFunctions();
  }

  Map<String, dynamic> get variables => _engine.variables;
  set variables(Map<String, dynamic> v) {
    _engine.variables
      ..clear()
      ..addAll(v);
  }

  List<ScriptStatement> get currentScript => _engine.currentScript;

  void setScriptMode(int mode) => _engine.scriptMode = mode;
  void setTargetPos(int x, int y) {
    _engine.targetX = x;
    _engine.targetY = y;
  }

  Future<void> loadScript(String assetPath) async {
    String content;
    try {
      if (!kIsWeb && await File(assetPath).exists()) {
        content = await File(assetPath).readAsString();
      } else {
        content = await rootBundle.loadString(assetPath);
      }
    } catch (e) {
      print("ScriptEngine: Failed to load $assetPath: $e");
      return;
    }

    _engine.clearRuntimeState();
    _tileMap.clear();
    _currentRow = 0;

    await _engine.loadFromString(content);
    HDGameMain().gameOption.scriptFile = assetPath;
    print(
      "ScriptEngine: Loaded ${_engine.currentScript.length} root statements from $assetPath",
    );
  }

  Future<void> loadFromString(String content) async {
    _engine.clearRuntimeState();
    _tileMap.clear();
    _currentRow = 0;
    await _engine.loadFromString(content);
  }

  Future<void> run() async {
    await _engine.run(
      onError: (e, stack) {
        if (e is GameReloadException) {
          // Silently stop
          return;
        }
        print("ScriptEngine Error: $e\n$stack");
      },
    );
  }

  Future<void> executeStatement(ScriptStatement stmt) =>
      _engine.executeStatement(stmt);

  void _registerHadarCommands() {
    final e = _engine;

    e.registerCommand('Talk', (stmt, eng) async {
      final args = stmt.args;
      var text = eng.getVal(args.isNotEmpty ? args[0] : '').toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      print("TALK: $text");
      await HDGameMain().addLog(text);
    });

    e.registerCommand('PressAnyKey', (stmt, eng) async {
      print("PressAnyKey...");
      await HDGameMain().waitForAnyKey();
      HDGameMain().clearLogs();
    });

    e.registerCommand('Map::Init', (stmt, eng) async {
      final args = stmt.args;
      final w = int.parse(args[0]);
      final h = int.parse(args[1]);
      final newMap = MapModel();
      newMap.init(w, h);
      HDGameMain().setNewMap(newMap);
      _currentRow = 0;
      print("Map Init: ${w}x$h");
    });

    e.registerCommand('Map::SetTile', (stmt, eng) async {
      final args = stmt.args;
      var char = args[0];
      if (char.startsWith('"') && char.endsWith('"')) {
        char = char.substring(1, char.length - 1);
      }
      final id = int.parse(args[1]);
      _tileMap[char] = id;
    });

    e.registerCommand('Map::SetRow', (stmt, eng) async {
      final args = stmt.args;
      var rowStr = args[0];
      if (rowStr.startsWith('"') && rowStr.endsWith('"')) {
        rowStr = rowStr.substring(1, rowStr.length - 1);
      }
      final map = HDGameMain().map!;
      for (int x = 0; x < rowStr.length && x < map.width; x++) {
        final char = rowStr[x];
        final tileId = _tileMap[char] ?? 0;
        map.setTile(x, _currentRow, tileId);
      }
      _currentRow++;
    });

    e.registerCommand('Select::Init', (_, __) async => HDSelect().init());
    e.registerCommand('Select::Add', (stmt, eng) async {
      var text = eng.getVal(stmt.args.isNotEmpty ? stmt.args[0] : '').toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      HDSelect().add(text);
    });
    e.registerCommand('Select::Run', (_, __) async => HDSelect().run());

    e.registerCommand('LoadScript', (stmt, eng) async {
      final args = stmt.args;
      var path = eng.getVal(args.isNotEmpty ? args[0] : '').toString();
      if (path.startsWith('"') && path.endsWith('"')) {
        path = path.substring(1, path.length - 1);
      }
      print("Loading Script: $path");
      await loadScript('assets/$path');
      setScriptMode(0);
      await run();
      if (args.length >= 3) {
        final nx = (eng.getVal(args[1]) as num).toInt();
        final ny = (eng.getVal(args[2]) as num).toInt();
        HDGameMain().party.setPosition(nx, ny);
      }
      eng.halted = true;
    });

    e.registerCommand('Map::LoadFromFile', (stmt, eng) async {
      var path = eng.getVal(stmt.args.isNotEmpty ? stmt.args[0] : '').toString();
      if (path.startsWith('"') && path.endsWith('"')) {
        path = path.substring(1, path.length - 1);
      }
      print("ScriptEngine: Loading map file $path");
      await HDGameMain().loadMapFromFile('assets/$path');
    });

    e.registerCommand('Battle::Init', (_, __) async => HDBattle().init());
    e.registerCommand('Battle::RegisterEnemy', (stmt, eng) async {
      final enemyId = (eng.getVal(stmt.args[0]) as num).toInt();
      HDBattle().registerEnemy(enemyId);
    });
    e.registerCommand('Battle::ShowEnemy', (_, __) async => HDBattle().showEnemy());
    e.registerCommand('Battle::Start', (stmt, eng) async {
      final mode = (eng.getVal(stmt.args[0]) as num).toInt();
      await HDBattle().start(mode);
    });

    e.registerCommand('Map::SetStartPos', (stmt, eng) async {
      final x = (eng.getVal(stmt.args[0]) as num).toInt();
      final y = (eng.getVal(stmt.args[1]) as num).toInt();
      HDGameMain().party.setPosition(x, y);
    });

    e.registerCommand('Map::ChangeTile', (stmt, eng) async {
      final cx = (eng.getVal(stmt.args[0]) as num).toInt();
      final cy = (eng.getVal(stmt.args[1]) as num).toInt();
      final tileId = (eng.getVal(stmt.args[2]) as num).toInt();
      HDGameMain().map?.setTile(cx, cy, tileId);
    });

    e.registerCommand('WarpPrevPos', (_, __) async => HDGameMain().party.warpToPrev());

    final flags = () => HDGameMain().gameOption.flags;
    final vars = () => HDGameMain().gameOption.variables;

    e.registerCommand('Flag::Set', (stmt, eng) async {
      final flagId = eng.getVal(stmt.args[0]);
      final idx = flagId is num ? flagId.toInt() : int.tryParse(flagId.toString()) ?? -1;
      if (idx >= 0 && idx < HDConfig.maxFlags) {
        flags()[idx] = true;
      }
    });
    e.registerCommand('Flag::Reset', (stmt, eng) async {
      final flagIdReset = eng.getVal(stmt.args[0]);
      final idx = flagIdReset is num ? flagIdReset.toInt() : int.tryParse(flagIdReset.toString()) ?? -1;
      if (idx >= 0 && idx < HDConfig.maxFlags) {
        flags()[idx] = false;
      }
    });
    e.registerCommand('Variable::Set', (stmt, eng) async {
      final idx = (eng.getVal(stmt.args[0]) as num).toInt();
      final val = eng.getVal(stmt.args[1]);
      if (idx >= 0 && idx < HDConfig.maxVariables) {
        vars()[idx] = (val as num).toInt();
      }
    });
    e.registerCommand('Variable::Add', (stmt, eng) async {
      final idxAdd = (eng.getVal(stmt.args[0]) as num).toInt();
      var inc = 1;
      if (stmt.args.length > 1) {
        inc = (eng.getVal(stmt.args[1]) as num).toInt();
      }
      if (idxAdd >= 0 && idxAdd < HDConfig.maxVariables) {
        vars()[idxAdd] += inc;
      }
    });

    e.registerCommand('Player::ChangeAttribute', (stmt, eng) async {
      final pIdx = (eng.getVal(stmt.args[0]) as num).toInt() - 1;
      final attr = stmt.args[1].replaceAll('"', '');
      final valAttr = eng.getVal(stmt.args[2]);
      if (pIdx >= 0 && pIdx < HDGameMain().party.players.length) {
        HDGameMain().party.players[pIdx].changeAttribute(attr, valAttr);
      }
    });
    e.registerCommand('Enemy::ChangeAttribute', (stmt, eng) async {
      final eIdx = (eng.getVal(stmt.args[0]) as num).toInt() - 1;
      final attrEn = stmt.args[1].replaceAll('"', '');
      final valEn = eng.getVal(stmt.args[2]);
      if (eIdx >= 0 && eIdx < HDBattle().enemies.length) {
        HDBattle().enemies[eIdx].changeAttribute(attrEn, valEn);
      }
    });
    e.registerCommand('Player::AssignFromEnemyData', (stmt, eng) async {
      final pIdxEn = (eng.getVal(stmt.args[0]) as num).toInt() - 1;
      final enemyIdToAs = (eng.getVal(stmt.args[1]) as num).toInt();
      if (pIdxEn >= 0 && pIdxEn < HDGameMain().party.players.length) {
        HDGameMain().party.players[pIdxEn].assignFromEnemyData(enemyIdToAs);
      }
    });

    e.registerCommand('Party::PosX', (_, __) async {});
    e.registerCommand('Party::PosY', (_, __) async {});

    e.registerCommand('Party::PlusGold', (stmt, eng) async {
      final amount = (eng.getVal(stmt.args[0]) as num).toInt();
      HDGameMain().party.gold += amount;
    });

    e.registerCommand('Party::Move', (stmt, eng) async {
      final dx = (eng.getVal(stmt.args[0]) as num).toInt();
      final dy = (eng.getVal(stmt.args[1]) as num).toInt();
      final game = HDGameMain().mapViewGameRef;
      if (game != null && game.player != null) {
        final playerComponent = game.player as HDPlayerSprite;
        await playerComponent.forceMove(dx, dy);
      } else {
        HDGameMain().party.move(dx, dy);
      }
    });

    e.registerCommand('Map::SetType', (stmt, eng) async {
      final type = (eng.getVal(stmt.args[0]) as num).toInt();
      HDGameMain().gameOption.mapType = type;
      HDGameMain().map?.tileOverrides.clear();
      HDGameMain().notifyListeners();
    });

    e.registerCommand('Map::SetEncounter', (stmt, eng) async {
      final encounterId = (eng.getVal(stmt.args[0]) as num).toInt();
      final encounterRate = (eng.getVal(stmt.args[1]) as num).toInt();
      print("Stub: Map::SetEncounter(encounterId: $encounterId, rate: $encounterRate)");
    });

    e.registerCommand('DisplayMap', (_, __) async => _refreshDisplay());
    e.registerCommand('DisplayStatus', (_, __) async => _refreshDisplay());

    e.registerCommand('Wait', (stmt, eng) async {
      final ms = (eng.getVal(stmt.args[0]) as num).toInt();
      await Future.delayed(Duration(milliseconds: ms));
    });

    e.registerCommand('TextAlign', (stmt, eng) async {
      final align = (eng.getVal(stmt.args[0]) as num).toInt();
      print("Stub: TextAlign(align: $align)");
    });

    e.registerCommand('Tile::CopyTile', (stmt, eng) async {
      final from = (eng.getVal(stmt.args[0]) as num).toInt();
      final to = (eng.getVal(stmt.args[1]) as num).toInt();
      final map = HDGameMain().map;
      if (map != null) {
        map.tileOverrides[to] = from;
        HDGameMain().mapVersion++;
        HDGameMain().notifyListeners();
      }
    });

    e.registerCommand('Tile::CopyToDefaultTile', (stmt, eng) async {
      final typeToDflt = (eng.getVal(stmt.args[0]) as num).toInt();
      final map = HDGameMain().map;
      if (map != null) {
        map.tileOverrides.clear();
        HDGameMain().mapVersion++;
        HDGameMain().notifyListeners();
      }
      print("Stub: Tile::CopyToDefault(type: $typeToDflt)");
    });
    e.registerCommand('Tile::CopyToDefaultSprite', (stmt, eng) async {
      final typeToDflt = (eng.getVal(stmt.args[0]) as num).toInt();
      final map = HDGameMain().map;
      if (map != null) {
        map.tileOverrides.clear();
        HDGameMain().mapVersion++;
        HDGameMain().notifyListeners();
      }
      print("Stub: Tile::CopyToDefault(type: $typeToDflt)");
    });
  }

  Future<void> _refreshDisplay() async {
    HDGameMain().refresh();
    HDGameMain().gameOption.refresh();
    await Future.delayed(const Duration(milliseconds: 16));
  }

  void _registerHadarFunctions() {
    final e = _engine;

    e.registerFunction('Flag::IsSet', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() : -1;
      if (idx >= 0 && idx < HDConfig.maxFlags) {
        return HDGameMain().gameOption.flags[idx] ? 1 : 0;
      }
      return 0;
    });

    e.registerFunction('Variable::Get', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() : -1;
      if (idx >= 0 && idx < HDConfig.maxVariables) {
        return HDGameMain().gameOption.variables[idx];
      }
      return 0;
    });

    e.registerFunction('On', (args, eng) {
      if (args.length < 2) return 0;
      final x = (args[0] as num).toInt();
      final y = (args[1] as num).toInt();
      bool on;
      if (eng.targetX != -1 && eng.targetY != -1) {
        on = (eng.targetX == x && eng.targetY == y);
      } else {
        on = (HDGameMain().party.x == x && HDGameMain().party.y == y);
      }
      return on ? 1 : 0;
    });

    e.registerFunction('OnArea', (args, eng) {
      if (args.length < 4) return 0;
      final x1 = (args[0] as num).toInt();
      final y1 = (args[1] as num).toInt();
      final x2 = (args[2] as num).toInt();
      final y2 = (args[3] as num).toInt();
      final px = eng.targetX != -1 ? eng.targetX : HDGameMain().party.x;
      final py = eng.targetY != -1 ? eng.targetY : HDGameMain().party.y;
      return (px >= x1 && px <= x2 && py >= y1 && py <= y2) ? 1 : 0;
    });

    e.registerFunction('Battle::Result', (_, __) => HDBattle().result());
    e.registerFunction('Select::Result', (_, __) => HDSelect().result());
    e.registerFunction('Party::PosX', (_, __) => HDGameMain().party.x);
    e.registerFunction('Party::PosY', (_, __) => HDGameMain().party.y);

    e.registerFunction('Player::GetName', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() - 1 : 0;
      if (idx >= 0 && idx < HDGameMain().party.players.length) {
        return HDGameMain().party.players[idx].name;
      }
      return "Unknown";
    });

    e.registerFunction('Player::GetGenderName', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() - 1 : 0;
      if (idx >= 0 && idx < HDGameMain().party.players.length) {
        return HDGameMain().party.players[idx].getGenderName();
      }
      return "Unknown";
    });

    e.registerFunction('Player::GetAttribute', (args, __) {
      if (args.length < 2) return 0;
      final pIdx = (args[0] as num).toInt() - 1;
      final attr = args[1].toString();
      if (pIdx >= 0 && pIdx < HDGameMain().party.players.length) {
        return HDGameMain().party.players[pIdx].getAttribute(attr);
      }
      return 0;
    });

    e.registerFunction('Player::IsAvailable', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() - 1 : 0;
      if (idx >= 0 && idx < HDGameMain().party.players.length) {
        return HDGameMain().party.players[idx].isValid() ? 1 : 0;
      }
      return 0;
    });
  }
}
