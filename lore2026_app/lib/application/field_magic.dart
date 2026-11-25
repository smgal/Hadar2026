import 'dart:typed_data';

import 'package:lore_world/lore_world.dart';

import '../domain/map/map_model.dart';
import '../domain/map/map_runtime.dart';
import '../domain/map/tile_properties.dart';
import '../domain/window/map_overview_window_data.dart';
import 'game_session.dart';
import 'ports/host_binding.dart';
import 'scripting/script_engine_adapter.dart';
import 'tile_event_dispatcher.dart';
import 'window_manager.dart';

/// 지도가 있어야 끝나는 마법 — 규칙 패키지가 `MapActionNeeded` 로 넘긴 일을
/// 여기서 마저 한다 (제9장 9.3 · 9.6).
///
/// 두 가지 실패가 다르게 다뤄진다:
///
/// * **그 맵에서 막힌 마법**(제6장 「맵별 마법 제한」) — [blockedHere] 로
///   **쓰기 전에** 본다. MP 도 물품도 줄지 않는다.
/// * **이벤트 칸을 겨눈 마법** — 쓴 뒤에 「알 수 없는 힘이 당신의 마법을
///   배척합니다.」로 실패한다. MP 는 이미 치렀다. 숨겨진 사건을 마법으로
///   돌아가지 못하게 하는 장치다.
class HDFieldMagic {
  static final HDFieldMagic _instance = HDFieldMagic._internal();
  factory HDFieldMagic() => _instance;
  HDFieldMagic._internal();

  HDGameSession get _session => HDGameSession();

  Future<void> _say(String text) => HDHosts().ui.addLog(text);

  static const String _repelled = '알 수 없는 힘이 당신의 마법을 배척합니다.';

  /// 이 맵에서 [action] 이 막혀 있으면 그 까닭의 문구, 아니면 null.
  String? blockedHere(MapAction action) {
    final rt = _session.mapRuntime;
    return switch (action) {
      MapAction.terraform when rt.blocks(HDHandicap.tileChanging) =>
        '이 지역의 악의 힘이 지형 변화를 방해합니다.',
      MapAction.greatTerraform when rt.blocks(HDHandicap.bigTileChanging) =>
        '이 지역의 악의 힘이 지형 변화를 방해합니다.',
      MapAction.etherealMove when rt.blocks(HDHandicap.ethereal) =>
        '알 수 없는 힘이 기화 이동을 방해합니다.',
      MapAction.teleport when rt.blocks(HDHandicap.teleport) =>
        '알 수 없는 힘이 공간 이동을 방해합니다.',
      MapAction.showMap when rt.blocks(HDHandicap.eagleEye) =>
        '당신의 머릿속에는 아무런 형상도 떠오르지 않았다.',
      MapAction.revealHidden when rt.blocks(HDHandicap.seeThrough) =>
        '이 동굴의 악의 힘이 이 마법을 방해합니다.',
      MapAction.farSight when rt.blocks(HDHandicap.clairvoyance) =>
        '이 동굴의 악의 힘이 이 마법을 방해합니다.',
      _ => null,
    };
  }

  /// 변화 마법 [spell] (1~10) 이 지도에 하는 일. 지도와 무관하면 null.
  static MapAction? actionOfChangeSpell(int spell) => switch (spell) {
    2 => MapAction.showMap,
    6 => MapAction.etherealMove,
    7 => MapAction.terraform,
    8 => MapAction.teleport,
    10 => MapAction.greatTerraform,
    _ => null,
  };

  /// 규칙 패키지가 넘긴 일을 한다.
  Future<void> perform(MapActionNeeded needed) async {
    switch (needed.action) {
      case MapAction.showMap:
        await showMap();
      case MapAction.etherealMove:
        await _etherealMove();
      case MapAction.terraform:
        await _terraform(1);
      case MapAction.greatTerraform:
        // 세로로는 5칸, 가로로는 4칸.
        await _terraform(_session.party.facing.$1 == 0 ? 5 : 4);
      case MapAction.teleport:
        await _teleport(needed.distance ?? teleportDefault);
      case MapAction.revealHidden:
        await _revealHidden();
      case MapAction.prophecy:
        await _prophecy();
      case MapAction.farSight:
        await _farSight(needed.distance ?? 1);
    }
  }

