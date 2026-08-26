import type { MvMap } from './mvmap';

export interface MapListEntry {
  file: string;
  width: number;
  height: number;
  displayName: string;
  eventCount: number;
}

export interface MapInfoEntry {
  id: number;
  name: string;
  json?: string;
  cm2?: string;
  [k: string]: unknown;
}

export interface MapsResponse {
  assetsDir: string;
  maps: MapListEntry[];
  mapInfos: (MapInfoEntry | null)[];
}

export async function fetchMapList(): Promise<MapsResponse> {
  const res = await fetch('/api/maps');
  if (!res.ok) throw new Error(`목록 조회 실패: ${res.status}`);
  return res.json();
}

export async function fetchMap(file: string): Promise<{ map: MvMap; rev: string }> {
  const res = await fetch(`/api/map?file=${encodeURIComponent(file)}`);
  if (!res.ok) throw new Error(`맵 로드 실패(${file}): ${res.status}`);
  return { map: await res.json(), rev: res.headers.get('X-Map-Rev') ?? '' };
}

export async function fetchRev(file: string): Promise<string> {
  const res = await fetch(`/api/map/rev?file=${encodeURIComponent(file)}`);
  if (!res.ok) throw new Error(`rev 조회 실패(${file}): ${res.status}`);
  return (await res.json()).rev ?? '';
}

/** 저장 시점에 파일이 외부(AI API 등)에서 변경돼 있으면 던져진다. */
export class SaveConflictError extends Error {
  constructor(public currentRev: string) {
    super('파일이 외부에서 변경됨');
  }
}

/** 저장하고 새 rev 를 반환. rev 불일치면 SaveConflictError. */
export async function saveMap(
  file: string,
  body: string,
  rev: string,
  force = false,
): Promise<string> {
  const params = new URLSearchParams({ file });
  if (rev) params.set('rev', rev);
  if (force) params.set('force', '1');
  const res = await fetch(`/api/map?${params}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body,
  });
  if (res.status === 409) {
    const detail = await res.json().catch(() => ({ currentRev: '' }));
    throw new SaveConflictError(detail.currentRev ?? '');
  }
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`저장 실패(${file}): ${res.status} ${detail}`);
  }
  return (await res.json()).rev ?? '';
}

/**
 * MapInfos.json 의 이름 → 실제 json 파일 해석 (HDMapNavigation 과 동일 규칙):
 * json 필드가 있으면 그 파일, 없으면 Map{id:03d}.json.
 */
export function resolveMapNames(infos: (MapInfoEntry | null)[]): Map<string, string> {
  const fileToName = new Map<string, string>();
  for (const info of infos) {
    if (!info || typeof info.name !== 'string') continue;
    const file =
      typeof info.json === 'string' ? info.json : `Map${String(info.id).padStart(3, '0')}.json`;
    fileToName.set(file, info.name);
  }
  return fileToName;
}
