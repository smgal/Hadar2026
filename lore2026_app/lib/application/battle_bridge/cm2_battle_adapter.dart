import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lore_battle/lore_battle.dart' as lb;
import 'package:lore_battle_text/lore_battle_text.dart' as bt;
import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart' as wt;

import '../../domain/battle/battle_result.dart';
import '../game_session.dart';
import '../menu_flows.dart';
import '../ports/host_binding.dart';
import 'battle_runner.dart';
import 'lore_bridge.dart';

/// `Battle::Start` 의 값 — `assets/common/const.cm2` 의 `BATTLE_*` 와 같다.
abstract final class HDBattleFlag {
  static const int noEscape = 1;
  static const int enemyFirst = 2;
  static const int noPrelude = 4;
  static const int loseOk = 8;

  /// 「반복」 — 도망에 성공해도 같은 적(입힌 피해 그대로, 쓰러진 적은 빠진 채)과
  /// 곧바로 다시, 적 선공으로 싸운다. 기획서가 「도망에 성공해도 다시 싸운다」·
  /// 「이길 때까지 반복」이라고 적은 전투 (3rd/12 §12.4 · 1st/08 §8.2 · 2nd/08 §8.2).
  static const int repeat = 16;

  /// 「새 편성」 — 이기면 처음 등록한 적이 새로 편성되어 다시 덤벼 온다. 도망에
  /// 성공하거나 지면 끝난다. 3편 코볼트성의 탈출(「이기면 새 킹과 다시 싸운다」,
  /// 3rd/12 §12.4)과 2편의 이벤트 패배 전투(메너스의 악마 사냥꾼 · 몰록의 환상,
  /// 2nd/07 §7.2 — [repeat] · [loseOk] 와 함께 쓴다).
  static const int renew = 32;
}

/// cm2 의 전투 동사를 전투 model 로 옮긴다.
///
/// ```
/// Battle::Init()
/// Battle::RegisterEnemy(19, 4)                  → registerEnemy × 4
/// Enemy::ChangeAttribute(5, "name", "오크킹")    → renameEnemy / overrideEnemy
/// Battle::Start(BATTLE_NO_ESCAPE)               → start
/// Battle::Result()                              → result
/// ```
///
/// 무작위 조우도 같은 길을 쓴다(`HDFieldRules`). 전투 화면
/// (`HDBattleOverlay`)은 [active] 를 듣고 그린다.
class HDCm2BattleAdapter with ChangeNotifier {
  HDCm2BattleAdapter._internal();
  static final HDCm2BattleAdapter _instance = HDCm2BattleAdapter._internal();
  factory HDCm2BattleAdapter() => _instance;

  final List<String> _enemyKeys = [];
  final Map<int, lb.EnemyOverride> _overrides = {};
  HDBattleResult _result = HDBattleResult.none;

  lb.BattleOutcome? _lastOutcome;
  lb.BattleOutcome? get lastOutcome => _lastOutcome;

  /// 마지막 전투에서 등록 순서 n(1부터)번째 적이 끝났을 때의 상태. 「반복」으로
  /// 여러 판을 치렀으면 그 적이 마지막으로 나온 판의 상태다. 전투 중 불려 나온
  /// 적은 들어 있지 않다.
  final Map<int, lb.EnemyState> _finalByIndex = {};

  /// 「반복」에서 도망친 뒤 다시 붙을 때 낼 문장 (`Battle::SetRepeatText`).
  String? repeatText;

  /// [HDBattleFlag.renew] 전투에서 이긴 뒤 새 편성이 덤벼 오기 전의 문장.
  /// 없으면 아무것도 내지 않는다 — 머리말(「적이 출현했다」)이 있는 전투는
  /// 그것이 다시 나온다.
  String? renewText;

  /// 등록 순서 [index](1부터)의 적이 쓰러졌는가(의식불명이거나 죽음) — 도망쳤어도.
  bool enemyDown(int index) => _finalByIndex[index]?.isDown ?? false;

  /// 마지막 전투에서 쓰러뜨린 등록된 적의 수 — 도망쳤어도.
  int enemiesDown() => _finalByIndex.values.where((e) => e.isDown).length;

  List<String> get enemyKeys => List.unmodifiable(_enemyKeys);

  /// 지금 도는 전투. 없으면 null — 화면이 이것으로 전투 창을 켜고 끈다.
  lb.BattleView? get active => _active;
  lb.BattleView? _active;
  bool get isBattleActive => _active != null;

  /// 마지막 전투의 결과 (`BATTLERESULT_*`).
  int result() => _result.wire;

  /// 시험이 난수를 고정할 때.
  @visibleForTesting
  int? seedOverride;

  final Random _random = Random();

  LoreWorld get _world => HDGameSession().party.world;
  int get _episode => _world.episode.number;

