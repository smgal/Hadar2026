# 검수 보고서 — BP-31 콘텐츠 서버 REST/MCP API 명세

- **검수자**: R8 · **대상 파일**: `blueprint/31_content_server_api.md` (1,351줄)
- **판정**: **조건부 합격**
- **점수**: A3 B4 C4 D4 E3 F3 G5 = **26/35** (합격선 26 에 정확히 걸침)

## 0. 기계적 검사 결과

| # | 검사 | 결과 |
|---|---|---|
| 1 | 줄 수 | 1,351줄 ✅ |
| 2 | 코드 인용 (18곳 샘플) | 부록 A 는 거의 전량 정확, **본문 §6 의 2곳이 부록과 불일치** → 축 A 3점 |
| 3 | 링크 검증 | 상대 링크·`§` 절 참조 전량 해소 ✅ |
| 4 | 식별자 검증 | 배치 op **15종이라 적고 실제 16종 열거** ❌ / 에러 코드 **26종이라 적고 실제 39종** ❌ / 라우트 31개 ✅ / MCP 28종 ✅ |
| 5 | 중복 검사 | 앵커 kind↔타일 액션 표를 **BP-26 에서 두 번 옮겨 적음**(§2.5 `autoPlaceTile` 칸, §7.2 표) → 축 F |
| 6 | 미확정 표현 | `미정` 1건(Q-31-1, 열린 질문 절 — 허용) / `알아서` 1건(§7.2 가이드 산문 — 허용) ✅ |

---

## 1. 엔드포인트 × 기존 API 정합 감사표 (**요구 산출물**)

기존 `tools/mapEditor` 코드와 **직접 대조**한 결과. 20개 항목 이상.

### 1.1 계승 원칙 P1~P7 대조

| # | BP-31 주장 | 실측 (`tools/mapEditor`) | 판정 |
|---|---|---|---|
| P1 | `ai_api.ts:217` `applyOps(map, ops, warnings)` 가 **6종 op** 를 순서대로 적용하고 `writeMapFile` 한 번만(`:673-674`) | `applyOps` 217행 시작, op 6종(`set`/`rect`/`fill`/`setCells`/`resize`/`setDisplayName`), 673 `applyOps` → 674 `writeMapFile` | ✅ **정확** |
| P1 | `AI_GUIDE.md` 가 "여러 편집은 반드시 한 호출에 모을 것" 명시 | `AI_GUIDE.md:97` 에 굵게 존재 | ✅ |
| P2 | `util.ts:10-13` `sendError(res, status, error, hint)` | 10~12행, `hint ? {error,hint} : {error}` | ✅ |
| P2 | `parseLayer` 실패 hint = 레이어 목록 (`ai_api.ts:51-56`) | `:53` `사용 가능: ${LAYER_LIST}`, `:56` `hasOwnProperty` 가드 | ✅ **정확** |
| P2 | `resolveValue` 실패 hint = `value | a5 | b 중 하나 필요` (`:129`) | `:129` 문자열 그대로 | ✅ **행 단위 정확** |
| P3 | `applyOps` throw → `writeMapFile` 미도달, catch(`:818-826`) | catch 818~827 | ✅ |
| P4 | `GET /api/ai` 가 `AI_GUIDE.md` 원문을 `text/markdown` 반환 (`:493-499`) | 493~498, `res.setHeader('Content-Type','text/markdown; charset=utf-8')` | ✅ |
| P4 | MCP 첫 도구가 `get_guide`, 설명에 "반드시 한 번 읽을 것" (`mcp/server.mjs:73-78`) | 실제 **72~77** | ⚠ 1행 오차 |
| P5 | `opInt` 가 NaN 을 400 으로 (`:75-86`), 과거 `data[NaN]` 버그(DEVLOG §5) | `opInt` 75~85, DEVLOG:157 에 그 버그 기록 | ✅ |
| P5 | `parseLayer` 빈 문자열 거부 + 프로토타입 키 차단 (`:51-56`) | 52~56 | ✅ |
| P5 | `clampRegion` 교집합 (`:196-207` / 부록 `:199-208`) | 199~208 | ✅ (부록 쪽이 정확) |
| P6 | `store.ts:34-36` `revOf` = mtime(ms) 문자열 | 34~36 그대로 | ✅ **정확** |
| P6 | `vite.config.ts:83-92` 가 rev 불일치 시 `409 {error, currentRev}` | 83~92, `currentRev: revOf(p)` | ✅ **정확** — **단 `/api/map` PUT 한정** (F-31-03) |
| P7 | `store.ts:72-78`, `:137-145` tmp + `renameSync` | `writeMapFile` 72~79, `writeMapInfos` 137~144 | ✅ |

