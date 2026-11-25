import 'map_model.dart';

/// What the party can do with a tile.
///
/// The values 0–4 cross into cm2 scripts as `ScriptMode()` and are
/// compared against `FLAG_MAP`/`FLAG_TALK`/`FLAG_SIGN`/`FLAG_EVENT`/
/// `FLAG_ENTER` in `assets/common/const.cm2`. They are declared explicitly
/// as [scriptMode] rather than left to `Enum.index`, so reordering the enum
/// can no longer silently mis-branch every cm2 map script.
enum HDTileAction {
  /// Solid: wall, block, impassable object. Also the cm2 `FLAG_MAP`
  /// mode, which is what a map runs on load.
  none(0),

  /// NPC — talk by walking into the tile. cm2 `FLAG_TALK`.
  talk(1),

  /// Signboard — read by walking into the tile. cm2 `FLAG_SIGN`.
  sign(2),

  /// Fires when the party steps onto the tile. cm2 `FLAG_EVENT`.
  event(3),

  /// Doorway / entrance: fires when the party walks into it.
  /// cm2 `FLAG_ENTER`.
  enter(4),

  water(5),
  swamp(6),
  lava(7),
  cliff(8),

  /// Ordinary walkable ground; no event.
  move(9);

  const HDTileAction(this.scriptMode);

  /// Value handed to `HDScriptEngine.setScriptMode` and read back by cm2
  /// scripts as `ScriptMode()`. See the note above before changing.
  final int scriptMode;

  /// Actions triggered by walking into the tile (it stays where it is and
  /// the party does not move).
  ///
  /// These are also exactly the actions that block movement while still
  /// being reachable, which is why [HDTileProperties.isUnitPassable]
  /// derives from this instead of restating the list.
  bool get isInteractive => this == talk || this == sign || this == enter;

  /// Actions triggered by stepping onto the tile.
  ///
  /// **`enter` is not here in lore2026.** hadar2026_app fires an entrance
  /// both ways; the Lore originals only ever ask "들어가기를 원합니까 ?" when
  /// the party walks *into* the entrance and stays put (부록 D.4).
  bool get isStepOn => this == event;

  /// Three-letter tag for the tile debug overlay / dispatch trace.
  /// Empty for actions the trace does not label.
  String get debugTag => switch (this) {
    talk => 'Tak',
    sign => 'Sig',
    event => 'Evt',
    enter => 'Ent',
    water => 'Wtr',
    swamp => 'Swm',
    lava => 'Lav',
    none || cliff || move => '',
  };

  /// The region code the map converter writes into layer z5 when the
  /// tile's own index band does not say what the cell does
  /// (`tools/lore_import/import_maps.py`, `REGION`).
  static HDTileAction? fromRegion(int region) => switch (region) {
    1 => event,
    2 => talk,
    3 => sign,
    4 => enter,
    5 => none,
    6 => move,
    7 => water,
    8 => swamp,
    9 => lava,
    _ => null,
  };

  /// Inverse of [fromRegion]. `cliff` has no code: nothing in the Lore
  /// maps needs to force it.
  int get region => switch (this) {
    event => 1,
    talk => 2,
    sign => 3,
    enter => 4,
    none => 5,
    move => 6,
    water => 7,
    swamp => 8,
    lava => 9,
    cliff => 0,
  };
}

class HDTileProperties {
  static const int TYPE_TOWN = 0;
  static const int TYPE_KEEP = 1;
  static const int TYPE_GROUND = 2;
  static const int TYPE_DEN = 3;

  /// The map-type name `MapInfos.json` uses → the engine's number
  /// (`MAPTYPE_*`, the same four hadar2026_app has).
  static int typeFromName(String name) => switch (name) {
    'town' => TYPE_TOWN,
    'keep' => TYPE_KEEP,
    'ground' => TYPE_GROUND,
    'den' => TYPE_DEN,
    _ => TYPE_TOWN,
  };

