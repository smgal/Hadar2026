import 'dart:math';

/// Victory settlement, ported from `battle.dart` `_settleWin`.

/// Formula 16 — `battle.dart:276-280`.
///
/// ```dart
/// int plus = e.data.id + 1;
/// plus = (plus * plus * plus) ~/ 8;
/// xp + max(1, plus)
/// ```
///
/// Note what it reads: the enemy's **table index**, not its level. So
/// the reward tracks where a row happens to sit in the table. Ported
/// as-is; rebalancing is not a B1 concern.
///
/// Summed over every enemy in the battle, and awarded in full to each
/// conscious party member (`battle.dart:284-286`).
int victoryExperience(Iterable<int> enemyLegacyIds) {
  var total = 0;
  for (final id in enemyLegacyIds) {
    var plus = id + 1;
    plus = (plus * plus * plus) ~/ 8;
    total += max(1, plus);
  }
  return total;
}

/// Formula 17 — `battle.dart:294`. Summed over every enemy and added to
/// the party once, not per member.
int goldReward(Iterable<int> enemyLevels) {
  var total = 0;
  for (final level in enemyLevels) {
    total += level * 5;
  }
  return total;
}