### 1.2 신규 엔드포인트 ↔ 기존 API 대응 감사

| 신규 | 대응 기존 | 형태 일치 | 실측 지적 |
|---|---|---|---|
| `GET /api/content` | `GET /api/ai` (`:493-498`) | ✅ 동형 | 별칭 `/guide` 도 기존과 동일(`rest[0]==='guide'`) ✅ |
| `GET /api/content/status` | `GET /api/ai/current` (`:501-513`) | ⚠ 부분 | 기존은 `{file,lastSeenFile,ageSeconds,hint}` 4필드. BP-31 예시는 `currentMap:{file,ageSeconds,migration}` 로 **`lastSeenFile`·`hint` 를 누락**. `uiCurrent` 재사용(`store.ts:151-156`)은 정확 ✅ |
| `POST /api/content/packs` 409 `pack_exists` | `POST /api/ai/maps` 409 (`:560`) | ✅ | `ai_api.ts:560` 문자열 `이미 존재하는 파일` 실재 ✅ |
| `POST /api/content/edit` | `POST /api/ai/maps/{f}/edit` (`:666-684`) | ⚠ | 기존은 **단일 파일**, 신규는 최대 32파일 2단계 커밋. 차이를 §1.2 가 명시 ✅ |
| `GET /api/content/validate` 200+`ok:false` | `GET .../validate` (`:770-775`) | ✅ **정확** | `sendJson(res,200,{file,rev,ok:!issues.some(error),issues})` 그대로. R-31-12 근거 성립 |
| `GET .../graph.png` | `GET .../preview.png` (`:778-811`) | ⚠ | "크기 상한을 넘으면 400" 은 **사실이 아님** (F-31-02) |
| `POST /api/content/anchors` + `set_tile` | `POST /api/ai/maps/{f}/edit` | ⚠ | 맵 파일 쓰기 경로가 **둘**이 된다. Q-31-4 가 인지하고 유지 결정 ✅ — 단 [BP-36 D3] 은 "맵 파일 쓰기 경로를 늘리지 않는다" 로 **정반대 원칙**을 선언(F-31-06) |
| `map_not_found` hint 의 등록 이름 목록 | `MapInfos.json` 15엔트리 | ✅ | 나열한 Test/LORE_EP/MAP003/TOWN1/GROUND1/DEN1/DEN2 가 실제 id 1~7 과 순서까지 일치 ✅ |
| `registerAs` 가 `json` 필드를 쓴다 (`:584-593`) | `ai_api.ts:592` `json: file` | ✅ **부록 H-4 정확 반영** |
| `source_corrupt` 500 (`store.ts:51-60`) | `readMapFile` 51~60 의 `StoreError(500, 맵 파일 JSON 손상)` | ✅ **정확** |
| `unknown_op` hint 전량 나열 (`ai_api.ts:331`) | `:331` `set | rect | fill | setCells | resize | setDisplayName` | ✅ **행 단위 정확** |
| 405 라우터 말단 (`vite.config.ts:116-124`) | 116~124 | ✅ **정확** |
| 브라우저 저장 충돌 (`src/api.ts:44-49`) | `SaveConflictError` 44~48 | ✅ |
| MCP `tool()` 헬퍼 형태 | `mcp/server.mjs:47-56` | ✅ (부록) / ❌ (§6 본문은 `:44-50`) |
| MCP 이미지 도구 형태 | `mcp/server.mjs:201-235`(preview), `237-256`(tile_image) | ✅ (부록) / ❌ (§6 본문은 `:210-240`) |
| 타일 액션 규칙 TS 포팅 (`src/rules.ts:97-137`) | `tileAction` 97~106, `objectAction` 109~119, `unitAction` 125~137 | ✅ **정확** |
| 브라우저 2초 폴링 + `hasPendingInput` 가드 | `main.ts:593`, DEVLOG §5 "사각형 드래그·사이드바 입력 포커스를 가드에 추가" | ✅ **정확** |
| `HADAR_ASSETS` 기본값 | `vite.config.ts:11` `'../../hadar2026_app/assets'` | ✅ |
| 인증 없음 = localhost 전제 | `README.md` 주의 + `vite.config.ts` 무인증 | ✅ |

