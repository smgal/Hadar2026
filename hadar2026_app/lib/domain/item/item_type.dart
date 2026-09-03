/// What kind of thing an item is, and which body part it goes on.
///
/// Ported 1:1 from the original Unity build — `ITEM_TYPE` and `EQUIP` in
/// `REF_UNITY_LoreEp1/src_as_cs/ObjTypes.cs:32-49,81-85`.
library;

/// Item classification — port of `ITEM_TYPE` (`ObjTypes.cs:32-49`).
///
/// The original carved the range into groups with aliased sentinel
/// members (`WEAPON_MIN = 0`, `SHIELD_MIN = WEAPON_MAX`, …). Dart enums
/// have no value aliases, so the sentinels are *not* members here: every
/// member carries its explicit [wire] value and the group questions are
/// answered by [isWeapon] / [isShield] / [isArmorGroup] / [isEtc], which
/// reproduce the original `*_MIN <= x < *_MAX` bounds.
///
/// [wire] is a contract value, **not `Enum.index`** — the same rule
/// `HDTileAction.scriptMode` follows. It is packed into `HDItemId.wire`
/// (cm2 receives an item as a single integer) and lands in save files, so
/// reordering the members would break both. `test/domain/item/
/// item_type_test.dart` pins every value as a literal.
enum HDItemType {
  /// No item — the original's `ITEM_TYPE.NONE`. Never a valid
  /// `HDItemId` kind; an absent item is a null `HDItem`/`HDItemId`.
  none(-1),

  // Weapons: WEAPON_MIN(0) .. WEAPON_MAX(7)
  /// 베는 무기.
  wield(0),

  /// 찍는 무기.
  chop(1),

  /// 찌르는 무기.
  stab(2),

  /// 타격 무기.
  hit(3),

  /// 쏘는 무기.
  shoot(4),

  /// A single summoned creature's attack. Held in the summon's hand —
  /// `ObjParty.cs:1651` equips it as `EQUIP.HAND`.
  summonSingle(5),

  /// A multi-summon's attack. Also `EQUIP.HAND` (`ObjParty.cs:1677`).
  summonMulti(6),

  // Shield: SHIELD_MIN(7) .. SHIELD_MAX(8)
  shield(7),

  // Armour group: ARMOR_MIN(8) .. ARMOR_MAX(11)
  /// Body armour.
  armor(8),

  /// Helmet.
  head(9),

  /// Sabatons — the original comment reads `Leg -> Sabaton`.
  leg(10),

  // Etc: ETC_MIN(11) .. ETC_MAX(12)
  ornament(11);

  const HDItemType(this.wire);

  /// Stable integer identity. See the note on [HDItemType] before
  /// changing — this crosses into cm2 arguments and save files.
  final int wire;

  // The original's group sentinels, kept as bounds rather than members.
  static const int _weaponMin = 0;
  static const int _weaponMax = 7;
  static const int _shieldMin = 7;
  static const int _shieldMax = 8;
  static const int _armorMin = 8;
  static const int _armorMax = 11;
  static const int _etcMin = 11;
  static const int _etcMax = 12;

  /// `WEAPON_MIN <= x < WEAPON_MAX` — the five weapon classes plus the
  /// two summon attacks.
  bool get isWeapon => wire >= _weaponMin && wire < _weaponMax;

  /// `SHIELD_MIN <= x < SHIELD_MAX`.
  bool get isShield => wire >= _shieldMin && wire < _shieldMax;

  /// `ARMOR_MIN <= x < ARMOR_MAX` — body, head and legs.
  bool get isArmorGroup => wire >= _armorMin && wire < _armorMax;

  /// `ETC_MIN <= x < ETC_MAX`.
  bool get isEtc => wire >= _etcMin && wire < _etcMax;

  /// Which equipment slot this kind can occupy, or null for [none].
  ///
  /// The mapping is the original's, read off the equipment screen's slot
  /// order (`GameEventEquipment.cs:334-360`, `_ix_equipment` 0..5) and
  /// `ObjPlayer.SetEquipment` call sites.
  HDEquipSlot? get equipSlot => switch (this) {
    wield || chop || stab || hit || shoot => HDEquipSlot.hand,
    summonSingle || summonMulti => HDEquipSlot.hand,
    shield => HDEquipSlot.handSub,
    armor => HDEquipSlot.armor,
    head => HDEquipSlot.head,
    leg => HDEquipSlot.leg,
    ornament => HDEquipSlot.etc,
    none => null,
  };

  /// The member whose [wire] is [value], or null if none matches.
  ///
  /// Deliberately nullable: an out-of-range value arriving from cm2 or a
  /// save file is a caller-visible error, not something to silently fold
  /// into a default.
  static HDItemType? fromWire(int value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

/// A body part an item can be worn on — port of `EQUIP`
/// (`ObjTypes.cs:81-85`). The original's `MAX` sentinel is not a member.
///
/// [wire] follows the same rule as [HDItemType.wire]: explicit, pinned by
/// test, never `Enum.index`.
enum HDEquipSlot {
  /// Main hand — weapons and summon attacks.
  hand(0),

  /// Off hand — the shield.
  handSub(1),

  /// Body armour.
  armor(2),

  /// Helmet.
  head(3),

  /// Sabatons.
  leg(4),

  /// Ornament.
  etc(5);

  const HDEquipSlot(this.wire);

  /// Stable integer identity; reaches save files.
  final int wire;

  /// The member whose [wire] is [value], or null if none matches.
  static HDEquipSlot? fromWire(int value) {
    for (final slot in values) {
      if (slot.wire == value) return slot;
    }
    return null;
  }
}
