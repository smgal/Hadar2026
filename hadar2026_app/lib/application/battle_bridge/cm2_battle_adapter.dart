import 'package:flutter/foundation.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_battle_text/hd_battle_text.dart' as tx;
import 'package:hd_world/hd_world.dart';

import '../../domain/battle/battle_result.dart';
import '../game_session.dart';
import '../menu_flows.dart';
import '../ports/host_binding.dart';
import 'battle_runner.dart';
import 'level_up.dart';
import 'package:hd_bridge/hd_bridge.dart' as bridge;

/// cm2 동사 5개를 새 전투 model 위에 얹는 호환 계층 (B3-01).
///
/// ## 왜 어댑터인가
///
/// `Battle::` 호출 지점이 **53곳, 파일 5개**다 — `L1_ep1d0.cm2` ·
/// `lore_ep1.cm2` · `town1.cm2` · `town2.cm2` · `Map002.cm2`.
/// **cm2 는 구현이 아니라 이미 저작된 콘텐츠**라, 그 53곳을 고치는 것은
/// 확장이 아니라 치환이다(4차 판정). 그래서 규격은 풍부하게 두고 동사
/// 다섯 개를 그 위에 얹는다.
///
/// ```
/// Battle::Init            판을 비운다
/// Battle::RegisterEnemy   legacyId → 문자열 키
/// Battle::ShowEnemy       조우 알림
/// Battle::Start(mode)     조립 → 진행 → 정산 반영
/// Battle::Result()        와이어 값 그대로 (evade 0 / win 1 / lose 2 / 미결 -1)
/// ```
class HDCm2BattleAdapter with ChangeNotifier {
  HDCm2BattleAdapter._internal();
  static final HDCm2BattleAdapter _instance = HDCm2BattleAdapter._internal();
  factory HDCm2BattleAdapter() => _instance;

  final List<String> _enemyKeys = [];
  final List<int> _enemyRanks = [];
  HDBattleResult _result = HDBattleResult.none;

  /// `Battle::ShowEnemy` 가 조우 알림을 이미 찍었는가.
  bool _announced = false;

  /// 마지막 전투의 정산 결과. 화면이 읽을 것이 있으면 여기서 본다.
  hb.BattleOutcome? get lastOutcome => _lastOutcome;
  hb.BattleOutcome? _lastOutcome;

  /// 등록된 적 키. 테스트와 `Enemy::ChangeAttribute` 가 본다.
  List<String> get enemyKeys => List.unmodifiable(_enemyKeys);

  /// 지금 굴러가는 전투. 전투 중이 아니면 null.
  ///
  /// 화면이 적의 상태를 읽으라고 열어 둔 것이다. B4 가 제대로 된 view 를
  /// 만들 때까지 기존 오버레이가 계속 살아 있어야 한다 — 규칙은 여전히
  /// `packages/hd_battle` 안에만 있다.
  hb.Battle? get active => _active;
  hb.Battle? _active;

  bool get isBattleActive => _active != null;

  /// cm2 `Battle::Result()`.
  ///
  /// 전투가 실제로 끝나기 전에는 **-1(미결)** 이다. 예전 구현은 승리를
  /// 기본값으로 돌려줘서 전투 없이도 이긴 것이 됐다(P0-13).
  int result() => _result.wire;

  /// cm2 `Battle::Init`.
  void init() {
    _enemyKeys.clear();
    _enemyRanks.clear();
    _result = HDBattleResult.none;
    _lastOutcome = null;
    _active = null;
    _announced = false;
    notifyListeners();
  }

  /// cm2 `Battle::RegisterEnemy(id)`.
  ///
  /// 유효 범위는 **0~74** — 표 전체다. 예전 가드가 `<= 0` 이라 id 0(Orc)을
  /// 소환할 수 없었고, 범위 밖은 조용히 삼켰다(P0-15). 경고를 남기고
  /// 무시하는 판정을 유지한다 — `town1.cm2:50` 에 주석 처리된
  /// `RegisterEnemy(75)` 가 실제로 있다.
  void registerEnemy(int legacyId, {int? rank}) {
    final data = hb.enemyByLegacyId[legacyId];
    if (data == null) {
      debugPrint(
        'Battle::RegisterEnemy($legacyId) is outside the table — ignored',
      );
      return;
    }
    _enemyKeys.add(data.key);
    _enemyRanks.add(rank ?? 0);
  }

  /// cm2 `Battle::ShowEnemy`.
  ///
  /// **"…이 나타났다 !" 는 여기서 찍어야 한다.** 원작이 이 동사를 따로 둔
  /// 이유가 그것이다 — `Map002.cm2` 는 `ShowEnemy` 와 `Battle::Start`
  /// 사이에 "적과 교전한다 / 도망간다" 를 묻는다. 누가 나왔는지 모른 채
  /// 싸울지 말지를 고르게 되면 그 물음이 의미를 잃는다.
  ///
  /// 전투 model 도 개시할 때 `EnemiesAppeared` 를 낸다. 그래서 여기서
  /// 찍었으면 [start] 가 그쪽을 막는다 — 두 번 찍지 않게.
  Future<void> showEnemy() async {
    if (_enemyKeys.isEmpty) return;
    final event = hb.EnemiesAppeared([
      for (var i = 0; i < _enemyKeys.length; i++) i,
    ]);
    final color = tx.battleLineColor(event);
    for (final line in tx.battleLines(event, _KeyNames(_enemyKeys))) {
      await HDHosts().ui.addLog(
        tx.withDefaultColor(line, color),
        isDialogue: false,
      );
    }
    _announced = true;
  }

