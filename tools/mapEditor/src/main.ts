import { SaveConflictError, fetchMap, fetchMapList, fetchRev, resolveMapNames, saveMap } from './api';
import { EventsPanel } from './events_panel';
import {
  EVENT_LAYER,
  LAYER_META,
  eventAt,
  getTile,
  normalizeData,
  resizeMap,
  serializeMv,
} from './mvmap';
import { PalettePanel } from './palette';
import { Renderer, TILE } from './renderer';
import { EditorState, type Tool } from './state';
import { A5_BASE, ACTION_NAMES, Tilesets, a5Index, unitAction } from './tilesets';

const $ = <T extends HTMLElement>(id: string): T => document.getElementById(id) as T;

const state = new EditorState();
const tilesets = new Tilesets();

const canvas = $<HTMLCanvasElement>('mapCanvas');
const renderer = new Renderer(canvas, state, tilesets);
const palette = new PalettePanel(
  $('paletteRoot'),
  $('paletteTitle'),
  state,
  tilesets,
  () => renderer.requestRender(),
);
const eventsPanel = new EventsPanel($('eventsRoot'), state, mutateWithSnapshot, () =>
  renderer.requestRender(),
);

// ── 유틸 ────────────────────────────────────────────────────────────

function mutateWithSnapshot(fn: () => void): void {
  const before = state.takeSnapshot();
  fn();
  state.commitSnapshot(before);
  renderer.markTilesDirty();
  renderer.requestRender();
  refreshToolbar();
  refreshMapInfo(); // 크기·이벤트 수가 바뀌었을 수 있음
}

/** 실행취소/다시실행 공통 경로 — 사이드바까지 함께 갱신해 스테일 UI 를 막는다. */
function applyHistory(dir: 'undo' | 'redo'): void {
  if (dir === 'undo') state.undo();
  else state.redo();
  renderer.markTilesDirty();
  renderer.requestRender();
  refreshToolbar();
  refreshMapInfo();
  if (state.isEventMode) eventsPanel.refresh();
}

function paintValueForLayer(z: number): number {
  if (z === 0 || z === 1) return A5_BASE + state.selA5;
  if (z === 2 || z === 3) return state.selB;
  if (z === 4) return state.selShadow;
  return state.selRegion;
}

function tileFromMouse(e: PointerEvent | WheelEvent): { x: number; y: number } {
  const rect = canvas.getBoundingClientRect();
  const ts = TILE * state.zoom;
  return {
    x: Math.floor((e.clientX - rect.left - state.panX) / ts),
    y: Math.floor((e.clientY - rect.top - state.panY) / ts),
  };
}

// ── 툴바 / 레이어 / 상태바 갱신 ──────────────────────────────────────

function refreshToolbar(): void {
  $('dirtyDot').classList.toggle('on', state.dirty);
  ($('undoBtn') as HTMLButtonElement).disabled = !state.canUndo;
  ($('redoBtn') as HTMLButtonElement).disabled = !state.canRedo;
  document.querySelectorAll<HTMLButtonElement>('.toolBtn').forEach((b) => {
    b.classList.toggle('active', b.dataset.tool === state.tool);
  });
  $('zoomLabel').textContent = `${Math.round(state.zoom * 100)}%`;
  $('nightOpts').classList.toggle('hidden', !state.night);
  $('sightOpts').classList.toggle('hidden', !state.lightPreview);
}

function refreshLayerList(): void {
  const root = $('layerList');
  root.innerHTML = '';
  for (const meta of LAYER_META) {
    root.appendChild(layerRow(meta.z, meta.label, state.layerVisible[meta.z], (v) => {
      state.layerVisible[meta.z] = v;
      if (meta.z <= 3) renderer.markTilesDirty();
      renderer.requestRender();
    }));
  }
  root.appendChild(
    layerRow(EVENT_LAYER, '이벤트', state.showEvents, (v) => {
      state.showEvents = v;
      renderer.requestRender();
    }),
  );
}

