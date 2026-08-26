import { LAYER_META, getTile, type PaletteKind } from './mvmap';
import {
  A5_BASE,
  A5_COLS,
  A5_COUNT,
  B_COUNT,
  B_SHADOW_BASE,
  SRC_TILE,
  Tilesets,
} from './tilesets';
import type { EditorState } from './state';

/**
 * 활성 레이어에 따라 달라지는 스프라이트 팔레트 패널.
 *  - 지면(L0/L1): Lore_A5.png 128타일
 *  - 오브젝트(L2/L3): Lore_B.png 256타일 (0 = 지우기)
 *  - 빛/그림자(L4): 사분면 비트 0~15 (실제 야간 오버레이 스프라이트로 표시)
 *  - 지역(L5): 숫자 ID + 맵에서 사용 중인 값
 */
export class PalettePanel {
  constructor(
    private root: HTMLElement,
    private title: HTMLElement,
    private state: EditorState,
    private tilesets: Tilesets,
    private onPicked: () => void,
  ) {}

  currentKind(): PaletteKind | null {
    if (this.state.isEventMode) return null;
    return LAYER_META[this.state.activeLayer]?.palette ?? null;
  }

  /** 레이어 전환/선택 변경 시 호출. DOM 을 전부 다시 만든다. */
  refresh(): void {
    const kind = this.currentKind();
    this.root.innerHTML = '';
    if (kind === null) {
      this.title.textContent = '팔레트';
      this.root.innerHTML =
        '<div class="palInfo">이벤트 모드 — 캔버스에서 이벤트를 클릭해 선택하고,<br>선택 상태에서 빈 타일을 클릭하면 이동합니다.</div>';
      return;
    }
    this.title.textContent = `팔레트 — ${LAYER_META[this.state.activeLayer].label}`;
    if (kind === 'a5') this.buildA5();
    else if (kind === 'b') this.buildB();
    else if (kind === 'shadow') this.buildShadow();
    else this.buildRegion();
  }

  private buildA5(): void {
    const cell = 42;
    const canvas = document.createElement('canvas');
    canvas.width = A5_COLS * cell;
    canvas.height = (A5_COUNT / A5_COLS) * cell;
    canvas.style.width = '100%';
    const ctx = canvas.getContext('2d')!;
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(this.tilesets.a5, 0, 0, canvas.width, canvas.height);
    this.drawSel(ctx, this.state.selA5 % A5_COLS, Math.floor(this.state.selA5 / A5_COLS), cell);

    canvas.addEventListener('pointerdown', (e) => {
      const { col, row } = this.cellAt(canvas, e, cell);
      const idx = row * A5_COLS + col;
      if (idx >= 0 && idx < A5_COUNT) {
        this.state.selA5 = idx;
        this.refresh();
        this.onPicked();
      }
    });
    this.root.appendChild(canvas);

    const info = document.createElement('div');
    info.className = 'palInfo';
    info.textContent = `선택: A5 #${this.state.selA5} → 데이터값 ${A5_BASE + this.state.selA5}`;
    this.root.appendChild(info);
  }

  private buildB(): void {
    const cell = 21;
    const cols = 16;
    const canvas = document.createElement('canvas');
    canvas.width = cols * cell;
    canvas.height = cols * cell;
    canvas.style.width = '100%';
    const ctx = canvas.getContext('2d')!;
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#101218';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    // B 시트의 시각 배치가 그대로 팔레트 배치 (좌반 0..127, 우반 128..255)
    ctx.drawImage(this.tilesets.b, 0, 0, canvas.width, canvas.height);
    const sel = this.state.selB;
    if (sel > 0) {
      const { col, row } = bIdToCell(sel);
      this.drawSel(ctx, col, row, cell);
    }

    canvas.addEventListener('pointerdown', (e) => {
      const { col, row } = this.cellAt(canvas, e, cell);
      const id = col < 8 ? row * 8 + col : 128 + row * 8 + (col - 8);
      if (id >= 0 && id < B_COUNT) {
        this.state.selB = id;
        this.refresh();
        this.onPicked();
      }
    });
    this.root.appendChild(canvas);

    const info = document.createElement('div');
    info.className = 'palInfo';
    info.textContent =
      this.state.selB === 0 ? '선택: 없음(0) — 지우기' : `선택: B #${this.state.selB}`;
    this.root.appendChild(info);

    const chips = document.createElement('div');
    chips.className = 'chipRow';
    const erase = document.createElement('span');
    erase.className = 'chip' + (this.state.selB === 0 ? ' sel' : '');
    erase.textContent = '지우기 (0)';
    erase.onclick = () => {
      this.state.selB = 0;
      this.refresh();
      this.onPicked();
    };
    chips.appendChild(erase);
    this.root.appendChild(chips);
  }

