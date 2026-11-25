import 'rng.dart';

/// Weapon blows, both ways — ch.8.5 and ch.8.6.
///
/// One function per line of the design document's numbered steps, so a
/// test can pin each step against every possible roll. `rand(N)` in the
/// document is [BattleRng.next]. Integer division throughout.
///
/// **Draw order is part of the contract.** The steps are called in the
/// document's order and each takes exactly the draws listed here.

// --- a member strikes -------------------------------------------------

/// Step 3 — `rand(20) > accuracy` misses.
///
/// A roll *equal* to the accuracy hits, so accuracy 19 never misses.
/// The position layer lowers [accuracy] before it gets here when the
/// blow has to stretch.
bool memberAttackMisses({required int accuracy, required BattleRng rng}) =>
    rng.next(20) > accuracy;

/// Step 4 — base damage.
///
/// Monks and assassins ([fixedCoefficient]) ignore the weapon and hit
/// with `strength × skill × 5`; everyone else with
/// `strength × weaponPower × skill ÷ 10`.
int memberBaseDamage({
  required int strength,
  required int weaponPower,
  required int skill,
  required bool fixedCoefficient,
}) => fixedCoefficient
    ? strength * skill * 5
    : strength * weaponPower * skill ~/ 10;

/// The assistant member's automatic attack —
/// `strength × weaponPower × level ÷ 2`. Everything after the base
/// (deviation, resistance, defence) is the same as a member's blow.
int assistantBaseDamage({
  required int strength,
  required int weaponPower,
  required int level,
}) => strength * weaponPower * level ~/ 2;

/// Step 5 — `damage − damage × rand(50) ÷ 100`, keeping 51..100%.
int applyDeviation(int damage, BattleRng rng) =>
    damage - damage * rng.next(50) ~/ 100;

/// Step 6 — `rand(100) < physical resistance` stops the blow outright.
/// A resistance of 100 or more always does.
bool enemyBlocksBlow({
  required int physicalResistance,
  required BattleRng rng,
}) => rng.next(100) < physicalResistance;

/// Step 7 — what the enemy's armour takes off: `ac × level × (1..10)`.
///
/// The same term comes off attack magic (ch.8.5), so both call this.
int enemyDefence({
  required int ac,
  required int level,
  required BattleRng rng,
}) => ac * level * (rng.next(10) + 1);

// --- an enemy strikes -------------------------------------------------

/// `rand(20) >= accuracy` misses — note `>=`, where the member's own
/// roll is `>`. At the same accuracy an enemy misses one draw more
/// often.
bool enemyAttackMisses({
  required int accuracyPhysical,
  required BattleRng rng,
}) => rng.next(20) >= accuracyPhysical;

/// `strength × level × (1..10) ÷ 5`.
int enemyWeaponDamage({
  required int strength,
  required int level,
  required BattleRng rng,
}) => strength * level * (rng.next(10) + 1) ~/ 5;

/// The shield — `rand(550) < shield skill × shield power` stops the
/// blow whole (ch.8.6, ch.10.3).
///
/// Fighter family with a shield only; the caller decides whether there
/// is anything to roll for. [bonus] is the position layer's: a member
/// who braced this round adds to the threshold.
bool shieldBlocks({
  required int shieldSkill,
  required int shieldPower,
  required BattleRng rng,
  int bonus = 0,
}) => rng.next(shieldBlockRange) < shieldSkill * shieldPower + bonus;

/// The shield roll's range. Skill 100 with the best shield (5) is 500
/// of it — ten blows in eleven.
const int shieldBlockRange = 550;

/// What a member's armour takes off: `ac × level × (1..10) ÷ 10`.
/// A tenth of what the same numbers are worth to an enemy.
int memberDefence({
  required int ac,
  required int level,
  required BattleRng rng,
}) => ac * level * (rng.next(10) + 1) ~/ 10;

/// The four ways a weapon finishes an unconscious enemy — which line
/// the view prints (appendix E.7). The model only draws the number.
const int finishingFlavours = 4;
