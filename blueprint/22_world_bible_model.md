# 세계관 바이블 데이터 모델

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-22 · **상태**: 초안 · **선행 문서**: [BP-21](21_content_pack_spec.md)
> **독자**: 콘텐츠 작성자 · 생성 에이전트 작성자 · 린트 구현자
> **한 줄 요약**: 생성된 퀘스트가 서로 모순되지 않게 하는 **근거 데이터** — 세계 축·세력·장소·액터·아이템·인카운터를 스키마로 정의하고, 그 위에 린트가 검사할 일관성 규칙 20개를 얹는다.

**파이프라인 구획**(D-01): 이 장의 데이터는 **Authoring 입력**이자 **Build 검증 근거**다.
런타임은 바이블 원문을 읽지 않고, 빌드가 추린 부분(액터 이름, 장소 이름, 아이템 스탯)만 번들에서 읽는다.

**참조 관계**: 파일 위치·ID 문법·Condition/Effect DSL 은 [BP-21](21_content_pack_spec.md) 소관이다.
이 장은 그 위치에 들어갈 **필드 스키마**만 정의한다. 퀘스트/대화 내부 구조는
[BP-23](23_quest_model.md) / [BP-24](24_dialogue_model.md) 소관이며 여기서 재정의하지 않는다.

**이 장이 소유하지 *않는* 것** (D-18) — 아래는 링크만 하고 재서술하지 않는다.

| 주제 | 소유 장 |
|---|---|
| Condition/Effect DSL 시그니처, 꼬리 호출·지연 효과 규칙, ID 문법, 문자열 키 | [BP-21](21_content_pack_spec.md) |
| 월드 이벤트 12종 이름·**payload** | [BP-23 §23.11.1](23_quest_model.md) |
| **아이템 실제 데이터 · 인벤토리 게임 규칙 · 장비 마이그레이션** | [BP-42](42_item_and_inventory.md) |
| 문체 규칙(어미 사전·금지 표현 목록) | [BP-43](43_content_style_guide.md) |
| 전투 결과 코드의 정본(승/패/도주) | [BP-27](27_runtime_engine.md) |
| 세이브 포맷·`mapDelta`·마이그레이션 어휘 | [BP-25](25_world_state_and_save.md) |

> §6.4 의 레거시 대응표와 §6.5 의 아이템 시드 목록은 **BP-42 로 이관 예정인 초안**이다.
> BP-42 가 작성되면 이 장은 스키마만 남기고 데이터는 링크로 대체한다(D-18). 현재 BP-42 가
> 아직 없으므로(`I-14`) 근거 실측을 잃지 않기 위해 여기 보존한다.

**개정 이력**

| 판 | 반영 내용 |
|---|---|
| 2026-08-30 (2판) | 검수(REVIEW_BP-22 F-01~F-11 · S-01~S-05) · BP-90 `I-07`/`I-08`/`I-19`/`I-20` · D-18~D-26 · GROUND_TRUTH 부록 B-1 / B-2 / D / F-2 / F-4 / G-2 / H-1~H-4 를 반영해 개정 |
| **2026-08-30 (3판)** | **D-31 반영 — `I-20` 해소.** [BP-21](21_content_pack_spec.md) 이 `do` 를 22 → 25 로 확장하고 `schemaVersion` 을 2 로 올렸으므로, `R-22-18` 의 `_v1Unimplemented` 우회가 **원작 시드 8종 중 5종에서 해제**됐다(§6.5). SP 회복·해독·의식 회복·부활·`magicTorch` 버프가 정식 `effects` 를 갖는다 → **`R-22-18` 의 hard gate 위반이 그 5종에서 사라졌다.** 잔존 3종(소환 두루마리·수정 구슬·비행 부츠)의 사유를 개별 명시. `G-22-2` **해소** · `Q-22-4` **종결**. do 정의는 여전히 BP-21 소유이므로 이 장은 **링크만** 한다(D-18/D-25) |

---

## 1. 왜 바이블이 "데이터" 여야 하는가

### 1.1 산문 설정집의 한계

원작 설정은 지금 **대사 안에만** 존재한다. 실측 예:

| 설정 | 유일한 출처 | 형태 |
|---|---|---|
| Lord Ahn 이 로어성의 지배자이며 Necromancer 에게 밀리고 있다 | `assets/lore_ep1.cm2` 의 술집 취객 대사 | 자연어 문장 |
| Ancient Evil 은 배척 대상이지만 실제로는 자애로운 존재다 | `assets/lore_ep1.cm2` 의 수감자 대사(400자 이상 1줄) | 자연어 문장 |
| Red Antares 는 동굴에 은신한 최강의 마법사이며 동료로 영입 가능하다 | `assets/lore_ep1.cm2` 의 Jr. Antares 유골 이벤트 | 자연어 문장 |
| 황금의 방패가 MENACE 한가운데 숨겨져 있다 | `REF_UNITY_LoreEp1/src_as_cs/YunjrMap_T1.cs:840` | C# 문자열 리터럴 |
| MENACE 에는 Dwarf, Giant, Wolf, Python 이 산다 | `assets/lore_ep1.cm2` | 자연어 문장 |

이 상태에서 LLM 에게 "에피소드 1을 써라" 라고 하면, 프롬프트에 넣을 수 있는 것은
**대사 원문 덤프**뿐이다. 그러면 세 가지가 깨진다.

| 깨지는 것 | 증상 |
|---|---|
| 컨텍스트 예산 | cm2 원문 전량은 수십 KB. 매 생성마다 넣으면 예산을 다 쓴다 |
| 검증 가능성 | "생성된 NPC 가 Lord Ahn 을 우호적으로 말했는데 그 NPC 는 반체제 세력이다" 를 프로그램이 판정할 수 없다 |
| 재현성 | 같은 프롬프트가 다른 설정을 만들어 낸다. 에피소드 2가 에피소드 1과 모순된다 |

### 1.2 바이블의 두 가지 소비자

```
world/*.json + actors/*.json + items/items.json
        │
        ├─► 1단계 context (D-14): 프롬프트 컨텍스트 팩의 재료
        │     → 생성 에이전트가 "이 세계에서 말이 되는" 것만 쓰게 만든다
        │
        └─► 5단계 lint (D-14): 정적 검사의 근거
              → 생성물이 세계와 모순되면 커밋 전에 잡는다
```

- **R-22-1** 바이블은 **생성 입력이자 검증 기준**이다. 둘이 같은 파일이어야 "프롬프트에 넣은 규칙"과
  "린트가 검사하는 규칙"이 갈라지지 않는다. (D-12 가 평가기 공유를 요구하는 것과 같은 논리)
- **R-22-2** 바이블에 없는 고유명사를 생성물이 도입하면 린트 경고. 도입하려면 **먼저 바이블에 추가**해야 한다.
  이것이 "생성 → 검증" 루프를 닫는 핵심 규칙이다.
- **R-22-3** 바이블 파일의 `_` 접두 필드(`_toneHint`, `_summary`, `_promptNote`)는 게임에 표시되지 않고
  **프롬프트 전용**이다. 따라서 [BP-21 §5.1](21_content_pack_spec.md) 의 인라인 텍스트 금지 예외다.

---

## 2. `world/lore.json` — 세계 축·연대기·톤

### 2.1 최상위 필드

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `schemaVersion` | int | ✅ | 팩의 `schemaVersion` 과 일치해야 함 |
| `pack` | string | ✅ | 소유 팩 id |
| `axes` | object | ✅ | 세계 축 (§2.2) |
| `chronicle` | object[] | ✅ | 연대기 사건 목록 (§2.3) |
| `tone` | object | ✅ | 톤 규정 (§2.4) |
| `taboos` | object[] | ⬜ | 금기 목록 (§2.5) |
| `_promptNote` | string | ⬜ | 컨텍스트 팩에 그대로 실릴 보조 지시 |

### 2.2 `axes` — 세계 축

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `premise` | string | ✅ | 세계 전제 1~3문장 |
| `era` | string | ✅ | 시대 |
| `techLevel` | enum | ✅ | `medieval` \| `medieval_with_relics` \| `cyber_fantasy` |
| `magicRules` | string[] | ✅ | 마법이 되는 것/안 되는 것 |
| `conflicts` | object[] | ✅ | 갈등축. `{id, name, sides:[factionId], stake, status}` |
| `mysteries` | object[] | ⬜ | 미해결 떡밥. `{id, question, revealedBy?}` |

```json
{
  "schemaVersion": 1,
  "pack": "core",
  "axes": {
    "premise": "로어 대륙은 Lord Ahn 의 질서 아래 오래 유지되어 왔으나, 바다에서 떠오른 '또 다른 지식의 성전'과 함께 나타난 Necromancer 에게 밀리고 있다.",
    "era": "질서의 황혼기",
    "techLevel": "medieval_with_relics",
    "magicRules": [
      "마법은 SP, 초능력(ESP)은 ESP 를 소모한다. 두 자원은 별개다.",
      "죽은 자의 목소리는 유골 앞에서만 들린다.",
      "성전(피라밋)의 지식은 일정 수준에 이른 자에게만 열린다."
    ],
    "conflicts": [
      {
        "id": "lore.core.conflict_necromancer",
        "name": "Lord Ahn 대 Necromancer",
        "sides": ["faction.core.lore_order", "faction.core.necromancer_host"],
        "stake": "로어 대륙의 존속",
        "status": "escalating"
      },
      {
        "id": "lore.core.conflict_ancient_evil",
        "name": "Ancient Evil 을 둘러싼 교리 분열",
        "sides": ["faction.core.lore_order", "faction.core.ancient_evil_cult"],
        "stake": "로어성 내부의 사상 통제",
        "status": "suppressed"
      }
    ],
    "mysteries": [
      {
        "id": "lore.core.mystery_why_suppress",
        "question": "Lord Ahn 은 Ancient Evil 의 실체를 인정하면서 왜 배격만 가르치는가?",
        "revealedBy": null
      }
    ]
  }
}
```

### 2.3 `chronicle` — 연대기

**이 배열이 지식 범위(§5.4) 검사의 시간축**이다. 액터가 "아직 일어나지 않은 사건" 을 말하면
린트가 잡는 근거가 여기서 나온다.

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `id` | lore id | ✅ | `lore.<pack>.<slug>` |
| `order` | int | ✅ | 시간 순서. 팩 전체에서 유일. 값의 절대치는 무의미, 대소만 의미 |
| `title` | string key | ✅ | 표시명 |
| `_summary` | string | ✅ | 프롬프트용 요약(게임 미표시) |
| `visibility` | enum | ✅ | `public`(누구나 안다) \| `regional`(특정 장소/세력만) \| `secret`(특정 액터만) |
| `knownBy` | string[] | ⬜ | `visibility != public` 일 때 필수. faction id / place id / npc id 혼합 허용 |
| `gatedBy` | Condition | ⬜ | 플레이 중 이 사건이 "공개"되는 조건. 없으면 게임 시작 시점에 이미 과거 |
| `places` | place id[] | ⬜ | 사건이 벌어진 장소 |
| `actors` | npc id[] | ⬜ | 관련 인물 |

```json
"chronicle": [
  { "id": "lore.core.founding_of_lore", "order": 100,
    "title": "str.core.lore.founding_of_lore.title",
    "_summary": "로어성이 세워지고 Lord Ahn 의 질서가 시작됨.",
    "visibility": "public", "places": ["place.core.lore_castle"] },

  { "id": "lore.core.temple_rises", "order": 800,
    "title": "str.core.lore.temple_rises.title",
    "_summary": "바다에서 '또 다른 지식의 성전'이 떠오름. 같은 시기 Necromancer 가 나타남.",
    "visibility": "regional", "knownBy": ["place.core.lore_castle"],
    "places": ["place.core.temple_of_knowledge"] },

  { "id": "lore.core.antares_vanishes", "order": 850,
    "title": "str.core.lore.antares_vanishes.title",
    "_summary": "최강의 마법사 Red Antares 가 어느 동굴로 은신한 뒤 모습을 감춤.",
    "visibility": "secret", "knownBy": ["npc.core.jr_antares_remains"],
    "actors": ["npc.core.red_antares"] },

  { "id": "lore.core.knight_imprisoned", "order": 900,
    "title": "str.core.lore.knight_imprisoned.title",
    "_summary": "Ancient Evil 의 실상을 퍼뜨린 기사가 로어성 수용소에 갇힘.",
    "visibility": "secret", "knownBy": ["place.core.lore_prison", "faction.core.ancient_evil_cult"],
    "places": ["place.core.lore_prison"] }
]
```

- **R-22-4** `order` 는 팩 안에서 유일해야 하고, 팩 간에는 `pack.json#dependsOn` 순서로 정렬한 뒤
  `order` 로 정렬한다. 즉 `gen_ep1` 의 사건은 항상 `core` 사건 뒤에 온다.
- **R-22-5** 생성 팩은 `core` 의 `chronicle` 항목을 **수정할 수 없고 추가만 할 수 있다**([BP-21 §4.7](21_content_pack_spec.md)).

### 2.4 `tone` — 톤 규정

| 필드 | 타입 | 의미 |
|---|---|---|
| `register` | enum | `archaic_polite`(원작 기본: "…하시오", "…이오") \| `plain` \| `modern` |
| `person` | enum | 화자 시점. `second_person_party`(원작: 파티를 "당신들") |
| `sentenceLength` | object | `{avg:int, max:int}` 권장 문장 길이(글자) |
| `allowedRegisters` | string[] | 예외 허용 어투(취객, 어린이 등) |
| `forbidden` | string[] | 금지 표현(현대 용어, 이모지, 영문 약어 등) |
| `properNounStyle` | enum | `latin_kept` — 원작대로 `Necromancer`, `Lord Ahn` 등은 로마자 유지 |

```json
"tone": {
  "register": "archaic_polite",
  "person": "second_person_party",
  "sentenceLength": { "avg": 45, "max": 200 },
  "allowedRegisters": ["drunk_slur", "child_plain", "guard_curt"],
  "forbidden": ["이모지", "현대 IT 용어", "영문 약어(NPC/HP/MP 등 UI 밖)", "메타 농담"],
  "properNounStyle": "latin_kept"
}
```

