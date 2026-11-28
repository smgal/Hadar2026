import 'dart:convert';
import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

/// 온갖 것이 들어 있는 세계 하나.
LoreWorld busyWorld() {
  final w = LoreWorld.newGame(Episode.ep3, fighter(name: 'Hero', level: 4))
    ..gold = 123456
    ..food = 77
    ..arrows = 4321
    ..setTorch(9);
  w.join(rosterEp3['canopus']!.build());
  w.join(rosterEp3['vega']!.build()..hidden = true);
  w.join(
    rosterEp3['pollux']!.build()
      ..poison = 3
      ..unconscious = 2
      ..dead = 1
      ..acPenalty = 1
      ..exp = 999
      ..trainedExp = 54321,
  );
  w.give(CrystalKey.summon, 3);
  w.useCrystal(CrystalKey.summon, rng: Random(3));
  w.give(ItemKey.hpPotion, 5);
  w.give(ItemKey.warpOrb, 2);
  w.give(CrystalKey.ball);
  w.give('weapon.long_sword', 3);
  w.give('armour.obsidian');
  w.buffs
    ..grant(FieldBuff.levitation)
    ..swampWalk = 12
    ..mindReadSteps = 2;
  w.options
    ..encounterTendency = 5
    ..maxEnemies = 8
    ..attackUnconscious = false
    ..restHours = 11;
  w.calendar.advance(days: 40, hours: 3, minutes: 7, seconds: 5);
  w.espTrainingUnlocked = false;
  return w;
}

