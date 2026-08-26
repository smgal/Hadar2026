# Hadar 맵 에디터 — AI API 가이드

이 문서는 AI 에이전트(MCP 도구, LLM)가 Hadar2026 의 맵을 프로그래밍 방식으로 생성·수정하기 위한 API 명세다.
`GET /api/ai` 가 항상 이 문서를 반환한다. Base URL 은 에디터 dev 서버 (기본 `http://localhost:5310`).

모든 쓰기 연산은 서버가 파일을 읽고→수정하고→RPG Maker MV 원본 직렬화 형식으로 저장하므로,
**MV 포맷의 어떤 필드도 손실되지 않고**, 사람이 브라우저 에디터로 보고 있으면 변경이 자동 반영된다.

## 권장 워크플로

0. 사용자가 "지금 맵" / "현재 열려 있는 맵" 이라고 하면 `GET /api/ai/current` — 브라우저 에디터가 열어 둔 맵 파일을 반환 (10초 내 활동이 없으면 `file: null` → 사용자에게 확인)
1. `GET /api/ai/maps` — 맵 목록 확인 (또는 `POST /api/ai/maps` 로 새 맵 생성)
2. `GET /api/ai/maps/{file}` — 대상 맵 요약 (크기, 레이어 히스토그램, 이벤트)
3. `GET /api/ai/maps/{file}/preview.png` — 현재 모습 확인 (멀티모달이면 꼭 볼 것)
4. `POST /api/ai/maps/{file}/edit` — 배치 편집 (한 호출에 여러 op)
5. `GET /api/ai/maps/{file}/validate` + `preview.png` — 결과 검증
6. 통행 가능성 확인이 필요하면 `GET /api/ai/maps/{file}/passability`

## 도메인 지식 (필수)

### 레이어 (RPG Maker MV `data` 배열의 6개 z-레이어)

| layer 이름 | z | 의미 | 값 |
|---|---|---|---|
| `ground` | 0 | 지면 타일 (Lore_A5.png) | 0 또는 `1536 + A5인덱스(0~127)`. 값 0 도 게임에선 A5 #0 으로 그려짐 |
| `ground2` | 1 | 게임 미사용 (보존용) | 건드리지 말 것 |
| `objLower` | 2 | 오브젝트 하단 (Lore_B.png) | B 타일 id 0~255, 0 = 없음 |
| `objUpper` | 3 | 오브젝트 상단 — **통행 판정에 사용** | B 타일 id 0~255, 0 = 없음 |
| `shadow` (별칭 `light`) | 4 | **빛/그림자** 사분면 비트 | 0~15. `0 = 항상 밝음(광원 지역, 실내 등)`, `15 = 야간에 완전히 어두움`, 1~14 = 부분(비트: 1=좌상 2=우상 4=좌하 8=우하) |
| `region` | 5 | 지역 ID (게임이 ixEvent 로 읽음) | 0~255 |

편집 op 에서 값 지정은 세 가지 형태: `"value": 1620` (원시값) / `"a5": 84` (지면용, 1536+84 로 기록) / `"b": 9` (오브젝트용).

### 타일 의미 (게임의 통행/액션 규칙, HDTileProperties)

**A5 인덱스** (ground): `0~55 MOVE(통행)`, `56~59 WATER`, `60~61 SWAMP`, `62~63 LAVA`, `64~69 ENTER(입구)`, `70~71 CLIFF`, `72~127 BLOCK(벽)`.

**B 타일 id** (objLower/objUpper): `1~63 BLOCK`, `64~87 MOVE(장식)`, `88~95 MOVE(애니메이션)`, `96~111 BLOCK`, `112~123 SIGN(표지판)`, `124~127 ENTER`, `128~143 TALK(NPC)`, `144~239 MOVE`, `240~255 = 야간 그림자 오버레이 예약(오브젝트 레이어에 직접 놓지 말 것)`.

통행 판정 우선순위: 타일 위 이벤트 > objUpper 의 오브젝트 > ground 타일. objLower 는 순수 장식.
타일의 실제 생김새: `GET /api/ai/tile.png?a5=84` 또는 `?b=9` (48×48 PNG). 시트 전체: `GET /api/image?file=Lore_A5.png`(8열×16행, 인덱스=행*8+열), `Lore_B.png`(왼쪽 절반 8열이 0~127, 오른쪽 절반이 128~255).
카탈로그(전 타일의 액션 분류): `GET /api/ai/palette`.

### 빛/야간

야간에 게임은 `shadow` 레이어 값이 있는 타일을 어둡게 그린다. 공식: `ix = ((shadow ^ 15) | lightBit) ^ 15`
(lightBit 는 플레이어 시야 원). **마을 실내·광원 근처는 shadow=0, 야외·동굴은 shadow=15** 로 칠하는 것이 기본 패턴.
빛이 부드럽게 새는 경계는 1~14 의 사분면 비트로 표현.

### 이벤트

- 이벤트 **이름 접두사가 게임의 타입 판정**: `TALK`(대화 NPC), `SIGN`(표지판), `EVENT`(스크립트 트리거), `ENTER`(출입구), `NPC`. 예: `TALK001`.
- `dialogLines` 는 RPG Maker code 401 대사 줄. 이벤트가 밟히거나 조사될 때 순서대로 출력.
- `hadarEvent` 확장 (선택): `{"kind":"warp","payload":{"map":"TOWN1","x":10,"y":20}}` (이동), `{"kind":"oneshot","payload":{"flag":3}}` (1회성), `"talk"`/`"sign"` (payload 무시).
- TALK/SIGN/ENTER/EVENT 이벤트가 있는 타일은 통행 불가(상호작용) 취급됨.

