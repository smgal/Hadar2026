import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_battle_text/hd_battle_text.dart' as bt;
import 'package:hd_bridge/hd_bridge.dart' as br;
import 'package:hd_world/hd_world.dart' as hw;
import 'package:hd_world_text/hd_world_text.dart' as wt;

/// 한 판을 **사람이 고르면서** 끝까지 끌고 간다.
///
/// ## 왜 이것이 따로 있나
///
/// `battle_run.dart` 는 전부 「가장 가까운 것을 친다」 로 답하고 끝을
/// 본다. 장비가 낸 숫자를 보려는 것이라 판단이 필요 없고, 그래서 판단이
/// 들어가는 물음은 전부 놓친다 — 사거리가 모자랄 때 무엇을 할 것인가,
/// 물러설 것인가 붙을 것인가.
///
/// 이쪽은 그 물음을 사람에게 돌린다. `hd_battle` 이 이미 뒤집힌 제어로
/// 되어 있어(`pendingDecision` 을 내놓고 `applyCommand` 를 기다린다)
/// 콘솔·Flutter 와 **같은 문을 쓴다** — 이 파일에 규칙은 하나도 없다.
///
/// ## 물을 것이 없으면 알아서 나아간다
///
/// `advance()` 를 누르라고 하지 않는다. 명령을 받으면 다음 물음이
/// 나오거나 판이 끝날 때까지 굴리고, 그 사이에 일어난 일을 전부 줄로
/// 만들어 돌려준다. 한 번의 왕복에 한 번의 선택 — 그것이 마우스로 두는
/// 판의 박자다.
class BattleSession {
  hb.Battle? _battle;
  final List<String> _log = [];
  List<String> _enemyKeys = const [];
  int _seed = 0;

  /// 정산까지 끝났는가. 끝난 판은 화면에 남아 있되 명령을 받지 않는다.
  bool _settled = false;

  bool get isRunning => _battle != null;

  /// 한 판을 연다. 열려 있던 것은 버린다.
  Map<String, Object?> start(
    hw.World world, {
    required List<String> enemyKeys,
    required int seed,
    int? initialGap,
    List<int>? enemyRanks,
  }) {
    final unknown = enemyKeys
        .where((k) => !hb.enemyByKey.containsKey(k))
        .toList();
    if (unknown.isNotEmpty) {
      return {'error': 'unknown enemy key', 'keys': unknown};
    }
    if (enemyKeys.isEmpty) {
      return {'error': 'a fight needs at least one enemy'};
    }

    final setup = br.toBattleSetup(
      world,
      enemyKeys: enemyKeys,
      seed: seed,
      initialGap: initialGap,
      enemyRanks: enemyRanks ?? const [],
      // 무기 이름은 여기서 사람 말로 바꾼다. 다리도 전투도
      // 한국어를 갖지 않으므로 아는 쪽이 넘긴다.
      itemName: (ref) => wt.itemName(world.catalog[ref]?.nameKey ?? ''),
    );
    _battle = hb.Battle(setup);
    _enemyKeys = List.of(enemyKeys);
    _seed = seed;
    _settled = false;
    _log.clear();
    _runToNextQuestion();
    return view();
  }

  void abandon() {
    _battle = null;
    _log.clear();
    _settled = false;
  }

  /// 답 하나를 넣고, 다음 물음까지 굴린다.
  Map<String, Object?> command(Map<String, Object?> json) {
    final battle = _battle;
    if (battle == null) return {'error': 'no fight is open'};
    if (battle.isFinished) return {'error': 'the fight is over'};
    if (battle.pendingDecision == null) {
      // 물음이 없는데 답이 왔다. 화면이 두 번 눌렀을 때 나는 일이라
      // 오류로 세우지 않고 그냥 지금 상태를 돌려준다.
      _runToNextQuestion();
      return view();
    }

    final hb.BattleCommand parsed;
    try {
      parsed = hb.BattleCommand.fromJson(json.cast<String, dynamic>());
    } catch (error) {
      return {'error': 'unreadable command', 'detail': '$error'};
    }

    try {
      _record(battle.applyCommand(parsed));
    } on ArgumentError catch (error) {
      // 모델이 안 받는 답. 화면이 낡은 물음을 들고 있을 때 난다.
      return {'error': 'the model refused that answer', 'detail': error.message.toString(), ...view()};
    } on StateError catch (error) {
      return {'error': error.message, ...view()};
    }

    _runToNextQuestion();
    return view();
  }

  /// 아무도 안 물을 때까지 굴린다.
  void _runToNextQuestion() {
    final battle = _battle;
    if (battle == null) return;
    var guard = 0;
    while (!battle.isFinished &&
        battle.pendingDecision == null &&
        guard++ < 4000) {
      _record(battle.advance());
    }
  }