function layerRow(
  z: number,
  label: string,
  visible: boolean,
  onVisible: (v: boolean) => void,
): HTMLElement {
  const row = document.createElement('div');
  row.className = 'layerRow' + (state.activeLayer === z ? ' active' : '');
  const eye = document.createElement('span');
  eye.className = 'eye';
  eye.textContent = visible ? '👁' : '▢';
  eye.title = '표시 켜기/끄기';
  eye.onclick = (e) => {
    e.stopPropagation();
    onVisible(!visible);
    refreshLayerList();
  };
  const name = document.createElement('span');
  name.textContent = label;
  row.append(eye, name);
  row.onclick = () => {
    state.activeLayer = z;
    refreshLayerList();
    palette.refresh();
    $('eventsSection').classList.toggle('hidden', !state.isEventMode);
    if (state.isEventMode) eventsPanel.refresh();
    renderer.requestRender();
    updateHint();
  };
  return row;
}

function updateStatus(): void {
  const map = state.map;
  const { hoverX: x, hoverY: y } = state;
  if (!map || x < 0 || y < 0 || x >= map.width || y >= map.height) {
    $('posSpan').textContent = '(-, -)';
    $('valsSpan').textContent = '';
    $('actionSpan').textContent = '';
    return;
  }
  $('posSpan').textContent = `(${x}, ${y})`;
  const vals: string[] = [];
  for (let z = 0; z < 6; z++) {
    const v = getTile(map, z, x, y);
    if (z <= 1) vals.push(`L${z}:${v}${v >= A5_BASE ? `(A5#${a5Index(v)})` : ''}`);
    else vals.push(`L${z}:${v}`);
  }
  $('valsSpan').textContent = vals.join(' ');
  const ev = eventAt(map, x, y);
  const action = unitAction(
    getTile(map, 0, x, y),
    getTile(map, 3, x, y),
    ev ? evTypeForAction(ev.name) : null,
  );
  $('actionSpan').textContent =
    `액션: ${ACTION_NAMES[action]}` + (ev ? ` | 이벤트: ${ev.name}` : '');
}

function evTypeForAction(name: string): string | null {
  for (const t of ['TALK', 'ENTER', 'SIGN']) if (name.startsWith(t)) return t;
  if (name.startsWith('EVENT') || name.startsWith('EVT')) return 'EVENT';
  return null;
}

function updateHint(): void {
  const hint = state.isEventMode
    ? '클릭: 이벤트 선택 / 선택 후 빈 타일 클릭: 이동'
    : '우클릭: 지우기 · Alt+클릭: 스포이드 · Space/휠클릭 드래그: 이동 · Ctrl+휠: 줌' +
      (state.night && state.lightPreview ? ' · Ctrl+클릭: 광원 위치' : '');
  $('hintSpan').textContent = hint;
}

// ── 그리기 도구 ──────────────────────────────────────────────────────

let painting: { erase: boolean } | null = null;
let panDrag: { sx: number; sy: number; panX: number; panY: number } | null = null;
let spaceDown = false;
/** 사각형 도구를 시작한 마우스 버튼 (0=칠하기, 2=지우기). */
let rectButton: number | null = null;

function paintAt(x: number, y: number, erase: boolean): void {
  const z = state.activeLayer;
  const value = erase ? 0 : paintValueForLayer(z);
  if (state.applyTile(z, x, y, value)) {
    if (z <= 3) renderer.markTilesDirty();
    renderer.requestRender();
    refreshToolbar();
  }
}

function floodFill(x: number, y: number, erase: boolean): void {
  const map = state.map;
  if (!map || x < 0 || y < 0 || x >= map.width || y >= map.height) return;
  const z = state.activeLayer;
  const target = getTile(map, z, x, y);
  const value = erase ? 0 : paintValueForLayer(z);
  if (target === value) return;
  state.beginStroke();
  const stack = [[x, y]];
  const seen = new Set<number>([y * map.width + x]);
  while (stack.length > 0) {
    const [cx, cy] = stack.pop()!;
    state.applyTile(z, cx, cy, value);
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (nx < 0 || ny < 0 || nx >= map.width || ny >= map.height) continue;
      const key = ny * map.width + nx;
      if (seen.has(key) || getTile(map, z, nx, ny) !== target) continue;
      seen.add(key);
      stack.push([nx, ny]);
    }
  }
  state.endStroke();
  if (z <= 3) renderer.markTilesDirty();
  renderer.requestRender();
  refreshToolbar();
}

function applyRect(erase: boolean): void {
  if (!state.rectStart || !state.rectEnd) return;
  const x0 = Math.min(state.rectStart.x, state.rectEnd.x);
  const y0 = Math.min(state.rectStart.y, state.rectEnd.y);
  const x1 = Math.max(state.rectStart.x, state.rectEnd.x);
  const y1 = Math.max(state.rectStart.y, state.rectEnd.y);
  const z = state.activeLayer;
  const value = erase ? 0 : paintValueForLayer(z);
  state.beginStroke();
  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) state.applyTile(z, x, y, value);
  }
  state.endStroke();
  state.rectStart = null;
  state.rectEnd = null;
  if (z <= 3) renderer.markTilesDirty();
  renderer.requestRender();
  refreshToolbar();
}