  /// cm2 `Battle::Start(mode)`.
  ///
  /// 조립 → 진행 → 정산 반영이 한 자리에 있다. 예전 전투는 RPG 상태를
  /// 진행 중에 직접 고쳤고 경험치를 두 곳에서 더했다 — 무엇이 언제
  /// 바뀌는지 추적할 수 없었다. 이제 **끝나고 한 번**이다.
  Future<void> start(int mode) async {
    if (_enemyKeys.isEmpty) {
      debugPrint('Battle::Start($mode) with no enemies registered — skipped');
      _result = HDBattleResult.none;
      return;
    }
    final party = HDGameSession().party;
    final setup = bridge.toBattleSetup(
      party.world,
      enemyKeys: List.of(_enemyKeys),
      enemyRanks: [
        for (final r in _enemyRanks)
          if (r > 0) r,
      ],
      seed: nextSeed(),
      mode: mode,
    );

    final outcome = await HDBattleRunner(
      HDHosts().ui,
      // `ShowEnemy` 가 이미 찍었으면 model 의 조우 알림은 버린다.
      suppressAppearance: _announced,
      onBattleStarted: (b) {
        _active = b;
        notifyListeners();
      },
      onStep: notifyListeners,
    ).run(setup);
    _active = null;
    _announced = false;
    // 오버레이(`HDBattleOverlay`)는 이 adapter 를 듣고 `active` 를 읽는다.
    // 여기서 알리지 않으면 **전투가 끝나도 오버레이가 남는다** — 맵을 바꿔
    // `init()` 이 불릴 때까지. 실제로 그렇게 보였다(2026-09-06).
    notifyListeners();
    _lastOutcome = outcome;
    _result = _toLegacy(outcome.resultCode);
    // 정산은 `hd_bridge` 가 한다 — 체력·상태는 바로 쓰고, 세계가 규칙을
    // 갖는 것(쓴 물건 빼기)만 명령으로 돌려준다. 거절은 삼키지 않는다.
    final settlement = bridge.settle(party.world, outcome);
    for (final command in settlement.commands) {
      for (final event in party.world.apply(command)) {
        if (event is CommandRefused) {
          debugPrint('[battle] 정산이 거절됐다 — ${event.reason.name}');
        }
      }
    }
    // 레벨업은 전투가 아니라 RPG 의 일이다(B3-05). 정산이 끝난 뒤에 온다 —
    // 오르면 hp 를 최대로 채우기 때문에 순서가 바뀌면 회복분이 덮인다.
    await settleLevelUps(party, outcome, HDHosts().ui);
    party.notifyListeners();
    HDHosts().ui.refresh();

    // **전멸은 여기서 끝난다.** 옛 전투가 `processGameOver(2)` 를 부르던
    // 자리다. cm2 쪽은 `if (Equal(temp, BATTLERESULT_LOSE)) halt()` 로
    // 스크립트만 멈추므로(`L1_ep1d0.cm2:357`), 이것을 안 부르면 전원 HP 0
    // 인 채로 지도를 계속 걸어다니게 된다.
    if (_result == HDBattleResult.lose) {
      await HDMenuFlows().processGameOver(2);
    }
  }

  /// 시드를 고정한다. 저장·재현이 필요해지면 여기가 그 자리다.
  ///
  /// 지금은 테스트가 쓴다 — 시계에서 딴 시드로는 이겼는지 졌는지가
  /// 실행마다 달라져서, 스크립트가 결과를 제대로 받는지 확인할 수 없다.
  @visibleForTesting
  int? seedOverride;

  /// 전투마다 다른 시드.
  ///
  /// **전투 안에서는 시드가 하나뿐**이라 그 뒤로는 전부 재현 가능하다.
  int nextSeed() =>
      seedOverride ?? (DateTime.now().microsecondsSinceEpoch & 0x7fffffff);

  /// 규격의 결과 코드를 cm2 와이어 값으로.
  ///
  /// `assets/const.cm2:53-55` 가 정본이다 — `evade 0 / win 1 / lose 2`.
  /// 부록 B-2·F-3 이 해소한 것을 되돌리지 않는다.
  HDBattleResult _toLegacy(hb.BattleResultCode code) => switch (code) {
    hb.BattleResultCode.evade => HDBattleResult.evade,
    hb.BattleResultCode.win => HDBattleResult.win,
    hb.BattleResultCode.lose => HDBattleResult.lose,
    hb.BattleResultCode.none => HDBattleResult.none,
  };
}

/// 등록된 적 키만으로 조우 알림 문장을 만들기 위한 최소 이름표.
///
/// `Battle::ShowEnemy` 는 전투가 만들어지기 **전**이라 `Battle` 인스턴스가
/// 없다. `EnemiesAppeared` 문장은 적 이름만 쓰므로 그것만 채운다.
class _KeyNames implements tx.BattleNames {
  const _KeyNames(this.keys);

  final List<String> keys;

  @override
  tx.HDNoun enemy(int index) =>
      tx.HDNoun(hb.enemyByKey[keys[index]]?.name ?? keys[index]);

  @override
  tx.HDNoun member(int slot) => tx.HDNoun('');

  @override
  String weapon(int slot) => '';
}
