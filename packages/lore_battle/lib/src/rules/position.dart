import 'affinity.dart';
import 'rng.dart';

/// Where everyone stands, and what that costs (B5-01).
///
/// ## Two integers, not coordinates
///
/// Neither reference tree has any notion of position. This is designed,
/// and the shape was chosen so it stays a Dragon-Quest battle rather
/// than becoming a grid game:
///
/// * every combatant carries a **rank**, 1 (front) to 3 (back), within
///   its own side
/// * both sides share one **gap**, 0 to 2
///
/// ```
/// distance(a, e) = gap + (a.rank - 1) + (e.rank - 1)
/// ```
///
/// "We advance" and "they advance" are therefore the *same event* — the
/// gap shrinks. What that costs is symmetric too, which is what keeps
/// closing from being a free win.
///
/// What this cannot express, deliberately: flanking, individual
/// positions inside a rank, singling one enemy out to push.

/// Front rank.
const int frontRank = 1;

/// Back rank. Nothing can retreat past it — that is being cornered.
const int backRank = 3;

/// The widest the two sides can stand apart.
///
/// Real fights run three to four rounds (appendix W-1), so a gap that
/// takes two rounds to close would spend half the battle walking.
/// Encounters should start at 0 or 1; 2 is for spotting them first.
const int maxGap = 2;

int clampRank(int rank) =>
    rank < frontRank ? frontRank : (rank > backRank ? backRank : rank);

int clampGap(int gap) => gap < 0 ? 0 : (gap > maxGap ? maxGap : gap);

/// How far apart two combatants on opposite sides are.
int distanceBetween({
  required int gap,
  required int attackerRank,
  required int targetRank,
}) => gap + (attackerRank - 1) + (targetRank - 1);

/// What being out of reach costs.
///
/// ## Never a wasted turn
///
/// The one invariant of B5: **out of reach is a penalty, not a void.**
/// Accuracy drops and a front-rank defender may take the blow instead,
/// but the turn is never simply lost. Four different things move
/// combatants around — formation orders, charges, knockback and the
/// dodge-back passive — and two of them cannot be predicted when the
/// command is given. If a moved target could void an attack outright,
/// this would fail the same way Dragon Quest 1 did when the chosen
/// target died before your turn came up.
class ReachPenalty {
  const ReachPenalty({required this.accuracy, required this.interception});

  /// Subtracted from the attacker's accuracy.
  final int accuracy;

  /// Percent chance a nearer defender takes the hit instead.
  final int interception;

  static const ReachPenalty none = ReachPenalty(accuracy: 0, interception: 0);

  bool get isNone => accuracy == 0 && interception == 0;
}

/// The penalty for being [shortBy] steps out of reach.
///
/// Nothing beyond two steps gets worse; by then interception is over
/// half and the accuracy loss is already decisive.
ReachPenalty reachPenalty(int shortBy) {
  if (shortBy <= 0) return ReachPenalty.none;
  if (shortBy == 1) return const ReachPenalty(accuracy: 6, interception: 30);
  return const ReachPenalty(accuracy: 14, interception: 55);
}

/// Whether a nearer defender steps in front of the blow.
bool intercepts({required ReachPenalty penalty, required BattleRng rng}) {
  if (penalty.interception <= 0) return false;
  return rng.next(100) < penalty.interception;
}

/// Ranks that actually hold ground, lowest first.
///
/// A rank nobody stands in is not a rank. This is what lets a side be
/// "the front" without tracking who is where — and what makes an empty
/// front rank an invitation for the other side to walk in.
List<int> occupiedRanks(Iterable<int> ranks) {
  final seen = ranks.toSet().toList()..sort();
  return seen;
}

/// The rank a side is actually fronting with, or [backRank] if nobody
/// is standing.
int frontOf(Iterable<int> ranks) {
  final occupied = occupiedRanks(ranks);
  return occupied.isEmpty ? backRank : occupied.first;
}

/// Whether anyone can still fall back.
bool canRetreat(int rank) => rank < backRank;

/// Whether there is a rank in front to step into.
bool canAdvance(int rank) => rank > frontRank;

/// A side's formation order for the round.
enum FormationOrder {
  /// Stand where you are.
  hold,

  /// Close the gap by one.
  advance,

  /// Open the gap by one.
  retreat,
}

