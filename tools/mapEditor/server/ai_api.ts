// AI 도구(MCP·에이전트)용 시맨틱 REST API. 사람 UI 용 저수준 API(/api/map)와 달리
// 레이어 이름·타일 의미 단위로 동작하고, 모든 응답이 JSON(미리보기는 PNG)이다.
// 전체 사용법은 GET /api/ai (AI_GUIDE.md) 가 기술한다.
import fs from 'node:fs';
import path from 'node:path';
import type { IncomingMessage, ServerResponse } from 'node:http';
import {
  NUM_LAYERS,
  dialogLinesOf,
  eventActionGrid,
  eventTypeOf,
  getTile,
  newEvent,
  nextEventId,
  placeEvent,
  resizeMap,
  setDialogLines,
  setTile,
  type MvEvent,
  type MvMap,
} from '../src/mvmap';
import { A5_BASE, A5_COUNT, ACTION_NAMES, a5Index, objectAction, tileAction, unitAction } from '../src/rules';
import { renderPreview, renderTile } from './preview';
import {
  StoreError,
  listMapFiles,
  readMapFile,
  readMapInfos,
  uiCurrent,
  writeMapFile,
  writeMapInfos,
  type Store,
} from './store';
import { readJsonBody, sendError, sendJson } from './util';

// ── 레이어 이름 ↔ z 매핑 ────────────────────────────────────────────

const LAYER_NAMES: Record<string, number> = {
  ground: 0,
  ground2: 1,
  objLower: 2,
  objUpper: 3,
  shadow: 4,
  light: 4, // alias
  region: 5,
};

const LAYER_LIST = 'ground(0), ground2(1), objLower(2), objUpper(3), shadow|light(4), region(5)';

function parseLayer(v: string | null): number {
  // 빈 문자열은 "미지정"으로 취급 — Number('') === 0 이 조용히 ground 로 해석되는 것을 막는다.
  if (v === null || v.trim() === '') {
    throw new StoreError(400, 'layer 파라미터 필요', `사용 가능: ${LAYER_LIST}`);
  }
  // hasOwnProperty: 'toString' 같은 프로토타입 키가 in 연산자를 통과하는 것을 막는다.
  if (Object.prototype.hasOwnProperty.call(LAYER_NAMES, v)) return LAYER_NAMES[v];
  const z = Number(v);
  if (Number.isInteger(z) && z >= 0 && z < NUM_LAYERS) return z;
  throw new StoreError(400, `알 수 없는 layer: ${v}`, `사용 가능: ${LAYER_LIST}`);
}

/** op 의 layer 필드를 파싱. 문자열/숫자가 아니면 400. */
function opLayer(op: Record<string, unknown>): number {
  const raw = op.layer;
  if (typeof raw === 'string') return parseLayer(raw);
  if (typeof raw === 'number') return parseLayer(String(raw));
  throw new StoreError(400, `op 에 layer 없음: ${JSON.stringify(op)}`, `사용 가능: ${LAYER_LIST}`);
}

/**
 * op 의 정수 필드를 읽는다. 누락/비숫자면 400 —
 * NaN 이 좌표 경계검사(NaN 비교는 전부 false)를 통과해 "성공했지만 아무것도 안 쓰인"
 * 응답이 나가는 것을 막는다.
 */
function opInt(op: Record<string, unknown>, name: string): number {
  const v = Number(op[name]);
  if (!Number.isFinite(v)) {
    throw new StoreError(
      400,
      `op 의 ${name} 이 숫자가 아님: ${JSON.stringify(op[name])}`,
      `${String(op.op ?? 'op')} 에는 정수 ${name} 가 필요`,
    );
  }
  return Math.floor(v);
}

/**
 * 레이어별 원시값 범위 검증. 위반이면 400, 애매하면 warnings 에 남긴다.
 * set/rect/fill 과 setCells 가 같은 규칙을 쓰도록 한 곳에 모았다.
 */
function checkRawValue(z: number, v: number, warnings: string[]): number {
  if (!Number.isInteger(v)) throw new StoreError(400, `타일 값이 정수가 아님: ${v}`);
  if (z === 4 && (v < 0 || v > 15)) throw new StoreError(400, `shadow 값 범위 밖: ${v}`, '0~15 (사분면 비트)');
  if (z === 5 && (v < 0 || v > 255)) throw new StoreError(400, `region 값 범위 밖: ${v}`, '0~255');
  if ((z === 2 || z === 3) && (v < 0 || v > 255)) throw new StoreError(400, `오브젝트 값 범위 밖: ${v}`, '0~255');
  if (z <= 1 && v !== 0 && (v < A5_BASE || v >= A5_BASE + A5_COUNT)) {
    warnings.push(`지면 raw 값 ${v} 는 A5 범위(0 또는 1536~1663) 밖 — 게임 렌더가 예상과 다를 수 있음`);
  }
  return v;
}

