// hadar2026_app 의 HDSightCalculator / HDWorldMap._renderShadow 공식 포팅.
// 야간 뷰가 게임과 동일하게 보이도록 값을 그대로 유지한다.

/**
 * 타일 (mapX, mapY) 가 플레이어 시야 원 안에 얼마나 들어오는지 4비트 사분면
 * 마스크로 반환. sightRange >= 5 면 15(완전 점등).
 * 비트: 1=좌상, 2=우상, 4=좌하, 8=우하.
 */
export function lightBitFor(
  mapX: number,
  mapY: number,
  playerX: number,
  playerY: number,
  sightRange: number,
): number {
  if (sightRange >= 5) return 15;

  const mag = 2;
  let bit = 0;
  let sqrRadius = mag * sightRange + 0.3;
  sqrRadius *= sqrRadius;

  for (let sy = 0; sy < mag; sy++) {
    for (let sx = 0; sx < mag; sx++) {
      const fx = (mapX - playerX) * mag + sx - 0.5;
      const fy = (mapY - playerY) * mag + sy - 0.5;
      if (fx * fx + fy * fy <= sqrRadius) {
        bit |= 1 << (sx + 2 * sy);
      }
    }
  }
  return bit;
}

/**
 * 그림자 값 + 시야 비트 → 실제로 그릴 그림자 사분면.
 * HDWorldMap._renderShadow: ix = ((shadow ^ 15) | lightBit) ^ 15
 * ix > 0 이면 B 타일 (240 + ix) 를 그린다. 달빛이 없고 ix == 15 면 두 번
 * 겹쳐 그려 더 어둡게 만든다 (게임 동작 그대로).
 */
export function shadowIx(shadowVal: number, lightBit: number): number {
  return ((shadowVal ^ 15) | lightBit) ^ 15;
}
