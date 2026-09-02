# Content Pack 포맷·매니페스트·ID 체계

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-21 · **상태**: 초안 · **선행 문서**: [BP-20](20_target_architecture.md)
> **독자**: 런타임 구현자 · 콘텐츠 툴 구현자 · 생성 에이전트 작성자
> **한 줄 요약**: AI 가 만들고 빌드가 검증하고 런타임이 해석하는 **콘텐츠 팩**의 물리 포맷 — 디렉토리, 매니페스트, ID 문법, 문자열 키, 그리고 Condition/Effect DSL 의 단일 진실 원천(SSoT).

**파이프라인 구획**(D-01): 이 장은 **Authoring 산출물의 형식**과 **Build 입력 계약**을 정의한다.
런타임은 여기 정의된 소스를 직접 읽지 않고, 빌드가 구운 `build/content.bundle.json` 만 읽는다.

**이 장이 SSoT 인 것**(D-18 소유권 표): `§6 Condition/Effect DSL`, `§4 ID 문법`, `§5 문자열 키 체계`,
`§3 팩 매니페스트`. 다른 장(BP-23 퀘스트, BP-24 대화, BP-27 런타임, BP-33 린트)은 여기 정의된
op/do 집합과 ID 문법을 **참조만** 하고 재정의하지 않는다.
JSON Schema 전문은 [BP-90](90_appendix_schemas.md) 에 있고 이 장에는 핵심 발췌만 싣는다.

**이 장이 SSoT 가 *아닌* 것** — D-18 에 따라 아래 주제는 소유 장을 링크만 하고 여기서 재서술하지 않는다.

| 주제 | 소유 장 | 이 장에서의 취급 |
|---|---|---|
| 월드 이벤트 12종 이름·**payload** | [BP-23 §23.11.1](23_quest_model.md) | 이 장은 이벤트를 정의하지도, payload 를 인용하지도 않는다(D-20a·D-25) |
| Quest/Stage/Objective 스키마 | [BP-23](23_quest_model.md) | Effect `start_quest`/`advance_quest` 의 인자 타입만 명시 |
| Dialogue/Node/Choice 스키마, **텍스트 길이 수치** | [BP-24](24_dialogue_model.md) | §5.5 의 길이 임계값은 BP-24 를 따른다(`I-10`) |
| 세이브 포맷 v2 봉투·`WorldState` 필드·`mapDelta` | [BP-25](25_world_state_and_save.md) | Effect 의 "부작용 대상" 열은 필드명 인용이며 구조를 정의하지 않는다 |
| 런타임 실행 경로·`WorldRng`·`rngCursor`·`pendingNavigation`·`mix`·`chanceSeedId` | [BP-27](27_runtime_engine.md) | §6.5 는 `chanceKey` 의 **명칭·형식과 결정 규약**만 정한다. 해시 함수 `mix` 의 구현(웹 32비트 2워드 제약)과 `chanceSeedId` 의 형식·소비는 BP-27 §9.2 소관(D-19·D-21·D-29a·D-30) |
| 검증 규칙 카탈로그 | [BP-33](33_validation_and_lint.md) | 이 장은 규칙 ID(`CV-nn`)와 심각도만 부여한다(§6.11) |

**개정 이력**

| 판 | 반영 내용 |
|---|---|
| 2026-08-30 (2판) | 검수(REVIEW_BP-21 F-01~F-14) · BP-90 `I-06`/`I-10`/`I-12`/`I-17` · BP-91 `W-01`/`W-05`/`W-11` · D-18~D-26 · GROUND_TRUTH 부록 A-4 / B-1 / B-5 / D / F-4 / H-4 |
| **2026-08-30 (4판)** | **D-31 시행 — Effect `do` 를 22 → 25 로 확장하고 `schemaVersion` 을 1 → 2 로 승격**(BP-90 `I-20` 해소). `E23 restore` · `E24 cure` · `E25 grant_buff` 신설(§6.6), `target` 인자 공통 규약 신설(§6.6.1), 확장 근거(§6.6.2)와 buff 화이트리스트의 코드 실측 종속(§6.6.3) 명문화. **§7.2.1 신설 — 이 기획서 최초의 승격 실행 기록**이며 절차의 공백 3건을 적발해 `R-21-69`(지원 집합 동시 갱신)·`R-21-70`(무변환 승격의 `steps: []`)·`R-21-71`(승격이 해제하는 우회 목록)로 규정. `CV-16`/`CV-17` 부여, §3.5·§3.6 팩 예시와 `R-21-41` 지원 집합 갱신 |
| 2026-08-30 (3판) | **D-30** — `chance` 유도식을 `mix([seed, step, chanceSeedId])` 로 확정하고 **R-21-34 를 개정 2판으로 갱신**(§6.5 · §6.5.1), 재굴림·래치 규약 신설(§6.5.2), 해시 함수 표기를 `mix` 로 통일. **D-29a** — `chanceKey`(이 장 소유) ↔ `chanceSeedId`(BP-27 소유) 2개체 분리, 2판의 "`siteId` 라는 이름을 어느 문서도 쓰지 않는다" 서술이 **과잉이었음을 정정**. **BP-90 `I-06` 해소.** §6.1 결정성 행 정정, §6.8 발췌의 소스↔번들 프로파일 경계 명시 |


---

## 1. 왜 "팩" 단위인가

### 1.1 팩이 없을 때 생기는 문제

현행 콘텐츠는 세 군데에 흩어져 있고 경계가 없다.

| 현행 저장소 | 위치 | 문제 |
|---|---|---|
| 맵 JSON 의 `events[].dialogLines` | `assets/maps/Map0NN.json` | 지형 데이터와 대사가 한 파일 → AI 가 지형을 고치면 대사가 함께 흔들린다 |
| cm2 스크립트 | `assets/*.cm2` | 좌표 하드코딩. `assets/lore_ep1.cm2` 는 **어디서도 로드되지 않는 고아 파일**(grep 결과 `LoadScript("lore_ep1...")` 0건)인데, 그 안의 좌표는 `TOWN1.json` 의 TALK 오브젝트와 정확히 일치한다(실측, [BP-26 §1](26_entity_registry_and_anchors.md) 참조) |
| 네이티브 Dart 맵 스크립트 | `lib/application/scripting/maps/` | 코드라서 콘텐츠 롤백 = 코드 롤백 |

셋 다 **"누가 만든 콘텐츠인가"** 를 표현할 수 없다. AI 가 생성한 에피소드 1과 사람이 쓴 원작 대사가
같은 파일에 섞이면, 생성물이 마음에 안 들 때 되돌릴 단위가 없다.

### 1.2 팩이 주는 네 가지 성질

| 성질 | 내용 | 이것이 없으면 |
|---|---|---|
| **합성(composition)** | `core` + `gen_ep1` + `gen_ep2` 를 겹쳐 하나의 월드로 병합 | 에피소드 추가마다 기존 파일을 수정해야 함 |
| **생성물 격리(isolation)** | AI 산출물은 항상 `gen_*` 팩 안에만 쓰인다. `core` 는 사람이 소유 | 원작 대사가 생성물에 덮여도 알 수 없음 |
| **롤백(rollback)** | 팩 디렉토리 하나를 지우면 그 에피소드가 통째로 사라진다. `content.lock.json` 이 재빌드 해시로 증명 | "이 대사 어디서 왔지" 를 추적 불가 |
| **버전 호환(compat)** | 세이브가 `contentVersion:{packId:version}` 을 기록(D-08). 팩 버전이 세이브보다 낮으면 로드 거부 | 콘텐츠를 고치면 옛 세이브가 조용히 깨짐 |

### 1.3 팩 = 소유권 경계 + 병합 단위 + 롤백 단위

```
core        사람이 소유. 원작 이식분. AI 는 읽기만 한다.
gen_ep1     생성 팩. AI 가 쓰기 가능. core 에 의존.
gen_ep2     생성 팩. core, gen_ep1 에 의존 가능.
```

- **R-21-1** 하나의 파일은 정확히 하나의 팩에 속한다. 팩 경계를 넘는 파일 공유 금지.
- **R-21-2** 팩은 자기 팩의 ID 와 `dependsOn` 에 선언한 팩의 ID 만 참조할 수 있다(§4.7).
- **R-21-3** 팩 간 순환 의존 금지. 빌드가 위상 정렬에 실패하면 하드 실패.
- **R-21-4** 병합 순서는 `dependsOn` 위상 정렬 결과이며, 같은 ID 의 재정의는 **금지**(덮어쓰기 없음).
  기존 엔티티를 바꾸려면 그 엔티티를 소유한 팩을 수정해야 한다. 이 규칙이 "생성 팩이 원작을
  몰래 바꾸는" 사고를 원천 차단한다.

---

## 2. 디렉토리 레이아웃

### 2.1 전체 트리 (D-03 확정 레이아웃의 상세화)

```
hadar2026_app/assets/content/
  <packId>/                       # 팩 루트. 디렉토리 이름 == pack.json#id
    pack.json                     # [필수] 매니페스트 (팩당 정확히 1개)
    world/
      lore.json                   # [core 필수 / gen 선택] 세계 축·연대기·톤
      factions.json               # [선택] 세력 카탈로그
      places.json                 # [선택] 장소 카탈로그 (맵과 1:N)
    actors/
      <actor_slug>.json           # [선택] NPC 1인 1파일
    items/
      items.json                  # [선택] 아이템 카탈로그 (팩당 1파일)
    quests/
      <quest_slug>.json           # [선택] 퀘스트 1건 1파일
    dialogue/
      <dialogue_slug>.json        # [선택] 대화 그래프 1건 1파일
    anchors/
      <MAPNAME>.json              # [선택] 맵별 앵커 묶음. 파일명 == 맵 이름
    strings/
      ko.json                     # [필수, 비어 있어도 파일은 존재] 표시 문자열 전량
    encounters/
      encounters.json             # [선택] 인카운터 정의 (BP-22 §7)
    _gen/                         # [선택] 생성 파이프라인 중간 산출물(감사용, 빌드 입력 아님)
      outline/<quest_slug>.json
      critic/<quest_slug>.json

hadar2026_app/assets/content/build/     # 빌드 산출물. 팩 바깥. 커밋 대상.
  content.bundle.json
  content.index.json
  content.lock.json
```

### 2.2 디렉토리·파일별 규약

| 경로 | 필수 | 파일당 엔티티 수 | 파일명 규칙 | 근거 |
|---|---|---|---|---|
| `pack.json` | 필수 | 1 (매니페스트) | 고정 | 팩 식별 |
| `world/lore.json` | `core` 필수, `gen_*` 선택 | 1 (문서 1개) | 고정 | BP-22 §2 |
| `world/factions.json` | 선택 | N (배열) | 고정 | 세력 수가 적음(≤30) |
| `world/places.json` | 선택 | N (배열) | 고정 | 장소 그래프는 한눈에 봐야 함 |
| `actors/<slug>.json` | 선택 | **정확히 1** | `<slug>` == actor ID 의 슬러그 | diff 국소화. NPC 는 자주 개별 수정됨 |
| `items/items.json` | 선택 | N (배열, ≤ 500) | 고정 | 카탈로그는 정렬·중복 검사가 쉬워야 함 |
| `quests/<slug>.json` | 선택 | **정확히 1** | `<slug>` == quest ID 의 슬러그 | 퀘스트 1건 = 생성 파이프라인 1회 단위 |
| `dialogue/<slug>.json` | 선택 | **정확히 1** | `<slug>` == dialogue ID 의 슬러그 | 대화 그래프는 단독 검증 대상 |
| `anchors/<MAPNAME>.json` | 선택 | N (맵 1개의 앵커 전량) | `<MAPNAME>` == `MapInfos.json#name` (대소문자 그대로) | 맵 편집 단위와 일치 |
| `strings/ko.json` | 필수 | N (플랫 맵) | 고정 | 언어 코드 = 파일명. `ko` 만 구현(D-17) |
| `encounters/encounters.json` | 선택 | N (배열) | 고정 | 인카운터는 전투 밸런스 표로 한꺼번에 본다 |

- **R-21-5** `actors/`, `quests/`, `dialogue/` 는 **1파일 1엔티티**다. 이유는 두 가지다.
  (a) 생성 에이전트가 파일을 통째로 다시 쓰는 편이 부분 수정보다 실패율이 낮다.
  (b) git diff 와 `hadar_content diff` 가 "무엇이 바뀌었나" 를 엔티티 단위로 보고할 수 있다.
- **R-21-6** 파일명의 슬러그와 파일 내부 `id` 의 슬러그가 다르면 **빌드 하드 실패**.
  (예: `actors/lore_gate_guard.json` 안의 `id` 가 `npc.core.gate_guard` 이면 실패)
- **R-21-7** (`CV-07`) `anchors/<MAPNAME>.json` 의 `MAPNAME` 은 `assets/maps/MapInfos.json` 에 있고
  **실제 맵 파일로 해석되어야** 한다. 이름 존재만으로는 부족하다 — 근거는 GROUND_TRUTH 부록 D-1:
  현행 등록 이름 15개 중 **7개가 존재하지 않는 파일로 해석**된다(`TOWN1`→`Map004.json` 부재 등).
  더 나쁜 것은 **등록되어 있다는 사실 자체가 로드를 깨뜨린다**는 점이다.
  `hadar2026_app/lib/application/map_navigation.dart:30` 이 폴백 `'<이름>.json'` 을 먼저 세우고
  `:43` 이 이름을 찾으면 `Map{id:03d}.json` 으로 **덮어쓰기** 때문이다. 미등록인 `ORIGIN` 은
  폴백이 살아남아 정상 로드된다(부록 F-4).
  - 현행 등록 이름 15개: `Test, LORE_EP, MAP003, TOWN1, GROUND1, DEN1, DEN2, Template_TOWN, Prolog,
    Prolog_B1, Prolog_B2, Template_DUNGEON, LoreContinent, CastleLore, LastDitch`
    — 이 중 **해석 성공 8개**(Test, LORE_EP, MAP003, Prolog_B1, Prolog_B2, LoreContinent, CastleLore, LastDitch),
    **해석 실패 7개**(TOWN1, GROUND1, DEN1, DEN2, Template_TOWN, Prolog, Template_DUNGEON).
  - 검증 표현의 정본은 [BP-22 §4.7 G-22-1 / R-22-11](22_world_bible_model.md) 이며 이 장은 그 표현을 채택한다.
  - 수리 경로는 **기존 데이터뿐**이다: 맵 에디터의 `registerAs` 는 이미 `json` 필드를 쓰므로
    (`tools/mapEditor/server/ai_api.ts:592`, 부록 H-4) 신규 맵은 올바르게 등록된다.
    기존 15개 엔트리에 `json` 필드를 채우는 것이 [BP-22 T-22-1](22_world_bible_model.md) 이고,
    이 장의 `R-21-7`·`C14`·`E14`는 **T-22-1 을 선행 의존**으로 갖는다.
- **R-21-8** `_gen/` 은 감사·재개용이며 **빌드 입력이 아니다**. 빌드는 이 디렉토리를 무시한다.
- **R-21-9** 위 표에 없는 디렉토리·파일이 팩 루트에 있으면 빌드가 경고(soft)한다. 오타 조기 발견용.

### 2.3 빌드 산출물

| 파일 | 내용 | 소비자 |
|---|---|---|
| `content.bundle.json` | 전 팩 병합 + 정규화(문자열 인라인 해소, 기본값 채움, Condition 정규형) | 런타임 `ContentRepository` |
| `content.index.json` | 트리거 인덱스 `(map,x,y,kind)→anchorId`, 역참조 인덱스(BP-26 §5) | 런타임 `TriggerIndex`, 린트, 생성 컨텍스트 |
| `content.lock.json` | 소스 파일별 SHA-256, 스키마 버전, 팩 버전, `legacyFlagMap`, 빌드 결정론 증빙 | CI, 마이그레이션, 세이브 호환 판정 |

- **R-21-10** 산출물은 **커밋한다**(gitignore 하지 않는다). 근거: 재현성 증빙을 diff 로 볼 수 있어야 하고,
  Flutter web 빌드가 `pubspec.yaml#flutter/assets` 로 이 파일들을 번들에 넣어야 한다.
- **R-21-11** 빌드는 결정론적이다. 같은 소스 → 같은 바이트. 정렬·부동소수 없음·타임스탬프 없음.
  `content.lock.json` 의 `buildInputHash` 가 이를 고정하고 CI 가 재빌드 후 해시 일치를 검사한다(D-15).
- **R-21-46** (`CV-08`) **팩 디렉토리는 `pubspec.yaml#flutter/assets` 에 명시 열거해야 번들에 실린다.**
  근거는 GROUND_TRUTH 부록 A-4: Flutter 의 디렉토리 선언은 **하위 디렉토리를 포함하지 않으며**,
  현행 `hadar2026_app/pubspec.yaml` 은 `assets/`, `assets/images/`, `assets/maps/`, `assets/fonts/`
  4개만 열거한다. §2.1 레이아웃은 팩당 최대 8개 하위 디렉토리 + 팩 루트를 요구하므로,
  팩이 하나 늘 때마다 pubspec 에 9줄 이상이 필요하다.
  - 이 목록의 **생성은 빌드가 담당**한다([BP-35](35_ci_and_build.md)). 사람이 손으로 유지하지 않는다.
  - 웹 페이로드 실측은 총 45MB(그중 게임 자산 9.7MB, 부록 B-5)이므로,
    **소스 JSON 을 번들에서 빼고 `assets/content/build/` 만 선언하는 선택**이 가능하다.
    다만 소스가 수 MB 수준이 아니라면 이득이 작다 — 판단은 BP-35 소관이다.

---

## 3. `pack.json` 스키마

### 3.1 필드 표

| 필드 | 타입 | 필수 | 기본값 | 제약 | 예시 |
|---|---|---|---|---|---|
| `id` | string | ✅ | — | `^[a-z][a-z0-9_]{2,31}$`. 디렉토리 이름과 동일. 예약어 금지(§4.5) | `"gen_ep1"` |
| `schemaVersion` | integer | ✅ | — | ≥ 1. 빌드가 아는 최대치보다 크면 하드 실패. **현재 정본은 `2`**(D-31, §7.2.1). `1` 은 N-1 자동 승격 대상(R-21-42) | `2` |
| `version` | string | ✅ | — | semver `MAJOR.MINOR.PATCH` (프리릴리스·빌드메타 금지) | `"0.3.1"` |
| `title` | string | ✅ | — | 1~60자. 표시용이며 문자열 키가 아니다(툴 UI 전용) | `"에피소드 1: 사라진 학자"` |
| `dependsOn` | string[] | ✅ | — | 팩 id 배열. 빈 배열 허용. 순환 금지 | `["core"]` |
| `generatedBy` | object | ✅ | — | §3.2 | — |
| `description` | string | ⬜ | `""` | ≤ 500자 | `"로어성 학자 실종 사건"` |
| `authors` | string[] | ⬜ | `[]` | — | `["yk.ahn", "agent:writer-v3"]` |
| `license` | string | ⬜ | `"proprietary"` | — | `"proprietary"` |
| `idPrefix` | string | ⬜ | `id` 와 동일 | ID 두 번째 세그먼트로 쓰이는 값. 보통 `id` 와 같게 두고 건드리지 않는다 | `"gen_ep1"` |
| `retiredIds` | object[] | ⬜ | `[]` | §4.6 | — |
| `migrations` | object[] | ⬜ | `[]` | §7.3 | — |
| `entryPoints` | object | ⬜ | `{}` | 이 팩이 월드에 붙는 지점(§3.3) | — |
| `contentBudget` | object | ⬜ | §3.4 기본값 | soft gate 임계값 | — |
| `_note` | string | ⬜ | — | 주석 대용. 빌드가 무시 | — |

### 3.2 `generatedBy`

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `kind` | `"human"` \| `"agent"` \| `"mixed"` | ✅ | 생성 주체 |
| `pipeline` | string | ⬜ | 생성 파이프라인 식별(D-14). 예 `"hadar-gen/8stage"` |
| `model` | string | ⬜ | 모델 식별자. `kind != "human"` 이면 권장 |
| `promptVersion` | string | ⬜ | 프롬프트 계약 버전([BP-37](37_prompt_contracts.md)) |
| `at` | string | ⬜ | ISO-8601 UTC. **`content.lock.json` 이 아니라 여기 둔다** — lock 은 결정론을 지켜야 하므로 시각을 담지 않는다 |

### 3.3 `entryPoints`

생성 팩이 기존 월드에 "어디로 접속하는가" 를 선언한다. 린트가 고아 콘텐츠를 잡는 근거다.

```json
"entryPoints": {
  "quests": ["quest.gen_ep1.missing_scholar"],
  "anchors": ["anchor.gen_ep1.town1_scholar_wife"],
  "places": ["place.gen_ep1.scholar_house"],
  "stateKeys": [
    { "key": "flag.gen_ep1.quest.missing_scholar.name_recorded",
      "role": "provides",
      "_note": "후속 에피소드가 읽을 것을 전제한 접점. 이 팩 안에는 독자가 없다." }
  ]
}
```

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `quests` | quest id[] | ⬜ | 이 팩이 월드에 노출하는 진입 퀘스트 |
| `anchors` | anchor id[] | ⬜ | 기존 맵에 새로 심는 앵커 |
| `places` | place id[] | ⬜ | 이 팩이 추가하는 장소 |
| `stateKeys` | object[] | ⬜ | **팩 경계를 넘는 상태 접점**. `{ key, role, _note? }` |

