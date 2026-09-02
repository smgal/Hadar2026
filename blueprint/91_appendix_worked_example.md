# 부록 B — 엔드투엔드 예제: 퀘스트 1건이 파이프라인을 통과하는 전 과정

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-91 · **상태**: 초안 · **선행 문서**: [BP-90](90_appendix_schemas.md) · [BP-32](32_generation_harness.md)
> **독자**: 파이프라인 구현자 · 생성 에이전트 작성자 · 검수자 · "이 기획서로 정말 일이 되나" 를 확인하려는 사람
> **한 줄 요약**: 원작 세계관의 소박한 튜토리얼 퀘스트 1건을 **기획→생성→바인딩→검증→시뮬레이션→검수→커밋→플레이→세이브**까지 실제 산출물로 관통시키고, 그 과정에서 드러난 스펙의 구멍 13건을 기록한다.

**파이프라인 구획**(D-01): §2~§9 는 **Authoring + Build**, §10~§12 는 **Runtime** 이다.
경계는 §9(commit)다. 그 앞은 LLM 과 도구가 오프라인에서 하고, 그 뒤는 게임이 결정론적으로 해석만 한다.

**이 장이 SSoT 인 것: 없다.** 모든 필드·op·이벤트 이름은 소유 장의 것을 그대로 쓴다(D-18).
쓰다가 발견한 스펙의 부족·모순은 **고치지 않고 §13 에 기록**했다. 그 절이 이 문서의 가장 큰 가치다.

**개정 이력**

| 판 | 반영 내용 |
|---|---|
| 2026-08-30 (초판) | 8단계 전 구간 산출물 · ASCII 목업 7화면 · 런타임 추적 · 세이브 v2 전문 · **드러난 문제 13건(`W-01`~`W-13`) 적발** |
| **2026-09-01 (2판)** | **소유 장이 확정한 것을 예제에 반영하고, 근거가 소멸한 발견을 해소 처리.** ① `W-04` **해소** — D-28 이 region 승격안(BP-26 T1)을 최종 기각해 **1티어 자체가 없어졌다**(§13.2 · [BP-90 §5.2.1 (B)](90_appendix_schemas.md)). ② `W-01` **해소** — [BP-21 §4.1.1](21_content_pack_spec.md) 이 `STRING_KEY` 를 slot-path 로 확장. **이 장의 키를 정규식에 실제 대입해 40/40 통과를 확인**(§4.7.1). ③ `W-07` **해소** — [BP-23 §23.11.1](23_quest_model.md) 이 payload 유일 정본이 되어(`I-01`/`I-18`) 선택할 두 정본이 없어졌다. **§7.2 트레이스와 §11.3~§11.5 의 payload 를 정본으로 교체**. ④ `W-10` **부분 해소** — 솔버 쪽은 D-26 의 2축 판정으로 규정됐다. §7.3 의 판정을 **`PROVEN` + `UNSUPPORTED`** 로 고쳤다. 인벤토리 부재(BP-42)는 여전히 차단. ⑤ `chance` 유도식(D-30)·부록 H-1 정정판·`schemaVersion` 2 승격(D-31)에 대한 이 예제의 정합을 §4.7.1·§12.2·§9.5 에서 점검 |

---

## 1. 예제 설정

### 1.1 무엇을 만드는가

| 항목 | 값 |
|---|---|
| 퀘스트 | `quest.gen_ep1.name_on_ossuary` — **"유골에 새길 이름"** |
| 팩 | `gen_ep1` (생성 팩, `dependsOn: ["core"]`) |
| act / tier | 1 / 1 (튜토리얼급) |
| 무대 | 로어성(`TOWN1`) 안 두 장소 — LORE 주점 → 용사 납골당 |
| 등장 | `npc.core.lore_tavern_drunk`(주점 취객) · `npc.core.lore_crypt_keeper`(납골당지기) |
| 신규 엔티티 | 아이템 1개(`item.gen_ep1.crumpled_roster`) · 대화 3개 · 앵커 1개 |
| 전투 | **없음.** tier 1 은 "말을 거는 법과 저널 보는 법" 을 가르치는 것이 목적 |
| 소요 | 파티 이동 약 60보, 대화 3회 |

### 1.2 원작에서 가져온 재료 (전부 실측)

| 재료 | 출처 | 원문 |
|---|---|---|
| 취객의 사연 | `hadar2026_app/assets/lore_ep1.cm2` `On(17,37)` | "…나의 친구들은 이제 이 세상에 없다네. …내가 다리를 다쳐 병원에 있을 동안 그들은 모두 이 대륙의 평화를 위해 LORE 특공대에 지원 했다네. 하지만 그들은 아무도 다시는 돌아오지 못했어. …그래서 술로 나날을 보내고 있지. 죄책감을 잊기위해서 말이지..." |
| 납골당지기 | 같은 파일 `On(71,77)` | "물러나십시오. 여기는 용사의 유골들을 안치해 놓은 곳입니다." |
| 유골 앞의 목소리 | 같은 파일 `On(62,75)` | "당신이 한 유골 앞에 섰을때 이상한 느낌과 함께 먼 곳으로 부터 어떤 소리가 들려왔다." |
| LORE 특공대 | `faction.core.lore_guard`([BP-22 §3.3](22_world_bible_model.md)) | 같은 대사에서 유도된 세력 |
| 주점 | `place.core.lore_tavern` — `TOWN1` `(8,24,14,16)` | [BP-22 §4.7](22_world_bible_model.md) |
| 납골당 | `place.core.lore_crypt` — `TOWN1` `(58,70,18,16)` | 동상 |
| 파티 | 0번 "슴갈"(에스퍼) · 1번 "유리"(초능력자) | GROUND_TRUTH §10 |

퀘스트의 전제는 **원작 대사의 빈 곳을 메우는 것**이다. 취객은 친구들의 이름이 어디에도 남지 않은 것을
견디지 못한다. 납골당에는 유골만 있고 이름이 없다. 파티가 그 사이를 잇는다.

### 1.3 좌표는 전부 `TOWN1.json` 실측이다

```
$ python3 - <<'PY'
import json
d=json.load(open('hadar2026_app/assets/maps/TOWN1.json'))
w,h,data=d['width'],d['height'],d['data']
cell=lambda x,y:[data[z*w*h+y*w+x] for z in range(6)]
a5=lambda v: v-1536 if v>=1536 else v
for p in [(17,37),(16,37),(71,77),(72,77),(62,76),(62,75)]:
    c=cell(*p); print(p,"A5=",a5(c[0]),"objUpper=",c[3],"region=",c[5])
PY
(17, 37) A5= 0  objUpper= 129 region= 0
(16, 37) A5= 0  objUpper= 0   region= 0
(71, 77) A5= 8  objUpper= 133 region= 0
(72, 77) A5= 8  objUpper= 0   region= 0
(62, 76) A5= 14 objUpper= 0   region= 0
(62, 75) A5= 14 objUpper= 128 region= 0
```

| 좌표 | 판정 ([BP-26 §3.2](26_entity_registry_and_anchors.md)) | 쓰임 |
|---|---|---|
| `(17,37)` | objUpper 129 → **talk** (128~143) | 취객 `actor` 앵커. 이미 core 소유 |
| `(16,37)` | objUpper 0, A5 0 → **move** | 말을 걸 수 있는 인접 칸 (`A-26-04` 충족) |
| `(71,77)` | objUpper 133 → **talk** | 납골당지기 `actor` 앵커. 이미 core 소유 |
| `(72,77)` | A5 8 → **move** | 인접 통행 칸 |
| `(62,76)` | A5 14, objUpper 0 → **move** | **신규 `trigger` 앵커 자리** (밟을 수 있어야 함, `A-26-05`) |
| `(62,75)` | objUpper 128 → **talk** | 원작 유골. **통행 불가** — 여기 `trigger` 를 두면 하드 실패. §6 에서 일부러 실수해 본다 |

### 1.4 **선행 조건: T-22-1 없이는 이 예제가 굴러가지 않는다**

GROUND_TRUTH **부록 D-1** 이 확정한 파손이 이 예제의 정면에 있다.

```
MapInfos.json 의 TOWN1 = id 4  →  map_navigation.dart:38 이 'Map004.json' 으로 해석
                                   Map004.json 은 존재하지 않는다
                                   TOWN1.json 은 존재한다
```

- `TOWN1` 은 **이름으로 로드되지 않는다.** `GROUND1`(→`Map005.json`)·`DEN1`·`DEN2` 도 같다.
- 부록 D-2 때문에 로드 실패는 **실패로 보고되지도 않는다** — `MapBundle(json: null)` 이 "성공" 으로 돌아오고
  맵은 그대로인 채 스크립트만 바뀐다.
- 부록 F-2 가 더한다: `json == null` 이어도 네이티브 맵 스크립트는 붙으므로,
  `Town1MapScript` 가 **직전 맵 위에서** `isOn(x,y)` 를 평가한다.

따라서 **이 예제는 T-22-1 을 전제한다**:

```diff
  // hadar2026_app/assets/maps/MapInfos.json
- {"id":4,"expanded":false,"name":"TOWN1","order":4,"parentId":5,"scrollX":0,"scrollY":0}
+ {"id":4,"expanded":false,"name":"TOWN1","order":4,"parentId":5,"scrollX":0,"scrollY":0,
+  "json":"TOWN1.json"}
- {"id":5,"expanded":false,"name":"GROUND1","order":5,"parentId":1,"scrollX":0,"scrollY":0}
+ {"id":5,"expanded":false,"name":"GROUND1","order":5,"parentId":1,"scrollX":0,"scrollY":0,
+  "json":"GROUND1.json"}
```

코드는 이미 `json` 필드를 지원한다(`map_navigation.dart:44`). **데이터만 고치면 된다.**
빌드는 이것을 스스로 확인한다 — [BP-35 §1.5](35_ci_and_build.md) 의 `mapResolution` 이
`map_navigation.dart:30-51` 과 **똑같은 순서로** 해석하고, 해석 실패면 `V-MAP-016` ERROR 다.
즉 T-22-1 을 하지 않으면 **§9 의 commit 이전에 §6 의 lint 에서 멈춘다.** (§6.4 에서 실제로 확인한다.)

이 예제가 GROUND1 을 직접 쓰지는 않지만, `place.core.lore_continent` 가 `GROUND1` 을 가리키므로
`places.json` 검증이 같은 이유로 걸린다. 두 엔트리를 함께 고쳐야 한다.

### 1.5 8단계 매핑

| 단계 (D-14) | 이 문서의 절 | 산출 디렉토리 ([BP-32 §32.2.3](32_generation_harness.md)) | 주체 |
|---|---|---|---|
| 1 context | §2 | `runs/20260830-gen_ep1-004/01_context/` | 결정론 프로그램 |
| 2 outline | §3 | `02_outline/` | **LLM (Planner)** |
| 3 draft | §4 | `03_draft/` | **LLM (Writer, 2패스)** |
| 4 bind | §5 | `04_bind/` | 결정론 (Binder) |
| 5 lint | §6 | `05_lint/` | 결정론 |
| 6 sim | §7 | `06_sim/` | 결정론 |
| 7 critic | §8 | `07_critic/` | **LLM (Critic)** |
| 8 commit | §9 | `08_commit/` | 결정론 |

주문서(`content_gen/orders/ord-2026-08-30-ossuary.json`):

```json
{
  "orderId": "ord-2026-08-30-ossuary",
  "pack": "gen_ep1",
  "intent": "로어 주점의 취객이 LORE 특공대로 떠나 돌아오지 못한 친구들의 이름을 용사 납골당에 남기고 싶어 한다. 파티가 그 심부름을 맡는 1막 튜토리얼 퀘스트 1건.",
  "count": 1,
  "constraints": {
    "act": 1,
    "tier": 1,
    "maps": ["TOWN1"],
    "mustUseActors": ["npc.core.lore_tavern_drunk", "npc.core.lore_crypt_keeper"],
    "mayCreateActors": 0,
    "mayCreateItems": 1,
    "forbidPlaces": ["place.core.temple_of_knowledge"],
    "tags": ["side", "act1", "tutorial"]
  },
  "seed": 20260830,
  "promptSet": "v1"
}
```

`runId` = `20260830-gen_ep1-004` (R-32-9 형식 `<YYYYMMDD>-<packId>-<seq3>`).

---

## 2. 1단계 `context` — 조립된 컨텍스트 팩

`01_context/budget_report.json` (요약):

```json
{
  "runId": "20260830-gen_ep1-004",
  "agent": "planner",
  "budgetTotal": 57000,
  "blocks": [
    { "id": "S", "priority": "P0", "name": "출력 스키마와 금칙",     "budget": 6000,  "used": 5480, "truncated": false },
    { "id": "T", "priority": "P1", "name": "톤과 금기",              "budget": 3000,  "used": 2140, "truncated": false },
    { "id": "A", "priority": "P2", "name": "등장 인물의 지식과 목소리", "budget": 4000,  "used": 3120, "truncated": false },
    { "id": "W", "priority": "P3", "name": "세계 축과 연대기",        "budget": 8000,  "used": 4310, "truncated": false },
    { "id": "N", "priority": "P4", "name": "인접 콘텐츠 요약",        "budget": 12000, "used": 1890, "truncated": false },
    { "id": "E", "priority": "P5", "name": "예시",                   "budget": 8000,  "used": 7620, "truncated": false },
    { "id": "I", "priority": "P6", "name": "팩 전역 색인",            "budget": 6000,  "used": 940,  "truncated": false },
    { "id": "C", "priority": "P7", "name": "사용 가능 카탈로그",       "budget": 10000, "used": 6050, "truncated": false }
  ],
  "usedTotal": 31550,
  "truncationApplied": false,
  "sourceHashes": {
    "core/world/lore.json": "sha256:3a91…",
    "core/actors/lore_tavern_drunk.json": "sha256:c4e0…",
    "core/actors/lore_crypt_keeper.json": "sha256:81bd…",
    "content.index.json": "sha256:7b20…"
  }
}
```

`01_context/context_pack.md` 의 **[A] 블록 발췌** — 이것이 이 예제의 성패를 가른다:

````markdown
## [A] 등장 인물의 지식과 목소리

### npc.core.lore_tavern_drunk — 주점 취객
- role: `commoner` / traits: `drunk`, `grieving`, `garrulous`
- faction: `faction.core.lore_commoner` / place: `place.core.lore_tavern`
- _summary: LORE 주점 구석에 붙박이로 앉아 있는 중년. 다리를 다쳐 징집에서 빠졌고,
  지원해 간 친구들이 아무도 돌아오지 않은 뒤로 술로 산다.
- _voice: 말이 늘어지고 같은 말을 두 번 한다. "…게나", "…다네" 체.
  파티를 "자네" 라 부른다. 절대 존대하지 않는다.
- knows: place.core.lore_tavern, place.core.lore_castle, faction.core.lore_guard,
         faction.core.lore_commoner, topic:lost_friends, topic:tavern_gossip
- unknown: place.core.temple_of_knowledge, place.core.antares_cave,
           npc.core.red_antares, lore.core.knight_imprisoned, lore.core.antares_vanishes
- rumorOnly: npc.core.necromancer, place.core.menace
- states: on_duty 는 없음 — `drinking`(초기), `hopeful`, `at_peace`
- 원작 대사 원문(1건, 톤 기준):
  "이보게 자네, 내말 좀 들어 보게나. 나의 친구들은 이제 이 세상에 없다네. …"

### npc.core.lore_crypt_keeper — 납골당지기
- role: `priest` / traits: `stern`, `devout`, `weary`
- faction: `faction.core.lore_order` / place: `place.core.lore_crypt`
- _voice: 짧고 각지다. "…하시오", "…이오" 체. 사담을 먼저 꺼내지 않는다.
- knows: place.core.lore_crypt, faction.core.lore_guard, faction.core.lore_order,
         lore.core.founding_of_lore, topic:funeral_rite
- unknown: place.core.temple_of_knowledge, npc.core.red_antares
- states: `guarding`(초기), `recording`, `done`
- 원작 대사 원문: "물러나십시오. 여기는 용사의 유골들을 안치해 놓은 곳입니다."
````

**[T] 블록 발췌**:

```
register: archaic_polite ("…하시오", "…이오")   / 예외 허용: drunk_slur, guard_curt
person: second_person_party (파티를 "당신들")
properNounStyle: latin_kept — Necromancer, MENACE, LORE, Lord Ahn 은 로마자 유지
forbidden: 이모지 / 현대 IT 용어 / 영문 약어(NPC·HP·MP 등 UI 밖) / 메타 농담
길이: 대사 1줄 ≤28자 권장, >45자 에러 · 어절 ≥30자 에러 · 선택지 ≤18자 권장, >24자 에러
```

**[C] 블록 발췌** — Binder 가 쓸 좌표 후보를 **미리** 준다(R-33-22 의 정신):

```
TOWN1 에서 사용 가능한 자리 (빌드가 계산)
  talk 타일(objUpper 128~143), 인접 통행칸 있음:
    (8,63) (71,72) (50,71) (62,26) (12,26) (17,26) (20,32) (23,49) (40,9) (17,37) (71,77) …
  밟을 수 있는 칸(A5 <56, objUpper 0) — trigger 후보:
    (16,37) (18,37) (17,36) (17,38) (72,77) (71,78) (62,76) (61,76) (63,76) …
  region 200~255 예약 구간에 이미 쓰인 값: 없음
```

---

## 3. 2단계 `outline` — Planner 출력

`02_outline/outline.name_on_ossuary.json` — [BP-90 §2.20](90_appendix_schemas.md) `QuestOutline` 을 만족한다.

```json
{
  "runId": "20260830-gen_ep1-004",
  "pack": "gen_ep1",
  "arcRef": null,
  "slugHint": "name_on_ossuary",
  "titleKo": "유골에 새길 이름",
  "premiseKo": "LORE 주점 구석의 취객은 LORE 특공대에 지원해 돌아오지 못한 친구 셋의 이름을 종이에 적어 두고만 있다. 용사 납골당에는 유골만 있고 이름이 없다. 그는 다리 때문에 그 문턱을 넘지 못한다. 파티가 그 종이를 납골당지기에게 건네고 돌아와 알린다.",
  "act": 1,
  "tier": 1,
  "giver": "npc.core.lore_tavern_drunk",
  "place": "place.core.lore_tavern",
  "tags": ["side", "act1", "tutorial"],
  "prerequisitesKo": "없다. 로어성에 들어와 주점에 발을 들이면 언제든 받을 수 있다.",

  "beats": [
    { "id": "b1",
      "whatPlayerDoes": "주점 구석의 취객에게 말을 건다.",
      "whatPlayerLearns": "그의 친구 셋이 LORE 특공대에 지원했고 아무도 돌아오지 않았다는 것.",
      "where": "place.core.lore_tavern",
      "who": ["npc.core.lore_tavern_drunk"],
      "kind": "talk" },
    { "id": "b2",
      "whatPlayerDoes": "구겨진 명부 쪽지를 받는다.",
      "whatPlayerLearns": "그가 이름을 적어만 두고 한 번도 납골당에 가지 못했다는 것.",
      "where": "place.core.lore_tavern",
      "who": ["npc.core.lore_tavern_drunk"],
      "kind": "choice" },
    { "id": "b3",
      "whatPlayerDoes": "성 남쪽 용사 납골당으로 걸어간다.",
      "whatPlayerLearns": "납골당은 유골만 안치할 뿐 이름을 새기지 않는다는 것.",
      "where": "place.core.lore_crypt",
      "who": ["npc.core.lore_crypt_keeper"],
      "kind": "travel" },
    { "id": "b4",
      "whatPlayerDoes": "지기에게 쪽지를 건넨다.",
      "whatPlayerLearns": "이름 없는 유골이 많다는 것, 그리고 지기도 그것을 오래 마음에 두었다는 것.",
      "where": "place.core.lore_crypt",
      "who": ["npc.core.lore_crypt_keeper"],
      "kind": "talk" },
    { "id": "b5",
      "whatPlayerDoes": "돌아와 취객에게 알린다.",
      "whatPlayerLearns": "그가 처음으로 술잔을 내려놓는다는 것.",
      "where": "place.core.lore_tavern",
      "who": ["npc.core.lore_tavern_drunk"],
      "kind": "reveal" }
  ],

  "stages": [
    {
      "idHint": "bring_the_name",
      "journalKo": "취객의 쪽지를 용사 납골당의 지기에게 건넨다.",
      "beatRefs": ["b2", "b3", "b4"],
      "completion": "all",
      "objectives": [
        { "idHint": "o_hand_roster",
          "kind": "deliver",
          "targetHint": "item(구겨진 명부 쪽지) → npc.core.lore_crypt_keeper",
          "reachableBecause": "쪽지는 b2 의 선택지 효과로 지급되고, 지기의 대화 노드가 take_item 을 갖는다." },
        { "idHint": "o_see_the_niche",
          "kind": "reach",
          "targetHint": "TOWN1 의 유골 안치벽 앞. 밟을 수 있는 칸이어야 한다.",
          "reachableBecause": "납골당 내부는 통행 가능하고 지기에게 가는 길목이다.",
          "optional": true }
      ],
      "branchKo": null
    },
    {
      "idHint": "tell_the_drunk",
      "journalKo": "주점으로 돌아가 취객에게 알린다.",
      "beatRefs": ["b5"],
      "completion": "all",
      "objectives": [
        { "idHint": "o_report_back",
          "kind": "talk_to",
          "targetHint": "npc.core.lore_tavern_drunk",
          "reachableBecause": "취객은 주점 (17,37) 에 상주하며 이동하지 않는다." }
      ],
      "branchKo": null
    }
  ],

  "rewards": {
    "grantExp": 900,
    "addGold": 250,
    "addFood": 10,
    "items": [],
    "reputation": 3,
    "worldChangeKo": "취객의 상태가 at_peace 로 바뀌고, 납골당에 이름이 새겨졌다는 플래그가 선다. 이후 다른 성민 대사가 이 사건을 참조할 수 있다."
  },

  "newEntities": [
    { "type": "item",
      "slugHint": "crumpled_roster",
      "nameKo": "구겨진 명부 쪽지",
      "whyNeeded": "전달 목표의 매개물. core 아이템 17종 중 '이름이 적힌 종이' 에 해당하는 것이 없다.",
      "roleHint": null,
      "knowsHint": [],
      "unknownHint": [] },
    { "type": "dlg", "slugHint": "drunk_request", "nameKo": "취객의 부탁",
      "whyNeeded": "취객의 core 대사는 조건 분기가 없는 단발이라 퀘스트 상태별 응답을 담을 수 없다.",
      "unknownHint": [] },
    { "type": "dlg", "slugHint": "keeper_record", "nameKo": "지기의 기록",
      "whyNeeded": "take_item 을 담을 노드가 필요하다(QV-16).",
      "unknownHint": [] },
    { "type": "dlg", "slugHint": "ossuary_niche", "nameKo": "이름 없는 감실",
      "whyNeeded": "선택 목표 o_see_the_niche 의 보상이 되는 서술. 화자 없는 나레이션.",
      "unknownHint": [] }
  ],

  "placementHints": [
    { "subject": "ossuary_niche_trigger",
      "map": "TOWN1",
      "placeKind": "shrine",
      "nearKo": "지기 앞으로 가는 길목의, 유골이 놓인 벽 바로 앞 밟을 수 있는 칸" }
  ],

  "noveltyNote": "gen_ep1 의 기존 6건은 전부 '가서 무엇을 가져온다' 인데, 이 건은 가져오는 것이 사물이 아니라 이름이고 보상도 물건이 아니라 한 사람의 상태 변화다. 전투가 없는 유일한 퀘스트이며 tier 1 중 유일하게 맵을 벗어나지 않는다.",
  "openQuestions": [
    "취객의 상태 slug 를 core 액터에 추가해야 하는데(gen 팩은 core 를 수정할 수 없다), states 확장을 라우팅 확장처럼 별도 파일로 허용하는지 확인 필요.",
    "화자 없는 나레이션 대화를 Dialogue.speaker 필수 스키마로 어떻게 표현하는지 확인 필요."
  ]
}
```

