import '../data/class_table.dart';
import '../domain/character_class.dart';
import '../domain/fighting_style.dart';

/// Which skill gates which posture.
SkillType governingSkillOf(FightingStyle style) => switch (style) {
  FightingStyle.bulwark => SkillType.shieldUse,
  FightingStyle.assault || FightingStyle.skirmish => SkillType.striking,
  FightingStyle.volley => SkillType.shooting,
  FightingStyle.firepower => SkillType.attackMagic,
  FightingStyle.disrupt => SkillType.specialMagic,
  FightingStyle.mend => SkillType.cureMagic,
};

/// The ceiling a class needs in the governing skill before a posture is
/// offered.
///
/// One threshold for every style, because two would need explaining. It
/// admits a magician to [FightingStyle.assault] — a magician really can
/// swing a staff, and the posture being available is not the same as it
/// being wise.
const int styleSkillThreshold = 20;

/// Which postures [clazz] may be put on.
///
/// **Derived from the class table, not listed by hand.** A new class is
/// twelve numbers and its postures fall out; a hand-written list would
/// be a second place to forget.
Set<FightingStyle> stylesFor(CharacterClass clazz) {
  final out = <FightingStyle>{};
  for (final style in FightingStyle.values) {
    if (_ceiling(clazz, style) >= styleSkillThreshold) out.add(style);
  }
  // Anything that can hold a weapon can be told to go and hit things.
  if (out.isEmpty) out.add(FightingStyle.assault);
  return out;
}

/// The ceiling that gates a style, taking the best of the melee skills
/// for the two melee postures and of the two disruptive schools for
/// [FightingStyle.disrupt].
int _ceiling(CharacterClass clazz, FightingStyle style) {
  int max(List<SkillType> skills) => skills
      .map((s) => skillBand(clazz, s).max)
      .reduce((a, b) => a > b ? a : b);
  return switch (style) {
    FightingStyle.assault || FightingStyle.skirmish => max(const [
      SkillType.cutting,
      SkillType.chopping,
      SkillType.thrusting,
      SkillType.striking,
    ]),
    FightingStyle.disrupt => max(const [
      SkillType.specialMagic,
      SkillType.esp,
    ]),
    _ => skillBand(clazz, governingSkillOf(style)).max,
  };
}

/// The posture a class leans towards when nobody has chosen.
///
/// ## The floor decides, not the ceiling
///
/// A ceiling says what a class could become; the **floor** says what it
/// already is. A magician can train the superhuman senses to fifty and
/// attack magic only to twenty, so by ceiling its posture would be
/// disruption — but it starts with ten in attack magic and nothing in
/// the senses, which is what makes it a magician on the day it is
/// rolled.
///
/// Ties fall to the higher ceiling, then to the declaration order of
/// [FightingStyle], so the answer is always the same.
FightingStyle defaultStyleFor(CharacterClass clazz) {
  final allowed = stylesFor(clazz);
  var best = FightingStyle.assault;
  var bestFloor = -1;
  var bestCeiling = -1;
  for (final style in FightingStyle.values) {
    if (!allowed.contains(style)) continue;
    final floor = _floor(clazz, style);
    final ceiling = _ceiling(clazz, style);
    if (floor > bestFloor || (floor == bestFloor && ceiling > bestCeiling)) {
      best = style;
      bestFloor = floor;
      bestCeiling = ceiling;
    }
  }
  return best;
}

/// The floor that a style leans on, gathered the same way as the
/// ceiling.
int _floor(CharacterClass clazz, FightingStyle style) {
  int max(List<SkillType> skills) => skills
      .map((s) => skillBand(clazz, s).min)
      .reduce((a, b) => a > b ? a : b);
  return switch (style) {
    FightingStyle.assault || FightingStyle.skirmish => max(const [
      SkillType.cutting,
      SkillType.chopping,
      SkillType.thrusting,
      SkillType.striking,
    ]),
    FightingStyle.disrupt => max(const [
      SkillType.specialMagic,
      SkillType.esp,
    ]),
    _ => skillBand(clazz, governingSkillOf(style)).min,
  };
}
