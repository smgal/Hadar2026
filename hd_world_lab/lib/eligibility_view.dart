import 'package:hd_world/hd_world.dart';

/// Whether every item could go into every slot, for every member.
///
/// ## Why the whole board, in one answer
///
/// The screen colours a tile by what would happen if it were dropped
/// there, and a pointer moves faster than a round trip. Asking per
/// hover would either lag or push the rule into the browser — and the
/// rule may not live in the browser, because [checkEquip] is the only
/// authority on this and it is in the model.
///
/// So the answer is precomputed for the whole board. 59 items × 8 slots
/// × 5 members is small, and it can only go stale when the world
/// changes, which is exactly when the screen refetches it.
///
/// ## Carried is deliberately not folded in
///
/// [checkEquip] does not ask whether a thing is in the pack, and this
/// keeps that separation: `fits` says the rule would allow it, `carried`
/// says how many there are. A screen needs both as different colours —
/// "you own none" and "that is not for your class" are not the same
/// answer, which is the same distinction the refusal enum was built to
/// preserve.
Map<String, Object?> eligibilityJson(World world) {
  final catalog = world.catalog;
  final items = catalog.all.toList();

  final equippedBy = <String, List<Map<String, Object?>>>{};
  for (final m in world.members) {
    for (final slot in EquipSlot.displayOrder) {
      final ref = m.at(slot);
      if (ref == null) continue;
      (equippedBy[ref.value] ??= []).add({
        'member': m.ref.value,
        'slot': slot.name,
      });
    }
  }

  final byMember = <String, Object?>{};
  for (final m in world.members) {
    final rows = <String, Object?>{};
    for (final def in items) {
      final verdicts = <String, Object?>{};
      for (final slot in EquipSlot.displayOrder) {
        final reason = checkEquip(
          member: m,
          slot: slot,
          item: def,
          catalog: catalog,
        );
        verdicts[slot.name] = reason == null ? true : reason.name;
      }
      rows[def.ref.value] = verdicts;
    }
    byMember[m.ref.value] = rows;
  }

  return {
    'members': byMember,
    'equippedBy': equippedBy,
    'carried': {
      for (final e in world.pack.counts.entries) e.key.value: e.value,
    },
    // Distinct kinds, because that is what capacity counts. Showing a
    // unit total against a kind limit would read as a full pack that
    // still accepts things.
    'packCapacity': world.pack.capacity,
    'packKinds': world.pack.kindCount,
    'packUnits': world.pack.counts.values.fold<int>(0, (a, b) => a + b),
  };
}
