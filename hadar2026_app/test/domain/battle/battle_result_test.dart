import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/battle/battle_result.dart';

void main() {
  group('HDBattleResult.wire', () {
    // assets/const.cm2:53-55 is the authority:
    //   BATTLERESULT_EVADE.assign(0)
    //   BATTLERESULT_WIN.assign(1)
    //   BATTLERESULT_LOSE.assign(2)
    // Dart used to call 0 "Lose" and 2 "Run away", so five shipped
    // scripts read a wipe as an escape. Pin the agreement here, the way
    // tile_action_test.dart pins scriptMode.
    test('matches BATTLERESULT_* in assets/const.cm2', () {
      expect(HDBattleResult.evade.wire, 0);
      expect(HDBattleResult.win.wire, 1);
      expect(HDBattleResult.lose.wire, 2);
    });

    test('none sits outside the cm2 constants', () {
      expect(HDBattleResult.none.wire, -1);
      for (final r in HDBattleResult.values) {
        if (r == HDBattleResult.none) continue;
        expect(r.wire, isNot(HDBattleResult.none.wire));
      }
    });

    test('every wire value is distinct', () {
      final wires = HDBattleResult.values.map((r) => r.wire).toList();
      expect(wires.toSet().length, wires.length);
      expect(wires.length, 4);
    });
  });

}
