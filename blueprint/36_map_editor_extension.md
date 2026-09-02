# 기존 맵 에디터 확장안

> `상태: 활성` — 현재 노선(S1→S2→S3)에서 그대로 사용한다. 실행 계획은 [`issues/`](../issues/README.md).

> **문서 ID**: BP-36 · **상태**: 개정 2판(D-26·D-27 반영 + REVIEW_BP-36 조치) · **선행 문서**: [BP-26](26_entity_registry_and_anchors.md), [BP-30](30_toolchain_overview.md), [BP-31](31_content_server_api.md)
> **독자**: 맵 에디터 구현자 · 콘텐츠 서버 구현자 · 바인더(Binder) 구현자
> **한 줄 요약**: 이미 있는 `tools/mapEditor` 를 **앵커를 보고·놓고·따라오게** 만들고, 부록 D 의 맵 이름 해석 파손을 **도구가 스스로 진단·수정 제안**하게 한다.

**파이프라인 구획**(D-01): 전 구간 **Authoring**. 이 장이 정의하는 것은 배포물에 들어가지 않는다.
런타임은 맵 에디터를 모른다.

**개정 이력**

| 판 | 변경 |
|---|---|
| 초판 | 앵커 편집 UI · 실시간 정합 경고 · 좌표 추종 4시나리오 · region 예약 도구 지원 · 그래프 뷰어 · `preview.png` 오버레이 · `MapInfos` 진단/수정 · 구현 순서 5단계 · 회귀 방어선 4개 · vitest 6종 |
| **개정 2판** | **D-27 반영** — §5 를 통째로 다시 썼다. `region 200~255` 예약의 **팔레트·`validateMap` 확장·캔버스 해칭·`T-36-1`(Map001 정리)·`Q-36-1`(예약 폭)을 전량 삭제**하고, 그 자리를 **앵커 오버레이 전용 표시 + 도달 가능성 WARN + 진입점 게이트 비대칭 표시**로 대체했다(F-36-01). 에디터는 앵커 때문에 **맵 데이터를 바꾸지 않는다.** §3.4 의 `V-MAP-017` 행 삭제. **D-26 반영** — §6.2 문제 목록과 §3.3 상태바에 `UNSUPPORTED` 배지를 추가(F-36-06). **REVIEW_BP-36 조치** — [BP-31](31_content_server_api.md) 과의 맵 쓰기 경로 원칙 충돌 해소(F-36-02) · `openapi.yaml` 확장을 §10.2 로 넘김(F-36-03) · 신규 라우트 2개의 `AI_GUIDE.md` 등재와 `T-36-2` 의 15→19 산술 명시(F-36-04) · 클릭 이동에도 확인 다이얼로그(F-36-05) · `registerAs` 엔트리 범위 `:584-593` |

---

## 0. 이 장의 범위

| 항목 | 내용 |
|---|---|
| **이 장이 소유하는 것** | 브라우저 에디터 UI(앵커 레이어·인스펙터·경고 표시·그래프 창) · `preview.png` 오버레이 쿼리 · `map_ops.<MAP>.json` 형식 · `MapInfos.json` 진단/수정 제안 API · **앵커 오버레이 표시와 도달 가능성 경고의 UI**(§5) · 구현 순서와 회귀 방지 |
| **이 장이 소유하지 않는 것** | 앵커 스키마·정합 **규칙**(→ [BP-26 §2·§3](26_entity_registry_and_anchors.md)) · 콘텐츠 REST 계약(→ [BP-31](31_content_server_api.md)) · 검증 규칙 카탈로그(→ [BP-33 §4.5](33_validation_and_lint.md)) · 퀘스트/대화 스키마(→ [BP-23](23_quest_model.md)·[BP-24](24_dialogue_model.md)) · 그래프 PNG 렌더 알고리즘(→ [BP-31 §2.9](31_content_server_api.md)) |
| **근거 결정** | D-09(앵커), D-10(티어 0), D-12(같은 프로세스·같은 에러 규약), D-14(4단계 bind) |
| **한 문장 정의** | *맵 파일만 알던 도구에 "이 좌표가 무슨 의미인가" 를 보여 주고, 그 의미가 깨지는 순간 그 자리에서 말하게 만든다.* |

- **R-36-1** 이 장의 모든 신규 기능은 **기존 맵 편집 경로를 건드리지 않는다**. 앵커를 한 개도 만들지
  않은 사용자에게 에디터는 지금과 똑같이 보이고 똑같이 동작해야 한다. 콘텐츠 팩이 없으면
  앵커 UI 는 **통째로 숨는다**(§9.2 회귀 방어선 1).

---

## 1. 현행 에디터 구조 (실측)

### 1.1 파일과 줄 수

| 구획 | 파일 | 줄 | 역할 |
|---|---|---|---|
| 서버 | `tools/mapEditor/server/ai_api.ts` | **828** | `/api/ai/*` 시맨틱 REST 전량. 라우터 1개 함수(`handleAiApi`, `:471`)에 모든 경로가 들어 있다 |
| 서버 | `tools/mapEditor/server/store.ts` | **166** | assets 디렉토리 파일 IO. `readMapFile`/`writeMapFile`/`readMapInfos`/`writeMapInfos`/`uiCurrent` |
| 서버 | `tools/mapEditor/server/preview.ts` | **181** | 맵 → PNG 합성(pngjs). `renderPreview`/`renderTile` |
| 서버 | `tools/mapEditor/server/util.ts` | **27** | `sendJson`/`sendError`(=`{error, hint}`)/`readJsonBody` |
| 서버 | `tools/mapEditor/vite.config.ts` | 5,442바이트 | Vite 미들웨어. `:31` 이 `handleAiApi` 를 **가장 먼저** 부르고, 안 걸리면 `/api/map`·`/api/maps`·`/api/image` 저수준 경로로 내려간다 |
| 공유 | `tools/mapEditor/src/rules.ts` | **137** | `HDTileProperties` 포팅. `tileAction`/`objectAction`/`unitAction`/`ACTION_NAMES`/`ACTION_COLORS` — **브라우저와 node 가 같은 파일을 쓴다** |
| 공유 | `tools/mapEditor/src/mvmap.ts` | **274** | MV 직렬화 보존(`serializeMv`), `LAYER_META`, `EVENT_LAYER = 6`, `getTile`/`setTile`, `dialogLinesOf`/`setDialogLines` |
| 공유 | `tools/mapEditor/src/lighting.ts` | 43 | `shadowIx`/`lightBitFor` |
| UI | `tools/mapEditor/src/main.ts` | **762** | 부트·툴바·키보드·저장·폴링. `doSave`(`:505`), `reloadFromDisk`(`:561`), `hasPendingInput`(`:593`) |
| UI | `tools/mapEditor/src/renderer.ts` | **324** | Canvas 렌더. `EVENT_TYPE_COLORS`(`:15`), 통행 오버레이, 이벤트 테두리(`:247`) |
| UI | `tools/mapEditor/src/palette.ts` | **254** | 레이어별 팔레트 4종(`buildA5`/`buildB`/`buildShadow`/`buildRegion`) |
| UI | `tools/mapEditor/src/events_panel.ts` | **254** | 이벤트 목록·편집 폼 |
| UI | `tools/mapEditor/src/state.ts` | **191** | `EditorState` — undo 스택(타일 스트로크 / 스냅샷 2종), 선택 상태, 뷰 상태 |
| MCP | `tools/mapEditor/mcp/server.mjs` | **259** | `/api/ai/*` 를 감싼 도구 **15종**. 첫 도구가 `get_guide` |
| 문서 | `AI_GUIDE.md` 114 · `API_MANUAL.md` 93 · `USER_MANUAL.md` 158 · `DEVLOG.md` 198 · `openapi.yaml` 37,212바이트 | — | `GET /api/ai` 가 `AI_GUIDE.md` **원문**을 반환(`ai_api.ts:493-499`) |

### 1.2 세 인터페이스가 한 파일을 공유한다

```
브라우저 UI  ──PUT /api/map──────┐
                                 │
AI / MCP     ──POST /api/ai/*────┼──▶ hadar2026_app/assets/maps/*.json   (MV 원본 포맷 보존)
                                 │
mcp/server.mjs ─(fetch)─▶ /api/ai┘
```

| 표면 | 경로 | 입도 | 저장 방식 |
|---|---|---|---|
| Editor | `/api/map`, `/api/maps`, `/api/image` | 원시 MV JSON 통째 | `PUT` 전체 교체 + `rev`(mtime) 낙관적 잠금 |
| AI | `/api/ai/*` | 레이어·타일·이벤트 **시맨틱** | 요청마다 최소 범위만 갱신 후 즉시 저장 |
| MCP | stdio | AI 표면과 1:1(단 `palette`·단일 이벤트 조회 도구 없음) | — |

- 동시성: 브라우저 UI 는 **2초마다** `/api/map/rev` 를 폴링하고, 그 폴링이 곧
  `GET /api/ai/current` 의 근거다(`store.ts` `uiCurrent`, 10초 유효).
- 알려진 한계(그대로 인용): **3-way merge 없음**(DEVLOG §4.1), 대사 편집이 이벤트 `list` 재구성
  (§4.2), 타일셋 하드코딩(§4.4), `ground2` 사실상 사망(§4.5), **자동 테스트 0건**(§4.8).

### 1.3 이 장이 붙는 지점 (요약)

| 신규 기능 | 붙는 파일 | 성격 |
|---|---|---|
| 앵커 레이어·인스펙터 | `src/state.ts`, `src/main.ts`, `src/renderer.ts`, 신규 `src/anchors_panel.ts` | UI |
| 정합 실시간 경고 | 신규 `src/anchor_rules.ts`(= `rules.ts` 옆), `src/renderer.ts` | 공유 로직 |
| 앵커 추종 | `src/main.ts`(편집 op 훅), 콘텐츠 API 호출 | UI + 서버 |
| 앵커 오버레이·도달 가능성 경고 | `src/renderer.ts`, 신규 `src/anchor_rules.ts` (**`src/palette.ts`·`validateMap` 은 건드리지 않는다** — §5) | 공유 |
| 그래프 뷰어 | 신규 `src/graph_window.ts` | UI(서버 PNG 소비) |
| `preview.png` 오버레이 | `server/preview.ts`, `server/ai_api.ts` | 서버 |
| MapInfos 진단 | `server/store.ts`, `server/ai_api.ts`, `src/main.ts` | 서버 + UI |

---

## 2. 앵커 편집 UI

### 2.1 왜 콘텐츠 서버가 아니라 에디터인가

앵커는 **좌표를 가진 유일한 콘텐츠**다([BP-26 R-26-2](26_entity_registry_and_anchors.md)).
좌표를 고르는 행위는 통행 데이터·타일 그림·이웃 오브젝트를 눈으로 보면서만 할 수 있다.
JSON 편집기로 `{"x":34,"y":12}` 를 쓰는 것은 좌표를 고르는 것이 아니라 **추측하는 것**이다.

- **R-36-2** 앵커의 **좌표 필드만** 에디터가 소유한다. `actor`/`dialogue`/`effects`/`when` 같은
  의미 필드는 인스펙터가 **읽기 전용으로 보여 주고**, 편집은 콘텐츠 API/CLI 로 보낸다.
  이유: 의미 필드를 두 도구가 쓰면 스키마 정규화가 두 곳에 생긴다(D-12 원칙 위반).