  void init() {
    _enemyKeys.clear();
    _overrides.clear();
    _result = HDBattleResult.none;
    _lastOutcome = null;
    _finalByIndex.clear();
    repeatText = null;
    renewText = null;
    _active = null;
    notifyListeners();
  }

  /// 그 편 적 표의 [legacyId] 번(1부터)을 한 마리 등록한다.
  void registerEnemy(int legacyId) {
    final data = lb.enemyByLegacyId(_episode, legacyId);
    if (data == null) {
      debugPrint(
        '[battle] Battle::RegisterEnemy($legacyId) — 제$_episode부 적 표에 없는 번호다',
      );
      return;
    }
    if (_enemyKeys.length >= lb.maxEnemies) {
      debugPrint('[battle] 적은 ${lb.maxEnemies}마리까지다 — $legacyId 번은 넣지 않았다');
      return;
    }
    _enemyKeys.add(data.key);
  }

  /// 그 편의 **변형** 적(이름·수치를 바꾼 보스, `enemyVariantsFor`)을 한 마리
  /// 등록한다 — 제1부의 `major_mummy` · `sphinx` · `camp_soldier` 같은 것.
  void registerVariant(String key) {
    if (lb.resolveEnemy(_episode, key) == null) {
      debugPrint('[battle] Battle::RegisterVariant("$key") — 제$_episode부에 없는 적이다');
      return;
    }
    if (_enemyKeys.length >= lb.maxEnemies) {
      debugPrint('[battle] 적은 ${lb.maxEnemies}마리까지다 — "$key" 는 넣지 않았다');
      return;
    }
    _enemyKeys.add(key);
  }

  /// 일행 여섯 자리마다 그 대원의 **분신**을 적으로 세운다 (제1·2부의 환상 전투).
  ///
  /// 바탕은 [baseLegacyId] 번 적이고, 이름 · 레벨 · 능력치 · 방어를 그 대원의
  /// 것으로 덮는다. 마법 등급은 마법사 계열만 레벨 ÷ 4. 빈자리는 [fillLegacyId]
  /// 번 적이 채운다 (1st/08 §8.2 이블 컨센트레이션). 체력은 바탕 공식대로 가득.
  void registerPartyClones(int baseLegacyId, int fillLegacyId) {
    final world = _world;
    for (var seat = 0; seat < Seat.count; seat++) {
      final m = world.member(seat);
      if (m == null) {
        registerEnemy(fillLegacyId);
        continue;
      }
      final before = _enemyKeys.length;
      registerEnemy(baseLegacyId);
      if (_enemyKeys.length == before) continue;
      final index = _enemyKeys.length;
      renameEnemy(index, wt.memberName(m, episode: world.episode));
      for (final attr in const [
        'level',
        'strength',
        'mentality',
        'endurance',
        'resistance',
        'agility',
        'accuracy',
        'ac',
      ]) {
        final v = readAttribute(m, attr);
        if (v != null) overrideEnemy(index, attr, v);
      }
      overrideEnemy(
        index,
        'cast_level',
        m.family == Family.mage ? m.level ~/ 4 : 0,
      );
      overrideEnemy(index, 'special', 0);
    }
  }

  /// 등록 순서 [index](1부터)의 적 이름을 바꾼다.
  bool renameEnemy(int index, String name) =>
      _merge(index, lb.EnemyOverride(displayName: name));

  /// 등록 순서 [index](1부터)의 적 능력치 하나를 바꾼다.
  ///
  /// `ability_*` 는 제3부의 초자연 능력 하나를 붙이거나(1) 뗀다(0) — 그 적이
  /// 원래 가진 능력은 그대로 둔다. 「17대 드라콘제왕 = 아키드라코니안 + 분신」
  /// 은 `Enemy::ChangeAttribute(1, "ability_clone", 1)` 이다 (3rd/12 §12.2).
  bool overrideEnemy(int index, String attribute, int value) {
    final ability = abilityAttributes[attribute];
    if (ability != null) return _setAbility(index, ability, value != 0);
    final o = LoreBridge.overrideFor(attribute, value, _episode);
    return o != null && _merge(index, o);
  }

  /// `Enemy::ChangeAttribute` 의 능력 속성 이름.
  static const Map<String, lb.EnemyAbility> abilityAttributes = {
    'ability_mind_control': lb.EnemyAbility.mindControl,
    'ability_armour_break': lb.EnemyAbility.armourBreak,
    'ability_summon_ally': lb.EnemyAbility.summonAlly,
    'ability_mass_poison': lb.EnemyAbility.massPoison,
    'ability_mass_stun': lb.EnemyAbility.massStun,
    'ability_mass_death': lb.EnemyAbility.massDeath,
    'ability_heal_all': lb.EnemyAbility.healAll,
    'ability_clone': lb.EnemyAbility.clone,
  };

