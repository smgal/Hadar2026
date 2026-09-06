import 'battle_command.dart';
import 'battle_result_code.dart';

/// Where a damage number came from. The original wrote a different
/// sentence for each (`battle.dart:482` for a weapon hit, `:187` for a
/// spell), so the view needs to know which.
enum DamageSource { physical, spell }

/// Why an attack did nothing. The original had two distinct wordings:
/// the target *stopped* the attack on a resistance roll, or the attack
/// *landed* but the damage came out at zero or less.
enum BlockKind {
  /// Resistance roll succeeded — `battle.dart:455` / `:533`.
  resisted,

  /// Damage reduced to zero or below — `battle.dart:472` / `:550`.
  absorbed,
}

/// Something that happened, as a fact rather than a sentence.
///
/// Events carry no text. Building the sentence, picking the particle and
/// deciding when to pause is the view's work — that split is what lets a
/// console view and a Flutter view share this package unchanged.
sealed class BattleEvent {
  const BattleEvent();
}

// --- Framing --------------------------------------------------------

final class EnemiesAppeared extends BattleEvent {
  const EnemiesAppeared(this.enemyIndices);

  final List<int> enemyIndices;
}

final class RoundStarted extends BattleEvent {
  const RoundStarted(this.round);

  /// 1-based.
  final int round;
}

final class ActionSkipped extends BattleEvent {
  const ActionSkipped(this.slot);

  final int slot;
}

final class BattleEnded extends BattleEvent {
  const BattleEnded(this.code);

  final BattleResultCode code;
}

// --- Party acting ---------------------------------------------------

final class SpellCast extends BattleEvent {
  const SpellCast(this.slot, this.magicId);

  final int slot;
  final int magicId;
}

/// Hit points restored.
final class MemberHealed extends BattleEvent {
  const MemberHealed(this.slot, this.amount);

  final int slot;
  final int amount;
}

/// Poison cleared.
final class MemberCured extends BattleEvent {
  const MemberCured(this.slot);

  final int slot;
}

/// Brought round from a collapse. The accumulator is back to zero and
/// hit points are at least 1 (`rules/cure.dart`).
final class MemberRevived extends BattleEvent {
  const MemberRevived(this.slot);

  final int slot;
}

/// Brought back from the dead — **collapsed, not standing.** A full
/// recovery still needs the wake spell after this.
final class MemberResurrected extends BattleEvent {
  const MemberResurrected(this.slot);

  final int slot;
}

/// The spell ran but nobody needed any of what it does.
///
/// The original could not tell this apart from "the caster was broke":
/// in battle every cure primitive returned silently either way
/// (`m_healOne` and friends only print outside battle).
final class CureHadNoEffect extends BattleEvent {
  const CureHadNoEffect(this.slot, this.magicId);

  final int slot;
  final int magicId;
}

/// The caster's magic or ESP level is too low for the category to offer
/// anything — `magic_system.dart:229-232`.
final class NoSpellAvailable extends BattleEvent {
  const NoSpellAvailable(this.slot, this.action);

  final int slot;
  final BattleAction action;
}

/// The cost check failed — `magic_system.dart:242-256`. The original
/// only ever *checked*; see `spendsCost` in `rules/spellbook.dart`.
final class NotEnoughSpellPoints extends BattleEvent {
  const NotEnoughSpellPoints(this.slot, {required this.usesEsp});

  final int slot;
  final bool usesEsp;
}

final class AttackMissed extends BattleEvent {
  const AttackMissed(this.slot);

  final int slot;
}

/// The blow had to stretch (B5-01).
///
/// The target stood [shortBy] steps further than the weapon reaches.
/// **The turn is not lost** — accuracy drops and a nearer defender may
/// step in, which is the whole point: four different things move
/// combatants around and two of them cannot be foreseen when the
/// command is given, so being out of reach has to degrade an attack
/// rather than void it.
final class AttackStrained extends BattleEvent {
  const AttackStrained(this.slot, this.enemyIndex, this.shortBy);

  final int slot;
  final int enemyIndex;
  final int shortBy;
}

/// The two sides' formation orders resolved (B5-03).
///
/// Both are reported, because "they matched my move" is the readable
/// outcome of a standoff and the screen should be able to say it. The
/// orders are added rather than contested, so there is no die here.
final class FormationResolved extends BattleEvent {
  const FormationResolved({
    required this.from,
    required this.to,
    required this.partyAdvanced,
    required this.partyRetreated,
    required this.enemyAdvanced,
    required this.enemyRetreated,
  });

