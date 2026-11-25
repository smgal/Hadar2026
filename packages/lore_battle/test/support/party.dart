import 'package:lore_battle/lore_battle.dart';

/// A knight: sword and shield, front rank.
///
/// Hit points follow the Part 3 formula, `endurance × level × 10`, so
/// the fixtures stay honest about scale.
CombatantSnapshot knight({
  int slot = 0,
  String name = 'Knight',
  int level = 5,
  int? hp,
  int rank = 1,
  int accuracy = 15,
  int strength = 16,
  int luck = 10,
  int ac = 4,
  int shieldPower = 2,
  List<int> skills = const [50, 10, 10, 0, 30, 0],
  String weaponKey = 'one_hand_slash',
  WeaponKind weaponKind = WeaponKind.slash,
  int weaponPower = 40,
  int poison = 0,
  int unconscious = 0,
  int dead = 0,
}) => CombatantSnapshot(
  slot: slot,
  name: name,
  family: Family.fighter,
  classId: ClassId.knight,
  level: level,
  strength: strength,
  mentality: 8,
  concentration: 8,
  endurance: 15,
  resistance: 10,
  agility: 12,
  accuracy: accuracy,
  luck: luck,
  skills: skills,
  hp: hp ?? 15 * level * 10,
  maxHp: 15 * level * 10,
  ac: ac,
  weaponPower: weaponPower,
  weaponKind: weaponKind,
  shieldPower: shieldPower,
  rank: rank,
  weaponKey: weaponKey,
  weaponName: 'Sabre',
  poison: poison,
  unconscious: unconscious,
  dead: dead,
);

/// A mage with every magic skill open at [skill].
CombatantSnapshot mage({
  int slot = 1,
  String name = 'Mage',
  int level = 5,
  int skill = 100,
  int? mp,
  int? hp,
  int rank = 3,
  int accuracy = 19,
  int concentration = 15,
  int classId = ClassId.necromancer,
  List<int>? skills,
}) => CombatantSnapshot(
  slot: slot,
  name: name,
  family: Family.mage,
  classId: classId,
  level: level,
  strength: 8,
  mentality: 18,
  concentration: concentration,
  endurance: 10,
  resistance: 12,
  agility: 10,
  accuracy: accuracy,
  luck: 10,
  skills: skills ?? [skill, skill, skill, skill, skill, skill],
  hp: hp ?? 10 * level * 10,
  maxHp: 10 * level * 10,
  mp: mp ?? 18 * level * 10,
  maxMp: 18 * level * 10,
  rank: rank,
  weaponName: 'Bare hands',
);

/// A paladin: a fighter whose second skill slot is the cure skill.
CombatantSnapshot paladin({
  int slot = 2,
  int level = 5,
  int cureSkill = 50,
  int? mp,
}) => CombatantSnapshot(
  slot: slot,
  name: 'Paladin',
  family: Family.fighter,
  classId: ClassId.paladin,
  level: level,
  strength: 15,
  mentality: 12,
  endurance: 14,
  resistance: 10,
  agility: 11,
  accuracy: 15,
  luck: 10,
  skills: [40, cureSkill, 10, 0, 40, 10],
  hp: 14 * level * 10,
  maxHp: 14 * level * 10,
  mp: mp ?? 12 * level * 5,
  maxMp: 12 * level * 5,
  ac: 4,
  weaponPower: 40,
  weaponKind: WeaponKind.slash,
  shieldPower: 2,
  rank: 1,
  weaponKey: 'one_hand_slash',
  weaponName: 'Sabre',
);

/// A hunter with a bow, back rank.
CombatantSnapshot hunter({int slot = 3, int level = 5}) => CombatantSnapshot(
  slot: slot,
  name: 'Hunter',
  family: Family.fighter,
  classId: ClassId.hunter,
  level: level,
  strength: 14,
  endurance: 12,
  resistance: 8,
  agility: 16,
  accuracy: 18,
  luck: 12,
  skills: const [0, 10, 10, 60, 0, 10],
  hp: 12 * level * 10,
  maxHp: 12 * level * 10,
  ac: 3,
  weaponPower: 55,
  weaponKind: WeaponKind.shoot,
  rank: 3,
  weaponKey: 'bow',
  weaponName: 'Bow',
);

/// A monk — bare hands, fixed coefficient.
CombatantSnapshot monk({int slot = 4, int level = 5}) => CombatantSnapshot(
  slot: slot,
  name: 'Monk',
  family: Family.fighter,
  classId: ClassId.monk,
  level: level,
  strength: 17,
  endurance: 13,
  resistance: 9,
  agility: 15,
  accuracy: 16,
  luck: 11,
  skills: const [0, 0, 0, 0, 0, 60],
  hp: 13 * level * 10,
  maxHp: 13 * level * 10,
  ac: 3,
  rank: 1,
  weaponName: 'Bare hands',
);

/// A plain assistant for seat 5.
CombatantSnapshot assistant({
  bool attacksAll = false,
  bool immune = false,
  int hp = 600,
  int level = 6,
}) => CombatantSnapshot(
  slot: assistantSeat,
  name: 'Helper',
  family: Family.unknown,
  level: level,
  strength: 12,
  endurance: 10,
  resistance: 5,
  accuracy: 15,
  luck: 10,
  hp: hp,
  maxHp: 600,
  ac: 2,
  weaponPower: 22,
  weaponKind: WeaponKind.special,
  rank: 1,
  weaponKey: 'natural_slash',
  weaponName: 'Claws',
  attacksAll: attacksAll,
  immuneToMindControl: immune,
);

/// The five who take commands.
List<CombatantSnapshot> partyOfFive() => [
  knight(),
  mage(),
  paladin(),
  hunter(),
  monk(),
];

