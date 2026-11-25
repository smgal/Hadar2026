/// One map cell, as read from the six RPG Maker MV layers (z0~z5).
///
/// Five-layer layout (BP-36 R-36-57):
/// - [ixTile] z0 L1 ground (Lore_A5)
/// - [ixDecor] z1 L2 floor decor — rugs, grass flowers (Lore_B). People
///   walk over it, so it never decides the tile action.
/// - [ixObj0] z2 L3 object — tables, furniture, trees, NPCs (Lore_B). Blocks.
/// - [ixObj1] z3 L4 top object — small things on a table or bare floor
///   (Lore_B). Blocks, and is checked before [ixObj0].
/// - [shadow] z4 L5 light/shadow quadrant bits
/// - [ixEvent] z5 region id, then overwritten by `events[]` type bits
class MapUnit {
  int ixTile;
  int ixDecor;
  int ixObj0;
  int ixObj1;
  int shadow;
  int ixEvent;

  MapUnit({
    this.ixTile = 0,
    this.ixDecor = 0,
    this.ixObj0 = 0,
    this.ixObj1 = 0,
    this.shadow = 0,
    this.ixEvent = 0,
  });

  factory MapUnit.fromJson(Map<String, dynamic> json) {
    return MapUnit(
      ixTile: json['ixTile'] ?? 0,
      // Saves made before the five-layer layout have no ixDecor.
      ixDecor: json['ixDecor'] ?? 0,
      ixObj0: json['ixObj0'] ?? 0,
      ixObj1: json['ixObj1'] ?? 0,
      shadow: json['shadow'] ?? 0,
      ixEvent: json['ixEvent'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ixTile': ixTile,
      'ixDecor': ixDecor,
      'ixObj0': ixObj0,
      'ixObj1': ixObj1,
      'shadow': shadow,
      'ixEvent': ixEvent,
    };
  }
}
