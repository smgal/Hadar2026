# P0-18 상호작용 진입점 3개 중 bump 경로만 게이트가 있어 비대칭이다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 K-2 · K-1 · K-3 · B-3](../../blueprint/_meta/GROUND_TRUTH.md) · [D-27 앵커는 타일 비트에 의존하지 않는다](../../blueprint/_meta/DECISIONS.md) · [BP-27 `Q-27-10`](../../blueprint/27_runtime_engine.md)

## 문제

`HDGameMain().checkTileEvent(...)` 를 부르는 곳은 `hadar2026_app/lib/presentation/panels/player_sprite.dart` 에
**3개뿐**이고(본인 확인: `grep -n "checkTileEvent"`), **타일 액션 선검사(게이트)의 유무가 서로 다르다.**

| 진입점 | 줄 | 호출 | presentation 게이트 |
|---|---|---|---|
| 이동 완료(step-on) | `:193` | `checkTileEvent(party.x, party.y, isInteraction: false)` | **없음** |
| 이동 차단 시 상호작용(bump) | `:362-366` | `checkTileEvent(nextX, nextY, isInteraction: true)` | **있음** |
| 확인키 상호작용 | `:405` | `checkTileEvent(targetX, targetY, isInteraction: true)` | **없음** |

bump 경로만 게이트를 갖는다 — `:355-371`:

```dart
if (map != null) {
  final action = HDTileProperties.getUnitAction(
    map.getUnit(nextX, nextY),
  );
  if (action.isInteractive) {          // ← :359  유일한 presentation 게이트
    if (_lastInteractedX != nextX || _lastInteractedY != nextY) {
      await HDGameMain().checkTileEvent(nextX, nextY, isInteraction: true);
      _lastInteractedX = nextX;
      _lastInteractedY = nextY;
    }
  }
}
```

확인키 경로(`:401-405`)와 step-on(`:193`)은 좌표를 계산해 **바로** 부른다 — 선검사가 없다.

**결과**: 같은 타일이 조작 방식에 따라 다르게 동작한다.
`isInteractive`(talk/sign/enter) 가 아닌 칸 — 예를 들어 평범한 `move` 칸 —
에 대해 **확인키로는 디스패처가 호출되고, 벽을 향해 걸어 부딪히는 방식으로는 호출되지 않는다.**

디스패처가 같은 검사를 자체적으로 하므로(`isScriptedAction = isInteraction ? action.isInteractive : action.isStepOn`)
지금 플레이어에게 보이는 차이는 없다. **문제는 게이트가 두 계층에 중복 존재한다는 것** —
`:359` 는 **presentation 이 콘텐츠 발화 여부를 결정하는 유일한 지점**이다.

## 왜 지금 고쳐야 하는가

- [D-27](../../blueprint/_meta/DECISIONS.md) 은 "앵커는 타일 비트에 의존하지 않는다" 를 확정했다.
  부록 K-1 이 확인한 대로 step-on(`:193`)과 확인키(`:405`)에서는 **코드 변경 없이 이미 성립**한다 —
  게이트가 없으므로 콘텐츠 티어가 `(map,x,y)` 로 트리거 인덱스를 직접 조회할 수 있다.
  **bump 경로만 그 전제를 깨뜨린다.**
- [P1-11](../deferred/P1-11-dispatcher-tier0.md)(디스패처 티어 0 삽입)이 이 지점에 의존한다.
  게이트를 남겨 두면 티어 0 이 "일부 조작 방식에서만" 동작한다.
- 부록 K-2 가 **"1줄 수준의 변경"** 이라고 판단했다. 비용이 거의 없다.
- 부록 K-3: `:193` 호출은 `await` 하지 않는 fire-and-forget 이고 재진입 가드(`_isScriptRunning`)가
  유일한 보호막이다. 게이트를 없애면 호출 빈도가 늘어나므로 **그 가드가 여전히 유효한지 확인해야 한다.**

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 | 장점 | 단점 |
|---|---|---|---|---|
| A | **`if (action.isInteractive)` 게이트 제거** — 확인키 경로와 같게 만든다 | `player_sprite.dart:355-371` | 3경로가 대칭이 된다. 게이트가 `application/` 한 곳(디스패처)에만 남는다 | bump 마다 디스패처 호출이 늘어난다. `_lastInteractedX/Y` 중복 방지는 유지해야 한다 |
| B | 확인키·step-on 경로에 **게이트를 추가**해 3경로를 대칭으로 | `player_sprite.dart` 2곳 | 호출 횟수가 준다 | **[D-27](../../blueprint/_meta/DECISIONS.md) 을 정면으로 깨뜨린다.** 앵커가 평범한 칸에서 발화할 수 없게 된다 |
| C | 게이트를 콘텐츠 조회 뒤로 옮긴다 | `player_sprite.dart` + 콘텐츠 티어 | D-27 을 지키면서 호출도 줄인다 | 콘텐츠 티어가 아직 없다 — [P1-11](../deferred/P1-11-dispatcher-tier0.md) 이후에만 가능 |

