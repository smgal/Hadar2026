import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_world/hd_world.dart' as hw;

/// Seven postures into the six the battle can act on.
///
/// ## The mapping is lossy, and says where
///
/// The battle's presets grew out of the enemy dispatcher, so they
/// describe **posture** — where to stand, when to leave. The world's
/// styles describe **role**, which is a finer question. Two pairs
/// collapse:
///
/// | style | preset | what is lost |
/// |---|---|---|
/// | volley | caster | keeps its distance, but shoots rather than casts |
/// | disrupt | skirmisher | closes to apply a coating, but the battle does not know why |
///
/// Neither loss changes where the member stands, which is all the
/// battle reads a preset for today. The finer behaviour is the preset
/// logic chapter's work and is not built yet — until it is, this table
/// is the honest translation rather than a pretence.
hb.PresetKind presetFor(hw.FightingStyle style) => switch (style) {
  hw.FightingStyle.bulwark => hb.PresetKind.guardian,
  hw.FightingStyle.assault => hb.PresetKind.aggressive,
  hw.FightingStyle.skirmish => hb.PresetKind.skirmisher,
  hw.FightingStyle.volley => hb.PresetKind.caster,
  hw.FightingStyle.firepower => hb.PresetKind.caster,
  hw.FightingStyle.disrupt => hb.PresetKind.skirmisher,
  hw.FightingStyle.mend => hb.PresetKind.medic,
};

/// Every preset a member could be switched to mid-battle.
Set<hb.PresetKind> knownPresetsFor(hw.CharacterClass clazz) => {
  for (final style in hw.stylesFor(clazz)) presetFor(style),
};
