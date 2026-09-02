# [S1-02] 새 맵 `Map016.json`(석문 초소)과 NPC 3명을 배치한다

- **상태**: TODO · **구간**: S1 · **규모**: M · **선행**: [S1-01](S1-01-quest-design.md)
- **설계 근거**: [MILESTONES §0·§2](../MILESTONES.md) · [맵 에디터 AI API](../../tools/mapEditor/AI_GUIDE.md) ·
  [`GROUND_TRUTH`](../../blueprint/_meta/GROUND_TRUTH.md) §6·§11 · 부록 J-3 · 부록 H-4

## 문제

퀘스트를 놓을 장소가 없다. 등록된 맵 이름 15개 중 7개가 존재하지 않는 파일로 해석되고(부록 D-1),
걸어 다닐 수 있는 것은 `LORE_EP`(`Map002.json`, 50×50)와 `MAP003`(21×21) 정도다.
**다음 빈 id 는 16**, 신규 등록 경로는 정상이다(부록 H-4).

## 왜 지금 해야 하는가

- [S1-03](S1-03-quest-cm2.md) 의 `On(x,y)` 는 **좌표 하드코딩**이라 맵이 먼저 확정되어야 한다.
- 진입 연결이 없으면 [S1-04](S1-04-playthrough.md) 가 플레이로 도달할 수 없다.

## 무엇을 할 것인가

### 1. `MapInfos.json` 에 추가할 정확한 한 줄

`hadar2026_app/assets/maps/MapInfos.json` 은 항목 하나당 한 줄로 직렬화된다
(`tools/mapEditor/server/store.ts:137-144`). **마지막 항목(`id:15` LastDitch) 뒤에 `,` 를 붙이고 아래 한 줄을 추가**한다:

```json
{"id":16,"expanded":false,"name":"SEOKMUN","order":16,"parentId":0,"scrollX":0,"scrollY":0,"json":"Map016.json"}
```

- §3 의 `POST /api/ai/maps` 에 `registerAs:"SEOKMUN"` 을 주면 **에디터가 이 줄을 정확히 이 형태로 써 준다**
  (`tools/mapEditor/server/ai_api.ts:585-596` — id = maxId+1 = 16, order = maxOrder+1 = 16). 손으로 쓰지 말 것.
- **`cm2` 필드는 넣지 않는다** — `hadar2026_app/lib/application/map_navigation.dart:44-45` 가 id 로부터
  `cm2Path = 'Map016.cm2'` 를 기본 부여한다. `json` 필드는 있어도 무해하다(부록 H-4).

### 2. 맵 구조 (21×21 — `Map003.json` 과 같은 크기)

```
X = BLOCK(A5 105)   . = 바닥(A5 8)   N = NPC(objUpper TALK)   S = 푯말(objUpper SIGN)   E = 남문(A5 64)

      0123456789012345678901   ← x
    0 XXXXXXXXXXXXXXXXXXXXX
    1 X...................X
    2 X......XXXXXXX......X   봉화대 담장 = x7~13, y2~6
    3 X......X..S..X......X   S = (10,3) 봉화대 푯말
  4~5 X......X.....X......X   담장 내부 바닥 x8~12
    6 X......XXX.XXX......X   (10,6) = 봉화대 문. 퀘스트 완료 시 A5 8 로 바뀐다
    7 X...................X
    8 X.........N.........X   N = (10,8) 파수 대장 두람
 9~13 X...................X
   14 X....N.........N....X   N = (5,14) 창고지기 가른 / (15,14) 우물가의 아이
   15 X.............X.....X   X = (14,15) 우물 (objUpper B 9, 장식·통행불가)
16~19 X...................X   시작 위치 = (10,19)
   20 XXXXXXXXXXEXXXXXXXXXX   E = (10,20) 남문 → LORE_EP 복귀
```

- 둘레는 BLOCK(A5 **105** — `Map003.json` 이 벽으로 259칸 쓰는 실측값), 입구는 ENTER(A5 **64** —
  `Map002/003/GROUND1/Map013.json` 이 실제로 쓰는 유일한 ENTER 값), 바닥은 A5 **8**
  (`TOWN1.json` 1,300칸 실측). `shadow` 는 전 칸 **0**(마을은 밝음, AI_GUIDE §빛/야간).