### 2.2 레이어 모델 — 의사 레이어 7

`src/mvmap.ts` 는 이미 `EVENT_LAYER = 6` 이라는 **의사 레이어**를 쓴다(z 0~5 는 실제 타일 레이어).
같은 수법을 한 칸 더 쓴다.

```ts
// src/mvmap.ts
export const EVENT_LAYER = 6;
export const ANCHOR_LAYER = 7;   // 신규 — 콘텐츠 팩 앵커 오버레이
```

| 레이어 | 라벨 | 팔레트 | 기본 표시 | 편집 대상 |
|---|---|---|---|---|
| 0~5 | 기존 `LAYER_META` 그대로 | a5/b/shadow/region | 변경 없음 | 맵 파일 |
| 6 | `이벤트` | (없음) | 켬 | 맵 파일 `events[]` |
| **7** | **`앵커 (콘텐츠)`** | (없음, 인스펙터) | **팩이 있을 때만 켬** | `assets/content/**/anchors/<MAP>.json` |

- **R-36-3** 앵커 레이어는 **활성 레이어와 무관하게 항상 오버레이로 그려진다**(체크박스 `앵커`).
  타일을 칠하는 중에도 "여기에 위병이 서 있다" 는 것이 보여야 하기 때문이다.
  다만 **선택·이동은 활성 레이어가 7일 때만** 가능하다 — 이벤트 레이어의 규약과 동일.

### 2.3 색·기호 규약 — 기존 이벤트 테두리와 충돌하지 않게

현행 이벤트 테두리(`server/preview.ts:26-33`, `src/renderer.ts:15-22`, 두 곳에 같은 값이 복제되어 있음):

| 타입 | RGB | 색 |
|---|---|---|
| `TALK` | `240,80,220` | 마젠타 |
| `SIGN` | `60,220,230` | 시안 |
| `EVENT` | `90,230,90` | 초록 |
| `ENTER` | `240,220,60` | 노랑 |
| `NPC` | `240,144,64` | 주황 |
| `UNKNOWN` | `170,170,170` | 회색 |

앵커는 **같은 색을 쓰되 형태를 다르게** 한다. 새 색을 6개 더 만들면 6색 대 6색이 되어
"마젠타가 두 종류" 라는 최악의 상태가 된다.

| 요소 | 이벤트(기존) | 앵커(신규) |
|---|---|---|
| 테두리 | **실선**, 두께 `tilePx/8` | **점선**(대시 3px/3px), 두께 `tilePx/8`, **칸 안쪽으로 2px 들여 그림** |
| 색 | 위 표 | 앵커 `kind` → **요구 타일 액션**의 색을 그대로 씀(§2.3.1) |
| 글리프 | 없음 | 좌상단 모서리에 1글자 (`tilePx >= 16` 일 때만) |
| 선택 시 | 흰 테두리(`renderer.ts:249`) | 흰 **이중** 테두리 + 8방향 핸들 없음(격자 이동이므로) |

#### 2.3.1 kind → 색·글리프

`kind` 마다 요구하는 `HDTileAction` 이 정해져 있으므로([BP-26 §3.3](26_entity_registry_and_anchors.md)),
그 액션의 색을 쓰면 **"앵커 색과 밑에 깔린 타일 색이 같아야 정상"** 이라는 시각 규칙이 공짜로 생긴다.

| kind | 요구 액션 | 색(= `ACTION_COLORS`) | 글리프 |
|---|---|---|---|
| `actor` | `talk` | 마젠타 | `人` |
| `sign` | `sign` | 시안 | `文` |
| `portal` | `enter` | 노랑 | `門` |
| `trigger` | `event` | 초록 | `踏` |
| `container` | `talk`\|`sign` | 마젠타/시안(선언에 따름) | `箱` |
| `battle` | `event`\|`talk` | 초록/마젠타 | `戰` |

- **R-36-4** 앵커 점선 색이 그 칸의 통행 오버레이 색과 **다르면 곧 위반**이다(§3).
  위반 칸은 점선을 **빨강(`230,60,60`)** 으로 덮고 좌상단에 `!` 배지를 얹는다.
- **R-36-5** `EVENT_TYPE_COLORS`(renderer.ts)와 `EVENT_RGB`(preview.ts)의 **복제를 이 작업에서 제거**하고
  `src/rules.ts` 로 올린다. 두 렌더러가 갈라지는 것이 이미 알려진 문제다(DEVLOG §4.7).
  앵커 색을 추가하면서 복제를 하나 더 만들면 다음 사람이 세 곳을 고쳐야 한다.

### 2.4 앵커 인스펙터 (사이드바 신규 섹션)

`index.html` 의 `<aside id="sidebar">` 에 `eventsSection` 과 같은 형태로 `anchorsSection` 을 추가한다.

```
┌ 앵커 (콘텐츠) ──────────────────────────┐
│ 팩  [core ▾]      (읽기 전용: gen_ep1)   │
│ ┌─────────────────────────────────────┐ │
│ │ 人 town1_gate_guard      (34,12)  ! │ │  ← ! = 정합 위반
│ │ 文 town1_notice          (30,18)    │ │
│ │ 門 town1_to_ground       (50,99)    │ │
│ │ 踏 crypt_secret          (61,82)    │ │
│ └─────────────────────────────────────┘ │
│ ── 선택: anchor.core.town1_gate_guard ──│
│ kind    actor            (읽기 전용)     │
│ actor   npc.core.lore_gate_guard   [↗]  │
│ 좌표    x [34] y [12]      [이 칸으로]   │
│ facing  [down ▾]                        │
│ when    {"op":"true"}      (읽기 전용)   │
│ ─────────────────────────────────────── │
│ ⚠ (34,12) 의 타일 액션이 move 입니다.    │
│    요구: talk (objUpper B 128~143)      │
│    [타일 고치기]  [가까운 talk 칸 찾기]  │
└─────────────────────────────────────────┘
```

| 컨트롤 | 동작 | 호출 |
|---|---|---|
| 팩 드롭다운 | 여러 팩이 같은 맵에 앵커를 두면 팩별로 나눠 본다. 비선택 팩은 **흐리게** 그리고 편집 불가 | 로컬 |
| 목록 행 클릭 | 선택 + 캔버스가 그 좌표로 스크롤 | 로컬 |
| `[↗]` | 대상 엔티티를 그래프/상세 창으로(§6) | `GET /api/content/actors/{id}` |
| `x`/`y` 입력, `[이 칸으로]` | **원자적 이동**(§4) | `POST /api/content/anchors/{id}/move` |
| `[타일 고치기]` | 요구 액션의 대표 타일을 그 칸에 놓는 맵 편집 1건 | `POST /api/ai/maps/{file}/edit` |
| `[가까운 talk 칸 찾기]` | 체비셰프 거리 2 이내 후보 하이라이트([BP-26 R-26-25](26_entity_registry_and_anchors.md)) | 로컬 계산 |

- **R-36-6** 인스펙터의 읽기 전용 필드는 **회색 배경 + 커서 `not-allowed`** 로 표시하고,
  클릭하면 "이 필드는 콘텐츠 API 로 고칩니다: `PATCH /api/content/anchors/{id}`" 를 상태바에 띄운다.
  막아 놓고 이유를 안 말하면 사람이 JSON 을 직접 열게 되고, 그러면 R-36-2 가 무의미해진다.

### 2.5 배치·이동·삭제 상호작용

| 조작 | 조건 | 결과 |
|---|---|---|
| 앵커 레이어에서 **빈 칸 클릭** | 선택된 앵커 없음 | 새 앵커 다이얼로그(kind 선택 → id 슬러그 입력 → `autoPlaceTile` 체크) |
| 앵커 레이어에서 **빈 칸 클릭** | 앵커 선택 중 | 선택 앵커를 그 칸으로 이동(§4) — 이벤트 레이어의 기존 규약과 동일 |
| 앵커 클릭 | — | 선택 |
| `Delete` | 앵커 선택 중 | 삭제 확인 → `DELETE /api/content/anchors/{id}`. **타일은 지우지 않는다**(R-36-8) |
| `Esc` | 앵커 선택 중 | 선택 해제 |

- **R-36-7** 새 앵커 생성 시 `autoPlaceTile` 기본 **켬**([BP-26 R-26-31](26_entity_registry_and_anchors.md)).
  단 그 칸에 BLOCK 이 아닌 다른 오브젝트가 있으면 서버가 거부하므로(R-26-32), UI 는 **클릭 시점에
  미리 판정**해 커서를 `no-drop` 으로 바꾼다. 거부를 다이얼로그로 알리는 것보다 커서로 막는 편이 싸다.
- **R-36-8** 앵커 삭제는 **타일을 되돌리지 않는다.** 위병 타일이 남는 것은 `M-26-03`(앵커 없는 TALK 타일)
  경고로 잡힌다. 자동으로 지형을 지우면 사람이 손으로 그린 장식까지 사라진다.

### 2.6 상태와 undo

`EditorState` 의 undo 스택은 `{kind:'tiles'} | {kind:'snapshot'}` 두 종류다(`state.ts`).
앵커 변경은 **서버 커밋**이므로 로컬 undo 스택에 넣을 수 없다.

- **R-36-9** 앵커 편집은 **로컬 undo 대상이 아니다.** `Ctrl+Z` 는 타일만 되돌린다.
  앵커는 서버가 `rev` 를 반환하므로 되돌리기는 `POST /api/content/anchors/{id}/move` 를
  이전 좌표로 다시 호출하는 것으로 한다 — 인스펙터에 `[방금 이동 취소]` 버튼 1개.
- **R-36-10** `Ctrl+Z` 를 눌렀을 때 마지막 조작이 앵커였다면 **아무 일도 일어나지 않는 대신**
  상태바에 "앵커 변경은 되돌리기 대상이 아닙니다 — 인스펙터의 [방금 이동 취소]" 를 띄운다.
  조용히 타일 undo 가 발동하면 사람이 "되돌렸다" 고 오해한다.

---

## 3. 앵커–타일 정합 실시간 검증

### 3.1 규칙은 남의 것, 표시가 이 장의 것

| 것 | 소유 |
|---|---|
| 어떤 조합이 위반인가(`kind` ↔ 타일 액션 표, A-26-01~12, M-26-01~05) | [BP-26 §3.3·§3.4·§6.3](26_entity_registry_and_anchors.md) |
| 규칙 ID·심각도·메시지 문안(`V-MAP-001` ~ `V-MAP-022`) | [BP-33 §4.5](33_validation_and_lint.md) |
| **언제 검사하고 어떻게 보여 주는가** | **이 장** |

- **R-36-11** 에디터는 규칙을 **재정의하지 않는다.** 판정 함수는 `src/rules.ts` 의 `unitAction` 과
  `src/anchor_rules.ts` 의 `requiredActionFor(kind)` 한 쌍뿐이고, 후자는 BP-26 §3.3 표의
  **기계 번역본**이다. 표가 바뀌면 이 파일 하나만 바뀐다.

### 3.2 검사 시점 3종