- 근거: 원작 대사는 `Necromancer`, `MENACE`, `LORE`, `Lord Ahn`, `Ancient Evil` 을 **로마자 그대로**
  쓰고 서술은 `~하시오/~이오` 체다(`assets/lore_ep1.cm2` 실측).
- **주의**: 현행 `assets/town1.cm2` 에는 휴대폰 보조금 뉴스, `assets/Map002.cm2` 에는 "삶은 계란"
  말장난 같은 **개발 테스트용 더미 대사**가 남아 있다. 이들은 톤 규정 대상이 아니라
  **마이그레이션에서 폐기**한다([BP-28](28_migration_and_coexistence.md)).

### 2.5 `taboos` — 금기

| 필드 | 타입 | 의미 |
|---|---|---|
| `id` | string | 금기 식별자 |
| `rule` | string | 금기 내용 |
| `severity` | enum | `hard`(하드 실패) \| `soft`(경고) |
| `detect` | object | 검출 힌트. `{keywords:[string], scope:"all"\|"dialogue"\|"journal"}` |

```json
"taboos": [
  { "id": "taboo.core.no_modern_tech", "rule": "현대 기술·브랜드·시사를 언급하지 않는다.",
    "severity": "hard", "detect": { "keywords": ["휴대폰", "보조금", "이통사", "인터넷"], "scope": "all" } },
  { "id": "taboo.core.lord_ahn_not_dead", "rule": "Lord Ahn 의 사망을 확정 서술하지 않는다. 결말 권한은 core 에만 있다.",
    "severity": "hard", "detect": { "keywords": ["Lord Ahn 이 죽", "Lord Ahn 의 죽음"], "scope": "all" } },
  { "id": "taboo.core.no_meta", "rule": "게임·플레이어·저장 같은 메타 표현을 대사에 쓰지 않는다.",
    "severity": "soft", "detect": { "keywords": ["세이브", "플레이어", "게임"], "scope": "dialogue" } }
]
```

---

## 3. `world/factions.json` — 세력

### 3.1 스키마

| 필드 | 타입 | 필수 | 기본값 | 의미 |
|---|---|---|---|---|
| `id` | faction id | ✅ | — | `faction.<pack>.<slug>` |
| `name` | string key | ✅ | — | 표시명 |
| `desc` | string key | ⬜ | — | 설명(저널·도감용) |
| `_summary` | string | ✅ | — | 프롬프트용 1~2문장 |
| `alignment` | enum | ✅ | — | `order` \| `chaos` \| `neutral` \| `hidden` |
| `scale` | enum | ✅ | — | `continental` \| `regional` \| `local` \| `cell` |
| `relations` | object | ✅ | `{}` | `{<factionId>: -3..3}` — 음수=적대, 0=무관심, 양수=우호 |
| `places` | place id[] | ⬜ | `[]` | 근거지 |
| `leaders` | npc id[] | ⬜ | `[]` | 지도자 |
| `_toneHint` | string | ✅ | — | 이 세력 NPC 의 말투 지침 (프롬프트용) |
| `openTopics` | string[] | ⬜ | `[]` | 이 세력이 **먼저 꺼내는** 화제 |
| `closedTopics` | string[] | ⬜ | `[]` | 이 세력이 **말하지 않는** 화제 |
| `_aliases` | string[] | ⬜ | `[]` | **별칭 사전**(§5.4.1). 린트의 고유명사 매칭 원천 |

### 3.2 관계 값 척도

| 값 | 의미 | 대사에서의 표현 |
|---|---|---|
| `-3` | 교전 중 | 이름을 부르며 저주. 조우 시 즉시 전투 가능 |
| `-2` | 적대 | 경멸·경계 |
| `-1` | 불신 | 냉담, 화제 회피 |
| `0` | 무관심 | 중립 서술 |
| `+1` | 우호 | 협조적 |
| `+2` | 동맹 | 우리 편으로 지칭 |
| `+3` | 동일체 | 사실상 같은 조직 |

- **R-22-6** `relations` 는 **비대칭을 허용**한다(A→B 는 -2, B→A 는 0 가능). 짝사랑·일방적 적대가 존재하므로.
  단 `-3` 과 `+3` 은 대칭이어야 한다(교전과 동일체는 상호적). 위반 시 린트 경고.

### 3.3 초기 `core` 세력 데이터 초안

원작 대사에서 실제로 확인되는 것만 넣었다(실측 출처 명시).

| id | 이름 | alignment | scale | 근거 |
|---|---|---|---|---|
| `faction.core.lore_order` | 로어 질서(Lord Ahn 체제) | `order` | `continental` | `lore_ep1.cm2` "우리는 Ancient Evil을 배척하고 Lord Ahn님을 받들어야 합니다." |
| `faction.core.lore_commoner` | 로어 성민 | `neutral` | `regional` | 주점·시장 NPC 다수 |
| `faction.core.lore_guard` | LORE 특공대 | `order` | `regional` | `lore_ep1.cm2` "그들은 모두 이 대륙의 평화를 위해 LORE 특공대에 지원 했다네." |
| `faction.core.necromancer_host` | Necromancer 군세 | `chaos` | `continental` | 29회 언급(전 cm2 실측) |
| `faction.core.ancient_evil_cult` | Ancient Evil 신봉자 | `hidden` | `cell` | `lore_ep1.cm2` 수감된 기사 대사 |
| `faction.core.antares_line` | Antares 혈통 | `neutral` | `local` | `lore_ep1.cm2` Jr. Antares / Red Antares |
| `faction.core.lastditch` | 라스트디치 성 | `order` | `regional` | `lore_ep1.cm2` "LASTDITCH 성에서 성문을 지키고 있는 Polaris" |
| `faction.core.menace_dwellers` | 메너스 서식종 | `chaos` | `local` | `lore_ep1.cm2` "'MENACE' 속에는 Dwarf, Giant, Wolf, Python같은 괴물들이 살고 있소." |
| `faction.core.skeleton_kin` | Skeleton 족 | `neutral` | `cell` | `lore_ep1.cm2` "Skeleton족의 한 명이 우리와 함께 생활하려 한다는 것" |

```json
{
  "id": "faction.core.ancient_evil_cult",
  "name": "str.core.faction.ancient_evil_cult.name",
  "_summary": "Ancient Evil 의 실상을 목격하고 그 사상을 퍼뜨리다 로어성에 잡힌 소수. 조직이라기보다 개별 목격자들의 느슨한 고리.",
  "alignment": "hidden",
  "scale": "cell",
  "relations": {
    "faction.core.lore_order": -1,
    "faction.core.lore_commoner": 0,
    "faction.core.necromancer_host": -2
  },
  "places": ["place.core.lore_prison"],
  "leaders": [],
  "_toneHint": "확신에 차 있으나 조심스럽다. 단정하지 않고 '내가 본 것은' 이라는 목격담 화법을 쓴다. Lord Ahn 을 비난하지 않고 이해할 수 없어 한다.",
  "openTopics": ["ancient_evil_true_nature", "why_lore_suppresses"],
  "closedTopics": ["necromancer_alliance"]
}
```

---

## 4. `world/places.json` — 장소

### 4.1 장소와 맵은 1:N

- 한 맵에 여러 장소가 있다(로어성 맵 안에 주점·수용소·납골당).
- 한 장소가 여러 맵에 걸치지는 **않는다**(1 place → 1 map). 걸치는 것처럼 보이면 두 장소로 나누고
  `adjacent` 로 잇는다.
- 좌표 없는 장소(아직 배치되지 않은 전설의 장소)도 허용한다 — `map: null`.

### 4.2 스키마

| 필드 | 타입 | 필수 | 기본값 | 의미 |
|---|---|---|---|---|
| `id` | place id | ✅ | — | `place.<pack>.<slug>` |
| `name` | string key | ✅ | — | 표시명 |
| `desc` | string key | ⬜ | — | 저널·지도 설명 |
| `_summary` | string | ✅ | — | 프롬프트용 |
| `map` | string \| null | ✅ | — | `MapInfos.json#name`. `null` = 미배치 |
| `regions` | object[] | ⬜ | `[]` | 영역 rect 목록 (§4.3) |
| `kind` | enum | ✅ | — | `town` \| `dungeon` \| `field` \| `keep` \| `interior` \| `landmark` |
| `mapType` | int | ⬜ | `kind` 에서 유도 | `HDTileProperties.TYPE_*` (0 TOWN / 1 KEEP / 2 GROUND / 3 DEN) |
| `mood` | string[] | ✅ | — | 분위기 태그 (§4.4) |
| `faction` | faction id \| null | ✅ | — | 소속 세력 |
| `adjacent` | object[] | ⬜ | `[]` | 인접 장소 그래프 (§4.5) |
| `danger` | int 0..5 | ✅ | — | 위험도 (§4.6) |
| `encounterRate` | int 0..10 | ⬜ | `danger*2` | `HDParty.encounter` 로 넘길 조우율 |
| `encounters` | enc id[] | ⬜ | `[]` | 이 장소에서 나오는 인카운터 |
| `lightLevel` | enum | ⬜ | `kind` 에서 유도 | `bright` \| `dim` \| `dark` — 맵 shadow 레이어 규약과 대응 |
| `_toneHint` | string | ⬜ | — | 이 장소 서술의 분위기 지침 |
| `_aliases` | string[] | ⬜ | `[]` | **별칭 사전**(§5.4.1) |

### 4.3 `regions` — 영역

```json
"regions": [ { "x": 8, "y": 24, "w": 14, "h": 16, "_note": "주점 1층" } ]
```

- 좌표계는 맵 JSON 과 동일하게 **0-based, x=열, y=행**([BP-26 §2](26_entity_registry_and_anchors.md) 와 같은 규약).
- `regions` 가 비면 **맵 전체**를 뜻한다.

#### 4.3.1 중첩 규칙 — **`kind` 계층으로 판정한다** (REVIEW_BP-22 `F-03` 해소)

초판 R-22-7 은 "같은 맵의 두 장소 rect 가 겹치면 하드 실패" 였는데, 이 장이 제시한 `core` 초안
(§4.7)이 그 규칙을 **스스로 위반**했다. `place.core.lore_castle` 이 `TOWN1` **전체**를 차지하고
주점·수용소·납골당 셋이 그 안에 들어 있기 때문이다. "주점이 성 안에 있다" 는 관계는 **정상적인 서술**이므로,
규칙 쪽이 틀렸다.

**확정: `kind` 를 2계층으로 나누고, 계층이 다르면 겹침을 허용한다.**

| 계층 | `kind` | 성격 | 겹침 규칙 |
|---|---|---|---|
| **컨테이너** | `town`, `dungeon`, `field`, `keep` | 맵의 큰 구역. `regions` 생략 시 맵 전체 | 컨테이너끼리는 **겹침 금지**(hard) |
| **구역** | `interior`, `landmark` | 컨테이너 안의 방·시설·지형지물 | 구역끼리는 **겹침 금지**(hard). 컨테이너와는 **겹침 허용** |

- **R-22-7** (개정) 같은 맵에서 **같은 계층**의 두 장소 rect 가 겹치면 하드 실패.
  **다른 계층**(컨테이너 ⊃ 구역)의 겹침은 정상이며, 그때 구역은 자기를 감싸는 컨테이너에
  **암묵적으로 소속**된다.
- **R-22-7a** 구역이 어떤 컨테이너에도 감싸이지 않으면 린트 경고(떠 있는 구역).
- **R-22-7b** 명시적 `parent` 필드는 v1 에 **도입하지 않는다.** 포함 관계는 rect 로 계산되며,
  계산 결과를 `content.index.json` 이 `containedBy` 로 굽는다(BP-35). 이유: 좌표와 소속을
  두 곳에 적으면 어긋난다 — 앵커가 좌표 결합을 없앤 것과 같은 논리다.
- **Q-22-3 은 이것으로 해소된다.** (열린 질문 목록에서 해소 표시)

### 4.4 `mood` 태그 (권장 집합 — 열린 집합 + 경고)

`solemn`, `bustling`, `desolate`, `oppressive`, `sacred`, `squalid`, `hostile`, `hidden`,
`festive`, `mournful`, `industrial`, `wild`

- **R-22-8** 태그는 **권장 집합**이다(초판은 제목에 "닫힌 집합" 이라 적고 본문은 열린 집합처럼 서술해
  모순이었다 — REVIEW_BP-22 `S-05`). 새 태그는 `schemaVersion` 승격 없이 쓸 수 있고,
  린트가 "미등록 mood" 를 **경고**한다. 하드 실패가 아니다.

### 4.5 `adjacent` — 장소 그래프

```json
"adjacent": [
  { "to": "place.core.lore_continent", "via": "portal", "anchor": "anchor.core.town1_gate_south" },
  { "to": "place.core.lore_prison",    "via": "walk" }
]
```

| `via` | 의미 |
|---|---|
| `walk` | 같은 맵 안에서 걸어서 이동 가능 |
| `portal` | ENTER 타일/앵커를 통한 맵 전환. `anchor` 필수 |
| `script` | 스크립트/이벤트로만 이동(원작 `LoadScript` 류) |
| `locked` | 조건 충족 전에는 불가. `when: Condition` 필수 |

- **R-22-9** `adjacent` 는 **양방향 선언을 요구하지 않는다**(일방통행 존재). 단 `via: "walk"` 는
  대칭이어야 하며 린트가 비대칭을 경고한다.
- **R-22-10** 장소 그래프는 퀘스트 솔버(D-13)가 "이 목표에 도달 가능한가" 를 푸는 지도다.
  `reach` 목표([BP-23](23_quest_model.md))가 place 를 가리키면 솔버가 이 그래프를 탐색한다.

### 4.6 `danger` 척도

| 값 | 의미 | 권장 파티 레벨 | 대표 인카운터 레벨 |
|---|---|---|---|
| 0 | 안전지대(마을 내부) | — | 없음 |
| 1 | 외곽 | 1~3 | 1~4 |
| 2 | 야외 | 3~7 | 4~9 |
| 3 | 던전 상층 | 7~12 | 9~15 |
| 4 | 던전 심층 | 12~18 | 15~22 |
| 5 | 최종 구역 | 18+ | 22~30 |