**HG-2 (사람 승인 게이트)** — `openQuestions` 2건이 뜬 채로 승인되었다.
두 질문은 그대로 §13 의 `W-02`·`W-09` 가 된다.

---

## 4. 3단계 `draft` — Writer 출력 실물

Writer 는 2패스다([BP-32 §32.3.3](32_generation_harness.md)): **패스 A(구조)** 가 조건식·효과·그래프를 짜고,
**패스 B(문장)** 가 문자열만 채운다. 아래는 두 패스를 합친 최종 산출물이다.

### 4.1 `03_draft/quests/name_on_ossuary.json`

```json
{
  "id": "quest.gen_ep1.name_on_ossuary",
  "schemaVersion": 1,
  "pack": "gen_ep1",
  "title": "str.gen_ep1.quest.name_on_ossuary.title",
  "summary": "str.gen_ep1.quest.name_on_ossuary.summary",
  "act": 1,
  "tier": 1,
  "giver": "npc.core.lore_tavern_drunk",
  "place": "place.core.lore_tavern",
  "prerequisites": { "op": "true" },
  "autoStart": false,
  "repeatable": false,
  "entryStage": "bring_the_name",
  "stages": [
    {
      "id": "bring_the_name",
      "index": 0,
      "title": "str.gen_ep1.quest.name_on_ossuary.stage.bring_the_name.title",
      "journal": "str.gen_ep1.quest.name_on_ossuary.stage.bring_the_name.journal",
      "completion": "all",
      "objectives": [
        {
          "id": "o_hand_roster",
          "kind": "deliver",
          "params": {
            "item": "item.gen_ep1.crumpled_roster",
            "actor": "npc.core.lore_crypt_keeper",
            "count": 1
          },
          "counter": { "target": 1 },
          "label": "str.gen_ep1.quest.name_on_ossuary.objective.o_hand_roster.desc"
        },
        {
          "id": "o_see_the_niche",
          "kind": "reach",
          "params": { "map": "TOWN1", "x": 62, "y": 76, "radius": 1 },
          "optional": true,
          "counter": { "target": 1 },
          "label": "str.gen_ep1.quest.name_on_ossuary.objective.o_see_the_niche.desc"
        }
      ],
      "onEnter": [],
      "onExit": [],
      "next": "tell_the_drunk"
    },
    {
      "id": "tell_the_drunk",
      "index": 1,
      "title": "str.gen_ep1.quest.name_on_ossuary.stage.tell_the_drunk.title",
      "journal": "str.gen_ep1.quest.name_on_ossuary.stage.tell_the_drunk.journal",
      "completion": "all",
      "objectives": [
        {
          "id": "o_report_back",
          "kind": "talk_to",
          "params": { "actor": "npc.core.lore_tavern_drunk" },
          "counter": { "target": 1 },
          "label": "str.gen_ep1.quest.name_on_ossuary.objective.o_report_back.desc"
        }
      ],
      "onEnter": [],
      "onExit": [],
      "next": "complete"
    }
  ],
  "onComplete": [
    { "do": "set_flag", "id": "flag.gen_ep1.quest.name_on_ossuary.name_recorded" },
    { "do": "set_npc_state", "id": "npc.core.lore_tavern_drunk", "state": "at_peace" },
    { "do": "set_npc_state", "id": "npc.core.lore_crypt_keeper", "state": "done" },
    { "do": "add_var", "id": "var.core.party.reputation_lore", "delta": 3 }
  ],
  "onFail": [],
  "rewards": [
    { "do": "grant_exp", "amount": 900 },
    { "do": "add_gold", "delta": 250 },
    { "do": "add_food", "delta": 10 }
  ],
  "failConditions": null,
  "journal": {
    "bring_the_name": "str.gen_ep1.quest.name_on_ossuary.stage.bring_the_name.journal",
    "tell_the_drunk": "str.gen_ep1.quest.name_on_ossuary.stage.tell_the_drunk.journal"
  },
  "journalComplete": "str.gen_ep1.quest.name_on_ossuary.journal_done",
  "journalFail": null,
  "tags": ["side", "act1", "tutorial"],
  "mutex": [],
  "chainNext": [],
  "generatedBy": "agent:writer-v3/20260830-gen_ep1-004"
}
```

**보상이 티어 권장 범위 안인지 자체 검산** ([BP-23 §23.9.3](23_quest_model.md) tier 1):

| 축 | 값 | 권장 | 판정 |
|---|---|---|---|
| `grant_exp` | 900 | 200 ~ 1,500 | ✅ |
| `add_gold` | 250 | 100 ~ 400 | ✅ |
| `add_food` | 10 | 0 ~ 20 | ✅ |
| `add_var`(평판) | 3 | 1 ~ 5 | ✅ |
| `give_item` | 0개 | 0 ~ 1 | ✅ |

총 보상 가치(§23.9.4 식) = `900 + 250×50 + 10×20 + 3×200 = 14,300`.
같은 팩 tier 1 의 다른 퀘스트가 12,000~16,000 범위이므로 `QV-34`(4배 차이) 걸리지 않는다.

> **참고**: §23.9.4 의 환산식 주석이 *"골드 1 ≈ exp 50 (tier1 기준 900exp/250gold 에서 역산)"* 이라고
> 쓰여 있다. 이 예제의 900/250 은 우연이 아니라 **그 기준점을 그대로 채택한 것**이다.

### 4.2 `03_draft/dialogue/drunk_request.json`

```json
{
  "id": "dlg.gen_ep1.drunk_request",
  "schemaVersion": 1,
  "pack": "gen_ep1",
  "speaker": "npc.core.lore_tavern_drunk",
  "kind": "talk",
  "maxDepth": 16,
  "tags": ["quest_hook"],
  "entry": [
    { "when": { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "completed" },
      "go": "n_thanks" },
    { "when": { "op": "and", "args": [
        { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "active" },
        { "op": "quest_stage", "id": "quest.gen_ep1.name_on_ossuary", "stage": "tell_the_drunk" }
      ] },
      "go": "n_report" },
    { "when": { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "active" },
      "go": "n_waiting" },
    { "go": "n_offer" }
  ],
  "nodes": {
    "n_offer": {
      "id": "n_offer",
      "header": "str.gen_ep1.dlg.drunk_request.node.n_offer.header",
      "lines": [
        "str.gen_ep1.dlg.drunk_request.node.n_offer.line.0",
        "str.gen_ep1.dlg.drunk_request.node.n_offer.line.1",
        "str.gen_ep1.dlg.drunk_request.node.n_offer.line.2",
        "str.gen_ep1.dlg.drunk_request.node.n_offer.line.3"
      ],
      "onEnter": [],
      "choices": [
        { "id": "c_accept",
          "text": "str.gen_ep1.dlg.drunk_request.choice.n_offer.c_accept",
          "effects": [
            { "do": "set_flag", "id": "flag.gen_ep1.quest.name_on_ossuary.heard_out" },
            { "do": "give_item", "id": "item.gen_ep1.crumpled_roster", "count": 1 },
            { "do": "start_quest", "id": "quest.gen_ep1.name_on_ossuary" }
          ],
          "go": "n_give" },
        { "id": "c_decline",
          "text": "str.gen_ep1.dlg.drunk_request.choice.n_offer.c_decline",
          "go": "n_decline" }
      ]
    },
    "n_give": {
      "id": "n_give",
      "header": "str.gen_ep1.dlg.drunk_request.node.n_offer.header",
      "lines": [
        "str.gen_ep1.dlg.drunk_request.node.n_give.line.0",
        "str.gen_ep1.dlg.drunk_request.node.n_give.line.1"
      ],
      "onEnter": [],
      "next": "end"
    },
    "n_decline": {
      "id": "n_decline",
      "header": "str.gen_ep1.dlg.drunk_request.node.n_offer.header",
      "lines": [ "str.gen_ep1.dlg.drunk_request.node.n_decline.line.0" ],
      "onEnter": [],
      "next": "end"
    },
    "n_waiting": {
      "id": "n_waiting",
      "header": "str.gen_ep1.dlg.drunk_request.node.n_offer.header",
      "lines": [
        "str.gen_ep1.dlg.drunk_request.node.n_waiting.line.0",
        "str.gen_ep1.dlg.drunk_request.node.n_waiting.line.1"
      ],
      "onEnter": [],
      "next": "end"
    },
    "n_report": {
      "id": "n_report",
      "header": "str.gen_ep1.dlg.drunk_request.node.n_offer.header",
      "lines": [
        "str.gen_ep1.dlg.drunk_request.node.n_report.line.0",
        "str.gen_ep1.dlg.drunk_request.node.n_report.line.1",
        "str.gen_ep1.dlg.drunk_request.node.n_report.line.2"
      ],
      "onEnter": [],
      "next": "end"
    },
    "n_thanks": {
      "id": "n_thanks",
      "header": "str.gen_ep1.dlg.drunk_request.node.n_offer.header",
      "lines": [
        "str.gen_ep1.dlg.drunk_request.node.n_thanks.line.0",
        "str.gen_ep1.dlg.drunk_request.node.n_thanks.line.1"
      ],
      "onEnter": [],
      "next": "end"
    }
  },
  "_note": "n_report 는 목표 진행만 하고 완료 효과는 퀘스트가 한다. 대화가 complete_quest 를 직접 부르지 않는 것이 중요 — 목표 판정을 우회하면 저널이 어긋난다."
}
```

**중요한 설계 판단 두 가지**

1. `n_report` 는 `complete_quest` 를 **부르지 않는다.** `talk_to` 목표가 `talk` 이벤트로 진행되고,
   stage `tell_the_drunk` 의 `next: "complete"` 가 전이를 만든다. 대화가 직접 완료시키면
   `o_report_back` 의 counter 가 0 인 채로 퀘스트가 끝나 저널이 어긋난다.
2. 모든 노드가 **같은 `header` 키**를 공유한다. 화자가 한 명이므로 헤더도 하나다
   ([BP-24 §24.6.2](24_dialogue_model.md) 의 결정 순서에서 노드 `header` 가 최우선).

### 4.3 `03_draft/dialogue/keeper_record.json`

```json
{
  "id": "dlg.gen_ep1.keeper_record",
  "schemaVersion": 1,
  "pack": "gen_ep1",
  "speaker": "npc.core.lore_crypt_keeper",
  "kind": "talk",
  "maxDepth": 16,
  "tags": ["quest_hook"],
  "entry": [
    { "when": { "op": "and", "args": [
        { "op": "quest_stage", "id": "quest.gen_ep1.name_on_ossuary", "stage": "bring_the_name" },
        { "op": "has_item", "id": "item.gen_ep1.crumpled_roster", "count": 1 }
      ] },
      "go": "n_receive" },
    { "when": { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "completed" },
      "go": "n_after" },
    { "go": "n_idle" }
  ],
  "nodes": {
    "n_idle": {
      "id": "n_idle",
      "header": "str.gen_ep1.dlg.keeper_record.node.n_idle.header",
      "lines": [
        "str.gen_ep1.dlg.keeper_record.node.n_idle.line.0",
        "str.gen_ep1.dlg.keeper_record.node.n_idle.line.1"
      ],
      "onEnter": [],
      "next": "end"
    },
    "n_receive": {
      "id": "n_receive",
      "header": "str.gen_ep1.dlg.keeper_record.node.n_idle.header",
      "lines": [
        "str.gen_ep1.dlg.keeper_record.node.n_receive.line.0",
        "str.gen_ep1.dlg.keeper_record.node.n_receive.line.1",
        "str.gen_ep1.dlg.keeper_record.node.n_receive.line.2"
      ],
      "onEnter": [
        { "do": "take_item", "id": "item.gen_ep1.crumpled_roster", "count": 1 },
        { "do": "set_npc_state", "id": "npc.core.lore_crypt_keeper", "state": "recording" }
      ],
      "next": "end"
    },
    "n_after": {
      "id": "n_after",
      "header": "str.gen_ep1.dlg.keeper_record.node.n_idle.header",
      "lines": [
        "str.gen_ep1.dlg.keeper_record.node.n_after.line.0",
        "str.gen_ep1.dlg.keeper_record.node.n_after.line.1"
      ],
      "onEnter": [],
      "next": "end"
    }
  },
  "_note": "entry 1번의 has_item 이 없으면, 쪽지를 이미 건넨 뒤 다시 말을 걸었을 때 take_item 이 0 으로 클램프되며 경고 로그만 남는다(E6). 조건을 붙이는 편이 옳다 — BP-33 이 '회수 직전 has_item 조건 없음' 을 경고하는 이유."
}
```

### 4.4 `03_draft/dialogue/ossuary_niche.json`

```json
{
  "id": "dlg.gen_ep1.ossuary_niche",
  "schemaVersion": 1,
  "pack": "gen_ep1",
  "speaker": "npc.core.lore_crypt_keeper",
  "kind": "narration",
  "maxDepth": 4,
  "tags": ["ambient", "lore"],
  "entry": [ { "go": "n_look" } ],
  "nodes": {
    "n_look": {
      "id": "n_look",
      "header": "",
      "lines": [
        "str.gen_ep1.dlg.ossuary_niche.node.n_look.line.0",
        "str.gen_ep1.dlg.ossuary_niche.node.n_look.line.1"
      ],
      "onEnter": [],
      "next": "end"
    }
  },
  "_note": "kind:narration 인데 speaker 가 필수라서 지기를 넣었다. 실제로는 아무도 말하지 않고 header 도 없다(header:\"\"). 스키마가 화자 없는 서술을 표현하지 못한다 — §13 W-02."
}
```

### 4.5 `03_draft/items/items.json` (gen_ep1 추가분)

```json
[
  {
    "id": "item.gen_ep1.crumpled_roster",
    "name": "str.gen_ep1.item.crumpled_roster.name",
    "desc": "str.gen_ep1.item.crumpled_roster.desc",
    "category": "quest",
    "stackable": false,
    "value": 0,
    "tradable": false,
    "droppable": false,
    "effects": [],
    "sources": ["npc_gift"],
    "_summary": "취객이 오래 품고 다닌 종이. 이름 셋과 지원 날짜가 번진 잉크로 적혀 있다.",
    "_aliases": ["명부 쪽지", "쪽지", "구겨진 종이"],
    "_note": "category:quest 이므로 effects 는 비어 있어야 한다(R-22-19). tradable/droppable 은 quest 카테고리 기본값과 같지만 명시했다."
  }
]
```

### 4.6 `03_draft/actors/_routing/lore_tavern_drunk.json` — 남의 팩 액터에 붙이는 정상 경로

`core` 액터 파일을 **수정하지 않고** 대화를 붙인다([BP-21 R-21-19](21_content_pack_spec.md) · [BP-22 R-22-14](22_world_bible_model.md)).

```json
{
  "owner": "npc.core.lore_tavern_drunk",
  "pack": "gen_ep1",
  "schemaVersion": 1,
  "routing": [
    { "when": { "op": "or", "args": [
        { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "active" },
        { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "completed" },
        { "op": "not", "arg": { "op": "flag", "id": "flag.gen_ep1.quest.name_on_ossuary.heard_out" } }
      ] },
      "go": "dlg.gen_ep1.drunk_request" }
  ],
  "_note": "core 의 defaultDialogue 는 그대로 남는다. 위 조건이 전부 거짓이면(= 거절하고 플래그만 선 상태) core 의 원작 대사로 떨어진다."
}
```

`03_draft/actors/_routing/lore_crypt_keeper.json` 도 같은 형태다:

```json
{
  "owner": "npc.core.lore_crypt_keeper",
  "pack": "gen_ep1",
  "schemaVersion": 1,
  "routing": [
    { "when": { "op": "or", "args": [
        { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "active" },
        { "op": "quest_state", "id": "quest.gen_ep1.name_on_ossuary", "state": "completed" }
      ] },
      "go": "dlg.gen_ep1.keeper_record" }
  ]
}
```

### 4.7 `03_draft/strings/name_on_ossuary.ko.json` — 발췌

문체는 [BP-22 §2.4](22_world_bible_model.md) `tone`(archaic_polite, latin_kept) 을 따르고,
길이는 [BP-24 §24.5.5](24_dialogue_model.md) 를 따른다. **괄호 안은 한글 환산 길이**(§24.5.5 `weight` 식).

```json
{
  "_meta": { "lang": "ko", "pack": "gen_ep1", "count": 27 },

  "str.gen_ep1.quest.name_on_ossuary.title":   "유골에 새길 이름",
  "str.gen_ep1.quest.name_on_ossuary.summary": "주점 취객이 돌아오지 못한 친구들의 이름을 남기고 싶어 한다.",
  "str.gen_ep1.quest.name_on_ossuary.stage.bring_the_name.title":   "쪽지를 지기에게",
  "str.gen_ep1.quest.name_on_ossuary.stage.bring_the_name.journal": "취객에게서 이름 셋이 적힌 쪽지를 받았다. 용사 납골당의 지기에게 건네야 한다.",
  "str.gen_ep1.quest.name_on_ossuary.stage.tell_the_drunk.title":   "주점으로 돌아가",
  "str.gen_ep1.quest.name_on_ossuary.stage.tell_the_drunk.journal": "지기가 이름을 새기겠다고 했다. 취객에게 돌아가 알려야 한다.",
  "str.gen_ep1.quest.name_on_ossuary.journal_done": "세 이름이 감실에 새겨졌다. 취객은 처음으로 잔을 내려놓았다.",
  "str.gen_ep1.quest.name_on_ossuary.objective.o_hand_roster.desc":   "쪽지를 지기에게 건넨다",
  "str.gen_ep1.quest.name_on_ossuary.objective.o_see_the_niche.desc": "빈 감실 앞에 선다",
  "str.gen_ep1.quest.name_on_ossuary.objective.o_report_back.desc":   "취객에게 돌아가 알린다",

  "str.gen_ep1.item.crumpled_roster.name": "구겨진 명부 쪽지",
  "str.gen_ep1.item.crumpled_roster.desc": "이름 셋과 지원한 날이 적혀 있다. 잉크가 번졌다.",

  "str.gen_ep1.dlg.drunk_request.node.n_offer.header":  "@B주점 구석의 취객",
  "str.gen_ep1.dlg.drunk_request.node.n_offer.line.0":  "이보게 자네, 잠깐 앉아 보게나.",
  "str.gen_ep1.dlg.drunk_request.node.n_offer.line.1":  "내 친구 셋이 @BLORE 특공대@@에 갔다네.",
  "str.gen_ep1.dlg.drunk_request.node.n_offer.line.2":  "그 뒤로 아무도 돌아오지 않았어.",
  "str.gen_ep1.dlg.drunk_request.node.n_offer.line.3":  "이름이라도 남겨야 하지 않겠나.",
  "str.gen_ep1.dlg.drunk_request.choice.n_offer.c_accept":  "쪽지를 받겠소",
  "str.gen_ep1.dlg.drunk_request.choice.n_offer.c_decline": "지금은 어렵소",
  "str.gen_ep1.dlg.drunk_request.node.n_give.line.0":   "고맙네. 이 종이일세.",
  "str.gen_ep1.dlg.drunk_request.node.n_give.line.1":   "성 남쪽 납골당의 지기에게 주게나.",
  "str.gen_ep1.dlg.drunk_request.node.n_decline.line.0": "그런가. 나도 오래 미뤄 온 일일세.",
  "str.gen_ep1.dlg.drunk_request.node.n_waiting.line.0": "아직인가. 서두를 것은 없네.",
  "str.gen_ep1.dlg.drunk_request.node.n_waiting.line.1": "다만 내가 더 늙기 전에 말이지.",
  "str.gen_ep1.dlg.drunk_request.node.n_report.line.0":  "새겨 주었다고? 정말인가.",
  "str.gen_ep1.dlg.drunk_request.node.n_report.line.1":  "…이십 년일세. 이십 년.",
  "str.gen_ep1.dlg.drunk_request.node.n_report.line.2":  "자네들에게 갚을 것이 없구먼.",
  "str.gen_ep1.dlg.drunk_request.node.n_thanks.line.0":  "이제 한 잔만 하고 일어나겠네.",
  "str.gen_ep1.dlg.drunk_request.node.n_thanks.line.1":  "그 아이들 이름을 부르면서 말이지.",

  "str.gen_ep1.dlg.keeper_record.node.n_idle.header":   "@B납골당지기",
  "str.gen_ep1.dlg.keeper_record.node.n_idle.line.0":   "물러나십시오.",
  "str.gen_ep1.dlg.keeper_record.node.n_idle.line.1":   "여기는 용사의 유골을 안치한 곳이오.",
  "str.gen_ep1.dlg.keeper_record.node.n_receive.line.0": "…그 종이를 이리 주시오.",
  "str.gen_ep1.dlg.keeper_record.node.n_receive.line.1": "이름 없는 감실이 셋이었소.",
  "str.gen_ep1.dlg.keeper_record.node.n_receive.line.2": "오늘 그 앞에 이름을 새기겠소.",
  "str.gen_ep1.dlg.keeper_record.node.n_after.line.0":  "세 이름은 잘 새겨 두었소.",
  "str.gen_ep1.dlg.keeper_record.node.n_after.line.1":  "그 사람에게도 그리 전하시오.",

  "str.gen_ep1.dlg.ossuary_niche.node.n_look.line.0": "이름이 새겨지지 않은 감실이",
  "str.gen_ep1.dlg.ossuary_niche.node.n_look.line.1": "셋, 나란히 비어 있다."
}
```

**길이 자체 검산** (Writer 패스 B 가 출력과 함께 낸 표):

| 키 | 한글 환산 | 상한 | 판정 |
|---|---|---|---|
| `…n_offer.line.0` "이보게 자네, 잠깐 앉아 보게나." | 15.0 | 대사 28 권장 / 45 에러 | ✅ 권장 |
| `…n_offer.line.1` "내 친구 셋이 @BLORE 특공대@@에 갔다네." | 16.5 (태그 4칸 제외) | 동상 | ✅ |
| `…n_offer.line.3` "이름이라도 남겨야 하지 않겠나." | 15.0 | 동상 | ✅ |
| `…keeper_record.node.n_idle.line.1` | 19.0 | 동상 | ✅ |
| `choice.n_offer.c_accept` "쪽지를 받겠소" | 7.0 | 선택지 18 권장 / 24 에러 | ✅ |
| `choice.n_offer.c_decline` "지금은 어렵소" | 7.0 | 동상 | ✅ |
| `…n_offer.header` "@B주점 구석의 취객" | 9.0 | 헤더 20 권장 / 28 에러 | ✅ |
| `quest…summary` | 30.0 | 저널 요약 40 권장 / 56 에러 ([BP-41 §41.4.4](41_journal_ui_spec.md)) | ✅ |
| `stage.bring_the_name.journal` | 39.0 | 단계 저널 60 권장 / 84 에러 | ✅ |
| `objective.o_hand_roster.desc` "쪽지를 지기에게 건넨다" | 12.0 | 목표 문구 16 권장 / 21 에러 ([BP-41 §41.4.3](41_journal_ui_spec.md)) | ✅ |
| `objective.o_report_back.desc` "취객에게 돌아가 알린다" | 12.0 | 동상 | ✅ |
| 최장 어절 | "돌아오지"(4자) / "납골당의"(4자) | 어절 20 권장 / 30 에러 | ✅ 여유 |

