import 'dart:async';

import 'package:cm2_script/cm2_script.dart';
import 'package:flutter/foundation.dart';

import '../../application/battle.dart';
import '../../application/tile_event_dispatcher.dart';
import '../game_reload_exception.dart';
import '../game_session.dart';
import '../ports/host_binding.dart';
import '../window_manager.dart';
import '../../application/select.dart';
import '../../hd_config.dart';
import '../../application/menu_flows.dart';
import '../../domain/item/item_data.dart';
import '../../domain/item/item_id.dart';
import '../../domain/map/map_model.dart';
import '../../domain/party/player.dart';
import '../../domain/map/tile_properties.dart';

/// Thin adapter over [ScriptEngine]: loads scripts from files/bundle and
/// registers Hadar-specific commands and functions.
class HDScriptEngine {
  static final HDScriptEngine _instance = HDScriptEngine._internal();
  factory HDScriptEngine() => _instance;

  late final ScriptEngine _engine;

  final Map<String, int> _tileMap = {};
  int _currentRow = 0;

  /// Hint set by `Map::SetStartPos` during FLAG_MAP execution.
  /// Consumed (and cleared) by `executePendingNavigation` to apply the
  /// fallback start position when no explicit coords were provided.
  (int, int)? _startPosHint;

  /// Pending map transition stored by the `LoadScript` handler when called
  /// from within a tile-event dispatch. Consumed by [executePendingNavigation].
  ({String path, bool hasExplicit, int nx, int ny})? pendingNavigation;

  /// Executes the pending map transition (stored by `LoadScript` during a
  /// tile event). Follows the same loading path as the startup `LoadScript`
  /// call: loadMapFromFile → FLAG_MAP run → position → facing.
  Future<void> executePendingNavigation() async {
    final nav = pendingNavigation;
    if (nav == null) return;
    pendingNavigation = null;

    HDWindowManager().clear();
    bool isMap = await HDGameSession().loadMapFromFile(nav.path);
    if (!isMap) await loadScript('assets/${nav.path}');

    _startPosHint = null;
    setScriptMode(0);
    await run(); // FLAG_MAP may call Map::SetStartPos → sets _startPosHint

    if (nav.hasExplicit) {
      HDGameSession().party.setPosition(nav.nx, nav.ny);
    } else if (_startPosHint != null) {
      HDGameSession().party.setPosition(_startPosHint!.$1, _startPosHint!.$2);
    } else {
      final map = HDGameSession().map;
      if (map != null) {
        HDGameSession().party.setPosition(map.width ~/ 2, map.height ~/ 2);
      }
    }
    _startPosHint = null;
    _applyEntryFacing();
  }

