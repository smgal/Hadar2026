import 'rng.dart';

/// Whose turn it is.
enum Side { party, enemy }

/// One entry in the order of battle.
class Turn {
  const Turn(this.side, this.index, this.initiative);

  final Side side;

  /// Party slot, or index into the enemy list.
  final int index;

  /// What put it here, for a view that wants to show the roll.
  final int initiative;
}

/// How much a die adds on top of agility.
///
/// Wide enough that a slow character sometimes goes first, narrow
/// enough that agility decides most rounds. 10 puts the swing at about
/// half a typical agility spread (the table runs 0-30).
const int initiativeJitter = 10;

/// Builds the order of battle for one round (B2-05).
///
/// ## This is a decision, not a port
///
/// Neither reference tree has initiative. The C++ battle runs the whole
/// party in slot order and then every enemy in list order, and the Unity
/// port's `_ProcessOnCombatPower` — which looks like it was meant to
/// become this — is a stub that sums numbers and throws them away
/// (appendix P-3).
///
/// So `agility` was read in exactly two places, both in the escape
/// formula (appendix O). A stat on every row of a 75-row table did
/// nothing else. That is what this fixes.
///
/// ## How it works
///
/// Each combatant rolls `agility + random(jitter)` and the list is
/// sorted high to low. Ties fall to the party first, then to the lower
/// index — a fixed rule, so the same seed always gives the same order.
///
/// Everyone who **can act** is listed, so a member who collapses
/// earlier in the round simply gets skipped when their turn arrives.
List<Turn> orderOfBattle({
  required List<int> partyAgility,
  required List<bool> partyActive,
  required List<int> enemyAgility,
  required List<bool> enemyActive,
  required BattleRng rng,
}) {
  final turns = <Turn>[];
  // Party first, then enemies: draw order has to be fixed or the same
  // seed would not reproduce.
  for (var i = 0; i < partyAgility.length; i++) {
    if (!partyActive[i]) continue;
    turns.add(
      Turn(Side.party, i, partyAgility[i] + rng.next(initiativeJitter)),
    );
  }
  for (var i = 0; i < enemyAgility.length; i++) {
    if (!enemyActive[i]) continue;
    turns.add(
      Turn(Side.enemy, i, enemyAgility[i] + rng.next(initiativeJitter)),
    );
  }
  turns.sort((a, b) {
    if (a.initiative != b.initiative) return b.initiative - a.initiative;
    if (a.side != b.side) return a.side == Side.party ? -1 : 1;
    return a.index - b.index;
  });
  return turns;
}