### 권고안: **A**

```diff
    if (map != null) {
-     final action = HDTileProperties.getUnitAction(
-       map.getUnit(nextX, nextY),
-     );
-     if (action.isInteractive) {
-       // Only trigger if we haven't interacted with THIS tile in THIS press session
-       if (_lastInteractedX != nextX || _lastInteractedY != nextY) {
-         await HDGameMain().checkTileEvent(nextX, nextY, isInteraction: true);
-         _lastInteractedX = nextX;
-         _lastInteractedY = nextY;
-       }
-     }
+     // No tile-action pre-check here: the dispatcher owns that decision
+     // (application/ tile_event_dispatcher.dart). Gating in presentation
+     // made the same tile behave differently for bump vs. confirm-key
+     // (부록 K-2) and blocks D-27's tile-bit-free anchors.
+     // The per-press dedup below stays — it is an input concern.
+     if (_lastInteractedX != nextX || _lastInteractedY != nextY) {
+       await HDGameMain().checkTileEvent(nextX, nextY, isInteraction: true);
+       _lastInteractedX = nextX;
+       _lastInteractedY = nextY;
+     }
    }
```

- `_lastInteractedX/Y` 는 **유지한다.** 부록 K-3 이 지적한 대로 이것은 "같은 누름 세션 안의 중복 상호작용" 을
  막는 **입력 관심사**이고, presentation 이 소유하는 것이 옳다.
- `HDTileProperties` 임포트가 미사용이 되면 정리한다.
- 재진입 가드 확인: 호출 빈도가 늘어나므로 `tile_event_dispatcher.dart` 의 `_isScriptRunning` 가드가
  bump 반복 입력에서도 유지되는지 실제로 눌러 확인한다.

## 완료 판정 기준

- [ ] `player_sprite.dart` 에 `HDTileProperties.getUnitAction` 을 **콘텐츠 발화 조건으로 쓰는 코드가 없다**
      (이동 가능 판정 등 다른 용도는 무관)
- [ ] 벽(BLOCK 타일)을 향해 걸어 부딪혀도 게임이 멈추거나 로그가 넘치지 않는다
      (디스패처가 `isScriptedAction == false` 로 걸러낸다)
- [ ] talk/sign/enter 타일에 부딪히면 **이전과 동일한 대사**가 나온다 (회귀 없음)
- [ ] 같은 방향키를 누른 채 유지해도 같은 칸에서 상호작용이 1회만 발생한다 (`_lastInteractedX/Y` 유지)
- [ ] `flutter analyze --no-fatal-infos` · `flutter test` 통과
- [ ] 테스트 추가 없음이 기본 — 이 코드는 `presentation/` 의 Bonfire 스프라이트 안이고 위젯 테스트가 없다(부록 §12).
      위 4항목의 수동 확인이 판정을 대신한다. 헤드리스 검증은 [P2-03](../deferred/P2-03-movement-loop-extraction.md) 이후 가능

## 하지 않을 것

- 이동·상호작용 루프를 `application/` 으로 추출 — [P2-03](../deferred/P2-03-movement-loop-extraction.md) 소관(부록 B-3).
- 디스패처 티어 0 삽입 — [P1-11](../deferred/P1-11-dispatcher-tier0.md) 소관.
- `:193` 의 fire-and-forget 을 `await` 로 바꾸기 (데드락 회피 이유가 주석에 있다, 부록 K-3) · `_lastInteractedX/Y` 이관.
- `HDTileAction` enum 이나 `isInteractive`/`isStepOn` 정의 변경.