/** 편집 op 의 값 지정({value} 원시값 / {a5} 지면 인덱스 / {b} B 타일 id)을 원시값으로 해석. */
function resolveValue(z: number, op: Record<string, unknown>, warnings: string[]): number {
  if (typeof op.a5 === 'number') {
    // a5 는 지면 전용. 다른 레이어에 쓰면 1536+a5 가 되어 그 레이어의 유효 범위를
    // 벗어나므로(같은 값을 value 로 주면 아래 checkRawValue 가 거부한다) 여기서도 거부한다.
    if (z > 1) {
      throw new StoreError(
        400,
        `a5 값은 ground/ground2 레이어 전용인데 z=${z} 에 사용됨`,
        z === 2 || z === 3 ? '오브젝트 레이어는 b 를 쓸 것' : 'shadow/region 레이어는 value 를 쓸 것',
      );
    }
    if (!Number.isInteger(op.a5) || op.a5 < 0 || op.a5 >= A5_COUNT) {
      throw new StoreError(400, `a5 인덱스 범위 밖: ${op.a5}`, '0~127 정수');
    }
    return A5_BASE + (op.a5 as number);
  }
  if (typeof op.b === 'number') {
    if (z !== 2 && z !== 3) warnings.push(`b 값은 objLower/objUpper 레이어용인데 z=${z} 에 사용됨`);
    if (!Number.isInteger(op.b) || op.b < 0 || op.b > 255) {
      throw new StoreError(400, `b 타일 id 범위 밖: ${op.b}`, '0~255 정수 (0=지우기)');
    }
    return checkRawValue(z, op.b as number, warnings);
  }
  if (typeof op.value === 'number') {
    return checkRawValue(z, op.value as number, warnings);
  }
  throw new StoreError(400, `op 에 값 지정 없음: ${JSON.stringify(op)}`, 'value | a5 | b 중 하나 필요');
}

// ── 이벤트 시맨틱 뷰 ────────────────────────────────────────────────

/** 손상된 맵의 형태 어긋난 요소도 500 없이 표현되도록 방어적으로 읽는다. */
function eventView(ev: MvEvent): Record<string, unknown> {
  const malformed =
    typeof ev !== 'object' || typeof ev.name !== 'string' || typeof ev.x !== 'number' || typeof ev.y !== 'number';
  return {
    id: ev?.id ?? null,
    name: ev?.name ?? '',
    type: eventTypeOf(ev?.name),
    note: ev?.note ?? '',
    x: ev?.x ?? null,
    y: ev?.y ?? null,
    dialogLines: malformed ? [] : dialogLinesOf(ev),
    hadarEvent: ev?.hadarEvent ?? null,
    ...(malformed ? { malformed: true } : {}),
  };
}

function applyEventFields(map: MvMap, ev: MvEvent, body: Record<string, unknown>): void {
  if (typeof body.name === 'string') ev.name = body.name;
  if (typeof body.note === 'string') ev.note = body.note;
  if (typeof body.x === 'number') {
    if (body.x < 0 || body.x >= map.width) throw new StoreError(400, `x 범위 밖: ${body.x}`, `0~${map.width - 1}`);
    ev.x = Math.floor(body.x as number);
  }
  if (typeof body.y === 'number') {
    if (body.y < 0 || body.y >= map.height) throw new StoreError(400, `y 범위 밖: ${body.y}`, `0~${map.height - 1}`);
    ev.y = Math.floor(body.y as number);
  }
  if (Array.isArray(body.dialogLines)) {
    const lines = (body.dialogLines as unknown[]).filter((l): l is string => typeof l === 'string');
    setDialogLines(ev, lines);
  }
  if ('hadarEvent' in body) {
    const he = body.hadarEvent;
    if (he === null) {
      delete ev.hadarEvent;
    } else if (typeof he === 'object' && typeof (he as any).kind === 'string') {
      ev.hadarEvent = {
        kind: (he as any).kind,
        payload: typeof (he as any).payload === 'object' && (he as any).payload !== null ? (he as any).payload : {},
      };
    } else {
      throw new StoreError(400, 'hadarEvent 는 null 또는 {kind, payload} 형태', '예: {"kind":"warp","payload":{"map":"TOWN1","x":10,"y":20}}');
    }
  }
}

// ── 요청 파라미터 헬퍼 ──────────────────────────────────────────────

function intParam(url: URL, name: string, def: number | null): number {
  const raw = url.searchParams.get(name);
  if (raw === null) {
    if (def === null) throw new StoreError(400, `${name} 파라미터 필요`);
    return def;
  }
  const v = Number(raw);
  if (!Number.isFinite(v)) throw new StoreError(400, `${name} 이 숫자가 아님: ${raw}`);
  return Math.floor(v);
}

