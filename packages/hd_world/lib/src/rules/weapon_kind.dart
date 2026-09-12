import '../domain/item_def.dart';
import '../domain/item_kind.dart';
import '../domain/wire.dart';

/// The fighting style a pair of hands adds up to.
///
/// ## Derived, never stored
///
/// There is no "weapon kind" field on a member and no slot to choose
/// one in. The style is a **function of what is held**, recomputed
/// whenever the hands change, so it can never disagree with the
/// equipment screen. That is the whole reason the two hands became real
/// slots.
enum WeaponKind implements Wired {
  /// Nothing in the main hand.
  unarmed(0),

  /// One weapon, the other hand free. Light on its feet.
  oneHanded(1),

  /// One weapon and a shield. The shield also gives a way to strike.
  swordAndShield(2),

  /// A one-handed spear and a shield. Holds a line and answers back.
  spearAndShield(3),

  /// Two weapons of the same class. Strikes twice, carries two
  /// coatings.
  dualWield(4),

  /// One weapon and a light. Sees, but gives up the free hand.
  torchbearer(5),

  /// Two-handed blade. Builds momentum while it keeps landing.
  greatSword(6),

  /// Two-handed striking weight. Its charge always drives the target
  /// back.
  warHammer(7),

  /// A staff. The same at every distance, which nothing else is.
  longStaff(8),

  /// A hafted head. Spear at range, axe up close, and the distance
  /// decides which.
  polearm(9),

  /// A cavalry lance. Reaches furthest and hates being closed on.
  lance(10),

  /// Shoots from the back rank; helpless once something is on top of
  /// it.
  bow(11),

  /// Shoots from anywhere, and weakly.
  crossbow(12),

  /// Shoots hardest of all, from a set position.
  arbalest(13),

  /// Thrown from the middle rank, with a hand left for a shield.
  thrown(14);

  const WeaponKind(this.wire);

  @override
  final int wire;

  static WeaponKind? fromWire(int wire) => byWire(values, wire);

  /// Whether this style leaves the off hand free to carry a light.
  bool get canCarryLight =>
      this == oneHanded || this == thrown || this == unarmed;
}

/// Reads the style off the two hands.
///
/// Order of questions: the shapes that are their own answer come first
/// (a bow is a bow whatever the other hand holds), then the number of
/// hands, then what the off hand carries.
WeaponKind weaponKindFor({ItemDef? right, ItemDef? left}) {
  if (right == null || !right.kind.isWeapon) return WeaponKind.unarmed;

  // Self-identifying shapes. A thrown weapon keeps a shield hand and is
  // still thrown; a staff is a staff.
  final selfNamed = switch (right.shape) {
    WeaponShape.bow => WeaponKind.bow,
    WeaponShape.crossbow => WeaponKind.crossbow,
    WeaponShape.arbalest => WeaponKind.arbalest,
    WeaponShape.lance => WeaponKind.lance,
    WeaponShape.staff => WeaponKind.longStaff,
    WeaponShape.thrown || WeaponShape.blowpipe => WeaponKind.thrown,
    _ => null,
  };
  if (selfNamed != null) return selfNamed;

  if (right.hands == Hands.two) {
    return switch (right.shape) {
      WeaponShape.blade => WeaponKind.greatSword,
      WeaponShape.mace => WeaponKind.warHammer,
      WeaponShape.polearm || WeaponShape.spear || WeaponShape.axe =>
        WeaponKind.polearm,
      _ => WeaponKind.greatSword,
    };
  }

  // One-handed. The off hand names it.
  if (left != null) {
    if (left.kind == ItemKind.light) return WeaponKind.torchbearer;
    if (left.kind == ItemKind.shield) {
      return right.shape == WeaponShape.spear
          ? WeaponKind.spearAndShield
          : WeaponKind.swordAndShield;
    }
    if (left.kind.isWeapon) return WeaponKind.dualWield;
  }
  return WeaponKind.oneHanded;
}

/// What a style adds beyond reach.
///
/// ## Not on the item, and not in the battle
///
/// Two daggers and one dagger are the same row in any reach table, so
/// these numbers cannot live on an item. And the battle cannot work them
/// out, because it never sees both hands. So they live here, next to the
/// derivation that names the style, and travel as plain numbers.
class StylePassives {
  const StylePassives({
    this.strikes = 1,
    this.evasion = 0,
    this.initiative = 0,
    this.coatings = 1,
  });

  /// How many blows one attack action lands.
  final int strikes;

  /// Added to evasion. A free hand is what makes a light style light.
  final int evasion;

  /// Added to initiative. Negative for weight — a crossbow is wound.
  final int initiative;

  /// How many coatings the weapon holds at once.
  final int coatings;
}

/// The passives table.
///
/// The evasion a free hand buys is deliberately **smaller than a
/// shield's** contribution, so dropping the shield is a decision rather
/// than an upgrade. Holding a light fills the hand, so a torchbearer
/// gets nothing — that is the second price of seeing in the dark.
const Map<WeaponKind, StylePassives> stylePassives = {
  WeaponKind.unarmed: StylePassives(),
  WeaponKind.oneHanded: StylePassives(evasion: 4, initiative: 5),
  WeaponKind.swordAndShield: StylePassives(),
  WeaponKind.spearAndShield: StylePassives(),
  WeaponKind.dualWield: StylePassives(strikes: 2, evasion: 2, coatings: 2),
  WeaponKind.torchbearer: StylePassives(),
  WeaponKind.greatSword: StylePassives(),
  WeaponKind.warHammer: StylePassives(initiative: -3),
  WeaponKind.longStaff: StylePassives(evasion: 4),
  WeaponKind.polearm: StylePassives(),
  WeaponKind.lance: StylePassives(),
  WeaponKind.bow: StylePassives(),
  WeaponKind.crossbow: StylePassives(initiative: -2),
  WeaponKind.arbalest: StylePassives(initiative: -5),
  WeaponKind.thrown: StylePassives(),
};

StylePassives passivesFor(WeaponKind kind) =>
    stylePassives[kind] ?? const StylePassives();