/// Resolves both sides' formation orders at once (B5-03).
///
/// They are added, not contested: the party advancing while the enemy
/// retreats leaves the gap where it was, and the screen can say so.
/// No dice, and both sides paid a turn for it.
int resolveFormation({
  required int gap,
  required FormationOrder party,
  required FormationOrder enemy,
}) {
  var next = gap;
  next += switch (party) {
    FormationOrder.advance => -1,
    FormationOrder.retreat => 1,
    FormationOrder.hold => 0,
  };
  next += switch (enemy) {
    FormationOrder.advance => -1,
    FormationOrder.retreat => 1,
    FormationOrder.hold => 0,
  };
  return clampGap(next);
}

/// Where a creature stands when the encounter does not say (B5-01).
///
/// Reads what it is, not a hand-written formation: the 75-row table is
/// generated from the original binary and nobody is going to place all
/// of them by hand. Casters keep their distance, brutes lead, and
/// anything that can do both leads anyway.
///
/// An encounter that cares overrides it with `BattleSetup.enemyRanks`.
int defaultEnemyRank({
  required int strength,
  required int castLevel,
  required int specialCastLevel,
  required int agility,
}) {
  // A commander that summons and abducts hangs back the furthest.
  if (specialCastLevel > 0) return backRank;
  // Something with no arms at all is not going to lead a line.
  if (strength <= 0) return castLevel > 0 ? backRank : 2;
  if (castLevel >= 4) return backRank;
  if (castLevel > 0) return 2;
  // Fast and unarmoured skirmishers dart in front.
  return frontRank;
}

/// How far apart an encounter opens when nobody says (B5-01).
///
/// The party keeps its distance only when it is plainly the stronger
/// side; otherwise whatever it ran into is already on top of it. That
/// asymmetry is deliberate — closing is easy and opening is hard, in
/// this game as in every other one that models a line.
///
/// Levels weigh more than agility because a level gap is what the
/// player feels as "we can take these", and agility is already doing
/// work in initiative and evasion.
///
/// An encounter that wants a specific opening sets `initialGap` and
/// this is never consulted — an ambush is 0, spotting them across a
/// hall is 2.
int openingGap({
  required Iterable<int> partyAgility,
  required Iterable<int> partyLevel,
  required Iterable<int> enemyAgility,
  required Iterable<int> enemyLevel,
}) {
  int mean(Iterable<int> xs) {
    if (xs.isEmpty) return 0;
    return xs.reduce((a, b) => a + b) ~/ xs.length;
  }

  final score =
      (mean(partyAgility) - mean(enemyAgility)) +
      (mean(partyLevel) - mean(enemyLevel)) * 2;
  if (score >= 20) return 2;
  if (score >= 10) return 1;
  return 0;
}

/// Who an enemy swings at, weighted by rank (B5-04).
///
/// ## The problem this fixes
///
/// The inherited battle drew a party member uniformly
/// (`pickTargetIndex`). With every member equally likely to be hit
/// there is no front line, no way to shelter a caster, and **the party
/// order screen has no effect on a battle at all**. Attack choices
/// being shallow is a smaller problem than the defensive side having
/// literally no decision in it.
///
/// ## How it works
///
/// Weight falls off with **distance**, measured against the nearest
/// candidate. Being within reach is not the same as being equally easy
/// to get at: the people in front are still in the way.
///
/// How steeply it falls off depends on the weapon. Something with a
/// long weapon picks its target almost freely; something swinging a
/// club takes whoever is nearest. That is [falloffForReach].
///
/// A floor keeps the back rank from being a hiding place. Put the whole
/// party back there and the weights flatten out on their own — nobody
/// is in front of anybody, so there is nothing to hide behind.

/// How much weight one extra step of distance costs, by reach.
///
/// A pike reaches past the front line; a mace does not.
int falloffForReach(int reach) {
  final value = 55 - reach * 10;
  return value < 15 ? 15 : value;
}

/// The floor a candidate's weight never drops to below.
const int rankWeightFloor = 20;

