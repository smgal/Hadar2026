import '../data/enemy_data.dart';
import '../model/enemy_instance.dart';
import 'condition.dart';
import 'rng.dart';

/// Special magic — ch.9.5.
///
/// Five spells that take a capability away instead of hit points, each
/// with a one-enemy form (tiers 1..5) and an every-enemy form (6..10).
/// None of them deals damage.

/// Which of the five a tier is. Tiers 6..10 are the same five again.
enum SpecialKind {
  /// 기술 무력화 — removes the special attack.
  disarm,

  /// 방어 무력화 — armour and both resistances.
  weaken,

  /// 능력 저하 — level and both resistances.
  drain,

  /// 마법 불능 — the casting ladder, one rung.
  silence,

  /// 탈 초인화 — one supernatural ability.
  unmake,

  /// 독 — Part 1 only. Poisons the target (1st/07 7.5).
  poison,
}

/// One special spell's numbers.
class SpecialSpell {
  const SpecialSpell({
    required this.kind,
    required this.cost,
    required this.resistRange,
    required this.accuracyRange,
    this.resistsWithPhysical = false,
  });

  final SpecialKind kind;

  /// Flat magic-point cost, per target.
  final int cost;

  /// `rand(resistRange) < resistance` stops it.
  final int resistRange;

  /// `rand(accuracyRange) > accuracy` misses. Wider is harder to land.
  final int accuracyRange;

  /// 방어 무력화 is the one that is rolled against **physical**
  /// resistance; the rest are against magic resistance.
  final bool resistsWithPhysical;
}

/// The table, from ch.9.5.
const Map<SpecialKind, SpecialSpell> specialSpells = {
  SpecialKind.disarm: SpecialSpell(
    kind: SpecialKind.disarm,
    cost: 200,
    resistRange: 100,
    accuracyRange: 60,
  ),
  SpecialKind.weaken: SpecialSpell(
    kind: SpecialKind.weaken,
    cost: 50,
    resistRange: 100,
    accuracyRange: 40,
    resistsWithPhysical: true,
  ),
  SpecialKind.drain: SpecialSpell(
    kind: SpecialKind.drain,
    cost: 100,
    resistRange: 200,
    accuracyRange: 30,
  ),
  SpecialKind.silence: SpecialSpell(
    kind: SpecialKind.silence,
    cost: 150,
    resistRange: 100,
    accuracyRange: 100,
  ),
  SpecialKind.unmake: SpecialSpell(
    kind: SpecialKind.unmake,
    cost: 400,
    resistRange: 100,
    accuracyRange: 100,
  ),
  // Part 1's own. The documents keep it "as the original had it" and
  // give no Part 3 numbers; these are the original's (cost 10, the
  // poison roll's 100 / 40).
  SpecialKind.poison: SpecialSpell(
    kind: SpecialKind.poison,
    cost: 10,
    resistRange: 100,
    accuracyRange: 40,
  ),
};

/// The spell a tier casts, 1..10.
SpecialKind specialKindOfTier(int tier) => switch ((tier - 1) % 5) {
  0 => SpecialKind.disarm,
  1 => SpecialKind.weaken,
  2 => SpecialKind.drain,
  3 => SpecialKind.silence,
  _ => SpecialKind.unmake,
};

/// Tiers 6..10 are cast on every enemy.
bool specialTierHitsAll(int tier) => tier >= 6;

/// 방어 무력화 is easier to land on something heavily armoured:
/// `rand(25)` instead of `rand(40)` once armour class is 5 or more.
int specialAccuracyRange(SpecialSpell spell, {required int enemyAc}) =>
    spell.kind == SpecialKind.weaken && enemyAc >= 5 ? 25 : spell.accuracyRange;

/// How one cast ended.
enum SpecialOutcome { resisted, missed, applied }

/// What an applied spell actually changed, for the view to name.
enum SpecialEffect {
  none,
  specialRemoved,
  defenceLowered,
  abilityLowered,
  castingLowered,
  castingRemoved,
  superhumanLowered,
  superhumanRemoved,
  poisoned,
}

/// Casts one special spell on one enemy. **The caller has already
/// charged for it** — a stopped spell still costs.
///
/// Resistance first, then accuracy, as the document's columns run.
/// Every reduction goes through [reduceStat]; the original's unsigned
/// bytes wrapped a resistance of 5 round to 251 (appendix A #37).
({SpecialOutcome outcome, SpecialEffect effect}) castSpecial(
  SpecialKind kind, {
  required EnemyInstance target,
  required int accuracy,
  required BattleRng rng,
}) {
  final spell = specialSpells[kind]!;
  final resistance = spell.resistsWithPhysical
      ? target.physicalResistance
      : target.magicResistance;
  if (rng.next(spell.resistRange) < resistance) {
    return (outcome: SpecialOutcome.resisted, effect: SpecialEffect.none);
  }
  if (rng.next(specialAccuracyRange(spell, enemyAc: target.ac)) > accuracy) {
    return (outcome: SpecialOutcome.missed, effect: SpecialEffect.none);
  }

  switch (kind) {
    case SpecialKind.disarm:
      target.special = EnemySpecial.none;
      return (
        outcome: SpecialOutcome.applied,
        effect: SpecialEffect.specialRemoved,
      );

    case SpecialKind.weaken:
      // Armour always goes on a lightly resistant target; on a
      // resistant one it is a coin toss. Both resistances drop either
      // way — separately, each to its own floor (appendix A #20).
      if (target.physicalResistance < 31 || rng.next(2) == 0) {
        target.ac = reduceStat(target.ac, 1);
      }
      target.physicalResistance = reduceStat(target.physicalResistance, 10);
      target.magicResistance = reduceStat(target.magicResistance, 10);
      return (
        outcome: SpecialOutcome.applied,
        effect: SpecialEffect.defenceLowered,
      );

    case SpecialKind.drain:
      target.level = reduceStat(target.level, 1, floor: 1);
      target.physicalResistance = reduceStat(target.physicalResistance, 10);
      target.magicResistance = reduceStat(target.magicResistance, 10);
      return (
        outcome: SpecialOutcome.applied,
        effect: SpecialEffect.abilityLowered,
      );

    case SpecialKind.silence:
      target.castLevel = reduceStat(target.castLevel, 1);
      return (
        outcome: SpecialOutcome.applied,
        effect: target.castLevel == 0
            ? SpecialEffect.castingRemoved
            : SpecialEffect.castingLowered,
      );

    case SpecialKind.unmake:
      // Part 3 names its abilities, so one is taken — the lowest, which
      // is what the original meant to do before it added one instead
      // (appendix A #2). Parts 1 and 2 grade them, so the grade drops.
      if (target.abilities.isNotEmpty) {
        final lowest = target.abilities.reduce(
          (a, b) => a.index < b.index ? a : b,
        );
        target.removeAbility(lowest);
      } else {
        target.superLevel = reduceStat(target.superLevel, 1);
      }
      return (
        outcome: SpecialOutcome.applied,
        effect: target.hasSupernatural
            ? SpecialEffect.superhumanLowered
            : SpecialEffect.superhumanRemoved,
      );

    case SpecialKind.poison:
      target.poison += 1;
      return (outcome: SpecialOutcome.applied, effect: SpecialEffect.poisoned);
  }
}
