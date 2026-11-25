import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  /// 스크립트가 쓰는 이름. 이 목록이 바뀌면 맵 스크립트가 깨진다.
  const scriptNames = [
    'strength',
    'mentality',
    'concentration',
    'endurance',
    'resistance',
    'agility',
    'accuracy',
    'luck',
    'level',
    'hp',
    'mp',
    'exp',
    'poison',
    'unconscious',
    'dead',
    'class',
    'family',
    'gender',
    'ac',
    'skill1',
    'skill2',
    'skill3',
    'skill4',
    'skill5',
    'skill6',
  ];

  test('every name the scripts use is readable and writable', () {
    for (final name in scriptNames) {
      final m = fighter();
      expect(memberAttributeNames, contains(name));
      expect(readAttribute(m, name), isNotNull, reason: name);
      expect(writeAttribute(m, name, 1), isTrue, reason: name);
      expect(readAttribute(m, name), 1, reason: name);
    }
  });

  test('every listed name is readable', () {
    final m = fighter();
    for (final name in memberAttributeNames) {
      expect(readAttribute(m, name), isNotNull, reason: name);
    }
  });

  test('reads the right field', () {
    final m =
        fighter(
            classId: ClassId.knight,
            level: 3,
            abilities: [11, 12, 13, 14, 15, 16, 17, 18],
            skills: [21, 22, 23, 24, 25, 26],
            armour: 'armour.chain_mail',
          )
          ..poison = 4
          ..unconscious = 5
          ..dead = 6
          ..exp = 77
          ..trainedExp = 88;
    expect(
      [for (final n in scriptNames.take(8)) readAttribute(m, n)],
      [11, 12, 13, 14, 15, 16, 17, 18],
    );
    expect(
      [for (var i = 1; i <= 6; i++) readAttribute(m, 'skill$i')],
      [21, 22, 23, 24, 25, 26],
    );
    expect(readAttribute(m, 'level'), 3);
    expect(readAttribute(m, 'hp'), 420);
    expect(readAttribute(m, 'mp'), 0);
    expect(readAttribute(m, 'exp'), 77);
    expect(readAttribute(m, 'trainedexp'), 88);
    expect(readAttribute(m, 'poison'), 4);
    expect(readAttribute(m, 'unconscious'), 5);
    expect(readAttribute(m, 'dead'), 6);
    expect(readAttribute(m, 'class'), ClassId.knight);
    expect(readAttribute(m, 'family'), Family.fighter.wire);
    expect(readAttribute(m, 'gender'), Gender.male.wire);
    // ac 는 계산된 값이다: 기본 2 + 체인 메일 3.
    expect(readAttribute(m, 'ac'), 5);
    expect(readAttribute(m, 'maxhp'), 420);
    expect(readAttribute(m, 'maxmp'), 0);
  });

  test('unknown names give null and false, and change nothing', () {
    final m = fighter();
    final before = m.toJson();
    for (final name in [
      '',
      'nope',
      'skill0',
      'skill7',
      'skill',
      'skill10',
      'name',
      'weapon',
    ]) {
      expect(readAttribute(m, name), isNull, reason: name);
      expect(writeAttribute(m, name, 5), isFalse, reason: name);
    }
    expect(m.toJson(), before);
  });

  test('derived maxima cannot be written', () {
    final m = fighter();
    expect(writeAttribute(m, 'maxhp', 9999), isFalse);
    expect(writeAttribute(m, 'maxmp', 9999), isFalse);
    expect(m.maxHp, 100);
  });

  test('names are case-insensitive', () {
    final m = fighter();
    expect(writeAttribute(m, 'Strength', 19), isTrue);
    expect(readAttribute(m, 'STRENGTH'), 19);
  });

  test('family and gender take wire numbers and refuse nonsense', () {
    final m = fighter();
    expect(writeAttribute(m, 'family', Family.mage.wire), isTrue);
    expect(m.family, Family.mage);
    expect(writeAttribute(m, 'family', 99), isFalse);
    expect(m.family, Family.mage);
    expect(writeAttribute(m, 'gender', Gender.female.wire), isTrue);
    expect(m.gender, Gender.female);
    expect(writeAttribute(m, 'gender', -1), isFalse);
    expect(m.gender, Gender.female);
  });

  test('wire numbers are pinned', () {
    expect([for (final f in Family.values) f.wire], [0, 1, 2, 3, 4, 5, 6]);
    expect([for (final g in Gender.values) g.wire], [0, 1, 2]);
    expect([for (final e in Episode.values) e.number], [1, 2, 3]);
  });

  test(
    'negative values are raised to zero, level to one, skills capped at 100',
    () {
      final m = fighter();
      writeAttribute(m, 'hp', -50);
      writeAttribute(m, 'luck', -1);
      writeAttribute(m, 'level', 0);
      writeAttribute(m, 'skill3', 250);
      expect(m.hp, 0);
      expect(m.luck, 0);
      expect(m.level, 1);
      expect(m.skills[2], 100);
    },
  );

  test('writing ac moves the base defence so that the computed AC matches', () {
    final m = fighter(armour: 'armour.chain_mail');
    expect(m.ac, 5);
    expect(writeAttribute(m, 'ac', 9), isTrue);
    expect(m.ac, 9);
    expect(m.baseAc, 6);
    expect(m.armourPower, 3);
    // 갑옷보다 낮게는 내려가지 않는다 — 기본 방어가 0 에서 멈춘다.
    writeAttribute(m, 'ac', 0);
    expect(m.baseAc, 0);
    expect(m.ac, 3);
  });

  test('one write touches one field — order does not matter', () {
    // 인내력보다 생명력을 먼저 써도 깎이지 않는다.
    final m = Member(
      family: Family.fighter,
      classId: 1,
      abilities: List.filled(8, 0),
    );
    expect(writeAttribute(m, 'hp', 500), isTrue);
    expect(m.hp, 500);
    writeAttribute(m, 'endurance', 10);
    writeAttribute(m, 'level', 2);
    expect(m.hp, 500);
    reviseMember(m);
    expect(m.hp, 200);
  });

  test('revise with fill tops both pools up', () {
    final m = mage(level: 2)
      ..hp = 1
      ..mp = 1;
    reviseMember(m, fill: true);
    expect(m.hp, 200);
    expect(m.mp, 200);
  });
}