| # | 시점 | 범위 | 지연 | 주체 |
|---|---|---|---|---|
| **C1** | 타일을 칠하는 매 스트로크 종료(`endStroke`) | **변경된 칸에 앵커가 있는 것만** | 즉시(<1ms) | 브라우저 로컬 |
| **C2** | 앵커 이동·생성 직후 | 그 앵커 1개 | 즉시 | 브라우저 로컬 → 서버 확정 |
| **C3** | 저장(`doSave`) 및 2초 폴링에서 외부 변경 감지 | 이 맵의 앵커 전량 + `V-MAP-*` 서버 검사 | 디바운스 400ms | `GET /api/content/anchors/{map}` |

- **R-36-12** C1 은 **절대 서버를 부르지 않는다.** 붓질 한 번에 HTTP 요청이 나가면 도구가 못 쓰게 된다.
  로컬 판정에 필요한 것은 `unitAction(ground, objUpper, eventType)` 뿐이고 전부 메모리에 있다.
- **R-36-13** 로컬 판정과 서버 판정이 **다르면 서버가 이긴다**. 다르다는 사실 자체를 상태바에
  `⚠ 로컬/서버 판정 불일치 — rules.ts 포팅이 낡았을 수 있음` 으로 남긴다(DEVLOG §4.6 의 수동 동기화 문제를
  조용히 넘기지 않기 위해).

### 3.3 표시 3단계

```
① 칸       점선 테두리를 빨강으로 + 좌상단 `!` 배지
② 인스펙터 선택 앵커 아래 경고 박스 (규칙 ID · 메시지 · 수정 버튼 2개)
③ 상태바   "앵커 경고 3건 (오류 1, 경고 2)" — 클릭하면 인스펙터가 첫 오류로 이동
```

| 심각도 | 칸 표시 | 상태바 | 저장 |
|---|---|---|---|
| ERROR (`V-MAP-001` 등) | 빨강 점선 + `!` | 빨강 카운트 | **막지 않음**(R-36-14) |
| WARN (`V-MAP-007/011` 등) | 주황 점선 + `?` | 주황 카운트 | 막지 않음 |
| 정상 | kind 색 점선 | — | — |

- **R-36-14** 에디터는 **저장을 막지 않는다.** 맵 파일 저장은 지형 편집이고, 앵커 위반은 콘텐츠 문제다.
  "고치는 중간 상태" 를 저장 못 하게 하면 사람이 도구를 끄고 JSON 을 연다.
  차단은 `hadar_content commit`(D-15 Hard gate)에서 일어난다. 에디터는 **보여 주기만 한다.**
- **R-36-15** 경고 문구는 `{error, hint}` 규약의 `hint` 를 **그대로** 띄운다. 에디터가 문구를
  다시 쓰면 서버 메시지와 갈라진다.
- **R-36-15a** (D-26) 상태바는 심각도 3종이 아니라 **4종**을 센다:
  `✗ n · ⚠ n · 🔒 n · ⓘ n`. 🔒 는 `supportVerdict == "UNSUPPORTED"`(§6.2), ⓘ 는
  진입점 게이트 비대칭 같은 **고칠 수 없지만 알아야 하는 사실**(§5.4)이다.
  세 자리에 뭉치면 "고칠 수 있는 것" 과 "기다려야 하는 것" 이 구분되지 않는다.

### 3.4 로컬이 잡는 것 / 서버에 맡기는 것

| 규칙 | 로컬(C1/C2) | 서버(C3) | 이유 |
|---|---|---|---|
| `V-MAP-001` kind ↔ 타일 액션 | ✅ | ✅ | 맵 데이터만 있으면 됨 |
| `V-MAP-002` 좌표 범위 | ✅ | ✅ | 동상 |
| `V-MAP-005` 인접 4칸 통행 | ✅ | ✅ | 동상 |
| `V-MAP-006` step-on 칸 통행 | ✅ | ✅ | 동상 |
| `V-MAP-006a` step-on 앵커 칸이 **통행 가능**한가 | ✅ | ✅ | 동상. region 을 보지 않는다(§5) |
| `V-MAP-003/004` 포털 도착지 | ❌ | ✅ | **다른 맵**을 읽어야 함 |
| `V-MAP-008/009` 액터 중복·place 불일치 | ❌ | ✅ | 액터 카탈로그가 필요 |
| `V-MAP-013` `when` 이 항상 false | ❌ | ✅ | 솔버(L5) |
| `V-MAP-016` MapInfos 해석 | ❌ | ✅ | §8 |

> **`V-MAP-017`(trigger 의 region 200~255)은 이 표에서 삭제되었다.** D-27 로 [BP-33](33_validation_and_lint.md) 이
> 그 규칙 번호를 결번 처리했다. 로컬도 서버도 판정할 수 없었던 규칙이며(`unitAction` 이 region 을 인자로
> 받지 않는다 — `rules.ts:125-137`), 애초에 게임에서도 동작하지 않았다(§5.1).

---

## 4. 좌표가 움직일 때 앵커가 따라오는 방법

### 4.1 네 가지 시나리오

| # | 사람이 한 일 | 지금(앵커 없던 시절) | 확장 후 |
|---|---|---|---|
| **S1** | 앵커 레이어에서 앵커를 새 칸으로 끌었다 | — | **앵커가 타일을 끌고 간다**(정상 경로) |
| **S2** | 타일 레이어에서 위병 타일(B 132)을 지웠다 | 조용히 지워짐 | 그 칸 앵커가 즉시 ERROR. `[타일 되돌리기]` 제안 |
| **S3** | `rect`/`fill` 이 앵커가 있는 칸을 덮었다 | 조용히 덮임 | 스트로크 종료 시 **영향받은 앵커 목록** 토스트 |
| **S4** | `resize` 로 맵을 줄여 앵커가 밖으로 나갔다 | — | `V-MAP-002`/`M-26-04` ERROR. resize 전 **사전 경고 다이얼로그** |

### 4.2 S1 — 원자적 이동 (정상 경로)

절차는 [BP-26 §6.2](26_entity_registry_and_anchors.md) 가 확정했고 엔드포인트는
[BP-31 §2.5](31_content_server_api.md) `POST /api/content/anchors/{id}/move` 다. 에디터가 하는 일은 **호출과 표시**뿐이다.

```
┌ 위병을 옮깁니다 ────────────────────────┐
│ anchor.core.town1_gate_guard             │
│ (34,12) → (36,12)                        │
│                                          │
│ ☑ 타일도 함께 옮긴다                      │
│    objUpper (34,12) B132 → 0             │
│    objUpper (36,12) 0    → B132          │
│                                          │
│ 도착 칸 판정: talk ✅                     │
│                        [취소]  [옮기기]  │
└──────────────────────────────────────────┘
```

- **R-36-16** 체크박스를 끄면 **앵커만** 옮긴다. 그러면 출발 칸에 `M-26-03`(앵커 없는 TALK 타일)
  경고가, 도착 칸에 `V-MAP-001` 오류가 생긴다 — 다이얼로그가 그 결과를 **미리** 두 줄로 보여 준다.
- **R-36-17** 서버가 롤백하면(정합 재검사 실패, [BP-26 R-26-22](26_entity_registry_and_anchors.md))
  에디터는 로컬 맵 상태를 **디스크에서 다시 읽는다**(`reloadFromDisk`, `main.ts:561`).
  낙관적 로컬 반영을 되돌리려 하지 말 것 — 이미 있는 재로드 경로를 쓰는 편이 안전하다.

### 4.3 S2/S3 — 타일 쪽에서 시작된 이동

```
┌ toast ────────────────────────────────────────────────┐
│ 이 편집이 앵커 2개를 깨뜨렸습니다.                       │
│   人 town1_gate_guard (34,12) — talk 이 아님            │
│   文 town1_notice     (30,18) — sign 이 아님            │
│              [되돌리기(Ctrl+Z)]  [앵커 옮기기]  [무시]  │
└───────────────────────────────────────────────────────┘
```

| 버튼 | 동작 |
|---|---|
| `되돌리기` | 로컬 타일 undo(스트로크 단위). 앵커는 건드리지 않았으므로 그대로 복구 |
| `앵커 옮기기` | 각 앵커에 대해 체비셰프 2 이내 후보 탐색. **후보가 정확히 1개인 것만** 자동, 나머지는 인스펙터로([BP-26 R-26-26](26_entity_registry_and_anchors.md)) |
| `무시` | 경고 배지만 남기고 닫는다 |

- **R-36-18** 토스트는 **스트로크 종료 시 1회**만 뜬다. 붓질 중에 뜨면 못 쓴다.
- **R-36-19** `portal` 앵커는 `앵커 옮기기` 후보에서 **제외**한다([BP-26 R-26-30](26_entity_registry_and_anchors.md)).
  토스트에 "출입구는 손으로 옮기세요" 를 명시한다.

### 4.4 S4 — resize 사전 경고

`resize` 는 이미 스냅샷 undo 대상이다(`state.ts` `commitSnapshot`). 여기에 사전 검사를 얹는다.

```
┌ 크기 변경 ────────────────────────────────┐
│ 100×100 → 80×80                            │
│                                            │
│ ⚠ 앵커 3개가 맵 밖으로 나갑니다:            │
│    門 town1_to_ground (50,99)              │
│    踏 crypt_secret    (61,82)              │
│    人 tavern_drunk    (17,37) ← 안전       │
│                                            │
│ 밖으로 나간 앵커는 삭제되지 않고            │
│ V-MAP-002 오류로 남습니다.                  │
│                       [취소]  [계속]       │
└────────────────────────────────────────────┘
```

- **R-36-20** resize 는 앵커를 **자동으로 지우지도 옮기지도 않는다.** 좌표가 밖에 남는 것은
  복구 가능하지만, 지워진 앵커는 복구 불가다.

---

## 5. 앵커 오버레이와 도달 가능성 경고 — region 예약안 폐기 후

### 5.1 왜 이 절을 다시 썼는가 (D-27)

초판은 [BP-26 §3.5](26_entity_registry_and_anchors.md) 의 T1 안(region 레이어 200~255 예약)을 전제로
**팔레트 확장 · `validateMap` 신규 issue 2종 · 캔버스 초록 해칭 · `Map001.json` 정리 태스크**를 설계했다.
그 전제는 **틀렸다.** 비용 문제가 아니라 **작동하지 않는다.**

**반증 — GROUND_TRUTH 부록 J-1 (비트 연산)**

| # | 실측 위치 | 코드 | 함의 |
|---|---|---|---|
| 1 | `hadar2026_app/lib/application/map_loader.dart:44` | `map.data[index].ixEvent = _getLayerData(rawData, 5, index, size);` | z5(region) 원시값 **0~255** 가 `ixEvent` 의 **비트 0~7** 에 들어간다 |
| 2 | `hadar2026_app/lib/domain/map/tile_properties.dart:187` | `int eventType = unit.ixEvent & 0x00FF0000;` | 마스크는 **비트 16~23** 만 본다 |
| 3 | 위 둘의 결합 | `200 & 0x00FF0000 == 0` | **어떤 region 값도 타일 액션을 만들지 못한다** |
| 4 | `tools/mapEditor/server/ai_api.ts:94` | `if (z === 5 && (v < 0 \|\| v > 255)) throw …` | `0x00010000` 을 직접 심는 우회조차 막혀 있다 |
| 5 | `hadar2026_app/lib/application/map_loader.dart:60-70` | `events[]` 이름 접두사 → `eventType = 0x00010000 \| …` → `ixEvent = eventType \| id` | `ixEvent` 상위 바이트가 채워지는 **유일한 경로** |

