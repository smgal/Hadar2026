# S2-04 맵 에디터가 cm2·플래그를 인지한다

- **상태**: BLOCKED (S1-99 대기)
- **구간**: S2
- **규모**: M
- **선행**: [S1-99](../S1-sample-quest/S1-99-friction-log.md) · [S2-03](S2-03-cm2-linter.md)(린터를 재사용)
- **설계 근거**: [MILESTONES §3](../MILESTONES.md) · [`GROUND_TRUTH` §11 맵 에디터 API · 부록 H-4 · J-1](../../blueprint/_meta/GROUND_TRUTH.md) · [`tools/mapEditor/AI_GUIDE.md`](../../tools/mapEditor/AI_GUIDE.md)

## 착수 조건

[S1-99 마찰 기록](../S1-sample-quest/S1-99-friction-log.md) 이 이 문제를 **실제로 겪었다고 확인**해야 한다.
겪지 않았으면 이 이슈는 `DROPPED` 다.

다음 중 하나가 기록되어 있어야 한다.
- NPC 를 놓은 좌표를 cm2 의 `On(x,y)` 에 **손으로 옮겨 적었다**
- 맵을 고친 뒤 cm2 의 좌표가 맞는지 눈으로 다시 확인했다
- 말을 걸어도 아무 반응이 없어, 좌표가 어긋난 것인지 스크립트가 틀린 것인지 구분하지 못했다

## S1 이 겪지 않았다면

**NPC 3명이면 좌표 3쌍이다.** 종이에 적어 두면 틀리지 않고, 틀려도 `preview.png` 에서 마젠타 테두리(TALK)를
보며 바로 찾는다. 즉 S1 규모에서는 **에디터가 몰라도 사람이 감당한다.**

버려도 되는 근거: [S2-03](S2-03-cm2-linter.md) 의 **L8·L9 가 이 문제의 90%를 이미 잡는다** —
좌표가 맵 범위 안인지, 그 칸이 실제로 TALK 타일인지를 CLI 가 판정한다.
이 이슈가 추가로 주는 것은 **시각적 확인과 편집 중 경고**뿐이다.
사람이 에디터 GUI 를 거의 안 쓰고 API·CLI 로만 작업한다면 `DROPPED` 가 타당하다.
**다만 `registerAs` 의 `cm2` 필드 확장(§4)만은 살려서 [S2-02](S2-02-cm2-override-chain.md) 로 옮긴다** —
그것은 시각화가 아니라 데이터 규약이다.

## 문제

### 1. 에디터는 맵만 안다

`tools/mapEditor/server/ai_api.ts`(828줄)의 엔드포인트는 전부 맵 JSON 만 읽고 쓴다.
`GET /api/ai/maps/{file}/validate`(`:769-773`) 도 맵 내부 정합성만 본다 — **cm2 파일을 열지 않는다.**

→ `Map016.cm2` 의 `On(14,30)` 이 가리키는 칸이 실제로 TALK 인지 에디터는 모른다.
→ 사람이 objUpper 의 NPC 를 한 칸 옮기면 cm2 는 조용히 죽는다. 경고가 없다.

### 2. `registerAs` 가 `cm2` 필드를 쓰지 않는다

`tools/mapEditor/server/ai_api.ts:584-593`:

```ts
const entry = {
  id: maxId + 1,
  expanded: false,
  name: body.registerAs,
  order: maxOrder + 1,
  parentId: 0,
  scrollX: 0,
  scrollY: 0,
  json: file,            // ← :592  json 만 쓴다. cm2 가 없다
};
```

`json` 은 쓴다(부록 H-4 — 그 덕에 신규 맵은 부록 D-1 의 이름 해석 파손을 피한다).
그러나 `cm2` 가 없으므로 `HDMapNavigation` 이 `map_navigation.dart:44` 의 기본값
`'Map$idStr.cm2'` 로 해석한다. 즉 **파일명이 id 에 묶인다.**

