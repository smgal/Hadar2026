import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/party/party.dart';
import 'package:hadar2026_app/domain/party/party_actions.dart';
import 'package:hadar2026_app/domain/party/player.dart';

HDPlayer _makePlayer({
  required String name,
  int order = 0,
  int hp = 100,
  int maxHp = 100,
  int endurance = 10,
  int level0 = 1,
  int level1 = 0,
  int level2 = 0,
  int unconscious = 0,
  int dead = 0,
  int poison = 0,
}) {
  final p = HDPlayer()
    ..name = name
    ..order = order
    ..hp = hp
    ..maxHp = maxHp
    ..endurance = endurance
    ..unconscious = unconscious
    ..dead = dead
    ..poison = poison;
  p.level[0] = level0;
  p.level[1] = level1;
  p.level[2] = level2;
  return p;
}

void main() {
  group('HDPartyActions.restPlayer', () {
    test('returns noFood when party.food <= 0 and does not heal', () {
      final party = HDParty()..food = 0;
      final p = _makePlayer(name: '슴갈', hp: 50);
      // restPlayer needs an actual party member entry — replace slot 0.
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.noFood);
      expect(p.hp, 50, reason: 'no healing without food');
      expect(party.food, 0);
    });

    test('returns alreadyDead and does not heal a dead member', () {
      final party = HDParty()..food = 100;
      final p = _makePlayer(name: '슴갈', hp: 0, dead: 1);
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.alreadyDead);
      expect(p.hp, 0);
      expect(party.food, 100, reason: 'dead members do not consume food');
    });

    test('partiallyHealed: HP increases but stays below endurance*level', () {
      final party = HDParty()..food = 10;
      // endurance 10, level0 5 → maxHp = 50; recovery = (5+0+0)*2 = 10
      final p = _makePlayer(
        name: '슴갈',
        hp: 30,
        maxHp: 50,
        endurance: 10,
        level0: 5,
      );
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.partiallyHealed);
      expect(p.hp, 40);
      expect(party.food, 9, reason: 'one food consumed when healing');
    });

    test('fullyHealed: HP capped at endurance*level, food consumed', () {
      final party = HDParty()..food = 10;
      // maxHp rule = endurance*level0 = 8*5 = 40; recovery = 10
      final p = _makePlayer(
        name: '슴갈',
        hp: 35,
        maxHp: 40,
        endurance: 8,
        level0: 5,
      );
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.fullyHealed);
      expect(p.hp, 40, reason: 'capped at endurance*level0');
      expect(party.food, 9);
    });

    test('fullyHealed at the exact cap consumes no food', () {
      final party = HDParty()..food = 10;
      final p = _makePlayer(
        name: '슴갈',
        hp: 40,
        maxHp: 40,
        endurance: 8,
        level0: 5,
      );
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.fullyHealed);
      expect(party.food, 10, reason: 'already at full HP — no food consumed');
    });

    test('poison blocks healing on a conscious member', () {
      final party = HDParty()..food = 10;
      final p = _makePlayer(name: '슴갈', hp: 30, poison: 3);
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.poisoned);
      expect(p.hp, 30);
      expect(party.food, 10);
    });

    test('unconscious + poison reports unconsciousPoisoned, no recovery', () {
      final party = HDParty()..food = 10;
      final p = _makePlayer(name: '슴갈', hp: 0, unconscious: 5, poison: 3);
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.unconsciousPoisoned);
      expect(p.unconscious, 5, reason: 'poison blocks consciousness recovery');
    });

    test('unconscious without poison ticks down by sum of levels', () {
      final party = HDParty()..food = 10;
      // levels = 2+1+0 = 3; unconscious 5 -> 2 (still out)
      final p = _makePlayer(
        name: '슴갈',
        hp: 0,
        unconscious: 5,
        level0: 2,
        level1: 1,
      );
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.unconsciousStillOut);
      expect(p.unconscious, 2);
    });

    test('unconsciousRecovered when ticks reach zero, hp clamped to 1+', () {
      final party = HDParty()..food = 10;
      // levels = 5+5+5 = 15; unconscious 5 → recovered
      final p = _makePlayer(
        name: '슴갈',
        hp: 0,
        unconscious: 5,
        level0: 5,
        level1: 5,
        level2: 5,
      );
      party.players[0] = p;

      final r = HDPartyActions.restPlayer(p, party);

      expect(r.outcome, RestOutcome.unconsciousRecovered);
      expect(p.unconscious, 0);
      expect(p.hp, greaterThanOrEqualTo(1));
      expect(party.food, 9);
    });
  });

  group('HDPartyActions.applyRestHousekeeping', () {
    test('decrements magicTorch and resets transient buffs', () {
      final party = HDParty()
        ..magicTorch = 3
        ..levitation = 2
        ..walkOnWater = 4
        ..walkOnSwamp = 1
        ..mindControl = 5;

      HDPartyActions.applyRestHousekeeping(party);

      expect(party.magicTorch, 2);
      expect(party.levitation, 0);
      expect(party.walkOnWater, 0);
      expect(party.walkOnSwamp, 0);
      expect(party.mindControl, 0);
    });

    test('does not underflow magicTorch when already zero', () {
      final party = HDParty()..magicTorch = 0;
      HDPartyActions.applyRestHousekeeping(party);
      expect(party.magicTorch, 0);
    });
  });

  group('HDPartyActions.swapMembers', () {
    test('swaps two valid members and renumbers order', () {
      final party = HDParty();
      party.players[0] = _makePlayer(name: 'A', order: 0);
      party.players[1] = _makePlayer(name: 'B', order: 1);
      party.players[2] = _makePlayer(name: 'C', order: 2);

      HDPartyActions.swapMembers(party, 0, 2);

      expect(party.players[0].name, 'C');
      expect(party.players[2].name, 'A');
      // order is reassigned to slot index for everyone.
      for (int i = 0; i < party.players.length; i++) {
        expect(party.players[i].order, i);
      }
    });
  });

  group('HDPartyActions.dismissMember', () {
    test('clears name and pushes the invalid slot to the back', () {
      final party = HDParty();
      party.players[0] = _makePlayer(name: 'A', order: 0);
      party.players[1] = _makePlayer(name: 'B', order: 1);
      party.players[2] = _makePlayer(name: 'C', order: 2);
      // slots 3..5 default invalid (no name).

      HDPartyActions.dismissMember(party, 1); // dismiss B

      expect(party.players[0].name, 'A');
      expect(party.players[1].name, 'C', reason: 'C bubbled up into slot 1');
      // The dismissed (now nameless) slot is at the end.
      expect(party.players.last.isValid(), false);
      // order stays slot-aligned.
      for (int i = 0; i < party.players.length; i++) {
        expect(party.players[i].order, i);
      }
    });
  });
}