function pick(x: number, y: number): void {
  const map = state.map;
  if (!map || x < 0 || y < 0 || x >= map.width || y >= map.height) return;
  const z = state.activeLayer;
  const v = getTile(map, z, x, y);
  if (z <= 1) state.selA5 = Math.max(0, Math.min(127, a5Index(v)));
  else if (z <= 3) state.selB = Math.max(0, Math.min(255, v));
  else if (z === 4) state.selShadow = Math.max(0, Math.min(15, v));
  else state.selRegion = Math.max(0, Math.min(255, v));
  palette.refresh();
}

// ── 캔버스 입력 ──────────────────────────────────────────────────────

canvas.addEventListener('contextmenu', (e) => e.preventDefault());

canvas.addEventListener('pointerdown', (e) => {
  canvas.setPointerCapture(e.pointerId);
  const map = state.map;
  if (!map) return;

  // 이미 다른 조작(붓질/사각형/팬)이 진행 중이면 추가 버튼 입력을 무시한다 —
  // 사각형 프리뷰 중 우클릭이 그 영역을 통째로 지워버리는 사고를 막는다.
  if (painting || panDrag || state.rectStart) return;

  // 팬: 휠클릭 또는 Space+좌클릭
  if (e.button === 1 || (e.button === 0 && spaceDown)) {
    panDrag = { sx: e.clientX, sy: e.clientY, panX: state.panX, panY: state.panY };
    canvas.classList.add('panning');
    return;
  }

  const { x, y } = tileFromMouse(e);

  // 광원 미리보기 위치 이동 (Ctrl+클릭).
  // macOS 는 ctrl+좌클릭을 button 2 로 보내므로 둘 다 받는다 — 안 그러면
  // 문서화된 조작이 "지우개"로 동작한다.
  if ((e.button === 0 || e.button === 2) && e.ctrlKey && state.night && state.lightPreview) {
    if (x >= 0 && y >= 0 && x < map.width && y < map.height) {
      state.playerX = x;
      state.playerY = y;
      renderer.requestRender();
    }
    return;
  }

  // 이벤트 모드
  if (state.isEventMode) {
    if (e.button !== 0 || x < 0 || y < 0 || x >= map.width || y >= map.height) return;
    const ev = eventAt(map, x, y);
    if (ev) {
      state.selectedEventId = ev.id;
      eventsPanel.refresh();
      renderer.requestRender();
    } else if (state.selectedEventId !== null && map.events[state.selectedEventId]) {
      mutateWithSnapshot(() => {
        const sel = map.events[state.selectedEventId!]!;
        sel.x = x;
        sel.y = y;
      });
      eventsPanel.refresh();
    }
    return;
  }

  // 스포이드 (Alt+클릭 또는 도구)
  if (e.button === 0 && (e.altKey || state.tool === 'picker')) {
    pick(x, y);
    return;
  }

  const erase = e.button === 2 || state.tool === 'eraser';

  if (state.tool === 'fill' && !erase) {
    floodFill(x, y, false);
    return;
  }
  if (state.tool === 'rect' && (e.button === 0 || e.button === 2)) {
    state.rectStart = { x, y };
    state.rectEnd = { x, y };
    rectButton = e.button; // 우클릭으로 시작하면 지우는 사각형
    renderer.requestRender();
    return;
  }
  // 붓 / 지우개 / 우클릭 지우기
  if (e.button === 0 || e.button === 2) {
    painting = { erase };
    state.beginStroke();
    paintAt(x, y, erase);
  }
});

