import '../domain/character_class.dart';

/// The floor and ceiling a class has in one skill.
class SkillBand {
  const SkillBand(this.min, this.max);

  final int min;
  final int max;

  /// A class that can never train this skill at all.
  bool get isClosed => max == 0;

  @override
  String toString() => 'SkillBand($min, $max)';
}

/// What each class is, as twelve pairs of numbers.
///
/// ## This is a port, not a design
///
/// Transcribed from the original's `_CLASS_ABILITY[17][12][2]`, laid out
/// in the same order so the two can be compared line by line. The
/// column order is the declaration order of [SkillType]; a parity test
/// spells several cells out as literals.
///
/// Read it and the seventeen classes stop being names: a knight is
/// shield 20..60, a hunter is shooting 40..100, a monk is striking
/// 40..100 **and nothing else**, an esper is esp 50..100 with weapons
/// capped at 40.
const Map<CharacterClass, List<int>> _classAbility = {
  // cut      chop     thrust   strike   shoot    shield   atkMag   chgMag   cureMag  summon   special  esp
  CharacterClass.unknown: [
    10, 50, 10, 50, 10, 50, 0, 50, 10, 50, 10, 50, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  CharacterClass.wanderer: [
    10, 50, 10, 50, 10, 50, 0, 50, 10, 50, 10, 50, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  CharacterClass.knight: [
    10, 60, 10, 60, 5, 50, 0, 50, 0, 0, 20, 60, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  CharacterClass.hunter: [
    0, 0, 5, 50, 5, 50, 0, 60, 40, 100, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  CharacterClass.monk: [
    0, 0, 0, 0, 0, 0, 40, 100, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  CharacterClass.paladin: [
    25, 60, 0, 0, 5, 50, 10, 50, 0, 30, 20, 70, //
    0, 0, 0, 0, 10, 50, 0, 0, 0, 0, 0, 0,
  ],
  CharacterClass.assassin: [
    10, 80, 0, 0, 0, 60, 20, 70, 10, 80, 0, 0, //
    0, 0, 0, 0, 0, 0, 10, 30, 10, 40, 0, 0,
  ],
  CharacterClass.magician: [
    0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, //
    10, 20, 10, 20, 10, 20, 0, 0, 0, 0, 0, 50,
  ],
  CharacterClass.esper: [
    0, 40, 0, 40, 0, 40, 0, 40, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 50, 100,
  ],
  CharacterClass.swordman: [
    40, 100, 0, 0, 0, 0, 0, 30, 0, 0, 0, 30, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ],
  CharacterClass.mage: [
    0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, //
    10, 50, 10, 30, 10, 30, 0, 0, 0, 0, 0, 50,
  ],
  CharacterClass.conjurer: [
    0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, //
    0, 20, 10, 50, 10, 30, 10, 30, 0, 10, 0, 50,
  ],
  CharacterClass.sorcerer: [
    0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, //
    0, 20, 0, 20, 10, 50, 10, 50, 0, 10, 0, 50,
  ],
  CharacterClass.wizard: [
    0, 0, 0, 0, 0, 0, 0, 30, 0, 0, 0, 0, //
    40, 100, 25, 60, 25, 60, 0, 0, 0, 50, 0, 100,
  ],
  CharacterClass.necromancer: [
    0, 0, 0, 0, 0, 0, 0, 30, 0, 0, 0, 0, //
    20, 60, 20, 70, 40, 100, 40, 100, 0, 100, 0, 100,
  ],
  CharacterClass.archimage: [
    0, 0, 0, 0, 0, 0, 0, 30, 0, 0, 0, 0, //
    10, 60, 40, 100, 30, 70, 20, 50, 0, 100, 0, 100,
  ],
  CharacterClass.timewalker: [
    0, 0, 0, 0, 0, 0, 0, 30, 0, 0, 0, 0, //
    40, 70, 40, 100, 40, 70, 20, 100, 20, 50, 20, 100,
  ],
};

/// The band [clazz] has in [skill].
SkillBand skillBand(CharacterClass clazz, SkillType skill) {
  final row = _classAbility[clazz];
  if (row == null) return const SkillBand(0, 0);
  return SkillBand(row[skill.wire * 2], row[skill.wire * 2 + 1]);
}

/// Every band for one class, in [SkillType] order.
List<SkillBand> skillBands(CharacterClass clazz) => [
  for (final skill in SkillType.values) skillBand(clazz, skill),
];

/// The skills [clazz] can train at all.
Set<SkillType> trainableSkills(CharacterClass clazz) => {
  for (final skill in SkillType.values)
    if (!skillBand(clazz, skill).isClosed) skill,
};

/// Which classes a member of [clazz] may change to.
///
/// The original's rule: a caster may become one of the seven higher
/// casters, anyone else one of the six higher fighters, and an esper
/// may not change at all. The candidate must already meet every floor
/// of the target class, which is checked outside this table.
List<CharacterClass> jobChangeCandidates(CharacterClass clazz) {
  if (clazz == CharacterClass.unknown || clazz == CharacterClass.esper) {
    return const [];
  }
  if (classTypeOf(clazz) == ClassType.caster) {
    return const [
      CharacterClass.mage,
      CharacterClass.conjurer,
      CharacterClass.sorcerer,
      CharacterClass.wizard,
      CharacterClass.necromancer,
      CharacterClass.archimage,
      CharacterClass.timewalker,
    ];
  }
  return const [
    CharacterClass.knight,
    CharacterClass.hunter,
    CharacterClass.monk,
    CharacterClass.paladin,
    CharacterClass.assassin,
    CharacterClass.swordman,
  ];
}