  HDScriptEngine._internal() {
    _engine = ScriptEngine(
      contentLoader: (path) async {
        final assetPath = path.startsWith('assets/') ? path : 'assets/$path';
        return HDHosts().assets.loadString(assetPath);
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

  /// Loads [assetPath] into the engine. Returns whether it succeeded.
  ///
  /// **A failed load leaves nothing behind.** It used to return early
  /// before `clearRuntimeState()`, so the previous map's script,
  /// variables and contexts stayed loaded and kept running on the new
  /// map's tiles — and because `HDTileEventDispatcher` picks the cm2
  /// tier whenever `currentMapCm2Path != null`, that stale script was
  /// what ran (GROUND_TRUTH A-2). Callers that track "which map's cm2 is
  /// loaded" must drop that path when this returns false.
  Future<bool> loadScript(String assetPath) async {
    String content;
    try {
      content = await HDHosts().assets.loadString(assetPath);
    } catch (e) {
      print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
      _resetLoadedScript();
      return false;
    }

    print("ScriptEngine: Loading script content from $assetPath");

    _engine.clearRuntimeState();
    _tileMap.clear();
    _currentRow = 0;

    await _engine.loadFromString(content);
    HDGameSession().gameOption.scriptFile = assetPath;
    print(
      "ScriptEngine: Loaded ${_engine.currentScript.length} root statements from $assetPath",
    );
    return true;
  }

  /// Drops the currently loaded script and everything derived from it.
  ///
  /// `clearRuntimeState()` alone keeps `currentScript`, so the statements
  /// of the previous map would still be there to run.
  void _resetLoadedScript() {
    _engine.clearRuntimeState();
    _engine.currentScript = [];
    _tileMap.clear();
    _currentRow = 0;
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

  /// Was `Event::Override` invoked during the most recent [run]? Used by
  /// `HDTileEventDispatcher` to decide whether to fall through to static
  /// JSON events. Reset to `false` at the start of every run.
  bool get handled => _engine.handled;

  /// Sets player facing after a map transition (called by LoadScript handler).
  ///
  /// Priority:
  /// 1. Adjacent [Enter] tile → face away from it (stepped through entrance).
  /// 2. Face toward map center.
  /// 3. Face down (fallback when already at center).
  void _applyEntryFacing() {
    final map = HDGameSession().map;
    final party = HDGameSession().party;
    if (map == null) return;

    final px = party.x, py = party.y;

    // (1) adjacent Enter tile
    for (final (ddx, ddy) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      final unit = map.getUnit(px + ddx, py + ddy);
      if (unit != null &&
          HDTileProperties.getUnitAction(unit) == HDTileAction.enter) {
        party.setFace(-ddx, -ddy); // face away from the entrance
        return;
      }
    }

    // (2) face toward map center; dominant axis wins
    final cx = map.width ~/ 2, cy = map.height ~/ 2;
    final dx = cx - px, dy = cy - py;
    if (dx != 0 || dy != 0) {
      if (dy.abs() >= dx.abs()) {
        party.setFace(0, dy > 0 ? 1 : -1);
      } else {
        party.setFace(dx > 0 ? 1 : -1, 0);
      }
      return;
    }

    // (3) fallback
    party.setFace(0, 1);
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
      // All Talk output — including SIGN — flows through the dialog body.
      // SIGN gets its distinguishing "푯말에 써 있기를:" header set by the
      // tile dispatcher before the script runs, not via a separate popup.
      print("ScriptEngine [TALK]: $text");
      await HDHosts().ui.addLog(text);
    });

    // Description log — "흘러가는 상황 설명" that lands in the
    // bottom-right description panel rather than the dialog area.
    // e.g. `Log("일행은 용암 지대로 들어섰다 !!!")`.
    e.registerCommand('Log', (stmt, eng) async {
      final args = stmt.args;
      var text = eng.getVal(args.isNotEmpty ? args[0] : '').toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      print("ScriptEngine [LOG]: $text");
      await HDHosts().ui.addLog(text, isDialogue: false);
    });

    // Dialog header — top line of the dialog panel. Pass an empty
    // string to clear. e.g. `SetHeader("경비병과 대화")` renders as
    // blue text with an auto-appended colon: "@B경비병과 대화:@@".
    e.registerCommand('SetHeader', (stmt, eng) async {
      final args = stmt.args;
      var text = eng.getVal(args.isNotEmpty ? args[0] : '').toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      // Auto-format: blue color + colon. Raw callers (e.g. the tile
      // dispatcher) that set the header via host.setHeader() directly
      // are responsible for their own formatting.
      if (text.isNotEmpty) text = '@B$text:@@';
      HDHosts().ui.setHeader(text);
    });

    e.registerCommand('Answer', (stmt, eng) async {
      final args = stmt.args;
      var text = eng.getVal(args.isNotEmpty ? args[0] : '').toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      print("ScriptEngine [ANSWER]: $text");
      await HDHosts().ui.addLog('@G$text@@');
    });

    e.registerCommand('PressAnyKey', (stmt, eng) async {
      print("PressAnyKey...");
      await HDHosts().ui.waitForAnyKey();
      HDHosts().ui.clearLogs();
    });

    e.registerCommand('Map::Init', (stmt, eng) async {
      final args = stmt.args;
      final w = int.parse(args[0]);
      final h = int.parse(args[1]);
      final newMap = MapModel();
      newMap.init(w, h);
      HDGameSession().setNewMap(newMap);
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
      final map = HDGameSession().map!;
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
      final hasExplicitPos = args.length >= 3;
      final nx = hasExplicitPos ? (eng.getVal(args[1]) as num).toInt() : 0;
      final ny = hasExplicitPos ? (eng.getVal(args[2]) as num).toInt() : 0;

      if (HDTileEventDispatcher().isScriptRunning) {
        // Store pending navigation and release current map. The widget layer
        // detects map == null + pendingNavigation != null and re-enters the
        // same loading path as app startup via HDGameMain.navigateToPending().
        pendingNavigation = (
          path: path,
          hasExplicit: hasExplicitPos,
          nx: nx,
          ny: ny,
        );
        HDWindowManager().clear();
        HDGameSession().clearCurrentMap();
      } else {
        // Startup path: execute immediately (map must be ready before init returns).
        pendingNavigation = (
          path: path,
          hasExplicit: hasExplicitPos,
          nx: nx,
          ny: ny,
        );
        await executePendingNavigation();
      }
      eng.handled = true;
      eng.halted = true;
    });

    e.registerCommand('Map::LoadFromFile', (stmt, eng) async {
      var path = eng.getVal(stmt.args.isNotEmpty ? stmt.args[0] : '').toString();
      if (path.startsWith('"') && path.endsWith('"')) {
        path = path.substring(1, path.length - 1);
      }
      print("ScriptEngine: Loading map file $path");
      HDWindowManager().clear();
      await HDGameSession().loadMapFromFile(path);
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
      _startPosHint = (x, y);
    });

    e.registerCommand('Map::ChangeTile', (stmt, eng) async {
      final cx = (eng.getVal(stmt.args[0]) as num).toInt();
      final cy = (eng.getVal(stmt.args[1]) as num).toInt();
      final tileId = (eng.getVal(stmt.args[2]) as num).toInt();
      HDGameSession().map?.setTile(cx, cy, tileId);
    });

    e.registerCommand('WarpPrevPos', (_, __) async => HDGameSession().party.warpToPrev());

    final flags = () => HDGameSession().gameOption.flags;
    final vars = () => HDGameSession().gameOption.variables;

    e.registerCommand('Flag::Set', (stmt, eng) async {
      final flagId = eng.getVal(stmt.args[0]);
      final idx = flagId is num ? flagId.toInt() : int.tryParse(flagId.toString()) ?? -1;
      if (idx >= 0 && idx < HDConfig.maxFlags) {
        flags()[idx] = true;
      } else {
        _warnOutOfRange('Flag::Set', idx, HDConfig.maxFlags);
      }
    });
    e.registerCommand('Flag::Reset', (stmt, eng) async {
      final flagIdReset = eng.getVal(stmt.args[0]);
      final idx = flagIdReset is num ? flagIdReset.toInt() : int.tryParse(flagIdReset.toString()) ?? -1;
      if (idx >= 0 && idx < HDConfig.maxFlags) {
        flags()[idx] = false;
      } else {
        _warnOutOfRange('Flag::Reset', idx, HDConfig.maxFlags);
      }
    });
    e.registerCommand('Variable::Set', (stmt, eng) async {
      final idx = (eng.getVal(stmt.args[0]) as num).toInt();
      final val = eng.getVal(stmt.args[1]);
      if (idx >= 0 && idx < HDConfig.maxVariables) {
        vars()[idx] = (val as num).toInt();
      } else {
        _warnOutOfRange('Variable::Set', idx, HDConfig.maxVariables);
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
      } else {
        _warnOutOfRange('Variable::Add', idxAdd, HDConfig.maxVariables);
      }
    });

    // ---- 원작에 구현이 있는데 등록만 빠져 있던 심볼 (G2-02) ----

    e.registerCommand('GameOver', (_, _) async {
      // 원작 `game::proccessGameOver(EXITCODE_BY_FORCE)`
      // (`hd_base_extern.cpp:151-153`). EXITCODE 는 USER/ACCIDENT/ENEMY/
      // FORCE = 0/1/2/3 이고 이 심볼은 인자 없는 강제 종료다.
      await HDMenuFlows().processGameOver(3);
    });

    e.registerCommand('Player::ApplyAttribute', (stmt, eng) async {
      // 원작 `hd_class_pc_player.cpp:376-381` — hp/sp/esp 를 최대치로 채운다.
      final p = _playerArg(eng.getVal(stmt.args[0]), 'Player::ApplyAttribute');
      if (p == null) return;
      p.hp = p.maxHp;
      p.sp = p.maxSp;
      p.esp = p.maxEsp;
    });

    e.registerCommand('Player::ReviseAttribute', (stmt, eng) async {
      // 원작 `hd_class_pc_player.cpp:369-374` — 최대치를 넘은 값을 깎는다.
      // `menace.cm2:48-54` 가 ac 를 0 으로 만든 뒤 이것을 부른다.
      final p = _playerArg(eng.getVal(stmt.args[0]), 'Player::ReviseAttribute');
      if (p == null) return;
      if (p.hp > p.maxHp) p.hp = p.maxHp;
      if (p.sp > p.maxSp) p.sp = p.maxSp;
      if (p.esp > p.maxEsp) p.esp = p.maxEsp;
    });

    e.registerCommand('Map::SetLightArea', (stmt, eng) async {
      final r = _rectArg(stmt, eng, 'Map::SetLightArea');
      if (r == null) return;
      HDGameSession().lightAreas.set(r[0], r[1], r[2], r[3]);
      HDHosts().ui.refresh();
    });

    e.registerCommand('Map::ResetLightArea', (stmt, eng) async {
      final r = _rectArg(stmt, eng, 'Map::ResetLightArea');
      if (r == null) return;
      if (!HDGameSession().lightAreas.reset(r[0], r[1], r[2], r[3])) {
        debugPrint(
          '[cm2] Map::ResetLightArea(${r.join(",")}) matched no area that '
          'Map::SetLightArea had created',
        );
      }
      HDHosts().ui.refresh();
    });

    e.registerCommand('Item::Give', (stmt, eng) async {
      final id = _itemArg(eng.getVal(stmt.args[0]), 'Item::Give');
      if (id == null) return;
      if (!HDGameSession().party.give(id)) {
        debugPrint(
          '[cm2] Item::Give: backpack full — "${itemById(id)!.name}" not '
          'added, existing slots untouched',
        );
      }
    });

    e.registerCommand('Item::Take', (stmt, eng) async {
      final id = _itemArg(eng.getVal(stmt.args[0]), 'Item::Take');
      if (id == null) return;
      if (!HDGameSession().party.take(id)) {
        debugPrint(
          '[cm2] Item::Take: the party has no "${itemById(id)!.name}"',
        );
      }
    });

    e.registerCommand('Player::ChangeAttribute', (stmt, eng) async {
      final pIdx = (eng.getVal(stmt.args[0]) as num).toInt() - 1;
      final attr = stmt.args[1].replaceAll('"', '');
      final valAttr = eng.getVal(stmt.args[2]);
      if (pIdx >= 0 && pIdx < HDGameSession().party.players.length) {
        HDGameSession().party.players[pIdx].changeAttribute(attr, valAttr);
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
      if (pIdxEn >= 0 && pIdxEn < HDGameSession().party.players.length) {
        HDGameSession().party.players[pIdxEn].assignFromEnemyData(enemyIdToAs);
      }
    });

    e.registerCommand('Party::PosX', (_, __) async {});
    e.registerCommand('Party::PosY', (_, __) async {});

    e.registerCommand('Party::PlusGold', (stmt, eng) async {
      final amount = (eng.getVal(stmt.args[0]) as num).toInt();
      HDGameSession().party.gold += amount;
    });

    e.registerCommand('Party::Move', (stmt, eng) async {
      final dx = (eng.getVal(stmt.args[0]) as num).toInt();
      final dy = (eng.getVal(stmt.args[1]) as num).toInt();
      // Delegate to PartyMovementHost: presentation-backed hosts play
      // the walk animation and sync coords; headless hosts just bump
      // the domain coordinates. The script doesn't care which.
      await HDHosts().movement.animatePartyMove(dx, dy);
    });

    e.registerCommand('Map::SetType', (stmt, eng) async {
      final type = (eng.getVal(stmt.args[0]) as num).toInt();
      HDGameSession().gameOption.mapType = type;
      HDGameSession().map?.tileOverrides.clear();
      HDHosts().ui.refresh();
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
      final map = HDGameSession().map;
      if (map != null) {
        map.tileOverrides[to] = from;
        HDGameSession().mapVersion++;
        HDHosts().ui.refresh();
      }
    });

    e.registerCommand('Tile::CopyToDefaultTile', (stmt, eng) async {
      final typeToDflt = (eng.getVal(stmt.args[0]) as num).toInt();
      final map = HDGameSession().map;
      if (map != null) {
        map.tileOverrides.clear();
        HDGameSession().mapVersion++;
        HDHosts().ui.refresh();
      }
      print("Stub: Tile::CopyToDefault(type: $typeToDflt)");
    });
    e.registerCommand('Tile::CopyToDefaultSprite', (stmt, eng) async {
      final typeToDflt = (eng.getVal(stmt.args[0]) as num).toInt();
      final map = HDGameSession().map;
      if (map != null) {
        map.tileOverrides.clear();
        HDGameSession().mapVersion++;
        HDHosts().ui.refresh();
      }
      print("Stub: Tile::CopyToDefault(type: $typeToDflt)");
    });
  }

  Future<void> _refreshDisplay() async {
    HDHosts().ui.refresh();
    HDGameSession().gameOption.refresh();
    await Future.delayed(const Duration(milliseconds: 16));
  }

  /// 범위 밖 정수 인자를 알린다.
  ///
  /// 이 계열의 커맨드들은 가드에 `else` 가 없어 `Flag::Set(300)` 이
  /// **아무 로그도 없이** 사라졌다(부록 F-1). 미등록 심볼의 침묵
  /// (§9, "Unknown command" 는 그래도 찍힌다)과 원인이 다른 별개 실패다.
  static void _warnOutOfRange(String symbol, int idx, int max) {
    debugPrint(
      'ScriptEngine: [WARN] $symbol($idx) is outside [0, $max) — ignored',
    );
  }

  /// cm2 가 넘긴 정수를 아이템 id 로 읽는다. 카탈로그에 없는 값이면
  /// **경고를 남기고** null — 범위 밖 인자를 조용히 흘려보내는 것이
  /// 부록 F-1 이 기록한 현행 결함이라 그 패턴을 따르지 않는다.
  static HDItemId? _itemArg(dynamic raw, String symbol) {
    final wire = raw is num
        ? raw.toInt()
        : int.tryParse(raw.toString()) ?? -1;
    final id = HDItemId.tryFromWire(wire);
    if (id == null || itemById(id) == null) {
      debugPrint(
        '[cm2] $symbol: $wire does not name an item — ignored. Use a '
        'constant from assets/item4ep1.cm2.',
      );
      return null;
    }
    return id;
  }

  /// cm2 의 1-base 인물 번호를 파티 구성원으로 읽는다
  /// (`Player::ChangeAttribute` 가 쓰는 관례와 동일).
  static HDPlayer? _playerArg(dynamic raw, String symbol) {
    final n = raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
    final idx = n - 1;
    final players = HDGameSession().party.players;
    if (idx < 0 || idx >= players.length) {
      debugPrint(
        '[cm2] $symbol: player $n is outside 1..${players.length} — ignored',
      );
      return null;
    }
    return players[idx];
  }

  /// `Map::SetLightArea(x1,y1,x2,y2)` 의 네 인자를 읽는다.
  static List<int>? _rectArg(CommandStatement stmt, ScriptEngine eng,
      String symbol) {
    if (stmt.args.length < 4) {
      debugPrint('[cm2] $symbol needs four coordinates — ignored');
      return null;
    }
    final v = <int>[];
    for (var i = 0; i < 4; i++) {
      final raw = eng.getVal(stmt.args[i]);
      final n = raw is num ? raw.toInt() : int.tryParse(raw.toString());
      if (n == null || n < 0) {
        debugPrint('[cm2] $symbol: argument $i ($raw) is not a coordinate '
            '— ignored');
        return null;
      }
      v.add(n);
    }
    return v;
  }

  void _registerHadarFunctions() {
    final e = _engine;

    e.registerFunction('Flag::IsSet', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() : -1;
      if (idx >= 0 && idx < HDConfig.maxFlags) {
        return HDGameSession().gameOption.flags[idx] ? 1 : 0;
      }
      // The return value stays 0: changing it would flip existing cm2
      // branches. Only the silence goes away.
      _warnOutOfRange('Flag::IsSet', idx, HDConfig.maxFlags);
      return 0;
    });

    // **함수**로 등록해야 한다. 커맨드로 두거나 빠뜨리면 cm2 가
    // "Unknown function" 후 0 을 반환해 조건이 조용히 오분기한다 —
    // 이 심볼이 미등록이던 동안 `L1_ep1d2.cm2:200` 의
    // `Not(Party::CheckIf(CHECKIF_LEVITATION))` 이 항상 참이라
    // **부양 마법 중에도 절벽에서 떨어졌다**(부록 M-3).
    e.registerFunction('Party::CheckIf', (args, _) {
      final raw = args.isNotEmpty && args[0] is num
          ? (args[0] as num).toInt()
          : -1;
      final party = HDGameSession().party;
      // assets/const.cm2:42-46 의 CHECKIF_* 순서 그대로.
      switch (raw) {
        case 0: // CHECKIF_MAGICTORCH
          return party.magicTorch > 0 ? 1 : 0;
        case 1: // CHECKIF_LEVITATION
          return party.levitation > 0 ? 1 : 0;
        case 2: // CHECKIF_WALKONWATER
          return party.walkOnWater > 0 ? 1 : 0;
        case 3: // CHECKIF_WALKONSWAMP
          return party.walkOnSwamp > 0 ? 1 : 0;
        case 4: // CHECKIF_MINDCONTROL
          return party.mindControl > 0 ? 1 : 0;
        default:
          debugPrint(
            '[cm2] Party::CheckIf($raw) is outside 0..4 — returning 0. '
            'Use a CHECKIF_* constant from assets/const.cm2.',
          );
          return 0;
      }
    });

    e.registerFunction('Item::Has', (args, _) {
      if (args.isEmpty) return 0;
      final id = _itemArg(args[0], 'Item::Has');
      if (id == null) return 0;
      return HDGameSession().party.has(id) ? 1 : 0;
    });

    e.registerFunction('Variable::Get', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() : -1;
      if (idx >= 0 && idx < HDConfig.maxVariables) {
        return HDGameSession().gameOption.variables[idx];
      }
      _warnOutOfRange('Variable::Get', idx, HDConfig.maxVariables);
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
        on = (HDGameSession().party.x == x && HDGameSession().party.y == y);
      }
      return on ? 1 : 0;
    });

    e.registerFunction('OnArea', (args, eng) {
      if (args.length < 4) return 0;
      final x1 = (args[0] as num).toInt();
      final y1 = (args[1] as num).toInt();
      final x2 = (args[2] as num).toInt();
      final y2 = (args[3] as num).toInt();
      final px = eng.targetX != -1 ? eng.targetX : HDGameSession().party.x;
      final py = eng.targetY != -1 ? eng.targetY : HDGameSession().party.y;
      return (px >= x1 && px <= x2 && py >= y1 && py <= y2) ? 1 : 0;
    });

    e.registerFunction('Battle::Result', (_, __) => HDBattle().result());
    e.registerFunction('Select::Result', (_, __) => HDSelect().result());
    e.registerFunction('Party::PosX', (_, __) => HDGameSession().party.x);
    e.registerFunction('Party::PosY', (_, __) => HDGameSession().party.y);

    e.registerFunction('Player::GetName', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() - 1 : 0;
      if (idx >= 0 && idx < HDGameSession().party.players.length) {
        return HDGameSession().party.players[idx].name;
      }
      return "Unknown";
    });

    e.registerFunction('Player::GetGenderName', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() - 1 : 0;
      if (idx >= 0 && idx < HDGameSession().party.players.length) {
        return HDGameSession().party.players[idx].getGenderName();
      }
      return "Unknown";
    });

    e.registerFunction('Player::GetAttribute', (args, __) {
      if (args.length < 2) return 0;
      final pIdx = (args[0] as num).toInt() - 1;
      final attr = args[1].toString();
      if (pIdx >= 0 && pIdx < HDGameSession().party.players.length) {
        return HDGameSession().party.players[pIdx].getAttribute(attr);
      }
      return 0;
    });

    e.registerFunction('Player::IsAvailable', (args, __) {
      final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() - 1 : 0;
      if (idx >= 0 && idx < HDGameSession().party.players.length) {
        return HDGameSession().party.players[idx].isValid() ? 1 : 0;
      }
      return 0;
    });
  }
}
