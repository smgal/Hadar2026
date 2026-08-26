import { lightBitFor, shadowIx } from './lighting';
import { eventActionGrid, eventTypeOf, getTile, type MvMap } from './mvmap';
import {
  ACTION_COLORS,
  ACTION_MOVE,
  B_SHADOW_BASE,
  Tilesets,
  unitAction,
} from './tilesets';
import type { EditorState } from './state';

/** 화면 타일 크기 (게임 렌더와 동일하게 32px 기준, zoom 배율 적용). */
export const TILE = 32;

const EVENT_TYPE_COLORS: Record<string, string> = {
  TALK: '#f050dc',
  SIGN: '#3cdce6',
  EVENT: '#5ae65a',
  ENTER: '#f0dc3c',
  NPC: '#f09040',
  UNKNOWN: '#aaaaaa',
};

export class Renderer {
  private ctx: CanvasRenderingContext2D;
  private base: HTMLCanvasElement;
  private baseCtx: CanvasRenderingContext2D;
  private baseDirty = true;
  private rafPending = false;

  constructor(
    private canvas: HTMLCanvasElement,
    private state: EditorState,
    private tilesets: Tilesets,
  ) {
    this.ctx = canvas.getContext('2d')!;
    this.base = document.createElement('canvas');
    this.baseCtx = this.base.getContext('2d')!;
  }

  markTilesDirty(): void {
    this.baseDirty = true;
  }

  requestRender(): void {
    if (this.rafPending) return;
    this.rafPending = true;
    requestAnimationFrame(() => {
      this.rafPending = false;
      this.render();
    });
  }

  /** 캔버스를 컨테이너 크기에 맞춘다 (devicePixelRatio 반영). */
  resizeToContainer(): void {
    const parent = this.canvas.parentElement!;
    const dpr = window.devicePixelRatio || 1;
    const w = parent.clientWidth;
    const h = parent.clientHeight;
    if (w === 0 || h === 0) return;
    this.canvas.width = Math.round(w * dpr);
    this.canvas.height = Math.round(h * dpr);
    this.canvas.style.width = `${w}px`;
    this.canvas.style.height = `${h}px`;
    this.requestRender();
  }

  private rebuildBase(map: MvMap): void {
    const w = map.width * TILE;
    const h = map.height * TILE;
    if (this.base.width !== w || this.base.height !== h) {
      this.base.width = w;
      this.base.height = h;
    }
    const ctx = this.baseCtx;
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, w, h);