`stateKeys[].role` (닫힌 집합): `provides`(이 팩이 쓰고 남이 읽는다) · `consumes`(남이 쓴 것을 이 팩이 읽는다) ·
`shared`(양방향).

- **R-21-12** `entryPoints.quests` 에 선언되지 않았고 다른 퀘스트가 참조하지도 않는 퀘스트는
  린트 경고(고아 퀘스트).
- **R-21-47** `stateKeys` 는 [BP-26 §5.4](26_entity_registry_and_anchors.md) 의 역참조 검사
  `RG-02`(아무도 읽지 않는 플래그) / `RG-03`(아무도 쓰지 않는 플래그) 경고를 **의도 선언으로 억제**한다.
  근거(BP-91 `W-11`): 후속 에피소드를 위해 일부러 남기는 플래그를 `_note` 의 `lint-ignore` 로 숨기면
  그것은 의도의 표현이 아니라 경고의 은폐다. 억제는 반드시 이 칸을 통해서만 한다.
  - `role: "provides"` → `RG-02` 억제. `role: "consumes"` → `RG-03` 억제. `shared` → 양쪽 억제.
  - 선언했는데 실제로 그 팩에서 읽지도 쓰지도 않으면 **별개 경고**(허위 접점 선언).

### 3.4 `contentBudget` (soft gate 임계값, D-15)

| 필드 | 타입 | 기본값 | 의미 |
|---|---|---|---|
| `maxQuests` | int | `50` | 팩당 퀘스트 상한 |
| `maxDialogueNodes` | int | `2000` | 팩당 대화 노드 총합 |
| `maxStringChars` | int | `400000` | `strings/ko.json` 값 문자 총합 |
| `warnLineChars` | int | **[BP-24 §24.5](24_dialogue_model.md) 의 권장값** | 한 줄 권장 최대 글자수. **이 장은 기본값을 정하지 않는다** |
| `warnNodePages` | int | `2` | 한 노드가 넘길 권장 최대 페이지 수 |

- **R-21-48** (`I-10` 해소) 텍스트 길이 수치의 소유는 **BP-24**다(D-18). 초판 BP-21 은 `warnLineChars`
  기본값을 `31`(496px ÷ 16px 전각 가정)로 못박았으나, BP-24 는 480px 기준으로 권장 28자·경고 29~45·
  에러 >45 를 정의했다. **폭 산정 자체가 갈렸으므로(496 vs 480) 이 장은 수치를 버리고 소유 장을 따른다.**
  `contentBudget.warnLineChars` 는 팩이 BP-24 의 권장값을 **더 좁힐 때만** 명시하는 선택 필드다
  (넓히는 값을 쓰면 린트가 경고).

### 3.5 예시 1 — `core`

```json
{
  "id": "core",
  "schemaVersion": 2,
  "version": "1.0.0",
  "title": "하다르 원작 이식",
  "description": "REF_hadar / REF_UNITY_LoreEp1 에서 이식한 원작 세계관과 대사.",
  "dependsOn": [],
  "authors": ["smgal"],
  "generatedBy": { "kind": "human" },
  "entryPoints": {
    "anchors": ["anchor.core.town1_gate_guard"],
    "places": ["place.core.lore_castle"],
    "quests": [],
    "stateKeys": []
  },
  "retiredIds": [],
  "migrations": [ { "from": 1, "to": 2, "steps": [], "_note": "D-31 do 22→25 순수 확대. 소스 변환 없음 (R-21-70)" } ],
  "_note": "core 는 AI 가 쓰기 금지. 읽기 전용 참조 팩이다."
}
```

### 3.6 예시 2 — `gen_ep1`

```json
{
  "id": "gen_ep1",
  "schemaVersion": 2,
  "version": "0.3.1",
  "title": "에피소드 1: 사라진 학자",
  "description": "로어성의 학자가 메너스로 향한 뒤 소식이 끊긴다.",
  "dependsOn": ["core"],
  "authors": ["agent:outline-v2", "agent:writer-v3", "yk.ahn"],
  "generatedBy": {
    "kind": "agent",
    "pipeline": "hadar-gen/8stage",
    "model": "claude-opus-5",
    "promptVersion": "bp37/2026-08",
    "at": "2026-08-30T04:11:00Z"
  },
  "entryPoints": {
    "quests": ["quest.gen_ep1.missing_scholar"],
    "anchors": ["anchor.gen_ep1.town1_scholar_wife"],
    "places": ["place.gen_ep1.scholar_house"],
    "stateKeys": [
      { "key": "flag.gen_ep1.quest.missing_scholar.name_recorded", "role": "provides" }
    ]
  },
  "contentBudget": { "maxQuests": 12 },
  "retiredIds": [
    {
      "id": "npc.gen_ep1.tavern_drunk",
      "retiredAt": "0.2.0",
      "reason": "core 의 주점 취객과 중복. dlg 를 core 로 넘김.",
      "replacedBy": "npc.core.lore_tavern_drunk"
    }
  ],
  "migrations": [
    {
      "from": 1,
      "to": 2,
      "steps": [
        { "kind": "rename_id", "from": "flag.gen_ep1.quest.missing_scholar.met", "to": "flag.gen_ep1.quest.missing_scholar.met_client" }
      ],
      "_note": "이 팩은 1→2 경로에 자체 변환(플래그 개명)이 있다. D-31 의 do 추가는 순수 확대이므로 여기에 별도 step 이 필요 없다 — steps 는 콘텐츠 변환만 담는다(R-21-70)."
    }
  ]
}
```

> **`core` 와 `gen_ep1` 의 `migrations` 가 다른 이유**: 둘 다 `from:1 → to:2` 경로를 **선언**해야 하지만
> (R-21-70), 담는 `steps` 는 그 팩의 콘텐츠 사정에 달렸다. `core` 는 바꿀 것이 없어 `steps: []` 이고
> `gen_ep1` 은 자체 개명이 하나 있다. **포맷 승격(do 추가)은 어느 쪽의 `steps` 에도 나타나지 않는다** —
> 순수 확대는 구 데이터를 변환하지 않기 때문이다.

### 3.7 JSON Schema 발췌 (전문은 [BP-90](90_appendix_schemas.md))

**`$id` 명명 규약** (`I-12` 해소) — 두 네임스페이스를 **접두 경로로 분리**한다. 파일명 규칙을 통일하는 대신
용도가 다른 두 계열이 섞이지 않게 하는 쪽을 택한다(이미 작성된 BP-90·BP-37 을 모두 유효하게 두는 최소 변경).

| 계열 | `$id` 형태 | 디스크 경로 | 소유 |
|---|---|---|---|
| **콘텐츠 스키마**(팩·엔티티·DSL·번들) | `https://hadar2026/schema/<name>.json` | `schema/<name>.json` | 이 장 + [BP-90](90_appendix_schemas.md) |
| **생성 계약 스키마**(에이전트 입출력) | `https://hadar2026/schema/gen/<name>.schema.json` | `schema/gen/<name>.schema.json` | [BP-37](37_prompt_contracts.md) |

- **R-21-49** 로더는 `$id` 의 `https://hadar2026/schema/` 접두를 벗기고 남은 경로를 그대로 디스크 경로로 쓴다.
  따라서 매핑 규칙은 **하나**이며, `gen/` 하위인지 여부만으로 두 계열이 구분된다.
- 모든 `$ref` 는 절대 `$id` 를 쓴다(상대 `$ref` 금지). 근거는 BP-90 `R-90-3`.

```json
{
  "$id": "https://hadar2026/schema/pack.json",
  "type": "object",
  "required": ["id", "schemaVersion", "version", "title", "dependsOn", "generatedBy"],
  "additionalProperties": false,
  "properties": {
    "id":            { "type": "string", "pattern": "^[a-z][a-z0-9_]{2,31}$" },
    "schemaVersion": { "type": "integer", "minimum": 1 },
    "version":       { "type": "string", "pattern": "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$" },
    "title":         { "type": "string", "minLength": 1, "maxLength": 60 },
    "dependsOn":     { "type": "array", "items": { "type": "string", "pattern": "^[a-z][a-z0-9_]{2,31}$" }, "uniqueItems": true },
    "generatedBy": {
      "type": "object",
      "required": ["kind"],
      "properties": { "kind": { "enum": ["human", "agent", "mixed"] } }
    },
    "retiredIds": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "retiredAt", "reason"],
        "properties": {
          "id":         { "$ref": "#/$defs/entityId" },
          "retiredAt":  { "type": "string" },
          "reason":     { "type": "string" },
          "replacedBy": { "$ref": "#/$defs/entityId" }
        }
      }
    }
  }
}
```

---

## 4. ID 체계 (D-04 상세화)

### 4.1 두 가지 문법

ID 는 **엔티티 ID** 와 **상태 키** 두 종류다. 문법이 다르다.

```ebnf
(* 엔티티 ID: 3 세그먼트 고정 *)
entity-id   = type "." pack "." slug ;
type        = "npc" | "quest" | "item" | "dlg" | "place" | "anchor"
            | "faction" | "enc" | "lore" ;
pack        = short-slug ;
slug        = lower alnum-us{2,47} ;              (* 3~48자 *)
short-slug  = lower alnum-us{2,31} ;              (* 3~32자 *)
lower       = "a".."z" ;
alnum-us    = lower | "0".."9" | "_" ;

(* 상태 키: 4 세그먼트 이상, 마지막이 점으로 이어질 수 있음 *)
state-key   = state-type "." pack "." domain "." dotted-name ;
state-type  = "flag" | "var" ;
domain      = short-slug ;
dotted-name = slug { "." slug } ;

(* 문자열 키: §5. slot 은 단일 세그먼트가 아니라 '경로' 다 — §4.1.1 *)
string-key  = "str" "." pack "." owner-type "." owner-slug "." slot-path ;
owner-type  = "npc" | "quest" | "item" | "dlg" | "place" | "faction" | "enc" | "lore" | "ui" ;
owner-slug  = slug ;
slot-path   = slot-seg { "." slot-seg } ;         (* 1개 이상 *)
slot-seg    = local-name | index ;
local-name  = lower alnum-us{1,47} ;              (* 2~48자. 로컬 ID 최소 길이에 맞춤 *)
index       = "0" | nonzero digit{0,3} ;          (* 0~9999, 선행 0 금지 *)
nonzero     = "1".."9" ;
digit       = "0".."9" ;

(* 참조 전용 타입: 정의는 코드가 하고 콘텐츠는 참조만 한다 — §4.2 *)
enemy-ref   = "enemy" "." pack "." slug ;
```

정규식 형태:

```
ENTITY_ID  ^(npc|quest|item|dlg|place|anchor|faction|enc|lore)\.[a-z][a-z0-9_]{2,31}\.[a-z][a-z0-9_]{2,47}$
ENEMY_REF  ^enemy\.[a-z][a-z0-9_]{2,31}\.[a-z][a-z0-9_]{2,47}$
STATE_KEY  ^(flag|var)\.[a-z][a-z0-9_]{2,31}\.[a-z][a-z0-9_]{2,31}(\.[a-z][a-z0-9_]{2,47})+$
STRING_KEY ^str\.[a-z][a-z0-9_]{2,31}\.(npc|quest|item|dlg|place|faction|enc|lore|ui)\.[a-z][a-z0-9_]{2,47}(\.([a-z][a-z0-9_]{1,47}|0|[1-9][0-9]{0,3}))+$
```

#### 4.1.1 문자열 키의 `slot` 은 **경로**다 — 정본 확정 (`W-01` / REVIEW_BP-21 `F-01`)

초판은 `slot = slug`(단일 세그먼트, 점 불가)로 규정하면서 §5.3 표준 슬롯에는
`node.<nodeId>.line.<n>` 처럼 **점을 포함하고 숫자로 끝나는** 형태를 실었다. 두 규정이 양립하지 않아
**BP-21 자신의 예시 9개 중 8개**, [BP-91](91_appendix_worked_example.md) 예제의 대화 문자열 키 26개,
[BP-26 §8.2~§8.3](26_entity_registry_and_anchors.md) 이관 도구가 생성하는 키가 전부 하드 실패했다.

**확정: §5.3 표준 슬롯 표가 정본이고, 정규식을 그에 맞춰 확장한다.**

근거 3가지 —

| # | 근거 |
|---|---|
| 1 | 슬롯은 **소유 엔티티 내부의 구조 경로**다(`node`→`intro`→`line`→`0`). 이것을 `node_intro_line_0` 처럼 한 세그먼트로 뭉개면 키에서 구조를 되읽을 수 없고, 자동 생성기가 슬러그 규칙(연속 `_` 금지)과 충돌한다 |
| 2 | 구분자를 `_`/`-` 로 바꾸는 안은 **로컬 ID 자체가 `_` 를 포함**하므로(`find_trail`, `wife_plea`) 파싱이 모호해진다 |
| 3 | 이미 세 문서(BP-21 §5.4·BP-26 §8·BP-91)와 BP-90 `common.stringKey` 가 경로형 슬롯을 전제로 쓰였다. 정규식 한 줄을 고치는 쪽이 파급이 최소다 |

파생 규칙 —

- **R-21-50** (`CV-01`) 문자열 키는 `STRING_KEY` 정규식을 만족해야 한다. 위반은 **하드 실패**.
- **R-21-51** `slot-path` 는 **1개 이상**의 세그먼트를 갖는다. `str.core.npc.x` 처럼 슬롯이 없는 키는 실패.
- **R-21-52** `index` 세그먼트는 `0` 또는 선행 0 없는 1~4자리 정수다. `01`·`00` 은 실패
  (같은 슬롯이 두 표기를 가지면 중복 키가 생긴다).
- **R-21-53** 키 전체 길이는 **200자 이하**. 초과는 하드 실패(구조 경로가 무한히 깊어지는 것을 막는다).
- **R-21-54** `slot-seg` 의 최소 길이는 **2자**로, 로컬 ID 문법(`^[a-z][a-z0-9_]{1,31}$`, §4.2 표)의
  최소 길이와 같다. 따라서 **어떤 유효한 로컬 ID 도 그대로 슬롯 세그먼트가 될 수 있다** — 이것이
  "슬롯 = 구조 경로" 를 성립시키는 조건이다.

**검증 수행 기록** (실제로 스크립트를 돌려 확인함) — 위 4종 정규식을 이 문서 ·
[BP-22](22_world_bible_model.md) · [BP-26](26_entity_registry_and_anchors.md) 세 파일에서 추출한
**ID 형태 토큰 273개 전량에 대입**했다.

| 검사 | 대상 | 결과 |
|---|---|---|
| `STRING_KEY` | 세 파일의 `str.` 토큰 **29개** | **불통과 3건 — 전부 의도된 비-ID**: ① §4.1.1 의 반례 `str.core.npc.x`(슬롯 없음) ② §5.2 의 키 접두 서술 `str.core.npc.lore_gate_guard.` ③ BP-22 의 슬롯 서술 `str.core.item.<slug>.name`. **실제 예시 키는 전부 통과** |
| `STATE_KEY` | `flag.`/`var.` 토큰 | 불통과 2건 — 둘 다 이 절과 §7.3 이 "잘못된 예시" 로 **인용**하는 `flag.gen_ep1.quest.a.met*`(`F-06`). 마이그레이션 예시 본문은 유효 키로 교체 완료 |
| `ENTITY_ID` / `ENEMY_REF` | 나머지 토큰 | 불통과는 전부 **필드 경로 서술**(`enc.members[].enemy`, `anchor.dialogue`, `item.effects`, `place.map`)이거나 플레이스홀더(`dlg.x#…`)이며 ID 가 아니다 |

초판 상태에서 같은 검사를 돌리면 §5.4 의 문자열 키 예시 **9개 중 8개**,
[BP-26 §8.3](26_entity_registry_and_anchors.md) 이 생성하는 키, [BP-91](91_appendix_worked_example.md) 의 26개가
모두 불통과였다. **개정 후 실제 키의 불통과는 0 이다.**

### 4.2 타입 접두사 전체 목록

| 접두사 | 대상 | 소유 파일 | 예시 |
|---|---|---|---|
| `npc` | 액터(NPC·동료·유령·목소리) | `actors/<slug>.json` | `npc.core.lore_gate_guard` |
| `quest` | 퀘스트 | `quests/<slug>.json` | `quest.gen_ep1.missing_scholar` |
| `item` | 아이템 | `items/items.json` | `item.core.rusty_key` |
| `dlg` | 대화 그래프 | `dialogue/<slug>.json` | `dlg.gen_ep1.guard_intro` |
| `place` | 장소 | `world/places.json` | `place.core.lore_castle` |
| `anchor` | 앵커(좌표 바인딩) | `anchors/<MAP>.json` | `anchor.core.town1_gate_guard` |
| `faction` | 세력 | `world/factions.json` | `faction.core.lore_order` |
| `enc` | 인카운터(적 조합) | `encounters/encounters.json` | `enc.core.menace_patrol` |
| `lore` | 연대기 사건 | `world/lore.json` | `lore.core.rise_of_necromancer` |
| `flag` | 불리언 상태 | (선언 없음, 사용처가 곧 선언) | `flag.gen_ep1.quest.missing_scholar.met_client` |
| `var` | 정수 상태 | (선언 없음) | `var.core.party.reputation_lore` |
| `str` | 표시 문자열 | `strings/ko.json` | `str.core.npc.lore_gate_guard.name` |

**참조 전용 타입** — 정의는 **콘텐츠가 아니라 코드**가 하고, 콘텐츠는 참조만 한다.
`kEntityTypes`(§4.4)와는 별도 집합이며 `validateEnemyRef` 로 검사한다.

| 접두사 | 대상 | 정의 위치 | 참조 위치 | 예시 |
|---|---|---|---|---|
| `enemy` | 적 종 | `lib/domain/battle/enemy_data.dart` (코드) → 빌드가 `build/enemies.index.json` 생성 | `encounters/encounters.json` 의 `members[].enemyRef` | `enemy.core.orc` |

- **R-21-55** (`CV-02`) 콘텐츠 팩은 `enemy.*` 를 **정의할 수 없다**. 정의하면 하드 실패.
  참조는 `build/enemies.index.json` 에 존재하는 `ref` 값에 한한다.
- **R-21-56** (`I-08` 해소, 소유는 [BP-22 §7.3~§7.4](22_world_bible_model.md))
  **번들·목표·전투 API 의 정본 표기는 정수 id** 이고, `enemy.<pack>.<slug>` 는 **소스 가독성 별칭**이다.
  빌드가 별칭을 정수로 정규화하며, 별칭과 정수가 어긋나면 하드 실패.
  이 규칙이 BP-22(문자열)·[BP-23](23_quest_model.md)(정수)·[BP-35](35_ci_and_build.md)(정수)의 3갈래를 하나로 묶는다.
- **R-21-57** (부록 B-1) 유효한 적 정수 id 는 **1~74** 다. `hadar2026_app/lib/application/battle.dart:44`
  의 `if (enemyTableId <= 0 || enemyTableId >= enemyTable.length) return;` 가드 때문에
  **id 0(`Orc`)은 어떤 경로로도 소환되지 않는다.** 테이블 엔트리는 75개(id 0~74)지만
  **실사용 가능한 적은 74종**이다. `enemy.*` 별칭 집합도 id 0 을 포함하지 않는다.

**로컬 ID(전역 ID 아님)** — 아래는 부모 엔티티 안에서만 유일하면 되고, 위 문법을 따르지 않는다.

| 로컬 ID | 스코프 | 문법 | 정의 장 |
|---|---|---|---|
| Stage `id` | 소속 퀘스트 | `^[a-z][a-z0-9_]{1,31}$` | [BP-23](23_quest_model.md) |
| Objective `id` | 소속 Stage | 동일 | [BP-23](23_quest_model.md) |
| Node `id` | 소속 대화 | 동일 | [BP-24](24_dialogue_model.md) |
| Choice `go` 대상 | 소속 대화 | 동일 | [BP-24](24_dialogue_model.md) |

- **R-21-13** 로컬 ID 를 전역에서 가리켜야 할 때는 `quest.gen_ep1.missing_scholar#stage_2` 처럼
  `#` 로 잇는다. 이 형태는 참조에만 쓰이고 정의부에는 나타나지 않는다.

### 4.3 슬러그 규칙

| 규칙 | 값 | 위반 시 |
|---|---|---|
| 허용 문자 | `a-z`, `0-9`, `_` | 하드 실패 |
| 길이 | 3~48자 (팩 슬러그는 3~32자) | 하드 실패 |
| 첫 글자 | 반드시 영문 소문자 (숫자·`_` 시작 금지) | 하드 실패 |
| 연속 `_` | 금지 (`__`) | 하드 실패 |
| 끝 `_` | 금지 | 하드 실패 |
| 대문자·하이픈·공백·비ASCII | 금지 | 하드 실패 |
| 의미 | 영어 snake_case 권장. 한글 음차(`ro_eo_seong`)보다 의미어(`lore_castle`) 선호 | 린트 경고 |

- **R-21-14** 슬러그는 사람이 읽는 식별자다. 자동 생성 시에도 `npc_0417` 같은 무의미 슬러그를 만들지 말 것.
  린트가 `^[a-z]{1,3}_?\d+$` 패턴을 경고한다.

### 4.4 정규식 검증기 의사코드

