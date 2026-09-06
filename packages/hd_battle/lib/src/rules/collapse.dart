/// What losing hit points did to a combatant.
enum CollapseOutcome {
  /// Still standing.
  none,

  /// Hit points reached zero. The combatant stops acting but can still be
  /// revived — see [applyDamage].
  collapsed,

  /// Was already collapsed and took more punishment, but is still not
  /// dead — the accumulator has not passed the threshold yet.
  deepened,

  /// Was already collapsed and has now died.
  finished,

  /// Was already dead; nothing changed.
  alreadyDead,
}

/// The result of changing a combatant's vitals.
class VitalsChange {
  const VitalsChange({
    required this.hp,
    required this.unconscious,
    required this.dead,
    required this.outcome,
    required this.damageApplied,
  });

  final int hp;
  final int unconscious;
  final int dead;
  final CollapseOutcome outcome;

  /// Hit points actually taken off. Zero when the target was already
  /// down, since finishing a collapsed target is not a damage roll.
  final int damageApplied;
}

/// **One rule for losing all hit points, for everyone.**
///
/// ```
/// already dead        -> nothing changes
/// already collapsed   -> unconscious += amount; past the threshold it dies
/// otherwise           -> hp -= amount; at zero it collapses
/// ```
///
/// `unconscious` is an accumulator, not a flag, and [deathThreshold] is
/// what it has to pass — see `unconsciousDeathThreshold` in
/// `condition.dart`. B2-04 shipped with "one more hit and you are dead";
/// B2-03 replaced that after reading `checkCondition` in the C++ tree,
/// which had this mechanic all along.
///
/// ## Why this is a decision and not a port
///
/// The battle we inherited had *three* different answers to "hit points
/// reached zero", depending on how it happened:
///
/// | path | old behaviour | source |
/// |---|---|---|
/// | poison | collapsed (two stages) | `battle.dart:212-218` |
/// | a weapon | died outright | `battle.dart:486-489` |
/// | a spell | died, hit points left negative, no experience | `battle.dart:171-176` |
///
/// The weapon path even said so in a comment: *"goes unconscious first in
/// hadar sometimes but let's just do death for simplicity"*.
///
/// The C++ tree (`REF_hadar/`) keeps `unconscious` and `dead` as separate
/// fields on both players and enemies, so a two-stage collapse was
/// clearly the intent. **That is all we take from it.** The real original
/// is the Pascal build, which is not in this repo, and the C++ port's
/// fidelity has never been checked — so where it looks wrong we treat it
/// as wrong (`issues/DECISION-LOG.md`, 6th decision). The specific
/// branches below are ours.
///
/// ## What follows from one rule
///
/// * Hit points are **clamped at zero**. The old code left party members
///   at `hp: -4` and handed that to the RPG.
/// * Collapsing is **recoverable**, dying is not — which is what gives
///   the cure spells something to do (B2-02: revive acts on [dead],
///   the consciousness spells on [unconscious]).
/// * How much a collapsed combatant can absorb scales with its
///   toughness, so a sturdy character is hard to finish off.
/// * A spell that drops a target now behaves exactly like a weapon that
///   does. It used to skip the clamp and the experience award.
VitalsChange applyDamage({
  required int hp,
  required int unconscious,
  required int dead,
  required int amount,
  required int deathThreshold,
}) {
  if (dead > 0) {
    return VitalsChange(
      hp: hp,
      unconscious: unconscious,
      dead: dead,
      outcome: CollapseOutcome.alreadyDead,
      damageApplied: 0,
    );
  }
  if (unconscious > 0) {
    // Already down: the damage piles onto the accumulator instead of
    // hit points, and death waits for it to pass the threshold.
    final piled = unconscious + amount;
    return VitalsChange(
      hp: 0,
      unconscious: piled,
      dead: piled > deathThreshold ? 1 : 0,
      outcome: piled > deathThreshold
          ? CollapseOutcome.finished
          : CollapseOutcome.deepened,
      damageApplied: amount,
    );
  }
  final next = hp - amount;
  if (next <= 0) {
    return VitalsChange(
      hp: 0,
      unconscious: 1,
      dead: 0,
      outcome: CollapseOutcome.collapsed,
      damageApplied: hp,
    );
  }
  return VitalsChange(
    hp: next,
    unconscious: 0,
    dead: 0,
    outcome: CollapseOutcome.none,
    damageApplied: amount,
  );
}
