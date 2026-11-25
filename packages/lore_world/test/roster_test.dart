import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

void main() {
  group('Part 3 roster', () {
    test('the keys map scripts already use', () {
      expect(rosterEp3.keys.toList(), [
        'canopus',
        'alcor',
        'mizar',
        'antares_jr',
        'pollux',
        'altair',
        'vega',
        'algol',
        'proxima',
        'denebola',
        'capella',
        'becrux',
        'draco_prisoner',
      ]);
    });

    test('every member remembers the key it was built from', () {
      for (final e in rosterEp3.values) {
        final m = e.build();
        expect(m.rosterKey, e.key);
        expect(m.nameKey, 'companion.${e.key}');
        expect(m.name, isEmpty);
      }
    });

    test('build makes a fresh member each time', () {
      final a = rosterEp3['canopus']!.build();
      final b = rosterEp3['canopus']!.build();
      a.hp = 1;
      a.skills[0] = 99;
      expect(b.hp, isNot(1));
      expect(b.skills[0], 20);
    });

    test('class and level from chapter 4.3', () {
      final expected = <String, (Family, int, int, Gender)>{
        'canopus': (Family.fighter, ClassId.paladin, 5, Gender.male),
        'alcor': (Family.fighter, ClassId.swordsman, 2, Gender.male),
        'mizar': (Family.fighter, ClassId.knight, 2, Gender.male),
        'antares_jr': (Family.mage, ClassId.wizard, 15, Gender.male),
        'pollux': (Family.fighter, ClassId.assassin, 5, Gender.female),
        'altair': (Family.fighter, ClassId.fighter, 3, Gender.male),
        'vega': (Family.mage, ClassId.conjurer, 4, Gender.female),
        'algol': (Family.mage, ClassId.sorcerer, 3, Gender.male),
        'proxima': (Family.fighter, ClassId.hunter, 4, Gender.male),
        'denebola': (Family.fighter, ClassId.monk, 10, Gender.male),
        'capella': (Family.mage, ClassId.mage, 2, Gender.female),
        'becrux': (Family.mage, ClassId.mage, 9, Gender.male),
      };
      for (final e in expected.entries) {
        final m = rosterEp3[e.key]!.build();
        expect(
          (m.family, m.classId, m.level, m.gender),
          e.value,
          reason: e.key,
        );
      }
    });

    test(
      'join state: HP full, MP 0, no unspent experience, trained = level',
      () {
        for (final e in rosterEp3.values) {
          if (e.seat == RosterSeat.assistant) continue;
          final m = e.build();
          if (e.key != 'pollux') expect(m.hp, m.maxHp, reason: e.key);
          expect(m.mp, 0, reason: e.key);
          expect(m.exp, 0, reason: e.key);
          expect(m.trainedExp, trainedExpForLevel(m.level), reason: e.key);
          expect(levelForTrainedExp(m.trainedExp), m.level, reason: e.key);
        }
      },
    );

    test('Pollux joins with 1 HP', () {
      final m = rosterEp3['pollux']!.build();
      expect(m.hp, 1);
      expect(m.maxHp, 11 * 5 * 10);
      expect(m.weapon, 'weapon.rapier');
      expect(m.weaponPower, 40);
    });

    test('Canopus: abilities, cure skill in the second slot, bare hands', () {
      final m = rosterEp3['canopus']!.build();
      expect(m.abilities, [19, 6, 4, 18, 17, 20, 17, 12]);
      expect(m.skills, [20, 10, 5, 0, 50, 10]);
      expect(m.cureSkill, 10);
      expect(m.weapon, isNull);
      expect(m.ac, 2);
      expect(m.maxHp, 900);
      expect(m.maxMp, 6 * 5 * 5);
    });

    test('equipment and base defence as listed', () {
      final mizar = rosterEp3['mizar']!.build();
      expect(
        [mizar.weapon, mizar.shield, mizar.armour],
        ['weapon.gladius', 'shield.leather', 'armour.ring_mail'],
      );
      expect(mizar.weaponPower, 30);
      expect(mizar.shieldPower, 1);
      expect(mizar.ac, 4);

      final altair = rosterEp3['altair']!.build();
      expect(altair.weaponPower, 35);
      expect(altair.shieldPower, 2);

      final proxima = rosterEp3['proxima']!.build();
      expect(proxima.baseAc, 1);
      expect(proxima.weaponPower, 55);
      expect(proxima.weaponKind, WeaponKind.shoot);

      final denebola = rosterEp3['denebola']!.build();
      expect(denebola.ac, 6);
      expect(denebola.weaponKind, WeaponKind.bare);

      expect(rosterEp3['becrux']!.build().ac, 2);
      expect(rosterEp3['capella']!.build().ac, 0);
    });

    test('Antares Jr. wears ring mail that does nothing for a mage', () {
      final m = rosterEp3['antares_jr']!.build();
      expect(m.armour, 'armour.ring_mail');
      expect(m.ac, 0);
      expect(m.skills, [60, 30, 30, 0, 0, 0]);
    });

    test(
      'three companions fall short of their class requirement, as the data says',
      () {
        // 제4장 4.3 의 기술치를 그대로 옮겼다. 원작 데이터가 계급 조건에 못
        // 미치는 사람이 셋 있다 — 카노푸스(전사: 베는 20 < 25), 미자르(기사:
        // 방패 10 < 20), 프록시마(사냥꾼: 찍는 0 < 5). 고치지 않고 이름을 남긴다.
        final short = [
          for (final e in rosterEp3.values)
            if (e.seat == RosterSeat.companion &&
                !e.build().classDef!.meets(e.build().skills))
              e.key,
        ];
        expect(short, ['canopus', 'mizar', 'proxima']);
        expect(rosterEp3['canopus']!.build().skills, [20, 10, 5, 0, 50, 10]);
        expect(rosterEp3['mizar']!.build().skills, [20, 10, 5, 0, 10, 10]);
        expect(rosterEp3['proxima']!.build().skills, [0, 0, 10, 40, 0, 10]);
      },
    );

    test('the draco prisoner is an assistant converted from enemy No.48', () {
      final e = rosterEp3['draco_prisoner']!;
      expect(e.seat, RosterSeat.assistant);
      final m = e.build();
      expect(m.rosterKey, 'draco_prisoner');
      expect(m.family, Family.unknown);
      expect(m.level, 12);
      expect(m.abilities, [30, 20, 0, 30, 20, 18, 18, 10]);
      expect(m.hp, 3600);
      expect(m.ac, 4);
      expect(m.weaponPower, 34);
    });

    test('asking whether Canopus is in the party', () {
      final w = LoreWorld.newGame(
        Episode.ep3,
        Member(
          name: 'Hero',
          family: Family.fighter,
          classId: 1,
          abilities: List.filled(8, 10),
        )..hp = 100,
      );
      expect(w.hasRosterMember('canopus'), isFalse);
      w.join(rosterEp3['canopus']!.build());
      w.setAssistant(rosterEp3['draco_prisoner']!.build());
      expect(w.hasRosterMember('canopus'), isTrue);
      expect(w.seatOfRoster('canopus'), 1);
      expect(w.seatOfRoster('draco_prisoner'), 5);
      w.hideCompanions();
      expect(w.hasRosterMember('canopus'), isFalse);
      expect(w.hasRosterMember('canopus', includeHidden: true), isTrue);
      w.restoreCompanions();
      w.dismiss(1);
      expect(w.hasRosterMember('canopus', includeHidden: true), isFalse);
    });
  });

  group('Part 1 roster', () {
    test('ten initial companions in the original order', () {
      expect(initialCompanionsEp1.length, 10);
      for (final key in initialCompanionsEp1) {
        expect(rosterEp1.containsKey(key), isTrue, reason: key);
      }
    });

    test('initial companions: level 1, bare, skills at the class minimum', () {
      for (final key in initialCompanionsEp1) {
        final m = rosterEp1[key]!.build();
        expect(m.level, 1, reason: key);
        expect([m.weapon, m.shield, m.armour], [null, null, null], reason: key);
        expect(m.skills, m.classDef!.requirements, reason: key);
        expect(m.hp, m.endurance * 10, reason: key);
        expect(
          m.mp,
          m.family == Family.mage ? m.mentality * 10 : 0,
          reason: key,
        );
        expect(m.trainedExp, 0, reason: key);
      }
    });

    test('abilities and class mapping', () {
      final hercules = rosterEp1['hercules']!.build();
      expect(hercules.abilities, [17, 5, 5, 17, 11, 15, 15, 10]);
      expect(hercules.classId, ClassId.knight);
      final merlin = rosterEp1['merlin']!.build();
      expect(merlin.family, Family.mage);
      expect(merlin.abilities, [11, 19, 14, 5, 5, 7, 18, 15]);
      // 닌자 → 암살자.
      expect(rosterEp1['arcturus']!.build().classId, ClassId.assassin);
      expect(rosterEp1['algol']!.build().gender, Gender.female);
      // 베텔규스는 여성이다(원작자 결정).
      expect(rosterEp1['betelgeuse']!.build().gender, Gender.female);
    });

    test('join characters keep level and state from the original', () {
      final polaris = rosterEp1['polaris']!.build();
      expect(polaris.classId, ClassId.paladin);
      expect(polaris.level, 3);
      expect(polaris.trainedExp, 6000);
      expect(polaris.weapon, 'weapon.long_sword');

      final rigel = rosterEp1['rigel']!.build();
      expect(rigel.hp, 1);
      expect(rigel.trainedExp, 20000);

      final hunter = rosterEp1['lore_hunter']!.build();
      expect(hunter.level, 10);
      expect(hunter.trainedExp, 1050000);
      expect(hunter.hp, 1900);

      final antares = rosterEp1['red_antares']!.build();
      expect(antares.classId, ClassId.archmage);
      expect(antares.hp, 0);
      expect(antares.condition, Condition.unconscious);
      expect(antares.trainedExp, 2700000);
    });

    test('Spica is an esper', () {
      final m = rosterEp1['spica']!.build();
      expect(m.classDef!.key, 'class.esper');
      expect(m.gender, Gender.female);
      expect(m.level, 11);
      expect(m.skills[MageSkill.esp], 55);
      expect(m.trainedExp, 1320000);
    });

    test('assistants', () {
      for (final key in ['mad_joe', 'skeleton', 'draconian']) {
        expect(rosterEp1[key]!.seat, RosterSeat.assistant, reason: key);
        expect(rosterEp1[key]!.build().family, Family.unknown, reason: key);
      }
      final skeleton = rosterEp1['skeleton']!.build();
      expect(skeleton.level, 5);
      expect(skeleton.weaponPower, 20);
      expect(skeleton.ac, 3);
      final draconian = rosterEp1['draconian']!.build();
      expect(draconian.level, 17);
      expect(draconian.weaponPower, 44);
      expect(draconian.ac, 7);
      expect(draconian.trainedExp, 3570000);
      // 미친 조는 맨손이다.
      expect(rosterEp1['mad_joe']!.build().weaponPower, 5);
    });
  });

  group('Part 2 roster', () {
    test('eight companions and two assistants', () {
      expect(rosterEp2.keys.toList(), [
        'hercules',
        'titan',
        'merlin',
        'betelgeuse',
        'mercury',
        'polaris',
        'genius_kie',
        'regulus',
        'mad_joe',
        'death_knight',
      ]);
    });

    test('numbers from chapter 4.2', () {
      final kie = rosterEp2['genius_kie']!.build();
      expect(kie.classId, ClassId.paladin);
      expect(kie.level, 10);
      expect(kie.abilities, [19, 15, 10, 14, 18, 16, 18, 17]);
      expect(kie.skills, [25, 30, 30, 10, 40, 15]);
      expect(kie.weaponPower, 60);
      expect(kie.shieldPower, 4);
      expect(kie.ac, 3 + 6);
      expect(kie.maxMp, 15 * 10 * 5);

      final titan = rosterEp2['titan']!.build();
      expect(titan.classId, ClassId.fighter);
      expect(titan.skills, [10, 10, 10, 10, 10, 10]);

      final polaris = rosterEp2['polaris']!.build();
      expect(polaris.weaponPower, 40);
      expect(polaris.shieldPower, 3);
      expect(polaris.ac, 6);

      expect(rosterEp2['betelgeuse']!.build().gender, Gender.female);
      expect(rosterEp2['regulus']!.build().skills, [0, 0, 0, 0, 0, 50]);
    });

    test('the death knight joins with 1 HP out of 6650', () {
      final m = rosterEp2['death_knight']!.build();
      expect(m.level, 19);
      expect(m.maxHp, 6650);
      expect(m.hp, 1);
      expect(m.weaponPower, 48);
      expect(m.ac, 6);
      expect(m.gender, Gender.neutral);
    });

    test('Mad Joe is of unknown family', () {
      final m = rosterEp2['mad_joe']!.build();
      expect(m.family, Family.unknown);
      expect(m.level, 2);
      expect(m.abilities, [10, 5, 6, 9, 5, 7, 5, 20]);
      expect(m.baseAc, 1);
    });
  });

  test('rosterOf picks the episode', () {
    expect(rosterOf(Episode.ep1), same(rosterEp1));
    expect(rosterOf(Episode.ep2), same(rosterEp2));
    expect(rosterOf(Episode.ep3), same(rosterEp3));
    for (final ep in Episode.values) {
      for (final e in rosterOf(ep).values) {
        expect(e.episode, ep, reason: e.key);
      }
    }
  });
}