부록 J-3 이 확정한 대로 **타일 액션의 실제 출처는 3개뿐**이다:
① 맵 JSON `events[]` 의 이름 접두사 → `ixEvent` 상위 바이트,
② `ixObj1`(objUpper) 의 B 타일 id 대역,
③ `ixTile`(ground) 의 A5 인덱스 대역.
**region(z5)·objLower(z2)·shadow(z4)·ground2(z1) 는 타일 액션에 관여하지 않는다.**

**따라서 초판이 이 절에서 설계한 것들은 전부 근거를 잃는다.**

| 초판 항목 | 처분 | 이유 |
|---|---|---|
| `buildRegion` 팔레트에 "콘텐츠 트리거 예약 200~255" 구역 추가 | **삭제** | 사람이 칠해도 게임에서 아무 일도 일어나지 않는다 |
| `[앵커와 함께 만들기]` 버튼(region 값 배정 + 앵커 생성 한 트랜잭션) | **삭제** | 배정할 값 자체가 필요 없다 |
| `R-36-21` 미사용 최솟값 자동 배정 · `R-36-22` 초록 사선 해칭 | **삭제** | 표시할 예약 대역이 없다 |
| `validateMap` 신규 issue 2종(예약 대역 고아 / 앵커 대역 미달) | **삭제** | 판정 대상이 없다. `validateMap` 은 **초판 그대로**(region 은 0~255 범위만, `ai_api.ts:380`) |
| `T-36-1` `Map001.json` (2,3) 의 `region 255` 정리 | **삭제** | 예약을 하지 않으므로 충돌이 없다. GROUND_TRUTH 부록 I-1 이 무의미해졌다 |
| `Q-36-1` 예약 폭이 200~255 로 맞는가 | **삭제** | 폭을 정할 대상이 없다 |
| 전 맵 region 실측표(13맵 전수 스캔) | **삭제** | 예약 비용을 계산하기 위한 표였고, 그 계산 자체가 불필요해졌다 |

> **`Map001.json` 을 건드리지 말 것.** GROUND_TRUTH 부록 I-1 의 참고 기록대로 이 4×4 맵은
> ground A5 `56/64/72/80`(WATER/ENTER/CLIFF/BLOCK 경계값)과 objUpper `112`(SIGN 대역)를
> 의도적으로 훑는 **테스트 픽스처**로 보인다. 정리할 이유가 사라졌으니 원래 값을 유지한다.

**교훈(D-27 말미)**: "기존 데이터 필드를 재활용한다" 는 안은 그 필드가 **실제로 읽히는지** 확인하기
전에는 채택하면 안 된다. `AI_GUIDE.md` 의 레이어 표가 "region: 지역 ID (게임이 `ixEvent` 로 읽음)" 이라
적어 둔 것이 이 오해의 출발점이었다 — **읽기는 하지만 쓰이지 않는다.**

- **T-36-1** (개정) `tools/mapEditor/AI_GUIDE.md` 의 레이어 표에서 region 설명을
  `region: 지역 ID (게임이 로드는 하지만 아무 판정에도 쓰지 않는다 — 타일 액션은 events[] 이름 · objUpper · ground 에서만 나온다)`
  로 고친다. 이 한 줄이 다음 사람의 같은 오해를 막는다. **E1 과 함께 머지**한다(문서 한 줄이므로 순서 부담 없음).

### 5.2 대신 무엇을 만드는가 — 앵커는 오버레이일 뿐이다

D-27 이 확정한 것: 콘텐츠 티어는 **타일 비트를 거치지 않고 트리거 인덱스를 직접 조회**한다
([BP-26 §4.1·§4.2](26_entity_registry_and_anchors.md) 인덱스 구조 ·
[BP-27 §4.2·§4.3](27_runtime_engine.md) 런타임 삽입 지점).
그 귀결은 에디터에게 **단순화**다.

- **R-36-21** (개정, D-27) **에디터는 앵커 때문에 맵 데이터를 바꾸지 않는다.** 앵커 레이어(의사 레이어 7,
  §2.2)는 **읽기 전용 오버레이**이고, 앵커를 놓거나 지우거나 옮기는 것은 `assets/content/**/anchors/<MAP>.json`
  만 건드린다. 맵 파일 rev 는 변하지 않고, 캔버스의 타일 base 는 다시 그리지 않는다.
- **R-36-22** (개정, D-27) 맵 타일을 함께 바꾸는 것은 **사람이 명시적으로 요청할 때만** 한다 —
  인스펙터의 `[권장 타일 놓기]` 버튼, 또는 앵커 생성 시 `autoPlaceTile`
  ([BP-31 §2.5](31_content_server_api.md)). 그 목적은 **게임이 앵커를 인식하게 만드는 것이 아니라**
  플레이어가 그 앵커에 **닿을 수 있게** 만드는 것이다.
- **R-36-22a** `trigger`·`battle(step_on)` 앵커에는 `[권장 타일 놓기]` 버튼이 **표시되지 않는다.**
  놓을 타일이 없다. 서버도 no-op 으로 응답하므로([BP-31 R-31-6b](31_content_server_api.md)) 버튼을
  두면 "눌렀는데 아무 일도 안 생긴다" 가 된다.

**캔버스 표시** (§2.3 의 색·기호 규약 안에서)

| 대상 | 표시 | 맵 데이터 |
|---|---|---|
| 모든 kind 의 앵커 | 점선 테두리 + kind 글리프(§2.3) | **미변경** |
| `trigger`/`battle(step_on)` 앵커 | 점선 테두리 + **밟는 발자국 글리프**. 타일 위에 아무 표시도 없어도 그려진다 | **미변경** |
| 도달 불가 앵커 | 테두리에 `!` 배지 + §3.3 상태바 한 줄 | **미변경** |
| bump 로만 안 닿는 앵커 | 배지 없음. §5.4 의 정보 줄에만 | **미변경** |

- **R-36-23** (개정) 콘텐츠 팩이 없는 환경에서는 앵커 레이어와 §5.3·§5.4 의 경고가 **통째로 숨는다**
  (§9.2 방어선 D1 그대로). 초판과 달리 `validateMap` 을 확장하지 않으므로, **팩이 없는 사용자에게는
  서버 응답조차 초판 이전과 바이트 단위로 동일**하다 — 회귀면이 줄었다.

### 5.3 도달 가능성 경고 — ERROR 가 아니라 WARN

D-27 이 앵커-타일 정합을 **런타임 요구에서 저작 품질 규칙으로 강등**했고([BP-26 §3.3](26_entity_registry_and_anchors.md)),
[BP-33 §4.5](33_validation_and_lint.md) 가 해당 4건을 ERROR → WARN 으로 조정했다.
에디터는 그 심각도를 **그대로 표시**한다.

`anchor_rules.ts` 가 계산하는 것은 "타일이 요구 액션인가" 가 아니라 **"플레이어가 닿을 수 있는가"** 다.

| activation | 로컬 판정식 | 어기면 무엇이 깨지는가 |
|---|---|---|
| `interact` | 그 칸이 **통행 차단**이고 인접 4칸 중 하나 이상이 통행 가능 | 통행 가능하면 파티가 밟고 지나가 **마주 볼 수 없다** → 대화·읽기·조사 불가 |
| `step_on` | 그 칸이 **통행 가능** | BLOCK 이면 **밟을 수 없다** → 발화하지 않음(거부가 아니라 호출 부재, 부록 K-1) |
| `both` | 위 둘 중 하나라도 성립 | 둘 다 실패하는 칸은 사실상 도달 불가 |

- **R-36-11** (개정, D-27) 판정 함수는 **두 개뿐**이다 — `src/rules.ts` 의 `unitAction`(기존, 무변경)과
  `src/anchor_rules.ts` 의 `reachabilityOf(kind, activation, unit, neighbors)`(신규).
  후자는 [BP-26 §3.3](26_entity_registry_and_anchors.md) 표의 **기계 번역본**이며 그 표가 정본이다.
  **`requiredActionFor(kind)` 는 만들지 않는다** — D-27 이후 "요구 액션" 이라는 개념 자체가 없다.
  대신 `recommendedTileFor(kind)` 가 `[권장 타일 놓기]` 버튼의 값을 낸다(표시·편의 전용).
- **R-36-11a** `reachabilityOf` 는 **region 을 인자로 받지 않는다.** 초판 검수(F-36-01)가 지적한
  "`unitAction` 이 region 을 안 보므로 로컬 판정 불가" 문제는 **판정 대상을 바꿈으로써 사라진다** —
  region 을 볼 필요가 애초에 없다.
- **R-36-13** (유지) 로컬 판정과 서버 판정이 어긋나면 **서버가 이기고, 그 사실을 상태바에 표시**한다
  (DEVLOG §4.6 의 수동 동기화 문제를 조용히 넘기지 않는다).
- **R-36-14** (유지·근거 강화) 에디터는 **저장을 막지 않는다.** D-27 이후에는 근거가 더 강하다 —
  도달 불가 앵커도 **게임에 실려 발화한다.** 막을 이유가 런타임에 없다.
  차단은 솔버가 그 앵커를 경유하는 퀘스트를 도달 불가로 판정할 때
  ([BP-26 R-26-7b](26_entity_registry_and_anchors.md) 의 2단 구조) 하드 게이트에서 일어난다.

**경고 문구** — `{error, hint}` 의 `hint` 를 그대로 띄운다(R-36-15). 초판의
"region {v} 는 예약 대역인데 앵커가 없습니다 — 아무 일도 일어나지 않습니다" 는 **삭제**한다.
그 문구는 "앵커가 있으면 일어난다" 는 거짓 함의를 준다.

```
⚠ anchor.core.town1_notice — (30,18) 의 타일 액션이 move 입니다.
   앵커는 발화하지만 파티가 그 칸을 밟고 지나가므로 읽을 수 없습니다.
   [권장 타일 놓기(B 116)]   [다른 칸으로 옮기기]   [무시]
```

### 5.4 진입점 게이트 비대칭을 보여 준다 (GROUND_TRUTH 부록 K)

에디터가 표시해야 할 **새 종류의 사실**이 하나 생겼다. `HDGameMain().checkTileEvent(...)` 를 부르는
곳은 `hadar2026_app/lib/presentation/panels/player_sprite.dart` 에 **3개**이고, 타일 액션 선검사의
유무가 **서로 다르다**.

| 진입점 | 줄 | presentation 게이트 | D-27 이 성립하는가 |
|---|---|---|---|
| 이동 완료(step-on) | `:193` | **없음** | ✅ 코드 변경 없이 앵커가 발화 |
| 확인키 상호작용 | `:405` | **없음** | ✅ 코드 변경 없이 앵커가 발화 |
| 이동 차단 시 상호작용(bump) | `:359` `if (action.isInteractive)` | **있음** | ❌ 타일이 talk/sign/enter 여야 호출된다 |

