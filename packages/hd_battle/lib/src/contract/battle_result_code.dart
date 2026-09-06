/// How a battle ended, as seen by the RPG side.
///
/// The integer [wire] values are a contract with content that is not
/// compiled with this package: the original CM2 scripts compare
/// `Battle::Result()` against the constants in `assets/const.cm2:53-55`.
///
/// ```
/// BATTLERESULT_EVADE.assign(0)
/// BATTLERESULT_WIN.assign(1)
/// BATTLERESULT_LOSE.assign(2)
/// ```
///
/// Declared explicitly, never `Enum.index`. The RPG-side mirror is
/// `hadar2026_app/lib/domain/battle/battle_result.dart`; the two must
/// agree, and `const.cm2` is the authority for both.
enum BattleResultCode {
  /// No battle has finished yet. Deliberately outside the CM2 constants
  /// so a script reading the result before a battle matches none of the
  /// three branches.
  none(-1),

  /// The party ran away.
  evade(0),

  /// Every enemy was defeated.
  win(1),

  /// The party was wiped out.
  lose(2);

  const BattleResultCode(this.wire);

  final int wire;

  static BattleResultCode fromWire(int wire) => values.firstWhere(
    (v) => v.wire == wire,
    orElse: () => throw ArgumentError('unknown result wire: $wire'),
  );
}