## API 레퍼런스

에러 응답은 `{"error": "...", "hint": "..."}` 형태다 — `hint` 는 없을 수도 있고, 있으면 그 지시를 따라 재시도할 것.

### 목록/생성

- `GET /api/ai/current` → `{file, ageSeconds, hint}` — 브라우저 에디터가 지금 열고 있는 맵. "지금 맵" 류 요청의 대상 결정에 사용.
- `GET /api/ai/maps` → `{maps:[{file,width,height,displayName,eventCount,rev}]}`
- `POST /api/ai/maps` body `{"file":"Map020.json","width":40,"height":30,"displayName":"새 동굴","groundA5":0,"registerAs":"CAVE1"}`
  - 표준 MV 필드를 모두 갖춘 새 맵 생성. `groundA5` 로 전체 지면 채움 (기본 0).
  - `registerAs` (선택): `MapInfos.json` 에 이름을 등록해 게임(`HDMapNavigation.loadByName`)이 찾을 수 있게 함.

### 읽기

- `GET /api/ai/maps/{file}` → 요약: 크기, displayName, 레이어별 히스토그램(top 10), 이벤트 전체.
- `GET /api/ai/maps/{file}/region?layer=ground&x=0&y=0&w=20&h=20` → `{rows:[[...]]}` (행 우선 2D 배열, 최대 20000칸/호출).
  - `&as=a5` (ground 전용): 원시값 대신 A5 인덱스로 반환.
- `GET /api/ai/maps/{file}/passability?x=&y=&w=&h=` → 액션 이름 2D 배열 (`MOVE`/`BLOCK`/`WATER`/`ENTER`/...). 걸을 수 있는 경로가 이어졌는지 검증할 때 사용.
- `GET /api/ai/maps/{file}/validate` → `{ok, issues:[{severity,message}]}` — 편집 후 반드시 호출 권장.
- `GET /api/ai/maps/{file}/preview.png?tile=16&night=0&events=1` → 렌더링 PNG.
  - `x,y,w,h` 영역 지정 (기본 전체), `tile` = 타일당 픽셀 (2~48, 기본 16)
  - `night=1` 야간 뷰, `moonlight=0` 달빛 없음(더 어두움), `playerX=&playerY=&sight=1..5` 광원 미리보기
  - `events=0` 이벤트 테두리 숨김

### 쓰기 (배치 편집)

`POST /api/ai/maps/{file}/edit` body:

```json
{"ops":[
  {"op":"rect","layer":"ground","x":0,"y":0,"w":40,"h":30,"a5":0},
  {"op":"set","layer":"objUpper","x":5,"y":5,"b":9},
  {"op":"fill","layer":"ground","x":10,"y":10,"a5":84},
  {"op":"setCells","layer":"shadow","x":0,"y":0,"rows":[[15,15,15],[15,0,15]]},
  {"op":"resize","width":50,"height":50},
  {"op":"setDisplayName","displayName":"로어 동굴 B1"}
]}
```

- `set` 한 칸, `rect` 사각 영역, `fill` 같은 값 flood fill, `setCells` 2D 배열 붙여넣기(`"as":"a5"` 옵션), `resize` 좌상단 기준 크기 변경, `setDisplayName`.
- ops 는 순서대로 적용되고 한 번의 파일 저장으로 끝난다. **여러 편집은 반드시 한 호출에 모을 것.**
- 응답: `{ok,rev,results:[{op,changed}],totalChanged,warnings}` — warnings 를 확인할 것.

### 이벤트 CRUD

- `GET /api/ai/maps/{file}/events`
- `POST /api/ai/maps/{file}/events` body `{"type":"TALK","x":10,"y":12,"note":"경비병","dialogLines":["멈추시오!"],"hadarEvent":null}`
  - `type` 만 주면 `TALK001` 식 자동 명명. `name` 으로 직접 지정도 가능.
- `PATCH /api/ai/maps/{file}/events/{id}` — 위 필드 부분 수정 (`hadarEvent:null` 로 확장 제거)
- `DELETE /api/ai/maps/{file}/events/{id}`
- 주의: `dialogLines` 수정은 이벤트 첫 페이지의 커맨드 list 를 표준형(101+401들+0)으로 재구성한다.

## 맵 제작 팁

- 맵 둘레는 BLOCK 타일(A5 72~127)로 감싸 플레이어가 밖으로 못 나가게 할 것.
- ENTER 타일/이벤트는 다른 맵으로 이어지는 곳에만. 실제 이동 로직은 hadarEvent `warp` 또는 네이티브/cm2 스크립트가 담당.
- 동굴(DEN 류) 맵은 전체 shadow=15 가 기본 (게임이 DEN 이름의 맵을 항상 어둡게 처리). 마을은 shadow=0.
- 편집 후 `validate` → `preview.png` 로 확인하는 습관을 들일 것. 미리보기에서 이벤트는 색 테두리(마젠타=TALK, 시안=SIGN, 초록=EVENT, 노랑=ENTER)로 표시된다.
