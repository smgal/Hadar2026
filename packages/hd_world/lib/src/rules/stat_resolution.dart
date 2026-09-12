import '../data/item_catalog.dart';
import '../domain/capability.dart';
import '../domain/equip_slot.dart';
import '../domain/item_def.dart';
import '../domain/item_kind.dart';
import '../domain/member.dart';
import '../domain/modifier.dart';
import 'weapon_kind.dart';

/// One member's numbers after everything worn has had its say.
///
/// Built by [resolveStats] and thrown away. Nothing caches it, so there
/// is no invalidation to get wrong.
class ResolvedStats {
  const ResolvedStats({
    required this.values,
    required this.immunities,
    required this.granted,
    required this.weaponKind,
    required this.strikes,
    required this.mainHandKind,
    required this.mainHandShape,
    required this.attackPower,
    required this.offHandLocked,
  });

  /// Final value per stat. Every key is present.
  final Map<StatKey, int> values;

  /// What cannot touch this member.
  final Set<Ailment> immunities;

  /// What this member's gear lets the party or the member do.
  final Set<Capability> granted;

  /// The style the two hands add up to.
  final WeaponKind weaponKind;

  /// How many blows one attack action lands. Two for a pair of weapons.
  final int strikes;

  /// What the main hand is, for whoever has to translate the style into
  /// another vocabulary. Null when the hand is empty.
  ///
  /// The style alone is not enough: "one weapon, free hand" says nothing
  /// about whether it cuts or thrusts, and a battle has to know.
  final ItemKind? mainHandKind;
  final WeaponShape? mainHandShape;

  /// How hard the weapon hits. **The battle multiplies this and never
  /// asks how the hands are arranged** — reach is the battle's own
  /// table, keyed by [weaponKind].
  final int attackPower;

  final bool offHandLocked;

  int operator [](StatKey key) => values[key] ?? 0;
}

/// The value a stat starts from, before anything is worn.
int _baseOf(Member m, StatKey key) => switch (key) {
  StatKey.maxHitPoints => m.baseMaxHitPoints,
  StatKey.maxSpellPoints => m.baseMaxSpellPoints,
  StatKey.maxEspPoints => m.baseMaxEspPoints,
  StatKey.accuracyPhysical => m.accuracy.physical,
  StatKey.accuracyMagic => m.accuracy.magic,
  StatKey.accuracyEsp => m.accuracy.esp,
  StatKey.strength => m.stats.strength,
  StatKey.mentality => m.stats.mentality,
  StatKey.concentration => m.stats.concentration,
  StatKey.endurance => m.stats.endurance,
  StatKey.resistance => m.stats.resistance,
  StatKey.agility => m.stats.agility,
  StatKey.luck => m.stats.luck,
  // A bare fist holds one coating. Dual wielding earns the second.
  StatKey.coatingSlots => 1,
  StatKey.defence => m.baseDefence,
  StatKey.evasion ||
  StatKey.initiative ||
  StatKey.shieldBlock ||
  StatKey.spellCostRelief ||
  StatKey.espCostRelief => 0,
};

/// Adds up a member.
///
/// ## Percentages read the whole, and read it once
///
/// Flat additions land first, then every percentage is taken against
/// **that subtotal** and added. So two amulets of ten percent give
/// twenty, never twenty-one, and the order they were put on can never
/// change the answer. Compounding would make equipment order matter,
/// which no screen would ever explain.
ResolvedStats resolveStats({
  required Member member,
  required ItemCatalog catalog,
}) {
  final adds = <StatKey, int>{};
  final percents = <StatKey, int>{};
  final immunities = <Ailment>{};
  final granted = <Capability>{};

  final worn = <ItemDef>[];
  for (final slot in EquipSlot.values) {
    final ref = member.at(slot);
    if (ref == null) continue;
    final def = catalog[ref];
    if (def == null) continue;
    // A locked off hand contributes nothing, even if something is still
    // recorded there — the state can arrive that way from an old save.
    if (slot == EquipSlot.leftHand && _mainIsTwoHanded(member, catalog)) {
      continue;
    }
    worn.add(def);
  }

  for (final def in worn) {
    for (final mod in def.modifiers) {
      if (mod.op == ModifierOp.add) {
        adds[mod.stat] = (adds[mod.stat] ?? 0) + mod.value;
      } else {
        percents[mod.stat] = (percents[mod.stat] ?? 0) + mod.value;
      }
    }
    immunities.addAll(def.immunities);
    granted.addAll(def.grants);
  }

  final right = _defAt(member, EquipSlot.rightHand, catalog);
  final left = _mainIsTwoHanded(member, catalog)
      ? null
      : _defAt(member, EquipSlot.leftHand, catalog);
  final kind = weaponKindFor(right: right, left: left);

  // What the style adds beyond reach. Folded in with everything worn,
  // so a screen reads one number and a bridge hands over one number.
  final passives = passivesFor(kind);
  adds[StatKey.coatingSlots] =
      (adds[StatKey.coatingSlots] ?? 0) + passives.coatings - 1;
  if (passives.evasion != 0) {
    adds[StatKey.evasion] = (adds[StatKey.evasion] ?? 0) + passives.evasion;
  }
  if (passives.initiative != 0) {
    adds[StatKey.initiative] =
        (adds[StatKey.initiative] ?? 0) + passives.initiative;
  }

  final values = <StatKey, int>{};
  for (final key in StatKey.values) {
    final subtotal = _baseOf(member, key) + (adds[key] ?? 0);
    values[key] = subtotal + subtotal * (percents[key] ?? 0) ~/ 100;
  }

  return ResolvedStats(
    values: values,
    immunities: immunities,
    granted: granted,
    weaponKind: kind,
    strikes: passives.strikes,
    mainHandKind: right?.kind,
    mainHandShape: right?.shape,
    attackPower: _attackPower(right, left, kind),
    offHandLocked: _mainIsTwoHanded(member, catalog),
  );
}

/// How hard the pair hits.
///
/// Dual wielding takes the **average** of the two, not the sum: the
/// style already strikes twice, so summing would pay for the same thing
/// twice over and make two daggers beat any single weapon.
int _attackPower(ItemDef? right, ItemDef? left, WeaponKind kind) {
  if (right == null || !right.kind.isWeapon) return 1;
  if (kind == WeaponKind.dualWield && left != null) {
    return (right.attackPower + left.attackPower) ~/ 2;
  }
  return right.attackPower;
}

bool _mainIsTwoHanded(Member member, ItemCatalog catalog) {
  final main = _defAt(member, EquipSlot.rightHand, catalog);
  return main != null && main.isTwoHanded;
}

ItemDef? _defAt(Member member, EquipSlot slot, ItemCatalog catalog) {
  final ref = member.at(slot);
  return ref == null ? null : catalog[ref];
}

/// Whether a held light is what this member is carrying.
bool carriesLight({required Member member, required ItemCatalog catalog}) {
  final ref = member.at(EquipSlot.leftHand);
  if (ref == null) return false;
  if (_mainIsTwoHanded(member, catalog)) return false;
  return catalog[ref]?.kind == ItemKind.light;
}
