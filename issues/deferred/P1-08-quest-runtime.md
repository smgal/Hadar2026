# P1-08 퀘스트 모델·런타임·저널 상태

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-02 · P1-03 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-02 · P1-03
- **설계 근거**: [BP-23](../../blueprint/23_quest_model.md)(**소유 장** — Quest/Stage/Objective 스키마 · 보상 티어표 · 이벤트→목표 매핑) · [D-06](../../blueprint/_meta/DECISIONS.md) · [BP-27 §6](../../blueprint/27_runtime_engine.md)

## 문제

**퀘스트가 코드에도 데이터에도 존재하지 않는다.**
`grep -rn quest hadar2026_app/lib` 결과가 **0건**이다. 목표·단계·저널·보상이라는 개념 자체가 없다.

지금 무엇이 대신 쓰이고 있는가:
- 진행 표시는 콘솔 로그뿐이다 — `hadar2026_app/lib/application/tile_event_dispatcher.dart:75-80` 처럼
  `host.addLog(..., isDialogue: false)` 로 흘려보내고, `HDConfig.maxProgressLines` 200줄이 지나면 사라진다.
- "무엇을 해야 하는가" 를 플레이어가 알 방법은 **직전 대사를 기억하는 것뿐**이다.
- 목표 자동 진행의 재료인 전투 결과조차 계약이 깨져 있다 —
  `hadar2026_app/lib/application/battle.dart:27` 의 `int _battleResult = 1; // 1: Win` 이
  `hadar2026_app/assets/const.cm2:53-55` 의 `BATTLERESULT_EVADE=0/WIN=1/LOSE=2` 와 0·2 에서 어긋난다(부록 B-2).
  게다가 `init()`(`:38`)이 `_battleResult = 1` 로 되돌리므로 **전투를 하지 않아도 승리를 반환한다**(부록 F-3).

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** MILESTONES §3 의 P1 완료 기준 5개 중 3개가 이 이슈에 직접 걸려 있다 —
"퀘스트 저널에서 진행 중 목표를 볼 수 있다"(상태 쪽), "전투 승리·아이템 획득이 목표를 자동 진행시킨다",
그리고 "손으로 만든 퀘스트 1개가 완주 가능하다"(P1-16).

퀘스트 상태 기계가 없으면 저작자는 플래그 조합으로 진행을 직접 관리해야 한다 —
그것은 정확히 cm2 로 이미 시도해 실패한 방식이고(GROUND_TRUTH §8·§9), 실패 양식이 침묵이라 디버깅이 불가능하다.

## 무엇을 할 것인가

**스키마와 매핑표는 [BP-23](../../blueprint/23_quest_model.md) 소유다. 필드 표·kind 명세·보상 티어표를 재서술하지 않는다.**

1. `packages/hadar_content/lib/quest.dart` · `stage.dart` · `objective.dart`
   - `Quest` · `Stage` · `Objective` 역직렬화 + `QuestState`(`inactive`/`active`/`completed`/`failed`) ·
     `ObjectiveKind`(**9종** — [BP-23 §23.4.3](../../blueprint/23_quest_model.md)).
   - `next` 3형태(단일 stageId · `"complete"` · `[{when, go}]`)와 `completion`(`all`/`any`) —
     [BP-23 §23.3.2·§23.3.3](../../blueprint/23_quest_model.md).
   - **그래프 제약**: 스테이지 DAG, 사이클 금지, 고립 objective 검출.
     검사 알고리즘은 [BP-23 §23.6.2·§23.6.3](../../blueprint/23_quest_model.md) 의 의사코드를 Dart 로 옮기고,
     **P1-12 의 L3 가 같은 함수를 재사용**하도록 순수 함수로 둔다.
2. `hadar2026_app/lib/application/content/quest_runtime.dart`
   - `QuestRuntime` — 이벤트 → 목표 매칭 → 카운터 갱신 → 스테이지 전이 → 효과 → 저널.
   - **완료 판정은 배치 단위다** — "한 상호작용 = 한 배치"([BP-23 §23.4.5](../../blueprint/23_quest_model.md)).
     이벤트마다 즉시 판정하지 않는다. 이 규약이 P1-02 의 "같은 step 안에서 `chance` 가 흔들리지 않는다" 와 맞물린다.
   - **완료 래치**([BP-23 §23.4.6](../../blueprint/23_quest_model.md)) — 이미 충족된 목표가 되돌려지지 않게 한다.
   - 상태 전이표와 **불법 전이 거부**는 [BP-23 §23.5.2·§23.5.3](../../blueprint/23_quest_model.md).
     불법 전이는 **거부하고 로그를 남긴다** — 조용히 무시하지 않는다.
   - `failConditions` 재평가 시점은 [BP-23 §23.8.2](../../blueprint/23_quest_model.md), `timeoutSteps` 는 §23.8.4
     (벽시계가 아니라 `WorldState.step` 기준 — D-08a).
   - `defeat` 카운터의 증가량 규칙은 [BP-27 §6.2](../../blueprint/27_runtime_engine.md).
