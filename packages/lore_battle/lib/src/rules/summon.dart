import '../contract/battle_setup.dart';
import '../contract/vocabulary.dart';
import '../data/summon_table.dart';
import '../model/enemy_instance.dart';
import 'attack_magic.dart' show tiersOpened;
import 'condition.dart';
import 'rng.dart';

/// Summoning — ch.9.7 and the summoning crystal of ch.9.8.
///
/// Whatever is called lands in the sixth seat, replacing whoever sat
/// there, and **stays after the battle**. So the battle has to hand the
/// whole creature back, which is why this builds a [CombatantSnapshot]
/// rather than something lighter.

/// The summon tiers a skill value opens, 1..10.
List<int> castableSummonTiers(int summonSkill) => [
  for (var tier = 1; tier <= tiersOpened(summonSkill); tier++) tier,
];

/// What a summon costs — `skill × tier² ÷ 10`, rounded.
///
/// **Not the original's.** The original charges nothing, so a caster
/// could summon without end, and the design documents leave the number
/// to the remake (ch.9.7, appendix A D1). This is the curve the
/// appendix suggests: the same one attack magic is priced on.
int summonCost({required int skill, required int tier}) =>
    (skill * tier * tier + 5) ~/ 10;

/// The level a summon arrives at — `skill ÷ 5`, at least 1.
int summonLevel(int summonSkill) {
  final level = summonSkill ~/ 5;
  return level < 1 ? 1 : level;
}

/// Picks which creature a tier produces — one draw, uniform over every
/// form the tier holds.
({SummonSpec spec, SummonForm form}) pickSummon(int tier, BattleRng rng) {
  final specs = summonTiers[tier]!;
  final all = [
    for (final spec in specs)
      for (final form in spec.forms) (spec: spec, form: form),
  ];
  return all.length == 1 ? all.single : all[rng.next(all.length)];
}

/// What the summoning crystal produces in battle — the dragon one time
/// in three, the golem otherwise.
SummonSpec pickCrystalSummon(BattleRng rng) =>
    rng.next(3) == 0 ? crystalDragon : crystalGolem;

/// Rolls one creature into the sixth seat.
///
/// **Draw order**: strength, mentality, concentration, endurance,
/// resistance, accuracy, luck, armour, power. A stat with no spread
/// draws nothing. Agility is always 0 — a summon acts after everything
/// that has any.
CombatantSnapshot rollSummon({
  required SummonSpec spec,
  required SummonForm form,
  required int summonSkill,
  required BattleRng rng,
}) {
  int roll(StatRoll s) => rollSpread(s.base, s.spread, rng);

  final strength = roll(spec.strength);
  final mentality = roll(spec.mentality);
  final concentration = roll(spec.concentration);
  final endurance = roll(spec.endurance);
  final resistance = roll(spec.resistance);
  final accuracy = roll(spec.accuracy);
  final luck = roll(spec.luck);
  final ac = roll(spec.ac);

  final rule = spec.power;
  final int power;
  if (rule.fixed != null) {
    power = roll(rule.fixed!);
  } else if (rule.randomUpTo > 0) {
    power = summonSkill * (rng.next(rule.randomUpTo) + 1);
  } else {
    power = summonSkill * rule.tenths ~/ 10;
  }

  final level = spec.fixedLevel ?? summonLevel(summonSkill);
  final maxHp = endurance * level * 10;
  final maxMp = spec.holdsMagic ? mentality * level : 0;
  final skills = List<int>.filled(6, 0);
  for (final slot in spec.skillSlotsAtSummonSkill) {
    skills[slot] = summonSkill;
  }

  return CombatantSnapshot(
    slot: assistantSeat,
    name: '',
    nameKey: form.nameKey,
    family: spec.family,
    classId: spec.classId,
    level: level,
    strength: strength < 0 ? 0 : strength,
    mentality: mentality < 0 ? 0 : mentality,
    concentration: concentration < 0 ? 0 : concentration,
    endurance: endurance < 0 ? 0 : endurance,
    resistance: resistance < 0 ? 0 : resistance,
    agility: 0,
    accuracy: accuracy < 0 ? 0 : accuracy,
    luck: luck < 0 ? 0 : luck,
    skills: skills,
    hp: maxHp < 1 ? 1 : maxHp,
    maxHp: maxHp < 1 ? 1 : maxHp,
    mp: maxMp,
    maxMp: maxMp,
    ac: ac < 0 ? 0 : ac,
    weaponPower: power < 1 ? 1 : power,
    weaponKind: spec.weaponKind,
    shieldPower: spec.shieldPower,
    rank: spec.rank,
    weaponKey: form.weaponKey ?? spec.weaponKey,
    weaponNameKey: form.weaponNameKey ?? spec.weaponNameKey,
    attacksAll: spec.attacksAll,
    immuneToMindControl: spec.immuneToMindControl,
  );
}

/// An enemy that 독심 talked round, as the assistant it becomes
/// (ch.7.8's conversion table).
///
/// | | |
/// |---|---|
/// | level · strength · mentality · endurance · agility | the enemy's own |
/// | family | unknown — so it strikes one enemy (appendix A #12) |
/// | concentration | 0 |
/// | resistance | its physical resistance ÷ 2 |
/// | accuracy | its physical accuracy |
/// | luck | 10 |
/// | hit points / magic points | `endurance × level × 10` / `mentality × level × 10`, full |
/// | armour class | the enemy's own |
/// | weapon power | `level × 2 + 10` |
CombatantSnapshot recruitFromEnemy(EnemyInstance enemy) {
  final maxHp = enemy.endurance * enemy.level * 10;
  final maxMp = enemy.mentality * enemy.level * 10;
  return CombatantSnapshot(
    slot: assistantSeat,
    name: enemy.displayName ?? '',
    nameKey: enemy.displayName == null
        ? 'enemy.${enemy.episode}.${enemy.nameKey}'
        : '',
    family: Family.unknown,
    classId: 0,
    level: enemy.level,
    strength: enemy.strength,
    mentality: enemy.mentality,
    concentration: 0,
    endurance: enemy.endurance,
    resistance: enemy.physicalResistance ~/ 2,
    agility: enemy.agility,
    accuracy: enemy.accuracyPhysical,
    luck: 10,
    hp: maxHp < 1 ? 1 : maxHp,
    maxHp: maxHp < 1 ? 1 : maxHp,
    mp: maxMp,
    maxMp: maxMp,
    ac: enemy.ac,
    weaponPower: enemy.level * 2 + 10,
    weaponKind: WeaponKind.special,
    rank: enemy.rank,
    weaponKey: 'natural_slash',
    weaponNameKey: 'natural.attack',
    attacksAll: false,
  );
}
