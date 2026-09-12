import 'mitigation.dart';
import 'rng.dart';

/// Physical attack rules, ported unchanged from `battle.dart`
/// `_executeAttack`. Integer division stays `~/` and every random range
/// stays exactly as it was.

/// Formula 1 — `battle.dart:450`.
///
/// Note the asymmetry the original had: a roll *equal* to the accuracy
/// hits, so accuracy 19 or more never misses on a `[0, 20)` draw.
bool physicalAttackMisses({
  required int accuracyPhysical,
  required BattleRng rng,
}) => rng.next(20) > accuracyPhysical;

/// Formula 2 — `battle.dart:455`. The enemy stops the blow outright.
bool enemyResistsAttack({
  required int enemyResistance,
  required BattleRng rng,
}) => rng.next(100) < enemyResistance;

/// Formulas 3, 4 and 5 — `battle.dart:462-470`, in that order.
///
/// ```dart
/// int damage = (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;
/// damage -= (damage * Random().nextInt(50)) ~/ 100;
/// damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10;
/// ```
///
/// May come out zero or negative; the caller treats that as absorbed.
/// Two draws, always both taken.
/// B5-05 replaced the `random(50)` spread with [graze] — one source of
/// variance instead of two. Pass 100 to leave a figure ungrazed.
int physicalDamage({
  required int strength,
  required int powOfWeapon,
  required int levelPhysical,
  required int enemyAc,
  required int enemyLevel,
  required BattleRng rng,
  int graze = 100,
}) {
  var damage = (strength * powOfWeapon * levelPhysical) ~/ 20;
  damage = applyGraze(damage, graze);
  damage -= (enemyAc * enemyLevel * (rng.next(10) + 1)) ~/ 10;
  return damage;
}

/// Formula 6 — `battle.dart:446` and `:494`, the same expression in both
/// places. Awarded to the attacker alone.
int killExperience({required int enemyLevel}) => enemyLevel * 10;

// --- B5-05: the damage chain, rebuilt -------------------------------

/// Whether a creature simply cannot be hurt this way.
///
/// ## Why this replaces the resistance roll
///
/// `enemyResistsAttack` and `enemyResistsMagic` are the same expression
/// reading the same stat — `random(100) < resistance`. Physical attacks
/// were borrowing the magic resistance, and the outcome was a line of
/// text and no change to anything, which is the deadest result a turn
/// can have.
///
/// The data says something different from the implementation. Of the 75
/// rows, **38 have resistance 0** — the roll never fires for over half
/// the roster. Six sit at 80-100 (Sprite, Death Skull, Ancient Evil,
/// Lord Ahn, Panzer Viper, Neo-Necromancer) and **two are 255**
/// (Stheno and Euryale), where `random(100) < 255` is always true:
/// total physical immunity, with `ac` at 255 to match.
///
/// So the original's own numbers describe immunity as a property of
/// what a creature *is*, and the probabilistic roll was just how it got
/// implemented. Reading the data the way it was written removes the
/// whiff for everyone and keeps the puzzle for the few — appendix W-4.
enum Immunity {
  /// Nothing special. Most of the roster.
  none,

  /// Weapons pass through it. Bring magic.
  physical,

  /// Spells slide off it. Bring steel.
  magical,
}

/// How the original's `resistance` column reads as an immunity.
///
/// The threshold sits at 80 because that is where the table's own
/// clusters fall: 0-70 is a spread of ordinary creatures, and 80-255 is
/// the handful the original clearly meant to be unhittable.
Immunity immunityFor({required int resistance}) {
  if (resistance < 80) return Immunity.none;
  return Immunity.physical;
}

/// How much of a blow actually lands (B5-05).
///
/// ## One source of variance, not two
///
/// The party's damage already had a spread — `damage -= damage *
/// random(50) / 100`, keeping 51-100%. The enemy's had a wider one
/// built into its formula: `strength * level * (random(10) + 1) / 10`,
/// keeping 10-100%. Two different shapes for the same idea, and the
/// party's was the narrower.
///
/// This replaces the party's roll rather than stacking on top of it.
/// Measured, stacking drops the mean from 7.18 to 3.09 against an Orc —
/// physical attacks were already the weak half of the game (appendix
/// U-3) and would not survive it. Replacing lands at 3.90, which is why
/// [physicalPowerScale] exists.
///
/// The multiplier centres on the accuracy-versus-evasion difference, so
/// `agility` finally does something outside initiative and the escape
/// formula — appendix W-6 had it down to two readers.
///
/// Returned as a percentage, 0 to 100. **Zero is reachable**: a clean
/// dodge has to stay possible or an agile character is just a slower
/// one.
/// How far the accuracy-versus-evasion difference can shift the roll.
///
/// Without a cap a high-accuracy creature lands its ceiling every time
/// — measured, the Black Knight went from an average of about half its
/// maximum to four fifths of it, which is not a graze mechanic, it is a
/// damage buff wearing one.
const int grazeEdgeCap = 30;

int grazeScale({
  required int accuracy,
  required int evasion,
  required BattleRng rng,
}) {
  // Clamped so no pairing of numbers turns the roll into a constant.
  // At the extremes this shifts the average by a quarter either way,
  // which is enough to feel and not enough to erase the roll.
  var edge = accuracy - evasion;
  if (edge > grazeEdgeCap) edge = grazeEdgeCap;
  if (edge < -grazeEdgeCap) edge = -grazeEdgeCap;
  final roll = rng.next(100) + edge;
  if (roll <= 0) return 0;
  if (roll >= 100) return 100;
  return roll;
}

/// What the defender contributes to the graze roll.
///
/// Agility with a little luck, plus the shield.
///
/// ## Why the shield folds in here
///
/// B2-08 gave the shield its own roll before damage — block or not.
/// Once the graze multiplier exists that is the same idea twice: a
/// shield block *is* a graze of zero. Leaving both in place would give
/// the game four defensive layers (immunity, evasion, shield, armour)
/// with two of them indistinguishable to whoever is reading the screen.
///
/// So the shield moves the graze roll instead of pre-empting it, and a
/// graze that comes out at zero is reported as a block when there is a
/// shield to credit. One roll, one idea, and `powOfShield` still does
/// what B2-08 brought it back to life for.
int evasionOf({
  required int agility,
  required int luck,
  int shieldBlock = 0,
  int styleBonus = 0,
}) {
  final shield = shieldBlock > maxShieldBlock ? maxShieldBlock : shieldBlock;
  return agility ~/ 2 + luck ~/ 4 + shield ~/ 2 + styleBonus;
}

/// Applies [grazeScale] to a damage figure.
int applyGraze(int damage, int scale) => damage * scale ~/ 100;

/// How much the base physical formula was lifted (B5-05).
///
/// Replacing the old variance roll with the graze multiplier costs
/// roughly half the average — measured, 7.18 down to 3.90 for the
/// starting attacker against an Orc. Doubling puts it back at 8.41 with
/// a wider spread, which is the point: the same average, but a bad roll
/// and a good roll now feel different.
///
/// It does nothing about magic outscaling weapons (appendix U-3); that
/// needs the spell side, and this is not it.
const int physicalPowerScale = 2;
