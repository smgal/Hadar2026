import 'rng.dart';

/// Escape rules, ported from `battle.dart` `_tryToRunAway`.

/// The average agility of the enemies that can still act
/// (`battle.dart:400-410`). Integer mean of the sum; zero when nobody is
/// conscious, which the original left as the initial 0.
int averageEnemyAgility(Iterable<int> consciousEnemyAgilities) {
  var sum = 0;
  var count = 0;
  for (final a in consciousEnemyAgilities) {
    sum += a;
    count++;
  }
  if (count == 0) return 0;
  return sum ~/ count;
}

/// How much each step of gap between the lines helps the party get away
/// (B6-04). `rand(20)` is the whole of the luck in the roll, so two steps
/// (+30) is more than luck can ever give — pulling back first is a real
/// decision, not a rounding error.
const int escapeGapBonus = 15;

/// Formula 9 — `battle.dart:412-415`, made a party roll (B6-04).
///
/// ```dart
/// int playerRunScore = (p.agility + p.luck) ~/ 2 + Random().nextInt(20);
/// int enemyBlockScore = avgEnemyAgility + 10;
/// if (playerRunScore > enemyBlockScore) ...
/// ```
///
/// The original rolled this per member, for everyone but the leader, and
/// ended the fight on the first success — with five members that was
/// nearly automatic. Now [agility] and [luck] are the **party's
/// averages**, there is one draw, and [gap] adds [escapeGapBonus] a
/// step. A tie still counts as failure.
bool escapeSucceeds({
  required int agility,
  required int luck,
  required int averageEnemyAgility,
  required BattleRng rng,
  int gap = 0,
}) {
  final runScore = (agility + luck) ~/ 2 + rng.next(20) + gap * escapeGapBonus;
  final blockScore = averageEnemyAgility + 10;
  return runScore > blockScore;
}

/// Integer mean, zero for nobody — the same shape [averageEnemyAgility]
/// uses, for the party side.
int averageOf(Iterable<int> values) {
  var sum = 0;
  var count = 0;
  for (final v in values) {
    sum += v;
    count++;
  }
  return count == 0 ? 0 : sum ~/ count;
}