```dart
// lib/domain/content/content_ids.dart (D-11 배치)
sealed class ContentId {
  final String raw;
  const ContentId(this.raw);
}

class IdError {
  final String raw;
  final String code;   // 'bad_shape' | 'bad_type' | 'bad_slug' | 'reserved' | 'retired' | 'cross_pack'
  final String message;
  final String? hint;  // 맵 에디터 API 와 같은 {error, hint} 규약 (GROUND_TRUTH §11)
}

const kEntityTypes = {'npc','quest','item','dlg','place','anchor','faction','enc','lore'};
const kStateTypes  = {'flag','var'};
const kReservedPacks = {'build','core_internal','tmp','test','debug','system','hadar','null','none'};
final _slug      = RegExp(r'^[a-z][a-z0-9_]{2,47}$');
final _shortSlug = RegExp(r'^[a-z][a-z0-9_]{2,31}$');

IdError? validateEntityId(String raw, {required String owningPack, required Set<String> visiblePacks}) {
  final parts = raw.split('.');
  if (parts.length != 3) {
    return IdError(raw, 'bad_shape', '엔티티 ID 는 <type>.<pack>.<slug> 3 세그먼트여야 합니다.',
        hint: '예: npc.core.lore_gate_guard');
  }
  final [type, pack, slug] = parts;
  if (!kEntityTypes.contains(type)) {
    return IdError(raw, 'bad_type', '알 수 없는 타입 접두사 "$type".',
        hint: '허용: ${kEntityTypes.join(", ")}');
  }
  if (!_shortSlug.hasMatch(pack) || kReservedPacks.contains(pack)) {
    return IdError(raw, 'reserved', '팩 세그먼트 "$pack" 가 잘못되었거나 예약어입니다.');
  }
  if (!_slug.hasMatch(slug) || slug.contains('__') || slug.endsWith('_')) {
    return IdError(raw, 'bad_slug', '슬러그 "$slug" 가 규칙 위반입니다.',
        hint: '소문자/숫자/언더스코어 3~48자, 영문으로 시작, 연속·말미 언더스코어 금지');
  }
  // 정의부는 자기 팩만 / 참조부는 보이는 팩만 (§4.7)
  if (!visiblePacks.contains(pack)) {
    return IdError(raw, 'cross_pack', '팩 "$pack" 은 $owningPack 의 dependsOn 에 없습니다.',
        hint: 'pack.json#dependsOn 에 "$pack" 를 추가하거나 참조를 제거하세요.');
  }
  return null;
}

IdError? validateStateKey(String raw, {required Set<String> visiblePacks}) {
  final parts = raw.split('.');
  if (parts.length < 4) return IdError(raw, 'bad_shape',
      '상태 키는 <flag|var>.<pack>.<domain>.<name...> 4 세그먼트 이상이어야 합니다.',
      hint: '예: flag.gen_ep1.quest.missing_scholar.met_client');
  if (!kStateTypes.contains(parts[0])) return IdError(raw, 'bad_type', '상태 키 타입은 flag 또는 var 입니다.');
  if (!_shortSlug.hasMatch(parts[1]) || !visiblePacks.contains(parts[1]))
    return IdError(raw, 'cross_pack', '보이지 않는 팩 "${parts[1]}".');
  if (!_shortSlug.hasMatch(parts[2])) return IdError(raw, 'bad_slug', 'domain 세그먼트 위반.');
  for (final seg in parts.sublist(3)) {
    if (!_slug.hasMatch(seg)) return IdError(raw, 'bad_slug', 'name 세그먼트 "$seg" 위반.');
  }
  return null;
}

// --- 문자열 키 (W-01 확정 문법, §4.1.1) ---
final _slotName  = RegExp(r'^[a-z][a-z0-9_]{1,47}$');   // 2~48자
final _slotIndex = RegExp(r'^(0|[1-9][0-9]{0,3})$');    // 0~9999, 선행 0 금지
const kOwnerTypes = {'npc','quest','item','dlg','place','faction','enc','lore','ui'};

IdError? validateStringKey(String raw, {required Set<String> visiblePacks}) {
  if (raw.length > 200) {
    return IdError(raw, 'too_long', '문자열 키는 200자를 넘을 수 없습니다.');
  }
  final parts = raw.split('.');
  if (parts.length < 5) {
    return IdError(raw, 'bad_shape',
        '문자열 키는 str.<pack>.<ownerType>.<ownerSlug>.<slotPath...> 5 세그먼트 이상이어야 합니다.',
        hint: '예: str.gen_ep1.dlg.wife_plea.node.intro.line.0');
  }
  if (parts[0] != 'str') return IdError(raw, 'bad_type', '문자열 키는 str 로 시작합니다.');
  if (!_shortSlug.hasMatch(parts[1]) || !visiblePacks.contains(parts[1])) {
    return IdError(raw, 'cross_pack', '보이지 않는 팩 "${parts[1]}".');
  }
  if (!kOwnerTypes.contains(parts[2])) {
    return IdError(raw, 'bad_type', '알 수 없는 소유자 타입 "${parts[2]}".',
        hint: '허용: ${kOwnerTypes.join(", ")}');
  }
  if (!_slug.hasMatch(parts[3])) {
    return IdError(raw, 'bad_slug', '소유자 슬러그 "${parts[3]}" 위반.');
  }
  for (final seg in parts.sublist(4)) {                 // slot-path: 1개 이상
    if (!_slotName.hasMatch(seg) && !_slotIndex.hasMatch(seg)) {
      return IdError(raw, 'bad_slug', '슬롯 세그먼트 "$seg" 위반.',
          hint: '소문자 2~48자 또는 선행 0 없는 0~9999 정수');
    }
  }
  return null;
}

// --- 참조 전용 타입 (§4.2) ---
IdError? validateEnemyRef(String raw, {required Set<String> knownEnemyRefs}) {
  if (!RegExp(r'^enemy\.[a-z][a-z0-9_]{2,31}\.[a-z][a-z0-9_]{2,47}$').hasMatch(raw)) {
    return IdError(raw, 'bad_shape', '적 참조는 enemy.<pack>.<slug> 형태여야 합니다.');
  }
  if (!knownEnemyRefs.contains(raw)) {
    return IdError(raw, 'unknown_ref', '알 수 없는 적 참조 "$raw".',
        hint: 'build/enemies.index.json 의 ref 값만 쓸 수 있습니다. '
              '적 정의는 lib/domain/battle/enemy_data.dart 소관이며 콘텐츠가 추가할 수 없습니다. '
              '유효 정수 id 범위는 1~74 입니다(부록 B-1).');
  }
  return null;
}
```

- **R-21-15** 검증기는 `lib/domain/content/content_ids.dart` 한 곳에만 있고, 런타임·CLI·콘텐츠 서버가
  **같은 코드를 import** 한다(D-12). TypeScript 쪽 콘텐츠 서버는 위 정규식 4종을 그대로 복제하되
  `hadar_content stats --emit-regex` 가 뽑아 준 값을 생성 코드로 넣는다(수기 복제 금지).

### 4.5 예약어

| 범주 | 값 | 이유 |
|---|---|---|
| 예약 팩 id | `build`, `core_internal`, `tmp`, `test`, `debug`, `system`, `hadar`, `null`, `none` | 산출물 디렉토리·툴 내부 네임스페이스와 충돌 |
| 예약 슬러그 | `none`, `null`, `undefined`, `default`, `self`, `this`, `end`, `complete` | `next: "end"`, `next: "complete"` 등 DSL 리터럴과 충돌 |
| 예약 domain (상태 키) | `quest`, `party`, `world`, `npc`, `map`, `sys` | 의미 고정. 아래 표 참조 |
| 예약 slot-path **첫 세그먼트** (문자열 키) | `name`, `title`, `summary`, `desc`, `header`, `journal`, `line`, `node`, `choice`, `stage`, `objective`, `default_line` | 자동 생성 슬롯. 예약은 **첫 세그먼트에만** 적용되며 두 번째 이후(로컬 ID·인덱스)는 자유 |

상태 키 domain 의미 고정:

| domain | 소유 | 예시 |
|---|---|---|
| `quest` | 퀘스트 진행 상태 | `flag.gen_ep1.quest.missing_scholar.met_client` |
| `party` | 파티 전역 | `var.core.party.reputation_lore` |
| `world` | 월드 이벤트 | `flag.core.world.necromancer_awakened` |
| `npc` | NPC 개별 상태 보조 | `flag.core.npc.lore_gate_guard.bribed` |
| `map` | 맵 국소 상태(타일 변경 등) | `flag.core.map.town1.crypt_opened` |
| `sys` | 시스템 예약 | `var.core.sys.seed_offset` |

### 4.6 삭제·은퇴 (`retiredIds`)

- **R-21-16** ID 는 **불변**이며 **재사용 금지**다. 엔티티를 지울 때는 파일을 지우고
  `pack.json#retiredIds` 에 항목을 추가한다.
- **R-21-17** 은퇴한 ID 를 **정의**하면 하드 실패. 은퇴한 ID 를 **참조**하면 하드 실패
  (단 `replacedBy` 가 있으면 빌드가 자동 치환하고 경고).
- **R-21-18** 세이브 마이그레이션은 `retiredIds` 를 읽는다. 세이브에 남은 은퇴 플래그는
  `replacedBy` 로 옮기고, 없으면 드롭한 뒤 로그에 남긴다(D-08).

```json
{ "id": "quest.gen_ep1.lost_cat", "retiredAt": "0.3.0",
  "reason": "톤 검수 탈락(RK-07). 서사 축과 무관.", "replacedBy": null }
```

### 4.7 팩 간 참조 규칙

| 상황 | 허용 | 근거 |
|---|---|---|
| 자기 팩 ID **정의** | ✅ | — |
| 다른 팩 ID **정의** | ❌ 하드 실패 | 소유권 침범 |
| `dependsOn` 에 있는 팩 ID **참조** | ✅ | 합성의 목적 |
| `dependsOn` 에 없는 팩 ID 참조 | ❌ 하드 실패 (`cross_pack`) | 암묵 결합 차단 |
| 같은 ID 를 두 팩이 정의 | ❌ 하드 실패 (`duplicate_id`) | 병합 순서에 의존하는 동작 금지 |
| 의존 팩의 앵커 좌표를 다른 팩이 이동 | ❌ 하드 실패 | 앵커는 소유 팩만 옮긴다([BP-26 §6](26_entity_registry_and_anchors.md)) |
| 의존 팩의 액터에 새 대화 **추가** | ✅ 단, `dlg` 는 자기 팩 소유, `speaker` 만 남의 npc 를 가리킴 | 이것이 확장의 정상 경로 |

- **R-21-19** "남의 액터에 내 대화를 붙이는" 확장은 앵커가 아니라 **대화 진입 조건**으로 한다.
  `dlg.gen_ep1.guard_about_scholar` 를 만들고, `npc.core.lore_gate_guard` 의 앵커를 건드리는 대신
  대화 라우팅 테이블(BP-24 §대화 라우팅)에 조건부 항목을 추가한다.

---

## 5. 문자열 키 체계

### 5.1 인라인 텍스트 금지 원칙

- **R-21-20** 콘텐츠 소스의 어떤 필드도 **표시될 한국어 문장을 직접 담지 않는다**.
  대사·제목·요약·저널·선택지·아이템 설명은 전부 `str.…` 키를 담고, 실제 텍스트는 `strings/ko.json` 에 있다.

**예외 (인라인 허용)**:

| 필드 | 이유 |
|---|---|
| `pack.json#title`, `#description` | 툴 UI 전용, 게임에 표시되지 않음 |
| 모든 `_note` | 주석 대용, 빌드가 버림 |
| `world/*.json` 의 `_toneHint`, `_summary` 같은 `_` 접두 필드 | 프롬프트 컨텍스트 재료이며 게임에 표시되지 않음 |
| 디버그 전용 `debugLabel` | 릴리스 빌드가 제거 |

- **R-21-21** 위 예외 밖에서 값이 한글 문자(`가-힣`)나 `@` 색상 태그를 포함하면 빌드 하드 실패.
  에러 메시지는 "문자열 키로 옮기세요" + 자동 제안 키를 hint 로 준다.

### 5.2 키 규칙

```
str.<pack>.<owner_type>.<owner_slug>.<slot_path>
```

- `<pack>`, `<owner_type>`, `<owner_slug>` 는 **소유 엔티티 ID 에서 기계적으로 유도**된다.
  소유자 `npc.core.lore_gate_guard` → 키 접두 `str.core.npc.lore_gate_guard.`
- `<slot_path>` 는 그 엔티티 안에서의 **구조 경로**다. 점으로 이어진 1개 이상의 세그먼트이며
  각 세그먼트는 로컬 ID(2~48자 소문자) 또는 인덱스(0~9999)다. 문법 확정 근거는 §4.1.1.
- **R-21-22** 키의 pack 세그먼트는 **키를 담은 파일이 속한 팩**이다. 남의 팩 엔티티에 대한 대사를
  내 팩에서 쓸 때는 소유자 슬러그를 그대로 쓰되 pack 은 내 팩으로 한다:
  `str.gen_ep1.npc.lore_gate_guard.about_scholar` (소유자는 core 의 문지기, 문자열은 gen_ep1 소유).

### 5.3 표준 슬롯

| 소유자 타입 | 슬롯 | 의미 |
|---|---|---|
| `npc` | `name` | 표시 이름 (필수) |
| `npc` | `title` | 직함/호칭 (선택) |
| `npc` | `default_line.<n>` | 기본 대사 n번째 |
| `quest` | `title`, `summary` | 퀘스트 제목·요약 (필수) |
| `quest` | `stage.<stageId>.journal` | 스테이지 저널 |
| `quest` | `objective.<objId>.desc` | 목표 설명 |
| `item` | `name`, `desc` | 아이템 이름·설명 (name 필수) |
| `dlg` | `node.<nodeId>.line.<n>` | 노드 n번째 줄 |
| `dlg` | `node.<nodeId>.header` | 노드 헤더(`UiHost.setHeader`) |
| `dlg` | `choice.<nodeId>.<choiceId>` | 선택지 문구 |
| `place` | `name`, `desc` | 장소 이름·설명 |
| `faction` | `name`, `desc` | 세력 이름·설명 |
| `enc` | `name` | 인카운터 표시 이름(전투 로그용) |
| `ui` | 자유 | UI 문자열([BP-41](41_journal_ui_spec.md) 소유) |

- **R-21-23** 슬롯 경로의 `<n>` 은 0-based 정수이며 연속이어야 한다(구멍 금지). 선행 0 금지(R-21-52).
- **R-21-23a** 표의 `<nodeId>`/`<stageId>`/`<objId>`/`<choiceId>` 는 그대로 **로컬 ID**([BP-23](23_quest_model.md)·[BP-24](24_dialogue_model.md) 소유)이며,
  R-21-54 에 따라 어떤 유효 로컬 ID 도 슬롯 세그먼트가 될 수 있다.
- **R-21-24** 빌드가 슬롯 키를 **자동 생성**한다. 작가 에이전트는 대화 노드에 `lines: ["…"]` 형태의
  임시 인라인을 쓸 수 없고, 처음부터 키를 쓴다. 대신 콘텐츠 서버가 `POST /api/content/strings/mint`
  로 "이 소유자·이 슬롯의 키를 만들어 달라" 를 받아 키를 돌려준다([BP-31](31_content_server_api.md)).

### 5.4 `strings/ko.json` 구조

플랫 맵이다. 중첩 객체를 쓰지 않는다 — 키가 곧 경로이고, 플랫이어야 정렬·diff·누락 검사가 단순하다.

```json
{
  "_meta": {
    "lang": "ko",
    "pack": "gen_ep1",
    "count": 42
  },
  "str.gen_ep1.npc.lore_gate_guard.about_scholar.0": "학자 나리 말이오? 사흘 전에 @B메너스@@ 쪽으로 가셨소.",
  "str.gen_ep1.npc.lore_gate_guard.about_scholar.1": "그 뒤로는 아무도 못 봤소이다.",
  "str.gen_ep1.quest.missing_scholar.title": "사라진 학자",
  "str.gen_ep1.quest.missing_scholar.summary": "로어성의 학자가 메너스로 향한 뒤 소식이 끊겼다.",
  "str.gen_ep1.quest.missing_scholar.stage.find_trail.journal": "성문 앞 위병에게 학자의 행방을 물었다.",
  "str.gen_ep1.dlg.wife_plea.node.intro.header": "@B학자의 아내",
  "str.gen_ep1.dlg.wife_plea.node.intro.line.0": "제 남편이 돌아오지 않습니다.",
  "str.gen_ep1.dlg.wife_plea.choice.intro.accept": "찾아보겠소.",
  "str.gen_ep1.dlg.wife_plea.choice.intro.decline": "내 알 바 아니오."
}
```

- `_meta` 는 유일하게 허용되는 비-키 항목이며 `_` 로 시작한다.
- **R-21-25** 값이 비어 있는 키(`""`)는 하드 실패. 의도적 공백은 `" "` 가 아니라 키를 삭제한다.
- **R-21-26** 참조되지 않는 키(고아 문자열)는 린트 경고. 참조되는데 없는 키(누락 문자열)는 **하드 실패**(D-15).

### 5.5 색상 태그와 길이 제약

**색상 태그**는 원작 표기를 그대로 계승한다. `@B` 로 켜고 `@@` 로 끈다.
실측 사용례: `assets/lore_ep1.cm2` 의 `'@B또다른 지식의 성전@@'`, `assets/menace.cm2` 의 `@7…@@`,
`REF_UNITY_LoreEp1/src_as_cs/NpcWeaponShop.cs:47` 의 `@F…@@`.
문자열은 `lib/domain/console/console_log.dart` 가 원문 그대로 보관하고
`HDTextUtils.parseRichText` 가 렌더 시 해석한다.

**태그 집합은 파서 실측으로 확정한다** (REVIEW_BP-21 `F-08`). `hadar2026_app/lib/utils/hd_text_utils.dart:4-22`
의 `colorTable` 은 **17개 키**(`'0'`~`'9'`, `'A'`~`'F'`, **그리고 `'G'`(Amber)**)를 갖고,
파서는 `next.toUpperCase()` 로 조회하므로 **소문자 태그도 유효**하다. 초판이 쓴 `0-9A-F`(16개, 대문자만)는
실제 파서보다 좁아 **유효한 콘텐츠를 하드 실패시키는** 규칙이었다.

| 규칙 | 내용 | 심각도 | 근거 |
|---|---|---|---|
| 문법 (`CV-03`) | `@` + 태그 1글자 `[0-9A-Ga-g]` 로 시작, `@@` 로 종료 | 하드 실패 | `hd_text_utils.dart:4-22`, `:56` |
| 미종료 태그 | 열린 태그를 닫지 않아도 **파서가 문자열 끝에서 자동 종료**한다(`currentColor` 는 `parseRichText` 지역 변수이고 마지막 `flushBuffer()` 로 끝난다 — `hd_text_utils.dart:28,68`). 색이 다음 문자열로 새지 않는다 | **린트 경고**(하드 실패 아님) | `F-08`·`W-05` |
| 중첩 | 금지. `@B…@C…@@` 는 첫 `@@` 에서 전부 해제되므로 의도와 다르게 렌더된다 | 린트 경고 | 파서 동작 |
| 리터럴 `@` | `@` 다음 문자가 `[0-9A-Ga-g@]` 가 **아니면 리터럴로 렌더된다**(`hd_text_utils.dart:60-64`). 즉 `@가` 는 정상이다. 금지 대상이 아니다 | 정보 | `F-09` |
| 강조 남용 | 한 문자열에 색 구간 3개 초과 | 린트 경고 | — |

- **R-21-58** (`W-05` 해소) 현행 코드의 SIGN 기본 헤더 `'@B푯말에 써 있기를:'`
  (`hadar2026_app/lib/application/tile_event_dispatcher.dart:117`)은 `@B` 를 닫지 않는다.
  초판 규칙(균형 = 하드 실패)대로면 **원작·현행 관행이 통째로 위반**이 된다.
  파서가 문자열 끝에서 색을 자동 해제한다는 실측에 근거해, **미종료는 경고로 강등**하고
  이 관행을 합법으로 둔다. 다만 생성물은 명시적으로 닫는 것을 권장한다(경고가 그 권장의 표현이다).

**길이 제약 — 소유는 [BP-24 §24.5](24_dialogue_model.md)** (D-18 · `I-10`).

초판은 여기서 "496px ÷ 16px ≈ 31자" 를 직접 산출했으나, 텍스트 길이 수치의 소유 장은 BP-24 이고
BP-24 는 480px 기준으로 다른 값을 정했다. **D-18 에 따라 이 장은 자기 산출을 버리고 소유 장을 링크한다.**

| 항목 | 소유 |
|---|---|
| 줄당 권장/경고/에러 글자수, 폭 산정 기준 | [BP-24 §24.5](24_dialogue_model.md) |
| 페이지당 줄 수(`HDConfig.maxLinesPerPage = 13`) | 코드 상수. BP-24 가 페이지 계산에 사용 |
| 노드 페이지 수 경고(`contentBudget.warnNodePages`) | 이 장(§3.4) — 팩 단위 예산이므로 |
| 문자열 1개 하드 상한 **1000자** | **이 장**(`CV-04`). 키-값 저장소의 물리 제약이므로 팩 포맷 소관 |

- **R-21-59** (`CV-04`) `strings/*.json` 의 한 값은 **1000자를 넘을 수 없다**(하드 실패).
  이것은 "읽기 좋은 길이" 가 아니라 **포맷 상한**이며, 읽기 좋은 길이는 BP-24 가 정한다.
