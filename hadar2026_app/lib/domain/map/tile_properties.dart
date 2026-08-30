import 'map_model.dart';

/// What the party can do with a tile.
///
/// Used to be ten `static const int` members on [HDTileProperties], which
/// meant every `switch` over an action was non-exhaustive and the rules
/// below ("which actions are interactive?") had to be restated at each
/// call site — `application/` and `presentation/` had drifted into
/// keeping two copies. As an enum the compiler checks exhaustiveness and
/// the rules live in one place.
/// The values 0–4 cross into cm2 scripts as `ScriptMode()` and are
/// compared against `FLAG_MAP`/`FLAG_TALK`/`FLAG_SIGN`/`FLAG_EVENT`/
/// `FLAG_ENTER` in `assets/const.cm2`. They are declared explicitly as
/// [scriptMode] rather than left to `Enum.index`, so reordering the enum
/// can no longer silently mis-branch every cm2 map script.
enum HDTileAction {
  /// Solid: wall, block, impassable object. Also the cm2 `FLAG_MAP`
  /// mode, which is what a map runs on load.
  none(0),

  /// NPC — talk by facing the tile and confirming. cm2 `FLAG_TALK`.
  talk(1),

  /// Signboard — read by facing the tile and confirming. cm2 `FLAG_SIGN`.
  sign(2),

  /// Fires when the party steps onto the tile. cm2 `FLAG_EVENT`.
  event(3),

  /// Doorway / entrance: fires both on step-on and on confirm.
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

  /// Actions triggered by facing the tile and pressing confirm.
  ///
  /// These are also exactly the actions that block movement while still
  /// being reachable, which is why [HDTileProperties.isUnitPassable]
  /// derives from this instead of restating the list.
  bool get isInteractive =>
      this == talk || this == sign || this == enter;

  /// Actions triggered by stepping onto the tile.
  bool get isStepOn => this == event || this == enter;

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
}

class HDTileProperties {
  static const int TYPE_TOWN = 0;
  static const int TYPE_KEEP = 1;
  static const int TYPE_GROUND = 2;
  static const int TYPE_DEN = 3;

  static bool isPassable(int tileId, int mapType) {
    if (mapType == TYPE_TOWN) {
      if (tileId == 0) return true;
      if (tileId == 25 || tileId == 26) return true; // Swamp, Lava
      if (tileId >= 27 && tileId <= 47) return true;
      return false;
    } else if (mapType == TYPE_KEEP) {
      if (tileId == 0) return true;
      if (tileId >= 40 && tileId <= 47) return true;
      return false;
    } else if (mapType == TYPE_GROUND) {
      if (tileId == 0) return true;
      if (tileId >= 24 && tileId <= 47) return true;
      return false;
    } else if (mapType == TYPE_DEN) {
      if (tileId == 0) return true;
      if (tileId >= 41 && tileId <= 47) return true;
      return false;
    }
    return false;
  }

  static bool isUnitPassable(MapUnit? unit, {int walkOnWater = 0}) {
    if (unit == null) return false;
    final action = getUnitAction(unit);

    // Solid: walls/blocks, plus everything you interact with by facing it
    // (NPC, signboard, entrance) — those occupy the tile.
    if (action == HDTileAction.none || action.isInteractive) return false;

    // Water: impassable unless it is shallow (ixTile == 56) and the party
    // currently has the walk-on-water buff.
    if (action == HDTileAction.water) {
      return unit.ixTile == 56 && walkOnWater > 0;
    }

    return true;
  }

