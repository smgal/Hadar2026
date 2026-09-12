import '../domain/wire.dart';

/// Why a command was not carried out.
///
/// ## Refusals are values, not exceptions
///
/// Every reason a thing cannot be worn is a member of this enum, so a
/// screen can explain it, a test can assert on it, and the HTTP surface
/// can return it. Nothing in this package throws to say no.
///
/// The distinctions matter to a reader: "that does not go there" and
/// "that is not for your class" are different sentences, and rolling
/// them into one boolean is what made the old equipment flow silently
/// drop items.
enum RefusalReason implements Wired {
  /// No such member.
  noSuchMember(0),

  /// No such item in the catalogue.
  noSuchItem(1),

  /// The item is not in the party's pack.
  notCarried(2),

  /// That kind of item does not belong in that slot.
  wrongSlot(3),

  /// A class amulet, and not for this class.
  wrongClass(4),

  /// The main hand holds a two-handed weapon, so the off hand is shut.
  offHandLocked(5),

  /// The off hand can only take a second weapon of the same class as
  /// the main hand.
  mismatchedPair(6),

  /// A weapon in the off hand needs a one-handed weapon in the main
  /// hand to pair with.
  noMainHandToPairWith(7),

  /// A two-handed weapon cannot go in the off hand at all.
  twoHandedInOffHand(8),

  /// The slot is already empty.
  slotEmpty(9),

  /// Bare hands cannot be taken off.
  cannotRemoveBareHands(10),

  /// The pack is full, so taking the worn item off would destroy it.
  packFull(11),

  /// Two of the same class amulet on one member.
  duplicateAmulet(12);

  const RefusalReason(this.wire);

  @override
  final int wire;

  static RefusalReason? fromWire(int wire) => byWire(values, wire);
}
