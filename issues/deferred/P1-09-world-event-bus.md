# P1-09 월드 이벤트 버스 (12종 발행)

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-03 대기)
- **구간**: P1
- **규모**: M
- **선행**: P1-03
- **설계 근거**: [BP-23 §23.11](../../blueprint/23_quest_model.md)(**이름·payload 소유 장**) · [BP-25 §4.3](../../blueprint/25_world_state_and_save.md)(큐 처리 순서 EV-1~8 소유) · [BP-27 §7](../../blueprint/27_runtime_engine.md)(발행 지점 정본) · [D-20 · D-20a · D-26](../../blueprint/_meta/DECISIONS.md)

## 문제

**게임 안의 사건이 아무 곳에도 알려지지 않는다.** 상태 변화가 전부 지역적으로 처리되고 끝난다.

- 전투 결과는 `HDBattle` 안에만 남는다 — `hadar2026_app/lib/application/battle.dart:106,130,214,223,225` 가
  `_battleResult` 를 대입하고 `:32` 의 `result()` 로 **누가 물어보면** 답한다. 알림은 없다.
- 맵 전환은 `hadar2026_app/lib/application/game_session.dart:97-130` 안에서 끝난다.
  전환 사실을 관측할 수 있는 것은 `mapVersion` 증가로 리빌드되는 UI 뿐이다.
- 소지금 변화는 `hadar2026_app/lib/domain/party/party.dart:58-59` 의 세터가 조용히 바꾼다.
- 휴식은 `hadar2026_app/lib/application/menu_flows.dart:146` 의 `restHere()` 안에서 끝난다.
- 플래그·변수 변화는 `script_engine_adapter.dart:362-391` 이 배열을 직접 쓴다.

따라서 "슬라임 3마리를 잡아라" 같은 목표가 **자동으로 진행될 수 없다.**
P1-08 의 `QuestRuntime` 은 판정할 재료를 공급받지 못한다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** D-16-6 이 이것을 최소 집합에 넣은 이유가 그대로다 —
전투 승리·아이템 획득·입장이 목표를 자동 진행시키지 않으면, 저작자는 모든 목표를
"NPC 에게 다시 말을 걸어 확인" 형태로만 쓸 수 있다. 그러면 퀘스트가 전부 같은 모양이 된다.

MILESTONES §3 의 "전투 승리·아이템 획득이 **목표를 자동 진행**시킨다" 가 이 이슈의 직접 판정이다.

## 무엇을 할 것인가

**이벤트 이름 12종은 D-20 이 고정하고, payload 는 [BP-23 §23.11.1](../../blueprint/23_quest_model.md) 이 소유한다.
payload 필드를 이 이슈에 옮겨 적지 않는다** — D-20a·D-25 가 금지한 행위이고, 실제로 D-20 초판이
12행 중 9행을 잘못 옮겨 적어 사고가 났다.

**이름 12종** (payload 는 위 링크를 볼 것):
`talk` · `enter_place` · `step_tile` · `battle_won` · `item_gained` · `item_lost` ·
`flag_changed` · `var_changed` · `dialogue_choice` · `map_changed` · `gold_changed` · `party_rested`

1. `packages/hadar_content/lib/world_event.dart` — `WorldEvent` · `WorldEventType`(12값).
   이름은 **소문자 snake_case, 동사 과거형 금지**(`talk` 이지 `talked_to` 가 아니다).
2. `hadar2026_app/lib/application/content/world_event_bus.dart`
   - `WorldEventBus` · `WorldEventSubscriber`.
   - **배치 큐다.** 발행은 즉시 처리하지 않고 큐에 넣고, 드레인 시점에 순서대로 처리한다.
     큐 처리 순서 규약 EV-1~8 은 [BP-25 §4.3](../../blueprint/25_world_state_and_save.md) 소유.
   - 재진입·무한 루프 방지(지연 효과)는 [BP-25 §4.4](../../blueprint/25_world_state_and_save.md).
   - `WorldState.step` 은 **월드 이벤트를 하나 처리할 때마다 +1** 이다(D-08a). 증가 주체가 이 버스다.
