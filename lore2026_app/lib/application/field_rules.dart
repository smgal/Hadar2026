import 'dart:math';

import 'package:lore_world/lore_world.dart';

import 'battle_bridge/cm2_battle_adapter.dart';
import 'dev/dev_mode.dart';
import 'game_session.dart';
import 'menu_flows.dart';
import 'ports/host_binding.dart';
import 'scripting/script_engine_adapter.dart';
import 'tile_event_dispatcher.dart';
import 'world_text.dart';

/// 걷고 쉬는 동안 일어나는 일 — 규칙은 `LoreWorld.step` · `LoreWorld.rest`
/// 가 정하고, 여기서는 그 결과를 화면에 내고 뒤따르는 일(조우 전투 ·
/// 예약한 사건 · 게임 오버)을 잇는다.
class HDFieldRules {
  static final HDFieldRules _instance = HDFieldRules._internal();
  factory HDFieldRules() => _instance;
  HDFieldRules._internal();

  /// 걸음과 휴식의 난수. 전투는 자기 씨앗을 따로 받는다.
  Random rng = Random();

  HDGameSession get _session => HDGameSession();
  LoreWorld get _world => _session.party.world;

  Future<void> _say(Iterable<String> lines) async {
    for (final line in lines) {
      await HDHosts().ui.addLog(line, isDialogue: false);
    }
  }

  void _changed() {
    _session.party.notifyListeners();
    HDHosts().ui.refresh();
  }

  /// 일반 통행 칸(물 위를 걷는 중의 물 포함)으로 한 걸음.
  Future<void> normalStep() async {
    final outcome = _world.step(
      StepInput(
        mapKind: _session.mapKind,
        terrain: Terrain.normal,
        encounters: _session.mapRuntime.hasEncounters && !HDDevMode().noEncounters,
      ),
      rng: rng,
    );
    await _say(worldLines(outcome));
    _changed();
    if (outcome.gameOver) {
      await HDMenuFlows().processGameOver(1);
      return;
    }
    final encounter = outcome.first<EncounterStarted>();
    if (encounter != null) {
      await _randomEncounter(encounter.enemyCount);
    }
    await checkTimer();
  }

  Future<void> enterSwamp() => _hazard(Terrain.swamp);
  Future<void> enterLava() => _hazard(Terrain.lava);

  Future<void> _hazard(Terrain terrain) async {
    final outcome = _world.step(
      StepInput(mapKind: _session.mapKind, terrain: terrain, encounters: false),
      rng: rng,
    );
    await _say(worldLines(outcome));
    _changed();
    if (outcome.gameOver) await HDMenuFlows().processGameOver(1);
  }

  /// 일행 전원이 행동할 수 없으면 게임 오버로 넘긴다. 사건 스크립트가
  /// 일행을 쓰러뜨린 뒤(함정 · 독화살)에 부른다.
  Future<void> checkGameOver() async {
    if (_session.map == null) return; // 이미 다른 곳으로 가는 중
    if (_world.protagonist != null && _world.isGameOver) {
      await HDMenuFlows().processGameOver(1);
    }
  }

  /// 무작위 조우 — 맵의 조우 표에서 [count] 마리를 뽑아 싸운다.
  Future<void> _randomEncounter(int count) async {
    final table = _session.mapRuntime.encounterTable;
    if (table.isEmpty) return;
    final battle = HDCm2BattleAdapter()..init();
    for (var i = 0; i < count; i++) {
      battle.registerEnemy(table[rng.nextInt(table.length)]);
    }
    final host = HDHosts().ui;
    host.beginNarrative();
    try {
      await battle.start(0);
    } finally {
      await host.endNarrative(autoFlush: false);
    }
  }

  /// 예약한 시각이 됐으면 편 스크립트를 `FLAG_TIMER` 로 부른다.
  ///
  /// 울린 사건이 곧바로 또 울릴 예약(`Timer::Set(번호, 0)`)을 걸면 그것도
  /// 이어서 울린다. 사건이 맵을 옮기면(`LoadScript`) 여기서 멈추고, 새 맵에
  /// 들어선 뒤 [fireDueTimerNow] 가 나머지를 울린다. 엔딩이 제목 화면으로
  /// 돌아가 맵이 비어도 멈춘다.
  Future<void> checkTimer() async {
    while (true) {
      final due = _session.takeDueTimer();
      if (due == null) return;
      final engine = HDScriptEngine()..firedTimerId = due.id;
      final host = HDHosts().ui;
      host.beginNarrative();
      try {
        await HDTileEventDispatcher().runExclusive(
          () => engine.runEpisode(HDScriptMode.timer),
        );
      } finally {
        await host.endNarrative(
          autoFlush: engine.pendingNavigation == null && _session.map != null,
        );
      }
      _changed();
      if (engine.pendingNavigation != null || _session.map == null) return;
    }
  }

  /// 스크립트가 끝난 직후에 부른다 — 울릴 시각이 지난 예약을 다음 걸음을
  /// 기다리지 않고 지금 울린다.
  ///
  /// `Timer::Set(번호, 0)` 이 이 길로 바로 울린다. 3편 엔딩 다섯 개가 그렇게
  /// 불린다 — 즉위식(로어성 `FLAG_MAP`) 끝의 엔딩 B, 로드안을 쓰러뜨린 대화
  /// (`FLAG_TALK`) 끝의 엔딩 C, 돔 에필로그(`FLAG_MAP`) 끝의 엔딩 A.
  /// 스크립트가 맵을 옮기는 중이면 아무것도 하지 않는다 — 새 맵의
  /// `FLAG_MAP` 이 끝난 뒤 다시 불린다.
  Future<void> fireDueTimerNow() async {
    if (HDScriptEngine().pendingNavigation != null) return;
    if (_session.map == null) return;
    await checkTimer();
  }

  /// [hours] 시간 쉰다. 식량 · 회복 · 횃불 · 변화 마법 해제 · 레벨업 판정
  /// (제11장 11.6, 제7장 7.6). 예약한 사건이 있으면 시계가 그 시각을 넘지
  /// 않고, 쉬고 난 뒤 그 사건이 일어난다.
  ///
  /// [silent] 면 문장을 내지 않는다 — 사건이 시간을 보낼 때 쓴다.
  Future<Outcome> rest(int hours, {bool silent = false}) async {
    final outcome = _world.rest(hours, rng: rng, notAfter: _session.restLimit);
    if (!silent) {
      for (final line in worldLines(outcome)) {
        await HDHosts().ui.addLog(line);
      }
    }
    _changed();
    return outcome;
  }
}