  void _record(List<hb.BattleEvent> events) {
    final battle = _battle!;
    final names = _Names(battle);
    for (final event in events) {
      _log.addAll(bt.battleLines(event, names));
    }
    while (_log.length > 400) {
      _log.removeAt(0);
    }
  }

  /// 결과를 세계에 얹는다. 경험치 · 체력 · 쓴 물건 · 떠난 사람.
  Map<String, Object?> settleInto(hw.World world) {
    final battle = _battle;
    if (battle == null) return {'error': 'no fight is open'};
    final outcome = battle.outcome;
    if (outcome == null) return {'error': 'the fight has not finished'};
    if (_settled) return {'error': 'already settled', ...view()};

    final before = {for (final m in world.members) m.ref: m.hitPoints};
    final settlement = br.settle(world, outcome);
    final refusals = <Map<String, Object?>>[];
    for (final command in settlement.commands) {
      for (final event in world.apply(command)) {
        if (event is hw.CommandRefused) refusals.add(event.toJson());
      }
    }
    _settled = true;

    return {
      'settled': true,
      'result': outcome.resultCode.name,
      'members': [
        for (final m in world.members)
          {
            'ref': m.ref.value,
            'name': m.name,
            'hitPointsBefore': before[m.ref],
            'hitPointsAfter': m.hitPoints,
            'experience': settlement.experience[m.ref] ?? 0,
          },
      ],
      'spent': outcome.consumedItems,
      'departed': [for (final r in settlement.departed) r.value],
      'worldEffects': settlement.worldEffects,
      'refused': refusals,
      'state': world.view.toJson(),
    };
  }

  // ── 화면이 읽는 것 ────────────────────────────────────────

  Map<String, Object?> view() {
    final battle = _battle;
    if (battle == null) {
      return {'open': false, 'log': const <String>[]};
    }

    final decision = battle.pendingDecision;
    final asking = decision?.slot;

    // 같은 적이 둘 이상이면 번호를 붙인다. 종류마다 아이콘이 다르지만
    // 같은 종류 둘은 같은 아이콘이라 그것만으로는 못 가른다.
    final seen = <String, int>{};
    final ordinal = <int, int>{};
    final total = <String, int>{};
    for (final e in battle.enemies) {
      total[e.key] = (total[e.key] ?? 0) + 1;
    }
    for (var i = 0; i < battle.enemies.length; i++) {
      final key = battle.enemies[i].key;
      seen[key] = (seen[key] ?? 0) + 1;
      if (total[key]! > 1) ordinal[i] = seen[key]!;
    }

    final asker = asking == null
        ? null
        : battle.party.where((c) => c.slot == asking).firstOrNull;

    return {
      'open': true,
      'round': battle.round,
      'gap': battle.gap,
      'maxGap': hb.maxGap,
      'phase': battle.phase.name,
      'finished': battle.isFinished,
      'settled': _settled,
      'seed': _seed,
      'enemyKeys': _enemyKeys,
      'result': battle.outcome?.resultCode.name,
      'party': [
        for (final c in battle.party)
          if (c.isPresent) _partyJson(c, battle, asker: asker, asking: asking),
      ],
      'enemies': [
        for (var i = 0; i < battle.enemies.length; i++)
          _enemyJson(battle, i, ordinal[i], asker),
      ],
      'decision': decision == null ? null : _decisionJson(battle, decision),
      'log': List.of(_log),
    };
  }

  Map<String, Object?> _partyJson(
    hb.Combatant c,
    hb.Battle battle, {
    hb.Combatant? asker,
    int? asking,
  }) {
    final weapon = c.weapon;
    return {
      'slot': c.slot,
      'name': c.name,
      'rank': c.rank,
      'hp': c.hp,
      'maxHp': c.snapshot.maxHp,
      'sp': c.sp,
      'maxSp': c.snapshot.maxSp,
      'esp': c.esp,
      'maxEsp': c.snapshot.maxEsp,
      'poison': c.poison,
      'condition': c.condition.name,
      // 원작은 상태를 이름 색으로만 알렸다(부록 V-4). 그 번호를 그대로
      // 보낸다 — 그리는 것은 읽는 쪽의 일이다.
      'colorIndex': bt.conditionColor(
        hp: c.hp,
        poison: c.poison,
        unconscious: c.unconscious,
        dead: c.dead,
      ),
      'conscious': c.isConscious,
      'weaponKey': weapon.key,
      'reach': weapon.longestReach,
      'braced': c.braced,
      'staggered': c.staggered,
      'coatings': [
        for (final coat in c.coatings)
          {'kind': coat.kind.name, 'rounds': coat.rounds},
      ],
      'asking': c.slot == asking,
    };
  }

