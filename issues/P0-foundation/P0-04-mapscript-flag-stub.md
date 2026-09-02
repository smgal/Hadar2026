# P0-04 `HDMapScript` 플래그 API 가 빈 스텁 — 네이티브 조건 분기가 전무

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 A-3 · §8](../../blueprint/_meta/GROUND_TRUTH.md) · [DECISION-LOG 판정 근거](../DECISION-LOG.md) · [BP-25 WorldState](../../blueprint/25_world_state_and_save.md)

## 문제

`hadar2026_app/lib/application/scripting/map_script.dart:41-48`:

```dart
bool isFlagSet(int index) {
  // Requires implementation in GameModel / State
  return false;
}

void setFlag(int index) {
  // Requires implementation in GameModel / State
}
```

`HDNativeScriptRunner` 에는 **실제 구현이 있다** — `native_script_runner.dart:91-97`:

```dart
bool isFlagSet(int flagId) {
  return flags[flagId] ?? false;
}

void setFlag(int flagId) {
  flags[flagId] = true;
}
```

그런데 맵 스크립트는 자기 자신(수퍼클래스)의 스텁을 호출한다. 실사용 지점(본인 전수 확인):

| 파일:줄 | 코드 | 실제 평가 |
|---|---|---|
| `maps/town1_map_script.dart:38` | `if (!isFlagSet(41) && isArea(49, 29, 51, 29))` | `!false` = 항상 참 |
| `maps/town1_map_script.dart:40` | `setFlag(41)` | no-op |
| `maps/town1_map_script.dart:77` | `if (!isFlagSet(33))` | 항상 참 |
| `maps/town1_map_script.dart:79` | `setFlag(33)` | no-op |
| `maps/town1_map_script.dart:82` | `if (!isFlagSet(34))` | 항상 참 |

즉 `town1_map_script.dart:38` 의 로드안 대사는 **같은 칸을 밟을 때마다 매번 반복**되고,
`:77-87` 의 3단 분기는 첫 번째 가지에서만 머문다.
`maps/town1_map_script.dart:28-30` 의 주석 처리된 `isFlagSet(33)` 예시도 동작하지 않는 API 를 예시로 남긴 것이다.

## 왜 지금 고쳐야 하는가

- [DECISION-LOG.md](../DECISION-LOG.md) 의 착수 판정이 "지금 구조에서는 손으로도 퀘스트를 만들 수 없다" 는
  근거로 **가장 먼저 든 항목**이 이것이다. 네이티브 Dart 로 임시 대응하는 경로
  ([P0-00](P0-00-content-volume-target.md) 의 "5개 미만" 구간 권고)는 이 수리 없이는 성립하지 않는다.
- 부록 F-2([P0-05](P0-05-native-script-without-geometry.md))와 **원인이 독립적**이다. 저쪽을 고쳐도 이 문제는 남는다.
- 세이브 미저장 문제와도 별개다 — `HDNativeScriptRunner.flags` 는 세이브에 들어가지 않지만(§8),
  그 배선은 [P1-04](../deferred/P1-04-save-v2.md) 소관이다. **이 이슈는 "런타임 안에서라도 동작하게" 까지다.**

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 | 장점 | 단점 |
|---|---|---|---|---|
| A | **스텁을 `HDNativeScriptRunner` 로 위임** | `map_script.dart:41-48` 2메서드 | 최소 변경. 이미 있는 구현을 쓴다 | `HDMapScript` 가 러너 싱글턴에 직접 의존 (같은 `application/scripting/` 안이므로 계층 위반은 아님) |
| B | 스텁을 `HDGameOption.flags`(List<bool>(256)) 로 위임 | `map_script.dart` | cm2 의 `Flag::Set/IsSet` 과 **같은 저장소**를 공유 → 상태가 하나로 통일되고 세이브도 이미 된다 | 인덱스 공간이 cm2 스크립트와 충돌할 수 있다 (town1 이 쓰는 33·34·41 이 cm2 쪽에서 다른 의미로 쓰이는지 확인 필요) |
| C | 스텁을 삭제하고 추상 메서드로 승격 | `map_script.dart` + 4개 맵 스크립트 | 미구현이 컴파일 에러로 드러난다 | 맵 스크립트마다 같은 구현을 반복해야 한다 |
| D | `map_script.dart` 에서 스텁을 지우고 `HDMapScriptContext`(`game`) 에 노출 | `map_script_context.dart` | 나머지 호스트 접근과 경로가 통일된다(`game.addLog` 등) | 호출부 5곳 수정 필요 |

