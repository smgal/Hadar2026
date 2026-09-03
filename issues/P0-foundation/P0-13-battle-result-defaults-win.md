# P0-13 `Battle::Result()` 가 전투 없이도 승리를 반환한다

- **상태**: DONE
- **구간**: P0
- **규모**: S
- **선행**: P0-12
- **설계 근거**: [`GROUND_TRUTH` 부록 F-3 · B-2](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-27 런타임 실행 경로](../../blueprint/27_runtime_engine.md)

## 문제

`hadar2026_app/lib/application/battle.dart:27` — 초기값이 승리다:

```dart
int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away
```

`init()` 도 승리로 되돌린다 (`:34-41`):

```dart
void init() {
  enemies.clear();
  playerCommands.clear();
  isBattleActive = false;
  _battleResult = 1;       // ← :38
  selectedEnemyIndex = -1;
  notifyListeners();
}
```

`start()` 진입에서도 다시 1 이다 (`:106`).

`init()` 이 불리는 곳은 cm2 커맨드 `Battle::Init`(`script_engine_adapter.dart:333`)과
**맵 전환**(`game_session.dart:95` — `HDBattle().init()`)이다.

**즉 cm2 스크립트가 `Battle::Start` 없이 `Battle::Result()` 를 읽으면 항상 승리다.**
`Battle::Init` → `Battle::RegisterEnemy` 만 하고 `Battle::Start` 를 빠뜨린 스크립트,
또는 맵에 들어와 아무 전투도 하지 않은 상태에서 결과를 읽는 스크립트가 모두 승리 분기를 탄다.

[P0-12](P0-12-battle-result-inverted.md)(값 의미가 cm2 와 정반대)와 합쳐 **전투 결과 계약 전체가 신뢰 불가**다.
실제 cm2 분기 지점 5곳(`assets/lore_ep1.cm2:355`, `town1.cm2:57`, `town2.cm2:355`,
`L1_ep1d0.cm2:354`·`:424`)이 모두 이 값을 읽는다.

## 왜 지금 고쳐야 하는가

- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 6번(범위 밖 인자가 침묵하지 않는다)과 같은 계열의
  **침묵 실패**다. 다만 여기서는 "값이 없는데 있는 척한다" 는 형태다.
- [P0-12](P0-12-battle-result-inverted.md) 가 값의 **의미**를 확정한다. 이 이슈는 그 위에 **"아직 값이 없다" 라는 상태**를 추가한다.
  순서가 뒤바뀌면 미실행 상태에 어떤 정수를 줄지 정할 수 없다.
- [BP-23](../../blueprint/23_quest_model.md) 의 `battle_won` 이벤트가 "전투를 해서 이겼다" 를 의미해야 한다.
  "전투를 안 해서 기본값이 승리" 가 이벤트를 발행하면 퀘스트 목표가 공짜로 달성된다.

## 무엇을 할 것인가

[P0-12](P0-12-battle-result-inverted.md) 가 도입한 `HDBattleResult` enum 에 **미실행 상태를 추가**한다.

```diff
  enum HDBattleResult {
+   /// No battle has run since the last init. cm2 `Battle::Result()`
+   /// returns this wire value; content must treat it as "no result",
+   /// never as a win (부록 F-3).
+   none(-1),
    evade(0),
    win(1),
    lose(2);
```

`battle.dart`:

```diff
- int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away
+ HDBattleResult _battleResult = HDBattleResult.none;
...
  void init() {
    ...
-   _battleResult = 1;
+   _battleResult = HDBattleResult.none;
```

- `start()` 진입(`:106`)의 `_battleResult = 1` 도 `HDBattleResult.none` 으로 바꾼다 —
  전투가 시작되었을 뿐 아직 결과가 없다. 종료 정산(`:222-226`)이 값을 확정한다.
- `:222-226` 의 정산 로직을 확인해 **모든 종료 경로가 `none` 이 아닌 값을 세우는지** 점검한다.
  세우지 못하는 경로가 있으면 그것이 진짜 버그다.
