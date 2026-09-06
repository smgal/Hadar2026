/// How a combatant is doing, for display and for rules that branch on it.
///
/// The C++ tree had exactly these four and no more
/// (`hd_res_string.h` `enum CONDITION`). That is worth knowing because
/// it settles a question B2-03 was about to get wrong: the special
/// spells (13-18) are **not** timed status effects in this game. They
/// permanently reduce a stat — see [reduceStat].
enum Condition { good, poisoned, unconscious, dead }

/// Reads a condition off the raw fields, worst first.
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

/// How much punishment a collapsed combatant absorbs before dying.
///
/// From `hd_class_pc_player.cpp` `checkCondition`:
///
/// ```cpp
/// if ((hp <= 0) && (unconscious == 0))               unconscious = 1;
/// if ((unconscious > endurance * level[0]) && (dead == 0)) dead = 1;
/// ```
///
/// So `unconscious` was never a flag — it is an **accumulator**, and
/// death arrives when it passes toughness times level. That is a
/// mechanic, not a suspicious constant, so we keep it; it replaces the
/// blunter "one more hit and you are dead" that B2-04 shipped with.
///
/// The floor of 1 is ours: an endurance-0 or level-0 combatant would
/// otherwise die to the very blow that collapsed it, which would make
/// the collapsed state unreachable for exactly the weakest targets.
int unconsciousDeathThreshold({required int endurance, required int level}) {
  final threshold = endurance * level;
  return threshold < 1 ? 1 : threshold;
}

/// Lowers a stat by [amount], never past [floor].
///
/// The special spells reduce enemy stats directly, and **the C++ tree
/// gets this wrong twice**. `castSpellWithSpecialAbility` case 3 does a
/// bare `p_enemy->resistance -= 10`, and case 4 guards with
/// `if (resistance > 0) resistance -= 10;` — which still takes a
/// resistance of 5 down to -5.
///
/// A negative resistance happens to be harmless where it is read
/// (`random(100) < resistance` is simply never true), but it is wrong,
/// it would surface the moment anything displayed or serialised it, and
/// the Pascal original is not here to say otherwise. Treated as a bug
/// and fixed (`issues/DECISION-LOG.md`, 6th decision).
int reduceStat(int value, int amount, {int floor = 0}) {
  final next = value - amount;
  return next < floor ? floor : next;
}