### 권고안: **A**

`HDNativeScriptRunner` 로 위임한다. 근거 — 저 러너의 `flags` 는 이미
"맵 전환마다 초기화되는 cm2 전역과 달리 살아남아야 하는 상태" 라는 목적으로 만들어졌다
(`native_script_runner.dart:19-23` 의 주석이 그것을 명시한다).

```diff
- bool isFlagSet(int index) {
-   // Requires implementation in GameModel / State
-   return false;
- }
-
- void setFlag(int index) {
-   // Requires implementation in GameModel / State
- }
+ bool isFlagSet(int index) => HDNativeScriptRunner().isFlagSet(index);
+
+ void setFlag(int index) => HDNativeScriptRunner().setFlag(index);
```

- **B 를 채택하지 않는 이유**: cm2 쪽 인덱스 공간과의 충돌을 P0 에서 조사·해소할 근거가 없다.
  통합은 [P1-03](../deferred/P1-03-worldstate-unification.md)(`WorldState`)이 이름 있는 키로 처리할 일이다.
- `map_script.dart:41-48` 에 **"이 저장소는 세이브되지 않는다(부록 §8) — [P1-04](../deferred/P1-04-save-v2.md) 에서 이관"** 주석을 남긴다.
- `maps/town1_map_script.dart:28-30` 의 죽은 주석 예시는 살리거나 지운다 (동작하는 API 를 예시로 두기 위해).
- 임포트 순환 확인: `native_script_runner.dart:6` 이 `map_script.dart` 를 임포트한다.
  Dart 는 순환 임포트를 허용하지만, 껄끄러우면 `resetFlag` 를 포함해 작은 인터페이스로 분리한다.

## 완료 판정 기준

- [ ] `Town1MapScript` 의 같은 칸(`isArea(49,29,51,29)`)을 두 번 밟으면
      **두 번째에는 로드안 대사가 나오지 않는다** (`onEvent` 가 `false` 를 반환)
- [ ] `setFlag(33)` 후 `HDNativeScriptRunner().isFlagSet(33) == true` 다
- [ ] `HDNativeScriptRunner().startNewGame()` 이후 모든 플래그가 다시 `false` 다
- [ ] `flutter analyze --no-fatal-infos` 통과 (순환 임포트 경고 없음)
- [ ] 테스트 추가: `hadar2026_app/test/application/scripting/map_script_flags_test.dart` —
      `HDMapScript` 를 구현한 최소 페이크 스크립트로
      ① `setFlag` 후 `isFlagSet` 이 참 ② 러너의 `flags` 맵에 값이 들어감 ③ `startNewGame` 후 초기화됨을 고정한다

## 하지 않을 것

- 플래그를 세이브에 넣기 — [P1-04](../deferred/P1-04-save-v2.md) 소관.
- 정수 인덱스를 이름 있는 키로 바꾸기 — [P1-03](../deferred/P1-03-worldstate-unification.md) 소관.
- 3중 분열된 상태 저장소의 통합 — 같음.
- 네이티브/cm2/JSON 티어 우선순위 변경 — [P1-11](../deferred/P1-11-dispatcher-tier0.md) 소관.
- 새 맵 스크립트 작성이나 기존 스크립트의 콘텐츠 확장.
