import 'rng.dart';

/// ESP in battle, magic 41-45 (B2-10).
///
/// Not a fourth attack category. Three of the five do nothing in combat,
/// one recruits an enemy, and one rolls a table.

/// What an ESP ability does when used in a battle.
enum EspAbility {
  /// 41 · 42 · 44 — clairvoyance, prophecy, farsight. **No combat
  /// effect at all**: the original printed the name and returned.
  inert,

  /// 43 — mind control. Turns a whitelisted enemy into a party member.
  mindControl,

  /// 45 — psychokinesis. Rolls [psychokineticEffect] off the caster's
  /// ESP level.
  psychokinesis,
}

EspAbility? espAbilityFor(int magicId) => switch (magicId) {
  41 || 42 || 44 => EspAbility.inert,
  43 => EspAbility.mindControl,
  45 => EspAbility.psychokinesis,
  _ => null,
};

/// ESP points an ability costs. The inert three cost nothing because
/// they return before the check.
int espCost(EspAbility ability) => switch (ability) {
  EspAbility.inert => 0,
  EspAbility.mindControl => 15,
  EspAbility.psychokinesis => 20,
};

/// The one ESP ability that adds a party member (B2-10 · B5-09).
const int mindControlMagicId = 43;

// --- 43 mind control -------------------------------------------------

/// Enemies that can be talked round, by table index.
///
/// `static const SmSet MIND_CONTROLLABLE("6,10,20,24,27,29,33,35,40,47,53,62")`
/// tested against `PcEnemy.ed_number`, which is the argument
/// `registerEnemy` took — so these are indices into the 75-row table
/// (appendix P-4), not the Unity port's shifted ones.
///
/// Read that way the list is coherent: Phantom · Python · Gazer ·
/// Kobold · Crazy One · Headless · Basilisk · Vampire · Rotten Corpse ·
/// Dancing-Swd · Dragon · Death Knight — the thinking and undead ones.
const Set<int> mindControllableLegacyIds = {
  6,
  10,
  20,
  24,
  27,
  29,
  33,
  35,
  40,
  47,
  53,
  62,
};

/// Death Knight is forced to level 17 for the difficulty check.
///
/// `if (p_enemy->ed_number == 62) enemyLevel = 17;` — its real level is
/// higher, so without this the strongest recruitable enemy would be
/// unrecruitable. Kept as a deliberate exception.
const int deathKnightLegacyId = 62;
const int deathKnightEffectiveLevel = 17;

/// Why a mind control attempt ended.
enum MindControlOutcome {
  /// The enemy is not on the list.
  immune,

  /// Not enough ESP points.
  notAffordable,

  /// The enemy outranks the caster and the coin went against them.
  outmatched,

  /// The persuasion roll failed.
  unmoved,

  /// The enemy joins the party.
  recruited,
}

/// Resolves magic 43 against one enemy.
///
/// Two gates, in the original's order:
///
/// 1. `enemyLevel > espLevel && random(2) == 0` — a stronger enemy
///    shrugs it off half the time.
/// 2. `random(60) > (espLevel - enemyLevel) * 2 + accuracyEsp` — the
///    level gap counts double toward the persuasion.
MindControlOutcome resolveMindControl({
  required int enemyLegacyId,
  required int enemyLevel,
  required int espLevel,
  required int accuracyEsp,
  required int casterEsp,
  required BattleRng rng,
}) {
  if (casterEsp < espCost(EspAbility.mindControl)) {
    return MindControlOutcome.notAffordable;
  }
  if (!mindControllableLegacyIds.contains(enemyLegacyId)) {
    return MindControlOutcome.immune;
  }
  final effective = enemyLegacyId == deathKnightLegacyId
      ? deathKnightEffectiveLevel
      : enemyLevel;
  if (effective > espLevel && rng.next(2) == 0) {
    return MindControlOutcome.outmatched;
  }
  if (rng.next(60) > (espLevel - effective) * 2 + accuracyEsp) {
    return MindControlOutcome.unmoved;
  }
  return MindControlOutcome.recruited;
}

