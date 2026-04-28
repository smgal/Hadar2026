import 'map_model.dart';

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
    int action = getUnitAction(unit);

    // Solid objects: ACTION_NONE (Wall/Block), ACTION_TALK (NPC), ACTION_SIGN (Signboard), ACTION_ENTER
    if (action == ACTION_NONE ||
        action == ACTION_TALK ||
        action == ACTION_SIGN ||
        action == ACTION_ENTER) {
      return false;
    }

    // Water: Impassable unless it is shallow water (ixTile == 56) and we have the buff
    if (action == ACTION_WATER) {
      if (unit.ixTile == 56 && walkOnWater > 0) {
        return true;
      }
      return false;
    }

    return true;
  }

  static const int ACTION_NONE = 0;
  static const int ACTION_TALK = 1;
  static const int ACTION_SIGN = 2;
  static const int ACTION_EVENT = 3;
  static const int ACTION_ENTER = 4;
  static const int ACTION_WATER = 5;
  static const int ACTION_SWAMP = 6;
  static const int ACTION_LAVA = 7;
  static const int ACTION_CLIFF = 8;
  static const int ACTION_MOVE = 9;

  // Legacy getAction, kept for backward compatibility if needed elsewhere
  static int getAction(int tileId, int mapType) {
    if (mapType == TYPE_TOWN) {
      if (tileId == 0) return ACTION_EVENT;
      if (tileId <= 21) return ACTION_NONE; // BLOCK
      if (tileId <= 22) return ACTION_ENTER;
      if (tileId <= 23) return ACTION_SIGN;
      if (tileId <= 24) return ACTION_WATER;
      if (tileId <= 25) return ACTION_SWAMP;
      if (tileId <= 26) return ACTION_LAVA;
      if (tileId <= 47) return ACTION_MOVE; // MOVE
      return ACTION_TALK;
    } else if (mapType == TYPE_KEEP) {
      if (tileId == 0) return ACTION_EVENT;
      if (tileId <= 39) return ACTION_NONE; // BLOCK
      if (tileId <= 47) return ACTION_MOVE; // MOVE
      if (tileId <= 48) return ACTION_WATER;
      if (tileId <= 49) return ACTION_SWAMP;
      if (tileId <= 50) return ACTION_LAVA;
      if (tileId <= 51) return ACTION_NONE; // BLOCK
      if (tileId <= 52) return ACTION_EVENT;
      if (tileId <= 53) return ACTION_SIGN;
      if (tileId <= 54) return ACTION_ENTER;
      return ACTION_TALK;
    } else if (mapType == TYPE_GROUND) {
      if (tileId == 0) return ACTION_EVENT;
      if (tileId <= 21) return ACTION_NONE; // BLOCK
      if (tileId <= 22) return ACTION_SIGN;
      if (tileId <= 23) return ACTION_SWAMP;
      if (tileId <= 47) return ACTION_MOVE; // MOVE
      if (tileId <= 48) return ACTION_WATER;
      if (tileId <= 49) return ACTION_SWAMP;
      if (tileId <= 50) return ACTION_LAVA;
      return ACTION_ENTER;
    } else if (mapType == TYPE_DEN) {
      if (tileId == 0) return ACTION_EVENT;
      if (tileId <= 20) return ACTION_NONE; // BLOCK
      if (tileId <= 21) return ACTION_TALK;
      if (tileId <= 40) return ACTION_NONE; // BLOCK
      if (tileId <= 47) return ACTION_MOVE; // MOVE
      if (tileId <= 48) return ACTION_WATER;
      if (tileId <= 49) return ACTION_SWAMP;
      if (tileId <= 50) return ACTION_LAVA;
      if (tileId <= 51) return ACTION_NONE; // BLOCK
      if (tileId <= 52) return ACTION_EVENT;
      if (tileId <= 53) return ACTION_SIGN;
      if (tileId <= 54) return ACTION_ENTER;
      return ACTION_TALK;
    }
    return ACTION_NONE;
  }

  static int _getTileAction(int ixTile) {
    if (ixTile < 56) return ACTION_MOVE;
    if (ixTile < 60) return ACTION_WATER;
    if (ixTile < 62) return ACTION_SWAMP;
    if (ixTile < 64) return ACTION_LAVA;
    if (ixTile < 70) return ACTION_ENTER;
    if (ixTile < 72) return ACTION_CLIFF;
    if (ixTile < 128) return ACTION_NONE; // BLOCK
    return ACTION_MOVE;
  }

  static int getUnitAction(MapUnit? unit) {
    if (unit == null) return ACTION_NONE;

    // Check Event First
    int eventType = unit.ixEvent & 0x00FF0000;
    if (eventType != 0) {
      if (eventType == 0x00010000) return ACTION_EVENT;
      if (eventType == 0x00020000) return ACTION_TALK;
      if (eventType == 0x00030000) return ACTION_SIGN;
      if (eventType == 0x00040000) return ACTION_ENTER;
    }

    // Check Object (Lore_B)
    if (unit.ixObj1 > 0) {
      int objAction = _getObjectAction(unit.ixObj1);
      if (objAction != ACTION_MOVE && objAction != ACTION_NONE) {
        return objAction;
      }
      if (objAction == ACTION_NONE) return ACTION_NONE;
    }

    // Check Tile (Lore_A5)
    return _getTileAction(unit.ixTile);
  }

  static int _getObjectAction(int ixObj) {
    if (ixObj <= 0) return ACTION_MOVE;

    // The RPG Maker MZ index (ixObj) perfectly aligns with the Unity GameRes.cs index
    // Left half (0-127), Right half (128-255).
    int iUnity = ixObj;

    // Apply the rules from GameRes.cs (object loop offset)
    if (iUnity <= 0) return ACTION_MOVE;
    if (iUnity < 64) return ACTION_NONE; // BLOCK
    if (iUnity < 88) return ACTION_MOVE;
    if (iUnity < 96) return ACTION_MOVE; // Animation object
    if (iUnity < 112) return ACTION_NONE; // BLOCK
    if (iUnity < 124) return ACTION_SIGN;
    if (iUnity < 128) return ACTION_ENTER;
    if (iUnity < 144) return ACTION_TALK; // TALK objects (NPCs/Knights)

    return ACTION_MOVE;
  }
}