canvas.addEventListener('pointermove', (e) => {
  if (panDrag) {
    state.panX = panDrag.panX + (e.clientX - panDrag.sx);
    state.panY = panDrag.panY + (e.clientY - panDrag.sy);
    renderer.requestRender();
    return;
  }
  const { x, y } = tileFromMouse(e);
  if (x !== state.hoverX || y !== state.hoverY) {
    state.hoverX = x;
    state.hoverY = y;
    updateStatus();
    renderer.requestRender();
  }
  if (painting) {
    paintAt(x, y, painting.erase);
  } else if (state.rectStart) {
    state.rectEnd = { x, y };
    renderer.requestRender();
  }
});

window.addEventListener('pointerup', (e) => {
  if (panDrag) {
    panDrag = null;
    canvas.classList.remove('panning');
    return;
  }
  if (painting) {
    state.endStroke();
    painting = null;
    refreshToolbar();
  }
  // 사각형을 시작한 버튼이 떨어질 때만 적용 — 다른 버튼의 pointerup 에 휩쓸리지 않게.
  if (state.rectStart && (rectButton === null || e.button === rectButton)) {
    applyRect(rectButton === 2);
    rectButton = null;
  }
});

canvas.addEventListener('pointerleave', () => {
  state.hoverX = -1;
  state.hoverY = -1;
  updateStatus();
  renderer.requestRender();
});

canvas.addEventListener(
  'wheel',
  (e) => {
    e.preventDefault();
    if (e.ctrlKey || e.metaKey) {
      // 커서 위치를 앵커로 줌
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const oldZoom = state.zoom;
      const dir = e.deltaY < 0 ? 1 : -1;
      setZoom(dir > 0 ? nextZoom(oldZoom) : prevZoom(oldZoom), mx, my);
    } else {
      state.panX -= e.deltaX;
      state.panY -= e.deltaY;
      renderer.requestRender();
    }
  },
  { passive: false },
);

const ZOOM_LEVELS = [0.25, 0.5, 0.75, 1, 1.5, 2, 3];

function nextZoom(z: number): number {
  return ZOOM_LEVELS.find((v) => v > z + 1e-6) ?? z;
}

function prevZoom(z: number): number {
  return [...ZOOM_LEVELS].reverse().find((v) => v < z - 1e-6) ?? z;
}

function setZoom(newZoom: number, anchorX?: number, anchorY?: number): void {
  if (newZoom === state.zoom) return;
  const ax = anchorX ?? canvas.clientWidth / 2;
  const ay = anchorY ?? canvas.clientHeight / 2;
  const scale = newZoom / state.zoom;
  state.panX = ax - (ax - state.panX) * scale;
  state.panY = ay - (ay - state.panY) * scale;
  state.zoom = newZoom;
  refreshToolbar();
  renderer.requestRender();
}

// ── 키보드 ──────────────────────────────────────────────────────────

const TOOL_KEYS: Record<string, Tool> = {
  b: 'pencil',
  r: 'rect',
  f: 'fill',
  i: 'picker',
  x: 'eraser',
};