색상 태그 검사: `@B…@@` 2쌍(헤더 1, 본문 1). 헤더의 `@B주점 구석의 취객` 은 **닫는 `@@` 가 없다** —
원작 `tile_event_dispatcher.dart:117` 의 `'@B푯말에 써 있기를:'` 과 같은 형태다.
[BP-21 §5.5](21_content_pack_spec.md) 의 "한 문자열 안에서 열린 태그는 반드시 닫힌다" 를 **위반한다**.
§6 에서 이 위반이 실제로 잡힌다. → §13 `W-05`

#### 4.7.1 [2판] `STRING_KEY` 대입 검증 — `W-01` 해소 확인

초판은 **이 예제의 문자열 키 26개가 전부 정규식을 통과하지 못한다**고 적었다(`W-01`, 등급 **차단**).
[BP-21 §4.1.1](21_content_pack_spec.md) 이 그것을 받아 **slot 을 단일 세그먼트에서 경로(slot-path)로 확장**했다.
확장이 실제로 이 예제를 통과시키는지 **말로 확인하지 않고 대입해 봤다.**

```
$ python3 - <<'PY'
import re
txt = open('blueprint/91_appendix_worked_example.md', encoding='utf-8').read()
toks = sorted(set(re.findall(r'str\.[A-Za-z0-9_.]+', txt)))
SK = re.compile(r'^str\.[a-z][a-z0-9_]{2,31}'
                r'\.(npc|quest|item|dlg|place|faction|enc|lore|ui)'
                r'\.[a-z][a-z0-9_]{2,47}'
                r'(\.([a-z][a-z0-9_]{1,47}|0|[1-9][0-9]{0,3}))+$')
bad = [t for t in toks if not SK.match(t)]
print("total", len(toks), "pass", len(toks)-len(bad), "fail", len(bad), bad)
PY
total 40 pass 40 fail 0 []
```

**이 장의 `str.` 토큰 40개 전량 통과, 불통과 0.** 초판 기준으로는 같은 검사가 26개 전부 불통과였다.
40 이 26 보다 큰 이유는 초판 이후 §4.7 발췌와 §10 목업에서 인용된 키가 늘었기 때문이며,
**늘어난 것까지 전부 통과**한다. 통과의 근거가 되는 슬롯 형태 4종을 대표 키로 확인하면:

| 슬롯 형태 | 대표 키 | slot-path 세그먼트 | 통과 근거([BP-21 §4.1](21_content_pack_spec.md)) |
|---|---|---|---|
| 노드 + 줄 번호 | `str.gen_ep1.dlg.drunk_request.node.n_offer.line.0` | `node` `n_offer` `line` `0` (4) | `index` 규칙이 **`0` 을 허용**한다(`"0" \| nonzero digit{0,3}`). `line.0` 이 초판 정규식에서 막힌 지점이다 |
| 노드 + 헤더 | `str.gen_ep1.dlg.keeper_record.node.n_idle.header` | `node` `n_idle` `header` (3) | `local-name` 최소 2자 — `n_idle` 이 통과한다(R-21-54) |
| 노드 + 선택지 | `str.gen_ep1.dlg.drunk_request.choice.n_offer.c_accept` | `choice` `n_offer` `c_accept` (3) | 로컬 ID 가 `_` 를 포함해도 세그먼트 하나로 성립 |
| 스테이지 저널 | `str.gen_ep1.quest.name_on_ossuary.stage.bring_the_name.journal` | `stage` `bring_the_name` `journal` (3) | `owner-type` 에 `quest` 가 있고, 전체 길이 62자 ≤ 200(R-21-53) |

**함께 돌린 두 검사**

- **`STATE_KEY`**: `flag.`/`var.` 토큰 9개 중 불통과 3건 — **전부 의도된 비-ID** 다.
  ① `flag.gen_ep1.map.TOWN1.…` 는 §13.3 `W-03` 이 **반례로 인용**하는 대문자 위반,
  ② `flag.gen_ep1.map.town1.` 은 그 정정형의 **접두 서술**, ③ `flag.gen_ep1.quest.` 는 키 접두 서술.
  **실제 키는 전부 통과**한다. (`W-03` 자체는 여전히 미해소 — 소문자화 변환 규칙이 [BP-26](26_entity_registry_and_anchors.md) 에 없다.)
- **`ENTITY_ID`**: 불통과로 잡힌 토큰은 전부 **문자열 키의 꼬리**(`dlg.drunk_request.node.…` 처럼
  `str.<pack>.` 뒤에서 다시 매칭된 조각)이거나 필드 경로 서술(`anchor.when`)·파일명(`lore.json`) 이다.
  **엔티티 ID 로 쓰인 토큰의 불통과는 0** 이다.

> **이 검증이 왜 이 장에 있어야 하나**: `W-01` 은 이 장이 **실제로 만들어 보다가** 발견한 것이고
> ([BP-90](90_appendix_schemas.md) 의 문서 대조로는 나오지 않았다), 소유 장의 수정이 그 발견을 실제로 해소했는지는
> **같은 데이터에 다시 대입해야만** 알 수 있다. "정규식을 고쳤다" 는 서술을 근거로 해소 처리하면
> D-29 가 저지른 실수(요약을 근거로 판단)를 반복한다. → §13.1 `W-01` (**해소**)

---

## 5. 4단계 `bind` — 앵커 배치와 맵 편집

Binder 는 **결정론적 프로그램**이다([BP-32 §32.4.3](32_generation_harness.md)). LLM 이 준 `placementHints`
(좌표가 아니라 "어떤 자리")를 실제 좌표로 바꾸는 것이 이 단계의 전부다.

### 5.1 좌표 선정 근거

`placementHints[0]` = `{subject: "ossuary_niche_trigger", map: "TOWN1", placeKind: "shrine", nearKo: "지기 앞으로 가는 길목의, 유골이 놓인 벽 바로 앞 밟을 수 있는 칸"}`

Binder 의 결정 절차:

```
1. place.core.lore_crypt 의 regions = (58,70,18,16)  → x 58..75, y 70..85 로 후보를 좁힌다
2. 원작 유골 이벤트 좌표를 앵커점으로 삼는다 — lore_ep1.cm2 의 On(62,75)
3. 그 4-이웃 중 A-26-05(앵커 칸 자체가 통행 가능)를 만족하는 칸을 찾는다
     (61,75) A5 13 objUpper 0 → move  ✅
     (63,75) A5 14 objUpper 128 → talk ❌
     (62,74) A5  6 objUpper 0 → move  ✅
     (62,76) A5 14 objUpper 0 → move  ✅
4. 그중 지기(71,77)로 가는 최단 경로 위에 있는 칸을 고른다 → (62,76)
5. 동률이면 (y, x) 사전순으로 고정한다 — 같은 입력이 항상 같은 좌표를 낳아야 한다(D-01)
```

**그런데 Binder 는 1차 시도에서 3번을 건너뛰고 2번의 앵커점 `(62,75)` 를 그대로 썼다.**
"유골이 놓인 벽 **바로 앞**" 이라는 힌트를 "유골 그 자리" 로 해석한 것이다.
이 실수는 §6 에서 잡힌다 — **일부러 남겨 둔 위반 1**이다.

### 5.2 `04_bind/anchors/TOWN1.json` — 1차 (위반 포함)

```json
{
  "schemaVersion": 1,
  "pack": "gen_ep1",
  "map": "TOWN1",
  "anchors": [
    {
      "id": "anchor.gen_ep1.town1_ossuary_niche",
      "kind": "trigger",
      "x": 62,
      "y": 75,
      "once": true,
      "effects": [
        { "do": "play_dialogue", "id": "dlg.gen_ep1.ossuary_nich" }
      ],
      "_note": "빈 감실 앞. 선택 목표 o_see_the_niche 와 같은 자리."
    }
  ]
}
```

**심어 둔 위반 3건**

| # | 위치 | 무엇이 틀렸나 | 잡힐 규칙 |
|---|---|---|---|
| 1 | `/anchors/0` `x:62, y:75` | `kind:"trigger"` 는 `event` 액션을 요구하는데 (62,75) 는 `objUpper 128` → `talk`. 게다가 밟을 수 없다(`A-26-05`) | `V-MAP-*` |
| 2 | `/anchors/0/effects/0/id` `dlg.gen_ep1.ossuary_nich` | 마지막 `e` 누락 오타 | `V-L2-007` |
| 3 | `strings/ko.json` 의 `…n_offer.header` = `"@B주점 구석의 취객"` | 열린 `@B` 를 `@@` 로 닫지 않음 | `V-L1-*` (태그 균형) |

### 5.3 앵커가 요구하는 맵 편집 — 실제 호출

> **⚠ 이 절은 초판 실행 기록이며, D-27·D-28 로 전제가 폐기됐다** (2판 주석 · `W-04` 해소).
> 아래 서술은 *"`trigger` 앵커가 `event` 액션을 필요로 하고, 그 액션을 만드는 유일한 경로가
> region 200~255 예약 승격이다"* 를 전제한다. **그 전제가 둘 다 사라졌다.**
>
> | 초판 전제 | 현재 확정 | 근거 |
> |---|---|---|
> | region 값이 타일 액션을 만든다 | **만들지 못한다.** `map_loader.dart:44` 가 region 을 `ixEvent` 하위 바이트에 넣는데 `tile_properties.dart:187` 은 상위 바이트만 본다 | D-27 · GROUND_TRUTH 부록 J-1 |
> | 그래서 로더를 고쳐 승격시킨다(BP-26 T1) | **최종 기각.** 기술적으로 가능하지만 맵 편집 내구성이 깨진다(누가 region 레이어를 지우면 트리거가 소실) | D-28 (비교표 5항, 4번이 결정적) |
> | 앵커는 맵 데이터에 표시를 남긴다 | **아무 표시도 남기지 않는다.** 콘텐츠 티어가 `(map,x,y)` 로 **트리거 인덱스를 직접 조회**하고, 앵커가 있으면 타일 액션과 **무관하게** 처리한다 | D-27 |
> | 앵커-타일 정합은 하드 실패 | **WARN 으로 강등.** 저작 품질 문제이지 런타임 동작 조건이 아니다(actor 앵커는 마주 볼 수 없으면 대화가 불가하므로 여전히 경고 대상) | D-27 |
>
> **따라서 이 예제를 지금 다시 돌리면 §5.3 의 맵 편집 호출은 아예 일어나지 않는다.**
> `04_bind/map_ops.TOWN1.json` 은 **빈 `ops` 로 산출**되고, 앵커 생성 API 호출 하나만 남는다.
> 아래 400 응답이 잡아낸 **심어 둔 위반 1**(좌표 (62,75)가 밟을 수 없는 칸)은 **여전히 잡힌다** —
> 근거가 "타일 액션이 `event` 가 아니다" 에서 **"`trigger` 앵커 칸이 통행 불가여서 플레이어가 밟을 수 없다"**
> 로 바뀌고 등급이 ERROR → **WARN** 이 되지만, 좌표 후보 3개를 함께 주는 `{error, hint}` 동작은 그대로다.
>
> **절을 지우지 않는 이유**: 이 절의 400 응답과 그 아래 상자가 `W-04` 를 발견한 증거이고,
> D-28 이 "폐기 사실과 이유를 문서에 남기고 삭제만 하지 말 것" 을 명시했다.
> 정본 서술은 [BP-26](26_entity_registry_and_anchors.md) 소유이므로 이 장은 고쳐 쓰지 않고 **주석으로 표시**한다(D-18).

`trigger` 앵커는 `HDTileAction.event` 를 요구하는데, 그 액션을 만드는 경로는
**region 200~255 예약 승격**뿐이다([BP-26 §3.5](26_entity_registry_and_anchors.md) 권고안 T1). *(초판 전제 — 위 주석 참조)*
따라서 Binder 는 맵 편집 op 를 **함께 산출**한다(적용은 하지 않는다 — `04_bind/map_ops.TOWN1.json`).

```json
{
  "map": "TOWN1",
  "file": "TOWN1.json",
  "reason": "anchor.gen_ep1.town1_ossuary_niche (kind=trigger) 가 요구하는 event 액션 부여",
  "ops": [
    { "op": "set", "layer": "region", "x": 62, "y": 75, "b": 200 }
  ],
  "revExpected": "1756499000000"
}
```

적용은 콘텐츠 서버를 통한다. 맵 API 는 기존 것을 그대로 쓴다(GROUND_TRUTH §11):

```bash
$ curl -s -X POST 'http://localhost:5310/api/ai/maps/TOWN1.json/edit' \
    -H 'Content-Type: application/json' \
    -d '{"ops":[{"op":"set","layer":"region","x":62,"y":75,"b":200}]}' | jq .
{
  "ok": true,
  "file": "TOWN1.json",
  "applied": 1,
  "rev": "1756500442117",
  "changed": [ { "layer": "region", "x": 62, "y": 75, "from": 0, "to": 200 } ]
}
```

그리고 앵커 자체는 콘텐츠 서버로 만든다([BP-31 §2.5](31_content_server_api.md) 15번):

```bash
$ curl -s -X POST 'http://localhost:5310/api/content/anchors' \
    -H 'Content-Type: application/json' \
    -d '{
          "pack": "gen_ep1",
          "map": "TOWN1",
          "kind": "trigger",
          "slug": "town1_ossuary_niche",
          "x": 62, "y": 75,
          "once": true,
          "effects": [ { "do": "play_dialogue", "id": "dlg.gen_ep1.ossuary_nich" } ],
          "autoPlaceTile": true
        }' | jq .
{
  "error": "anchor.gen_ep1.town1_ossuary_niche 는 kind=trigger 인데 (62,75) 의 타일 액션이 talk 입니다.",
  "hint": "trigger 는 밟을 수 있는 칸이어야 합니다(A-26-05). objUpper 를 0 으로 지우거나, 인접한 통행 칸으로 옮기세요. 이 근처의 통행 가능 좌표(빌드가 계산): (62,76), (61,75), (62,74)"
}
HTTP/1.1 400 Bad Request
```

**서버가 먼저 막았다.** `autoPlaceTile: true` 로 region 200 을 심어도 `objUpper 128` 이 남아
2티어 판정이 `talk` 로 끝나기 때문이다([BP-26 §3.2](26_entity_registry_and_anchors.md) — 2티어가 3티어보다 먼저다).

> **여기서 드러난 것**: `region` 승격은 `ixEvent` 를 채우므로 **1티어**가 되어 2티어보다 앞선다.
> 즉 region 200 을 심으면 `objUpper 128` 이 있어도 `event` 가 이길 **수도** 있다.
> [BP-26 R-26-10](26_entity_registry_and_anchors.md) 은 "레거시 이벤트가 있으면 그쪽이 이긴다" 만 말하고
> **region 승격과 objUpper 의 우선순위는 말하지 않는다.** 서버와 로더가 다르게 판단할 여지가 있다.
> → §13 `W-04`
>
> **[2판] 이 우려는 소멸했다 (D-28).** region 승격안이 최종 기각되어 **1티어가 존재하지 않으므로
> 1티어 ↔ 2티어 우선순위 문제가 성립하지 않는다.** 앵커는 타일 비트를 전혀 쓰지 않고(D-27),
> 판정의 단일 정본은 **트리거 인덱스**다 — 서버와 런타임이 같은 인덱스를 본다.
> `anchors.schema.json` 에 region 관련 필드가 **애초에 없었고 앞으로도 생기지 않는다**
> ([BP-90 §5.2.1 (B)](90_appendix_schemas.md)). §13.2 의 `W-04` 행을 **해소**로 갱신했다.

### 5.4 `04_bind/bind_report.json` — 1차 결과

```json
{
  "runId": "20260830-gen_ep1-004",
  "attempt": 1,
  "status": "blocked",
  "anchorsPlanned": 1,
  "anchorsCreated": 0,
  "mapOpsPlanned": 1,
  "mapOpsApplied": 1,
  "resolvedReferences": {
    "npc.core.lore_tavern_drunk":  { "found": true,  "anchoredAt": ["anchor.core.town1_tavern_drunk"] },
    "npc.core.lore_crypt_keeper":  { "found": true,  "anchoredAt": ["anchor.core.town1_crypt_keeper"] },
    "item.gen_ep1.crumpled_roster":{ "found": true,  "givenBy": ["dlg.gen_ep1.drunk_request#n_offer/c_accept"] },
    "dlg.gen_ep1.ossuary_nich":    { "found": false, "hint": "dlg.gen_ep1.ossuary_niche (편집 거리 1)" }
  },
  "blockers": [
    { "code": "anchor_tile_mismatch", "anchor": "anchor.gen_ep1.town1_ossuary_niche",
      "at": [62, 75], "required": "event", "actual": "talk",
      "candidates": [[62,76],[61,75],[62,74]] },
    { "code": "unresolved_reference", "path": "/anchors/0/effects/0/id",
      "value": "dlg.gen_ep1.ossuary_nich" }
  ]
}
```

- **R-32-7 준수**: Binder 는 앞 단계(`03_draft/`)를 고치지 않는다. `blocked` 로 멈추고 보고만 한다.
- 맵 op 는 이미 적용됐다(`mapOpsApplied: 1`). **되돌리기가 필요하다** — 앵커가 (62,76) 으로 옮겨지면
  (62,75) 의 region 200 은 고아가 된다. 이 되돌림 절차가 어느 장에도 없다. → §13 `W-06`

---

## 6. 5단계 `lint` — 세 가지 출력

`hadar_content lint` 는 `--format={human|ci|ai}` 로 **같은 진단 목록을 다르게 직렬화**한다
([BP-33 §7](33_validation_and_lint.md)). 아래 셋은 **같은 실행의 세 표현**이다.

### 6.1 사람용 (`--format=human`)

```
$ hadar_content lint --pack gen_ep1

콘텐츠 린트 — gen_ep1 v0.4.0 (schemaVersion 1)
스캔: 파일 9개 · 액터 0(참조 2) · 퀘스트 1 · 대화 3 · 앵커 1 · 문자열 38
경고 밀도: 0.22 (상한 0.50)

━━ ERROR 3건 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 ✗ V-MAP-002  anchors/TOWN1.json:9  #/anchors/0
   앵커 "anchor.gen_ep1.town1_ossuary_niche" 는 kind=trigger 인데
   TOWN1(62,75) 의 타일 액션이 talk 입니다 (요구: event).
   → trigger 는 파티가 밟을 수 있는 칸이어야 합니다(A-26-05).
     이 근처의 통행 가능 좌표: (62,76), (61,75), (62,74)
   fix: suggest — `hadar_content fix --rule V-MAP-002 --accept 1`

 ✗ V-L2-007  anchors/TOWN1.json:12  #/anchors/0/effects/0/id
   존재하지 않는 대화 "dlg.gen_ep1.ossuary_nich" 를 참조합니다.
   → 비슷한 id: dlg.gen_ep1.ossuary_niche (편집 거리 1)
   fix: suggest — `hadar_content fix --rule V-L2-007 --accept 1`

 ✗ V-L1-014  strings/ko.json  key=str.gen_ep1.dlg.drunk_request.node.n_offer.header
   색상 태그가 닫히지 않았습니다: "@B주점 구석의 취객"
   → @B 로 연 구간은 같은 문자열 안에서 @@ 로 닫아야 합니다(BP-21 §5.5).
     문자열 경계를 넘는 태그는 허용되지 않습니다.
   fix: 제안 — "@B주점 구석의 취객@@"

━━ WARN 2건 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 ⚠ V-L4-021  dialogue/keeper_record.json  #/nodes/n_receive/onEnter/0
   take_item 직전에 has_item 조건이 보이지 않습니다.
   → 이 노드는 entry 조건에서 has_item 을 확인하므로 실제로는 안전합니다.
     억제하려면 // lint-ignore: V-L4-021 를 _note 에 넣으세요.

 ⚠ V-MAP-011  anchors/TOWN1.json  (17,37) (71,77)
   앵커와 레거시 cm2 좌표 핸들러가 함께 있습니다(이관 미완료).
   → lore_ep1.cm2 의 On(17,37)/On(71,77) 이 같은 좌표를 잡습니다.
     티어 0 이 먼저 처리하므로 동작은 정상이나, cm2 쪽을 정리하면 경고가 사라집니다.

━━ 요약 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ERROR 3 · WARN 2 · INFO 1      게이트: 차단됨
  계층별  L1:1  L2:1  L3:0  L4:1  MAP:2  DET:0  L5:미실행(ERROR 존재)
  소요    L1 4ms · L2 9ms · L3 11ms · L4 180ms      합계 204ms

종료 코드 2
```

### 6.2 CI 용 (`--format=ci`)

stdout — GitHub Actions 워크플로 명령(PR diff 에 인라인 주석이 붙는다):

```
::error file=hadar2026_app/assets/content/gen_ep1/anchors/TOWN1.json,line=9,title=V-MAP-002::앵커 "anchor.gen_ep1.town1_ossuary_niche" 는 kind=trigger 인데 TOWN1(62,75) 의 타일 액션이 talk 입니다. 통행 가능 좌표: (62,76), (61,75), (62,74)
::error file=hadar2026_app/assets/content/gen_ep1/anchors/TOWN1.json,line=12,title=V-L2-007::존재하지 않는 대화 "dlg.gen_ep1.ossuary_nich" 를 참조합니다. 비슷한 id: dlg.gen_ep1.ossuary_niche
::error file=hadar2026_app/assets/content/gen_ep1/strings/ko.json,line=17,title=V-L1-014::색상 태그가 닫히지 않았습니다: "@B주점 구석의 취객"
::warning file=hadar2026_app/assets/content/gen_ep1/dialogue/keeper_record.json,line=31,title=V-L4-021::take_item 직전에 has_item 조건이 보이지 않습니다.
::warning file=hadar2026_app/assets/content/gen_ep1/anchors/TOWN1.json,line=6,title=V-MAP-011::앵커와 레거시 cm2 좌표 핸들러가 함께 있습니다.
```

`--out 05_lint/lint_report.json` (기계 판독, `file` → `ptr` → `rule` 정렬 — R-33-16):

```json
{
  "tool": "hadar_content",
  "toolVersion": "0.4.0",
  "schemaVersion": 1,
  "pack": { "id": "gen_ep1", "version": "0.4.0" },
  "gate": "blocked",
  "counts": { "error": 3, "warn": 2, "info": 1 },
  "byLayer": { "L1": 1, "L2": 1, "L3": 0, "L4": 1, "MAP": 2, "DET": 0, "L5": null },
  "timingsMs": { "L1": 4, "L2": 9, "L3": 11, "L4": 180, "total": 204 },
  "diagnostics": [
    {
      "rule": "V-MAP-002", "severity": "ERROR", "layer": "L4", "target": "anchor",
      "where": {
        "pack": "gen_ep1",
        "file": "hadar2026_app/assets/content/gen_ep1/anchors/TOWN1.json",
        "line": 9, "col": 7,
        "ptr": "/anchors/0",
        "entity": "anchor.gen_ep1.town1_ossuary_niche"
      },
      "error": "kind=trigger 인데 TOWN1(62,75) 의 타일 액션이 talk 입니다 (요구: event).",
      "hint": "trigger 는 파티가 밟을 수 있는 칸이어야 합니다(A-26-05).",
      "fix": { "kind": "suggest", "candidates": [ { "x": 62, "y": 76 }, { "x": 61, "y": 75 }, { "x": 62, "y": 74 } ] }
    },
    {
      "rule": "V-L2-007", "severity": "ERROR", "layer": "L2", "target": "anchor",
      "where": {
        "pack": "gen_ep1",
        "file": "hadar2026_app/assets/content/gen_ep1/anchors/TOWN1.json",
        "line": 12, "col": 41,
        "ptr": "/anchors/0/effects/0/id",
        "entity": "anchor.gen_ep1.town1_ossuary_niche"
      },
      "error": "존재하지 않는 대화 \"dlg.gen_ep1.ossuary_nich\" 를 참조합니다.",
      "hint": "비슷한 id: dlg.gen_ep1.ossuary_niche (편집 거리 1)",
      "fix": { "kind": "suggest", "candidates": ["dlg.gen_ep1.ossuary_niche"] }
    },
    {
      "rule": "V-L1-014", "severity": "ERROR", "layer": "L1", "target": "string",
      "where": {
        "pack": "gen_ep1",
        "file": "hadar2026_app/assets/content/gen_ep1/strings/ko.json",
        "line": 17, "col": 56,
        "ptr": "/str.gen_ep1.dlg.drunk_request.node.n_offer.header",
        "entity": "str.gen_ep1.dlg.drunk_request.node.n_offer.header"
      },
      "error": "색상 태그가 닫히지 않았습니다: \"@B주점 구석의 취객\"",
      "hint": "@B 로 연 구간은 같은 문자열 안에서 @@ 로 닫아야 합니다.",
      "fix": { "kind": "suggest", "candidates": ["@B주점 구석의 취객@@"] }
    }
  ]
}
```

