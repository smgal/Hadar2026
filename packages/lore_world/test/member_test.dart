import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('max HP and MP', () {
    test('max HP = endurance × level × 10', () {
      final m = fighter(level: 7, abilities: [10, 10, 10, 13, 10, 10, 10, 10]);
      expect(m.maxHp, 13 * 7 * 10);
    });

    test('a mage has mentality × level × 10', () {
      final m = mage(level: 4, abilities: [10, 17, 10, 10, 10, 10, 10, 10]);
      expect(m.maxMp, 17 * 4 * 10);
    });

    test('a paladin has half of that, other fighters none', () {
      final abilities = [10, 12, 10, 10, 10, 10, 10, 10];
      expect(
        fighter(classId: ClassId.paladin, level: 5, abilities: abilities).maxMp,
        12 * 5 * 5,
      );
      for (final id in [
        ClassId.fighter,
        ClassId.knight,
        ClassId.swordsman,
        ClassId.hunter,
        ClassId.monk,
        ClassId.assassin,
      ]) {
        expect(fighter(classId: id, level: 5, abilities: abilities).maxMp, 0);
      }
    });

    test('levelling up does not refill HP by itself', () {
      final m = fighter();
      expect(m.hp, 100);
      m.level = 2;
      expect(m.maxHp, 200);
      expect(m.hp, 100);
    });
  });

  group('weapon power', () {
    test('bare hands are 5', () {
      final m = fighter();
      expect(m.weaponPower, 5);
      expect(m.weaponKind, WeaponKind.bare);
    });

    test('is read from the column of the class', () {
      // 신월도: 투사 45 · 기사 48 · 검사 50 · 암살자 40 · 전사 40.
      expect(fighter(weapon: 'weapon.scimitar').weaponPower, 45);
      expect(
        fighter(classId: ClassId.knight, weapon: 'weapon.scimitar').weaponPower,
        48,
      );
      expect(
        fighter(
          classId: ClassId.swordsman,
          weapon: 'weapon.scimitar',
        ).weaponPower,
        50,
      );
      expect(
        fighter(
          classId: ClassId.assassin,
          weapon: 'weapon.scimitar',
        ).weaponPower,
        40,
      );
      expect(
        fighter(
          classId: ClassId.paladin,
          weapon: 'weapon.scimitar',
        ).weaponPower,
        40,
      );
    });

    test('a weapon the class cannot use is 5, and counts as bare hands', () {
      // 사냥꾼은 베는 무기를 못 쓴다 — 표의 괄호 값(40)은 읽히지 않는다.
      final hunter = fighter(
        classId: ClassId.hunter,
        weapon: 'weapon.scimitar',
      );
      expect(hunter.weaponPower, 5);
      expect(hunter.weaponKind, WeaponKind.bare);
      // 전투승은 어떤 무기도 못 쓴다.
      final monk = fighter(classId: ClassId.monk, weapon: 'weapon.halberd');
      expect(monk.weaponPower, 5);
      // 기사는 쏘는 무기를 못 쓴다.
      expect(
        fighter(classId: ClassId.knight, weapon: 'weapon.bow').weaponPower,
        5,
      );
    });

    test('changes the moment the class changes — nothing is cached', () {
      final m = fighter(weapon: 'weapon.dagger');
      expect(m.weaponPower, 10);
      m.classId = ClassId.hunter;
      expect(m.weaponPower, 25);
      m.classId = ClassId.swordsman;
      expect(m.weaponPower, 5);
    });

    test('bonus classes from the manual are the higher cells', () {
      final sword = weaponByKey('weapon.short_sword')!;
      // 단검은 암살자 +10.
      expect(sword.power[5] - sword.power[0], 10);
      final bow = weaponByKey('weapon.arbalest')!;
      // 아르발레스트는 사냥꾼 85.
      expect(bow.power[3], 85);
    });

    test('mages cannot use any weapon', () {
      final m = mage()..weapon = 'weapon.dagger';
      expect(m.weaponPower, 5);
      expect(m.weaponKind, WeaponKind.bare);
    });

    test('a natural weapon overrides the table and is special', () {
      final m = Member(
        family: Family.unknown,
        abilities: List.filled(8, 10),
        naturalWeapon: 'natural.fangs',
        naturalPower: 90,
      );
      expect(m.weaponPower, 90);
      expect(m.weaponKind, WeaponKind.special);
    });
  });

  group('shield and armour', () {
    test('shield power is the shield number, 0 if unusable', () {
      expect(fighter(shield: 'shield.chromatic').shieldPower, 4);
      expect(
        fighter(
          classId: ClassId.hunter,
          shield: 'shield.chromatic',
        ).shieldPower,
        0,
      );
      expect(fighter().shieldPower, 0);
    });

    test('only fighter, knight, swordsman and paladin use shields', () {
      final users = [
        for (final c in classTable)
          if (c.family == Family.fighter && c.shield && c.selectable) c.id,
      ];
      expect(users, [
        ClassId.fighter,
        ClassId.knight,
        ClassId.swordsman,
        ClassId.paladin,
      ]);
    });

    test('AC = base defence + armour', () {
      expect(fighter().ac, 2);
      expect(fighter(armour: 'armour.plate').ac, 10);
      expect(fighter(armour: 'armour.obsidian').ac, 22);
    });

    test('a mage only gets leather armour', () {
      final m = mage()..armour = 'armour.leather';
      expect(m.ac, 1);
      m.armour = 'armour.ring_mail';
      expect(m.armourPower, 0);
      expect(m.ac, 0);
    });

    test('armour destruction lowers AC but never below zero', () {
      final m = fighter(armour: 'armour.leather')..acPenalty = 2;
      expect(m.ac, 1);
      m.acPenalty = 9;
      expect(m.ac, 0);
    });
  });

  group('condition', () {
    test('shows the gravest one: dead > unconscious > poisoned > good', () {
      final m = fighter();
      expect(m.condition, Condition.good);
      m.poison = 1;
      expect(m.condition, Condition.poisoned);
      m.unconscious = 1;
      expect(m.condition, Condition.unconscious);
      m.dead = 1;
      expect(m.condition, Condition.dead);
    });

    test('can act = conscious, alive and HP above zero', () {
      final m = fighter();
      expect(m.canAct, isTrue);
      m.poison = 5;
      expect(m.canAct, isTrue);
      m.hp = 0;
      expect(m.canAct, isFalse);
      m.hp = 10;
      m.unconscious = 1;
      expect(m.canAct, isFalse);
      m.unconscious = 0;
      m.dead = 1;
      expect(m.canAct, isFalse);
    });
  });

  group('status progression', () {
    test('HP at zero means unconscious', () {
      final m = fighter();
      expect(m.takeDamage(40), DamageResult.hurt);
      expect(m.hp, 60);
      expect(m.takeDamage(60), DamageResult.fellUnconscious);
      expect(m.hp, 0);
      expect(m.unconscious, 1);
      expect(m.dead, 0);
    });

    test('further damage piles onto the unconscious counter', () {
      final m = fighter()
        ..hp = 0
        ..unconscious = 1;
      expect(m.takeDamage(5), DamageResult.deeperUnconscious);
      expect(m.unconscious, 6);
    });

    test('past endurance × level the member dies', () {
      // 인내력 10 · 레벨 1 → 한계 10.
      final m = fighter()
        ..hp = 0
        ..unconscious = 1;
      expect(m.unconsciousLimit, 10);
      expect(m.takeDamage(9), DamageResult.deeperUnconscious);
      expect(m.unconscious, 10);
      expect(m.dead, 0);
      expect(m.takeDamage(1), DamageResult.died);
      expect(m.dead, 1);
    });

    test('the limit grows with level', () {
      final m = fighter(level: 5)
        ..hp = 0
        ..unconscious = 1;
      expect(m.unconsciousLimit, 50);
      m.takeDamage(49);
      expect(m.dead, 0);
      m.takeDamage(1);
      expect(m.dead, 1);
    });

    test('damage to the dead piles onto the death counter, up to a cap', () {
      final m = fighter()..dead = 1;
      expect(m.takeDamage(500), DamageResult.deeperDead);
      expect(m.dead, 501);
      expect(m.takeDamage(40000, deadCap: 30000), DamageResult.deeperDead);
      expect(m.dead, 30000);
      expect(m.takeDamage(1, deadCap: 30000), DamageResult.none);
      expect(m.dead, 30000);
    });

    test('zero or negative damage does nothing', () {
      final m = fighter();
      expect(m.takeDamage(0), DamageResult.none);
      expect(m.takeDamage(-5), DamageResult.none);
      expect(m.hp, 100);
    });
  });

  group('healing primitives', () {
    test('revive brings back as unconscious, counter within 1..limit', () {
      final m = fighter()
        ..hp = 0
        ..unconscious = 40
        ..dead = 7;
      expect(m.revive(), isTrue);
      expect(m.dead, 0);
      expect(m.unconscious, 10);
      expect(m.condition, Condition.unconscious);

      final n = fighter()
        ..hp = 0
        ..dead = 3;
      n.revive();
      expect(n.unconscious, 1);
      expect(n.revive(), isFalse);
    });

    test('awaken leaves at least 1 HP', () {
      final m = fighter()
        ..hp = 0
        ..unconscious = 4;
      expect(m.awaken(), isTrue);
      expect(m.hp, 1);
      expect(m.canAct, isTrue);
      expect(m.awaken(), isFalse);
    });

    test('heal stops at the maximum and reports what it gave', () {
      final m = fighter()..hp = 70;
      expect(m.healHp(1000), 30);
      expect(m.hp, 100);
      expect(m.healHp(10), 0);
    });
  });

  group('attack mode of an assistant', () {
    test('follows the family', () {
      Member of(Family f) => Member(family: f, abilities: List.filled(8, 10));
      expect(of(Family.unknown).attackMode, AttackMode.single);
      expect(of(Family.giant).attackMode, AttackMode.single);
      expect(of(Family.dragon).attackMode, AttackMode.single);
      expect(of(Family.fighter).attackMode, AttackMode.single);
      expect(of(Family.golem).attackMode, AttackMode.all);
      expect(of(Family.mage).attackMode, AttackMode.all);
      expect(of(Family.elemental).attackMode, AttackMode.all);
    });

    test('can be overridden — the fire spirit strikes one', () {
      final m = Member(
        family: Family.elemental,
        abilities: List.filled(8, 10),
        attackModeOverride: AttackMode.single,
      );
      expect(m.attackMode, AttackMode.single);
    });
  });
}