**총평**: 실측 대조 24항목 중 **정확 18 · 경미 오차 4 · 사실 오류 2**. 기존 도구에 대한 이해도는 매우 높다.

---

## 2. 치명 결함

### F-31-01 배치 op 개수와 에러 코드 개수가 실제와 다르다 (계약 문서의 산술 오류)
- **위치**: `31_content_server_api.md:15`, `:31`, `:798`(§3.2 제목), `:824`(R-31-21), `:1179`, `:1294`
- **op**: 표에 15행이지만 **14행이 `set_string` / `mint_string` 두 개**를 한 칸에 담았다. R-31-21 의 hint 열거와 §6.2 `content_edit` description 이 나열하는 것은 **16개**(`create_entity | update_entity | delete_entity | set_field | unset_field | array_insert | array_remove | array_move | add_anchor | move_anchor | update_anchor | remove_anchor | set_tile | set_string | mint_string | set_migration`). "15종" 이 5곳에 박혀 있다.
- **에러 코드**: §5.1+§5.2 를 세면 **39종**(`grep '^| \`[a-z_]*\`'` 실측). 문서는 "26종" 이라 2곳에 적었다.
- **왜 치명인가**: R-31-21 은 "hint 가 **허용 op 15종 전량**을 나열한다" 를 계약으로 삼는다. 구현자가 15개만 나열하면 하나가 빠진다. R-31-31("코드는 추가만 가능") 도 카탈로그 크기를 계약으로 만드는데 숫자가 틀렸다.
- **요구 조치**: op 표를 16행으로 분리(`set_string` 과 `mint_string` 을 별행), 5곳의 "15종"→"16종", 2곳의 "26종"→"39종". 이후 개수를 본문에 박지 말고 "§3.2 표 전량" 으로 참조할 것.

### F-31-02 `preview.png` 규약 오인용 — "크기 상한을 넘으면 400"
- **위치**: §2.9 첫 문단
- **문서 주장**: "맵 `preview.png`(`ai_api.ts:777-810`)와 같은 규약: `image/png` 를 직접 반환하고, **크기 상한을 넘으면 400**"
- **실측** (`ai_api.ts:778-811`): 400 이 나는 조건은 **요청 영역이 맵과 겹치지 않을 때**(`r.w===0 || r.h===0`) 하나뿐이다. `tilePx` 는 `Math.max(2, Math.min(48, …))` 로 **조용히 클램프**되고, `sight` 도 1~5 로 클램프된다. **크기 상한 400 은 존재하지 않는다.** 20,000칸 상한은 `/region`(`:648`)과 `/passability`(`:751`)에만 있다.
- **파급**: 그래프 PNG 의 상한 정책(Q-31-1 의 "40노드 초과 시 400")이 "기존과 같은 규약" 이라는 근거를 잃는다. 오히려 기존 규약은 **클램프**이므로, 그래프도 클램프할지 400 할지 새로 정해야 한다.
- **요구 조치**: "크기 상한을 넘으면 400" → "**영역이 맵과 겹치지 않으면 400, 배율·시야는 조용히 클램프**(`ai_api.ts:794,804`)". 그래프 상한 정책은 별도 결정임을 명시.

