import 'capability.dart';
import 'character_class.dart';
import 'equip_slot.dart';
import 'ids.dart';
import 'item_kind.dart';
import 'modifier.dart';

/// One row of the item catalogue. Immutable reference data.
///
/// ## What an item may say about itself
///
/// Numbers it moves ([modifiers]), ailments it turns aside
/// ([immunities]), and things it lets the party do ([grants]). All
/// three are **data**, so a new amulet is a new row and not a new
/// branch somewhere. That is the whole extensibility claim of this
/// package, and the reason the previous model needed a code change for
/// every effect.
///
/// [nameKey] is a key, not a name. Sentences live outside this package,
/// the way battle text does — the model never holds display strings.
class ItemDef {
  const ItemDef({
    required this.ref,
    required this.nameKey,
    required this.kind,
    this.hands = Hands.one,
    this.shape,
    this.attackPower = 0,
    this.modifiers = const [],
    this.immunities = const {},
    this.grants = const {},
    this.classMask = const ClassMask.any(),
    this.annexKey = '',
    this.removable = true,
    this.legacyIndex = -1,
  });

  final ItemRef ref;

  /// Lookup key for the display name. Never the name itself.
  final String nameKey;

  final ItemKind kind;

  /// How many hands it asks for. Meaningless for anything but a weapon,
  /// and left at one there.
  final Hands hands;

  /// The physical form, for a weapon. Null otherwise.
  final WeaponShape? shape;

  /// How hard it hits. The battle multiplies this; it never reads
  /// [shape] or [hands], which decide reach instead.
  final int attackPower;

  final List<Modifier> modifiers;
  final Set<Ailment> immunities;
  final Set<Capability> grants;

  /// Which classes may wear it. Any, unless it is a class amulet.
  final ClassMask classMask;

  /// Whether it can be taken off at all.
  ///
  /// False for bare hands, which the original also refused to remove:
  /// an empty main hand is not a state the rules have a formula for.
  final bool removable;

  /// The original's free-text stat rider, kept verbatim as a key so the
  /// three items that shipped with one are not silently dropped.
  final String annexKey;

  /// Position this row held in the original's tables, or -1 for
  /// something new. Lets cm2 keep addressing items by number.
  final int legacyIndex;

  Set<EquipSlot> get allowedSlots => kind.allowedSlots;

  bool get isTwoHanded => kind.isWeapon && hands == Hands.two;

  @override
  String toString() => 'ItemDef(${ref.value})';
}
