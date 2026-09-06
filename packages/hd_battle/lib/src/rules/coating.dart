import '../contract/battle_event.dart';
import 'affinity.dart';
import 'rng.dart';

/// Weapon coatings (B6-03).
///
/// ## What this is
///
/// B5-06 gave physical attacks an element — the weapon's method, slash or
/// pierce or blunt, which the weapon is born with and cannot change. A
/// coating is something laid **on top** of that for a few rounds: poison
/// on the edge, a paralytic, oil set alight.
///
/// Two ways to get one, same effect: the poison spell (13) for a caster,
/// or a vial from the pack for anyone (`battle_item.dart`). That is the
/// point — B2-06 gave the magicless something to do with items, and this
/// gives them a second thing.
///
/// ## Three rounds
///
/// A fight runs three to four rounds (appendix W). One round would make
/// the coating turn a waste; the whole fight would make not coating a
/// mistake. Three trades the one turn spent applying it for most of the
/// rest of the fight — the exchange has to be a real one.
const int coatingRounds = 3;

/// One coating on one weapon, counting down.
class WeaponCoating {
  WeaponCoating(this.kind) : rounds = coatingRounds;

  final Coating kind;

  /// Rounds left, including the current one.
  int rounds;
}

/// The element a fire-coated blow goes through the chart with.
///
/// Only fire changes the element; poison and paralysis leave the blow's
/// own method in place and add their effect after the hit lands. The
/// chart is `affinity.dart`'s — no new table.
Element? coatingElement(Coating kind) => switch (kind) {
  Coating.fire => Element.fire,
  Coating.poison || Coating.paralysis => null,
};

/// How much poison one poisoned hit lays on. The same unit the poison
/// spell stacks (`castDebuff` case 13: `poison + 1`).
const int coatingPoisonPerHit = 1;

/// Chance a paralytic hit actually stuns, out of 100.
///
/// Every hit landing a stun would let one coated fighter hold an enemy
/// out of the fight indefinitely; none would make the vial worthless.
/// Half, before resistance, so that against ordinary flesh roughly every
/// other hit costs the target its turn.
const int paralysisChancePercent = 50;

/// Whether a poison or paralysis coating takes hold on a hit.
///
/// Resistance is the same gate the poison spell uses —
/// `rand(100) < resistance` shrugs it off — so the physically immune
/// (`resistance >= 80`, B5-05) are nearly immune to coatings too.
/// Paralysis additionally has to pass its own chance.
bool coatingTakesHold({
  required Coating kind,
  required int resistance,
  required BattleRng rng,
}) {
  if (rng.next(100) < resistance) return false;
  if (kind == Coating.paralysis) {
    return rng.next(100) < paralysisChancePercent;
  }
  return true;
}

/// Fire damage a thrown fire vial does to one enemy, before the chart.
///
/// Between the fire crystal (40) and a level-1 sword swing (~10): a vial
/// is a consumable, so it should beat a swing, and it should not make the
/// crystal pointless. Poison and paralysis vials do no damage when thrown
/// — they apply their effect once, the same way one coated hit would.
const int vialThrowDamage = 30;

/// Spell points the coating spell (13) costs — unchanged from its life
/// as a special spell (`debuffSpells[13].cost`).
const int coatingSpellCost = 10;