/// Relative weights for a list of candidate ranks.
///
/// Exposed for tests and for a view that wants to explain the odds.
List<int> rankWeights({
  required List<int> candidateRanks,
  required int attackerRank,
  required int gap,
  required int reach,
}) {
  if (candidateRanks.isEmpty) return const [];
  final distances = [
    for (final rank in candidateRanks)
      distanceBetween(gap: gap, attackerRank: attackerRank, targetRank: rank),
  ];
  var nearest = distances.first;
  for (final d in distances) {
    if (d < nearest) nearest = d;
  }
  final falloff = falloffForReach(reach);
  return [
    for (final d in distances)
      () {
        final weight = 100 - (d - nearest) * falloff;
        return weight < rankWeightFloor ? rankWeightFloor : weight;
      }(),
  ];
}

/// Picks an index into [candidateRanks], weighted by [rankWeights].
///
/// Draws exactly one number whatever the weights are, so adding this
/// does not shift the rest of a seeded battle by a variable amount.
int pickByRank({
  required List<int> candidateRanks,
  required int attackerRank,
  required int gap,
  required int reach,
  required BattleRng rng,
}) {
  final weights = rankWeights(
    candidateRanks: candidateRanks,
    attackerRank: attackerRank,
    gap: gap,
    reach: reach,
  );
  var total = 0;
  for (final w in weights) {
    total += w;
  }
  if (total <= 0) return rng.next(candidateRanks.length);
  var roll = rng.next(total);
  for (var i = 0; i < weights.length; i++) {
    roll -= weights[i];
    if (roll < 0) return i;
  }
  return weights.length - 1;
}

// --- B5-07: being pushed around --------------------------------------

/// What happens when something is driven back a rank.
enum PushResult {
  /// It gave ground.
  moved,

  /// There was nowhere left to go. Being cornered costs instead.
  cornered,
}

/// Extra damage for having nowhere to fall back to.
///
/// A knockback that does nothing against the back rank would make the
/// whole mechanic fizzle exactly when the fight has gone furthest —
/// against the boss standing at the back. Cornering has to be worth
/// something.
const int corneredBonusPercent = 50;

/// Drives a combatant back one rank if it can go.
PushResult pushBack(int rank) =>
    canRetreat(rank) ? PushResult.moved : PushResult.cornered;

/// Whether a blow drives its target back.
///
/// **Only weight does.** Letting every weakness push would move the
/// line several times a round — 43 of the 75 rows are ordinary flesh
/// and weak to slashing, so the commonest attack in the game would also
/// be the commonest shove, and position would stop being something a
/// player can plan around.
///
/// Restricting it to blunt keeps it rare enough to read, gives maces
/// and the shafts of polearms a job nothing else does, and is the one
/// reading that needs no explaining: a club knocks you backwards, a
/// sword cut does not.
bool knocksBack(Element element, {required bool hitWeakness}) =>
    hitWeakness && element == Element.blunt;

/// How long a combatant stays visibly off balance after being pushed.
///
/// ## Why this is a state and not a sequence
///
/// Initiative is rolled per round (B2-05), so "the attack right after a
/// knockback is stronger" would be a lottery: whether the follow-up
/// lands at all depends on a die nobody controls. Marking the target
/// instead makes the synergy independent of who moves when — the same
/// trick as Persona's downed enemies or Darkest Dungeon's marks.
///
/// Cleared at the top of the pushed side's next round, so it is worth
/// one round of follow-up and no more.
const int staggerBonusPercent = 30;

/// What a side wants the gap to be (B5-03).
///
/// Reach decides: a side that cannot reach wants to close, and a side
/// that can reach further than the other wants to stay out. Both spend
/// a turn to say so and the two orders are added, so matching a move
/// costs the same as making one.
FormationOrder formationWant({
  required int myReach,
  required int theirReach,
  required int gap,
}) {
  if (myReach < theirReach && gap > 0) return FormationOrder.advance;
  if (myReach > theirReach && gap < maxGap) return FormationOrder.retreat;
  // Even reach: close, because standing off achieves nothing and the
  // fight has three or four rounds to happen in.
  return gap > 0 ? FormationOrder.advance : FormationOrder.hold;
}

/// How much better a braced defender's shield gets (B5-03).
///
/// Big for the first blow, much less for the second in the same round.
/// Without the falloff a braced tank is simply unhittable, and a tank
/// that cannot be worn down is not a decision either.
int braceBonus(int hitsThisRound) => hitsThisRound == 0 ? 45 : 12;