3. **저널 상태** — `WorldState.journal`(P1-03 이 만든 링 버퍼)에 항목을 넣는다.
   목표 문구 자동 생성(label 생략 시)은 [BP-23 §23.10.3](../../blueprint/23_quest_model.md) 템플릿.
   진행 알림은 콘솔 progress 레인([BP-23 §23.10.5](../../blueprint/23_quest_model.md)).
   **화면 스펙은 P1-13 이고 이 이슈는 상태와 문구 생성까지다.**
4. **전투 결과 계약** — 목표 `defeat` 를 판정하려면 `battle_won` 이 신뢰 가능해야 한다.
   정본 재정의는 [BP-27 §7.1](../../blueprint/27_runtime_engine.md) 이고, 코드 수정 자체는
   **P0-12(0/2 역전)·P0-13(무전투 승리)** 가 담당한다. 이 이슈는 그 결과를 **소비**하고,
   `battle.dart` 종료 지점에서 `battle_won` 을 발행하는 배선만 P1-09 와 함께 놓는다.
5. `assets/content/core/quests/` 디렉토리와 `pack.json` 의 `entryPoints` 배선
   ([BP-21 §3.3](../../blueprint/21_content_pack_spec.md)).

## 완료 판정 기준

- [ ] `start_quest` → `advance_quest` → `complete_quest` 가 `WorldState.quests` 에 반영되고 세이브를 넘긴다 (P1-04 와 함께)
- [ ] 목표 9종 kind 전량이 파싱되고, 각각 대응 월드 이벤트로 진행한다
      ([BP-23 §23.11.2](../../blueprint/23_quest_model.md) 매핑표의 모든 행이 코드에 존재)
- [ ] 스테이지 사이클이 있는 퀘스트 JSON 을 넣으면 **로드 시점에 예외**가 난다 (조용히 통과하지 않는다)
- [ ] 역행 전이(`advance_quest` 로 앞 스테이지 지정)가 거부되고 로그가 남는다
- [ ] 이미 완료한 목표가 카운터 감소로 되돌려지지 않는다 (완료 래치)
- [ ] `timeoutSteps` 가 `WorldState.step` 만으로 판정된다 (벽시계 참조 0건)
- [ ] **테스트 1**: `hadar2026_app/test/application/content/quest_runtime_test.dart` —
      이벤트 시퀀스를 주입해 스테이지 전이·카운터·완료 래치·불법 전이 거부를 고정.
      페이크 바인딩은 `test/application/map_navigation_test.dart:13-28` 패턴
- [ ] **테스트 2**: `packages/hadar_content/test/quest_graph_test.dart` —
      사이클 검출·고립 objective 검출·`next` 3형태 파싱을 고정. **P1-12 의 L3 가 이 함수를 호출한다**
- [ ] **테스트 3**: `hadar2026_app/test/application/content/quest_batch_test.dart` —
      "한 상호작용 = 한 배치" 규약. 한 번의 상호작용에서 이벤트 3개가 나면 판정이 **1회**만 돈다는 것을 고정

## 하지 않을 것

- **저널 UI(화면·키 조작·추적 바)** — **P1-13**.
- 월드 이벤트 **버스 구현** — **P1-09**. 이 이슈는 버스의 구독자다.
- 전투 결과 코드 수정 — **P0-12 · P0-13**.
- 동시 진행 상한·상호 배타(`mutex`)·자동 실패 전파 — [BP-23 §23.7](../../blueprint/23_quest_model.md) 의 이 기능들은
  P1 에서 **스키마만 파싱**하고 런타임 강제는 P1-16 이 필요를 증명한 뒤로 미룬다.
- 퀘스트 솔버·완주 증명·2축 판정 — **P2**(D-26).
- 보상 밸런스 린트(`QV-31`~`QV-36`) — P1-12 의 L4 는 범위 밖이다. P1 은 L1~L3 만.