  // Tile-id → action table from the original C++ build. Currently
  // unreferenced (dispatch goes through [getUnitAction]); kept as the
  // documented mapping for map-data tooling.
  static HDTileAction getAction(int tileId, int mapType) {
    if (mapType == TYPE_TOWN) {
      if (tileId == 0) return HDTileAction.event;
      if (tileId <= 21) return HDTileAction.none; // BLOCK
      if (tileId <= 22) return HDTileAction.enter;
      if (tileId <= 23) return HDTileAction.sign;
      if (tileId <= 24) return HDTileAction.water;
      if (tileId <= 25) return HDTileAction.swamp;
      if (tileId <= 26) return HDTileAction.lava;
      if (tileId <= 47) return HDTileAction.move; // MOVE
      return HDTileAction.talk;
    } else if (mapType == TYPE_KEEP) {
      if (tileId == 0) return HDTileAction.event;
      if (tileId <= 39) return HDTileAction.none; // BLOCK
      if (tileId <= 47) return HDTileAction.move; // MOVE
      if (tileId <= 48) return HDTileAction.water;
      if (tileId <= 49) return HDTileAction.swamp;
      if (tileId <= 50) return HDTileAction.lava;
      if (tileId <= 51) return HDTileAction.none; // BLOCK
      if (tileId <= 52) return HDTileAction.event;
      if (tileId <= 53) return HDTileAction.sign;
      if (tileId <= 54) return HDTileAction.enter;
      return HDTileAction.talk;
    } else if (mapType == TYPE_GROUND) {
      if (tileId == 0) return HDTileAction.event;
      if (tileId <= 21) return HDTileAction.none; // BLOCK
      if (tileId <= 22) return HDTileAction.sign;
      if (tileId <= 23) return HDTileAction.swamp;
      if (tileId <= 47) return HDTileAction.move; // MOVE
      if (tileId <= 48) return HDTileAction.water;
      if (tileId <= 49) return HDTileAction.swamp;
      if (tileId <= 50) return HDTileAction.lava;
      return HDTileAction.enter;
    } else if (mapType == TYPE_DEN) {
      if (tileId == 0) return HDTileAction.event;
      if (tileId <= 20) return HDTileAction.none; // BLOCK
      if (tileId <= 21) return HDTileAction.talk;
      if (tileId <= 40) return HDTileAction.none; // BLOCK
      if (tileId <= 47) return HDTileAction.move; // MOVE
      if (tileId <= 48) return HDTileAction.water;
      if (tileId <= 49) return HDTileAction.swamp;
      if (tileId <= 50) return HDTileAction.lava;
      if (tileId <= 51) return HDTileAction.none; // BLOCK
      if (tileId <= 52) return HDTileAction.event;
      if (tileId <= 53) return HDTileAction.sign;
      if (tileId <= 54) return HDTileAction.enter;
      return HDTileAction.talk;
    }
    return HDTileAction.none;
  }

  static HDTileAction _getTileAction(int ixTile) {
    if (ixTile < 56) return HDTileAction.move;
    if (ixTile < 60) return HDTileAction.water;
    if (ixTile < 62) return HDTileAction.swamp;
    if (ixTile < 64) return HDTileAction.lava;
    if (ixTile < 70) return HDTileAction.enter;
    if (ixTile < 72) return HDTileAction.cliff;
    if (ixTile < 128) return HDTileAction.none; // BLOCK
    return HDTileAction.move;
  }

  static HDTileAction getUnitAction(MapUnit? unit) {
    if (unit == null) return HDTileAction.none;

    // Check Event First
    int eventType = unit.ixEvent & 0x00FF0000;
    if (eventType != 0) {
      if (eventType == 0x00010000) return HDTileAction.event;
      if (eventType == 0x00020000) return HDTileAction.talk;
      if (eventType == 0x00030000) return HDTileAction.sign;
      if (eventType == 0x00040000) return HDTileAction.enter;
    }

    // Check Object (Lore_B)
    if (unit.ixObj1 > 0) {
      final objAction = _getObjectAction(unit.ixObj1);
      if (objAction != HDTileAction.move && objAction != HDTileAction.none) {
        return objAction;
      }
      if (objAction == HDTileAction.none) return HDTileAction.none;
    }

    // Check Tile (Lore_A5)
    return _getTileAction(unit.ixTile);
  }

  static HDTileAction _getObjectAction(int ixObj) {
    if (ixObj <= 0) return HDTileAction.move;

    // The RPG Maker MZ index (ixObj) perfectly aligns with the Unity GameRes.cs index
    // Left half (0-127), Right half (128-255).
    int iUnity = ixObj;

    // Apply the rules from GameRes.cs (object loop offset)
    if (iUnity <= 0) return HDTileAction.move;
    if (iUnity < 64) return HDTileAction.none; // BLOCK
    if (iUnity < 88) return HDTileAction.move;
    if (iUnity < 96) return HDTileAction.move; // Animation object
    if (iUnity < 112) return HDTileAction.none; // BLOCK
    if (iUnity < 124) return HDTileAction.sign;
    if (iUnity < 128) return HDTileAction.enter;
    if (iUnity < 144) return HDTileAction.talk; // TALK objects (NPCs/Knights)

    return HDTileAction.move;
  }
}