// --- 45 psychokinesis ------------------------------------------------

/// What a psychokinesis roll produced.
enum PsychokineticEffect {
  /// Rolls 1-6: `roll x 10` to one enemy.
  strikeOne,

  /// Rolls 7-10: `roll x 5` to every enemy.
  strikeAll,

  /// Rolls 11-12: the enemy flees outright.
  terrify,

  /// Rolls 13-14: poison.
  poison,

  /// Rolls 15-17: stops the heart — adds to the unconscious
  /// accumulator (B2-03) without touching hit points.
  stopHeart,

  /// 18 and up: illusion — dulls the enemy's accuracy.
  illusion,
}

/// Which effect a roll lands on.
PsychokineticEffect psychokineticEffect(int roll) {
  if (roll <= 6) return PsychokineticEffect.strikeOne;
  if (roll <= 10) return PsychokineticEffect.strikeAll;
  if (roll <= 12) return PsychokineticEffect.terrify;
  if (roll <= 14) return PsychokineticEffect.poison;
  if (roll <= 17) return PsychokineticEffect.stopHeart;
  return PsychokineticEffect.illusion;
}

/// Rolls the table — `random(espLevel) + 1`.
///
/// So the ceiling rises with the caster's ESP level: below 11 they can
/// only ever strike, and the outright-kill effects need level 11 and up.
///
/// **`random(0)` throws in Dart** where C's returned 0, so an ESP level
/// of 0 is floored to a roll of 1 rather than crashing.
int rollPsychokinesis({required int espLevel, required BattleRng rng}) =>
    espLevel <= 0 ? 1 : rng.next(espLevel) + 1;

/// Damage for the two striking effects.
int psychokineticDamage(int roll) => roll <= 6 ? roll * 10 : roll * 5;

/// The roll ranges for the effects that have to get past resistance.
///
/// Each is `random(resistRange) < resistance` to be blocked, then
/// `random(accuracyRange) > accuracyEsp` to miss. **The failure branches
/// still do something** — see [psychokineticConsolation].
({int resistRange, int accuracyRange}) psychokineticRolls(
  PsychokineticEffect effect,
) => switch (effect) {
  PsychokineticEffect.terrify => (resistRange: 40, accuracyRange: 60),
  PsychokineticEffect.poison => (resistRange: 100, accuracyRange: 40),
  PsychokineticEffect.stopHeart => (resistRange: 40, accuracyRange: 80),
  PsychokineticEffect.illusion => (resistRange: 40, accuracyRange: 30),
  _ => (resistRange: 0, accuracyRange: 0),
};

/// What a failed roll leaves behind.
enum PsychokineticConsolation {
  /// Nothing.
  none,

  /// Resistance drops by 5.
  resistanceDown,

  /// Endurance drops by 5.
  enduranceDown,

  /// Agility drops by 5.
  agilityDown,

  /// Ten hit points, or a collapse if it had fewer.
  chipDamage,
}

/// The original does not simply return on a failure — each effect leaves
/// a smaller mark. That is what keeps a bad roll from being a wasted
/// turn.
PsychokineticConsolation psychokineticConsolation(
  PsychokineticEffect effect, {
  required bool resisted,
}) => switch (effect) {
  PsychokineticEffect.terrify =>
    resisted
        ? PsychokineticConsolation.resistanceDown
        : PsychokineticConsolation.enduranceDown,
  PsychokineticEffect.stopHeart =>
    resisted
        ? PsychokineticConsolation.resistanceDown
        : PsychokineticConsolation.chipDamage,
  PsychokineticEffect.illusion =>
    resisted
        ? PsychokineticConsolation.agilityDown
        : PsychokineticConsolation.none,
  _ => PsychokineticConsolation.none,
};