- 참고: 원작 대사는 BP-24 의 권장 길이를 크게 넘는다. `assets/lore_ep1.cm2` 의 감옥 죄수 대사는
  한 `Talk()` 가 **400자**를 넘고 그런 문자열이 여럿이다. 이 장의 하드 상한 1000자는
  **원작 이식을 막지 않도록** 잡은 값이다(D-17).

---

## 6. Condition / Effect DSL — 완전 명세 (**이 절이 SSoT**)

### 6.1 공통 규약

| 항목 | 규약 |
|---|---|
| 표현 | Condition = **단일 JSON 객체**, `op` 필드로 분기. Effect = **JSON 객체 배열**, `do` 필드로 분기 |
| 순수성 | Condition 은 **부작용이 없다**. WorldState 를 읽기만 한다 |
| 결정성 | **18 op 전량이 같은 `WorldState` 에서 항상 같은 값**을 낸다. `chance` 도 예외가 아니다 — 시드 유도에 쓰는 `step` 이 `WorldState` 의 필드이므로(D-30 · §6.5), 같은 상태를 몇 번 평가해도 값이 흔들리지 않는다. 상태가 진행해(`step` 증가) 값이 바뀌는 것은 비결정이 아니라 **입력이 달라진 것**이다 |
| ~~결정성(초판)~~ | ~~"`chance` 를 제외한 모든 op 는 같은 WorldState 에서 항상 같은 값"~~ — **폐기(D-30)**. `chance` 를 예외로 적은 것은 유도식에 `step` 이 없던 초판 §6.5 를 전제한 서술이었다. `step` 이 시드에 들어오면 `chance` 는 "WorldState 의 함수" 가 되므로 예외가 아니다 |
| 닫힌 집합 | 아래 표에 없는 `op`/`do` 는 **빌드 하드 실패**. 런타임은 그런 값을 만나면 안 되지만, 만나면 `StateError` 로 즉시 실패한다(cm2 의 "Unknown function → 0 반환" 침묵 실패와 정반대로 설계, GROUND_TRUTH §9) |
| 확장 | `schemaVersion` 을 올려야만 가능(§7). **실제로 한 번 올렸다** — D-31 의 do 22 → 25, 실행 기록은 §7.2.1 |
| 미지정 필드 | `additionalProperties: false`. 오타 필드는 하드 실패 |
| 구현 위치 | `lib/domain/content/condition.dart`, `effect.dart` — 런타임·CLI·린트가 같은 코드를 공유(D-12) |
| 타입 오류 | **[BP-90](90_appendix_schemas.md) 의 스키마 전문**이 op/do 별 필수 인자와 타입을 전부 강제한다. §6.8 은 **발췌**이므로 그 강제를 전량 담지 않는다(`F-04`) — 발췌만 보고 "타입 안전" 을 결론짓지 말 것 |
| 런타임 타입 실패 | 번들은 빌드를 통과한 것만 담기므로 정상 경로에서는 발생하지 않는다. 그럼에도 발생하면 **버그**이며 디버그 빌드는 크래시, 릴리스는 해당 Effect 배열을 롤백(R-21-31)하고 로그 |
| **미정의 입력** | op/do 이름이 미지이면 `StateError`. **인자 값이 가리키는 대상이 없을 때의 동작은 §6.3·§6.6 표의 "런타임 미정의 입력" 열에 43개 전량 명시**한다(`F-11`) |

### 6.2 평가 순서·중첩·단축 평가

- **R-21-27 (단축 평가)** `and` 는 첫 `false` 에서 멈추고, `or` 는 첫 `true` 에서 멈춘다.
  Condition 은 부작용이 없으므로 단축 평가가 **관찰 가능한 차이를 만들지 않는다. 예외는 없다.**
  - 초판은 "`chance` 는 시드 난수를 소비하므로 예외" 라고 적었으나, 이는 §6.5 의 무커서 해시 유도식과
    양립하지 않는 서술이었다(REVIEW_BP-21 `F-03`). **D-21 이 "`chance` 는 커서를 밀지 않는다" 를
    확정**했으므로 이 예외 문언은 **폐기**한다. `chance` 는 평가 횟수·평가 순서와 무관하게 같은 값을 낸다.
  - 커서를 쓰는 난수(`WorldRng`)는 **Effect 와 전투 등 쓰기 경로 전용**이며 소유는
    [BP-27](27_runtime_engine.md) 이다(D-18·D-21). Condition 은 커서를 절대 건드리지 않는다.
- **R-21-28 (중첩 깊이)** `and`/`or`/`not` 중첩 깊이 최대 **8**. 초과 시 하드 실패.
  이유: 생성 에이전트가 만드는 조건식이 사람이 검수 불가능해지는 지점이 대략 여기다.
- **R-21-29 (args 개수)** `and`/`or` 의 `args` 는 1~16개. 0개는 하드 실패(의도가 불명확).
- **R-21-30 (Effect 순서)** Effect 배열은 **선언 순서대로 전부 적용**된다. 조건 분기는 없다.
  분기가 필요하면 대화 노드나 스테이지를 나눈다(BP-24 §노드 분기).
- **R-21-31 (Effect 원자성)** 하나의 Effect 배열은 **전부 적용되거나 전혀 적용되지 않는다**.
  런타임은 배열 적용 전 WorldState 스냅샷을 뜨고, 중간 실패 시 되돌린다. 실패는 버그이므로
  디버그 빌드에서는 크래시하고 릴리스에서는 롤백 후 로그를 남긴다.
- **R-21-32 (Effect 중복)** 같은 배열 안에서 같은 `do`+`id` 조합이 두 번 나오면 린트 경고
  (`add_var`/`add_gold` 등 누적형은 예외).

### 6.3 Condition op 전량 (18개)

| # | op | 인자 | 타입 | 의미 | 검증 규칙(빌드) | 빌드 실패 시 | **런타임 미정의 입력** |
|---|---|---|---|---|---|---|---|
| C1 | `true` | — | — | 항상 참 | — | — | 없음 |
| C2 | `false` | — | — | 항상 거짓 | 린트 경고(죽은 분기) | — | 없음 |
| C3 | `and` | `args` | Condition[] | 전부 참 | 1~16개, 깊이 ≤8 | 하드 실패 | 없음 |
| C4 | `or` | `args` | Condition[] | 하나라도 참 | 1~16개, 깊이 ≤8 | 하드 실패 | 없음 |
| C5 | `not` | `arg` | Condition | 부정 | 필수 | 하드 실패 | 없음 |
| C6 | `flag` | `id` | flag key | 플래그가 켜져 있는가 | ID 문법·팩 가시성 | 하드 실패 | 없는 플래그 → **`false`** |
| C7 | `var_cmp` | `id`,`cmp`,`value` | var key, enum, int | 변수 비교 | `cmp ∈ {==,!=,<,<=,>,>=}`, `value` 는 int32 | 하드 실패 | 없는 변수 → **`0`** 으로 비교 |
| C8 | `has_item` | `id`,`count?` | item id, int≥1 | 인벤토리에 count 개 이상 | 아이템 존재, `count` 기본 1 | 하드 실패 | 미보유 → 소지 **0** 으로 비교(즉 `false`) |
| C9 | `quest_state` | `id`,`state` | quest id, enum | 퀘스트 상태 일치 | `state ∈ {inactive,active,completed,failed}` | 하드 실패 | `WorldState.quests` 에 항목이 없으면 → **`inactive`** |
| C10 | `quest_stage` | `id`,`stage` | quest id, stage id | 현재 스테이지 일치 | 스테이지가 그 퀘스트에 존재 | 하드 실패 | 퀘스트가 `active` 가 **아니면 항상 `false`**(`inactive`·`completed`·`failed` 모두). 스테이지 비교는 `active` 일 때만 의미를 갖는다 |
| C11 | `party_has_class` | `classId` | int 0..2 | 해당 클래스 생존 멤버 존재 | 0=에스퍼,1=싸이보그,2=초능력자 (`HDPlayer.getClassName`) | 하드 실패 | 해당 멤버 없음 → `false` |
| C12 | `party_level_cmp` | `cmp`,`value` | enum, int | 파티 **최고** 물리 레벨 비교 | **`value` 1..20** (§6.3 상세 참조) | 하드 실패 | 유효 멤버 0명 → 최댓값 **0** 으로 비교 |
| C13 | `gold_cmp` | `cmp`,`value` | enum, int≥0 | 소지금 비교 (`HDParty.gold`) | — | 하드 실패 | 없음 |
| C14 | `map_is` | `mapName` | string | 현재 맵 이름 일치 | `MapInfos.json#name` 에 존재하고 **실제 파일로 해석**([BP-22 §4.7](22_world_bible_model.md), R-21-7) | 하드 실패 | 현재 맵 이름이 미확정(`generated` 맵 등)이면 → `false` |
| C15 | `visited` | `placeId` | place id | 그 장소를 방문한 적 있는가 | place 존재 | 하드 실패 | `WorldState.visited` 에 없음 → `false` |
| C16 | `npc_state` | `id`,`state` | npc id, string | NPC 상태 일치 | `state` 가 그 액터의 `states[]` 에 선언되어 있어야 함([BP-22 §5.6](22_world_bible_model.md)) | 하드 실패 | `WorldState.npcStates` 에 항목이 없으면 → 액터의 **`initialState`** 와 비교 |
| C17 | `time_of_day` | `value` | enum | 시간대 일치 | `value ∈ {day,night}` | 하드 실패 | 시간대 미구현 → **항상 `day`**. `night` 비교는 항상 `false` + 린트 경고 |
| C18 | `chance` | `percent` | int 1..99 | 시드 해시 판정(§6.5) | 0/100 금지(`true`/`false` 를 쓰라는 hint) | 하드 실패 | 없음(순수 함수) |

**상세**

- **C6 `flag`** — `{"op":"flag","id":"flag.core.world.necromancer_awakened"}`.
  세계에 존재하지 않는 플래그를 읽으면 `false`. 플래그는 선언 없이 사용처가 곧 선언이므로,
  "쓰기는 있는데 읽기가 없는" / "읽기는 있는데 쓰기가 없는" 플래그를 린트가 경고한다(BP-33).
- **C7 `var_cmp`** — 없는 변수는 `0`. `{"op":"var_cmp","id":"var.core.party.reputation_lore","cmp":">=","value":10}`.
- **C8 `has_item`** — `count` 는 1 이상. 스택 불가 아이템(`stackable:false`)에 `count > 1` 이면 하드 실패.
- **C11 `party_has_class`** — 의식 불명·사망 멤버는 세지 않는다(`HDPlayer.isAvailable()`).
- **C12 `party_level_cmp`** — 파티 **최댓값** 기준. 평균이 아니다(빈 슬롯이 평균을 왜곡하므로).
  `HDPlayer.level.physical` 을 본다. 마법/ESP 레벨 비교는 v1 에 없다.
  - **값 범위 정정** (REVIEW_BP-21 `F-07`): 초판은 `1..21` 로 적었으나 **도달 가능한 최대 레벨은 20** 이다.
    `hadar2026_app/lib/domain/party/player.dart:167` 의 `expTable` 은 엔트리 **21개(index 0~20)** 이고
    승급 루프가 `while (level.physical < expTable.length - 1 && …)` 이므로 상한이 `20` 이다.
    `value: 21` 은 **영원히 참이 될 수 없는 조건**이라 빌드 하드 실패로 잡는다.
- **C14 `map_is`** — 장소가 아니라 **맵 이름**이다. 장소 판정은 `visited` 또는 앵커 트리거를 쓴다.
  맵과 장소는 1:N 이므로([BP-22 §4](22_world_bible_model.md)) 둘을 섞지 말 것.
  - **검증 강화** (REVIEW_BP-21 `F-05` / GROUND_TRUTH 부록 D): "이름이 `MapInfos.json` 에 있는가" 만
    확인하면 **정확히 로드 불가능한 7개 맵을 유효하다고 통과시킨다.** 등록되어 있다는 사실 자체가
    로드를 깨뜨리기 때문이다(R-21-7). 검증은 반드시 **파일 해석까지** 확인해야 하며,
    표현의 정본은 [BP-22 R-22-11](22_world_bible_model.md) 이다. 선행 의존은 [BP-22 T-22-1](22_world_bible_model.md).
- **C17 `time_of_day`** — 게임에 시간대가 아직 없다(D-16 선택 항목). v1 런타임은 항상 `day` 를
  돌려주며, 린트가 "시간대 미구현" 경고를 낸다. 스키마에는 지금 넣어 둔다 — 나중에 op 를 추가하면
  `schemaVersion` 을 올려야 하기 때문.

### 6.4 Condition 예시

```json
{"op":"and","args":[
  {"op":"quest_state","id":"quest.gen_ep1.missing_scholar","state":"active"},
  {"op":"quest_stage","id":"quest.gen_ep1.missing_scholar","stage":"find_trail"},
  {"op":"not","arg":{"op":"has_item","id":"item.gen_ep1.scholar_notebook"}},
  {"op":"or","args":[
    {"op":"var_cmp","id":"var.core.party.reputation_lore","cmp":">=","value":10},
    {"op":"gold_cmp","cmp":">=","value":300}
  ]}
]}
```

### 6.5 `chance` 의 시드 규약 (D-21 · **D-29a 명명** · **D-30 유도식 확정**)

**`chanceKey` 의 명칭·형식은 이 절이 소유한다.** 다만 초판·2판의 서술을 두 번 정정한다.

| 판 | 서술 | 상태 |
|---|---|---|
| 초판 | `key = "<contextId>#<evalPath>"`, 유도식에 `step` 없음 | 폐기 |
| 2판(D-21a·D-29 반영) | "`siteId` 라는 이름은 **폐기**한다 — 이후 어느 문서도 그 이름을 쓰지 않는다" | **과잉이었다 → 정정(D-29a)** |
| **3판(현행, D-29a·D-30)** | 문자열 키 = **`chanceKey`**(이 장 소유), 그것을 해시해 번들에 굽는 정수 = **`chanceSeedId`**([BP-27](27_runtime_engine.md) 소유). 유도식에 **`step` 포함**(D-30) | **정본** |

- **2판 서술이 왜 과잉이었나**: `siteId` 는 두 개체를 가리키는 데 혼용된 이름이었고
  (문자열 키 ↔ 번들에 굽는 정수), 2판은 그것을 "같은 것의 두 이름" 으로 보아 **이름 자체를 통째로 폐기**했다.
  그 결과 **빌드 상수에 이름이 없어졌고**, BP-27 은 부를 이름이 없어 `siteId` 를 계속 쓸 수밖에 없었다 —
  결정 위반이 아니라 **결정의 공백**이었다. D-29a 가 두 개체에 각자 이름을 주어 이 공백을 닫았다.
- **`siteId` 는 여전히 폐기**다. 두 개체를 구별하지 못하는 이름이기 때문이다. 지금은 각자 이름이 있다.
- **소유 경계**: `chanceKey`(문자열 키의 이름·형식·경로 문법) = **이 장**.
  `chanceSeedId`(정수의 형식·런타임 소비 방법) = [BP-27 §9.2](27_runtime_engine.md).
  `chanceSeedId` **생성 절차**(빌드가 어느 단계에서 무엇을 순회해 굽는가) = [BP-35 §1.4.1](35_ci_and_build.md).

- **R-21-33** 난수는 **결정론적**이다(D-01: 비결정 난수 금지).
- **R-21-33a** `chance` 는 **커서를 밀지 않는다**(D-21). Condition 의 순수성이 이것으로 보전되고,
  `WorldStateView`/`WorldStateMutator` 분리와 QuestSolver 가 성립한다.
  커서를 쓰는 난수(`WorldRng`·`rngCursor`)는 **Effect·전투 등 쓰기 경로 전용**이며 소유는
  [BP-27](27_runtime_engine.md) 이다(D-18).
- **유도식 (정본 — D-30)**:

```
// [Authoring] 저작 시점의 위치 식별자. 이 장이 소유한다.
chanceKey    = "<contextId>#<evalPath>"
             // 예: "dlg.gen_ep1.guard_intro#entry[2].args[1]"
             //     "quest.gen_ep1.missing_scholar#stages[1].objectives[0].when.args[0]"
             //     "dlg.gen_ep1.guard_intro#nodes.intro.onEnter[0]"

// [Build] 해시는 빌드가 한 번만 한다. BP-35 §1.4.1 이 생성 절차를 소유한다.
chanceSeedId = mix([hashString(chanceKey)])            // 번들에 굽는 정수

// [Runtime] 런타임은 정수만 섞는다. BP-27 §9.2 가 mix 와 소비 방법을 소유한다.
value        = mix([seed, step, chanceSeedId]) % 100   // 0..99
result       = value < percent
```

**`step` 이 시드에 들어간다** — D-30 이 확정했다. 근거는 §6.5.1.

| 입력 | 출처 | 소유 |
|---|---|---|
| `seed` | `WorldState.seed` (세이브에 저장) | [BP-25](25_world_state_and_save.md) |
| `step` | 월드 논리 시각(월드 이벤트 카운터). **`rngCursor` 가 아니다** | [BP-25](25_world_state_and_save.md) 필드 · [BP-27](27_runtime_engine.md) 증가 시점 |
| `chanceKey` | 이 절의 `<contextId>#<evalPath>` | **이 장** |
| `chanceSeedId` | `chanceKey` 를 해시한 정수. 번들의 `Condition.chanceSeedId` | [BP-27 §9.2](27_runtime_engine.md) |
| `mix` / `hashString` 구현 | 해시 함수 **정본 이름은 `mix`** | [BP-27 §9.2](27_runtime_engine.md) |
| 빌드 시 `chanceSeedId` 부여 | 번들에 구워 넣는 **생성 절차** | [BP-35 §1.4.1](35_ci_and_build.md) |

- **해시 함수 이름의 정본은 `mix`** 다([BP-27 §9.2](27_runtime_engine.md)). 초판·2판이 쓴
  `splitmix64` / `fnv1a64` 표기는 **폐기**한다 — 세 장이 세 이름을 쓰던 상태를 D-30 이 `mix` 로 통일했다.
  `mix` 는 내부적으로 splitmix64 계열을 쓰지만, **웹 정수 제약(Dart 웹의 `int` 는 IEEE-754 double →
  32비트 상·하위 2워드 구현이 강제된다) 때문에 구현이 고정**된다. 그 제약과 구현은
  [BP-27 §9.2](27_runtime_engine.md) 가 소유하므로 이 장은 링크만 한다(D-18).
- **이 장이 정의하지 않는 것**: `mix` 의 내부 상수·라운드 수, `chanceSeedId` 의 비트 폭,
  웹/VM 동치 검증 벡터. 전부 [BP-27 §9.2](27_runtime_engine.md) 소관이다.

- **R-21-34a (`evalPath` 정규화 — 결정론 전제)** [BP-35](35_ci_and_build.md) 가 요청한 항목이다.
  `chanceSeedId` 가 결정론적이려면 **같은 노드가 항상 같은 `chanceKey` 문자열**로 표기되어야 한다.
  표기가 흔들리면 재빌드마다 해시가 달라져 `V-DET-001`(재빌드 결정론)이 깨진다.

  | # | 정규화 규칙 | 예 |
  |---|---|---|
  | 1 | 구분자는 **`.`** 하나. 앞뒤 공백 없음. 빈 세그먼트 금지 | `stages.objectives` |
  | 2 | 배열 인덱스는 **`[n]`**, 0-기반, **10진, 선행 0 금지**. `.0` 형태로 쓰지 않는다 | `args[0]` ✅ / `args.0` ❌ / `args[00]` ❌ |
  | 3 | 맵(객체) 키는 **`.<key>`** 로 잇는다. 인덱스 표기를 쓰지 않는다 | `nodes.n_intro` ✅ / `nodes["n_intro"]` ❌ |
  | 4 | 세그먼트 이름은 **소유 장 스키마의 필드명 그대로**. 축약·별칭 금지 | `objectives` ✅ / `objs` ❌ |
  | 5 | 단항 축약·`and`/`or` 평탄화 등 **정규화 변환을 거친 뒤의 경로가 아니라, 정규화 *전* 소스 구조의 경로**를 쓴다 | [BP-35 R-35-6](35_ci_and_build.md) 이 `chance` 서브트리 평탄화를 금지하는 이유가 이것이다 |
  | 6 | `contextId` 는 **최상위 엔티티 ID 문자열 그대로**(§4.2 문법). 팩 접두 생략 금지 | `dlg.gen_ep1.guard_intro` |
  | 7 | 인코딩은 **UTF-8, 정규화 형태 NFC**. 해시 입력은 이 바이트열이다 | — |

  - 규칙 5 가 가장 중요하다. 정규화 후 경로를 쓰면 **"정규화가 의미를 바꾸지 않는다"(R-35-5)가
    `chance` 에 대해 거짓**이 된다 — 조건식 모양만 다듬어도 분기 결과가 뒤집힌다.
  - 세그먼트 이름 어긋남 주의: [BP-27](27_runtime_engine.md) 초판의 `<ownerId>#<path>` 표기는
    이 장의 `<contextId>#<evalPath>` 와 **세그먼트 이름이 달랐다**. 정본은 이 장의 것이다(D-18 · D-29a 부수 정정).

- `contextId` 는 평가를 요청한 **최상위 엔티티 ID**, `evalPath` 는 그 안에서 이 `chance` 노드까지의
  **구조 경로**다. 경로는 실제 스키마 구조를 그대로 따른다 — 초판 예시
  `"…#node.intro.entry[2].args[1]"` 는 `entry` 가 Dialogue **최상위 필드**(D-07)인데 노드 하위에 둔
  잘못된 형태였다(REVIEW_BP-21 `F-13`). 위 예시가 정정본이다.
