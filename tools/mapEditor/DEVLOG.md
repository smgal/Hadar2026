# 제작 일지

이 문서는 `tools/mapEditor`를 다시 손볼 때(버그 수정, 기능 추가, 다른 사람에게 인계) 배경을 빨리 파악하도록 남기는 기록이다. "왜 이렇게 만들었는지"와 "지금 뭐가 부족한지"에 집중한다. 사용법은 [USER_MANUAL.md](USER_MANUAL.md)(사람용)와 [API_MANUAL.md](API_MANUAL.md)·[openapi.yaml](openapi.yaml)(AI/API용)를 참고.

## 1. 요구 사항 (원본 요청 요약)

**1차 요청** — RPG Maker MV를 실제로 쓰고 있지만, 이 프로젝트 전용으로 가볍게 맵을 만지는 도구가 필요하다는 취지:

- 웹으로 실행 (설치형 앱 아님)
- TypeScript면 pnpm, Python이면 uv — 이 프로젝트는 TS/Vite/pnpm으로 결정
- 로컬 `assets/maps/*.json`을 읽고·수정하고·저장
- 타일과 오브젝트의 **레이어 구조**, **빛과 관련된 타일** 지정 가능
- **레이어에 따라 팔레트가 달라지고**, 레이어별 표시 on/off
- **주간/야간 뷰 토글**
- 빠뜨린 게 있으면 알아서 추가
- **RPG Maker MV 포맷의 어떤 필드도 제거 금지** — 나중에 RPG Maker MV에서 다시 열 수 있어야 함. 다만 "이 툴이 MV의 모든 기능을 커버해야 한다"는 아니고, 그 범위는 포기해도 됨

**2차 요청** — 위 에디터를 **Open API로 제어**해서 **MCP/AI 도구로 맵을 생성**할 수 있게 해달라는 것. 사람용이 아니라 **AI가 쓰기 좋은 API**로.

