import 'condition.dart';

/// The four things a cure spell can do.
///
/// Every cure in the game (magic 19-32) is a **composition** of these,
/// and **the order is load-bearing** — see [cureStepsFor].
enum CureStep {
  /// Restore hit points.
  heal,

  /// Clear poison.
  antidote,

  /// Bring someone round from a collapse.
  recoverConsciousness,

  /// Bring someone back from the dead.
  revitalize,
}

/// What one cure step did.
class CureApplied {
  const CureApplied({
    required this.hp,
    required this.poison,
    required this.unconscious,
    required this.dead,
    required this.spSpent,
    required this.amount,
    required this.step,
    required this.applied,
    this.shortOfSp = false,
  });

  final int hp;
  final int poison;
  final int unconscious;
  final int dead;

  /// Spell points the caster paid. Zero when nothing happened.
  final int spSpent;

  /// Hit points restored, for [CureStep.heal]. Zero otherwise.
  final int amount;

  final CureStep step;

  /// False when the target did not need it, or the caster could not pay.
  final bool applied;

  /// Distinguishes "could not pay" from "was not needed".
  final bool shortOfSp;
}

/// Which steps a cure spell runs, in order.
///
/// From `hd_class_pc_player.cpp` `castCureSpell`. The composition is the
/// original's; **the ordering matters and is not cosmetic** — [heal]
/// refuses to touch a poisoned target (see [applyCureStep]), so
/// the heal-and-antidote spell only works because the antidote runs
/// first.
///
/// | id | spell | steps |
/// |---|---|---|
/// | 19 / 26 | heal | heal |
/// | 20 / 27 | cure poison | antidote |
/// | 21 / 28 | heal + cure poison | antidote, heal |
/// | 22 / 29 | wake | recoverConsciousness |
/// | 23 | revive | revitalize |
/// | 24 / 30 | wake + cure + heal | recoverConsciousness, antidote, heal |
/// | 25 / 32 | full recovery | revitalize, recoverConsciousness, antidote, heal |
/// | 31 | revive all | revitalize |
///
/// Note the halves are **not** in the same order: single-target puts
/// revive at 23 (fifth) while the party-wide list puts it at 31
/// (sixth).
/// That asymmetry is in the name table, and the C++ switch statements
/// match their own halves, so it is deliberate rather than a slip.
List<CureStep> cureStepsFor(int magicId) {
  switch (magicId) {
    case 19:
    case 26:
      return const [CureStep.heal];
    case 20:
    case 27:
      return const [CureStep.antidote];
    case 21:
    case 28:
      return const [CureStep.antidote, CureStep.heal];
    case 22:
    case 29:
      return const [CureStep.recoverConsciousness];
    case 23:
    case 31:
      return const [CureStep.revitalize];
    case 24:
    case 30:
      return const [
        CureStep.recoverConsciousness,
        CureStep.antidote,
        CureStep.heal,
      ];
    case 25:
    case 32:
      return const [
        CureStep.revitalize,
        CureStep.recoverConsciousness,
        CureStep.antidote,
        CureStep.heal,
      ];
    default:
      return const [];
  }
}

/// Whether the spell hits the whole party rather than one member.
bool cureTargetsAll(int magicId) => magicId >= 26 && magicId <= 32;

/// Runs one step against one target.
///
/// The preconditions and costs are the original's
/// (`m_healOne` · `m_antidoteOne` · `m_recoverConsciousnessOne` ·
/// `m_revitalizeOne`), and two of them are worth calling out because
/// they shape how the spells compose:
///
/// * **Healing refuses a poisoned target.** Not just a dead or collapsed
///   one — poison blocks it too. That is the whole reason
///   the heal-and-antidote spell exists as a separate entry.
/// * **Waking someone costs `10 x` the accumulator.** So the deeper a
///   collapse (B2-03), the more it takes to undo — the accumulator earns
///   its keep twice.
///
/// Reviving leaves the target collapsed rather than standing, so a full
/// recovery needs the revive *and* the wake. The original clamps the
/// accumulator down to the death threshold on the way, which is what
/// keeps a revived target from dying again immediately.
CureApplied applyCureStep(
  CureStep step, {
  required int hp,
  required int maxHp,
  required int poison,
  required int unconscious,
  required int dead,
  required int deathThreshold,
  required int casterSp,
  required int casterMagicLevel,
}) {
  CureApplied unchanged({bool shortOfSp = false}) => CureApplied(
    hp: hp,
    poison: poison,
    unconscious: unconscious,
    dead: dead,
    spSpent: 0,
    amount: 0,
    step: step,
    applied: false,
    shortOfSp: shortOfSp,
  );

  switch (step) {
    case CureStep.heal:
      // `m_healOne`: refuses the dead, the collapsed, the poisoned, and
      // anyone already at full health.
      if (dead > 0 || unconscious > 0 || poison > 0) return unchanged();
      if (hp >= maxHp) return unchanged();
      final cost = 2 * casterMagicLevel;
      // A caster with no magic level pays 0 and restores 0. The C++
      // menu gate (`level/2 + 1`) still offers the spell to them, so it
      // reports success while doing nothing — treated as a bug and
      // refused (6th decision).
      if (cost == 0) return unchanged();
      if (casterSp < cost) return unchanged(shortOfSp: true);
      final restored = cost * 3 ~/ 2;
      if (restored == 0) return unchanged();
      final next = hp + restored > maxHp ? maxHp : hp + restored;
      return CureApplied(
        hp: next,
        poison: poison,
        unconscious: unconscious,
        dead: dead,
        spSpent: cost,
        amount: next - hp,
        step: step,
        applied: true,
      );

    case CureStep.antidote:
      // `m_antidoteOne`: cost is flat, and it will not reach through a
      // collapse.
      if (dead > 0 || unconscious > 0) return unchanged();
      if (poison == 0) return unchanged();
      if (casterSp < 15) return unchanged(shortOfSp: true);
      return CureApplied(
        hp: hp,
        poison: 0,
        unconscious: unconscious,
        dead: dead,
        spSpent: 15,
        amount: 0,
        step: step,
        applied: true,
      );

    case CureStep.recoverConsciousness:
      // `m_recoverConsciousnessOne`: cost scales with the accumulator.
      if (dead > 0) return unchanged();
      if (unconscious == 0) return unchanged();
      final cost = 10 * unconscious;
      if (casterSp < cost) return unchanged(shortOfSp: true);
      return CureApplied(
        hp: hp <= 0 ? 1 : hp,
        poison: poison,
        unconscious: 0,
        dead: dead,
        spSpent: cost,
        amount: 0,
        step: step,
        applied: true,
      );

    case CureStep.revitalize:
      // `m_revitalizeOne`: brings them back *collapsed*, with the
      // accumulator pulled down to something survivable.
      if (dead == 0) return unchanged();
      const cost = 30;
      if (casterSp < cost) return unchanged(shortOfSp: true);
      var woken = unconscious > deathThreshold ? deathThreshold : unconscious;
      if (woken == 0) woken = 1;
      return CureApplied(
        hp: hp,
        poison: poison,
        unconscious: woken,
        dead: 0,
        spSpent: cost,
        amount: 0,
        step: step,
        applied: true,
      );
  }
}

