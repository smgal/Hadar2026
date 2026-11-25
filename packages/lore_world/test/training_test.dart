import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

const mil = TrainingFacility.military;
const school = TrainingFacility.magicSchool;

void main() {
  group('training cost', () {
    test('military 15 × skill², magic school 10 × skill²', () {
      expect(trainingCost(military: true, currentSkill: 10), 1500);
      expect(trainingCost(military: false, currentSkill: 10), 1000);
      expect(trainingCost(military: true, currentSkill: 49), 15 * 49 * 49);
    });

    test(
      '10 → 50 costs 602,100 at the military school, 401,400 at the magic school',
      () {
        var military = 0;
        var magic = 0;
        for (var s = 10; s < 50; s++) {
          military += trainingCost(military: true, currentSkill: s);
          magic += trainingCost(military: false, currentSkill: s);
        }
        expect(military, 602100);
        expect(magic, 401400);
      },
    );
  });

  group('train', () {
    test(
      'moves experience into the trained total and raises the skill by one',
      () {
        final w = worldWith(fighter(exp: 2000));
        final out = w.train(0, mil, FighterSkill.slash);
        expect(out.ok, isTrue);
        final e = out.first<SkillTrained>()!;
        expect(e.value, 11);
        expect(e.cost, 1500);
        final m = w.protagonist!;
        expect(m.skills[FighterSkill.slash], 11);
        expect(m.exp, 500);
        expect(m.trainedExp, 1500);
      },
    );

    test('experience alone does not raise the level', () {
      final w = worldWith(fighter(exp: 9999999));
      expect(w.protagonist!.level, 1);
      expect(levelForTrainedExp(w.protagonist!.trainedExp), 1);
    });

    test('refuses when experience is short and says by how much', () {
      final w = worldWith(fighter(exp: 1499));
      final out = w.train(0, mil, FighterSkill.slash);
      expect(out.reason, RefusalReason.notEnoughExp);
      expect(out.refusal!.amount, 1);
      expect(w.protagonist!.skills[FighterSkill.slash], 10);
      expect(w.protagonist!.exp, 1499);
    });

    test('a field at its cap has nothing more to teach', () {
      final w = worldWith(
        fighter(skills: [50, 10, 10, 10, 10, 10], exp: 99999999),
      );
      expect(
        w.train(0, mil, FighterSkill.slash).reason,
        RefusalReason.skillAtCap,
      );
    });

    test('a field with cap 0 does not fit the class', () {
      // 검사는 찍는·찌르는·쏘는 무기를 수련할 수 없다.
      final w = worldWith(
        fighter(
          classId: ClassId.swordsman,
          skills: [40, 0, 0, 0, 0, 0],
          exp: 99999999,
        ),
      );
      for (final s in [
        FighterSkill.chop,
        FighterSkill.pierce,
        FighterSkill.shoot,
      ]) {
        expect(w.train(0, mil, s).reason, RefusalReason.skillNotForClass);
      }
      expect(w.train(0, mil, FighterSkill.shield).ok, isTrue);
    });

    test('the cap stops training exactly at the table value', () {
      final w = worldWith(
        fighter(
          classId: ClassId.swordsman,
          skills: [40, 0, 0, 0, 29, 0],
          exp: 99999999,
        ),
      );
      expect(w.train(0, mil, FighterSkill.shield).ok, isTrue);
      expect(w.protagonist!.skills[FighterSkill.shield], 30);
      expect(
        w.train(0, mil, FighterSkill.shield).reason,
        RefusalReason.skillAtCap,
      );
    });

    test('the facility must match the family', () {
      final w = worldWith(fighter(exp: 99999));
      w.join(mage(exp: 99999));
      expect(w.train(0, school, 0).reason, RefusalReason.notMageFamily);
      expect(w.train(1, mil, 0).reason, RefusalReason.notFighterFamily);
      expect(w.train(1, school, MageSkill.attack).ok, isTrue);
      expect(w.facilityFor(0), mil);
      expect(w.facilityFor(1), school);
      expect(w.facilityFor(3), isNull);
    });

    test('a paladin trains cure in the second slot, at the military rate', () {
      final w = worldWith(
        fighter(
          classId: ClassId.paladin,
          skills: [25, 10, 5, 0, 20, 10],
          exp: 1500,
        ),
      );
      final out = w.train(0, mil, FighterSkill.chop);
      expect(out.ok, isTrue);
      expect(out.first<SkillTrained>()!.cost, 1500);
      expect(w.protagonist!.cureSkill, 11);
      expect(w.trainingOptions(0)[1].skillKey, 'skill.cure');
    });

    test('an empty seat is refused, not thrown at', () {
      final w = worldWith(fighter());
      expect(w.train(3, mil, 0).reason, RefusalReason.noSuchMember);
      expect(w.train(0, mil, 9).reason, RefusalReason.invalidAmount);
    });

    test('Part 1 locks ESP training until the story unlocks it', () {
      final w = worldWith(mage(exp: 99999), episode: Episode.ep1);
      expect(w.espTrainingUnlocked, isFalse);
      expect(
        w.train(0, school, MageSkill.esp).reason,
        RefusalReason.espTrainingLocked,
      );
      w.espTrainingUnlocked = true;
      expect(w.train(0, school, MageSkill.esp).ok, isTrue);
      expect(worldWith(mage()).espTrainingUnlocked, isTrue);
    });

    test('training options show what the screen needs', () {
      final w = worldWith(
        fighter(
          classId: ClassId.knight,
          skills: [10, 10, 5, 0, 60, 0],
          exp: 100,
        ),
      );
      final o = w.trainingOptions(0);
      expect(o.length, 6);
      expect(o[0].cap, 60);
      expect(o[0].cost, 1500);
      expect(o[0].blocked, RefusalReason.notEnoughExp);
      expect(o[3].forClass, isFalse);
      expect(o[3].blocked, RefusalReason.skillNotForClass);
      expect(o[4].blocked, RefusalReason.skillAtCap);
      // 현재 기술치 0 → 비용 0.
      expect(o[5].cost, 0);
      expect(o[5].blocked, isNull);
    });
  });

  group('all courses completed', () {
    test('visiting dumps every remaining point into the trained total', () {
      final w = worldWith(
        fighter(
          classId: ClassId.monk,
          skills: [0, 0, 0, 0, 0, 100],
          exp: 123456,
          trainedExp: 1000,
        ),
      );
      expect(w.allCoursesCompleted(0), isTrue);
      final out = w.visitSchool(0, mil);
      expect(out.first<AllCoursesCompleted>()!.expMoved, 123456);
      expect(w.protagonist!.exp, 0);
      expect(w.protagonist!.trainedExp, 124456);
    });

    test('one field short of its cap and nothing is dumped', () {
      final w = worldWith(
        fighter(classId: ClassId.monk, skills: [0, 0, 0, 0, 0, 99], exp: 500),
      );
      expect(w.allCoursesCompleted(0), isFalse);
      final out = w.visitSchool(0, mil);
      expect(out.ok, isTrue);
      expect(out.events, isEmpty);
      expect(w.protagonist!.exp, 500);
    });

    test('the wrong school does not dump either', () {
      final w = worldWith(
        fighter(classId: ClassId.monk, skills: [0, 0, 0, 0, 0, 100], exp: 500),
      );
      expect(w.visitSchool(0, school).reason, RefusalReason.notMageFamily);
      expect(w.protagonist!.exp, 500);
    });
  });

  group('class change', () {
    Member swordsmanToBe() => fighter(skills: [40, 10, 10, 10, 10, 10]);

    test('costs 10000 gold and stays inside the family', () {
      final w = worldWith(swordsmanToBe())..gold = 10000;
      final out = w.changeClass(0, mil, ClassId.swordsman);
      expect(out.ok, isTrue);
      final e = out.first<ClassChanged>()!;
      expect(e.from, ClassId.fighter);
      expect(e.to, ClassId.swordsman);
      expect(w.gold, 0);
      expect(w.protagonist!.classId, ClassId.swordsman);
    });

    test('without the fee nothing happens', () {
      final w = worldWith(swordsmanToBe())..gold = 9999;
      final out = w.changeClass(0, mil, ClassId.swordsman);
      expect(out.reason, RefusalReason.notEnoughGoldForClassChange);
      expect(out.refusal!.amount, 1);
      expect(w.protagonist!.classId, ClassId.fighter);
      expect(w.gold, 9999);
    });

    test('the requirement must be met', () {
      final w = worldWith(fighter())..gold = 50000;
      expect(
        w.changeClass(0, mil, ClassId.swordsman).reason,
        RefusalReason.classRequirementNotMet,
      );
      expect(w.classChangeOptions(0), [ClassId.fighter]);
      expect(w.gold, 50000);
    });

    test('fighters cannot become mages and the other way round', () {
      final w = worldWith(fighter())..gold = 50000;
      w.join(mage());
      expect(
        w.changeClass(0, school, ClassId.mage).reason,
        RefusalReason.notMageFamily,
      );
      expect(
        w.changeClass(1, mil, ClassId.fighter).reason,
        RefusalReason.notFighterFamily,
      );
    });

    test('the same class and the story-only classes are refused', () {
      final w = worldWith(fighter())..gold = 50000;
      expect(
        w.changeClass(0, mil, ClassId.fighter).reason,
        RefusalReason.alreadyThatClass,
      );
      expect(
        w.changeClass(0, mil, ClassId.demigod).reason,
        RefusalReason.classNotSelectable,
      );
      expect(
        w.changeClass(0, mil, 77).reason,
        RefusalReason.classNotSelectable,
      );
    });

    test('a paladin who leaves the class loses the magic points', () {
      final m = fighter(
        classId: ClassId.paladin,
        level: 4,
        skills: [25, 10, 10, 10, 20, 10],
      );
      expect(m.mp, 200);
      final w = worldWith(m)..gold = 10000;
      expect(w.changeClass(0, mil, ClassId.fighter).ok, isTrue);
      expect(m.maxMp, 0);
      expect(m.mp, 0);
    });

    test('becoming a paladin gives a pool but does not fill it', () {
      final m = fighter(level: 4, skills: [25, 10, 10, 10, 20, 10]);
      final w = worldWith(m)..gold = 10000;
      expect(w.changeClass(0, mil, ClassId.paladin).ok, isTrue);
      expect(m.maxMp, 200);
      expect(m.mp, 0);
    });

    test('equipment is re-read against the new class', () {
      final m = fighter(
        skills: [40, 10, 10, 10, 10, 10],
        weapon: 'weapon.scimitar',
      )..shield = 'shield.leather';
      final w = worldWith(m)..gold = 20000;
      expect(m.weaponPower, 45);
      w.changeClass(0, mil, ClassId.swordsman);
      expect(m.weaponPower, 50);
      expect(m.shieldPower, 1);
    });

    test('the change clears armour damage (the original recomputed AC)', () {
      final m = fighter(
        skills: [40, 10, 10, 10, 10, 10],
        armour: 'armour.plate',
      )..acPenalty = 3;
      final w = worldWith(m)..gold = 10000;
      expect(m.ac, 7);
      w.changeClass(0, mil, ClassId.swordsman);
      expect(m.ac, 10);
    });

    test('a mage climbs to wizard once the skills are there', () {
      final m = mage(skills: [40, 25, 25, 0, 0, 0]);
      final w = worldWith(m)..gold = 10000;
      expect(w.classChangeOptions(0), contains(ClassId.wizard));
      expect(w.changeClass(0, school, ClassId.wizard).ok, isTrue);
      expect(m.classDef!.key, 'class.wizard');
    });
  });

  group('experience training ground', () {
    test('10000 gold buys 10000 experience each and one hour', () {
      final w = worldWith(fighter())..gold = 35000;
      w.join(mage());
      final before = w.calendar.hour;
      final out = w.buyExpTraining(3);
      expect(out.ok, isTrue);
      final e = out.first<ExpTrained>()!;
      expect(e.seats, [0, 1]);
      expect(e.expEach, 30000);
      expect(e.hours, 3);
      expect(w.gold, 5000);
      expect(w.protagonist!.exp, 30000);
      expect(w.member(1)!.exp, 30000);
      expect(w.calendar.hour, before + 3);
    });

    test('it is unspent experience — the level does not move', () {
      final w = worldWith(fighter())..gold = 100000;
      w.buyExpTraining(10);
      expect(w.protagonist!.trainedExp, 0);
      expect(w.protagonist!.level, 1);
    });

    test('members who cannot act and the assistant get nothing', () {
      final w = worldWith(fighter())..gold = 10000;
      w.join(mage()..unconscious = 3);
      w.setAssistant(fighter(name: 'Aide'));
      w.buyExpTraining(1);
      expect(w.member(1)!.exp, 0);
      expect(w.assistant!.exp, 0);
    });

    test('refuses a bad amount and an empty purse', () {
      final w = worldWith(fighter())..gold = 9999;
      expect(w.buyExpTraining(0).reason, RefusalReason.invalidAmount);
      expect(w.buyExpTraining(11).reason, RefusalReason.invalidAmount);
      expect(w.buyExpTraining(1).reason, RefusalReason.notEnoughGold);
      expect(w.gold, 9999);
    });
  });

  group('class table', () {
    test('fourteen selectable classes, seven per family', () {
      expect(selectableClasses(Family.fighter).map((c) => c.id), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
      expect(selectableClasses(Family.mage).map((c) => c.id), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
    });

    test('requirements never exceed caps where the field is trainable', () {
      for (final c in classTable) {
        for (var i = 0; i < 6; i++) {
          if (c.caps[i] == 0) continue;
          expect(
            c.requirements[i],
            lessThanOrEqualTo(c.caps[i]),
            reason: c.key,
          );
        }
      }
    });

    test('rows match chapter 7.3', () {
      final knight = classOf(Family.fighter, ClassId.knight)!;
      expect(knight.requirements, [10, 10, 5, 0, 20, 0]);
      expect(knight.caps, [60, 60, 50, 0, 60, 50]);
      final timewalker = classOf(Family.mage, ClassId.timewalker)!;
      expect(timewalker.requirements, [40, 40, 40, 20, 20, 20]);
      expect(timewalker.caps, [70, 100, 70, 50, 100, 100]);
      final paladin = classOf(Family.fighter, ClassId.paladin)!;
      expect(paladin.weapons.contains(WeaponKind.chop), isFalse);
      expect(paladin.shield, isTrue);
    });

    test('weapon permissions match the circle table', () {
      Set<WeaponKind> of(int id) => classOf(Family.fighter, id)!.weapons;
      const s = WeaponKind.slash;
      const c = WeaponKind.chop;
      const p = WeaponKind.pierce;
      const a = WeaponKind.shoot;
      expect(of(ClassId.fighter), {s, c, p, a});
      expect(of(ClassId.knight), {s, c, p});
      expect(of(ClassId.swordsman), {s});
      expect(of(ClassId.hunter), {c, p, a});
      expect(of(ClassId.monk), isEmpty);
      expect(of(ClassId.assassin), {s, p, a});
      expect(of(ClassId.paladin), {s, p, a});
    });
  });
}
