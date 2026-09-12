import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

/// The class table is a port. These cells are the original's.
void main() {
  test('a knight is the shield', () {
    expect(skillBand(CharacterClass.knight, SkillType.shieldUse).min, 20);
    expect(skillBand(CharacterClass.knight, SkillType.shieldUse).max, 60);
    expect(skillBand(CharacterClass.knight, SkillType.shooting).isClosed, isTrue);
  });

  test('a hunter is the bow and a monk is the fist', () {
    expect(skillBand(CharacterClass.hunter, SkillType.shooting).max, 100);
    expect(skillBand(CharacterClass.monk, SkillType.striking).max, 100);
    // A monk trains exactly one skill. That is the whole class.
    expect(trainableSkills(CharacterClass.monk), {SkillType.striking});
  });

  test('an esper is capped at forty with a weapon', () {
    for (final s in const [
      SkillType.cutting,
      SkillType.chopping,
      SkillType.thrusting,
      SkillType.striking,
    ]) {
      expect(skillBand(CharacterClass.esper, s).max, 40, reason: s.name);
    }
    expect(skillBand(CharacterClass.esper, SkillType.esp).min, 50);
    expect(skillBand(CharacterClass.esper, SkillType.esp).max, 100);
  });

  test('the assassin is the only class with both missiles and special magic', () {
    final both = [
      for (final c in CharacterClass.values)
        if (!skillBand(c, SkillType.shooting).isClosed &&
            !skillBand(c, SkillType.specialMagic).isClosed)
          c,
    ];
    expect(both, [CharacterClass.assassin]);
  });

  test('every class has twelve bands and no floor above its ceiling', () {
    for (final c in CharacterClass.values) {
      final bands = skillBands(c);
      expect(bands.length, 12, reason: c.name);
      for (final b in bands) {
        expect(b.min, lessThanOrEqualTo(b.max), reason: '${c.name} $b');
      }
    }
  });

  test('a caster changes into a caster and an esper changes into nothing', () {
    expect(jobChangeCandidates(CharacterClass.esper), isEmpty);
    expect(
      jobChangeCandidates(CharacterClass.magician),
      contains(CharacterClass.archimage),
    );
    expect(
      jobChangeCandidates(CharacterClass.knight),
      contains(CharacterClass.swordman),
    );
    expect(
      jobChangeCandidates(CharacterClass.knight),
      isNot(contains(CharacterClass.wizard)),
    );
  });

  test('class type sorts the seventeen into five shapes', () {
    expect(classTypeOf(CharacterClass.knight), ClassType.physical);
    expect(classTypeOf(CharacterClass.paladin), ClassType.hybridCure);
    expect(classTypeOf(CharacterClass.assassin), ClassType.hybridSpecial);
    expect(classTypeOf(CharacterClass.esper), ClassType.hybridEsp);
    expect(classTypeOf(CharacterClass.timewalker), ClassType.caster);
  });

  test('a caster carries half the hit points and all the spell points', () {
    const stats = BaseStats(endurance: 10, mentality: 10, concentration: 10);
    const levels = Levels(physical: 2, magic: 2, esp: 2);
    final fighter = vitalityFor(
      clazz: CharacterClass.knight,
      stats: stats,
      levels: levels,
    );
    final caster = vitalityFor(
      clazz: CharacterClass.wizard,
      stats: stats,
      levels: levels,
    );
    expect(fighter.maxHitPoints, 100);
    expect(fighter.maxSpellPoints, 0);
    expect(caster.maxHitPoints, 50);
    expect(caster.maxSpellPoints, 20);
  });
}
