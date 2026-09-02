# P1-03 `WorldState` — 3중 분열된 상태를 이름 있는 키로 통합

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-01 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-01
- **설계 근거**: [BP-25 §1~§3](../../blueprint/25_world_state_and_save.md)(**소유 장**) · [D-04 · D-08 · D-08a](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` §8 · 부록 A-3 · F-1

## 문제

진행 상태가 **세 곳으로 갈라져 있고, 셋 다 이름이 없고, 하나는 저장되지 않고, 하나는 맵 전환마다 사라진다.**

**① `HDGameOption`** — 저장됨, 정수 인덱스, 범위 밖은 침묵
```dart
// hadar2026_app/lib/domain/game_option.dart:9-10
List<bool> flags = List.filled(HDConfig.maxFlags, false);      // 256칸
List<int> variables = List.filled(HDConfig.maxVariables, 0);   // 256칸
```
cm2 의 `Flag::Set/Reset/IsSet`·`Variable::Set/Add/Get` 이 이것을 쓴다. `toJson()`(`:27-34`)에 실려 저장된다.
그러나 `script_engine_adapter.dart:362-391` 이 범위 검사에 `else` 를 두지 않아 `Flag::Set(300)` 은
**아무 일도 하지 않고 아무 로그도 남기지 않는다**(부록 F-1).

**② `HDNativeScriptRunner`** — **저장되지 않음**
```dart
// hadar2026_app/lib/application/scripting/native_script_runner.dart:22-23
Map<int, bool> flags = {};
Map<int, int> variables = {};
```
`isFlagSet`/`setFlag` 구현은 `:91-97` 에 있다. 그런데
`hadar2026_app/lib/application/save_manager.dart:18-24` 의 저장 대상은
`{version, party, gameSystem, gameOption, map}` 뿐이다 — **이 Map 두 개는 어디에도 실리지 않는다.**
게다가 맵 스크립트는 자기 자신의 스텁(`map_script.dart:41-48`)을 호출하므로 **쓰기도 사실상 죽어 있다**(부록 A-3).
즉 write-dead 이면서 동시에 저장 누락이다.

**③ `HDScriptEngine.variables`** — 맵 전환 시 소실
`hadar2026_app/lib/application/game_session.dart:101-108` 이 맵 전환마다
`HDScriptEngine().loadScript(...)` 를 호출하고, 그 안(`script_engine_adapter.dart:103`)에서
`_engine.clearRuntimeState()` 가 **엔진 전역을 전부 날린다**. 주석 `:104-106` 이
"globals are not preserved across map transitions" 라고 이 사실을 명시하고 있다.

세 저장소 전부 **의미가 `assets/const.cm2` 나 주석에만 존재하는 정수 인덱스**다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 퀘스트는 정의상 "여러 맵·여러 세션에 걸쳐 살아남는 상태" 다.
현재 구조에서 손으로 퀘스트를 만들면 세 가지 중 하나를 고른 셈이 되는데 셋 다 못 쓴다 —
①은 256칸 정수라 이름 충돌을 사람이 관리해야 하고, ②는 세이브에서 사라지고, ③은 맵을 나가면 사라진다.

정수 인덱스에는 **"범위 밖" 이라는 실패 양식이 내재**한다(부록 F-1). 이름 있는 키는 그 실패 양식 자체를 없앤다 —
없는 키는 기본값으로 읽히고(BP-21 §6.3), 오타는 린트가 "쓰기만 있고 읽기가 없는 플래그" 로 잡는다.

## 무엇을 할 것인가

**설계는 [BP-25 §2~§3](../../blueprint/25_world_state_and_save.md) 이 소유한다.** 필드 표를 재서술하지 않는다.

1. `packages/hadar_content/lib/world_state.dart`
   - `MutableWorldState` — 실제 상태 컨테이너. 필드 정의는 [BP-25 §2.1](../../blueprint/25_world_state_and_save.md).
   - `WorldStateView`(읽기 전용) / `WorldStateMutator`(쓰기 전용) 분리 — [BP-25 §3.2·§3.3](../../blueprint/25_world_state_and_save.md).
     이 분리가 P1-02 의 "Condition 은 순수 함수" 를 **타입으로 강제**하는 장치다.
   - `WorldContext` — 상태가 아닌 실행 문맥([BP-25 §2.8](../../blueprint/25_world_state_and_save.md)).
   - `QuestProgress` · `JournalEntry` — 중첩 타입([BP-25 §2.2](../../blueprint/25_world_state_and_save.md)).
   - **시각은 `step` 정수 하나뿐이다**(D-08a). 벽시계(`DateTime`)를 `WorldState` 안에 넣지 않는다.
     `startedStep`/`updatedStep`/`atStep` 이 전부 이 값을 기록한다.
   - `journal` 은 링 버퍼([BP-25 §2.7](../../blueprint/25_world_state_and_save.md)), `dialogueMemory` 는
     1회성 기록을 플래그와 섞지 않기 위한 별 필드([BP-25 §2.6](../../blueprint/25_world_state_and_save.md)).
   - **정렬 직렬화** — 키 순서를 고정한다([BP-25 §2.3](../../blueprint/25_world_state_and_save.md)).
     결정론 해시(`contentHash`)가 이것에 의존한다.
2. **레거시 정수 플래그 다리** — `legacyFlagMap`
   - `content.lock.json` 에 `legacyFlagMap: {flagId: intIndex}` 를 빌드가 생성한다(D-04).
     이 이슈는 **런타임 측 다리**만 만든다: `HDGameOption.flags[i]` ↔ `WorldState.flags` 의 이름 키 양방향 반영.
   - 접합점은 `script_engine_adapter.dart:362-391` 의 4개 커맨드다. cm2 가 `Flag::Set(7)` 을 부르면
     `legacyFlagMap` 역참조로 대응 이름 키도 세운다. **역참조에 없는 정수는 이름 공간에 흡수하지 않고
     `orphans` 로 남긴다**([BP-25 §6.4](../../blueprint/25_world_state_and_save.md)).
   - ②(`HDNativeScriptRunner.flags`/`.variables`)는 **다리를 놓지 않고 `WorldState` 로 흡수한다.**
     부록 A-3 이 확정한 대로 이 저장소는 write-dead 이므로 보존할 기존 데이터가 없다.
     `native_script_runner.dart:91-97` 의 `isFlagSet`/`setFlag` 를 `WorldState` 위임으로 바꾸고,
     `map_script.dart:41-48` 의 스텁도 같은 곳을 향하게 한다(P0-04 가 스텁을 먼저 고친다).
   - ③은 흡수하지 않는다. cm2 엔진 내부 변수는 스크립트 지역 변수로 남고, 맵을 넘겨야 하는 값만
     콘텐츠 키로 올린다. 이 경계를 `docs/` 가 아니라 **`world_state.dart` 의 doc comment 에** 적는다.
3. `hadar2026_app/lib/application/content/` 에 `WorldState` 를 들고 있는 소유자를 둔다.
   싱글턴 관례를 따르되 **`reset()` 을 노출**한다(D-11). 세이브 배선은 P1-04 가 한다.

## 완료 판정 기준

- [ ] `WorldState` 안에 `DateTime`·벽시계 타입이 **0개**다 (grep 으로 확인 가능)
- [ ] `WorldStateView` 에 쓰기 메서드가 없고, `WorldStateMutator` 에 읽기 메서드가 없다
- [ ] `HDMapScript.isFlagSet`/`setFlag` 와 `HDNativeScriptRunner.isFlagSet`/`setFlag` 가
      **같은 저장소**를 본다 (스텁 반환 `false` 가 사라졌다)
- [ ] `Flag::Set(300)` 이 이름 키를 세우지 않으면서 **로그를 남긴다** (침묵하지 않는다 — P0-14 와 함께)
- [ ] 같은 `WorldState` 를 두 번 직렬화하면 **바이트 단위로 동일**하다 (키 순서 고정)
- [ ] **테스트 1**: `packages/hadar_content/test/world_state_test.dart` —
      정렬 직렬화 안정성, `journal` 링 버퍼 상한, `step` 단조 증가, 없는 키의 기본값 읽기
- [ ] **테스트 2**: `hadar2026_app/test/application/content/legacy_flag_bridge_test.dart` —
      `legacyFlagMap` 이 있는 정수는 이름 키로 반영되고, 없는 정수는 `orphans` 에 남는다는 두 명제를 고정.
      `HDHosts().bind(...)` 페이크 + `tearDown` 의 `HDHosts().reset()` 패턴은
      `hadar2026_app/test/application/map_navigation_test.dart:13-28` 을 따른다
- [ ] 계층 grep 2종 + `dart:io` 검사 통과

## 하지 않을 것

- **세이브 포맷 변경과 v1 마이그레이션** — P1-04. 이 이슈는 인메모리 통합까지다.
- `legacyFlagMap` 을 **생성**하는 빌드 단계 — P1-12.
- 월드 이벤트 발행 — P1-09.
- `HDGameOption` 삭제 — cm2 공존을 위해 남긴다(D-10 · [BP-28](../../blueprint/28_migration_and_coexistence.md)).
- 디버그/치트 커맨드 20종([BP-25 §9](../../blueprint/25_world_state_and_save.md)) — P1 범위 밖.
