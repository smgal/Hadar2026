import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lore_world/lore_world.dart';

import '../domain/game_option.dart';
import '../domain/lighting/light_areas.dart';
import '../domain/lighting/sight_calculator.dart';
import '../domain/map/actor.dart';
import '../domain/map/map_bundle.dart';
import '../domain/map/map_model.dart';
import '../domain/map/map_runtime.dart';
import '../domain/map/tile_table.dart';
import '../domain/party/party.dart';
import 'audio.dart';
import 'battle_bridge/cm2_battle_adapter.dart';
import 'map_loader.dart';
import 'map_navigation.dart';
import 'scripting/native_script_runner.dart';
import 'scripting/script_engine_adapter.dart';

/// Resolves a `MapInfos.json#cm2` value to an asset path. The field holds
/// a path relative to `assets/` (`ep3/Lore.cm2`).
String _resolveCm2Asset(String cm2Ref) =>
    cm2Ref.startsWith('assets/') ? cm2Ref : 'assets/$cm2Ref';

/// 예약한 사건 — 「지금으로부터 N분 뒤」(제11장 11.4).
///
/// 반역 루트의 연쇄 사건과 크리스탈 볼이 쓴다. 걸음으로 시간이 흘러 그
/// 시각에 닿으면 그 걸음에서 바로 일어나고, 휴식은 시계를 그 시각에 맞춘다.
/// 원작은 예약이 남아 있는 동안 저장을 막았다 — 여기서는 **예약을 세이브에
/// 같이 넣어** 그 제한을 없앴다(부록 B.5 가 허용한 선택).
class HDTimer {
  HDTimer(this.id, this.dueSeconds);

  /// 스크립트가 붙인 번호 (`Timer::Set(번호, 분)`).
  final int id;

  /// 울릴 시각 — `LoreCalendar.totalSeconds` 기준.
  final int dueSeconds;

  Map<String, dynamic> toJson() => {'id': id, 'due': dueSeconds};

  static HDTimer? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], due = j['due'];
    return (id is int && due is int) ? HDTimer(id, due) : null;
  }
}

/// Holds the world state of the current play session: the party, the
/// currently loaded map, what the map's script configured for it, and the
/// progress flags.
///
/// Pure session state — no UI knowledge. The presentation layer drives UI
/// repaints by listening to this `ChangeNotifier`.
class HDGameSession extends ChangeNotifier {
  static final HDGameSession _instance = HDGameSession._internal();
  factory HDGameSession() => _instance;
  HDGameSession._internal();

  // Incremented on each game reload (save load / new game) to invalidate
  // async map loads that were queued before the reload.
  int sessionId = 0;

  MapModel? map;

  /// What `MapInfos.json` knows about the current map (type, default tile,
  /// start cell). Null on the title screen.
  LoreMapInfo? mapInfo;

  /// What the current map's script set up in `FLAG_MAP`.
  final HDMapRuntime mapRuntime = HDMapRuntime();

  /// 장면 속 인물 (`Actor::*`). 맵을 바꾸면 비운다.
  final Map<String, HDActor> actors = {};

  /// 스크립트(`Map::SetLightArea`)가 밝혀 둔 영역. 맵을 바꾸면 비운다.
  final HDLightAreas lightAreas = HDLightAreas();

  /// (map type, original tile number) → layers. Loaded once in [init].
  TileTable tileTable = TileTable.empty;

  String? errorMessage;

  // Bumped whenever the map's visible content changes.
  int mapVersion = 0;

  final HDParty party = HDParty();
  final HDGameOption gameOption = HDGameOption();
  final HDMapLoader mapLoader = HDMapLoader();

  /// 예약한 사건. 한 번에 하나.
  HDTimer? timer;

  /// 지금 하고 있는 편 (1~3).
  int get episode => party.world.episode.number;

  MapKind get mapKind => HDSightCalculator.mapKindOf(gameOption.mapType);

  void setNewMap(MapModel newMap) {
    map = newMap;
    mapVersion++;
    notifyListeners();
  }

  /// Boot: read the map index and the tile table. **No map is loaded** —
  /// the title screen runs without one (`HDTitleFlow`).
  Future<void> init() async {
    await HDNativeScriptRunner().startNewGame();
    await HDMapNavigation().infos();
    tileTable = await HDMapNavigation().tileTable();
  }

