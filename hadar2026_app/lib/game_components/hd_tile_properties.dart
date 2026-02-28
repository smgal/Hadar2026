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

  static const int ACTION_NONE = 0;
  static const int ACTION_TALK = 1;
  static const int ACTION_SIGN = 2;
  static const int ACTION_EVENT = 3;
  static const int ACTION_ENTER = 4;
  static const int ACTION_WATER = 5;
  static const int ACTION_SWAMP = 6;
  static const int ACTION_LAVA = 7;

  static int getAction(int tileId, int mapType) {
    if (mapType == TYPE_TOWN) {
      if (tileId == 0) return ACTION_EVENT;
      if (tileId <= 21) return ACTION_NONE; // BLOCK
      if (tileId <= 22) return ACTION_ENTER;
      if (tileId <= 23) return ACTION_SIGN;
      if (tileId <= 24) return ACTION_WATER;
      if (tileId <= 25) return ACTION_SWAMP;
      if (tileId <= 26) return ACTION_LAVA;
      if (tileId <= 47) return ACTION_NONE; // MOVE
      return ACTION_TALK;
    } else if (mapType == TYPE_KEEP) {
      if (tileId == 0) return ACTION_EVENT;
      if (tileId <= 39) return ACTION_NONE; // BLOCK
      if (tileId <= 47) return ACTION_NONE; // MOVE
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
      if (tileId <= 47) return ACTION_NONE; // MOVE
      if (tileId <= 48) return ACTION_WATER;
      if (tileId <= 49) return ACTION_SWAMP;
      if (tileId <= 50) return ACTION_LAVA;
      return ACTION_ENTER;
    } else if (mapType == TYPE_DEN) {
      if (tileId == 0) return ACTION_EVENT;
      if (tileId <= 20) return ACTION_NONE; // BLOCK
      if (tileId <= 21) return ACTION_TALK;
      if (tileId <= 40) return ACTION_NONE; // BLOCK
      if (tileId <= 47) return ACTION_NONE; // MOVE
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
}
