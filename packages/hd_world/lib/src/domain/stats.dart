import 'character_class.dart';

/// The seven numbers a character is made of.
class BaseStats {
  const BaseStats({
    this.strength = 0,
    this.mentality = 0,
    this.concentration = 0,
    this.endurance = 0,
    this.resistance = 0,
    this.agility = 0,
    this.luck = 0,
  });

  final int strength;
  final int mentality;
  final int concentration;
  final int endurance;
  final int resistance;
  final int agility;
  final int luck;

  BaseStats copyWith({
    int? strength,
    int? mentality,
    int? concentration,
    int? endurance,
    int? resistance,
    int? agility,
    int? luck,
  }) => BaseStats(
    strength: strength ?? this.strength,
    mentality: mentality ?? this.mentality,
    concentration: concentration ?? this.concentration,
    endurance: endurance ?? this.endurance,
    resistance: resistance ?? this.resistance,
    agility: agility ?? this.agility,
    luck: luck ?? this.luck,
  );
}

/// Three separate ladders, as the original had them.
class Levels {
  const Levels({this.physical = 1, this.magic = 0, this.esp = 0});

  final int physical;
  final int magic;
  final int esp;

  Levels copyWith({int? physical, int? magic, int? esp}) => Levels(
    physical: physical ?? this.physical,
    magic: magic ?? this.magic,
    esp: esp ?? this.esp,
  );
}

/// The three accuracies.
class Accuracy {
  const Accuracy({this.physical = 0, this.magic = 0, this.esp = 0});

  final int physical;
  final int magic;
  final int esp;
}

/// How much of a ceiling a class type gets, as a percentage.
///
/// ## Ported, and deliberately not applied by default
///
/// The original computed maxima from these factors: a fighter carries
/// full hit points and no spell points, a caster half the hit points
/// and all the spell points, a hybrid four fifths and half. That is the
/// whole reason [ClassType] exists.
///
/// [vitalityFor] is offered for **character creation**. Nothing in this
/// package calls it while resolving a member's stats — a member carries
/// its own maxima and equipment moves them. Deriving them on every
/// resolve would silently rebalance every existing character, which is
/// a decision for content, not for a refactor.
class VitalityFactors {
  const VitalityFactors({required this.hitPercent, required this.spellPercent});

  final int hitPercent;
  final int spellPercent;
}

const Map<ClassType, VitalityFactors> classVitality = {
  ClassType.physical: VitalityFactors(hitPercent: 100, spellPercent: 0),
  ClassType.caster: VitalityFactors(hitPercent: 50, spellPercent: 100),
  ClassType.hybridCure: VitalityFactors(hitPercent: 80, spellPercent: 50),
  ClassType.hybridSpecial: VitalityFactors(hitPercent: 80, spellPercent: 50),
  ClassType.hybridEsp: VitalityFactors(hitPercent: 80, spellPercent: 50),
};

/// The original's `5`, its own comment calling it a balance knob.
const int hitPointScale = 5;

/// What a freshly made character of this class would carry.
///
/// The original multiplied spell points by ten as well. That factor is
/// **left out** and named here rather than buried: the battle's spell
/// costs were measured against the smaller scale, so putting it back is
/// a balance change with a battle-side consequence.
({int maxHitPoints, int maxSpellPoints, int maxEspPoints}) vitalityFor({
  required CharacterClass clazz,
  required BaseStats stats,
  required Levels levels,
}) {
  final f = classVitality[classTypeOf(clazz)]!;
  return (
    maxHitPoints:
        stats.endurance * levels.physical * hitPointScale * f.hitPercent ~/ 100,
    maxSpellPoints: stats.mentality * levels.magic * f.spellPercent ~/ 100,
    maxEspPoints: stats.concentration * levels.esp,
  );
}