→ **같은 앵커가 조작 방식에 따라 다르게 동작한다.** 확인키로는 되고, 벽에 부딪혀서는 안 된다.
사람이 이것을 모르면 "왜 어떤 때는 되고 어떤 때는 안 되나" 를 콘텐츠·좌표 문제로 오진한다.

- **R-36-23a** (부록 K-2) 인스펙터는 `interact` 앵커마다 두 값을 나란히 보여 준다:
  `확인키 ✅ / 부딪힘 ❌`. 후자가 ❌ 인 것은 **에디터가 고칠 수 없다** — presentation 게이트를
  제거하는 1줄 수준의 코드 변경이 필요하고, 그 판단은 [BP-27 Q-27-10](27_runtime_engine.md) 소관이다.
- **R-36-23b** 이 표시는 **경고(⚠)가 아니라 정보(ⓘ)** 다. 대부분의 저작자는 확인키만 쓰므로
  실사용에 문제가 없고, ⚠ 로 띄우면 WARN 밀도만 올린다([BP-33 R-33-10](33_validation_and_lint.md)).
  서버도 같은 판단으로 `severity: "info"` 를 쓴다([BP-31 R-31-7a](31_content_server_api.md)).
- **R-36-23c** 게이트가 제거되면(Q-27-10 이 해소되면) 이 표시는 **사라져야 한다.**
  `GET /api/content/anchors/{map}` 응답의 `bump_gate_asymmetry` 항목 유무로 판단하고,
  에디터에 그 사실을 하드코딩하지 않는다.

```
┌ 앵커 — anchor.core.town1_gate_guard ──────────────┐
│ kind      actor          activation   interact    │
│ 좌표      (34, 12)       facing       down        │
│ 타일      objUpper B132 → talk                    │
│                                                   │
│ 도달 가능성                                        │
│   확인키로 말 걸기      ✅                          │
│   부딪혀서 말 걸기      ❌  ⓘ 게이트 미제거         │
│   인접 통행 가능 칸     2                          │
│                                                   │
│ [권장 타일 놓기]  [다른 칸으로 옮기기]  [↗ 대화]   │
└───────────────────────────────────────────────────┘
```

## 6. 퀘스트·대화 그래프 뷰어 (읽기 전용)

### 6.1 무엇을 만들고 무엇을 만들지 않는가

| | 만든다 | 만들지 않는다 |
|---|---|---|
| 렌더 | ❌ 서버 PNG 를 그대로 띄운다([BP-31 §2.9](31_content_server_api.md)) | 브라우저에서 그래프를 다시 그리기 |
| 편집 | ❌ **읽기 전용** | 노드 드래그·간선 연결·텍스트 수정 |
| 항해 | ✅ 맵 ↔ 그래프 상호 점프 | 그래프 안에서 새 노드 만들기 |

- **R-36-24** 그래프 뷰어는 **읽기 전용**이다. 근거는 [BP-12 §12.8 R-12-9](12_reference_designs.md)
  (Twine 참조에서 "시각적 드래그 저작" 은 명시적 비채택). 대화 그래프를 마우스로 잇기 시작하면
  스키마 정규화가 브라우저로 새고, D-12 의 "AI 는 API/CLI 로만 쓴다" 규칙이 사람에게만 예외가 된다.

### 6.2 창 구성

```
┌ 그래프 — dlg.gen_ep1.wife_plea ─────────────────────── [×] ┐
│ [대화 ▾] [dlg.gen_ep1.wife_plea ▾]  배율 [2 ▾]  ☑ 문제 표시│
│ ┌───────────────────────────────────────────────────────┐ │
│ │                                                       │ │
│ │        (서버가 그린 PNG — pngjs 격자 배치)             │ │
│ │                                                       │ │
│ └───────────────────────────────────────────────────────┘ │
│ 문제 3건                                                   │
│  ✗ 도달 불가 노드: node.after_refuse    [앵커로 이동]      │
│  ⚠ 종료 도달 불가: node.loop_back                          │
│  🔒 미활성 팩: item_gained 발행 지점 없음 (BP-42 대기)      │
└────────────────────────────────────────────────────────────┘
```

| 요소 | 출처 |
|---|---|
| PNG | `GET /api/content/dialogues/{id}/graph.png?scale=2&problems=1&legend=1` |
| 문제 목록 | `GET /api/content/validate` 응답에서 이 id 를 소유자로 갖는 항목만 필터 |
| `[앵커로 이동]` | 그 대화를 참조하는 앵커를 `GET /api/content/refs/{id}` 로 찾아 캔버스 이동 |
| 🔒 배지 | `POST /api/content/sim` 응답의 `supportVerdict == "UNSUPPORTED"` + `unpublishedEvents`([BP-31 §2.7](31_content_server_api.md)) |

**D-26 — 제3의 상태를 보여 준다** (F-36-06)

D-26 은 솔버 판정을 **2축**으로 나눴다: 모델 증명(`PROVEN`/`REFUTED`/`UNKNOWN`) × 실행 가능
(`SUPPORTED`/`UNSUPPORTED`). 그래서 "**증명은 됐지만 발행 지점이 없어 실제로는 진행되지 않는다**" 는
상태가 생겼고, 그것은 ✗(에러)도 ⚠(경고)도 아니다.

| 조합 | 배지 | 문구 | 사람이 해야 할 일 |
|---|---|---|---|
| `PROVEN` + `SUPPORTED` | (없음) |  | 없음 |
| `PROVEN` + `UNSUPPORTED` | **🔒 회색 자물쇠** | `미활성 팩 — {이벤트} 발행 지점 없음 ({blockedBy} 대기)` | **콘텐츠는 옳다.** 커밋하고 기다린다 |
| `REFUTED` | ✗ 빨강 | `완주 경로 없음: {reason}` | 콘텐츠를 고친다 |
| `UNKNOWN` | ⚠ 주황 | `증명 시간 초과 — 판정 불가` | 범위를 좁혀 재실행 |

- **R-36-25a** (D-26) 🔒 는 **"통과" 로 표시하지 않는다.** 하드 게이트는 통과하지만 릴리스 게이트
  (`V-L5-007`, [BP-33 §5.4](33_validation_and_lint.md))에서 차단되므로, 아무 표시도 없으면 사람이
  "다 됐다" 로 오해한다. 반대로 ✗ 로 띄우면 고칠 수 없는 것을 고치려 든다 — **그래서 별도 배지**다.
- **R-36-25b** 판정은 [BP-34](34_headless_sim_and_solver.md) 소유이고 에디터는 **표시만** 한다.
  두 축의 필드 이름(`modelVerdict`/`supportVerdict`)은 서버 응답과 CI 리포트가 동일하므로
  ([BP-31 R-31-13a](31_content_server_api.md)) 에디터도 그 이름을 그대로 읽는다.

- **R-36-25** 문제 색 팔레트는 [BP-31 R-31-18](31_content_server_api.md) 이 확정한
  "문제 색"(도달 불가 = 빨강 / 종료 도달 불가 = 주황 / 고아 = 회색)을 쓰고,
  캔버스의 **타입 색**(마젠타=TALK …)과 섞지 않는다. 창 하단에 범례를 항상 켠다.
- **R-36-26** 노드 40개 초과 시 서버가 400 을 반환하는 잠정 정책([BP-31 Q-31-1](31_content_server_api.md))에 맞춰,
  뷰어는 400 을 받으면 `?focus=<nodeId>&depth=2` 로 **자동 재시도**하고 "부분 보기" 배지를 띄운다.

### 6.3 맵 ↔ 그래프 상호 점프

| 출발 | 조작 | 도착 |
|---|---|---|
| 캔버스의 `actor` 앵커 | 인스펙터 `[↗]` | 그 액터의 `defaultDialogue` 그래프 |
| 그래프의 문제 노드 | `[앵커로 이동]` | 그 대화를 쓰는 앵커가 있는 맵·좌표(다른 맵이면 맵 전환) |
| 인스펙터의 `trigger` 앵커 | `[퀘스트 보기]` | 그 앵커의 `effects` 가 건드리는 퀘스트 그래프 |

- **R-36-27** 점프는 **역참조 인덱스**([BP-26 §5](26_entity_registry_and_anchors.md))가 있어야 성립한다.
  인덱스가 낡았으면(`GET /api/content/status` 의 `stale`) 점프 버튼을 비활성화하고
  "빌드가 필요합니다: `POST /api/content/build`" 를 띄운다.

---

## 7. `preview.png` 확장 — 앵커·퀘스트 오버레이

### 7.1 신규 쿼리 파라미터

현행 `GET /api/ai/maps/{file}/preview.png` 파라미터: `x,y,w,h,tile,night,moonlight,playerX,playerY,sight,events`.

| 신규 | 기본 | 값 | 의미 |
|---|---|---|---|
| `anchors` | `0` | `0`\|`1` | 앵커 점선 테두리 + 글리프. 콘텐츠 팩이 없으면 무시 |
| `anchorPack` | (전체) | pack id | 이 팩의 앵커만 |
| `problems` | `0` | `0`\|`1` | 정합 위반 칸을 빨강으로 덮고 `!` 배지 |
| `quest` | — | quest id | 그 퀘스트의 목표 좌표만 강조(나머지 앵커는 흐리게) |
| `legend` | `0` | `0`\|`1` | 우하단에 범례 블록. `tile >= 12` 일 때만 유효 |

```bash
# 위병 배치를 확인
curl -s "http://localhost:5310/api/ai/maps/TOWN1.json/preview.png\
?x=28&y=6&w=16&h=14&tile=24&anchors=1&problems=1&legend=1" -o town1_gate.png

# 퀘스트 하나의 동선만
curl -s "http://localhost:5310/api/ai/maps/TOWN1.json/preview.png\
?tile=6&anchors=1&quest=quest.gen_ep1.missing_scholar" -o scholar_route.png
```

### 7.2 합성 순서 (`server/preview.ts` `renderPreview`)

기존 순서는 `지면 → obj2 → obj3 → 야간 그림자 → 이벤트 테두리 → 플레이어 표시` 다.
신규 레이어는 **이벤트 테두리 다음, 플레이어 앞**에 넣는다.

```
1 지면(A5)            ← 변경 없음
2 objLower / objUpper ← 변경 없음
3 야간 그림자          ← 변경 없음
4 이벤트 테두리(실선)   ← events=1 일 때 (변경 없음)
5 앵커 테두리(점선)     ← anchors=1  (신규)
6 위반 덮기(빨강)       ← problems=1 (신규)
7 퀘스트 강조/디밍      ← quest=…    (신규)
8 플레이어 표시         ← 변경 없음
9 범례 블록            ← legend=1   (신규)
```

- **R-36-28** 앵커 오버레이는 **기존 파라미터가 없을 때 픽셀 단위로 지금과 동일한 PNG 를 낸다.**
  `anchors=0&problems=0&quest=&legend=0` 이 기본이므로 기존 호출·기존 MCP 도구·기존 문서 예제는
  **한 글자도 바뀌지 않는다**. 골든 이미지 회귀 테스트의 기준선이 이것이다(§9.3).
- **R-36-29** `tile < 16` 이면 글리프를 그리지 않는다(읽을 수 없는 글자가 점선을 지저분하게 만든다).
  `tile < 8` 이면 점선 대신 **1px 실선**으로 대체한다.
