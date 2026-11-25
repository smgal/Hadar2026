// 제3부 전투 한 판을 사람 손 없이 굴려 문장을 눈으로 확인하는 도구.
//
//   dart run tool/auto_play.dart            # 시드 7, 오크병사 넷
//   dart run tool/auto_play.dart 21         # 다른 시드
//   dart run tool/auto_play.dart 7 --ambush # 적이 먼저 (첫 턴에 일행 차례 없음)
//   dart run tool/auto_play.dart 7 --color  # 색 표기(@D…@@)를 지우지 않고 그대로
//
// 규칙은 `lore_battle`, 문장은 `lore_battle_text` 에서만 온다 — 여기에는
// 누가 무엇을 고를지(간단한 정책)와 줄을 찍는 일만 있다.
import 'dart:io';

import 'package:lore_battle/lore_battle.dart';
import 'package:lore_battle_text/lore_battle_text.dart';

/// 레벨 3 안팎의 다섯 — 가이아 테라에서 오크 마을로 갈 무렵의 일행.
List<CombatantSnapshot> _party() => const [
  CombatantSnapshot(
    slot: 0,
    name: '아르젠',
    family: Family.fighter,
    classId: ClassId.knight,
    level: 3,
    strength: 14,
    mentality: 6,
    endurance: 15,
    resistance: 9,
    agility: 11,
    accuracy: 13,
    luck: 10,
    skills: [10, 10, 5, 0, 20, 0],
    hp: 450,
    maxHp: 450,
    ac: 4,
    weaponPower: 30,
    weaponKind: WeaponKind.slash,
    shieldPower: 1,
    rank: 1,
    weaponKey: 'one_hand_slash',
    weaponName: '그라디우스',
  ),
  CombatantSnapshot(
    slot: 1,
    name: '리라',
    family: Family.mage,
    classId: ClassId.mage,
    level: 3,
    strength: 6,
    mentality: 17,
    concentration: 12,
    endurance: 9,
    resistance: 12,
    agility: 10,
    accuracy: 15,
    luck: 12,
    skills: [20, 10, 10, 0, 20, 0],
    hp: 270,
    maxHp: 270,
    mp: 510,
    maxMp: 510,
    ac: 1,
    rank: 3,
    weaponName: '맨손',
  ),
  CombatantSnapshot(
    slot: 2,
    name: '세드릭',
    family: Family.fighter,
    classId: ClassId.paladin,
    level: 3,
    strength: 13,
    mentality: 11,
    endurance: 14,
    resistance: 10,
    agility: 9,
    accuracy: 12,
    luck: 9,
    skills: [25, 20, 5, 0, 20, 10],
    hp: 420,
    maxHp: 420,
    mp: 165,
    maxMp: 165,
    ac: 4,
    weaponPower: 30,
    weaponKind: WeaponKind.slash,
    shieldPower: 1,
    rank: 1,
    weaponKey: 'one_hand_slash',
    weaponName: '그라디우스',
  ),
  CombatantSnapshot(
    slot: 3,
    name: '미라벨',
    family: Family.fighter,
    classId: ClassId.hunter,
    level: 3,
    strength: 11,
    endurance: 11,
    resistance: 8,
    agility: 16,
    accuracy: 17,
    luck: 13,
    skills: [0, 5, 5, 40, 0, 0],
    hp: 330,
    maxHp: 330,
    ac: 3,
    weaponPower: 27,
    weaponKind: WeaponKind.shoot,
    rank: 3,
    weaponKey: 'sling',
    weaponName: '투석기',
  ),
  CombatantSnapshot(
    slot: 4,
    name: '도윤',
    family: Family.fighter,
    classId: ClassId.fighter,
    level: 2,
    strength: 12,
    endurance: 12,
    resistance: 8,
    agility: 12,
    accuracy: 11,
    luck: 10,
    skills: [10, 10, 10, 10, 10, 0],
    hp: 240,
    maxHp: 240,
    ac: 3,
    weaponPower: 35,
    weaponKind: WeaponKind.pierce,
    rank: 2,
    weaponKey: 'spear',
    weaponName: '단창',
  ),
];

