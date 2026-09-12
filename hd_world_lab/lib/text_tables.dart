import 'package:hd_world/hd_world.dart';
import 'package:hd_world_text/hd_world_text.dart';

/// Every name table, as JSON.
///
/// The front end holds **no Korean of its own** — it asks for this once
/// and looks everything up. One table, so a name can never be one thing
/// on a screen and another in a terminal.
Map<String, Object?> textTablesJson() => {
  'slot': {for (final v in EquipSlot.values) v.name: slotName(v)},
  'class': {for (final v in CharacterClass.values) v.name: className(v)},
  'classType': {
    for (final v in ClassType.values) v.name: classTypeNames[v],
  },
  'skill': {for (final v in SkillType.values) v.name: skillNames[v]},
  'weaponKind': {
    for (final v in WeaponKind.values) v.name: weaponKindName(v),
  },
  'style': {for (final v in FightingStyle.values) v.name: styleName(v)},
  'styleHint': {
    for (final v in FightingStyle.values) v.name: styleHints[v],
  },
  'stat': {for (final v in StatKey.values) v.name: statName(v)},
  'capability': {
    for (final v in Capability.values) v.name: capabilityName(v),
  },
  'ailment': {for (final v in Ailment.values) v.name: ailmentNames[v]},
  'refusal': {
    for (final v in RefusalReason.values) v.name: refusalMessage(v),
  },
  'item': {
    for (final d in ItemCatalog.builtIn.all) d.ref.value: itemName(d.nameKey),
  },
  'annex': annexNames,
  'op': {'add': '+', 'percent': '%'},
};

/// The catalogue as a front end needs it, name included.
Map<String, Object?> catalogJson() => {
  'items': [
    for (final d in ItemCatalog.builtIn.all)
      {...ItemView(d).toJson(), 'name': itemName(d.nameKey)},
  ],
  'slots': [
    for (final s in EquipSlot.displayOrder)
      {'slot': s.name, 'wire': s.wire, 'name': slotName(s)},
  ],
  'styles': [
    for (final s in FightingStyle.values)
      {'style': s.name, 'name': styleName(s), 'hint': styleHints[s]},
  ],
};

/// A fresh sample world, with names filled in from the text tables.
World buildSampleWorld() {
  final members = [
    for (final template in sampleParty)
      template.build()..name = memberName(template.nameKey),
  ];
  return World(
    members: members,
    // Room to spare on purpose: putting a two-handed weapon on displaces
    // two things at once, and a pack with no slack would refuse the move
    // for a reason that has nothing to do with the rule being tried.
    pack: Pack(
      capacity: 40,
      counts: {
        for (final e in samplePack.entries) ItemRef(e.key): e.value,
      },
    ),
  );
}