### F-31-03 §1.1 P6 이 **`/api/ai/*` 에는 없는 성질**을 "계승 원칙" 으로 적었다
- **위치**: §1.1 P6, 한 줄 요약(`:5`), §4.1
- **문서 주장**: "**rev 기반 낙관적 잠금** … 기존 맵 API 에서 계승"
- **실측**: `rev` 선행조건 검사는 **`PUT /api/map`(브라우저 UI 전용, `vite.config.ts:84-92`)에만** 있다. `/api/ai/*` 의 쓰기 경로 4곳(`POST /maps`, `POST /maps/{f}/edit`, `POST|PATCH|DELETE /events*`) 은 **rev 를 응답에 실어 주기만 하고 요청에서 읽지 않는다**. 즉 **AI 는 오늘도 브라우저의 미저장 편집을 조용히 덮어쓸 수 있다.**
- **왜 치명인가**: 심문 항목 "콘텐츠 서버와 맵 에디터가 같은 파일을 동시에 쓸 때 rev 충돌은 어떻게 해소되나" 의 답이 §4.3 표에 있는데, 그 표는 **AI→디스크 방향의 무조건 덮어쓰기**를 다루지 않는다. §4.3 4행("사람이 편집 중(dirty)인데 AI 가 같은 맵을 씀 → 저장 시 409")은 **사람이 나중에 저장할 때** 알게 된다는 뜻이지, AI 의 쓰기가 막힌다는 뜻이 아니다. R-31-24 가 `ifRev` 를 **선택**으로 두었으므로 신규 API 도 같은 성질을 물려받는다.
- **요구 조치**: ① P6 을 "rev **표현**(mtime 문자열)과 409 응답 형태를 계승. **선행조건 검사는 `/api/map` 에만 있고 `/api/ai/*` 에는 없다**" 로 정정. ② §4.3 표에 "AI 가 쓰고 사람이 아직 저장 안 함" 행을 추가해 **사람 쪽 변경이 사라진다**는 사실과 완화책(폴링 리로드 + `hasPendingInput` 가드)을 명시. ③ **`set_tile` op 는 `ifRev.map` 을 필수로 할지** 재검토 — 앵커+타일 원자성(R-26-22)의 실효가 여기에 걸린다.

---

## 3. 중요 결함

### F-31-04 §7.2 가이드가 `region 200~255 → event 액션` 을 **현재 동작인 것처럼** 적었다
- **위치**: §7.2 §3.8 표 마지막 행, §2.5 `autoPlaceTile` 칸
- **문서 주장**: `trigger`/`battle(step_on)` → 요구 액션 `event` → **region 레이어 200~255**, `autoPlaceTile` 이 `region 200` 을 놓는다.
- **실측 (런타임)**:
  - `hadar2026_app/lib/application/map_loader.dart:44` — `map.data[index].ixEvent = _getLayerData(rawData, 5, index, size);` (region 원시값 0~255 그대로)
  - `hadar2026_app/lib/domain/map/tile_properties.dart:187` — `int eventType = unit.ixEvent & 0x00FF0000;` → **region 200(0xC8)은 마스크에 걸리지 않아 0**. `event` 액션이 **나오지 않는다.**
  - 게다가 `ai_api.ts:94` 가 region 값을 0~255 로 강제하므로 `0x00010000` 을 심을 수도 없다.
- **실측 (서버)**: R-31-7 은 앵커-타일 정합을 **서버가 `src/rules.ts` 의 `unitAction` 으로 직접 검사**한다고 했는데, `unitAction(rawGround, ixObj1, eventType)` 은 **region 을 인자로 받지도 않는다**(`rules.ts:125-137`). 즉 `trigger` 앵커의 정합을 현재 규칙 함수로는 검사할 수 없다.
- **파급**: 이 표는 소유 장 [BP-26 §3.5 T1] 의 **권고안**(로더 수정 전제)인데, BP-31 가이드는 전제를 떼고 옮겨 적어 **에이전트가 오늘 따라 하면 아무 일도 안 일어나는 데이터**를 만든다. [BP-91 W-04] 가 이미 "서버와 런타임이 다르게 판단한다" 로 적발한 문제와 같은 뿌리다.
- **요구 조치**: 전재를 지우고 [BP-26 §3.5] 링크 + "**로더 수정(T1) 전에는 미동작**" 한 줄. R-31-7 의 "서버가 직접 검사 가능" 주장에서 `trigger` kind 를 **예외로 뺄 것**.

