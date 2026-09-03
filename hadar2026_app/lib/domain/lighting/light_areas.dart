/// Rectangles a script has forced to stay lit, regardless of the hour or
/// the party's sight radius.
///
/// The original exposes this one tile at a time —
/// `REF_hadar/src/hadar/hd_base_extern.h:44-45`:
///
/// ```cpp
/// void map::setLight(int x, int y);
/// void map::resetLight(int x, int y);
/// ```
///
/// cm2 calls it with four arguments (`L1_ep1d1.cm2:331`
/// `Map::SetLightArea(8,10, 14,15)`), so the script-facing form is a
/// rectangle and this class is the loop around the original's per-tile
/// call. Storing rectangles rather than a per-tile bitmap keeps it
/// independent of map size and cheap to reset.
///
/// Per-map state: the session clears it on every map transition, the way
/// the original's map data does not carry lighting across maps.
class HDLightAreas {
  final List<List<int>> _rects = [];

  /// Whether any script has lit tile ([x], [y]).
  bool isLit(int x, int y) {
    for (final r in _rects) {
      if (x >= r[0] && x <= r[2] && y >= r[1] && y <= r[3]) return true;
    }
    return false;
  }

  /// Lights the rectangle spanning ([x1],[y1])..([x2],[y2]) inclusive.
  /// The corners may be given in any order.
  void set(int x1, int y1, int x2, int y2) {
    final rect = _normalise(x1, y1, x2, y2);
    if (_rects.any((r) => _same(r, rect))) return;
    _rects.add(rect);
  }

  /// Undoes a [set] of exactly the same rectangle.
  ///
  /// Only whole rectangles are removed — the original pairs
  /// `resetLight` with the matching `setLight`, and cm2 does the same
  /// (`L1_ep1d4.cm2:73` resets the same `12,16, 12,16` that `:480`
  /// sets). Punching a hole in an overlapping rectangle is not a case the
  /// original has.
  bool reset(int x1, int y1, int x2, int y2) {
    final rect = _normalise(x1, y1, x2, y2);
    final before = _rects.length;
    _rects.removeWhere((r) => _same(r, rect));
    return _rects.length != before;
  }

  /// Drops every rectangle — called on a map transition.
  void clear() => _rects.clear();

  /// How many rectangles are active. For tests and diagnostics.
  int get count => _rects.length;

  static List<int> _normalise(int x1, int y1, int x2, int y2) => [
    x1 < x2 ? x1 : x2,
    y1 < y2 ? y1 : y2,
    x1 > x2 ? x1 : x2,
    y1 > y2 ? y1 : y2,
  ];

  static bool _same(List<int> a, List<int> b) =>
      a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3];
}
