import 'wire.dart';

/// The eight places something can be worn.
///
/// ## Two hands, and three amulets
///
/// The predecessor had six slots with the off hand reserved for a
/// shield, which left dual wielding and a held torch with nowhere to go.
/// Here both hands are real slots and what may enter them is a property
/// of the item, not of the slot.
///
/// `wire` 0..5 are the values the previous model shipped, so a save
/// written by it still reads. 6 and 7 are new and simply absent from an
/// older file.
enum EquipSlot implements Wired {
  /// Main hand. Anything that is a weapon at all.
  rightHand(0),

  /// Off hand. A shield, a second one-handed weapon of the same class,
  /// or a torch. Locked while the main hand holds a two-handed weapon.
  leftHand(1),

  body(2),
  head(3),
  legs(4),

  /// Worn by anyone, whatever their race or class.
  commonAmulet(5),

  /// Restricted to the wearer's own class.
  classAmulet1(6),

  /// The second such slot. Two, so that a build has to give something
  /// up; one would collapse to a single best answer.
  classAmulet2(7);

  const EquipSlot(this.wire);

  @override
  final int wire;

  static EquipSlot? fromWire(int wire) => byWire(values, wire);

  bool get isHand => this == rightHand || this == leftHand;

  bool get isClassAmulet => this == classAmulet1 || this == classAmulet2;

  /// The order a screen shows them in, which is not the storage order.
  static const List<EquipSlot> displayOrder = [
    rightHand,
    leftHand,
    head,
    body,
    legs,
    commonAmulet,
    classAmulet1,
    classAmulet2,
  ];
}