- 매핑 근거: `hadar2026_app/lib/domain/battle/enemy_data.dart` 의 `level` 필드가 1~30 범위이고
  (id 1 `Troll` lv1 → id 74 `Neo-Necromancer` lv30 — id 0 `Orc` 는 소환 불가, 부록 B-1),
  파티 exp 테이블은 엔트리 21개이며 **도달 가능한 최대 레벨은 20**이다
  (`hadar2026_app/lib/domain/party/player.dart:167`, 승급 루프가 `level.physical < expTable.length - 1`).
  따라서 아래 표 5행의 "18+" 는 실제로 **18~20 의 3레벨 폭**이다(REVIEW_BP-22 `S-03`).

### 4.7 초기 `core` places 데이터 초안

현행 맵 데이터와 원작 고유명사를 실제로 매핑한 것이다.

| place id | 표시명 | map(이름) | 실제 파일 | regions | kind | mood | faction | danger | 근거 |
|---|---|---|---|---|---|---|---|---|---|
| `place.core.lore_castle` | 로어성 | `TOWN1` | `TOWN1.json` (100×100, `displayName:"로어성"`) | 전체(컨테이너) | `town` | solemn, bustling | `lore_order` | 0 | 파일 실측 |
| `place.core.lore_tavern` | LORE 주점 | `TOWN1` | 동일 | `(8,24,14,16)` 구역 | `interior` | bustling, mournful | `lore_commoner` | 0 | `lore_ep1.cm2` "여기는 LORE 주점입니다." 좌표 (12,26)(17,26)(20,32)(12,31)(14,34)(17,32)(20,35)(17,37) |
| `place.core.lore_prison` | 로어성 수용소 | `TOWN1` | 동일 | `(38,5,18,10)` 구역 | `interior` | oppressive, hidden | `lore_order` | 0 | `lore_ep1.cm2` 좌표 (40,9)(49,10)(52,10) |
| `place.core.lore_crypt` | 용사 납골당 | `TOWN1` | 동일 | `(58,70,18,16)` 구역 | `interior` | sacred, mournful | `lore_order` | 0 | `lore_ep1.cm2` 좌표 (62,75)(71,77), Jr. Antares 유골 이벤트 |
| `place.core.lore_continent` | 로어 대륙 | `GROUND1` | `GROUND1.json` (100×100, `displayName:"로어 대륙"`) | 전체 | `field` | wild | `null` | 2 | 파일 실측 |
| `place.core.menace` | 메너스 | `DEN1` | `DEN1.json` (50×50, `displayName:"메너스"`) | 전체 | `dungeon` | hostile, industrial | `menace_dwellers` | 3 | 파일 실측 + `ground1.cm2` "MENACE에 들어가시겠습니까?" |
| `place.core.menace_deep` | 메너스 심층 | `DEN2` | `DEN2.json` (53×53, `displayName:"53x53"` — 미설정) | 전체 | `dungeon` | hostile, desolate | `menace_dwellers` | 4 | 파일 실측 |
| `place.core.lastditch` | 라스트디치 | `LastDitch` | `Map015.json` (75×75, `displayName:"라스트디치"`) | 전체 | `keep` | solemn, desolate | `lastditch` | 2 | 파일 실측 + `lore_ep1.cm2` "LASTDITCH 성에서 성문을 지키고 있는 Polaris" |
| `place.core.lore_continent_v2` | 로어 대륙(신판) | `LoreContinent` | `Map013.json` (100×100, `displayName:"로어 대륙"`) | 전체 | `field` | wild | `null` | 2 | 파일 실측. `GROUND1` 의 재작업본으로 추정 → Q-22-1 |
| `place.core.lore_castle_v2` | 로어성(신판) | `CastleLore` | `Map014.json` (100×100, `displayName:"로어성"`) | 전체 | `town` | solemn | `lore_order` | 0 | 파일 실측. `TOWN1` 의 재작업본으로 추정 → Q-22-1 |
| `place.core.temple_of_knowledge` | 또 다른 지식의 성전 | `null` | — | — | `landmark` | sacred, hidden | `null` | 5 | `lore_ep1.cm2` "이 성의 바로위에 있는 피라밋… '@B또다른 지식의 성전@@'" — **맵 미제작** |
| `place.core.antares_cave` | Red Antares 의 동굴 | `null` | — | — | `dungeon` | hidden, sacred | `antares_line` | 4 | `lore_ep1.cm2` "그는 말년에 어떤 동굴로 은신을 한 후" — **맵 미제작** |
| `place.core.prolog_surface` | 프롤로그: 지상 | `Prolog_B1` | `Map010.json` (65×82, 이벤트 8) | 전체 | `dungeon` | wild | `null` | 1 | 파일 실측. 이벤트 note 에 "의뢰인1", "의뢰인의 조수" |
| `place.core.prolog_cave` | 프롤로그: 동굴 | `Prolog_B2` | `Map011.json` (53×52, 이벤트 9) | 전체 | `dungeon` | dim, hostile | `null` | 2 | 파일 실측 |
| `place.core.lore_ep_town` | LORE_EP 시가 | `LORE_EP` | `Map002.json` (50×50, 이벤트 18) | 전체(컨테이너) | `town` | bustling | `lore_commoner` | 0 | 파일 실측. TALK001 note="로드안" |

**중첩 검증** (§4.3.1): `TOWN1` 위의 4개 장소 중 컨테이너는 `lore_castle` 하나이고 나머지 셋은 구역이다.
구역끼리 겹치는 쌍은 없다 — `(8,24,14,16)` / `(38,5,18,10)` / `(58,70,18,16)` 은 x·y 범위가 서로 분리된다.
따라서 이 초안은 개정된 `R-22-7` 을 **통과**한다(초판 규칙에서는 3쌍이 하드 실패였다).

**⚠ 이 표가 드러낸 실제 결함 (G-22-1)**

`HDMapNavigation.loadByName` 은 `MapInfos.json` 에서 이름을 찾아 `Map${id:03d}.json` 으로 해석한다
(`hadar2026_app/lib/application/map_navigation.dart:43` — `:30` 이 폴백 `'<이름>.json'` 을 먼저 세우고
`:43` 이 그것을 덮어쓴다). 그런데 실측 결과:

**전 15개 엔트리 판정** (GROUND_TRUTH 부록 D-1 전량):

| MapInfos 이름 | id | 해석되는 파일 | 존재? | `<이름>.json` 존재? | 판정 |
|---|---|---|---|---|---|
| `Test` | 1 | `Map001.json` | ✅ | ❌ | OK |
| `LORE_EP` | 2 | `Map002.json` | ✅ | ❌ | OK |
| `MAP003` | 3 | `Map003.json` | ✅ | ✅ | OK |
| **`TOWN1`** | 4 | `Map004.json` | ❌ | **✅** | **깨짐** |
| **`GROUND1`** | 5 | `Map005.json` | ❌ | **✅** | **깨짐** |
| **`DEN1`** | 6 | `Map006.json` | ❌ | **✅** | **깨짐** |
| **`DEN2`** | 7 | `Map007.json` | ❌ | **✅** | **깨짐** |
| `Template_TOWN` | 8 | `Map008.json` | ❌ | ❌ | 깨짐 |
| `Prolog` | 9 | `Map009.json` | ❌ | ❌ | 깨짐 |
| `Prolog_B1` | 10 | `Map010.json` | ✅ | ❌ | OK |
| `Prolog_B2` | 11 | `Map011.json` | ✅ | ❌ | OK |
| `Template_DUNGEON` | 12 | `Map012.json` | ❌ | ❌ | 깨짐 |
| `LoreContinent` | 13 | `Map013.json` | ✅ | ❌ | OK |
| `CastleLore` | 14 | `Map014.json` | ✅ | ❌ | OK |
| `LastDitch` | 15 | `Map015.json` | ✅ | ❌ | OK |

**해석 성공 8 / 실패 7.**

**핵심 역설 — 등록이 오히려 폴백을 죽인다.** `TOWN1`/`GROUND1`/`DEN1`/`DEN2` 는 **동명 파일이 실제로 존재**한다.
이름이 `MapInfos.json` 에 등록되어 있지 **않았다면** 폴백(`map_navigation.dart:30` 의 `'<이름>.json'`)이
살아남아 정상 로드되었을 것이다. 즉 **인덱스에 등록하는 행위가 맵을 로드 불가로 만든다.**
직접 증거는 부록 F-4: **미등록인 `ORIGIN` 은 `ORIGIN.json` 으로 정상 로드된다.**

로드는 실패하지만 실패로 보고되지도 않는다(부록 D-2): 부록 A-1 때문에 `cm2Path` 는 항상 non-null 이라
`map_navigation.dart:66-73` 이 에러를 반환하지 않고 `MapBundle(json: null)` 을 **성공으로** 돌려준다.
`HDGameSession.loadMapFromFile:97-99` 는 `bundle.json != null` 일 때만 `setNewMap` 을 호출하므로
**맵은 그대로인 채 스크립트만 교체되고 함수는 `true` 를 반환한다.**

**파급 2건 (이 장의 places 모델이 전제해야 하는 것)**

| # | 사실 | places 모델에 대한 함의 |
|---|---|---|
| 부록 F-2 | `game_session.dart:97-128` 은 `bundle.json == null` 이어도 `mapScriptFactory[bundle.mapName]` 이 있으면 네이티브 스크립트를 붙인다. `TOWN1` 로드 시 `Town1MapScript` 가 **직전 맵 위에 부착**되고 그 `isOn(x,y)` 는 **다른 맵의 좌표**를 평가한다 | `place.map` 이 해석 실패하면 장소·앵커·좌표가 **다른 맵을 가리킨 채로 동작**한다. `R-22-11` 이 hard 여야 하는 직접 근거 |
| 부록 G-2 | `mapScriptFactory` 는 `TOWN1`·`GROUND1`·`TOWN2`·`DEN1` 4종을 등록하지만 `TOWN2` 는 `MapInfos.json` 에도 없고 `assets/maps/TOWN2.json` 파일도 없다 → **한 번도 실행된 적 없는 코드** | 초기 places 초안에 `TOWN2` 대응 장소를 두지 않는다. 맵이 생기면 그때 추가 |

- **R-22-11** places 의 `map` 필드는 `MapInfos.json#name` 을 가리키며, 빌드는 그 이름이
  **실제 파일로 해석되는지** 검사한다. 해석 실패는 하드 실패다.
- **T-22-1** `MapInfos.json` 의 **7개 깨진 엔트리**에 `"json": "TOWN1.json"` 등을 추가한다.
  코드는 이미 이 필드를 지원한다(`hadar2026_app/lib/application/map_navigation.dart:45`).
  **데이터만 고치면 된다.**
  - 맵 에디터의 `registerAs` 는 **이미 `json` 필드를 쓴다**(`tools/mapEditor/server/ai_api.ts:592`, 부록 H-4).
    즉 신규 맵은 올바르게 등록되고 **수리 대상은 기존 15개 엔트리뿐**이다.
  - T-22-1 은 [BP-21 `R-21-7`/`C14`/`E14`](21_content_pack_spec.md)(`CV-07`),
    [BP-26 `A-26-03`](26_entity_registry_and_anchors.md), [BP-34](34_headless_sim_and_solver.md) 시뮬레이터의
    **공통 선행 의존**이다.

---

## 5. `actors/<slug>.json` — 액터

### 5.1 스키마

| 필드 | 타입 | 필수 | 기본값 | 의미 |
|---|---|---|---|---|
| `id` | npc id | ✅ | — | `npc.<pack>.<slug>`. 파일명과 슬러그 일치 필수 |
| `type` | `"actor"` | ✅ | — | 판별자 |
| `pack` | string | ✅ | — | 소유 팩 |
| `name` | string key | ✅ | — | 표시 이름 |
| `title` | string key | ⬜ | — | 직함 |
| `faction` | faction id \| null | ✅ | — | 소속 |
| `place` | place id | ✅ | — | 상주 장소 |
| `role` | enum | ✅ | — | §5.2 |
| `traits` | string[] | ✅ | — | 성격 태그 (§5.3, 2~5개) |
| `knowledge` | object | ✅ | — | **지식 범위** (§5.4) |
| `defaultDialogue` | dlg id \| null | ✅ | — | 조건에 걸리는 대화가 없을 때 |
| `dialogueRouting` | object[] | ⬜ | `[]` | 조건부 대화 라우팅 (§5.5) |
| `states` | object[] | ✅ | — | `npcState` 값 집합 (§5.6). 최소 1개 |
| `initialState` | string | ✅ | — | `states[].id` 중 하나 |
| `sprite` | object | ⬜ | — | 스프라이트 참조 (§5.7) |
| `mortal` | bool | ⬜ | `true` | 사망 가능 여부 |
| `recruitable` | bool | ⬜ | `false` | 동료 영입 가능 여부(D-16 선택 항목) |
| `_summary` | string | ✅ | — | 프롬프트용 1~2문장 |
| `_voice` | string | ✅ | — | 말투 지침 (프롬프트용) |
| `_aliases` | string[] | ⬜ | `[]` | **별칭 사전**(§5.4.1) |

### 5.2 `role` (닫힌 집합)

`guard`, `commoner`, `merchant`, `scholar`, `priest`, `noble`, `soldier`, `prisoner`,
`innkeeper`, `wanderer`, `spirit`, `beast`, `boss`, `child`, `quest_giver`, `informant`

### 5.3 `traits` (닫힌 집합)

`stern`, `warm`, `fearful`, `proud`, `bitter`, `curious`, `secretive`, `garrulous`,
`drunk`, `devout`, `cynical`, `loyal`, `greedy`, `grieving`, `naive`, `weary`

### 5.4 `knowledge` — **지식 범위 (이 문서의 핵심)**

문제: LLM 은 "그럴듯한" 대사를 쓴다. 그래서 성문 위병이 아직 아무도 모르는 학자의 실종을 알고 있거나,
주점 취객이 던전 최심부의 보스 이름을 말한다. 사람이 읽으면 어색하지만 **프로그램은 판정할 수 없다.**

