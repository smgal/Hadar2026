# P1-11 디스패처 티어 0 삽입 + `pendingNavigation` 승격

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-10 대기)
- **구간**: P1
- **규모**: M
- **선행**: P1-10
- **설계 근거**: [BP-27 §4 · §2.7 · §2.8](../../blueprint/27_runtime_engine.md)(**런타임 실행 경로 소유 장**) · [D-10 · D-19 · D-27](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` 부록 K

## 문제

**콘텐츠 티어가 발화할 자리가 없고, 있어야 할 자리 앞에 타일 액션 게이트가 서 있다.**

```dart
// hadar2026_app/lib/application/tile_event_dispatcher.dart:51-61
final action = HDTileProperties.getUnitAction(map.getUnit(x, y));
final bool isScriptedAction =
    isInteraction ? action.isInteractive : action.isStepOn;
if (isScriptedAction) {
  host.beginNarrative();
  ...
  await _dispatchScripted(action, x, y, map, host);
}
```
타일 액션을 먼저 뽑아 그것이 scripted 인지로 분기한다. 앵커가 `move` 타일 위에 있으면
이 게이트에서 걸러져 **콘텐츠가 아예 호출되지 않는다.** D-27 이 요구하는 "타일 비트 무의존" 이 성립하지 않는다.

그리고 `_dispatchScripted`(`:106-157`)의 3티어 앞에는 **아무 것도 삽입되어 있지 않다.**

**두 번째 문제 — `pendingNavigation` 이 cm2 엔진 사유물이다** (D-19)
```dart
// hadar2026_app/lib/application/tile_event_dispatcher.dart:98-100
await host.endNarrative(
  autoFlush: HDScriptEngine().pendingNavigation == null,
);
```
narrative flush 여부가 **cm2 엔진 내부 상태**에 결합되어 있다.
선언 위치는 `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:34` 이고
설정은 `:301`·`:311` 이다. 콘텐츠 티어가 Effect `warp` 를 실행하려면 같은 지연 이동 메커니즘이 필요한데,
현재 소유자가 cm2 엔진이므로 콘텐츠 런타임이 cm2 를 경유해야 한다 — 계층상 말이 안 된다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** P1-07·P1-08·P1-10 이 전부 완성되어도 이 이슈 없이는 **한 번도 실행되지 않는다.**
티어 0 이 콘텐츠 런타임의 유일한 진입점이다.

`pendingNavigation` 승격이 없으면 D-10 의 "티어 0 이 처리했으면 아래로 내려가지 않는다" 규약이
**맵 이동 시 성립하지 않는다** — 워프하는 앵커를 밟으면 narrative 가 잘못 flush 되고 화면이 깨진다.

## 무엇을 할 것인가

**실행 경로의 정본은 [BP-27 §4](../../blueprint/27_runtime_engine.md) 다. diff 스케치가 §4.2 에 있다.**

1. **티어 0 을 타일 액션 게이트 *앞*으로 삽입**한다([BP-27 §4.0·§4.2](../../blueprint/27_runtime_engine.md)).
   - `tile_event_dispatcher.dart:51` 의 `getUnitAction` **이전에**
     `TriggerIndex.lookup(mapName, x, y, activation)` 을 조회한다.
     `activation` 은 `isInteraction` 에서 직접 유도한다(`true → interact`, `false → stepOn`) —
     타일 액션을 계산할 필요가 없다.
   - 앵커가 있으면 `ContentRuntime` 이 처리하고 **handled 로 종료**한다. 아래 3티어로 내려가지 않는다.
   - 앵커가 없으면 **기존 코드가 한 글자도 다르지 않게** 실행된다 — 무중단 점진 이관(D-10).
   - `_dispatchScripted` 의 3티어 순서(native → cm2 → JSON)는 **그대로 유지**한다.
2. **step-on 발화** — [BP-27 §4.3](../../blueprint/27_runtime_engine.md).
   `player_sprite.dart:193` 은 선검사가 없어 밟은 칸의 타일 액션과 무관하게 항상 호출된다(부록 K-1).
   따라서 `move` 칸의 `trigger` 앵커도 잡힌다. **presentation 을 수정하지 않는다.**
3. **ambient 지형 이벤트는 여전히 타일 기반**이다([BP-27 §4.4](../../blueprint/27_runtime_engine.md)).
   `tile_event_dispatcher.dart:73-94` 의 swamp/lava/water 처리는 콘텐츠 티어와 무관하게 남는다.
4. **`pendingNavigation` 을 세션/런타임 공용 개념으로 승격**(D-19).
   - 이름·소유자·처리 시점의 정본은 [BP-27](../../blueprint/27_runtime_engine.md) 이다.
   - `script_engine_adapter.dart:34` 의 필드를 공용 소유자로 옮기고, `:301`·`:311` 이 그것을 세우게 한다.
   - `tile_event_dispatcher.dart:98-100` 의 `autoFlush` 판정이 **cm2 엔진을 참조하지 않게** 한다.
   - Effect `warp`(E14)가 같은 메커니즘을 쓴다.
5. `hadar2026_app/lib/application/content/content_runtime.dart`
   - `ContentRuntime` — 앵커 해석, 세 런타임(대화/퀘스트/이벤트 버스) 조립, 지연 효과 실행
     ([BP-27 §2.7](../../blueprint/27_runtime_engine.md)).
   - `PendingNavigation` 값 타입.
6. `hadar2026_app/lib/application/content/content_effect_bridge.dart`
   - `HDEffectBridge` — 도메인 `EffectApplier` 가 표현만 하고 실행 못 하는 do 를
     세션·전투·맵에 연결한다([BP-27 §2.8](../../blueprint/27_runtime_engine.md)).
     `warp` → 세션, `start_battle` → `HDBattle`, `change_tile` → `MapModel.setTile` + `mapDelta` 표시,
     `set_encounter` → `HDParty`, `play_dialogue` → 꼬리 호출.
   - **주의**: `change_tile` 은 ground(A5) 만 바꾼다. `getUnitAction` 이 `ixObj1` 을 먼저 보므로
     (`tile_properties.dart:196-202`) objUpper 에 오브젝트가 있는 칸은 효과가 없다 —
     그 사실을 [BP-21 §6.6 E15](../../blueprint/21_content_pack_spec.md) 가 이미 제약으로 적었고, 런타임은 경고를 낸다.
7. **재진입 가드의 의미를 문서화하고 테스트로 고정**(D-10).
   `tile_event_dispatcher.dart:34` 의 `_isScriptRunning` 은 전역 bool 1개다.
   콘텐츠 티어는 **비동기 대화 그래프**를 돌리므로 가드의 의미를 "한 번에 하나의 상호작용" 으로 확정한다.
   `:193` 의 호출이 **fire-and-forget** 이라는 사실(부록 K-3)이 이 가드를 유일한 보호막으로 만든다.

## 완료 판정 기준

- [ ] `move` 타일 위의 `trigger` 앵커를 밟으면 콘텐츠가 발화한다 (타일 액션 게이트를 통과하지 않았음이 확인된다)
- [ ] 앵커가 **없는** 맵에서 기존 3티어 동작이 완전히 동일하다 (레거시 회귀 없음)
- [ ] 티어 0 이 처리하면 native/cm2/JSON 이 **호출되지 않는다** (중복 대사 없음)
- [ ] `tile_event_dispatcher.dart` 의 `autoFlush` 판정에 `HDScriptEngine()` 참조가 **없다**
- [ ] Effect `warp` 로 맵을 옮겨도 narrative 가 정상 처리된다 (화면 깨짐 없음, 플레이로 확인)
- [ ] `presentation/panels/player_sprite.dart` 가 이 이슈에서 **수정되지 않았다** (P0-18 이 bump 게이트만 담당)
- [ ] `application/` 계층 grep 2종 + `dart:io` 검사 통과 (`ContentRuntime` 이 `presentation/` 을 import 하지 않는다)
- [ ] **테스트 1**: `hadar2026_app/test/application/tier0_dispatch_test.dart` —
      ① 앵커 있음 → 티어 0 만 실행, ② 앵커 없음 → 기존 3티어 그대로, ③ `move` 칸 step-on 발화.
      페이크 `UiHost`·`AssetSource` 바인딩은 `test/application/map_navigation_test.dart:13-28` 패턴
- [ ] **테스트 2**: `hadar2026_app/test/application/reentrancy_guard_test.dart` —
      대화 실행 중 두 번째 `check()` 호출이 **무시**된다는 명제를 고정 ("한 번에 하나의 상호작용")
- [ ] **테스트 3**: `hadar2026_app/test/application/pending_navigation_test.dart` —
      cm2 경로와 콘텐츠 `warp` 경로가 **같은 지연 이동 메커니즘**을 쓴다는 것을 고정

## 하지 않을 것

- **bump 게이트(`player_sprite.dart:359`) 제거** — **P0-18**.
- **이동·상호작용 루프를 `application/` 으로 추출**(`HDPartyMovement`) — **P2-03**. 부록 B-3 의 헤드리스 장벽은 별개 문제다.
- 3티어 순서 변경·cm2 티어 제거 — 공존이 전략(D-10 · [BP-28](../../blueprint/28_migration_and_coexistence.md)).
- `map_loader.dart` 수정 — D-28.
- 헤드리스 하네스·`SimDriver` — **P2**.