- **결과 성질**: 같은 `(seed, step, chanceSeedId)` 는 **항상 같은 값**이다. 따라서
  (a) 같은 스텝 안에서 몇 번을 평가하든 값이 흔들리지 않고,
  (b) 스텝이 진행되면 값이 바뀌므로 "영원히 같은 분기" 로 굳지 않는다.

- **R-21-34 (개정 2판 — D-30 확정)** **같은 세이브·같은 위치·같은 스텝은 항상 같은 결과다.**
  스텝을 넘겨 다시 평가하면 값이 달라질 수 있다.
  **재시도 횟수에 의존하는 분기**가 필요하면 `chance` 가 아니라 카운터를 쓴다(`add_var` + `var_cmp`).
  **결과를 영구히 고정**하고 싶으면 Effect 의 `set_flag` 로 래치한다(§6.5.2).

  **R-21-34 개정 이력** (삭제하지 않고 남긴다 — 이 기획서의 방식이다)

  | 판 | 명제 | 유도식 전제 | 상태 |
  |---|---|---|---|
  | 초판 | "같은 세이브·**같은 위치**는 항상 같은 결과" | `splitmix64(seed ^ fnv1a64(chanceKey))` — `step` 없음 | **폐기** |
  | 개정 1판 | "같은 스텝 안의 재평가는 항상 같은 값" (조건절만 붙였고 **명제 본문을 고치지 않았다**) | `splitmix64(seed, step, fnv1a64(key))` | **불충분** |
  | **개정 2판(현행)** | "같은 세이브·같은 위치·**같은 스텝**은 항상 같은 결과" | `mix([seed, step, chanceSeedId])` | **정본(D-30)** |

  - **초판을 폐기하는 이유**: `step` 이 없으면 `chance` 는 확률이 아니라 **그 세이브에 고정된 상수**가 된다.
    30% 대사는 한 세이브에서 **영원히 나오거나 영원히 안 나온다** — 작성자가 기대하는 동작이 아니다.
    BP-90 `I-06` 이 이 차이를 "표기 차이가 아니라 게임 동작이 갈린다" 로 적발했고 D-30 이 판정했다.
  - **개정 1판이 불충분했던 이유**: 조건절("같은 스텝 안에서는")은 맞았지만 **초판 명제 본문이
    문서에 그대로 남아** 두 문장이 병존했다. `step` 은 명제의 **주어에 들어가야** 한다.
  - **세이브 스커밍 차단 범위**: 리로드해도 `step` 이 같으면 결과가 같으므로 **같은 스텝 안에서는 차단**된다.
    스텝을 진행시키는 재굴림은 막지 않는다 — 그것은 §6.5.2 의 래치로 다룬다.

#### 6.5.1 왜 `step` 을 포함하는가 (D-30 근거)

| # | 근거 |
|---|---|
| 1 | **`step` 이 없으면 확률이 아니다.** 세이브마다 고정된 상수가 되어, 같은 세이브에서 그 `chance` 는 영원히 한쪽으로만 간다 |
| 2 | **순수성은 유지된다.** D-05/D-21 이 요구하는 것은 "조건 평가가 상태를 바꾸지 않는다" 이고, `step` 은 `WorldStateView` 로 **읽는** 값이다. 커서를 밀지 않으므로 `WorldStateView`/`WorldStateMutator` 분리는 그대로 성립한다 |
| 3 | **평가 횟수 불변성이 필요한 범위에서 유지된다.** 목표 판정은 **배치 단위**([BP-23](23_quest_model.md))이므로 한 배치 = 한 스텝 안에서 같은 값이 나오면 충분하다. "영원히 같은 값" 은 요구사항이 아니었다 |
| 4 | **솔버는 어느 쪽이든 양 분기를 탐색**한다(D-13 · R-21-35). `chanceSeedId` 가 분기 지점을 식별하므로 `step` 유무가 솔버 설계를 바꾸지 않는다 |

#### 6.5.2 재굴림(reroll)과 래치 — `chance` 만으로 영구 결과를 만들지 않는다

`step` 이 시드에 들어가므로 플레이어는 **나갔다 다시 들어와** 같은 `chance` 를 다시 굴릴 수 있다.
이것은 유도식의 결함이 아니라 **`chance` 의 성질**이며, 영구 결과가 필요하면 다음처럼 래치한다.

```json
// ✅ 래치 있음 — 첫 판정 결과를 플래그로 굳힌다
{ "when":  {"op":"and","args":[
             {"op":"not","arg":{"op":"flag","id":"flag.gen_ep1.crypt.omen_rolled"}},
             {"op":"chance","percent":30}]},
  "effects": [ {"do":"set_flag","id":"flag.gen_ep1.crypt.omen_rolled"},
               {"do":"set_flag","id":"flag.gen_ep1.crypt.omen_seen"} ] }
```

- **래치는 정의상 Effect 의 일이다.** 상태를 바꾸는 행위이므로 Condition 이 할 수 없다(D-05 순수성).
  `chance` 를 "한 번만 굴리게" 만드는 op 를 추가하는 안은 **채택하지 않는다** — 그것은 부작용 있는
  Condition 이고 D-21 이 기각한 설계다.
- **Condition 만으로 영구 결과를 만들려는 설계는 하지 않는다**(D-30).
- 이 패턴의 누락은 [BP-33 §4.6](33_validation_and_lint.md) 의 **`V-DET-013`(WARN)** 이 잡는다(D-30 이 BP-33 에 지정).
  검사 대상은 "`chance` 로 분기하는데 그 분기 경로에 래치용 `set_flag` 가 없는 곳" 이며,
  판정 범위·메시지·자동 수정 가능성은 **BP-33 소유**다(D-18). 이 장은 패턴만 보인다.

- **세 안의 트레이드오프** (REVIEW_BP-21 `F-03` 이 요구한 비교표):

| 안 | 재현 기준 | 세이브 스커밍 | Condition 순수성 | 확률로서 기능하는가 | 콘텐츠 수정 시 기존 세이브 | 채택 |
|---|---|---|---|---|---|---|
| (a) 경로 해시만 (`seed`+`chanceSeedId`) | 위치별 고정 | 차단 | 유지 | **아니다** — 세이브마다 고정 상수 | 분기 결과 변동(Q-21-3) | **기각(D-30)** |
| (b) `seed`+`rngCursor` | 소비 순서 | **가능** | **깨짐**(커서 전진 = 부작용) | 예 | 영향 없음 | 기각(D-21) |
| **(c) `seed`+`step`+`chanceSeedId`** | 논리 시각 + 위치 | 같은 스텝 안에서 차단 | **유지** | **예** | 분기 결과 변동(Q-21-3 유효) | **확정(D-30)** |

> (a) 는 초판이 채택했던 안이다. **D-30 이 기각**했다 — 순수성·스커밍 차단은 (c) 도 같은 수준으로
> 만족하는데 (a) 만 "확률로서 기능하지 않는다" 는 결정적 손실을 갖는다. `step` 을 넣어 잃는 것은
> "영원히 같은 분기" 뿐이고, 그것은 요구사항이 아니라 §6.5.2 의 래치로 표현할 것이었다.
- **R-21-35 (검증기 규약)** 정적 검증기와 솔버(D-13)는 `chance` 를 **비결정 분기**로 보고
  **양쪽 분기를 모두 탐색**한다. 즉 `chance` 뒤에 있는 어떤 경로도 "확률이 낮아서 검증 생략" 되지 않는다.
- **R-21-36** (`CV-05`) 퀘스트 **완주 가능성에 필수인 경로**를 `chance` 뒤에 두면 하드 실패
  (솔버가 "실패 분기에서 완주 불가" 를 증명하면 그 자체가 게이트 위반). 즉 `chance` 는
  **선택적 보상·연출**에만 쓴다.
- **R-21-36a** 솔버 판정은 D-26 에 따라 **2축**(모델 증명 × 실행 가능)이다. `chance` 양 분기 탐색은
  "모델 증명" 축에만 관여하며, "실행 가능" 축(이벤트 발행 지점 존재 여부)은
  [BP-34](34_headless_sim_and_solver.md) 소관이다.
- **Q-21-3 은 유효하다** (D-21a 가 명시 승인): 구조 경로를 키로 쓰면 **대화를 고칠 때 기존 세이브의
  분기 결과가 바뀐다.** v1 은 구조 경로로 가되, 선택 필드 `seedKey`(작성자가 고정하는 안정 키)를
  탈출구로 남긴다. 선택 인자 추가는 `schemaVersion` 승격이 필요 없다(§7.2).

### 6.6 Effect do 전량 (25개)

> **v1 은 22개였다. D-31 이 25개로 확장하고 `schemaVersion` 을 1 → 2 로 올렸다** (BP-90 `I-20` 해소).
> 확장 사유는 §6.6.2, 승격 절차의 실행 기록은 **§7.2.1** 에 있다.
> `E23`~`E25` 세 행이 추가분이며 `E1`~`E22` 는 **한 글자도 바뀌지 않았다** — 순수 확대이므로 기존 데이터는 그대로 유효하다.

| # | do | 인자 | 타입 | 의미 | 부작용 대상 | 검증 규칙(빌드) | **런타임 미정의/경계 입력** |
|---|---|---|---|---|---|---|---|
| E1 | `set_flag` | `id` | flag key | 플래그 on | `WorldState.flags` | ID 문법·가시성 | 이미 on → 무동작(무경고) |
| E2 | `clear_flag` | `id` | flag key | 플래그 off | `WorldState.flags` | 동일 | 없던 플래그 → 무동작(무경고) |
| E3 | `set_var` | `id`,`value` | var key, int | 변수 대입 | `WorldState.vars` | int32 범위 | 없음 |
| E4 | `add_var` | `id`,`delta` | var key, int | 변수 가산 | `WorldState.vars` | `delta != 0` 권장(0 이면 경고) | 없는 변수 → **0 에서 가산**. int32 범위를 벗어나면 **클램프**(랩어라운드 금지) + 경고 로그 |
| E5 | `give_item` | `id`,`count?` | item id, int≥1 | 아이템 지급 | `WorldState.inventory` | 아이템 존재. 비스택 아이템 중복 지급 시 경고 | `maxStack`([BP-22 §6.1](22_world_bible_model.md)) 초과분은 **버린다** + 경고 로그. 비스택 아이템 재지급은 수량 1 유지 |
| E6 | `take_item` | `id`,`count?` | item id, int≥1 | 아이템 회수 | `WorldState.inventory` | 보유량 부족 시 **0 으로 클램프**하고 경고 로그 | 미보유 → 무동작 + 경고 로그 |
| E7 | `add_gold` | `delta` | int | 소지금 증감 | `HDParty.gold` | 결과가 음수면 0 클램프 | 음수 결과 → 0 클램프 |
| E8 | `add_food` | `delta` | int | 식량 증감 | `HDParty.food` | 0 클램프 | 동일 |
| E9 | `start_quest` | `id` | quest id | 퀘스트 시작 → `active`, stage[0] | `WorldState.quests` | 스테이지 1개 이상 | 이미 `active`/`completed`/`failed` → **무시 + 경고 로그** |
| E10 | `advance_quest` | `id`,`stage` | quest id, stage id | 지정 스테이지로 전이 | `WorldState.quests` | 그 퀘스트의 스테이지여야. 역행 전이는 하드 실패(D-06) | 퀘스트가 `active` 가 아니면 → **무시 + 경고 로그**. 이미 그 스테이지면 무동작 |
| E11 | `complete_quest` | `id` | quest id | 완료 → `completed` + `onComplete`+`rewards` 실행 | `WorldState.quests` | 중첩 배열도 §6.7 폐포 검사 대상 | `active` 가 아니면 → 무시 + 경고 로그 |
| E12 | `fail_quest` | `id` | quest id | 실패 → `failed` + `onFail` 실행 | `WorldState.quests` | 그 퀘스트에 `failConditions`/`onFail` 이 있어야 함 | `active` 가 아니면 → 무시 + 경고 로그 |
| E13 | `set_npc_state` | `id`,`state` | npc id, string | NPC 상태 전환 | `WorldState.npcStates` | `state` 가 액터의 `states[]` 에 선언되어야 | 번들에 없는 상태(정상 경로에선 불가) → **무시 + ERROR 로그**. `terminal` 상태에서의 이탈 시도 → 무시 + ERROR |
| E14 | `warp` | `map`,`x`,`y` | string, int, int | 맵 이동 | 세션(맵·파티 위치) | 맵 이름이 **실제 파일로 해석**(R-21-7), 좌표 범위 내, **도착 타일 통행 가능**(하드) | 런타임 맵 로드 실패 → **이동 취소 + ERROR 로그**. 파티는 원위치. 지연 이동 메커니즘은 [BP-27](27_runtime_engine.md) 소관(D-19) |
| E15 | `change_tile` | `map?`,`x`,`y`,`tile` | string?, int, int, int | **ground(A5) 타일** 교체 | 맵 런타임 상태 → 세이브의 `mapDelta`([BP-25](25_world_state_and_save.md)) | `map` 생략 시 현재 맵. `tile` 은 A5 인덱스 0..127. 좌표 범위 내 | 좌표 범위 밖 → 무시 + ERROR 로그 |
| E16 | `start_battle` | `encounterId` | enc id | 전투 개시 | 전투 서브시스템 | 인카운터 존재. 적 ≤ `HDParty.maxEnemy`(기본 3). 각 적 id **1~74**(R-21-57) | 인카운터 부재(정상 경로에선 불가) → 전투 미개시 + ERROR 로그 |
| E17 | `play_dialogue` | `id` | dlg id | 대화 그래프 실행 | UI(대화 런타임) | 대화 존재. 꼬리 호출·체인 ≤4(§6.7) | 체인 깊이 초과 → 체인 절단 + 경고 로그 |
| E18 | `journal` | `entryKey` | string key | 저널에 항목 추가 | `WorldState.journal` | 문자열 키 존재 | 항목의 `questId`/`stageId` 를 무엇으로 채우는지는 [BP-25](25_world_state_and_save.md) 소관(`I-13`) |
| E19 | `heal_party` | `percent` | int 1..100 | 생존 멤버 HP 를 최대치의 n% 회복 | 파티 | 의식불명/사망은 회복하지 않음 | 생존자 0명 → 무동작 |
| E20 | `grant_exp` | `amount` | int≥1 | 경험치 지급(생존 멤버 균등 분배) | 파티 | 레벨업 판정은 기존 성장식 재사용 | 생존자 0명 → 무동작. 나머지는 버린다(결정론) |
| E21 | `set_encounter` | `rate` | int 0..10 | 조우율 설정 (`HDParty.encounter`) | 파티 | 0 = 조우 없음. 상한 10 의 근거는 아래 상세 | 없음 |
| E22 | `unlock_place` | `id` | place id | 장소 해금(지도·워프 대상에 노출) | `WorldState` | place 존재. `map: null` 인 place 는 하드 실패 | 이미 해금 → 무동작(무경고) |
| **E23** | **`restore`** | `resource`,`percent`,`target?` | enum, int 1..100, target 식 | **SP/ESP 를 최대치의 n% 회복** | 파티(`HDPlayer.sp`/`esp`) | `resource` ∈ {`sp`,`esp`} — **`hp` 는 하드 실패**(E19 `heal_party` 가 담당, 중복 정의 금지). `percent` 1..100. `target` 문법 §6.6.1 | 대상 0명(전원 사망 등) → 무동작. `lowest:<resource>` 의 `resource` 가 인자 `resource` 와 달라도 허용(의도적) |
| **E24** | **`cure`** | `status`,`target?` | enum, target 식 | **상태 해제** | 파티(`HDPlayer.poison`/`unconscious`/`dead`) | `status` ∈ {`poison`,`unconscious`,`dead`} — 그 밖은 하드 실패. `target` 문법 §6.6.1 | 해당 상태가 아닌 멤버 → 그 멤버만 무동작(무경고). `dead` 해제 시 HP 는 **1** 로 복귀하며 회복은 E19/E23 이 별도로 한다 |
| **E25** | **`grant_buff`** | `buff`,`turns` | enum, int 1..999 | **파티 버프 부여** | `HDParty.buffs`(`PartyBuffs`) | `buff` ∈ {`magicTorch`,`walkOnWater`,`canUseEsp`} — **화이트리스트 밖은 하드 실패**(근거 §6.6.3). `turns` 1..999 | 이미 걸린 버프 → **더 큰 값으로 덮어쓴다**(누적 아님, 결정론). `canUseEsp` 는 `bool` 이므로 `turns` 를 **무시하고 영구 부여** + 경고 로그 |

**상세**

- **E6 `take_item` 클램프** — 부족분을 하드 실패로 두면 "이미 팔아버린 퀘스트 아이템" 때문에
  게임이 죽는다. 클램프 + 경고가 안전하다. 대신 **린트가** "회수 직전에 `has_item` 조건이 없다" 를
  경고한다(BP-33).
- **E10 `advance_quest` 역행 금지** — D-06 의 "되돌리기 없음" 을 여기서 강제한다.
  스테이지 DAG 의 위상 순서 뒤로 가는 전이는 빌드 하드 실패.
- **E14 `warp` 통행 검사** — 도착 타일의 `HDTileProperties.getUnitAction` 이 `none`/`isInteractive`
  이면 파티가 벽 속에 갇힌다. 빌드가 맵 데이터를 읽어 검사한다([BP-26 §3](26_entity_registry_and_anchors.md) 와 같은 판정 테이블).
- **E15 `change_tile` — ground 레이어만 바꾼다** (REVIEW_BP-21 `F-12` / BP-90 `I-17`).
  원작 cm2 의 `Map::ChangeTile` 대응(`assets/lore_ep1.cm2` 의 유골 앞 비밀 통로 `Map::ChangeTile(61,82,14)`).
  - **제약**: `hadar2026_app/lib/domain/map/map_model.dart` 의 `setTile()` 은 `unit.ixTile` 만 바꾸고,
    `HDTileProperties.getUnitAction` 은 **`ixObj1`(objUpper)를 먼저 본다**
    (`tile_properties.dart:196-202`). 따라서 **objUpper 에 오브젝트가 있는 칸은 `change_tile` 로
    통행·상호작용 상태를 바꿀 수 없다.** "문을 열어 talk NPC 를 없앤다" 같은 앵커 관련 변화는
    이 do 로 표현되지 않는다.
  - 원작 재현에는 충분하다(원작도 A5 만 바꿨다). 신규 콘텐츠가 objUpper 를 바꿔야 하면
    **`layer` 인자 추가가 필요**하며 이는 `schemaVersion` 승격 사항이다 → **Q-21-8**.
  - **저장 위치**: 타일 변경은 맵 파일을 영구 변경하지 않고 세이브의 **`mapDelta`** 에 쌓인다.
    이 구조의 이름·인코딩·`base` 구분(D-22)은 [BP-25](25_world_state_and_save.md) 소유다.
    초판이 쓴 "타일 오버라이드 맵" 이라는 표현은 기존 `MapModel.tileOverrides`
    (**좌표별이 아니라 타일 id → 타일 id 전역 리맵**, `Tile::CopyTile` 계열이 채운다)와
    이름이 겹쳐 혼동을 낳으므로 폐기한다.
- **E16 `start_battle` 의 결과** — 콘텐츠가 승/패/도주를 **조건으로 읽을 수단은 v1 DSL 에 없다.**
  진행은 월드 이벤트로만 관측한다(이름·payload 는 [BP-23 §23.11.1](23_quest_model.md) 소유).
  전투 결과 코드의 정본 확정은 [BP-27](27_runtime_engine.md) 소관이다 —
  GROUND_TRUTH 부록 B-2 는 `battle.dart:27`(1 Win / 0 Lose / 2 Run)과
  `const.cm2:53-55`(0 EVADE / 1 WIN / 2 LOSE)가 **패배와 도주를 뒤바꿔** 매핑함을 확정했고,
  부록 F-3 은 `Battle::Start` 없이 `Battle::Result()` 를 읽으면 **항상 승리**임을 확정했다.
- **E17 `play_dialogue`** — 대화 안에서 대화를 부르는 것은 허용되지만 **꼬리 호출만** 허용한다(§6.7).
- **E20 `grant_exp`** — `HDPlayer.experience` 에 균등 분배. 나머지는 버린다(결정론).
- **E21 `set_encounter` 의 상한 10** — `HDParty.encounter` 는 기본 3이고 코드에 상한이 없다
  (`hadar2026_app/lib/domain/party/party.dart:79`). 원작 cm2 의 `Map::SetEncounter` 실사용값은
  `ground1.cm2:32` 의 `Map::SetEncounter(1, 10)` 이다. 10 은 **그 실사용 최대치를 상한으로 채택**한 값이며
  코드 제약이 아니다. 더 큰 값이 필요해지면 상한만 넓히면 되고 이는 제약 완화이므로
  `schemaVersion` 승격이 필요 없다(§7.2).