해결: 액터마다 **무엇을 아는가 / 무엇을 모르는가**를 선언한다. 린트는 대사에 등장하는 고유명사·
사건 ID 를 이 집합과 대조한다.

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `knows` | string[] | ✅ | 아는 것. lore id / place id / npc id / faction id / item id / `topic:<slug>` 혼합 |
| `unknown` | string[] | ✅ | **명시적으로 모르는 것**. 여기 있는 것을 말하면 하드 실패 |
| `rumorOnly` | string[] | ⬜ | 소문 수준으로만 안다. 단정 서술 시 경고 |
| `learnsWhen` | object[] | ⬜ | `{ "subject": <id>, "when": Condition }` — 조건 충족 후 `knows` 에 편입 |
| `scopeDefault` | enum | ⬜ | `strict`(선언 밖은 전부 모름, 기본) \| `public`(`visibility:"public"` 연대기는 자동으로 앎) |

```json
"knowledge": {
  "scopeDefault": "public",
  "knows": [
    "place.core.lore_castle",
    "place.core.lore_continent",
    "faction.core.lore_order",
    "npc.core.lord_ahn",
    "lore.core.founding_of_lore",
    "topic:gate_duty",
    "topic:monster_sightings"
  ],
  "unknown": [
    "place.core.temple_of_knowledge",
    "place.core.antares_cave",
    "npc.core.red_antares",
    "lore.core.antares_vanishes",
    "lore.core.knight_imprisoned"
  ],
  "rumorOnly": [
    "npc.core.necromancer",
    "lore.core.temple_rises"
  ],
  "learnsWhen": [
    { "subject": "quest.gen_ep1.missing_scholar",
      "when": { "op": "quest_state", "id": "quest.gen_ep1.missing_scholar", "state": "active" } }
  ]
}
```

#### 5.4.2 "액터의 대사" 의 정의 — 검사 대상 범위 (REVIEW_BP-22 `F-07` 해소)

`L-22-10`/`L-22-14` 는 hard 인데 초판은 "액터의 **대사**에 …가 등장하면" 이라고만 적고
그 범위를 정의하지 않았다. 후보가 4가지였고, 특히 [BP-21 R-21-19](21_content_pack_spec.md) /
이 장 `R-22-14` 가 "남의 팩 액터에 대화를 붙이는" 정상 경로를 열어 두었으므로,
**`gen_ep1` 이 붙인 대사가 `core` 액터의 `unknown` 에 걸려 하드 실패**하는 사태가 구조적으로 발생한다.

**확정: 판정 대상은 "노드의 *유효 화자*(effective speaker)가 그 액터인 `lines`" 뿐이다.**

| 항목 | 규칙 |
|---|---|
| 유효 화자 | `Node.speaker` 가 있으면 그것, 없으면 `Dialogue.speaker`([BP-24](24_dialogue_model.md) 소유 필드) |
| 포함 | 유효 화자 = 해당 액터인 노드의 `lines`, 그 노드의 `header` |
| **제외** | 선택지 문구(`choices[].text` — 파티가 말한다), 나레이션 노드, 유효 화자가 다른 노드 |
| **제외** | `play_dialogue` 로 전이된 **다른 대화** — 그 대화는 자기 화자 기준으로 따로 검사된다 |
| 포함 여부 무관 | 앵커의 `dialogue`(BP-26 §2.3)로 붙었든 `dialogueRouting` 으로 붙었든 **유효 화자만** 본다 |

- **R-22-13a (팩 확장 예외)** 다른 팩이 붙인 대사가 `core` 액터의 `unknown` 을 건드릴 때,
  `core` 를 고칠 수 없으므로([BP-21 R-21-4](21_content_pack_spec.md)) **확장 팩이 자기 팩에
  `knowledge` 확장 파일** `actors/_knowledge/<owner_slug>.json` 을 두어 해소한다.

  ```json
  { "actor": "npc.core.lore_gate_guard", "pack": "gen_ep1",
    "learnsWhen": [
      { "subject": "quest.gen_ep1.missing_scholar",
        "when": { "op": "quest_state", "id": "quest.gen_ep1.missing_scholar", "state": "active" } }
    ],
    "removeUnknown": ["place.gen_ep1.scholar_house"],
    "_note": "위병은 실종 사건이 공론화된 뒤에야 학자 집을 안다." }
  ```

  - 빌드는 소유 팩의 `knowledge` 에 이 확장을 **합성**한다(원본 파일은 건드리지 않는다).
  - `removeUnknown` 은 `unknown` 에서 항목을 빼는 유일한 정상 경로다. 남용을 막기 위해
    **린트가 확장 파일당 `removeUnknown` 3개 초과를 경고**한다.
  - `R-22-14` 의 `actors/_routing/` 과 같은 병합 원리다.

**린트가 이것으로 하는 일** (규칙 상세는 §8):

| 검사 | 방법 |
|---|---|
| 미래 사건 언급 | 대사가 참조하는 `lore.*` 의 `order` 가 현재 진행 지점보다 크면 경고 |
| 모르는 것 언급 | **유효 화자 기준** 대사에 등장한 고유명사가 `unknown` 에 있으면 **하드 실패** |
| 범위 밖 언급 | `scopeDefault:"strict"` 인데 `knows` 밖의 고유명사를 쓰면 경고 |
| 소문 단정 | `rumorOnly` 항목을 단정형("…이다", "…했소")으로 말하면 경고. 추측형("…라 하더이다")은 통과 |

#### 5.4.1 `_aliases` — 별칭 사전 (하드 게이트의 원천 필드)

`L-22-10`(hard)의 검사 방법이 "별칭 사전 문자열 매칭" 인데, 초판은 그 사전의 **원천 필드를 어느
스키마 표에도 선언하지 않았다**(REVIEW_BP-22 `F-06`). 사전이 없으면 hard gate 를 구현할 수 없다.

- **R-22-12** 고유명사 검출은 **바이블에 등재된 표시 이름과 별칭**을 사전으로 삼는 문자열 매칭이다.
  `_aliases: string[]` 는 **`faction` / `place` / `actor` / `item` 네 엔티티의 공통 선택 필드**이며
  각 §의 필드표에 선언되어 있다. 예: `place.core.menace` → `["MENACE", "메너스", "금광"]`.
- **R-22-12a** `_` 접두 필드는 [BP-21 §8](21_content_pack_spec.md) 규약에 따라 **빌드가 번들에서 제거**한다.
  린트는 **소스**를 보므로 문제가 없다. 런타임은 별칭을 필요로 하지 않는다.
- **R-22-12b** 별칭은 **팩 경계를 넘어 병합**된다. `gen_ep1` 이 `core` 엔티티에 별칭을 더하려면
  자기 팩의 `world/aliases.json`(선택 파일)에 `{ "<entityId>": ["..."] }` 를 두고, 빌드가 합집합을 만든다.
- **R-22-12c** 같은 별칭 문자열이 서로 다른 두 엔티티에 등록되면 **하드 실패**(매칭이 모호해진다).
- **R-22-13** `knowledge.knows` 는 **대화 생성 프롬프트의 화이트리스트**로도 쓰인다.
  생성 에이전트에게는 이 액터가 아는 것만 컨텍스트로 준다. 그러면 애초에 모르는 것을 쓸 수 없다.
  린트는 그 위의 2차 방어선이다.

### 5.5 `dialogueRouting`

```json
"dialogueRouting": [
  { "when": { "op": "quest_stage", "id": "quest.gen_ep1.missing_scholar", "stage": "ask_guard" },
    "go": "dlg.gen_ep1.guard_about_scholar" },
  { "when": { "op": "flag", "id": "flag.core.npc.lore_gate_guard.bribed" },
    "go": "dlg.core.guard_friendly" }
]
```

- 위에서부터 첫 `true` 를 채택하고, 전부 실패하면 `defaultDialogue`. 대화 그래프 내부의
  `entry` 라우팅과 같은 규약이다(D-07) — 상세는 [BP-24](24_dialogue_model.md).
- **R-22-14** 남의 팩 액터에 대화를 붙이는 정상 경로가 이것이다([BP-21 §4.7 R-21-19](21_content_pack_spec.md)).
  생성 팩은 `core` 액터 파일을 수정하는 대신, 빌드가 병합하는 **라우팅 확장 파일**
  `actors/_routing/<owner_slug>.json` 을 자기 팩에 둔다.

### 5.6 `states` — npcState 값 집합

`Condition.npc_state` / `Effect.set_npc_state`([BP-21 §6](21_content_pack_spec.md))가 쓰는 값을
**여기서 선언**한다. 선언되지 않은 상태를 쓰면 하드 실패다 — cm2 의 오타 침묵 실패를 막는 장치.

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `id` | string | ✅ | 상태 슬러그(액터 안에서 유일) |
| `_desc` | string | ✅ | 프롬프트용 설명 |
| `terminal` | bool | ⬜ | `true` 면 이 상태에서 빠져나올 수 없음(사망 등) |
| `from` | string[] | ⬜ | 전이 가능한 이전 상태. 생략 시 어디서든 가능 |

```json
"states": [
  { "id": "on_duty",  "_desc": "평시 근무 중. 형식적이고 짧게 응대." },
  { "id": "alarmed",  "_desc": "실종 사건을 알게 됨. 경계하며 말이 많아짐.", "from": ["on_duty"] },
  { "id": "grateful", "_desc": "파티가 사건을 해결함. 존대와 호의.", "from": ["alarmed"] },
  { "id": "dead",     "_desc": "사망.", "terminal": true }
],
"initialState": "on_duty"
```

- **R-22-15** (개정, REVIEW_BP-22 `F-08`) `from` 이 선언된 상태로의 전이 검사는 **경고(warn)** 다.
  하드가 아닌 이유: 정확한 판정은 (a) 모든 대화 그래프, (b) 모든 퀘스트 스테이지 DAG, (c) 앵커 `when`,
  (d) `play_dialogue` 체인을 가로지르는 도달성 분석을 요구하고, 조건식에 `chance`/`var_cmp` 가 섞이면
  **정확한 판정이 불가능**하다. 근사하면 오탐이 난다.
  - **판정 기준(보수적 근사)**: 어떤 경로로도 선행 상태에 도달할 수 없음이 **증명될 때만** 보고한다.
    즉 "모르면 통과". 이 방향은 오탐을 0으로 만들고 미탐을 허용한다.
  - `chance`/`var_cmp` 등 값이 정해지지 않는 조건은 **양쪽 다 참일 수 있다**고 본다(over-approximation).
  - 알고리즘 확정은 [BP-33](33_validation_and_lint.md) 소관이다.
- **R-22-16** `terminal: true` 상태를 벗어나는 `set_npc_state` 는 **하드 실패**.
  이것은 도달성 분석이 필요 없는 국소 판정이므로 hard 로 남는다.
- **R-22-17a** (`I-19`) 소스의 `states` 는 **객체 배열**(`{id,_desc,terminal,from}`)이고
  `initialState` 를 갖는다. **번들 정규화 규칙(무엇을 남기고 무엇을 버리는가)은
  [BP-35](35_ci_and_build.md) 소유**다. 런타임이 `terminal` 검사(R-22-16)를 하려면 번들에
  최소한 `id` + `terminal` + `initialState` 가 남아야 한다 — 이 요구를 BP-35 에 전달한다.

### 5.7 `sprite`

| 필드 | 타입 | 의미 |
|---|---|---|
| `sheet` | string | 스프라이트 시트 파일명. 기본 `HDConfig.mainSpriteSheet` (`lore_sprite_transparent.png`) |
| `index` | int | 시트 내 인덱스 |
| `objTile` | int | 이 액터가 맵에 놓일 때 쓰는 B 타일 id. **128~143(TALK 범위)** 이어야 함 |

- **R-22-17** `objTile` 이 TALK 범위(128~143) 밖이면 하드 실패. 근거:
  `HDTileProperties._getObjectAction` 이 `128 <= ixObj < 144` 를 `HDTileAction.talk` 로 판정한다
  (`hadar2026_app/lib/domain/map/tile_properties.dart:223`; 함수 시작은 `:208`). 실측 확인: `TOWN1.json` 의 대화 NPC 좌표
  (8,63)/(71,72)/(50,71)/(62,26)/(12,26)/(20,32)/(23,49)/(40,9) 의 objUpper 값은 각각
  132/129/133/132/131/133/133/133 로 전부 이 범위에 있다.

### 5.8 완전한 액터 예시

```json
{
  "id": "npc.core.lore_gate_guard",
  "type": "actor",
  "pack": "core",
  "name": "str.core.npc.lore_gate_guard.name",
  "title": "str.core.npc.lore_gate_guard.title",
  "faction": "faction.core.lore_guard",
  "place": "place.core.lore_castle",
  "role": "guard",
  "traits": ["stern", "loyal", "weary"],
  "_summary": "로어성 남문을 지키는 중년 위병. 20년째 같은 자리에 서 있다.",
  "_voice": "짧고 각지게. 존대는 하되 다정하지 않다. '…하시오' 체. 사담을 먼저 꺼내지 않는다.",
  "_aliases": ["성문 위병", "남문 위병"],
  "knowledge": {
    "scopeDefault": "public",
    "knows": ["place.core.lore_castle", "place.core.lore_continent", "faction.core.lore_order",
              "npc.core.lord_ahn", "lore.core.founding_of_lore", "topic:gate_duty"],
    "unknown": ["place.core.temple_of_knowledge", "place.core.antares_cave",
                "npc.core.red_antares", "lore.core.knight_imprisoned"],
    "rumorOnly": ["npc.core.necromancer", "lore.core.temple_rises"]
  },
  "defaultDialogue": "dlg.core.gate_guard_idle",
  "dialogueRouting": [],
  "states": [
    { "id": "on_duty", "_desc": "평시 근무." },
    { "id": "alarmed", "_desc": "이상 사태를 인지.", "from": ["on_duty"] },
    { "id": "dead", "_desc": "사망.", "terminal": true }
  ],
  "initialState": "on_duty",
  "sprite": { "sheet": "lore_sprite_transparent.png", "index": 12, "objTile": 132 },
  "mortal": true,
  "recruitable": false
}
```

---

## 6. `items/items.json` — 아이템 카탈로그

### 6.1 스키마

