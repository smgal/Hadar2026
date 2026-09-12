/// Every identity that crosses a boundary carries an explicit integer.
///
/// ## Why this file exists
///
/// Three boundaries read these numbers: the HTTP surface, a save file,
/// and the legacy cm2 scripts. `Enum.index` changes when a member is
/// inserted, so it can never be the identity — the same rule
/// `HDTileAction.scriptMode` follows on the app side. Anything with a
/// `wire` is pinned by a test that spells the number out as a literal.
///
/// Adding a member is safe. Renumbering one is a breaking change.
abstract interface class Wired {
  /// Stable integer identity. Never derived from a position.
  int get wire;
}

/// Looks a [Wired] member up by its number.
///
/// Returns null rather than throwing or falling back to a default: a
/// number arriving from outside is the caller's error to report, and a
/// silent default is how `Party::CheckIf` used to mis-branch.
T? byWire<T extends Wired>(List<T> values, int wire) {
  for (final value in values) {
    if (value.wire == wire) return value;
  }
  return null;
}
