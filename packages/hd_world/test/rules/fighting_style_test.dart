import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

void main() {
  test('a knight holds the line and a hunter shoots', () {
    expect(stylesFor(CharacterClass.knight), contains(FightingStyle.bulwark));
    expect(
      stylesFor(CharacterClass.knight),
      isNot(contains(FightingStyle.volley)),
    );
    expect(stylesFor(CharacterClass.hunter), contains(FightingStyle.volley));
    expect(
      stylesFor(CharacterClass.hunter),
      isNot(contains(FightingStyle.bulwark)),
    );
  });

  test('a monk has one posture, because it has one skill', () {
    expect(stylesFor(CharacterClass.monk), {
      FightingStyle.assault,
      FightingStyle.skirmish,
    });
  });

  test('a fighter is the only class that both shields and heals', () {
    final both = [
      for (final c in CharacterClass.values)
        if (stylesFor(c).contains(FightingStyle.bulwark) &&
            stylesFor(c).contains(FightingStyle.mend))
          c,
    ];
    expect(both, [CharacterClass.paladin]);
  });

  test('an assassin disrupts and an esper disrupts', () {
    expect(stylesFor(CharacterClass.assassin), contains(FightingStyle.disrupt));
    expect(stylesFor(CharacterClass.esper), contains(FightingStyle.disrupt));
  });

  test('every class can be told to go and hit something', () {
    for (final c in CharacterClass.values) {
      expect(stylesFor(c), isNotEmpty, reason: c.name);
    }
  });

  test('the default is what the class already is, not what it could be', () {
    // Read off the floor. A magician's ceiling in the senses is fifty and
    // in attack magic only twenty, but it is rolled with ten in attack
    // magic and nothing in the senses — so it is a caster on day one.
    expect(defaultStyleFor(CharacterClass.magician), FightingStyle.firepower);
    expect(defaultStyleFor(CharacterClass.knight), FightingStyle.bulwark);
    expect(defaultStyleFor(CharacterClass.hunter), FightingStyle.volley);
    expect(defaultStyleFor(CharacterClass.monk), FightingStyle.assault);
    expect(defaultStyleFor(CharacterClass.wizard), FightingStyle.firepower);
    expect(defaultStyleFor(CharacterClass.esper), FightingStyle.disrupt);
    expect(defaultStyleFor(CharacterClass.swordman), FightingStyle.assault);
    expect(defaultStyleFor(CharacterClass.necromancer), FightingStyle.mend);
    expect(defaultStyleFor(CharacterClass.paladin), FightingStyle.assault);
  });

  test('the default is always one of the allowed ones', () {
    for (final c in CharacterClass.values) {
      expect(stylesFor(c), contains(defaultStyleFor(c)), reason: c.name);
    }
  });

  test('thrift is not a posture', () {
    // It is a toggle over whichever posture is set, so it must not
    // appear in the list a screen offers.
    expect(FightingStyle.values.length, 7);
    expect(
      [for (final s in FightingStyle.values) s.name],
      isNot(contains('thrift')),
    );
  });
}
