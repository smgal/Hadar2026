/// Between the party and the fight.
///
/// `hd_world` knows who the party is; `hd_battle` knows how a fight
/// goes. **Neither knows the other exists** — that is asserted by a
/// purity test in each. This package knows both, and nothing else knows
/// this one, so the coupling has exactly one home.
///
/// Two directions:
///
/// * [toBattleSetup] resolves the party into the numbers a battle takes
/// * [settle] writes the result back and returns what the world still
///   has to decide, as commands
library;

export 'src/consumables.dart';
export 'src/from_battle.dart';
export 'src/standing_order.dart';
export 'src/to_battle.dart';
export 'src/weapon_key.dart';
