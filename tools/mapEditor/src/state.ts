import { EVENT_LAYER, LAYER_META, type MvMap } from './mvmap';

export type Tool = 'pencil' | 'rect' | 'fill' | 'picker' | 'eraser';

export interface TileChange {
  z: number;
  i: number; // z*w*h + y*w + x (data 배열 절대 인덱스)
  before: number;
  after: number;
}

interface Snapshot {
  width: number;
  height: number;
  data: number[];
  eventsJson: string;
}

export type UndoEntry =
  | { kind: 'tiles'; changes: TileChange[] }
  | { kind: 'snapshot'; before: Snapshot; after: Snapshot };

const MAX_UNDO = 200;

export class EditorState {
  map: MvMap | null = null;
  fileName = '';
  dirty = false;
  /** 로드 시점의 파일 버전(mtime). 저장 충돌 감지와 외부 변경 폴링에 사용. */
  rev = '';

  /** 0..5 = 타일 레이어, 6(EVENT_LAYER) = 이벤트 모드. */
  activeLayer = 0;
  layerVisible: boolean[] = LAYER_META.map((m) => m.defaultVisible);
  showEvents = true;
  showGrid = true;
  showPassability = false;

  night = false;
  moonlight = true;
  lightPreview = false;
  sightRange = 2; // 1..4 (5 = 주간과 동일이라 야간 미리보기에선 1~4만)
  playerX = 0;
  playerY = 0;

  zoom = 1;
  panX = 16;
  panY = 16;

  tool: Tool = 'pencil';
  selA5 = 0; // A5 인덱스 (0..127), 저장 시 1536+idx
  selB = 1; // B 타일 ID (0..255), 0 = 지우기
  selShadow = 15; // 0..15
  selRegion = 1; // 0..255

  hoverX = -1;
  hoverY = -1;
  rectStart: { x: number; y: number } | null = null;
  rectEnd: { x: number; y: number } | null = null;
  selectedEventId: number | null = null;

  private undoStack: UndoEntry[] = [];
  private redoStack: UndoEntry[] = [];
  private stroke: Map<string, TileChange> | null = null;

  get isEventMode(): boolean {
    return this.activeLayer === EVENT_LAYER;
  }

  // ── 타일 변경 (스트로크 단위 undo) ──────────────────────────────────

  beginStroke(): void {
    this.stroke = new Map();
  }

  /** 스트로크 중 단일 타일 변경. 같은 타일 재변경 시 최초 before 유지. */
  applyTile(z: number, x: number, y: number, value: number): boolean {
    const map = this.map;
    if (!map || x < 0 || y < 0 || x >= map.width || y >= map.height) return false;
    const i = z * map.width * map.height + y * map.width + x;
    const before = map.data[i] ?? 0;
    if (before === value) return false;
    map.data[i] = value;
    if (this.stroke) {
      const key = `${z}:${i}`;
      const prev = this.stroke.get(key);
      if (prev) prev.after = value;
      else this.stroke.set(key, { z, i, before, after: value });
    }
    this.dirty = true;
    return true;
  }

  endStroke(): void {
    if (this.stroke && this.stroke.size > 0) {
      this.pushUndo({ kind: 'tiles', changes: [...this.stroke.values()] });
    }
    this.stroke = null;
  }

  // ── 스냅샷 undo (이벤트 편집, 리사이즈 등 구조 변경용) ───────────────

  takeSnapshot(): Snapshot | null {
    const map = this.map;
    if (!map) return null;
    return {
      width: map.width,
      height: map.height,
      data: [...map.data],
      eventsJson: JSON.stringify(map.events),
    };
  }

  commitSnapshot(before: Snapshot | null): void {
    const after = this.takeSnapshot();
    if (!before || !after) return;
    if (
      before.width === after.width &&
      before.height === after.height &&
      before.eventsJson === after.eventsJson &&
      before.data.length === after.data.length &&
      before.data.every((v, i) => v === after.data[i])
    ) {
      return; // 실제 변경 없음
    }
    this.pushUndo({ kind: 'snapshot', before, after });
    this.dirty = true;
  }

  private pushUndo(entry: UndoEntry): void {
    this.undoStack.push(entry);
    if (this.undoStack.length > MAX_UNDO) this.undoStack.shift();
    this.redoStack = [];
  }

  get canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  get canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  undo(): void {
    const entry = this.undoStack.pop();
    if (!entry || !this.map) return;
    this.applyEntry(entry, 'before');
    this.redoStack.push(entry);
    this.dirty = true;
  }

  redo(): void {
    const entry = this.redoStack.pop();
    if (!entry || !this.map) return;
    this.applyEntry(entry, 'after');
    this.undoStack.push(entry);
    this.dirty = true;
  }

  private applyEntry(entry: UndoEntry, dir: 'before' | 'after'): void {
    const map = this.map!;
    if (entry.kind === 'tiles') {
      for (const c of entry.changes) {
        map.data[c.i] = dir === 'before' ? c.before : c.after;
      }
    } else {
      const snap = entry[dir];
      map.width = snap.width;
      map.height = snap.height;
      map.data = [...snap.data];
      map.events = JSON.parse(snap.eventsJson);
      this.selectedEventId = null;
    }
  }

  resetForNewMap(map: MvMap, fileName: string): void {
    this.map = map;
    this.fileName = fileName;
    this.dirty = false;
    this.undoStack = [];
    this.redoStack = [];
    this.stroke = null;
    this.selectedEventId = null;
    this.rectStart = null;
    this.rectEnd = null;
    this.playerX = Math.floor(map.width / 2);
    this.playerY = Math.floor(map.height / 2);
    this.panX = 16;
    this.panY = 16;
  }
}
