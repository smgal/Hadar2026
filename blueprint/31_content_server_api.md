# BP-31 · 콘텐츠 서버 REST/MCP API 명세

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-31 · **상태**: 개정 2판(D-26·D-27 반영 + REVIEW_BP-31 조치) · **선행 문서**: [BP-30](30_toolchain_overview.md), [BP-21](21_content_pack_spec.md), [BP-26](26_entity_registry_and_anchors.md)
> **독자**: 콘텐츠 서버 구현자 · MCP 래퍼 구현자 · 생성 에이전트 작성자
> **한 줄 요약**: 기존 맵 API(`/api/ai/*`)와 **같은 프로세스·같은 규약**으로 `/api/content/*` 31개 라우트를 추가하고, 배치 `ops`·`rev` 낙관적 잠금·`{error, code, hint}` 에러·MCP 도구 28종·자기기술 가이드까지 확정한다.

**파이프라인 구획**(D-01): 전부 **Authoring** 이다. 이 API 는 배포물에 포함되지 않고, 런타임은 이 서버의 존재를 모른다.

**개정 이력**

| 판 | 변경 |
|---|---|
| 초판 | 31 라우트 · 배치 op · rev 규약 · 에러 카탈로그 · MCP 도구 28종 · 가이드 초안 |
| **개정 2판** | **D-27 반영** — `region 200~255` 기반 편집·검증·자동배치를 **전량 삭제**했다. 앵커는 맵 데이터에 아무 표시도 남기지 않으며(§2.5.0), 앵커-타일 정합은 ERROR 가 아니라 **도달 가능성 WARN** 이다. `R-31-7` 을 "서버가 직접 검사" 에서 **kind 별 검사 가능 범위 표**로 좁혔고, GROUND_TRUTH 부록 K 의 **진입점 게이트 비대칭**을 응답에 노출한다. **D-25 위반 2건 해소** — §2.5·§7.2 의 앵커 kind ↔ 타일 표를 삭제하고 [BP-26 §3.3](26_entity_registry_and_anchors.md) 링크로 대체. **D-26 반영** — `POST /api/content/sim` 응답을 **2축**(`modelVerdict`/`supportVerdict`)으로 바꿨다([BP-33 §7.2](33_validation_and_lint.md) 의 CI JSON 필드명과 일치). **REVIEW_BP-31 조치** — `preview.png` 는 상한 400 이 아니라 **클램프**임을 정정(F-31-02) · P6 의 "rev 낙관적 잠금 계승" 을 `/api/map` 한정 사실로 정정하고 §4.3 에 "AI 가 덮어씀" 행 추가(F-31-03) · 누락 라우트 2개를 표에 편입해 **33 라우트**(F-31-05) · [BP-36 D3](36_map_editor_extension.md) 과의 맵 쓰기 경로 충돌 해소(F-31-06) · §6 의 MCP 인용 2곳을 부록 값으로 통일(F-31-07) · 라우트 계약 테스트 소유자 지정(F-31-08) · op **16종**·에러 **39종** 표기 통일 · 코드 인용 줄 번호 6곳 교정 |

---

## 0. 이 장의 범위

| 항목 | 내용 |
|---|---|
| 확정하는 것 | 엔드포인트 31개의 메서드·경로·요청/응답·에러·멱등성·curl 예시 · 배치 op 16종 · rev 동시성 규약 · 에러 코드 39종 · MCP 도구 28종 · 가이드 문서 초안 |
| 확정하지 않는 것 | 검증 **규칙**의 내용(→ [BP-33](33_validation_and_lint.md)) · 시뮬레이터 **알고리즘**(→ [BP-34](34_headless_sim_and_solver.md)) · 브라우저 UI(→ [BP-36](36_map_editor_extension.md)) · 프롬프트(→ [BP-37](37_prompt_contracts.md)) |
| 스키마 SSoT | 요청/응답 본문의 엔티티 스키마는 이 장이 정의하지 않는다. [BP-21 §6](21_content_pack_spec.md)(DSL), [BP-22](22_world_bible_model.md), [BP-23](23_quest_model.md), [BP-24](24_dialogue_model.md), [BP-26 §2](26_entity_registry_and_anchors.md)(앵커) 를 그대로 통과시킨다 |
| 근거 결정 | D-12, D-14, D-15, D-09, D-03, D-04 |

**본 API 의 한 문장 정의**: *콘텐츠 팩 소스 트리에 대한 시맨틱 CRUD + 검증·시뮬레이션 위임 창구.*
파일을 통째로 주고받는 저수준 API 는 제공하지 않는다(맵의 `/api/map` 에 해당하는 것이 없다).

---

## 1. 설계 원칙 — 기존 맵 API 에서 계승할 5가지

### 1.1 계승 원칙 표

| # | 원칙 | 맵 API 의 실제 구현 | 콘텐츠 API 에서의 형태 |
|---|---|---|---|
| **P1** | **배치 편집 `ops` 를 1급으로** | `ai_api.ts:217` `applyOps(map, ops, warnings)` — 6종 op 를 순서대로 적용하고 `writeMapFile` **한 번**만 호출(`:673-674`). `AI_GUIDE.md` 가 "여러 편집은 반드시 한 호출에 모을 것" 을 명시 | `POST /api/content/edit` 이 **16종 op**(§3.2 표)를 받아 여러 파일을 **한 트랜잭션**으로 쓴다(§3) |
| **P2** | **`{error, hint}` — hint 는 행동 지시** | `server/util.ts:10-12` `sendError(res, status, error, hint)`. 실제 hint 예: `parseLayer` 실패 시 `사용 가능: ground(0), ground2(1), …`(`ai_api.ts:51-56`), `resolveValue` 실패 시 `value \| a5 \| b 중 하나 필요`(`:129`) | 같은 필드에 `code` 를 **추가**(하위호환 상위집합). hint 는 "다음에 이 요청을 보내라" 수준까지 구체화(§5) |
| **P3** | **검증 실패 시 디스크는 그대로** | `applyOps` 가 `StoreError` 를 던지면 `writeMapFile` 에 도달하지 못하고 catch(`:818-826`)가 에러를 보낸다. 즉 **부분 적용이 디스크에 남지 않는다** | 여러 파일을 다루므로 in-memory 워킹셋 → 전량 검증 → 전량 커밋(§3.3) |
| **P4** | **서버가 자기 사용법을 반환** | `ai_api.ts:493-499` — `GET /api/ai` 가 `AI_GUIDE.md` 원문을 `text/markdown` 으로 그대로 반환. MCP 의 첫 도구가 `get_guide` 이고 설명에 "다른 도구를 쓰기 전에 반드시 한 번 읽을 것"(`mcp/server.mjs:72-77`) | `GET /api/content` 가 `CONTENT_AI_GUIDE.md` 를 반환(§7). MCP 첫 도구는 `content_guide` |
| **P5** | **방어적 파싱 — 조용한 성공 금지** | `opInt`(`:75-85`)가 NaN 을 400 으로 끊는다(과거 `data[NaN]` 에 쓰고 `changed:1` 을 반환하던 버그, DEVLOG §5). `parseLayer` 는 빈 문자열을 거부하고 `hasOwnProperty` 로 프로토타입 키를 막는다(`:51-56`). `clampRegion` 은 교집합을 계산한다(`:199-208`) | 모든 op 필드에 타입·범위 검사. 알 수 없는 필드는 **무시하지 않고 400**(§3.4) |

보조로 계승하는 것 2가지:

| # | 원칙 | 근거 |
|---|---|---|
| **P6** | **rev 의 표현과 409 응답 형태** | `store.ts:34-36` `revOf` = mtime(ms) 문자열. `vite.config.ts:83-92` 가 `rev` 불일치 시 `409 {error, currentRev}`. **계승하는 것은 표현과 응답 형태이고, 선행조건 검사 자체는 아니다**(아래 실측) |
| **P7** | **원자적 파일 쓰기** | `store.ts:72-79`(`renameSync` `:77`), `:137-144`(`:143`) — `tmp` 에 쓰고 `renameSync`. 중간에 죽어도 반쯤 쓰인 파일이 남지 않는다 |

**P6 의 실측 한정 — "계승" 이 안전 착시를 만들지 않도록**(F-31-03)

`rev` **선행조건 검사**는 `PUT /api/map`(브라우저 UI 전용, `vite.config.ts:84-92`)에**만** 있다.
`/api/ai/*` 의 쓰기 경로 4곳(`POST /maps`, `POST /maps/{f}/edit`, `POST|PATCH|DELETE /events*`)은
**`rev` 를 응답에 실어 주기만 하고 요청에서 읽지 않는다.**

| | 요청의 rev 를 읽는가 | 결과 |
|---|:---:|---|
| `PUT /api/map?rev=…` (브라우저) | ✅ | 불일치 시 409 `{error, currentRev}` |
| `POST /api/ai/maps/{f}/edit` | ❌ | **무조건 덮어쓴다.** 브라우저의 미저장 편집이 조용히 사라질 수 있다 |
| `POST /api/content/*` (신규) | 🔸 `ifRev` 를 주면 검사(R-31-24 — **선택**) | 주지 않으면 맵 API 와 같은 성질을 물려받는다 |

→ 따라서 P6 은 "**rev 표현(mtime 문자열)과 409 응답 형태를 계승**" 이며, "AI 의 쓰기가 사람의 편집을
막아 준다" 는 뜻이 **아니다.** 그 파급과 완화책은 §4.3 이 다룬다.
### 1.2 맵 API 와 달라지는 3가지

| 차이 | 이유 | 결과 |
|---|---|---|
| **다중 파일 트랜잭션** | 맵 편집은 파일 1개면 끝나지만, 퀘스트 1건은 `quests/x.json` + `strings/ko.json` + `anchors/MAP.json` + `maps/MAP.json` 최대 4개를 함께 고친다 | §3.3 의 2단계 커밋(워킹셋 → 전량 검증 → 전량 rename) |
| **깊은 검증을 서버가 못 한다** | 서버는 TypeScript 이고 Condition/Effect 평가기는 Dart 한 벌뿐이다([BP-30 R-30-1/2](30_toolchain_overview.md)) | 서버는 **형태 검증**만. `validate`/`lint`/`sim`/`build` 는 `hadar_content` CLI 를 subprocess 로 위임(§2.7) |
| **문자열 키 간접층** | 콘텐츠 소스에는 한국어 문장이 직접 들어가지 않는다([BP-21 R-21-20/21](21_content_pack_spec.md)) | 텍스트를 다루는 모든 요청은 `str.…` 키를 주고받는다. 편의를 위해 `POST /api/content/strings/mint` 와 op `mint_string` 이 "텍스트 → 키" 를 대행(§2.6) |

### 1.3 공통 규약

| 항목 | 값 |
|---|---|
| Base URL | `http://localhost:5310` ([BP-30 §7.4](30_toolchain_overview.md), `vite.config.ts:143`) |
| 경로 접두 | `/api/content` |
| 요청 Content-Type | `application/json; charset=utf-8` (본문이 있을 때) |
| 응답 Content-Type | `application/json; charset=utf-8` — 단 `GET /api/content` 는 `text/markdown`, `*.png` 는 `image/png` |
| 인증 | **없음**. localhost 전용 dev 도구 전제(맵 API 와 동일, `README.md` "주의") |
| 문자 인코딩 | 경로 세그먼트는 `decodeURIComponent`. 잘못된 `%` 시퀀스는 400 (`ai_api.ts:483-489` 과 동일 처리) |
| 대상 디렉토리 | `HADAR_ASSETS` (기본 `../../hadar2026_app/assets`). 모든 조회 응답이 `assetsDir` 을 함께 반환([BP-30 R-30-28](30_toolchain_overview.md)) |
| 라우터 진입 | `vite.config.ts:31` 의 `handleAiApi(...)` 직후에 `handleContentApi(store, req, res, url, CONTENT_GUIDE_PATH)` 삽입 |
| `error`/`hint` 의 언어 | **한국어**. 기존 `/api/ai/*` 의 메시지가 전량 한국어이므로 섞지 않는다. `code` 만 영문 snake_case |
| `X-Hadar-Actor` | 쓰기 요청의 행위자 표기 — `agent` \| `human` \| `unknown`(기본). MCP 래퍼가 `agent` 를 붙이고, `generatedBy.kind` 기입에 쓰인다(§2.3, Q-31-5). 위조 방지는 목표가 아니다 |
| 맵 파일을 쓰는 경로 | **이 API 는 새 맵 쓰기 함수를 만들지 않는다** — 아래 R-31-0 |

- **R-31-0** (F-31-06, [BP-36 §9.2 D3](36_map_editor_extension.md) 과 통일) 콘텐츠 API 가 맵 파일을 고칠
  때는 **기존 `applyOps`/`writeMapFile`(`ai_api.ts:217`/`store.ts:72`)을 내부적으로 호출**한다.
  신규 쓰기 함수·신규 직렬화 경로를 만들지 않는다. 즉 `set_tile` op 와 앵커 엔드포인트의 타일 편집은
  **`POST /api/ai/maps/{f}/edit` 와 같은 코드**를 지나며, "맵 파일 쓰기 경로는 하나" 라는 BP-36 의 원칙과
  "콘텐츠 API 안에서 앵커와 타일을 원자적으로 묶는다" 는 이 장의 요구가 동시에 만족된다.

**컬렉션 이름 ↔ 저장 위치 매핑** (URL 의 `{collection}`)

| `{collection}` | ID 접두 | 파일 | 파일당 엔티티 | 근거 |
|---|---|---|---|---|
| `quests` | `quest` | `<pack>/quests/<slug>.json` | 1 | [BP-21 §2.2](21_content_pack_spec.md) R-21-5 |
| `dialogues` | `dlg` | `<pack>/dialogue/<slug>.json` | 1 | 디렉토리는 단수 `dialogue/`, URL 은 복수 `dialogues` |
| `actors` | `npc` | `<pack>/actors/<slug>.json` | 1 | |
| `items` | `item` | `<pack>/items/items.json` | N (배열) | |
| `places` | `place` | `<pack>/world/places.json` | N (배열) | |
| `factions` | `faction` | `<pack>/world/factions.json` | N (배열) | |
| `encounters` | `enc` | `<pack>/encounters/encounters.json` | N (배열) | |

- **R-31-1** 위 표에 없는 `{collection}` 은 400 `bad_collection` 이며 hint 가 **허용 목록 전량**을 준다(P2).
- **R-31-2** 서버는 `{collection}` 과 `{id}` 의 접두사 일치를 검사한다. `POST /api/content/quests` 에 `id: "dlg.core.x"` 를 주면 400 `id_collection_mismatch`.
- **R-31-3** 앵커(`anchor`)와 문자열(`str`)은 이 표에 없다. 파일 구조가 다르므로 전용 라우트를 갖는다(§2.5, §2.6).

---

## 2. 엔드포인트 전수 명세

### 2.0 전체 목록 (33 라우트)