window.addEventListener('keydown', (e) => {
  const target = e.target as HTMLElement;
  if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT') {
    return;
  }
  if (e.code === 'Space') {
    spaceDown = true;
    canvas.classList.add('panning');
    e.preventDefault();
    return;
  }
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    void doSave();
    return;
  }
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') {
    e.preventDefault();
    applyHistory(e.shiftKey ? 'redo' : 'undo');
    return;
  }
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') {
    e.preventDefault();
    applyHistory('redo');
    return;
  }
  if (e.key >= '1' && e.key <= '7') {
    const z = Number(e.key) - 1;
    state.activeLayer = z; // 7 = 이벤트 모드
    refreshLayerList();
    palette.refresh();
    $('eventsSection').classList.toggle('hidden', !state.isEventMode);
    if (state.isEventMode) eventsPanel.refresh();
    renderer.requestRender();
    updateHint();
    return;
  }
  const tool = TOOL_KEYS[e.key.toLowerCase()];
  if (tool && !e.ctrlKey && !e.metaKey) {
    state.tool = tool;
    refreshToolbar();
    return;
  }
  if (e.key.toLowerCase() === 'g') {
    state.showGrid = !state.showGrid;
    ($('gridChk') as HTMLInputElement).checked = state.showGrid;
    renderer.requestRender();
    return;
  }
  if (e.key.toLowerCase() === 'n') {
    state.night = !state.night;
    ($('nightChk') as HTMLInputElement).checked = state.night;
    refreshToolbar();
    renderer.requestRender();
    updateHint();
  }
});

window.addEventListener('keyup', (e) => {
  if (e.code === 'Space') {
    spaceDown = false;
    if (!panDrag) canvas.classList.remove('panning');
  }
});

// ── 저장 / 로드 ─────────────────────────────────────────────────────

async function doSave(force = false): Promise<void> {
  const map = state.map;
  if (!map || !state.fileName) return;
  try {
    state.rev = await saveMap(state.fileName, serializeMv(map), state.rev, force);
    state.dirty = false;
    refreshToolbar();
    updateHint(); // 해소된 "외부에서 변경됨" 경고를 기본 힌트로 되돌린다
    flashStatus(`저장됨: ${state.fileName}`);
  } catch (e) {
    if (e instanceof SaveConflictError) {
      if (confirm('파일이 외부(AI API 등)에서 변경됐습니다.\n외부 변경을 버리고 이 화면의 내용으로 덮어쓸까요?')) {
        await doSave(true);
      }
      return;
    }
    alert(String(e));
  }
}

function flashStatus(msg: string): void {
  const span = $('hintSpan');
  span.textContent = msg;
  setTimeout(() => {
    // 낡은 문구를 복원하지 않고 현재 상태 기준 힌트로 되돌린다.
    if (span.textContent === msg) updateHint();
  }, 2500);
}

async function loadMapFile(file: string): Promise<void> {
  if (state.dirty && !confirm('저장하지 않은 변경이 있습니다. 버리고 다른 맵을 열까요?')) {
    ($('mapSelect') as HTMLSelectElement).value = state.fileName;
    return;
  }
  const { map, rev } = await fetchMap(file);
  normalizeData(map);
  if (!Array.isArray(map.events)) map.events = [];
  state.resetForNewMap(map, file);
  state.rev = rev;
  try {
    localStorage.setItem('hadar.lastMap', file); // 새로고침/서버 재시작 후에도 같은 맵 복원
  } catch {
    // localStorage 불가 환경은 무시
  }
  renderer.markTilesDirty();
  refreshMapInfo();
  refreshLayerList();
  palette.refresh();
  eventsPanel.refresh();
  $('eventsSection').classList.toggle('hidden', !state.isEventMode);
  refreshToolbar();
  renderer.requestRender();
  updateHint();
}

