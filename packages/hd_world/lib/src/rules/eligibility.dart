import '../data/item_catalog.dart';
import '../domain/equip_slot.dart';
import '../domain/ids.dart';
import '../domain/item_def.dart';
import '../domain/item_kind.dart';
import '../domain/member.dart';
import 'refusal.dart';

/// May [member] put [item] in [slot]?
///
/// Returns null for yes, and the reason for no. **Two questions in
/// order**: does it go there at all, and is it for you. Keeping them
/// separate is why a screen can say two different things instead of
/// greying the row out.
///
/// This does not ask whether the item is carried, and it does not
/// evict anything — those belong to the command that changes state.
RefusalReason? checkEquip({
  required Member member,
  required EquipSlot slot,
  required ItemDef item,
  required ItemCatalog catalog,
}) {
  if (!item.allowedSlots.contains(slot)) return RefusalReason.wrongSlot;

  if (item.kind == ItemKind.classAmulet) {
    if (!item.classMask.admits(member.clazz)) return RefusalReason.wrongClass;
    final other = slot == EquipSlot.classAmulet1
        ? EquipSlot.classAmulet2
        : EquipSlot.classAmulet1;
    if (member.at(other) == item.ref) return RefusalReason.duplicateAmulet;
  }

  if (slot == EquipSlot.leftHand) {
    if (item.isTwoHanded) return RefusalReason.twoHandedInOffHand;
    final main = _defAt(member, EquipSlot.rightHand, catalog);
    if (main != null && main.isTwoHanded) return RefusalReason.offHandLocked;
    if (item.kind.isWeapon) {
      if (main == null || !main.kind.isWeapon) {
        return RefusalReason.noMainHandToPairWith;
      }
      if (main.kind != item.kind) return RefusalReason.mismatchedPair;
    }
  }

  return null;
}

/// Whether the off hand is shut right now.
///
/// A property of what the main hand holds, not a stored flag. A screen
/// greys the slot out by asking this.
bool isOffHandLocked(Member member, ItemCatalog catalog) {
  final main = _defAt(member, EquipSlot.rightHand, catalog);
  return main != null && main.isTwoHanded;
}

/// What in the pack could go into [slot] for this member.
///
/// The whole filter is [checkEquip], so the list a screen offers and the
/// answer a command gives can never disagree — the bug the old flow had
/// when its six-way switch and its equip step were written separately.
List<ItemRef> candidatesFor({
  required Member member,
  required EquipSlot slot,
  required Iterable<ItemRef> carried,
  required ItemCatalog catalog,
}) {
  final out = <ItemRef>[];
  for (final ref in carried) {
    final def = catalog[ref];
    if (def == null) continue;
    if (checkEquip(
          member: member,
          slot: slot,
          item: def,
          catalog: catalog,
        ) ==
        null) {
      out.add(ref);
    }
  }
  return out;
}

ItemDef? _defAt(Member member, EquipSlot slot, ItemCatalog catalog) {
  final ref = member.at(slot);
  return ref == null ? null : catalog[ref];
}
