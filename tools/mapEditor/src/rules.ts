// 순수 게임 규칙 — 브라우저(에디터 UI)와 node(dev 서버 AI API)가 공유한다.
// DOM 의존 없음. 내용은 hadar2026_app 의 HDTileProperties / HDMapLoader 포팅.

export const SRC_TILE = 48; // 시트의 타일 원본 크기 (MV 표준)

export interface SheetRect {
  sx: number;
  sy: number;
  sw: number;
  sh: number;
}

/** 지면 데이터 값 → A5 인덱스 (HDMapLoader: d < 0x600 ? d : d - 0x600). */
export function a5Index(raw: number): number {
  return raw < 0x600 ? raw : raw - 0x600;
}

export const A5_BASE = 1536; // MV 에서 A5 타일 ID 시작값
export const A5_COLS = 8;
export const A5_COUNT = 128;
/** B 시트의 전체 열 수. 왼쪽 절반(0~127)과 오른쪽 절반(128~255)이 각각 B_COLS/2 열. */
export const B_COLS = 16;
export const B_HALF_COLS = B_COLS / 2;
export const B_COUNT = 256;
/** 야간 그림자 오버레이로 쓰이는 B 타일 구간 (240 + 사분면 비트). */
export const B_SHADOW_BASE = 240;

/** 지면 raw 값의 A5 시트 좌표. 게임과 동일하게 0 도 A5 #0 으로 그린다. */
export function a5Rect(raw: number): SheetRect | null {
  const idx = a5Index(raw);
  if (!Number.isInteger(idx) || idx < 0 || idx >= A5_COUNT) return null;
  const row = Math.floor(idx / A5_COLS);
  const col = idx % A5_COLS;
  return { sx: col * SRC_TILE, sy: row * SRC_TILE, sw: SRC_TILE, sh: SRC_TILE };
}

/**
 * B 타일 ID(1..255)의 시트 좌표. HDWorldMap._getBSprite 포팅:
 * 왼쪽 절반(열 0~7)이 0..127, 오른쪽 절반(열 8~15)이 128..255.
 */
export function bRect(id: number): SheetRect | null {
  if (!Number.isInteger(id) || id <= 0 || id >= B_COUNT) return null;
  const half = B_COUNT / 2; // 128
  let row: number;
  let col: number;
  if (id < half) {
    row = Math.floor(id / B_HALF_COLS);
    col = id % B_HALF_COLS;
  } else {
    const localId = id - half;
    row = Math.floor(localId / B_HALF_COLS);
    col = B_HALF_COLS + (localId % B_HALF_COLS);
  }
  return { sx: col * SRC_TILE, sy: row * SRC_TILE, sw: SRC_TILE, sh: SRC_TILE };
}

// ── 통행/액션 규칙 (HDTileProperties 포팅) ─────────────────────────────

export const ACTION_NONE = 0;
export const ACTION_TALK = 1;
export const ACTION_SIGN = 2;
export const ACTION_EVENT = 3;
export const ACTION_ENTER = 4;
export const ACTION_WATER = 5;
export const ACTION_SWAMP = 6;
export const ACTION_LAVA = 7;
export const ACTION_CLIFF = 8;
export const ACTION_MOVE = 9;

export const ACTION_NAMES: Record<number, string> = {
  [ACTION_NONE]: 'BLOCK',
  [ACTION_TALK]: 'TALK',
  [ACTION_SIGN]: 'SIGN',
  [ACTION_EVENT]: 'EVENT',
  [ACTION_ENTER]: 'ENTER',
  [ACTION_WATER]: 'WATER',
  [ACTION_SWAMP]: 'SWAMP',
  [ACTION_LAVA]: 'LAVA',
  [ACTION_CLIFF]: 'CLIFF',
  [ACTION_MOVE]: 'MOVE',
};

/** 통행 오버레이 색 (MOVE 는 표시하지 않음). */
export const ACTION_COLORS: Record<number, string> = {
  [ACTION_NONE]: 'rgba(230, 60, 60, 0.42)',
  [ACTION_TALK]: 'rgba(240, 80, 220, 0.5)',
  [ACTION_SIGN]: 'rgba(60, 220, 230, 0.5)',
  [ACTION_EVENT]: 'rgba(90, 230, 90, 0.5)',
  [ACTION_ENTER]: 'rgba(240, 220, 60, 0.5)',
  [ACTION_WATER]: 'rgba(70, 110, 240, 0.45)',
  [ACTION_SWAMP]: 'rgba(160, 90, 230, 0.45)',
  [ACTION_LAVA]: 'rgba(240, 140, 40, 0.5)',
  [ACTION_CLIFF]: 'rgba(150, 100, 60, 0.5)',
};

/** HDTileProperties._getTileAction — A5 인덱스 기준. */
export function tileAction(ixTile: number): number {
  if (ixTile < 56) return ACTION_MOVE;
  if (ixTile < 60) return ACTION_WATER;
  if (ixTile < 62) return ACTION_SWAMP;
  if (ixTile < 64) return ACTION_LAVA;
  if (ixTile < 70) return ACTION_ENTER;
  if (ixTile < 72) return ACTION_CLIFF;
  if (ixTile < 128) return ACTION_NONE; // BLOCK
  return ACTION_MOVE;
}

/** HDTileProperties._getObjectAction — B 타일 ID 기준. */
export function objectAction(ixObj: number): number {
  if (ixObj <= 0) return ACTION_MOVE;
  if (ixObj < 64) return ACTION_NONE; // BLOCK
  if (ixObj < 88) return ACTION_MOVE;
  if (ixObj < 96) return ACTION_MOVE; // 애니메이션 오브젝트
  if (ixObj < 112) return ACTION_NONE; // BLOCK
  if (ixObj < 124) return ACTION_SIGN;
  if (ixObj < 128) return ACTION_ENTER;
  if (ixObj < 144) return ACTION_TALK; // NPC 류
  return ACTION_MOVE;
}

/**
 * HDTileProperties.getUnitAction — 이벤트 > 오브젝트(obj1) > 지면 순으로 판정.
 * eventType 은 해당 타일 위 이벤트의 이름 접두사 타입("TALK" 등, 없으면 null).
 */
export function unitAction(rawGround: number, ixObj1: number, eventType: string | null): number {
  if (eventType === 'EVENT') return ACTION_EVENT;
  if (eventType === 'TALK') return ACTION_TALK;
  if (eventType === 'SIGN') return ACTION_SIGN;
  if (eventType === 'ENTER') return ACTION_ENTER;

  if (ixObj1 > 0) {
    const oa = objectAction(ixObj1);
    if (oa !== ACTION_MOVE && oa !== ACTION_NONE) return oa;
    if (oa === ACTION_NONE) return ACTION_NONE;
  }
  return tileAction(a5Index(rawGround));
}