### 6.3 AI 재시도용 (`--format=ai`)

**그대로 다음 턴 프롬프트에 붙여 넣는 형태**다. ERROR 만 "고쳐야 할 것" 에 넣고 WARN 은 맨 아래로 접는다(R-33-18).

````markdown
## 콘텐츠 검증 실패 — 수정 후 다시 제출하세요

당신이 만든 팩 `gen_ep1` (v0.4.0) 이 검증을 통과하지 못했습니다.
아래 3건을 **전부** 고쳐서 해당 파일 전체를 다시 출력하세요.
스키마와 허용 값 목록은 이전 턴에서 준 것과 동일합니다. 다시 요청하지 마세요.

### 고쳐야 할 것

1. [V-MAP-002] `anchors/TOWN1.json` → `/anchors/0`
   - 현재 값: `{"kind":"trigger","x":62,"y":75}`
   - 문제: TOWN1(62,75) 는 objUpper 가 128 이라 타일 액션이 `talk` 이고 **밟을 수 없습니다**.
     `kind:"trigger"` 는 파티가 그 칸을 밟아야 발동하므로 통행 가능한 칸이어야 합니다.
   - 그 근처에서 통행 가능한 좌표(빌드가 계산): (62,76), (61,75), (62,74)
   - 조치: 셋 중 하나로 좌표를 옮기세요. (62,76) 이 납골당지기(71,77)로 가는 경로 위에 있습니다.
     맵을 고쳐야 한다면 맵 에디터 API 호출을 함께 제안하세요.

2. [V-L2-007] `anchors/TOWN1.json` → `/anchors/0/effects/0/id`
   - 현재 값: `"dlg.gen_ep1.ossuary_nich"`
   - 문제: 그런 대화가 없습니다.
   - 이 팩에서 참조 가능한 대화 전량:
     `dlg.gen_ep1.drunk_request`, `dlg.gen_ep1.keeper_record`, `dlg.gen_ep1.ossuary_niche`
   - 조치: 위 목록 중 하나로 바꾸세요.

3. [V-L1-014] `strings/ko.json` → 키 `str.gen_ep1.dlg.drunk_request.node.n_offer.header`
   - 현재 값: `"@B주점 구석의 취객"`
   - 문제: `@B` 로 연 색상 구간이 닫히지 않았습니다. 한 문자열 안에서 `@@` 로 닫아야 합니다.
   - 조치: `"@B주점 구석의 취객@@"` 로 바꾸세요.

### 출력 규칙

- 고친 파일만, 파일당 하나의 ```json 블록으로 출력. 블록 앞줄에 `<!-- file: <상대경로> -->` 를 쓰세요.
- 위에 언급되지 않은 필드·파일은 **바꾸지 마세요**.
- 새 문자열을 쓸 때는 인라인 한국어를 넣지 말고 `strings/ko.json` 에 키를 추가하세요.
- 설명 문장을 덧붙이지 마세요. 코드 블록만 출력하세요.

### 참고 (지금은 고치지 않아도 됨)
경고 2건이 있습니다. 대표: `take_item` 직전 `has_item` 조건 부재(V-L4-021) — 이 건은
entry 조건이 이미 확인하므로 무시해도 됩니다.
````

### 6.4 재시도 후 (2차)

Binder 가 위 3건을 반영한 `04_bind/anchors/TOWN1.json`:

```json
{
  "schemaVersion": 1,
  "pack": "gen_ep1",
  "map": "TOWN1",
  "anchors": [
    {
      "id": "anchor.gen_ep1.town1_ossuary_niche",
      "kind": "trigger",
      "x": 62,
      "y": 76,
      "once": true,
      "onceFlag": "flag.gen_ep1.map.town1.ossuary_niche_fired",
      "effects": [
        { "do": "play_dialogue", "id": "dlg.gen_ep1.ossuary_niche" }
      ],
      "_note": "빈 감실 앞 통행 칸. (62,75) 의 유골은 core 의 talk 앵커로 남는다."
    }
  ]
}
```

- `onceFlag` 를 **명시했다.** [BP-26 §2.3](26_entity_registry_and_anchors.md) 의 자동 생성 규칙은
  `flag.<pack>.map.<mapname>.<anchor_slug>_fired` 인데, `<mapname>` 이 `TOWN1` 이면
  `flag.gen_ep1.map.TOWN1.…` 가 되어 **상태 키 문법(소문자만)을 위반한다**. 소문자화 규칙이 없어
  Binder 가 손으로 `town1` 을 넣었다. → §13 `W-03`

맵 편집 되돌림 + 재적용:

```bash
$ curl -s -X POST 'http://localhost:5310/api/ai/maps/TOWN1.json/edit' \
    -H 'Content-Type: application/json' \
    -d '{"ops":[{"op":"set","layer":"region","x":62,"y":75,"b":0},
                {"op":"set","layer":"region","x":62,"y":76,"b":200}]}' | jq '.changed'
[
  { "layer": "region", "x": 62, "y": 75, "from": 200, "to": 0 },
  { "layer": "region", "x": 62, "y": 76, "from": 0,   "to": 200 }
]
```

2차 린트:

```
$ hadar_content lint --pack gen_ep1

콘텐츠 린트 — gen_ep1 v0.4.0 (schemaVersion 1)
스캔: 파일 9개 · 액터 0(참조 2) · 퀘스트 1 · 대화 3 · 앵커 1 · 문자열 38
경고 밀도: 0.22 (상한 0.50)

━━ ERROR 0건 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━ WARN 2건 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ⚠ V-L4-021  dialogue/keeper_record.json  take_item 직전 has_item 조건 부재
 ⚠ V-MAP-011 anchors/TOWN1.json  (17,37) (71,77) 레거시 cm2 좌표 중복

━━ 요약 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ERROR 0 · WARN 2 · INFO 1      게이트: 통과 (L5 진행 가능)
  계층별  L1:0  L2:0  L3:0  L4:1  MAP:1  DET:0  L5:대기
  소요    합계 198ms

종료 코드 0
```

### 6.5 T-22-1 을 하지 않았다면 여기서 멈춘다

§1.4 의 선행 조건을 건너뛰고 같은 린트를 돌리면:

```
 ✗ V-MAP-016  (build)  mapResolution
   맵 이름 "TOWN1" 이 Map004.json 으로 해석되는데 그 파일이 없습니다.
   → MapInfos.json 의 id=4 엔트리에 "json": "TOWN1.json" 을 추가하세요.
     코드는 이미 이 필드를 지원합니다(map_navigation.dart:44).
     같은 문제: GROUND1→Map005.json, DEN1→Map006.json, DEN2→Map007.json,
                Template_TOWN→Map008.json, Prolog→Map009.json, Template_DUNGEON→Map012.json
 ✗ V-L2-*    anchors/TOWN1.json  맵 "TOWN1" 을 해석할 수 없어 앵커 좌표를 검증할 수 없습니다.
 ✗ V-L2-*    quests/name_on_ossuary.json  #/stages/0/objectives/1/params/map  동상

종료 코드 2
```

**부록 D-1 의 7건이 빌드를 통과할 수 없다**는 것이 [BP-35 R-35-11](35_ci_and_build.md) 의 의도다.
현행 게임은 이 실패를 조용히 삼키지만(부록 D-2), 콘텐츠 빌드는 삼키지 않는다.

---

## 7. 6단계 `sim` — 헤드리스 시뮬레이션과 완주 증명

### 7.1 시나리오 2종

| 시나리오 | 정책 | 무엇을 고정하나 |
|---|---|---|
| `q.gen_ep1.ossuary.happy` | `scripted` | 정상 완주 경로. 골든 트레이스 대상 |
| `q.gen_ep1.ossuary.refuse` | `scripted` | 거절 → 다시 말 걸어 수락. 라우팅 폴백 확인 |

### 7.2 `06_sim/trace.name_on_ossuary.json` — 발췌

전량은 `seq` 0~91 이다. 아래는 **수주 · 전달 · 완료** 세 대목만 뽑았다.
포맷은 [BP-34 §3.6](34_headless_sim_and_solver.md) `traceVersion: 1`.

```jsonc
{
  "traceVersion": 1,
  "meta": {
    "scenarioId": "q.gen_ep1.ossuary.happy",
    "policy": "scripted",
    "seed": 20260830,
    "contentLockHash": "c0de91a4f2",
    "packVersions": { "core": "1.0.0", "gen_ep1": "0.4.0" },
    "engineSchemaVersion": 2,
    "startMap": "TOWN1", "startX": 16, "startY": 40,
    "assetMisses": [],
    "stop": "goalsCompleted",
    "steps": 61,
    "finalStateHash": "a71b0d4c9e",
    "coverage": { "anchors": 3, "anchorsTotal": 3,
                  "dialogueNodes": 7, "dialogueNodesTotal": 11,
                  "questStages": 2, "questStagesTotal": 2, "maps": 1, "places": 2 }
  },
  "events": [
    { "seq": 0, "step": 0, "kind": "boot",
      "data": { "bundle": "assets/content/build/content.bundle.json", "anchorCount": 119 } },
    { "seq": 1, "step": 0, "kind": "map_enter",
      "data": { "map": "TOWN1", "x": 16, "y": 40, "place": "place.core.lore_tavern" } },
    { "seq": 2, "step": 1, "kind": "world_event",
      "data": { "type": "enter_place",
                "payload": { "placeId": "place.core.lore_tavern", "map": "TOWN1", "x": 16, "y": 40 } } },

    /* ── 주점 구석까지 3보 이동 후 취객에게 말 걸기 ───────────────── */
    { "seq": 6, "step": 4, "kind": "move",
      "data": { "outcome": "moved", "dx": 0, "dy": -1, "from": [16,38], "to": [16,37],
                "action": "move", "faced": 1 } },
    { "seq": 7, "step": 5, "kind": "move",
      "data": { "outcome": "interacted", "dx": 1, "dy": 0, "from": [16,37], "to": [17,37],
                "action": "talk", "faced": 2 } },
    { "seq": 8, "step": 5, "kind": "tier",
      "data": { "chosen": "content", "anchor": "anchor.core.town1_tavern_drunk", "x": 17, "y": 37 } },
    { "seq": 9, "step": 5, "kind": "narrative_begin", "data": {} },
    { "seq": 10, "step": 5, "kind": "world_event",
      "data": { "type": "talk",
                "payload": { "actorId": "npc.core.lore_tavern_drunk",
                             "dialogueId": "dlg.gen_ep1.drunk_request",
                             "map": "TOWN1", "x": 17, "y": 37 } } },
    { "seq": 11, "step": 5, "kind": "dialogue_enter",
      "data": { "dialogue": "dlg.gen_ep1.drunk_request", "entryIndex": 3, "node": "n_offer" } },
    { "seq": 12, "step": 5, "kind": "clear_logs", "data": {} },
    { "seq": 13, "step": 5, "kind": "header",
      "data": { "text": "@B주점 구석의 취객@@" } },
    { "seq": 14, "step": 5, "kind": "log",
      "data": { "lane": "dialogue", "text": "이보게 자네, 잠깐 앉아 보게나." } },
    { "seq": 15, "step": 5, "kind": "log",
      "data": { "lane": "dialogue", "text": "내 친구 셋이 @BLORE 특공대@@에 갔다네." } },
    { "seq": 16, "step": 5, "kind": "log",
      "data": { "lane": "dialogue", "text": "그 뒤로 아무도 돌아오지 않았어." } },
    { "seq": 17, "step": 5, "kind": "log",
      "data": { "lane": "dialogue", "text": "이름이라도 남겨야 하지 않겠나." } },
    { "seq": 18, "step": 5, "kind": "menu",
      "data": { "kind": "console", "title": "",
                "choices": ["쪽지를 받겠소", "지금은 어렵소"], "chosen": 1 } },
    { "seq": 19, "step": 5, "kind": "dialogue_choice",
      "data": { "dialogue": "dlg.gen_ep1.drunk_request", "node": "n_offer", "choice": "c_accept" } },
    { "seq": 20, "step": 5, "kind": "world_event",
      "data": { "type": "dialogue_choice",
                "payload": { "dialogueId": "dlg.gen_ep1.drunk_request",
                             "nodeId": "n_offer", "choiceId": "c_accept" } } },
    { "seq": 21, "step": 5, "kind": "effect",
      "data": { "do": "set_flag", "id": "flag.gen_ep1.quest.name_on_ossuary.heard_out", "applied": true } },
    { "seq": 22, "step": 5, "kind": "world_event",
      "data": { "type": "flag_changed",
                "payload": { "flagId": "flag.gen_ep1.quest.name_on_ossuary.heard_out", "value": true } } },
    { "seq": 23, "step": 5, "kind": "effect",
      "data": { "do": "give_item", "id": "item.gen_ep1.crumpled_roster", "applied": true } },
    { "seq": 24, "step": 5, "kind": "world_event",
      "data": { "type": "item_gained",
                "payload": { "itemId": "item.gen_ep1.crumpled_roster", "delta": 1, "total": 1 } } },
    { "seq": 25, "step": 5, "kind": "effect",
      "data": { "do": "start_quest", "id": "quest.gen_ep1.name_on_ossuary", "applied": true } },
    { "seq": 26, "step": 5, "kind": "quest_state",
      "data": { "quest": "quest.gen_ep1.name_on_ossuary", "state": "active",
                "stage": "bring_the_name",
                "counters": { "o_hand_roster": 0, "o_see_the_niche": 0 } } },
    { "seq": 27, "step": 5, "kind": "dialogue_node",
      "data": { "dialogue": "dlg.gen_ep1.drunk_request", "node": "n_give", "from": "n_offer" } },
    { "seq": 30, "step": 5, "kind": "dialogue_exit",
      "data": { "dialogue": "dlg.gen_ep1.drunk_request", "lastNode": "n_give",
                "reachedEnd": true, "nodesVisited": 2 } },
    { "seq": 31, "step": 5, "kind": "narrative_end", "data": { "autoFlush": true } },

    /* ── 납골당까지 이동, (62,76) 밟기 ─────────────────────────────── */
    { "seq": 58, "step": 38, "kind": "world_event",
      "data": { "type": "enter_place",
                "payload": { "placeId": "place.core.lore_crypt", "map": "TOWN1", "x": 62, "y": 70 } } },
    { "seq": 62, "step": 41, "kind": "move",
      "data": { "outcome": "moved", "dx": 0, "dy": 1, "from": [62,75], "to": [62,76],
                "action": "event", "faced": 0 } },
    { "seq": 63, "step": 41, "kind": "world_event",
      "data": { "type": "step_tile",
                "payload": { "map": "TOWN1", "x": 62, "y": 76, "action": "move" } } },
    { "seq": 64, "step": 41, "kind": "tier",
      "data": { "chosen": "content", "anchor": "anchor.gen_ep1.town1_ossuary_niche", "x": 62, "y": 76 } },
    { "seq": 65, "step": 41, "kind": "dialogue_enter",
      "data": { "dialogue": "dlg.gen_ep1.ossuary_niche", "entryIndex": 0, "node": "n_look" } },
    { "seq": 68, "step": 41, "kind": "dialogue_exit",
      "data": { "dialogue": "dlg.gen_ep1.ossuary_niche", "lastNode": "n_look",
                "reachedEnd": true, "nodesVisited": 1 } },
    { "seq": 69, "step": 41, "kind": "quest_state",
      "data": { "quest": "quest.gen_ep1.name_on_ossuary", "state": "active",
                "stage": "bring_the_name",
                "counters": { "o_hand_roster": 0, "o_see_the_niche": 1 } } },

    /* ── 지기에게 전달 → 스테이지 전이 ────────────────────────────── */
    { "seq": 76, "step": 47, "kind": "world_event",
      "data": { "type": "talk",
                "payload": { "actorId": "npc.core.lore_crypt_keeper",
                             "dialogueId": "dlg.gen_ep1.keeper_record",
                             "map": "TOWN1", "x": 71, "y": 77 } } },
    { "seq": 77, "step": 47, "kind": "dialogue_enter",
      "data": { "dialogue": "dlg.gen_ep1.keeper_record", "entryIndex": 0, "node": "n_receive" } },
    { "seq": 78, "step": 47, "kind": "effect",
      "data": { "do": "take_item", "id": "item.gen_ep1.crumpled_roster", "applied": true } },
    { "seq": 79, "step": 47, "kind": "world_event",
      "data": { "type": "item_lost",
                "payload": { "itemId": "item.gen_ep1.crumpled_roster", "delta": 1, "total": 0 } } },
    { "seq": 80, "step": 47, "kind": "effect",
      "data": { "do": "set_npc_state", "id": "npc.core.lore_crypt_keeper",
                "state": "recording", "applied": true } },
    { "seq": 84, "step": 47, "kind": "dialogue_exit",
      "data": { "dialogue": "dlg.gen_ep1.keeper_record", "lastNode": "n_receive",
                "reachedEnd": true, "nodesVisited": 1 } },
    { "seq": 85, "step": 47, "kind": "quest_state",
      "data": { "quest": "quest.gen_ep1.name_on_ossuary", "state": "active",
                "stage": "tell_the_drunk", "counters": { "o_report_back": 0 } } },

    /* ── 주점 복귀 → 완료 ─────────────────────────────────────────── */
    { "seq": 88, "step": 61, "kind": "world_event",
      "data": { "type": "talk",
                "payload": { "actorId": "npc.core.lore_tavern_drunk",
                             "dialogueId": "dlg.gen_ep1.drunk_request",
                             "map": "TOWN1", "x": 17, "y": 37 } } },
    { "seq": 89, "step": 61, "kind": "quest_state",
      "data": { "quest": "quest.gen_ep1.name_on_ossuary", "state": "completed", "stage": null,
                "counters": { "o_report_back": 1 } } },
    { "seq": 90, "step": 61, "kind": "effect",
      "data": { "do": "grant_exp", "amount": 900, "applied": true } },
    { "seq": 91, "step": 61, "kind": "state_snapshot",
      "data": { "hash": "a71b0d4c9e", "flags": 2, "vars": 1,
                "inventory": {}, "quests": 1 } }
  ]
}
```

**payload 정본 — `W-07` 해소 (2판)**

초판은 **payload 를 어느 정본으로 쓸지 정하지 못했다.** D-20 의 표(`talk: {actorId, anchorId, …}` ·
`item_gained: {itemId, count}` · `step_tile: {…, anchorId?}` · `enter_place: {placeId, map}`)와
[BP-23 §23.11.1](23_quest_model.md) 이 갈라져 있었고, **골든 트레이스는 바이트 비교 대상이므로
그 선택이 회귀 테스트의 기준 자체를 바꾼다.**

**선택할 것이 없어졌다.** D-20a·D-25 가 D-20 의 payload 표를 삭제하고
[BP-23 §23.11.1](23_quest_model.md) 을 유일 정본으로 확정했으며([BP-90 §5.2.1](90_appendix_schemas.md) `I-01` 해소),
BP-23 은 3판에서 자기 장 안의 중복 표기까지 없앴다(`I-18` 해소 · `R-23-24`).
**위 트레이스는 그 정본으로 교체했다.** 바뀐 4종:

| 이벤트 | 초판 (D-20 표기) | **정본** ([BP-23 §23.11.1](23_quest_model.md)) |
|---|---|---|
| `talk` | `{actorId, anchorId, map, x, y}` | `{actorId, dialogueId?, map, x, y}` — `anchorId` 없음. 이 예제는 세 번 모두 대화가 열리므로 `dialogueId` 가 **채워진다** |
| `enter_place` | `{placeId, map}` | `{placeId, map, x, y}` — 경계를 넘은 칸을 싣는다(주점 `(16,40)` · 납골당 `(62,70)`. 후자는 `place.core.lore_crypt` 의 `regions=(58,70,18,16)` 경계 y=70) |
| `step_tile` | `{map, x, y, anchorId?}` | `{map, x, y, action}` — `action` 은 그 칸의 타일 액션(`(62,76)` 은 A5 14·objUpper 0 → `move`, §1.3). **앵커 id 는 payload 에 없다** |
| `item_gained` / `item_lost` | `{itemId, count}` | `{itemId, delta, total}` — 지급 후 `total: 1`, 회수 후 `total: 0` |

- **`step_tile` 에서 `anchorId` 가 빠진 것이 의미가 있다.** 앵커 정보는 payload 가 아니라
  **트레이스의 `tier` 항목**(seq 64)이 싣는다. 이벤트는 "무슨 칸을 밟았나" 만 보고하고
  "그 칸에 무엇이 걸려 있었나" 는 디스패치 기록이다. D-27 의 "앵커는 타일 비트에 흔적을 남기지 않는다" 와
  같은 방향의 분리다 — payload 가 앵커를 실으면 앵커를 옮길 때 골든이 깨진다.
- **`talk.dialogueId` 는 선택 필드다**([BP-23 R-23-25](23_quest_model.md)). 이 예제는 세 번 다 대화가 열리므로
  채워지지만, 대화가 붙지 않은 actor 앵커는 **필드를 생략**한다(`null` 을 쓰지 않는다 — 표기가 둘이면 골든이 갈린다).
- **골든 재승인 1회가 필요하다.** §7.4 가 `golden=new` 인 첫 실행이므로 이 예제에서는 비용이 0 이지만,
  이미 승인된 골든이 있는 팩이라면 **이 교체가 전량 재승인 대상**이다. 초판 `W-07` 이 경고한 비용이
  실제로 이 형태로 청구된다는 것을 기록해 둔다. → §13.2 `W-07` (**해소**)

또 `seq 26 / 85 / 89` 의 `quest_state` 는 BP-34 가 정의한 kind 를 썼다. [BP-27 §2.6](27_runtime_engine.md) 은
같은 시점에 **`quest_state_changed` 라는 13번째 월드 이벤트를 발행**한다고 쓰는데, D-20 은 12종 닫힌 집합이다.
이 트레이스는 그 이벤트를 **발행하지 않는 쪽**을 골랐다. → §13 `W-08`

### 7.3 솔버의 완주 증명

**판정은 2축이다** (D-26 · 초판은 1축이었다 — 아래 상세)

```
$ hadar_content solve --quest quest.gen_ep1.name_on_ossuary --mode both --explain --verify-witness

  ⚠ quest.gen_ep1.name_on_ossuary
      모델 증명 : PROVEN        opt=34 states  pes=34 states   61ms
      실행 가능 : UNSUPPORTED   미발행 이벤트 2종 의존

     낙관·비관 결과가 같다 → 놓칠 수 없는(non-missable) 퀘스트다.
     증인 액션열(9): 
       talk(anchor.core.town1_tavern_drunk) → choice c_accept
       step(62,76)
       talk(anchor.core.town1_crypt_keeper)
       talk(anchor.core.town1_tavern_drunk)
     증인 재생 검증: sim --policy scripted 로 재생 → stop=goalsCompleted (일치) ✅

     선택 목표 o_see_the_niche 는 완주에 필요하지 않다(optional:true) —
     낙관/비관 양쪽에서 스킵 경로가 존재함을 확인했다.

     ❗ 실행 가능 축 실패 — 이 경로가 소비하는 이벤트 중 발행 지점이 없는 것:
        item_gained  (give_item Effect 뒤 발행 지점 없음 — 인벤토리 부재)
        item_lost    (take_item Effect 뒤 발행 지점 없음 — 인벤토리 부재)
        → 의존 목표: o_hand_roster (kind=deliver, talk ∧ item_lost 필요)
        → 해소 조건: BP-42 의 WorldState.inventory 구현 (BP-51 참조)

  1 proven / 0 refuted / 0 unknown
  0 supported / 1 unsupported          ← 릴리스 게이트 차단
  exit 0   (커밋 가능. 팩은 "미활성" 으로 표시된다)