/// How many cure spells a caster may choose from.
///
/// `castCureSpell` gates the two halves on different curves:
///
/// ```cpp
/// int num_enabled = p_player->level[1] / 2 + 1;   // single target
/// int num_enabled = p_player->level[1] / 2 - 3;   // whole party
/// ```
///
/// both capped at 7, and the party-wide list refuses outright when the
/// count is not positive — so the party-wide cures need magic level 8.
///
/// The C++ source carries a porter note on that refusal saying the
/// comparison used to be `< 0` and needs review, so the porter changed
/// it and was unsure.
/// `< 0` would let a count of zero through and offer an empty menu, so
/// the change looks right and we keep it — but it is flagged rather than
/// trusted, per the 6th decision.
({int single, int all}) cureSpellsEnabled({required int magicLevel}) {
  var single = magicLevel ~/ 2 + 1;
  if (single > 7) single = 7;
  if (single < 0) single = 0;
  var all = magicLevel ~/ 2 - 3;
  if (all <= 0) {
    all = 0;
  } else if (all > 7) {
    all = 7;
  }
  return (single: single, all: all);
}

/// The cure spell ids this caster can pick, single-target first.
List<int> castableCures({required int magicLevel}) {
  final counts = cureSpellsEnabled(magicLevel: magicLevel);
  return [
    for (var i = 0; i < counts.single; i++) 19 + i,
    for (var i = 0; i < counts.all; i++) 26 + i,
  ];
}

/// Whether the target still needs any of [steps].
///
/// Used to tell "the spell did nothing" from "the caster was broke",
/// which the original could not distinguish in battle — it returned
/// silently either way.
bool cureWouldHelp(
  List<CureStep> steps, {
  required int hp,
  required int maxHp,
  required int poison,
  required int unconscious,
  required int dead,
}) {
  for (final step in steps) {
    switch (step) {
      case CureStep.heal:
        if (dead == 0 && unconscious == 0 && poison == 0 && hp < maxHp) {
          return true;
        }
      case CureStep.antidote:
        if (dead == 0 && unconscious == 0 && poison > 0) return true;
      case CureStep.recoverConsciousness:
        if (dead == 0 && unconscious > 0) return true;
      case CureStep.revitalize:
        if (dead > 0) return true;
    }
  }
  return false;
}

/// Reads the condition a cure would be aimed at, for the view.
Condition cureTargetCondition({
  required int hp,
  required int poison,
  required int unconscious,
  required int dead,
}) => conditionOf(hp: hp, poison: poison, unconscious: unconscious, dead: dead);

/// Applies a whole cure spell to one target, running its steps in order.
///
/// Returns the accumulated result plus the individual step outcomes so
/// the view can report exactly what happened.
({
  int hp,
  int poison,
  int unconscious,
  int dead,
  int spSpent,
  List<CureApplied> steps,
})
applyCure(
  int magicId, {
  required int hp,
  required int maxHp,
  required int poison,
  required int unconscious,
  required int dead,
  required int deathThreshold,
  required int casterSp,
  required int casterMagicLevel,
}) {
  var curHp = hp;
  var curPoison = poison;
  var curUnconscious = unconscious;
  var curDead = dead;
  var sp = casterSp;
  var spent = 0;
  final outcomes = <CureApplied>[];

  for (final step in cureStepsFor(magicId)) {
    final result = applyCureStep(
      step,
      hp: curHp,
      maxHp: maxHp,
      poison: curPoison,
      unconscious: curUnconscious,
      dead: curDead,
      deathThreshold: deathThreshold,
      casterSp: sp,
      casterMagicLevel: casterMagicLevel,
    );
    curHp = result.hp;
    curPoison = result.poison;
    curUnconscious = result.unconscious;
    curDead = result.dead;
    sp -= result.spSpent;
    spent += result.spSpent;
    outcomes.add(result);
  }

  return (
    hp: curHp,
    poison: curPoison,
    unconscious: curUnconscious,
    dead: curDead,
    spSpent: spent,
    steps: outcomes,
  );
}