  private buildShadow(): void {
    const cell = 42;
    const cols = 8;
    const canvas = document.createElement('canvas');
    canvas.width = cols * cell;
    canvas.height = 2 * cell;
    canvas.style.width = '100%';
    const ctx = canvas.getContext('2d')!;
    ctx.imageSmoothingEnabled = false;
    for (let i = 0; i < 16; i++) {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const x = col * cell;
      const y = row * cell;
      // 밝은 바닥 위에 실제 야간 오버레이(B 240+i)를 겹쳐 미리보기
      ctx.fillStyle = '#c8b070';
      ctx.fillRect(x, y, cell, cell);
      if (i > 0) {
        const r = this.tilesets.bRect(B_SHADOW_BASE + i);
        if (r) ctx.drawImage(this.tilesets.b, r.sx, r.sy, SRC_TILE, SRC_TILE, x, y, cell, cell);
      }
      ctx.fillStyle = i === 0 ? '#14161c' : '#fff';
      ctx.font = '11px monospace';
      ctx.textBaseline = 'top';
      ctx.fillText(String(i), x + 3, y + 3);
      ctx.strokeStyle = '#3a4054';
      ctx.strokeRect(x + 0.5, y + 0.5, cell - 1, cell - 1);
    }
    const sel = this.state.selShadow;
    this.drawSel(ctx, sel % cols, Math.floor(sel / cols), cell);

    canvas.addEventListener('pointerdown', (e) => {
      const { col, row } = this.cellAt(canvas, e, cell);
      const v = row * cols + col;
      if (v >= 0 && v <= 15) {
        this.state.selShadow = v;
        this.refresh();
        this.onPicked();
      }
    });
    this.root.appendChild(canvas);

    const info = document.createElement('div');
    info.className = 'palInfo';
    info.innerHTML =
      `선택: ${sel} — ` +
      (sel === 0 ? '항상 밝음 (광원 지역)' : sel === 15 ? '야간 완전 암전' : '부분 그림자 (사분면)') +
      '<br>비트: 1=좌상 2=우상 4=좌하 8=우하';
    this.root.appendChild(info);
  }

  private buildRegion(): void {
    const row = document.createElement('div');
    row.className = 'row';
    row.innerHTML = `지역 ID <input type="number" min="0" max="255" class="num" value="${this.state.selRegion}" /> <span class="palInfo">0 = 지우기</span>`;
    const input = row.querySelector('input')!;
    input.addEventListener('change', () => {
      const v = Math.max(0, Math.min(255, Number(input.value) || 0));
      this.state.selRegion = v;
      this.refresh();
      this.onPicked();
    });
    this.root.appendChild(row);

    // 현재 맵에서 사용 중인 지역 값
    const map = this.state.map;
    if (map) {
      const used = new Set<number>();
      for (let y = 0; y < map.height; y++) {
        for (let x = 0; x < map.width; x++) {
          const v = getTile(map, 5, x, y);
          if (v > 0) used.add(v);
        }
      }
      const chips = document.createElement('div');
      chips.className = 'chipRow';
      for (const v of [...used].sort((a, b) => a - b)) {
        const chip = document.createElement('span');
        chip.className = 'chip' + (v === this.state.selRegion ? ' sel' : '');
        chip.textContent = String(v);
        chip.style.borderColor = `hsl(${(v * 47) % 360}, 80%, 55%)`;
        chip.onclick = () => {
          this.state.selRegion = v;
          this.refresh();
          this.onPicked();
        };
        chips.appendChild(chip);
      }
      if (used.size > 0) {
        const label = document.createElement('div');
        label.className = 'palInfo';
        label.textContent = '이 맵에서 사용 중:';
        this.root.appendChild(label);
        this.root.appendChild(chips);
      }
    }
  }

  private cellAt(
    canvas: HTMLCanvasElement,
    e: PointerEvent,
    cell: number,
  ): { col: number; row: number } {
    const rect = canvas.getBoundingClientRect();
    const scale = canvas.width / rect.width;
    const col = Math.floor(((e.clientX - rect.left) * scale) / cell);
    const row = Math.floor(((e.clientY - rect.top) * scale) / cell);
    return { col, row };
  }

  private drawSel(ctx: CanvasRenderingContext2D, col: number, row: number, cell: number): void {
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 2;
    ctx.strokeRect(col * cell + 1, row * cell + 1, cell - 2, cell - 2);
    ctx.strokeStyle = '#3563c4';
    ctx.strokeRect(col * cell + 3, row * cell + 3, cell - 6, cell - 6);
  }
}

function bIdToCell(id: number): { col: number; row: number } {
  if (id < 128) return { col: id % 8, row: Math.floor(id / 8) };
  const localId = id - 128;
  return { col: 8 + (localId % 8), row: Math.floor(localId / 8) };
}