- `gotoEndBattle`(`:236-`)의 분기는 `none` 케이스를 **명시적으로 처리**한다 —
  `switch` 로 만들어 누락이 컴파일 에러가 되게 한다.

### 와이어 값 `-1` 을 고른 이유

| 후보 | 문제 |
|---|---|
| `-1` | cm2 의 `BATTLERESULT_*`(0·1·2) 와 겹치지 않는다. **권고** |
| `3` | 겹치지 않지만 "다음 결과 종류" 로 오인될 수 있다 |
| `0` (EVADE 재사용) | 전투를 안 한 것과 도주한 것이 구별되지 않는다 |

cm2 쪽 상수 추가는 하지 않는다 — `assets/const.cm2` 는 원작 정본이므로 건드리지 않고,
콘텐츠가 `-1` 을 명시적으로 다뤄야 하는 상황은 [P1](../MILESTONES.md) 의 조건 DSL 에서 이름으로 표현한다.

## 완료 판정 기준

- [x] `HDBattle().init()` 직후 `HDBattle().result()` 가 **`-1`** 이다 (승리가 아니다)
- [x] 맵을 전환한 직후(`game_session.dart:95` 의 `init()` 경유) `result()` 가 `-1` 이다
- [x] `Battle::Start` 를 거쳐 승리하면 `result()` 가 `1`, 패배는 `2`, 도주는 `0` 이다
      ([P0-12](P0-12-battle-result-inverted.md) 의 계약 유지)
- [x] `battle.dart` 의 결과 분기가 `switch (HDBattleResult)` 로 되어 있어 `none` 누락이 컴파일 에러다
- [x] 테스트 추가: `hadar2026_app/test/domain/battle/battle_result_test.dart` (P0-12 와 같은 파일) —
      `HDBattleResult.none.wire == -1` 및 나머지 3개 값을 고정하고,
      `HDBattle().init()` 직후 `result() == -1` 임을 고정한다

## 하지 않을 것

- `assets/const.cm2` 에 `BATTLERESULT_NONE` 추가.
- cm2 콘텐츠 스크립트 5곳의 수정 — 이들은 `-1` 을 어느 상수와도 매칭하지 못해
  **기존 분기 중 어느 것도 타지 않는다.** 그것이 "결과 없음" 의 올바른 표현이다.
- 전투 흐름·밸런스 변경.
- `battle_won` 월드 이벤트 발행 — [P1-09](../deferred/P1-09-world-event-bus.md) 소관.
- 값 의미 매핑 자체 — [P0-12](P0-12-battle-result-inverted.md) 소관 (선행).

## 구현 기록 (2026-09-03)

[P0-12](P0-12-battle-result-inverted.md) 와 같은 커밋에서 처리했다 — 같은 필드의 계약이다.

- `HDBattleResult.none` 와이어 **-1**. cm2 의 `BATTLERESULT_*`(0·1·2)와 겹치지 않는다.
- `init()`(맵 전환마다 호출됨)과 `start()` 진입이 모두 `none` 으로 초기화한다.
- 종료 정산(`start()` 말미)이 모든 경로에서 `lose`/`win`/`evade` 중 하나를 세우는 것을 확인했다.
  세우지 못한 채 `gotoEndBattle` 에 도달하면 **경고 로그**를 남긴다 — 예전처럼 조용히 승리로 처리하지 않는다.
- `gotoEndBattle` 이 `switch` 라 `none` 케이스 누락이 컴파일 에러다.
- `assets/const.cm2` 에 `BATTLERESULT_NONE` 을 **추가하지 않았다** — 콘텐츠가 어느 분기도 타지 않는 것이
  "결과 없음" 의 올바른 표현이다.

- 테스트: `test/domain/battle/battle_result_test.dart` — `none.wire == -1`, `init()` 직후 `result() == -1`
- `GROUND_TRUTH` 부록 F-3 을 **[해소됨]** 으로 갱신
