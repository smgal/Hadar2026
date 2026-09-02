# S3-03 맵·NPC 배치 생성 (기존 맵 에디터 API 활용)

- **상태**: BLOCKED (S3-01 대기)
- **구간**: S3
- **규모**: M
- **선행**: [S3-01](S3-01-quest-spec-format.md)
- **설계 근거**: [`tools/mapEditor/AI_GUIDE.md`](../../tools/mapEditor/AI_GUIDE.md) · [`GROUND_TRUTH` §11 · 부록 H-4 · J-1](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §4](../MILESTONES.md)

## 착수 조건

[S3-01](S3-01-quest-spec-format.md) 이 `DONE` — 개요의 `map` 절(`name`/`size`/`type`/`displayName`)과
`client.where`·`cast[].where` 가 이 이슈의 입력이다.

`tools/mapEditor` dev 서버가 떠 있어야 한다(`cd tools/mapEditor && pnpm dev` → `http://localhost:5310`).

## 문제

맵과 NPC 를 만드는 도구는 **이미 다 있다.** `tools/mapEditor/server/ai_api.ts`(828줄)가
생성·배치 편집·이벤트 CRUD·통행 검사·미리보기를 REST 로 제공하고, `GET /api/ai` 가 `AI_GUIDE.md`(114줄) 전문을 반환한다.

없는 것은 **절차**다.
- 어떤 순서로 호출해야 "플레이 가능한 마을" 이 되는지가 어디에도 적혀 있지 않다.
- NPC 좌표와 cm2 의 `On(x,y)` 를 **누가** 일치시키는지 규약이 없다.
- 자기 검토(스스로 결과를 보고 고치기)를 하지 않으면 통행 불가 마을이 나온다.

**이 이슈는 새 도구를 만들지 않는다. 절차를 확정하고 문서화한다.**

## 절차 — curl 시퀀스

`BASE=http://localhost:5310/api/ai` 로 둔다.

```bash
# 0. 가이드 전문을 먼저 읽는다 (규약이 바뀌었을 수 있다)
curl -s $BASE

# 1. 빈 id 확인 — 다음 빈 맵 id 는 16 (부록 §6)
curl -s $BASE/maps | jq '.maps[].file'

# 2. 맵 생성 + MapInfos 등록. groundA5 는 0~55 중 하나(MOVE 대역)
curl -s -X POST $BASE/maps -H 'content-type: application/json' -d '{
  "file":"Map016.json","width":40,"height":30,
  "displayName":"샘마을","groundA5":0,"registerAs":"SPRINGWELL"}'
#   → {"ok":true,"file":"Map016.json","rev":1,"registered":{"id":16,...,"json":"Map016.json"}}
#   registered.json 이 있는지 반드시 확인한다 — 부록 D-1 의 이름 해석 파손을 피하는 것이 이 필드다

# 3. 지형. 한 호출에 ops 를 모은다 (AI_GUIDE.md §쓰기: "여러 편집은 반드시 한 호출에")
curl -s -X POST $BASE/maps/Map016.json/edit -H 'content-type: application/json' -d '{"ops":[
  {"op":"rect","layer":"ground","x":0,"y":0,"w":40,"h":30,"a5":0},
  {"op":"rect","layer":"objUpper","x":0,"y":0,"w":40,"h":1,"b":9},
  {"op":"rect","layer":"objUpper","x":0,"y":29,"w":40,"h":1,"b":9},
  {"op":"rect","layer":"objUpper","x":0,"y":0,"w":1,"h":30,"b":9},
  {"op":"rect","layer":"objUpper","x":39,"y":0,"w":1,"h":30,"b":9},
  {"op":"rect","layer":"shadow","x":0,"y":0,"w":40,"h":30,"value":0}
]}'
#   둘레는 BLOCK(B 1~63 또는 A5 72~127). 마을은 shadow=0 (AI_GUIDE.md §맵 제작 팁)

# 4. NPC 배치 — objUpper 에 B 128~143 (TALK 대역)
curl -s -X POST $BASE/maps/Map016.json/edit -H 'content-type: application/json' -d '{"ops":[
  {"op":"set","layer":"objUpper","x":14,"y":20,"b":128},
  {"op":"set","layer":"objUpper","x":8,"y":26,"b":129},
  {"op":"set","layer":"objUpper","x":30,"y":26,"b":130}
]}'
#   응답의 warnings 를 확인한다

# 5. 입구 — 다른 맵에서 들어오는 칸. A5 64~69 (ENTER) 또는 B 124~127
curl -s -X POST $BASE/maps/Map016.json/edit -H 'content-type: application/json' -d '{"ops":[
  {"op":"set","layer":"ground","x":20,"y":29,"a5":64}]}'

# 6. 자기 검토 (1) — 통행 가능성
curl -s "$BASE/maps/Map016.json/passability?x=0&y=0&w=40&h=30" | jq -r '.rows[]|@tsv'
#   NPC 칸이 TALK 로, 둘레가 BLOCK 으로, 그 사이가 MOVE 로 이어져 있어야 한다

# 7. 자기 검토 (2) — 정합성
curl -s $BASE/maps/Map016.json/validate | jq
#   ok:false 면 issues 를 읽고 3~5 를 다시 한다

# 8. 자기 검토 (3) — 눈으로
curl -s "$BASE/maps/Map016.json/preview.png?tile=16&events=1" -o /tmp/Map016.png
#   멀티모달이면 반드시 이미지를 본다. TALK 는 마젠타, ENTER 는 노랑 테두리

# 9. 좌표 목록을 확정해 넘긴다 — 이것이 S3-02 의 {{map_summary}} 입력이다
curl -s $BASE/maps/Map016.json | jq '{width,height,displayName}'
```