| # | 메서드 | 경로 | 멱등 | 요약 |
|---:|---|---|:---:|---|
| 1 | GET | `/api/content` | ✅ | AI 가이드 전문(markdown) |
| 2 | GET | `/api/content/status` | ✅ | 팩 목록·빌드 신선도·CLI 사용 가능 여부 |
| 3 | GET | `/api/content/packs` | ✅ | 팩 목록 |
| 4 | POST | `/api/content/packs` | ❌ | 팩 생성(디렉토리 + `pack.json` + 빈 `strings/ko.json`) |
| 5 | GET | `/api/content/packs/{id}` | ✅ | 매니페스트 + 엔티티 통계 |
| 6 | PATCH | `/api/content/packs/{id}` | ✅ | 매니페스트 부분 수정 |
| 7 | GET | `/api/content/{collection}` | ✅ | 엔티티 목록(요약) |
| 8 | POST | `/api/content/{collection}` | ❌ | 엔티티 생성 |
| 9 | GET | `/api/content/{collection}/{id}` | ✅ | 엔티티 전문 |
| 10 | PATCH | `/api/content/{collection}/{id}` | ✅ | 엔티티 부분 수정(JSON Merge Patch) |
| 11 | DELETE | `/api/content/{collection}/{id}` | ✅ | 엔티티 삭제 + `retiredIds` 등재 |
| 12 | POST | `/api/content/edit` | ❌ | **배치 편집**(§3) |
| 13 | GET | `/api/content/anchors` | ✅ | 좌표·액터로 앵커 역조회 |
| 14 | GET | `/api/content/anchors/{map}` | ✅ | 맵 1개의 앵커 전량 + 정합 상태 |
| 15 | POST | `/api/content/anchors` | ❌ | 앵커 생성(+ 타일 자동 배치) |
| 16 | POST | `/api/content/anchors/{map}/edit` | ❌ | 맵 단위 앵커 배치 편집 |
| 17 | PATCH | `/api/content/anchors/{id}` | ✅ | 앵커 필드 수정(좌표 제외) |
| 18 | POST | `/api/content/anchors/{id}/move` | ✅ | **앵커 + 타일 원자적 이동** |
| 19 | DELETE | `/api/content/anchors/{id}` | ✅ | 앵커 삭제(+ 타일 정리 선택) |
| 20 | GET | `/api/content/strings/{lang}` | ✅ | 문자열 조회(접두사 필터) |
| 21 | PATCH | `/api/content/strings/{lang}` | ✅ | 문자열 upsert/삭제 |
| 22 | POST | `/api/content/strings/mint` | ❌ | 텍스트 → 키 발급([BP-21 R-21-24](21_content_pack_spec.md)) |
| 23 | GET | `/api/content/validate` | ✅ | 깊은 검증(CLI 위임) |
| 24 | GET | `/api/content/lint` | ✅ | soft gate 린트(CLI 위임) |
| 25 | POST | `/api/content/build` | ✅ | 번들 재빌드(CLI 위임) |
| 26 | POST | `/api/content/sim` | ✅ | 헤드리스 시뮬레이션/솔버(CLI 위임) |
| 27 | GET | `/api/content/refs/{id}` | ✅ | 역참조 조회 |
| 28 | GET | `/api/content/graph/{questId}` | ✅ | 퀘스트 그래프 요약(JSON) |
| 29 | GET | `/api/content/context` | ✅ | 생성용 컨텍스트 팩 조립 |
| 30 | GET | `/api/content/quests/{id}/graph.png` | ✅ | 스테이지 DAG 그림 |
| 31 | GET | `/api/content/dialogues/{id}/graph.png` | ✅ | 대화 그래프 그림 |
| 32 | GET | `/api/content/rev?path=<상대경로>` | ✅ | 파일 1개의 rev 조회. 브라우저 폴링용(§4.3). 맵 API 의 `GET /api/map/rev`(`vite.config.ts:44-52`)와 동형 |
| 33 | GET | `/api/content/sim/trace/{id}.json` | ✅ | `POST /sim` 응답의 `traceUrl` 실체. 24시간 보존(R-31-13) |

- **R-31-0a** 위 표는 **전수 목록**이다. 본문이 쓰는 경로가 표에 없으면 그것은 계약 결함이다
  (초판이 32·33번을 §4.3·§2.7 본문에서만 썼다 — F-31-05).
멱등: 같은 요청을 두 번 보냈을 때 두 번째가 상태를 더 바꾸지 않으면 ✅. 생성 계열은 두 번째가 409 이므로 ❌ 로 표기한다(맵 API 의 `POST /api/ai/maps` 가 `409 이미 존재하는 파일` 을 반환하는 것과 같은 규약, `ai_api.ts:560`).

---

### 2.1 `GET /api/content` — AI 가이드

`GET /api/ai` 와 **동형**이다(`ai_api.ts:493-499`).

| 항목 | 값 |
|---|---|
| 응답 | `200 text/markdown; charset=utf-8` — `tools/mapEditor/CONTENT_AI_GUIDE.md` 원문 |
| 별칭 | `GET /api/content/guide` (맵 API 가 `/api/ai/guide` 를 별칭으로 두는 것과 동일) |
| 에러 | 파일 없음 → `500 guide_missing` |

```bash
curl -s http://localhost:5310/api/content | head -20
```

---

### 2.2 `GET /api/content/status`

에이전트가 **작업 시작 전 환경을 확인**하는 창구. 맵 API 의 `GET /api/ai/current` 에 대응하는 자리다.

```bash
curl -s http://localhost:5310/api/content/status | jq .
```

```json
{
  "assetsDir": "/Users/…/hadar2026_app/assets",
  "packs": [
    { "id": "core",    "version": "1.0.0", "schemaVersion": 1, "entities": 214, "rev": "1756500000000" },
    { "id": "gen_ep1", "version": "0.3.1", "schemaVersion": 1, "entities": 37,  "rev": "1756512345678" }
  ],
  "build": {
    "present": true,
    "staleSources": ["gen_ep1/quests/missing_scholar.json"],
    "lockBuildInputHash": "8f2c…",
    "hint": "소스가 산출물보다 새로움 — POST /api/content/build 를 호출할 것"
  },
  "cli": { "available": true, "bin": "/opt/homebrew/bin/dart", "version": "hadar_content 0.1.0" },
  "currentMap": {
    "file": "TOWN1.json",
    "lastSeenFile": "TOWN1.json",
    "ageSeconds": 2,
    "migration": "shadowed",
    "hint": null
  }
}
```

| 필드 | 의미 |
|---|---|
| `build.staleSources` | mtime 이 `content.lock.json` 보다 새로운 소스 파일. 비어 있으면 산출물이 최신 |
| `cli.available` | `false` 면 23~26번 엔드포인트가 전부 `503 cli_unavailable` ([BP-30 Q-30-3](30_toolchain_overview.md)) |
| `currentMap` | 브라우저 에디터가 열고 있는 맵(`store.ts:151-156` 의 `uiCurrent` 재사용) + 그 맵의 이관 상태([BP-28 §3.2](28_migration_and_coexistence.md)) |
| `currentMap.lastSeenFile` · `.hint` | 기존 `GET /api/ai/current`(`ai_api.ts:501-513`)의 4필드를 **그대로 계승**. `ageSeconds >= 10` 이면 `file` 은 `null` 이 되고 `lastSeenFile` 에 마지막 폴링 파일이 남으며, `hint` 에 "사용자에게 지금 어떤 맵을 보고 있는지 확인할 것" 이 들어간다(`:508-510`) |

- **R-31-3a** (S-31-01) `currentMap` 은 기존 `current` 와 **필드 단위로 동형**이다. `hint` 는 에이전트의
  행동을 실제로 바꾸는 필드이므로(오래된 값을 현재 맵으로 오인하는 것을 막는다) 빠뜨리지 않는다.

---

### 2.3 팩 — 3·4·5·6번

#### `GET /api/content/packs`

```bash
curl -s http://localhost:5310/api/content/packs | jq .
```

```json
{ "assetsDir": "/…/assets",
  "packs": [
    { "id": "core", "title": "하다르 원작 이식", "version": "1.0.0", "dependsOn": [],
      "generatedBy": { "kind": "human" }, "rev": "1756500000000",
      "counts": { "quests": 0, "dialogues": 41, "actors": 63, "items": 22, "places": 14,
                  "factions": 5, "encounters": 9, "anchors": 118, "strings": 1204 } }
  ] }
```

#### `POST /api/content/packs`

| 항목 | 값 |
|---|---|
| 본문 | `{ "id", "title", "dependsOn"?, "description"?, "generatedBy"?, "schemaVersion"? }` |
| 기본값 | `schemaVersion: 1`, `version: "0.1.0"`, `dependsOn: []`, `generatedBy: {"kind":"agent"}` (MCP 경유 시) / `{"kind":"human"}` (직접 curl 시 `X-Hadar-Actor: human` 헤더로 지정) |
| 성공 | `201 { ok, id, rev, created: [파일 경로 목록] }` |
| 부작용 | 디렉토리 골격 생성 + `pack.json` + **빈 `strings/ko.json`**([BP-21 §2.2](21_content_pack_spec.md) 가 `strings/ko.json` 을 "비어 있어도 파일은 존재" 로 필수 규정) |
| 에러 | 409 `pack_exists` / 400 `bad_slug`(팩 슬러그 규칙) / 400 `reserved_pack`([BP-21 §4.5](21_content_pack_spec.md) 예약어) / 400 `dependency_cycle` |

```bash
curl -s -X POST http://localhost:5310/api/content/packs \
  -H 'Content-Type: application/json' \
  -d '{"id":"gen_ep2","title":"에피소드 2: 메너스의 소문","dependsOn":["core"],
       "generatedBy":{"kind":"agent","pipeline":"hadar-gen/8stage","model":"…","promptVersion":"1.2"}}'
```

```json
{ "ok": true, "id": "gen_ep2", "rev": "1756512399001",
  "created": ["gen_ep2/pack.json","gen_ep2/strings/ko.json","gen_ep2/quests/","gen_ep2/dialogue/",
              "gen_ep2/actors/","gen_ep2/anchors/","gen_ep2/items/","gen_ep2/world/","gen_ep2/encounters/"] }
```

#### `GET /api/content/packs/{id}` · `PATCH /api/content/packs/{id}`

`GET` 은 매니페스트 전문 + `counts` + `entryPoints` 검사 결과.
`PATCH` 는 JSON Merge Patch 로 매니페스트를 수정한다. 단 **`id` 와 `schemaVersion` 은 수정 불가**(400 `immutable_field`) — 전자는 디렉토리 이름과 묶여 있고, 후자는 승격 규칙([BP-21 §7.2](21_content_pack_spec.md))을 따르는 마이그레이션 절차가 필요하다.

```bash
curl -s -X PATCH http://localhost:5310/api/content/packs/gen_ep1 \
  -H 'Content-Type: application/json' \
  -d '{"version":"0.3.2","ifRev":"1756512345678",
       "entryPoints":{"quests":["quest.gen_ep1.missing_scholar"]}}'
```

---

### 2.4 엔티티 컬렉션 — 7·8·9·10·11번

`{collection}` 은 §1.3 의 7종. 모든 컬렉션이 **같은 계약**을 따른다.

#### `GET /api/content/{collection}`

| 쿼리 | 기본값 | 의미 |
|---|---|---|
| `pack` | (전체) | 팩 필터 |
| `q` | — | ID·슬러그 부분 일치 |
| `tag` | — | `tags` 배열 포함 여부(퀘스트 등) |
| `full` | `0` | `1` 이면 요약이 아니라 전문 배열 |
| `limit` / `offset` | `200` / `0` | 페이지네이션 |

```bash
curl -s 'http://localhost:5310/api/content/quests?pack=gen_ep1' | jq .
```

```json
{ "collection": "quests", "total": 1, "limit": 200, "offset": 0,
  "items": [
    { "id": "quest.gen_ep1.missing_scholar", "pack": "gen_ep1",
      "file": "gen_ep1/quests/missing_scholar.json", "rev": "1756512345678",
      "title": "str.gen_ep1.quest.missing_scholar.title",
      "titleText": "사라진 학자",
      "stages": 3, "objectives": 5, "tags": ["main","act1"] }
  ] }
```

- **R-31-4** 요약 응답은 문자열 키와 함께 **해소된 텍스트**(`titleText`)를 나란히 준다. 에이전트가 목록을 훑을 때 키만 보면 아무 의미도 알 수 없기 때문이다. 쓰기 요청에서는 `*Text` 필드를 **받지 않는다**(400 `inline_text`).

#### `POST /api/content/{collection}`

| 항목 | 값 |
|---|---|
| 본문 | `{ "id", "pack"?, ...엔티티 본문, "ifPackRev"? }` — 엔티티 본문 스키마는 각 담당 장 소관 |
| `pack` 생략 시 | `id` 의 2번째 세그먼트에서 유도 |
| 성공 | `201 { ok, id, file, rev, warnings }` |
| 파일 배치 | 1파일 1엔티티 컬렉션은 새 파일 생성(파일명 = 슬러그, R-21-6), N-엔티티 컬렉션은 배열에 삽입 후 `id` 사전순 재정렬([BP-21 §8](21_content_pack_spec.md) 배열 정렬 규약) |
| 에러 | 409 `id_exists` / 409 `retired_id` / 400 `bad_id` / 400 `id_collection_mismatch` / 400 `slug_file_mismatch` / 404 `pack_not_found` / 400 `inline_text` |

```bash
curl -s -X POST http://localhost:5310/api/content/actors \
  -H 'Content-Type: application/json' \
  -d '{
    "id": "npc.gen_ep1.scholar_wife",
    "type": "actor",
    "pack": "gen_ep1",
    "faction": "faction.core.lore_commoner",
    "place": "place.gen_ep1.scholar_house",
    "defaultDialogue": "dlg.gen_ep1.wife_plea"
  }'
```

```json
{ "ok": true, "id": "npc.gen_ep1.scholar_wife",
  "file": "gen_ep1/actors/scholar_wife.json", "rev": "1756512400111",
  "warnings": ["str.gen_ep1.npc.scholar_wife.name 이 아직 없음 — POST /api/content/strings/mint 로 만들 것"] }
```

- **R-31-5** 서버는 **참조 대상의 존재를 확인하지 않는다**(`faction.core.lore_commoner` 가 실제로 있는지 등). 그것은 깊은 검증(CLI)의 몫이다([BP-30 R-30-2](30_toolchain_overview.md)). 대신 참조 **형태**(ID 정규식)는 검사하고, 미해소 참조는 `warnings` 로 알린다.

#### `GET /api/content/{collection}/{id}`

```bash
curl -s http://localhost:5310/api/content/quests/quest.gen_ep1.missing_scholar | jq .
```

응답은 소스 파일 원문 + 메타 봉투:

```json
{ "id": "quest.gen_ep1.missing_scholar", "collection": "quests", "pack": "gen_ep1",
  "file": "gen_ep1/quests/missing_scholar.json", "rev": "1756512345678",
  "body": { /* 소스 JSON 그대로. _note 포함 */ },
  "strings": { "str.gen_ep1.quest.missing_scholar.title": "사라진 학자", "…": "…" } }
```

| 쿼리 | 의미 |
|---|---|
| `strings=0` | `strings` 동봉 생략(기본 `1`) |
| `resolve=1` | 참조를 1단계 펼쳐 동봉(`_resolved` 필드에 giver 액터·대화 요약) |

#### `PATCH /api/content/{collection}/{id}`

**JSON Merge Patch (RFC 7386) 의미론**을 쓴다: 객체는 재귀 병합, `null` 은 필드 삭제, **배열은 통째 교체**.

```bash
curl -s -X PATCH http://localhost:5310/api/content/quests/quest.gen_ep1.missing_scholar \
  -H 'Content-Type: application/json' \
  -d '{"ifRev":"1756512345678","tags":["main","act1","tutorial"],"_note":null}'
```

| 항목 | 값 |
|---|---|
| 예약 필드 | `ifRev`(선택) — 본문 최상위에서만 유효하며 병합 대상에서 제외 |
| 배열 부분 수정 | Merge Patch 로는 불가능. `POST /api/content/edit` 의 `array_insert`/`array_remove`/`array_move` 를 쓸 것(§3.2) |
| 성공 | `200 { ok, id, rev, changedFields, warnings }` |
| 에러 | 409 `rev_conflict` / 404 `entity_not_found` / 400 `immutable_field`(`id`, `pack`) / 400 `inline_text` |

#### `DELETE /api/content/{collection}/{id}`

| 항목 | 값 |
|---|---|
| 부작용 | 파일(또는 배열 요소) 제거 + `pack.json#retiredIds` 에 `{ id, since, reason }` 등재([BP-21 §4.6](21_content_pack_spec.md)) |
| 쿼리 | `reason=<string>`(권장), `force=1`(역참조가 남아 있어도 강행) |
| 기본 동작 | 역참조가 있으면 **거부**한다 → `409 has_references` + hint 에 참조자 목록 |
| 성공 | `200 { ok, id, retired: true, rev, alsoRemoved: ["str.gen_ep1.quest.…"] }` |

```bash
curl -s -X DELETE 'http://localhost:5310/api/content/dialogues/dlg.gen_ep1.dead_branch?reason=critic%20반려'
```

```json
{ "error": "dlg.gen_ep1.dead_branch 를 참조하는 곳이 2군데 있습니다.",
  "code": "has_references",
  "hint": "먼저 참조를 끊으세요: anchor.gen_ep1.town1_wife(dialogue), quest.gen_ep1.missing_scholar#s1.choose. 그래도 지우려면 ?force=1",
  "references": ["anchor.gen_ep1.town1_wife#dialogue", "quest.gen_ep1.missing_scholar#s1.choose.dialogueId"] }
```

- **R-31-6** 삭제는 **문자열도 함께 정리**한다. 소유자 접두(`str.<pack>.<type>.<slug>.`)로 시작하는 키를 전부 제거하고 `alsoRemoved` 로 보고한다. 남겨 두면 [BP-33](33_validation_and_lint.md) 의 고아 문자열 경고가 영구히 쌓인다.

---

### 2.5 앵커 — 13~19번

앵커 스키마는 [BP-26 §2](26_entity_registry_and_anchors.md) 소관이다. 여기서는 **조작 방법**만 정한다.

#### 2.5.0 먼저 — D-27 이 이 절에서 무엇을 지웠는가

초판은 `trigger`/`battle(step_on)` 앵커를 위해 **맵의 region 레이어 200~255 에 값을 심는** 자동 배치를
갖고 있었다. **그 기능은 전량 삭제한다.** 이유는 정책이 아니라 사실이다 — GROUND_TRUTH 부록 J-1:

