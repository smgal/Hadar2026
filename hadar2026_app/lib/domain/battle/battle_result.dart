/// How a battle ended.
///
/// [wire] is the value cm2 sees through `Battle::Result()` and compares
/// against the constants in `assets/const.cm2:53-55`:
///
/// ```
/// BATTLERESULT_EVADE.assign(0)
/// BATTLERESULT_WIN.assign(1)
/// BATTLERESULT_LOSE.assign(2)
/// ```
///
/// The Dart side used to carry raw ints with the **opposite** meaning for
/// 0 and 2 (`battle.dart` called 0 "Lose" and 2 "Run away"), so five
/// shipped scripts — `lore_ep1.cm2:355`, `town1.cm2:57`,
/// `town2.cm2:355`, `L1_ep1d0.cm2:354`,`:424` — read a wipe as an escape
/// and vice versa. `const.cm2` is the original's table and stays the
/// authority; this enum is what makes Dart agree with it.
///
/// Declared explicitly, never `Enum.index` — the same rule
/// `HDTileAction.scriptMode` follows, and for the same reason: the value
/// crosses into content that is not compiled with this code.
/// `test/domain/battle/battle_result_test.dart` pins it.
enum HDBattleResult {
  /// No battle has run since the last `init()`.
  ///
  /// Deliberately outside the cm2 constants: content comparing against
  /// `BATTLERESULT_EVADE`/`WIN`/`LOSE` matches none of them, which is the
  /// correct reading of "there is no result yet". The field used to
  /// default to *win*, so a script that never called `Battle::Start`
  /// still took the victory branch.
  none(-1),

  /// 도주 — cm2 `BATTLERESULT_EVADE`.
  evade(0),

  /// 승리 — cm2 `BATTLERESULT_WIN`.
  win(1),

  /// 전멸 — cm2 `BATTLERESULT_LOSE`.
  lose(2);

  const HDBattleResult(this.wire);

  /// Value handed to cm2 by `Battle::Result()`. See the note above.
  final int wire;
}