## NPC 배치 규약

| 항목 | 규약 | 근거 |
|---|---|---|
| 레이어 | **`objUpper`(z3)** — 통행 판정에 쓰이는 유일한 오브젝트 레이어 | AI_GUIDE.md §레이어 |
| 값 | **B 타일 128~143 = TALK.** 다른 대역을 쓰면 말을 걸 수 없다 | AI_GUIDE.md §타일 의미 · `tile_properties.dart` |
| 표지판 | B 112~123 (SIGN) | 같음 |
| 입구 | A5 64~69 또는 B 124~127 (ENTER) | 같음 |
| `events[]` | **쓰지 않는다.** 정적 대사는 cm2 가 다 하고, `Event::Override()` 로 억제한다 | 부록 §4 · C-1(세이브가 `events` 를 유실하므로 정적 대사는 로드 후 사라진다) |
| `region` 레이어 | **건드리지 않는다.** 기능적으로 죽어 있다 | 부록 J-1 |
| `hadarEvent` | **쓰지 않는다.** 파싱만 되고 디스패치되지 않는다 | 부록 §6 |
| NPC 간 거리 | 서로 인접하지 않게 (마주보고 확인하는 칸이 겹치면 어느 쪽인지 모른다) | `player_sprite.dart:405` 의 마주본 칸 판정 |

### 좌표 ↔ `On(x,y)` 일치의 책임

**이 이슈(S3-03)가 좌표를 정하고, 그 목록을 [S3-02](S3-02-generation-prompt.md) 에 입력으로 넘긴다.**

- S3-03 이 배치 → `{"npc":"우물지기 노인","x":14,"y":20,"action":"TALK"}` 형태 목록 산출.
- 그 목록이 S3-02 프롬프트의 `{{map_summary}}` 로 들어가고, 프롬프트 §3 이 **"좌표를 새로 만들지 말고 이 목록에서 고른다"** 를 강제한다.
- 즉 **AI 가 좌표를 두 번 만들지 않는다.** 맵이 먼저고 cm2 가 나중이다.
- 최종 일치 검증은 [S3-04](S3-04-minimal-validation.md) 가 [S2-03](../S2-enablers/S2-03-cm2-linter.md) 의 L8·L9 로 한다.
- 순서를 뒤집으면(cm2 를 먼저 쓰고 맵을 맞추면) 좌표가 두 곳에서 생성되어 반드시 어긋난다. **순서를 규약으로 못박는다.**

## 완료 판정 기준

- [ ] 위 시퀀스가 `tools/mapEditor/AI_GUIDE.md` 에 **§퀘스트 맵 만들기** 절로 들어가 있다(`GET /api/ai` 가 반환하므로 자동 배포된다)
- [ ] 개요 1장으로 시퀀스를 돌려 맵 1개 + NPC 3개가 만들어진다
- [ ] `passability` 결과에서 NPC 3칸이 `TALK`, 둘레가 전부 `BLOCK`, 입구에서 NPC 3칸까지 `MOVE` 로 연결된다
- [ ] `validate` 가 `ok: true`
- [ ] `MapInfos.json` 항목에 `json` 필드가 있고, 게임이 그 **이름으로** 맵을 로드한다
- [ ] 좌표 목록 JSON 이 산출되어 [S3-02](S3-02-generation-prompt.md) 의 `{{map_summary}}` 로 그대로 들어간다
- [ ] 이 절차를 **두 번** 돌려 서로 다른 맵 2개가 나온다(1회성 수동 작업이 아님을 확인)

## 하지 않을 것

- **맵 에디터 API 에 새 엔드포인트를 추가하지 않는다.** 기존 것만 쓴다.
  cm2 인지 기능이 필요하면 [S2-04](../S2-enablers/S2-04-map-editor-cm2-support.md) 소관이다.
- 절차 스크립트화(`gen_map.sh`) — curl 시퀀스를 문서로 확정하는 것이 이 이슈다. 자동화는 [S3-05](S3-05-pilot-batch.md) 가 필요하면 그때.
- 지형 생성 알고리즘(방 배치·미로 생성). AI 가 `ops` 를 직접 쓴다.
- `events[]` 를 쓰는 정적 대사. 부록 C-1 때문에 로드 후 사라진다.
- 야간 조명 설계. 마을은 `shadow=0`, 동굴은 `15` 라는 기본 패턴만 따른다(AI_GUIDE.md §빛/야간).
- 콘텐츠 서버·MCP 확장 — [deferred/P2-01](../deferred/P2-01-content-server-api.md) · [P2-02](../deferred/P2-02-mcp-wrapper.md).
- **기존 맵을 편집하지 않는다.** 새 맵만 만든다([S3-04](S3-04-minimal-validation.md) 의 "기존 파일 미변경" 판정 대상).