| 실측 | 결과 |
|---|---|
| `map_loader.dart:44` — `map.data[i].ixEvent = _getLayerData(rawData, 5, i, size)` | region 원시값(0~255)이 `ixEvent` 의 **비트 0~7** 에 들어간다 |
| `tile_properties.dart:187` — `int eventType = unit.ixEvent & 0x00FF0000;` | 마스크는 **비트 16~23** 만 본다 → `200 & 0x00FF0000 == 0` |
| `ai_api.ts:94` — `if (z === 5 && (v < 0 \|\| v > 255)) throw …` | region 값이 0~255 로 강제되므로 `0x00010000` 을 직접 심을 수도 없다 |

→ **어떤 region 값도 타일 액션을 만들지 못한다.** region 레이어는 로드되지만 아무 효과가 없다.
부록 J-3 에 따라 타일 액션의 실제 출처는 ① 맵 JSON `events[]` 의 이름 접두사 ② `ixObj1`(objUpper) 의
B 대역 ③ `ixTile`(ground) 의 A5 대역 **3개뿐**이며, region·objLower·shadow·ground2 는 관여하지 않는다.

**D-27 이 대신 확정한 것** — 콘텐츠 티어는 **타일 비트를 거치지 않고 트리거 인덱스를 직접 조회**한다
([BP-26 §4.1](26_entity_registry_and_anchors.md) 인덱스 · [BP-27 §4.2·§4.3](27_runtime_engine.md) 런타임 경로).
그 귀결이 이 API 에 주는 것은 세 가지다.

- **R-31-6a** (D-27) **앵커 생성·이동은 맵 파일을 반드시 고쳐야 하는 것이 아니다.** `autoPlaceTile` 은
  "게임이 앵커를 인식하게 만드는 수단" 이 아니라 **"플레이어가 그 앵커에 닿을 수 있게 만드는 편의"** 다.
  `false` 로 두어도 앵커는 정상 발화한다.
- **R-31-6b** (D-27) `trigger`·`battle(step_on)` 은 **놓을 타일이 없다.** 이 kind 에 `autoPlaceTile: true`
  를 주면 서버는 `warnings` 에 `no_tile_needed` 를 남기고 **맵 파일을 건드리지 않는다**(에러가 아니다 —
  기존 요청이 깨지지 않아야 한다).
- **R-31-6c** (D-27) 앵커-타일 정합 위반의 심각도는 **`warning`** 이다. 소유는 [BP-33 §4.5](33_validation_and_lint.md)
  이며 그 장이 D-27 로 4건을 ERROR → WARN 으로 강등하고 `V-MAP-017`(region 규칙)을 삭제했다.
  이 API 는 그 심각도를 **그대로 중계**하고 자기 판단을 얹지 않는다.

> **부록 I-1 은 무의미해졌다.** `Map001.json` (2,3) 의 `region=255` 가 예약 대역과 충돌한다는 지적은
> **예약을 하지 않으므로 성립하지 않는다.** 그 칸을 정리하는 태스크도 필요 없다.

#### `GET /api/content/anchors` — 역조회

| 쿼리 | 의미 |
|---|---|
| `map` + `x` + `y` | 그 칸의 앵커 전량(kind 무관) |
| `actor` | 그 액터를 가리키는 앵커 전량(맵 횡단) |
| `kind` | kind 필터 |
| `pack` | 팩 필터 |

[BP-26 §6.2](26_entity_registry_and_anchors.md) 의 좌표 이동 절차 2단계가 정확히 이 호출이다.

```bash
curl -s 'http://localhost:5310/api/content/anchors?map=TOWN1&x=34&y=12' | jq .
```

```json
{ "map": "TOWN1", "x": 34, "y": 12,
  "anchors": [
    { "id": "anchor.core.town1_gate_guard", "kind": "actor", "pack": "core",
      "actor": "npc.core.lore_gate_guard", "facing": "down",
      "file": "core/anchors/TOWN1.json", "rev": "1756500011000",
      "tile": { "action": "talk", "objUpper": 132, "groundA5": 12, "reachable": true } }
  ] }
```

- **R-31-6d** (D-27) `tile` 블록의 필드 이름은 `ok` 가 아니라 **`reachable`** 이다. `ok` 는 "이 앵커가
  동작하는가" 로 읽히지만 런타임은 타일과 무관하게 앵커를 발화시킨다. 이 값이 묻는 것은
  **"플레이어가 물리적으로 닿을 수 있는가"** 뿐이다.

#### `GET /api/content/anchors/{map}` — 맵 1개 전량 + 정합 상태

```bash
curl -s http://localhost:5310/api/content/anchors/TOWN1 | jq '.summary'
```

```json
{ "map": "TOWN1", "mapFile": "TOWN1.json", "mapRev": "1756499000000",
  "migration": { "state": "shadowed", "since": "2026-09-01" },
  "files": [ { "pack": "core", "file": "core/anchors/TOWN1.json", "rev": "1756500011000" } ],
  "anchors": [ /* … */ ],
  "summary": { "total": 118, "byKind": { "actor": 74, "sign": 21, "portal": 9, "trigger": 8, "container": 5, "battle": 1 },
               "unreachable": 2, "orphanTiles": 6, "legacyEventOverlap": 3, "bumpOnly": 1 },
  "issues": [
    { "severity": "warning", "code": "anchor_unreachable", "rule": "A-26-16", "anchor": "anchor.core.town1_notice",
      "message": "(30,18) 의 타일 액션이 move 입니다. 앵커는 발화하지만 파티가 그 칸을 밟고 지나가므로 읽을 수 없습니다.",
      "hint": "POST /api/ai/maps/TOWN1.json/edit {\"ops\":[{\"op\":\"set\",\"layer\":\"objUpper\",\"x\":30,\"y\":18,\"b\":116}]} 또는 POST /api/content/anchors/anchor.core.town1_notice/move 로 옮기세요." },
    { "severity": "warning", "code": "orphan_interactive_tile", "x": 41, "y": 7,
      "message": "TALK 타일인데 앵커가 없습니다 (M-26-03)." },
    { "severity": "info", "code": "bump_gate_asymmetry", "anchor": "anchor.core.town1_gate_guard",
      "message": "이 앵커는 확인키로는 발화하지만, 벽에 부딪히는 조작(bump)으로는 발화하지 않습니다 — presentation 게이트(player_sprite.dart:359)가 남아 있습니다.",
      "hint": "조작 방식에 따라 다르게 동작합니다. 코드 수정은 BP-27 Q-27-10 소관이며 콘텐츠로는 회피할 수 없습니다." }
  ] }
```

**R-31-7 (개정, D-27) — 서버가 검사할 수 있는 것과 할 수 없는 것**

이 엔드포인트는 맵 파일과 앵커 파일을 함께 읽어 **도달 가능성**을 그 자리에서 계산한다.
근거는 여전히 "타일 규칙이 이미 TS 로 포팅되어 브라우저와 공유 중"(`src/rules.ts:97-137`)이다.
그러나 **모든 kind 를 검사할 수 있는 것은 아니다** — `unitAction(rawGround, ixObj1, eventType)`
(`rules.ts:125-137`)의 인자에 region 이 없고, D-27 이후 앵커의 발화 조건은 타일이 아니라
[BP-26 §2.2](26_entity_registry_and_anchors.md) 의 `activation` 이기 때문이다.

| kind (`activation`) | 서버가 계산하는 것 | 필요한 데이터 | 판정 |
|---|---|---|---|
| `actor`·`sign`·`container`·`battle`(`interact`) | 그 칸이 **통행 차단**이고 인접 4칸 중 하나가 통행 가능한가 | 맵 타일만 | ✅ 서버 |
| `portal`(`interact`) | 동일 + `enter` 계열 타일인지 | 맵 타일만 | ✅ 서버 |
| `trigger`·`battle`·`portal`(`step_on`/`both`) | 그 칸이 **통행 가능**한가 (밟을 수 있는가) | 맵 타일만 | ✅ 서버 |
| `portal` 도착지 유효성 | 다른 맵의 좌표·통행 | **다른 맵 파일** | ❌ CLI |
| 앵커가 경유하는 퀘스트의 완주 가능성 | 상태공간 탐색 | 콘텐츠 그래프 전체 | ❌ CLI(솔버) |

- **R-31-7** 위 표의 ✅ 행만 서버가 직접 판정한다. **`trigger` 를 위해 region 을 읽는 일은 없다** —
  D-27 이후 `trigger` 의 검사는 "region 이 200~255 인가" 가 아니라 **"그 칸을 밟을 수 있는가"** 이며,
  그것은 `unitAction` 의 현행 인자만으로 계산된다. ❌ 행은 `GET /api/content/validate` 로 위임한다.
- **R-31-7a** (GROUND_TRUTH 부록 K) 응답은 **진입점 게이트 비대칭**을 `info` 로 보고한다.
  `checkTileEvent` 호출 3곳 중 step-on(`player_sprite.dart:193`)과 확인키(`:405`)는 **선검사가 없어**
  코드 변경 없이 앵커가 발화하지만, bump 경로(`:359`)만 `if (action.isInteractive)` 게이트가 남아
  **같은 앵커가 조작 방식에 따라 다르게 동작한다.** 저작자가 이것을 모르면 "왜 벽에 부딪혀도
  대화가 안 뜨나" 를 콘텐츠 문제로 오진한다. 해소는 [BP-27 Q-27-10](27_runtime_engine.md) 소관이고,
  이 API 는 **보이게만** 한다.
- **R-31-7b** 심각도는 D-27 에 따라 **`warning`** 이 기본이다. `error` 로 올리는 것은
  좌표가 맵 범위를 벗어난 경우처럼 **데이터가 성립하지 않는** 때뿐이다.
- **R-31-8** 여러 팩이 같은 맵에 앵커를 두면 파일이 여러 개다. 응답의 `files` 는 배열이고, 쓰기 요청은 항상 `pack` 을 명시해야 한다(생략 시 400 `pack_required`).

#### `POST /api/content/anchors` — 생성 (+ 타일 자동 배치)

[BP-26 R-26-31/32](26_entity_registry_and_anchors.md) 의 구현 창구다.

| 필드 | 필수 | 의미 |
|---|---|---|
| `pack` | ✅ | 소유 팩 |
| `map` | ✅ | `MapInfos.json#name` |
| `kind` | ✅ | `actor`\|`sign`\|`portal`\|`trigger`\|`container`\|`battle` |
| `slug` | ⬜ | 생략 시 `<map소문자>_<대상슬러그>` 로 유도 |
| `x`, `y` | ✅ | 좌표 |
| kind 별 필드 | — | [BP-26 §2.3](26_entity_registry_and_anchors.md) 그대로 |
| `autoPlaceTile` | ⬜ (기본 `true`) | **권장 타일**을 놓아 플레이어가 앵커에 닿을 수 있게 한다. kind ↔ 권장 타일 대응의 **정본은 [BP-26 §3.3](26_entity_registry_and_anchors.md) 표**이며 이 장은 옮겨 적지 않는다(D-25). `trigger`·`battle(step_on)` 은 **놓을 타일이 없어 no-op**(R-31-6b). `"force"` 는 기존 오브젝트를 덮어쓴다 |
| `ifRev` | ⬜ | `{ "anchors": "…", "map": "…" }` |

```bash
curl -s -X POST http://localhost:5310/api/content/anchors \
  -H 'Content-Type: application/json' \
  -d '{"pack":"gen_ep1","map":"TOWN1","kind":"actor","slug":"town1_scholar_wife",
       "actor":"npc.gen_ep1.scholar_wife","x":22,"y":40,"facing":"down","autoPlaceTile":true}'
```

```json
{ "ok": true, "id": "anchor.gen_ep1.town1_scholar_wife",
  "anchorsFile": "gen_ep1/anchors/TOWN1.json", "anchorsRev": "1756512500222",
  "mapFile": "TOWN1.json", "mapRev": "1756512500250",
  "tilePlaced": { "layer": "objUpper", "x": 22, "y": 40, "before": 0, "after": 132 },
  "reachable": true,
  "warnings": ["앵커 추가로 트리거 인덱스가 낡음 — POST /api/content/build 필요"] }
```

에러 사례 — 그 자리에 다른 오브젝트가 있음(R-26-32):

```json
{ "error": "(22,40) 의 objUpper 에 이미 B 47(BLOCK)이 있어 자동 배치를 거부했습니다.",
  "code": "anchor_tile_occupied",
  "hint": "다른 좌표를 고르거나, 먼저 POST /api/ai/maps/TOWN1.json/edit 로 (22,40) 을 비운 뒤 재시도하세요. 덮어쓰려면 autoPlaceTile:\"force\"." }
```

`trigger` 앵커의 응답은 `tilePlaced` 가 `null` 이고 맵 rev 가 바뀌지 않는다:

```json
{ "ok": true, "id": "anchor.gen_ep1.crypt_scholar_clue",
  "anchorsFile": "gen_ep1/anchors/TOWN1.json", "anchorsRev": "1756512500222",
  "mapFile": "TOWN1.json", "mapRev": "1756499000000",
  "tilePlaced": null,
  "reachable": true,
  "warnings": ["no_tile_needed: trigger(step_on) 앵커는 맵 데이터에 표시를 남기지 않습니다 (D-27). 맵 파일은 변경되지 않았습니다."] }
```

#### `POST /api/content/anchors/{map}/edit` — 맵 단위 배치

`POST /api/ai/maps/{file}/edit` 와 **동형**이다. op 집합은 §3.2 의 앵커 op 6종(`add_anchor`, `move_anchor`, `update_anchor`, `remove_anchor`, `set_migration`, `set_tile`).

```bash
curl -s -X POST http://localhost:5310/api/content/anchors/DEN1/edit \
  -H 'Content-Type: application/json' \
  -d '{"pack":"gen_ep1","ops":[
        {"op":"add_anchor","kind":"container","slug":"den1_notebook","x":31,"y":18,
         "contents":[{"item":"item.gen_ep1.scholar_notebook","count":1}],"once":true},
        {"op":"add_anchor","kind":"battle","slug":"den1_guardian","x":33,"y":18,
         "encounter":"enc.core.menace_patrol","activation":"step_on"},
        {"op":"set_migration","state":"shadowed","since":"2026-09-14"}
      ]}'
```

```json
{ "ok": true, "map": "DEN1", "pack": "gen_ep1",
  "anchorsRev": "1756512600100", "mapRev": "1756512600130",
  "results": [ {"op":"add_anchor","id":"anchor.gen_ep1.den1_notebook","tilePlaced":true},
               {"op":"add_anchor","id":"anchor.gen_ep1.den1_guardian","tilePlaced":true},
               {"op":"set_migration","changed":1} ],
  "totalChanged": 3, "warnings": [] }
```

#### `PATCH /api/content/anchors/{id}` · `DELETE /api/content/anchors/{id}`

`PATCH` 는 **좌표를 제외한** 필드만 고친다(좌표는 18번이 담당) → `x`/`y` 를 주면 400 `use_move_endpoint`.
`DELETE` 는 `?cleanupTile=1` 이면 그 칸의 **objUpper** 를 되돌린다(region 은 애초에 건드리지 않는다 — §2.5.0).
기본은 타일을 남긴다(다른 앵커가 쓸 수 있고, 사람이 의도해 놓은 지형일 수도 있으므로).

#### `POST /api/content/anchors/{id}/move` — 원자적 이동

[BP-26 R-26-22/24](26_entity_registry_and_anchors.md) 의 구현. **앵커 이동이 타일 이동을 끌고 간다.**

```bash
curl -s -X POST http://localhost:5310/api/content/anchors/anchor.core.town1_gate_guard/move \
  -H 'Content-Type: application/json' \
  -d '{"x":36,"y":12,"moveTile":true,"ifRev":{"anchors":"1756500011000","map":"1756499000000"}}'
```

```json
{ "ok": true, "id": "anchor.core.town1_gate_guard",
  "from": { "x": 34, "y": 12 }, "to": { "x": 36, "y": 12 },
  "tileOps": [ {"layer":"objUpper","x":34,"y":12,"before":132,"after":0},
               {"layer":"objUpper","x":36,"y":12,"before":0,"after":132} ],
  "anchorsRev": "1756512700000", "mapRev": "1756512700020",
  "verify": { "tileAction": "talk", "adjacentPassable": 2, "reachable": true, "bumpReachable": true } }
```

| 단계 | 서버 동작 | 실패 시 |
|---|---|---|
| 1 | 앵커 파일·맵 파일 rev 확인 | 409 `rev_conflict` |
| 2 | 워킹셋에서 앵커 좌표 변경 + 타일 2칸 편집 | — |
| 3 | 도달 가능성 재검사([BP-26 §3.3·§3.4](26_entity_registry_and_anchors.md)) | **커밋을 막지 않는다**(D-27). `warnings` 에 `anchor_unreachable` 을 담고 4단계로 진행 |
| 4 | 두 파일 tmp 작성 → rename 2회 | §3.3 의 부분 커밋 규약 |

