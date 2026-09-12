import 'wire.dart';

/// The twelve trainable skills.
///
/// A class is *defined* by its floor and ceiling in these twelve, which
/// is how the original expressed "what this job is" as numbers rather
/// than as prose.
enum SkillType implements Wired {
  cutting(0),
  chopping(1),
  thrusting(2),
  striking(3),
  shooting(4),
  shieldUse(5),
  attackMagic(6),
  changeMagic(7),
  cureMagic(8),
  summonMagic(9),
  specialMagic(10),
  esp(11);

  const SkillType(this.wire);

  @override
  final int wire;

  static SkillType? fromWire(int wire) => byWire(values, wire);
}

/// The five broad shapes a class can take.
///
/// Drives the vitality formulas: a caster carries half the hit points
/// and all of the spell points, a fighter the reverse, a hybrid four
/// fifths and half.
enum ClassType implements Wired {
  physical(0),
  caster(1),

  /// Fighter — arms plus healing.
  hybridCure(2),

  /// Assassin — arms plus summoning and special magic.
  hybridSpecial(3),

  /// Esper — arms plus the superhuman senses.
  hybridEsp(4);

  const ClassType(this.wire);

  @override
  final int wire;

  static ClassType? fromWire(int wire) => byWire(values, wire);
}

/// The seventeen classes.
///
/// `wire` is the original's `CLASS` numbering and **must not move**: the
/// original itself says only 1..8 are reachable at character creation
/// and that 0..8 may never be reordered.
enum CharacterClass implements Wired {
  unknown(0),
  wanderer(1),
  knight(2),
  hunter(3),
  monk(4),
  paladin(5),
  assassin(6),
  magician(7),
  esper(8),
  swordman(9),
  mage(10),
  conjurer(11),
  sorcerer(12),
  wizard(13),
  necromancer(14),
  archimage(15),
  timewalker(16);

  const CharacterClass(this.wire);

  @override
  final int wire;

  static CharacterClass? fromWire(int wire) => byWire(values, wire);

  /// Reachable by creating a character rather than by changing job.
  bool get isStarting => wire >= 1 && wire <= 8;
}

/// Which of the five shapes a class has.
ClassType classTypeOf(CharacterClass clazz) => switch (clazz) {
  CharacterClass.unknown ||
  CharacterClass.wanderer ||
  CharacterClass.knight ||
  CharacterClass.hunter ||
  CharacterClass.monk ||
  CharacterClass.swordman => ClassType.physical,
  CharacterClass.paladin => ClassType.hybridCure,
  CharacterClass.assassin => ClassType.hybridSpecial,
  CharacterClass.esper => ClassType.hybridEsp,
  CharacterClass.magician ||
  CharacterClass.mage ||
  CharacterClass.conjurer ||
  CharacterClass.sorcerer ||
  CharacterClass.wizard ||
  CharacterClass.necromancer ||
  CharacterClass.archimage ||
  CharacterClass.timewalker => ClassType.caster,
};

/// A set of classes, as the thing a class amulet is restricted to.
///
/// Stored as a set rather than a bitmask so that adding an eighteenth
/// class is a data change and not an arithmetic one.
class ClassMask {
  const ClassMask(this.classes);

  /// Everyone. What a common amulet would carry if it carried one at
  /// all — it does not, and that absence is the definition.
  const ClassMask.any() : classes = const {};

  /// Every class of one shape. "Any caster" without listing eight.
  ClassMask.type(ClassType type)
    : classes = {
        for (final c in CharacterClass.values)
          if (classTypeOf(c) == type) c,
      };

  final Set<CharacterClass> classes;

  bool get isAny => classes.isEmpty;

  bool admits(CharacterClass clazz) => isAny || classes.contains(clazz);
}