  /// One page of `Lore_A5`. The first page is hadar2026_app's sheet; the
  /// pages after it hold the Lore tiles the converter added, **laid out in
  /// the same bands** — which is what lets the action stay a function of
  /// `index % pageSize` instead of needing a table.
  static const int a5PageSize = 128;

  /// Bit position of the action override inside [MapUnit.ixEvent].
  static const int _eventShift = 16;
  static const int _eventMask = 0x00FF0000;

  static bool isUnitPassable(MapUnit? unit, {int walkOnWater = 0}) {
    if (unit == null) return false;
    final action = getUnitAction(unit);

    // Solid: walls/blocks, plus everything you interact with by walking
    // into it (NPC, signboard, entrance) — those occupy the tile.
    if (action == HDTileAction.none || action.isInteractive) return false;

    // Water needs the walk-on-water effect. **Deep sea is not water
    // here**: the converter marks it as a block, because the original
    // rules call it impassable terrain (필드형 1~19) and only the tile
    // numbered "물" can be walked with the magic.
    if (action == HDTileAction.water) return walkOnWater > 0;

    return true;
  }

  static HDTileAction _getTileAction(int ixTile) {
    final local = ixTile % a5PageSize;
    if (local < 56) return HDTileAction.move;
    if (local < 60) return HDTileAction.water;
    if (local < 62) return HDTileAction.swamp;
    if (local < 64) return HDTileAction.lava;
    if (local < 70) return HDTileAction.enter;
    if (local < 72) return HDTileAction.cliff;
    return HDTileAction.none; // BLOCK
  }

  /// What the cell does if nothing overrides it: the object layers, then
  /// the ground tile. This is the part hadar2026_app has too.
  static HDTileAction bandAction(MapUnit unit) {
    // Check Objects (Lore_B), top first: z3 (L4 top object), then z2
    // (L3 object). A MOVE-band object (or an empty layer) falls through to
    // the layer below. z1 (L2 floor decor, ixDecor) is never consulted —
    // people walk over rugs. BP-36 R-36-57.
    final topAction = _getObjectAction(unit.ixObj1);
    if (topAction != HDTileAction.move) return topAction;
    final lowerAction = _getObjectAction(unit.ixObj0);
    if (lowerAction != HDTileAction.move) return lowerAction;

    // Check Tile (Lore_A5)
    return _getTileAction(unit.ixTile);
  }

  static HDTileAction getUnitAction(MapUnit? unit) {
    if (unit == null) return HDTileAction.none;

    // An override wins. The map converter writes one wherever the bands
    // cannot say what the original tile meant — a hidden event cell drawn
    // as plain floor, a person, a number whose meaning differs between
    // the three games — and `events[]` entries land in the same bits.
    final override = HDTileAction.fromRegion(
      (unit.ixEvent & _eventMask) >> _eventShift,
    );
    if (override != null) return override;

    return bandAction(unit);
  }

  /// Stores [action] as the cell's override, or clears it when the bands
  /// already say the same thing (so a cell edited back to plain floor
  /// carries no stale override).
  static void setUnitAction(MapUnit unit, HDTileAction action) {
    final low = unit.ixEvent & ~_eventMask;
    unit.ixEvent = bandAction(unit) == action
        ? low
        : low | (action.region << _eventShift);
  }

  static HDTileAction _getObjectAction(int ixObj) {
    if (ixObj <= 0) return HDTileAction.move;
    if (ixObj < 64) return HDTileAction.none; // BLOCK
    if (ixObj < 88) return HDTileAction.move;
    if (ixObj < 96) return HDTileAction.move; // Animation object
    if (ixObj < 112) return HDTileAction.none; // BLOCK
    if (ixObj < 124) return HDTileAction.sign;
    if (ixObj < 128) return HDTileAction.enter;
    if (ixObj < 144) return HDTileAction.talk; // TALK objects (NPCs/Knights)

    return HDTileAction.move;
  }
}