| 필드 | 타입 | 필수 | 기본값 | 의미 |
|---|---|---|---|---|
| `id` | item id | ✅ | — | `item.<pack>.<slug>` |
| `name` | string key | ✅ | — | 표시명 |
| `desc` | string key | ⬜ | — | 설명 |
| `category` | enum | ✅ | — | `quest` \| `weapon` \| `armor` \| `shield` \| `consumable` \| `key` \| `lore` \| `relic` \| `crystal` |
| `stackable` | bool | ✅ | — | `false` 면 보유 수량이 0/1 |
| `maxStack` | int | ⬜ | `99` | `stackable:true` 일 때 상한 |
| `value` | int | ✅ | — | 기준 가격(gold). 0 = 매매 불가 |
| `tradable` | bool | ⬜ | `category != quest && != key` | 상점 매매 가능 |
| `droppable` | bool | ⬜ | `!(quest\|key)` | 버릴 수 있는가 |
| `effects` | Effect[] | ⬜ | `[]` | **사용 시** 적용. [BP-21 §6](21_content_pack_spec.md) DSL 재사용 |
| `equip` | object | ⬜ | — | 장비 스탯 (§6.2) |
| `sources` | string[] | ⬜ | `[]` | 획득처 태그 (§6.3) |
| `grade` | int 1..5 | ⬜ | `1` | 가치 등급. 보상 티어표([BP-23 §23.9](23_quest_model.md))가 참조 (`I-07`) |
| `unique` | bool | ⬜ | `false` | `true` 면 월드 전체에 1개만 존재. 중복 지급이 하드 실패 검사 대상 (`I-07`) |
| `legacy` | object | ⬜ | — | 레거시 정수 ID 대응 (§6.4) |
| `_summary` | string | ✅ | — | 프롬프트용 |
| `_aliases` | string[] | ⬜ | `[]` | **별칭 사전**(§5.4.1) |

- **R-22-18** (**3판 개정** — D-31 반영 / REVIEW_BP-22 `F-04` / BP-90 `I-20` **해소**)
  `category: "consumable"` 은 `effects` 가 비어 있으면 원칙적으로 하드 실패다(쓸모없는 소비품 금지). **예외 1개**:
  `"_v1Unimplemented": true` 를 명시하면 **경고로 강등**된다.
  - **초판 사유(해소됨)**: 원작 소비품 10종 중 **8종**의 효과에 대응하는 `do` 가 v1 DSL 22종에 **없어서**,
    원작 시드가 **자기 규칙에 걸려 빌드되지 않는** 상태였다(`I-20` · G-22-2).
  - **현재 사유(축소됨)**: **D-31 이 `do` 를 25종으로 확장**했다 —
    [BP-21 §6.6](21_content_pack_spec.md) 의 `restore` · `cure` · `grant_buff`
    (정의는 그 장 소유. 이 장은 인자·열거값을 재서술하지 않는다 — D-18/D-25).
    이로써 8종 중 **5종이 정식 `effects` 를 갖고, 우회 플래그를 뗀다**(§6.5 표).
    **그 5종에서 `R-22-18` 위반은 사라졌다** — 하드 실패 원칙을 그대로 두고 시드가 규칙을 만족한다.
  - **잔존 3종** — `_v1Unimplemented` 를 계속 쓴다. 사유가 서로 다르므로 개별로 적는다.

    | 아이템 | 왜 아직 안 되나 | 어느 장이 풀 수 있나 |
    |---|---|---|
    | `item.core.scroll_summon` | "아군 소환" 에 대응하는 런타임 기능이 **없다.** `start_battle` 은 적을 세우는 do 이고 파티 편성을 바꾸지 못한다 | 파티 편성 API 가 선행 → [BP-42](42_item_and_inventory.md) · [BP-40](40_gameplay_changes.md) |
    | `item.core.crystal_ball` | "주변 정보 표시" 는 UI 기능이고 Effect 로 표현할 대상이 아니다 | [BP-41](41_journal_ui_spec.md) 이 화면을 정하기 전까지 미정 |
    | `item.core.winged_boots` | `levitation` 버프가 **죽은 필드**다([BP-42 §1.7](42_item_and_inventory.md) 실측). `grant_buff` 에 넣으면 [BP-21 R-21-68](21_content_pack_spec.md)(`CV-16`)이 **빌드 하드 실패**시킨다 | 런타임이 `levitation` 을 읽게 되면 화이트리스트가 넓어진다(제약 완화이므로 승격 불필요) |

    **`winged_boots` 를 `grant_buff` 로 쓰는 것은 금지다.** 스키마가 통과시켜 주면 "작성자에게는 성공,
    플레이어에게는 무동작" 이 되고, 그것이 D-31 이 막으려던 문제다. 우회 플래그를 유지하는 쪽이 정직하다.
  - `_v1Unimplemented: true` 인 아이템은 **인벤토리에 존재하되 사용 메뉴에 노출되지 않는다.**
    "쓸 수 없는 아이템" 이 아니라 "아직 구현되지 않은 아이템" 임을 UI 가 표시한다([BP-42](42_item_and_inventory.md) 소관).
  - **린트**: 팩당 `_v1Unimplemented` 개수를 리포트한다. **`core` 팩의 기대값은 3** 이며 그보다 늘어나면
    새 아이템이 우회를 남용하는 것이므로 검수 대상이다. 다음 감소는 위 표의 세 조건 중 하나가 풀릴 때 일어난다.
- **R-22-19** `category: "quest"` 아이템의 `effects` 는 비어 있어야 한다(퀘스트 아이템은 조건 재료일 뿐).
  이 경우는 `_v1Unimplemented` 없이도 정상이다.
- **R-22-20** (개정, REVIEW_BP-22 `F-05` — **자체 예외 선언 회수**) 아이템 사용 컨텍스트의 지연 효과
  제약은 **[BP-21 §6.7.4 의 컨텍스트 X3](21_content_pack_spec.md)** 가 정의한다(D-18: DSL 소유는 BP-21).
  이 장은 그 규칙을 **링크만** 한다.
  - 요지: X3 에서 `play_dialogue`·`start_battle` 은 금지, `warp` 은 꼬리 호출 1개만 허용(`CV-12`).
  - 초판은 여기서 스스로 "`teleport_ball` 은 예외" 를 선언했으나, 그것은 참조가 아니라 재정의였다.
    BP-21 §6.7.4 가 아이템 사용 컨텍스트를 명시함으로써 예외 선언이 불필요해졌다.
  - **Q-22-8**: 원작 이동 구슬은 목적지를 플레이어가 고르므로 `warp(map,x,y)` 로 표현되지 않는다
    ([BP-21 Q-21-9](21_content_pack_spec.md)). v1 은 **고정 목적지 워프 아이템만** 표현 가능하다.

### 6.2 `equip`

| 필드 | 타입 | 의미 | 매핑 | 전투식이 읽는가 |
|---|---|---|---|---|
| `slot` | enum | `weapon` \| `shield` \| `armor` | `HDPlayer.weapon/shield/armor` | — |
| `power` | int | 공격력 | `HDPlayer.powOfWeapon` | **부분** (`battle.dart` 의 플레이어 공격식) |
| `ac` | int | 방어도 | **`HDPlayer.ac`** | ✅ **유일한 방어 입력** |
| `weaponType` | enum | `wield` \| `chop` \| `stab` \| `hit` \| `shoot` \| `summon_single` \| `summon_multi` | 원작 `ITEM_TYPE`(`REF_UNITY_LoreEp1/src_as_cs/ObjTypes.cs:32`) | ❌ v1 미사용 |
| `classRestrict` | int[] | 착용 가능 클래스 | 0 에스퍼 / 1 싸이보그 / 2 초능력자 | — |

**⚠ 장비가 전투에 반영되지 않는다는 실측** (GROUND_TRUTH 부록 H-1 / H-2)

| # | 사실 | 스키마에 대한 함의 |
|---|---|---|
| H-1 | `powOfShield` / `powOfArmor` 는 **어떤 전투 규칙도 읽지 않는 죽은 필드**다. 등장하는 곳이 전부 대입·직렬화·`getAttribute` 스위치뿐이다(`party.dart:107,129`, `player.dart:50,134,136,293,294,358,361,426,427`) | `equip` 스키마는 이 둘에 매핑하지 **않는다**. 방어는 `ac` 하나로만 표현한다 |
| H-1 | 방어 계산은 `hadar2026_app/lib/application/battle.dart:513-514` 의 `damage -= (t.ac * t.level.physical * (Random().nextInt(10)+1)) ~/ 10` 뿐이다 | **방어구를 바꿔도 `ac` 를 건드리지 않는 한 아무 효과가 없다.** 아이템 장착이 `ac` 를 갱신하도록 하는 것은 [BP-42](42_item_and_inventory.md) 소관 |
| H-2 | 레벨 1 기준 피해 감소량은 `ac × (0.1~1.0)` 이고 레벨 1 적(`Orc` str 8)의 공격력은 `0.8~8` 이다. `books.json` 의 **ac 10/20 은 초반 전투를 통째로 무효화**한다 | `equip.ac` 는 원작 `ObjItem.cs` 척도(가죽 갑옷 1.0 → `1`) 계열을 쓰고 `books.json` 척도(20)를 쓰지 않는다. 실제 재척도 수치는 BP-42 소유 |

- **R-22-21a** `equip` 은 `power`/`ac` 두 수치만 갖는다. `powOfShield`/`powOfArmor` 는 스키마에 없다.
- 원작 `books.json` 은 `power` 를 실수(`5.0`, `15.0`)로 쓴다. **정수로 반올림**한다
  ([BP-21 §8](21_content_pack_spec.md) 부동소수 금지).
- **S-02 반영**: 원작 `ITEM_TYPE` 은 `ARMOR`/`HEAD`/`LEG` **3종 방어구 슬롯**을 갖고
  `ObjItem.cs:574-582` 에 "가죽캡/가죽 투구/가죽 신발" 이 실재한다. `HDPlayer` 가 `armor` 정수
  1개뿐이므로 **v1 은 HEAD/LEG 를 지원하지 않는다.** 누락이 아니라 의도적 축소다.

### 6.3 `sources` — 획득처 태그 (닫힌 집합)

`quest_reward`, `shop`, `chest`, `drop`, `npc_gift`, `start_kit`, `hidden`, `craft`, `unobtainable`

- **R-22-21** `sources` 가 비었거나 `unobtainable` 만 있는데 어떤 퀘스트가 `acquire` 목표로 요구하면
  **하드 실패**(획득 불가능한 목표). 솔버(D-13)가 이것을 증명한다.

### 6.4 레거시 흡수 — `books.json` 과 `HDPlayer` 정수 ID

**현황 (실측)**

| 자산 | 상태 |
|---|---|
| `hadar2026_app/assets/maps/books.json` | 1506 바이트. `weapon` 5종(맨손/단도/단검/단창/작은도끼), `armor` 3종(맨몸/두꺼운옷/가죽갑옷). **앱 코드 어디에서도 로드하지 않음**(grep 0건). 탭 들여쓰기 |
| `HDPlayer.weapon/shield/armor` | 정수 1개씩. 이름은 `getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon"` 하드코딩 플레이스홀더(`lib/domain/party/player.dart`) |
| `HDPlayer.powOfWeapon/powOfShield/powOfArmor` | 정수. 장비와 별개로 직접 대입됨(`assets/menace.cm2` 의 `Player::ChangeAttribute(6,"pow_of_weapon",0)`) |
| `HDParty` 인벤토리 | `food:int`, `gold:int` 두 개가 전부. **아이템 목록 없음** |
| 원작 전체 목록 | `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs` — 무기 7×5계열 + 소환 다수, 방패 6종, 갑옷 12종 |
| 원작 파티 아이템 | `REF_UNITY_LoreEp1/src_as_cs/Console.cs:195` — 회복약/마법 회복약/해독의 약초/의식의 약초/부활의 약초/소환 두루마리/대형 횃불/수정 구슬/비행 부츠/이동 구슬 |
| 원작 크리스탈·유물 | 화염·소환·한파·에너지·다크 크리스탈, 황금방패의조각(`PARTY_CRYSTAL`, `PARTY_RELIC`) |

**흡수 전략**

`legacy` 필드가 신규 ID ↔ 레거시 정수의 다리다. 빌드가 이것을 모아
`content.lock.json#legacyItemMap` 을 만든다([BP-21 §2.3](21_content_pack_spec.md) 의 `legacyFlagMap` 과 같은 구조).

**⚠ `legacy.intId` 는 "복원" 이 아니라 "신규 부여" 다** (REVIEW_BP-22 `F-09` / GROUND_TRUTH 부록 H-3)

| # | 사실 | 결론 |
|---|---|---|
| 1 | `HDPlayer.weapon` 정수에 **의미를 부여하는 코드가 레포 어디에도 없다.** `player.dart:44` 의 `int weapon = 0` 과 `player.dart:91` 의 `getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon"` 이 전부다 | "`weapon == 1` 은 단검" 이라는 대응은 **어디에도 근거가 없다** |
| 2 | `books.json` 은 앱이 읽지 않는다(참조 0건, R-22-22 가 확인) | `books.json` 의 id 공간과 `HDPlayer.weapon` 을 잇는 근거가 **존재하지 않는다**(부록 H-3) |
| 3 | `books.json` 의 `weapon[].id` 는 **1-based**(맨손=1)인데 `armor[].id` 는 **0-based**(맨몸=0)다 | 두 배열의 기수가 다르다. 아래 대응표는 이 차이를 흡수해 적었으나 **구현 시 off-by-one 주의** |

- **R-22-23a** `legacy.intId` 는 **이 기획이 새로 정하는 값**이며, 기존 세이브의 `HDPlayer.weapon`
  값과 의미가 일치한다고 가정하지 않는다.
- **R-22-23b** v1 세이브 마이그레이션은 `HDPlayer.weapon/shield/armor` 정수를 **`null` 로 처리하고
  경고 로그**를 남긴다. 임의 매핑으로 복원하려 하지 않는다 — 근거가 없으므로 어떤 매핑도 추측이다.
  마이그레이션 절차의 소유는 [BP-42](42_item_and_inventory.md)(장비 마이그레이션)와
  [BP-25](25_world_state_and_save.md)(세이브 포맷)다.
- **R-22-23c** `legacy.booksJsonId` / `legacy.unitySource` 는 **출처 주석**이며 런타임 키가 아니다.