```

`06_sim/solver.name_on_ossuary.json` 요약:

```json
{
  "verdict": { "model": "proven", "executable": "unsupported" },
  "quest": "quest.gen_ep1.name_on_ossuary",
  "mode": "both",
  "optimistic": { "states": 34, "expanded": 31, "maxDepth": 4, "elapsedMs": 28, "dominancePruned": 6 },
  "pessimistic": { "states": 34, "expanded": 31, "maxDepth": 4, "elapsedMs": 33, "dominancePruned": 6 },
  "witness": [
    { "anchor": "anchor.core.town1_tavern_drunk", "outcome": "c_accept" },
    { "step": [62, 76] },
    { "anchor": "anchor.core.town1_crypt_keeper", "outcome": "o0" },
    { "anchor": "anchor.core.town1_tavern_drunk", "outcome": "o0" }
  ],
  "witnessVerified": true,
  "optionalSkipped": ["o_see_the_niche"],
  "unpublishedEvents": [
    { "event": "item_gained", "consumedBy": ["o_hand_roster"], "reason": "inventory_absent", "owner": "BP-42" },
    { "event": "item_lost",   "consumedBy": ["o_hand_roster"], "reason": "inventory_absent", "owner": "BP-42" }
  ],
  "packActivation": "inactive"
}
```

**초판은 `"verdict": "proven"` 한 값이었다 — 그것이 `W-10` 의 핵심이다.**

- 초판의 솔버는 **모델 그래프상 완주 경로가 있다**는 것만 보고 `PROVEN` 을 냈고,
  그 경로가 의존하는 `item_gained`/`item_lost` 에 **현행 빌드의 발행 지점이 없다**는 사실을 보지 않았다(§11.5).
  즉 **"돌아가지 않는 콘텐츠" 를 통과시켰다.**
- **D-26 이 이 예제를 근거로 판정을 2축으로 확정**했다: `모델 증명`(`PROVEN`/`REFUTED`/`UNKNOWN`) ×
  `실행 가능`(`SUPPORTED`/`UNSUPPORTED`). 빌드가 **이벤트 → 발행 지점 레지스트리**를 만들고,
  솔버가 경로의 소비 이벤트를 그 레지스트리와 대조한다. 하나라도 `unpublished` 면 `UNSUPPORTED`.
- **`PROVEN + UNSUPPORTED` 는 게이트 통과가 아니다.** 커밋은 되고 팩은 **"미활성"** 으로 표시되며
  **릴리스 게이트에서 차단**된다(D-26). 위 출력의 `exit 0` + `packActivation: "inactive"` 가 그 상태다 —
  마일스톤 중 콘텐츠를 미리 만들어 두는 것을 허용하되 배포를 막는 장치다.
- **따라서 이 퀘스트의 판정은 `PROVEN` 이 아니라 `PROVEN + UNSUPPORTED` 다.** 축 이름·레지스트리 대조는
  [BP-34](34_headless_sim_and_solver.md) 소유, 레지스트리 생성은 [BP-35](35_ci_and_build.md), 게이트 반영은 [BP-53](53_acceptance_criteria.md) 이며
  이 절은 그 판정을 **인용**한다(D-18). → §13.1 `W-10`
- **다른 미발행 후보도 함께 확인했다**: `enter_place` 는 [D-20](_meta/DECISIONS.md) 이 "장소 개념 부재로 미발행" 으로 못박은
  이벤트지만, **이 퀘스트의 완주 경로가 소비하지 않는다** — `o_see_the_niche` 는 좌표형 `reach` 라
  `step_tile`/`map_changed` 로 진행하고, 그마저 `optional: true` 다(§11.5). 따라서 `unpublishedEvents` 는 2종이다.
  **"미발행 이벤트가 발행된다" 와 "완주 경로가 그것을 소비한다" 는 다른 질문**이고, 후자만 축 판정에 들어간다.

### 7.4 소요 시간

```
$ hadar_content sim --all && hadar_content solve --all
  ✅ q.gen_ep1.ossuary.happy    scripted   61 steps  goals=1/1  golden=new
  ✅ q.gen_ep1.ossuary.refuse   scripted   74 steps  goals=1/1  golden=new
  2 passed
  sim   총 0.41s (트레이스 2건, 평균 205ms)
  solve 총 0.06s (퀘스트 1건)
  합계  0.47s

  [BP-34 §10.1] 목표: 시나리오 1건 < 2s, 솔버 1건 < 5s → 여유
```

골든이 `new` 인 이유는 첫 실행이기 때문이다. §9 의 commit 에서
`06_sim/trace.name_on_ossuary.json` 이 `test/golden/q.gen_ep1.ossuary.happy.trace.json` 으로 승격된다.

---

## 8. 7단계 `critic` — 검수와 재생성

### 8.1 1차 채점 (`07_critic/critic.name_on_ossuary.json`)

```json
{
  "runId": "20260830-gen_ep1-004",
  "target": "quest.gen_ep1.name_on_ossuary",
  "rubricVersion": "r1",
  "scores": {
    "Q1_lore": 5, "Q2_voice": 4, "Q3_narrative": 4, "Q4_clarity": 4,
    "Q5_balance": 4, "Q6_style": 3, "Q7_novelty": 4, "Q8_integration": 3
  },
  "rationale": {
    "Q1_lore": "취객의 사연·LORE 특공대·용사 납골당이 전부 lore_ep1.cm2 의 실제 대사에서 나왔다. 새 설정을 만들지 않고 빈 곳만 메웠다.",
    "Q2_voice": "취객의 '…게나/…다네/자네' 와 지기의 '…하시오/…이오' 가 잘 분리된다. 다만 n_report 의 '자네들에게 갚을 것이 없구먼' 은 취객이 파티를 처음으로 복수형으로 부르는 곳인데 앞에서 계속 단수 '자네' 였다.",
    "Q3_narrative": "5비트가 군더더기 없다. 다만 b3(이동)이 서사적으로 비어 있어 선택 목표 하나로 메우는 구조가 다소 얇다.",
    "Q4_clarity": "저널 두 줄로 다음 할 일이 명확하다. 지기의 위치를 '성 남쪽 납골당' 이라 말해 준 것이 좋다.",
    "Q5_balance": "tier 1 권장 범위 정중앙. 전투 없는 퀘스트에 exp 900 은 다소 후하나 2배를 넘지 않는다.",
    "Q6_style": "n_report 의 '…이십 년일세. 이십 년.' 반복이 원작 톤과 잘 맞는다. 그러나 n_thanks 의 '한 잔만 하고 일어나겠네' 는 취객이 술을 끊는다는 결말을 흐린다.",
    "Q7_novelty": "gen_ep1 의 다른 6건과 겹치지 않는다. 전투 없는 유일한 건.",
    "Q8_integration": "core 액터 2인을 라우팅 확장으로만 건드려 소유권 규칙을 지켰다. 다만 취객의 상태 slug(at_peace)가 core actors 파일에 선언되어 있지 않다."
  },
  "total": 31,
  "minAxis": 3,
  "verdict": "conditional",
  "findings": [
    {
      "id": "CF-01",
      "axis": "Q8_integration",
      "severity": "blocking",
      "path": "/onComplete/1",
      "quote": "{\"do\":\"set_npc_state\",\"id\":\"npc.core.lore_tavern_drunk\",\"state\":\"at_peace\"}",
      "finding": "core 액터 npc.core.lore_tavern_drunk 의 states[] 에 at_peace 가 선언되어 있지 않다. BP-22 §5.6 은 선언되지 않은 상태를 쓰면 하드 실패라고 규정한다. 그런데 gen 팩은 core 액터 파일을 수정할 수 없다(R-21-19).",
      "requiredFix": "core 에 상태를 추가하거나, 상태 대신 이 팩 소유의 플래그로 표현하도록 바꿀 것. 어느 쪽인지는 사람이 정해야 한다.",
      "returnToStage": "3_struct"
    },
    {
      "id": "CF-02",
      "axis": "Q6_style",
      "severity": "major",
      "path": "str.gen_ep1.dlg.drunk_request.node.n_thanks.line.0",
      "quote": "이제 한 잔만 하고 일어나겠네.",
      "finding": "'한 잔만 하고' 는 그가 여전히 술에 매여 있다는 인상을 준다. onComplete 가 상태를 at_peace 로 바꾸는 것과 어긋난다.",
      "requiredFix": "술을 계속 마신다는 뉘앙스를 지우되 금주 선언처럼 과장하지도 말 것. 잔을 내려놓는 동작을 쓰는 편이 원작 톤에 맞는다.",
      "returnToStage": "7_style"
    },
    {
      "id": "CF-03",
      "axis": "Q2_voice",
      "severity": "minor",
      "path": "str.gen_ep1.dlg.drunk_request.node.n_report.line.2",
      "quote": "자네들에게 갚을 것이 없구먼.",
      "finding": "이 대화 안에서 취객이 파티를 부르는 호칭이 '자네'(단수) → '자네들'(복수) 로 흔들린다.",
      "requiredFix": "하나로 통일할 것. 파티는 2인이므로 복수가 더 정확하지만, 앞의 4줄을 고치는 것보다 이 한 줄을 고치는 편이 변경이 작다.",
      "returnToStage": "7_style"
    }
  ],
  "summary": "원작 재료를 정확히 쓴 견고한 튜토리얼 퀘스트다. 서사·명료성 모두 합격선이나, core 액터의 상태 선언 문제(CF-01)가 blocking 이라 그대로는 커밋할 수 없다.",
  "notes": [
    "선택 목표를 하나 더(취객의 친구 이름 셋 중 하나를 다른 NPC 가 기억한다) 두면 b3 의 공백이 메워질 것 같다. 규정 근거는 없는 취향 의견이다."
  ]
}
```

**판정 규칙 적용** ([BP-32 §32.3.7](32_generation_harness.md)): 모든 축 ≥ 3 ✅ · 총점 31 ≥ 30 ✅ →
`conditional`. 그러나 `severity: "blocking"` 이 하나 있으므로 **8단계로 넘어갈 수 없다.**

### 8.2 수정 지시의 처리

| finding | 되돌아갈 단계 | 실제 조치 |
|---|---|---|
| `CF-01` | `3_struct` | **사람 결정 필요** — HG-3 게이트에서 "core 를 고친다" 를 선택 |
| `CF-02` | `7_style` | StyleEditor 가 문자열 1개 교체 |
| `CF-03` | `7_style` | StyleEditor 가 문자열 1개 교체 |

`CF-01` 에 대한 사람의 결정:

```
core/actors/lore_tavern_drunk.json 의 states[] 에 at_peace 를 추가한다.
근거: 상태는 '이 인물이 취할 수 있는 모습' 이지 '누가 그렇게 만들었는가' 가 아니다.
      플래그로 우회하면 npc_state op 를 못 쓰고 조건식이 팩마다 갈라진다.
부작용: core 팩 version 1.0.0 → 1.1.0 (MINOR). gen_ep1 의 dependsOn 은 그대로.
```

```diff
  // hadar2026_app/assets/content/core/actors/lore_tavern_drunk.json
  "states": [
    { "id": "drinking", "_desc": "술로 죄책감을 덮고 있다. 말이 늘어진다." },
-   { "id": "hopeful",  "_desc": "누군가 자기 말을 들어 주었다.", "from": ["drinking"] }
+   { "id": "hopeful",  "_desc": "누군가 자기 말을 들어 주었다.", "from": ["drinking"] },
+   { "id": "at_peace", "_desc": "친구들의 이름이 남았다. 처음으로 잔을 내려놓는다.",
+                       "from": ["drinking", "hopeful"] }
  ],
```

### 8.3 StyleEditor 출력 (`07_critic/style.name_on_ossuary.json`) — 발췌

```json
{
  "runId": "20260830-gen_ep1-004",
  "styleGuideVersion": "bp43/2026-08",
  "edits": [
    {
      "key": "str.gen_ep1.dlg.drunk_request.node.n_thanks.line.0",
      "before": "이제 한 잔만 하고 일어나겠네.",
      "after":  "이 잔을 내려놓고 일어나겠네.",
      "criterion": "register",
      "reason": "CF-02. 술을 계속 마신다는 뉘앙스를 제거하되 금주 선언은 피함. 잔을 내려놓는 동작으로 대체.",
      "beforeChars": 15, "afterChars": 15
    },
    {
      "key": "str.gen_ep1.dlg.drunk_request.node.n_report.line.2",
      "before": "자네들에게 갚을 것이 없구먼.",
      "after":  "자네에게 갚을 것이 없구먼.",
      "criterion": "token",
      "reason": "CF-03. 이 대화 안의 호칭을 '자네' 단수로 통일.",
      "beforeChars": 15, "afterChars": 14
    }
  ],
  "unchangedCount": 36,
  "properNounCheck": {
    "found": ["LORE 특공대"],
    "allKnownBySpeaker": true,
    "violations": []
  }
}
```

`properNounCheck` 가 통과한 근거: 취객의 `knowledge.knows` 에 `faction.core.lore_guard` 가 있고,
그 `_aliases` 에 `"LORE 특공대"` 가 등재되어 있다([BP-22 R-22-12](22_world_bible_model.md)).
`unknown` 의 `place.core.temple_of_knowledge`·`npc.core.red_antares` 는 어느 대사에도 등장하지 않는다.

### 8.4 재생성 후 2차 채점

```
$ hadar_content lint --pack gen_ep1 --pack core && hadar_content sim --all && hadar_content solve --all
  ERROR 0 · WARN 2 · 게이트 통과
  ✅ q.gen_ep1.ossuary.happy   61 steps  goals=1/1
  ✅ q.gen_ep1.ossuary.refuse  74 steps  goals=1/1
  ⚠ quest.gen_ep1.name_on_ossuary  PROVEN(모델) / UNSUPPORTED(실행 가능 — item_gained·item_lost 미발행)
```

```json
{
  "runId": "20260830-gen_ep1-004",
  "target": "quest.gen_ep1.name_on_ossuary",
  "rubricVersion": "r1",
  "attempt": 2,
  "scores": {
    "Q1_lore": 5, "Q2_voice": 5, "Q3_narrative": 4, "Q4_clarity": 4,
    "Q5_balance": 4, "Q6_style": 4, "Q7_novelty": 4, "Q8_integration": 5
  },
  "total": 35,
  "minAxis": 4,
  "verdict": "pass",
  "findings": [],
  "summary": "CF-01~03 이 모두 해소되었다. core 의 states 확장으로 소유권 규칙을 지키면서 상태 전이가 성립한다. 문체 교정 2건으로 결말의 인상이 정리되었다."
}
```

| 축 | 1차 | 2차 | 변화 |
|---|---|---|---|
| Q2_voice | 4 | 5 | 호칭 통일(CF-03) |
| Q6_style | 3 | 4 | 결말 뉘앙스 정리(CF-02) |
| Q8_integration | 3 | 5 | core states 확장(CF-01) |
| **총점** | **31** | **35** | 합격선 30 을 여유 있게 통과 |

---

## 9. 8단계 `commit` — 팩 반영과 빌드 산출물

### 9.1 `08_commit/commit_plan.json`

```json
{
  "runId": "20260830-gen_ep1-004",
  "approvedAt": "HG-3",
  "files": [
    { "action": "add",    "path": "assets/content/gen_ep1/quests/name_on_ossuary.json" },
    { "action": "add",    "path": "assets/content/gen_ep1/dialogue/drunk_request.json" },
    { "action": "add",    "path": "assets/content/gen_ep1/dialogue/keeper_record.json" },
    { "action": "add",    "path": "assets/content/gen_ep1/dialogue/ossuary_niche.json" },
    { "action": "add",    "path": "assets/content/gen_ep1/anchors/TOWN1.json" },
    { "action": "add",    "path": "assets/content/gen_ep1/actors/_routing/lore_tavern_drunk.json" },
    { "action": "add",    "path": "assets/content/gen_ep1/actors/_routing/lore_crypt_keeper.json" },
    { "action": "modify", "path": "assets/content/gen_ep1/items/items.json",  "delta": "+1 entry" },
    { "action": "modify", "path": "assets/content/gen_ep1/strings/ko.json",   "delta": "+38 keys" },
    { "action": "modify", "path": "assets/content/gen_ep1/pack.json",         "delta": "version 0.4.0 → 0.5.0, entryPoints.quests +1" },
    { "action": "modify", "path": "assets/content/core/actors/lore_tavern_drunk.json", "delta": "states +at_peace (CF-01)" },
    { "action": "modify", "path": "assets/content/core/pack.json",            "delta": "version 1.0.0 → 1.1.0" },
    { "action": "modify", "path": "assets/maps/TOWN1.json",                   "delta": "region(62,76)=200  ← [2판] D-27·D-28 로 이 항목은 사라진다. 앵커는 맵 데이터를 건드리지 않는다(§5.3 주석)" },
    { "action": "modify", "path": "assets/maps/MapInfos.json",                "delta": "T-22-1 — id 4/5 에 json 필드" },
    { "action": "add",    "path": "test/golden/q.gen_ep1.ossuary.happy.trace.json" },
    { "action": "add",    "path": "test/golden/q.gen_ep1.ossuary.refuse.trace.json" }
  ],
  "packVersionBumps": {
    "gen_ep1": { "from": "0.4.0", "to": "0.5.0", "reason": "퀘스트 1건 추가 (MINOR)" },
    "core":    { "from": "1.0.0", "to": "1.1.0", "reason": "액터 상태 1개 추가 (MINOR, 기존 데이터 유효)" }
  },
  "gates": {
    "lint":   { "error": 0, "warn": 2, "pass": true },
    "sim":    { "scenarios": 2, "passed": 2, "pass": true },
    "solve":  { "verdict": { "model": "proven", "executable": "unsupported" }, "pass": true, "releaseBlocked": true },
    "critic": { "total": 35, "minAxis": 4, "verdict": "pass", "pass": true },
    "determinism": { "rebuildHashMatch": true, "pass": true }
  }
}
```

### 9.2 `content.lock.json` diff

```diff
--- a/hadar2026_app/assets/content/build/content.lock.json
+++ b/hadar2026_app/assets/content/build/content.lock.json
@@
   "packs": [
-    { "id": "core",    "version": "1.0.0", "fileCount": 48, "packHash": "sha256:1f0c…" },
-    { "id": "gen_ep1", "version": "0.4.0", "fileCount": 61, "packHash": "sha256:9ab3…" }
+    { "id": "core",    "version": "1.1.0", "fileCount": 48, "packHash": "sha256:4d72…" },
+    { "id": "gen_ep1", "version": "0.5.0", "fileCount": 70, "packHash": "sha256:e118…" }
   ],
   "sources": {
-    "core/actors/lore_tavern_drunk.json":        "sha256:c4e0…",
+    "core/actors/lore_tavern_drunk.json":        "sha256:2a55…",
+    "gen_ep1/anchors/TOWN1.json":                "sha256:6f30…",
+    "gen_ep1/actors/_routing/lore_crypt_keeper.json": "sha256:b0c7…",
+    "gen_ep1/actors/_routing/lore_tavern_drunk.json": "sha256:91ae…",
+    "gen_ep1/dialogue/drunk_request.json":       "sha256:33d1…",
+    "gen_ep1/dialogue/keeper_record.json":       "sha256:7c8b…",
+    "gen_ep1/dialogue/ossuary_niche.json":       "sha256:15fa…",
+    "gen_ep1/quests/name_on_ossuary.json":       "sha256:aa07…",
-    "gen_ep1/items/items.json":                  "sha256:5e21…",
+    "gen_ep1/items/items.json":                  "sha256:d34c…",
-    "gen_ep1/strings/ko.json":                   "sha256:b512…",
+    "gen_ep1/strings/ko.json":                   "sha256:0ff9…",
   },
   "mapSources": {
-    "assets/maps/MapInfos.json": "sha256:aa10…",
+    "assets/maps/MapInfos.json": "sha256:38b1…",
-    "assets/maps/TOWN1.json":    "sha256:cc93…",
+    "assets/maps/TOWN1.json":    "sha256:7e40…",
   },
   "outputs": {
-    "content.bundle.json": { "sha256": "e4f1…", "bytes": 318742 },
+    "content.bundle.json": { "sha256": "b90a…", "bytes": 324109 },
-    "content.index.json":  { "sha256": "7b20…", "bytes":  94118 }
+    "content.index.json":  { "sha256": "c771…", "bytes":  95004 }
   },
-  "buildInputHash": "sha256:c0de…",
+  "buildInputHash": "sha256:91f7…",
   "legacyFlagMap": {
     "flag.core.world.necromancer_awakened": 12,
     "flag.core.map.town1.crypt_opened": 13,
+    "flag.gen_ep1.map.town1.ossuary_niche_fired": 41,
+    "flag.gen_ep1.quest.name_on_ossuary.heard_out": 42,
+    "flag.gen_ep1.quest.name_on_ossuary.name_recorded": 43
   },
-  "legacyFlagMapHash": "sha256:88af…",
+  "legacyFlagMapHash": "sha256:c209…",
   "budget": {
-    "bundleBytes": { "value": 318742, "target": 409600, "hardLimit": 1048576, "ok": true },
+    "bundleBytes": { "value": 324109, "target": 409600, "hardLimit": 1048576, "ok": true },
-    "indexBytes":  { "value":  94118, "target": 122880, "hardLimit":  262144, "ok": true }
+    "indexBytes":  { "value":  95004, "target": 122880, "hardLimit":  262144, "ok": true }
   },
-  "diagnostics": { "error": 0, "warn": 11, "info": 4 }
+  "diagnostics": { "error": 0, "warn": 13, "info": 5 }
 }