  final int from;
  final int to;
  final bool partyAdvanced;
  final bool partyRetreated;
  final bool enemyAdvanced;
  final bool enemyRetreated;

  /// Both sides spent a turn and the distance did not move.
  bool get cancelled =>
      from == to &&
      (partyAdvanced || partyRetreated) &&
      (enemyAdvanced || enemyRetreated);
}

/// Someone stepped forward and struck in one action (B5-03).
final class Charged extends BattleEvent {
  const Charged(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

/// Someone stepped forward and set themselves (B5-03).
final class Braced extends BattleEvent {
  const Braced(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

/// A shield turned the attacker away, not the defender (B5-07).
///
/// The obvious reading — a successful block pushes the *blocker* back —
/// fights the brace: standing firm is what a shield is for, and being
/// shoved out of the front rank for doing it well would undo the role.
/// Turning it around makes the shield an answer to being crowded.
final class AttackerShovedBack extends BattleEvent {
  const AttackerShovedBack(this.slot, this.enemyIndex, this.toRank);

  final int slot;
  final int enemyIndex;
  final int toRank;
}

/// Someone gave ground rather than take a killing blow (B5-07).
final class DodgedBack extends BattleEvent {
  const DodgedBack(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

/// Something was driven back a rank (B5-06 · B5-07).
///
/// The reward for hitting a weakness is position, not just damage. In a
/// battle with no press-turn to hand out, more damage is arithmetic;
/// moving the line is an event.
final class EnemyPushedBack extends BattleEvent {
  const EnemyPushedBack(this.enemyIndex, this.toRank);

  final int enemyIndex;
  final int toRank;
}

/// It had nowhere left to fall back to, and paid for it instead.
final class EnemyCornered extends BattleEvent {
  const EnemyCornered(this.enemyIndex, this.extraDamage);

  final int enemyIndex;
  final int extraDamage;
}

/// A party member was driven back a rank.
final class MemberPushedBack extends BattleEvent {
  const MemberPushedBack(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

/// A party member was pinned against the back rank.
final class MemberCornered extends BattleEvent {
  const MemberCornered(this.slot, this.extraDamage);

  final int slot;
  final int extraDamage;
}

/// A nearer enemy took the blow meant for one further back (B5-01).
///
/// This is what makes a boss behind its minions worth clearing a path
/// to, without ever removing it from the target list.
final class AttackIntercepted extends BattleEvent {
  const AttackIntercepted(this.slot, this.intendedIndex, this.actualIndex);

  final int slot;
  final int intendedIndex;
  final int actualIndex;
}

/// An enemy had to stretch to reach its target (B5-01).
final class EnemyAttackStrained extends BattleEvent {
  const EnemyAttackStrained(this.enemyIndex, this.slot, this.shortBy);

  final int enemyIndex;
  final int slot;
  final int shortBy;
}

/// A party member in front took the blow meant for someone behind
/// (B5-01). The front rank earning its name.
final class EnemyAttackIntercepted extends BattleEvent {
  const EnemyAttackIntercepted(
    this.enemyIndex,
    this.intendedSlot,
    this.actualSlot,
  );

  final int enemyIndex;
  final int intendedSlot;
  final int actualSlot;
}

/// A spell went wide. Separate from [AttackMissed] because the original
/// named the target in this one.
final class SpellMissed extends BattleEvent {
  const SpellMissed(this.slot, this.magicId, this.enemyIndex);

  final int slot;
  final int magicId;
  final int enemyIndex;
}

/// One of the special spells (13-18) took a capability away.
final class DebuffApplied extends BattleEvent {
  const DebuffApplied(this.slot, this.magicId, this.enemyIndex, this.detail);

  final int slot;
  final int magicId;
  final int enemyIndex;

  /// Which stat actually moved. 방어 무력화 can hit either armour or
  /// resistance depending on the target, so the view cannot work it out
  /// from the spell id alone.
  final DebuffDetail detail;
}

/// What a debuff changed, for the view to name.
enum DebuffDetail {
  poisonStacked,
  specialRemoved,
  armourLowered,
  resistanceLowered,
  abilityLowered,
  castingLowered,
  castingRemoved,
  superhumanLowered,
  superhumanRemoved,
}

/// A special spell was blocked or went wide.
final class DebuffFailed extends BattleEvent {
  const DebuffFailed(
    this.slot,
    this.magicId,
    this.enemyIndex, {
    required this.resisted,
  });

  final int slot;
  final int magicId;
  final int enemyIndex;

  /// True when the target resisted, false when the cast missed.
  final bool resisted;
}

final class EnemyBlocked extends BattleEvent {
  const EnemyBlocked(
    this.slot,
    this.enemyIndex,
    this.kind, {
    this.source = DamageSource.physical,
  });

  final int slot;
  final int enemyIndex;
  final BlockKind kind;

  /// The original wrote different sentences for a blocked weapon and a
  /// blocked spell.
  final DamageSource source;
}

final class EnemyDamaged extends BattleEvent {
  const EnemyDamaged(
    this.slot,
    this.enemyIndex,
    this.amount,
    this.source, {
    this.whileCollapsed = false,
  });

  final int slot;
  final int enemyIndex;
  final int amount;
  final DamageSource source;

  /// The target was already collapsed, so this went onto the
  /// unconscious accumulator rather than hit points
  /// (`rules/collapse.dart`).
  final bool whileCollapsed;
}

/// The enemy ran out of hit points and stopped acting. **Not dead** —
/// B2-04 made every path two-stage, so this is recoverable and a second
/// blow is what kills (see `rules/collapse.dart`).
final class EnemyCollapsed extends BattleEvent {
  const EnemyCollapsed(this.slot, this.enemyIndex, this.source);

  final int slot;
  final int enemyIndex;
  final DamageSource source;
}

/// The killing blow on an enemy that had already collapsed.
///
/// Reachable since B2-04: when an earlier member of the same round
/// collapses the enemy a later member had already picked, that member
/// finishes it instead of retargeting. The inherited battle had this
/// branch (`battle.dart:437-447`) but nothing could ever reach it
/// (appendix O-3).
final class EnemyFinished extends BattleEvent {
  const EnemyFinished(this.slot, this.enemyIndex);

  final int slot;
  final int enemyIndex;
}

/// The party tries to run (B6-04). [slot] is the leader who gave the
/// order; the roll is one for everyone.
final class EscapeAttempted extends BattleEvent {
  const EscapeAttempted(this.slot, {this.gap = 0});

  final int slot;

  /// The gap between the lines when the attempt was made — what the
  /// view says when it explains why it worked or did not.
  final int gap;
}

/// The party did not get away. **Everyone loses the round** — nobody
/// else acts, the enemies do (B6-04).
final class EscapeFailed extends BattleEvent {
  const EscapeFailed(this.slot);

  final int slot;
}

final class EscapeSucceeded extends BattleEvent {
  const EscapeSucceeded(this.slot);

  final int slot;
}

// --- Enemies acting -------------------------------------------------

final class EnemyPoisonTick extends BattleEvent {
  const EnemyPoisonTick(this.enemyIndex, this.amount);

  final int enemyIndex;
  final int amount;
}

final class EnemyCollapsedFromPoison extends BattleEvent {
  const EnemyCollapsedFromPoison(this.enemyIndex);

  final int enemyIndex;
}

final class EnemyDiedFromPoison extends BattleEvent {
  const EnemyDiedFromPoison(this.enemyIndex);

  final int enemyIndex;
}

/// The enemy is casting. B2-07 replaced the port's one generic line
/// with the real ladder, so this now precedes a specific effect.
final class EnemyUsedSpecial extends BattleEvent {
  const EnemyUsedSpecial(this.enemyIndex);

  final int enemyIndex;
}

/// An enemy patched itself up.
final class EnemyHealedSelf extends BattleEvent {
  const EnemyHealedSelf(this.enemyIndex, this.amount);

  final int enemyIndex;
  final int amount;
}

/// An enemy healed one of its allies.
final class EnemyHealedAlly extends BattleEvent {
  const EnemyHealedAlly(this.enemyIndex, this.targetIndex, this.amount);

  final int enemyIndex;
  final int targetIndex;
  final int amount;
}

/// An enemy brought a fallen ally back. One stage per cast: dead ->
/// collapsed -> standing (`rules/enemy_ai.dart`).
final class EnemyRevivedAlly extends BattleEvent {
  const EnemyRevivedAlly(
    this.enemyIndex,
    this.targetIndex, {
    required this.fromDeath,
  });

  final int enemyIndex;
  final int targetIndex;

  /// True when it undid death, false when it merely woke them.
  final bool fromDeath;
}

/// An enemy ground a party member's armour down. Level-6 casters only.
final class MemberArmourWorn extends BattleEvent {
  const MemberArmourWorn(this.enemyIndex, this.slot);

  final int enemyIndex;
  final int slot;
}

/// A party member's luck saved them from something.
final class MemberLuckSaved extends BattleEvent {
  const MemberLuckSaved(this.slot);

  final int slot;
}

/// An enemy used one of its three innate abilities.
final class EnemyAbilityUsed extends BattleEvent {
  const EnemyAbilityUsed(this.enemyIndex, this.ability, this.slot);

  final int enemyIndex;
  final EnemySpecialKind ability;

  /// -1 when it found nobody to use it on.
  final int slot;
}

/// Which innate ability, for the view to name.
enum EnemySpecialKind { poison, knockOut, slay }

/// An innate ability went wide.
final class EnemyAbilityMissed extends BattleEvent {
  const EnemyAbilityMissed(this.enemyIndex, this.ability);

  final int enemyIndex;
  final EnemySpecialKind ability;
}

/// An item was used (B2-06).
final class ItemUsed extends BattleEvent {
  const ItemUsed(this.slot, this.itemKey);

  final int slot;
  final String itemKey;
}

/// The shield turned a blow aside (B2-08).
final class ShieldBlocked extends BattleEvent {
  const ShieldBlocked(this.enemyIndex, this.slot);

  final int enemyIndex;
  final int slot;
}

/// Affinity moved the damage (B2-09).
final class AffinityApplied extends BattleEvent {
  const AffinityApplied(this.enemyIndex, this.element, this.result);

  final int enemyIndex;
  final ElementKind element;
  final AffinityKind result;
}

/// The elements a view may be asked to name.
///
/// B5-02 added the three physical ones. They live on the same axis as
/// the magical ones on purpose — one affinity chart, not two.
enum ElementKind {
  fire,
  ice,
  lightning,
  force,
  mind,
  poison,
  slash,
  pierce,
  blunt,
}

enum AffinityKind { weak, resisted }

/// One of 41 · 42 · 44 was used and did nothing, as in the original.
final class EspHadNoEffect extends BattleEvent {
  const EspHadNoEffect(this.slot, this.magicId);

  final int slot;
  final int magicId;
}

/// Mind control landed — the enemy is now a party member (B2-10).
final class EnemyRecruited extends BattleEvent {
  const EnemyRecruited(this.slot, this.enemyIndex);

  final int slot;
  final int enemyIndex;
}

/// Why a mind control attempt failed, for the view to name.
enum MindControlFailure { immune, outmatched, unmoved, notAffordable }

final class MindControlFailed extends BattleEvent {
  const MindControlFailed(this.slot, this.enemyIndex, this.reason);

  final int slot;
  final int enemyIndex;
  final MindControlFailure reason;
}

/// Psychokinesis rolled its table (B2-10).
final class PsychokinesisRolled extends BattleEvent {
  const PsychokinesisRolled(this.slot, this.roll, this.effect);

  final int slot;
  final int roll;
  final PsychokinesisKind effect;
}

/// Which psychokinetic effect came up.
enum PsychokinesisKind {
  strikeOne,
  strikeAll,
  terrify,
  poison,
  stopHeart,
  illusion,
}

/// An enemy was frightened off the field.
final class EnemyFled extends BattleEvent {
  const EnemyFled(this.enemyIndex);

  final int enemyIndex;
}

/// An enemy was poisoned.
final class EnemyPoisoned extends BattleEvent {
  const EnemyPoisoned(this.enemyIndex);

  final int enemyIndex;
}

/// A partial effect from a failed psychokinetic roll, or a stat lost
/// some other way.
final class EnemyWeakened extends BattleEvent {
  const EnemyWeakened(this.enemyIndex, this.stat);

  final int enemyIndex;
  final WeakenedStat stat;
}

enum WeakenedStat { resistance, endurance, agility, accuracy, heart }

/// Reinforcements arrived (B2-11).
final class EnemySummoned extends BattleEvent {
  const EnemySummoned(this.callerIndex, this.enemyIndex);

  final int callerIndex;
  final int enemyIndex;
}

/// A party member was dragged over to the enemy side (B2-11).
///
/// Not a death — the slot is **gone**, and `BattleOutcome.departedSlots`
/// is what tells the RPG to clear it.
final class MemberAbducted extends BattleEvent {
  const MemberAbducted(this.enemyIndex, this.slot);

  final int enemyIndex;
  final int slot;
}

/// A party member was poisoned.
final class MemberPoisoned extends BattleEvent {
  const MemberPoisoned(this.slot);

  final int slot;
}

/// A party member was struck down without a damage roll.
final class MemberStruckDown extends BattleEvent {
  const MemberStruckDown(this.slot, {required this.killed});

  final int slot;

  /// True for an outright kill, false for a knock-out.
  final bool killed;
}

final class MemberBlocked extends BattleEvent {
  const MemberBlocked(this.enemyIndex, this.slot, this.kind);

  final int enemyIndex;
  final int slot;
  final BlockKind kind;
}

final class MemberDamaged extends BattleEvent {
  const MemberDamaged(
    this.enemyIndex,
    this.slot,
    this.amount,
    this.source, {
    this.whileCollapsed = false,
  });

  final int enemyIndex;
  final int slot;
  final int amount;
  final DamageSource source;

  /// See [EnemyDamaged.whileCollapsed].
  final bool whileCollapsed;
}

/// The member ran out of hit points. **Not dead** — the cure spells can
/// bring them back (B2-02).
final class MemberCollapsed extends BattleEvent {
  const MemberCollapsed(this.slot);

  final int slot;
}

/// A collapsed member took enough further punishment to die.
final class MemberDied extends BattleEvent {
  const MemberDied(this.slot);

  final int slot;
}

/// Poison ticking on a party member.
///
/// The inherited battle ticked poison for enemies only — the party's
/// `poison` field was never read during combat. With collapsing made
/// recoverable, this became the party's only way to actually die, so
/// B2-04 ticks it.
final class MemberPoisonTick extends BattleEvent {
  const MemberPoisonTick(this.slot, this.amount);

  final int slot;
  final int amount;
}

final class MemberCollapsedFromPoison extends BattleEvent {
  const MemberCollapsedFromPoison(this.slot);

  final int slot;
}

final class MemberDiedFromPoison extends BattleEvent {
  const MemberDiedFromPoison(this.slot);

  final int slot;
}

// --- Settlement -----------------------------------------------------

/// The victory experience award, one number shared by every conscious
/// member (`battle.dart:276-286`). Kill bonuses are not announced — the
/// original folded them silently into the attacker's total.
final class ExperienceSettled extends BattleEvent {
  const ExperienceSettled(this.total);

  final int total;
}

final class GoldSettled extends BattleEvent {
  const GoldSettled(this.amount);

  final int amount;
}

// --- Weapon coatings (B6-03) -----------------------------------------

/// Something laid on a weapon for a few rounds.
///
/// A weapon's own method (slash · pierce · blunt) is what it is; a coating
/// is laid **on top** for a while. Comes from the poison spell (13) or a
/// vial from the pack, and either way lasts `coatingRounds` rounds.
enum Coating {
  /// Every hit poisons the target, resistance permitting.
  poison,

  /// Every hit may stun the target, costing it its next turn.
  paralysis,

  /// Hits carry the fire element through the affinity chart.
  fire,
}

/// A coating was laid on a member's weapon.
final class WeaponCoated extends BattleEvent {
  const WeaponCoated(this.slot, this.coating, {required this.rounds});

  final int slot;
  final Coating coating;

  /// How many rounds it will hold.
  final int rounds;
}

/// A coating wore off at the top of a round.
final class CoatingExpired extends BattleEvent {
  const CoatingExpired(this.slot, this.coating);

  final int slot;
  final Coating coating;
}

/// A paralysis coating took hold: the enemy will lose its next action.
final class EnemyStunned extends BattleEvent {
  const EnemyStunned(this.slot, this.enemyIndex);

  final int slot;
  final int enemyIndex;
}

/// The stunned enemy's turn came and went.
final class EnemyLostTurn extends BattleEvent {
  const EnemyLostTurn(this.enemyIndex);

  final int enemyIndex;
}

/// A coating tried to take hold and the target shrugged it off.
final class CoatingResisted extends BattleEvent {
  const CoatingResisted(this.slot, this.enemyIndex, this.coating);

  final int slot;
  final int enemyIndex;
  final Coating coating;
}

/// A coating vial was thrown at an enemy instead of laid on a weapon.
/// What it did follows as its own event (damage, poison, stun, resisted).
final class VialThrown extends BattleEvent {
  const VialThrown(this.slot, this.enemyIndex, this.coating);

  final int slot;
  final int enemyIndex;
  final Coating coating;
}

/// Spell points restored by an item (B6-05).
final class MemberSpRestored extends BattleEvent {
  const MemberSpRestored(this.slot, this.amount);

  final int slot;
  final int amount;
}