```json
{
  "id": "item.core.short_sword",
  "name": "str.core.item.short_sword.name",
  "category": "weapon",
  "stackable": false,
  "value": 120,
  "equip": { "slot": "weapon", "power": 15, "ac": 0, "weaponType": "wield" },
  "sources": ["shop", "start_kit"],
  "legacy": {
    "kind": "weapon",
    "intId": 1,
    "booksJsonId": 3,
    "unitySource": "ObjItem.WEAPON_LIST[WIELD][1]"
  },
  "_summary": "가장 흔한 베는 무기. 로어성 무기점의 첫 진열품."
}
```

**대응표 — `books.json` → `items.json`** (BP-42 이관 예정 초안. 실제 수치 확정은 BP-42 소유)

| books.json | id | name | power | 신규 item id | category | 비고 |
|---|---|---|---|---|---|---|
| weapon[0] | 1 | 맨손 | 1.0 | *(아이템 없음)* | — | `weapon == 0` 상태로 표현. 아이템화하지 않는다 |
| weapon[1] | 2 | 단도 | 5.0 | `item.core.dagger` | weapon | 원작 STAB #1 (`ObjItem.cs` power 10.0) → 값 충돌 → Q-22-2 |
| weapon[2] | 3 | 단검 | 15.0 | `item.core.short_sword` | weapon | 원작 WIELD #1 power 15.0 ✅ 일치 |
| weapon[3] | 4 | 단창 | 20.0 | `item.core.short_spear` | weapon | 원작 STAB #3 power 35.0 → 충돌 → Q-22-2 |
| weapon[4] | 5 | 작은도끼 | 22.0 | `item.core.hand_axe` | weapon | 원작 CHOP #2 "소형 도끼" power 35.0 → 충돌 |
| armor[0] | 0 | 맨몸 | ac 0 | *(아이템 없음)* | — | `armor == 0` |
| armor[1] | 1 | 두꺼운옷 | ac 10 | `item.core.thick_clothes` | armor | 원작에 없음. `books.json` 고유 |
| armor[2] | 2 | 가죽갑옷 | ac 20 | `item.core.leather_armor` | armor | 원작 ARMOR #1 ac 1.0 → 척도 자체가 다름 → Q-22-2 |

**대응표 — `HDPlayer` 정수 필드 → 신규 모델** (BP-42 이관 예정 초안)

| 현행 | 신규 | 전환 방법 |
|---|---|---|
| `HDPlayer.weapon: int` | `equippedWeapon: itemId?` | 세이브 v2 마이그레이션이 `legacyItemMap.weapon[intId]` 로 역참조. 매핑 없는 값은 `null` + 경고 |
| `HDPlayer.shield: int` | `equippedShield: itemId?` | 동일 |
| `HDPlayer.armor: int` | `equippedArmor: itemId?` | 동일 |
| `getWeaponName()` 하드코딩 | `strings/ko.json` 의 `str.core.item.<slug>.name` | 플레이스홀더 제거 |
| `powOfWeapon` | `equip.power` 에서 유도 | cm2 가 직접 대입하는 경로(`Player::ChangeAttribute`)는 오버라이드로 남긴다 |
| `powOfShield` / `powOfArmor` | **폐기 대상**(부록 H-1: 전투식이 읽지 않는 죽은 필드) | 스키마에 대응 필드를 두지 않는다. 방어는 `ac` 로만 표현 |
| `ac` | `equip.ac` 의 합으로 갱신 | **전투식의 유일한 방어 입력**. 장착 시 갱신 책임은 BP-42 |
| `HDParty.food/gold` | 그대로 유지 + `WorldState.inventory` 신설 | food/gold 는 파티 코어 값이므로 아이템화하지 않는다 |

- **R-22-22** `books.json` 은 **읽지 않는다**. 값만 참고해 `items.json` 을 짜고, 원본은
  `assets/maps/` 에서 `assets/_legacy/` 로 옮긴 뒤 폐기 예정으로 표시한다.
  (맵 디렉토리에 아이템 데이터가 있는 것 자체가 오분류다)
- **R-22-23** 원작 `ObjItem.cs` 의 (계열, 인덱스) 2차원 키는 `legacy.unitySource` 문자열로만 보존하고
  런타임 키로 쓰지 않는다.

### 6.5 초기 `core` 아이템 시드 (원작 파티 아이템) — BP-42 이관 예정 초안

아래 표의 `v1` 열은 `R-22-18` 의 `_v1Unimplemented` 플래그 필요 여부다.
**초판은 8종이 `⚠` 였고, 이 플래그가 없으면 초기 시드가 자기 hard gate 에 걸렸다**(`I-20`).
**D-31 이 `do` 를 25종으로 확장한 뒤 `⚠` 는 3종으로 줄었다** — 표의 `대표 effect` 열이 그 결과다.
do 의 시그니처·열거값은 [BP-21 §6.6](21_content_pack_spec.md) 소유이며 여기서 재서술하지 않는다(D-18/D-25).

| item id | name | category | stackable | 원작 대응 | 대표 effect | v1 |
|---|---|---|---|---|---|---|
| `item.core.potion_heal` | 회복약 | consumable | ✅ | `PARTY_ITEM.POTION_HEAL` | `heal_party` | ✅ |
| `item.core.potion_mana` | 마법 회복약 | consumable | ✅ | `POTION_MANA` | **`restore`**(sp) — D-31 | ✅ |
| `item.core.herb_detox` | 해독의 약초 | consumable | ✅ | `HERB_DETOX` | **`cure`**(poison) — D-31 | ✅ |
| `item.core.herb_jolt` | 의식의 약초 | consumable | ✅ | `HERB_JOLT` | **`cure`**(unconscious) — D-31 | ✅ |
| `item.core.herb_resurrection` | 부활의 약초 | consumable | ✅ | `HERB_RESURRECTION` | **`cure`**(dead) + `heal_party` — D-31 | ✅ |
| `item.core.scroll_summon` | 소환 두루마리 | consumable | ✅ | `SCROLL_SUMMON` | — 아군 소환 런타임 기능 없음 | ⚠ |
| `item.core.big_torch` | 대형 횃불 | consumable | ✅ | `BIG_TORCH` | **`grant_buff`**(magicTorch) — D-31 | ✅ |
| `item.core.crystal_ball` | 수정 구슬 | consumable | ✅ | `CRYSTAL_BALL` | — 정보 표시 UI 미정 | ⚠ |
| `item.core.winged_boots` | 비행 부츠 | consumable | ✅ | `WINGED_BOOTS` | — `levitation` 이 죽은 버프라 `grant_buff` 하드 실패 | ⚠ |
| `item.core.teleport_ball` | 이동 구슬 | consumable | ✅ | `TELEPORT_BALL` | `warp(map,x,y)` — **고정 목적지만**([BP-21 §6.7.4 X3](21_content_pack_spec.md)) | ✅ |
| `item.core.pyro_crystal` | 화염의 크리스탈 | crystal | ✅ | `PARTY_CRYSTAL.PYRO_CRYSTAL` | — | ✅ |
| `item.core.summon_crystal` | 소환의 크리스탈 | crystal | ✅ | `SUMMON_CRYSTAL` | — | ✅ |
| `item.core.frozen_crystal` | 한파의 크리스탈 | crystal | ✅ | `FROZEN_CRYSTAL` | — | ✅ |
| `item.core.energy_crystal` | 에너지 크리스탈 | crystal | ✅ | `ENERGY_CRYSTAL` | — | ✅ |
| `item.core.dark_crystal` | 다크 크리스탈 | crystal | ✅ | `DARK_CRYSTAL` | — | ✅ |
| `item.core.shard_of_gold` | 황금방패의 조각 | relic | ✅ | `PARTY_RELIC.SHARD_OF_GOLD` | — | ✅ |
| `item.core.golden_shield` | 황금의 방패 | relic | ❌ | `YunjrMap_T1.cs:840` 대사 | — | ✅ |

- **G-22-2** ✅ **해소 (D-31)**. 초판 기록: *"원작 소비품 효과 상당수(SP 회복, 해독, 의식 회복, 부활, 버프 부여)에
  대응하는 Effect do 가 v1 DSL 에 없다. D-05 는 닫힌 집합이므로 추가하려면 `schemaVersion` 승격이 필요하다."*
  → **승격이 실제로 일어났다.** [BP-21 §7.2.1](21_content_pack_spec.md) 이 `schemaVersion` 1 → 2 승격을 실행하고
  `restore`/`cure`/`grant_buff` 3종을 추가했다. **이 갭이 지목한 5개 효과가 전부 표현 가능해졌다.**
  `Q-22-4` 종결(§9.3).
  - 지우지 않고 남기는 이유: 이 갭이 **기획서 최초의 스키마 승격을 촉발한 근거**이고,
    "카탈로그가 자기 hard gate 에 걸린다" 는 형태의 결함을 어떻게 발견했는지가 이 절의 산출물이다.
  - **남은 3종은 do 부재가 아니다** — 소환·정보 표시는 **런타임 기능 부재**, 비행 부츠는
    **죽은 버프 필드**다(R-22-18 의 잔존 표). 즉 DSL 확장으로 풀 문제가 아니므로 `G-22-2` 의 범위 밖이다.

---

## 7. 적·인카운터 카탈로그

### 7.1 현황

`lib/domain/battle/enemy_data.dart` 에 `const List<HDEnemyData> enemyTable` 로 하드코딩되어 있다.

| 항목 | 실측 |
|---|---|
| 엔트리 수 | **75개** (`id: 0` `Orc` ~ `id: 74` `Neo-Necromancer`). GROUND_TRUTH §10 의 "76종" 은 폐기됨(부록 B-1) |
| **실사용 가능 수** | **74종 (id 1~74)**. `hadar2026_app/lib/application/battle.dart:43-46` 의 `if (enemyTableId <= 0 \|\| enemyTableId >= enemyTable.length) return;` 가드 때문에 **`id: 0`(`Orc`)은 cm2·콘텐츠 어느 경로로도 소환할 수 없다**(부록 B-1) |
| 필드 | `id, name, strength, mentality, endurance, resistance, agility, accuracy[2], ac, special, castLevel, specialCastLevel, level` |
| 레벨 분포 | 1(Orc) ~ 30(Neo-Necromancer). **소환 가능 범위는 1(Troll, id 1) ~ 30** |
| HP 산출 | `HDEnemy` 생성자에서 `hp = endurance * level` |
| 이름 | 전부 로마자 영문(`Orc`, `Giant Spider`, `Death Knight`, `ArchiMage`) |
| 서사 인물과의 중복 | `id: 66 Ancient Evil`, `id: 67 Lord Ahn` — **세계관 인물이 적 테이블에 있다** |
| 참조 경로 | cm2 의 `Battle::RegisterEnemy(69)` 처럼 **정수 인덱스**로 지정(`assets/town1.cm2`) |

### 7.2 세 가지 안

| 안 | 방식 | 장점 | 단점 |
|---|---|---|---|
| **A. 코드 유지 + 생성 인덱스** | `enemy_data.dart` 를 SSoT 로 두고, 빌드가 `build/enemies.index.json` 을 생성. 콘텐츠는 `enemy.core.<slug>` 로 참조하며 슬러그↔정수 매핑은 인덱스가 갖는다 | 밸런스 수치가 코드 리뷰·타입 검사를 받음. 마이그레이션 0. 기존 cm2 `Battle::RegisterEnemy(n)` 그대로 동작 | 적 추가에 코드 변경 필요(콘텐츠 PR 이 아님) |
| **B. 데이터 완전 이전** | `enemies/enemies.json` 으로 옮기고 코드는 로더만 | 콘텐츠 팀이 적을 추가 가능. 팩별 적 확장 가능 | `const` 테이블이 런타임 로드로 바뀌며 부팅 경로 변경. cm2 정수 참조가 깨질 위험. 75종 손 마이그레이션 |
| **C. 하이브리드** | `core` 75종은 코드 유지(A), 생성 팩은 `enemies/enemies.json` 로 추가 가능(B) | 양쪽 장점 | 같은 개념이 두 곳에 사는 이중 관리. "이 적은 어디 있지?" 가 상시 질문이 됨 |

### 7.3 **권고안: A (코드 유지 + 생성 인덱스)**

근거 4가지:

1. **밸런스는 콘텐츠가 아니라 시스템이다.** 적 스탯을 바꾸면 전 게임의 난이도 곡선이 움직인다.
   AI 가 자유롭게 쓸 수 있는 곳에 두면 안 된다. 반대로 "이 던전에 어떤 적이 나오는가" 는 콘텐츠다 —
   그래서 **인카운터는 콘텐츠 팩에, 적 정의는 코드에** 둔다.
2. **cm2 호환.** `Battle::RegisterEnemy(69)` 는 지금도 동작하는 정수 참조다(D-10 의 무중단 이관 원칙).
   테이블을 옮기면 이 경로가 깨진다.
3. **마이그레이션 비용 0.** B 안은 75 엔트리를 옮기고 부팅 경로를 바꾸는데, 그 대가로 얻는 것이
   "적 추가 편의" 하나뿐이다. 적 추가는 에피소드당 몇 건 수준이다.
4. **C 안의 이중 관리는 정확히 GROUND_TRUTH §8 의 "3중 분열" 을 다시 만드는 패턴이다.**
   같은 실수를 반복하지 않는다.

**A 안의 구체 산출물**

```jsonc
// hadar2026_app/assets/content/build/enemies.index.json  (빌드 생성물, 손으로 쓰지 않음)
{
  "_generatedFrom": "lib/domain/battle/enemy_data.dart",
  "_sourceHash": "sha256:…",
  "count": 75,
  "summonableCount": 74,
  "enemies": [
    { "ref": "enemy.core.orc", "intId": 0, "name": "Orc", "level": 1, "hp": 8,
      "strength": 8, "endurance": 8, "agility": 8, "ac": 1, "castLevel": 0,
      "summonable": false,
      "_note": "battle.dart:44 의 `<= 0` 가드로 소환 불가(부록 B-1). 인덱스에는 남기되 참조 금지." },
    { "ref": "enemy.core.troll", "intId": 1, "name": "Troll", "level": 1, "hp": 6,
      "strength": 9, "endurance": 6, "agility": 9, "ac": 1, "castLevel": 0,
      "summonable": true },
    { "ref": "enemy.core.neo_necromancer", "intId": 74, "name": "Neo-Necromancer", "level": 30, "hp": 1800,
      "strength": 40, "endurance": 60, "agility": 30, "ac": 10, "castLevel": 6,
      "summonable": true }
  ]
}
```

