# API 매뉴얼

이 도구의 HTTP API는 **[OpenAPI 3.0.3](https://spec.openapis.org/oas/v3.0.3) 표준 문서**로 정의돼 있다: [openapi.yaml](openapi.yaml). 이 문서는 그 스펙을 어떻게 보고, 검증하고, 코드로 뽑아 쓰는지 안내하는 짧은 진입점이다.

> **AI 에이전트라면**: 이 스펙은 "무엇을 호출할 수 있는가(계약)"만 정의한다. 레이어가 뭘 의미하는지, 어떤 A5 인덱스가 물인지, 빛 값을 어떻게 칠해야 하는지 같은 **도메인 지식**은 스펙에 없다 — 대신 서버가 직접 제공하는 `GET /api/ai`([AI_GUIDE.md](AI_GUIDE.md))를 반드시 먼저 읽을 것. 이 매뉴얼과 openapi.yaml은 "형식"을, AI_GUIDE.md는 "의미"를 담당한다.

## 스펙 보기

### 1) Redoc으로 정적 HTML 렌더링

```bash
npx @redocly/cli build-docs openapi.yaml -o api-docs.html
open api-docs.html   # 또는 브라우저로 직접 열기
```

모든 엔드포인트·스키마·요청 예제가 사람이 읽기 좋은 문서로 나온다. 서버 실행이 필요 없는 정적 파일이라 `pnpm dev`로 뜬 실제 API 서버와는 별개로 아무 때나 열어볼 수 있다.

### 2) VS Code 등 IDE 확장

"OpenAPI (Swagger) Editor" 류 확장에 `openapi.yaml`을 열면 인라인 미리보기와 자동완성을 지원한다.

### 3) 유효성 검증

스펙 자체를 수정한 뒤엔 반드시 lint를 통과시킬 것:

```bash
npx @redocly/cli lint openapi.yaml
```

이 저장소의 `openapi.yaml`은 lint 0 에러 상태로 관리한다(경고 몇 개는 의도된 것 — 로컬 전용 서버라 `localhost` URL 경고, 사내 도구라 라이선스 필드 없음 경고, 그리고 실제로 4xx를 반환하지 않는 순수 조회 엔드포인트 몇 개의 경고. 전부 `openapi.yaml` 안에 주석으로 이유를 남겨뒀다).

### 4) Postman / Insomnia로 가져오기

두 도구 모두 "Import → File"에서 `openapi.yaml`을 직접 읽을 수 있다. 임포트하면 모든 엔드포인트가 요청 컬렉션으로 생성된다.

### 5) 타입 생성 (TypeScript 클라이언트를 직접 짜는 경우)

```bash
npx openapi-typescript openapi.yaml -o src/api-types.d.ts
```

## 빠른 시작 (curl)

```bash
# 1. dev 서버 실행 (별도 터미널)
cd tools/mapEditor && pnpm dev

# 2. 도메인 가이드부터 읽기 (필수)
curl -s http://localhost:5310/api/ai | less

# 3. 지금 브라우저가 열어둔 맵 확인
curl -s http://localhost:5310/api/ai/current

# 4. 맵 요약
curl -s http://localhost:5310/api/ai/maps/TOWN1.json | jq .

# 5. 배치 편집 (예: 5×5 지면을 A5 #84로)
curl -s -X POST http://localhost:5310/api/ai/maps/TOWN1.json/edit \
  -H 'Content-Type: application/json' \
  -d '{"ops":[{"op":"rect","layer":"ground","x":10,"y":10,"w":5,"h":5,"a5":84}]}'

# 6. 결과 확인 (PNG)
curl -s "http://localhost:5310/api/ai/maps/TOWN1.json/preview.png?x=5&y=5&w=15&h=15&tile=24" -o preview.png
```

## API 표면 두 가지

`openapi.yaml`은 태그로 구분된 두 그룹을 모두 문서화한다:

| 태그 | 베이스 경로 | 대상 | 특징 |
|---|---|---|---|
| `AI` | `/api/ai/*` | AI 에이전트, MCP, 스크립트 | 시맨틱(레이어 이름·타일 인덱스 단위), 요청마다 즉시 저장 |
| `Editor` | `/api/map`, `/api/maps`, `/api/image` | 브라우저 UI 자체 | 원시 MV JSON 통째로 GET/PUT, 낙관적 잠금(`rev`) |

**AI로 맵을 다룰 땐 `Editor` 태그의 엔드포인트를 직접 호출하지 말 것** — 원시 PUT은 파일 전체를 교체하므로 동시 편집 중인 다른 클라이언트(사람 UI 등)의 변경을 지울 위험이 크다. `AI` 태그의 시맨틱 엔드포인트(`/edit`, `/events` 등)는 최소 단위로만 파일을 갱신한다.

## MCP로 쓰기

REST를 직접 호출하는 대신 MCP 도구로 감싼 버전을 쓰려면 [mcp/server.mjs](mcp/server.mjs) 참고 — `AI` 태그 엔드포인트 대부분을 도구 15종으로 감쌌다. 완전한 1:1은 아니다: `GET /api/ai/palette`(팔레트 카탈로그)와 `GET .../events/{id}`(단일 이벤트 조회)는 아직 전용 도구가 없음(각각 curl 직접 호출, `list_events`로 대체). 등록 방법은 [README.md](README.md#한눈에-보는-구조) 참고.

## 에러 처리 규약

모든 에러 응답은 `{ "error": string, "hint"?: string }` 형태다(스키마: `openapi.yaml`의 `Error`). `hint`가 있으면 그 지시를 따라 재시도하도록 만들어졌다 — 예:

```json
{"error": "알 수 없는 layer: wrong", "hint": "사용 가능: ground(0), ground2(1), objLower(2), objUpper(3), shadow|light(4), region(5)"}
```

저장 충돌(409)만 예외로 `currentRev` 필드가 추가로 붙는다(`PUT /api/map`).

## 스펙과 실제 동작이 다르면

`openapi.yaml`은 손으로 작성·관리하는 문서라 서버 코드([server/ai_api.ts](server/ai_api.ts), [vite.config.ts](vite.config.ts))가 변경됐는데 스펙이 못 따라갔을 수 있다. 의심되면 실제 코드가 항상 우선이다. 스펙을 고칠 때는 위 lint를 다시 통과시킬 것.
