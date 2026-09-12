import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/party/party.dart';
import 'package:hadar2026_app/domain/party/party_actions.dart';
import 'package:hd_world/hd_world.dart';

Member _makeMember({
  required String name,
  int hp = 100,
  int maxHp = 100,
  int endurance = 10,
  int level0 = 1,
  int level1 = 0,
  int level2 = 0,
  int unconscious = 0,
  int dead = 0,
  int poison = 0,
}) => Member(
  ref: MemberRef(name),
  name: name,
  stats: BaseStats(endurance: endurance),
  levels: Levels(physical: level0, magic: level1, esp: level2),
  baseMaxHitPoints: maxHp,
  hitPoints: hp,
  unconscious: unconscious,
  dead: dead,
  poison: poison,
);

/// 자리 0 에 그 사람을 앉힌다.
///
/// 자리 번호가 곧 신원이라 목록을 갈아 끼우는 대신 자리를 채운다.
Member _seat(HDParty party, Member m, [int index = 0]) {
  party.world = World(
    members: [
      for (var i = 0; i < 6; i++)
        if (i == index) m else Member(ref: MemberRef('seat\$i'), name: ''),
    ],
    pack: party.world.pack,
  );
  return m;
}

void main() {
  group('HDPartyActions.restPlayer', () {
    test('returns noFood when party.food <= 0 and does not heal', () {
      final party = HDParty()..food = 0;
      final p = _makeMember(name: '슴갈', hp: 50);
      // restPlayer needs an actual party member entry — replace slot 0.
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.noFood);
      expect(p.hitPoints, 50, reason: 'no healing without food');
      expect(party.food, 0);
    });

    test('returns alreadyDead and does not heal a dead member', () {
      final party = HDParty()..food = 100;
      final p = _makeMember(name: '슴갈', hp: 0, dead: 1);
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.alreadyDead);
      expect(p.hitPoints, 0);
      expect(party.food, 100, reason: 'dead members do not consume food');
    });

    test('partiallyHealed: HP increases but stays below endurance*level', () {
      final party = HDParty()..food = 10;
      // endurance 10, level0 5 → maxHp = 50; recovery = (5+0+0)*2 = 10
      final p = _makeMember(
        name: '슴갈',
        hp: 30,
        maxHp: 50,
        endurance: 10,
        level0: 5,
      );
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.partiallyHealed);
      expect(p.hitPoints, 40);
      expect(party.food, 9, reason: 'one food consumed when healing');
    });

    test('fullyHealed: HP capped at endurance*level, food consumed', () {
      final party = HDParty()..food = 10;
      // maxHp rule = endurance*level0 = 8*5 = 40; recovery = 10
      final p = _makeMember(
        name: '슴갈',
        hp: 35,
        maxHp: 40,
        endurance: 8,
        level0: 5,
      );
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.fullyHealed);
      expect(p.hitPoints, 40, reason: 'capped at endurance*level0');
      expect(party.food, 9);
    });

    test('fullyHealed at the exact cap consumes no food', () {
      final party = HDParty()..food = 10;
      final p = _makeMember(
        name: '슴갈',
        hp: 40,
        maxHp: 40,
        endurance: 8,
        level0: 5,
      );
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.fullyHealed);
      expect(party.food, 10, reason: 'already at full HP — no food consumed');
    });

    test('poison blocks healing on a conscious member', () {
      final party = HDParty()..food = 10;
      final p = _makeMember(name: '슴갈', hp: 30, poison: 3);
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.poisoned);
      expect(p.hitPoints, 30);
      expect(party.food, 10);
    });

    test('unconscious + poison reports unconsciousPoisoned, no recovery', () {
      final party = HDParty()..food = 10;
      final p = _makeMember(name: '슴갈', hp: 0, unconscious: 5, poison: 3);
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.unconsciousPoisoned);
      expect(p.unconscious, 5, reason: 'poison blocks consciousness recovery');
    });

    test('unconscious without poison ticks down by sum of levels', () {
      final party = HDParty()..food = 10;
      // levels = 2+1+0 = 3; unconscious 5 -> 2 (still out)
      final p = _makeMember(
        name: '슴갈',
        hp: 0,
        unconscious: 5,
        level0: 2,
        level1: 1,
      );
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.unconsciousStillOut);
      expect(p.unconscious, 2);
    });

    test('unconsciousRecovered when ticks reach zero, hp clamped to 1+', () {
      final party = HDParty()..food = 10;
      // levels = 5+5+5 = 15; unconscious 5 → recovered
      final p = _makeMember(
        name: '슴갈',
        hp: 0,
        unconscious: 5,
        level0: 5,
        level1: 5,
        level2: 5,
      );
      _seat(party, p);

      final r = HDPartyActions.restMember(p, party);

      expect(r.outcome, RestOutcome.unconsciousRecovered);
      expect(p.unconscious, 0);
      expect(p.hitPoints, greaterThanOrEqualTo(1));
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
    HDParty seated() {
      final party = HDParty();
      party.world = World(
        members: [
          for (final n in const ['A', 'B', 'C'])
            Member(ref: MemberRef(n), name: n),
          for (var i = 3; i < 6; i++)
            Member(ref: MemberRef('seat$i'), name: ''),
        ],
      );
      return party;
    }

    test('두 자리를 맞바꾼다', () {
      final party = seated();
      HDPartyActions.swapMembers(party, 0, 2);
      expect(party.members[0].name, 'C');
      expect(party.members[2].name, 'A');
      expect(party.members[1].name, 'B', reason: '가운데는 그대로');
      expect(party.members.length, 6, reason: '빈 자리도 남는다');
    });

    test('같은 자리나 범위 밖은 아무것도 하지 않는다', () {
      final party = seated();
      HDPartyActions.swapMembers(party, 1, 1);
      HDPartyActions.swapMembers(party, -1, 0);
      HDPartyActions.swapMembers(party, 0, 99);
      expect([for (final m in party.members.take(3)) m.name], ['A', 'B', 'C']);
    });
  });

  group('HDPartyActions.dismissMember', () {
    test('이름을 비우고 **자리를 옮기지 않는다**', () {
      // 이전 모델은 빈 자리를 뒤로 몰았다. 자리 번호가 곧 신원이라
      // (출하 스크립트가 여섯째 자리를 미리 손본다) 몰면 cm2 가 가리키는
      // 사람이 바뀐다.
      final party = HDParty();
      party.world = World(
        members: [
          for (final n in const ['A', 'B', 'C'])
            Member(ref: MemberRef(n), name: n),
          for (var i = 3; i < 6; i++)
            Member(ref: MemberRef('seat$i'), name: ''),
        ],
      );

      HDPartyActions.dismissMember(party, 1);

      expect(party.members[0].name, 'A');
      expect(party.members[1].isPresent, isFalse, reason: 'B 가 나갔다');
      expect(party.members[2].name, 'C', reason: 'C 는 제자리다');
      expect(party.present.length, 2);
    });

    test('내보낸 사람의 장비는 남지 않는다', () {
      final party = HDParty();
      party.world = World(
        members: [
          Member(
            ref: const MemberRef('A'),
            name: 'A',
            equipment: const {EquipSlot.body: ItemRef('bodyArmour.leather')},
          ),
          Member(ref: const MemberRef('B'), name: 'B'),
        ],
      );
      HDPartyActions.dismissMember(party, 0);
      expect(party.members[0].equipment, isEmpty);
    });
  });
}
