import 'item_type.dart';

/// The address of one item in the item table: a `(kind, detail, index)`
/// coordinate.
///
/// Port of the original's `ResId` (`ObjItem.cs:42-231`) with the top
/// eight bits dropped. The original packed a two-bit verification tag
/// into bits 30-31 so a bare `uint` could answer "is this actually an
/// item id?" at runtime; Dart answers that at compile time with
/// `HDItemId?`, so the tag has no job here. The two other tag values are
/// dead in the original as well — nothing constructs a `ResId` from the
/// reserved tag, and `ResId(string)` (the six-character name packing at
/// `ObjItem.cs:120-149`) has no call site in `src_as_cs/` and could not
/// hold a Korean item name in any case.
///
/// What is kept is the three-axis coordinate and its byte layout. The
/// equipment screen filters the backpack by kind *and* detail
/// (`GameEventEquipment.cs:334-360`), and cm2 has to be able to name an
/// item with a single integer, which [wire] provides — laid out exactly
/// like `ResId`'s low 24 bits:
///
/// ```text
///  [ kind ]  [detail]  [ index]
///  kkkkkkkk  dddddddd  iiiiiiii
/// ```
///
/// One deliberate difference: `ResId`'s type byte held a coarse tag
/// (`ITEM_TYPE_TAG_WEAPON` = 1, `_SHIELD` = 2, `_ARMOR` = 3,
/// `_ORNAMENT` = 4) and leaned on `detail` to recover the precise type.
/// Here the byte is [HDItemType.wire] itself, so `kind` is already
/// precise and `detail` is free for finer classification.
class HDItemId {
  /// Throws in debug if [kind] is [HDItemType.none] — an absent item is
  /// a null `HDItemId`, never a `none`-kinded one — or if [detail] or
  /// [index] does not fit in a byte.
  const HDItemId(this.kind, {this.detail = 0, this.index = 0})
    : assert(
        kind != HDItemType.none,
        'HDItemType.none is not an item; use a null HDItemId instead',
      ),
      assert(detail >= 0 && detail <= _byteMax, 'detail must fit in a byte'),
      assert(index >= 0 && index <= _byteMax, 'index must fit in a byte');

  /// What the item is.
  final HDItemType kind;

  /// Sub-classification within [kind]. Free axis; the item table
  /// (G1-02) decides what it means per kind.
  final int detail;

  /// Which row of `(kind, detail)` this is.
  final int index;

  static const int _byteMax = 0xFF;
  static const int _kindShift = 16;
  static const int _detailShift = 8;

  /// The three axes folded into one integer — `ResId`'s low 24 bits.
  ///
  /// This is what cm2 scripts pass around and what save files store, so
  /// the layout is pinned by test.
  int get wire =>
      (kind.wire << _kindShift) | (detail << _detailShift) | index;

  /// Unpacks [wire]; throws [ArgumentError] if it does not name an item.
  ///
  /// cm2 arguments and save data both arrive as plain integers, and a
  /// bad one has to be loud — silently ignoring an out-of-range argument
  /// is exactly the failure mode P0-14 records.
  factory HDItemId.fromWire(int wire) {
    final id = tryFromWire(wire);
    if (id == null) {
      throw ArgumentError.value(wire, 'wire', 'not a valid item id');
    }
    return id;
  }

  /// Unpacks [wire], or returns null if it does not name an item — the
  /// tolerant form of [HDItemId.fromWire] for callers that want to
  /// report the failure themselves.
  static HDItemId? tryFromWire(int wire) {
    if (wire < 0 || wire > 0xFFFFFF) return null;
    final kind = HDItemType.fromWire((wire >> _kindShift) & _byteMax);
    if (kind == null || kind == HDItemType.none) return null;
    return HDItemId(
      kind,
      detail: (wire >> _detailShift) & _byteMax,
      index: wire & _byteMax,
    );
  }

  @override
  bool operator ==(Object other) => other is HDItemId && other.wire == wire;

  @override
  int get hashCode => wire;

  @override
  String toString() =>
      'HDItemId(${kind.name}, $detail, $index '
      '= 0x${wire.toRadixString(16).padLeft(6, '0')})';
}