  /// Asset path of the cm2 paired with the current map, or null if none
  /// loaded. Used by [HDTileEventDispatcher] to pick the script tier.
  String? currentMapCm2Path;

  Future<bool> loadMapFromFile(String fileName) async {
    final bundle = await HDMapNavigation().loadByName(fileName);
    errorMessage = HDMapNavigation().errorMessage;
    if (bundle == null) return false;

    // A registered-but-unfought enemy list does not survive a map change.
    HDCm2BattleAdapter().init();
    lightAreas.clear();
    mapRuntime.clear();
    actors.clear();
    HDAudio().stopMusic();

    mapInfo = bundle.info;
    gameOption.mapName = bundle.mapName;
    if (bundle.info != null) gameOption.mapType = bundle.info!.type;

    if (bundle.json != null) {
      setNewMap(bundle.json!);
    }

    currentMapCm2Path = bundle.cm2Path;
    if (bundle.cm2Path != null) {
      final loaded = await HDScriptEngine().loadScript(
        _resolveCm2Asset(bundle.cm2Path!),
      );
      // A map whose script has not been written yet is still walkable.
      // Drop the path so the dispatcher does not run a stale script.
      if (!loaded) currentMapCm2Path = null;
    }

    final native = HDNativeScriptRunner();
    native.currentMapScript?.onUnload();
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

  /// Releases the current map so the widget layer can show a loading
  /// indicator and re-enter the loading path. Called by `LoadScript`.
  void clearCurrentMap() {
    HDCm2BattleAdapter().init();
    actors.clear();
    final native = HDNativeScriptRunner();
    native.currentMapScript?.onUnload();
    native.currentMapScript = null;
    currentMapCm2Path = null;
    map = null;
    notifyListeners();
  }

  /// 게임을 끝내고 제목 화면으로. 일행·진행 상태·맵을 모두 비운다.
  void resetToTitle() {
    sessionId++;
    clearCurrentMap();
    mapInfo = null;
    mapRuntime.clear();
    lightAreas.clear();
    timer = null;
    errorMessage = null;
    gameOption.reset();
    HDScriptEngine().pendingNavigation = null;
    HDScriptEngine().arrivalLines.clear();
    HDScriptEngine().stepAgainRequested = false;
    party.hidden = false;
    HDAudio().stopMusic();
    notifyListeners();
  }

  // ── 걸을 수 있는 범위 ──────────────────────────────────

  /// 원작은 맵 가장자리에 여백을 둔다 — 화면(9×11칸)이 맵 밖을 비추지
  /// 않게 하려는 것이다. 가로는 5 ~ 너비−4, 세로는 제1부가 5 ~ 높이−4,
  /// 제2·3부가 6 ~ 높이−5 (기획서 좌표, 1부터).
  bool isInsideWalkRange(int x, int y) {
    final m = map;
    if (m == null) return false;
    final info = mapInfo;
    if (info == null) return x >= 0 && y >= 0 && x < m.width && y < m.height;
    final top = info.episode == 1 ? 4 : 5; // 엔진 좌표(0부터)
    return x >= 4 && x <= m.width - 5 && y >= top && y <= m.height - 1 - top;
  }

  // ── 예약 ────────────────────────────────────────────────

  void setTimer(int id, int minutes) {
    timer = HDTimer(id, party.world.calendar.totalSeconds + minutes * 60);
  }

  void clearTimer() => timer = null;

  /// 예약한 시각이 됐으면 그 예약을 꺼내 돌려준다 (한 번만).
  HDTimer? takeDueTimer() {
    final t = timer;
    if (t == null || party.world.calendar.totalSeconds < t.dueSeconds) {
      return null;
    }
    timer = null;
    return t;
  }

  /// 휴식이 넘지 말아야 할 시각 (예약이 있으면 그 시각).
  LoreCalendar? get restLimit {
    final t = timer;
    if (t == null) return null;
    return party.world.calendar.copy()
      ..advance(seconds: t.dueSeconds - party.world.calendar.totalSeconds);
  }

  // Break synchronous notification chains so we never notify during build.
  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) super.notifyListeners();
    });
  }
}
