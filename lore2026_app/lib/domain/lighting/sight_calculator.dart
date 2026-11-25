import 'package:lore_world/lore_world.dart';

import '../map/tile_properties.dart';

/// 어둠 속에서 얼마나 보이는가를 지도 그리기에 맞게 풀어 준다.
///
/// 규칙(시각 · 달 · 동굴 · 횃불)은 `LoreWorld.sight` 가 정한다(제11장 11.5).
/// 여기서는 그 답을 지도가 쓰는 두 값 — 반경과 「바깥이 어둡게나마 보이는가」
/// — 으로 옮기고, 칸마다 네 귀퉁이 중 어디가 밝은지를 계산한다.
class HDSightCalculator {
  /// 반경이 이 값 이상이면 전체가 밝다 (지도가 어둠을 그리지 않는다).
  static const int fullSight = 5;

  /// `MapInfos.json` 의 맵 유형 → 규칙이 아는 유형.
  static MapKind mapKindOf(int mapType) => switch (mapType) {
    HDTileProperties.TYPE_GROUND => MapKind.field,
    HDTileProperties.TYPE_DEN => MapKind.cave,
    HDTileProperties.TYPE_KEEP => MapKind.fortress,
    _ => MapKind.town,
  };

  /// 시야 반경 (칸). 낮이면 [fullSight].
  static int sightRangeFor({
    required LoreWorld world,
    required int mapType,
    bool darkZone = false,
  }) {
    final sight = world.sight(mapKindOf(mapType), darknessZone: darkZone);
    return sight.radius ?? fullSight;
  }

  /// 시야 밖이 어둡게나마 보이는가 (달빛, 또는 센 횃불).
  static bool isInMoonlight({
    required LoreWorld world,
    required int mapType,
    bool darkZone = false,
  }) => world.sight(mapKindOf(mapType), darknessZone: darkZone).dimBeyond;

  /// 칸 (mapX, mapY) 의 네 귀퉁이 중 밝은 것을 비트로 (15 = 전부 밝음).
  ///
  /// 칸을 2×2 로 쪼개 귀퉁이마다 일행과의 거리를 잰다 — 그래서 어둠의
  /// 가장자리가 계단이 아니라 둥글게 나온다.
  static int lightBitFor({
    required int mapX,
    required int mapY,
    required int playerX,
    required int playerY,
    required int sightRange,
  }) {
    if (sightRange >= fullSight) return 15;

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