  Map<String, Object?> _enemyJson(
    hb.Battle battle,
    int index,
    int? ordinal,
    hb.Combatant? asker,
  ) {
    final e = battle.enemies[index];
    final distance = asker == null
        ? null
        : hb.distanceBetween(
            gap: battle.gap,
            attackerRank: asker.rank,
            targetRank: e.rank,
          );
    // 사거리가 값을 내는 자리다. 격자가 거리를 보여 주므로, 그 거리에서
    // 무기가 닿는지 안 닿는지도 같은 칸에 있어야 한다.
    String? verdict;
    if (asker != null && distance != null) {
      final attack = hb.chooseAttack(asker.weapon, distance);
      verdict = bt.reachVerdict(attack: attack, distance: distance);
    }
    return {
      'index': index,
      'key': e.key,
      'name': e.name,
      'ordinal': ordinal,
      'rank': e.rank,
      'hp': e.hp,
      'condition': e.condition.name,
      'colorIndex': bt.enemyNameColor(
        hp: e.hp,
        unconscious: e.unconscious,
        dead: e.dead,
      ),
      'conscious': e.isConscious,
      'reach': e.weapon.longestReach,
      if (distance != null) 'distance': distance,
      if (verdict != null) 'reachVerdict': verdict,
    };
  }

  /// 무엇을 묻고 있나 — 화면이 그대로 그릴 수 있는 꼴로.
  ///
  /// 문구는 전부 `hd_battle_text` 에서 온다. 콘솔과 이 화면이 같은 말을
  /// 써야 하므로 여기서 한국어를 짓지 않는다.
  Map<String, Object?> _decisionJson(
    hb.Battle battle,
    hb.BattleDecision decision,
  ) {
    final c = battle.party.where((p) => p.slot == decision.slot).firstOrNull;
    final weaponName = c == null ? '' : c.snapshot.weaponName;

    Map<String, Object?> base(String kind) => {
      'kind': kind,
      'slot': decision.slot,
      'who': c?.name ?? '',
      'cancelLabel': bt.cancelLabelFor(decision),
    };

    switch (decision) {
      case hb.ActionDecision(:final options):
        return {
          ...base('action'),
          'options': [
            for (final a in options)
              {
                'action': a.name,
                'label': bt.actionLabel(a, weaponName: weaponName),
              },
          ],
        };

      case hb.OrderDecision(:final options):
        return {
          ...base('order'),
          'options': [
            for (final a in options)
              {'action': a.name, 'label': bt.orderLabel(a)},
          ],
        };

      case hb.EnemyTargetDecision(:final enemyIndices):
        // 목록이 아니라 **격자에서 고르는** 물음이다. 번호만 준다.
        return {...base('enemy'), 'enemyIndices': enemyIndices};

      case hb.AllyTargetDecision(:final slots):
        return {...base('ally'), 'slots': slots};

      case hb.SpellDecision(:final options):
        return {
          ...base('spell'),
          'options': [
            for (final o in options)
              {
                ...o.toJson(),
                'label': bt.skillLine(o),
                'name': bt.skillName(o.magicId),
              },
          ],
          // 여덟 줄이 넘으면 범위로 한 번 접는다. 접는 규칙도 문구와
          // 같은 곳에 있다 — 모델은 모른다.
          'groups': [
            for (final g in bt.skillGroups(options))
              {
                'header': bt.skillGroupHeader(g),
                'magicIds': [for (final o in g.options) o.magicId],
              },
          ],
        };

      case hb.ItemDecision(:final itemKeys):
        return {
          ...base('item'),
          'options': [
            for (final k in itemKeys)
              {'itemKey': k, 'label': bt.itemLine(k)},
          ],
        };

      case hb.ItemUseDecision(:final itemKey, :final uses):
        return {
          ...base('itemUse'),
          'itemKey': itemKey,
          'itemLabel': bt.itemLine(itemKey),
          'options': [
            for (final u in uses) {'use': u.name, 'label': bt.itemUseLabel(u)},
          ],
        };
    }
  }
}

/// 슬롯·번호를 이름으로 바꾼다. `hd_battle_text` 가 요구하는 것.
class _Names implements bt.BattleNames {
  _Names(this.battle);

  final hb.Battle battle;

  @override
  bt.HDNoun member(int slot) {
    final c = battle.party.where((p) => p.slot == slot).firstOrNull;
    return bt.HDNoun(c?.name ?? '?');
  }

  @override
  bt.HDNoun enemy(int index) {
    if (index < 0 || index >= battle.enemies.length) return bt.HDNoun('?');
    return bt.HDNoun(battle.enemies[index].name);
  }

  @override
  String weapon(int slot) {
    final c = battle.party.where((p) => p.slot == slot).firstOrNull;
    return c == null ? '' : c.snapshot.weaponName;
  }
}

/// 고를 수 있는 적 전부 — 화면이 판을 짜는 데 쓴다.
List<Map<String, Object?>> enemyRosterJson() => [
  for (final data in hb.enemyTable)
    {
      'key': data.key,
      'name': data.name,
      'level': data.level,
      'endurance': data.endurance,
    },
];
