/// **폐기 — B2-01·B2-10 이 대체했다.**
///
/// The port's two catch-all spell formulas. Attack magic now costs and
/// hits per spell (`attack_magic.dart`) and ESP has its own rules
/// (`esp.dart`), so nothing calls these any more.
///
/// Kept for one reason: `test/rules/magic_escape_test.dart` pins them as
/// a record of what the inherited battle did. They go with the old
/// `application/battle.dart` at B4-03.
library;

import 'rng.dart';

/// Formula 7 — `battle.dart:166`. Applied to each conscious enemy in
/// turn, drawing once per enemy.
int spellDamageAll({
  required int levelMagic,
  required int levelEsp,
  required BattleRng rng,
}) => (levelMagic + levelEsp) * 5 + rng.next(10);

/// Formula 8 — `battle.dart:185`.
int spellDamageSingle({
  required int levelMagic,
  required int levelEsp,
  required BattleRng rng,
}) => (levelMagic + levelEsp) * 8 + rng.next(15);