```

**`legacyFlagMap` 배정 규칙 확인** (R-35-12): 새 플래그 3개가 41·42·43 에 붙었다.
기존 12·13 은 그대로다 — **기존 배정은 lock 의 이전 값을 읽어 고정**하고 남은 번호만 쓴다.
`flag.gen_ep1.map.town1.…` 가 `flag.gen_ep1.quest.…` 보다 앞선 이유는 팩 안 **사전순**이기 때문이다
(`map` < `quest`). 256 중 44개 사용, 여유 212.

### 9.3 `content.index.json` diff 요약

```diff
   "triggers": {
     "TOWN1": {
+      "62,76": { "event": ["anchor.gen_ep1.town1_ossuary_niche"] },
       "17,37": { "talk":  ["anchor.core.town1_tavern_drunk"] },
       "71,77": { "talk":  ["anchor.core.town1_crypt_keeper"] },
   },
   "byQuestObjective": {
+    "deliver:item.gen_ep1.crumpled_roster": ["quest.gen_ep1.name_on_ossuary#bring_the_name/o_hand_roster"],
+    "reach:TOWN1@62,76":                    ["quest.gen_ep1.name_on_ossuary#bring_the_name/o_see_the_niche"],
+    "talk_to:npc.core.lore_tavern_drunk":   ["quest.gen_ep1.name_on_ossuary#tell_the_drunk/o_report_back"],
   },
   "xref": {
+    "item.gen_ep1.crumpled_roster": {
+      "givenBy":    ["dlg.gen_ep1.drunk_request#n_offer/c_accept"],
+      "takenBy":    ["dlg.gen_ep1.keeper_record#n_receive"],
+      "requiredBy": ["quest.gen_ep1.name_on_ossuary#bring_the_name/o_hand_roster",
+                     "dlg.gen_ep1.keeper_record#entry[0]"]
+    },
+    "flag.gen_ep1.quest.name_on_ossuary.name_recorded": {
+      "writtenBy": ["quest.gen_ep1.name_on_ossuary#onComplete[0]"],
+      "readBy":    []
+    },
   },
   "mapResolution": {
-    "TOWN1":  { "id": 4, "json": "Map004.json", "cm2": "Map004.cm2", "width": null, "height": null },
+    "TOWN1":  { "id": 4, "json": "TOWN1.json",  "cm2": null, "width": 100, "height": 100 },
   },
-  "stats": { "actors": 12, "quests": 7, "dialogues": 23, "nodes": 150, "anchors": 34, "strings": 418 }
+  "stats": { "actors": 12, "quests": 8, "dialogues": 26, "nodes": 161, "anchors": 35, "strings": 456 }
```

> `flag.gen_ep1.quest.name_on_ossuary.name_recorded` 의 `readBy` 가 **비어 있다**.
> [BP-33](33_validation_and_lint.md) 이 "쓰기는 있는데 읽기가 없는 플래그" 를 경고한다(WARN 13건 중 1건).
> 의도적이다 — 후속 에피소드가 이 플래그를 읽는 것을 전제한 **접점**이다.
> `pack.json#entryPoints` 에 플래그를 선언하는 칸이 없어 이 의도를 표현할 방법이 없다. → §13 `W-11`

### 9.4 `08_commit/summary.md`

```markdown
# gen_ep1 v0.5.0 — 유골에 새길 이름

## 무엇을
- 로어성 주점의 취객이 LORE 특공대로 떠난 친구 셋의 이름을 용사 납골당에 남기려 하는
  튜토리얼급 사이드 퀘스트 1건 추가 (act 1 / tier 1 / 전투 없음)

## 바뀐 점
- 퀘스트 1 · 대화 3 · 아이템 1 · 앵커 1 · 문자열 38 추가
- core 액터 `lore_tavern_drunk` 에 상태 `at_peace` 추가 (core 1.0.0 → 1.1.0)
- ~~`TOWN1.json` region(62,76)=200 — 콘텐츠 트리거 예약 구간~~ **[2판] 해당 없음** — D-28 이 region 예약안을 최종 기각했다. 앵커는 트리거 인덱스로만 발화하며 맵 파일은 무변경이다
- **T-22-1 동반 반영**: `MapInfos.json` id 4/5 에 `json` 필드 추가

## 검증
- lint ERROR 0 / WARN 2 (레거시 cm2 좌표 중복 1, take_item 힌트 1 — 둘 다 무해)
- sim 2 시나리오 통과, solve **PROVEN(모델) + UNSUPPORTED(실행 가능)** — 낙관=비관, 놓칠 수 없음.
  **`item_gained`/`item_lost` 발행 지점 부재로 팩은 "미활성"** 이며 릴리스 게이트에서 차단된다(D-26 · §7.3)
- critic 35/40, 최저 축 4, verdict pass
- 재빌드 해시 일치

## 참고
- `flag.gen_ep1.quest.name_on_ossuary.name_recorded` 는 아직 읽는 곳이 없다(후속 접점)
```

---

### 9.5 [2판] 산출물 정합 재점검 — 그 사이 확정된 것들을 이 예제에 대입

초판 이후 D-27·D-28·D-30·D-31 과 `I-01`~`I-20` 의 소유 장 반영이 진행됐다.
**이 예제의 산출물이 그것들과 어긋나지 않는지 항목별로 대입해 본 결과**다.
어긋난 곳은 앞선 절에 주석으로 표시했고, 여기에는 판정만 모은다.

| # | 확정된 것 | 이 예제에 대입한 결과 | 조치 |
|---|---|---|---|
| 1 | **D-27·D-28** — 앵커는 타일 비트를 쓰지 않고 region 승격안은 기각 | §5.3 의 맵 편집 호출과 §9.1 의 `TOWN1.json` 수정 항목이 **일어나지 않는다.** `content.lock.json` 의 `mapSources["assets/maps/TOWN1.json"]` **해시도 바뀌지 않는다** — 이 예제가 실제로 고치는 맵 파일은 `MapInfos.json`(T-22-1) 하나다 | §5.3 주석 · §9.1 인라인 주석 · §12.2 갱신. §9.2 diff 는 초판 실행 기록으로 보존 |
| 2 | **`I-01`·`I-18`** — payload 정본은 [BP-23 §23.11.1](23_quest_model.md) 하나 | §7.2 트레이스의 `talk`·`enter_place`·`step_tile`·`item_gained`/`item_lost` **4종 payload 가 D-20 표기였다** | §7.2 에서 정본으로 교체 + 변경 4행 표. §11.3~§11.5 도 갱신. `W-07` **해소** |
| 3 | **D-26** — 솔버 판정은 2축 | §7.3·§8.4·§9.1·§9.4 가 `PROVEN` 한 값이었다. 이 퀘스트는 **`PROVEN` + `UNSUPPORTED`** 다 | 네 곳 모두 갱신. `W-10` 의 BP-34 절반 **해소** |
| 4 | **D-30** — `chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p`, 문자열 키는 `chanceKey` | **이 예제에 `chance` 노드가 0개**다. 조건은 `{"op":"true"}`·`flag`·`quest_state` 뿐이고 `rngCursor: 0`(§12.2). 따라서 `content.lock.json` 의 `chanceSeedIds` 는 **빈 맵**이고 `chanceSeedIdsHash` 는 빈 입력 해시다 | 변경 없음. §12.2 에 "이 예제는 `chance` 를 검증하지 않는다" 를 명시 |
| 5 | **D-31** — `do` 25종 · `schemaVersion` **1 → 2** | 이 예제의 팩 파일들은 `schemaVersion: 1` 이고 **새 3종 do 를 쓰지 않는다** — 실사용 do 는 `set_flag`·`give_item`·`take_item`·`start_quest`·`play_dialogue`·`set_npc_state`·`add_var`·`add_gold`·`add_food`·`grant_exp` **10종**이며 전부 v1 22종 안에 있다(grep 확인). 즉 **초판 산출물은 승격 후에도 유효**하다 — 순수 확대이므로 구 데이터가 그대로 통과하고, [BP-21 R-21-42](21_content_pack_spec.md) 의 N-1 자동 승격 범위 안이다 | 파일을 고치지 않는다. 단 **재빌드 시 `pack.json#migrations` 에 `{from:1, to:2, steps:[]}` 를 선언해야 한다**([BP-21 R-21-70](21_content_pack_spec.md)) → 아래 (a) |
| 6 | **부록 H-1 정정판** — 죽은 장비 필드는 `powOfShield`/`powOfArmor` **2개**이고 `powOfWeapon` 은 `battle.dart:439` 가 읽는다 | **이 예제에 장비가 없다.** 유일한 신규 아이템 `item.gen_ep1.crumpled_roster` 는 `category: "quest"` 이고 `equip` 블록이 없다. `powOf*` 를 언급하는 곳이 **0곳**(grep 확인) | 변경 없음. 이 예제는 H-1 계열 결정에 **영향받지도 검증하지도 않는다** |
| 7 | **`I-09`·`I-16`** — `defeat.enemy` 1~74 · `survive.turns` 1~999 | 이 예제의 목표는 `deliver`·`reach`·`talk_to` 3종뿐이고 **`defeat`·`survive` 를 쓰지 않는다**(§1.1 "전투 없음") | 변경 없음. tier 1 보상 검산(§14.1 항목 7)도 적 id 를 인용하지 않으므로 무영향 |
| 8 | **`W-01`** — `STRING_KEY` slot-path 확장 | 문자열 키 **40개 전량을 정규식에 대입해 통과 확인** | §4.7.1 신설. `W-01` **해소** |

**(a) 이 예제가 드러낸 승격 절차의 실사용 형태**

초판 산출물은 `schemaVersion: 1` 이고 D-31 승격 뒤에도 **한 글자도 고칠 필요가 없다.**
그런데 [BP-21 R-21-70](21_content_pack_spec.md) 은 무변환 승격에도 `{from, to, steps: []}` 선언을 **요구**한다.
이 예제에 대입하면 `gen_ep1/pack.json` 과 `core/pack.json` 에 각각 그 항목이 붙고,
`content.lock.json` 의 두 `packHash` 가 **콘텐츠 변경 없이** 바뀐다.

- **그것이 의도된 동작이다.** 포맷 세대가 바뀐 것은 사실이므로 lock 이 그것을 기록해야 하고,
  기록하지 않으면 "이 팩이 2 로 검토됐는지" 를 나중에 알 수 없다(§7.2.1 (b) 의 근거).
- **비용은 재빌드 1회 + 골든 재승인 0회**다. 트레이스에는 `schemaVersion` 이 실리지 않으므로
  §7.4 의 골든 2건은 영향받지 않는다. §7.2 의 payload 교체(#2)만이 골든 재승인 사유다.

## 10. 플레이 시점 재현 — ASCII 목업

800×480 고정 레이아웃([BP-41 §41.1.1](41_journal_ui_spec.md)). 아래 목업의 한 칸은 **반각 1칸**이고,
맵 뷰포트 288px = 36칸, 대화 패널 512px = 60칸, 상태 288px = 36칸, 진행 512px = 60칸이다.
세로는 19.2px/행 기준 상단 16행 · 하단 8행.

### 화면 1 — 주점 안, 취객 앞 (대화 전)

```
┌────────────────────────────────────┬────────────────────────────────────────────────────────────┐
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │                                                            │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒....╔══╗....╔══╗..........▒▒▒▒▒▒▒ │                                                            │
│ ▒....║酒║....║酒║..........▒▒▒▒▒▒▒ │                                                            │
│ ▒....╚══╝....╚══╝..........▒▒▒▒▒▒▒ │                                                            │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒....(취)....◄@..........▒▒▒▒▒▒▒▒▒ │                                                            │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │                                                            │
│                                    │                                                            │
│   (취) = 취객 (17,37)              │                                                            │
│   @    = 파티 (16,37), 오른쪽 향함 │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
├────────────────────────────────────┼────────────────────────────────────────────────────────────┤
│ 슴갈  Lv 1  HP  38/ 38  SP 12/12   │                                                            │
│ 유리  Lv 1  HP  31/ 31  ESP 9/ 9   │  로어성                                                    │
│                                    │  일행은 주점 안으로 들어섰다.                              │
│ 식량 100    황금 500               │                                                            │
│                                    │                                                            │
│ ↑↓←→ 이동  Enter 확인  Space 메뉴  │                                                            │
└────────────────────────────────────┴────────────────────────────────────────────────────────────┘
   HDMapViewport 288×320             HDConsolePanel 512×320 / HDProgressPanel 512×160
```

### 화면 2 — 말을 걸었다 (대화 + 선택지)

`showMenu(items, clearLogs: false)` — 대사는 **위에 그대로 남고** 선택지가 하단에 붙는다
([BP-24 §24.4.3](24_dialogue_model.md) 채택 근거 1).

```
┌────────────────────────────────────┬────────────────────────────────────────────────────────────┐
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │ @B주점 구석의 취객@@                                       │
│ ▒..........................▒▒▒▒▒▒▒ │ ────────────────────────────────────────────────────────── │
│ ▒....╔══╗....╔══╗..........▒▒▒▒▒▒▒ │ 이보게 자네, 잠깐 앉아 보게나.                             │
│ ▒....║酒║....║酒║..........▒▒▒▒▒▒▒ │ 내 친구 셋이 @BLORE 특공대@@에 갔다네.                     │
│ ▒....╚══╝....╚══╝..........▒▒▒▒▒▒▒ │ 그 뒤로 아무도 돌아오지 않았어.                            │
│ ▒..........................▒▒▒▒▒▒▒ │ 이름이라도 남겨야 하지 않겠나.                             │
│ ▒....(취)....◄@..........▒▒▒▒▒▒▒▒▒ │                                                            │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │  ┌──────────────────────────┐                              │
│                                    │  │@F> 쪽지를 받겠소@@       │                              │
│                                    │  │   지금은 어렵소          │                              │
├────────────────────────────────────┼──┴──────────────────────────┴──────────────────────────────┤
│ 슴갈  Lv 1  HP  38/ 38  SP 12/12   │                                                            │
│ 유리  Lv 1  HP  31/ 31  ESP 9/ 9   │  로어성                                                    │
│                                    │  일행은 주점 안으로 들어섰다.                              │
│ 식량 100    황금 500               │                                                            │
│                                    │                                                            │
│ ↑↓ 고르기  Enter 확인  Esc 취소    │                                                            │
└────────────────────────────────────┴────────────────────────────────────────────────────────────┘
```

- 헤더는 `clearLogs()` 뒤에 `setHeader()` 로 세운다 — `clearLogs` 가 헤더까지 지우기 때문이다.
- 본문 4줄 + 헤더 3행 + 메뉴 3행 = 10행. `pageBudget = 13 − 3 − 3 = 7` ≥ 4 → **페이지 넘김 없음**.
- **취소(Esc) = 마지막 선택지** 이므로 마지막은 반드시 빠져나갈 수 있는 항목이어야 한다(`DV-12`).
  여기서는 "지금은 어렵소" 다.

### 화면 3 — 수락 직후 (아이템 지급 + 저널 알림)

알림은 `beginNarrative()` 중에는 **큐에 쌓이고**, `endNarrative()` 직후 flush 된다(R-41-12).
아래는 flush 된 뒤의 화면이다.

```
┌────────────────────────────────────┬────────────────────────────────────────────────────────────┐
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │ @B주점 구석의 취객@@                                       │
│ ▒..........................▒▒▒▒▒▒▒ │ ────────────────────────────────────────────────────────── │
│ ▒....╔══╗....╔══╗..........▒▒▒▒▒▒▒ │ 고맙네. 이 종이일세.                                       │
│ ▒....║酒║....║酒║..........▒▒▒▒▒▒▒ │ 성 남쪽 납골당의 지기에게 주게나.                          │
│ ▒....╚══╝....╚══╝..........▒▒▒▒▒▒▒ │                                                            │
│ ▒..........................▒▒▒▒▒▒▒ │                          ▂▂▂▂▂                             │
│ ▒....(취)....◄@..........▒▒▒▒▒▒▒▒▒ │                                                            │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
├────────────────────────────────────┼────────────────────────────────────────────────────────────┤
│ 슴갈  Lv 1  HP  38/ 38  SP 12/12   │@E눈여겨 봄@@ · 쪽지를 지기에게 건넨다                       │
│ 유리  Lv 1  HP  31/ 31  ESP 9/ 9   │────────────────────────────────────────────────────────── │
│                                    │ 구겨진 명부 쪽지를 받았다.                                 │
│ 식량 100    황금 500               │@E[임무]@@ 유골에 새길 이름 — 시작                          │
│                                    │@E[임무]@@ 유골에 새길 이름 — 쪽지를 지기에게              │
│ Enter 계속                         │                                                            │
└────────────────────────────────────┴────────────────────────────────────────────────────────────┘
```

- 진행 패널 맨 윗줄이 `HDTrackerBar`([BP-41 §41.6](41_journal_ui_spec.md)). 추적 중인 퀘스트의
  **현재 단계에서 미완료인 첫 non-hidden 목표** 하나를 보여 준다. `counter.target == 1` 이므로 `(n/m)` 은 없다.
- 알림 문구는 [BP-41 §41.7.2](41_journal_ui_spec.md) 고정 — 접두 `[임무]`, 시작은 `@E` 노랑.
- **알림 2줄이 한 배치에서 나왔다**: `start_quest` 가 퀘스트를 시작하고, 곧이어 stage 진입이
  같은 배치에서 일어난다. 3줄 상한 안이다.

### 화면 4 — 저널 (Space → 임무 → 상세)

`HDJournalWindow` 512×400, 내부 492×380 = 19행. 좌우 144px, 상하 40px 이 남는다.

```
┌────────────────────────────────────┬────────────────────────────────────────────────────────────┐
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │                                                            │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒..┌──────────────────────────────────────────────────────────────┐                             │
│ ▒..│@F유골에 새길 이름@@                              @E눈여겨 봄@@│                            │
│ ▒..│──────────────────────────────────────────────────────────────│                            │
│ ▒..│@7주점 취객이 돌아오지 못한 친구들의 이름을 남기고 싶어 한다.@@│                            │
│ ▒..│                                                              │                            │
│ ▒..│> 쪽지를 지기에게                                             │                            │
│ ▒..│@7취객에게서 이름 셋이 적힌 쪽지를 받았다. 용사 납골당의 지기@@│                            │
│ ▒..│@7에게 건네야 한다.@@                                         │                            │
│ ▒..│                                                              │                            │
│ ▒..│해야 할 일                                                    │                            │
│ ▒..│  [ ] 쪽지를 지기에게 건넨다                                  │                            │
│ ▒..│  (선택) [ ] 빈 감실 앞에 선다                                │                            │
│ ▒..│                                                              │                            │
│ ▒..│                                                              │                            │
├────│                                                              │────────────────────────────┤
│ 슴갈│                                                              │E눈여겨 봄@@ · 쪽지를 지기에│
│ 유리│                                                              │─────────────────────────── │
│     │@7↑↓ 넘기기  Enter 눈여겨 봄  Esc 뒤로@@                      │쪽지를 받았다.              │
│ 식량└──────────────────────────────────────────────────────────────┘름 — 시작                   │
│                                    │@E[임무]@@ 유골에 새길 이름 — 쪽지를 지기에게              │
│                                    │                                                            │
└────────────────────────────────────┴────────────────────────────────────────────────────────────┘
```

- 목표 행 접두: 미완료 `[ ]`, 완료 `[v]`, `counter.target > 1` 이면 `[0/3]`
  ([BP-41 §41.4.3](41_journal_ui_spec.md)). `optional: true` 는 `(선택) ` 접두.
- 목표 문구는 `label` 키를 쓴다. 생략하면 [BP-23 §23.10.3](23_quest_model.md) 의 자동 문구가 나온다.
- 창이 뒤를 **부분적으로** 덮어 "게임이 계속 있다" 는 감각이 남는다.

### 화면 5 — 납골당, 빈 감실 앞 (선택 목표 완료)

(62,76) 을 밟는 순간 `trigger` 앵커가 발동한다. 화자 없는 서술이므로 **헤더가 없다**.

```
┌────────────────────────────────────┬────────────────────────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ 이름이 새겨지지 않은 감실이                                │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓ │ 셋, 나란히 비어 있다.                                      │
│ ▓░[骨][骨][骨][骨][骨][骨][骨]░░░░▓ │                                                            │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓ │                          ▂▂▂▂▂                             │
│ ▓░[骨][骨][ ][ ][ ][骨][骨]░░░░░░▓ │                                                            │
│ ▓░░░░░░░░@▲░░░░░░░░░░░░░░░░░░░░░░▓ │                                                            │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░(지)░░░░▓ │                                                            │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓ │                                                            │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │                                                            │
│                                    │                                                            │
│   [ ] = 이름 없는 감실 (62,75)     │                                                            │
│   @   = 파티 (62,76), 위를 향함    │                                                            │
│   (지) = 납골당지기 (71,77)        │                                                            │
│                                    │                                                            │
│                                    │                                                            │
├────────────────────────────────────┼────────────────────────────────────────────────────────────┤
│ 슴갈  Lv 1  HP  38/ 38  SP 12/12   │@E눈여겨 봄@@ · 쪽지를 지기에게 건넨다                       │
│ 유리  Lv 1  HP  31/ 31  ESP 9/ 9   │────────────────────────────────────────────────────────── │
│                                    │@E[임무]@@ 빈 감실 앞에 선다 — 마침                         │
│ 식량  98    황금 500               │                                                            │
│                                    │                                                            │
│ Enter 계속                         │                                                            │
└────────────────────────────────────┴────────────────────────────────────────────────────────────┘
```

- 선택 목표가 완료돼도 **추적 바는 바뀌지 않는다** — 추적 바는 "미완료인 첫 non-hidden 목표" 를 보이는데
  `o_hand_roster` 가 여전히 미완료이기 때문이다.
- 알림 문구는 `target == 1` 이므로 `— 마침` 형태다(§41.7.2).

### 화면 6 — 지기에게 쪽지를 건넨다 (단계 전이)

```
┌────────────────────────────────────┬────────────────────────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ @B납골당지기@@                                             │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓ │ ────────────────────────────────────────────────────────── │
│ ▓░[骨][骨][骨][骨][骨][骨][骨]░░░░▓ │ …그 종이를 이리 주시오.                                    │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓ │ 이름 없는 감실이 셋이었소.                                 │
│ ▓░[骨][骨][ ][ ][ ][骨][骨]░░░░░░▓ │ 오늘 그 앞에 이름을 새기겠소.                              │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓ │                                                            │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░(지)◄@░░▓ │                          ▂▂▂▂▂                             │
│ ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓ │                                                            │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
├────────────────────────────────────┼────────────────────────────────────────────────────────────┤
│ 슴갈  Lv 1  HP  38/ 38  SP 12/12   │@E눈여겨 봄@@ · 취객에게 돌아가 알린다                       │
│ 유리  Lv 1  HP  31/ 31  ESP 9/ 9   │────────────────────────────────────────────────────────── │
│                                    │ 구겨진 명부 쪽지를 건넸다.                                 │
│ 식량  94    황금 500               │@E[임무]@@ 쪽지를 지기에게 건넨다 — 마침                    │
│                                    │@E[임무]@@ 유골에 새길 이름 — 주점으로 돌아가              │
│ Enter 계속                         │                                                            │
└────────────────────────────────────┴────────────────────────────────────────────────────────────┘
```

- 추적 바가 **바뀌었다** — 단계가 `tell_the_drunk` 로 전이하면서 미완료 첫 목표가 갈렸다.
- 알림 3줄 중 첫 줄(아이템 소실)은 퀘스트 알림이 아니라 인벤토리 로그다. 퀘스트 알림 2줄은 상한 안이다.

### 화면 7 — 주점 복귀, 완료와 보상

```
┌────────────────────────────────────┬────────────────────────────────────────────────────────────┐
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │ @B주점 구석의 취객@@                                       │
│ ▒..........................▒▒▒▒▒▒▒ │ ────────────────────────────────────────────────────────── │
│ ▒....╔══╗....╔══╗..........▒▒▒▒▒▒▒ │ 새겨 주었다고? 정말인가.                                   │
│ ▒....║酒║....║酒║..........▒▒▒▒▒▒▒ │ …이십 년일세. 이십 년.                                     │
│ ▒....╚══╝....╚══╝..........▒▒▒▒▒▒▒ │ 자네에게 갚을 것이 없구먼.                                 │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒....(취)....◄@..........▒▒▒▒▒▒▒▒▒ │                          ▂▂▂▂▂                             │
│ ▒..........................▒▒▒▒▒▒▒ │                                                            │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
│                                    │                                                            │
├────────────────────────────────────┼────────────────────────────────────────────────────────────┤
│ 슴갈  Lv 2  HP  46/ 46  SP 15/15   │                                                            │
│ 유리  Lv 2  HP  38/ 38  ESP 12/12  │────────────────────────────────────────────────────────── │
│                                    │@A[임무]@@ 유골에 새길 이름 — 완료                          │
│ 식량 104    황금 750               │ 사례로 황금 250과 식량 10을 받았다.                        │
│                                    │                                                            │
│ Enter 계속                         │                                                            │
└────────────────────────────────────┴────────────────────────────────────────────────────────────┘
```

- 완료는 `@A`(초록) 2줄 — 제목 1줄 + 사례 요약 1줄([BP-41 §41.7.2](41_journal_ui_spec.md)).
- **추적 바가 사라졌다.** 추적 중이던 퀘스트가 끝났고 다른 활성 퀘스트가 없다.
- `grant_exp 900` 이 생존 멤버 2인에게 균등 분배(450씩) → 두 명 모두 레벨 2.
  exp 테이블 2단계 임계가 0 이므로([GROUND_TRUTH §10] 0,0,1500,…) 첫 전투 전에도 레벨업이 가능하다.
  **tier 1 보상이 레벨 2를 그냥 준다** — 밸런스 린트가 잡지 못하는 구간이다. → §13 `W-12`

---

## 11. 런타임 실행 추적

화면 2~3 이 만들어지는 동안 `ContentRuntime` / `DialogueRuntime` / `QuestRuntime` / `WorldEventBus` 가
무엇을 하는지 단계별로 적는다. [BP-27 §4.4·§5.1·§6.1](27_runtime_engine.md) 의 설계와 일치해야 한다.

### 11.1 타일 상호작용 1회의 전 과정

```
 1  HDInputDispatcher.process(Enter)              — currentInputMode == map
 2  HDPlayerSprite.update(dt) → checkTileEvent(x:17,y:37, isInteraction:true)
      ※ 이 호출이 presentation 에 있는 것이 헤드리스의 장벽이다(부록 B-3, BP-34 P-1)
 3  HDTileEventDispatcher.check(...)
 3.1   _isScriptRunning ← true                     "한 번에 하나의 상호작용"(D-10)
 3.2   HDTileProperties.getUnitAction(unit(17,37)) → objUpper 129 → HDTileAction.talk
 3.3   isScriptedAction = isInteraction ? action.isInteractive → true
 3.4   host.beginNarrative(); host.clearLogs()
 4  _dispatchScripted → ★ 티어 0
 4.1   ContentRuntime.handleTile(map:"TOWN1", x:17, y:37, action:talk, isInteraction:true, host)
 4.2     isInteracting ← true                      (락 획득. finally 로 반드시 해제)
 4.3     TriggerIndex.at("TOWN1", 17, 37, talk)
           → content.index.json#/triggers/TOWN1/"17,37"/talk
           → ["anchor.core.town1_tavern_drunk"]
 4.4     anchor.when 평가 — 없으므로 {"op":"true"} → 활성
 4.5     WorldEventBus.publish(talk {actorId, anchorId, map, x, y})
           ※ 큐에만 넣는다. 드레인은 4.9 에서 한 번에.
 4.6     대화 라우팅 결정 (BP-22 §5.5 + gen_ep1 의 _routing 병합 결과)
           routing[0].when = or(active, completed, not(heard_out))
             → quest_state(inactive) ∧ ¬flag(heard_out) → not(false)=true → 채택
           → dlg.gen_ep1.drunk_request
 4.7     DialogueRuntime.run(dlg, state: mutator, host: host)
```

### 11.2 대화 루프 (화면 2)

```
 4.7.1  resolveEntry — entry[] 를 위에서부터 평가
          [0] quest_state(completed)                        → false
          [1] and(quest_state(active), quest_stage(…))      → false (단축 평가로 첫 인자에서 중단)
          [2] quest_state(active)                           → false
          [3] when 없음 = 기본                              → true  → n_offer
        trace: dialogue_enter { entryIndex: 3, node: "n_offer" }

 4.7.2  renderNode(n_offer)  — BP-24 §24.4.2 의 호출 순서 그대로
          ① applyEffects(node.onEnter = [])                   없음
          ② header = resolveHeader(node) → "@B주점 구석의 취객@@"
          ③ headerCost = 3, menuCost = 1 + 2 = 3
             pageBudget = 13 − 3 − 3 = 7      (HDConfig.maxLinesPerPage = 13)
          ④ host.clearLogs(); host.setHeader(header)
             for key in lines:  wrapCount 를 번들의 _wrap 에서 읽는다 (TextPainter 재측정 없음)
               line.0 wrapped=1  emitted 1 ≤ 7   → addLog
               line.1 wrapped=1  emitted 2 ≤ 7   → addLog
               line.2 wrapped=1  emitted 3 ≤ 7   → addLog
               line.3 wrapped=1  emitted 4 ≤ 7   → addLog     페이지 넘김 없음
          ⑥ visible = choices where evaluate(when) ∧ ¬consumed
               c_accept  (when 없음 → true)
               c_decline (when 없음 → true)
             items = ["", "쪽지를 받겠소", "지금은 어렵소"]     items[0] 은 제목 행
             sel = await host.showMenu(items, clearLogs: false) → 1
             chosen = visible[0] = c_accept
          ⑦ emitWorldEvent(dialogue_choice {dialogueId, nodeId, choiceId})
             applyEffects(chosen.effects)  ← 원자적. 스냅샷 후 적용, 중간 실패 시 롤백(R-21-31)
```

### 11.3 Effect 적용과 이벤트 발행 (화면 3)

```
 EffectApplier.apply([set_flag, give_item, start_quest], mutator)
   E1 set_flag(flag.gen_ep1.quest.name_on_ossuary.heard_out)
        WorldState.flags 에 추가
        → publish(flag_changed {flagId, value:true})
   E2 give_item(item.gen_ep1.crumpled_roster, 1)
        WorldState.inventory[…] = 1
        → publish(item_gained {itemId, delta:1, total:1})     ← 정본 payload (BP-23 §23.11.1 #5)
   E3 start_quest(quest.gen_ep1.name_on_ossuary)
        QuestRuntime.start(...)
          prerequisites = {"op":"true"} → 통과
          quests[q] = { state:"active", stage:"bring_the_name",
                        counters:{o_hand_roster:0, o_see_the_niche:0},
                        startedAt: step, updatedAt: step }
                        ※ D-08a 는 startedStep/updatedStep 을 요구한다 → §13 W-09
          stage 진입 절차 (BP-23 §23.3.4)
            1. prev.onExit  — 없음(최초 진입)
            2. stage ← bring_the_name
            3. counters 초기화(전부 0)
            4. journal append {questId, stageId:"bring_the_name",
                               entryKey:"str.…stage.bring_the_name.journal", at: step}
            5. onEnter = [] 적용
            6. 재평가 루프 — 상태형 목표 초기 스캔
                 o_see_the_niche(reach): 파티 (17,37) ∉ (62,76)±1 → 0
                 o_hand_roster(deliver): 누적형 → 초기 스캔 없음
               전이 조건 미충족 → 루프 종료 (1회)

 4.8  DialogueResult { reachedEnd:true, lastNode:"n_give", deferred:[], nodesVisited:2 }
        deferred 가 비었다 — warp / start_battle / play_dialogue 없음
```

### 11.4 배치 드레인 — 목표 진행이 일어나는 유일한 지점

```
 4.9  WorldEventBus.drain()          ← 재진입 불가. 이미 드레인 중이면 즉시 반환
        큐: [ talk, dialogue_choice, flag_changed, item_gained ]   (발생 순서 보존)

        구독자는 QuestRuntime 하나뿐이다.

        ① talk {actorId: npc.core.lore_tavern_drunk}
             활성 퀘스트의 목표만 검사(§6.3 성능)
             현재 stage 는 bring_the_name — talk_to 목표 없음 → 무진행
             ※ deliver 는 talk ∧ item_lost 를 같은 배치에서 봐야 하는데 item_lost 가 없다 → 무진행
        ② dialogue_choice → choose 목표 없음 → 무진행
        ③ flag_changed  → flag_set 목표 없음 → 무진행
        ④ item_gained {itemId: crumpled_roster, delta:1, total:1}
             acquire 목표 없음 → 무진행
             ※ 이 퀘스트는 acquire 를 쓰지 않는다. 쪽지는 deliver 의 매개물일 뿐이다.

        WorldState.step += 1  (이벤트 4건을 하나의 배치로 처리 — 배치당 1 증가)
        큐 비움. maxCascadeDepth(8) 미도달.

 4.10 지연 효과 실행 — deferred 가 비었으므로 없음. pendingNavigation = null
 4.11 isInteracting ← false  (락 해제, finally)
 4.12 return true            ← 티어 0 이 처리했다. 아래 티어로 내려가지 않는다(D-10)

 5  HDTileEventDispatcher finally
 5.1   host.endNarrative(autoFlush: ContentRuntime().pendingNavigation == null → true)
 5.2   저널 알림 큐 flush (R-41-12) — narrative 중 쌓인 2줄을 진행 패널로
 5.3   _isScriptRunning ← false
```

### 11.5 발행된 월드 이벤트 — 이름은 D-20, payload 는 BP-23 §23.11.1

이 예제의 전 구간에서 발행되는 이벤트를 **D-20 의 12종 정본 이름**으로 정리한다.
**payload 정본은 [BP-23 §23.11.1](23_quest_model.md) 의 12행 표 하나**이며(D-20a·D-25 · `I-01`/`I-18` 해소),
이 절은 payload 를 나열하지 않고 그 표를 가리킨다 — 실제 값은 §7.2 트레이스에서 볼 수 있다.

| 시점 | 이벤트 | 진행시키는 목표 |
|---|---|---|
| 주점 진입 | `enter_place` | — (이 퀘스트는 place 형 `reach` 를 쓰지 않는다) |
| 취객에게 말 걸기 | `talk` | `o_report_back` (stage 2 에서만) |
| 선택지 확정 | `dialogue_choice` | — (`choose` 목표 없음) |
| `set_flag` 적용 후 | `flag_changed` | — (`flag_set` 목표 없음) |
| `give_item` 적용 후 | `item_gained` | — (`acquire` 목표 없음) |
| 매 이동 | `step_tile` | `o_see_the_niche` (좌표형 `reach`) |
| 납골당 진입 | `enter_place` | — |
| `take_item` 적용 후 | `item_lost` | `o_hand_roster` (같은 배치의 `talk` 과 짝을 이뤄) |
| `set_npc_state` 적용 후 | — | **발행하지 않는다.** D-20 에 `npc_state_changed` 가 없다 |
| 완료 시 `add_var` | `var_changed` | — (`var_reach` 목표 없음) |
| 완료 시 `add_gold` | `gold_changed` | — (Condition 재평가·실패 판정 전용) |

**쓰이지 않는 이벤트**: `battle_won`(전투 없음), `map_changed`(맵을 벗어나지 않음),
`party_rested`(휴식 없음). 이것이 [BP-23 §23.11.4](23_quest_model.md) 가 말한
"목표 진행에 안 쓰이는 이벤트" 와 "쓰이지 않는 이벤트" 의 구분이다.

**발행 지점이 없는 이벤트 2종**: `item_gained`/`item_lost` 는 D-20 이
"인벤토리 부재로 BP-42 가 만들 때까지 미발행" 이라고 못 박은 것이다.
**이 예제는 그 둘에 전적으로 의존한다** — `deliver` 목표가 `item_lost` 없이는 절대 진행되지 않는다.
즉 이 퀘스트는 **BP-42 의 인벤토리 시스템이 구현되기 전에는 완주 불가**다. → §13 `W-10`

> **[2판] 이 사실이 이제 기계 판정으로 올라왔다 (D-26).** 초판은 이 단락을 사람이 읽는 경고로만 남겼고
> §7.3 의 솔버는 `PROVEN` 을 냈다. **D-26 이 이 예제를 근거로 솔버 판정을 2축으로 확정**했으므로
> 위 2종은 빌드의 **이벤트 → 발행 지점 레지스트리**에서 `unpublished` 로 표시되고,
> 이 퀘스트는 **`PROVEN` + `UNSUPPORTED`** 를 받아 릴리스 게이트에서 차단된다(§7.3).
> `enter_place` 도 D-20 의 미발행 목록에 있지만 **완주 경로가 소비하지 않으므로**(유일한 소비자
> `o_see_the_niche` 가 좌표형 `reach` 이고 `optional: true`) 축 판정에 들어가지 않는다.

### 11.6 `set_npc_state` 가 이벤트를 못 내는 문제

`onComplete` 의 `set_npc_state(npc.core.lore_tavern_drunk, "at_peace")` 는 `WorldState.npcStates` 를
바꾸지만 **어떤 월드 이벤트도 발행하지 않는다**(D-20 12종에 없다). 결과:

- `npc_state` Condition 을 쓰는 다른 대화의 라우팅은 **다음 상호작용 때 재평가**되므로 실제로는 동작한다.
- 그러나 `npc_state` 변화를 목표로 삼는 방법이 없다. `Objective.kind` 9종에도 `npc_state` 가 없다.
- 우회: `set_npc_state` 와 `set_flag` 를 **쌍으로** 쓰고 목표는 `flag_set` 으로 잡는다.
  이 예제의 `onComplete` 가 정확히 그 형태다(`name_recorded` 플래그 + 상태 2개).

→ §13 `W-13`

---

## 12. 세이브 결과 — 완료 직후의 `WorldState`

화면 7 직후(step 61) 저장한 세이브 v2 전문이다. 포맷은 [BP-25 §5.1](25_world_state_and_save.md),
스키마는 [BP-90 §2.16](90_appendix_schemas.md).

```json
{
  "version": 2,
  "envelope": {
    "savedAtWallClock": "2026-08-30T14:02:11.000Z",
    "appVersion": "0.5.0",
    "slotLabel": "로어성 · 주점",
    "playStep": 61,
    "stateHash": "a71b0d4c9e33f210"
  },
  "currentMapName": "TOWN1",
  "party": { "…": "HDParty.toJson() 그대로 (party.dart:182)" },
  "gameSystem": { "…": "HDGameSystem.toJson() 그대로" },
  "gameOption": {
    "flags": [false, "…256칸. index 41/42/43 이 true"],
    "variables": [0, "…256칸"],
    "mapType": 0,
    "scriptFile": ""
  },
  "mapDelta": {
    "tileOverrides": {},
    "unitPatches": [],
    "handicapData": [0, 0, 0, 0]
  },
  "worldState": {
    "schemaVersion": 2,
    "contentVersion": { "core": "1.1.0", "gen_ep1": "0.5.0" },
    "flags": [
      "flag.gen_ep1.map.town1.ossuary_niche_fired",
      "flag.gen_ep1.quest.name_on_ossuary.heard_out",
      "flag.gen_ep1.quest.name_on_ossuary.name_recorded"
    ],
    "vars": {
      "var.core.party.reputation_lore": 3
    },
    "quests": {
      "quest.gen_ep1.name_on_ossuary": {
        "state": "completed",
        "stage": null,
        "counters": { "o_report_back": 1 },
        "startedAt": 5,
        "updatedAt": 61
      }
    },
    "inventory": {},
    "npcStates": {
      "npc.core.lore_crypt_keeper": "done",
      "npc.core.lore_tavern_drunk": "at_peace"
    },
    "visited": [
      "place.core.lore_castle",
      "place.core.lore_crypt",
      "place.core.lore_tavern"
    ],
    "journal": [
      { "questId": "quest.gen_ep1.name_on_ossuary", "stageId": "bring_the_name",
        "entryKey": "str.gen_ep1.quest.name_on_ossuary.stage.bring_the_name.journal", "at": 5 },
      { "questId": "quest.gen_ep1.name_on_ossuary", "stageId": "tell_the_drunk",
        "entryKey": "str.gen_ep1.quest.name_on_ossuary.stage.tell_the_drunk.journal", "at": 47 },
      { "questId": "quest.gen_ep1.name_on_ossuary", "stageId": null,
        "entryKey": "str.gen_ep1.quest.name_on_ossuary.journal_done", "at": 61 }
    ],
    "seed": 20260830,
    "step": 61,
    "rngCursor": 0
  },
  "legacy": {
    "nativeFlags": {},
    "nativeVariables": {}
  }
}
```

### 12.1 이 JSON 이 지키는 불변식

| 불변식 | 확인 |
|---|---|
| `INV-1` `state == active ⇔ stage != null` | `completed` 이므로 `stage: null` ✅ |
| `INV-3` `inventory[i] >= 1` | 쪽지를 건네 0 이 되었으므로 **키 자체가 없다** ✅ |
| `INV-5` `flags`/`visited` 정렬 출력 | 사전순 ✅ |
| `INV-6` `step` 비감소 | 5 → 47 → 61 ✅ |
| `INV-7` `journal.at` 비감소 | 5 ≤ 47 ≤ 61 ✅ |
| 결정론 | `rngCursor: 0` — 이 퀘스트는 난수를 한 번도 쓰지 않았다. `chance` 도 전투도 없다 ✅ |

### 12.2 눈여겨볼 값

| 값 | 왜 그런가 |
|---|---|
| `mapDelta` 가 **전부 비었다** | `change_tile` 을 쓰지 않았다. **[2판]** 초판이 함께 적은 `region(62,76)=200` 은 D-27·D-28 로 **애초에 일어나지 않는 편집**이 됐다(§5.3 주석) — 앵커는 맵 데이터에 흔적을 남기지 않으므로 소스 맵 파일도 무변경이다. 결론(`mapDelta` 가 빈다)은 같고 **이유가 하나 줄었다** |
| `gameOption.flags[41..43]` | `legacyFlagMap` 역참조로 이름 있는 플래그 3개가 정수 슬롯에 **동시 기록**된다. cm2 가 `Flag::IsSet(42)` 로 읽을 수 있다([BP-28](28_migration_and_coexistence.md) 다리) |
| `scriptFile: ""` | T-22-1 이후 `MapInfos.json` 의 `TOWN1` 에 `cm2` 필드가 없으므로 페어링 cm2 가 **없다**. 부록 A-1 의 "존재하지 않는 `Map004.cm2`" 가 사라졌다 |
| `journal[2].stageId: null` | 완료 엔트리는 스테이지에 속하지 않는다. `journalComplete` 키를 쓴다 |
| `rngCursor: 0` | `chance` 는 **커서를 밀지 않는다**(D-21). 이 퀘스트는 Effect 난수도 쓰지 않는다. **[2판] 이 예제에는 `chance` 노드가 0개**이므로 D-30 의 유도식 확정(`chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p`)이 이 세이브의 어느 값도 바꾸지 않는다 — `content.lock.json` 의 `chanceSeedIds` 도 빈 맵이다(§9.2). 즉 이 예제는 **`chance` 를 검증하지 않는다**([BP-34](34_headless_sim_and_solver.md) `FX_ROOM` 이 그 역할을 맡는다) |
| `startedAt` / `updatedAt` / `at` | **D-08a 는 `startedStep`/`updatedStep`/`atStep` 을 요구한다.** BP-25 §5.1 의 예시 JSON 을 그대로 따랐다 → §13 `W-09` |

### 12.3 세이브 크기

```
$ wc -c save_data_1.json
   4118 save_data_1.json      (worldState 부분 1,024B)
```

v1 이었다면 `map` 전체 스냅샷 100×100 = **약 570KB**(부록 C-3)였다.
`currentMapName` + `mapDelta` 로 바뀌면서 **약 140배** 줄었다. 슬롯 4개 합계 16KB —
브라우저 `localStorage` 5MB(UTF-16 이라 실질 2.5MB) 대비 여유.

---

## 13. 이 예제가 드러낸 문제

> **기록만 한다. 고치지 않는다**(D-18). 각 항목의 "고칠 장" 이 소유 장이다.
> 앞선 [BP-90 §5](90_appendix_schemas.md) 의 `I-01`~`I-20` 은 **문서를 대조해서** 나온 것이고,
> 아래 `W-01`~`W-13` 은 **실제로 만들어 보다가** 나온 것이다. 겹치는 것은 상호 참조로 표시했다.
>
> **[2판] `상태` 열을 신설했다.** 초판 13행의 `위치`·`무엇이 막혔나` 열은 **적발 당시의 사실이므로 고치지 않는다**
> ([BP-90 §5.2](90_appendix_schemas.md) 와 같은 규약 — 무엇이 왜 어긋났는지가 이 절의 산출물이다).
> 판정 기준도 같다: **"결정이 났는가" 가 아니라 "소유 장이 고쳤는가 / 근거가 소멸했는가"** 다.
>
> | 판 | 차단 | 높음 | 보통 | 해소 |
> |---|---|---|---|---|
> | 초판 | 3 | 5 | 5 | 0 |
> | **2판** | **1** (`W-10` 잔여) | **3** | 5 | **4** (`W-01`·`W-04`·`W-07` 완전 · `W-10` 부분) |

### 13.1 차단 — 이 예제가 실제로 굴러가지 않는 이유

| ID | 위치 | 무엇이 막혔나 | 고칠 장 | **상태(2판)** |
|---|---|---|---|---|
| **W-01** | [BP-21 §4.1](21_content_pack_spec.md) `STRING_KEY` 정규식 ↔ §5.3 표준 슬롯 표 | **이 예제의 대화 문자열 키 26개가 전부 정규식을 통과하지 못한다.** 정규식은 슬롯을 **단일 세그먼트** `[a-z][a-z0-9_]{2,47}` 로 규정하는데, §5.3 이 정한 표준 슬롯은 `node.<nodeId>.line.<n>`·`choice.<nodeId>.<choiceId>`·`stage.<stageId>.journal`·`objective.<objId>.desc` 처럼 **점을 포함하고 숫자로 끝난다**. BP-21 §5.4 의 자기 예시 `str.gen_ep1.dlg.wife_plea.node.intro.header` 조차 통과하지 못한다. [BP-90 §2.1](90_appendix_schemas.md) `common.stringKey` 는 이 정규식을 **충실히 옮겼으므로 같은 결함을 물려받았다**(D-18 준수). 즉 L1 스키마 검사를 켜는 순간 **모든 대화 콘텐츠가 하드 실패**한다 | **BP-21** | ✅ **해소** — [BP-21 §4.1.1](21_content_pack_spec.md) 이 `STRING_KEY` 를 slot-path 로 확장(§9.1 항목 14). **§4.7.1 에서 이 장의 키 40개를 정규식에 대입해 40/40 통과 확인** |
| **W-10** | D-20 · [BP-42](42_item_and_inventory.md) 부재 | `deliver` 목표는 `talk` ∧ `item_lost` 를 같은 배치에서 봐야 진행된다. D-20 은 `item_gained`/`item_lost` 가 **인벤토리 부재로 아직 미발행**임을 명시했다. 이 예제의 핵심 목표 `o_hand_roster` 는 그 이벤트에 전적으로 의존하므로, **BP-42 가 인벤토리를 만들기 전에는 이 퀘스트가 완주 불가**다. 그런데 §7.3 의 솔버는 `PROVEN` 을 냈다 — **솔버가 "이벤트 발행 지점이 실제로 존재하는가" 를 보지 않기 때문**이다. 정적 증명과 실행 가능성이 갈라진다 | **BP-34**(발행 지점 존재 검사 추가) · **BP-42**(인벤토리) | ⚠ **부분 해소** — 솔버 절반은 **해소**: D-26 이 이 발견을 근거로 판정을 **2축**(모델 증명 × 실행 가능)으로 확정했고, §7.3 을 `PROVEN` + `UNSUPPORTED` 로 갱신했다. **인벤토리 절반은 여전히 차단** — [BP-42](42_item_and_inventory.md) 가 `WorldState.inventory` 를 구현하기 전까지 이 퀘스트는 완주 불가이고 팩은 "미활성" 이다 |
| **W-09** | D-08a ↔ [BP-25 §2.2·§5.1](25_world_state_and_save.md) | §12 의 세이브 JSON 을 쓰면서 `startedAt`/`updatedAt`/`at` 과 `startedStep`/`updatedStep`/`atStep` 중 어느 것을 쓸지 정할 수 없었다. **세이브 파일의 필드명**이라 나중에 바꾸면 마이그레이션이 필요하다. BP-90 §2.15 도 같은 이유로 BP-25 표기를 따랐다. [BP-90 §5.2 `I-04`](90_appendix_schemas.md) 와 같은 건 | **BP-25** | ❌ 미해소 — 세이브 필드명은 [BP-25](25_world_state_and_save.md) 소유. [BP-90 §5.2.1](90_appendix_schemas.md) 은 `I-04` 를 해소로 판정했으나(BP-25 §2.2 가 `startedStep`/`updatedStep`/`atStep` 으로 개정) **이 장 §12 의 예시 JSON 은 아직 초판 이름을 쓴다** — 다음 개정에서 교체 |

### 13.2 높음 — 구현이 갈라지는 지점

| ID | 위치 | 내용 | 고칠 장 | **상태(2판)** |
|---|---|---|---|---|
| **W-04** | [BP-26 §3.2·§3.5 R-26-10](26_entity_registry_and_anchors.md) | `trigger` 앵커의 `event` 액션은 **region 200~255 승격(1티어)** 으로 만들어지는데, 같은 칸에 `objUpper 128`(2티어 `talk`)이 있으면 **어느 쪽이 이기는지 규정이 없다.** R-26-10 은 "레거시 `events[]` 가 region 승격보다 나중에 적용된다" 만 말한다. §5.3 에서 콘텐츠 서버는 2티어를 우선해 400 을 냈지만, 로더 수정안(`ixEvent = 0x00010000 \| region`)대로면 1티어가 이긴다. **서버와 런타임이 다르게 판단한다** | **BP-26** | ✅ **해소** — **문제 자체가 소멸했다.** D-28 이 region 승격안(BP-26 T1)을 **최종 기각**했으므로 1티어가 존재하지 않고 1↔2티어 우선순위 충돌도 발생하지 않는다. 앵커는 타일 비트를 쓰지 않고 **트리거 인덱스를 직접 조회**한다(D-27) — 서버와 런타임이 같은 인덱스를 보므로 "다르게 판단" 할 여지가 없다. 근거 기록은 [BP-90 §5.2.1 (B)](90_appendix_schemas.md), 이 장의 파급 주석은 §5.3 |
| **W-07** | D-20 ↔ [BP-23 §23.11.1](23_quest_model.md) | §7.2 의 트레이스를 쓰면서 payload 를 어느 정본으로 쓸지 정할 수 없었다. 트레이스는 **바이트 비교 골든**이므로 이 선택이 회귀 테스트의 기준 자체를 바꾼다. 나중에 바꾸면 모든 골든을 재승인해야 한다. [BP-90 §4.5 · §5.2 `I-01`](90_appendix_schemas.md) 의 실사용 파급 | **BP-23** | ✅ **해소** — 선택할 두 정본이 없어졌다. D-20a·D-25 가 D-20 의 payload 표를 삭제하고([BP-90](90_appendix_schemas.md) `I-01`), [BP-23](23_quest_model.md) 이 자기 장 안의 중복 표기까지 제거했다(`I-18` · `R-23-24`). **§7.2 트레이스의 4종 payload 를 정본으로 교체**했고 골든 재승인 1회가 그 비용이다 |
| **W-08** | [BP-27 §2.6](27_runtime_engine.md) · [BP-34 §3.6](34_headless_sim_and_solver.md) ↔ D-20 | 13번째 이벤트 `quest_state_changed`. §7.2 의 트레이스는 **발행하지 않는 쪽**을 골랐다. 발행하는 쪽을 고르면 `world_event` 항목 3개가 트레이스에 추가되어 골든이 달라진다. [BP-90 §5.2 `I-02`](90_appendix_schemas.md) 와 같은 건 | **BP-23** | ❌ 미해소(표기) — [BP-90 §5.2.1](90_appendix_schemas.md) 은 `I-02` 를 **해소**로 판정했다([BP-34](34_headless_sim_and_solver.md) 가 `quest_state` 를 **트레이스 전용 kind** 로 정정, BP-27 에서 그 이름이 0건). 즉 **이 장이 고른 "발행하지 않는 쪽" 이 정본이 됐다** — 트레이스는 무변경이고, 남은 것은 이 행의 표기뿐이다 |
| **W-13** | D-20 · [BP-23 §23.4](23_quest_model.md) | `set_npc_state` 는 `WorldState.npcStates` 를 바꾸지만 **어떤 이벤트도 발행하지 않고**(12종에 없다), `Objective.kind` 9종에도 `npc_state` 가 없다. 따라서 "NPC 가 어떤 상태가 되는 것" 을 목표로 삼을 수 없다. 우회는 `set_npc_state` + `set_flag` 를 쌍으로 쓰는 것인데, **상태와 플래그를 동기화할 책임이 콘텐츠 작성자에게 넘어간다** — 이름 있는 상태를 도입한 이유(D-16-4)가 부분적으로 무력해진다 | **BP-23**(이벤트/kind) | ❌ 미해소 — [BP-23](23_quest_model.md) 이 3판에서 `I-09`/`I-16`/`I-18` 을 고치면서도 **이벤트 12종과 objective 9종은 늘리지 않았다**(추가는 `schemaVersion` 승격 사항). 우회(`set_npc_state` + `set_flag` 쌍)가 유지된다 |
| **W-12** | [BP-23 §23.9.3](23_quest_model.md) ↔ GROUND_TRUTH §10 | tier 1 권장 `grant_exp` 200~1,500 을 지켰는데(900), exp 테이블 2단계 임계가 **0** 이라 첫 퀘스트 하나로 파티 전원이 레벨 2가 된다(§10 화면 7). §23.9.3 의 산정 규칙은 "다음 레벨업까지 필요한 Δexp 의 10~40%" 인데, **1→2 의 Δexp 가 0 이므로 그 규칙이 성립하지 않는 구간**이다. `QV-31` 은 범위 안이라 아무것도 잡지 못한다 | **BP-23** | ❌ 미해소 — [BP-23 §23.9.3](23_quest_model.md) 의 tier 1 산정 규칙이 그대로다. 참고: 3판의 `I-09` 정정(적 id 1~74)은 **보상 수치를 바꾸지 않았으므로**(§23.9.2 검산) 이 문제도 그대로 남는다 |

### 13.3 보통 — 절차·표기의 공백

| ID | 위치 | 내용 | 고칠 장 | **상태(2판)** |
|---|---|---|---|---|
| **W-02** | [BP-24 §24.2.1](24_dialogue_model.md) | `Dialogue.kind: "narration"` 인데 `speaker` 가 **필수**다. §4.4 의 `ossuary_niche` 는 아무도 말하지 않는 서술인데 화자로 납골당지기를 넣어야 했다. 그 결과 지기의 `knowledge` 범위 검사가 이 나레이션 문장에도 적용된다 — 서술자가 액터의 지식에 묶인다. [BP-90 §5.2 `I-15`](90_appendix_schemas.md) 의 구체적 사례 | **BP-24** | ❌ 미해소 — [BP-90](90_appendix_schemas.md) 은 `I-15` 를 해소로 판정했으나(재생 경로 확정 + 앵커 오용 시 린트 경고), **`narration` 의 `speaker` 필수 여부**는 [BP-24](24_dialogue_model.md) 가 아직 답하지 않았다 |
| **W-03** | [BP-26 §2.3](26_entity_registry_and_anchors.md) `trigger.onceFlag` | 자동 생성 규칙 `flag.<pack>.map.<mapname>.<anchor_slug>_fired` 의 `<mapname>` 에 `TOWN1` 을 넣으면 `flag.gen_ep1.map.TOWN1.…` 가 되어 **상태 키 문법(소문자만)을 위반**한다. 소문자화 규칙이 없다. §6.4 에서 Binder 가 손으로 `town1` 을 넣었는데, 그러면 `Template_TOWN` → `template_town`, `LORE_EP` → `lore_ep` 같은 변환 규칙이 **어디에도 정의돼 있지 않다** | **BP-26** | ❌ 미해소 — 맵 이름 소문자화 변환 규칙이 [BP-26](26_entity_registry_and_anchors.md) 에 없다. §4.7.1 의 `STATE_KEY` 대입에서 이 반례가 **여전히 불통과**로 잡힌다 |
| **W-05** | `tile_event_dispatcher.dart:117` ↔ [BP-21 §5.5](21_content_pack_spec.md) | 현행 코드의 SIGN 기본 헤더가 `'@B푯말에 써 있기를:'` — **`@B` 를 열고 닫지 않는다.** BP-21 §5.5 는 "한 문자열 안에서 열린 태그는 반드시 닫힌다" 를 하드 실패로 규정한다. §4.7 에서 이 관행을 따라 헤더를 쓴 결과 린트에 걸렸다(§6.1). **원작 관행과 새 규칙이 충돌**한다 — 콘솔이 줄 끝에서 색을 자동 리셋하는지 여부에 따라 규칙이 달라져야 한다 | **BP-21**(규칙) · **BP-28**(레거시 문자열 변환) | ❌ 미해소(등급 강등) — [BP-21 §9.1 항목 8](21_content_pack_spec.md) 이 색상 태그 집합을 파서 실측에 맞춰 정정하고 **미종료 태그를 경고로 강등**했다(파서가 문자열 끝에서 자동 해제). 하드 실패는 사라졌으나 **레거시 문자열 변환 규칙**([BP-28](28_migration_and_coexistence.md) 절반)은 미정 |
| **W-06** | [BP-32 §32.3.4](32_generation_harness.md) · [BP-31 §3.3](31_content_server_api.md) | Binder 가 맵 편집을 **적용한 뒤** 앵커 생성이 실패하면(§5.3~5.4) 맵에 고아 변경이 남는다. §6.4 에서 손으로 되돌렸지만, **되돌림 절차가 어느 장에도 없다.** BP-31 §3.3 의 2단계 커밋은 콘텐츠 배치 편집 안의 원자성이지, 맵 API 와 콘텐츠 API **사이의** 원자성이 아니다 | **BP-32**(단계 실패 시 롤백) · **BP-31**(교차 API 원자성) | ❌ 미해소 — 교차 API 원자성·단계 실패 롤백이 [BP-31](31_content_server_api.md)/[BP-32](32_generation_harness.md) 에 아직 없다. 참고: D-28 로 §5.3 의 맵 편집이 사라지므로 **이 예제에서는 고아 변경이 생기지 않지만**, 맵 편집을 수반하는 다른 앵커(예: `change_tile` 을 쓰는 콘텐츠)에서는 그대로 성립한다 |
| **W-11** | [BP-21 §3.3](21_content_pack_spec.md) `entryPoints` | `entryPoints` 는 `quests`/`anchors`/`places` 세 칸뿐이다. §9.3 의 `flag.gen_ep1.quest.name_on_ossuary.name_recorded` 는 **후속 에피소드가 읽을 것을 전제한 의도적 접점**인데, 그 의도를 선언할 칸이 없어 린트가 "쓰기만 하고 읽지 않는 플래그" 로 경고한다. 억제하려면 `_note` 에 `lint-ignore` 를 넣어야 하는데, 그건 의도의 표현이 아니라 경고의 은폐다 | **BP-21** | ✅ 해소 — [BP-21 §9.1 항목 17](21_content_pack_spec.md) 이 `entryPoints.stateKeys` 를 신설했다. §3.6 팩 예시가 `stateKeys` 로 접점을 선언하므로 `RG-02`/`RG-03` 경고를 `_note` 의 `lint-ignore` 없이 억제할 수 있다 |

### 13.4 스펙이 잘 버틴 곳 (반대 기록)

문제만 적으면 균형이 맞지 않는다. **실제로 써 보니 제대로 작동한 설계**를 남긴다.

| 설계 | 어디서 효과가 났나 |
|---|---|
| 앵커 ↔ 타일 정합 검사(BP-26 §3.3) | §5~§6 의 위반 1건을 **좌표 후보와 함께** 잡았다. 사람이 "여기 밟을 수 있나" 를 눈으로 확인할 필요가 없었다 |
| `{error, hint}` 규약 계승 | §5.3 의 서버 400 응답이 통행 가능 좌표 3개를 함께 줬다. 재시도가 1회로 끝났다 |
| `--format=ai` 리포트(BP-33 §7.3) | §6.3 을 그대로 다음 턴에 붙여 3건을 한 번에 고쳤다. "참조 가능한 대화 전량" 을 준 덕에 두 번째 오타가 나지 않았다 |
| 라우팅 확장 파일(BP-22 R-22-14) | core 액터 2인을 **한 글자도 고치지 않고** 대화를 붙였다. 소유권 규칙이 실제로 작동한다 |
| `mapResolution`(BP-35 R-35-11) | 부록 D-1 의 파손이 **빌드에서 막힌다**는 것을 §6.5 에서 확인했다. 게임은 삼키지만 빌드는 삼키지 않는다 |
| `currentMapName` + `mapDelta`(BP-25 §5) | 세이브가 570KB → 4KB. 부록 C-3 의 웹 저장 한계 문제가 사라졌다 |
| `showMenu(clearLogs:false)`(BP-24 §24.4.3) | 화면 2 에서 대사 4줄이 선택지 위에 남는다. 선택이 무엇에 대한 응답인지 화면만 봐도 안다 |
| 알림 큐 flush(BP-41 R-41-12) | 대화 중 쌓인 저널 알림 2줄이 `endNarrative` 직후 한 번에 나온다. 대화가 끊기지 않는다 |
| Effect 원자성 + 꼬리 호출(R-21-31/38/40) | `c_accept` 의 3개 효과가 하나로 적용되고, `play_dialogue`/`warp` 가 없어 지연 처리가 필요 없었다. 규칙이 단순함을 강제했다 |
| 상태형 목표의 초기 스캔(BP-23 §23.4.2) | `o_see_the_niche` 가 stage 진입 시 0 으로 스캔되고, 나중에 밟았을 때 래치된다. "이미 그 자리에 서 있었다면" 데드락이 원천 차단된다 |

---

## 14. 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 14.1 확정한 것

| # | 내용 |
|---|---|
| 1 | 원작 재료(취객·납골당지기·LORE 특공대·유골)만으로 만든 tier 1 퀘스트 1건의 **전 산출물** — 퀘스트 1 · 대화 3 · 아이템 1 · 앵커 1 · 라우팅 확장 2 · 문자열 38 |
| 2 | 좌표를 **`TOWN1.json` 실측**으로 고정: 취객 (17,37) · 지기 (71,77) · 트리거 (62,76) · 인접 통행칸 (16,37)/(72,77). 각 칸의 objUpper/A5 값과 타일 액션 판정 근거를 함께 남김 |
| 3 | **T-22-1 이 선행 조건**임을 실증 — `MapInfos.json` 에 `json` 필드가 없으면 `V-MAP-016` 으로 lint 에서 막힌다(§6.5) |
| 4 | 8단계 전 구간의 산출물 실물: `orders/*.json` · `budget_report.json` · `QuestOutline` · draft 6파일 · `bind_report.json` · 린트 3포맷 · 트레이스 · 솔버 리포트 · `CriticReport` 2회 · `StyleReport` · `commit_plan.json` · lock/index diff · `summary.md` |
| 5 | **일부러 심은 위반 3건**(앵커 타일 불일치 · 대화 id 오타 · 색상 태그 미닫힘)이 각각 `V-MAP-002`/`V-L2-007`/`V-L1-014` 로 잡히고 1회 재시도로 해소되는 과정 |
| 6 | 검수 1차 31/40 `conditional`(blocking 1건) → 수정 → 2차 35/40 `pass` 의 실제 채점표와 수정 지시 |
| **6a** | **[2판] 솔버 판정을 2축으로 표기**(D-26) — 이 퀘스트는 `PROVEN`(모델) + `UNSUPPORTED`(실행 가능)이며 **커밋은 되고 릴리스는 막힌다**(팩 "미활성"). 미발행 이벤트 2종과 그것을 소비하는 목표를 `unpublishedEvents` 로 명시(§7.3) |
| **6b** | **[2판] 산출물 정합 재점검 8항목**(§9.5) — D-27/D-28·`I-01`/`I-18`·D-26·D-30·D-31·부록 H-1·`I-09`/`I-16`·`W-01` 을 이 예제에 대입한 결과와 조치. **`chance` 0개 · 장비 0개 · `defeat`/`survive` 0개**이므로 그 세 계열 결정은 이 예제를 통과하지도 검증하지도 않는다는 것을 명시 |
| 7 | 보상이 tier 1 권장 범위 정중앙임을 §23.9.3 표로 자체 검산, 총 보상 가치 14,300 산출 |
| 8 | 800×480 안의 **ASCII 목업 7화면** — 대화 → 선택 → 저널 알림 → 저널 창 → 나레이션 트리거 → 단계 전이 → 완료·보상 |
| 9 | 타일 상호작용 1회의 **런타임 실행 추적 전량**(디스패처 → 티어 0 → 라우팅 → 대화 루프 → Effect → 배치 드레인 → 락 해제 → narrative flush), 발행 이벤트를 D-20 12종 정본 이름 + **[BP-23 §23.11.1](23_quest_model.md) 정본 payload** 로 표기(2판) |
| 10 | 완료 시점 세이브 v2 **전문**과 불변식 7종 확인, 세이브 크기 4,118B(v1 대비 약 1/140) |
| 11 | **이 예제가 드러낸 문제 13건**(`W-01`~`W-13`) — 차단 3 · 높음 5 · 보통 5. 고치지 않고 위치·내용·고칠 장만 기록 |
| **11a** | **[2판] 그중 4건이 해소됐다** — `W-01`(문자열 키 정규식, **§4.7.1 에서 40/40 대입 확인**) · `W-04`(region 승격 기각으로 **문제 자체 소멸**, D-28) · `W-07`(payload 정본 단일화, `I-01`/`I-18`) · `W-10`(솔버 절반 — D-26 의 **2축 판정**). 나머지 9건은 `상태` 열에 미해소 사유와 그 사이 진행분을 기록 |
| 12 | **스펙이 잘 버틴 곳 10건**을 반대 기록으로 남김 |

### 14.2 다음 장으로 넘긴 것

| 대상 | 넘긴 것 |
|---|---|
| [BP-21](21_content_pack_spec.md) | ~~`W-01` 문자열 키 정규식 전면 재검토~~ **완료**(§4.1.1 slot-path 확장 · §4.7.1 대입 확인) · `W-05` 색상 태그 미닫힘 규칙과 원작 관행의 충돌(**경고로 강등** — 레거시 변환은 BP-28 절반이 남음) · ~~`W-11` `entryPoints` 에 상태 키 칸~~ **완료**(`entryPoints.stateKeys` 신설) |
| [BP-23](23_quest_model.md) | ~~`W-07` payload 정본~~ **완료**(§23.11.1 유일 정본 · `R-23-24`) · ~~`W-08` `quest_state_changed`~~ **완료**(트레이스 전용 kind 로 정정 — 이 장이 고른 쪽이 정본이 됐다) · `W-12` 레벨 1→2 Δexp 0 구간 · `W-13` `npc_state` 이벤트/objective 부재 |
| [BP-25](25_world_state_and_save.md) | `W-09` 시각 필드명 D-08a 반영(세이브 필드명이므로 되돌리기 비쌈) |
| [BP-26](26_entity_registry_and_anchors.md) | `W-03` `onceFlag` 자동 생성 시 맵 이름 소문자화 규칙. ~~`W-04` region 승격 ↔ objUpper 우선순위~~ — **넘길 것이 없어졌다**(D-28 이 최종 기각, `W-04` 해소) |
| [BP-24](24_dialogue_model.md) | `W-02` 화자 없는 나레이션의 표현 |
| [BP-31](31_content_server_api.md) · [BP-32](32_generation_harness.md) | `W-06` 맵 API ↔ 콘텐츠 API 교차 원자성과 단계 실패 시 롤백 |
| [BP-34](34_headless_sim_and_solver.md) | ~~`W-10` 솔버가 "이벤트 발행 지점이 실제로 존재하는가" 를 검사하도록 확장~~ **규정 완료**(D-26 의 2축 판정 · 레지스트리 대조는 BP-34, 생성은 [BP-35](35_ci_and_build.md), 게이트는 [BP-53](53_acceptance_criteria.md)). 남은 것은 **구현**이다 |
| [BP-42](42_item_and_inventory.md) | `W-10` 인벤토리 없이는 `deliver`/`acquire` 가 성립하지 않음 — 이 예제가 그 증거 |
| [BP-35](35_ci_and_build.md) | §9 의 lock/index diff 형태를 골든 리포트로 고정할지 |
| [BP-41](41_journal_ui_spec.md) | §10 의 7화면을 UI 구현 시 시각 회귀 기준으로 쓸지 |

### 14.3 열린 질문

| # | 질문 | 영향 | 잠정 |
|---|---|---|---|
| **Q-91-1** | 이 예제를 **픽스처로 커밋**할 것인가? [BP-34 §9](34_headless_sim_and_solver.md) 는 `FX_ROOM` 이라는 인공 최소 월드를 쓴다. 이 예제는 **실제 맵·실제 원작 대사**를 쓰므로 더 현실적이지만, `TOWN1.json`(100×100) 로드 비용과 core 팩 의존이 붙는다 | CI 시간, 픽스처 유지보수 | `FX_ROOM` 은 단위 픽스처로 유지하고, 이 예제는 **통합 골든 1건**으로 별도 추가한다 |
| ~~**Q-91-2**~~ | *(**종결** — D-26)* "`W-10` 때문에 이 퀘스트는 인벤토리 구현 전까지 실행 불가인데 솔버는 `PROVEN` 을 낸다. 능력 매트릭스를 넣으면 미구현 기능을 전제한 콘텐츠를 **미리 만들 수 없게** 된다." | 콘텐츠와 엔진의 병렬 개발 | **D-26 이 이 딜레마를 2축 판정으로 해소했다.** 모델 증명과 실행 가능을 **분리해 둘 다 보고**하므로 미리 만드는 것이 허용되고(커밋 가능), 배포만 막힌다(팩 "미활성" · 릴리스 게이트 차단). 잠정안의 `--assume-capabilities` 플래그 대신 **판정 자체를 2축으로** 만든 것이 차이다 — 플래그는 사람이 켜야 하지만 2축은 항상 보고된다. 축 이름·레지스트리 대조는 [BP-34](34_headless_sim_and_solver.md) 소유 |
| ~~**Q-91-3**~~ | *(**종결**)* `W-01` 을 고치는 두 방향 — (a) 정규식 완화 (b) 구분자를 `/` 로 변경 | 전 콘텐츠의 키 형태 | **[BP-21 §4.1.1](21_content_pack_spec.md) 이 (a) 를 채택**했다. 잠정안이 예측한 대로 파싱은 "앞 4 세그먼트 고정 + 나머지 전부 slot-path" 가 됐고, `slot-seg` 는 `local-name`(2~48자) 또는 `index`(0~9999, 선행 0 금지)다. (b) 를 기각한 근거는 **로컬 ID 자체가 `_` 를 포함**해 구분자를 바꿔도 모호성이 남는다는 것이다. **§4.7.1 에서 40/40 대입 확인** |
| **Q-91-4** | 검수 에이전트가 `blocking` 을 낸 `CF-01`(core 상태 선언)은 **사람 결정**으로 core 팩을 고쳐 해결했다. 이 경로가 잦아지면 "생성 팩은 core 를 못 고친다" 는 원칙이 형해화한다. 어느 빈도까지 허용하나? | 소유권 규칙의 실효성 | `commit_plan.json` 이 `core` 수정을 별도 카운트하고, 한 실행에서 2건을 넘으면 HG-3 에서 강제 검토 |
| **Q-91-5** | ASCII 목업(§10)을 **문서에만 두는 것**과 위젯 골든 테스트로 고정하는 것 중 어느 쪽인가? 후자는 UI 구현을 못 박지만 800×480 레이아웃이 이미 고정이라 비용이 크지 않을 수 있다 | UI 회귀 검출 | M2 에서 `test/presentation/journal_golden_test.dart` 1건으로 시작한다 |