/**
 * 요청 영역과 맵의 **교집합**을 반환. 시작점을 0 으로 밀면서 w/h 를 그대로 두면
 * 요청하지 않은 반대편 타일이 대상에 들어오므로, 잘려나간 만큼 폭에서 뺀다.
 * 교집합이 비면 w/h 가 0 이 되고, 호출부는 이를 "대상 없음"으로 처리한다.
 */
function clampRegion(map: MvMap, x: number, y: number, w: number, h: number) {
  if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(w) || !Number.isFinite(h)) {
    throw new StoreError(400, `영역 좌표/크기가 숫자가 아님 (x=${x}, y=${y}, w=${w}, h=${h})`);
  }
  const cx = Math.max(0, Math.min(map.width, x));
  const cy = Math.max(0, Math.min(map.height, y));
  const cw = Math.max(0, Math.min(map.width, x + w) - cx);
  const ch = Math.max(0, Math.min(map.height, y + h) - cy);
  return { x: cx, y: cy, w: cw, h: ch };
}

// ── 편집 ops ────────────────────────────────────────────────────────

interface OpResult {
  op: string;
  changed: number;
}

function applyOps(map: MvMap, ops: unknown[], warnings: string[]): OpResult[] {
  const results: OpResult[] = [];
  for (const raw of ops) {
    if (typeof raw !== 'object' || raw === null) throw new StoreError(400, `op 이 객체가 아님: ${JSON.stringify(raw)}`);
    const op = raw as Record<string, unknown>;
    const kind = String(op.op ?? '');
    let changed = 0;

    if (kind === 'set') {
      const z = opLayer(op);
      const v = resolveValue(z, op, warnings);
      const x = opInt(op, 'x');
      const y = opInt(op, 'y');
      if (x < 0 || y < 0 || x >= map.width || y >= map.height) {
        warnings.push(`set (${x},${y}) 는 맵 밖 — 무시됨`);
      } else if (getTile(map, z, x, y) !== v) {
        setTile(map, z, x, y, v);
        changed = 1;
      }
    } else if (kind === 'rect') {
      const z = opLayer(op);
      const v = resolveValue(z, op, warnings);
      const r = clampRegion(map, opInt(op, 'x'), opInt(op, 'y'), opInt(op, 'w'), opInt(op, 'h'));
      if (r.w === 0 || r.h === 0) {
        warnings.push(`rect (${op.x},${op.y} ${op.w}×${op.h}) 는 맵과 겹치지 않음 — 무시됨`);
      }
      for (let y = r.y; y < r.y + r.h; y++) {
        for (let x = r.x; x < r.x + r.w; x++) {
          if (getTile(map, z, x, y) !== v) {
            setTile(map, z, x, y, v);
            changed++;
          }
        }
      }
    } else if (kind === 'fill') {
      const z = opLayer(op);
      const v = resolveValue(z, op, warnings);
      const x = opInt(op, 'x');
      const y = opInt(op, 'y');
      if (x < 0 || y < 0 || x >= map.width || y >= map.height) {
        warnings.push(`fill (${x},${y}) 는 맵 밖 — 무시됨`);
      } else {
        const target = getTile(map, z, x, y);
        if (target !== v) {
          const stack = [[x, y]];
          const seen = new Set<number>([y * map.width + x]);
          while (stack.length > 0) {
            const [cx, cy] = stack.pop()!;
            setTile(map, z, cx, cy, v);
            changed++;
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
        }
      }
    } else if (kind === 'setCells') {
      const z = opLayer(op);
      const x0 = opInt(op, 'x');
      const y0 = opInt(op, 'y');
      const rows = op.rows;
      if (!Array.isArray(rows) || !rows.every((r) => Array.isArray(r))) {
        throw new StoreError(400, 'setCells 의 rows 는 2차원 숫자 배열', '예: "rows":[[15,15],[15,0]]');
      }
      const isA5 = op.as === 'a5';
      if (isA5 && z > 1) {
        throw new StoreError(
          400,
          `setCells 의 as:"a5" 는 ground/ground2 레이어 전용인데 z=${z} 에 사용됨`,
          '다른 레이어는 as 없이 원시값으로 줄 것',
        );
      }
      for (let ry = 0; ry < rows.length; ry++) {
        const row = rows[ry] as unknown[];
        for (let rx = 0; rx < row.length; rx++) {
          const cell = row[rx];
          if (typeof cell !== 'number') continue;
          const x = x0 + rx;
          const y = y0 + ry;
          if (x < 0 || y < 0 || x >= map.width || y >= map.height) continue;
          // set/rect/fill 과 동일한 레이어별 범위검증을 거친다.
          let v: number;
          if (isA5) {
            if (!Number.isInteger(cell) || cell < 0 || cell >= A5_COUNT) {
              throw new StoreError(400, `setCells a5 인덱스 범위 밖: ${cell} (${x},${y})`, '0~127 정수');
            }
            v = A5_BASE + cell;
          } else {
            v = checkRawValue(z, cell, warnings);
          }
          if (getTile(map, z, x, y) !== v) {
            setTile(map, z, x, y, v);
            changed++;
          }
        }
      }
    } else if (kind === 'resize') {
      const w = Math.floor(Number(op.width));
      const h = Math.floor(Number(op.height));
      if (!Number.isInteger(w) || !Number.isInteger(h) || w < 1 || h < 1 || w > 256 || h > 256) {
        throw new StoreError(400, `resize 크기 범위 밖: ${op.width}×${op.height}`, '1~256');
      }
      resizeMap(map, w, h);
      changed = 1;
    } else if (kind === 'setDisplayName') {
      map.displayName = String(op.displayName ?? '');
      changed = 1;
    } else {
      throw new StoreError(400, `알 수 없는 op: ${kind}`, 'set | rect | fill | setCells | resize | setDisplayName');
    }
    results.push({ op: kind, changed });
  }
  return results;
}

// ── 검증 ────────────────────────────────────────────────────────────

interface Issue {
  severity: 'error' | 'warning' | 'info';
  message: string;
}

function validateMap(map: MvMap): Issue[] {
  const issues: Issue[] = [];
  const size = map.width * map.height;
  if (map.data.length !== size * NUM_LAYERS) {
    issues.push({
      severity: map.data.length < size * NUM_LAYERS ? 'error' : 'warning',
      message: `data 길이 ${map.data.length} ≠ width*height*6 (${size * NUM_LAYERS})`,
    });
  }
  const badCells: Record<string, number> = {};
  for (let y = 0; y < map.height; y++) {
    for (let x = 0; x < map.width; x++) {
      const g = getTile(map, 0, x, y);
      if (g !== 0 && (g < A5_BASE || g >= A5_BASE + A5_COUNT)) badCells.ground = (badCells.ground ?? 0) + 1;
      for (const z of [2, 3]) {
        const v = getTile(map, z, x, y);
        if (v < 0 || v > 255) badCells[`obj${z}`] = (badCells[`obj${z}`] ?? 0) + 1;
        else if (v >= 240) badCells[`obj${z}_shadowSprite`] = (badCells[`obj${z}_shadowSprite`] ?? 0) + 1;
      }
      const s = getTile(map, 4, x, y);
      if (s < 0 || s > 15) badCells.shadow = (badCells.shadow ?? 0) + 1;
      const r = getTile(map, 5, x, y);
      if (r < 0 || r > 255) badCells.region = (badCells.region ?? 0) + 1;
    }
  }
  if (badCells.ground) issues.push({ severity: 'warning', message: `ground 에 A5 범위(0, 1536~1663) 밖 값 ${badCells.ground}개` });
  if (badCells.obj2) issues.push({ severity: 'error', message: `objLower 에 0~255 밖 값 ${badCells.obj2}개` });
  if (badCells.obj3) issues.push({ severity: 'error', message: `objUpper 에 0~255 밖 값 ${badCells.obj3}개` });
  if (badCells.obj2_shadowSprite || badCells.obj3_shadowSprite) {
    issues.push({
      severity: 'warning',
      message: `오브젝트 레이어에 야간 그림자 예약 스프라이트(240~255)가 ${(badCells.obj2_shadowSprite ?? 0) + (badCells.obj3_shadowSprite ?? 0)}개 배치됨`,
    });
  }
  if (badCells.shadow) issues.push({ severity: 'error', message: `shadow 에 0~15 밖 값 ${badCells.shadow}개` });
  if (badCells.region) issues.push({ severity: 'error', message: `region 에 0~255 밖 값 ${badCells.region}개` });

  const posSeen = new Map<number, string>();
  for (let i = 0; i < map.events.length; i++) {
    const ev = map.events[i];
    if (!ev) continue;
    // 형태가 어긋난 요소는 버리지 않고 문제로 보고한다 (읽기는 store 가 보존).
    if (typeof ev !== 'object' || Array.isArray(ev) || typeof ev.name !== 'string' || typeof ev.x !== 'number' || typeof ev.y !== 'number') {
      issues.push({
        severity: 'error',
        message: `events[${i}] 가 MV 이벤트 형태가 아님 (name/x/y 필요): ${JSON.stringify(ev).slice(0, 80)}`,
      });
      continue;
    }
    if (ev.id !== i) issues.push({ severity: 'error', message: `이벤트 "${ev.name}" 의 id(${ev.id})가 배열 인덱스(${i})와 다름 — MV 규약 위반` });
    if (ev.x < 0 || ev.y < 0 || ev.x >= map.width || ev.y >= map.height) {
      issues.push({ severity: 'error', message: `이벤트 "${ev.name}" (${ev.x},${ev.y}) 가 맵 밖` });
    }
    if (eventTypeOf(ev.name) === 'UNKNOWN') {
      issues.push({ severity: 'info', message: `이벤트 "${ev.name}" 의 이름 접두사가 TALK/SIGN/EVENT/ENTER/NPC 가 아님 — 게임이 타입을 인식 못함` });
    }
    const key = ev.y * map.width + ev.x;
    if (posSeen.has(key)) {
      issues.push({ severity: 'warning', message: `이벤트 "${ev.name}" 가 "${posSeen.get(key)}" 와 같은 타일 (${ev.x},${ev.y}) 에 있음` });
    } else {
      posSeen.set(key, ev.name);
    }
  }
  return issues;
}

// ── 새 맵 생성 ──────────────────────────────────────────────────────

function newMvMap(width: number, height: number, displayName: string, groundA5: number): MvMap {
  // 필드 구성/순서는 기존 맵(RPG Maker MV 저장본)과 동일하게 맞춘다.
  const map: MvMap = {
    autoplayBgm: false,
    autoplayBgs: false,
    battleback1Name: '',
    battleback2Name: '',
    bgm: { name: '', pan: 0, pitch: 100, volume: 90 },
    bgs: { name: '', pan: 0, pitch: 100, volume: 90 },
    disableDashing: false,
    displayName,
    encounterList: [],
    encounterStep: 30,
    height,
    note: '',
    parallaxLoopX: false,
    parallaxLoopY: false,
    parallaxName: '',
    parallaxShow: true,
    parallaxSx: 0,
    parallaxSy: 0,
    scrollType: 0,
    specifyBattleback: false,
    tilesetId: 7,
    width,
    data: new Array(width * height * NUM_LAYERS).fill(0),
    events: [null],
  } as unknown as MvMap;
  const size = width * height;
  for (let i = 0; i < size; i++) map.data[i] = A5_BASE + groundA5;
  return map;
}

// ── 팔레트 카탈로그 ─────────────────────────────────────────────────

function paletteCatalog(): unknown {
  const a5 = [];
  for (let i = 0; i < A5_COUNT; i++) {
    a5.push({ a5: i, rawValue: A5_BASE + i, action: ACTION_NAMES[tileAction(i)] });
  }
  const b = [];
  for (let i = 1; i < 256; i++) {
    b.push({
      b: i,
      action: ACTION_NAMES[objectAction(i)],
      reserved: i >= 240 ? 'night-shadow-overlay' : undefined,
    });
  }
  return {
    note: '개별 타일의 생김새는 GET /api/ai/tile.png?a5=N 또는 ?b=N 으로 확인. 시트 전체는 /api/image?file=Lore_A5.png / Lore_B.png',
    a5,
    b,
  };
}

// ── 라우터 ──────────────────────────────────────────────────────────

/** /api/ai/* 요청 처리. 처리했으면 true. */
export async function handleAiApi(
  store: Store,
  req: IncomingMessage,
  res: ServerResponse,
  url: URL,
  guidePath: string,
): Promise<boolean> {
  // prefix 판정을 먼저 — decodeURIComponent 를 여기서 돌리면 잘못된 퍼센트 시퀀스가 든
  // 무관한 요청(정적 리소스 등)까지 URIError 로 500 이 된다.
  if (!url.pathname.startsWith('/api/ai/') && url.pathname !== '/api/ai') return false;
  const method = req.method ?? 'GET';

  let rest: string[];
  try {
    rest = url.pathname.split('/').filter(Boolean).map(decodeURIComponent).slice(2);
  } catch {
    sendError(res, 400, `URL 인코딩이 잘못됨: ${url.pathname}`, '경로의 % 시퀀스를 확인할 것');
    return true;
  }

  try {
    // GET /api/ai — 사용 가이드 (markdown)
    if (rest.length === 0 || (rest.length === 1 && rest[0] === 'guide')) {
      res.statusCode = 200;
      res.setHeader('Content-Type', 'text/markdown; charset=utf-8');
      res.end(fs.readFileSync(guidePath, 'utf-8'));
      return true;
    }

    // GET /api/ai/current — 브라우저 에디터가 지금 열고 있는 맵
    if (rest[0] === 'current' && method === 'GET') {
      const ageMs = uiCurrent.file ? Date.now() - uiCurrent.at : null;
      const active = ageMs !== null && ageMs < 10_000; // UI 는 2초마다 폴링
      sendJson(res, 200, {
        file: active ? uiCurrent.file : null,
        lastSeenFile: uiCurrent.file,
        ageSeconds: ageMs !== null ? Math.round(ageMs / 1000) : null,
        hint: active
          ? '브라우저 에디터가 이 맵을 열어 두고 있음 — "지금 맵" 요청은 이 파일을 대상으로 할 것'
          : '최근 10초 내 브라우저 에디터 활동 없음 — 대상 맵을 사용자에게 확인할 것',
      });
      return true;
    }

    if (rest[0] === 'palette' && method === 'GET') {
      sendJson(res, 200, paletteCatalog());
      return true;
    }

    if (rest[0] === 'tile.png' && method === 'GET') {
      const a5 = url.searchParams.get('a5');
      const b = url.searchParams.get('b');
      if (a5 !== null && b !== null) {
        throw new StoreError(400, 'a5 와 b 를 동시에 지정할 수 없음', '한 번에 하나만 — a5= 또는 b=');
      }
      // 정수 검사: NaN 은 a5Rect/bRect 의 범위 비교를 전부 통과해 검은 PNG 가 나가므로 여기서 막는다.
      const raw = a5 ?? b;
      if (raw === null) throw new StoreError(400, 'a5= 또는 b= 파라미터 필요');
      const id = Number(raw);
      if (!Number.isInteger(id)) {
        throw new StoreError(400, `타일 id 가 정수가 아님: ${raw}`, a5 !== null ? 'a5 는 0~127' : 'b 는 1~255');
      }
      const buf = a5 !== null ? renderTile(store, 'a5', id) : renderTile(store, 'b', id);
      res.statusCode = 200;
      res.setHeader('Content-Type', 'image/png');
      res.end(buf);
      return true;
    }

    if (rest[0] !== 'maps') {
      throw new StoreError(404, `알 수 없는 경로: /api/ai/${rest.join('/')}`, 'GET /api/ai 에서 전체 API 목록 확인');
    }

    // /api/ai/maps
    if (rest.length === 1) {
      if (method === 'GET') {
        const { maps } = listMapFiles(store);
        sendJson(res, 200, { maps });
        return true;
      }
      if (method === 'POST') {
        const body = (await readJsonBody(req)) as Record<string, unknown>;
        const file = String(body.file ?? '');
        // '..' 는 여기서도 거부 — 통과시키면 뒤의 writeMapFile(safeJoin)에서
        // 파일을 만든 뒤 혼란스러운 400 이 난다.
        if (!/^[A-Za-z0-9_.\-가-힣]+\.json$/.test(file) || file.includes('..')) {
          throw new StoreError(400, `잘못된 파일 이름: ${file}`, '예: "Map020.json" (경로 없이, ".." 불가, .json 필수)');
        }
        const p = path.join(store.mapsDir, file);
        if (fs.existsSync(p)) throw new StoreError(409, `이미 존재하는 파일: ${file}`, '기존 맵 수정은 POST /api/ai/maps/{file}/edit');
        const width = Math.floor(Number(body.width));
        const height = Math.floor(Number(body.height));
        if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 || width > 256 || height > 256) {
          throw new StoreError(400, `width/height 범위 밖: ${body.width}×${body.height}`, '1~256');
        }
        const groundA5 = typeof body.groundA5 === 'number' ? body.groundA5 : 0;
        if (groundA5 < 0 || groundA5 >= A5_COUNT) throw new StoreError(400, `groundA5 범위 밖: ${groundA5}`, '0~127');
        const map = newMvMap(width, height, String(body.displayName ?? ''), groundA5);
        const rev = writeMapFile(store, file, map);

        let registered: unknown = null;
        if (typeof body.registerAs === 'string' && body.registerAs.length > 0) {
          const infos = readMapInfos(store) as (Record<string, unknown> | null)[];
          if (infos.some((e) => e && e.name === body.registerAs)) {
            throw new StoreError(409, `MapInfos 에 이미 있는 이름: ${body.registerAs}`, '맵 파일은 생성됨 — registerAs 없이 재시도하거나 다른 이름 사용');
          }
          let maxId = 0;
          let maxOrder = 0;
          for (const e of infos) {
            if (!e) continue;
            maxId = Math.max(maxId, Number(e.id) || 0);
            maxOrder = Math.max(maxOrder, Number(e.order) || 0);
          }
          const entry = {
            id: maxId + 1,
            expanded: false,
            name: body.registerAs,
            order: maxOrder + 1,
            parentId: 0,
            scrollX: 0,
            scrollY: 0,
            json: file,
          };
          infos.push(entry);
          writeMapInfos(store, infos);
          registered = entry;
        }
        sendJson(res, 201, { ok: true, file, rev, registered });
        return true;
      }
    }

    const file = rest[1];
    const sub = rest[2];

    // GET /api/ai/maps/{file} — 요약
    if (rest.length === 2 && method === 'GET') {
      const { map, rev } = readMapFile(store, file);
      const layers: Record<string, unknown> = {};
      for (const [name, z] of Object.entries(LAYER_NAMES)) {
        if (name === 'light') continue;
        const counts = new Map<number, number>();
        const size = map.width * map.height;
        for (let i = 0; i < size; i++) {
          const v = map.data[z * size + i] ?? 0;
          counts.set(v, (counts.get(v) ?? 0) + 1);
        }
        const top = [...counts.entries()]
          .sort((a, b) => b[1] - a[1])
          .slice(0, 10)
          .map(([value, count]) => (z <= 1 && value >= A5_BASE ? { value, a5: a5Index(value), count } : { value, count }));
        layers[name] = { distinctValues: counts.size, nonZero: size - (counts.get(0) ?? 0), top };
      }
      sendJson(res, 200, {
        file,
        rev,
        width: map.width,
        height: map.height,
        displayName: map.displayName ?? '',
        tilesetId: map.tilesetId ?? null,
        layers,
        events: map.events.filter(Boolean).map((ev) => eventView(ev!)),
      });
      return true;
    }

    // GET /api/ai/maps/{file}/region
    if (sub === 'region' && method === 'GET') {
      const { map, rev } = readMapFile(store, file);
      const z = parseLayer(url.searchParams.get('layer'));
      const r = clampRegion(
        map,
        intParam(url, 'x', 0),
        intParam(url, 'y', 0),
        intParam(url, 'w', map.width),
        intParam(url, 'h', map.height),
      );
      if (r.w * r.h > 20000) {
        throw new StoreError(400, `영역이 너무 큼 (${r.w}×${r.h}=${r.w * r.h}칸)`, '한 번에 20000칸 이하로 나눠 조회');
      }
      const asA5 = url.searchParams.get('as') === 'a5' && z <= 1;
      const rows: number[][] = [];
      for (let y = r.y; y < r.y + r.h; y++) {
        const row: number[] = [];
        for (let x = r.x; x < r.x + r.w; x++) {
          const v = getTile(map, z, x, y);
          row.push(asA5 ? a5Index(v) : v);
        }
        rows.push(row);
      }
      sendJson(res, 200, { file, rev, layer: z, encoding: asA5 ? 'a5' : 'raw', ...r, rows });
      return true;
    }

    // POST /api/ai/maps/{file}/edit — 배치 편집
    if (sub === 'edit' && method === 'POST') {
      const { map } = readMapFile(store, file);
      const body = (await readJsonBody(req)) as Record<string, unknown>;
      if (!Array.isArray(body.ops) || body.ops.length === 0) {
        throw new StoreError(400, 'ops 배열 필요', '예: {"ops":[{"op":"rect","layer":"ground","x":0,"y":0,"w":5,"h":5,"a5":84}]}');
      }
      const warnings: string[] = [];
      const results = applyOps(map, body.ops, warnings);
      const rev = writeMapFile(store, file, map);
      sendJson(res, 200, {
        ok: true,
        file,
        rev,
        results,
        totalChanged: results.reduce((s, r) => s + r.changed, 0),
        warnings,
      });
      return true;
    }

    // /api/ai/maps/{file}/events[...]
    if (sub === 'events') {
      const { map } = readMapFile(store, file);
      if (rest.length === 3 && method === 'GET') {
        sendJson(res, 200, { file, events: map.events.filter(Boolean).map((ev) => eventView(ev!)) });
        return true;
      }
      if (rest.length === 3 && method === 'POST') {
        const body = (await readJsonBody(req)) as Record<string, unknown>;
        const typePrefix = typeof body.type === 'string' ? body.type : null;
        let name = typeof body.name === 'string' ? body.name : null;
        if (!name) {
          if (!typePrefix || !['TALK', 'SIGN', 'EVENT', 'ENTER', 'NPC'].includes(typePrefix)) {
            throw new StoreError(400, 'name 또는 type(TALK|SIGN|EVENT|ENTER|NPC) 필요', 'type 만 주면 TALK001 식으로 자동 명명');
          }
          let maxNum = 0;
          for (const e of map.events) {
            if (!e || !e.name.startsWith(typePrefix)) continue;
            const n = parseInt(e.name.slice(typePrefix.length), 10);
            if (!Number.isNaN(n)) maxNum = Math.max(maxNum, n);
          }
          name = `${typePrefix}${String(maxNum + 1).padStart(3, '0')}`;
        }
        const id = nextEventId(map);
        const ev = newEvent(id, name, 0, 0);
        placeEvent(map, ev);
        applyEventFields(map, ev, body);
        const rev = writeMapFile(store, file, map);
        sendJson(res, 201, { ok: true, file, rev, event: eventView(ev) });
        return true;
      }
      if (rest.length === 4) {
        const id = Number(rest[3]);
        const ev = map.events[id];
        if (!ev) throw new StoreError(404, `이벤트 id ${id} 없음`, `존재하는 id: ${map.events.filter(Boolean).map((e) => e!.id).join(', ') || '(없음)'}`);
        if (method === 'GET') {
          sendJson(res, 200, eventView(ev));
          return true;
        }
        if (method === 'PATCH') {
          const body = (await readJsonBody(req)) as Record<string, unknown>;
          applyEventFields(map, ev, body);
          const rev = writeMapFile(store, file, map);
          sendJson(res, 200, { ok: true, file, rev, event: eventView(ev) });
          return true;
        }
        if (method === 'DELETE') {
          map.events[id] = null;
          const rev = writeMapFile(store, file, map);
          sendJson(res, 200, { ok: true, file, rev, deleted: id });
          return true;
        }
      }
    }

    // GET /api/ai/maps/{file}/passability
    if (sub === 'passability' && method === 'GET') {
      const { map, rev } = readMapFile(store, file);
      const r = clampRegion(
        map,
        intParam(url, 'x', 0),
        intParam(url, 'y', 0),
        intParam(url, 'w', map.width),
        intParam(url, 'h', map.height),
      );
      if (r.w * r.h > 20000) throw new StoreError(400, `영역이 너무 큼 (${r.w}×${r.h}칸)`, '20000칸 이하로 나눠 조회');
      const evType = eventActionGrid(map);
      const rows: string[][] = [];
      for (let y = r.y; y < r.y + r.h; y++) {
        const row: string[] = [];
        for (let x = r.x; x < r.x + r.w; x++) {
          row.push(
            ACTION_NAMES[
              unitAction(getTile(map, 0, x, y), getTile(map, 3, x, y), evType.get(y * map.width + x) ?? null)
            ],
          );
        }
        rows.push(row);
      }
      sendJson(res, 200, { file, rev, ...r, rows, legend: 'MOVE=통행 가능, BLOCK=벽, WATER/SWAMP/LAVA=지형 효과, ENTER/SIGN/TALK/EVENT=상호작용' });
      return true;
    }

    // GET /api/ai/maps/{file}/validate
    if (sub === 'validate' && method === 'GET') {
      const { map, rev } = readMapFile(store, file);
      const issues = validateMap(map);
      sendJson(res, 200, { file, rev, ok: !issues.some((i) => i.severity === 'error'), issues });
      return true;
    }

    // GET /api/ai/maps/{file}/preview.png
    if (sub === 'preview.png' && method === 'GET') {
      const { map } = readMapFile(store, file);
      const r = clampRegion(
        map,
        intParam(url, 'x', 0),
        intParam(url, 'y', 0),
        intParam(url, 'w', map.width),
        intParam(url, 'h', map.height),
      );
      if (r.w === 0 || r.h === 0) {
        throw new StoreError(
          400,
          `요청 영역이 맵과 겹치지 않음 (맵 ${map.width}×${map.height})`,
          'x/y/w/h 가 맵 범위 안에 오도록 조정할 것',
        );
      }
      const tilePx = Math.max(2, Math.min(48, intParam(url, 'tile', 16)));
      const px = url.searchParams.get('playerX');
      const py = url.searchParams.get('playerY');
      const buf = renderPreview(store, map, {
        ...r,
        tilePx,
        night: url.searchParams.get('night') === '1',
        moonlight: url.searchParams.get('moonlight') !== '0',
        playerX: px !== null ? Number(px) : null,
        playerY: py !== null ? Number(py) : null,
        sight: Math.max(1, Math.min(5, intParam(url, 'sight', 2))),
        events: url.searchParams.get('events') !== '0',
      });
      res.statusCode = 200;
      res.setHeader('Content-Type', 'image/png');
      res.end(buf);
      return true;
    }

    throw new StoreError(
      404,
      `알 수 없는 경로 또는 메서드: ${method} /api/ai/${rest.join('/')}`,
      'GET /api/ai 에서 전체 API 목록 확인',
    );
  } catch (e) {
    if (e instanceof StoreError) {
      sendError(res, e.status, e.message, e.hint);
    } else if (e instanceof SyntaxError) {
      sendError(res, 400, `요청 본문 JSON 파싱 실패: ${e.message}`);
    } else {
      sendError(res, 500, String(e));
    }
    return true;
  }
}
