import 'package:hd_world/hd_world.dart';

/// The integer item space shipped scripts still pass around.
///
/// ## Why an integer at all
///
/// `Player::ChangeAttribute(n, "weapon", 4)` names a weapon by its
/// position in the original's table. The new catalogue is keyed by
/// name, because a position renames everything after it when a row is
/// inserted — but the shipped scripts cannot be asked to change, so the
/// old numbers stay answerable.
///
/// `ItemDef.legacyIndex` is that position. This file is the only place
/// that reads it.

/// The item at [index] in the original's table for [kind].
///
/// **Null is the answer for a number that was never there**, which the
/// caller reports. The predecessor answered such a lookup with slot
/// zero — bare hands — and a script could equip nothing by accident.
ItemRef? legacyItemRef(
  ItemKind kind,
  int index, {
  required ItemCatalog catalog,
}) {
  for (final def in catalog.ofKind(kind)) {
    if (def.legacyIndex == index) return def.ref;
  }
  return null;
}

/// The number a script would recognise this item by, or -1.
int legacyIndexOf(ItemRef ref, {required ItemCatalog catalog}) =>
    catalog[ref]?.legacyIndex ?? -1;

/// Which kinds the original's three equipment integers addressed.
///
/// A subtlety worth stating: the original's weapon integer indexed a
/// **single ladder of ten**, mixing the five weapon classes. The
/// catalogue keeps each class's own numbering, so a bare integer is
/// ambiguous. These are the classes to search, in the order the
/// original's own name list went.
const Map<String, List<ItemKind>> legacyEquipKinds = {
  'weapon': [
    ItemKind.slashWeapon,
    ItemKind.chopWeapon,
    ItemKind.pierceWeapon,
    ItemKind.bluntWeapon,
    ItemKind.missileWeapon,
  ],
  'shield': [ItemKind.shield],
  'armor': [ItemKind.bodyArmour],
};

/// The original's ten-weapon name ladder, as catalogue references.
///
/// This **is** the old `weapon` integer: index 0 is bare hands, 1 the
/// dagger, and so on to 9. Ported verbatim from the shipped name list
/// so a script's `weapon 4` still means a long sword.
const List<String> legacyWeaponLadder = [
  'weapon.fist_cut', // 0 bare hands
  'weapon.knife', // 1
  'weapon.club', // 2
  'weapon.halberd', // 3
  'weapon.long_sword', // 4
  'weapon.mace', // 5
  'weapon.cavalry_lance', // 6
  'weapon.poleaxe', // 7
  'weapon.trident', // 8
  'weapon.flamberge', // 9  the original's flame sword slot
];

/// The reference a script's `weapon` integer means.
ItemRef? legacyWeapon(int index) =>
    index >= 0 && index < legacyWeaponLadder.length
    ? ItemRef(legacyWeaponLadder[index])
    : null;

/// The reference a script's `shield` or `armor` integer means.
///
/// Both are simple: the original numbered them 0..5 and so does the
/// catalogue, so [legacyItemRef] answers directly.
ItemRef? legacyShield(int index, {required ItemCatalog catalog}) =>
    legacyItemRef(ItemKind.shield, index, catalog: catalog);

ItemRef? legacyArmour(int index, {required ItemCatalog catalog}) =>
    legacyItemRef(ItemKind.bodyArmour, index, catalog: catalog);

// --- the packed integer cm2 passes ----------------------------------

const int _kindShift = 16;
const int _detailShift = 8;
const int _byteMax = 0xFF;

/// The single integer a script names an item by.
///
/// ```text
///  [ kind ]  [detail]  [ index]
///  kkkkkkkk  dddddddd  iiiiiiii
/// ```
///
/// The layout is the previous model's, so the generated constants in
/// `assets/item4ep1.cm2` keep their values. `detail` was always zero —
/// the kind byte is already precise — and is read here only to reject a
/// number that sets it.
ItemRef? itemRefFromWire(int wire, {required ItemCatalog catalog}) {
  if (wire < 0) return null;
  final kind = ItemKind.fromWire((wire >> _kindShift) & _byteMax);
  if (kind == null) return null;
  if ((wire >> _detailShift) & _byteMax != 0) return null;
  return legacyItemRef(kind, wire & _byteMax, catalog: catalog);
}

/// The integer a script would name this item by, or -1.
int itemWireOf(ItemRef ref, {required ItemCatalog catalog}) {
  final def = catalog[ref];
  if (def == null || def.legacyIndex < 0) return -1;
  return (def.kind.wire << _kindShift) | def.legacyIndex;
}
