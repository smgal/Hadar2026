import '../data/enemy_data.dart';
import '../rules/enemy_ai.dart' show EnemySpellKind;
import 'battle_result_code.dart';

/// Where a damage number came from. The original writes a different
/// sentence for a weapon and for a spell (appendix E.7).
enum DamageSource { physical, spell }

/// Why an attack did nothing. Two distinct wordings in the original:
/// the target *stopped* it on a resistance roll, or it *landed* and the
/// armour took all of it.
enum BlockKind {
  /// The resistance roll succeeded — "저지했다".
  resisted,

  /// Damage reduced to zero or below — "막았다".
  absorbed,
}

/// Something that happened, as a fact rather than a sentence.
///
/// Events carry no text. Building the sentence, picking the particle
/// and deciding when to pause is the view's work — that split is what
/// lets a console view and a Flutter view share this package unchanged.
///
/// Indices into the enemy list are stable for the whole battle: an
/// enemy that dies keeps its line (the original leaves a blank line
/// rather than closing the list up, appendix E.2).
sealed class BattleEvent {
  const BattleEvent();
}

// --- Framing --------------------------------------------------------

final class EnemiesAppeared extends BattleEvent {
  const EnemiesAppeared(this.enemyIndices);

  final List<int> enemyIndices;
}

final class RoundStarted extends BattleEvent {
  const RoundStarted(this.round, {this.enemyActsFirst = false});

  /// 1-based.
  final int round;

  /// The party has no phase this round — an ambush (ch.8.3).
  final bool enemyActsFirst;
}

/// The member backed out of the action menu — "잠시 주저했다".
final class ActionSkipped extends BattleEvent {
  const ActionSkipped(this.slot);

  final int slot;
}

final class BattleEnded extends BattleEvent {
  const BattleEnded(this.code);

  final BattleResultCode code;
}

// --- The party: weapons ----------------------------------------------

/// A weapon blow is on its way — the original's action line, "{이름}는
/// {무기}로 {적}을 공격했다". What became of it follows as its own event.
///
/// Also raised for the assistant member's automatic attack ([slot] 5),
/// once per enemy when it sweeps them all.
final class AttackDeclared extends BattleEvent {
  const AttackDeclared(this.slot, this.enemyIndex);

  final int slot;
  final int enemyIndex;
}

final class AttackMissed extends BattleEvent {
  const AttackMissed(this.slot);

  final int slot;
}

/// A shooting weapon and an empty quiver — "화살이 다 떨어져 공격할 수
/// 없었다". The attack does not happen.
final class OutOfArrows extends BattleEvent {
  const OutOfArrows(this.slot);

  final int slot;
}

/// The blow had to stretch: the target stood [shortBy] steps further
/// than the weapon reaches. **The turn is not lost** — accuracy drops
/// and a nearer defender may step in.
final class AttackStrained extends BattleEvent {
  const AttackStrained(this.slot, this.enemyIndex, this.shortBy);

  final int slot;
  final int enemyIndex;
  final int shortBy;
}

/// A nearer enemy took the blow meant for one further back.
final class AttackIntercepted extends BattleEvent {
  const AttackIntercepted(this.slot, this.intendedIndex, this.actualIndex);

  final int slot;
  final int intendedIndex;
  final int actualIndex;
}

/// The two sides' formation orders resolved. Both are reported, because
/// "they matched my move" is the readable outcome of a standoff.
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

