import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

CreationInput input({
  String name = 'Hero',
  Gender gender = Gender.male,
  List<int> answers = const [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  int agility = 14,
  int accuracy = 13,
  int luck = 13,
  List<int> skills = const [10, 10, 10, 10, 10, 10],
  int classId = ClassId.fighter,
}) => CreationInput(
  name: name,
  gender: gender,
  answers: answers,
  agility: agility,
  accuracy: accuracy,
  luck: luck,
  skills: skills,
  classId: classId,
);

void main() {
  group('score table', () {
    test('0→5 1→7 2→11 3→14 4→17 5→19 6→20', () {
      expect(scoreToAbility, [5, 7, 11, 14, 17, 19, 20]);
    });

    test('every pair of abilities shares exactly three questions', () {
      // 다섯에서 셋을 고르는 열 조합이 한 번씩 — 한 능력치는 여섯 질문에 나온다.
      final seen = <String>{};
      for (final q in questionAbilities) {
        expect(q.toSet().length, 3);
        seen.add((q.map((a) => a.index8).toList()..sort()).join());
      }
      expect(seen.length, 10);
      for (final a in Ability.values.take(5)) {
        expect(questionAbilities.where((q) => q.contains(a)).length, 6);
      }
    });

    test('answers map to the ability the table names', () {
      // 전부 1 번: 체력 6, 정신력 3, 집중력 1.
      expect(scoreAnswers(List.filled(10, 1)), [6, 3, 1, 0, 0]);
      // 전부 3 번: 집중력 1, 인내력 3, 저항력 6.
      expect(scoreAnswers(List.filled(10, 3)), [0, 0, 1, 3, 6]);
      // 전부 2 번: 정신력 3, 집중력 4, 인내력 3.
      expect(scoreAnswers(List.filled(10, 2)), [0, 3, 4, 3, 0]);
    });

    test('scores always total ten', () {
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        final answers = [for (var q = 0; q < 10; q++) rng.nextInt(3) + 1];
        final scores = scoreAnswers(answers)!;
        expect(scores.fold<int>(0, (a, b) => a + b), 10);
        expect(scores.every((s) => s >= 0 && s <= 6), isTrue);
      }
    });

    test('bad answers are rejected, not guessed', () {
      expect(scoreAnswers([1, 2, 3]), isNull);
      expect(scoreAnswers([1, 1, 1, 1, 1, 1, 1, 1, 1, 4]), isNull);
      expect(scoreAnswers([0, 1, 1, 1, 1, 1, 1, 1, 1, 1]), isNull);
    });
  });

  group('family', () {
    test('strength against mentality decides first', () {
      expect(
        decideFamily(
          strength: 14,
          mentality: 11,
          concentration: 20,
          endurance: 5,
        ),
        Family.fighter,
      );
      expect(
        decideFamily(
          strength: 11,
          mentality: 14,
          concentration: 5,
          endurance: 20,
        ),
        Family.mage,
      );
    });

    test('a tie falls to endurance against concentration, then to mage', () {
      expect(
        decideFamily(
          strength: 11,
          mentality: 11,
          concentration: 7,
          endurance: 14,
        ),
        Family.fighter,
      );
      expect(
        decideFamily(
          strength: 11,
          mentality: 11,
          concentration: 14,
          endurance: 7,
        ),
        Family.mage,
      );
      expect(
        decideFamily(
          strength: 11,
          mentality: 11,
          concentration: 11,
          endurance: 11,
        ),
        Family.mage,
      );
    });

    test('is judged before the gender bonus', () {
      // 체력 11 · 정신력 11, 인내력 = 집중력 → 마법사. 남성 보너스로 체력이
      // 15 가 되어도 계열은 바뀌지 않는다.
      // 답: Q1=1(체력) Q2=2(정신) Q3=1(체력) Q4=2(집중) Q5=2(집중) Q6=2(인내)
      //     Q7=1(정신) Q8=3(저항) Q9=2(인내) Q10=3(저항)
      final p = previewCreation(
        answers: [1, 2, 1, 2, 2, 2, 1, 3, 2, 3],
        gender: Gender.male,
      )!;
      expect(p.scores, [2, 2, 2, 2, 2]);
      expect(p.baseAbilities, [11, 11, 11, 11, 11]);
      expect(p.family, Family.mage);
      expect(p.abilities[0], 15);
    });
  });

  group('gender bonus', () {
    test('male +4 strength, female +4 mentality', () {
      expect(applyGenderBonus([11, 11, 11, 11, 11], Gender.male), [
        15,
        11,
        11,
        11,
        11,
      ]);
      expect(applyGenderBonus([11, 11, 11, 11, 11], Gender.female), [
        11,
        15,
        11,
        11,
        11,
      ]);
    });

    test('male overflow runs strength → endurance → resistance', () {
      expect(applyGenderBonus([19, 5, 5, 14, 7], Gender.male), [
        20,
        5,
        5,
        17,
        7,
      ]);
      expect(applyGenderBonus([20, 5, 5, 19, 7], Gender.male), [
        20,
        5,
        5,
        20,
        10,
      ]);
    });

    test('female overflow runs mentality → concentration → resistance', () {
      expect(applyGenderBonus([5, 20, 19, 5, 7], Gender.female), [
        5,
        20,
        20,
        5,
        10,
      ]);
    });

    test('what still overflows at the end is lost', () {
      expect(applyGenderBonus([20, 5, 5, 20, 19], Gender.male), [
        20,
        5,
        5,
        20,
        20,
      ]);
    });
  });

  group('class eligibility at creation', () {
    test('a fighter starting at six tens can only be a fighter', () {
      expect(eligibleClassIds(Family.fighter, [10, 10, 10, 10, 10, 10]), [
        ClassId.fighter,
      ]);
    });

    test('every fighter class is reachable with sixty points', () {
      final builds = {
        ClassId.fighter: [10, 10, 10, 10, 10, 10],
        ClassId.knight: [10, 10, 5, 0, 20, 15],
        ClassId.swordsman: [40, 0, 0, 0, 10, 10],
        ClassId.hunter: [0, 5, 5, 40, 0, 10],
        ClassId.monk: [0, 0, 0, 0, 0, 60],
        ClassId.assassin: [20, 0, 0, 20, 0, 20],
        ClassId.paladin: [25, 0, 5, 0, 20, 10],
      };
      for (final e in builds.entries) {
        expect(e.value.fold<int>(0, (a, b) => a + b), 60);
        expect(
          eligibleClassIds(Family.fighter, e.value),
          contains(e.key),
          reason: 'class ${e.key}',
        );
      }
    });

    test('paladin fits exactly — one point off and it is gone', () {
      expect(
        eligibleClassIds(Family.fighter, [25, 0, 5, 0, 20, 10]),
        contains(ClassId.paladin),
      );
      expect(
        eligibleClassIds(Family.fighter, [24, 1, 5, 0, 20, 10]),
        isNot(contains(ClassId.paladin)),
      );
      expect(
        eligibleClassIds(Family.fighter, [25, 0, 5, 1, 19, 10]),
        isNot(contains(ClassId.paladin)),
      );
    });

    test('a mage can only start as mage, conjurer or sorcerer', () {
      // 위저드 이상은 조건의 합이 60 을 넘는다.
      for (final id in [
        ClassId.wizard,
        ClassId.necromancer,
        ClassId.archmage,
        ClassId.timewalker,
      ]) {
        final req = classOf(Family.mage, id)!.requirements;
        expect(req.fold<int>(0, (a, b) => a + b), greaterThan(60));
      }
      expect(eligibleClassIds(Family.mage, [10, 10, 10, 10, 10, 10]), [
        ClassId.mage,
        ClassId.conjurer,
        ClassId.sorcerer,
      ]);
    });

    test('the Part 1 classes are never offered', () {
      expect(
        eligibleClassIds(Family.mage, [100, 100, 100, 100, 100, 100]),
        isNot(contains(ClassId.esper)),
      );
      expect(
        eligibleClassIds(Family.fighter, [100, 100, 100, 100, 100, 100]),
        isNot(contains(ClassId.demigod)),
      );
    });
  });

  group('createCharacter', () {
    test('a male fighter starts as the chapter says', () {
      final r = createCharacter(input());
      expect(r.ok, isTrue);
      final m = r.member!;
      // 전부 1 번 → 체력 6점(20), 정신력 3점(14), 집중력 1점(7), 나머지 5.
      // 남성 +4 는 체력이 이미 20 이라 인내력으로 간다: 5 → 9.
      expect(m.abilities, [20, 14, 7, 9, 5, 14, 13, 13]);
      expect(m.family, Family.fighter);
      expect(m.classId, ClassId.fighter);
      expect(m.level, 1);
      expect(m.hp, 90);
      expect(m.mp, 0);
      expect(m.baseAc, 2);
      expect(m.ac, 2);
      expect(m.weapon, isNull);
      expect(m.weaponPower, 5);
      expect(m.weaponKind, WeaponKind.bare);
      expect(m.exp, 0);
      expect(m.trainedExp, 0);
      expect(m.canAct, isTrue);
    });

    test('a female mage starts with magic points and no base defence', () {
      final r = createCharacter(
        input(
          gender: Gender.female,
          answers: List.filled(10, 2),
          classId: ClassId.conjurer,
        ),
      );
      expect(r.ok, isTrue);
      final m = r.member!;
      // 전부 2 번 → 정신 3(14) 집중 4(17) 인내 3(14), 체력·저항 0(5).
      // 여성 +4 → 정신력 18.
      expect(m.abilities.sublist(0, 5), [5, 18, 17, 14, 5]);
      expect(m.family, Family.mage);
      expect(m.hp, 140);
      expect(m.mp, 180);
      expect(m.baseAc, 0);
    });

    test('a paladin starts with no magic points', () {
      final r = createCharacter(
        input(skills: [25, 0, 5, 0, 20, 10], classId: ClassId.paladin),
      );
      expect(r.ok, isTrue);
      expect(r.member!.mp, 0);
      expect(r.member!.maxMp, r.member!.mentality * 5);
    });

    test('refusals are named', () {
      expect(
        createCharacter(input(name: '  ')).refusal,
        RefusalReason.emptyName,
      );
      expect(
        createCharacter(input(name: 'Ninechars')).refusal,
        RefusalReason.nameTooLong,
      );
      expect(
        createCharacter(input(gender: Gender.neutral)).refusal,
        RefusalReason.invalidGender,
      );
      expect(
        createCharacter(input(answers: [1, 2])).refusal,
        RefusalReason.invalidAnswers,
      );
      expect(
        createCharacter(input(agility: 20, accuracy: 20, luck: 1)).refusal,
        RefusalReason.invalidPointSplit,
      );
      expect(
        createCharacter(input(agility: 21, accuracy: 19, luck: 0)).refusal,
        RefusalReason.invalidPointSplit,
      );
      expect(
        createCharacter(input(skills: [10, 10, 10, 10, 10, 11])).refusal,
        RefusalReason.invalidSkillSplit,
      );
      expect(
        createCharacter(input(skills: [70, -10, 0, 0, 0, 0])).refusal,
        RefusalReason.invalidSkillSplit,
      );
      expect(
        createCharacter(input(classId: ClassId.paladin)).refusal,
        RefusalReason.classRequirementNotMet,
      );
      expect(
        createCharacter(input(classId: ClassId.demigod)).refusal,
        RefusalReason.classNotSelectable,
      );
      expect(
        createCharacter(input(classId: 42)).refusal,
        RefusalReason.classNotSelectable,
      );
    });

    test('a four-syllable Korean name fits, a five-syllable one does not', () {
      // 한글을 코드에 쓰지 않으려고 코드 포인트로 만든다(가 = U+AC00).
      final four = String.fromCharCodes(List.filled(4, 0xAC00));
      final five = String.fromCharCodes(List.filled(5, 0xAC00));
      expect(nameWidth(four), 8);
      expect(createCharacter(input(name: four)).ok, isTrue);
      expect(
        createCharacter(input(name: five)).refusal,
        RefusalReason.nameTooLong,
      );
    });

    test('question variants come from the injected generator', () {
      final a = pickQuestionVariants(Random(3));
      final b = pickQuestionVariants(Random(3));
      expect(a, b);
      expect(a.length, 10);
      expect(a.every((v) => v == 0 || v == 1), isTrue);
    });
  });
}
