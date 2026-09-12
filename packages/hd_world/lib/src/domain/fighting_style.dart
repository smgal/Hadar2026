import 'wire.dart';

/// A standing order a member can be put on.
///
/// ## Roles, not a rule editor
///
/// Seven postures and one toggle. There is no condition language and no
/// priority list — writing conditions is the single most expensive
/// screen a party menu can grow, and the value it adds is the value of
/// not playing.
///
/// The names are roles: what this member is *for*. Which target they
/// pick is never theirs to decide.
enum FightingStyle implements Wired {
  /// Front rank, shield up, takes the blow.
  bulwark(0),

  /// Closes and hits whatever is nearest.
  assault(1),

  /// Strikes from the middle rank and gives ground.
  skirmish(2),

  /// Shoots from the back rank and stays there.
  volley(3),

  /// Attack magic first.
  firepower(4),

  /// Coatings, curses and the mind — takes capability away.
  disrupt(5),

  /// Nobody falls. Everything else second.
  mend(6);

  const FightingStyle(this.wire);

  @override
  final int wire;

  static FightingStyle? fromWire(int wire) => byWire(values, wire);

}