/** 외부(AI API 등) 변경을 화면에 반영 — 뷰(팬/줌/선택 레이어 등)는 유지. */
async function reloadFromDisk(): Promise<void> {
  const file = state.fileName;
  if (!file) return;
  const kept = {
    panX: state.panX,
    panY: state.panY,
    playerX: state.playerX,
    playerY: state.playerY,
    selectedEventId: state.selectedEventId,
  };
  const { map, rev } = await fetchMap(file);
  normalizeData(map);
  if (!Array.isArray(map.events)) map.events = [];
  state.resetForNewMap(map, file);
  state.rev = rev;
  state.panX = kept.panX;
  state.panY = kept.panY;
  state.playerX = Math.min(kept.playerX, map.width - 1);
  state.playerY = Math.min(kept.playerY, map.height - 1);
  if (kept.selectedEventId !== null && map.events[kept.selectedEventId]) {
    state.selectedEventId = kept.selectedEventId;
  }
  renderer.markTilesDirty();
  refreshMapInfo();
  palette.refresh();
  if (state.isEventMode) eventsPanel.refresh();
  refreshToolbar();
  renderer.requestRender();
  flashStatus('외부 변경 반영됨 (AI API)');
}

/** 사이드바 입력칸(이벤트 인스펙터·표시 이름·크기)에 커서가 있으면 미적용 편집 중으로 본다. */
function hasPendingInput(): boolean {
  const el = document.activeElement as HTMLElement | null;
  if (!el) return false;
  const tag = el.tagName;
  if (tag !== 'INPUT' && tag !== 'TEXTAREA' && tag !== 'SELECT') return false;
  return el.closest('#sidebar') !== null;
}

// 외부 변경 감지 폴링 — AI 가 편집하면 브라우저 화면이 따라간다.
let pollBusy = false;
setInterval(() => {
  void (async () => {
    // 진행 중인 조작(붓질·사각형 프리뷰·팬)이나 입력칸의 미적용 편집을 덮어쓰지 않는다.
    if (pollBusy || !state.map || !state.fileName) return;
    if (painting || panDrag || state.rectStart || hasPendingInput()) return;
    pollBusy = true;
    try {
      const rev = await fetchRev(state.fileName);
      if (rev !== state.rev) {
        if (state.dirty) {
          $('hintSpan').textContent = '⚠ 파일이 외부에서 변경됨 — 저장 시 확인창이 뜹니다';
        } else {
          await reloadFromDisk();
        }
      }
    } catch {
      // 서버 재시작 등 일시 오류는 무시
    } finally {
      pollBusy = false;
    }
  })();
}, 2000);

function refreshMapInfo(): void {
  const map = state.map;
  if (!map) return;
  const evCount = map.events.filter(Boolean).length;
  $('mapInfo').textContent =
    `${state.fileName} · ${map.width}×${map.height} · tileset ${map.tilesetId ?? '-'} · 이벤트 ${evCount}`;
  ($('displayNameInput') as HTMLInputElement).value = String(map.displayName ?? '');
  ($('resizeW') as HTMLInputElement).value = String(map.width);
  ($('resizeH') as HTMLInputElement).value = String(map.height);
}

// ── 툴바 이벤트 배선 ────────────────────────────────────────────────

$('saveBtn').onclick = () => void doSave();
$('undoBtn').onclick = () => applyHistory('undo');
$('redoBtn').onclick = () => applyHistory('redo');
document.querySelectorAll<HTMLButtonElement>('.toolBtn').forEach((b) => {
  b.onclick = () => {
    state.tool = b.dataset.tool as Tool;
    refreshToolbar();
  };
});
$('zoomInBtn').onclick = () => setZoom(nextZoom(state.zoom));
$('zoomOutBtn').onclick = () => setZoom(prevZoom(state.zoom));

const bindChk = (id: string, get: () => boolean, set: (v: boolean) => void): void => {
  const el = $(id) as HTMLInputElement;
  el.checked = get();
  el.onchange = () => {
    set(el.checked);
    refreshToolbar();
    renderer.requestRender();
    updateHint();
  };
};
bindChk('gridChk', () => state.showGrid, (v) => (state.showGrid = v));
bindChk('passChk', () => state.showPassability, (v) => (state.showPassability = v));
bindChk('nightChk', () => state.night, (v) => (state.night = v));
bindChk('moonChk', () => state.moonlight, (v) => (state.moonlight = v));
bindChk('lightChk', () => state.lightPreview, (v) => (state.lightPreview = v));