- **봉화대 문을 ground 레이어의 BLOCK 타일로 만드는 것이 핵심이다.** `Map::ChangeTile` 은
  `script_engine_adapter.dart:350-355` → `map_model.dart:37-42` 로 **`ixTile`(ground)만** 바꾼다 —
  objUpper 로 막아 두면 `Map::ChangeTile` 이 **조용한 no-op** 이 된다.

### 3. 맵 에디터 API 로 만드는 절차 (dev 서버: `cd tools/mapEditor && pnpm dev` → `http://localhost:5310`)

```bash
# (1) 새 맵 생성 + MapInfos 등록. groundA5=105 로 전면을 벽으로 채운다
curl -s -X POST http://localhost:5310/api/ai/maps -H 'Content-Type: application/json' \
  -d '{"file":"Map016.json","width":21,"height":21,"displayName":"석문 초소","groundA5":105,"registerAs":"SEOKMUN"}'

# (2) 배치 편집 — 지형·NPC·푯말·남문을 한 호출에 모은다 (AI_GUIDE: 여러 편집은 반드시 한 호출)
curl -s -X POST http://localhost:5310/api/ai/maps/Map016.json/edit -H 'Content-Type: application/json' \
  -d '{"ops":[
    {"op":"rect","layer":"ground","x":1,"y":1,"w":19,"h":19,"a5":8},
    {"op":"rect","layer":"ground","x":7,"y":2,"w":7,"h":5,"a5":105},
    {"op":"rect","layer":"ground","x":8,"y":3,"w":5,"h":3,"a5":8},
    {"op":"set","layer":"ground","x":10,"y":20,"a5":64},
    {"op":"rect","layer":"shadow","x":0,"y":0,"w":21,"h":21,"value":0},
    {"op":"set","layer":"objUpper","x":10,"y":8,"b":133},
    {"op":"set","layer":"objUpper","x":5,"y":14,"b":129},
    {"op":"set","layer":"objUpper","x":15,"y":14,"b":132},
    {"op":"set","layer":"objUpper","x":10,"y":3,"b":112},
    {"op":"set","layer":"objUpper","x":14,"y":15,"b":9}
  ]}'

# (3) 이벤트 CRUD — 이 맵은 이벤트를 만들지 않는다. 비어 있음(`[]`)을 확인만 한다
curl -s http://localhost:5310/api/ai/maps/Map016.json/events

# (4) 검증 → (5) 통행 확인 → (6) 눈으로 확인
curl -s http://localhost:5310/api/ai/maps/Map016.json/validate
curl -s 'http://localhost:5310/api/ai/maps/Map016.json/passability?x=0&y=0&w=21&h=21'
curl -s -o /tmp/map016.png 'http://localhost:5310/api/ai/maps/Map016.json/preview.png?tile=24&events=1'
```

- **이벤트(`events[]`)를 일부러 쓰지 않는다.** NPC 를 objUpper TALK 타일로 놓으면 `MapModel.toJson()` 이
  저장하는 `ixObj1` 로 **세이브에 살아남지만**, 이벤트 기반 NPC 의 `dialogLines` 는 세이브 로드 후
  통째로 사라진다(부록 C-1). 대사는 전부 cm2 가 낸다. 타일 액션의 출처는 3개뿐이므로(부록 J-3)
  `region`·`objLower`·`shadow` 는 배치에 쓰지 않는다.

### 4. NPC 배치 규약 — objUpper TALK 대역

| 좌표 | B 타일 id | 정체 | cm2 핸들러 |
|---|---|---|---|
| `(10,8)` | **133** | 파수 대장 두람 | `if (On(10,8))` |
| `(5,14)` | **129** | 창고지기 가른 | `if (On(5,14))` |
| `(15,14)` | **132** | 우물가의 아이 | `if (On(15,14))` |
| `(10,3)` | **112** | 봉화대 푯말 (SIGN 대역 112~123) | `if (On(10,3))` + `FLAG_SIGN` |
| `(10,20)` | — (ground A5 64) | 남문 → LORE_EP | `if (On(10,20))` + `FLAG_ENTER` |