### F-31-05 31 라우트 "전수 명세" 인데 본문이 쓰는 라우트 2개가 표에 없다
- `GET /api/content/rev?path=<pack>/anchors/TOWN1.json` — §4.3 1행이 브라우저 폴링 경로로 사용. §2.0 표에 없음.
- `GET /api/content/sim/trace/{id}.json` — §2.7 `POST /sim` 응답의 `traceUrl` 이 가리키는 실체. §2.0 표에 없음(R-31-13 이 24시간 보존까지 규정).
- **요구 조치**: 두 라우트를 표에 추가해 33으로 하거나, "보조 라우트" 절로 분리해 명시. 표 제목이 "전수 목록" 이므로 누락은 계약 결함이다.

### F-31-06 [BP-36 §9.2 D3] 과 정면 충돌 — 맵 파일 쓰기 경로의 개수
- **BP-31**: `set_tile` op(§3.2 13번), `POST /api/content/anchors`(`tilePlaced`), `POST .../move`(`tileOps`) 가 **콘텐츠 API 안에서 맵 파일을 쓴다**. Q-31-4 는 "유지" 로 결론.
- **BP-36 D3**: "**맵 파일 쓰기 경로를 늘리지 않는다** — 앵커 편집이 맵 파일을 건드리는 유일한 경로는 기존 `POST /api/ai/maps/{file}/edit` 다. 신규 쓰기 함수를 만들지 않는다."
- 두 장이 같은 사실을 반대로 규정한다. 구현자가 어느 쪽을 따를지 알 수 없다.
- **요구 조치**: 한 줄로 조정 — "콘텐츠 API 는 **내부적으로 기존 `applyOps`/`writeMapFile` 을 호출**하며 새 쓰기 함수를 만들지 않는다" 로 통일하면 둘 다 만족한다. 어느 장이 소유인지 D-18 표에 없으므로 메인 중재 필요.

### F-31-07 §6 본문의 MCP 인용 2곳이 자기 부록과 어긋난다
- 본문: `tool()` 헬퍼 `mcp/server.mjs:44-50`, 이미지 도구 `:210-240`
- 부록 A: `:47-56`, `:201-235`
- 실측: `tool()` 47~56, `preview` registerTool 201~235, `tile_image` 237~256 → **부록이 옳고 본문이 틀렸다.**
- **요구 조치**: 본문을 부록 값으로 통일.

### F-31-08 축 E — 이 API 자신의 검증 수단이 없다
- 31 라우트·39 에러 코드·16 op 를 확정했으나 **"이것이 명세대로 동작하는지 무엇이 보장하는가"** 가 없다. `openapi.yaml` 확장은 [BP-35] 로 넘겼고, 계약 테스트는 어느 장도 받지 않는다.
- 실측 배경: `tools/mapEditor` 는 **자동 테스트가 0건**(DEVLOG §4.8). [BP-36 T-36-3] 이 vitest 6종을 신설하지만 **콘텐츠 라우트는 그 목록에 없다.**
- **요구 조치**: 최소한 "각 라우트는 성공 1 + 대표 에러 1 의 계약 테스트를 갖는다(소유: BP-35 또는 BP-36 T-36-3 확장)" 한 줄을 §8.2 에 추가.

---

## 4. 설계 반대 심문

