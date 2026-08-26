// RPG Maker MV 맵 JSON 모델.
//
// 이 툴은 MV 포맷의 어떤 필드도 버리지 않는다 — 파싱한 객체를 그대로 들고
// data / events / width / height / displayName 만 제자리에서 수정한 뒤,
// MV 에디터가 쓰는 것과 동일한 줄 구조로 재직렬화한다.
//
// data 배열의 레이어 해석은 hadar2026_app 의 HDMapLoader 와 동일:
//   z0: 지면 (A5 타일, 값 = 1536 + A5 인덱스)
//   z1: MV 레이어2 — 게임에서 미사용, 보존만
//   z2: ixObj0 — 오브젝트 하단 (B 타일 0..255)
//   z3: ixObj1 — 오브젝트 상단 (B 타일 0..255)
//   z4: shadow — 빛/그림자 사분면 비트 (0..15). 0=항상 밝음, 15=야간 암전
//   z5: region — 지역 ID (게임에서 ixEvent 로 읽음)

export interface MvEventPage {
  list?: { code: number; indent?: number; parameters?: unknown[] }[];
  [k: string]: unknown;
}

export interface HadarEvent {
  kind: string;
  payload: Record<string, unknown>;
}

export interface MvEvent {
  id: number;
  name: string;
  note: string;
  x: number;
  y: number;
  pages: MvEventPage[];
  hadarEvent?: HadarEvent;
  [k: string]: unknown;
}

export interface MvMap {
  width: number;
  height: number;
  data: number[];
  events: (MvEvent | null)[];
  tilesetId?: number;
  displayName?: string;
  [k: string]: unknown;
}

export const NUM_LAYERS = 6;

export type PaletteKind = 'a5' | 'b' | 'shadow' | 'region';

export interface LayerMeta {
  z: number;
  label: string;
  palette: PaletteKind;
  defaultVisible: boolean;
}

export const LAYER_META: LayerMeta[] = [
  { z: 0, label: 'L0 지면 (A5)', palette: 'a5', defaultVisible: true },
  { z: 1, label: 'L1 지면2 (게임 미사용)', palette: 'a5', defaultVisible: false },
  { z: 2, label: 'L2 오브젝트 하단 (B)', palette: 'b', defaultVisible: true },
  { z: 3, label: 'L3 오브젝트 상단 (B)', palette: 'b', defaultVisible: true },
  { z: 4, label: 'L4 빛/그림자', palette: 'shadow', defaultVisible: false },
  { z: 5, label: 'L5 지역 ID', palette: 'region', defaultVisible: false },
];

/** 이벤트 오버레이를 나타내는 의사(pseudo) 레이어 번호. */
export const EVENT_LAYER = 6;

export function getTile(map: MvMap, z: number, x: number, y: number): number {
  if (x < 0 || y < 0 || x >= map.width || y >= map.height) return 0;
  return map.data[z * map.width * map.height + y * map.width + x] ?? 0;
}

export function setTile(map: MvMap, z: number, x: number, y: number, v: number): void {
  if (x < 0 || y < 0 || x >= map.width || y >= map.height) return;
  map.data[z * map.width * map.height + y * map.width + x] = v;
}

/** data 길이를 w*h*6 으로 맞춘다 (짧으면 0 채움, 길면 그대로 둠). */
export function normalizeData(map: MvMap): void {
  const need = map.width * map.height * NUM_LAYERS;
  while (map.data.length < need) map.data.push(0);
}

/** 좌상단 기준으로 내용 보존 리사이즈. 새 data 배열을 반환하지 않고 map 을 직접 수정. */
export function resizeMap(map: MvMap, newW: number, newH: number): void {
  const next = new Array<number>(newW * newH * NUM_LAYERS).fill(0);
  for (let z = 0; z < NUM_LAYERS; z++) {
    for (let y = 0; y < Math.min(map.height, newH); y++) {
      for (let x = 0; x < Math.min(map.width, newW); x++) {
        next[z * newW * newH + y * newW + x] = getTile(map, z, x, y);
      }
    }
  }
  map.width = newW;
  map.height = newH;
  map.data = next;
  for (const ev of map.events) {
    if (!ev) continue;
    ev.x = Math.min(ev.x, newW - 1);
    ev.y = Math.min(ev.y, newH - 1);
  }
}

/**
 * RPG Maker MV 가 저장하는 것과 동일한 줄 구조로 직렬화:
 *   {
 *   "필드":값,...,        ← data/events 를 제외한 모든 필드 한 줄 (원본 키 순서 보존)
 *   "data":[...],
 *   "events":[
 *   null,
 *   {...},                ← 이벤트마다 한 줄
 *   ]
 *   }
 * 변경 없는 맵은 원본과 바이트 단위로 동일하게 재생성된다 (diff 최소화).
 */
export function serializeMv(map: MvMap): string {
  const head: string[] = [];
  for (const [k, v] of Object.entries(map)) {
    if (k === 'data' || k === 'events') continue;
    head.push(JSON.stringify(k) + ':' + JSON.stringify(v));
  }
  const eventLines = map.events.map((e) => (e === null ? 'null' : JSON.stringify(e)));
  const eventsBlock = eventLines.length > 0 ? '[\n' + eventLines.join(',\n') + '\n]' : '[\n]';
  return (
    '{\n' +
    head.join(',') +
    ',\n"data":' +
    JSON.stringify(map.data) +
    ',\n"events":' +
    eventsBlock +
    '\n}'
  );
}

/**
 * hadar2026_app 의 MapEvent._parseTypeString 포팅 — 이벤트 이름 접두사로 타입 결정.
 * 손상된 맵 파일의 이름 없는 이벤트도 크래시 없이 UNKNOWN 으로 떨어지게 한다.
 */