- 슬러그는 `name` 에서 기계적으로 유도: 소문자화 → 비영숫자를 `_` 로 → 연속 `_` 축약
  (`ArchiDraconian` → `archidraconian`, `Dancing-Swd` → `dancing_swd`, `Rock-Man` → `rock_man`).
- **R-22-24** 유도된 슬러그가 충돌하거나 [BP-21 §4.3](21_content_pack_spec.md) 슬러그 규칙을 위반하면
  빌드 하드 실패. 그때는 `enemy_data.dart` 옆의 `enemy_slug_overrides.dart` 에 수동 매핑을 넣는다.
- **R-22-25** (개정, REVIEW_BP-22 `F-01` / BP-90 `I-08` 해소) `enemy.*` 는 **참조 전용 타입**이며
  그 ID 문법은 **[BP-21 §4.2 의 "참조 전용 타입" 표](21_content_pack_spec.md)** 가 정의한다(`R-21-55`~`R-21-57`).
  - 초판은 "BP-21 타입 접두사 목록에 `enemy` 가 없다" 를 근거로 삼았는데, 그러면
    `validateEntityId` 가 `enemy.core.orc` 를 **`bad_type` 하드 실패**시켜 이 장의 인카운터 스키마가
    **작성하는 순간 검증에 걸렸다.** BP-21 에 참조 전용 타입을 신설해 해소했다.
  - **표기 정본은 정수 id**(`R-21-56`)다. BP-22(문자열)·[BP-23](23_quest_model.md)(정수)·
    [BP-35](35_ci_and_build.md)(정수)의 3갈래를 정수로 통일하고, `enemy.<pack>.<slug>` 는
    **소스 가독성 별칭**으로 둔다. 빌드가 별칭을 정수로 정규화하고 불일치 시 하드 실패.
- **R-22-25a** `summonable: false` 인 항목(현재 `intId: 0` 하나)은 인덱스에 남기되
  **어떤 콘텐츠도 참조할 수 없다**(`L-22-31`, hard). 인덱스에서 지우지 않는 이유는
  레거시 cm2 가 `Battle::RegisterEnemy(0)` 을 쓸 때 "왜 아무 일도 안 일어나는가" 를 설명할
  근거를 남기기 위해서다(부록 F-1 의 침묵 실패 계열).

### 7.4 `encounters/encounters.json` — 인카운터 (콘텐츠 소유)

인카운터는 "적 조합 + 등장 규칙" 이며 **콘텐츠다**. `enc.<pack>.<slug>` ID 를 갖는다.

| 필드 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `id` | enc id | ✅ | `enc.<pack>.<slug>` |
| `name` | string key | ⬜ | 전투 로그 표시명 |
| `members` | object[] | ✅ | `{ "enemy": 4, "enemyRef": "enemy.core.dwarf", "count": 2 }`. `enemy` = **정수 id 1~74**(정본), `enemyRef` = 선택 별칭. 합계 ≤ `HDParty.maxEnemy`(기본 3) |
| `places` | place id[] | ⬜ | 랜덤 조우 대상 장소 |
| `weight` | int | ⬜ | 랜덤 조우 가중치(기본 1) |
| `when` | Condition | ⬜ | 등장 조건 |
| `kind` | enum | ✅ | `random` \| `fixed` \| `boss` |
| `onWin` | Effect[] | ⬜ | 승리 시 |
| `onLose` | Effect[] | ⬜ | 패배 시. 생략 시 기본 게임오버 처리 |
| `onEscape` | Effect[] | ⬜ | **도주 시**. 생략 시 아무 효과도 적용하지 않는다 |
| `escapable` | bool | ⬜ | 기본 `true`. `kind:"boss"` 는 기본 `false` |

**⚠ 전투 결과 3값의 정본은 이 장이 정하지 않는다** (REVIEW_BP-22 `F-10` / GROUND_TRUTH 부록 B-2·F-3)

- `hadar2026_app/lib/application/battle.dart:27` 은 `1: Win, 0: Lose, 2: Run away` 인데
  `hadar2026_app/assets/const.cm2:53-55` 는 `BATTLERESULT_EVADE=0, WIN=1, LOSE=2` 다 —
  **패배와 도주가 뒤바뀐 채 매핑**되어 있다(부록 B-2).
- `_battleResult` 초기값이 `1`(Win)이고 `init()` 도 `1` 로 되돌리므로,
  `Battle::Start` 없이 `Battle::Result()` 를 읽으면 **항상 승리**다(부록 F-3).
- **정본 확정은 [BP-27](27_runtime_engine.md) 소관**(D-18: 런타임 실행 경로)이며 이 장은 링크만 한다.
  `onWin`/`onLose`/`onEscape` **3분기 스키마**만 여기서 정의한다 — 어느 정수가 어느 분기인지는
  BP-27 이 정한 매핑을 따른다.
- **R-22-26a** `onEscape` 는 `escapable: false` 인 인카운터에 있으면 린트 경고(도달 불가 효과).

```json
{
  "id": "enc.core.menace_patrol",
  "name": "str.core.enc.menace_patrol.name",
  "kind": "random",
  "members": [ { "enemy": 4, "enemyRef": "enemy.core.dwarf", "count": 2 },
               { "enemy": 7, "enemyRef": "enemy.core.wolf",  "count": 1 } ],
  "places": ["place.core.menace"],
  "weight": 3,
  "escapable": true,
  "_note": "lore_ep1.cm2: 'MENACE 속에는 Dwarf, Giant, Wolf, Python 같은 괴물들이 살고 있소.'"
}
```

- **R-22-26** `members` 총합이 `HDParty.maxEnemy` 를 넘으면 하드 실패.
- **R-22-27** `kind:"boss"` 인카운터의 평균 레벨이 소속 장소 `danger` 의 권장 범위(§4.6)를
  ±5 이상 벗어나면 린트 경고(밸런스 soft gate).

---

## 8. 일관성 규칙 목록

린트가 검사할 세계관 제약이다. 규칙 번호는 [BP-33](33_validation_and_lint.md) 이 이어받아
심각도·메시지·수정 힌트를 확정한다.

### 8.1 참조 무결성 (hard)

| # | 규칙 | 심각도 | 검사 방법 |
|---|---|---|---|
| **L-22-01** | 액터의 `place` 는 존재하는 place 여야 한다 | hard | ID 존재 검사 |
| **L-22-02** | 액터의 `faction` 은 존재하는 faction 이거나 `null` 이어야 한다 | hard | 동일 |
| **L-22-03** | place 의 `map` 은 `MapInfos.json` 에 있고 **실제 파일로 해석**되어야 한다 | hard | §4.7 G-22-1 |
| **L-22-04** | place 의 `regions` rect 는 맵 크기 안에 있어야 한다 | hard | 맵 JSON `width`/`height` 대조 |
| **L-22-05** | `set_npc_state` / `npc_state` 가 쓰는 상태는 그 액터의 `states[]` 에 선언되어야 한다 | hard | §5.6 |
| **L-22-06** | `states[].from` 이 선언된 상태로의 전이는 도달 가능한 선행 상태에서만 일어나야 한다 | **warn**(보수적 근사: 도달 불가가 **증명될 때만** 보고) | R-22-15 (`F-08`) |
| **L-22-06a** | `terminal: true` 상태를 벗어나는 `set_npc_state` | hard | R-22-16 |
| **L-22-07** | `enc.members[].enemy` 는 `build/enemies.index.json` 에 존재해야 한다 | hard | §7.3 |
| **L-22-31** | `enc.members[].enemy` 가 `summonable: false`(현재 `intId: 0`)를 가리키면 안 된다 | **hard** | 부록 B-1 · R-22-25a |
| **L-22-32** | `enemyRef` 별칭과 `enemy` 정수가 `enemies.index.json` 상에서 일치해야 한다 | hard | R-21-56 |
| **L-22-08** | 아이템 사용 컨텍스트의 지연 효과 제약 → **[BP-21 `CV-12`](21_content_pack_spec.md) 를 인용**한다. 이 장은 새 번호를 만들지 않는다 | hard | R-22-20 (`F-05`) |
| **L-22-33** | `category:"consumable"` 인데 `effects` 가 비었고 `_v1Unimplemented` 도 없음 | hard | R-22-18 (`I-20` **해소** — D-31 로 우회 대상이 8종 → 3종. 규칙 자체는 그대로 유지한다) |
| **L-22-34** | 같은 별칭 문자열이 서로 다른 두 엔티티에 등록됨 | hard | R-22-12c |
| **L-22-35** | `unique: true` 아이템을 두 곳 이상에서 `give_item` 함 | hard | `I-07` |
| **L-22-09** | `sprite.objTile` 은 128~143(TALK) 범위여야 한다 | hard | R-22-17 |

### 8.2 지식 범위 (§5.4)

| # | 규칙 | 심각도 | 검사 방법 |
|---|---|---|---|
| **L-22-10** | 액터의 대사에 그 액터의 `unknown` 항목의 이름·별칭이 등장하면 안 된다 | **hard** | 별칭 사전 문자열 매칭 |
| **L-22-11** | `scopeDefault:"strict"` 액터가 `knows` 밖의 고유명사를 말하면 경고 | warn | 동일 |
| **L-22-12** | 액터가 `rumorOnly` 항목을 단정형 종결로 말하면 경고 | warn | 종결어미 패턴(`~이오`, `~하오`, `~습니다`) 매칭 |
| **L-22-13** | 액터가 참조하는 `lore.*` 사건의 `order` 가 그 액터의 대화가 도달 가능한 최소 진행 지점보다 미래면 경고 | warn | 연대기 순서 + 퀘스트 전제 조건 역산 |
| **L-22-14** | `visibility:"secret"` 인 연대기 사건을 `knownBy` 에 없는 액터가 말하면 **hard** | hard | §2.3 |
| **L-22-15** | `learnsWhen.when` 이 절대 참이 될 수 없으면(솔버 판정) 경고 | warn | 솔버(D-13) |

### 8.3 세력·톤 일관성

| # | 규칙 | 심각도 | 검사 방법 |
|---|---|---|---|
| **L-22-16** | 서로 `relations <= -2` 인 두 세력의 NPC 가 상대 세력을 우호적으로 지칭하면 경고 | warn | 감성 어휘 사전 + 세력 별칭 매칭 |
| **L-22-17** | `relations` 의 `-3`/`+3` 은 대칭이어야 한다 | warn | R-22-6 |
| **L-22-18** | 액터가 자기 세력의 `closedTopics` 를 먼저 꺼내면 경고 | warn | 화제 태그 대조 |
| **L-22-19** | `taboos[].severity:"hard"` 의 `detect.keywords` 가 대사에 등장하면 하드 실패 | hard | §2.5 |
| **L-22-20** | `tone.forbidden` 항목(이모지·현대 용어·영문 약어) 검출 시 경고 | warn | 정규식 + 사전 |
| **L-22-21** | 문장 길이가 `tone.sentenceLength.max` 를 넘으면 경고 | warn | 글자수 |
| **L-22-22** | `properNounStyle:"latin_kept"` 인데 `Necromancer` 를 "네크로맨서" 로 음차하면 경고 | warn | 별칭 사전 역매칭 |

### 8.4 배치·도달성

| # | 규칙 | 심각도 | 검사 방법 |
|---|---|---|---|
| **L-22-23** | 액터의 `place` 와 그 액터를 가리키는 앵커의 맵/영역이 일치해야 한다 | **warn** | 아래 참조 |
| **L-22-24** | 같은 맵의 두 place `regions` rect 가 겹치면 안 된다 | hard | R-22-7 |
| **L-22-25** | `adjacent.via:"walk"` 는 대칭이어야 한다 | warn | R-22-9 |
| **L-22-26** | 어떤 앵커·퀘스트도 가리키지 않는 액터(고아 액터)는 경고 | warn | 역참조 인덱스([BP-26 §5](26_entity_registry_and_anchors.md)) |
| **L-22-27** | `map: null` 인 place 를 `warp`/`reach` 목표가 가리키면 하드 실패 | hard | §4.7 |
| **L-22-28** | 어떤 place 에서도 도달할 수 없는 place(장소 그래프의 고립 노드)는 경고 | warn | 그래프 연결성 |
| **L-22-29** | `sources` 가 없거나 `unobtainable` 뿐인 아이템을 `acquire` 목표가 요구하면 하드 실패 | hard | R-22-21 · D-26 |
| **L-22-30** | 인카운터 평균 레벨이 소속 place `danger` 권장 범위를 ±5 초과 벗어나면 경고 | warn | R-22-27 |

총 **35개** 규칙(hard 15 / warn 20).

### 8.5 심각도 변경 2건과 그 이유

| 규칙 | 초판 | 개정 | 이유 |
|---|---|---|---|
| `L-22-06` | hard | **warn** | 정확한 판정에 대화 그래프·퀘스트 DAG·앵커 조건·`play_dialogue` 체인을 가로지르는 도달성 분석이 필요하고, `chance`/`var_cmp` 가 섞이면 **정확한 판정이 불가능**하다. 보수적 근사(도달 불가가 증명될 때만 보고)로 낮춘다 (REVIEW_BP-22 `F-08`) |
| `L-22-23` | hard | **warn** | [BP-26 Q-26-5](26_entity_registry_and_anchors.md) 가 "NPC 가 퀘스트 진행에 따라 다른 장소로 이동" 을 앵커 `when` 으로 표현하기로 했고, 그때 액터의 `place` 는 **주 거처**를 뜻한다. `place` 가 단일 값인 채로 hard 를 유지하면 그 서사가 표현 불가가 된다 (REVIEW_BP-22 `P-06`) |

- **R-22-28** 액터의 `place` 는 **"주 거처"** 로 정의한다. 앵커가 다른 맵에 있어도 오류가 아니며,
  린트는 "주 거처와 다른 맵에 배치됨" 을 **정보성 경고**로만 보고한다.
