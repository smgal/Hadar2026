import 'dart:async';

import '../domain/map/map_model.dart';
import '../domain/map/tile_properties.dart';
import '../domain/party/party.dart';
import '../application/game_session.dart';
import '../application/scripting/native_script_runner.dart';
import '../application/scripting/script_engine_adapter.dart';
import 'field_rules.dart';
import 'game_reload_exception.dart';
import 'ports/ui_host.dart';

/// 한 걸음의 뒤처리 — 원작 부록 D.4 의 ④·⑤ 를 맡는다.
///
/// ```
/// 이벤트 칸 ───→ 사건 실행 (사건이 없으면 평범한 바닥)
/// 늪 ──────────→ 중독 진행 → 늪 효과
/// 용암 ────────→ 피해 → 게임 오버 확인
/// 통행 칸·물 ──→ 일반 걸음: 중독 진행 → 게임 오버 확인 → 독심 −1
///                → 무작위 조우 → 시간 경과 → 예약한 사건
/// ```
///
/// 사람·푯말·입구는 걸어 들어가지 않고 **부딪혀서** 부른다
/// (`isInteraction: true`). 그쪽도 여기로 온다.
///
/// 스크립트는 세 층으로 받는다 — hadar2026_app 과 같다:
/// 1. native map script (Dart, `HDNativeScriptRunner.mapScriptFactory`)
/// 2. 짝지은 cm2 (`MapInfos.json#cm2`)
/// 3. JSON `MapEvent.dialogLines` (cm2 가 `Event::Override` 를 안 불렀을 때)
///
/// 로어 맵은 전부 2번이다.
class HDTileEventDispatcher {
  static final HDTileEventDispatcher _instance =
      HDTileEventDispatcher._internal();
  factory HDTileEventDispatcher() => _instance;
  HDTileEventDispatcher._internal();

  bool _isScriptRunning = false;

  /// 스크립트나 걸음 뒤처리가 도는 중인가. 도는 동안은 걷기 입력을 받지
  /// 않는다 — 전투나 대화 중에 한 칸 더 걸어 버리는 것을 막는다.
  bool get isScriptRunning => _isScriptRunning;

  /// [body] 를 「도는 중」으로 표시한 채 돌린다. 타일이 부르지 않은 실행
  /// (맵에 들어온 직후의 `FLAG_MAP`, 예언, 예약한 사건, 메뉴에서 쓴 물건)이
  /// 쓴다. 이미 도는 중이면 그 안에서 불린 것이므로 그대로 이어 돌린다.
  Future<void> runExclusive(Future<void> Function() body) async {
    if (_isScriptRunning) {
      await body();
      return;
    }
    _isScriptRunning = true;
    try {
      await body();
    } finally {
      _isScriptRunning = false;
    }
  }

