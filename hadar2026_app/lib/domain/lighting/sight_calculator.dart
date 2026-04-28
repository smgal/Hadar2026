import '../party/party.dart';

/// Pure functions describing the lighting/visibility rules of the original
/// game: how far the party can see at a given hour, whether ambient
/// moonlight applies, and the per-tile shadow bitmask near the player.
///
/// Lives in the domain because the rules (clock thresholds, magic torch
/// behavior, "DEN" maps being unlit, "TOWN/CASTLE" always lit, etc.) are
/// game-design facts — the renderer just consumes the numbers.
class HDSightCalculator {
  /// Returns sight radius (1..5) given the party's current time + magic
  /// torch + the current map's name. Maps containing "DEN" force a dark
  /// interior.
  static int sightRangeFor({required HDParty party, required String mapName}) {
    int time = party.hour * 100 + party.min;

    int sightRange = 5;
    if (time < 600) {
      sightRange = 1;
    } else if (time < 620) {
      sightRange = 2;
    } else if (time < 640) {
      sightRange = 3;
    } else if (time < 700) {
      sightRange = 4;
    } else if (time < 1800) {
      sightRange = 5;
    } else if (time < 1820) {
      sightRange = 4;
    } else if (time < 1840) {
      sightRange = 3;
    } else if (time < 1900) {
      sightRange = 2;
    } else {
      sightRange = 1;
    }

    final isDen = mapName.toUpperCase().contains('DEN');
    if (isDen) sightRange = 1;

    final inDark = isDen || !(party.hour >= 7 && party.hour < 17);
    if (inDark && party.magicTorch > 0) {
      if (party.magicTorch >= 1 && party.magicTorch <= 2) {
        sightRange = sightRange > 2 ? sightRange : 2;
      } else {
        sightRange = sightRange > 3 ? sightRange : 3;
      }
    }
    return sightRange;
  }

  /// Whether the map currently has ambient moonlight (so tiles outside the
  /// torch radius can still be drawn dimly rather than pitch black).
  static bool isInMoonlight({
    required HDParty party,
    required String mapName,
  }) {
    final upper = mapName.toUpperCase();
    final isDen = upper.contains('DEN');
    final isTown = upper.contains('TOWN') || upper.contains('CASTLE');

    bool inMoonlight = (party.day ~/ 12) >= 10 && (party.day ~/ 12) <= 20;
    inMoonlight &= !isDen;
    inMoonlight |= isTown;

    if (isDen) return false;

    final inDark = isDen || !(party.hour >= 7 && party.hour < 17);
    if (inDark && party.magicTorch > 4) inMoonlight = true;
    return inMoonlight;
  }

  /// 4-bit corner mask describing how much of tile (mapX, mapY) falls
  /// inside the player's visibility disk. Returns 15 (fully lit) when
  /// sightRange ≥ 5.
  static int lightBitFor({
    required int mapX,
    required int mapY,
    required int playerX,
    required int playerY,
    required int sightRange,
  }) {
    if (sightRange >= 5) return 15;

    const int mag = 2;
    int bit = 0;
    double sqrRadius = mag * sightRange + 0.3;
    sqrRadius *= sqrRadius;

    for (int sy = 0; sy < mag; sy++) {
      for (int sx = 0; sx < mag; sx++) {
        double fx = (mapX - playerX) * mag + sx - 0.5;
        double fy = (mapY - playerY) * mag + sy - 0.5;

        if ((fx * fx + fy * fy) <= sqrRadius) {
          int shift = sx + 2 * sy;
          bit |= (1 << shift);
        }
      }
    }
    return bit;
  }
}