export function eventTypeOf(name: string): string {
  if (typeof name !== 'string') return 'UNKNOWN';
  if (name.startsWith('TALK')) return 'TALK';
  if (name.startsWith('ENTER')) return 'ENTER';
  if (name.startsWith('EVENT') || name.startsWith('EVT')) return 'EVENT';
  if (name.startsWith('NPC')) return 'NPC';
  if (name.startsWith('SIGN')) return 'SIGN';
  return 'UNKNOWN';
}

/** 첫 페이지 list 의 code=401 파라미터를 대사 줄로 추출 (게임과 동일한 규칙). */
export function dialogLinesOf(ev: MvEvent): string[] {
  const lines: string[] = [];
  const list = ev.pages?.[0]?.list ?? [];
  for (const item of list) {
    if (item.code === 401 && Array.isArray(item.parameters)) {
      for (const p of item.parameters) if (typeof p === 'string') lines.push(p);
    }
  }
  return lines;
}

/**
 * 대사 줄을 첫 페이지 list 에 다시 써넣는다.
 * 주의: list 전체를 표준형(101 + 401들 + 0)으로 재구성한다 — 이 프로젝트의 맵은
 * code 0/101/401 만 쓰므로 안전하지만, 다른 코드가 있던 이벤트라면 사라진다.
 */
export function setDialogLines(ev: MvEvent, lines: string[]): void {
  if (!ev.pages || ev.pages.length === 0) ev.pages = [newEventPage()];
  const page = ev.pages[0];
  if (lines.length === 0) {
    page.list = [{ code: 0, indent: 0, parameters: [] }];
    return;
  }
  page.list = [
    { code: 101, indent: 0, parameters: ['', 0, 1, 0] },
    ...lines.map((l) => ({ code: 401, indent: 0, parameters: [l] as unknown[] })),
    { code: 0, indent: 0, parameters: [] },
  ];
}

/**
 * 새 이벤트의 페이지 골격. MV 스키마의 모든 필드를 채우되, 값은 **이 프로젝트의 기존
 * 이벤트(Map002 계열)와 동일**하게 맞춘 것 — MV 에디터의 신규 이벤트 기본값
 * (directionFix:false, priorityType:0, trigger:0, walkAnime:true)과는 네 필드가 다르다.
 * 게임 런타임은 이 필드들을 읽지 않으므로 동작에는 영향이 없고, RPG Maker MV 에서도
 * 그대로 열린다.
 */
export function newEventPage(): MvEventPage {
  return {
    conditions: {
      actorId: 1,
      actorValid: false,
      itemId: 1,
      itemValid: false,
      selfSwitchCh: 'A',
      selfSwitchValid: false,
      switch1Id: 1,
      switch1Valid: false,
      switch2Id: 1,
      switch2Valid: false,
      variableId: 1,
      variableValid: false,
      variableValue: 0,
    },
    directionFix: true,
    image: { characterIndex: 0, characterName: '', direction: 2, pattern: 0, tileId: 0 },
    list: [{ code: 0, indent: 0, parameters: [] }],
    moveFrequency: 3,
    moveRoute: {
      list: [{ code: 0, parameters: [] }],
      repeat: true,
      skippable: false,
      wait: false,
    },
    moveSpeed: 3,
    moveType: 0,
    priorityType: 1,
    stepAnime: false,
    through: false,
    trigger: 1,
    walkAnime: false,
  };
}

export function newEvent(id: number, name: string, x: number, y: number): MvEvent {
  return { id, name, note: '', pages: [newEventPage()], x, y };
}

/** events 배열에서 비어 있는 id(=인덱스) 를 찾는다. MV 는 index === id 규약. */
export function nextEventId(map: MvMap): number {
  for (let i = 1; i < map.events.length; i++) {
    if (!map.events[i]) return i;
  }
  return Math.max(1, map.events.length);
}

/** 이벤트를 id 위치에 배치 (배열을 null 로 채워가며 확장). */
export function placeEvent(map: MvMap, ev: MvEvent): void {
  while (map.events.length <= ev.id) map.events.push(null);
  map.events[ev.id] = ev;
}

/**
 * 타일 인덱스(y*width+x) → 통행 판정에 쓰이는 이벤트 타입.
 *
 * 게임의 HDMapLoader 와 동일하게 **배열 순서대로 덮어쓴다**: 같은 칸에 이벤트가 여러 개면
 * 마지막 것이 이긴다. NPC/UNKNOWN 은 게임에서 eventType 비트가 0 이라 이벤트 계층을
 * 통과시키므로, 여기서도 앞선 항목을 지운다(추가가 아니라 삭제).
 */
export function eventActionGrid(map: MvMap): Map<number, string> {
  const grid = new Map<number, string>();
  for (const ev of map.events) {
    if (!ev) continue;
    if (typeof ev.x !== 'number' || typeof ev.y !== 'number') continue;
    if (ev.x < 0 || ev.y < 0 || ev.x >= map.width || ev.y >= map.height) continue;
    const key = ev.y * map.width + ev.x;
    const type = eventTypeOf(ev.name);
    if (type === 'EVENT' || type === 'TALK' || type === 'SIGN' || type === 'ENTER') {
      grid.set(key, type);
    } else {
      grid.delete(key); // NPC/UNKNOWN 이 앞선 이벤트의 타입을 소거 (게임과 동일)
    }
  }
  return grid;
}

/** 해당 칸의 이벤트. 여러 개면 게임과 같이 **마지막** 것을 반환한다. */
export function eventAt(map: MvMap, x: number, y: number): MvEvent | null {
  let found: MvEvent | null = null;
  for (const ev of map.events) {
    if (ev && ev.x === x && ev.y === y) found = ev;
  }
  return found;
}
