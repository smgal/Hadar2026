import 'package:hd_battle/hd_battle.dart';

/// The party the RPG starts a new game with, as a battle snapshot.
///
/// Mirrors `hadar2026_app/lib/domain/party/party.dart:189-238`, with the
/// two derived values already resolved the way the RPG would resolve
/// them: `ac` is `baseAc + equipmentAc` (leather armour is ac 1) and
/// `powOfWeapon` is the dagger's attack power (10).
CombatantSnapshot seumgal({int hp = 150, int slot = 0}) => CombatantSnapshot(
  slot: slot,
  name: 'Seumgal',
  characterClass: 0,
  strength: 18,
  mentality: 20,
  concentration: 20,
  endurance: 15,
  agility: 12,
  ac: 6,
  hp: hp,
  maxHp: 150,
  sp: 100,
  maxSp: 100,
  esp: 100,
  maxEsp: 100,
  accuracyPhysical: 15,
  accuracyMagic: 15,
  accuracyEsp: 15,
  levelPhysical: 1,
  levelMagic: 20,
  levelEsp: 20,
  powOfWeapon: 10,
  weaponName: 'Dagger',
);

CombatantSnapshot yuri({int hp = 100, int slot = 1}) => CombatantSnapshot(
  slot: slot,
  name: 'Yuri',
  characterClass: 2,
  strength: 10,
  endurance: 10,
  agility: 15,
  ac: 4,
  hp: hp,
  maxHp: 100,
  sp: 100,
  maxSp: 100,
  esp: 80,
  maxEsp: 80,
  accuracyPhysical: 10,
  levelPhysical: 1,
  levelEsp: 1,
  powOfWeapon: 10,
  weaponName: 'Dagger',
);

BattleSetup startingSetup({
  List<String> enemyKeys = const ['giant', 'wolf'],
  int seed = 1,
  int seumgalHp = 150,
  int yuriHp = 100,
}) => BattleSetup(
  party: [
    seumgal(hp: seumgalHp),
    yuri(hp: yuriHp),
  ],
  enemyKeys: enemyKeys,
  seed: seed,
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
  ItemUseDecision() => ChooseItemUse(decision.slot, ItemUse.coat),
};

/// Opens the skill list and casts the first skill whose scope passes
/// [scope]; attacks when there is none. Answers everything else the way
/// [alwaysAttack] does.
BattleCommand? Function(BattleDecision) castFirst(
  bool Function(SkillOption option) scope,
) =>
    (decision) => switch (decision) {
      ActionDecision() => ChooseAction(
        decision.slot,
        decision.options.contains(BattleAction.castSkill)
            ? BattleAction.castSkill
            : BattleAction.attack,
      ),
      SpellDecision() => () {
        final picks = decision.options.where(scope);
        return picks.isEmpty
            ? CancelChoice(decision.slot)
            : ChooseSpell(decision.slot, picks.first.magicId);
      }(),
      _ => alwaysAttack(decision),
    };
