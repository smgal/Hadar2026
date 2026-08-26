#!/usr/bin/env node
// Hadar 맵 에디터 MCP 서버 — dev 서버의 /api/ai/* 를 MCP 도구로 노출한다.
// 사용 전 에디터 dev 서버가 떠 있어야 한다: cd tools/mapEditor && pnpm dev
// 대상 URL 은 HADAR_EDITOR_URL 환경변수 (기본 http://localhost:5310).
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

const BASE = process.env.HADAR_EDITOR_URL ?? 'http://localhost:5310';

async function api(method, path, body) {
  let res;
  try {
    res = await fetch(BASE + path, {
      method,
      headers: body !== undefined ? { 'Content-Type': 'application/json' } : undefined,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    throw new Error(
      `에디터 서버(${BASE})에 연결 실패: ${e.message}. ` +
        'tools/mapEditor 에서 `pnpm dev` 로 서버를 먼저 띄우세요.',
    );
  }
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  return text;
}

async function apiPng(path) {
  let res;
  try {
    res = await fetch(BASE + path);
  } catch (e) {
    throw new Error(
      `에디터 서버(${BASE})에 연결 실패: ${e.message}. ` +
        'tools/mapEditor 에서 `pnpm dev` 로 서버를 먼저 띄우세요.',
    );
  }
  if (!res.ok) throw new Error(`GET ${path} → ${res.status}: ${await res.text()}`);
  return Buffer.from(await res.arrayBuffer()).toString('base64');
}

const server = new McpServer({ name: 'hadar-map-editor', version: '0.1.0' });

/** 텍스트 결과 도구 등록 헬퍼 (에러는 isError 텍스트로 반환). */
function tool(name, description, shape, fn) {
  server.registerTool(name, { description, inputSchema: shape }, async (args) => {
    try {
      const text = await fn(args);
      return { content: [{ type: 'text', text }] };
    } catch (e) {
      return { content: [{ type: 'text', text: String(e.message ?? e) }], isError: true };
    }
  });
}

const fileArg = z.string().describe('맵 파일 이름, 예: "TOWN1.json"');
const regionArgs = {
  x: z.number().int().optional().describe('영역 시작 x (기본 0)'),
  y: z.number().int().optional().describe('영역 시작 y (기본 0)'),
  w: z.number().int().optional().describe('영역 너비 (기본 맵 전체)'),
  h: z.number().int().optional().describe('영역 높이 (기본 맵 전체)'),
};

function regionQuery(args) {
  const q = new URLSearchParams();
  for (const k of ['x', 'y', 'w', 'h']) if (args[k] !== undefined) q.set(k, String(args[k]));
  return q;
}

tool(
  'get_guide',
  '맵 포맷·레이어 의미·타일 규칙·API 사용법 전체 가이드(markdown). 다른 도구를 쓰기 전에 반드시 한 번 읽을 것.',
  {},
  () => api('GET', '/api/ai/guide'),
);

tool('list_maps', '편집 가능한 맵 목록 (파일명, 크기, 표시 이름, 이벤트 수).', {}, () =>
  api('GET', '/api/ai/maps'),
);

tool(
  'current_map',
  '브라우저 에디터가 지금 열고 있는 맵 파일. 사용자가 "지금 맵"이라고 하면 먼저 이걸 호출할 것. (10초 내 브라우저 활동이 없으면 file:null → 사용자에게 확인)',
  {},
  () => api('GET', '/api/ai/current'),
);

tool(
  'create_map',
  '새 맵 생성 (RPG Maker MV 표준 필드 전부 포함). registerAs 를 주면 MapInfos.json 에 게임용 이름 등록.',
  {
    file: z.string().describe('새 파일 이름, 예: "Map020.json"'),
    width: z.number().int().min(1).max(256),
    height: z.number().int().min(1).max(256),
    displayName: z.string().optional().describe('게임에 표시되는 맵 이름'),
    groundA5: z.number().int().min(0).max(127).optional().describe('전체 지면을 채울 A5 인덱스 (기본 0)'),
    registerAs: z.string().optional().describe('MapInfos.json 에 등록할 논리 이름, 예: "CAVE1"'),
  },
  (args) => api('POST', '/api/ai/maps', args),
);

tool(
  'map_summary',
  '맵 요약: 크기, 표시 이름, 레이어별 값 히스토그램, 이벤트 전체 목록.',
  { file: fileArg },
  (args) => api('GET', `/api/ai/maps/${encodeURIComponent(args.file)}`),
);

tool(
  'read_region',
  '한 레이어의 타일 값을 2D 배열로 읽기 (행 우선, 최대 20000칸).',
  {
    file: fileArg,
    layer: z
      .string()
      .describe('ground | ground2 | objLower | objUpper | shadow | region (또는 z 0~5)'),
    ...regionArgs,
    as_a5: z.boolean().optional().describe('true 면 ground 값을 A5 인덱스로 변환해 반환'),
  },
  (args) => {
    const q = regionQuery(args);
    q.set('layer', args.layer);
    if (args.as_a5) q.set('as', 'a5');
    return api('GET', `/api/ai/maps/${encodeURIComponent(args.file)}/region?${q}`);
  },
);

tool(
  'edit_map',
  '배치 편집. ops 배열을 순서대로 적용하고 한 번 저장한다. op 종류: ' +
    'set(x,y) | rect(x,y,w,h) | fill(x,y) | setCells(x,y,rows) | resize(width,height) | setDisplayName(displayName). ' +
    '값 지정: value(원시) | a5(지면 인덱스) | b(B 타일 id). 여러 편집은 반드시 한 호출에 모을 것.',
  {
    file: fileArg,
    ops: z.array(z.record(z.any())).describe('예: [{"op":"rect","layer":"ground","x":0,"y":0,"w":10,"h":10,"a5":84}]'),
  },
  (args) => api('POST', `/api/ai/maps/${encodeURIComponent(args.file)}/edit`, { ops: args.ops }),
);

tool(
  'passability',
  '영역의 통행/액션 판정(MOVE/BLOCK/WATER/ENTER/TALK 등)을 2D 배열로 반환. 경로 연결 검증용.',
  { file: fileArg, ...regionArgs },
  (args) =>
    api('GET', `/api/ai/maps/${encodeURIComponent(args.file)}/passability?${regionQuery(args)}`),
);

tool(
  'validate_map',
  '맵 무결성 검사 (값 범위, 이벤트 위치/이름 규약, data 길이). 편집 후 호출 권장.',
  { file: fileArg },
  (args) => api('GET', `/api/ai/maps/${encodeURIComponent(args.file)}/validate`),
);

tool('list_events', '맵의 이벤트 목록 (시맨틱 뷰: type, dialogLines, hadarEvent 포함).', { file: fileArg }, (args) =>
  api('GET', `/api/ai/maps/${encodeURIComponent(args.file)}/events`),
);

const eventFields = {
  x: z.number().int().optional(),
  y: z.number().int().optional(),
  note: z.string().optional().describe('편집용 메모'),
  dialogLines: z.array(z.string()).optional().describe('대사 줄 (code 401)'),
  hadarEvent: z
    .union([z.null(), z.object({ kind: z.string(), payload: z.record(z.any()).optional() })])
    .optional()
    .describe('확장 이벤트: {"kind":"warp","payload":{"map":"TOWN1","x":10,"y":20}} 등. null 이면 제거'),
};

tool(
  'create_event',
  '이벤트 생성. type 만 주면 TALK001 식 자동 명명. 이름 접두사(TALK/SIGN/EVENT/ENTER/NPC)가 게임의 타입 판정.',
  {
    file: fileArg,
    type: z.enum(['TALK', 'SIGN', 'EVENT', 'ENTER', 'NPC']).optional(),
    name: z.string().optional().describe('직접 명명 시 (type 대신)'),
    ...eventFields,
  },
  (args) => {
    const { file, ...body } = args;
    return api('POST', `/api/ai/maps/${encodeURIComponent(file)}/events`, body);
  },
);

tool(
  'update_event',
  '이벤트 부분 수정 (name/note/x/y/dialogLines/hadarEvent).',
  { file: fileArg, id: z.number().int(), name: z.string().optional(), ...eventFields },
  (args) => {
    const { file, id, ...body } = args;
    return api('PATCH', `/api/ai/maps/${encodeURIComponent(file)}/events/${id}`, body);
  },
);

tool('delete_event', '이벤트 삭제.', { file: fileArg, id: z.number().int() }, (args) =>
  api('DELETE', `/api/ai/maps/${encodeURIComponent(args.file)}/events/${args.id}`),
);

server.registerTool(
  'preview',
  {
    description:
      '맵을 PNG 로 렌더링해서 반환 (게임 렌더러와 동일 합성). 편집 결과를 눈으로 확인할 때 사용. ' +
      '이벤트는 색 테두리로 표시(마젠타=TALK, 시안=SIGN, 초록=EVENT, 노랑=ENTER, 주황=NPC, 회색=이름 규약을 벗어난 이벤트).',
    inputSchema: {
      file: fileArg,
      ...regionArgs,
      tile: z.number().int().min(2).max(48).optional().describe('타일당 픽셀 (기본 16)'),
      night: z.boolean().optional().describe('야간 뷰'),
      moonlight: z.boolean().optional().describe('달빛 (기본 true, false 면 더 어두움)'),
      playerX: z.number().int().optional().describe('광원(플레이어) 위치 x — 야간 시야 미리보기'),
      playerY: z.number().int().optional(),
      sight: z.number().int().min(1).max(5).optional().describe('시야 반경 (기본 2)'),
      events: z.boolean().optional().describe('이벤트 테두리 표시 (기본 true)'),
    },
  },
  async (args) => {
    try {
      const q = regionQuery(args);
      if (args.tile !== undefined) q.set('tile', String(args.tile));
      if (args.night) q.set('night', '1');
      if (args.moonlight === false) q.set('moonlight', '0');
      if (args.playerX !== undefined) q.set('playerX', String(args.playerX));
      if (args.playerY !== undefined) q.set('playerY', String(args.playerY));
      if (args.sight !== undefined) q.set('sight', String(args.sight));
      if (args.events === false) q.set('events', '0');
      const data = await apiPng(`/api/ai/maps/${encodeURIComponent(args.file)}/preview.png?${q}`);
      return { content: [{ type: 'image', data, mimeType: 'image/png' }] };
    } catch (e) {
      return { content: [{ type: 'text', text: String(e.message ?? e) }], isError: true };
    }
  },
);

server.registerTool(
  'tile_image',
  {
    description: '타일 하나의 48×48 PNG. 팔레트에서 타일 생김새를 확인할 때 사용.',
    inputSchema: {
      a5: z.number().int().min(0).max(127).optional().describe('A5 지면 타일 인덱스'),
      b: z.number().int().min(1).max(255).optional().describe('B 오브젝트 타일 id'),
    },
  },
  async (args) => {
    try {
      const q = args.a5 !== undefined ? `a5=${args.a5}` : args.b !== undefined ? `b=${args.b}` : null;
      if (!q) return { content: [{ type: 'text', text: 'a5 또는 b 인자가 필요합니다.' }], isError: true };
      const data = await apiPng(`/api/ai/tile.png?${q}`);
      return { content: [{ type: 'image', data, mimeType: 'image/png' }] };
    } catch (e) {
      return { content: [{ type: 'text', text: String(e.message ?? e) }], isError: true };
    }
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