→ `registerAs: "QUEST_TOWN"` + `file: "Map020.json"` 으로 만든 맵은 cm2 를 반드시 `Map020.cm2` 로 이름 붙여야 한다.
   [S2-02](S2-02-cm2-override-chain.md) 가 도입할 **cm2 배열**은 이 경로로는 아예 쓸 수 없다.

### 3. 플래그 사용 현황이 보이지 않는다

어떤 맵의 어떤 칸이 어떤 플래그를 읽고 쓰는지는 cm2 를 읽어야만 안다.
[S2-01](S2-01-flag-registry.md) 의 레지스트리가 생겨도 **"이 플래그는 어디서 켜지고 어디서 읽히나"** 는
맵 위에서 봐야 이해된다.

## 왜 지금 고쳐야 하는가

- [S3-03](../S3-generation/S3-03-map-generation.md) 은 이 API 를 **그대로** 쓴다. AI 가 NPC 를 놓고 좌표를 cm2 에 적는데,
  둘의 일치를 확인할 곳이 지금은 없다.
- [S3-04](../S3-generation/S3-04-minimal-validation.md) 의 "새 맵이 이름으로 로드되는지" 판정은
  `MapInfos.json` 항목이 **정확히** 만들어졌는지에 달려 있고, 그 항목을 만드는 것이 `registerAs` 다.

## 무엇을 할 것인가

### 1. `GET /api/ai/maps/{file}/scripts` — cm2 참조 목록

응답:
```json
{"file":"Map016.json","rev":7, "cm2":["Map016.cm2","quest_Q1.cm2"],
 "refs":[{"script":"Map016.cm2","line":12,"kind":"On","x":14,"y":30,"scriptMode":"FLAG_TALK","tileAction":"TALK","match":true},
         {"script":"quest_Q1.cm2","line":8,"kind":"OnArea","x":23,"y":21,"x2":23,"y2":22,"scriptMode":"FLAG_EVENT","tileAction":"MOVE","match":false,"hint":"이 칸은 EVENT 타일이 아니다 — objUpper 나 events[] 를 확인할 것"}],
 "flags":[{"index":60,"name":"Q1_ACCEPTED","reads":[{"script":"quest_Q1.cm2","line":9}],"writes":[{"script":"quest_Q1.cm2","line":21}]}]}
```

**추출은 [S2-03](S2-03-cm2-linter.md) 의 `cm2_lint --json` 을 자식 프로세스로 호출해 얻는다.**
TS 에 cm2 파서를 두 번째로 만들지 않는다(S2-03 의 권고 근거와 동일).

### 2. `validate` 확장 — cm2 참조 불일치를 issue 로

`ai_api.ts:769-773` 의 `issues[]` 에 `severity: "error"` 로 추가:
`On(14,30) 이 가리키는 칸이 TALK 타일이 아니다 (Map016.cm2:12)`.
기존 `{ok, issues:[{severity,message}]}` 형태를 그대로 쓴다 — **응답 스키마를 바꾸지 않는다.**

### 3. 편집 op 가 cm2 참조 칸을 건드리면 경고

`POST /api/ai/maps/{file}/edit` 의 응답에는 이미 `warnings` 가 있다(AI_GUIDE.md §쓰기).
op 가 cm2 참조 좌표의 `objUpper` 를 바꾸면 그 배열에 추가:
`(14,30) 은 Map016.cm2:12 의 On() 대상이다 — 액션이 TALK→MOVE 로 바뀌었다`.
**차단하지 않는다.** 좌표를 옮기고 cm2 를 뒤이어 고치는 흐름을 막으면 안 된다.

### 4. `registerAs` 가 `cm2` 도 쓴다

`ai_api.ts:584-593` 의 `entry` 에 `cm2` 를 추가한다.

| 요청 | `MapInfos.json` 에 기록 |
|---|---|
| `registerAs` 만 | 지금과 동일 (`cm2` 없음 → 기본 해석) |
| `registerAs` + `cm2: "quest_town.cm2"` | `"cm2": "quest_town.cm2"` |
| `registerAs` + `cm2: ["Map020.cm2","quest_Q1.cm2"]` | 배열 그대로 ([S2-02](S2-02-cm2-override-chain.md) 의 체인) |