/// 누가 무엇을 고르는지. 일부러 단순하다 — 문장을 고루 내는 것이 목적이다.
///
/// * 리라(1): 첫 턴은 전체 공격 마법, 그 뒤로는 낼 수 있는 가장 높은 단일
///   공격 마법
/// * 세드릭(2): 다친 사람이 있으면 치료, 없으면 공격
/// * 나머지: 맨 앞의 적을 공격
BattleCommand _answer(Battle battle, BattleDecision decision) {
  final slot = decision.slot;
  switch (decision) {
    case ActionDecision(:final options):
      final canCast = options.contains(BattleAction.castSkill);
      if (slot == 1 && canCast) {
        return ChooseAction(slot, BattleAction.castSkill);
      }
      if (slot == 2 && canCast && _someoneIsHurt(battle)) {
        return ChooseAction(slot, BattleAction.castSkill);
      }
      return ChooseAction(slot, BattleAction.attack);

    case SpellDecision(:final options):
      bool has(int id) => options.any((o) => o.magicId == id && o.affordable);
      if (slot == 2) {
        final heal = skillId(SkillCategory.cure, 1);
        return has(heal) ? ChooseSpell(slot, heal) : CancelChoice(slot);
      }
      final area = skillId(SkillCategory.attackAll, 1);
      if (battle.round == 1 && has(area)) return ChooseSpell(slot, area);
      final singles = [
        for (final o in options)
          if (o.category == SkillCategory.attackOne && o.affordable) o.magicId,
      ];
      return singles.isEmpty
          ? CancelChoice(slot)
          : ChooseSpell(slot, singles.last);

    case EnemyTargetDecision(:final enemyIndices):
      return ChooseEnemyTarget(slot, enemyIndices.first);

    // 가장 급한 사람이 맨 앞에 온다.
    case AllyTargetDecision(:final slots):
      return ChooseAllyTarget(slot, slots.first);

    case ItemDecision(:final itemKeys):
      return ChooseItem(slot, itemKeys.first);

    case OrderDecision(:final options):
      return ChooseAction(slot, options.first);
  }
}

bool _someoneIsHurt(Battle battle) =>
    battle.party.any((c) => c.isConscious && c.hp * 4 < c.snapshot.maxHp * 3);

final RegExp _colorMarkup = RegExp(r'@[0-9A-F@]');

void main(List<String> args) {
  final seed = args.isNotEmpty ? int.tryParse(args.first) ?? 7 : 7;
  final ambush = args.contains('--ambush');
  final keepColor = args.contains('--color');

  final battle = Battle(
    BattleSetup(
      party: _party(),
      enemyKeys: const [
        'orc_soldier',
        'orc_soldier',
        'orc_soldier',
        'orc_soldier',
      ],
      seed: seed,
      episode: 3,
      consumables: const {ItemKey.hpPotion: 2},
      arrows: 20,
      initialGap: 0,
      enemyActsFirst: ambush,
    ),
  );
  final names = LoreBattleNames(
    battle,
    pronounOf: (slot) => slot == 1 ? '그녀' : '그',
  );

  void show(Iterable<BattleEvent> events) {
    for (final event in events) {
      for (final line in battleLines(event, names)) {
        stdout.writeln(keepColor ? line : line.replaceAll(_colorMarkup, ''));
      }
    }
  }

  var steps = 0;
  while (!battle.isFinished && steps++ < 5000) {
    final decision = battle.pendingDecision;
    if (decision == null) {
      show(battle.advance());
    } else {
      show(battle.applyCommand(_answer(battle, decision)));
    }
  }

  final outcome = battle.outcome;
  if (outcome == null) {
    stdout.writeln('[전투가 $steps 걸음 안에 끝나지 않았다]');
    exitCode = 1;
    return;
  }
  stdout.writeln('');
  stdout.writeln(
    '결과 ${outcome.resultCode.name}(${outcome.resultCode.wire}) · '
    '금 ${outcome.goldGained} · 화살 ${outcome.arrowsUsed}개 사용',
  );
  for (final c in outcome.combatants) {
    stdout.writeln(
      '  ${names.member(c.slot)}  HP ${c.hp}  MP ${c.mp}  '
      '경험치 +${c.experienceGained}',
    );
  }
}