void main() {
  test('the save carries a version', () {
    expect(busyWorld().toJson()['version'], loreSaveVersion);
    expect(loreSaveVersion, 1);
  });

  test('a world survives the round trip unchanged', () {
    final before = busyWorld();
    final after = LoreWorld.fromJson(before.toJson());
    expect(after.toJson(), before.toJson());
  });

  test('it survives being written as text too', () {
    final before = busyWorld();
    final text = jsonEncode(before.toJson());
    final result = LoreWorld.load(jsonDecode(text));
    expect(result.isClean, isTrue);
    expect(jsonEncode(result.world.toJson()), text);
  });

  test('every field of the world comes back', () {
    final w = LoreWorld.fromJson(busyWorld().toJson());
    expect(w.episode, Episode.ep3);
    expect([w.gold, w.food, w.arrows, w.torch], [123456, 77, 4321, 9]);
    expect(w.countOf(ItemKey.hpPotion), 5);
    expect(w.countOf(ItemKey.warpOrb), 2);
    expect(w.countOf(CrystalKey.summon), 2);
    expect(w.countOf(CrystalKey.ball), 1);
    expect(w.countOf('weapon.long_sword'), 3);
    expect(w.countOf('armour.obsidian'), 1);
    expect(w.buffs.levitation, 255);
    expect(w.buffs.swampWalk, 12);
    expect(w.buffs.waterWalk, 0);
    expect(w.buffs.mindReadSteps, 2);
    expect(w.options.encounterTendency, 5);
    expect(w.options.maxEnemies, 8);
    expect(w.options.attackUnconscious, isFalse);
    expect(w.options.restHours, 11);
    expect(w.calendar.toString(), '674-1-7 19:07:05');
    expect(w.espTrainingUnlocked, isFalse);
    expect(w.specialMagicUnlocked, isTrue);
  });

  test('every field of a member comes back', () {
    final w = LoreWorld.fromJson(busyWorld().toJson());
    final hero = w.protagonist!;
    expect(hero.name, 'Hero');
    expect(hero.level, 4);

    final pollux = w.seats[3]!;
    expect(pollux.rosterKey, 'pollux');
    expect(pollux.nameKey, 'companion.pollux');
    expect(pollux.gender, Gender.female);
    expect(pollux.family, Family.fighter);
    expect(pollux.classId, ClassId.assassin);
    expect(pollux.abilities, [15, 19, 20, 11, 18, 20, 17, 10]);
    expect(pollux.skills, [10, 0, 35, 10, 0, 20]);
    expect([pollux.poison, pollux.unconscious, pollux.dead], [3, 2, 1]);
    expect([pollux.exp, pollux.trainedExp], [999, 54321]);
    expect(
      [pollux.weapon, pollux.shield, pollux.armour],
      ['weapon.rapier', null, 'armour.leather'],
    );
    expect(pollux.acPenalty, 1);
    expect(pollux.hp, 1);

    // 숨겨진 동료는 데이터와 함께 숨김 표시도 돌아온다.
    expect(w.seats[2]!.hidden, isTrue);
    expect(w.member(2), isNull);

    final summoned = w.assistant!;
    expect(summoned.level, 30);
    expect(summoned.mindControlImmune, isTrue);
    expect(summoned.naturalWeapon, isNotNull);
    expect(summoned.weaponKind, WeaponKind.special);
    expect(summoned.weaponPower, anyOf(255, 150, 200));
  });

  test('derived values are not in the save', () {
    final text = jsonEncode(busyWorld().toJson());
    for (final derived in [
      'maxHp',
      'maxMp',
      '"ac"',
      'weaponPower',
      'shieldPower',
      'armourPower',
      'weaponKind',
      'condition',
      'canAct',
    ]) {
      expect(text.contains(derived), isFalse, reason: derived);
    }
  });

  test('an attack-mode override survives', () {
    final w = worldWith(fighter());
    w.setAssistant(buildSummon(summonPools[0][0], skill: 50, rng: Random(1)));
    expect(w.assistant!.family, Family.elemental);
    final back = LoreWorld.fromJson(w.toJson());
    expect(back.assistant!.attackMode, AttackMode.single);
  });

  test('a copy is independent', () {
    final a = busyWorld();
    final b = a.copy();
    b.protagonist!.hp = 1;
    b.gold = 0;
    b.give(ItemKey.hpPotion, 9);
    expect(a.protagonist!.hp, isNot(1));
    expect(a.gold, 123456);
    expect(a.countOf(ItemKey.hpPotion), 5);
  });

  group('loading never throws', () {
    test('something that is not a map', () {
      final r = LoreWorld.load('nonsense');
      expect(r.issues.single.kind, LoadIssueKind.notAMap);
      expect(r.world.presentSeats, isEmpty);
      expect(LoreWorld.load(null).issues.single.kind, LoadIssueKind.notAMap);
    });

    test('an empty map gives a usable default world', () {
      final r = LoreWorld.load(<String, Object?>{});
      expect(r.isClean, isTrue);
      expect(r.world.episode, Episode.ep3);
      expect(r.world.options.encounterTendency, 2);
      expect(r.world.calendar.toString(), '673-11-27 16:00:00');
    });

    test('a newer version and an unknown episode are reported', () {
      final r = LoreWorld.load({'version': 99, 'episode': 7});
      expect(r.issues.map((i) => i.kind), [
        LoadIssueKind.newerVersion,
        LoadIssueKind.unknownEpisode,
      ]);
      expect(r.world.episode, Episode.ep3);
    });

    test('items this build does not know are dropped and named', () {
      final json = busyWorld().toJson();
      (json['consumables']! as Map)['item.future_thing'] = 3;
      (json['backpack']! as Map)['weapon.laser'] = 1;
      final r = LoreWorld.load(json);
      expect(r.issues.map((i) => i.key), ['item.future_thing', 'weapon.laser']);
      expect(
        r.issues.every((i) => i.kind == LoadIssueKind.unknownItem),
        isTrue,
      );
      expect(r.world.countOf('item.future_thing'), 0);
      expect(r.world.countOf(ItemKey.hpPotion), 5);
    });

    test(
      'equipment this build does not know empties the slot and is named',
      () {
        final json = busyWorld().toJson();
        ((json['seats']! as List)[0]! as Map)['weapon'] = 'weapon.laser';
        final r = LoreWorld.load(json);
        expect(r.issues.single.kind, LoadIssueKind.unknownEquipment);
        expect(r.issues.single.seat, 0);
        expect(r.issues.single.key, 'weapon.laser');
        expect(r.world.protagonist!.weapon, isNull);
      },
    );

    test('garbage in fields falls back instead of throwing', () {
      final r = LoreWorld.load({
        'gold': 'lots',
        'food': 9999,
        'arrows': -5,
        'seats': [
          {
            'name': 5,
            'abilities': 'x',
            'skills': [1, 'two'],
            'level': null,
          },
          'not a member',
        ],
        'calendar': {'month': 99, 'hour': -3},
        'options': {'encounterTendency': 50, 'maxEnemies': 0},
        'buffs': 7,
      });
      final w = r.world;
      expect(w.gold, 0);
      expect(w.food, 255);
      expect(w.arrows, 0);
      expect(w.seats[0]!.abilities, List.filled(8, 0));
      expect(w.seats[0]!.skills, [1, 0, 0, 0, 0, 0]);
      expect(w.seats[0]!.level, 1);
      expect(w.seats[1], isNull);
      expect(w.calendar.month, 12);
      expect(w.calendar.hour, 0);
      expect(w.options.encounterTendency, 5);
      expect(w.options.maxEnemies, 3);
    });
  });
}
