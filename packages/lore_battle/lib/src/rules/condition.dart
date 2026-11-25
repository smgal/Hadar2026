import 'rng.dart';

/// How a combatant is doing, worst first (ch.7.7): 죽은 상태 > 의식 불명
/// > 중독 > 좋음.
enum Condition { good, poisoned, unconscious, dead }

/// Reads a condition off the three counters.
Condition conditionOf({
  required int hp,
  required int poison,
  required int unconscious,
  required int dead,
}) {
  if (dead > 0) return Condition.dead;
  if (unconscious > 0 || hp <= 0) return Condition.unconscious;
  if (poison > 0) return Condition.poisoned;
  return Condition.good;
}

/// How much punishment an unconscious **party member** absorbs before
/// dying — `endurance × level` (ch.7.7).
///
/// The original used ten times this for poison taken in battle
/// (appendix A #11); the intended rule is one threshold everywhere, so
/// there is one function.
///
/// The floor of 1 keeps an endurance-0 member from dying to the very
/// blow that dropped them.
int unconsciousDeathThreshold({required int endurance, required int level}) {
  final threshold = endurance * level;
  return threshold < 1 ? 1 : threshold;
}

/// Lowers a stat by [amount], never past [floor].
///
/// Every reduction the special spells and ESP make goes through here.
/// The original subtracted from unsigned bytes, so a resistance of 5
/// minus 10 came out as 251 — very nearly immune (appendix A #37).
int reduceStat(int value, int amount, {int floor = 0}) {
  final next = value - amount;
  return next < floor ? floor : next;
}

/// What a change to a party member's vitals did.
enum VitalsOutcome {
  /// Still standing.
  none,

  /// Hit points reached zero: unconscious now.
  collapsed,

  /// Already unconscious; the counter grew and they are still alive.
  deepened,

  /// Already unconscious, and the counter passed the threshold.
  died,

  /// Already dead; the death counter grew (which is what a later
  /// revival is priced by).
  alreadyDead,
}

/// The result of damage to a party member.
class VitalsChange {
  const VitalsChange({
    required this.hp,
    required this.unconscious,
    required this.dead,
    required this.outcome,
  });

  final int hp;
  final int unconscious;
  final int dead;
  final VitalsOutcome outcome;
}

/// Damage to a party member — ch.7.7 and ch.8.6.
///
/// ```
/// dead         -> the death counter takes it
/// unconscious  -> the unconscious counter takes it; past the threshold, dead
/// otherwise    -> hit points take it; at zero, unconscious
/// ```
///
/// The counters are cumulative on purpose: waking someone costs ten
/// magic points per point of unconsciousness and raising them thirty
/// per point of death (ch.9.4), so how hard a fallen member keeps being
/// hit is what their rescue costs.
///
/// [deadCap] bounds the death counter for sources that have a bound —
/// battle poison stops adding at 10000. Enemy blows have none.
VitalsChange applyMemberDamage({
  required int hp,
  required int unconscious,
  required int dead,
  required int amount,
  required int deathThreshold,
  int? deadCap,
}) {
  if (dead > 0) {
    final grows = deadCap == null || dead < deadCap;
    return VitalsChange(
      hp: hp,
      unconscious: unconscious,
      dead: grows ? dead + amount : dead,
      outcome: VitalsOutcome.alreadyDead,
    );
  }
  if (unconscious > 0) {
    final piled = unconscious + amount;
    final died = piled > deathThreshold;
    return VitalsChange(
      hp: 0,
      unconscious: piled,
      dead: died ? 1 : 0,
      outcome: died ? VitalsOutcome.died : VitalsOutcome.deepened,
    );
  }
  final next = hp - amount;
  if (next <= 0) {
    return VitalsChange(
      hp: 0,
      unconscious: 1,
      dead: 0,
      outcome: VitalsOutcome.collapsed,
    );
  }
  return VitalsChange(
    hp: next,
    unconscious: 0,
    dead: 0,
    outcome: VitalsOutcome.none,
  );
}

/// Where battle poison stops feeding the death counter (ch.7.7).
const int battlePoisonDeadCap = 10000;

/// What an enemy's poison takes each round, by episode.
///
/// 50 in Parts 2 and 3, 1 in Part 1 (appendix E.11) — Part 1's enemies
/// have a tenth of the hit points, and fifty a round would finish most
/// of that table in one.
int enemyPoisonTick(int episode) => episode == 1 ? 1 : 50;

/// How many hit points one point of `endurance × level` is worth to an
/// enemy: 10 in Parts 2 and 3, 1 in Part 1, as each part's document
/// states its formula.
int enemyHpScale(int episode) => episode == 1 ? 1 : 10;

/// An enemy's hit point ceiling. Reads the **live** numbers, so the
/// spell that lowers its level lowers this too (ch.9.5).
int enemyMaxHp({
  required int endurance,
  required int level,
  required int episode,
}) {
  final hp = endurance * level * enemyHpScale(episode);
  return hp < 1 ? 1 : hp;
}

/// `base ± spread`, uniform. Draws nothing when [spread] is zero, so a
/// fixed stat does not shift the sequence.
int rollSpread(int base, int spread, BattleRng rng) =>
    spread <= 0 ? base : base + rng.next(spread * 2 + 1) - spread;
