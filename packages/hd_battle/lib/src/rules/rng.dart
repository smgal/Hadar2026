import 'dart:math';

/// The single source of randomness for one battle.
///
/// The original created a fresh `Random()` at every draw — 14 places in
/// `battle.dart` — which made a battle impossible to reproduce and
/// forced `defense_scale_test.dart` to copy the formulas into the test
/// rather than call them. Here every draw comes from one generator, so a
/// battle is a function of (setup, commands, seed).
///
/// **Draw order is part of the contract.** Two runs with the same seed
/// only agree if the rules ask for numbers in the same sequence, so the
/// port keeps the original's evaluation order — including its
/// short-circuits, which skip draws.
abstract class BattleRng {
  /// Uniform integer in `[0, max)`. Mirrors `Random.nextInt`.
  int next(int max);

  /// How many numbers have been drawn so far. Lets a test assert that a
  /// change did not silently add or remove a draw.
  int get draws;
}

/// The real thing: one seeded generator per battle.
class SeededRng implements BattleRng {
  SeededRng(this.seed) : _random = Random(seed);

  final int seed;
  final Random _random;

  @override
  int get draws => _draws;
  int _draws = 0;

  @override
  int next(int max) {
    _draws++;
    return _random.nextInt(max);
  }
}

/// Hands back a fixed sequence of draws.
///
/// This is what lets a test exercise a formula over every possible roll
/// instead of copying the arithmetic — the gap `defense_scale_test.dart`
/// had to live with.
class ScriptedRng implements BattleRng {
  ScriptedRng(this.script, {this.repeat = false});

  final List<int> script;

  /// When true the script wraps around instead of running out.
  final bool repeat;

  @override
  int get draws => _draws;
  int _draws = 0;

  @override
  int next(int max) {
    if (_draws >= script.length && !repeat) {
      throw StateError(
        'scripted rng ran out after $_draws draws (asked for next($max))',
      );
    }
    final value = script[_draws % script.length];
    _draws++;
    if (value < 0 || value >= max) {
      throw StateError('scripted draw $value is outside next($max)');
    }
    return value;
  }
}
