# P1-15 세계관 바이블 초기 데이터와 places 매핑

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-01 · P0-01 대기)
- **구간**: P1
- **규모**: M
- **선행**: P1-01 · P0-01
- **설계 근거**: [BP-22](../../blueprint/22_world_bible_model.md)(**소유 장** — 세계관·액터·아이템 카탈로그 **스키마**) · [BP-21 §5](../../blueprint/21_content_pack_spec.md)(문자열 키) · [D-03 · D-04 · D-20](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` 부록 D-1 · F-2 · G-2 · B-1

## 문제

**세계관이 데이터로 존재하지 않는다.** 지금 어디에 있는가:

- 고유명사와 설정이 `hadar2026_app/assets/lore_ep1.cm2` 등 cm2 대사 문자열 안에만 있다
  (cm2 전체 4,056줄 · `Talk` 호출 393개).
- 장소 개념이 없다. 맵 이름(`MapInfos.json`)이 전부이고 **맵과 장소가 1:1 로 가정**되어 있다.
  실제로는 `TOWN1` 하나 안에 주점·수용소·납골당이 들어 있다(BP-22 §4.7 이 좌표로 실측했다).
- 액터 개념이 없다. NPC 는 좌표에 붙은 대사 뭉치다.
- 맵 이름 해석이 깨져 있다 — `hadar2026_app/lib/application/map_navigation.dart:43` 이
  `resolvedJsonName = 'Map$idStr.json'` 으로 폴백(`:29`)을 덮어써
  등록 15개 중 **7개가 존재하지 않는 파일로 해석**된다(부록 D-1).
  더 나쁜 것: `hadar2026_app/lib/application/game_session.dart:97-128` 은 `bundle.json == null` 이어도
  `mapScriptFactory[bundle.mapName]` 이 있으면 네이티브 스크립트를 **직전 맵 위에 부착**한다(부록 F-2).
- `hadar2026_app/lib/application/scripting/native_script_runner.dart:25-30` 은 `TOWN2` 를 등록하지만
  `MapInfos.json` 에도 `assets/maps/TOWN2.json` 에도 없다 — **한 번도 실행된 적 없는 코드**(부록 G-2).

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 손으로 퀘스트를 만들 때 가장 먼저 필요한 것이
"이 퀘스트는 어디서 벌어지는가 / 누가 나오는가" 이고, 그것이 `places.json`·`actors/` 다.
없으면 저작자가 매번 맵 JSON 을 열어 좌표를 세는 수동 작업을 반복한다 —
**GATE-01 이 측정하는 "기계적 배선" 비용을 직접 키우는 요인이다.**

그리고 월드 이벤트 `enter_place` 가 **장소 개념 부재로 미발행**이다(D-20).
이 이슈가 끝나야 P1-09 의 12종 중 마지막 하나가 발행된다.

## 무엇을 할 것인가

**스키마는 [BP-22](../../blueprint/22_world_bible_model.md) 소유다. 필드 표를 재서술하지 않는다.**
초기 데이터는 BP-22 의 §3.3(세력) · §4.7(places) · §5.8(액터 예시) · §6.5(아이템 시드) 초안을 **그대로 옮긴다.**

1. **선행 데이터 수리 — T-22-1**
   `MapInfos.json` 의 **7개 깨진 엔트리**에 `"json": "TOWN1.json"` 등을 추가한다.
   코드는 이미 이 필드를 지원한다(`map_navigation.dart:45`) — **데이터만 고치면 된다.**
   맵 에디터의 `registerAs` 는 이미 `json` 필드를 쓰므로(`tools/mapEditor/server/ai_api.ts:592`, 부록 H-4)
   **수리 대상은 기존 15개 엔트리뿐**이다.
   **이 수리는 P0-01 이 담당한다.** 이 이슈는 그 결과를 전제로 하고, `places.map` 검증으로 재발을 막는다.
2. **`assets/content/core/world/`**
   - `lore.json` — `axes`(세계 축) · `chronicle`(연대기) · `tone` · `taboos`. [BP-22 §2](../../blueprint/22_world_bible_model.md).
   - `factions.json` — [BP-22 §3.3](../../blueprint/22_world_bible_model.md) 의 초기 세력 데이터.
     관계 값 척도는 §3.2.
   - `places.json` — [BP-22 §4.7](../../blueprint/22_world_bible_model.md) 의 **15개 장소 초안**을 옮긴다.
     `TOWN1` 위의 4개 장소(성 전체 + 주점 · 수용소 · 납골당 구역)처럼 **맵과 장소는 1:N** 이다(§4.1).
     `map: null` 장소(성전·안타레스 동굴)는 맵 미제작 상태로 남긴다.
     **`TOWN2` 대응 장소를 두지 않는다**(부록 G-2 — 맵이 생기면 그때 추가).
3. **`assets/content/core/actors/<slug>.json`**
   최소 세트만 만든다 — P1-16 이 쓸 인물 + 기존 cm2 에서 이미 말하는 인물.
   `role`(닫힌 집합) · `traits`(닫힌 집합) · `knowledge`(지식 범위) · `dialogueRouting` ·
   `states`(npcState 값 집합) · `sprite`. 스키마는 [BP-22 §5](../../blueprint/22_world_bible_model.md).
   **`knowledge` 를 빼먹지 않는다** — 액터가 알 수 없는 것을 말하는 오류를 잡는 유일한 근거다(§5.4).
4. **`assets/content/core/items/items.json`** — P1-05 가 만든 카탈로그와 **같은 파일**이다.
   이 이슈는 `sources`(획득처 태그) 배분과 `grade` 유도만 맞춘다([BP-22 §6.3](../../blueprint/22_world_bible_model.md)).
5. **적 카탈로그 — 안 A 채택**([BP-22 §7.3](../../blueprint/22_world_bible_model.md)).
   `hadar2026_app/lib/domain/battle/enemy_data.dart:33` 의 `enemyTable` **75 엔트리(id 0~74)를 코드에 그대로 둔다.**
   `assets/content/build/enemies.index.json` 을 **빌드가 생성**한다(P1-12).
   - `hadar2026_app/lib/application/battle.dart:43-46` 의 `<= 0` 가드 때문에
     **id 0(`Orc`)은 영구 소환 불가**다. 실사용 가능한 적은 **id 1~74, 74종**이다(부록 B-1).
   - 인덱스에는 id 0 을 `summonable: false` 로 **남기되 어떤 콘텐츠도 참조할 수 없게** 한다 —
     레거시 cm2 의 `Battle::RegisterEnemy(0)` 이 왜 아무 일도 안 하는지 설명할 근거를 남기기 위해서다.
   - 표기 정본은 **정수 id** 이고 `enemy.<pack>.<slug>` 는 소스 가독성 별칭이다(R-22-25).
   - 마법은 `hadar2026_app/lib/domain/magic/magic.dart` 의 **45종(id 1~45)** 이며 같은 원칙(코드 유지 + 생성 인덱스)을 따른다.
6. **`assets/content/core/encounters/encounters.json`** — 인카운터는 **콘텐츠 소유**다([BP-22 §7.4](../../blueprint/22_world_bible_model.md)).
   "이 던전에 어떤 적이 나오는가" 는 콘텐츠이고 "적의 스탯" 은 시스템이다 — 이 경계가 안 A 의 핵심이다.
   각 인카운터의 적 수는 `HDParty.maxEnemy`(기본 3) 이하여야 한다.
7. **`assets/content/core/strings/ko.json`** — 모든 표시 문자열.
   인라인 텍스트 금지([BP-21 §5.1](../../blueprint/21_content_pack_spec.md)).
8. **`pack.json`** — `core` 팩 매니페스트([BP-21 §3.5](../../blueprint/21_content_pack_spec.md) 예시 1).
9. **`enter_place` 발행 배선** — places 의 좌표 구역 판정으로 장소 진입을 감지해 P1-09 의 버스에 발행한다.
   `WorldState.visited` 도 여기서 채워진다(Condition `visited` 의 재료).

## 완료 판정 기준

- [ ] `assets/content/core/` 에 `pack.json` · `world/{lore,factions,places}.json` · `actors/*.json` ·
      `items/items.json` · `encounters/encounters.json` · `strings/ko.json` 이 있다
- [ ] `hadar_content validate`(P1-12) 가 통과한다 — 특히 **모든 `places.map` 이 실제 파일로 해석**된다(R-22-11, hard)
- [ ] `places.json` 에 `TOWN1` 을 가리키는 장소가 **4개**이고 구역끼리 겹치지 않는다
- [ ] `TOWN2` 대응 장소가 **없다** (부록 G-2)
- [ ] `enemies.index.json` 이 `count: 75` · `summonableCount: 74` 이고 id 0 이 `summonable: false` 다
- [ ] 콘텐츠에서 id 0 을 참조하면 **빌드 하드 실패**한다
- [ ] 인카운터의 적 수가 3을 넘으면 빌드 실패한다
- [ ] `enter_place` 가 실제로 발행된다 (주점 구역에 들어가면 이벤트가 나온다 — 플레이로 확인)
- [ ] `WorldState.visited` 가 채워지고 Condition `visited` 가 참이 된다
- [ ] **테스트 1**: `hadar2026_app/test/application/content/place_binding_test.dart` —
      `TOWN1` 좌표를 넣으면 올바른 장소가 나오고, 컨테이너와 구역이 중첩된 좌표에서 **구역이 우선**한다.
      페이크 `AssetSource` 로 places JSON 을 인메모리 제공한다
      (선례: `test/application/map_navigation_test.dart:13-28`)
- [ ] **테스트 2**: `hadar2026_app/test/domain/battle/enemy_index_test.dart` —
      **부록 B-1 회귀** — `enemyTable.length == 75` 이고 `registerEnemy(0)` 이 적을 추가하지 않는다는
      두 명제를 고정한다. 테이블 크기가 바뀌면 이 테스트가 먼저 깨진다
- [ ] **테스트 3**: `tools/content_cli/test/place_map_resolution_test.dart` —
      존재하지 않는 파일로 해석되는 `map` 값을 넣으면 검증이 **오류**를 낸다 (부록 D-1 의 역설 재발 방지)

## 하지 않을 것

- **`MapInfos.json` 7개 엔트리 수리 자체** — **P0-01**.
- `TOWN2` 맵 제작 — **P0-06** 이 도달 불가 코드를 정리한다.
- `enemy_data.dart` 를 JSON 으로 옮기는 것 — 안 B 기각. 밸런스는 콘텐츠가 아니라 시스템이다.
- 세계관 산문 설정집 작성 — 데이터가 목적이다(BP-22 §1.1).
- 지식 범위 위반 검사(L4) — **P1-12 범위 밖**. 스키마에 `knowledge` 를 넣되 검사는 P2.
- 세력 관계·톤 일관성 린트 — 같은 이유로 L4 이며 범위 밖.
- 다국어 — `ko` 만(D-17).
