import 'collapse.dart';

/// Rules that decide starting and changing condition, with no randomness.

/// Formula 18 — `enemy.dart:41-42`.
///
/// ```dart
/// hp = endurance * level;
/// if (hp <= 0) hp = 1;
/// ```
///
/// So a zero-endurance enemy still starts with 1 hit point.
int enemyInitialHp({required int endurance, required int level}) {
  final hp = endurance * level;
  return hp <= 0 ? 1 : hp;
}

/// Formula 19, now expressed through the shared collapse rule.
///
/// Poison was the **only** path in the inherited battle that produced a
/// two-stage collapse (`battle.dart:211-219`). B2-04 made every path
/// behave that way, so this is no longer a special case — it is one
/// [applyDamage] call plus the rule that poison finishes a target that
/// is already down.
///
/// It also applies to party members now. The inherited battle ticked
/// poison for enemies only (the party's `poison` field was never read
/// during combat), which left the party with no way to die at all once
/// collapsing became recoverable.
VitalsChange applyPoisonTick({
  required int hp,
  required int poison,
  required int unconscious,
  required int dead,
  required int deathThreshold,
}) {
  if (poison <= 0) {
    return VitalsChange(
      hp: hp,
      unconscious: unconscious,
      dead: dead,
      outcome: CollapseOutcome.none,
      damageApplied: 0,
    );
  }
  return applyDamage(
    hp: hp,
    unconscious: unconscious,
    dead: dead,
    amount: poison,
    deathThreshold: deathThreshold,
  );
}
