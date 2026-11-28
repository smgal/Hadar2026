import 'package:flutter/material.dart';
import 'package:lore_battle/lore_battle.dart' as lb;
import 'package:lore_battle_text/lore_battle_text.dart' as bt;

import '../../../utils/hd_text_utils.dart';

/// 전투 중 맵 자리에 겹치는 세 조각 — 대열 · 적 목록 · 일행.
///
/// 원작은 전투가 시작되면 맵 화면을 검게 지우고 적 목록을 그 자리에 쓴다
/// (제13장 13.1). 그 자리에 대열(간격과 열)을 더했다 — 하다르 전투 뼈대의
/// 위치 규칙이 로어 전투에도 그대로 있기 때문이다. 문장은 대화 창으로 간다
/// (`HDBattleRunner`).
const TextStyle _base = TextStyle(
  fontFamily: 'DungGeunMo',
  fontSize: 13,
  height: 1.2,
  color: Color(0xFF808080),
);

Widget _tinted(String markup, {TextStyle? style}) => Text.rich(
  HDTextUtils.parseRichText(markup, baseStyle: style ?? _base),
  maxLines: 1,
  overflow: TextOverflow.clip,
  softWrap: false,
);

Widget _panel({required Widget child, EdgeInsets? padding}) => Container(
  decoration: BoxDecoration(
    color: const Color(0xFF101010),
    border: Border.all(color: const Color(0xFF303030)),
  ),
  padding: padding ?? const EdgeInsets.fromLTRB(6, 4, 6, 4),
  child: child,
);

/// 대열 — 앞열이 가운데로 오게 양쪽을 마주 세우고 그 사이에 간격을 그린다.
class HDFormationStrip extends StatelessWidget {
  const HDFormationStrip({super.key, required this.battle});

  final lb.BattleView battle;

  String _side(Map<int, int> countByRank, {required bool enemySide}) {
    final parts = <String>[];
    for (final r in enemySide ? [1, 2, 3] : [3, 2, 1]) {
      final n = countByRank[r] ?? 0;
      if (n == 0) continue;
      parts.add('${bt.paintText(bt.TextColor.lightBlue, "$r열")}×$n');
    }
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final party = <int, int>{};
    for (final c in battle.party) {
      if (c.isPresent && c.dead == 0) party[c.rank] = (party[c.rank] ?? 0) + 1;
    }
    final enemies = <int, int>{};
    for (final e in battle.enemies) {
      if (e.isPresent) enemies[e.rank] = (enemies[e.rank] ?? 0) + 1;
    }
    // 간격은 화살표 길이로도 보인다 — 숫자보다 먼저 읽힌다.
    final arrow = '←${"─" * (battle.gap * 2 + 1)}→';
    return _panel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: _tinted(
        '일행 ${_side(party, enemySide: false)} '
        '${bt.paintText(bt.TextColor.yellow, "$arrow${battle.gap}")} '
        '${_side(enemies, enemySide: true)} 적',
      ),
    );
  }
}

/// 적 목록 — 이름 색이 남은 생명력을 대략 알려 준다(제8장 8.7).
class HDEnemyPane extends StatelessWidget {
  const HDEnemyPane({super.key, required this.battle});

  final lb.BattleView battle;

  @override
  Widget build(BuildContext context) {
    final order = bt.enemiesInDisplayOrder(battle);
    return _panel(
      child: ListView.builder(
        itemCount: order.length,
        itemBuilder: (context, row) {
          final i = order[row];
          final e = battle.enemies[i];
          final color = bt.enemyNameColor(
            hp: e.hp,
            unconscious: e.unconscious,
            dead: e.dead,
            episode: e.episode,
            alwaysBright: e.showsAsClone,
          );
          final state = e.dead > 0
              ? '죽음'
              : e.unconscious > 0
              ? '의식 불명'
              : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _tinted(
              '${(i + 1).toString().padLeft(2)}. '
              '${bt.paintText(color, bt.enemyDisplayName(e))} '
              '${bt.paintText(bt.TextColor.lightBlue, "${e.rank}열")}'
              '${state.isEmpty ? "" : "  ${bt.paintText(bt.TextColor.darkGray, state)}"}',
              style: _base.copyWith(fontSize: 14),
            ),
          );
        },
      ),
    );
  }
}

/// 일행 — 묻는 순서(리더 → 앞열부터)로, 생명력 · 마력과 지금 닿는 적.
class HDPartyPane extends StatelessWidget {
  const HDPartyPane({super.key, required this.battle});

  final lb.BattleView battle;

  String _reach(lb.CombatantView c) {
    if (!c.isConscious) return '';
    final reachable = <String>[];
    for (var i = 0; i < battle.enemies.length; i++) {
      final e = battle.enemies[i];
      if (!e.isPresent) continue;
      final distance = lb.distanceBetween(
        gap: battle.gap,
        attackerRank: c.rank,
        targetRank: e.rank,
      );
      if (lb.chooseAttack(c.weapon, distance).shortfall(distance) == 0) {
        reachable.add('${i + 1}');
      }
    }
    return reachable.isEmpty
        ? bt.paintText(bt.TextColor.darkGray, '닿는 적 없음')
        : bt.paintText(bt.TextColor.lightGreen, '→${reachable.join(",")}');
  }

  @override
  Widget build(BuildContext context) {
    return _panel(
      child: ListView(
        children: [
          for (final c in bt.partyInDisplayOrder(battle))
            _tinted(
              '${bt.paintText(bt.conditionColor(hp: c.hp, poison: c.poison, unconscious: c.unconscious, dead: c.dead), bt.memberDisplayName(c.snapshot))} '
              '${bt.paintText(bt.TextColor.lightBlue, "${c.rank}")} '
              '${c.hp}/${c.snapshot.maxHp}'
              '${c.snapshot.maxMp > 0 ? " ${bt.paintText(bt.TextColor.lightCyan, "${c.mp}")}" : ""} '
              '${_reach(c)}',
            ),
        ],
      ),
    );
  }
}