/// Someone stepped forward and struck in one action.
final class Charged extends BattleEvent {
  const Charged(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

/// Someone stepped forward and set themselves.
final class Braced extends BattleEvent {
  const Braced(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

/// A shield turned the attacker away, not the defender.
final class AttackerShovedBack extends BattleEvent {
  const AttackerShovedBack(this.slot, this.enemyIndex, this.toRank);

  final int slot;
  final int enemyIndex;
  final int toRank;
}

/// Someone gave ground rather than take a finishing blow.
final class DodgedBack extends BattleEvent {
  const DodgedBack(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

/// An enemy was driven back a rank — the reward for hitting a weakness
/// with weight is position, not just damage.
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

final class MemberPushedBack extends BattleEvent {
  const MemberPushedBack(this.slot, this.toRank);

  final int slot;
  final int toRank;
}

final class MemberCornered extends BattleEvent {
  const MemberCornered(this.slot, this.extraDamage);

  final int slot;
  final int extraDamage;
}

/// Affinity moved the damage.
final class AffinityApplied extends BattleEvent {
  const AffinityApplied(this.enemyIndex, this.element, this.result);

  final int enemyIndex;
  final ElementKind element;
  final AffinityKind result;
}

/// The elements a view may be asked to name.
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

// --- The party: magic ------------------------------------------------

/// A skill is being used — the original's action line for it. Which
/// sentence that is depends on the skill's category; the view reads it
/// off [magicId].
///
/// [enemyIndex] is the enemy it is aimed at, or -1 when it has no single
/// target (every enemy, the party, a summon). An attack spell that hits
/// all enemies raises one of these **per enemy**, as the original prints
/// a line per enemy.
final class SpellCast extends BattleEvent {
  const SpellCast(this.slot, this.magicId, {this.enemyIndex = -1});

  final int slot;
  final int magicId;
  final int enemyIndex;
}

/// "마법 지수가 부족했다" — the caster could not pay. Raised when an
/// unaffordable line is picked from the list (the menu comes back) and
/// when a per-target spell runs dry partway through.
final class NotEnoughSpellPoints extends BattleEvent {
  const NotEnoughSpellPoints(this.slot);

  final int slot;
}

/// A spell went wide — "그러나, {적}을 빗나갔다".
final class SpellMissed extends BattleEvent {
  const SpellMissed(this.slot, this.magicId, this.enemyIndex);

  final int slot;
  final int magicId;
  final int enemyIndex;
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
  final DamageSource source;
}

final class EnemyDamaged extends BattleEvent {
  const EnemyDamaged(this.slot, this.enemyIndex, this.amount, this.source);

  /// Who did it; -1 for something no member did.
  final int slot;
  final int enemyIndex;
  final int amount;
  final DamageSource source;
}

/// The enemy ran out of hit points — **unconscious, not dead**. Whoever
/// did it is paid for it; a second blow is what kills.
final class EnemyCollapsed extends BattleEvent {
  const EnemyCollapsed(this.slot, this.enemyIndex, this.source);

  final int slot;
  final int enemyIndex;
  final DamageSource source;
}

/// An unconscious enemy was finished off — every member still standing
/// is paid for it.
final class EnemyFinished extends BattleEvent {
  const EnemyFinished(
    this.slot,
    this.enemyIndex, {
    this.source = DamageSource.physical,
    this.flavour = 0,
  });

  final int slot;
  final int enemyIndex;
  final DamageSource source;

  /// Which of the weapon's four finishing lines, 0..3 (appendix E.7).
  /// Always 0 for a spell, which has one.
  final int flavour;
}

/// "{이름}는 N만큼 경험치를 얻었다 !" — one per member paid.
final class ExperienceGained extends BattleEvent {
  const ExperienceGained(this.slot, this.amount);

  final int slot;
  final int amount;
}

/// What a special spell changed, for the view to name.
enum DebuffDetail {
  specialRemoved,
  defenceLowered,
  abilityLowered,
  castingLowered,
  castingRemoved,
  superhumanLowered,
  superhumanRemoved,
  poisoned,
}

/// A special spell took a capability away.
final class DebuffApplied extends BattleEvent {
  const DebuffApplied(this.slot, this.magicId, this.enemyIndex, this.detail);

  final int slot;
  final int magicId;
  final int enemyIndex;
  final DebuffDetail detail;
}

/// A special spell was stopped or went wide.
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

// --- The party: cures and items --------------------------------------

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

/// Brought round. The unconscious counter is back to zero and hit
/// points are at least 1.
final class MemberRevived extends BattleEvent {
  const MemberRevived(this.slot);

  final int slot;
}

/// Brought back from the dead — **unconscious, not standing**.
final class MemberResurrected extends BattleEvent {
  const MemberResurrected(this.slot);

  final int slot;
}

/// The cure or the item ran and nobody needed any of what it does. The
/// original says nothing at all here in battle (ch.9.4).
final class CureHadNoEffect extends BattleEvent {
  const CureHadNoEffect(this.slot);

  final int slot;
}

/// Magic points restored by a potion.
final class MemberMpRestored extends BattleEvent {
  const MemberMpRestored(this.slot, this.amount);

  final int slot;
  final int amount;
}

/// An item was used. What it did follows as its own events.
final class ItemUsed extends BattleEvent {
  const ItemUsed(this.slot, this.itemKey);

  final int slot;
  final String itemKey;
}

/// Why a crystal did nothing.
enum CrystalSilence {
  /// Only one of the Dark and Ebony pair is in the pack — "크리스탈은
  /// 전혀 반응하지 않았다".
  needsItsPair,

  /// The pair is here but the one it answers to is not — "이 크리스탈은
  /// 선의 힘을 사용하는 적에게만 반응한다".
  wrongEnemy,
}

/// A crystal was held up and nothing happened. **It is not used up.**
final class CrystalDidNotReact extends BattleEvent {
  const CrystalDidNotReact(this.slot, this.itemKey, this.reason);

  final int slot;
  final String itemKey;
  final CrystalSilence reason;
}

/// The Dark and Ebony crystals aged their target — every number it has,
/// halved.
final class EnemyAged extends BattleEvent {
  const EnemyAged(this.enemyIndex);

  final int enemyIndex;
}

/// The Spirit crystal halved an enemy's remaining hit points.
final class EnemySoulWithered extends BattleEvent {
  const EnemySoulWithered(this.enemyIndex, this.amount);

  final int enemyIndex;

  /// Hit points taken.
  final int amount;
}

/// The Energy crystal ran over the whole party: the living are awake
/// and whole, the dead are back with one hit point.
final class PartyRestored extends BattleEvent {
  const PartyRestored(this.slot);

  /// Who used it.
  final int slot;
}

// --- The party: ESP and summoning ------------------------------------

/// Which of 수소 핵융합's two lines, 0 or 1.
final class FusionUnleashed extends BattleEvent {
  const FusionUnleashed(this.slot, this.flavour);

  final int slot;
  final int flavour;
}

/// 독심 landed — the enemy has left the fight and sits in the sixth
/// seat. An [AssistantJoined] follows.
final class EnemyRecruited extends BattleEvent {
  const EnemyRecruited(this.slot, this.enemyIndex);

  final int slot;
  final int enemyIndex;
}

/// Why a persuasion failed.
enum MindControlFailure { immune, outmatched, unmoved }

final class MindControlFailed extends BattleEvent {
  const MindControlFailed(this.slot, this.enemyIndex, this.reason);

  final int slot;
  final int enemyIndex;
  final MindControlFailure reason;
}

/// An ESP ability was used and nothing took hold.
final class EspHadNoEffect extends BattleEvent {
  const EspHadNoEffect(this.slot, this.magicId, this.enemyIndex);

  final int slot;
  final int magicId;
  final int enemyIndex;
}

/// An enemy lost some of a stat.
final class EnemyWeakened extends BattleEvent {
  const EnemyWeakened(this.enemyIndex, this.stat);

  final int enemyIndex;
  final WeakenedStat stat;
}

enum WeakenedStat { resistance, endurance, agility, accuracy }

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

/// An enemy was dropped where it stood, with no damage roll — 유체
/// 이탈's best outcome.
final class EnemyStruckDown extends BattleEvent {
  const EnemyStruckDown(this.slot, this.enemyIndex);

  final int slot;
  final int enemyIndex;
}

/// How someone came to sit in the sixth seat.
enum AssistantSource { summon, crystal, persuasion }

/// The sixth seat has a new occupant.
final class AssistantJoined extends BattleEvent {
  const AssistantJoined(this.source, {required this.replaced});

  final AssistantSource source;

  /// Whoever sat there before is gone — a new summon overwrites the old
  /// one (ch.7.8).
  final bool replaced;
}

/// The party tries to run. [slot] is the leader who gave the order.
final class EscapeAttempted extends BattleEvent {
  const EscapeAttempted(this.slot, {this.gap = 0});

  final int slot;

  /// The gap between the lines when the attempt was made.
  final int gap;
}

/// The party did not get away, and everyone lost the round.
final class EscapeFailed extends BattleEvent {
  const EscapeFailed(this.slot);

  final int slot;
}

final class EscapeSucceeded extends BattleEvent {
  const EscapeSucceeded(this.slot);

  final int slot;
}

// --- Enemies acting -------------------------------------------------

/// Poison took its round's worth from an enemy. The original prints
/// nothing for this.
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

/// "{적}는 빗맞추었다".
final class EnemyAttackMissed extends BattleEvent {
  const EnemyAttackMissed(this.enemyIndex);

  final int enemyIndex;
}

/// An enemy had to stretch to reach its target.
final class EnemyAttackStrained extends BattleEvent {
  const EnemyAttackStrained(this.enemyIndex, this.slot, this.shortBy);

  final int enemyIndex;
  final int slot;
  final int shortBy;
}

/// A member in front took the blow meant for someone behind.
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

/// The shield turned a blow aside.
final class ShieldBlocked extends BattleEvent {
  const ShieldBlocked(this.enemyIndex, this.slot);

  final int enemyIndex;
  final int slot;
}

final class MemberBlocked extends BattleEvent {
  const MemberBlocked(
    this.enemyIndex,
    this.slot,
    this.kind, {
    this.source = DamageSource.physical,
  });

  final int enemyIndex;
  final int slot;
  final BlockKind kind;
  final DamageSource source;
}

final class MemberDamaged extends BattleEvent {
  const MemberDamaged(
    this.enemyIndex,
    this.slot,
    this.amount,
    this.source, {
    this.whileDown = false,
  });

  final int enemyIndex;
  final int slot;
  final int amount;
  final DamageSource source;

  /// The member was already unconscious or dead, so this went onto a
  /// counter rather than hit points (ch.8.6).
  final bool whileDown;
}

/// The member ran out of hit points — unconscious, and recoverable.
final class MemberCollapsed extends BattleEvent {
  const MemberCollapsed(this.slot);

  final int slot;
}

/// An unconscious member took enough further punishment to die.
final class MemberDied extends BattleEvent {
  const MemberDied(this.slot);

  final int slot;
}

/// An enemy cast one of its eleven spells. [slot] is the member it is
/// aimed at, or -1 for the whole party; what it did to each follows.
final class EnemyCastSpell extends BattleEvent {
  const EnemyCastSpell(this.enemyIndex, this.spell, this.slot);

  final int enemyIndex;
  final EnemySpellKind spell;
  final int slot;
}

/// "{적}의 마법공격은 빗나갔다".
final class EnemySpellMissed extends BattleEvent {
  const EnemySpellMissed(this.enemyIndex, this.slot);

  final int enemyIndex;
  final int slot;
}

/// An enemy patched itself up.
final class EnemyHealedSelf extends BattleEvent {
  const EnemyHealedSelf(this.enemyIndex, this.amount);

  final int enemyIndex;
  final int amount;
}

/// An enemy healed one of its side.
final class EnemyHealedAlly extends BattleEvent {
  const EnemyHealedAlly(this.enemyIndex, this.targetIndex, this.amount);

  final int enemyIndex;
  final int targetIndex;
  final int amount;
}

/// An enemy brought a fallen one of its side back, one stage: dead to
/// unconscious, or unconscious to standing.
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

/// An enemy tried its special attack on [slot] (-1: it found nobody).
final class EnemyAbilityUsed extends BattleEvent {
  const EnemyAbilityUsed(this.enemyIndex, this.ability, this.slot);

  final int enemyIndex;
  final EnemySpecial ability;
  final int slot;
}

/// "독 공격은 실패했다".
final class EnemyAbilityMissed extends BattleEvent {
  const EnemyAbilityMissed(this.enemyIndex, this.ability);

  final int enemyIndex;
  final EnemySpecial ability;
}

/// "그러나, {대원}는 독 공격을 피했다" — luck saved them.
final class MemberEvadedAbility extends BattleEvent {
  const MemberEvadedAbility(this.slot, this.ability);

  final int slot;
  final EnemySpecial ability;
}

/// A special attack landed: poisoned, knocked out, or killed.
final class MemberAfflicted extends BattleEvent {
  const MemberAfflicted(
    this.slot,
    this.ability, {
    this.enemyIndex = -1,
    this.mass = false,
  });

  final int slot;
  final EnemySpecial ability;
  final int enemyIndex;

  /// True when it came from one of the party-wide abilities, which the
  /// original words differently ("…에 의해 독에 감염 되었다").
  final bool mass;
}

/// An enemy tried to break [slot]'s armour.
final class ArmourBreakAttempted extends BattleEvent {
  const ArmourBreakAttempted(
    this.enemyIndex,
    this.slot, {
    required this.broken,
  });

  final int enemyIndex;
  final int slot;

  /// True when it worked — one point of armour class, gone for good.
  final bool broken;
}

/// Reinforcements arrived.
final class EnemySummoned extends BattleEvent {
  const EnemySummoned(this.callerIndex, this.enemyIndex);

  final int callerIndex;
  final int enemyIndex;
}

/// 정신 지배 took the assistant member. It is on the enemy list now, at
/// [newEnemyIndex], and its seat is empty.
final class MemberAbducted extends BattleEvent {
  const MemberAbducted(this.enemyIndex, this.slot, this.newEnemyIndex);

  final int enemyIndex;
  final int slot;
  final int newEnemyIndex;
}

/// A 분신 user and its images changed places.
///
/// [indices] is the whole group — the real one and every image — **with
/// nothing to say which is which**. The original prints no line for
/// this; the event exists so a view knows to redraw the list.
final class EnemyClonesShifted extends BattleEvent {
  const EnemyClonesShifted(this.indices);

  final List<int> indices;
}

/// Poison took its round's worth from a member. The original prints
/// nothing for this.
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

/// "일행은 N개의 금을 얻었다."
final class GoldSettled extends BattleEvent {
  const GoldSettled(this.amount);

  final int amount;
}
