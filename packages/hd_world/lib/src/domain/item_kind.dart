import 'equip_slot.dart';
import 'wire.dart';

/// What kind of thing an item is.
///
/// `wire` 0..12 are the original's `ITEM_TYPE` numbers, which cm2 still
/// passes around as a single integer. 13 and 14 are new; the original's
/// range ended at an exclusive 12.
enum ItemKind implements Wired {
  /// Cutting weapon.
  slashWeapon(0),

  /// Chopping weapon.
  chopWeapon(1),

  /// Thrusting weapon.
  pierceWeapon(2),

  /// Striking weapon.
  bluntWeapon(3),

  /// Missile weapon.
  missileWeapon(4),

  /// A summoned creature's attack, held in its hand.
  summonSingle(5),
  summonMulti(6),

  shield(7),
  bodyArmour(8),
  helmet(9),
  boots(10),

  /// The amulet anyone may wear. Its restriction is that it has none.
  commonAmulet(11),

  /// Used up rather than worn.
  consumable(12),

  /// A held light. Occupies a hand, which is the whole cost of it.
  light(13),

  /// The amulet only one class may wear.
  classAmulet(14);

  const ItemKind(this.wire);

  @override
  final int wire;

  static ItemKind? fromWire(int wire) => byWire(values, wire);

  bool get isWeapon =>
      wire >= slashWeapon.wire && wire <= missileWeapon.wire ||
      this == summonSingle ||
      this == summonMulti;

  bool get isArmour =>
      this == bodyArmour || this == helmet || this == boots || this == shield;

  bool get isAmulet => this == commonAmulet || this == classAmulet;

  /// Where this kind is allowed to sit.
  ///
  /// A set, not a single value. That one change is what admits dual
  /// wielding, a held torch, and two class-amulet slots — the
  /// predecessor answered with one slot and refused everything else.
  Set<EquipSlot> get allowedSlots => switch (this) {
    slashWeapon ||
    chopWeapon ||
    pierceWeapon ||
    bluntWeapon ||
    missileWeapon => const {EquipSlot.rightHand, EquipSlot.leftHand},
    summonSingle || summonMulti => const {EquipSlot.rightHand},
    shield || light => const {EquipSlot.leftHand},
    bodyArmour => const {EquipSlot.body},
    helmet => const {EquipSlot.head},
    boots => const {EquipSlot.legs},
    commonAmulet => const {EquipSlot.commonAmulet},
    classAmulet => const {EquipSlot.classAmulet1, EquipSlot.classAmulet2},
    consumable => const {},
  };
}

/// How many hands an item asks for.
enum Hands implements Wired {
  one(1),
  two(2);

  const Hands(this.wire);

  @override
  final int wire;

  static Hands? fromWire(int wire) => byWire(values, wire);
}

/// The physical form of a weapon.
///
/// Separate from [ItemKind] because the kind says how a blow lands
/// (cut, chop, thrust, strike, shot) while the shape says what the
/// thing is. Both are needed to name the fighting style: a two-handed
/// cutting *blade* is a great sword, a two-handed striking *mace* is a
/// war hammer, and the kind alone cannot tell them apart.
enum WeaponShape implements Wired {
  blade(0),
  axe(1),
  mace(2),
  spear(3),

  /// A haft with a head on it — halberd, poleaxe, trident.
  polearm(4),

  /// A cavalry lance. Long enough that closing ruins it.
  lance(5),
  staff(6),
  knuckle(7),
  bow(8),
  crossbow(9),
  arbalest(10),

  /// Anything let go of.
  thrown(11),

  /// A tube that delivers a coating rather than a wound.
  blowpipe(12);

  const WeaponShape(this.wire);

  @override
  final int wire;

  static WeaponShape? fromWire(int wire) => byWire(values, wire);
}