- **R-31-9** `moveTile: false` 를 주면 타일은 그대로 두고 앵커만 옮긴다. D-27 이후 이 조합은 **정상 동작한다** —
  앵커는 목적지 타일이 무엇이든 발화한다. 다만 목적지에 권장 타일이 없으면 `anchor_unreachable`
  경고가 붙는다. `trigger`/`battle(step_on)` 에는 `moveTile` 이 **의미가 없다**(옮길 타일이 없다).
- **R-31-9a** (D-27) 3단계가 커밋을 막지 않으므로 **이동은 실패하지 않는다**(rev 충돌·좌표 범위 밖 제외).
  초판의 "정합 위반 → 400 → 디스크 무변경" 은 앵커가 타일 비트에 기생한다는 폐기된 전제 위에 있었다.
  대신 [BP-36 §4.2](36_map_editor_extension.md) 의 확인 다이얼로그가 **사람의 오클릭**을 막는다.

---

### 2.6 문자열 — 20·21·22번

#### `GET /api/content/strings/{lang}`

```bash
curl -s 'http://localhost:5310/api/content/strings/ko?pack=gen_ep1&prefix=str.gen_ep1.quest.missing_scholar.' | jq .
```

```json
{ "lang": "ko", "pack": "gen_ep1", "file": "gen_ep1/strings/ko.json", "rev": "1756512345000",
  "total": 6,
  "strings": {
    "str.gen_ep1.quest.missing_scholar.title": "사라진 학자",
    "str.gen_ep1.quest.missing_scholar.summary": "@B로어성@@의 학자가 사흘째 돌아오지 않는다.",
    "str.gen_ep1.quest.missing_scholar.stage.s1.journal": "학자의 아내에게 이야기를 들었다."
  } }
```

| 쿼리 | 의미 |
|---|---|
| `pack` | 대상 팩(생략 시 전 팩 병합, 이때 쓰기는 불가) |
| `prefix` | 키 접두 필터 |
| `owner` | 소유 엔티티 ID 로 필터(`str.<pack>.<type>.<slug>.` 유도) |
| `missing=1` | 참조되지만 값이 없는 키만 |
| `orphan=1` | 값은 있지만 아무도 참조하지 않는 키만 |

#### `PATCH /api/content/strings/{lang}`

```bash
curl -s -X PATCH http://localhost:5310/api/content/strings/ko \
  -H 'Content-Type: application/json' \
  -d '{"pack":"gen_ep1","ifRev":"1756512345000",
       "set":{"str.gen_ep1.quest.missing_scholar.title":"사라진 학자"},
       "remove":["str.gen_ep1.quest.missing_scholar.old_hint"]}'
```

| 항목 | 값 |
|---|---|
| `set` | upsert 할 키→텍스트 맵 |
| `remove` | 삭제할 키 배열 |
| 검증 | 키 정규식([BP-21 §4.1 STRING_KEY](21_content_pack_spec.md)), `@` 색상 태그 균형([BP-21 §5.5](21_content_pack_spec.md)), 길이 경고(`contentBudget.warnLineChars`) |
| 정렬 | 저장 시 키 사전순 재정렬(결정론, [BP-21 §8](21_content_pack_spec.md)) |
| 성공 | `200 { ok, rev, set: n, removed: n, warnings }` |
| 에러 | 400 `bad_string_key` / 400 `unbalanced_color_tag` / 409 `rev_conflict` |

#### `POST /api/content/strings/mint` — 키 발급

[BP-21 R-21-24](21_content_pack_spec.md) 가 이 엔드포인트를 명시적으로 요구한다. 작가 에이전트가 인라인 텍스트를 쓸 수 없으므로, "이 소유자·이 슬롯의 텍스트" 를 주면 서버가 **키를 만들어 저장하고 키를 돌려준다**.

```bash
curl -s -X POST http://localhost:5310/api/content/strings/mint \
  -H 'Content-Type: application/json' \
  -d '{"pack":"gen_ep1","lang":"ko","items":[
        {"owner":"dlg.gen_ep1.wife_plea","slot":"node.intro.line.0","text":"제발… 남편을 찾아 주세요."},
        {"owner":"dlg.gen_ep1.wife_plea","slot":"node.intro.line.1","text":"사흘째 소식이 없어요."},
        {"owner":"dlg.gen_ep1.wife_plea","slot":"choice.intro.accept","text":"찾아보겠소."}
      ]}'
```

```json
{ "ok": true, "rev": "1756512800000",
  "minted": {
    "dlg.gen_ep1.wife_plea|node.intro.line.0": "str.gen_ep1.dlg.wife_plea.node.intro.line.0",
    "dlg.gen_ep1.wife_plea|node.intro.line.1": "str.gen_ep1.dlg.wife_plea.node.intro.line.1",
    "dlg.gen_ep1.wife_plea|choice.intro.accept": "str.gen_ep1.dlg.wife_plea.choice.intro.accept"
  },
  "warnings": ["str.…node.intro.line.0 은 31자 권장 폭 이내(15자)"] }
```

- **R-31-10** `mint` 는 **멱등하지 않다**. 같은 owner+slot 에 다른 텍스트로 다시 부르면 값을 덮어쓰고 `overwritten: true` 를 보고한다. 같은 텍스트면 변경 없음(`unchanged: true`).
- **R-31-11** `slot` 의 `<n>` 은 0-based 연속이어야 한다(R-21-23). 구멍이 생기면 `warnings` 에 `string_slot_gap` 을 남긴다(하드 실패는 CLI 의 몫).

---

### 2.7 검증·빌드·시뮬레이션 — 23·24·25·26번 (CLI 위임)

네 엔드포인트는 전부 `hadar_content` CLI 를 **subprocess** 로 부른다([BP-30 §4.2](30_toolchain_overview.md)). 서버는 인자를 조립하고, stdout 의 JSON 을 그대로 중계하며, 종료 코드를 HTTP 상태로 사상한다.

| CLI 종료 코드 | HTTP | 의미 |
|---|---|---|
| `0` | 200 | 통과 |
| `1` | **200** | 검사는 정상 수행됐고 위반이 있음 → 본문의 `ok:false` 로 표현 |
| `2` | 400 | 잘못된 인자(scope 형식 오류 등) |
| `3` | 500 | 소스 손상 |
| (실행 불가) | 503 | `cli_unavailable` |

- **R-31-12** "검사에 걸렸다" 를 HTTP 4xx 로 만들지 않는다. 400 은 **요청이 잘못됐을 때**만이다. 검사 결과는 200 + `ok:false` 로 온다 — 맵 API 의 `GET /api/ai/maps/{file}/validate` 가 이미 그렇게 한다(`ai_api.ts:770-775`: `sendJson(res, 200, { ok: !issues.some(error), issues })`).

#### `GET /api/content/validate`

| 쿼리 | 값 | 의미 |
|---|---|---|
| `scope` | `all`(기본) \| `pack:<id>` \| `map:<MAPNAME>` \| `<entityId>` | 검사 범위 |
| `fix` | `0`(기본) \| `1` | 앵커 자동 수복([BP-26 R-26-28](26_entity_registry_and_anchors.md)) |
| `severity` | `error`(기본) \| `all` | 응답에 포함할 최소 심각도 |

```bash
curl -s 'http://localhost:5310/api/content/validate?scope=pack:gen_ep1' | jq .
```

```json
{ "ok": false, "scope": "pack:gen_ep1", "durationMs": 412,
  "counts": { "error": 1, "warning": 6, "info": 1, "release": 0 },
  "issues": [
    { "severity": "error", "code": "unresolved_ref", "rule": "L-33-04",
      "at": "quest.gen_ep1.missing_scholar#s2.deliver.actorId",
      "message": "npc.gen_ep1.scholar 가 정의되어 있지 않습니다.",
      "hint": "POST /api/content/actors 로 npc.gen_ep1.scholar 를 만들거나, 이 목표의 actorId 를 기존 액터로 바꾸세요. 후보: npc.gen_ep1.scholar_wife" },
    { "severity": "warning", "code": "anchor_unreachable", "rule": "A-26-16",
      "at": "anchor.gen_ep1.town1_scholar_wife",
      "message": "(22,40) 의 타일 액션이 move 입니다. 앵커는 발화하지만 파티가 밟고 지나가므로 대화를 걸 수 없습니다.",
      "hint": "POST /api/content/anchors/anchor.gen_ep1.town1_scholar_wife/move 로 옮기거나 objUpper 를 권장 대역으로 설정하세요 — hint 의 set op 를 그대로 보내면 됩니다." }
  ] }
```

- **R-31-11a** (D-27) `severity` 는 이 API 가 정하지 않는다. `hadar_content lint`/`validate` 의 출력을
  **그대로 중계**하며, 심각도의 정본은 [BP-33 §5](33_validation_and_lint.md) 다. D-27 로 앵커-타일 정합
  4건이 ERROR → WARN 으로 강등되었고 `V-MAP-017`(region 규칙)은 삭제되었으므로, 위 예시의 두 번째
  항목은 **하드 게이트를 막지 않는다.** 단 그 앵커를 경유하는 퀘스트는 솔버가 도달 불가로 판정해
  `modelVerdict: REFUTED` 로 막힐 수 있다([BP-26 R-26-7b](26_entity_registry_and_anchors.md) 의 2단 구조).

#### `GET /api/content/lint`

같은 형태이며 soft gate 규칙만 본다. 쿼리 `scope`, `rules=<쉼표목록>`, `maxWarnings=<n>`.

#### `POST /api/content/build`

```bash
curl -s -X POST http://localhost:5310/api/content/build -d '{"checkFormat":true}'
```

```json
{ "ok": true, "durationMs": 1830,
  "outputs": [
    { "file": "build/content.bundle.json", "bytes": 318204, "sha256": "6b1f…", "budget": "ok" },
    { "file": "build/content.index.json",  "bytes":  94112, "sha256": "a002…", "budget": "ok" },
    { "file": "build/content.lock.json",   "bytes":  41880, "sha256": "cd77…", "budget": "ok" }
  ],
  "migration": { "legacy": ["LORE_EP","Prolog_B1"], "shadowed": ["TOWN1"], "migrated": ["MAP003"], "frozen": [] },
  "warnings": [] }
```

| 본문 필드 | 기본 | 의미 |
|---|---|---|
| `checkFormat` | `false` | `--check-format`. `true` 면 포맷 위반이 실패 |
| `fixFormat` | `false` | `--fix-format`. 정규화 후 저장 |
| `out` | (기본 경로) | 산출 디렉토리 override (결정론 비교용) |

#### `POST /api/content/sim`

```bash
curl -s -X POST http://localhost:5310/api/content/sim \
  -H 'Content-Type: application/json' \
  -d '{"quest":"quest.gen_ep1.missing_scholar","policy":"greedy","seed":1234,"maxSteps":4000,"trace":true}'
```

```json
{ "ok": false, "quest": "quest.gen_ep1.missing_scholar", "policy": "greedy", "seed": 1234,
  "modelVerdict": "REFUTED",
  "supportVerdict": "UNSUPPORTED",
  "unpublishedEvents": ["item_gained", "item_lost"],
  "blockedBy": ["BP-42"],
  "result": "unreachable_stage",
  "reached": ["s1_meet_wife", "s2_ask_guard"],
  "blockedAt": { "stage": "s3_find_notebook", "objective": "acquire_notebook" },
  "reason": "item.gen_ep1.scholar_notebook 를 주는 곳이 없습니다 (RG-01).",
  "hint": "container 앵커나 give_item 효과를 추가하세요. 예: POST /api/content/anchors {\"pack\":\"gen_ep1\",\"map\":\"DEN1\",\"kind\":\"container\",\"x\":31,\"y\":18,\"contents\":[{\"item\":\"item.gen_ep1.scholar_notebook\",\"count\":1}]}",
  "steps": 218,
  "traceUrl": "/api/content/sim/trace/9f3a2c.json" }
```

**D-26 — 판정은 2축이다. 한 필드로 뭉치지 않는다.**

| 필드 | 값 | 무엇을 묻는가 | 소유 |
|---|---|---|---|
| `modelVerdict` | `PROVEN` \| `REFUTED` \| `UNKNOWN` | 콘텐츠 그래프상 완주 경로가 존재하는가 | [BP-34 §5.1·§5.6](34_headless_sim_and_solver.md) |
| `supportVerdict` | `SUPPORTED` \| `UNSUPPORTED` | 그 경로가 소비하는 **모든 월드 이벤트에 현행 빌드의 발행 지점이 있는가** | [BP-34 §5.10](34_headless_sim_and_solver.md) 의 레지스트리 대조 |
| `unpublishedEvents` | 이벤트 이름 배열 | `UNSUPPORTED` 의 구체 원인. 발행 지점 레지스트리는 빌드가 생성한다(→ [BP-35](35_ci_and_build.md)) |  |
| `blockedBy` | 장 ID 배열 | 그 발행 지점을 만들어야 하는 장(예: 인벤토리 부재 → `BP-42`) |  |
| `result`·`reached`·`blockedAt`·`reason` | 기존 그대로 | 사람이 읽는 상세. **판정 근거로 파싱하지 말 것** |  |

- **R-31-13a** (D-26) 필드 이름은 [BP-33 §7.2](33_validation_and_lint.md) 의 CI 리포트 JSON
  (`solver.<questId>.modelVerdict` / `.supportVerdict` / `.unpublishedEvents` / `.blockedBy`)과
  **철자까지 같다.** 서버 응답과 CI 리포트가 다른 이름을 쓰면 같은 판정을 두 형태로 파싱해야 한다.
- **R-31-13b** (D-26) **`ok` 는 `modelVerdict == "PROVEN"` 만 본다.** `PROVEN + UNSUPPORTED` 는
  `ok: true` 이며, `warnings` 에 `release_blocked` 를 담는다 — 커밋은 되지만 릴리스 게이트
  (`V-L5-007`, [BP-33 §5.4](33_validation_and_lint.md))에서 차단되고 그 팩은 "미활성" 으로 표시된다.
  두 축을 `ok` 하나에 접으면 D-26 이 막으려던 오판이 API 수준에서 재발한다.
- **R-31-13c** `PROVEN + UNSUPPORTED` 응답의 `hint` 는 **에이전트에게 재시도를 권하지 않는다**:
  `"콘텐츠는 완주 가능합니다. 그러나 item_gained 이벤트의 발행 지점이 없어 실제로는 진행되지 않습니다 — 이것은 콘텐츠 문제가 아니라 코드(BP-42) 대기입니다. 이 팩은 미활성으로 커밋하고 사람에게 보고하세요."`

| 본문 필드 | 의미 |
|---|---|
| `quest` \| `all` | 대상 |
| `policy` | `scripted` \| `greedy` \| `random` (D-13) |
| `seed` | 시드. 생략 시 `0` **고정**(비결정 금지) |
| `maxSteps` | 상한. 초과 시 `result: "step_limit"` |
| `trace` | `true` 면 트레이스를 서버 임시 디렉토리에 남기고 URL 을 준다 |
| `solve` | `true` 면 `sim` 대신 `solve`(상태공간 탐색으로 완주 증명/반증) |
| `gate` | `commit`(기본) \| `release`. `release` 면 `supportVerdict != SUPPORTED` 를 `ok: false` 로 만든다([BP-33 R-33-56](33_validation_and_lint.md)) |

- **R-31-13** 트레이스 파일은 서버 임시 디렉토리(`node:os.tmpdir()` 하위)에 두고 **소스 트리에 쓰지 않는다**. 24시간 후 정리. 소스 트리를 어지럽히면 포맷 게이트·git 상태가 오염된다.
- **R-31-14** `sim`/`solve` 는 오래 걸릴 수 있다(수 초~수 분). 서버는 CLI 프로세스에 **타임아웃 120초**를 걸고 초과 시 `504 sim_timeout` + hint 로 "`maxSteps` 를 줄이거나 CLI 로 직접 실행" 을 안내한다.

---

### 2.8 조회 보조 — 27·28·29번

#### `GET /api/content/refs/{id}` — 역참조

[BP-26 §5](26_entity_registry_and_anchors.md) 의 레지스트리를 그대로 노출한다. 산출물(`content.index.json`)이 있으면 그것을 읽고, 없거나 낡았으면 소스를 즉석 스캔한다.

```bash
curl -s http://localhost:5310/api/content/refs/item.gen_ep1.scholar_notebook | jq .
```

