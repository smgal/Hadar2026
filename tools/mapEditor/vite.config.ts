import { defineConfig, type Plugin, type Connect } from 'vite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { handleAiApi } from './server/ai_api';
import { createStore, listMapFiles, mapPath, revOf, safeJoin, touchUiCurrent } from './server/store';
import { readBody, sendError, sendJson } from './server/util';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
// 대상 assets 디렉토리. 다른 위치를 편집하려면 HADAR_ASSETS 환경변수로 넘긴다.
const ASSETS_DIR = path.resolve(ROOT, process.env.HADAR_ASSETS ?? '../../hadar2026_app/assets');
const GUIDE_PATH = path.join(ROOT, 'AI_GUIDE.md');
const store = createStore(ASSETS_DIR);

function apiPlugin(): Plugin {
  const handler: Connect.NextHandleFunction = (req, res, next) => {
    void (async () => {
      const url = new URL(req.url ?? '/', 'http://localhost');
      const route = url.pathname;

      // 잘못된 퍼센트 시퀀스는 여기서 400 으로 끊는다. 그냥 흘려보내면 Vite 의
      // 정적 미들웨어가 decodeURI 에서 던져 500 + 에디터를 덮는 오류 오버레이가 뜬다.
      try {
        decodeURI(route);
      } catch {
        sendError(res, 400, `URL 인코딩이 잘못됨: ${route}`, '경로의 % 시퀀스를 확인할 것');
        return;
      }

      // AI 용 시맨틱 API (/api/ai/*)
      if (await handleAiApi(store, req, res, url, GUIDE_PATH)) return;

      // ── 이하 에디터 UI 용 저수준 API ──
      if (route === '/api/maps' && req.method === 'GET') {
        if (!fs.existsSync(store.mapsDir)) {
          sendError(res, 500, `maps 디렉토리를 찾을 수 없음: ${store.mapsDir}`);
          return;
        }
        const { maps, mapInfos } = listMapFiles(store);
        sendJson(res, 200, { assetsDir: ASSETS_DIR, aiApi: '/api/ai', maps, mapInfos });
        return;
      }

      if (route === '/api/map/rev' && req.method === 'GET') {
        const file = url.searchParams.get('file') ?? '';
        const p = mapPath(store, file);
        if (!p || !fs.existsSync(p)) {
          sendError(res, 404, `파일 없음: ${file}`);
          return;
        }
        touchUiCurrent(file); // UI 의 주기적 폴링 = "지금 열린 맵" 신호
        sendJson(res, 200, { rev: revOf(p) });
        return;
      }

      if (route === '/api/map') {
        const file = url.searchParams.get('file') ?? '';
        const p = mapPath(store, file);
        if (!p) {
          sendError(res, 400, `잘못된 파일 이름: ${file}`);
          return;
        }
        if (req.method === 'GET') {
          if (!fs.existsSync(p)) {
            sendError(res, 404, `파일 없음: ${file}`);
            return;
          }
          touchUiCurrent(file); // UI 가 맵을 여는 순간에도 현재 맵 갱신
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json; charset=utf-8');
          res.setHeader('X-Map-Rev', revOf(p));
          res.end(fs.readFileSync(p));
          return;
        }
        if (req.method === 'PUT') {
          const body = await readBody(req);
          try {
            JSON.parse(body); // 저장 전 JSON 유효성만 확인
          } catch (e) {
            sendError(res, 400, `유효하지 않은 JSON: ${e}`);
            return;
          }
          // 낙관적 잠금: 클라이언트가 로드했던 rev 와 다르면 409 (외부 수정 감지)
          const expected = url.searchParams.get('rev');
          const force = url.searchParams.get('force') === '1';
          if (expected && !force && fs.existsSync(p) && revOf(p) !== expected) {
            sendJson(res, 409, {
              error: '파일이 외부에서 변경됨 (AI API 또는 다른 편집기)',
              currentRev: revOf(p),
            });
            return;
          }
          const tmp = p + '.tmp';
          fs.writeFileSync(tmp, body, 'utf-8');
          fs.renameSync(tmp, p);
          sendJson(res, 200, { ok: true, bytes: Buffer.byteLength(body), rev: revOf(p) });
          return;
        }
      }

      if (route === '/api/image' && req.method === 'GET') {
        const file = url.searchParams.get('file') ?? '';
        const p = file.endsWith('.png') ? safeJoin(store.imagesDir, file) : null;
        if (!p || !fs.existsSync(p)) {
          sendError(res, 404, `이미지 없음: ${file}`);
          return;
        }
        res.statusCode = 200;
        res.setHeader('Content-Type', 'image/png');
        res.end(fs.readFileSync(p));
        return;
      }

      // /api/* 로 왔는데 위 분기 중 어디에도 안 걸렸으면 (지원 안 하는 메서드 등)
      // Vite 의 HTML 폴백으로 새지 않도록 여기서 API 형식으로 종결한다.
      if (route.startsWith('/api/')) {
        sendError(
          res,
          405,
          `지원하지 않는 메서드 또는 경로: ${req.method} ${route}`,
          'GET /api/ai 에서 사용 가능한 엔드포인트 확인',
        );
        return;
      }

      next();
    })().catch((e) => sendError(res, 500, String(e)));
  };

  return {
    name: 'hadar-fs-api',
    configureServer(server) {
      server.middlewares.use(handler);
    },
    configurePreviewServer(server) {
      server.middlewares.use(handler);
    },
  };
}

export default defineConfig({
  plugins: [apiPlugin()],
  server: { port: 5310 },
});