    const st = this.state;
    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        // L0 지면 — 게임과 동일하게 값 0 도 A5 #0 으로 그림
        if (st.layerVisible[0]) {
          const r = this.tilesets.a5Rect(getTile(map, 0, x, y));
          if (r) ctx.drawImage(this.tilesets.a5, r.sx, r.sy, r.sw, r.sh, x * TILE, y * TILE, TILE, TILE);
        }
        // L1 — 게임 미사용 레이어. 값이 있을 때만 그림 (보존 확인용)
        if (st.layerVisible[1]) {
          const v = getTile(map, 1, x, y);
          if (v > 0) {
            const r = this.tilesets.a5Rect(v);
            if (r) ctx.drawImage(this.tilesets.a5, r.sx, r.sy, r.sw, r.sh, x * TILE, y * TILE, TILE, TILE);
          }
        }
        // L2 / L3 오브젝트 (B)
        for (const z of [2, 3]) {
          if (!st.layerVisible[z]) continue;
          const v = getTile(map, z, x, y);
          if (v > 0) {
            const r = this.tilesets.bRect(v);
            if (r) ctx.drawImage(this.tilesets.b, r.sx, r.sy, r.sw, r.sh, x * TILE, y * TILE, TILE, TILE);
          }
        }
      }
    }
    this.baseDirty = false;
  }

  private render(): void {
    // save/restore 를 try/finally 로 감싼다 — 중간에 예외가 나도 dpr 스케일이
    // 중첩 누적되어 캔버스가 영구히 깨지는 것을 막는다.
    try {
      this.renderInner();
    } finally {
      this.ctx.restore();
    }
  }

  private renderInner(): void {
    const st = this.state;
    const map = st.map;
    const ctx = this.ctx;
    const dpr = window.devicePixelRatio || 1;

    ctx.save();
    ctx.scale(dpr, dpr);
    const cw = this.canvas.width / dpr;
    const ch = this.canvas.height / dpr;
    ctx.fillStyle = '#14161c';
    ctx.fillRect(0, 0, cw, ch);

    if (!map || map.width < 1 || map.height < 1) return;
    if (this.baseDirty) this.rebuildBase(map);
    // 폭·높이가 0 인 캔버스를 drawImage 소스로 쓰면 InvalidStateError 가 난다.
    if (this.base.width < 1 || this.base.height < 1) return;

    const ts = TILE * st.zoom;
    const px = (x: number) => st.panX + x * ts;
    const py = (y: number) => st.panY + y * ts;

    // 보이는 타일 범위
    const x0 = Math.max(0, Math.floor(-st.panX / ts));
    const y0 = Math.max(0, Math.floor(-st.panY / ts));
    const x1 = Math.min(map.width - 1, Math.ceil((cw - st.panX) / ts));
    const y1 = Math.min(map.height - 1, Math.ceil((ch - st.panY) / ts));

    // 베이스 (지면 + 오브젝트)
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(
      this.base,
      0,
      0,
      this.base.width,
      this.base.height,
      st.panX,
      st.panY,
      this.base.width * st.zoom,
      this.base.height * st.zoom,
    );

    // 맵 테두리
    ctx.strokeStyle = '#4a5060';
    ctx.lineWidth = 1;
    ctx.strokeRect(st.panX - 0.5, st.panY - 0.5, map.width * ts + 1, map.height * ts + 1);

    // 야간 뷰 — 게임 공식 그대로 (B 시트 240+ix 스프라이트)
    if (st.night) {
      for (let y = y0; y <= y1; y++) {
        for (let x = x0; x <= x1; x++) {
          const s = getTile(map, 4, x, y);
          if (s <= 0) continue; // shadow 0 = 항상 밝음 (게임과 동일)
          const lightBit = st.lightPreview
            ? lightBitFor(x, y, st.playerX, st.playerY, st.sightRange)
            : 0;
          const ix = shadowIx(s, lightBit);
          if (ix <= 0) continue;
          const r = this.tilesets.bRect(B_SHADOW_BASE + ix);
          if (!r) continue;
          ctx.drawImage(this.tilesets.b, r.sx, r.sy, r.sw, r.sh, px(x), py(y), ts, ts);
          if (!st.moonlight && ix === 15) {
            ctx.drawImage(this.tilesets.b, r.sx, r.sy, r.sw, r.sh, px(x), py(y), ts, ts);
          }
        }
      }
    }

    // L4 그림자 진단 오버레이 (편집용) — 사분면 비트를 보라색으로 표시
    if (st.layerVisible[4] || st.activeLayer === 4) {
      ctx.fillStyle = 'rgba(140, 60, 240, 0.4)';
      const half = ts / 2;
      for (let y = y0; y <= y1; y++) {
        for (let x = x0; x <= x1; x++) {
          const s = getTile(map, 4, x, y);
          if (s <= 0) continue;
          // 비트: 1=좌상, 2=우상, 4=좌하, 8=우하 (lightBitFor 의 shift 규약)
          if (s & 1) ctx.fillRect(px(x), py(y), half, half);
          if (s & 2) ctx.fillRect(px(x) + half, py(y), half, half);
          if (s & 4) ctx.fillRect(px(x), py(y) + half, half, half);
          if (s & 8) ctx.fillRect(px(x) + half, py(y) + half, half, half);
        }
      }
    }

    // L5 지역 ID 오버레이
    if (st.layerVisible[5] || st.activeLayer === 5) {
      for (let y = y0; y <= y1; y++) {
        for (let x = x0; x <= x1; x++) {
          const v = getTile(map, 5, x, y);
          if (v <= 0) continue;
          ctx.fillStyle = `hsla(${(v * 47) % 360}, 80%, 55%, 0.4)`;
          ctx.fillRect(px(x), py(y), ts, ts);
          if (st.zoom >= 1) {
            ctx.fillStyle = '#fff';
            ctx.font = `${Math.max(9, 10 * st.zoom)}px monospace`;
            ctx.textBaseline = 'top';
            ctx.fillText(String(v), px(x) + 2, py(y) + 2);
          }
        }
      }
    }

    // 통행/액션 오버레이
    if (st.showPassability) {
      const evType = eventActionGrid(map);
      for (let y = y0; y <= y1; y++) {
        for (let x = x0; x <= x1; x++) {
          const action = unitAction(
            getTile(map, 0, x, y),
            getTile(map, 3, x, y),
            evType.get(y * map.width + x) ?? null,
          );
          if (action === ACTION_MOVE) continue;
          const color = ACTION_COLORS[action];
          if (!color) continue;
          ctx.fillStyle = color;
          ctx.fillRect(px(x), py(y), ts, ts);
        }
      }
    }

    // 이벤트 마커
    if (st.showEvents || st.isEventMode) {
      for (const ev of map.events) {
        if (!ev || ev.x < x0 - 1 || ev.x > x1 + 1 || ev.y < y0 - 1 || ev.y > y1 + 1) continue;
        const type = eventTypeOf(ev.name);
        const color = EVENT_TYPE_COLORS[type] ?? EVENT_TYPE_COLORS.UNKNOWN;
        const selected = st.selectedEventId === ev.id;
        ctx.strokeStyle = selected ? '#ffffff' : color;
        ctx.lineWidth = selected ? 3 : 2;
        ctx.strokeRect(px(ev.x) + 1.5, py(ev.y) + 1.5, ts - 3, ts - 3);
        ctx.fillStyle = color;
        ctx.globalAlpha = 0.25;
        ctx.fillRect(px(ev.x) + 1.5, py(ev.y) + 1.5, ts - 3, ts - 3);
        ctx.globalAlpha = 1;
        if (st.zoom >= 0.75) {
          ctx.fillStyle = selected ? '#ffffff' : color;
          ctx.font = `bold ${Math.max(10, 12 * st.zoom)}px monospace`;
          ctx.textBaseline = 'middle';
          ctx.textAlign = 'center';
          ctx.fillText(type[0] ?? '?', px(ev.x) + ts / 2, py(ev.y) + ts / 2);
          ctx.textAlign = 'left';
        }
      }
    }

    // 격자
    if (st.showGrid && ts >= 8) {
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let x = x0; x <= x1 + 1; x++) {
        ctx.moveTo(px(x) + 0.5, py(y0));
        ctx.lineTo(px(x) + 0.5, py(y1 + 1));
      }
      for (let y = y0; y <= y1 + 1; y++) {
        ctx.moveTo(px(x0), py(y) + 0.5);
        ctx.lineTo(px(x1 + 1), py(y) + 0.5);
      }
      ctx.stroke();
    }

    // 사각형 도구 미리보기
    if (st.rectStart && st.rectEnd) {
      const rx0 = Math.min(st.rectStart.x, st.rectEnd.x);
      const ry0 = Math.min(st.rectStart.y, st.rectEnd.y);
      const rx1 = Math.max(st.rectStart.x, st.rectEnd.x);
      const ry1 = Math.max(st.rectStart.y, st.rectEnd.y);
      ctx.fillStyle = 'rgba(80, 160, 255, 0.25)';
      ctx.fillRect(px(rx0), py(ry0), (rx1 - rx0 + 1) * ts, (ry1 - ry0 + 1) * ts);
      ctx.strokeStyle = '#50a0ff';
      ctx.lineWidth = 2;
      ctx.strokeRect(px(rx0) + 1, py(ry0) + 1, (rx1 - rx0 + 1) * ts - 2, (ry1 - ry0 + 1) * ts - 2);
    }

    // 야간 광원 미리보기 — 플레이어 마커 + 시야 반경
    if (st.night && st.lightPreview) {
      const cx = px(st.playerX) + ts / 2;
      const cy = py(st.playerY) + ts / 2;
      ctx.strokeStyle = '#ffd040';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(cx, cy, ts * 0.38, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = 'rgba(255, 208, 64, 0.35)';
      ctx.fill();
      // 시야 원 (반지름: (2*sightRange+0.3)/2 타일 — lightBitFor 공식의 경계)
      ctx.setLineDash([6, 4]);
      ctx.strokeStyle = 'rgba(255, 208, 64, 0.6)';
      ctx.beginPath();
      ctx.arc(cx, cy, ((2 * st.sightRange + 0.3) / 2) * ts, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // 커서 위치 강조
    if (st.hoverX >= 0 && st.hoverY >= 0 && st.hoverX < map.width && st.hoverY < map.height) {
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 1.5;
      ctx.strokeRect(px(st.hoverX) + 0.75, py(st.hoverY) + 0.75, ts - 1.5, ts - 1.5);
    }
    // restore 는 render() 의 finally 가 담당한다.
  }
}