`cm2` 로 지정한 파일이 `assets/` 에 없으면 `{error, hint}` 로 거절한다 — cm2 로드 실패가
`script_engine_adapter.dart:97` 에서 침묵하므로(부록 A-2), **등록 시점이 막을 수 있는 마지막 지점**이다.

### 5. 브라우저 UI 오버레이

`On`/`OnArea` 좌표에 배지를 그린다. `match: false` 는 빨강. 클릭하면 `스크립트:줄` 을 보여준다.
플래그 필터: 특정 인덱스를 선택하면 읽는 칸/쓰는 칸을 다른 색으로.

### 기존 API 규약 계승 (전부 그대로)

| 규약 | 어디서 | 이 이슈에서 |
|---|---|---|
| `{error, hint}` 에러 | AI_GUIDE.md §API 레퍼런스 | 4번의 거절이 이 형태 |
| `rev` 동시성 | `ai_api.ts:569,608,674,713…` | `/scripts` 응답에도 `rev` 포함 |
| 배치 `ops` | `POST .../edit` | op 를 추가하지 않는다. `warnings` 만 늘린다 |
| `GET /api/ai` 가 가이드 전문 반환 | AI_GUIDE.md 머리말 | **AI_GUIDE.md 에 §cm2 절을 추가**해야 자동 반영된다 |
| MCP 래퍼 | `mcp/server.mjs` | 새 엔드포인트 1개에 대응하는 도구 1개 추가 |

## 완료 판정 기준

- [ ] `GET /api/ai/maps/Map002.json/scripts` 가 `Map002.cm2` 의 `On(30,20)`·`On(30,25)`·`On(30,28)`·`OnArea(23,21,23,22)` **4건**을 각각의 `scriptMode`·`tileAction`·`match` 와 함께 반환한다
- [ ] 그중 `match: false` 인 것이 있으면 `validate` 의 `issues[]` 에도 같은 개수로 나타난다
- [ ] `match: true` 인 칸의 `objUpper` 를 `edit` 으로 0 으로 바꾸면 응답 `warnings` 에 그 좌표와 `스크립트:줄` 이 들어온다
- [ ] `POST /api/ai/maps` 에 `cm2: "quest_x.cm2"` 를 주면 `MapInfos.json` 항목에 그 값이 들어가고, 게임이 그 파일을 로드한다
- [ ] `cm2` 로 없는 파일을 주면 `{error, hint}` 로 거절되고 **`MapInfos.json` 이 변경되지 않는다**
- [ ] `AI_GUIDE.md` 에 §cm2 절이 있고 `GET /api/ai` 가 그것을 포함해 반환한다
- [ ] cm2 를 파싱하는 TS 코드가 **0줄**이다(전부 `cm2_lint --json` 위임)

## 하지 않을 것

- **cm2 편집 기능.** 에디터는 cm2 를 **읽기만** 한다. 쓰기는 사람/AI 가 파일로 한다.
- cm2 파서의 TS 재구현. [S2-03](S2-03-cm2-linter.md) CLI 위임이 전제다.
- 좌표 변경 시 cm2 자동 수정(리팩터). 경고까지다.
- `region` 레이어 기반 앵커·트리거. **부록 J-1 이 region 이 기능적으로 죽어 있음을 증명했다**
  (`map_loader.dart:44` 가 0~255 를 하위 바이트에 넣고, `tile_properties.dart:186` 은 비트 16~23 을 본다).
  [deferred/P1-10](../deferred/P1-10-anchors.md) 소관이며, 그 설계는 J-2 가 무효화한 상태다.
- 콘텐츠 서버·MCP 확장 노선 — [deferred/P2-01](../deferred/P2-01-content-server-api.md) · [P2-02](../deferred/P2-02-mcp-wrapper.md).
  이 이슈는 **기존 에디터 API 에 엔드포인트 1개와 필드 1개를 더하는 것**이다.
- `hadarEvent` 의 `warp`/`oneshot` 디스패치 구현(부록 §6 — 파싱만 되고 실행 안 됨). 별건이다.