```json
{ "id": "item.gen_ep1.scholar_notebook", "kind": "item", "pack": "gen_ep1",
  "source": "index", "indexFresh": false,
  "definedIn": "gen_ep1/items/items.json",
  "givenBy": [],
  "takenBy": ["dlg.gen_ep1.wife_thanks#node.give.effects[0]"],
  "requiredBy": ["quest.gen_ep1.missing_scholar#s3.acquire_notebook"],
  "referencedBy": { "conditions": 1, "effects": 1 },
  "diagnostics": [
    { "code": "RG-01", "severity": "error",
      "message": "획득 불가 아이템을 요구하는 목표가 있습니다 (givenBy 가 비어 있음).",
      "hint": "container 앵커의 contents 또는 give_item 효과를 추가하세요." }
  ] }
```

- **R-31-15** `source: "scan"`(인덱스 미사용) 은 팩이 커지면 느리다. 응답에 `indexFresh` 를 실어 에이전트가 "먼저 build 를 부를지" 판단하게 한다.

#### `GET /api/content/graph/{questId}` — 퀘스트 그래프 요약

```bash
curl -s http://localhost:5310/api/content/graph/quest.gen_ep1.missing_scholar | jq .
```

```json
{ "quest": "quest.gen_ep1.missing_scholar",
  "stages": [
    { "id": "s1_meet_wife", "index": 0, "objectives": ["talk_wife"], "completion": "all", "next": "s2_ask_guard" },
    { "id": "s2_ask_guard", "index": 1, "objectives": ["talk_guard","optional_bribe"], "completion": "all",
      "next": [ { "when": "{op:flag …}", "go": "s3_find_notebook" }, { "when": "{op:true}", "go": "s3_find_notebook" } ] },
    { "id": "s3_find_notebook", "index": 2, "objectives": ["acquire_notebook","deliver_notebook"], "next": "complete" }
  ],
  "edges": [ ["s1_meet_wife","s2_ask_guard"], ["s2_ask_guard","s3_find_notebook"], ["s3_find_notebook","__complete__"] ],
  "analysis": { "cycles": [], "unreachableStages": [], "deadEnds": [],
                "dialogues": ["dlg.gen_ep1.wife_plea","dlg.gen_ep1.guard_about_scholar"],
                "actors": ["npc.gen_ep1.scholar_wife","npc.core.lore_gate_guard"],
                "items": ["item.gen_ep1.scholar_notebook"], "maps": ["TOWN1","DEN1"] } }
```

`?dialogue=<dlgId>` 를 주면 대화 그래프(노드·선택지·도달성)를 같은 형태로 돌려준다.

#### `GET /api/content/context` — 생성용 컨텍스트 팩 조립

D-14 의 **1단계 context** 를 서버가 대행한다. [BP-32](32_generation_harness.md) 가 이 응답의 **소비자**이며, 응답 필드의 의미론은 그 장이 확정한다. 이 장은 **인터페이스**만 정한다.

| 쿼리 | 필수 | 의미 |
|---|---|---|
| `for` | ✅ | `quest` \| `dialogue` \| `actor` \| `anchor_pass` |
| `pack` | ✅ | 작업 대상 팩(쓰기 대상) |
| `place` | ⬜ | 장소 스코프 |
| `map` | ⬜ | 맵 스코프 |
| `actors` | ⬜ | 쉼표 구분 액터 목록(등장인물 고정) |
| `budget` | ⬜ | **토큰** 예산(기본 `57000`). 단위와 기본값은 [BP-32 §32.5.2](32_generation_harness.md) 를 따른다 — 같은 조립 코드를 서버와 CLI 가 공유하므로(§32.3.1) 두 곳의 단위가 달라선 안 된다. 초과분은 요약으로 축약 |

```bash
curl -s 'http://localhost:5310/api/content/context?for=quest&pack=gen_ep1&place=place.core.lore_castle&budget=40000' | jq 'keys'
```

```json
["assetsDir","budget","dsl","existing","schemaRefs","style","targets","world"]
```

| 키 | 내용 |
|---|---|
| `world` | `world/lore.json` 요약 + 해당 장소·세력 발췌([BP-22](22_world_bible_model.md)) |
| `existing` | 스코프 안의 액터·아이템·퀘스트 **요약**(제목·한 줄 요약·상태 키 목록). 전문이 아니다 |
| `dsl` | Condition op 18 / Effect do 25 의 **이름과 시그니처만**([BP-21 §6](21_content_pack_spec.md) 에서 기계 추출) |
| `schemaRefs` | 이 작업에 필요한 JSON Schema 발췌([BP-90](90_appendix_schemas.md)) |
| `style` | 문체 규칙 요약([BP-43](43_content_style_guide.md)) |
| `targets` | 쓰기 대상 팩의 ID 접두, 이미 쓰인 슬러그 목록(충돌 회피), `retiredIds` |
| `budget` | `{ requested, used, truncated: [...] }` |

- **R-31-16** `context` 는 **읽기 전용**이며 어떤 파일도 만들지 않는다.
- **R-31-17** 예산 초과 시 무엇을 잘랐는지 `budget.truncated` 로 반드시 보고한다. 조용한 절단은 생성 품질 저하의 원인을 감춘다(P5 의 정신).

---

### 2.9 미리보기 PNG — 30·31번

맵 `preview.png`(`ai_api.ts:778-811`)와 같은 규약: `image/png` 를 직접 반환한다.

**기존 규약의 실측 — "크기 상한을 넘으면 400" 은 사실이 아니다**(F-31-02).

| 조건 | 기존 맵 `preview.png` 의 실제 동작 |
|---|---|
| 요청 영역이 맵과 겹치지 않음(`r.w === 0 \|\| r.h === 0`) | **400** + hint `x/y/w/h 가 맵 범위 안에 오도록 조정할 것` (`:787-793`) |
| 배율이 범위 밖 | **조용히 클램프** — `Math.max(2, Math.min(48, tile))` (`:794`) |
| 시야 반경이 범위 밖 | **조용히 클램프** — `Math.max(1, Math.min(5, sight))` (`:804`) |
| 렌더 칸 수가 큼 | **상한 없음.** 20,000칸 상한은 `/region`(`:648`)과 `/passability`(`:751`)에만 있다 |

- **R-31-17a** (F-31-02) 따라서 그래프 PNG 도 **범위 밖 배율은 클램프**하고(`scale` 1~4),
  **그릴 대상이 없을 때만 400** 을 낸다. 노드 수 상한을 400 으로 만들 것인지는
  "기존과 같은 규약" 이라는 근거를 쓸 수 없는 **별도 결정**이다(→ Q-31-1).

| 엔드포인트 | 그리는 것 |
|---|---|
| `GET /api/content/quests/{id}/graph.png` | 스테이지 DAG. 노드=스테이지(제목·목표 수), 간선=`next`. 조건 분기는 점선 + 조건 요약 라벨 |
| `GET /api/content/dialogues/{id}/graph.png` | 대화 그래프. 노드=대화 노드(줄 수), 간선=`next`/`choices`. 선택지는 라벨 부착 |

| 쿼리 | 기본 | 의미 |
|---|---|---|
| `scale` | `2` | 1~4. 범위 밖 값은 **조용히 클램프**(기존 `tile` 과 동형, R-31-17a) |
| `highlight` | — | 강조할 노드/스테이지 id(쉼표 구분) |
| `problems` | `1` | 도달 불가 노드를 **빨강**, 종료 도달 불가를 **주황**, 고아를 **회색**으로 칠한다 |
| `legend` | `1` | 범례 표시 |

```bash
curl -s "http://localhost:5310/api/content/dialogues/dlg.gen_ep1.wife_plea/graph.png?scale=2&problems=1" -o dlg.png
```

- **R-31-18** 색 규약은 기존 미리보기의 이벤트 테두리 색과 **충돌하지 않는 별개 팔레트**를 쓴다. 기존은 타입 색(마젠타=TALK 등, `preview.ts:26-33`)이고 그래프는 **문제 색**이다. 범례에 그 차이를 명시한다.
- **R-31-19** 그래프 렌더링은 `pngjs` 로 직접 그린다(격자 배치 + 직선 간선). Graphviz 같은 외부 바이너리에 의존하지 않는다 — 부트스트랩 요구사항([BP-30 §7.1](30_toolchain_overview.md))을 늘리지 않기 위해서다.
- **Q-31-1** 노드가 40개를 넘는 대화 그래프에서 격자 배치는 읽기 어려워진다. 계층 배치(Sugiyama) 최소 구현을 넣을지, 아니면 40 초과 시 400 + "`?focus=<nodeId>&depth=2` 로 부분 조회" 를 안내할지 미정. 잠정: 후자. **단 이 상한은 기존 맵 규약의 계승이 아니라 신규 정책이다**(R-31-17a) — 기존은 클램프이고, 그래프에는 "클램프" 에 해당하는 동작(자동 부분 조회)이 존재하므로 그쪽이 더 자연스러울 수 있다.

---

## 3. 배치 편집 규약

### 3.1 왜 배치인가

맵 API 의 `AI_GUIDE.md` 는 "**여러 편집은 반드시 한 호출에 모을 것**" 을 굵게 적어 두었다. 콘텐츠에서는 그 이유가 더 강하다 — 퀘스트 1건은 그 자체로는 유효하지 않고(대화·문자열·앵커가 함께 있어야 검증을 통과), 중간 상태를 커밋하면 **검증 신호가 잡음이 된다**.

### 3.2 op 집합 (16종)

`POST /api/content/edit` 의 `ops` 배열. `POST /api/content/anchors/{map}/edit` 는 이 중 앵커·타일 op 6종만 받는다.
**개수를 본문 여기저기에 박지 않는다** — 다른 절은 "§3.2 표 전량" 으로 참조한다(초판이 "15종" 을 5곳에
박아 두고 실제로는 16개를 열거해 어긋났다).

| # | `op` | 필수 필드 | 의미 | 대응 REST |
|---:|---|---|---|---|
| 1 | `create_entity` | `collection`, `id`, `body` | 엔티티 생성 | 8번 |
| 2 | `update_entity` | `collection`, `id`, `patch` | Merge Patch 적용 | 10번 |
| 3 | `delete_entity` | `collection`, `id`, `reason` | 삭제 + 은퇴 등재 | 11번 |
| 4 | `set_field` | `target`, `path`, `value` | JSON Pointer 경로에 값 설정 | — |
| 5 | `unset_field` | `target`, `path` | 경로 삭제 | — |
| 6 | `array_insert` | `target`, `path`, `index`, `value` | 배열 삽입(`index: -1` = 끝) | — |
| 7 | `array_remove` | `target`, `path`, `index` \| `match` | 배열 제거 | — |
| 8 | `array_move` | `target`, `path`, `from`, `to` | 배열 순서 변경(스테이지·노드 재정렬) | — |
| 9 | `add_anchor` | `map`, `kind`, `x`, `y`, kind 필드 | 앵커 추가(+타일) | 15번 |
| 10 | `move_anchor` | `id`, `x`, `y` | 앵커+타일 이동 | 18번 |
| 11 | `update_anchor` | `id`, `patch` | 앵커 필드 수정 | 17번 |
| 12 | `remove_anchor` | `id`, `cleanupTile?` | 앵커 제거 | 19번 |
| 13 | `set_tile` | `map`, `layer`, `x`, `y`, `value`\|`a5`\|`b` | 맵 타일 편집(앵커와 원자적으로 묶기 위한 통로) | `/api/ai/maps/{f}/edit` |
| 14 | `set_string` | `key`, `text` | 문자열 upsert(키를 이미 아는 경우) | 21번 |
| 15 | `mint_string` | `owner`, `slot`, `text` | 텍스트 → 키 발급 후 upsert | 22번 |
| 16 | `set_migration` | `map`, `state`, `since?`, `evidence?` | 이관 상태 기록([BP-28 §3.2](28_migration_and_coexistence.md)) | 16번 |

`target` 은 `"<collection>:<id>"` 또는 `"anchors:<MAPNAME>"` 또는 `"pack:<packId>"` 형태다.
`path` 는 RFC 6901 JSON Pointer (`/stages/1/objectives/0/params/count`).

- **R-31-20** op 4~8(경로 편집)은 **`set_tile` 계열과 달리 어떤 의미 검증도 하지 않는다.** 경로가 존재하는지·타입이 맞는지만 본다. DSL 유효성은 CLI 가 본다.
- **R-31-21** 알 수 없는 `op` 는 400 `unknown_op` 이며 hint 가 **§3.2 표의 op 전량**(현재 16종)을 나열한다. 개수가 아니라 **표가 계약**이다. 맵 API 가 `set | rect | fill | setCells | resize | setDisplayName` 을 그대로 나열하는 것(`ai_api.ts:331`)과 같은 방식이다.

### 3.3 원자성 — 2단계 커밋

```
1. 워킹셋 구성   touched 파일 전량을 디스크에서 읽어 메모리 복사본을 만든다
2. rev 확인      요청의 ifRev 와 대조 (없으면 생략)
3. op 순차 적용  워킹셋에만 적용. 실패하면 즉시 중단하고 3-2 로
   3-1 성공 → 4
   3-2 실패 → 디스크 무변경 상태로 4xx 반환. 적용된 op 수를 appliedBeforeFailure 로 보고
4. 사후 검증     정규화(BP-21 §8) + 형태 검증
   앵커 도달 가능성은 커밋을 막지 않는다 — 경고만 (R-31-6c, D-27)
   실패 → 디스크 무변경, 4xx
5. 커밋          파일마다 tmp 작성 → 전부 성공하면 rename 을 연속 수행
6. 응답          파일별 새 rev + results[] + warnings[]
```

- **R-31-22** 5단계의 `rename` 은 파일 개수만큼 나뉘므로 **완전한 원자성은 불가능**하다(POSIX 는 다중 rename 원자성을 주지 않는다). 대신 다음을 보장한다:
  (a) tmp 작성이 모두 성공한 뒤에만 rename 을 시작한다 → 실패의 절대 다수(디스크 부족·권한)를 rename 이전에 걸러낸다.
  (b) rename 도중 실패하면 이미 rename 된 파일을 **백업본으로 되돌린다**(커밋 전 원본을 `.bak` 으로 복사해 둔다).
  (c) 되돌리기까지 실패하면 `500 partial_commit` + `hint: "git status 로 확인하고 git checkout 으로 되돌리세요"` 를 반환한다. 소스 트리가 git 관리라는 전제가 최종 안전망이다(맵 에디터 `README.md` 의 "되돌리기는 git으로" 와 같은 입장).
- **R-31-23** 한 배치가 건드릴 수 있는 파일 수 상한은 **32개**다. 초과 시 400 `too_many_files` + "팩·맵 단위로 나눠 호출" 을 안내한다. 상한이 없으면 실패 시 되돌릴 범위가 통제 불가능해진다.

### 3.4 순서·부분 실패·dryRun

| 항목 | 규약 |
|---|---|
| 순서 | 배열 순서대로 적용한다. 재정렬하지 않는다 |
| 앞선 op 의 결과 참조 | 가능하다. `create_entity` 로 만든 엔티티를 뒤의 `set_field` 가 고칠 수 있다 |
| 부분 실패 | **없다.** 첫 실패에서 전체 중단, 디스크 무변경 |
| 실패 응답 | `{ error, code, hint, failedOpIndex, appliedBeforeFailure, results }` — `results` 는 실패 전까지의 **가상** 결과(디스크에는 없음)임을 `committed: false` 로 명시 |
| `dryRun: true` | 1~4단계만 수행하고 5단계를 건너뛴다. 응답 형태는 동일하되 `committed: false`, rev 는 현재 값 |
| `dryRun` 안의 `mint_string` | **키를 실제로 발급하지 않고 유도한다.** 키는 `owner`+`slot` 의 **순수 함수**([BP-21 R-21-24](21_content_pack_spec.md))이므로 dryRun 과 실행이 같은 값을 낸다 — 그래서 같은 배치의 뒤쪽 op 가 그 키를 참조하는 §3.4 예시가 dryRun 에서도 성립한다(S-31-02). 연번이 붙는 슬롯(`line.0`, `line.1` …)은 **현재 파일 상태 + 배치 내 순서**로 결정되며, 이 역시 결정론적이다 |
| 알 수 없는 최상위 필드 | 400 `unknown_field`. 무시하지 않는다(P5) |

```bash
curl -s -X POST http://localhost:5310/api/content/edit \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "pack": "gen_ep1",
  "dryRun": true,
  "ops": [
    { "op": "create_entity", "collection": "items", "id": "item.gen_ep1.scholar_notebook",
      "body": { "id": "item.gen_ep1.scholar_notebook", "type": "item", "pack": "gen_ep1",
                "name": "str.gen_ep1.item.scholar_notebook.name", "questItem": true, "stackable": false } },
    { "op": "mint_string", "owner": "item.gen_ep1.scholar_notebook", "slot": "name", "text": "학자의 수첩" },
    { "op": "add_anchor", "map": "DEN1", "kind": "container", "slug": "den1_notebook", "x": 31, "y": 18,
      "contents": [ { "item": "item.gen_ep1.scholar_notebook", "count": 1 } ], "once": true },
    { "op": "array_insert", "target": "quests:quest.gen_ep1.missing_scholar",
      "path": "/stages/2/objectives", "index": -1,
      "value": { "id": "acquire_notebook", "kind": "acquire",
                 "params": { "itemId": "item.gen_ep1.scholar_notebook", "count": 1 } } }
  ]
}
JSON
```