- **R-22-29** 다만 액터가 **어떤 앵커에도 배치되지 않으면**(`RG-04`) 여전히 경고다 —
  주 거처 선언과 배치 부재는 다른 문제다.

### 8.6 솔버 2축 판정과의 연결 (D-26)

`L-22-29`(획득 불가 아이템)는 **정적 참조 검사**다. 그런데 D-26 은 그보다 앞선 문제를 드러냈다:
`acquire`/`deliver` 목표가 의존하는 `item_gained`/`item_lost` 월드 이벤트는
**인벤토리 부재로 현재 발행 지점이 없다**(D-20 · BP-91 `W-10`).

- **R-22-30** 아이템 관련 목표는 **모델상 완주 증명(`PROVEN`)을 받아도 `UNSUPPORTED`** 일 수 있다.
  두 축의 판정과 레지스트리 대조는 [BP-34](34_headless_sim_and_solver.md) 소유이고,
  발행 지점 레지스트리 생성은 [BP-35](35_ci_and_build.md) 소유다.
- 이 장의 아이템 카탈로그는 **`SUPPORTED` 가 되는 시점이 [BP-42](42_item_and_inventory.md)
  구현 완료**임을 전제로 작성되었다. 그전까지 아이템 기반 퀘스트는 커밋 가능하되 릴리스에서 차단된다.

---

## 9. 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 9.1 확정한 것

| # | 내용 |
|---|---|
| 1 | 바이블은 **생성 입력이자 검증 기준** 이며 같은 파일이어야 한다(R-22-1~3). `_` 접두 필드는 프롬프트 전용 |
| 2 | `world/lore.json` = `axes` + `chronicle` + `tone` + `taboos`. 연대기의 `order` 가 지식 범위 검사의 시간축 |
| 3 | `world/factions.json` 스키마 + 관계 척도 -3..+3(비대칭 허용, ±3 만 대칭) + `core` 9개 세력 초안 |
| 4 | `world/places.json` 스키마. **place ↔ map 은 1:N, place → map 은 1:1**. `regions`/`kind`/`mood`/`adjacent`/`danger` |
| 4a | **중첩 규칙을 `kind` 2계층으로 재정의**(`F-03` 해소): 컨테이너(town/dungeon/field/keep) ⊃ 구역(interior/landmark). 같은 계층끼리만 겹침 금지. `parent` 필드는 도입하지 않고 rect 로 계산해 `containedBy` 를 굽는다 |
| 5 | `core` 15개 장소 초안 매핑표(TOWN1·GROUND1·DEN1·DEN2·Map013/014/015·Map002/010/011 + 미배치 2곳). **개정 `R-22-7` 을 통과함을 직접 검증** |
| 6 | **G-22-1**: `MapInfos.json` 등록 15개 중 **7개가 존재하지 않는 파일로 해석**된다. **등록이 오히려 폴백을 죽인다**(미등록 `ORIGIN` 은 정상 로드 — 부록 F-4). 로드 실패가 성공으로 보고되고(부록 D-2) 네이티브 스크립트가 **직전 맵 위에 부착**된다(부록 F-2). 해결은 T-22-1(`json` 필드) — 맵 에디터 `registerAs` 는 이미 그 필드를 쓰므로 **수리 대상은 기존 데이터뿐**(부록 H-4) |
| 7 | 액터 스키마 전량 + `role` 16종 / `traits` 16종 닫힌 집합 |
| 8 | **지식 범위(`knowledge`)** — `knows`/`unknown`/`rumorOnly`/`learnsWhen`/`scopeDefault`. 프롬프트 화이트리스트 겸 린트 근거 |
| 9 | `states[]` 로 `npcState` 값 집합을 **선언**하고 미선언 값은 하드 실패(cm2 침묵 실패 방지) |
| 10 | `sprite.objTile` 은 128~143 TALK 범위 강제. `TOWN1.json` 실측(132/129/133/…)으로 검증 |
| 11 | 아이템 스키마 + `category` 9종 + `sources` 9종 + `equip` 매핑 + **`grade`/`unique` 신설**(`I-07`) |
| 11a | **장비가 전투에 반영되지 않는다는 실측 반영**(부록 H-1/H-2): `powOfShield`/`powOfArmor` 는 죽은 필드라 스키마에서 제외, 방어는 **`ac` 하나**뿐, `books.json` 의 ac 10/20 은 초반 전투를 무효화하므로 원작 척도를 쓴다. 원작 HEAD/LEG 슬롯은 v1 미지원(의도적 축소, `S-02`) |
| 12 | `books.json` 미사용 자산과 `HDPlayer.weapon/shield/armor` 정수 ID 의 흡수 대응표 2종. **`legacy.intId` 는 "복원" 이 아니라 "신규 부여"** 이고 v1 세이브의 정수는 `null` + 경고로 처리(`F-09`/부록 H-3) |
| 13 | 원작 파티 아이템·크리스탈·유물 17종 시드 목록. 초판은 `_v1Unimplemented` 플래그로 **8종**의 hard gate 충돌을 우회했고, **3판에서 D-31 의 `do` 25종 확장으로 5종이 정식 `effects` 를 갖게 되어 우회가 3종으로 축소**됐다(`I-20` **해소** · `G-22-2` 해소 · `Q-22-4` 종결). 잔존 3종의 사유는 do 부재가 아니라 런타임 기능 부재·죽은 버프 필드다 |
| 14 | **적 카탈로그 권고안 = A(코드 유지 + `build/enemies.index.json` 생성)**. 근거 4항. `enemy` 는 [BP-21 §4.2](21_content_pack_spec.md) 의 **참조 전용 타입**이고 **정본 표기는 정수 id**(`I-08` 해소) |
| 14a | **실사용 가능한 적은 74종(id 1~74)**. `battle.dart:44` 의 `<= 0` 가드로 `id 0`(Orc)은 소환 불가(부록 B-1). 인덱스에 `summonable` 플래그를 두고 `L-22-31` 이 참조를 차단 |
| 15 | `encounters/encounters.json` 스키마 — 인카운터는 콘텐츠, 적 정의는 코드. **`onEscape` 3분기 신설**(부록 B-2/F-3, 정수 매핑 정본은 BP-27) |
| 16 | **일관성 규칙 35개**(hard 15 / warn 20). 심각도 변경 2건(`L-22-06`·`L-22-23` → warn)과 이유 명시 |
| 17 | 지식 범위 hard gate 의 **검사 대상 범위 확정**(`F-07`): "노드의 **유효 화자**가 그 액터인 `lines`". 팩 확장은 `actors/_knowledge/` 로 해소 |
| 18 | `_aliases` 를 faction/place/actor/item **4개 필드표에 공통 선택 필드로 선언**(`F-06`). 별칭 충돌은 하드 실패 |
| 19 | 솔버 2축(D-26)과의 연결: 아이템 목표는 `PROVEN + UNSUPPORTED` 일 수 있고 BP-42 완료가 `SUPPORTED` 조건 |

### 9.2 다음 장으로 넘긴 것

| 대상 | 내용 |
|---|---|
| [BP-21](21_content_pack_spec.md) | 파일 위치·ID 문법·Condition/Effect DSL(이 장은 참조만) |
| [BP-23](23_quest_model.md) | Objective 의 `talk_to`/`reach`/`acquire`/`deliver`/`defeat` 가 이 장의 액터·장소·아이템·인카운터를 어떻게 참조하는지 |
| [BP-24](24_dialogue_model.md) | `dialogueRouting` 과 대화 `entry` 라우팅의 통합, 남의 팩 액터 확장 파일(`actors/_routing/`) 병합 규칙 |
| [BP-25](25_world_state_and_save.md) | `legacyItemMap` 을 이용한 `HDPlayer.weapon` 정수 → itemId 세이브 마이그레이션 |
| [BP-26](26_entity_registry_and_anchors.md) | 액터 ↔ 좌표 바인딩(앵커), 역참조 인덱스, L-22-23/26 의 구현 |
| [BP-28](28_migration_and_coexistence.md) | `town1.cm2`·`Map002.cm2` 의 테스트용 더미 대사 폐기, 고아 `lore_ep1.cm2` 처리 |
| [BP-33](33_validation_and_lint.md) | L-22-01~35 의 메시지·수정 힌트·별칭 사전 구현, `L-22-06` 근사 알고리즘. **BP-21 의 `CV-nn` 은 그대로 인용**하고 새 번호를 만들지 않는다 |
| [BP-34](34_headless_sim_and_solver.md) | 솔버 2축 판정(D-26)의 `SUPPORTED`/`UNSUPPORTED` 대조 |
| [BP-35](35_ci_and_build.md) | `build/enemies.index.json` 생성(Dart 소스에서 나오는 유일한 산출물, `_sourceHash` 결정론), 액터 `states` 번들 정규화(`I-19`), place `containedBy` 계산 |
| [BP-27](27_runtime_engine.md) | 전투 결과 3값의 정본 매핑(부록 B-2/F-3) |
| [BP-37](37_prompt_contracts.md) | `_summary`/`_voice`/`_toneHint`/`knowledge.knows` 를 컨텍스트 팩으로 조립하는 규칙 |
| [BP-42](42_item_and_inventory.md) | **아이템 실제 데이터·인벤토리 게임 규칙·장비 마이그레이션**(D-18). §6.4 대응표와 §6.5 시드 목록은 BP-42 로 이관 예정인 초안이다. 장착이 `ac` 를 갱신하도록 하는 전투식 변경도 여기 |
| [BP-43](43_content_style_guide.md) | `tone` 규정의 문장 단위 상세(어미 목록, 금지 표현 사전) |

### 9.3 열린 질문

| # | 질문 | 영향 | 잠정 |
|---|---|---|---|
| **Q-22-1** | `TOWN1` vs `CastleLore`(Map014), `GROUND1` vs `LoreContinent`(Map013) 은 `displayName` 이 각각 "로어성"/"로어 대륙"으로 **동일**하다. 재작업본인가, 별개 장소인가? | places 초안 5개 항목 | 초안은 `_v2` 접미로 분리해 두되, 원저자 확인 후 하나를 `retiredIds` 로 은퇴 |
| **Q-22-2** | `books.json` 의 수치(단검 15.0, 가죽갑옷 ac 20)와 원작 `ObjItem.cs`(단검 15.0, 가죽 갑옷 ac 1.0)의 **척도가 다르다**. 어느 쪽을 `core` 기준으로 삼는가? | 전 아이템 밸런스 | 원작 `ObjItem.cs` 를 기준으로 하고 `books.json` 은 버린다(원작 충실). 단 `books.json` 의 "두꺼운옷"처럼 원작에 없는 항목은 살린다 |
| **Q-22-3** | *(해소)* place 의 부모/자식 계층. → §4.3.1 의 **`kind` 2계층 규칙**으로 대체. `parent` 필드는 도입하지 않고 rect 포함 관계를 빌드가 계산한다 | — | 해소 |
| ~~**Q-22-4**~~ | *(**종결** — D-31)* 원작 소비품 효과(SP 회복·해독·의식 회복·부활·버프 부여)에 대응하는 **Effect do 가 v1 DSL 에 없다**(G-22-2 · `I-20`). 추가할 것인가? | 아이템 시스템 완성도 · 초기 시드 8종 | **답: 추가한다.** [BP-21 §7.2.1](21_content_pack_spec.md) 이 `schemaVersion` 1 → 2 승격을 실행하고 3종을 추가했다 — 잠정 이름 `restore_sp`/`cure_status`/`grant_buff` 대신 **정본은 `restore`/`cure`/`grant_buff`**(자원·상태를 인자로 받으므로 이름에 넣지 않는다. 정의는 BP-21 소유). 결과: 초기 시드 8종 중 **5종 해제 · 3종 잔존**(R-22-18 잔존 표). REVIEW_BP-22 `DR-01` 의 "M1 안에 못박을 것" 도 이로써 이행 |
| **Q-22-5** | *(해소)* 적 테이블 수. 실측 **75 엔트리(id 0~74)**, **소환 가능 74종(id 1~74)**. GROUND_TRUTH 부록 B-1 이 이를 확정했고 §10 의 "76종" 은 폐기됨 | 문서 정합 | 74종 기준으로 통일. 이 장·[BP-21 R-21-57](21_content_pack_spec.md) 이 반영 완료 |
| **Q-22-6** | `id: 66 Ancient Evil`, `id: 67 Lord Ahn` 이 적 테이블에 있다. 서사 인물이 랜덤 조우에 나오면 세계관이 깨진다 | 인카운터 배치 | `enc` 정의에서 이 둘은 `kind:"boss"` 전용으로만 쓰고, 랜덤 풀에 넣으면 하드 실패시키는 규칙 추가 검토(BP-33) |
| **Q-22-7** | 지식 범위 검사(L-22-10)의 문자열 매칭은 별칭 사전 품질에 전적으로 의존한다. 별칭이 빠지면 검사가 조용히 통과한다 | 린트 신뢰도 | 역방향 검사(대문자 시작 로마자 토큰 중 사전에 없는 것 경고)를 **v1 필수로 승격**(REVIEW_BP-22 `S-04`). 사전·패턴 원천 파일 위치는 [BP-43](43_content_style_guide.md) 이 지정 |
| **Q-22-8** | 원작 이동 구슬은 목적지를 플레이어가 고르는데 `warp(map,x,y)` 는 고정 목적지뿐이다 | 원작 아이템 이식 | [BP-21 Q-21-9](21_content_pack_spec.md) 와 같은 건. v1 은 고정 목적지만 |
| **Q-22-9** | `L-22-06` 을 warn 으로 낮추면 `states[].from` 위반이 런타임까지 새어 나갈 수 있다. 런타임이 잡아야 하나? | 상태 기계 신뢰도 | 런타임은 `set_npc_state` 시 `from` 위반을 **무시 + ERROR 로그**로 처리한다([BP-21 §6.6 E13](21_content_pack_spec.md)). 조용히 적용하지 않는다 |
| **Q-22-10** | `_v1Unimplemented` 아이템이 인벤토리에 존재하되 쓸 수 없다면, 플레이어에게 어떻게 보이는가? | UX | [BP-42](42_item_and_inventory.md) 소관. "아직 쓸 수 없다" 를 표시할지 아예 드롭 테이블에서 뺄지 결정 필요 |