- **R-36-30** 앵커 데이터를 못 읽으면(팩 없음·파싱 실패) 400 이 아니라 **오버레이 없이 200** 을 반환하고
  PNG 메타가 아닌 응답 헤더 `X-Hadar-Warning` 에 사유를 넣는다. 미리보기가 에러로 죽으면
  AI 가 편집 결과를 확인할 수단을 잃는다.

### 7.3 MCP 도구 반영

`mcp/server.mjs` 의 `preview` 도구(`:201`)에 인자 4개를 추가한다.

```js
anchors:    z.boolean().optional().describe('앵커 오버레이(점선 테두리 + 글리프)'),
problems:   z.boolean().optional().describe('앵커-타일 정합 위반을 빨강으로 표시'),
quest:      z.string().optional().describe('이 퀘스트의 목표 좌표만 강조'),
legend:     z.boolean().optional().describe('범례 블록 표시(tile>=12 필요)'),
```

- **T-36-2** 같은 작업에서 MCP 커버리지 구멍 2개를 메운다(DEVLOG §6.9):
  `palette` 도구와 `get_event` 도구. 도구 수 15 → **19**.

---

## 8. 부록 D 대응 — `MapInfos.json` 진단과 수정 제안 (**이 장의 핵심**)

### 8.1 문제 재확인 (실측)

`hadar2026_app/lib/application/map_navigation.dart:30-51` 은 폴백을 **먼저** 세우고 인덱스가 그것을 **덮는다**:

```dart
String resolvedJsonName = '$searchName.json';   // 폴백
...
if (info['name'] == searchName) {
  resolvedJsonName = 'Map$idStr.json';          // 폴백을 덮어씀
```

`MapInfos.json` 의 15개 엔트리 **어디에도 `json` 필드가 없다**(직접 확인 — 필드는
`id/expanded/name/order/parentId/scrollX/scrollY` 뿐). 결과:

| 판정 | 이름 | 개수 |
|---|---|---|
| OK | Test, LORE_EP, MAP003, Prolog_B1, Prolog_B2, LoreContinent, CastleLore, LastDitch | 8 |
| **깨짐 — 동명 파일이 실제로 있는데 못 읽음** | **TOWN1, GROUND1, DEN1, DEN2** | **4** |
| 깨짐 — 어느 파일도 없음 | Template_TOWN, Prolog, Template_DUNGEON | 3 |

그리고 부록 F-4: **등록되지 않은 `ORIGIN` 은 폴백이 살아남아 정상 로드된다.**
즉 **인덱스에 이름을 등록하는 행위가 맵을 로드 불가로 만든다.**

### 8.2 `registerAs` 는 **이미 고쳐져 있다** (실측 정정)

`server/ai_api.ts:585-594` 가 만드는 엔트리:

```ts
const entry = {
  id: maxId + 1, expanded: false, name: body.registerAs,
  order: maxOrder + 1, parentId: 0, scrollX: 0, scrollY: 0,
  json: file,                    // ← ai_api.ts:592
};
```

- 신규 맵을 `POST /api/ai/maps` 로 만들고 `registerAs` 로 등록하면 **`json` 필드가 들어간다.**
  따라서 "앞으로 만들 맵" 은 부록 D 의 함정에 빠지지 않는다.
- **남은 갭은 정확히 하나**: **이미 존재하는 15개 엔트리**. 이것을 고칠 API 가 없고,
  그 사실을 알려 주는 진단도 없다.

- **R-36-31** 위 사실을 `AI_GUIDE.md` 의 `registerAs` 설명에 **명시**한다. 현재 문구는
  "`MapInfos.json` 에 이름을 등록해 게임이 찾을 수 있게 함" 인데, `json` 필드를 쓴다는 것과
  **그것이 없으면 `Map{id:03d}.json` 로 해석된다**는 것이 안 적혀 있어 사람이 손으로 엔트리를
  추가할 때 같은 함정을 재생산한다.

### 8.3 신규 엔드포인트 2개

#### `GET /api/ai/mapinfos` — 진단

```bash
curl -s http://localhost:5310/api/ai/mapinfos | jq .
```

```json
{
  "count": 15,
  "ok": false,
  "hasJsonField": 0,
  "entries": [
    { "id": 1,  "name": "Test",   "json": null,
      "resolved": "Map001.json", "resolvedExists": true,
      "sameNameFile": null,      "verdict": "ok" },
    { "id": 4,  "name": "TOWN1",  "json": null,
      "resolved": "Map004.json", "resolvedExists": false,
      "sameNameFile": "TOWN1.json", "verdict": "broken_same_name_exists",
      "suggest": { "json": "TOWN1.json" },
      "hint": "MapInfos.json 의 id 4 에 \"json\":\"TOWN1.json\" 을 추가하세요 (T-22-1)." },
    { "id": 8,  "name": "Template_TOWN", "json": null,
      "resolved": "Map008.json", "resolvedExists": false,
      "sameNameFile": null,      "verdict": "broken_no_candidate",
      "hint": "Map008.json 도 Template_TOWN.json 도 없습니다. 엔트리를 지우거나 맵을 만드세요." }
  ],
  "unregisteredFiles": [
    { "file": "ORIGIN.json",
      "note": "MapInfos 에 없어 폴백('<이름>.json')으로 로드됩니다 — 지금은 정상 동작합니다.",
      "hint": "이름으로 관리하려면 json 필드를 함께 넣어 등록하세요." }
  ],
  "summary": { "ok": 8, "broken_same_name_exists": 4, "broken_no_candidate": 3 }
}
```

**판정 규칙**

| verdict | 조건 | 제안 |
|---|---|---|
| `ok` | `json` 이 있고 그 파일이 있음 **또는** `json` 없고 `Map{id:03d}.json` 이 있음 | — |
| `broken_same_name_exists` | 해석 결과 파일 없음 + `<name>.json` 존재 | `json: "<name>.json"` |
| `broken_no_candidate` | 해석 결과 파일 없음 + 동명 파일도 없음 | 엔트리 삭제 또는 맵 생성 |
| `ambiguous` | `Map{id:03d}.json` 과 `<name>.json` 이 **둘 다** 존재 | **자동 수정 금지**. 사람이 정본을 고른다 |
| `shadowed` | `json` 이 있는데 그 파일이 없음 | 파일 생성 또는 `json` 정정 |

#### `POST /api/ai/mapinfos/repair` — 수정 제안 적용

```bash
# 1) 무엇이 바뀌는지만 본다 (기본)
curl -s -X POST http://localhost:5310/api/ai/mapinfos/repair \
  -H 'Content-Type: application/json' -d '{}' | jq .

# 2) 실제로 적용
curl -s -X POST http://localhost:5310/api/ai/mapinfos/repair \
  -H 'Content-Type: application/json' \
  -d '{"dryRun": false, "only": ["TOWN1","GROUND1","DEN1","DEN2"]}' | jq .
```

```json
{ "dryRun": false,
  "applied": [
    {"id":4,"name":"TOWN1",   "set":{"json":"TOWN1.json"}},
    {"id":5,"name":"GROUND1", "set":{"json":"GROUND1.json"}},
    {"id":6,"name":"DEN1",    "set":{"json":"DEN1.json"}},
    {"id":7,"name":"DEN2",    "set":{"json":"DEN2.json"}}
  ],
  "skipped": [
    {"id":8,"name":"Template_TOWN","reason":"broken_no_candidate — 후보 파일 없음"},
    {"id":9,"name":"Prolog","reason":"broken_no_candidate — 후보 파일 없음"}
  ],
  "backup": "MapInfos.json.bak.1756500000000",
  "ok": true }
```

| 규칙 | 내용 |
|---|---|
| **R-36-32** | `dryRun` 기본값은 **`true`**. `MapInfos.json` 은 **모든 맵 이름 해석의 뿌리**이므로 실수로 고쳐지면 게임 전체가 흔들린다 |
| **R-36-33** | `broken_same_name_exists` **만** 자동 수정한다. `ambiguous`·`broken_no_candidate`·`shadowed` 는 항상 `skipped` |
| **R-36-34** | 적용 전 `MapInfos.json.bak.<mtimeMs>` 백업을 남긴다. 저장 형식은 기존 `writeMapInfos`(항목당 한 줄)를 그대로 쓴다 — MV 저장 형식 보존 |
| **R-36-35** | **기존 엔트리의 `id`·`order`·`parentId` 를 절대 바꾸지 않는다.** `json` 필드 **추가만** 한다. id 를 재배열하면 세이브의 `scriptFile` 추론(Q-40-6)이 깨진다 |
| **R-36-36** | 응답은 `{error, hint}` 규약을 따르고, `hint` 는 항상 **다음에 칠 명령 한 줄**을 담는다 |

### 8.4 UI 표시 — 도구를 켠 사람이 바로 알게

| 위치 | 표시 |
|---|---|
| 맵 선택 드롭다운 | 깨진 맵 이름 옆에 `⚠` (예: `TOWN1.json ⚠ 이름으로 로드 불가`) |
| 부팅 시 배너 | `MapInfos.json 에 문제 7건 — 등록 이름 4개가 존재하지 않는 파일로 해석됩니다.` `[진단 보기]` `[4건 자동 고치기]` |
| 진단 창 | §8.3 의 `entries` 표 + 행마다 `[고치기]` |

```
┌ MapInfos 진단 ────────────────────────────────────────────┐
│ 15개 중 8개 정상 · 7개 문제 · json 필드를 가진 엔트리 0개  │
│                                                            │
│ id  이름              해석 결과      상태                   │
│  1  Test              Map001.json    ✅                     │
│  4  TOWN1             Map004.json    ❌ 없음 → TOWN1.json 있음  [고치기] │
│  5  GROUND1           Map005.json    ❌ 없음 → GROUND1.json 있음 [고치기] │
│  6  DEN1              Map006.json    ❌ 없음 → DEN1.json 있음    [고치기] │
│  7  DEN2              Map007.json    ❌ 없음 → DEN2.json 있음    [고치기] │
│  8  Template_TOWN     Map008.json    ❌ 후보 없음  (수동)   │
│  9  Prolog            Map009.json    ❌ 후보 없음  (수동)   │
│ 12  Template_DUNGEON  Map012.json    ❌ 후보 없음  (수동)   │
│                                                            │
│ ⓘ ORIGIN.json 은 등록되지 않아 폴백으로 정상 로드됩니다.    │
│    등록하면 오히려 깨집니다 — json 필드를 함께 넣으세요.    │
│                          [전부 고치기(4건)]      [닫기]    │
└────────────────────────────────────────────────────────────┘
```

- **R-36-37** 배너는 **문제가 0건이면 뜨지 않는다.** 늘 떠 있는 경고는 곧 무시된다.
- **R-36-38** 진단 창의 마지막 안내문("등록하면 오히려 깨집니다")은 **고정 문구**다.
  부록 D-1 의 역설은 도구를 처음 쓰는 사람이 반드시 한 번은 밟는 함정이므로 문서가 아니라 UI 에 둔다.

### 8.5 재발 방지 불변식

