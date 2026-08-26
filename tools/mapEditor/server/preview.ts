// 맵 → PNG 렌더링 (node 측, pngjs). AI 가 편집 결과를 눈으로 확인하는 용도.
// 합성 순서는 게임 렌더러(HDWorldMap)와 동일: 지면 → obj0 → obj1 → 야간 그림자.
import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';
import { lightBitFor, shadowIx } from '../src/lighting';
import { eventTypeOf, getTile, type MvMap } from '../src/mvmap';
import { B_SHADOW_BASE, SRC_TILE, a5Rect, bRect, type SheetRect } from '../src/rules';
import { StoreError, type Store } from './store';

export interface PreviewOpts {
  x: number;
  y: number;
  w: number;
  h: number;
  tilePx: number; // 출력 타일 한 변 px
  night: boolean;
  moonlight: boolean;
  playerX: number | null; // null = 광원 미리보기 없음
  playerY: number | null;
  sight: number;
  events: boolean; // 이벤트 위치 테두리 표시
}

const EVENT_RGB: Record<string, [number, number, number]> = {
  TALK: [240, 80, 220],
  SIGN: [60, 220, 230],
  EVENT: [90, 230, 90],
  ENTER: [240, 220, 60],
  NPC: [240, 144, 64],
  UNKNOWN: [170, 170, 170],
};

const sheetCache = new Map<string, PNG>();

function loadSheet(store: Store, name: string): PNG {
  const p = path.join(store.imagesDir, name);
  const cached = sheetCache.get(p);
  if (cached) return cached;
  if (!fs.existsSync(p)) throw new StoreError(500, `타일 시트 없음: ${p}`);
  const png = PNG.sync.read(fs.readFileSync(p));
  sheetCache.set(p, png);
  return png;
}

/** src 시트의 48×48 영역을 dst 의 (dx,dy) 에 tilePx 크기로 최근접 샘플링 + 알파 블렌드. */
function blitTile(
  dst: PNG,
  dx: number,
  dy: number,
  sheet: PNG,
  sr: SheetRect,
  tilePx: number,
): void {
  for (let py = 0; py < tilePx; py++) {
    const sy = sr.sy + Math.floor((py * SRC_TILE) / tilePx);
    for (let px = 0; px < tilePx; px++) {
      const sx = sr.sx + Math.floor((px * SRC_TILE) / tilePx);
      const si = (sy * sheet.width + sx) * 4;
      const a = sheet.data[si + 3] / 255;
      if (a <= 0) continue;
      const di = ((dy + py) * dst.width + (dx + px)) * 4;
      dst.data[di] = Math.round(sheet.data[si] * a + dst.data[di] * (1 - a));
      dst.data[di + 1] = Math.round(sheet.data[si + 1] * a + dst.data[di + 1] * (1 - a));
      dst.data[di + 2] = Math.round(sheet.data[si + 2] * a + dst.data[di + 2] * (1 - a));
      dst.data[di + 3] = 255;
    }
  }
}

function drawBorder(
  dst: PNG,
  dx: number,
  dy: number,
  tilePx: number,
  rgb: [number, number, number],
): void {
  const thick = Math.max(1, Math.floor(tilePx / 8));
  for (let py = 0; py < tilePx; py++) {
    for (let px = 0; px < tilePx; px++) {
      const onEdge = px < thick || py < thick || px >= tilePx - thick || py >= tilePx - thick;
      if (!onEdge) continue;
      const di = ((dy + py) * dst.width + (dx + px)) * 4;
      dst.data[di] = rgb[0];
      dst.data[di + 1] = rgb[1];
      dst.data[di + 2] = rgb[2];
      dst.data[di + 3] = 255;
    }
  }
}

export function renderPreview(store: Store, map: MvMap, opts: PreviewOpts): Buffer {
  const a5Sheet = loadSheet(store, 'Lore_A5.png');
  const bSheet = loadSheet(store, 'Lore_B.png');

  const outW = opts.w * opts.tilePx;
  const outH = opts.h * opts.tilePx;
  if (outW * outH > 16_000_000) {
    throw new StoreError(
      400,
      `출력 이미지가 너무 큼 (${outW}×${outH})`,
      'tile 을 줄이거나 x/y/w/h 로 영역을 좁힐 것 (픽셀 수 1600만 이하)',
    );
  }
  const out = new PNG({ width: outW, height: outH });

  for (let ty = 0; ty < opts.h; ty++) {
    const my = opts.y + ty;
    for (let tx = 0; tx < opts.w; tx++) {
      const mx = opts.x + tx;
      const dx = tx * opts.tilePx;
      const dy = ty * opts.tilePx;
      if (mx < 0 || my < 0 || mx >= map.width || my >= map.height) continue;

      const ground = a5Rect(getTile(map, 0, mx, my));
      if (ground) blitTile(out, dx, dy, a5Sheet, ground, opts.tilePx);
      for (const z of [2, 3]) {
        const v = getTile(map, z, mx, my);
        if (v > 0) {
          const r = bRect(v);
          if (r) blitTile(out, dx, dy, bSheet, r, opts.tilePx);
        }
      }

      if (opts.night) {
        const s = getTile(map, 4, mx, my);
        if (s > 0) {
          const lightBit =
            opts.playerX !== null && opts.playerY !== null
              ? lightBitFor(mx, my, opts.playerX, opts.playerY, opts.sight)
              : 0;
          const ix = shadowIx(s, lightBit);
          if (ix > 0) {
            const r = bRect(B_SHADOW_BASE + ix);
            if (r) {
              blitTile(out, dx, dy, bSheet, r, opts.tilePx);
              if (!opts.moonlight && ix === 15) blitTile(out, dx, dy, bSheet, r, opts.tilePx);
            }
          }
        }
      }
    }
  }

  if (opts.events) {
    for (const ev of map.events) {
      if (!ev) continue;
      const tx = ev.x - opts.x;
      const ty = ev.y - opts.y;
      if (tx < 0 || ty < 0 || tx >= opts.w || ty >= opts.h) continue;
      const rgb = EVENT_RGB[eventTypeOf(ev.name)] ?? EVENT_RGB.UNKNOWN;
      drawBorder(out, tx * opts.tilePx, ty * opts.tilePx, opts.tilePx, rgb);
    }
  }

  if (opts.night && opts.playerX !== null && opts.playerY !== null) {
    const tx = opts.playerX - opts.x;
    const ty = opts.playerY - opts.y;
    if (tx >= 0 && ty >= 0 && tx < opts.w && ty < opts.h) {
      drawBorder(out, tx * opts.tilePx, ty * opts.tilePx, opts.tilePx, [255, 208, 64]);
    }
  }

  return PNG.sync.write(out);
}

/** 단일 타일 PNG (48×48) — AI 가 특정 타일의 생김새를 확인하는 용도. */
export function renderTile(store: Store, kind: 'a5' | 'b', id: number): Buffer {
  const sheet = loadSheet(store, kind === 'a5' ? 'Lore_A5.png' : 'Lore_B.png');
  const r = kind === 'a5' ? a5Rect(id) : bRect(id);
  if (!r) {
    throw new StoreError(
      400,
      `잘못된 타일 id: ${kind} ${id}`,
      kind === 'a5' ? 'a5 는 0~127' : 'b 는 1~255',
    );
  }
  const out = new PNG({ width: SRC_TILE, height: SRC_TILE });
  blitTile(out, 0, 0, sheet, r, SRC_TILE);
  return PNG.sync.write(out);
}
