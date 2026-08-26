// assets 디렉토리에 대한 파일 IO. 모든 저장은 MV 직렬화 규칙(serializeMv)을 거쳐
// RPG Maker MV 포맷을 그대로 유지한다.
import fs from 'node:fs';
import path from 'node:path';
import { normalizeData, serializeMv, type MvMap } from '../src/mvmap';

export interface Store {
  assetsDir: string;
  mapsDir: string;
  imagesDir: string;
}

export function createStore(assetsDir: string): Store {
  return {
    assetsDir,
    mapsDir: path.join(assetsDir, 'maps'),
    imagesDir: path.join(assetsDir, 'images'),
  };
}

export function safeJoin(dir: string, name: string): string | null {
  if (!name || name.includes('/') || name.includes('\\') || name.includes('..')) return null;
  const p = path.join(dir, name);
  if (!p.startsWith(dir + path.sep)) return null;
  return p;
}

export function mapPath(store: Store, file: string): string | null {
  if (!file.endsWith('.json')) return null;
  return safeJoin(store.mapsDir, file);
}

/** 파일 버전 — mtime(ms) 문자열. 충돌 감지에 쓴다. */
export function revOf(p: string): string {
  return String(fs.statSync(p).mtimeMs);
}

export interface LoadedMap {
  map: MvMap;
  rev: string;
  path: string;
}

export function readMapFile(store: Store, file: string): LoadedMap {
  const p = mapPath(store, file);
  if (!p) throw new StoreError(400, `잘못된 파일 이름: ${file}`, '파일 이름만 (경로 없이) .json 으로 지정');
  if (!fs.existsSync(p)) {
    throw new StoreError(404, `맵 파일 없음: ${file}`, 'GET /api/ai/maps 로 존재하는 파일 확인');
  }
  let map: MvMap;
  try {
    map = JSON.parse(fs.readFileSync(p, 'utf-8')) as MvMap;
  } catch (e) {
    // 디스크 파일 손상은 서버측 문제 — 요청 본문 파싱 실패(400)로 오보고하지 않는다.
    throw new StoreError(
      500,
      `맵 파일 JSON 손상: ${file} (${e instanceof Error ? e.message : String(e)})`,
      '파일을 직접 열어 고치거나 git 으로 되돌릴 것',
    );
  }
  if (typeof map.width !== 'number' || !Array.isArray(map.data)) {
    throw new StoreError(400, `맵 형식이 아님: ${file}`, 'width/data 필드가 있는 RPG Maker MV 맵 JSON 이어야 함');
  }
  if (!Array.isArray(map.events)) map.events = [];
  // 형태가 어긋난 이벤트 요소는 여기서 버리지 않는다 (MV 포맷 보존 원칙).
  // 대신 소비자(eventTypeOf 등)가 방어적으로 동작하고 /validate 가 문제로 보고한다.
  normalizeData(map);
  return { map, rev: revOf(p), path: p };
}

/** MV 직렬화로 저장하고 새 rev 를 반환. */
export function writeMapFile(store: Store, file: string, map: MvMap): string {
  const p = mapPath(store, file);
  if (!p) throw new StoreError(400, `잘못된 파일 이름: ${file}`);
  const tmp = p + '.tmp';
  fs.writeFileSync(tmp, serializeMv(map), 'utf-8');
  fs.renameSync(tmp, p);
  return revOf(p);
}

export interface MapListItem {
  file: string;
  width: number;
  height: number;
  displayName: string;
  eventCount: number;
  rev: string;
}

export function listMapFiles(store: Store): { maps: MapListItem[]; mapInfos: unknown[] } {
  const files = fs.existsSync(store.mapsDir)
    ? fs.readdirSync(store.mapsDir).filter((f) => f.endsWith('.json'))
    : [];
  const maps: MapListItem[] = [];
  let mapInfos: unknown[] = [];
  for (const f of files) {
    const p = path.join(store.mapsDir, f);
    let parsed: any;
    try {
      parsed = JSON.parse(fs.readFileSync(p, 'utf-8'));
    } catch {
      continue;
    }
    if (f === 'MapInfos.json') {
      if (Array.isArray(parsed)) mapInfos = parsed;
      continue;
    }
    if (parsed && typeof parsed.width === 'number' && Array.isArray(parsed.data)) {
      maps.push({
        file: f,
        width: parsed.width,
        height: parsed.height,
        displayName: parsed.displayName ?? '',
        eventCount: Array.isArray(parsed.events) ? parsed.events.filter(Boolean).length : 0,
        rev: revOf(p),
      });
    }
  }
  return { maps, mapInfos };
}

/** MapInfos.json — 항목당 한 줄 (MV 저장 형식 그대로). */
export function readMapInfos(store: Store): unknown[] {
  const p = path.join(store.mapsDir, 'MapInfos.json');
  if (!fs.existsSync(p)) return [null];
  try {
    return JSON.parse(fs.readFileSync(p, 'utf-8'));
  } catch (e) {
    throw new StoreError(
      500,
      `MapInfos.json JSON 손상 (${e instanceof Error ? e.message : String(e)})`,
      '파일을 직접 열어 고치거나 git 으로 되돌릴 것',
    );
  }
}

export function writeMapInfos(store: Store, infos: unknown[]): void {
  const p = path.join(store.mapsDir, 'MapInfos.json');
  const lines = infos.map((e) => (e === null ? 'null' : JSON.stringify(e)));
  const text = '[\n' + lines.join(',\n') + '\n]';
  const tmp = p + '.tmp';
  fs.writeFileSync(tmp, text, 'utf-8');
  fs.renameSync(tmp, p);
}

/**
 * 브라우저 에디터가 "지금 열고 있는 맵" 추적.
 * UI 는 열려 있는 동안 2초마다 /api/map/rev 를 폴링하므로, 마지막 폴링 파일이
 * 곧 현재 맵이다. AI 는 GET /api/ai/current 로 조회한다.
 */
export const uiCurrent: { file: string | null; at: number } = { file: null, at: 0 };

export function touchUiCurrent(file: string): void {
  uiCurrent.file = file;
  uiCurrent.at = Date.now();
}

export class StoreError extends Error {
  constructor(
    public status: number,
    message: string,
    public hint?: string,
  ) {
    super(message);
  }
}
