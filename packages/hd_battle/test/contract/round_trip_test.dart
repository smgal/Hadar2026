import 'dart:convert';

import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// B1-01: the two handover types survive a JSON round trip, which is
/// what lets a fixture file be both a console demo and a test input.
void main() {
  group('BattleSetup', () {
    test('round-trips through JSON unchanged', () {
      final setup = startingSetup(
        enemyKeys: ['orc', 'orc', 'earth_worm'],
        seed: 424242,
      );
      final decoded = BattleSetup.fromJson(
        jsonDecode(jsonEncode(setup.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.seed, setup.seed);
      expect(decoded.mode, setup.mode);
      expect(decoded.enemyKeys, setup.enemyKeys);
      expect(decoded.party.length, setup.party.length);
      for (var i = 0; i < setup.party.length; i++) {
        expect(decoded.party[i].toJson(), setup.party[i].toJson());
      }
    });

    test('keeps duplicate enemy keys, which the scripts rely on', () {
      // assets/L1_ep1d0.cm2:367-403 registers legacy id 26 (devil_hunter)
      // seven times.
      final setup = startingSetup(enemyKeys: List.filled(7, 'devil_hunter'));
      final decoded = BattleSetup.fromJson(
        jsonDecode(jsonEncode(setup.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.enemyKeys.length, 7);
    });
  });

  group('BattleOutcome', () {
    test('round-trips through JSON unchanged', () {
      const outcome = BattleOutcome(
        resultCode: BattleResultCode.win,
        combatants: [
          CombatantResult(
            slot: 0,
            hp: 91,
            sp: 100,
            esp: 100,
            poison: 0,
            unconscious: 0,
            dead: 0,
            experienceGained: 47,
          ),
          CombatantResult(
            slot: 1,
            hp: -3,
            sp: 100,
            esp: 80,
            poison: 0,
            unconscious: 0,
            dead: 1,
            experienceGained: 20,
          ),
        ],
        goldGained: 25,
        consumedItems: {'potion': 2},
        worldEffects: ['magic_torch'],
      );

      final decoded = BattleOutcome.fromJson(
        jsonDecode(jsonEncode(outcome.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.toJson(), outcome.toJson());
      expect(decoded.resultCode, BattleResultCode.win);
      expect(decoded.combatants[1].hp, -3);
      expect(decoded.consumedItems['potion'], 2);
      expect(decoded.worldEffects, ['magic_torch']);
    });
  });

  group('BattleCommand', () {
    test('every command shape round-trips', () {
      final commands = <BattleCommand>[
        const ChooseAction(0, BattleAction.attack),
        const ChooseAction(0, BattleAction.autoBattle),
        const ChooseEnemyTarget(1, 2),
        const ChooseSpell(1, 19),
        const CancelChoice(3),
      ];
      for (final command in commands) {
        final decoded = BattleCommand.fromJson(
          jsonDecode(jsonEncode(command.toJson())) as Map<String, dynamic>,
        );
        expect(decoded.toJson(), command.toJson());
        expect(decoded.slot, command.slot);
      }
    });
  });

  group('result codes stay pinned to const.cm2', () {
    test('wire values are -1 / 0 / 1 / 2', () {
      // assets/const.cm2:53-55 is the authority. Content compares
      // against these numbers and is not compiled with this package.
      expect(BattleResultCode.none.wire, -1);
      expect(BattleResultCode.evade.wire, 0);
      expect(BattleResultCode.win.wire, 1);
      expect(BattleResultCode.lose.wire, 2);
    });

    test('none matches no CM2 branch', () {
      for (final code in [
        BattleResultCode.evade,
        BattleResultCode.win,
        BattleResultCode.lose,
      ]) {
        expect(BattleResultCode.none.wire, isNot(code.wire));
      }
    });

    test('fromWire is the inverse', () {
      for (final code in BattleResultCode.values) {
        expect(BattleResultCode.fromWire(code.wire), code);
      }
      expect(() => BattleResultCode.fromWire(9), throwsArgumentError);
    });
  });
}