- **E23 `restore` 는 HP 를 다루지 않는다** — `resource` 열거에 `hp` 가 없고, 있으면 하드 실패다.
  HP 회복은 `E19 heal_party(percent)` 하나뿐이며 **두 do 가 같은 필드를 쓰는 상태를 만들지 않는다.**
  이유는 두 가지다. ① 카탈로그 린트(`QV-33`·[BP-42 §4.5.1](42_item_and_inventory.md))가 "이 수치가 무엇을 바꾸는가" 를
  필드 단위로 검산하는데, 같은 필드에 두 경로가 있으면 그 검산이 성립하지 않는다.
  ② `heal_party` 는 이미 "생존 멤버만" 이라는 대상 규칙을 갖고 있어(E19) `target` 식과 의미가 겹친다.
  **`heal_party` 에 `target` 을 붙이는 것은 기존 do 의 선택 인자 추가이므로 승격이 필요 없다** — 필요해지면 그때 한다(§7.2).
- **E24 `cure` 의 3상태는 실제 필드다** — `HDPlayer` 에 `poison`/`unconscious`/`dead` 가 존재하고
  전투·메뉴가 읽는다. `E25` 와 달리 **죽은 필드에 값을 넣는 문제가 없다.**
  단 `dead` 해제의 HP 복귀값(1)은 **이 장이 정하지 않는다** — 파티 규칙이므로
  [BP-42](42_item_and_inventory.md) / [BP-27](27_runtime_engine.md) 이 확정하고 이 장은 "회복은 별도 do" 라는 분업만 못박는다.
- **E25 `grant_buff` 의 화이트리스트는 코드 실측에 종속된다** — §6.6.3.
- **E23~E25 는 지연 효과가 아니다**(§6.7). 즉 배열의 마지막 원소일 필요가 없고 폐포 상한(≤1)에도 세지 않는다.
  세 do 모두 파티 상태를 제자리에서 바꾸고 화면 전환을 유발하지 않는다.
  **아이템 사용 컨텍스트(X3, R-21-60)에서 전부 허용**된다 — 애초에 그것을 위해 추가된 do 다.

#### 6.6.1 `target` 인자 공통 규약 (E23·E24 공유)

`target` 은 **문자열 하나**이며 아래 4형태만 허용한다(닫힌 집합, 그 밖은 하드 실패).
`E23 restore` 와 `E24 cure` 가 같은 문법을 쓴다. **기본값은 `all`** 이므로 생략할 수 있다.

| 형태 | 정규식 | 의미 | 대상이 0명일 때 |
|---|---|---|---|
| `all` | `^all$` | 파티 전원 | (파티는 항상 1명 이상이므로 발생하지 않음) |
| `leader` | `^leader$` | 슬롯 0 (선두 캐릭터) | — |
| `slot:<0-5>` | `^slot:[0-5]$` | 그 슬롯의 멤버 | 빈 슬롯 → **무동작 + 경고 로그** |
| `lowest:<resource>` | `^lowest:(hp\|sp\|esp)$` | 그 자원의 **현재값/최대값 비율**이 가장 낮은 멤버 1명 | 후보 0명 → 무동작 |

- **R-21-65** `slot` 의 상한 5 는 **파티 최대 6인**(`HDParty` 실측)에서 온다. 코드 상수가 바뀌면
  이 정규식도 바뀌며, 이는 **제약 완화**이므로 승격이 필요 없다(§7.2).
- **R-21-66 (결정론)** `lowest:<resource>` 의 **동점 처리는 슬롯 번호 오름차순**이다. 난수를 쓰지 않는다 —
  `WorldRng` 를 끌어들이면 같은 세이브·같은 입력이 다른 결과를 내고 D-01 이 깨진다.
  비율(`현재/최대`)로 비교하는 이유도 같다: 절대값으로 비교하면 최대치가 다른 멤버 사이의 순서가
  캐릭터 성장 상태에 따라 흔들려 작성자가 예측할 수 없다.
- **R-21-67** `target` 은 `E23`/`E24` **에만** 있는 인자다. 다른 do 에 쓰면 `additionalProperties: false`
  로 하드 실패한다(§6.1). 대상 개념이 필요한 기존 do(`heal_party`·`grant_exp`)는 자체 규칙("생존 멤버 전원")을
  이미 갖고 있고, 그것을 `target` 으로 바꾸는 것은 **의미 변경**이므로 하지 않는다.
- **린트**: `target` 문법 검사는 L1(스키마 정규식), `slot:<n>` 이 **그 시점의 파티 구성에 존재하는가** 는
  정적으로 알 수 없으므로 검사하지 않는다. 런타임 경고 로그가 유일한 관측 수단이다.

#### 6.6.2 왜 22 → 25 인가 (D-31 근거 요약)

정본 판단은 **D-31** 이다. 이 장은 그 결과만 시행한다.

- 원작 소비품 10종 중 8종이 v1 22 do 로 표현되지 않았고, [BP-22 R-22-18](22_world_bible_model.md) 은
  "`consumable` 이 `effects` 비면 하드 실패" 다. → **원작 아이템 시드가 자기 규칙에 걸려 빌드를 통과하지 못한다**(BP-90 `I-20`).
- 반대 방향(규칙을 느슨하게 해서 통과시키기)은 **기각**됐다. 효과 없는 소비품을 허용하면
  [BP-42 R-42-23a](42_item_and_inventory.md) 가 이미 겪은 문제(관측 불가능한 소모품)가 스키마 차원에서 재발한다.
- 3종 추가로 8종 중 **5종**(SP 회복·해독·의식 회복·부활·`magicTorch` 버프)이 정식 효과를 갖는다.
  나머지 3종(소환 두루마리·수정 구슬·비행 부츠)은 **여전히 표현되지 않는다** — 앞의 둘은 대응 런타임 기능이 없고,
  비행 부츠는 `levitation` 이 **죽은 버프**라 `grant_buff` 가 하드 실패시킨다(§6.6.3). 그 3종의 처리는
  [BP-22 R-22-18](22_world_bible_model.md) / [BP-42 R-42-22](42_item_and_inventory.md) 소관이다.

#### 6.6.3 `grant_buff` 의 buff 화이트리스트 — 코드 실측 종속 열거

**허용은 `magicTorch` · `walkOnWater` · `canUseEsp` 3종뿐이다.** 근거는
[BP-42 §1.7](42_item_and_inventory.md) 의 전수 실측이다(소유 장이므로 여기서 재서술하지 않고 링크한다):
`PartyBuffs` 에 필드가 **8개** 있으나 **런타임이 읽어 동작을 바꾸는 것은 3개**이고,
나머지 5개(`levitation`·`walkOnSwamp`·`mindControl`·`penetration`·`canUseSpecialMagic`)는 읽는 곳이 0곳이다.

- **R-21-68** (`CV-16`) `grant_buff.buff` 가 화이트리스트 밖이면 **빌드 하드 실패**다. 경고가 아니다.
  죽은 필드에 값을 넣는 효과는 **작성자에게는 성공으로 보이고 플레이어에게는 아무 일도 일어나지 않는다** —
  D-31 이 막으려는 문제가 바로 이것이고, [BP-42 §1.3](42_item_and_inventory.md) 이 `powOfArmor` 를 두고 "자기기만" 이라 부른 것과 같은 종류다.
- **이 열거는 코드가 바뀌면 바뀐다.** 죽은 버프 하나를 살리는 커밋이 들어오면 화이트리스트가 넓어지고,
  그것은 **제약 완화**이므로 `schemaVersion` 승격이 필요 없다(§7.2). 반대로 좁히는 것은 강화이므로 승격이 필요하다.
  **따라서 화이트리스트의 정본은 이 절의 목록이 아니라 [BP-42 §1.7](42_item_and_inventory.md) 의 실측표**이며,
  이 절은 "실측을 따른다" 는 규칙과 현재 값을 적는다.
- **`Effect` → `PartyBuffs` 다리는 아직 없다.** `WorldState` 에 있는 다른 do 와 달리 `PartyBuffs` 는
  `HDParty` 안에 있고, 이 둘을 잇는 코드가 어느 장에도 설계되어 있지 않다([BP-42 §1.7](42_item_and_inventory.md) 말미).
  D-31 이 그 태스크를 [BP-51](51_task_breakdown.md) 에 요구했다. **다리가 놓이기 전까지 `grant_buff` 는
  스키마상 유효하지만 런타임 착지점이 없다** — 솔버의 "실행 가능" 축(D-26)에서 `UNSUPPORTED` 로 잡혀야 하는 종류다.
  → **Q-21-11**.

### 6.7 재진입·중첩 실행 규칙 — **지연 효과(deferred effect)의 단일 규약**

`HDTileEventDispatcher._isScriptRunning`(`hadar2026_app/lib/application/tile_event_dispatcher.dart:34`)은
현재 전역 bool 1개다. Content tier 가 비동기 대화 그래프를 돌리게 되면 이 가드의 의미를
명문화해야 한다(D-10).

#### 6.7.1 지연 효과의 정의

`warp` · `start_battle` · `play_dialogue` 셋은 **제어를 다른 비동기 흐름에 넘긴다**. 이 셋을
**지연 효과(deferred effect)** 라 부른다. 나머지 19개 do 는 즉시 효과이며 제약이 없다.

#### 6.7.2 초판의 결함 — 적용 단위가 실행 단위와 달랐다 (REVIEW_BP-21 `F-02`)

초판 R-21-40 은 "한 Effect **배열**에 지연 효과가 둘 이상이면 하드 실패" 였다. 그런데 한 번의
상호작용은 **여러 Effect 배열을 연쇄 실행**한다. 실제로 규칙을 우회하는 경로가 셋 확인되었다.

| # | 우회 경로 | 왜 통과하는가 |
|---|---|---|
| V1 | `[complete_quest, play_dialogue]` | 배열에는 지연 효과가 1개(`play_dialogue`)뿐이다. 그러나 `complete_quest` 는 `onComplete[]`+`rewards[]` 를 실행하고, [BP-23](23_quest_model.md) 은 "맵 이동·전투 연출은 `onComplete` 에 두라" 고 권장한다 → 실제로는 `warp` + `play_dialogue` 2개 |
| V2 | `[advance_quest(→s2), play_dialogue]` | `s2.onEnter` 가 또 `play_dialogue` 를 가질 수 있다. 체인 깊이 4(R-21-39)가 **무엇을 세는지**도 미정의였다 |
| V3 | 아이템 사용 | [BP-22 R-22-20](22_world_bible_model.md) 이 "아이템 사용 컨텍스트에서는 이 규칙을 만족시킬 수 없다" 며 **스스로 예외를 선언**했다. SSoT 인 이 장에 아이템 사용 컨텍스트가 아예 없었기 때문이다 |

#### 6.7.3 확정 규칙

- **R-21-37** (`CV-09`) 재진입 가드의 의미는 **"한 번에 하나의 상호작용"** 이다. 상호작용이 진행 중이면
  새 타일 이벤트는 **드롭**된다(큐잉하지 않는다). 테스트로 고정한다(D-10).
- **R-21-38** (`CV-10`) 지연 효과는 **꼬리 호출(tail call)** 로만 허용된다. 자기가 속한 Effect 배열의
  **마지막 원소**여야 한다. 중간에 있으면 빌드 하드 실패.
- **R-21-41a** (`CV-11`, **F-02 해소**) 지연 효과의 **개수 제약은 배열이 아니라
  "한 상호작용에서 실행되는 Effect 배열들의 전이적 폐포(transitive closure)"** 에 적용된다.
  폐포 안에 지연 효과가 **2개 이상이면 빌드 하드 실패**.
  - **폐포에 포함되는 것** — 다음 do 가 유발하는 중첩 배열을 전부 따라간다:

    | do | 유발하는 배열 |
    |---|---|
    | `start_quest` | 대상 퀘스트 `stages[0].onEnter` |
    | `advance_quest` | 이전 스테이지 `onExit` + 대상 스테이지 `onEnter` |
    | `complete_quest` | `onComplete` + `rewards` |
    | `fail_quest` | `onFail` |
    | `play_dialogue` | 대상 대화의 `entry` 로 도달 가능한 노드들의 `onEnter`(그리고 그 노드의 `choices[].effects` 는 **별개 상호작용**으로 본다 — 플레이어 입력이 끼므로) |

  - **폐포에서 제외되는 것**: 플레이어 입력을 사이에 두는 경계(선택지 확정, 다음 페이지 넘김).
    입력이 끼면 그 뒤는 **새 상호작용**이다.
- **R-21-39** (개정) `play_dialogue` **체인 깊이는 폐포의 깊이**로 센다(대화 → 대화 → 대화). 최대 **4**.
  빌드가 정적으로 순환을 검출해 하드 실패시키고, 런타임은 초과 시 체인을 끊고 경고 로그를 남긴다.
- **R-21-40** (개정) 정적으로 폐포를 계산할 수 없는 경우(런타임 조건 분기로 어느 배열이 실행될지
  갈리는 경우)에는 **가능한 모든 분기의 폐포를 각각 계산**하고, **어느 하나라도** 지연 효과 2개를
  담으면 하드 실패로 본다. 즉 **보수적(over-approximation)** 판정이다.
- **R-21-42a (런타임 안전망)** 그럼에도 런타임이 한 상호작용에서 지연 효과를 2개 이상 만나면
  **첫 번째만 실행하고 나머지는 버린 뒤 ERROR 로그**를 남긴다. 이것은 빌드 게이트를 통과한 콘텐츠에서는
  일어나지 않아야 하는 **버그 신호**다.
  - 이 런타임 규약은 [BP-25 §4.4](25_world_state_and_save.md) 가 독자적으로 정의했던 것을
    **SSoT 로 흡수**한 것이다(REVIEW_BP-21 `P-03`). 이후 BP-25 는 이 절을 링크만 한다.
  - 적용 시점·호출 순서 등 **실행 경로의 구현**은 [BP-27](27_runtime_engine.md) 소유다(D-18).

#### 6.7.4 실행 컨텍스트 4종 — 어디서 Effect 배열이 시작되는가

지연 효과 규칙은 컨텍스트마다 허용 범위가 다르다. **아이템 사용 컨텍스트를 여기 명시함으로써
[BP-22 R-22-20](22_world_bible_model.md) 의 자체 예외 선언을 회수한다**(REVIEW_BP-21 `P-04`, REVIEW_BP-22 `F-05`).

| # | 컨텍스트 | 진입점 | 지연 효과 허용 | 근거 |
|---|---|---|---|---|
| X1 | **타일 상호작용** | 앵커([BP-26](26_entity_registry_and_anchors.md)) → 대화/트리거 | `warp` ✅ `start_battle` ✅ `play_dialogue` ✅ (폐포당 1개) | 기본 경로 |
| X2 | **퀘스트 전이** | `onEnter`/`onExit`/`onComplete`/`onFail`/`rewards` | 동일. 단 유발한 상호작용의 폐포에 합산된다 | R-21-41a |
| X3 | **아이템 사용** | 메뉴에서 소비품 사용 → `item.effects` | `play_dialogue` ❌ · `start_battle` ❌ · **`warp` ✅(꼬리 호출 1개만)** | 아래 |
| X4 | **전투 결과 훅** | `encounter.onWin`/`onLose`/`onEscape` | `warp` ✅ `play_dialogue` ✅ · `start_battle` ❌(연쇄 전투 금지) | 무한 전투 방지 |

- **R-21-60** (`CV-12`) **아이템 사용 컨텍스트(X3)** 에서는 `play_dialogue` 와 `start_battle` 을 쓸 수 없다.
  아이템 사용은 **메뉴 오버레이** 안에서 일어나며, 대화 그래프나 전투는 그 오버레이를 걷어내야 하는데
  그 복귀 지점이 정의되지 않기 때문이다.
- **R-21-61** `warp` 는 X3 에서 **허용**한다. 원작의 이동 아이템(이동 구슬 `TELEPORT_BALL`)을
  표현할 다른 수단이 없기 때문이다. 배열의 마지막 원소여야 하고 폐포당 1개다.
- **Q-21-9** 원작 이동 구슬은 **목적지를 플레이어가 고른다.** `warp(map,x,y)` 는 목적지가 고정이라
  이를 표현할 수 없다. 목적지 선택 UI 가 필요하며 이는 `warp` 의 시그니처를 벗어난다.
  → v1 은 **고정 목적지 워프 아이템만** 표현 가능하다. 선택형은 `warp_menu(placeIds)` 후보로 남긴다.
  **D-31 의 `schemaVersion` 2 승격에는 넣지 않았다** — 목적지 선택 UI 가 선행이고 그 설계가 없다(§7.2.1 은 do 3종만 담았다). v3 후보다.

### 6.8 JSON Schema 발췌

> **⚠ 이것은 발췌다** (REVIEW_BP-21 `F-04`). 아래 `allOf` 는 op 18개 중 7개, do **25개 중 7개**의
> 필수 인자만 강제한다. **전 op/do 의 필수 인자·ID 패턴을 강제하는 것은
> [BP-90](90_appendix_schemas.md) 의 전문**이며, 이 발췌만 보고 "타입 안전" 을 결론짓지 말 것.
> §6.1 의 "타입 오류는 스키마 단계에서 잡는다" 는 **전문**을 두고 한 말이다.

전문은 [BP-90](90_appendix_schemas.md). 아래는 재귀 정의 + 대표 op 7개 + 대표 do 7개(D-31 추가분 `restore`/`cure`/`grant_buff` 3종을 **전부 포함**했다 — 신설 열거값이므로 발췌에서 빠지면 검수가 확인할 곳이 없다).

```json
{
  "$id": "https://hadar2026/schema/dsl.json",
  "$defs": {
    "flagKey":  { "type": "string", "pattern": "^flag\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,31}(\\.[a-z][a-z0-9_]{2,47})+$" },
    "varKey":   { "type": "string", "pattern": "^var\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,31}(\\.[a-z][a-z0-9_]{2,47})+$" },
    "itemId":   { "type": "string", "pattern": "^item\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,47}$" },
    "questId":  { "type": "string", "pattern": "^quest\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,47}$" },
    "placeId":  { "type": "string", "pattern": "^place\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,47}$" },
    "npcId":    { "type": "string", "pattern": "^npc\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,47}$" },
    "dlgId":    { "type": "string", "pattern": "^dlg\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,47}$" },
    "encId":    { "type": "string", "pattern": "^enc\\.[a-z][a-z0-9_]{2,31}\\.[a-z][a-z0-9_]{2,47}$" },

    "_comment_stringKey": "§4.1.1 확정 문법. slot 은 단일 세그먼트가 아니라 점으로 이어진 경로다(W-01).",
    "stringKey": { "type": "string", "maxLength": 200,
                   "pattern": "^str\\.[a-z][a-z0-9_]{2,31}\\.(npc|quest|item|dlg|place|faction|enc|lore|ui)\\.[a-z][a-z0-9_]{2,47}(\\.([a-z][a-z0-9_]{1,47}|0|[1-9][0-9]{0,3}))+$" },

    "cmp":      { "enum": ["==", "!=", "<", "<=", ">", ">="] },

    "condition": {
      "type": "object",
      "required": ["op"],
      "additionalProperties": false,
      "properties": {
        "op": { "enum": ["true","false","and","or","not","flag","var_cmp","has_item",
                         "quest_state","quest_stage","party_has_class","party_level_cmp",
                         "gold_cmp","map_is","visited","npc_state","time_of_day","chance"] },
        "args":    { "type": "array", "minItems": 1, "maxItems": 16, "items": { "$ref": "#/$defs/condition" } },
        "arg":     { "$ref": "#/$defs/condition" },
        "id":      { "type": "string" },
        "cmp":     { "$ref": "#/$defs/cmp" },
        "value":   { "type": ["integer", "string"] },
        "count":   { "type": "integer", "minimum": 1 },
        "state":   { "type": "string" },
        "stage":   { "type": "string" },
        "classId": { "type": "integer", "minimum": 0, "maximum": 2 },
        "mapName": { "type": "string" },
        "placeId": { "type": "string" },
        "percent": { "type": "integer", "minimum": 1, "maximum": 99 }
      },
      "allOf": [
        { "if": { "properties": { "op": { "const": "and" } } },      "then": { "required": ["args"] } },
        { "if": { "properties": { "op": { "const": "or"  } } },      "then": { "required": ["args"] } },
        { "if": { "properties": { "op": { "const": "not" } } },      "then": { "required": ["arg"] } },
        { "if": { "properties": { "op": { "const": "flag" } } },     "then": { "required": ["id"], "properties": { "id": { "$ref": "#/$defs/flagKey" } } } },
        { "if": { "properties": { "op": { "const": "var_cmp" } } },  "then": { "required": ["id","cmp","value"], "properties": { "id": { "$ref": "#/$defs/varKey" }, "value": { "type": "integer" } } } },
        { "if": { "properties": { "op": { "const": "has_item" } } }, "then": { "required": ["id"], "properties": { "id": { "$ref": "#/$defs/itemId" } } } },
        { "if": { "properties": { "op": { "const": "chance" } } },   "then": { "required": ["percent"] } },
        { "if": { "properties": { "op": { "const": "party_level_cmp" } } },
          "then": { "required": ["cmp","value"],
                    "properties": { "value": { "type": "integer", "minimum": 1, "maximum": 20 } } } },
        { "if": { "properties": { "op": { "const": "time_of_day" } } },
          "then": { "required": ["value"], "properties": { "value": { "enum": ["day","night"] } } } }
      ]
    },

    "effect": {
      "type": "object",
      "required": ["do"],
      "additionalProperties": false,
      "properties": {
        "do": { "enum": ["set_flag","clear_flag","set_var","add_var","give_item","take_item",
                         "add_gold","add_food","start_quest","advance_quest","complete_quest",
                         "fail_quest","set_npc_state","warp","change_tile","start_battle",
                         "play_dialogue","journal","heal_party","grant_exp","set_encounter",
                         "unlock_place","restore","cure","grant_buff"] },
        "id":          { "type": "string" },
        "value":       { "type": "integer" },
        "delta":       { "type": "integer" },
        "count":       { "type": "integer", "minimum": 1 },
        "state":       { "type": "string" },
        "stage":       { "type": "string" },
        "map":         { "type": "string" },
        "x":           { "type": "integer", "minimum": 0 },
        "y":           { "type": "integer", "minimum": 0 },
        "tile":        { "type": "integer", "minimum": 0, "maximum": 127 },
        "encounterId": { "type": "string" },
        "entryKey":    { "type": "string" },
        "percent":     { "type": "integer", "minimum": 1, "maximum": 100 },
        "amount":      { "type": "integer", "minimum": 1 },
        "rate":        { "type": "integer", "minimum": 0, "maximum": 10 },
        "resource":    { "enum": ["sp","esp"] },
        "status":      { "enum": ["poison","unconscious","dead"] },
        "buff":        { "enum": ["magicTorch","walkOnWater","canUseEsp"] },
        "turns":       { "type": "integer", "minimum": 1, "maximum": 999 },
        "target":      { "type": "string", "pattern": "^(all|leader|slot:[0-5]|lowest:(hp|sp|esp))$", "default": "all" }
      },
      "allOf": [
        { "if": { "properties": { "do": { "const": "set_flag" } } },
          "then": { "required": ["id"], "properties": { "id": { "$ref": "#/$defs/flagKey" } } } },
        { "if": { "properties": { "do": { "const": "give_item" } } },
          "then": { "required": ["id"], "properties": { "id": { "$ref": "#/$defs/itemId" } } } },
        { "if": { "properties": { "do": { "const": "warp" } } },
          "then": { "required": ["map","x","y"] } },
        { "if": { "properties": { "do": { "const": "journal" } } },
          "then": { "required": ["entryKey"], "properties": { "entryKey": { "$ref": "#/$defs/stringKey" } } } },
        { "if": { "properties": { "do": { "const": "restore" } } },
          "then": { "required": ["resource","percent"] } },
        { "if": { "properties": { "do": { "const": "cure" } } },
          "then": { "required": ["status"] } },
        { "if": { "properties": { "do": { "const": "grant_buff" } } },
          "then": { "required": ["buff","turns"] } }
      ]
    },

    "effectList": { "type": "array", "items": { "$ref": "#/$defs/effect" }, "maxItems": 32 }
  }
}
```