BattleSetup setupFor({
  List<CombatantSnapshot>? party,
  List<String> enemyKeys = const ['orc_soldier', 'orc_soldier'],
  int seed = 1,
  int episode = 3,
  Map<String, int> consumables = const {},
  int arrows = 50,
  int? initialGap = 0,
  List<int> enemyRanks = const [],
  Map<int, EnemyOverride> enemyOverrides = const {},
  bool canEscape = true,
  bool enemyActsFirst = false,
  bool attackUnconscious = true,
}) => BattleSetup(
  party: party ?? partyOfFive(),
  enemyKeys: enemyKeys,
  seed: seed,
  episode: episode,
  consumables: consumables,
  arrows: arrows,
  initialGap: initialGap,
  enemyRanks: enemyRanks,
  enemyOverrides: enemyOverrides,
  canEscape: canEscape,
  enemyActsFirst: enemyActsFirst,
  attackUnconscious: attackUnconscious,
);

/// Drives a battle to the end, answering every decision with [answer].
///
/// Returns every event in order. [answer] gets the decision and returns
/// the command; returning null means cancel.
({List<BattleEvent> events, BattleOutcome outcome}) runBattle(
  Battle battle,
  BattleCommand? Function(BattleDecision decision) answer, {
  int stepLimit = 5000,
}) {
  final events = <BattleEvent>[];
  var steps = 0;
  while (!battle.isFinished) {
    if (steps++ > stepLimit) {
      throw StateError('battle did not finish within $stepLimit steps');
    }
    final decision = battle.pendingDecision;
    if (decision == null) {
      events.addAll(battle.advance());
    } else {
      final command = answer(decision) ?? CancelChoice(decision.slot);
      events.addAll(battle.applyCommand(command));
    }
  }
  return (events: events, outcome: battle.outcome!);
}

/// Always attacks the first offered enemy; cancels nothing.
BattleCommand? alwaysAttack(BattleDecision decision) => switch (decision) {
  ActionDecision() => ChooseAction(decision.slot, BattleAction.attack),
  EnemyTargetDecision() => ChooseEnemyTarget(
    decision.slot,
    decision.enemyIndices.first,
  ),
  SpellDecision() => ChooseSpell(decision.slot, decision.magicIds.first),
  ItemDecision() => ChooseItem(decision.slot, decision.itemKeys.first),
  AllyTargetDecision() => ChooseAllyTarget(decision.slot, decision.slots.first),
  OrderDecision() => ChooseAction(decision.slot, decision.options.first),
};

/// One member ([slot]) casts [magicId] every round — at [enemyIndex] or
/// [allySlot] when it is asked — and everyone else attacks.
BattleCommand? Function(BattleDecision) castEveryRound(
  int slot,
  int magicId, {
  int? enemyIndex,
  int? allySlot,
}) => (decision) {
  if (decision.slot != slot) return alwaysAttack(decision);
  return switch (decision) {
    ActionDecision() => ChooseAction(
      slot,
      decision.options.contains(BattleAction.castSkill)
          ? BattleAction.castSkill
          : BattleAction.attack,
    ),
    SpellDecision() =>
      decision.magicIds.contains(magicId)
          ? ChooseSpell(slot, magicId)
          : CancelChoice(slot),
    EnemyTargetDecision() => ChooseEnemyTarget(
      slot,
      enemyIndex != null && decision.enemyIndices.contains(enemyIndex)
          ? enemyIndex
          : decision.enemyIndices.first,
    ),
    AllyTargetDecision() => ChooseAllyTarget(
      slot,
      allySlot != null && decision.slots.contains(allySlot)
          ? allySlot
          : decision.slots.first,
    ),
    _ => alwaysAttack(decision),
  };
};

/// One member ([slot]) uses [itemKey] every round while the party has
/// it; everyone else attacks.
BattleCommand? Function(BattleDecision) useItemEveryRound(
  int slot,
  String itemKey, {
  int? enemyIndex,
  int? allySlot,
}) => (decision) {
  if (decision.slot != slot) return alwaysAttack(decision);
  return switch (decision) {
    ActionDecision() => ChooseAction(
      slot,
      decision.options.contains(BattleAction.useItem)
          ? BattleAction.useItem
          : BattleAction.attack,
    ),
    ItemDecision() =>
      decision.itemKeys.contains(itemKey)
          ? ChooseItem(slot, itemKey)
          : CancelChoice(slot),
    EnemyTargetDecision() => ChooseEnemyTarget(
      slot,
      enemyIndex != null && decision.enemyIndices.contains(enemyIndex)
          ? enemyIndex
          : decision.enemyIndices.first,
    ),
    AllyTargetDecision() => ChooseAllyTarget(
      slot,
      allySlot != null && decision.slots.contains(allySlot)
          ? allySlot
          : decision.slots.first,
    ),
    _ => alwaysAttack(decision),
  };
};

/// Plays exactly one round: the opening `advance()` if the battle has
/// not started, every decision answered with [answer], and every turn
/// resolved. Returns that round's events — the last of them are the
/// party's poison and the next round's `RoundStarted`, since the same
/// step that closes a round opens the next.
List<BattleEvent> playOneRound(
  Battle battle,
  BattleCommand? Function(BattleDecision decision) answer,
) {
  final events = <BattleEvent>[];
  if (battle.phase == BattlePhase.intro) events.addAll(battle.advance());
  final round = battle.round;
  var guard = 0;
  while (!battle.isFinished && battle.round == round && guard++ < 2000) {
    final decision = battle.pendingDecision;
    if (decision == null) {
      events.addAll(battle.advance());
    } else {
      events.addAll(
        battle.applyCommand(answer(decision) ?? CancelChoice(decision.slot)),
      );
    }
  }
  return events;
}