| # | 불변식 | 강제 위치 |
|---|---|---|
| **R-36-39** | 이 서버가 `MapInfos.json` 에 **새 엔트리를 쓸 때는 반드시 `json` 필드를 포함**한다 | `ai_api.ts` `registerAs`(이미 만족) + 신규 `repair` |
| **R-36-40** | `json` 필드 없는 엔트리를 **새로 만들 수 있는 경로를 두지 않는다.** 브라우저 UI 에 "이름 등록" 기능을 추가할 때도 동일 | 코드 리뷰 + §9.3 테스트 |
| **R-36-41** | `POST /api/ai/maps` 의 `registerAs` 가 **파일이 실제로 만들어진 뒤에만** 등록한다(현행 순서 유지 — `writeMapFile` → `readMapInfos`) | 현행 코드 |
| **R-36-42** | `GET /api/ai/maps` 응답에 맵마다 `registeredAs`(있으면 이름) 와 `nameResolves`(bool) 를 추가한다. AI 가 "이 파일을 게임에서 이름으로 부를 수 있는가" 를 한 번에 알 수 있게 | `ai_api.ts` `listMapFiles` |

- **R-36-42a** (F-36-03) R-36-42 는 **기존 응답 스키마를 바꾼다.** 영향을 받는 소비자가 셋이다 —
  MCP 도구 `list_maps`(`mcp/server.mjs:79-81`), 브라우저 `GET /api/maps`(`vite.config.ts:34-42`,
  `listMapFiles`(`store.ts:90`)를 공유), 그리고 **손으로 관리되는 `openapi.yaml` 의 `MapListItem` 스키마**.
  `API_MANUAL.md:91` 이 "스펙과 실제 동작이 다르면 실제 코드가 우선" 이라 적어 둔 것은 **경고가 아니라
  이미 벌어진 일의 기록**이므로, 스펙 갱신을 태스크로 남기지 않으면 그대로 재발한다(→ §10.2).
- **R-36-43** 위 진단은 [BP-33 `V-MAP-016`](33_validation_and_lint.md) 과 **같은 판정**이다.
  에디터는 그것을 **선반영**할 뿐이며, 판정 알고리즘이 갈라지면 BP-33 이 이긴다(R-33-8).

---

## 9. 구현 순서와 회귀 방지

### 9.1 순서 (5단계)

| 단계 | 내용 | 선행 | 산출 | 왜 이 순서인가 |
|---|---|---|---|---|
| **E1** | `MapInfos` 진단·수정(§8) + `GET /api/ai/maps` 확장 | 없음 | `/api/ai/mapinfos`, `/repair`, 배너 | **앵커의 키가 맵 이름**이다. 이름이 안 풀리면 앵커를 붙일 대상이 없다([BP-40 RK-40-12], T-22-1) |
| **E2** | 색·규칙 복제 제거(R-36-5) + `anchor_rules.ts`(`reachabilityOf`/`recommendedTileFor`, §5.3) + `AI_GUIDE.md` region 설명 정정(T-36-1) | E1 | `src/rules.ts` 확장, 신규 `src/anchor_rules.ts` | UI 를 얹기 전에 **공유 로직**을 한 곳에 모은다. 지금 얹으면 복제가 3벌이 된다. **D-27 로 이 단계에서 `palette.ts`·`validateMap` 은 건드리지 않으므로 회귀면이 초판보다 좁다** |
| **E3** | 앵커 오버레이 렌더 + 인스펙터 **읽기 전용**(§2.2~2.4) | E2, [BP-31 §2.5](31_content_server_api.md) | `anchors_panel.ts`, 레이어 7 | 쓰기 없이 **보기만** 먼저. 이 단계까지는 어떤 파일도 새로 쓰지 않으므로 회귀 위험이 0 |
| **E4** | 앵커 쓰기(생성·이동·삭제) + 추종 UX(§4) + 실시간 경고(§3) | E3 | 원자적 이동 호출, 토스트 | 쓰기는 서버 트랜잭션이 준비된 뒤에만 |
| **E5** | `preview.png` 오버레이(§7) + 그래프 뷰어(§6) + MCP 도구 4종 추가 | E4, [BP-31 §2.9](31_content_server_api.md) | 신규 쿼리, `graph_window.ts` | 확인 수단은 마지막. 앞 단계가 없으면 그릴 것이 없다 |

- **R-36-43a** (F-36-04) `GET /api/ai` 가 반환하는 `AI_GUIDE.md`(114줄)에 **신규 라우트 2종의 절을
  신설**한다 — `GET /api/ai/mapinfos`(진단)와 `POST /api/ai/mapinfos/repair`(수정, `dryRun` 기본 true).
  가이드에 없으면 에이전트가 발견할 방법이 없다(그 문서가 유일한 자기기술 창구다).
  R-36-31 의 `registerAs` 설명 보강, T-36-1 의 region 설명 정정과 **같은 커밋**으로 간다.
- **R-36-43b** (F-36-04) `T-36-2` 의 MCP 도구 **15 → 19** 는 신규 4종의 합이다:
  `palette` · `get_event` · `mapinfos` · `mapinfos_repair`. 초판이 앞의 2종만 적어 산술이 어긋났다
  (15+2=17). 신규 도구 이름에는 접두사를 붙이지 않는다 — 기존 15종과 같은 표면이므로
  ([BP-30 R-30-30/31](30_toolchain_overview.md)).
- **R-36-44** E1 은 **다른 모든 것보다 먼저**이고 단독으로 가치가 있다(지금 깨진 4개 맵이 살아난다).
  앵커 작업이 미뤄져도 E1 은 그대로 머지한다.
- **R-36-45** E3 과 E4 사이에 **반드시 커밋 경계**를 둔다. 읽기 전용 상태로 한 번 실사용해 보지 않고
  쓰기를 붙이면, 오버레이 좌표 오차(off-by-one)를 쓰기 버그와 구분할 수 없다.

### 9.2 회귀 방어선 4개

| # | 방어선 | 구체 |
|---|---|---|
| **D1** | **콘텐츠 팩이 없으면 아무것도 바뀌지 않는다** | 부팅 시 `assets/content/` 존재 여부를 확인해 `hasContentPack` 을 세우고, 거짓이면 레이어 7·인스펙터·앵커 체크박스·§5.3 검사·§7 오버레이를 전부 숨긴다 |
| **D2** | **기본값이 곧 현행 동작** | §7.1 신규 쿼리 전부 기본 off(R-36-28). `validateMap` 신규 issue 는 앵커가 있을 때만(R-36-23) |
| **D3** | **맵 파일 쓰기 경로를 늘리지 않는다** | 맵 파일을 실제로 직렬화·저장하는 코드는 `applyOps`(`ai_api.ts:217`) + `writeMapFile`(`store.ts:72`) **한 벌뿐**이다. [BP-31 R-31-0](31_content_server_api.md) 이 "콘텐츠 API 는 이 둘을 **내부 호출**한다" 를 확정했으므로, `/api/content/anchors/*` 와 `set_tile` op 가 존재해도 쓰기 **경로**는 늘지 않는다(F-36-02 해소). D-27 이후 앵커 편집은 대부분 맵 파일을 아예 건드리지 않는다(§5.2) |
| **D4** | **MV 직렬화 불변** | `serializeMv` 를 건드리지 않는다. `MapInfos.json` 은 `writeMapInfos`(항목당 한 줄) 그대로 |

### 9.3 테스트 — 지금 0건이라는 사실부터 고친다

DEVLOG §4.8 이 기록한 대로 이 도구에는 **자동 테스트가 하나도 없다.** 새 기능을 얹으면서
테스트를 안 만들면 회귀를 감지할 수단이 없다.

- **T-36-3** `pnpm test`(vitest) 스크립트를 신설하고 아래를 최소 세트로 넣는다.

| 테스트 | 대상 | 기준 |
|---|---|---|
| `mvmap.roundtrip.test.ts` | 저장소의 맵 13개 전부 | 파싱→직렬화가 **정규화 후 고정점**(S-36-05). `store.ts:67` 의 `normalizeData(map)` 가 읽기 시점에 데이터를 정규화하므로, 원본이 비정규 상태인 맵은 1회차가 바이트 동일하지 않을 수 있다 — 기대치는 "2회차 이후 불변" 이다 |
| `rules.action.test.ts` | `tileAction`/`objectAction`/`unitAction` | [BP-26 §3.2](26_entity_registry_and_anchors.md) 판정표 전 경계값. `hadar2026_app/test/domain/map/tile_action_test.dart` 와 **같은 표** |
| `anchor_rules.test.ts` | `reachabilityOf(kind, activation, unit, neighbors)` | [BP-26 §3.3](26_entity_registry_and_anchors.md) 표 전행 × `interact`/`step_on`/`both`. **region 입력이 없다는 것을 시그니처로 고정**(R-36-11a) |
| `content_routes.contract.test.ts` | `/api/content/*` 33 라우트([BP-31 §2.0](31_content_server_api.md)) | 라우트마다 **성공 1 + 대표 에러 1**. BP-31 F-31-08 이 소유자 없이 남긴 계약 테스트를 이 세트가 받는다 |
| `mapinfos.diagnose.test.ts` | §8.3 판정 5종 | 현재 15엔트리로 `{ok:8, broken_same_name_exists:4, broken_no_candidate:3}` 를 정확히 재현 |
| `preview.golden.test.ts` | `renderPreview` | 신규 파라미터 전부 off 일 때 기준 PNG 와 **픽셀 동일**(R-36-28). **E2 이전에 기준선을 먼저 찍는다**(S-36-03) — `EVENT_RGB`/`EVENT_TYPE_COLORS` 통합(R-36-5)이 렌더 결과를 바꾸지 않았음을 증명할 대조군이 그때 필요하다 |
| `edit.ops.test.ts` | `applyOps` 경계값 | 기존 6 op × 범위 밖 입력. 회귀 방지용 |

- **R-36-46** CI 는 `hadar2026_app` / `packages/cm2_script` 두 잡뿐이다(`.github/workflows/ci.yml`).
  세 번째 잡 `tools/mapEditor`(`pnpm install --frozen-lockfile && pnpm test`)를 추가한다. 소유는 [BP-35](35_ci_and_build.md).
- **Q-36-2** 골든 PNG 를 레포에 커밋하면 바이너리가 늘어난다(13맵 × 여러 옵션). 대표 3맵 ×
  기본 옵션만 커밋하고 나머지는 해시만 저장하는 안이 유력하나, pngjs 출력이 플랫폼 간 동일한지
  확인이 필요하다.

### 9.4 동시 편집 — SSE 로 갈 것인가 ([BP-31 Q-31-2] / [BP-30 Q-30-6] 종결)

| 안 | 내용 | 판정 |
|---|---|---|
| A. 폴링 유지(2초) | 현행. `main.ts` `hasPendingInput()`(`:593`) 가 입력 중에는 갱신을 미룬다 | **채택** |
| B. SSE 전환 | Vite dev 미들웨어에 스트리밍 엔드포인트 추가 | 보류 |

**근거**

1. 진짜 문제는 지연이 아니라 **3-way merge 부재**(DEVLOG §4.1)다. SSE 로 바꿔도
   "사람이 왼쪽, AI 가 오른쪽" 이 여전히 한쪽을 통째로 지운다. 지연 2초를 0으로 만드는 것은
   **증상만 가린다**.