  HDTileAction _actionAt(MapModel map, int x, int y) =>
      HDTileProperties.getUnitAction(map.getUnit(x, y));

  /// 일행이 내려설 수 있는 칸인가 — 보통 바닥이거나, 물 위를 걷는 중의 물.
  bool _canLand(MapModel map, int x, int y) {
    if (!_session.isInsideWalkRange(x, y)) return false;
    final action = _actionAt(map, x, y);
    return action == HDTileAction.move ||
        (action == HDTileAction.water && _session.party.walkOnWater > 0) ||
        action == HDTileAction.swamp ||
        action == HDTileAction.lava;
  }

  /// 일행 앞으로 1~[distance] 칸 중 하나라도 `Map::SetMagicBarrier` 안이면 true.
  bool _crossesBarrier(int distance) {
    final rt = _session.mapRuntime;
    if (rt.magicBarriers.isEmpty) return false;
    final party = _session.party;
    final (dx, dy) = party.facing;
    for (var k = 1; k <= distance; k++) {
      if (rt.isBarrier(party.x + dx * k, party.y + dy * k)) return true;
    }
    return false;
  }

  void _moved() {
    _session.mapVersion++;
    _session.party.notifyListeners();
    HDHosts().ui.refresh();
  }

  // ── 주시자의 눈 · 수정 구슬 ────────────────────────────

  Future<void> showMap() async {
    final map = _session.map;
    if (map == null) return;
    final cells = Uint8List(map.width * map.height);
    for (var i = 0; i < cells.length; i++) {
      cells[i] = switch (HDTileProperties.getUnitAction(map.data[i])) {
        HDTileAction.none || HDTileAction.cliff => HDOverviewCell.wall,
        HDTileAction.enter => HDOverviewCell.entrance,
        HDTileAction.sign => HDOverviewCell.sign,
        HDTileAction.water => HDOverviewCell.water,
        HDTileAction.swamp => HDOverviewCell.swamp,
        HDTileAction.lava => HDOverviewCell.lava,
        HDTileAction.talk => HDOverviewCell.person,
        // 숨은 이벤트 칸은 지도에서도 숨어 있다 — 통로와 같은 색.
        HDTileAction.move || HDTileAction.event => HDOverviewCell.path,
      };
    }
    final window = HDMapOverviewWindow(
      columns: map.width,
      rows: map.height,
      cells: cells,
      partyX: _session.party.x,
      partyY: _session.party.y,
      title: _session.mapInfo?.title ?? '',
    );
    HDWindowManager().addWindow(window);
    try {
      await window.waitForClose();
    } finally {
      HDWindowManager().removeWindow(window);
    }
  }

  // ── 기화 이동 ──────────────────────────────────────────

  Future<void> _etherealMove() async {
    final map = _session.map;
    if (map == null) return;
    final party = _session.party;
    final (dx, dy) = party.facing;
    final tx = party.x + dx * 2, ty = party.y + dy * 2;
    // 지나가는 칸과 내려서는 칸 어느 쪽이든 이벤트 칸이거나 마법 장벽이면 배척된다.
    if (_actionAt(map, party.x + dx, party.y + dy) == HDTileAction.event ||
        _actionAt(map, tx, ty) == HDTileAction.event ||
        _crossesBarrier(2)) {
      await _say(_repelled);
      return;
    }
    if (!_canLand(map, tx, ty)) {
      await _say('기화 이동이 통하지 않습니다.');
      return;
    }
    party.setPosition(tx, ty);
    _moved();
    await _say('기화 이동을 마쳤습니다.');
  }

  // ── 지형 변화 · 대지형 변화 ────────────────────────────