| 심문 | 답 | 판정 |
|---|---|---|
| AI 가 API 대신 파일을 직접 쓰는 걸 무엇이 막나 | [BP-30 §3] 위임 + §7.2 가이드 §1 표 "소스 파일 직접 쓰기 — **API 만 쓸 것**" | ✅ 위임 적절 |
| **동시 쓰기 시 rev 충돌 해소** | §4.1~§4.3 + R-31-29 파일 단위 쓰기 락(423) + `diffSummary` | ⚠ **F-31-03** — 기존 `/api/ai/*` 에 선행조건이 없다는 사실을 짚지 않아, "계승" 이라는 서술이 안전 착시를 만든다 |
| 배치 중간 실패 시 이미 쓴 것 / 롤백 단위 | §3.3 2단계 커밋 + **R-31-22 가 다중 rename 의 비원자성을 인정**하고 `.bak` 되돌림 + `500 partial_commit` + git 최종 안전망 | ✅ **모범적**. 보장할 수 없는 것을 보장한다고 하지 않았다 |
| 배치 상한 | R-31-23 32파일, 초과 시 400 | ✅ 근거("실패 시 되돌릴 범위 통제")까지 명시 |
| 프롬프트 버전 드리프트 | 이 장 범위 밖 | — |
| CLI 미설치 환경 | `cli.available:false` → 503 `cli_unavailable` + `HADAR_DART_BIN` (Q-30-3 수신) | ✅ |
| 검사 실패를 4xx 로 만들지 않는 근거 | R-31-12 가 `ai_api.ts:770-775` 실물로 뒷받침 | ✅ **가장 잘 논증된 항목** |

---

## 5. D-25 / D-18 준수 검사

**남의 소유 스키마 전재 — grep 결과**

| 대상 | 결과 |
|---|---|
| Condition op 18종 열거 | **0건** ✅ (§2.8 은 "이름과 시그니처만" 이라고 개수만 인용) |
| Effect do 22종 열거 | **0건** ✅ (`give_item` 등은 예시 JSON 안에서만 등장) |
| 월드 이벤트 12종 이름 | **0건** ✅ |
| Quest/Dialogue 필드 스키마 | **0건** ✅ (§1.3 "요청/응답 본문의 엔티티 스키마는 이 장이 정의하지 않는다" 를 실제로 지킴) |
| **앵커 kind ↔ 요구 타일 액션·대표 타일** | **2건 전재** ❌ — §2.5 `autoPlaceTile` 칸(B132/B116/B125/region 200), §7.2 §3.8 표 6행 전량. 소유는 [BP-26 §3.3·§3.5] |

→ **D-25 취지 위반 2건.** 특히 §7.2 전재본은 F-31-04 의 오류를 그대로 품고 있어, "옮겨 적는 행위 자체가 오류원" 이라는 D-20a 교훈의 재현 사례다. 가이드 문서는 **API 호출 방법**만 담고 타일 규칙은 `GET /api/ai`(AI_GUIDE.md)로 넘기는 것이 옳다.

---

## 6. 개선 제안 (선택)

### S-31-01 `GET /api/content/status` 를 기존 `current` 와 정확히 동형으로
기존 응답의 `lastSeenFile`·`hint` 를 빠뜨렸다. `ageSeconds>=10` 일 때 "사용자에게 확인하라" 는 hint 는 에이전트 행동을 실제로 바꾸는 필드다(`ai_api.ts:508-510`).

### S-31-02 `mint` 의 비멱등성(R-31-10)을 배치 `dryRun` 과 함께 다시 볼 것
§3.4 는 `dryRun` 이 "1~4단계만 수행" 이라 했는데, `mint_string` 은 키를 **발급**한다. dryRun 에서 발급한 키를 뒤 op 가 참조하는 §3.4 예시가 실제로 성립하려면 dryRun 안에서도 키가 결정론적으로 유도돼야 한다. 그 규칙을 한 줄로 명시할 것("키는 `owner+slot` 의 순수 함수").

### S-31-03 `X-Hadar-Actor` 헤더 규약을 §1.3 공통 규약으로 올릴 것
지금은 §2.3 표 안과 Q-31-5 에만 있어 발견이 어렵다.