  bool _setAbility(int index, lb.EnemyAbility ability, bool on) {
    final i = index - 1;
    if (i < 0 || i >= _enemyKeys.length) return false;
    final current = _overrides[i]?.abilities ??
        lb.enemyByKey(_episode, _enemyKeys[i])?.abilities ??
        const <lb.EnemyAbility>{};
    final next = {...current};
    on ? next.add(ability) : next.remove(ability);
    return _merge(index, lb.EnemyOverride(abilities: next));
  }

  /// 등록한 적의 이름과 색 — 1부의 적 목록(`DisplayEnemies`)처럼 생명력에 따라 색을
  /// 고른다: 0 회색 · 1~19 밝은 빨강 · 20~49 빨강 · 50~99 갈색 · 100~199 노랑 ·
  /// 200~299 초록 · 그 위 밝은 초록 (LOREBATT.PAS:77~97).
  List<({String text, int color})> enemyNameList() => [
    for (var i = 0; i < _enemyKeys.length; i++)
      (
        text: _overrides[i]?.displayName ?? bt.enemyName(_episode, _enemyKeys[i]),
        color: switch (_overrides[i]?.hp ??
            lb.enemyByKey(_episode, _enemyKeys[i])?.hp ??
            0) {
          <= 0 => 8,
          < 20 => 12,
          < 50 => 4,
          < 100 => 6,
          < 200 => 14,
          < 300 => 2,
          _ => 10,
        },
      ),
  ];

  /// 등록 순서 [index](1부터)의 적에 쌓인 덮어쓰기 — 시험이 본다.
  @visibleForTesting
  lb.EnemyOverride? overrideAt(int index) => _overrides[index - 1];

  bool _merge(int index, lb.EnemyOverride o) {
    final i = index - 1;
    if (i < 0 || i >= _enemyKeys.length) return false;
    _overrides[i] = (_overrides[i] ?? const lb.EnemyOverride()).mergedWith(o);
    return true;
  }

  /// 그 편 적 표의 적을 보조 일원으로 만든다 (`Party::SetAssistant("enemy", n)`).
  Member? assistantFromEnemy(int legacyId) =>
      LoreBridge.assistantFromEnemyNumber(_episode, legacyId);

  int _nextSeed() => seedOverride ?? _random.nextInt(0x7fffffff);