**3차 요청 (실사용 중 발견)** — 브라우저 UI에서 수정 중인 상태로 API를 통해 추가 수정하면 두 상태가 갈라지는 문제. 지금은 진짜 merge가 아니라 "덮어쓰거나 포기하거나" 방식 (아래 [4장](#4-알려진-문제한계) 참고). **아직 미해결** — 3-way merge 설계는 논의했지만 구현 여부는 사용자 결정 대기 중.

## 2. 왜 이런 구조로 만들었나 (설계 결정과 근거)

### 2.1 두 개의 API 표면을 분리

- `/api/map`, `/api/maps`, `/api/map/rev`, `/api/image` — **사람용 저수준 API**. 브라우저 UI 전용, 원시 JSON 통째로 GET/PUT.
- `/api/ai/*` — **AI용 시맨틱 API**. 레이어 이름(`ground`/`objUpper`/...), 타일 의미(`a5`/`b` 인덱스), 배치 편집(ops 배열), PNG 미리보기 등 "의도" 단위로 조작.

이유: AI에게 원시 바이트 배열(`data[z*w*h+y*w+x]`)을 계산해서 보내라고 하면 실수하기 쉽고, 매번 전체 파일을 왕복해야 한다. 반대로 사람 UI는 붓질 하나하나를 네트워크로 보내면 낭비이므로 로컬에서 모았다가 저장. 그래서 애초에 사용 패턴이 다르다고 보고 API를 분리했다 — 하나로 합쳤으면 둘 다 어중간해졌을 것.

### 2.2 MV 포맷 보존 방법 — "파싱 후 그대로 들고 있기"

[src/mvmap.ts](src/mvmap.ts)의 `MvMap`은 TS 타입을 엄격히 정의하지 않고 `[k: string]: unknown` 인덱스 시그니처로 **알 수 없는 필드를 다 보존**한다. 수정하는 건 `width`/`height`/`data`/`events`/`displayName`뿐이고 나머지 필드는 파싱한 그대로 다시 내보낸다.

`serializeMv()`는 RPG Maker MV 에디터가 실제로 저장하는 줄 구조(필드 한 줄 + `"data"` 한 줄 + 이벤트당 한 줄)를 그대로 재현한다. **개발 중 검증**: 저장소의 맵 13개 전부 "파싱 → 재직렬화"가 원본과 바이트 단위로 동일함을 확인했다(`/private/tmp/.../roundtrip.mjs`, 세션에만 있던 스크립트라 저장소엔 없음 — 필요하면 재작성 쉬움: 각 맵 파일을 읽고 JSON.parse 후 serializeMv 결과를 원본 문자열과 비교). `MapInfos.json`도 같은 방식으로 별도 직렬화(`writeMapInfos`, [server/store.ts](server/store.ts))하며 라운드트립 확인함.

이 방식의 대가: MV의 진짜 스키마(예: 이벤트 페이지의 모든 `code` 종류, `moveRoute` 문법 등)를 전혀 모델링하지 않는다. 그래서 "대사만 편집"처럼 좁은 연산만 안전하게 지원하고, 나머지는 통째로 보존한다.

### 2.3 게임 코드에서 규칙을 그대로 포팅

빛/그림자 공식([src/lighting.ts](src/lighting.ts))과 타일 액션 판정([src/rules.ts](src/rules.ts))은 `hadar2026_app`의 `HDSightCalculator`/`HDTileProperties`/`HDWorldMap`을 그대로 옮긴 것이다. 임의로 재구현하지 않은 이유: 에디터의 야간 미리보기·통행 오버레이가 게임 실제 렌더와 조금이라도 다르면 에디터가 무의미해지기 때문. 게임 쪽 코드가 바뀌면 이 포팅도 같이 업데이트해야 한다 — 자동 동기화 장치 없음(아래 4.6).

### 2.4 동시 편집 — rev(mtime) 기반 낙관적 잠금 + 폴링

`server/store.ts`의 `revOf()`는 파일 mtime을 문자열로 반환한다. UI는 로드 시 rev를 저장해두고([src/state.ts](src/state.ts) `state.rev`), 저장할 때 함께 보내 서버가 비교한다([vite.config.ts](vite.config.ts) PUT 핸들러). 다르면 409.

또한 UI는 2초마다 `/api/map/rev`를 폴링해서([src/main.ts](src/main.ts) 의 `setInterval` 블록) 외부(AI API)가 파일을 바꾸면:
- 내가 편집 중(dirty)이 아니면 → 자동으로 다시 불러옴([src/main.ts](src/main.ts) 의 `reloadFromDisk`) — 뷰(팬/줌/선택된 이벤트)는 유지
- 내가 편집 중(dirty)이면 → 상태바에 경고만 표시, 저장 시도할 때 409로 확인창

**의도적으로 진짜 merge는 구현하지 않았다** — 처음엔 "덮어쓰기 확인창"이면 충분하다고 판단했는데, 실사용 중 사람+AI가 각각 다른 위치를 동시에 편집하는 흔한 상황에서 한쪽이 통째로 날아가는 문제가 바로 드러났다. 4.1장 참고.

### 2.5 "지금 맵이 뭐야?" 문제

AI가 "지금 맵에 그려줘"라고 지시받아도 서버는 브라우저가 뭘 열어놨는지 알 방법이 없었다. UI의 2초 폴링(`GET /api/map/rev`)을 신호로 재활용해서 `server/store.ts`의 `uiCurrent` 전역에 마지막으로 요청된 파일명 + 시각을 기록하고, `GET /api/ai/current`가 "10초 이내 폴링이 있었으면 그 파일, 아니면 null + 사용자에게 물어보라는 힌트"를 반환하도록 했다. 임시방편이지만 dev 서버가 사실상 단일 브라우저 탭 하나만 상대한다는 전제하에는 잘 맞는다(4.9 참고).

### 2.6 PNG 미리보기를 서버(Node)에서 직접 합성

브라우저 캔버스 렌더러(`src/renderer.ts`)와는 별도로 `server/preview.ts`가 `pngjs`로 **같은 합성 규칙**(지면→objLower→objUpper→야간 그림자)을 Node에서 재구현한다. 중복이지만 이유가 있다: MCP 도구가 이미지를 반환하려면 서버 프로세스 안에서 PNG 바이트를 만들어야 하고, 브라우저 Canvas API는 Node에 없다. 두 렌더러가 갈라지지 않도록 시트 좌표 계산(`a5Rect`/`bRect`)과 그림자 공식(`lightBitFor`/`shadowIx`)은 `src/rules.ts`/`src/lighting.ts`에만 두고 양쪽이 import해서 쓴다 — **합성 순서·오버레이 스타일(이벤트 테두리 색 등)은 각자 구현**이라 미묘하게 다를 수 있다(4.7 참고).

## 3. 기능 목록

### 3.1 브라우저 에디터 (사람용)

- 레이어 6종 + 이벤트 의사 레이어, 레이어별 팔레트(A5 지면/B 오브젝트/그림자 비트/지역 ID), 눈 아이콘으로 표시 on/off, 숫자키 1~7로 활성 레이어 전환
- 도구: 붓/사각형/채우기(flood fill)/스포이드/지우개, 스트로크 단위 실행취소·다시실행(최대 200단계 — [src/state.ts](src/state.ts) 의 `MAX_UNDO`)
- 주간/야간 토글 + 달빛 토글 + 광원(플레이어 위치·시야 반경) 미리보기 — 게임 공식 그대로
- 통행/액션 오버레이 (BLOCK/WATER/ENTER/TALK/... 색상 표시)
- 이벤트 패널: 목록·생성·수정(이름/메모/좌표/대사/hadarEvent 확장)·삭제
- 맵 정보: 표시 이름 수정, 크기 리사이즈(좌상단 기준 내용 보존)
- 확대/축소·팬, 격자 토글
- 저장(Ctrl+S), 외부 변경 자동 반영(2초 폴링), 저장 충돌 확인창
- 마지막으로 연 맵을 localStorage에 기억 → 새로고침해도 같은 맵 유지
- URL 파라미터로 초기 상태 지정: `?map=&night=&light=`

### 3.2 AI API (`/api/ai/*`)

- `GET /api/ai` — 마크다운 가이드 전체 반환(자가 기술)
- `GET /api/ai/current` — 브라우저가 지금 연 맵
- `GET /api/ai/maps`, `POST /api/ai/maps`(신규 생성 + MapInfos 등록)
- `GET /api/ai/maps/{file}` — 요약(레이어 히스토그램·이벤트 전체)
- `GET /api/ai/maps/{file}/region` — 2D 배열로 타일 읽기
- `POST /api/ai/maps/{file}/edit` — 배치 편집(set/rect/fill/setCells/resize/setDisplayName)
- 이벤트 CRUD (`/events`, `/events/{id}`)
- `GET /api/ai/maps/{file}/passability` — 통행 판정 2D 배열
- `GET /api/ai/maps/{file}/validate` — 무결성 검사
- `GET /api/ai/maps/{file}/preview.png`, `GET /api/ai/tile.png`, `GET /api/ai/palette`
- 에러는 `{error, hint?}` — hint 는 복구 방법이 있을 때만 채워진다

전체 요청/응답 스키마는 [openapi.yaml](openapi.yaml) 참고.

### 3.3 MCP 서버

[mcp/server.mjs](mcp/server.mjs) — 위 API를 감싼 stdio 서버, 도구 15종(`get_guide`, `current_map`, `list_maps`, `create_map`, `map_summary`, `read_region`, `edit_map`, `passability`, `validate_map`, `list_events`, `create_event`, `update_event`, `delete_event`, `preview`, `tile_image`). `preview`/`tile_image`는 MCP 이미지 콘텐츠로 반환. dev 서버가 떠 있어야 동작(`HADAR_EDITOR_URL` 환경변수로 대상 지정).

## 4. 알려진 문제/한계

이 목록은 "지금 완성됐다"가 아니라 "이 상태로 실사용하다 발견/예상되는 것"이다. 심각도 순 아님 — 발견/설계 당시 맥락 순.

### 4.1 (★ 가장 중요) 동시 편집 시 진짜 merge가 없음

2.4에서 설명한 대로, 저장 충돌 시 "내 화면으로 덮어쓰기" 아니면 "포기" 둘 중 하나뿐이다. 사람이 마을 왼쪽, AI가 오른쪽에 집을 짓는 것처럼 **겹치지 않는 영역을 동시에 편집해도 한쪽이 통째로 사라진다.**

**설계는 이미 논의됨** (사용자와의 대화 참고): 로드 시점의 원본을 "base"로 계속 들고 있다가, 저장 충돌 시 `base`/`local`/`remote` 3-way 비교를 **타일 단위·이벤트 단위**로 수행 — 한쪽만 바뀐 칸/필드는 자동 채택, 양쪽이 다르게 바꾼 것만 충돌로 표시. 텍스트 3-way merge보다 훨씬 쉬운 이유는 데이터가 격자+ID 배열이라 "같은 셀을 건드렸는가"가 명확하기 때문. **구현 안 됨** — 다음 세션에서 이어서 할 것.

구현 시 건드릴 곳: `src/state.ts`(base 스냅샷 보관), `src/api.ts`(원격 최신본 fetch), `src/main.ts`의 `doSave`/`SaveConflictError` 분기, 필요하면 충돌 표시용 작은 UI.

### 4.2 대사 편집이 이벤트 페이지의 `list`를 통째로 재구성

`setDialogLines()`([src/mvmap.ts](src/mvmap.ts))는 첫 페이지의 `list`를 `[101, 401×n, 0]` 표준형으로 덮어쓴다. 이 프로젝트의 모든 이벤트가 `code` 0/101/401만 쓰기 때문에 지금은 무해하지만, **다른 code(조건분기, 스위치 조작 등)가 있는 이벤트의 대사를 AI/UI로 수정하면 그 로직이 사라진다.** AI_GUIDE.md에 경고는 적어뒀지만 코드 레벨에서 막지는 않음.

단, "대사를 실제로 바꿨을 때만" 재구성되도록은 고쳤다 — 예전에는 중간에 빈 줄이 있는 이벤트를 대사에 손대지 않고 '적용'만 눌러도 재구성됐다(2026-08-23 감사에서 수정).

### 4.3 MV 이벤트 커맨드 전체를 편집 못 함

지원하는 건 `name`/`note`/`x`/`y`/대사(`dialogLines`)/`hadarEvent` 확장뿐. `moveRoute`, 조건 분기, 스위치/변수 조작 같은 MV 이벤트 커맨드 전반은 **읽기·쓰기 모두 미지원** — 그런 이벤트는 여전히 RPG Maker MV나 직접 JSON 편집이 필요하다. (애초 요구사항의 "MV 전체 기능은 포기해도 됨"에 해당하는 부분.)

### 4.4 타일셋 하드코딩

`Lore_A5.png`/`Lore_B.png` 두 장, 48px 원본 타일 크기, `tilesetId: 7`이 여러 곳에 하드코딩돼 있다(`server/ai_api.ts`의 `newMvMap`, `src/tilesets.ts`/`src/rules.ts`). 이 게임 하나만 상대하는 도구라 의도적으로 이렇게 뒀지만, 다른 RPG Maker MV 프로젝트(다른 타일셋, A1~A4/B~E 8슬롯 전체)에는 그대로 못 쓴다.

### 4.5 `ground2`(L1) 레이어가 사실상 죽어있음

MV의 두 번째 지면 레이어는 게임 렌더러가 아예 읽지 않는다([hadar2026_app/lib/application/map_loader.dart](../../hadar2026_app/lib/application/map_loader.dart) 참고 — z=1은 파싱하지 않음). 에디터는 보존은 하지만("MV 필드 제거 금지" 요구사항 때문) 편집 UI에서 만질 이유가 거의 없다. 기본적으로 숨김 처리(`defaultVisible: false`)만 해뒀다.

### 4.6 게임 로직과의 동기화가 수동

빛 공식·통행 규칙을 `hadar2026_app`에서 손으로 옮겨 왔기 때문에(2.3), **게임 쪽 `HDTileProperties`/`HDSightCalculator`/`HDWorldMap`이 바뀌면 에디터도 손으로 따라가야 한다.** 자동 검증(예: 두 코드베이스를 비교하는 테스트)은 없음.

### 4.7 브라우저 렌더러와 서버 PNG 렌더러가 별도 구현 (2.6)

좌표 계산·조명 공식은 공유하지만, 오버레이 스타일(이벤트 테두리 두께/색, 안티앨리어싱 여부 등)은 `src/renderer.ts`(Canvas)와 `server/preview.ts`(pngjs, 최근접 샘플링만 지원)가 각자 구현. 시각적으로 완전히 동일하진 않다 — 정합성 검사가 필요하면 둘을 직접 비교해야 한다.

### 4.8 자동 테스트 없음

`src/mvmap.ts`(직렬화 라운드트립), `src/rules.ts`(액션 판정 표), `server/ai_api.ts`(각 op의 경계값) 전부 개발 중 수동으로(curl, 헤드리스 크롬 스크린샷, 임시 스크립트) 검증했고 저장소에 남은 자동 테스트는 없다. `hadar2026_app/test/`처럼 `dart test`에 연결된 CI도 없음 — 이 툴만 따로 `pnpm test` 스크립트도 아직 없다.

### 4.9 "지금 맵" 감지가 단일 사용자·단일 탭 가정

`GET /api/ai/current`(2.5)는 최근 2초 폴링만 보고 판단한다. 브라우저 탭을 여러 개 열거나, 여러 사람이 같은 dev 서버를 공유하면 "지금 맵"이 뒤섞일 수 있다. 로컬 1인 개발 도구라는 전제하에는 문제없음.

### 4.10 그 외 자잘한 것

- 새 맵의 `MapInfos.json` id/order 자동 할당은 `max+1` 방식 — id가 듬성듬성 비어있어도 재사용 안 함(문제는 없지만 최적은 아님)
- `region`/`passability` 조회는 20,000칸/호출 제한, `preview.png`는 1600만 픽셀 제한 — 이 게임 맵 크기(최대 256×256)에선 여유 있지만 더 큰 맵엔 페이지네이션 필요
- API에 인증 없음 — localhost 전용 dev 서버라는 전제. 외부 노출 시 반드시 추가해야 함
- `pnpm-workspace.yaml`의 `allowBuilds: esbuild: true`는 pnpm 11의 빌드 스크립트 차단 정책 때문에 필요했던 설정 — pnpm 버전 업그레이드 시 문법이 또 바뀔 수 있음
- 잘못된 퍼센트 인코딩(`/%zz`)은 우리 미들웨어가 400 으로 끊는다. 그냥 흘려보내면 Vite 자체 정적 미들웨어가 `decodeURI` 에서 던져 500 + 에디터를 덮는 오류 오버레이가 뜨기 때문 — 상류(Vite) 동작이라 우리가 앞에서 막는 것 외엔 방법이 없다

## 5. 아카이빙 전 감사에서 고친 것 (2026-08-23)

멀티에이전트 감사(6개 관점 리뷰 → 반박 검증)로 찾은 31건을 모두 수정했다. 회귀를 의심할 일이 생기면 이 목록이 "무엇이 왜 그렇게 돼 있는지"의 근거다.

**서버 — 잘못된 입력을 조용히 삼키던 것들** ([server/ai_api.ts](server/ai_api.ts))
- `layer` 누락 시 `Number('') === 0` 이 조용히 ground 로 해석돼 **엉뚱한 레이어에 기록**되던 것 → 400. 프로토타입 키(`toString` 등)가 `in` 을 통과하던 것도 `hasOwnProperty` 로 차단
- `x`/`y` 누락·비숫자 시 NaN 이 경계검사를 통과해 `data[NaN]` 에 쓰고는 **"changed:1 성공"** 을 반환하던 것(파일엔 아무것도 안 쓰임) → 400
- `a5` 값을 오브젝트/그림자/지역 레이어에 쓰면 경고만 하고 255 초과 값을 기록하던 것(같은 값을 `value` 로 주면 400 이던 자기모순) → 400
- `setCells` 만 레이어별 범위검증을 건너뛰던 것 → `checkRawValue` 로 set/rect/fill 과 통일
- `clampRegion` 이 음수 시작점을 0 으로 **밀어내며 폭은 그대로 둬** 요청 밖 타일까지 편집·조회되던 것 → 교집합 계산으로 수정. 완전 비교차면 rect 는 경고, preview 는 400
- `tile.png` 의 비숫자 id 가 NaN 으로 범위검사를 통과해 **검은 PNG 를 200 으로** 반환하던 것 → 400. `a5`/`b` 동시 지정도 400
- 디스크 파일 손상(JSON 깨짐)을 **"요청 본문 파싱 실패"(400)** 로 오보고하던 것 → 500 + "맵 파일 JSON 손상"
- 형태가 어긋난 이벤트 요소가 있으면 요약·목록·**`/validate` 까지 전부 500** 이던 것 → 데이터는 보존한 채 `/validate` 가 error 로 보고. `eventTypeOf`·`eventView` 도 방어적으로
- 파일명 `..` 검사 시점이 달라 파일을 만든 뒤 혼란스러운 400 이 나던 것 → 생성 시점에 거부

**서버 — 라우팅** ([vite.config.ts](vite.config.ts))
- `/api/*` 에 지원 안 하는 메서드가 오면 응답 없이 Vite HTML 폴백으로 새던 것 → 405 JSON
- `decodeURIComponent` 가 try 밖에 있어 무관한 요청까지 500 이던 것 → prefix 판정을 먼저, 디코딩은 try 안으로

**게임 규칙 충실도**
- 같은 칸에 이벤트가 겹칠 때 통행 판정이 게임과 달랐다 — 게임(`HDMapLoader`)은 마지막 이벤트가 덮어쓰고 NPC/UNKNOWN 이면 이벤트 계층을 통과시키는데, 에디터는 NPC/UNKNOWN 을 건너뛰어 앞선 타입이 남았다 → [src/mvmap.ts](src/mvmap.ts) 의 `eventActionGrid()` 로 통합(브라우저 오버레이·서버 passability 가 같은 함수 사용), `eventAt()` 도 마지막 우선으로
- `newEventPage()` 주석이 "MV 에디터 기본값 그대로"라고 했으나 실제로는 이 프로젝트 관례값(네 필드가 다름) → 주석 정정

**브라우저 UI** ([src/main.ts](src/main.ts) 외)
- macOS 에서 `Ctrl+클릭`(=button 2)이 문서화된 "광원 이동" 대신 **타일을 지우던 것** → button 0/2 모두 수용
- 2초 폴링의 자동 리로드가 **진행 중인 사각형 드래그와 인스펙터 미적용 입력을 파괴**하던 것 → `rectStart`·사이드바 입력 포커스를 가드에 추가
- 사각형 프리뷰 중 우클릭이 그 영역을 통째로 지우던 것 → 조작 중 추가 버튼 무시 + 시작 버튼 기준으로만 적용(우클릭 시작 = 지우는 사각형)
- `Ctrl+Y` 만 이벤트 패널을 갱신하지 않아 스테일 인스펙터의 '적용'이 조용히 사라지던 것 → `applyHistory()` 로 undo/redo 4개 경로 통합, `refreshMapInfo()` 도 함께 호출(리사이즈·이벤트 증감 후 사이드바 스테일 해소)
- 저장 성공 후에도 해소된 "외부에서 변경됨" 경고가 무기한 남던 것 → `flashStatus` 가 `updateHint()` 로 복원
- 맵 전환 실패가 unhandled rejection 으로 삼켜져 셀렉트와 실제 맵이 어긋나던 것 → alert + 셀렉트 원복
- 0 크기 맵에서 `drawImage` 가 매 프레임 던지고 `ctx.save` 누수로 캔버스가 영구 붕괴되던 것 → `try/finally` + 크기 가드

**정리·문서·스펙**
- 죽은 코드 제거: `EditorState.listeners/on/notify`, 미사용 `B_COLS`(→ `B_HALF_COLS` 로 실제 사용)
- `tsconfig.json` 의 검사 범위가 `src/` 뿐이라 **`server/*.ts` 와 `vite.config.ts` 가 타입 검사에서 빠져 있던 것** → include 확장(현재 통과)
- 문서 오류: DEVLOG 상호 참조(3.3장→4.1장), USER_MANUAL 사이드바 위치(왼쪽→오른쪽), "에러는 항상 {error, hint}" → hint 는 선택, MCP `preview` 설명의 테두리 색 범례 보완
- openapi.yaml: 5개 연산에 누락된 400 추가, `..` 를 배제하도록 파일명 pattern 수정, tile.png 동시 지정·createMap 409 부분성공·영역 교집합·405 동작 명시

## 6. 향후 개선 아이디어 (우선순위 낮은 것도 포함)

1. **3-way merge 구현** (4.1) — 다음 착수 시 최우선 후보
2. 폴링 대신 WebSocket/SSE로 외부 변경을 즉시 push (지연 2초 → 즉시, 서버 부하도 감소)
3. `mvmap.ts`/`rules.ts`에 대한 단위 테스트 추가 (라운드트립·액션 판정 표 회귀 방지)
4. 이벤트 `list` 편집을 안전하게 — 대사 편집 시 기존 code가 0/101/401 외의 것이면 경고하고 거부(현재는 조용히 덮어씀, 4.2)
5. 여러 맵에 동일 ops를 한 번에 적용하는 배치 API (절차적 생성/대규모 수정용)
6. 이 도구를 다른 RPG Maker MV 프로젝트에도 쓰려면 타일셋을 설정 가능하게(4.4) — 지금은 이 게임 전용으로 남겨두는 게 맞을 수도 있음(과설계 주의)
7. 브라우저 렌더러/서버 PNG 렌더러 통합 또는 최소한 골든 이미지 비교 테스트(4.7)
8. localhost 밖으로 노출할 일이 생기면 토큰 인증 추가(4.10)
9. MCP 도구 커버리지 완성 — `GET /api/ai/palette`(팔레트 카탈로그)와 `GET .../events/{id}`(단일 이벤트 조회)는 REST에는 있지만 MCP 도구가 없다([mcp/server.mjs](mcp/server.mjs), [API_MANUAL.md](API_MANUAL.md#mcp로-쓰기) 참고). 사소하지만 완전성 차원에서 추가할 만함