  Future<void> check({
    required MapModel? map,
    required HDParty party,
    required UiHost host,
    required int x,
    required int y,
    bool isInteraction = false,
  }) async {
    if (map == null) return;
    if (_isScriptRunning) return;
    _isScriptRunning = true;

    bool narrativeOpened = false;
    bool reloaded = false;
    try {
      final action = HDTileProperties.getUnitAction(map.getUnit(x, y));
      final bool isScriptedAction = isInteraction
          ? action.isInteractive
          : action.isStepOn;

      if (isScriptedAction) {
        host.beginNarrative();
        narrativeOpened = true;
        host.clearLogs();
        // Give the UI a frame to rebuild into overlay mode.
        await Future.delayed(Duration.zero);
        await _dispatchScripted(action, x, y, map, host);
        await _stepAgain(party, host);
        // 사건이 일행을 쓰러뜨렸을 수 있다 (함정 · 낭떠러지).
        await HDFieldRules().checkGameOver();
      } else if (!isInteraction) {
        final field = HDFieldRules();
        switch (action) {
          case HDTileAction.swamp:
            await field.enterSwamp();
          case HDTileAction.lava:
            await field.enterLava();
          case HDTileAction.water:
          case HDTileAction.move:
          case HDTileAction.cliff:
            await field.normalStep();
          case HDTileAction.none:
          case HDTileAction.talk:
          case HDTileAction.sign:
          case HDTileAction.event:
          case HDTileAction.enter:
            break;
        }
      }
    } on GameReloadException {
      // 불러오기 · 제목으로 돌아가기 — 하던 일을 여기서 접는다.
      reloaded = true;
    } finally {
      if (narrativeOpened) {
        // If the script triggered a map transition, skip the any-key wait:
        // the player should arrive without pressing a key first.
        await host.endNarrative(
          autoFlush:
              HDScriptEngine().pendingNavigation == null &&
              HDGameSession().map != null,
        );
      }
      _isScriptRunning = false;
    }

    // 사건 스크립트가 `Timer::Set(번호, 0)` 을 걸고 끝났으면 다음 걸음을
    // 기다리지 않고 지금 울린다. 대사 창을 닫은 뒤에 부른다 — 예약 사건은
    // 자기 대사 창을 따로 연다.
    if (narrativeOpened && !reloaded) {
      try {
        await HDFieldRules().fireDueTimerNow();
      } on GameReloadException {
        // 예약 사건 안에서 불러왔다 — 할 일이 없다.
      }
    }
  }

  /// 한 번의 걸음에서 「다시 밟기」가 이어질 수 있는 최대 횟수 — 미끄럼 칸이
  /// 서로를 가리키는 맵이 있어도 멈추게 한다.
  static const int maxStepAgain = 32;

  /// 스크립트가 `Event::StepAgain()` 을 불렀으면 일행이 지금 선 칸을 밟은
  /// 것으로 다시 본다 — 미끄러져 내려선 칸의 사건(베리알의 동굴, 부록 A #29).
  /// 내려선 칸이 사건 칸이 아니면 아무 일도 없다.
  Future<void> _stepAgain(HDParty party, UiHost host) async {
    final engine = HDScriptEngine();
    for (var i = 0; i < maxStepAgain && engine.stepAgainRequested; i++) {
      engine.stepAgainRequested = false;
      final map = HDGameSession().map;
      if (map == null || engine.pendingNavigation != null) return;
      final action = HDTileProperties.getUnitAction(
        map.getUnit(party.x, party.y),
      );
      if (!action.isStepOn) return;
      await _dispatchScripted(action, party.x, party.y, map, host);
    }
    engine.stepAgainRequested = false;
  }

  Future<void> _dispatchScripted(
    HDTileAction action,
    int x,
    int y,
    MapModel map,
    UiHost host,
  ) async {
    if (action == HDTileAction.sign) {
      host.setHeader('@B푯말에 써 있기를:@@');
    }

    final native = HDNativeScriptRunner();
    final cm2Path = HDGameSession().currentMapCm2Path;

    // Tier 1: native map script.
    if (native.currentMapScript != null) {
      await _emitJsonDialog(map, x, y, host);
      await native.processMapEvent(action, x, y);
      return;
    }

    // Tier 2: paired cm2. JSON fallback only when the script did not
    // claim the tile with `Event::Override`.
    if (cm2Path != null) {
      HDScriptEngine().setTargetPos(x, y);
      HDScriptEngine().setScriptMode(action.scriptMode);
      await HDScriptEngine().run();
      if (HDScriptEngine().handled) return;
      await _emitJsonDialog(map, x, y, host);
      return;
    }

    // Tier 3: a map with no script at all — static JSON dialogue only.
    await _emitJsonDialog(map, x, y, host);
  }

  Future<void> _emitJsonDialog(
    MapModel map,
    int x,
    int y,
    UiHost host,
  ) async {
    for (final ev in map.events) {
      if (ev.x == x && ev.y == y) {
        for (final line in ev.dialogLines) {
          if (line.isNotEmpty) {
            await host.addLog(line);
          }
        }
        return;
      }
    }
  }
}