3. **발행 지점 배선** — 정본은 [BP-27 §7](../../blueprint/27_runtime_engine.md) 이다. 접합점:

   | 이벤트 | 접합 파일:줄 | 비고 |
   |---|---|---|
   | `battle_won` | `application/battle.dart` `_battleResult` 확정 지점(`:106,214,223,225`) | 전투 결과 계약 재정의는 [BP-27 §7.1](../../blueprint/27_runtime_engine.md), 코드 수정은 **P0-12·P0-13** 선행 |
   | `map_changed` | `application/game_session.dart:97-130` | `currentMapName` 은 **로드 성공 확정 후에만** 갱신(D-22 · 부록 D-2) |
   | `talk` · `step_tile` | `application/tile_event_dispatcher.dart` 티어 0 (P1-11) | 티어 0 삽입 전에는 미발행 |
   | `dialogue_choice` | `application/content/dialogue_runtime.dart`(P1-07) | 선택 확정 시 |
   | `flag_changed` · `var_changed` | `WorldStateMutator` 구현체(P1-03) | 레거시 정수 경로(`script_engine_adapter.dart:362-391`)도 `legacyFlagMap` 을 통해 같은 발행에 도달 |
   | `gold_changed` | `domain/party/party.dart:58-59` 세터 | 세터가 `domain/` 이므로 발행은 `application/` 쪽 통로에서 한다 |
   | `party_rested` | `application/menu_flows.dart:146` `restHere()` | |
   | `item_gained` · `item_lost` | `application/content/` 의 `giveItem`/`takeItem`(P1-05) | **P1-05 전까지 미발행** |
   | `enter_place` | places 바인딩 조회(P1-15) | **P1-15 전까지 미발행** |

4. **미발행 이벤트를 명시한다**(D-20).
   `item_gained`·`item_lost`·`enter_place` 3종은 **P1-05·P1-15 가 완료되기 전까지 발행 지점이 존재하지 않는다.**
   이 사실을 `world_event.dart` 의 doc comment 와 `WorldEventType` 열거 주석에 적고,
   "덮는다" 는 서술을 어디에도 쓰지 않는다. 발행 지점이 생긴 뒤에만 참이 되는 문장이다.
   빌드가 **이벤트 → 발행 지점 레지스트리**를 만드는 것은 D-26 이 요구하지만
   레지스트리 **생성**은 P1-12, 그것을 솔버가 소비하는 것은 P2 다.

## 완료 판정 기준

- [ ] `WorldEventType` 이 **정확히 12값**이고 이름이 D-20 목록과 문자 단위로 일치한다
- [ ] `battle_won` 이 전투 종료 시 1회 발행되고, 전투를 하지 않으면 발행되지 않는다 (부록 F-3 회귀)
- [ ] 이벤트 처리 1건마다 `WorldState.step` 이 정확히 1 증가한다
- [ ] 같은 상호작용 안에서 발행된 이벤트들이 **한 배치로** 드레인된다 (개별 즉시 처리가 아니다)
- [ ] 지연 효과가 재귀 발행을 만들어도 무한 루프가 나지 않는다 ([BP-25 §4.4](../../blueprint/25_world_state_and_save.md) 상한이 동작)
- [ ] `item_gained`/`item_lost`/`enter_place` 가 **미발행임이 코드 주석에 명시**되어 있고, P1-05·P1-15 완료 후 발행으로 바뀐다
- [ ] **테스트 1**: `hadar2026_app/test/application/content/world_event_bus_test.dart` —
      배치 드레인 순서(EV-1~8), `step` 증가량, 재진입 상한을 고정.
      페이크 바인딩은 `test/application/map_navigation_test.dart:13-28` 패턴
- [ ] **테스트 2**: `packages/hadar_content/test/world_event_test.dart` —
      12종 이름 집합을 **문자열 리터럴로** 고정한다. 이름이 바뀌면 이 테스트가 먼저 깨진다
      (`test/domain/map/tile_action_test.dart` 가 `scriptMode` 와이어 값을 고정하는 것과 같은 역할)

## 하지 않을 것

- **payload 필드를 이 이슈에서 정의하지 않는다** — [BP-23 §23.11.1](../../blueprint/23_quest_model.md) 소유(D-25).
- 전투 결과 코드 수정 — **P0-12 · P0-13**.
- 티어 0 삽입 — **P1-11**.
- 이벤트 → 발행 지점 **레지스트리 생성** — P1-12. 솔버의 `SUPPORTED`/`UNSUPPORTED` 판정 — **P2**(D-26).
- 새 이벤트 추가 — `schemaVersion` 승격을 요구하므로 P1 에서 하지 않는다.
- 시간대(`time_of_day`) 관련 이벤트 — 게임에 시간대가 없다.
