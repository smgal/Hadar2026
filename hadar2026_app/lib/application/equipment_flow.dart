import '../domain/item/item.dart';
import '../domain/item/item_data.dart';
import '../domain/item/item_id.dart';
import '../domain/item/item_type.dart';
import '../domain/party/party.dart';
import '../domain/party/player.dart';

/// Backpack <-> equipment moves, as pure functions over domain state.
///
/// The port of `GameEventEquipment.cs`'s equip/unequip steps
/// (`:112-133` remove, `:135-190` wear) without any of its Unity list
/// views. `HDMenuFlows` drives the prompts; everything that can go wrong
/// is decided here, so it can be tested without a UI at all.
///
/// The invariant every function keeps: **an item is never destroyed.**
/// Each move either completes as a whole or changes nothing.
class HDEquipmentFlow {
  const HDEquipmentFlow._();

  /// Backpack slot indices holding something that fits [slot].
  ///
  /// The original filtered by `(type tag, detail)` across a six-way switch
  /// (`GameEventEquipment.cs:334-360`); `HDItemType.equipSlot` already
  /// carries that mapping, so the filter is one comparison.
  static List<int> candidatesFor(HDParty party, HDEquipSlot slot) {
    final out = <int>[];
    for (var i = 0; i < party.itemCapacity; i++) {
      final id = party.itemAt(i);
      if (id != null && id.kind.equipSlot == slot) out.add(i);
    }
    return out;
  }

  /// Wears the item in backpack slot [backpackSlot], returning whatever
  /// was in [slot] to the backpack.
  ///
  /// The new item leaves the backpack *before* the old one goes in, so a
  /// full backpack can still swap. False (and no change) if the slot is
  /// empty or the item does not belong on that body part.
  static bool equipFromBackpack(
    HDParty party,
    HDPlayer player,
    HDEquipSlot slot,
    int backpackSlot,
  ) {
    final id = party.itemAt(backpackSlot);
    if (id == null || id.kind.equipSlot != slot) return false;

    final previous = player.equippedAt(slot);
    if (!party.take(id)) return false;
    if (!player.equipItem(slot, id)) {
      party.give(id);
      return false;
    }
    if (previous != null && !_isBareHand(slot, previous)) {
      party.give(previous);
    }
    return true;
  }

  /// Takes [slot] off and puts it in the backpack — the port of
  /// `OnCurrentEquipmentRemove` (`GameEventEquipment.cs:112-133`).
  ///
  /// False (and no change) when the slot is empty, when it holds bare
  /// hands (`:122`), or when the backpack has no room — refusing beats
  /// dropping the item on the floor.
  static bool unequipToBackpack(
    HDParty party,
    HDPlayer player,
    HDEquipSlot slot,
  ) {
    final id = player.equippedAt(slot);
    if (id == null || _isBareHand(slot, id)) return false;
    if (party.itemCount >= party.itemCapacity) return false;

    final removed = player.unequip(slot);
    if (removed == null) return false;
    return party.give(removed);
  }

  /// Bare hands are not an item you can take off or carry.
  static bool _isBareHand(HDEquipSlot slot, HDItemId id) =>
      slot == HDEquipSlot.hand && id.index == 0;

  /// Whether [slot] can offer a "(비운다)" choice.
  static bool canUnequip(HDParty party, HDPlayer player, HDEquipSlot slot) {
    final id = player.equippedAt(slot);
    return id != null &&
        !_isBareHand(slot, id) &&
        party.itemCount < party.itemCapacity;
  }

  // ---- 표시용 문구 ----------------------------------------------------
  //
  // domain 은 표시 문구를 갖지 않는다(`HDItemType` 에 label 이 없는 이유).
  // 화면 문구는 흐름을 짜는 이 층에 둔다.

  static const Map<HDEquipSlot, String> _slotLabels = {
    HDEquipSlot.hand: '손',
    HDEquipSlot.handSub: '방패',
    HDEquipSlot.armor: '갑옷',
    HDEquipSlot.head: '머리',
    HDEquipSlot.leg: '다리',
    HDEquipSlot.etc: '장식',
  };

  static String slotLabel(HDEquipSlot slot) => _slotLabels[slot]!;

  /// 분류 이름 — 소지품 목록의 가운데 칸.
  static String kindLabel(HDItemType type) {
    if (type.isWeapon) return '무기';
    if (type.isShield) return '방패';
    return switch (type) {
      HDItemType.armor => '갑옷',
      HDItemType.head => '머리',
      HDItemType.leg => '다리',
      HDItemType.ornament => '장식',
      _ => '',
    };
  }

  /// 수치 요약 — `공격 60` / `방어 5` / `-`.
  static String statLabel(HDItem item) {
    if (item.param.attaPow > 0) return '공격 ${item.param.attaPow}';
    if (item.param.ac > 0) return '방어 ${item.param.ac}';
    return '-';
  }

  /// 목록 한 줄. 카탈로그에 없는 id 는 이름을 잃지 않도록 id 를 보여 준다.
  static String describe(HDItemId id) {
    final item = itemById(id);
    if (item == null) return '알 수 없는 물건 ($id)';
    return '${item.name}   ${kindLabel(item.type)}   ${statLabel(item)}';
  }

  /// 슬롯 한 줄 — `손    - 단검`. 빈 칸은 인물의 기존 표시 이름을 쓴다.
  static String describeSlot(HDPlayer player, HDEquipSlot slot) {
    final id = player.equippedAt(slot);
    final name = id == null
        ? _emptyName(player, slot)
        : (itemById(id)?.name ?? '알 수 없는 물건');
    return '${slotLabel(slot).padRight(2)} - $name';
  }

  static String _emptyName(HDPlayer player, HDEquipSlot slot) =>
      switch (slot) {
        HDEquipSlot.hand => player.getWeaponName(),
        HDEquipSlot.handSub => player.getShieldName(),
        HDEquipSlot.armor => player.getArmorName(),
        _ => '없음',
      };
}