> **위 발췌는 *소스* 프로파일이다.** `chance` 노드에 `chanceSeedId` 가 **없다** — 그것은 빌드가
> 굽는 필드이므로 소스에 쓰면 `additionalProperties: false` 로 하드 실패한다(§6.1 · `CV-14`).
> 번들 프로파일(`chanceSeedId` 가 있는 형태)의 스키마는 [BP-90 §2.3](90_appendix_schemas.md) 이 소유하고,
> 굽는 절차는 [BP-35 §1.4.1](35_ci_and_build.md) 이 소유한다. 소스↔번들 프로파일 차이는
> **한 JSON Schema 로 표현할 수 없으므로** 두 규칙(소스에 있으면 ERROR / 번들에 없으면 ERROR)이
> [BP-33 §4.6](33_validation_and_lint.md) 의 카탈로그로 내려간다.

### 6.9 Effect 예시

```json
[
  {"do":"take_item","id":"item.gen_ep1.scholar_notebook"},
  {"do":"set_flag","id":"flag.gen_ep1.quest.missing_scholar.notebook_delivered"},
  {"do":"add_var","id":"var.core.party.reputation_lore","delta":5},
  {"do":"give_item","id":"item.core.rusty_key"},
  {"do":"journal","entryKey":"str.gen_ep1.quest.missing_scholar.stage.deliver.journal"},
  {"do":"advance_quest","id":"quest.gen_ep1.missing_scholar","stage":"enter_menace"},
  {"do":"play_dialogue","id":"dlg.gen_ep1.wife_thanks"}
]
```

- `play_dialogue` 가 배열의 **마지막 원소**다(R-21-38 준수).
- 이 배열 자체에는 지연 효과가 1개뿐이다. 다만 **`advance_quest` 가 `enter_menace.onEnter` 를 유발**하므로,
  빌드는 그 배열까지 따라가 **폐포 전체에서 지연 효과가 1개인지** 검사한다(R-21-41a).
  `enter_menace.onEnter` 가 `warp` 을 담고 있으면 이 예시는 **하드 실패**다.
- `journal` 의 `entryKey` 는 §4.1.1 확정 문법을 만족한다:
  `str` + `gen_ep1` + `quest` + `missing_scholar` + slot-path `stage.deliver.journal` (3 세그먼트).

**D-31 추가분 예시 — 원작 소비품 3종의 `effects`**

```json
{
  "item.core.potion_mana":       [ {"do":"restore","resource":"sp","percent":40,"target":"lowest:sp"} ],
  "item.core.herb_detox":        [ {"do":"cure","status":"poison","target":"all"} ],
  "item.core.herb_jolt":         [ {"do":"cure","status":"unconscious","target":"all"} ],
  "item.core.herb_resurrection": [ {"do":"cure","status":"dead","target":"lowest:hp"},
                                   {"do":"heal_party","percent":25} ],
  "item.core.big_torch":         [ {"do":"grant_buff","buff":"magicTorch","turns":300} ]
}
```

- `herb_resurrection` 이 **2개 효과**인 이유: `cure(dead)` 는 상태만 풀고 HP 를 1 로 되돌린다(E24).
  회복은 `heal_party` 가 한다 — **한 do 가 두 일을 하지 않는다**는 E23 의 분업 원칙과 같다.
- `target: "lowest:hp"` 는 사망자 중 슬롯 번호가 가장 앞인 1명을 고른다(R-21-66 의 동점 규칙).
  전원 부활이 필요하면 `"all"` 을 쓴다.
- `big_torch` 의 `turns: 300` 은 `magicTorch` 가 **정수 카운터**라서 성립한다.
  `canUseEsp` 는 `bool` 이므로 같은 형태를 써도 `turns` 가 무시된다(E25 경계 입력).
- **`item.core.winged_boots` 는 이 목록에 없다** — `levitation` 이 화이트리스트 밖이므로
  `grant_buff` 를 쓰면 하드 실패한다(R-21-68). 그 아이템의 처리는 [BP-22 R-22-18](22_world_bible_model.md) 소관이다.
- 위 5개는 [BP-22 §6.5](22_world_bible_model.md) 의 시드 표에 대응하는 **예시**이며, **실제 카탈로그 수치의 소유는
  [BP-42](42_item_and_inventory.md)** 다(D-18). 이 절은 do 의 사용 형태만 보인다.

### 6.10 cm2 대비 — 왜 이 DSL 이 AI 타깃으로 적합한가

| 항목 | cm2 (GROUND_TRUTH §9) | 이 DSL |
|---|---|---|
| 미지의 이름 | 미등록 함수 → **0 반환, 조용히 오분기** | 빌드 하드 실패 |
| 정적 검증 | 불가(들여쓰기 DSL, 타입 없음) | JSON Schema + 참조 무결성 + 도달성 |
| 상태 수명 | 맵 전환 시 엔진 전역 전멸 | WorldState 단일 저장소(D-08) |
| 난수 | `Random(n)` — 시드 규약 없음 | `chance` 시드 유도 `mix([seed, step, chanceSeedId])`(§6.5), 검증기가 양 분기 탐색 |
| 반복 실행 | `.assign` 이 매 실행 재실행되어 상태를 지움 | Effect 는 명시 호출 시에만 적용 |
| 표현력 | 루프·함수 없음 | 의도적으로 동일(선언적). 복잡 로직은 네이티브 Dart 로 |
| 범위 밖 인자 | 정상 심볼인데 값이 범위 밖이면 **아무 일도 안 하고 로그도 없다**(부록 F-1: `Flag::Set(300)`, `Battle::RegisterEnemy(0)`) | 범위 제약이 스키마에 있어 빌드가 잡는다. 런타임 경계 동작도 §6.3·§6.6 표에 명시 |

> **논거 정정**(GROUND_TRUTH 부록 E-3): "cm2 는 튜링 완전이라 정적 검증이 불가능하다" 는 주장은
> 성립하지 않는다 — `packages/cm2_script/lib/src/parser.dart` 에는 루프도 함수 정의도 없다.
> D-02 의 실제 근거는 위 표의 **침묵 실패·전역 소실·`.assign` 재실행·스키마 부재**이며,
> 이 문서는 어디서도 튜링 완전성을 근거로 쓰지 않는다.

### 6.11 하드 규칙 검사 ID (`CV-nn`)

REVIEW_BP-21 `F-14`: 초판은 하드 실패 규칙에 **번호도 소유자도 부여하지 않았다.** 그 결과
[BP-24](24_dialogue_model.md) 가 `DV-15~DV-20`, [BP-22](22_world_bible_model.md) 가 `L-22-08`,
[BP-26](26_entity_registry_and_anchors.md) 가 `A-26-nn` 으로 **같은 제약에 각자 번호를 다시 붙였다**.

**이 장의 하드 규칙에는 `CV-nn` 를 부여한다.** [BP-33](33_validation_and_lint.md) 은 이 번호를
그대로 받아 메시지·수정 힌트를 확정한다(번호를 새로 만들지 않는다).

| 검사 ID | 규칙 | 대상 | 심각도 |
|---|---|---|---|
| `CV-01` | 문자열 키가 `STRING_KEY` 문법을 만족 (R-21-50~54) | `strings/*.json` 키, 콘텐츠의 모든 stringKey 참조 | hard |
| `CV-02` | `enemy.*` 를 콘텐츠가 정의하지 않음 (R-21-55) | 전 팩 | hard |
| `CV-03` | 색상 태그가 `[0-9A-Ga-g]` 집합을 벗어나지 않음 (§5.5) | 문자열 값 | hard |
| `CV-04` | 문자열 값 ≤ 1000자 (R-21-59) | 문자열 값 | hard |
| `CV-05` | 완주 필수 경로가 `chance` 뒤에 없음 (R-21-36) | 퀘스트 | hard |
| `CV-06` | ID 문법·팩 가시성·중복·은퇴 (§4.4, §4.6, §4.7) | 전 ID | hard |
| `CV-07` | 맵 이름이 **실제 파일로 해석**됨 (R-21-7 · C14 · E14) | 앵커 파일명, `map_is`, `warp` | hard |
| `CV-08` | 팩 디렉토리가 `pubspec.yaml#flutter/assets` 에 열거됨 (R-21-46) | 빌드 산출 | hard |
| `CV-09` | 재진입 가드가 "한 번에 하나의 상호작용" 을 지킴 (R-21-37) | 런타임 테스트 | hard(테스트) |
| `CV-10` | 지연 효과가 배열의 마지막 원소 (R-21-38) | 전 Effect 배열 | hard |
| `CV-11` | 상호작용 폐포당 지연 효과 ≤ 1 (R-21-41a·R-21-40) | 폐포 | hard |
| `CV-12` | 아이템 사용 컨텍스트의 지연 효과 제약 (R-21-60) | `item.effects` | hard |
| `CV-13` | Condition 중첩 깊이 ≤ 8, `args` 1~16 (R-21-28·29) | 전 Condition | hard |
| `CV-14` | `additionalProperties: false` — 미지 필드/미지 op·do (§6.1) | 전 콘텐츠 | hard |
| `CV-15` | 파일 포맷 규약(UTF-8/LF/2-space/키 정렬/부동소수 금지/크기 상한) (§8) | 전 파일 | hard |
| **`CV-16`** | `grant_buff.buff` 가 화이트리스트 3종 안 (R-21-68 · §6.6.3) — 죽은 `PartyBuffs` 필드 지정 금지 | 전 Effect 배열 | hard |
| **`CV-17`** | `restore.resource` ∈ {`sp`,`esp`} · `cure.status` ∈ {`poison`,`unconscious`,`dead`} · `target` 문법 (§6.6·§6.6.1) | 전 Effect 배열 | hard |

- **R-21-64** `CV-nn` 는 **이 장이 소유**하고 BP-33 이 카탈로그에 편입한다. 다른 장은 같은 제약에
  새 번호를 만들지 않고 `CV-nn` 를 인용한다.
- **`CV-16`/`CV-17` 은 D-31 확장과 함께 신설**됐다. D-31 은 두 검사를 [BP-33](33_validation_and_lint.md) 의 **L1** 에 넣으라고 요구했고,
  이 장은 그 규칙에 **번호를 부여**한다(R-21-64 의 절차대로 — 새 하드 규칙이 생기면 먼저 `CV-nn` 를 받는다).
  BP-33 은 이 두 번호를 그대로 받아 메시지·수정 힌트를 확정한다.

---

## 7. 버전 관리와 호환성

### 7.1 두 개의 버전

| 버전 | 위치 | 의미 | 올리는 주체 |
|---|---|---|---|
| `schemaVersion` | `pack.json` | **포맷** 버전. DSL op 집합, 필드 구조 | 엔진 개발자 |
| `version` | `pack.json` | **콘텐츠** 버전(semver). 그 팩이 담은 내용 | 콘텐츠 작성자/빌드 |

### 7.2 `schemaVersion` 승격 규칙

| 변경 | 승격 필요? | 근거 |
|---|---|---|
| op/do **추가** | ✅ 필수 | 구 런타임이 새 op 를 만나면 해석 불가 |
| op/do **삭제** | ✅ 필수 | — |
| 기존 op 의 **필수 인자 추가** | ✅ 필수 | — |
| 기존 op 의 **선택 인자 추가**(기본값 보존) | ❌ 불필요 | 구 데이터가 그대로 유효 |
| 필드 **이름 변경** | ✅ 필수 | — |
| 제약 **완화**(길이 상한 증가 등) | ❌ 불필요 | — |
| 제약 **강화**(새 하드 실패 조건) | ✅ 필수 | 기존 통과 데이터가 실패할 수 있음 |
| 문자열 슬롯 추가 | ❌ 불필요 | 키는 자유 형식 |

- **R-21-41** 런타임과 CLI 는 `supportedSchemaVersions = {1, 2}` 처럼 **지원 집합**을 갖는다.
  팩의 `schemaVersion` 이 집합 밖이면 로드 거부하고, 어느 쪽이 오래됐는지 hint 로 알려준다.
  (초판은 `{1}` 이었다. **D-31 승격으로 `{1, 2}` 가 됐다** — §7.2.1 ③.)

### 7.2.1 승격 실행 기록 #1 — `schemaVersion` 1 → 2 (D-31, do 22 → 25)

**이 기획서 최초의 스키마 승격이다.** D-31 은 결과를 확정하면서 "§7.2 의 승격 절차가 실제로 작동하는지
이 건으로 검증하라" 고 요구했다. 아래는 절차를 **끝까지 밟은 기록**과 그 과정에서 드러난 절차 자체의 공백이다.

**승격 사유 판정** — §7.2 표의 어느 행에 걸리는가

| §7.2 표의 행 | 이 건의 해당 여부 | 판정 |
|---|---|---|
| op/do **추가** | ✅ `restore`·`cure`·`grant_buff` 3개 | **승격 필수** |
| 기존 op 의 **필수 인자 추가** | ❌ `E1`~`E22` 는 무변경 | — |
| 필드 **이름 변경** | ❌ | — |
| 제약 **강화** | ⚠ **판단 필요** — `CV-16`/`CV-17` 은 새 하드 실패 조건이지만 **새 do 에만 걸린다.** 구 데이터에 그 do 가 있을 수 없으므로 기존 통과 데이터가 실패하지 않는다 | 승격 사유 **아님**(이미 필수이므로 결론은 같다) |
| 제약 **완화** | ❌ | — |

→ **첫 행 하나로 이미 필수**다. 표가 이 케이스를 정확히 잡았다. ✅ **절차 1항은 작동한다.**

**절차 실행 — 실제로 무엇을 고쳐야 했나** (6곳)

| # | 대상 | 조치 | §7.2 표가 지시했는가 |
|---|---|---|---|
| ① | §6.6 do 표 · §6.8 발췌의 `do.enum` | `E23`~`E25` 3행 추가, 발췌 열거 확장 | ✅ (승격의 내용 자체) |
| ② | `pack.json#schemaVersion` — §3.5 `core` · §3.6 `gen_ep1` 예시 | `1` → `2` | ✅ |
| ③ | `supportedSchemaVersions` (R-21-41) | `{1}` → `{1, 2}` | ❌ **표에 없다** → 아래 (a) |
| ④ | `pack.json#migrations` 에 `{from:1, to:2}` 항목 | **`steps: []`** 로 선언 | ❌ **표에 없다** → 아래 (b) |
| ⑤ | [BP-22 R-22-18](22_world_bible_model.md) 의 `_v1Unimplemented` 우회 | 5종 해제(3종 잔존) | ❌ **표에 없다** → 아래 (c) |
| ⑥ | [BP-90 §2.3](90_appendix_schemas.md) 기계 판독 사본 · [BP-33](33_validation_and_lint.md) L1 규칙 | 소유 장이 반영 | ✅ (D-18 의 통상 파급) |

**절차가 답하지 못한 것 3건 — 이번 건으로 드러났고, 여기서 규정한다**

- **(a) 런타임·CLI 지원 집합의 갱신이 승격 체크리스트에 없었다.**
  R-21-41 은 "지원 집합을 갖는다" 는 **성질**만 규정하고, 승격할 때 그 집합을 넓히는 것이
  승격 작업의 일부라는 서술이 없었다. 집합을 넓히지 않으면 **승격 직후 모든 팩이 로드 거부**된다.
  - **R-21-69** `schemaVersion` 을 N 으로 올릴 때 **같은 커밋에서** `supportedSchemaVersions` 에 N 을 추가한다.
    두 변경이 갈라진 커밋은 CI 가 막는다([BP-35](35_ci_and_build.md) 소관 — 번들의 `schemaVersion` 이 지원 집합 밖이면 빌드 실패).
- **(b) "데이터 변환이 필요 없는 승격" 의 표현이 정의되지 않았다.**
  §7.3 은 마이그레이션을 `pack.json#migrations` 에 **선언적으로** 기술하라고만 했고, 허용 `kind` 7종은
  전부 **기존 데이터를 바꾸는** 연산이다. do 추가는 **순수 확대**여서 바꿀 것이 없는데,
  그렇다면 `migrations` 항목을 **아예 쓰지 않는 것**인지 **`steps` 를 비워 쓰는 것**인지 규정이 없었다.
  - **R-21-70** `steps: []` 인 `migrations` 항목을 **허용하고, 무변환 승격에서는 필수로** 한다.
    ```json
    "migrations": [ { "from": 1, "to": 2, "steps": [], "_note": "D-31 do 22→25 순수 확대. 소스 변환 없음" } ]
    ```
    항목을 아예 생략하면 R-21-42 의 "N-1 까지 자동 승격" 을 **빌드가 확인할 방법이 없다** —
    변환이 없다는 것과 승격 경로가 선언되지 않은 것을 구별할 수 없기 때문이다. 빈 `steps` 는
    "이 경로는 검토됐고 할 일이 없다" 는 **명시적 진술**이다.
- **(c) 승격이 다른 장의 우회를 해제한다는 사실을 절차가 추적하지 않았다.**
  [BP-22 R-22-18](22_world_bible_model.md) 은 `_v1Unimplemented: true` 를 "`schemaVersion` 2 에서 3개 do 가
  추가되면 **일괄 제거**" 라고 자기 문서 안에만 적어 두었다. 승격하는 쪽(이 장)에는 그 목록이 없어
  **승격만 하고 우회가 남는 상태**가 될 수 있었다.
  - **R-21-71** 승격 기록(§7.2.x)은 **이 승격으로 해제되는 우회 플래그·잠정 규칙의 목록**을 담는다.
    이 건의 목록: [BP-22 R-22-18](22_world_bible_model.md) `_v1Unimplemented`(원작 시드 8종 중 **5종 해제 · 3종 잔존**),
    [BP-42 R-42-23](42_item_and_inventory.md) 의 "`Q-42-1` 로 남기고 DSL 확장 뒤에 정식 효과를 붙인다",
    [BP-22 Q-22-4](22_world_bible_model.md)(**종결**).

**절차가 잘 작동한 것 3건** (반대 기록)

| # | 작동한 것 |
|---|---|
| 1 | **승격 필요 판정표(§7.2)가 8행 중 정확히 1행으로 결론을 냈다.** "제약 강화" 행에서 한 번 망설였으나, "기존 통과 데이터가 실패할 수 있음" 이라는 **근거 열**이 판단을 갈라 주었다 — 새 do 에만 걸리는 하드 규칙은 구 데이터에 걸릴 수 없다 |
| 2 | **완화/강화의 비대칭이 실제로 유용했다.** §6.6.1 `slot:[0-5]` 상한과 §6.6.3 buff 화이트리스트는 **코드 실측에 종속**되어 앞으로 넓어질 수 있는데, 넓히는 것은 완화이므로 승격이 필요 없다. 이 규칙 덕에 "코드가 바뀌면 스키마 버전이 또 올라가나" 라는 질문에 즉답할 수 있었다 |
| 3 | **`schemaVersion`(포맷) ↔ `version`(콘텐츠) 2축 분리(§7.1)가 값을 했다.** 이 승격으로 콘텐츠는 한 글자도 바뀌지 않으므로 팩의 `version` 은 그대로다. 두 버전이 하나였다면 전 팩의 semver 를 올려야 했고 세이브 호환 판정(§7.4)까지 흔들렸다 |