```json
{ "ok": true, "committed": false, "dryRun": true, "pack": "gen_ep1",
  "results": [
    { "op": "create_entity", "id": "item.gen_ep1.scholar_notebook", "file": "gen_ep1/items/items.json", "changed": 1 },
    { "op": "mint_string",   "key": "str.gen_ep1.item.scholar_notebook.name", "changed": 1 },
    { "op": "add_anchor",    "id": "anchor.gen_ep1.den1_notebook", "tilePlaced": true, "changed": 2 },
    { "op": "array_insert",  "path": "/stages/2/objectives", "changed": 1 }
  ],
  "touchedFiles": ["gen_ep1/items/items.json","gen_ep1/strings/ko.json",
                   "gen_ep1/anchors/DEN1.json","DEN1.json","gen_ep1/quests/missing_scholar.json"],
  "totalChanged": 5,
  "warnings": ["DEN1 은 아직 migration.state 가 없음 — set_migration op 로 legacy/shadowed 를 명시할 것"] }
```

실패 예:

```json
{ "error": "op[3] array_insert: 경로 /stages/2/objectives 가 없습니다 (stages 길이 2).",
  "code": "bad_path",
  "hint": "GET /api/content/quests/quest.gen_ep1.missing_scholar 로 현재 stages 를 확인하세요. 스테이지를 먼저 추가하려면 array_insert path=/stages 를 앞에 두세요.",
  "failedOpIndex": 3, "appliedBeforeFailure": 3, "committed": false }
```

---

## 4. 동시성 — `rev` 규약

### 4.1 rev 의 정의

맵 API 와 **완전히 같다**: 파일 mtime(ms)의 문자열(`store.ts:34-36`). 새 저장소·해시·버전 카운터를 도입하지 않는다.

| 대상 | rev 의 출처 |
|---|---|
| 엔티티(1파일 1엔티티) | 그 파일의 mtime |
| 엔티티(N-엔티티 파일) | **파일 전체**의 mtime. 같은 파일의 다른 아이템을 고쳐도 충돌한다(보수적) |
| 앵커 | `<pack>/anchors/<MAP>.json` 의 mtime |
| 문자열 | `<pack>/strings/<lang>.json` 의 mtime |
| 맵 | `maps/<file>.json` 의 mtime (기존 규약 그대로) |
| 팩 | `pack.json` 의 mtime |

### 4.2 쓰기 요청의 `ifRev`

| 형태 | 사용처 |
|---|---|
| `"ifRev": "1756512345678"` | 파일 1개만 건드리는 요청(엔티티 PATCH, 문자열 PATCH) |
| `"ifRev": { "anchors": "…", "map": "…" }` | 앵커 이동·생성 |
| `"ifRev": { "gen_ep1/quests/missing_scholar.json": "…", "DEN1.json": "…" }` | 배치 편집(파일 경로 키) |
| 생략 | 검사 없이 덮어쓴다 |

- **R-31-23a** (S-31-04) 위 3형태는 **하나의 union 타입**이다: `string | Record<string, string>`.
  문자열 형태는 "요청이 건드리는 유일한 파일" 을 가리키는 축약이고, 객체 형태는 논리 키(`anchors`/`map`)
  또는 파일 경로 키를 쓴다. MCP 스키마(§6.1)도 `z.union([z.string(), z.record(z.string())])` 로 적어야 하며,
  `z.record` 단독이면 문자열 형태를 받지 못한다.
- **R-31-24** `ifRev` 는 **선택**이다. 강제하면 에이전트가 매번 GET 을 선행해야 해서 호출 수가 배로 늘고, 대부분의 생성 작업은 새 파일을 만드는 것이라 충돌 위험이 없다.
- **R-31-25** 다만 **`PATCH`·`move`·`delete` 는 `ifRev` 를 권장**하고, 생략 시 응답 `warnings` 에 `no_ifrev` 를 남긴다. 생성(`POST`)은 409 `id_exists` 가 이미 보호한다.
- **R-31-26** 충돌 응답은 맵 API 와 같은 필드를 쓴다 — `currentRev` (`vite.config.ts:87-91`).

```json
{ "error": "gen_ep1/quests/missing_scholar.json 이 외부에서 변경됨",
  "code": "rev_conflict",
  "currentRev": "1756512999000",
  "yourRev": "1756512345678",
  "hint": "GET /api/content/quests/quest.gen_ep1.missing_scholar 로 최신본을 다시 읽고, 변경을 그 위에 다시 적용한 뒤 새 rev 로 재시도하세요.",
  "diffSummary": { "changedFields": ["stages[1].objectives", "tags"] } }
```

- **R-31-27** 409 응답에 `diffSummary` 를 실어 준다. 에이전트가 "내 변경과 겹치는가" 를 재조회 없이 1차 판단할 수 있다. 맵 API 의 409 에는 없던 개선이며, 맵과 달리 콘텐츠는 필드 단위 diff 가 쉽기 때문에 가능하다.

### 4.3 브라우저가 보고 있는 동안 AI 가 쓰는 경우

현행 브라우저 에디터는 2초마다 `/api/map/rev` 를 폴링해 외부 변경을 감지하고 자동 리로드한다(단, 사각형 드래그 중이거나 사이드바 입력에 포커스가 있으면 미룬다 — DEVLOG §5). 콘텐츠도 **같은 방식**을 따른다.

| 시나리오 | 동작 |
|---|---|
| AI 가 앵커만 추가 | 브라우저는 `/api/content/rev?path=<pack>/anchors/TOWN1.json` 폴링으로 감지 → 앵커 오버레이만 다시 그린다(맵 데이터는 미변경이므로 캔버스 base 는 유지) |
| AI 가 앵커 + 타일을 함께 이동 | 맵 rev 도 바뀌므로 기존 맵 리로드 경로가 그대로 발동 → 앵커 오버레이도 함께 갱신 |
| 사람이 편집 중(dirty)인데 AI 가 같은 맵을 씀 | 기존 정책 유지: 자동 리로드하지 않고 **저장 시 409** 로 알린다(`api.ts:44-49` `SaveConflictError`) |
| 사람이 앵커 인스펙터에 타이핑 중 | 폴링 갱신을 미룬다(기존 `hasPendingInput()` 가드에 앵커 패널 입력을 추가 — [BP-36 §2](36_map_editor_extension.md)) |
| 사람이 브라우저에서 앵커를 옮김 | 브라우저는 `POST /api/content/anchors/{id}/move` 를 호출한다. **저수준 PUT 을 쓰지 않는다** — 그래야 사람의 이동도 AI 의 이동과 같은 도달 가능성 검사를 거친다 |
| **AI 가 썼고 사람은 아직 저장하지 않았다** | **사람 쪽 변경이 사라진다.** AI 의 쓰기는 `ifRev` 를 생략하면 선행조건 검사를 받지 않으므로(R-31-24, §1.1 P6 실측) 디스크가 먼저 바뀌고, 브라우저는 dirty 상태라 자동 리로드하지 않는다. 사람이 나중에 저장하면 409 가 나지만 **그 시점에는 이미 AI 의 결과 위에 덮어쓸지를 고르는 문제**가 된다 |

**위 마지막 행의 완화책 3개** (F-31-03 — 초판은 이 시나리오를 표에 두지 않았다)

| # | 완화 | 한계 |
|---|---|---|
| (a) | 브라우저는 2초 폴링으로 rev 변화를 보고, **dirty 상태라면 자동 리로드 대신 배너**를 띄운다: "이 맵/앵커가 외부에서 변경되었습니다 — 저장하면 그 변경을 덮어씁니다. `[비교]` `[버리고 새로 읽기]`" | 사람이 배너를 무시할 수 있다 |
| (b) | `hasPendingInput()` 가드(DEVLOG §5)가 입력 중 갱신을 미루므로 **타이핑 중 값이 튀지 않는다** | 포커스가 남은 채 방치되면 가드가 계속 참이다(→ [BP-36 S-36-06](36_map_editor_extension.md)) |
| (c) | **`set_tile` op 와 앵커 이동은 `ifRev.map` 을 권장으로 강제**한다 — 생략 시 응답 `warnings` 에 `no_ifrev` 가 남고(R-31-25), 앵커+타일 원자성([BP-26 R-26-22](26_entity_registry_and_anchors.md))이 실효를 갖는 유일한 조건이 이것이다 | 필수로 만들면 호출 수가 배로 늘어난다(R-31-24 의 근거) |

- **R-31-27a** (F-31-03) **`ifRev` 를 필수로 만들지 않는다는 결정은 "AI 가 사람을 덮어쓸 수 있다" 를
  받아들이는 결정이다.** 그것을 문서에 적어 두지 않으면 다음 사람이 P6("낙관적 잠금 계승")을 읽고
  보호가 있다고 오해한다. 최종 안전망은 git 이며(R-31-22), 그것이 이 도구가 **localhost dev 도구**인
  이유이기도 하다.

- **R-31-28** 브라우저 UI 도 앵커에 관해서는 **`/api/content/*` 를 쓴다.** 맵 타일처럼 "UI 는 저수준 PUT, AI 는 시맨틱 API" 로 나누지 않는다. 앵커는 편집 단위가 작고 정합 검사가 필수라 시맨틱 API 가 UI 에도 최적이다.
- **R-31-29** 서버는 **프로세스 내 파일 단위 쓰기 락**(Promise 체인)을 둔다. Node 는 단일 스레드지만 `await` 사이에 다른 요청이 끼어들 수 있으므로, 읽기→수정→쓰기 구간을 파일 키로 직렬화한다. 락 대기 5초 초과 시 `423 locked`.
- **Q-31-2** 폴링(2초)을 SSE 로 바꾸면 앵커 편집 반응성이 좋아지지만 Vite dev 미들웨어에 스트리밍 엔드포인트를 추가해야 한다. [BP-36](36_map_editor_extension.md) 이 판단한다.

---

## 5. 에러 카탈로그

**규약**: 모든 에러는 `{ "error": string, "code": string, "hint"?: string, ...추가 }` 이다.
`error`+`hint` 는 기존 맵 API 규약 그대로이고 `code` 만 **추가**되므로, 기존 클라이언트(`mcp/server.mjs` 포함)는 변경 없이 동작한다.

- **R-31-30** `hint` 는 **행동 지시**여야 한다. "잘못된 값입니다" 는 금지. 다음 셋 중 하나를 담는다: (a) 허용값 전량, (b) 그대로 보낼 수 있는 다음 요청, (c) 실행할 명령.

### 5.1 400 — 요청이 잘못됨

| code | 언제 | hint 예 |
|---|---|---|
| `bad_json` | 본문 JSON 파싱 실패 | `요청 본문의 JSON 문법을 확인하세요. 위치: line 4 col 12` |
| `unknown_field` | 최상위에 모르는 필드 | `허용 필드: pack, ops, dryRun, ifRev. 오타로 보이는 것: "op" → "ops"` |
| `bad_collection` | `{collection}` 미지원 | `허용: quests, dialogues, actors, items, places, factions, encounters` |
| `bad_id` | ID 정규식 위반 | `형식은 <type>.<pack>.<slug> 입니다. 예: quest.gen_ep1.missing_scholar` |
| `bad_slug` | 슬러그 규칙 위반([BP-21 §4.3](21_content_pack_spec.md)) | `슬러그는 소문자/숫자/_ 3~48자, 영문으로 시작, 연속 __ 금지. "Missing-Scholar" → "missing_scholar"` |
| `id_collection_mismatch` | 접두사 불일치 | `POST /api/content/quests 에는 quest.* ID 가 필요합니다. dlg.* 는 /api/content/dialogues 로 보내세요` |
| `slug_file_mismatch` | 파일명 ≠ 슬러그(R-21-6) | `파일 gen_ep1/quests/a.json 에 id ...missing_scholar 를 넣을 수 없습니다. 파일명을 missing_scholar.json 으로 하세요` |
| `bad_string_key` | 문자열 키 정규식 위반 | `형식: str.<pack>.<owner_type>.<owner_slug>.<slot>. 예: str.gen_ep1.quest.missing_scholar.title` |
| `inline_text` | 소스 필드에 한글/색상 태그 직접 기입(R-21-21) | `"사라진 학자" 를 str.gen_ep1.quest.missing_scholar.title 로 옮기세요. POST /api/content/strings/mint {"pack":"gen_ep1","items":[{"owner":"quest.gen_ep1.missing_scholar","slot":"title","text":"사라진 학자"}]}` |
| `unbalanced_color_tag` | `@X…@@` 불균형([BP-21 §5.5](21_content_pack_spec.md)) | `@B 를 열었으면 @@ 로 닫으세요. 문제 위치: 12번째 글자` |
| `unknown_op` | 모르는 op | `허용 op: create_entity \| update_entity \| delete_entity \| set_field \| unset_field \| array_insert \| array_remove \| array_move \| add_anchor \| move_anchor \| update_anchor \| remove_anchor \| set_tile \| set_string \| mint_string \| set_migration` |
| `missing_field` | op 필수 필드 누락 | `add_anchor 에는 map, kind, x, y 가 필요합니다` |
| `bad_path` | JSON Pointer 미존재 | (§3.4 예시 참조) |
| `coord_out_of_range` | 좌표가 맵 밖 | `TOWN1 은 100×100 입니다. x 는 0~99` |
| ~~`anchor_tile_mismatch`~~ | **은퇴**(D-27). 앵커-타일 정합은 400 이 아니라 **`warning` 진단** `anchor_unreachable` 로만 보고된다(§2.5, §2.7). R-31-31 에 따라 코드는 지우지 않고 은퇴로 남긴다 | (요청을 거부하지 않으므로 400 카탈로그에 없다) |
| `anchor_tile_occupied` | 자동 배치 자리에 다른 오브젝트(R-26-32) | (§2.5 예시) |
| `dialogue_and_lines` | `sign` 앵커에 둘 다(A-26-09) | `dialogue 와 lines 중 하나만 두세요` |
| `use_move_endpoint` | PATCH 로 좌표 변경 시도 | `POST /api/content/anchors/{id}/move {"x":36,"y":12} 를 쓰세요` |
| `immutable_field` | `id`/`pack`/`schemaVersion` 수정 시도 | `id 는 불변입니다(D-04). 새 ID 로 만들고 기존 것은 DELETE 로 은퇴시키세요` |
| `too_many_files` | 배치가 32파일 초과(R-31-23) | `팩 또는 맵 단위로 나눠 호출하세요. 현재 41개` |
| `reserved_pack` | 예약 팩 이름 | `예약어: build, core_internal, tmp, test, debug, system, hadar, null, none` |
| `dependency_cycle` | `dependsOn` 순환 | `gen_ep1 → gen_ep2 → gen_ep1 순환. dependsOn 을 끊으세요` |
| `bad_scope` | validate/lint 의 scope 형식 오류 | `scope 는 all \| pack:<id> \| map:<NAME> \| <entityId>` |

### 5.2 404 / 409 / 423 / 5xx

