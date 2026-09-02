# P0-12 전투 결과 코드가 cm2 상수와 정반대다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 B-2](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-27 런타임 실행 경로 소유](../../blueprint/27_runtime_engine.md) · [BP-23 `battle_won` 이벤트](../../blueprint/23_quest_model.md)

## 문제

Dart 쪽 — `hadar2026_app/lib/application/battle.dart:27`:

```dart
int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away
```

cm2 쪽 — `hadar2026_app/assets/const.cm2:53-55` (본인 확인, 선언은 `:49-51`):

```
BATTLERESULT_EVADE.assign(0)
BATTLERESULT_WIN.assign(1)
BATTLERESULT_LOSE.assign(2)
```

| 값 | Dart 의미 | cm2 상수 의미 | 일치 |
|---|---|---|---|
| 0 | Lose (`battle.dart:214,223`) | EVADE(도주) | **불일치** |
| 1 | Win (`:106,225`) | WIN | 일치 |
| 2 | Run away (`:130`) | LOSE(패배) | **불일치** |

Dart 쪽 대입 지점 전량(본인 확인): `:27`(초기값) `:38`(`init`) `:106`(`start` 진입)
`:130`(도주 성공 → 2) `:214`·`:223`(전멸 → 0) `:225`(적 전멸 → 1).
읽는 쪽은 `:32` 의 `int result() => _battleResult;` 이고, 이것이
`script_engine_adapter.dart:543` 에서 cm2 함수로 노출된다:

```dart
e.registerFunction('Battle::Result', (_, __) => HDBattle().result());
```

cm2 에서 실제로 분기하는 곳(본인 확인): `assets/lore_ep1.cm2:355`, `assets/town1.cm2:57`,
`assets/town2.cm2:355`, `assets/L1_ep1d0.cm2:354`, `:424` — **5곳**.
이들은 `temp.assign(Battle::Result())` 후 `BATTLERESULT_*` 상수와 비교하므로
**패배와 도주를 뒤바꿔 처리한다.** 즉 파티가 전멸했는데 "도주했다" 분기를 타거나 그 반대다.

## 왜 지금 고쳐야 하는가

- [P0-13](P0-13-battle-result-defaults-win.md)(전투 없이도 승리 반환)의 **선행**이다. 두 이슈가 같은 필드의 계약을 다루므로
  의미를 먼저 정하지 않으면 [P0-13](P0-13-battle-result-defaults-win.md) 의 "미실행 상태" 값을 정할 수 없다.
- [BP-23](../../blueprint/23_quest_model.md) 의 월드 이벤트 12종에 `battle_won` 이 있다. 그 발행 조건이 이 값에 달려 있다.
- 부록 B-2 가 "**어느 쪽을 정본으로 삼을지 먼저 정해야 한다**([BP-27](../../blueprint/27_runtime_engine.md) 결정 사항)" 를 명시했다.
  그 결정을 이 이슈에서 내린다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 | 장점 | 단점 |
|---|---|---|---|---|
| A | **cm2 를 정본으로 삼고 Dart 를 맞춘다** (0=EVADE, 1=WIN, 2=LOSE) | `battle.dart` 의 대입 6곳 + 분기 3곳(`:194,224,240,265,269`) | 기존 cm2 콘텐츠 5곳이 **고치지 않아도 옳아진다**. `assets/const.cm2` 는 원작 계보의 정본 | Dart 쪽 리터럴을 전수 수정해야 한다. 세이브에 이 값이 들어가지 않는지 확인 필요 |
| B | Dart 를 정본으로 삼고 `const.cm2` 를 맞춘다 | `assets/const.cm2:53-55` 3줄 | 변경량이 가장 작다 | 원작 상수 정의를 바꾸는 것이므로 원작 스크립트 이관 시 다시 뒤집힌다. cm2 파일들의 주석과 어긋난다 |
| C | 명명 enum 을 도입해 양쪽이 그것을 참조 | `domain/battle/` 신규 enum + 어댑터 | 정수 혼동이 구조적으로 사라진다 | **P0 범위 초과에 가깝다.** 다만 와이어 값 고정은 `HDTileAction.scriptMode` 의 선례가 있어 자연스럽다 |

### 권고안: **A + C 의 최소 형태**

1. `domain/battle/` 에 와이어 값을 명시한 enum 을 만든다. `HDTileAction.scriptMode` 와 **같은 방식** —
   값은 명시적으로 선언하고 `Enum.index` 를 쓰지 않는다.

   ```dart
   /// Wire values shared with cm2 `assets/const.cm2:53-55`
   /// (BATTLERESULT_EVADE=0, WIN=1, LOSE=2). Never use Enum.index.
   enum HDBattleResult {
     evade(0),
     win(1),
     lose(2);
     const HDBattleResult(this.wire);
     final int wire;
   }
   ```

2. `battle.dart` 의 `_battleResult` 를 `HDBattleResult` 로 바꾸고, `result()` 는 `.wire` 를 반환한다.
   대입 지점을 의미로 치환한다:

   ```diff
   - _battleResult = 2; // Run away
   + _battleResult = HDBattleResult.evade;   // wire 0 — cm2 BATTLERESULT_EVADE
   ...
   - _battleResult = 0; // Lose
   + _battleResult = HDBattleResult.lose;    // wire 2 — cm2 BATTLERESULT_LOSE
   ```

3. `:240,265,269` 의 `gotoEndBattle` 분기와 `:194,224` 의 `!= 2` 비교를 enum 비교로 바꾼다.
   `switch` 로 만들면 값 추가 시 컴파일 에러로 드러난다.
4. `assets/const.cm2` 는 **수정하지 않는다.**

## 완료 판정 기준

- [ ] 파티 전멸로 전투가 끝난 뒤 `HDBattle().result()` 가 **2** 다 (cm2 `BATTLERESULT_LOSE`)
- [ ] 도주 성공으로 끝난 뒤 `result()` 가 **0** 이다 (cm2 `BATTLERESULT_EVADE`)
- [ ] 승리 시 `result()` 가 **1** 이다 (변화 없음)
- [ ] `assets/const.cm2` 가 수정되지 않았다 (git diff 로 확인)
- [ ] `battle.dart` 에 `_battleResult` 와 정수 리터럴을 직접 비교하는 코드가 없다
- [ ] 테스트 추가: `hadar2026_app/test/domain/battle/battle_result_test.dart` —
      `HDBattleResult.{evade,win,lose}.wire` 가 `{0,1,2}` 임을 고정한다.
      `test/domain/map/tile_action_test.dart` 가 `scriptMode` 를 고정하는 것과 같은 역할이며,
      테스트 주석에 `assets/const.cm2:53-55` 를 정본으로 명시한다

## 하지 않을 것

- cm2 콘텐츠 스크립트 5곳(`lore_ep1.cm2:355` 등)의 수정 — 이 안은 그것들이 **옳아지게** 만드는 것이다.
- `assets/const.cm2` 수정.
- `battle_won` 월드 이벤트 발행 — [BP-23](../../blueprint/23_quest_model.md) 소유, [P1-09](../deferred/P1-09-world-event-bus.md) 소관.
- 전투 결과를 세이브에 넣기.
- 전투 흐름·밸런스 변경. 어느 조건에서 어떤 결과가 되는지의 규칙은 그대로 둔다.
- `Battle::Result()` 의 미실행 기본값 문제 — [P0-13](P0-13-battle-result-defaults-win.md) 소관.