- B **128~143** 이 TALK 대역이다(`hadar2026_app/lib/domain/map/tile_properties.dart:222`).
  129·132·133 은 `Map002.json`·`TOWN1.json` 이 실제로 쓰는 값이라 그림이 존재한다. TALK 타일은
  통행 불가이므로(`tile_properties.dart:104-107`) 마주 보고 확인키를 눌러 말을 건다.
- **좌표는 [S1-01 §4](S1-01-quest-design.md) 의 표와 [S1-03](S1-03-quest-cm2.md) 의 `On(x,y)` 와 세 곳이 일치해야 한다.**
  한 곳만 틀리면 NPC 는 말을 하지 않고 **아무 오류도 나지 않는다.**

### 5. 기존 맵 → 새 맵 진입 연결 (확정)

**`LORE_EP`(`Map002.json`) 의 `(36,27)` 을 ENTER 로 바꾸고 `Map002.cm2` 에 핸들러를 추가한다.** 근거 — `Map002.cm2:38-57` 의 `FLAG_ENTER` 블록이 이 패턴의 실증이고 시작 위치가 `(32,27)`이다(`Map002.cm2:60`).
기존 ENTER 타일 7칸 중 **시작 위치에서 걸어서 닿는 것은 `(30,25)`(→MAP003)와 `(30,28)`(override 데모) 둘뿐**이고
둘 다 임자가 있다. 나머지 `(32,10)`·`(34,10)`·`(38,22)`·`(39,22)`·`(40,22)` 는 **도달 불가**다.

```bash
# LORE_EP 의 (36,27) — 현재 A5 104(BLOCK), objUpper 0. 서쪽 (35,27)에서 걸어와 부딪힌다
curl -s -X POST http://localhost:5310/api/ai/maps/Map002.json/edit -H 'Content-Type: application/json' \
  -d '{"ops":[{"op":"set","layer":"ground","x":36,"y":27,"a5":64}]}'
```

`hadar2026_app/assets/Map002.cm2` 의 `if (FLAG_ENTER.Equal(ScriptMode()))` 블록 안에 **추가**한다
(기존 `On(30,25)`·`On(30,28)` 은 건드리지 않는다):

```cm2
	if (On(36, 27))
		Event::Override()
		SetHeader("석문으로 가는 길")
		Select::Init()
		Select::Add("석문 초소로 가시겠습니까?")
		Select::Add("예")
		Select::Add("아니오")
		Select::Run()
		temp.assign(Select::Result())
		if (Equal(temp, 1))
			LoadScript("SEOKMUN", 10, 19)
```

- `LoadScript` 는 먼저 `MapInfos.json` 이름으로 맵을 찾고 실패하면 cm2 파일 경로로 재시도한다
  (`script_engine_adapter.dart:44-46`) — §1 의 등록이 없으면 **조용히 다른 경로로 새어 나간다.**
  되돌아오는 길은 `Map016.cm2` 의 `LoadScript("LORE_EP", 35, 27)` 이다([S1-03](S1-03-quest-cm2.md)).

## 완료 판정 기준

- [ ] `validate` 의 `issues` 가 비어 있고, `preview.png` 에서 담장·남문·NPC 3명이 §2 그림과 같은 자리다
- [ ] `passability` 에서 `(10,19)` → 남문·NPC 3명이 모두 **인접 도달 가능**하고, 봉화대 내부
      `(8~12, 3~5)` 는 **도달 불가**다 (문이 아직 BLOCK 이므로)
- [ ] `MapInfos.json` 에 `id:16 / name:"SEOKMUN"` 이 정확히 한 줄로 들어가고 기존 15줄이 그대로다
- [ ] `Map002.json` 의 변경이 `(36,27)` **한 칸**뿐이다 (`git diff --stat` 으로 확인)

## 하지 않을 것

- 코드 변경. 맵 에디터 기능 추가(→ [S2-04](../S2-enablers/S2-04-map-editor-cm2-support.md)).
- 기존 맵 지형 손질, 부록 D-1 이름 해석 파손 수리(→ [P0-01](../P0-foundation/P0-01-mapinfos-name-resolution.md)).
- 맵 JSON `events[]`·`hadarEvent`·`region` 레이어 사용, 야간 연출, 인카운터 설정.