| code | 상태 | 언제 | hint 예 |
|---|---|---|---|
| `pack_not_found` | 404 | 팩 미존재 | `GET /api/content/packs 로 확인하거나 POST /api/content/packs 로 만드세요` |
| `entity_not_found` | 404 | 엔티티 미존재 | `GET /api/content/quests?q=scholar 로 유사 ID 를 찾으세요` |
| `anchor_not_found` | 404 | 앵커 미존재 | `GET /api/content/anchors/TOWN1 로 목록을 확인하세요` |
| `map_not_found` | 404 | `MapInfos.json` 에 없는 맵 이름 | `등록 이름: Test, LORE_EP, MAP003, TOWN1, GROUND1, DEN1, DEN2, … / 새 맵은 POST /api/ai/maps 의 registerAs 로 등록` |
| `guide_missing` | 500 | 가이드 파일 없음 | `tools/mapEditor/CONTENT_AI_GUIDE.md 가 있는지 확인하세요` |
| `id_exists` | 409 | 이미 있는 ID | `수정하려면 PATCH /api/content/quests/{id} 를 쓰세요` |
| `pack_exists` | 409 | 이미 있는 팩 | `PATCH /api/content/packs/{id} 로 수정하세요` |
| `retired_id` | 409 | 은퇴 ID 재사용([BP-21 §4.6](21_content_pack_spec.md)) | `이 ID 는 2026-09-02 에 은퇴했습니다. 다른 슬러그를 쓰세요` |
| `has_references` | 409 | 참조가 남은 채 삭제 | (§2.4 예시 — 참조자 목록 동봉) |
| `rev_conflict` | 409 | rev 불일치 | (§4.2 예시 — `currentRev`, `diffSummary` 동봉) |
| `locked` | 423 | 파일 쓰기 락 대기 초과(R-31-29) | `다른 요청이 같은 파일을 쓰는 중입니다. 1초 뒤 재시도하세요` |
| `source_corrupt` | 500 | 소스 JSON 손상 | `gen_ep1/quests/x.json 을 직접 열어 고치거나 git checkout 으로 되돌리세요` (맵 API 의 동일 상황 처리 `store.ts:51-60` 계승) |
| `partial_commit` | 500 | rename 도중 실패 후 되돌리기 실패(R-31-22c) | `git status 로 확인하고 git checkout 으로 되돌리세요` |
| `cli_failed` | 500 | CLI 가 3 을 반환 | `stderr: … / dart run tools/content_cli/bin/hadar_content.dart validate --all 로 직접 실행해 보세요` |
| `cli_unavailable` | 503 | `dart` 미발견([BP-30 Q-30-3](30_toolchain_overview.md)) | `Dart SDK 를 설치하거나 HADAR_DART_BIN 환경변수로 경로를 지정한 뒤 서버를 재시작하세요` |
| `sim_timeout` | 504 | 120초 초과(R-31-14) | `maxSteps 를 줄이거나 CLI 로 직접: hadar_content sim --quest … --policy greedy` |

- **R-31-30a** 카탈로그의 크기(현재 **39종**)를 계약으로 삼지 않는다. 계약은 **§5.1·§5.2 의 표 자체**이며,
  구현은 그 표를 기계적으로 상수 목록으로 옮긴다. 개수를 본문에 박으면 표가 늘 때마다 어긋난다.
- **R-31-31** 에러 코드는 **추가만 가능하고 의미를 바꾸지 않는다.** 코드를 없앨 때는 가이드 문서에 은퇴로 남긴다. 에이전트가 코드로 분기하는 순간 이것도 계약이 된다.

---

## 6. MCP 도구 매핑표

기존 `mcp/server.mjs` 의 등록 방식을 그대로 따른다 — `tool(name, description, zodShape, fn)` 헬퍼(**`:47-56`**)로 텍스트 결과 도구를, `server.registerTool(...)` 직접 호출로 이미지 결과 도구를 등록한다(**`preview` `:201-235`**, **`tile_image` `:237-256`**). 에러는 던져서 `isError: true` 텍스트로 반환된다.

`api()`/`apiPng()` 헬퍼는 `mcp/lib/http.mjs` 로 추출해 두 서버가 공유한다([BP-30 §5.1](30_toolchain_overview.md)).

### 6.1 도구 28종

| # | MCP 도구 | REST | 입력 스키마 요약 |
|---:|---|---|---|
| 1 | `content_guide` | `GET /api/content` | `{}` |
| 2 | `content_status` | `GET /api/content/status` | `{}` |
| 3 | `content_packs` | `GET /api/content/packs` | `{}` |
| 4 | `content_pack_get` | `GET /api/content/packs/{id}` | `{ id }` |
| 5 | `content_pack_create` | `POST /api/content/packs` | `{ id, title, dependsOn?, description?, generatedBy? }` |
| 6 | `content_list` | `GET /api/content/{collection}` | `{ collection, pack?, q?, tag?, full?, limit?, offset? }` |
| 7 | `content_get` | `GET /api/content/{collection}/{id}` | `{ collection, id, strings?, resolve? }` |
| 8 | `content_create` | `POST /api/content/{collection}` | `{ collection, id, body }` |
| 9 | `content_update` | `PATCH /api/content/{collection}/{id}` | `{ collection, id, patch, ifRev? }` |
| 10 | `content_delete` | `DELETE /api/content/{collection}/{id}` | `{ collection, id, reason, force? }` |
| 11 | `content_edit` | `POST /api/content/edit` | `{ pack, ops: object[], dryRun?, ifRev? }` |
| 12 | `content_anchors_at` | `GET /api/content/anchors` | `{ map?, x?, y?, actor?, kind?, pack? }` |
| 13 | `content_anchors_get` | `GET /api/content/anchors/{map}` | `{ map }` |
| 14 | `content_anchor_create` | `POST /api/content/anchors` | `{ pack, map, kind, x, y, slug?, actor?, dialogue?, to?, effects?, contents?, encounter?, facing?, autoPlaceTile? }` |
| 15 | `content_anchors_edit` | `POST /api/content/anchors/{map}/edit` | `{ map, pack, ops: object[], dryRun? }` |
| 16 | `content_anchor_move` | `POST /api/content/anchors/{id}/move` | `{ id, x, y, moveTile?, ifRev? }` |
| 17 | `content_strings_get` | `GET /api/content/strings/{lang}` | `{ lang?, pack?, prefix?, owner?, missing?, orphan? }` |
| 18 | `content_strings_patch` | `PATCH /api/content/strings/{lang}` | `{ lang?, pack, set?, remove?, ifRev? }` |
| 19 | `content_strings_mint` | `POST /api/content/strings/mint` | `{ pack, lang?, items: [{owner, slot, text}] }` |
| 20 | `content_validate` | `GET /api/content/validate` | `{ scope?, fix?, severity? }` |
| 21 | `content_lint` | `GET /api/content/lint` | `{ scope?, rules?, maxWarnings? }` |
| 22 | `content_build` | `POST /api/content/build` | `{ checkFormat?, fixFormat? }` |
| 23 | `content_sim` | `POST /api/content/sim` | `{ quest?, all?, policy?, seed?, maxSteps?, trace?, solve? }` |
| 24 | `content_refs` | `GET /api/content/refs/{id}` | `{ id }` |
| 25 | `content_graph` | `GET /api/content/graph/{questId}` | `{ questId?, dialogue? }` |
| 26 | `content_context` | `GET /api/content/context` | `{ for, pack, place?, map?, actors?, budget? }` |
| 27 | `content_quest_graph` 🖼 | `GET /api/content/quests/{id}/graph.png` | `{ id, scale?, highlight?, problems?, legend? }` |
| 28 | `content_dialogue_graph` 🖼 | `GET /api/content/dialogues/{id}/graph.png` | `{ id, scale?, highlight?, problems?, legend? }` |

🖼 = `{ type: "image", data: <base64>, mimeType: "image/png" }` 를 반환(맵 서버의 `preview`/`tile_image` 와 동일).

**전용 도구가 없는 REST 라우트** (API_MANUAL.md 가 맵 쪽에서 그렇게 하듯 정직하게 남긴다):

| REST | 대체 |
|---|---|
| `PATCH /api/content/packs/{id}` | `content_edit` 의 `set_field` (`target: "pack:gen_ep1"`) |
| `PATCH /api/content/anchors/{id}` | `content_anchors_edit` 의 `update_anchor` |
| `DELETE /api/content/anchors/{id}` | `content_anchors_edit` 의 `remove_anchor` |

### 6.2 등록 코드 형태 (기존 `mcp/server.mjs` 와 동형)

```js
// tools/mapEditor/mcp/content_server.mjs
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { api, apiPng } from './lib/http.mjs';   // BASE = HADAR_EDITOR_URL ?? http://localhost:5310

const server = new McpServer({ name: 'hadar-content', version: '0.1.0' });

function tool(name, description, shape, fn) {
  server.registerTool(name, { description, inputSchema: shape }, async (args) => {
    try { return { content: [{ type: 'text', text: await fn(args) }] }; }
    catch (e) { return { content: [{ type: 'text', text: String(e.message ?? e) }], isError: true }; }
  });
}

const COLLECTIONS = ['quests', 'dialogues', 'actors', 'items', 'places', 'factions', 'encounters'];
const collectionArg = z.enum(COLLECTIONS).describe('엔티티 컬렉션');
const packArg = z.string().describe('팩 id, 예: "gen_ep1"');

tool(
  'content_guide',
  '콘텐츠 팩 포맷·ID 규칙·Condition/Effect DSL·앵커·워크플로 전체 가이드(markdown). ' +
    '다른 content_* 도구를 쓰기 전에 반드시 한 번 읽을 것.',
  {},
  () => api('GET', '/api/content/guide'),
);

tool(
  'content_edit',
  '콘텐츠 배치 편집. ops 를 순서대로 적용하고 전부 성공해야 저장한다(부분 적용 없음). ' +
    'op 종류: create_entity | update_entity | delete_entity | set_field | unset_field | ' +
    'array_insert | array_remove | array_move | add_anchor | move_anchor | update_anchor | ' +
    'remove_anchor | set_tile | set_string | mint_string | set_migration. ' +
    '퀘스트 1건은 반드시 한 호출에 모을 것. 먼저 dryRun:true 로 확인 권장.',
  {
    pack: packArg,
    ops: z.array(z.record(z.any())).describe('예: [{"op":"create_entity","collection":"quests","id":"quest.gen_ep1.x","body":{…}}]'),
    dryRun: z.boolean().optional().describe('true 면 검증만 하고 저장하지 않는다'),
    ifRev: z.record(z.string()).optional().describe('{ "<파일경로>": "<rev>" } 낙관적 잠금'),
  },
  (args) => api('POST', '/api/content/edit', args),
);

tool(
  'content_anchor_move',
  '앵커를 옮긴다. 맵 타일도 함께 옮겨지고(기본), 정합 검사에 실패하면 아무것도 바뀌지 않는다.',
  {
    id: z.string().describe('앵커 id, 예: "anchor.core.town1_gate_guard"'),
    x: z.number().int(), y: z.number().int(),
    moveTile: z.boolean().optional().describe('기본 true. false 면 앵커만 옮긴다'),
    ifRev: z.record(z.string()).optional(),
  },
  ({ id, ...body }) => api('POST', `/api/content/anchors/${encodeURIComponent(id)}/move`, body),
);

server.registerTool(
  'content_dialogue_graph',
  {
    description: '대화 그래프를 PNG 로 렌더링. 도달 불가 노드는 빨강, 종료에 못 닿는 노드는 주황, 고아는 회색.',
    inputSchema: {
      id: z.string(), scale: z.number().int().min(1).max(4).optional(),
      highlight: z.string().optional(), problems: z.boolean().optional(), legend: z.boolean().optional(),
    },
  },
  async (args) => {
    try {
      const q = new URLSearchParams();
      for (const k of ['scale', 'highlight']) if (args[k] !== undefined) q.set(k, String(args[k]));
      if (args.problems === false) q.set('problems', '0');
      if (args.legend === false) q.set('legend', '0');
      const data = await apiPng(`/api/content/dialogues/${encodeURIComponent(args.id)}/graph.png?${q}`);
      return { content: [{ type: 'image', data, mimeType: 'image/png' }] };
    } catch (e) { return { content: [{ type: 'text', text: String(e.message ?? e) }], isError: true }; }
  },
);

await server.connect(new StdioServerTransport());
```

- **R-31-32** 도구 `description` 은 **언제 쓰는지 + 함정**을 포함한다. 기존 맵 도구가 그렇게 되어 있다(`edit_map` 의 "여러 편집은 반드시 한 호출에 모을 것", `current_map` 의 "10초 내 활동 없으면 사용자에게 확인").
- **R-31-33** MCP 는 REST 응답 JSON 을 **가공하지 않고 그대로** 텍스트로 넘긴다. 요약·필드 제거를 하면 REST 와 MCP 의 동작이 갈라진다.

---

## 7. `GET /api/content` 가이드 문서 초안

파일: `tools/mapEditor/CONTENT_AI_GUIDE.md`. `AI_GUIDE.md` 와 마찬가지로 **에이전트가 이것만 읽고 작업할 수 있어야 한다.**

### 7.1 목차

```
# Hadar 콘텐츠 팩 — AI API 가이드
1. 이 문서로 무엇을 할 수 있나 / 없나
2. 권장 워크플로 (0~9단계)
3. 도메인 지식 (필수)
   3.1 3구획 파이프라인 — 당신은 Authoring 에 있다
   3.2 팩 · 디렉토리 · 파일당 엔티티 수
   3.3 ID 문법 3종과 슬러그 규칙
   3.4 문자열 키 — 한국어를 소스에 직접 쓰지 말 것
   3.5 Condition op 18 / Effect do 25 (닫힌 집합)
   3.6 퀘스트 = 스테이지 FSM / 대화 = 그래프
   3.7 앵커 — NPC 는 좌표가 아니라 정체성을 갖는다
   3.8 앵커는 맵 데이터에 표시를 남기지 않는다 (닿을 수 있는 자리에 두는 요령)
   3.9 이관 상태 4단계 (legacy/shadowed/migrated/frozen)
4. API 레퍼런스 (33 라우트)
5. 배치 편집 (ops — §3.2 표 전량)
6. 에러 코드와 복구 방법
7. 자주 하는 실수 10가지
8. 완전한 예제 — 퀘스트 1건을 처음부터 끝까지
```

### 7.2 초안 (발췌 — 실제 파일에 그대로 들어갈 문안)

````markdown
# Hadar 콘텐츠 팩 — AI API 가이드

이 문서는 AI 에이전트가 Hadar2026 의 **퀘스트·대화·NPC·아이템·앵커**를 만들기 위한 API 명세다.
`GET /api/content` 가 항상 이 문서를 반환한다. Base URL 은 맵 에디터와 같은 `http://localhost:5310`.

**맵(지형·타일)을 다루려면 `GET /api/ai` 를 읽어라.** 이 문서는 "의미" 를, 그쪽은 "지형" 을 담당한다.

## 1. 할 수 있는 것 / 없는 것

| 할 수 있다 | 할 수 없다 |
|---|---|
| 퀘스트·대화·액터·아이템·장소·인카운터 CRUD | 게임 코드(Dart) 수정 |
| 앵커 배치·이동(맵 타일이 함께 따라감) | 소스 파일 직접 쓰기 — **API 만 쓸 것** |
| 문자열 발급·수정 | 빌드 산출물(`build/*.json`) 직접 수정 |
| 검증·린트·시뮬레이션·빌드 실행 | git 조작(커밋은 사람이 한다) |

## 2. 권장 워크플로

0. `GET /api/content/status` — 팩이 있는지, 빌드가 최신인지, CLI 가 쓸 수 있는지 확인
1. `GET /api/content/context?for=quest&pack=<팩>&place=<장소>` — **세계관·기존 엔티티·DSL·문체 규칙을 한 번에** 받는다
2. 팩이 없으면 `POST /api/content/packs`
3. `POST /api/content/edit` 에 **`dryRun: true`** — 퀘스트 1건에 필요한 모든 것을 한 배치로
4. 경고가 없으면 `dryRun` 을 빼고 다시 호출 → 저장
5. `POST /api/content/anchors` 또는 배치의 `add_anchor` op 로 NPC·상자·트리거를 맵에 붙인다
6. `GET /api/content/validate?scope=pack:<팩>` — error 가 0 이 될 때까지 고친다
7. `GET /api/content/quests/{id}/graph.png` · `.../dialogues/{id}/graph.png` — 그림으로 자기 점검
8. `POST /api/content/sim {"quest":"…","policy":"greedy"}` — **완주 증명**. 실패하면 `hint` 를 따라 6번으로
9. `POST /api/content/build` — 산출물 갱신. 이후 사람이 커밋한다

> 3번에서 **반드시 `dryRun` 을 먼저 쓸 것.** 배치는 부분 적용이 없으므로, dryRun 이 통과하면 실제 저장도 거의 확실히 통과한다.

## 3.4 문자열 키 — 한국어를 소스에 직접 쓰지 말 것

콘텐츠 소스의 어떤 필드도 표시될 한국어 문장을 담지 않는다. 대신 키를 담는다.

```json
{ "title": "str.gen_ep1.quest.missing_scholar.title" }     ← 이렇게
{ "title": "사라진 학자" }                                   ← 400 inline_text
```

텍스트는 `strings/ko.json` 에 있고, 키는 서버가 만들어 준다:

```bash
curl -X POST http://localhost:5310/api/content/strings/mint -d '{
  "pack":"gen_ep1",
  "items":[{"owner":"quest.gen_ep1.missing_scholar","slot":"title","text":"사라진 학자"}]
}'
# → { "minted": { "quest.gen_ep1.missing_scholar|title": "str.gen_ep1.quest.missing_scholar.title" } }
```

배치 안에서는 `mint_string` op 를 쓴다. 같은 배치의 뒤쪽 op 가 발급된 키를 그대로 쓸 수 있다.

## 3.8 앵커는 맵 데이터에 표시를 남기지 않는다

**게임은 앵커를 트리거 인덱스에서 직접 찾는다.** 맵 타일이 무엇이든 앵커는 발화한다.
그러니 "타일을 안 놓아서 앵커가 안 먹는다" 는 걱정은 하지 않아도 된다.