**결론**: 승격 절차는 **핵심 판정(무엇이 승격을 요구하는가)에서 정확했고, 후속 조치 목록이 비어 있었다.**
R-21-69~71 세 규칙이 그 공백을 메운다. 다음 승격(#2)은 §7.2.x 로 같은 형식의 기록을 남긴다.

### 7.3 하위 호환 정책과 마이그레이션 선언

- **R-21-42** 빌드는 **N-1 스키마까지** 자동 승격을 지원한다(N-2 이상은 `hadar_content migrate` 수동 실행).
- **R-21-43** 마이그레이션은 `pack.json#migrations` 에 **선언적으로** 기술한다. 임의 스크립트 금지.

```json
"migrations": [
  {
    "from": 1,
    "to": 2,
    "steps": [
      { "kind": "rename_id",    "from": "flag.gen_ep1.quest.missing_scholar.met", "to": "flag.gen_ep1.quest.missing_scholar.met_client" },
      { "kind": "rename_field", "path": "quests/*.json#stages[*]",  "from": "next", "to": "transitions" },
      { "kind": "set_default",  "path": "actors/*.json",            "field": "knowledge", "value": { "knows": [], "unknown": [] } },
      { "kind": "drop_field",   "path": "items/items.json#items[*]", "field": "legacyIntId" },
      { "kind": "retire_id",    "id": "npc.gen_ep1.tavern_drunk",    "replacedBy": "npc.core.lore_tavern_drunk" }
    ]
  }
]
```

허용 `kind` (닫힌 집합): `rename_id`, `rename_field`, `set_default`, `drop_field`, `retire_id`,
`remap_enum`, `split_file`. 그 외는 하드 실패.

- **R-21-70 (재게시)** `steps` 는 **빈 배열일 수 있고, 무변환 승격에서는 비어야 한다.** 7종 `kind` 는
  전부 기존 데이터를 **바꾸는** 연산이므로 op/do 추가 같은 **순수 확대**에는 해당하는 `kind` 가 없다.
  항목 자체를 생략하지 않는 이유는 §7.2.1 (b) 에 있다 — 생략하면 "변환이 없다" 와 "경로가 선언되지 않았다" 를
  빌드가 구별할 수 없다.

- **R-21-62** (REVIEW_BP-21 `S-03`) 여기 정의한 것은 **콘텐츠 소스 마이그레이션**이다.
  **세이브 상태 마이그레이션은 [BP-25](25_world_state_and_save.md) 소관이며 별도 어휘를 쓴다**(D-18).
  두 어휘를 섞지 말 것 — 이 장은 `kind`, BP-25 는 자체 필드명을 쓴다.
  콘텐츠의 `rename_id` 가 세이브에 남은 옛 키까지 옮기지는 **않는다**. 그 연결은 BP-25 가 정의한다.
- **R-21-63** 예시의 상태 키는 반드시 §4.1 `STATE_KEY` 를 만족해야 한다. 초판은
  `flag.gen_ep1.quest.a.met` 를 썼는데 `a` 가 1글자라 **자기 문법 위반**이었다(REVIEW_BP-21 `F-06`).
  문서의 예시도 검증 대상이다.

### 7.4 세이브 ↔ 콘텐츠 호환 (D-08 연결)

| 상황 | 동작 |
|---|---|
| 세이브의 팩 version > 현재 팩 version | **로드 거부**. "콘텐츠가 세이브보다 오래됐습니다" |
| 세이브의 팩 version < 현재 팩 version, MAJOR 동일 | 정상 로드 + `migrations` 적용 |
| MAJOR 가 다름 | 로드 거부 (호환 보장 없음) |
| 세이브에 있고 현재 없는 팩 | 그 팩의 상태를 드롭 + 경고. 진행 중 퀘스트가 있으면 로드 거부 |
| 세이브에 없고 현재 새로 추가된 팩 | 정상. 새 콘텐츠가 초기 상태로 시작 |

상세 규칙과 v1 세이브 마이그레이션은 [BP-25](25_world_state_and_save.md) 소관이다.

---

## 8. 파일 포맷 규약

| 항목 | 규약 | 이유 |
|---|---|---|
| 형식 | JSON (JSON5·JSONC·YAML 금지) | `dart:convert` 로 그대로 읽힌다. 파서 추가 의존 없음 |
| 인코딩 | UTF-8, **BOM 없음** | Flutter `rootBundle`/`AssetSource` 기본 |
| 줄바꿈 | LF (`\n`) | CRLF 는 해시 결정론을 깬다 |
| 파일 끝 | 개행 1개로 종료 | git diff 잡음 제거 |
| 들여쓰기 | **space 2칸** | 원본 `books.json` 은 탭을 쓰지만 신규 콘텐츠는 space 로 통일 |
| 키 정렬 | 객체 키는 **사전순**. 단 `id`, `type`, `pack` 은 항상 맨 앞(이 순서로) | 결정론 + 사람이 읽기 |
| 배열 정렬 | 의미상 순서가 있는 배열(대화 `lines`, Effect, stage)은 **보존**. 카탈로그성 배열(items, places, factions)은 `id` 사전순 | 순서가 의미인 곳과 아닌 곳을 구분 |
| 부동소수 | **금지**. 모든 수치는 정수 | 직렬화 왕복 시 비트가 흔들려 해시가 깨짐 |
| `null` | 명시적 "없음" 을 뜻할 때만. 기본값 생략은 필드 자체를 뺀다 | 오탐 감소 |
| 주석 | JSON 이므로 불가. `_note`(string) 또는 `_notes`(string[]) 필드를 쓴다 | — |
| `_` 접두 필드 | 빌드가 **번들에서 제거**한다. 소스에만 남는다 | 런타임 번들 크기 절감 |
| 최대 파일 크기 | 소스 1파일 **512 KiB**, `strings/ko.json` **2 MiB**, 번들 산출물 **16 MiB** | 웹 빌드 로딩 시간 |
| 최대 팩 크기 | 소스 합계 **32 MiB** | — |

- **R-21-44** 빌드는 `--check-format` 모드에서 위 규약 위반을 **하드 실패**로 보고하고,
  `hadar_content build --fix-format` 이 정규화 후 저장한다. AI 는 항상 API/CLI 로 쓰므로
  (D-12 원칙 4) 정규화가 쓰기 시점에 자동 적용된다.
- **R-21-45** 사람이 손으로 편집한 파일도 커밋 전에 정규화된다. CI 가 재정규화 후 diff 가
  비어 있는지 검사한다(포맷 게이트). 이는 `dart format` 게이트가 아직 없는 코드 쪽과 달리,
  **콘텐츠는 처음부터 format-clean 으로 시작**한다는 뜻이다.
- **R-21-65** 팩이 늘 때마다 `pubspec.yaml#flutter/assets` 의 디렉토리 열거도 빌드가 갱신한다(R-21-46).
  포맷 게이트는 이 열거의 정렬·중복도 함께 검사한다.
- **R-21-66** 웹 페이로드 기준선은 **실측 45MB**(그중 게임 자산 9.7MB, `canvaskit/` 31MB — 부록 B-5)다.
  번들 크기 목표는 이 수치 대비 상대값으로 세운다([BP-35](35_ci_and_build.md)).
  위 표의 "번들 산출물 16 MiB" 는 그 안에서 콘텐츠가 차지할 수 있는 상한이다.

### 8.1 `_note` 사용 예

```json
{
  "id": "npc.gen_ep1.scholar_wife",
  "type": "actor",
  "pack": "gen_ep1",
  "_note": "critic 7단계에서 '슬픔이 과장됐다' 지적 → 대사 톤 낮춤(0.3.0). 다시 올리지 말 것.",
  "faction": "faction.core.lore_commoner",
  "place": "place.gen_ep1.scholar_house"
}
```

---

## 9. 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 9.1 확정한 것

| # | 내용 |
|---|---|
| 1 | 팩 = 소유권 경계 + 병합 단위 + 롤백 단위. `core`(사람) / `gen_*`(AI) 분리, 같은 ID 재정의 금지 (R-21-1~4) |
| 2 | 디렉토리 레이아웃 전량과 파일당 엔티티 수 규칙. actors/quests/dialogue 는 1파일 1엔티티, 파일명 == 슬러그 (R-21-5~9) |
| 3 | `pack.json` 전 필드(필수 6 + 선택 8) + `generatedBy`/`entryPoints`/`contentBudget` 하위 스키마 + `core`·`gen_ep1` 완전 예시 |
| 4 | ID 문법 4종(엔티티/상태/문자열/**적 참조**) EBNF + 정규식 + 타입 접두사 12종 + 참조 전용 타입 1종 + 로컬 ID 4종 + `#` 참조 문법 |
| 5 | 슬러그 규칙, 예약어 4범주, 상태 키 domain 6종 의미 고정 |
| 6 | 은퇴 규칙(`retiredIds`), 팩 간 참조 규칙 7항, 검증기 의사코드(`{error, hint}` 규약 계승) |
| 7 | 인라인 텍스트 금지 + 예외 4종, 문자열 키 유도 규칙, 표준 슬롯 표(**경로형**), `strings/ko.json` 플랫 구조 |
| 8 | 색상 태그 집합을 **파서 실측(`hd_text_utils.dart` 17키 `0-9A-G`, 소문자 허용)** 에 맞춰 정정. 미종료 태그는 파서가 문자열 끝에서 자동 해제하므로 **경고로 강등**(`W-05` 해소). 리터럴 `@` 는 정상 렌더됨 |
| 9 | **Condition 18 op / Effect 25 do 전량 명세(총 43)** — 시그니처·타입·의미·빌드 검증·**런타임 미정의/경계 입력 43/43**. do 는 D-31 로 22 → 25(§6.6 `E23`~`E25`) |
| 10 | 지연 효과(`warp`/`start_battle`/`play_dialogue`) 개념 도입. 제약 단위를 배열 → **한 상호작용의 전이적 폐포**로 재정의(`F-02` 해소). 실행 컨텍스트 4종(X1~X4)과 **아이템 사용 컨텍스트** 명시 |
| 11 | `chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p` — **`step` 포함이 정본**(D-30). **커서를 밀지 않는다**(D-21). `chanceKey`(문자열 키) 명칭·형식은 이 장 소유, `chanceSeedId`(번들 정수)는 [BP-27 §9.2](27_runtime_engine.md), 생성 절차는 [BP-35 §1.4.1](35_ci_and_build.md)(D-29a). 해시 함수 이름은 `mix` 로 통일(`splitmix64`/`fnv1a64` 표기 폐기). **R-21-34 개정 2판** + `evalPath` 정규화 7항(**R-21-34a**) + 세 안 트레이드오프 비교표 + 래치 규약(§6.5.2) |
| 12 | `schemaVersion` 승격 규칙 8항, 마이그레이션 선언 형식(허용 kind 7종), 세이브 호환 판정 5케이스. **세이브 상태 마이그레이션은 BP-25 별도 어휘**(R-21-62) |
| **23** | **`do` 25종 확장과 `schemaVersion` 2 승격**(D-31 / `I-20`) — `restore`(sp·esp) · `cure`(poison·unconscious·dead) · `grant_buff`(**살아 있는 3종만**, `CV-16` 하드 실패) + `target` 4형태 공통 규약. HP 는 `heal_party` 단독 담당으로 중복 정의 금지 |
| **24** | **승격 절차의 실증 검증**(§7.2.1) — 판정표는 정확했고 **후속 조치 목록이 비어 있었다.** `R-21-69`~`R-21-71` 로 메움. 승격이 해제하는 타 장 우회([BP-22](22_world_bible_model.md) `_v1Unimplemented` 5/8 · `Q-22-4` 종결)를 기록의 필수 항목으로 규정 |
| 13 | 파일 포맷 규약 13항(UTF-8/LF/2-space/키 정렬/부동소수 금지/`_note`/크기 상한) |
| 14 | **`STRING_KEY` 문법 정본 확정**(`W-01`/`F-01`): 슬롯은 단일 세그먼트가 아니라 **경로**다. §5.3 표준 슬롯 표가 정본이고 정규식을 확장했다. 세 파일 252개 토큰에 실제 대입해 검증 |
| 15 | **참조 전용 타입 `enemy`** 신설(REVIEW_BP-22 `F-01`/`I-08` 해소). 정본 표기는 정수 id, `enemy.*` 는 소스 별칭. 유효 id **1~74**(부록 B-1) |
| 16 | 맵 이름 검증을 "존재" 에서 **"실제 파일로 해석"** 으로 강화(`F-05`/부록 D). `R-21-7`·`C14`·`E14` 는 [BP-22 T-22-1](22_world_bible_model.md) 선행 의존 |
| 17 | `entryPoints.stateKeys` 신설(`W-11`) — 팩 경계를 넘는 상태 접점을 **선언으로** 표현해 `RG-02`/`RG-03` 경고를 억제 |
| 18 | 하드 규칙 검사 ID **`CV-01`~`CV-15`** 부여(`F-14`). BP-33 이 그대로 받는다 |
| 19 | `E15 change_tile` 은 **ground(A5) 만** 바꾼다는 제약 명시(`I-17`/`F-12`). 저장 위치는 BP-25 의 `mapDelta` 를 링크 |
| 20 | 텍스트 길이 수치의 소유를 **BP-24 로 이양**(D-18/`I-10`). 이 장은 포맷 상한 1000자만 유지 |
| 21 | `pubspec.yaml#flutter/assets` 비재귀 열거(부록 A-4) → `R-21-46`/`CV-08`. 웹 페이로드 기준선 45MB(부록 B-5) |
| 22 | `$id` 명명 규약을 **네임스페이스 분리**로 단일화(`I-12`): 콘텐츠는 `schema/<name>.json`, 생성 계약은 `schema/gen/<name>.schema.json` |

### 9.2 다음 장으로 넘긴 것

| 대상 | 내용 |
|---|---|
| [BP-22](22_world_bible_model.md) | `world/*.json`, `actors/*.json`, `items/items.json` 의 **필드 스키마**. 이 장은 파일 위치와 ID 만 정한다 |
| [BP-23](23_quest_model.md) | Quest/Stage/Objective 내부 구조, Objective.kind 9종, 스테이지 DAG 검증 |
| [BP-24](24_dialogue_model.md) | Dialogue/Node/Choice 내부 구조, 진입 라우팅, 도달성 검사, 페이지네이션 |
| [BP-25](25_world_state_and_save.md) | `WorldState` 직렬화, `legacyFlagMap` 생성 규칙, v1→v2 세이브 마이그레이션 |
| [BP-26](26_entity_registry_and_anchors.md) | 앵커 스키마, 트리거 인덱스, 엔티티 레지스트리(역참조), 좌표 이동 안전성 |
| [BP-27](27_runtime_engine.md) | Condition 평가기 / Effect 적용기의 실행 구조, Content tier 통합(D-10) |
| [BP-31](31_content_server_api.md) | `POST /api/content/strings/mint`, 팩 CRUD, `{error, hint}` 응답 규약 |
| [BP-33](33_validation_and_lint.md) | 린트 경고 항목의 규칙 번호·심각도·메시지, 그리고 **하드 규칙 `CV-01`~`CV-15` 의 카탈로그 편입**(§6.11) |
| [BP-34](34_headless_sim_and_solver.md) | 솔버 2축 판정(D-26)의 "실행 가능" 축 — 이벤트 발행 지점 레지스트리 대조 |
| [BP-42](42_item_and_inventory.md) | 아이템 실제 데이터·인벤토리 게임 규칙·장비 마이그레이션(D-18) |
| [BP-43](43_content_style_guide.md) | 문체 규칙(D-18). 이 장의 색상 태그는 **문법**이고 사용 관행은 BP-43 소관 |
| [BP-35](35_ci_and_build.md) | 결정론 재빌드 해시 검사, 포맷 게이트, `content.lock.json` 생성 절차, **`chanceSeedId` 생성 절차**(§1.4.1 — 이 장은 `chanceKey` 형식과 R-21-34a 정규화만 소유) |
| [BP-90](90_appendix_schemas.md) | 여기 발췌한 JSON Schema 의 **전문** |

### 9.3 열린 질문

| # | 질문 | 영향 | 잠정 |
|---|---|---|---|
| **Q-21-1** | *(해소)* 콘솔 줄당 글자수 산출. → **D-18 에 따라 [BP-24 §24.5](24_dialogue_model.md) 로 이양**(`I-10`). 이 장은 수치를 갖지 않는다. 다만 BP-24 의 값도 폰트 메트릭 실측이 아니라면 같은 문제가 남으며, `hd_text_utils.dart` 의 `splitToLines(text, maxWidth, baseStyle)` 를 CLI 에서 재사용해 산출하는 편이 D-12(평가기 공유)와 일관된다 | 길이 린트 임계값 | BP-24 소관 |
| **Q-21-2** | `time_of_day` 를 v1 스키마에 넣되 런타임은 항상 `day` 를 준다. 이 "선언은 있고 구현은 없는" op 를 허용하는 게 옳은가? 아니면 v2 로 미루고 op 를 빼는 게 옳은가? | schemaVersion 승격 빈도 | D-05 가 확정 목록에 포함시켰으므로 유지. 린트가 사용 시 경고 |
| **Q-21-3** | `chance` 의 `evalPath` 를 구조적 경로로 잡으면 **대화를 수정하면 기존 세이브의 분기 결과가 바뀐다**. 경로 대신 명시적 `seedKey` 필드를 요구해야 하나? | 세이브 안정성 | **D-21a 가 이 우려를 명시 승인**했다. v1 은 구조 경로로 가되 선택 필드 `seedKey` 를 탈출구로 남긴다(선택 인자 추가는 승격 불필요) |
| **Q-21-4** | 팩 병합에서 "재정의 금지" 는 안전하지만 뻣뻣하다. 원작 대사의 오타를 생성 팩이 고칠 수 없다. 명시적 `overrides` 블록을 허용할 것인가? | 운영 편의 vs 추적성 | v1 은 금지 유지. 오타는 `core` 를 직접 고친다 |
| **Q-21-5** | `strings/ko.json` 이 팩당 단일 파일이면 대형 팩에서 diff 충돌이 잦다. `strings/ko/<owner_type>.json` 분할이 필요한가? | 작성 편의 | 2 MiB 상한에 도달하면 분할. 그 전까지 단일 |
| **Q-21-6** | `E15 change_tile` 의 변경분을 세이브에 쌓으면 세이브가 무한히 커질 수 있다. 상한을 둘 것인가? | 세이브 크기 | `mapDelta` 소유는 [BP-25](25_world_state_and_save.md)(D-22). 상한도 거기서 정한다. 참고: 현행 맵 스냅샷 세이브가 이미 570KB 급이라는 실측이 있다(부록 C-3) |
| **Q-21-7** | *(해소)* `enc` 를 콘텐츠 팩에 두면 `enemy_data.dart` 와 이중 관리가 된다 | 밸런싱 워크플로 | [BP-22 §7](22_world_bible_model.md) 권고안 A(코드 유지 + 생성 인덱스) + `R-21-55~57`(참조 전용 타입, 정수 정본, id 1~74)로 확정 |
| **Q-21-8** | `E15 change_tile` 이 **objUpper(B 타일)를 바꾸지 못한다**(`I-17`). "문을 열어 NPC 를 없앤다" 같은 앵커 연동 변화를 표현할 수 없다. `layer` 인자를 추가할 것인가? | 신규 콘텐츠 표현력 | v1 은 A5 전용(원작 재현에는 충분). `layer` 추가는 필수 인자 변경이므로 `schemaVersion` 승격 사항. **D-31 의 2 승격에는 포함하지 않았다** — 원작 재현에 필요하지 않고 승격을 한 번에 몰아넣을 이유가 없다. v3 후보 |
| **Q-21-9** | 원작 이동 구슬은 목적지를 플레이어가 고르는데 `warp(map,x,y)` 는 고정 목적지뿐이다 | 원작 아이템 이식 | v1 은 고정 목적지 워프 아이템만. 선택형 `warp_menu(placeIds)` 는 **v2 승격에 포함되지 않았고**(§7.2.1) 목적지 선택 UI 설계가 선행이다 → v3 후보 |
| **Q-21-10** | `R-21-41a` 의 폐포 계산은 대화 그래프·퀘스트 DAG 를 가로지르는 정적 분석이다. 조건 분기가 많으면 보수적 판정이 **오탐**을 낼 수 있다 | 빌드 게이트 신뢰도 | 보수적(over-approximation) 유지. 오탐이 실제로 문제되면 `_note` 가 아니라 **명시적 `allowDeferred: n` 필드**를 v2 에 검토 |
| **Q-21-11** | `E25 grant_buff` 는 스키마상 유효하지만 **`Effect` → `PartyBuffs` 다리가 아직 없다**(§6.6.3). `PartyBuffs` 는 `WorldState` 가 아니라 `HDParty` 안에 있어 어느 장도 그 연결을 소유하지 않는다 | 승격한 do 가 런타임 착지점 없이 존재 | 다리 태스크는 D-31 이 [BP-51](51_task_breakdown.md) 에 요구했다. 그 전까지 `grant_buff` 를 쓴 콘텐츠는 솔버 2축(D-26)의 **실행 가능 축에서 `UNSUPPORTED`** 로 잡혀야 한다 — 발행 지점 레지스트리와 같은 취급이며 판정은 [BP-34](34_headless_sim_and_solver.md) 소관 |
