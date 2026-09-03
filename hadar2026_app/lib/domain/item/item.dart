import 'item_id.dart';
import 'item_type.dart';

/// The numeric side of an item — port of `ItemSub`
/// (`ObjItem.cs:12-25`).
///
/// The original stores `atta_pow` and `ac` as `double`. They are `int`
/// here because the battle formulas are integer arithmetic end to end
/// (`application/battle.dart:439,514`), so a fractional item power would
/// be truncated at its first use anyway.
class HDItemParam {
  const HDItemParam({
    this.attaPow = 0,
    this.ac = 0,
    this.type = HDItemType.none,
  });

  /// Attack power. Feeds `HDPlayer.powOfWeapon`, which the damage
  /// formula already reads (`battle.dart:439`) — wiring it up is G1-05.
  final int attaPow;

  /// Armour class. Both damage formulas defend with `ac` alone
  /// (`battle.dart:441,514`); `powOfShield`/`powOfArmor` are read
  /// nowhere (GROUND_TRUTH H-1).
  final int ac;

  /// What kind of item this is. Mirrors [HDItemId.kind] — see [HDItem].
  final HDItemType type;

  /// Port of `ItemSub.GetDefault()` (`ObjItem.cs:17-25`): an empty slot.
  static const HDItemParam defaults = HDItemParam();

  @override
  bool operator ==(Object other) =>
      other is HDItemParam &&
      other.attaPow == attaPow &&
      other.ac == ac &&
      other.type == type;

  @override
  int get hashCode => Object.hash(attaPow, ac, type);

  @override
  String toString() =>
      'HDItemParam(attaPow: $attaPow, ac: $ac, type: ${type.name})';
}

/// One row of the item table — port of `Item` (`ObjItem.cs:30-34`).
///
/// This is the shape only; the actual weapon/armour rows are G1-02.
class HDItem {
  /// [param]`.type` must equal [id]`.kind`.
  ///
  /// The original carried the two independently because `ResId`'s type
  /// byte was only a coarse tag; here [HDItemId.kind] is the precise
  /// type, so the pair is redundant and an assert keeps it from
  /// drifting. (The assert is what costs this constructor `const` —
  /// reading a field of a parameter is not a constant expression.)
  HDItem({
    required this.id,
    required this.name,
    required this.param,
    this.annex = '',
  }) : assert(
         param.type == id.kind,
         'param.type (${param.type.name}) must match id.kind '
         '(${id.kind.name})',
       );

  /// Where this row lives in the table.
  final HDItemId id;

  /// The name shown to the player. This is what replaces the
  /// `"무기1"` placeholders (G1-06).
  final String name;

  /// Attack power / armour class / kind.
  final HDItemParam param;

  /// Stat riders, kept verbatim as the original's string form —
  /// e.g. `"ATT+1AC-1STR+1"`. The original parses it with a regex at
  /// `ObjItem.cs:668-729`; nothing here parses it yet, and doing so is
  /// outside G1.
  final String annex;

  /// What kind of item this is. [id] is the authority; [param]`.type`
  /// is held to the same value by the constructor's assert.
  HDItemType get type => id.kind;

  @override
  bool operator ==(Object other) =>
      other is HDItem &&
      other.id == id &&
      other.name == name &&
      other.param == param &&
      other.annex == annex;

  @override
  int get hashCode => Object.hash(id, name, param, annex);

  @override
  String toString() => 'HDItem($id, "$name", $param, annex: "$annex")';
}