  /// 등록한 적과 싸운다. [flags] 는 `HDBattleFlag` 를 더한 값.
  Future<void> start(int flags) async {
    if (_enemyKeys.isEmpty) {
      debugPrint('[battle] Battle::Start 에 등록된 적이 없다 — 건너뛴다');
      _result = HDBattleResult.none;
      return;
    }
    final canEscape = flags & HDBattleFlag.noEscape == 0;
    final baseEnemyFirst = flags & HDBattleFlag.enemyFirst != 0;
    final prelude = flags & HDBattleFlag.noPrelude == 0;
    final loseOk = flags & HDBattleFlag.loseOk != 0;
    final repeat = flags & HDBattleFlag.repeat != 0;
    final renew = flags & HDBattleFlag.renew != 0;
    final host = HDHosts().ui;
    final world = _world;

    // 처음 등록한 편성 — 「새 편성」이 이것을 다시 세운다
    final firstKeys = List.of(_enemyKeys);
    final firstOverrides = Map.of(_overrides);
    List<int> firstOrigin() => [for (var i = 1; i <= firstKeys.length; i++) i];
    _enemyKeys.clear();
    _overrides.clear();
    _finalByIndex.clear();

    var keys = List.of(firstKeys);
    var overrides = Map.of(firstOverrides);
    // 이번 판의 j 번째 적이 처음 등록 순서로 몇 번째였는가(1부터)
    var origin = firstOrigin();
    var enemyFirst = baseEnemyFirst;
    var preludeDue = prelude;

    while (true) {
      if (preludeDue) {
        preludeDue = false;
        final choice = await _prelude(
          canEscape: canEscape,
          keys: keys,
          overrides: overrides,
        );
        if (choice == _Prelude.escaped) {
          _result = HDBattleResult.evade;
          if (!repeat) break;
          // 「반복」은 머리말에서 도망쳐도 곧바로 다시 붙는다 (코볼트킹의 결계)
          await host.addLog(repeatText ?? '그러나 적들이 다시 앞을 가로막았다.');
          await host.waitForAnyKey();
          enemyFirst = true;
        } else {
          enemyFirst = enemyFirst || choice == _Prelude.enemyFirst;
        }
      }

      final setup = LoreBridge.setupOf(
        world,
        enemyKeys: keys,
        overrides: overrides,
        seed: _nextSeed(),
        canEscape: canEscape,
        enemyActsFirst: enemyFirst,
        mode: flags,
      );

      final outcome = await HDBattleRunner(
        host,
        suppressAppearance: prelude,
        pronounOf: (slot) {
          final m = world.member(slot);
          return m == null ? null : wt.pronoun(m.gender);
        },
        onBattleStarted: (b) {
          _active = b;
          notifyListeners();
        },
        onStep: notifyListeners,
      ).run(setup);

      _active = null;
      _lastOutcome = outcome;
      _result = switch (outcome.resultCode) {
        lb.BattleResultCode.evade => HDBattleResult.evade,
        lb.BattleResultCode.win => HDBattleResult.win,
        lb.BattleResultCode.lose => HDBattleResult.lose,
        lb.BattleResultCode.none => HDBattleResult.none,
      };
      for (var j = 0; j < outcome.enemies.length && j < origin.length; j++) {
        _finalByIndex[origin[j]] = outcome.enemies[j];
      }

      // 정산은 세계가 한 곳에서 한다: HP·MP·상태·경험치·금·화살·물품·
      // 갑옷 파괴·보조 일원. 레벨은 쉴 때 오른다(제7장 7.6).
      final settled = world.settleBattle(LoreBridge.settlementOf(outcome));
      if (settled.isRefused) {
        debugPrint('[battle] 정산이 거절됐다 — ${settled.reason?.name}');
      }
      HDGameSession().party.notifyListeners();
      notifyListeners();
      host.refresh();

      // 「새 편성」 — 이겼으면 처음 편성이 새로 덤벼 온다
      if (renew && _result == HDBattleResult.win) {
        final text = renewText;
        if (text != null) {
          await host.addLog(text);
          await host.waitForAnyKey();
        }
        keys = List.of(firstKeys);
        overrides = Map.of(firstOverrides);
        origin = firstOrigin();
        enemyFirst = baseEnemyFirst;
        preludeDue = prelude;
        _finalByIndex.clear();
        continue;
      }

      if (!repeat || _result != HDBattleResult.evade) break;

      // 「반복」 — 남은 적만, 입힌 피해 그대로 다시 세운다
      final nextKeys = <String>[];
      final nextOverrides = <int, lb.EnemyOverride>{};
      final nextOrigin = <int>[];
      for (var j = 0; j < outcome.enemies.length && j < origin.length; j++) {
        final e = outcome.enemies[j];
        if (e.isDown || e.left) continue;
        nextOverrides[nextKeys.length] = e.resume;
        nextKeys.add(e.key);
        nextOrigin.add(origin[j]);
      }
      if (nextKeys.isEmpty) break;
      await host.addLog(repeatText ?? '그러나 적들이 다시 앞을 가로막았다.');
      await host.waitForAnyKey();
      keys = nextKeys;
      overrides = nextOverrides;
      origin = nextOrigin;
      enemyFirst = true;
    }

    if (_result == HDBattleResult.lose && !loseOk) {
      await HDMenuFlows().processGameOver(2);
    }
  }

  /// 「적이 출현했다 !!!」 — 적 목록과 평균 민첩성을 보이고 교전/도망을 묻는다
  /// (제8장 8.2).
  ///
  /// * 도망 — 일행의 평균 **행운** > 적의 평균 민첩성이면 싸우지 않는다.
  ///   실패하면 적이 먼저 공격한다.
  /// * 교전 — 일행의 평균 **민첩성** > 적의 평균 민첩성이면 일행이 먼저.
  Future<_Prelude> _prelude({
    required bool canEscape,
    required List<String> keys,
    required Map<int, lb.EnemyOverride> overrides,
  }) async {
    final host = HDHosts().ui;
    host.clearLogs();
    await host.addLog(bt.paintText(bt.TextColor.lightRed, '적이 출현했다 !!!'));
    final agilities = <int>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final data = lb.enemyByKey(_episode, key);
      final o = overrides[i];
      agilities.add(o?.agility ?? data?.agility ?? 0);
      await host.addLog(
        '  ${o?.displayName ?? bt.enemyName(_episode, key)}',
      );
    }
    final enemyAgility = agilities.isEmpty
        ? 0
        : agilities.reduce((a, b) => a + b) ~/ agilities.length;
    await host.addLog('');
    await host.addLog('적의 평균 민첩성 : $enemyAgility');

    final picked = await host.showWindowMenu([
      '',
      '적과 교전한다',
      if (canEscape) '도망간다',
    ]);
    final world = _world;
    if (picked == 2 && canEscape) {
      if (world.average(Ability.luck) > enemyAgility) {
        await host.addLog('일행은 무사히 도망쳤다.');
        await host.waitForAnyKey();
        return _Prelude.escaped;
      }
      await host.addLog('그러나, 도망치지 못했다.');
      return _Prelude.enemyFirst;
    }
    return world.average(Ability.agility) > enemyAgility
        ? _Prelude.partyFirst
        : _Prelude.enemyFirst;
  }
}

enum _Prelude { partyFirst, enemyFirst, escaped }