### S-31-04 `content_edit` 의 `ifRev` 형태 3종이 타입이 다르다
§4.2 는 문자열 / `{anchors,map}` / `{파일경로:rev}` 3형태를 허용하는데, MCP 스키마(§6.1 #11)는 `z.record(z.string())` 하나뿐이라 문자열 형태를 받지 못한다. 하나로 통일하거나 union 으로 명시.

### S-31-05 `error` 문자열의 언어
기존 API 는 전량 한국어 메시지다(`ai_api.ts` 실측). BP-31 예시도 한국어라 일관되지만, 규약으로 못 박혀 있지 않다. §1.3 에 한 줄.

---

## 7. 잘된 점

- **§1.1 계승 원칙 5+2** 가 이 기획서에서 기존 코드를 가장 성실하게 읽은 절이다. `opInt` NaN 방어, `parseLayer` 프로토타입 가드, `clampRegion` 교집합 같은 **DEVLOG §5 의 감사 결과까지 소화**해 원칙으로 승격시켰다.
- **R-31-12**(검사 위반은 200+`ok:false`)를 `ai_api.ts:770-775` 실물로 정당화한 것은 모범적인 논증이다.
- **R-31-22** 가 POSIX 다중 rename 의 비원자성을 인정하고 (a)(b)(c) 3단 완화를 제시한 것 — 보장 못 하는 것을 계약에 넣지 않는 태도.
- **§5 에러 카탈로그의 hint 품질**. R-31-30 이 "hint 는 행동 지시" 를 규약화하고, 실제 예시가 **그대로 붙여 넣을 수 있는 curl/op** 를 담았다. 기존 `{error,hint}` 철학의 정확한 확장.
- **부록 H-4 를 정확히 반영**했다(`ai_api.ts:584-593`, `json: file` at `:592`). "registerAs 에 json 이 없다" 는 오래된 오해를 재생산하지 않았다.
- 31 라우트 × curl 예시 × 응답 JSON 이 전부 붙어 있어 **이 문서만으로 구현이 가능**하다(축 C 의 본령).

---

## 8. 다른 장에 전파해야 할 발견

- **[BP-26]** F-31-04 — `trigger` 앵커의 `event` 액션은 **런타임 로더 수정 없이는 성립하지 않는다**(`map_loader.dart:44` + `tile_properties.dart:187` 마스크). §3.5 T1 이 그 전제를 갖고 있다면, 이를 **선결 과제로 승격**하고 BP-31/36/90/91 이 전제 없이 인용하지 못하게 해야 한다.
- **[BP-36]** F-31-06 — "맵 파일 쓰기 경로" 원칙이 두 장에서 반대다. 중재 필요.
- **[BP-30]** F-30-01 과 짝: §7.2 "자주 하는 실수" 5번(`has_flag`→`unknown_op`)이 **DSL op 와 배치 op 를 혼동**한다. `has_flag`/`set_quest` 는 서버가 잡지 못하고 `validate` 가 잡는다. 두 장 동시 수정.
- **[BP-33]** §5 의 `rule` 필드(`L-33-04`, `A-26-01`)가 BP-33 의 규칙 번호 체계와 일치하는지 BP-33 이 확인해야 한다. 이 장은 예시로만 썼다.
- **[BP-35]** F-31-08 — 콘텐츠 라우트의 계약 테스트 소유자가 없다. `openapi.yaml` 확장과 함께 받을 것.
- **[BP-34]/[BP-53]** **D-26 미반영** — `POST /api/content/sim` 의 `result` 값 집합(§2.7)이 D-26 의 **2축 판정**(모델 증명 `PROVEN|REFUTED|UNKNOWN` × 실행 가능 `SUPPORTED|UNSUPPORTED`)을 담지 않는다. 현재 예시는 `"result": "unreachable_stage"` 같은 단일 문자열뿐이다. `PROVEN + UNSUPPORTED` 를 구분해 응답해야 에이전트가 "커밋은 되지만 릴리스는 막힌다" 를 알 수 있다. `grep D-26` 결과 이 장에 **0건**.
- **[BP-32]** `GET /api/content/context` 의 `budget` 기본값이 **40,000 문자**인데 [BP-32 §32.5.2] 는 **57,000 토큰**이다. §32.3.1 은 "서버와 CLI 가 **같은 코드**를 쓰고 산출물이 동일해야 한다" 고 못 박았으므로 **단위와 값을 반드시 통일**해야 한다.

## 9. 결정 재검토 요청

없음. D-12(같은 프로세스·같은 에러 규약)·D-15·D-09 를 정확히 따랐다.