const sightInput = $('sightRange') as HTMLInputElement;
sightInput.oninput = () => {
  state.sightRange = Number(sightInput.value);
  $('sightLabel').textContent = sightInput.value;
  renderer.requestRender();
};

($('displayNameInput') as HTMLInputElement).onchange = (e) => {
  const map = state.map;
  if (!map) return;
  map.displayName = (e.target as HTMLInputElement).value;
  state.dirty = true;
  refreshToolbar();
};

$('resizeBtn').onclick = () => {
  const map = state.map;
  if (!map) return;
  const w = Number(($('resizeW') as HTMLInputElement).value);
  const h = Number(($('resizeH') as HTMLInputElement).value);
  if (!Number.isInteger(w) || !Number.isInteger(h) || w < 1 || h < 1 || w > 256 || h > 256) {
    alert('크기는 1~256 사이 정수여야 합니다.');
    return;
  }
  if (w === map.width && h === map.height) return;
  if (!confirm(`맵 크기를 ${map.width}×${map.height} → ${w}×${h} 로 변경할까요?\n(잘리는 영역의 타일/이벤트 위치는 되돌리기 전까지만 복구 가능)`)) return;
  mutateWithSnapshot(() => resizeMap(map, w, h));
  refreshMapInfo();
};

($('mapSelect') as HTMLSelectElement).onchange = (e) => {
  const select = e.target as HTMLSelectElement;
  loadMapFile(select.value).catch((err) => {
    // 실패를 삼키면 셀렉트 표시와 실제 열린 맵이 어긋난 채로 남는다.
    alert(`맵을 열지 못했습니다: ${err}`);
    select.value = state.fileName;
  });
};

window.addEventListener('beforeunload', (e) => {
  if (state.dirty) e.preventDefault();
});

window.addEventListener('resize', () => renderer.resizeToContainer());

// ── 부트스트랩 ──────────────────────────────────────────────────────

async function boot(): Promise<void> {
  try {
    await tilesets.load();
    const res = await fetchMapList();
    const names = resolveMapNames(res.mapInfos);
    const select = $('mapSelect') as HTMLSelectElement;
    select.innerHTML = '';
    for (const m of res.maps) {
      const opt = document.createElement('option');
      opt.value = m.file;
      const alias = names.get(m.file);
      const extra = [alias, m.displayName].filter((s) => s && s.length > 0).join(' · ');
      opt.textContent = `${m.file}${extra ? ` (${extra})` : ''} — ${m.width}×${m.height}`;
      select.appendChild(opt);
    }
    renderer.resizeToContainer();

    // URL 파라미터로 초기 상태 지정: ?map=TOWN1.json&night=1&light=1
    const params = new URLSearchParams(location.search);
    if (params.get('night') === '1') {
      state.night = true;
      ($('nightChk') as HTMLInputElement).checked = true;
    }
    if (params.get('light') === '1') {
      state.lightPreview = true;
      ($('lightChk') as HTMLInputElement).checked = true;
    }
    // 우선순위: URL 파라미터 > 마지막으로 열었던 맵 > 목록 첫 맵
    let remembered: string | null = null;
    try {
      remembered = localStorage.getItem('hadar.lastMap');
    } catch {
      // localStorage 불가 환경은 무시
    }
    const exists = (f: string | null) => f !== null && res.maps.some((m) => m.file === f);
    const wanted = params.get('map');
    const initial = exists(wanted) ? wanted! : exists(remembered) ? remembered! : res.maps[0]?.file;
    if (initial) {
      select.value = initial;
      await loadMapFile(initial);
    } else {
      alert(`편집할 맵이 없습니다: ${res.assetsDir}/maps`);
    }
  } catch (e) {
    alert(`초기화 실패: ${e}`);
  }
}

void boot();
