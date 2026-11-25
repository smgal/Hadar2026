import 'rng.dart';

/// Running away — ch.8.4.
///
/// The document's rule is one roll on one member's agility:
/// `rand(50) > agility` fails. In the original any companion could try
/// and the protagonist could not; in this skeleton it is **the leader's
/// order for the whole party**, so the agility is the leader's and a
/// failure costs everyone the round.

/// How much each step of gap between the lines helps — `hd_battle`'s
/// position layer, on top of the document's roll. Two steps are worth
/// 30 of the roll's 50, so pulling back first is a real decision.
const int escapeGapBonus = 15;

/// `rand(50) > agility (+ gap bonus)` fails; anything else gets away.
bool escapeSucceeds({
  required int agility,
  required BattleRng rng,
  int gap = 0,
}) => rng.next(50) <= agility + gap * escapeGapBonus;

/// The chance out of 100, for a view or a tool that wants to say it.
int escapeChancePercent({required int agility, int gap = 0}) {
  final threshold = agility + gap * escapeGapBonus;
  if (threshold < 0) return 0;
  if (threshold >= 49) return 100;
  return (threshold + 1) * 2;
}
