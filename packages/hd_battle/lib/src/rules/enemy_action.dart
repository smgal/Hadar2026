import 'physical.dart';
import 'rng.dart';

/// What an enemy does on its turn.
enum EnemyAttackKind { physical, special }

/// Enemy turn rules, ported from `battle.dart` `_enemyAttack`.

/// Formula 10 — `battle.dart:504`. Index into the list of conscious
/// party members, not a party slot.
int pickTargetIndex({required int candidateCount, required BattleRng rng}) =>
    rng.next(candidateCount);

/// Formula 11 — `battle.dart:507-510`, short-circuits included.
///
/// The original wrote it as a condition with an **empty** then-branch:
///
/// ```dart
/// if ((e.special > 0 || e.castLevel > 0) &&
///     (Random().nextInt(e.accuracy[0] * 1000 + 1) >
///         Random().nextInt(e.accuracy[1] * 1000 + 1)) &&
///     e.strength > 0) {
///   // Physical preferred by roll
/// } else {
///   if (e.castLevel > 0 || e.special > 0) { ...magic...; return; }
/// }
/// ```
///
/// Two things here are load-bearing and easy to lose in a rewrite:
///
/// * An enemy with no special and no cast level **draws no numbers at
///   all** — `&&` short-circuits before the rolls. Reordering this would
///   shift every later draw in the battle.
/// * An enemy that wins the roll but has zero strength falls into the
///   `else`, so it uses its special after all.
EnemyAttackKind chooseEnemyAttack({
  required int special,
  required int castLevel,
  required int strength,
  required int accuracyPhysical,
  required int accuracyMagical,
  required BattleRng rng,
}) {
  final canUseSpecial = special > 0 || castLevel > 0;
  if (canUseSpecial &&
      (rng.next(accuracyPhysical * 1000 + 1) >
          rng.next(accuracyMagical * 1000 + 1)) &&
      strength > 0) {
    return EnemyAttackKind.physical;
  }
  if (castLevel > 0 || special > 0) return EnemyAttackKind.special;
  return EnemyAttackKind.physical;
}

/// Formula 12 — `battle.dart:518`. One generic number for every magic
/// and special ability an enemy has.
int enemySpellDamage({required int enemyLevel, required BattleRng rng}) =>
    enemyLevel * 5 + rng.next(10);

/// Formula 13 — `battle.dart:533`.
///
/// The party's resistance is rolled against 50 here, while an enemy's is
/// rolled against 100 in `enemyResistsAttack` (physical.dart). That
/// asymmetry is the
/// original's, not a porting slip: a party member with resistance 25
/// stops half of all attacks.
bool memberResistsAttack({
  required int memberResistance,
  required BattleRng rng,
}) => rng.next(50) < memberResistance;

/// Formulas 14 and 15 — `battle.dart:543-548`, in that order.
///
/// ```dart
/// int damage = (e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10;
/// damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10;
/// ```
///
/// The second line is where worn equipment reaches the rules: the RPG
/// hands over `baseAc + equipmentAc` already summed. `powOfShield` and
/// `powOfArmor` are read nowhere — see appendix H-1 (corrected) and
/// B2-08.
/// B5-05 swapped the `(random(10)+1)/10` spread for [graze], so both
/// sides now vary the same way and `agility` is what moves it.
int enemyPhysicalDamage({
  required int enemyStrength,
  required int enemyLevel,
  required int memberAc,
  required int memberLevelPhysical,
  required BattleRng rng,
  int graze = 100,
}) {
  var damage = applyGraze(enemyStrength * enemyLevel, graze);
  damage -= (memberAc * memberLevelPhysical * (rng.next(10) + 1)) ~/ 10;
  return damage;
}
