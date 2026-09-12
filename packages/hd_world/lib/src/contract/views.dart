import '../data/class_table.dart';
import '../data/item_catalog.dart';
import '../domain/character_class.dart';
import '../domain/equip_slot.dart';
import '../domain/fighting_style.dart';
import '../domain/ids.dart';
import '../domain/item_def.dart';
import '../domain/member.dart';
import '../domain/modifier.dart';
import '../rules/eligibility.dart';
import '../rules/fighting_style.dart';
import '../rules/party_capability.dart';
import '../rules/stat_resolution.dart';

/// Read models.
///
/// ## Why these are separate types
///
/// A view answers a screen's question in one call and carries the
/// derived numbers with it, so a caller never recomputes and never sees
/// a half-resolved member. They are also the JSON the HTTP surface
/// serves, which means **the wire format is owned by the model** rather
/// than reinvented by each front end.
class MemberView {
  const MemberView({
    required this.member,
    required this.stats,
    required this.allowedStyles,
    required this.slots,
  });

  final Member member;
  final ResolvedStats stats;
  final Set<FightingStyle> allowedStyles;

  /// Every slot, whether filled or not, with why it is shut if it is.
  final List<SlotView> slots;

  static MemberView of(Member member, ItemCatalog catalog) => MemberView(
    member: member,
    stats: resolveStats(member: member, catalog: catalog),
    allowedStyles: stylesFor(member.clazz),
    slots: [
      for (final slot in EquipSlot.displayOrder)
        SlotView.of(member, slot, catalog),
    ],
  );

  Map<String, Object?> toJson() => {
    'ref': member.ref.value,
    'name': member.name,
    'class': member.clazz.name,
    'classWire': member.clazz.wire,
    'classType': member.classType.name,
    'levels': {
      'physical': member.levels.physical,
      'magic': member.levels.magic,
      'esp': member.levels.esp,
    },
    'condition': member.condition.name,
    'gender': member.gender,
    'experience': member.experience,
    'vitals': {
      'poison': member.poison,
      'unconscious': member.unconscious,
      'dead': member.dead,
      'hitPoints': member.hitPoints,
      'maxHitPoints': stats[StatKey.maxHitPoints],
      'spellPoints': member.spellPoints,
      'maxSpellPoints': stats[StatKey.maxSpellPoints],
      'espPoints': member.espPoints,
      'maxEspPoints': stats[StatKey.maxEspPoints],
    },
    'style': member.style.name,
    'thrift': member.thrift,
    'allowedStyles': [for (final s in allowedStyles) s.name],
    'weaponKind': stats.weaponKind.name,
    'strikes': stats.strikes,
    'mainHandKind': stats.mainHandKind?.name,
    'mainHandShape': stats.mainHandShape?.name,
    'attackPower': stats.attackPower,
    'offHandLocked': stats.offHandLocked,
    'stats': {
      for (final e in stats.values.entries) e.key.name: e.value,
    },
    'immunities': [for (final a in stats.immunities) a.name],
    'grants': [for (final c in stats.granted) c.name],
    'skillBands': {
      for (final s in SkillType.values)
        s.name: {
          'min': skillBand(member.clazz, s).min,
          'max': skillBand(member.clazz, s).max,
        },
    },
    'slots': [for (final s in slots) s.toJson()],
  };
}

/// One slot on one member.
class SlotView {
  const SlotView({
    required this.slot,
    required this.item,
    required this.locked,
  });

  final EquipSlot slot;
  final ItemRef? item;

  /// Shut because the main hand is holding a two-handed weapon.
  final bool locked;

  static SlotView of(Member member, EquipSlot slot, ItemCatalog catalog) =>
      SlotView(
        slot: slot,
        item: member.at(slot),
        locked: slot == EquipSlot.leftHand && isOffHandLocked(member, catalog),
      );

  Map<String, Object?> toJson() => {
    'slot': slot.name,
    'slotWire': slot.wire,
    'item': item?.value,
    'locked': locked,
  };
}

/// An item as a front end needs it.
class ItemView {
  const ItemView(this.def);

  final ItemDef def;

  Map<String, Object?> toJson() => {
    'ref': def.ref.value,
    'nameKey': def.nameKey,
    'kind': def.kind.name,
    'kindWire': def.kind.wire,
    'hands': def.hands.wire,
    'shape': def.shape?.name,
    'attackPower': def.attackPower,
    'removable': def.removable,
    'slots': [for (final s in def.allowedSlots) s.name],
    'classes': def.classMask.isAny
        ? null
        : [for (final c in def.classMask.classes) c.name],
    'modifiers': [
      for (final m in def.modifiers)
        {'stat': m.stat.name, 'op': m.op.name, 'value': m.value},
    ],
    'immunities': [for (final a in def.immunities) a.name],
    'grants': [for (final c in def.grants) c.name],
    'annexKey': def.annexKey,
    'legacyIndex': def.legacyIndex,
  };
}

/// The whole party, its pack, and what it can walk on.
class WorldView {
  const WorldView({
    required this.members,
    required this.pack,
    required this.abilities,
    required this.light,
  });

  final List<MemberView> members;
  final Map<ItemRef, int> pack;
  final PartyAbilities abilities;
  final LightLevel light;

  Map<String, Object?> toJson() => {
    'members': [for (final m in members) m.toJson()],
    'pack': [
      for (final e in pack.entries) {'item': e.key.value, 'count': e.value},
    ],
    'party': {
      'capabilities': [for (final c in abilities.capabilities) c.name],
      'lightBearers': abilities.lightBearers,
      'magicLight': abilities.magicLight,
      'sightInDarkness': light.radius,
      'moonlight': light.moonlight,
    },
  };
}