2. 앵커 편집은 **원자적 이동 엔드포인트**를 거치므로([BP-26 R-26-22](26_entity_registry_and_anchors.md))
   서버가 정합을 재검사하고 실패 시 롤백한다. 앵커에 관한 한 폴링 지연이 데이터를 깨뜨리지 않는다.
3. `hasPendingInput()` 가드에 **앵커 인스펙터 입력을 추가**하면([BP-31 §4.3](31_content_server_api.md))
   사람이 타이핑 중 화면이 튀는 문제는 해소된다 — 이것이 실제 불편의 원인이다.

- **R-36-47** 폴링을 유지하고, `hasPendingInput()` 에 앵커 인스펙터의 `x`/`y`/`facing` 입력을 추가한다.
- **T-36-4** 3-way merge(DEVLOG §6.1)를 **앵커 도입 전에** 착수 후보로 올린다. 앵커가 들어오면
  "사람이 지형, AI 가 앵커" 라는 **동시 편집이 일상**이 되므로 지금보다 충돌 빈도가 오른다.
- **Q-36-3** 앵커 파일은 맵 파일과 **다른 파일**이므로 3-way merge 없이도 맵/앵커 동시 편집은
  충돌하지 않는다. 그렇다면 T-36-4 의 우선순위는 오히려 내려가는가? 실사용 1주 뒤 재평가.

---

## 10. 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 10.1 확정한 것

| # | 확정 |
|---|---|
| R-36-1 | 콘텐츠 팩이 없으면 에디터는 **지금과 완전히 동일**하게 보이고 동작한다 |
| R-36-2 | 에디터는 앵커의 **좌표만** 소유한다. 의미 필드는 읽기 전용 |
| R-36-3 | 앵커는 의사 레이어 **7**(`ANCHOR_LAYER`). 표시는 항상, 편집은 활성 레이어 7일 때만 |
| R-36-4·5 | 앵커는 이벤트와 **같은 색·다른 형태**(점선). `EVENT_TYPE_COLORS`/`EVENT_RGB` 복제를 `rules.ts` 로 통합 |
| R-36-9·10 | 앵커 변경은 로컬 undo 대상이 아니며, `Ctrl+Z` 는 그 사실을 말한다 |
| **R-36-10a** | (F-36-05) **클릭 이동도 §4.2 확인 다이얼로그를 태운다.** 오클릭 한 번이 즉시 서버 커밋을 일으키는데 되돌림 수단이 버튼 1개뿐이면 같은 조작이 앵커 레이어에서만 위험도가 다르다. `[방금 이동 취소]` 는 **최근 5회 스택**으로 둔다 |
| R-36-12·13 | 붓질 중 검사는 **로컬만**. 로컬/서버 판정이 다르면 서버가 이기고 그 사실을 표시 |
| R-36-14 | 에디터는 앵커 위반으로 **저장을 막지 않는다**. 차단은 `commit` 게이트에서 |
| R-36-16~20 | 이동 4시나리오(S1~S4)의 UX. `portal` 은 자동 수복·자동 이동 제외, resize 는 사전 경고만 |
| **R-36-21·22·22a** | (개정, D-27) **에디터는 앵커 때문에 맵 데이터를 바꾸지 않는다.** 앵커 레이어는 읽기 전용 오버레이이고, 타일 편집은 사람이 명시적으로 요청할 때만. `trigger`/`battle(step_on)` 에는 `[권장 타일 놓기]` 버튼이 없다 |
| **R-36-11·11a** | 판정 함수는 `unitAction`(기존) + `reachabilityOf`(신규) 두 개. **`requiredActionFor` 는 만들지 않고 region 도 받지 않는다** |
| **R-36-23a~c** | 진입점 게이트 비대칭(부록 K)을 인스펙터에 `확인키 ✅ / 부딪힘 ❌` 로 표시. **경고가 아니라 정보**이며, 서버 응답의 `bump_gate_asymmetry` 유무로 판단(하드코딩 금지) |
| **R-36-15a·25a·25b** | (D-26) 상태바·그래프 창은 심각도 **4종**(`✗ ⚠ 🔒 ⓘ`). `PROVEN + UNSUPPORTED` 는 🔒 회색 자물쇠 — 통과로도 실패로도 표시하지 않는다 |
| R-36-24 | 그래프 뷰어는 **읽기 전용**. 드래그 저작을 도입하지 않는다 |
| R-36-28 | `preview.png` 는 신규 파라미터 전부 off 일 때 **픽셀 단위로 기존과 동일** |
| R-36-31~43 | `MapInfos` 진단(`GET /api/ai/mapinfos`) · 수정(`POST /api/ai/mapinfos/repair`, `dryRun` 기본 true, `broken_same_name_exists` 만 자동) · 재발 방지 불변식 4개 |
| R-36-44·45 | 구현 순서 E1→E5. E1 은 단독 가치가 있어 먼저 머지, E3/E4 사이 커밋 경계 필수 |
| R-36-47 | 동시 편집은 **폴링 유지**. SSE 는 증상만 가리므로 채택하지 않음 (Q-30-6 / Q-31-2 종결) |

**실측으로 정정한 것 2건**

1. `POST /api/ai/maps` 의 `registerAs` 는 **이미 `json` 필드를 쓴다**(엔트리 객체 `ai_api.ts:584-593`,
   `json: file` 은 **`:592`**). 남은 갭은 "앞으로 만들 맵" 이 아니라 **기존 15엔트리**이며,
   그것을 고칠 경로가 없다는 것이 진짜 문제다.
2. (**개정 2판에서 뒤집힘**) 초판은 "region 200~255 예약의 충돌은 `Map001.json` 1칸뿐이라 비용이 0" 이라
   적었다. 실측 자체는 정확했지만 **질문이 틀렸다** — GROUND_TRUTH 부록 J-1 이 확정한 대로
   **region 값은 애초에 타일 액션을 만들 수 없다**(`200 & 0x00FF0000 == 0`). 비용이 0인 것이 아니라
   **효과가 0**이며, 그래서 예약안 전체가 폐기되었다(D-27, §5.1). 부록 I-1 의 충돌 1칸도 무의미해졌다.

### 10.2 다음 장으로 넘긴 것

| 넘긴 것 | 받는 장 |
|---|---|
| `/api/content/anchors/*` 의 요청·응답 스키마와 `ifRev` 규약 | [BP-31 §2.5·§4](31_content_server_api.md) |
| 앵커 정합 규칙의 **내용**과 심각도·메시지 문안 | [BP-26 §3](26_entity_registry_and_anchors.md), [BP-33 §4.5](33_validation_and_lint.md) |
| 그래프 PNG 의 배치 알고리즘·40노드 상한 정책 | [BP-31 §2.9](31_content_server_api.md) |
| `map_ops.<MAP>.json` 을 **생성**하는 규칙(좌표 배정) | [BP-32 §32.3.4](32_generation_harness.md) Binder |
| `tools/mapEditor` CI 잡 추가(T-36-3 의 실행) | [BP-35](35_ci_and_build.md) |
| **`openapi.yaml` 확장**(37,212바이트, 손 관리) — `MapListItem` 에 `registeredAs`·`nameResolves` 2필드(R-36-42), 신규 `/api/ai/mapinfos`·`/api/ai/mapinfos/repair` 2종, `/api/content/*` 33 라우트 | [BP-35](35_ci_and_build.md) 문서 게이트 (F-36-03) |
| `MapInfos.json` 을 실제로 고치는 작업(T-22-1) 의 실행 시점 | [BP-50](50_roadmap.md), [BP-51](51_task_breakdown.md) |

**`map_ops.<MAP>.json` 형식 확정** (BP-32 가 생성하고 8단계가 적용한다)

```json
{
  "map": "TOWN1",
  "file": "TOWN1.json",
  "generatedBy": "binder@run_20260830_01",
  "ops": [
    {"op":"set","layer":"objUpper","x":34,"y":12,"b":132,
     "_for":"anchor.gen_ep1.town1_scholar_wife","_reason":"actor 앵커에 talk 타일 필요"},
    {"op":"set","layer":"objUpper","x":30,"y":18,"b":116,
     "_for":"anchor.gen_ep1.town1_notice","_reason":"sign 앵커를 마주 볼 수 있게 (권장 타일)"}
  ]
}
```

> **`trigger` 앵커는 이 파일에 등장하지 않는다.** D-27 이후 놓을 타일이 없으므로 Binder 가 생성할
> op 도 없다(§5.2). `map_ops.<MAP>.json` 이 비어 있는 맵이 나오는 것은 **정상**이며, 빈 파일은
> 생성하지 않는다.

- **R-36-48** `ops` 배열은 `POST /api/ai/maps/{file}/edit` 의 `ops` 와 **동일한 형식**이다.
  `_for`/`_reason` 은 서버가 무시하는 주석 필드이며, 적용 로그와 되돌리기 근거로만 쓴다.
- **R-36-49** 한 파일은 **한 맵만** 다룬다. 여러 맵을 한 트랜잭션으로 고쳐야 하면 파일을 나누고
  8단계가 순서대로 적용한다(맵 편집은 파일 단위 원자성이 한계다).

### 10.3 열린 질문

| # | 질문 | 왜 지금 못 정하는가 | 잠정 |
|---|---|---|---|
| **Q-36-1** | ~~region 예약 폭~~ → **D-27 로 종결(질문 소멸)**. 대신 남는 질문: `trigger` 앵커가 여러 개 겹친 칸에서 **점선 테두리를 어떻게 겹쳐 그리는가** | 타일 하나에 앵커 N개가 허용되므로([BP-26 §4.4](26_entity_registry_and_anchors.md)) 표시가 뭉갠다 | 테두리 1개 + 우상단에 개수 배지(`×3`). 인스펙터가 목록으로 펼친다 |
| **Q-36-2** | 골든 PNG 를 레포에 커밋할 것인가, 해시만 둘 것인가 | pngjs 출력의 플랫폼 간 동일성 미확인 | 대표 3맵만 커밋 + 나머지는 해시 |
| **Q-36-3** | 3-way merge(T-36-4)의 우선순위 | 앵커가 별도 파일이라 충돌면이 줄 수도 있다 | 실사용 1주 뒤 재평가 |
| **Q-36-4** | 앵커 인스펙터에서 `when`(Condition)을 **읽기 전용 트리로 시각화**할 것인가 | JSON 원문은 사람이 못 읽고, 트리 뷰는 [BP-21 §6](21_content_pack_spec.md) DSL 을 UI 가 다시 해석하게 만든다 | v1 은 원문 그대로 + 한 줄 요약 문자열을 서버가 내려 주는 안 |
| **Q-36-5** | 여러 팩이 같은 맵에 앵커를 둘 때 팩 드롭다운 기본값 | 팩 위상 순서([BP-26 R-26-14](26_entity_registry_and_anchors.md))가 UI 기본값과 같아야 하는지 미확정 | 최상위 팩(다른 팩이 의존하지 않는 것) 선택 |
| **Q-36-6** | `ambiguous`(`Map00N.json` 과 `<name>.json` 이 둘 다 존재)가 실제로 발생하는가 | 현재 실측 0건이지만 `MAP003` 은 `Map003.json` 과 `MAP003` 이름이 겹칠 여지가 있다 | 자동 수정 금지 유지. 발생 시 진단 창에 두 파일의 크기·이벤트 수를 나란히 표시 |
