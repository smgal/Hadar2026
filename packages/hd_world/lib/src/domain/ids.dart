/// Identities.
///
/// Both are opaque strings rather than table positions. The predecessor
/// keyed items by `(kind, index)` and members by their slot in a fixed
/// list, which meant inserting a row renamed the things after it and
/// reordering the party changed who a save referred to.
extension type const ItemRef(String value) {
  bool get isEmpty => value.isEmpty;
}

extension type const MemberRef(String value) {
  bool get isEmpty => value.isEmpty;
}