  Future<void> _terraform(int length) async {
    final map = _session.map;
    if (map == null) return;
    final party = _session.party;
    final (dx, dy) = party.facing;
    final floor = _session.tileTable.defaultTile(_session.gameOption.mapName);
    var changed = 0;
    for (var i = 1; i <= length; i++) {
      final x = party.x + dx * i, y = party.y + dy * i;
      final unit = map.getUnit(x, y);
      if (unit == null || !_session.isInsideWalkRange(x, y)) break;
      final action = HDTileProperties.getUnitAction(unit);
      if (action == HDTileAction.event) {
        if (changed == 0) {
          await _say(_repelled);
          return;
        }
        break;
      }
      // 사람 · 푯말 · 입구에는 통하지 않는다. 대지형 변화는 거기서 멈춘다.
      if (action.isInteractive) break;
      _session.tileTable
          .entry(_session.gameOption.mapName, floor)
          .withAction(HDTileAction.move)
          .applyTo(unit);
      changed++;
    }
    if (changed == 0) {
      await _say('지형 변화가 통하지 않습니다.');
      return;
    }
    _moved();
    await _say('지형 변화에 성공했습니다.');
  }

  // ── 공간 이동 · 이동 구슬 ──────────────────────────────

  Future<void> _teleport(int distance) async {
    final map = _session.map;
    if (map == null) return;
    final party = _session.party;
    final (dx, dy) = party.facing;
    final tx = party.x + dx * distance, ty = party.y + dy * distance;
    if (map.getUnit(tx, ty) == null) {
      await _say('공간 이동이 통하지 않습니다.');
      return;
    }
    if (_actionAt(map, tx, ty) == HDTileAction.event ||
        _crossesBarrier(distance)) {
      await _say(_repelled);
      return;
    }
    if (!_canLand(map, tx, ty)) {
      await _say('공간 이동 장소로 부적합합니다.');
      return;
    }
    party.setPosition(tx, ty);
    _moved();
    await _say('공간 이동 마법이 성공했습니다.');
  }

  // ── 투시 ────────────────────────────────────────────────

  /// 숨겨진 이벤트 칸을 검게 드러낸다. 키를 누르면 원래대로.
  Future<void> _revealHidden() async {
    final map = _session.map;
    if (map == null) return;
    // 그림만 잠깐 바꾼다: 이벤트 칸의 바닥을 어둠 타일로.
    final saved = <int, (int, int, int, int)>{};
    for (var i = 0; i < map.data.length; i++) {
      final u = map.data[i];
      if (HDTileProperties.getUnitAction(u) != HDTileAction.event) continue;
      saved[i] = (u.ixTile, u.ixDecor, u.ixObj0, u.ixObj1);
      u
        ..ixTile = _session.tileTable.darkTile
        ..ixDecor = 0
        ..ixObj0 = 0
        ..ixObj1 = 0;
    }
    _moved();
    await _say('일행은 주위를 투시하고 있다.');
    await HDHosts().ui.waitForAnyKey();
    for (final e in saved.entries) {
      map.data[e.key]
        ..ixTile = e.value.$1
        ..ixDecor = e.value.$2
        ..ixObj0 = e.value.$3
        ..ixObj1 = e.value.$4;
    }
    _moved();
  }

  // ── 예언 ────────────────────────────────────────────────

  Future<void> _prophecy() async {
    final engine = HDScriptEngine();
    if (!engine.hasEpisodeScript) {
      await _say('아무것도 떠오르지 않았다.');
      return;
    }
    await HDTileEventDispatcher().runExclusive(
      () => engine.runEpisode(HDScriptMode.prophecy),
    );
  }

  // ── 천리안 ──────────────────────────────────────────────

  /// 바라보는 쪽으로 한 칸씩 내다본다. 키를 누를 때마다 나아가고 Esc 로
  /// 끝낸다. 끝나면 제자리.
  Future<void> _farSight(int distance) async {
    final map = _session.map;
    if (map == null) return;
    final party = _session.party;
    final (dx, dy) = party.facing;
    final homeX = party.x, homeY = party.y;
    final prevX = party.xPrev, prevY = party.yPrev;
    await _say('천리안으로 먼 곳을 내다본다. (키를 누를 때마다 한 칸씩)');
    for (var i = 1; i <= distance; i++) {
      final x = homeX + dx * i, y = homeY + dy * i;
      if (map.getUnit(x, y) == null) break;
      party.setPosition(x, y);
      _moved();
      await HDHosts().ui.waitForAnyKey();
    }
    party
      ..setPosition(homeX, homeY)
      ..xPrev = prevX
      ..yPrev = prevY;
    _moved();
  }
}
