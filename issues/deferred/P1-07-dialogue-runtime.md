# P1-07 대화 그래프 모델과 런타임 (조건부 대사)

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-02 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-02
- **설계 근거**: [BP-24](../../blueprint/24_dialogue_model.md)(**소유 장** — 스키마 · **텍스트 길이 수치** · `UiHost` 출력 호출 순서) · [D-07 · D-16-3](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` 부록 A-3 · E-2

## 문제

**같은 NPC 가 상태에 따라 다른 말을 하는 것이 세 티어 전부에서 불가능하다.**

- **JSON 티어** — 좌표당 이벤트 1개, 무조건 출력.
  ```dart
  // hadar2026_app/lib/application/tile_event_dispatcher.dart:166-178
  for (final ev in map.events) {
    if (ev.x == x && ev.y == y) {
      for (final line in ev.dialogLines) {
        if (line.isNotEmpty) { await host.addLog(line); }
      }
      return;   // ← 좌표 일치하는 첫 이벤트만, 조건 없음
    }
  }
  ```
- **네이티브 티어** — 조건 분기가 한 번도 동작한 적이 없다.
  `hadar2026_app/lib/application/scripting/map_script.dart:41-48` 의 `isFlagSet` 이 `return false;` 스텁(부록 A-3).
- **cm2 티어** — `if (Flag::IsSet(n))` 은 되지만 정수 인덱스이고, 미등록 함수가 **0을 반환**해 조용히 오분기하며
  (GROUND_TRUTH §9), 맵 전환마다 엔진 전역이 날아간다(`game_session.dart:101-108`).

또한 레거시 이관 시 함정이 하나 있다: RPG Maker MV 는 조건을 만족하는 `pages` 중 **번호가 가장 큰 것**을 고르는데,
본 기획의 `Dialogue.entry[]` 는 **위에서부터 첫 번째 참**을 고른다(부록 E-2). 변환 시 순서를 뒤집어야 한다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 퀘스트의 최소 형태가 "말을 걸어 수주 → 다시 말을 걸어 완료" 이고,
그 둘이 **같은 좌표의 같은 NPC** 다. 조건부 첫마디가 없으면 수주 전과 후를 구별할 수 없어
심부름 퀘스트 하나조차 손으로 표현할 수 없다(D-16-3 이 이것을 최소 집합에 넣은 이유).

MILESTONES §3 의 P1 완료 기준 중 "같은 NPC 가 **상태에 따라 다른 말**을 한다" 가 이 이슈의 직접 판정이다.

## 무엇을 할 것인가

**스키마·길이 상한·출력 호출 순서는 [BP-24](../../blueprint/24_dialogue_model.md) 가 소유한다. 재서술하지 않고 링크한다.**
텍스트 길이 제약(페이지 예산 공식, 확정 상한)은 [BP-24 §24.5](../../blueprint/24_dialogue_model.md) 를 볼 것.

1. `packages/hadar_content/lib/dialogue.dart` · `node.dart` · `choice.dart`
   - `Dialogue`(`entry[]` + `nodes`) · `DialogueNode`(`lines`/`header`/`onEnter`/`choices`/`next`) · `Choice`.
   - `entry` 해석: **위에서부터 첫 `when` 참**([BP-24 §24.3.1](../../blueprint/24_dialogue_model.md)).
     `Condition` 평가는 P1-02 의 `ConditionEvaluator` 를 쓴다 — 대화용 평가기를 따로 만들지 않는다.
   - 사이클은 **조건부로 허용**된다([BP-24 §24.8.3](../../blueprint/24_dialogue_model.md)). 최대 깊이 상한은 §24.8.4.
2. `hadar2026_app/lib/application/content/dialogue_runtime.dart`
   - `DialogueRuntime` · `DialogueResult` · `DialogueTrace`.
   - **`UiHost` 호출 순서를 반드시 지킨다** — 정본은 [BP-24 §24.4.2·§24.4.4](../../blueprint/24_dialogue_model.md):
     `beginNarrative()` → `clearLogs()` → `setHeader()` → `addLog()`(줄 단위) → `waitForAnyKey()` → `endNarrative()`.
     시그니처는 `hadar2026_app/lib/application/ports/ui_host.dart:44,48,54,63,70,81` 에 이미 있다 — **신규 포트 메서드는 없다.**
   - 선택지는 **`showMenu` 를 쓴다**([BP-24 §24.4.3](../../blueprint/24_dialogue_model.md)).
     `showWindowMenu` 도 `showMessageWindow` 도 쓰지 않는다(§24.4.5 가 이유를 적었다).
   - `onEnter` 효과와 텍스트 출력의 순서는 §24.7.1, 선택지 효과의 원자성은 §24.7.2.
   - 파괴적 효과(`warp`/`start_battle`/`play_dialogue`)는 §24.7.3 — 즉시 실행하지 않고 **지연 목록**으로 넘긴다
     (실행은 P1-11 의 `HDEffectBridge`). `play_dialogue` 는 서브루틴이 아니라 **꼬리 호출**이다(§24.7.4).
   - 재방문 정책(`once` 노드, `repeatPool`)은 §24.9. 1회성 기록은 플래그가 아니라
     `WorldState.dialogueMemory` 에 쓴다([BP-25 §2.6](../../blueprint/25_world_state_and_save.md)).
   - 대화 도중 세이브 로드로 인한 중단은 `GameReloadException` 을 그대로 통과시킨다(기존 계약).
3. **레거시 변환은 데이터 작업이 아니라 규칙만** 이 이슈에 둔다.
   `map.events[].dialogLines`(code 401) → 단일 노드 대화 변환 규칙은
   [BP-24 §24.10.1](../../blueprint/24_dialogue_model.md). **다중 페이지가 있으면 순서를 뒤집는다**(부록 E-2).
   현재 레포의 모든 이벤트는 `pages` 가 1개라 당장 차이는 없지만 변환기에 그 규칙을 넣어 둔다.
4. `assets/content/core/strings/ko.json` — 대사는 **인라인 금지**, 문자열 키로만 참조한다
   ([BP-21 §5.1](../../blueprint/21_content_pack_spec.md)). `packages/hadar_content/lib/strings.dart` 의 `StringTable` 이 해석한다.

## 완료 판정 기준

- [ ] **같은 좌표의 같은 NPC 가 플래그 상태에 따라 다른 첫마디를 한다** (플레이로 확인)
- [ ] 선택지가 `showMenu` 로 뜨고, `when` 이 거짓인 선택지는 목록에 나타나지 않는다
- [ ] 노드 1개 출력의 `UiHost` 호출 순서가 [BP-24 §24.4.2](../../blueprint/24_dialogue_model.md) 와 정확히 일치한다
- [ ] `once` 노드가 두 번째 방문에 나오지 않고, 그 기록이 `WorldState.dialogueMemory` 에 있다 (플래그 공간을 오염시키지 않는다)
- [ ] `play_dialogue` 체인이 4단계를 넘으면 절단되고 경고 로그가 남는다
- [ ] 대화 중 `warp` 를 만나면 즉시 이동하지 않고 대화가 끝난 뒤 이동한다
- [ ] **테스트 1**: `hadar2026_app/test/application/content/dialogue_runtime_test.dart` —
      **`UiHost` 호출 순서를 문자열 로그로 기록하는 페이크 `UiHost`** 로 §24.4.2 순서를 고정한다.
      `HDHosts().bind(...)` + `tearDown` 의 `reset()` 패턴은 `test/application/map_navigation_test.dart:13-28` 을 따른다
- [ ] **테스트 2**: `packages/hadar_content/test/dialogue_entry_test.dart` —
      `entry[]` 가 **위에서부터 첫 참**을 고른다는 명제와, MV 역순 규칙(부록 E-2)이 변환기에서 뒤집힌다는 것을 함께 고정
- [ ] **테스트 3**: `packages/hadar_content/test/dialogue_graph_test.dart` —
      도달 불가 노드·종료 불가 사이클을 검출한다 (P1-12 의 L3 가 이 함수를 재사용)

## 하지 않을 것

- **텍스트 길이 수치를 이 이슈에서 정하지 않는다** — [BP-24 §24.5](../../blueprint/24_dialogue_model.md) 소유. 런타임은 상한을 강제만 한다.
- 얼굴 그림·음성·연출 — 없다(부록 E-1: `code 101` 은 텍스트 헤더가 아니다).
- 기존 cm2 대화의 **전면 재작성** — D-17. 공존이 전략이다.
- 다국어 — 구조만 열어두고 `ko` 만 구현(D-17).
- 디스패처에 티어 0 을 삽입하는 것 — **P1-11**.
- 대화 그래프 편집 UI·그래프 PNG — **P2**.