타일이 중요한 이유는 딱 하나다 — **플레이어가 그 칸에 닿을 수 있어야 한다.**

- 말을 걸어야 하는 앵커(`actor`/`sign`/`container`/`portal(interact)`)는 그 칸이 **통행 불가**여야 한다.
  통행 가능하면 파티가 그냥 밟고 지나가서 마주 볼 대상이 없다.
- 밟아서 발동하는 앵커(`trigger`/`battle(step_on)`)는 그 칸이 **통행 가능**해야 한다. 놓을 타일은 없다.

`autoPlaceTile: true`(기본)면 서버가 권장 타일을 대신 놓아 준다. 이미 다른 오브젝트가 있으면
**거부**하고 hint 를 준다 — 덮어쓰지 않는다(`"force"` 로 덮어쓸 수 있다).

**kind 별 권장 타일의 정확한 값(B 대역·A5 대역)은 여기 적지 않는다.**
정본은 기획서 BP-26 §3.3 이고, 그 표는 값이 바뀔 수 있다.
`GET /api/content/anchors/{map}` 이 위반마다 그대로 붙여 넣을 수 있는 `set` op 를 hint 로 주므로,
표를 외울 필요가 없다.

**주의 — 조작 방식에 따라 다르게 동작하는 경우가 있다.**
현재 게임 코드에는 "벽에 부딪혀 상호작용" 경로에만 타일 액션 선검사가 남아 있다.
확인키로는 발화하지만 부딪혀서는 발화하지 않는 앵커가 생길 수 있고,
`GET /api/content/anchors/{map}` 이 그런 앵커를 `bump_gate_asymmetry` 로 알려 준다.
콘텐츠로는 회피할 수 없으니 그대로 보고하면 된다.

## 7. 자주 하는 실수 10가지

1. 소스에 한국어를 직접 씀 → `inline_text`. `mint_string` 을 쓸 것
2. 엔티티마다 호출을 쪼갬 → 중간 상태가 검증에 걸린다. **퀘스트 1건 = 배치 1회**
3. 앵커를 파티가 밟고 지나가는 칸에 둠 → `anchor_unreachable`(경고). `autoPlaceTile` 을 끄지 말 것
4. NPC 를 옮길 때 타일만 옮김 → 앵커가 남는다. `POST .../anchors/{id}/move` 를 쓸 것
5. **배치 op** 이름을 틀림(`add_entity` → `create_entity`) → `unknown_op` 400. hint 의 목록만 쓸 것.
   반면 **Condition/Effect DSL** 의 op·do 오타(`has_flag`, `set_quest`)는 **서버가 잡지 못한다** —
   서버는 형태만 보고, DSL 유효성은 `GET /api/content/validate` 가 본다. 배치 후 반드시 부를 것
6. `chance` 를 퀘스트 필수 경로에 둠 → 완주 증명이 실패한다
7. 스테이지 `next` 로 사이클을 만듦 → 빌드 하드 실패
8. 대화에 종료(`"end"`)로 가지 않는 노드를 남김 → 도달성 검사 실패. `graph.png?problems=1` 로 먼저 볼 것
9. 아이템을 요구하는 목표만 만들고 주는 곳을 안 만듦 → `RG-01`. `content_refs` 로 확인할 것
10. `build` 를 안 부르고 끝냄 → 산출물이 낡는다. 마지막에 `POST /api/content/build`
````

- **R-31-34** 가이드 문서는 다른 기획서 장의 내용을 **복사하지 않고 요약**한다. 요약이 원문과 어긋나면 **원문(BP-21/23/24/26)이 정본**이며, 이 사실을 가이드 머리말에 명시한다.
- **R-31-35** 가이드의 "자주 하는 실수" 절은 실제 에러 로그를 보고 **갱신한다.** 이 절이 에이전트 실패율을 가장 크게 줄인다.

---

## 8. 이 장이 확정한 것 / 다음 장으로 넘긴 것 / 열린 질문

### 8.1 확정한 것

| ID | 확정 사항 |
|---|---|
| P1~P7 | 맵 API 에서 계승할 원칙 7가지와 그 코드 근거. **P6 은 rev 의 표현·409 형태만 계승**하고 선행조건 검사는 `/api/map` 한정임을 실측으로 한정 |
| R-31-1~3 | 컬렉션 7종 ↔ 파일 매핑, 접두사 일치 검사, 앵커·문자열의 전용 라우트 |
| — | **엔드포인트 33 라우트 전수 명세**(§2.0 표 + §2.1~§2.9 본문) |
| R-31-4~6 | 목록 응답의 `*Text` 동봉, 참조 존재 검사는 CLI 몫, 삭제 시 문자열 동반 정리 |
| **R-31-0/0a** | 콘텐츠 API 는 **기존 `applyOps`/`writeMapFile` 을 내부 호출**한다([BP-36 D3](36_map_editor_extension.md) 과 통일). §2.0 표는 전수 목록이며 그것이 계약 |
| **R-31-6a~d** | (D-27) 앵커는 맵 데이터에 표시를 남기지 않는다. `autoPlaceTile` 은 **도달 편의**이고, `trigger`/`battle(step_on)` 은 no-op. 정합 위반은 **WARN**. `tile.ok` → `tile.reachable` |
| R-31-7/7a/7b | 서버가 판정 가능한 kind 범위표(region 없이 성립), **진입점 게이트 비대칭을 `info` 로 노출**(부록 K), 기본 심각도 `warning` |
| R-31-8 | 다중 팩 앵커 파일 규약 |
| R-31-9 | `moveTile:false` 의 의미와 유일한 용도 |
| R-31-10/11 | `mint` 는 비멱등, 슬롯 번호 연속성 경고 |
| R-31-12 | 검사 위반은 4xx 가 아니라 200 + `ok:false` (맵 `/validate` 규약 계승) |
| R-31-13/13a~c/14 | 트레이스는 임시 디렉토리, sim 타임아웃 120초. **`sim` 응답은 D-26 의 2축**(`modelVerdict`/`supportVerdict`)이며 [BP-33 §7.2](33_validation_and_lint.md) CI JSON 과 필드명 일치. `ok` 는 모델 증명 축만 본다 |
| R-31-15~19 | 인덱스 신선도 보고, context 읽기 전용·절단 보고(예산 단위는 **토큰**, 기본 57,000), 그래프 PNG 팔레트·`pngjs` 자체 렌더. **기존 `preview.png` 규약은 상한 400 이 아니라 클램프**(R-31-17a) |
| R-31-20/21 | 경로 편집 op 는 형태만 검사, 알 수 없는 op 는 전량 목록 hint |
| R-31-22/23 | 2단계 커밋과 다중 rename 의 한계 인정 + 백업 되돌리기 + git 최종 안전망, 배치 32파일 상한 |
| R-31-23a | `ifRev` 는 `string \| Record<string,string>` **union**. MCP 스키마도 union |
| R-31-24~29 | `ifRev` 선택·권장 구분, `currentRev`+`diffSummary`, 브라우저도 앵커는 시맨틱 API 사용, 파일 단위 쓰기 락 |
| **R-31-27a** | `ifRev` 를 필수로 하지 않는 것은 **"AI 가 사람의 미저장 편집을 덮어쓸 수 있다" 를 받아들이는 결정**임을 명시(§4.3) |
| R-31-30/30a/31 | hint 는 행동 지시. **에러 코드 39종** 카탈로그(§5.1+§5.2 전량). 개수가 아니라 표가 계약. 코드는 추가만 |
| R-31-32/33 | MCP 도구 28종, description 규약, 응답 무가공 중계 |
| R-31-34/35 | 가이드 문서 목차와 초안, 원문 우선 원칙 |

### 8.2 다음 장으로 넘긴 것

| 넘긴 내용 | 받는 장 |
|---|---|
| **라우트 계약 테스트** — 33 라우트마다 성공 1 + 대표 에러 1. `tools/mapEditor` 는 현재 자동 테스트 0건(DEVLOG §4.8)이므로 [BP-36 T-36-3](36_map_editor_extension.md) 의 vitest 세트에 `content_routes.contract.test.ts` 를 추가하고 CI 잡이 받는다(F-31-08) | [BP-36](36_map_editor_extension.md), [BP-35](35_ci_and_build.md) |
| `openapi.yaml`(37,212바이트, 손 관리)에 `/api/content/*` 33 라우트 추가 | [BP-35](35_ci_and_build.md) |
| 발행 지점 레지스트리 생성(`supportVerdict` 의 입력) | [BP-35](35_ci_and_build.md) |
| `validate`/`lint` 가 반환하는 `rule` 번호·심각도·메시지 본문 | [BP-33](33_validation_and_lint.md) |
| `sim`/`solve` 의 `result` 값 집합, 트레이스 JSON 스키마, 정책별 동작 | [BP-34](34_headless_sim_and_solver.md) |
| `POST /api/content/build` 가 내부적으로 수행하는 빌드 단계와 `content.lock.json` 필드 | [BP-35](35_ci_and_build.md) |
| 브라우저 UI 가 이 API 를 어떻게 호출하는가(앵커 편집·그래프 뷰어·폴링/SSE) | [BP-36](36_map_editor_extension.md) |
| `GET /api/content/context` 응답 각 필드의 **내용 구성 규칙**과 예산 배분 | [BP-32](32_generation_harness.md), [BP-37](37_prompt_contracts.md) |
| 엔티티 본문 JSON Schema 전문(요청 바디 검증에 쓸 것) | [BP-90](90_appendix_schemas.md) |
| `openapi.yaml` 확장(기존 1,040줄에 `Content` 태그 추가) | [BP-35](35_ci_and_build.md) 의 문서 게이트 |

### 8.3 열린 질문

| ID | 질문 | 영향 | 잠정 |
|---|---|---|---|
| **Q-31-1** | 노드 40개 초과 그래프의 배치 알고리즘 | 그래프 PNG 가독성 | 400 + `?focus=&depth=` 부분 조회 안내 |
| **Q-31-2** | 앵커 변경 통지를 폴링 유지 vs SSE | 동시 편집 반응성 | 폴링 유지. [BP-36](36_map_editor_extension.md) 재검토 |
| **Q-31-3** | N-엔티티 파일(items/places)의 rev 가 파일 단위라 같은 파일의 다른 아이템 수정끼리 충돌한다. 아이템 단위 rev(내용 해시)로 갈 것인가? | 병렬 생성 시 409 빈발 | v1 은 파일 단위. 409 가 잦아지면 `ifRev` 를 `sha256(해당 요소)` 로 확장 |
| **Q-31-4** | `POST /api/content/edit` 이 맵 타일까지 건드리는데(`set_tile`), 이것이 맵 API 의 `POST /api/ai/maps/{f}/edit` 와 기능 중복이다. 하나로 합칠 것인가? | API 표면 | 유지. 콘텐츠 배치의 `set_tile` 은 **앵커와 원자적으로 묶기 위한 통로**이고, 순수 지형 작업은 맵 API 가 담당한다. 가이드에 이 구분을 명시 |
| **Q-31-5** | `generatedBy.kind` 를 서버가 어떻게 판별하는가? MCP 경유면 agent, curl 이면 human 이라는 추정은 위조가 쉽다 | 감사 추적의 신뢰도 | `X-Hadar-Actor` 헤더를 MCP 가 붙이고 기본값은 `unknown`. 위조 방지는 목표가 아니며 "실수로 잘못 기록되는 것" 만 막는다 |
| **Q-31-6** | 서버가 CLI 를 부를 때 매번 프로세스를 띄우면 `validate` 가 수백 ms 이상 걸린다. 장기 실행 CLI 데몬(`--serve`)을 둘 것인가? | 편집 루프 체감 | v1 은 매번 새 프로세스(결정론·단순성 우선). 500ms 를 넘기 시작하면 `hadar_content --serve` 모드 도입 |
| **Q-31-7** | 인증이 없다. 콘텐츠까지 쓰기 가능해지면 노출 시 피해가 맵보다 크다 | 보안 | localhost 바인딩 전제 유지 + `strictPort`([BP-30 R-30-26](30_toolchain_overview.md)). 원격 사용이 필요해지면 토큰 헤더 추가 |

---

## 부록 A. 이 장이 인용한 코드 위치

| 참조 | 경로:줄 | 인용 목적 |
|---|---|---|
| 가이드 반환 | `tools/mapEditor/server/ai_api.ts:493-499` | `GET /api/content` 의 동형 구현 |
| `applyOps` 배치 | `tools/mapEditor/server/ai_api.ts:217-336` | P1 배치 op |
| 알 수 없는 op 의 hint | `tools/mapEditor/server/ai_api.ts:331` | R-31-21 |
| `opInt` NaN 방어 | `tools/mapEditor/server/ai_api.ts:75-85` | P5 |
| `parseLayer` 빈 문자열·프로토타입 방어 | `tools/mapEditor/server/ai_api.ts:50-56` | P5 |
| `clampRegion` 교집합 | `tools/mapEditor/server/ai_api.ts:199-208` | P5 |
| edit 핸들러(검증 실패 시 미저장) | `tools/mapEditor/server/ai_api.ts:666-685` (`applyOps` `:673` → `writeMapFile` `:674`) | P3 |
| `validate` 가 200 + `ok` | `tools/mapEditor/server/ai_api.ts:770-775` | R-31-12 |
| `preview.png` — **영역 미겹침만 400, 배율·시야는 클램프** | `tools/mapEditor/server/ai_api.ts:778-811` (400 `:787-793`, `tilePx` 클램프 `:794`, `sight` 클램프 `:804`) | §2.9 규약(F-31-02) |
| 20,000칸 상한은 region·passability 전용 | `tools/mapEditor/server/ai_api.ts:648`, `:751` | §2.9 대조군 |
| region 값을 0~255 로 강제 | `tools/mapEditor/server/ai_api.ts:94` | §2.5.0 — `0x00010000` 을 심을 수 없다 |
| region 을 `ixEvent` **하위 바이트**에 넣는다 | `hadar2026_app/lib/application/map_loader.dart:44` | §2.5.0 (부록 J-1) |
| 마스크는 **비트 16~23** 만 본다 | `hadar2026_app/lib/domain/map/tile_properties.dart:187` | §2.5.0 (부록 J-1) |
| `checkTileEvent` 호출 3곳의 게이트 비대칭 | `hadar2026_app/lib/presentation/panels/player_sprite.dart:193`(게이트 없음), `:359`(`if (action.isInteractive)`), `:405`(게이트 없음) | R-31-7a (부록 K) |
| 생성 시 409 | `tools/mapEditor/server/ai_api.ts:560` | 멱등성 표기 근거 |
| `registerAs` 가 `json` 필드를 쓴다 | `tools/mapEditor/server/ai_api.ts:584-593` | `map_not_found` hint |
| `sendError({error, hint})` | `tools/mapEditor/server/util.ts:10-12` | P2 |
| `revOf` = mtime | `tools/mapEditor/server/store.ts:34-36` | §4.1 |
| tmp+rename 원자 쓰기 | `tools/mapEditor/server/store.ts:72-79`(`renameSync` `:77`), `:137-144`(`:143`) | P7, §3.3 |
| 손상 파일 500 처리 | `tools/mapEditor/server/store.ts:51-60` | `source_corrupt` |
| `uiCurrent` 추적 | `tools/mapEditor/server/store.ts:151-156` | `status.currentMap` |
| 409 + `currentRev` — **`PUT /api/map` 한정** | `tools/mapEditor/vite.config.ts:83-92`(`rev` 읽기 `:84`, 비교 `:86`, 응답 `:87-91`) | R-31-26, §1.1 P6 실측 |
| `GET /api/map/rev` | `tools/mapEditor/vite.config.ts:44-52` | 라우트 32번의 원본 |
| 405 종결 | `tools/mapEditor/vite.config.ts:116-124` | 라우터 말단 규약 |
| 서버 포트 | `tools/mapEditor/vite.config.ts:143` | Base URL |
| MCP `tool()` 헬퍼 | `tools/mapEditor/mcp/server.mjs:47-56` | §6.2 동형 |
| MCP `get_guide` 설명 | `tools/mapEditor/mcp/server.mjs:72-77` | `content_guide` 문안 |
| MCP 이미지 도구 | `tools/mapEditor/mcp/server.mjs:201-235`(`preview`), `:237-256`(`tile_image`) | 🖼 도구 형태 |
| 브라우저 저장 충돌 | `tools/mapEditor/src/api.ts:44-49` | §4.3 |
| 타일 액션 규칙(TS 포팅) | `tools/mapEditor/src/rules.ts:97-137` — `tileAction` `:97-106`, `objectAction` `:109-119`, `unitAction` `:125-137`(**region 을 인자로 받지 않는다**) | R-31-7 근거 및 그 한계 |
