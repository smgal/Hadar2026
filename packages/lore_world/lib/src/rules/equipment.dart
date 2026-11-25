import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/equipment_table.dart';
import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';

/// 그 대원이 그 장비를 쓸 수 있는가. 쓸 수 있으면 null, 아니면 이유.
///
/// 화면이 목록을 밝게·어둡게 칠할 때와 [EquipmentRules.equip] 이 **같은
/// 판정**을 쓴다. 판정을 두 군데 쓰면 갈라지는 날이 온다.
RefusalReason? checkUsable(Member m, String key) {
  final slot = equipSlotOf(key);
  if (slot == null) return RefusalReason.unknownItem;
  final clazz = m.classDef;
  if (clazz == null) return RefusalReason.classCannotUse;
  switch (slot) {
    case EquipSlot.weapon:
      return clazz.weapons.contains(weaponByKey(key)!.kind)
          ? null
          : RefusalReason.classCannotUse;
    case EquipSlot.shield:
      return clazz.shield ? null : RefusalReason.classCannotUse;
    case EquipSlot.armour:
      return clazz.canWearArmour(armourByKey(key)!.legacyId)
          ? null
          : RefusalReason.classCannotUse;
  }
}

String? _equipped(Member m, EquipSlot slot) => switch (slot) {
  EquipSlot.weapon => m.weapon,
  EquipSlot.shield => m.shield,
  EquipSlot.armour => m.armour,
};

void _setEquipped(Member m, EquipSlot slot, String? key) {
  switch (slot) {
    case EquipSlot.weapon:
      m.weapon = key;
      // 「신의 축복」은 그 무기에 내린 것이다 — 바꾸거나 내려놓으면 끝난다.
      m.weaponBlessed = false;
    case EquipSlot.shield:
      m.shield = key;
    case EquipSlot.armour:
      m.armour = key;
      // 원작의 「방어력을 다시 계산」 — 갑옷 파괴로 깎인 값이 사라진다.
      m.acPenalty = 0;
  }
}

/// 장착 · 해제 · 버림(제10장 10.1).
extension EquipmentRules on LoreWorld {
  /// 그 칸에 지금 장착한 것. 없으면 null.
  String? equippedIn(int seat, EquipSlot slot) {
    final m = member(seat);
    return m == null ? null : _equipped(m, slot);
  }

  /// 장착할 수 있는가. 되면 null, 아니면 이유.
  RefusalReason? checkEquip(int seat, String key) {
    final m = member(seat);
    if (m == null) return RefusalReason.noSuchMember;
    final slot = equipSlotOf(key);
    if (slot == null) return RefusalReason.unknownItem;
    if ((backpack[key] ?? 0) <= 0) return RefusalReason.notInBackpack;
    if (_equipped(m, slot) != null) return RefusalReason.slotOccupied;
    return checkUsable(m, key);
  }

  /// 배낭에서 꺼내 장착한다. 이미 장착한 칸은 먼저 해제해야 한다.
  Outcome equip(int seat, String key) {
    final refusal = checkEquip(seat, key);
    if (refusal != null) return Outcome.refused(refusal, seat: seat, key: key);
    final m = seats[seat]!;
    final slot = equipSlotOf(key)!;
    take(key);
    _setEquipped(m, slot, key);
    return Outcome.accepted([Equipped(seat, slot, key)]);
  }

  /// 장착한 것을 배낭으로 돌려보낸다.
  Outcome unequip(int seat, EquipSlot slot) {
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    final key = _equipped(m, slot);
    if (key == null) {
      return Outcome.refused(RefusalReason.nothingEquipped, seat: seat);
    }
    if ((backpack[key] ?? 0) >= stackLimit) {
      return Outcome.refused(RefusalReason.backpackFull, seat: seat, key: key);
    }
    give(key);
    _setEquipped(m, slot, null);
    return Outcome.accepted([Unequipped(seat, slot, key)]);
  }

  /// 「일행의 장비를 버림」 — 장착한 장비 하나를 없앤다. 돌아오지 않는다.
  Outcome discardEquipped(int seat, EquipSlot slot) {
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    final key = _equipped(m, slot);
    if (key == null) {
      return Outcome.refused(RefusalReason.nothingEquipped, seat: seat);
    }
    _setEquipped(m, slot, null);
    return Outcome.accepted([EquipmentDiscarded(seat, slot, key)]);
  }
}
