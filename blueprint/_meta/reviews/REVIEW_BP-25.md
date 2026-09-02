# 검수 보고서 — BP-25 월드 상태 통합과 세이브 v2

- **검수자**: R4 · **대상 파일**: blueprint/25_world_state_and_save.md (1001줄)
- **판정**: **수정 필요**
- **점수**: A3 B2 C2 D3 E4 F2 G4 = **20/35** (합격선 26, 모든 축 3 이상 — B/C/F 가 2점이라 불합격)

## 0. 수행한 기계적 검사 (증거)

| # | 검사 | 결과 |
|---|---|---|
| 1 | 줄 수 (`wc -l`) | 1001줄 — 규약 최소 250줄 **충족** |
| 2 | 코드 인용 검증 | **23곳** 직접 열어 대조 (§0.1) — 4곳 불일치 |
| 3 | 링크 검증 | 12개 상대 링크. 6개(33/35/41/42/51/90)는 미생성이나 OUTLINE.md 계획 파일 → **허용**. 24/26 은 검수 시점에 생성 확인 |
| 4 | 식별자 검증 | D-05 do 22종 분류 **정확**(§4.4 즉시 19 + 지연 3 = 22). 반면 `legacyVarMap`·`orphans` 는 DECISIONS 에 없는 **신규 식별자** |
| 5 | 중복 검사 | `pack.json#migrations` 를 BP-21 §7.3 과 **다른 스키마로 재정의**. 월드 이벤트 카탈로그를 BP-23 §23.11.1 과 **다른 이름 집합으로 재정의** |
| 6 | 미확정 표현 grep | "적절히/추후/TBD/등등" 핵심 명세에 **0건**. "나중에" 2건(:718, :894)은 서술부라 문제 없음 |

### 0.1 코드 인용 대조 결과 (23곳)

| 문서 위치 | 주장 | 실측 | 판정 |
|---|---|---|---|
| :20 | `game_option.dart:9` flags | `List<bool> flags = List.filled(...)` @9 | ✅ |
| :21 | `game_option.dart:10` variables | @10 | ✅ |
| :20 | `game_option.dart:20` reset() | @20 | ✅ |
| :20 | `reset()` **호출 지점 없음** | `grep -rn "gameOption.reset" lib/` → 0건 | ✅ |
| :22 | `script_engine_adapter.dart:362/369` Flag::Set/Reset | @362/@369 | ✅ |
| :23 | `:376/:383` Variable::Set/Add | @376/@383 | ✅ |
| :30-38 | Flag::Set 핸들러 코드 블록 | 문자열까지 일치 | ✅ |
| :25 | `native_script_runner.dart:22`, `:95` setFlag | 파일/줄은 맞음 | ⚠️ **F-01** (호출자 없음) |
| :26 | `:23`, `:39`, `:40` | @23/@39/@40 | ✅ |
| :55 | `game_session.dart:85` loadMapFromFile | @85 | ✅ |
| :56 | `game_session.dart:107` loadScript | @107 | ✅ |
| :57 | `script_engine_adapter.dart:103` clearRuntimeState | @103 | ✅ |
| :58 | `script_engine_adapter.dart:111` loadFromString | **실제 @107** (111은 print 종결) | ❌ **F-06** |
| :59 | `cm2_script.dart:74` loadFromString | @74 | ✅ |
| :60 | `cm2_script.dart:75` clearRuntimeState | @75 | ✅ |
| :64 | `cm2_script.dart:67` 본문 | @67 + 본문 4줄 일치 | ✅ |
| :101 | `save_manager.dart:18` data 맵 | @18-24 문자열 일치 | ✅ |
| :113 | `party.dart:182` toJson | @182 | ✅ |
| :117 | `map_model.dart:50` toJson (`events` 누락) | @50-58, `events` 없음 | ✅ |
| :119 | `map_model.dart:13` events 필드 | @13 | ✅ |
| :132 | `tile_event_dispatcher.dart:159` `_emitJsonDialog` | @159 | ✅ |
| :577 | `script_engine_adapter.dart:512` "cm2 가 정수 플래그를 읽는다" | `Flag::IsSet` @503 / `Variable::Get` @511 | ⚠️ 근사 |
| :821 | 로드 8단계에 `GameReloadException` 던지기 포함 | `loadGame` 은 `true` 반환만. 던지는 곳은 `menu_flows.dart:519/:536`(사망 경로 전용) | ❌ **F-07** |
| :838-844 | `map_unit.dart:26` 57바이트/칸 | @26 5필드, 계산 타당 | ✅ |
| :869 | `menu_flows.dart:434/466` save/load 메뉴 | @434/@466 | ✅ |

인용 **정확도 19/23**. 대부분 정밀하나, 틀린 4건 중 F-01·F-07 은 **설계 전제를 무너뜨리는 종류**라 축 A 를 3점으로 제한한다(루브릭 2번 규정).

---

## 치명 결함 (반드시 고쳐야 함)

### F-01 S3/S4 의 "쓰는 주체" 가 사실과 다르다 — GROUND_TRUTH 부록 A-3 미반영
- 위치: 25_world_state_and_save.md:25-26 (§1.1 표), :113 근처(§1.3 표), §5.1 `legacy.nativeFlags` 블록, §5.2 표
- 문서 주장: S3/S4(`HDNativeScriptRunner.flags/variables`)를 "네이티브 맵 스크립트 (`setFlag`, `:95`)" 가 쓴다. 따라서 세이브 v2 는 `legacy.nativeFlags/nativeVariables` 를 신설해 "S3/S4 저장 누락"을 해소한다.
- 실측:
  - `hadar2026_app/lib/application/scripting/native_script_runner.dart:95` `void setFlag(int flagId)` 의 **호출자가 레포 전체에 0건**이다.
  - 맵 스크립트(`town1_map_script.dart:40`, `:79`)가 부르는 것은 자기 부모의 스텁 `hadar2026_app/lib/application/scripting/map_script.dart:46` 이고, 그 본문은 `// Requires implementation in GameModel / State` 뿐이다. `isFlagSet`(map_script.dart:41)도 **항상 false 를 반환**한다.
  - 즉 **S3/S4 는 영원히 비어 있다.** GROUND_TRUTH 부록 A-3 이 이미 이 사실을 확정해 두었는데 본 장이 반영하지 않았다.
- 파급:
  1. §5.1/§5.2 의 `legacy.nativeFlags` 블록은 **항상 `{}` 를 직렬화하는 죽은 필드**다.
  2. §6.1 의사코드 9단계 `report.notes.add(LOST_NATIVE_RUNNER_STATE)` 는 존재한 적 없는 손실을 보고한다.
  3. R-25-1 의 "S1~S5 흡수" 서술이 실제 결함(= 네이티브 스크립트의 상태 API 자체가 미배선)을 가린다.
- 요구 조치: §1.1 S3/S4 행의 "쓰는 주체"를 **"(현재 없음) — `HDMapScript.isFlagSet/setFlag` 가 미구현 스텁이라 어떤 맵 스크립트도 이 저장소에 도달하지 못함(부록 A-3)"** 으로 정정. `legacy.nativeFlags` 를 (a) 스텁을 `HDNativeScriptRunner` 로 위임하도록 고치는 선결 태스크와 묶어 유지하거나, (b) 필드를 제거하고 이유를 명시. 어느 쪽이든 **선택을 문서에 못 박을 것**.

### F-02 D-08a 미반영 — `startedAt` / `updatedAt` / `at` 이 그대로 남아 있다 (10곳)
- 위치와 요구 치환:

| # | 줄 | 현재 | 바꿔야 할 것 |
|---|---|---|---|
| 1 | :162 | `D-08 이 startedAt/updatedAt/at 을 요구하는데` | D-08a 가 `startedStep/updatedStep/atStep` 으로 개정됐음을 명시 |
| 2 | :172 | `startedAt: int` (QuestProgress) | `startedStep: int` |
| 3 | :173 | `updatedAt: int` | `updatedStep: int` |
| 4 | :180 | `at: int` (JournalEntry) | `atStep: int` |
| 5 | :194 | INV-7 `journal 의 at 는 비감소 수열` | `atStep` |
| 6 | :256 | 크기 산출 근거 `state/stage/startedAt/updatedAt` | `startedStep/updatedStep` |
| 7 | :547 | 세이브 예제 JSON `"startedAt": 310` | `"startedStep": 310` |
| 8 | :548 | `"updatedAt": 4102` | `"updatedStep": 4102` |
| 9 | :556 | 저널 예제 `"at": 310` | `"atStep": 310` |
| 10 | :995 | Q-25-1 을 "열린 질문"으로 유지 | **D-08a 로 종결**됨을 기록하고 열린 질문에서 제거 |

- 근거: DECISIONS.md 「결정 개정 이력」 D-08a — *"퀘스트/저널의 시각 필드는 전부 이 `step` 을 기록한다(`startedStep`, `updatedStep`, `atStep`)"*. 개정문 자체가 *"BP-25 Q-25-1 제기 → 본 개정으로 종결"* 이라고 못 박았으므로 Q-25-1 을 그대로 두는 것은 명백한 미반영이다.
- 주의: §3.3 계약표의 `updatedAt 갱신`, §2.2 불변식 `startedAt <= updatedAt` 도 같이 갱신해야 한다.

### F-03 이벤트 이름 집합이 BP-23·BP-24 와 정면 충돌한다 — 세 장이 각각 "닫힌 집합"을 선언
- 위치: 25_world_state_and_save.md:429-442 (§4.2 "이벤트 카탈로그 (닫힌 집합)")
- 대조:

| 의미 | BP-25 §4.2 (11종) | BP-23 §23.11.1 (12종, "v1 확정 — 닫힌 집합") | BP-24 §24.4 | 일치 |
|---|---|---|---|---|
| 대화 진입 | `talked_to` | `talk` | — | ❌ |
| 장소 진입 | `entered_place` | `enter_place` | — | ❌ |
| 선택 확정 | `choice_made` | `dialogue_choice` | `dialogue_choice` (24_dialogue_model.md:464) | ❌ (BP-25 만 다름) |
| 전투 승리 | `battle_won` `{encounterId?, enemyIds, count}` | `battle_won` `{encounterId?, enemyIds:[int], map, x, y}` | — | ⚠️ payload 불일치 |
| 아이템 획득 | `item_gained` `{itemId, **count**, total}` | `item_gained` `{itemId, **delta**, total}` | — | ⚠️ 필드명 불일치 |
| 변수 변경 | `var_changed` `{varId, **value, delta**}` | `var_changed` `{varId, **oldValue, newValue**}` | — | ⚠️ 필드 집합 불일치 |
| 인도 | `item_delivered` (전용 이벤트) | 전용 이벤트 없음 — `talk ∧ item_lost` 배치 조합 | — | ❌ **메커니즘 자체가 다름** |
| 생존 | `turn_survived` `{count}` (전투 턴) | `survive ← step_tile` (이동) | — | ❌ |
| 타일 밟음 | (없음) | `step_tile` | — | ❌ |
| 맵 전환 | (없음) | `map_changed` | — | ❌ |
| 골드 | (없음) | `gold_changed` | — | ❌ |
| 휴식 | (없음) | `party_rested` | — | ❌ |
| 퀘스트 전이 | `quest_state_changed` | (없음) | — | ❌ |

- 12종 중 **완전히 일치하는 이름은 5개**(`battle_won`, `item_gained`, `item_lost`, `flag_changed`, `var_changed`)뿐이고, 그중 3개는 payload 가 다르다.
- 심각한 이유: BP-23 §23.11.1 은 *"`lib/application/content/world_event_bus.dart` (D-11) 가 발행하는 전부다"* 라고 못 박고 §23.11.4 에서 **objective kind 9종 커버리지 증명**까지 그 이름 집합 위에 세웠다. BP-25 의 집합으로는 `reach ← step_tile | map_changed`, `survive ← step_tile`, `deliver ← talk ∧ item_lost` 증명이 전부 깨진다.
- 요구 조치: 세 장 중 **한 곳만 소유자**로 정하고(문서 규약 6) 나머지는 링크만 남길 것. BP-25 는 "런타임 상태의 저장 형태" 담당이라고 §0 에서 스스로 선언했으므로, **이벤트 카탈로그의 SSoT 는 BP-23 으로 넘기고 §4.2 는 큐 처리 규칙(EV-1~7)만 남기는 것**이 자연스럽다. 어느 쪽이든 이름·payload 를 하나로 통일해야 한다.

### F-04 `mapDelta` 가 `Map::Init` / `Map::SetRow` 로 만들어진 맵에서 성립하지 않는다 — 실사용 콘텐츠 8개가 여기에 해당
- 위치: §5.4(:600-610), §8.3 SV-1(:857 근처), §5.3 "v2 복원 규약", R-25-4
- 문서 주장: 맵은 `currentMapName` 으로 원본을 재로드한 뒤 `mapDelta`(원본 대비 달라진 `MapUnit` 만)를 덮어쓴다. "`unitPatches` 는 현실적으로 수십 건 이하다."
- 실측:
  - `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:241-250` `Map::Init(w,h)` 은 **`MapModel()` 을 새로 만들어 `setNewMap`** 한다. 원본 JSON 이 존재하지 않는다.
  - `:262-274` `Map::SetRow` 가 행 단위로 타일을 채운다.
  - 이 방식으로 맵 전체를 구성하는 cm2 가 **8개**다: `assets/L1_ep1d0.cm2`(SetRow 50행), `L1_ep1d1`(30), `L1_ep1d2`(50), `L1_ep1d3`(50), `L1_ep1d4`(50), `L1_ep1d5`(50), `L1_ep1d5_1`(50), `town1.cm2`(30).
  - 이들은 `LoadScript("L1_ep1d0.cm2", 47, 28)` 로 진입한다. `HDMapNavigation.loadByName` 은 `MapInfos.json` 에서 이름을 못 찾아 `null` 을 반환하고(`map_navigation.dart:63-66`), `loadMapFromFile` 은 **`bundle == null` 로 즉시 false 를 반환**한다(`game_session.dart:88`).
- 결과 3중 파손:
  1. `currentMapName` 이 갱신되지 않는다(=직전 맵 이름이 **스테일하게 남는다**). R-25-4 의 전제가 무너진다.
  2. `mapDelta` 산출의 "원본"이 없다. 굳이 만들면 10,000칸 전부가 패치가 되어 **570KB 문제가 그대로 돌아온다**(SV-1 무효화).
  3. BP-27 §7.3 이 넣은 `if (mapName == null) return false;` 와 결합하면 **이 8개 맵에서는 저장 자체가 불가능**해진다 — v1 대비 **명백한 기능 후퇴**인데 §5.2 의 v1↔v2 차이표에 이 후퇴가 없다.
- 요구 조치: §5.4 에 "스크립트 생성 맵(origin 없음)" 케이스를 신설하고 셋 중 하나를 확정할 것 — (a) `mapDelta.mode: "full"` 폴백(스냅샷 저장, 웹에서는 SV-4 로 거부), (b) `Map::Init/SetRow` 재생을 위한 `mapRecipe`(스크립트 경로 + 진입 좌표) 저장, (c) 해당 맵에서의 저장을 **명시적 거부 + 사용자 문구**(§6.5 표에 추가). BP-28:89 가 "티어 0 진입 불가"만 다루고 **세이브 가능성은 아무도 다루지 않고 있다.**

### F-05 `WorldStateMutator.nextRandom` 이 R-25-5(조건 평가의 순수성)를 스스로 깬다
- 위치: §3.3 :378-379, §3.3 계약표 :392, §1.4 R-25-5, BP-27 §9.2 `WorldRng`
- 문서 주장: R-25-5 *"읽기 경로는 부작용이 없어야 한다(순수 함수). Condition 평가는 상태를 바꿀 수 없다"* / §3.1 *"읽기 전용 인터페이스만 주면 **컴파일 타임에** 위반이 잡힌다"*.
- 실제 설계: D-05 의 `chance(percent)` op 은 시드 난수를 소비한다. BP-27 §2.4 는 `ConditionEvaluator.evaluate(Condition, WorldStateView, {WorldRng? rng})` 로 정의하고, BP-27 §9.2 는 `WorldRng.nextInt(n) => _state.nextRandom(n)` 이며 `_state` 의 타입은 **`WorldStateMutator`** 다.
  → 즉 조건 평가에 `WorldRng` 를 넘기는 순간 **`rngCursor` 가 증가하고 `WorldState` 가 변한다.** View/Mutator 분리는 이 경로를 전혀 막지 못한다.
- 파급: T-25-08(`View 만으로는 상태를 바꿀 수 없다 … 스냅샷 해시로 검증`)은 `chance` 를 포함한 조건에서 **반드시 실패**한다. §3.4 의 "QuestSolver 는 `WorldStateView` + 복제본 Mutator" 도 성립하지 않는다(솔버가 조건을 평가할 때마다 커서가 밀린다).
- 요구 조치: 셋 중 하나를 확정 —
  (a) `chance` 를 **커서를 소비하지 않는 순수 해시 함수**로 정의: `chance(p) := hash(seed, step, conditionPath) % 100 < p` — 같은 스텝의 같은 조건은 항상 같은 값. 이러면 View 만으로 평가 가능하고 R-25-5 가 유지된다.
  (b) `chance` 평가를 Condition 에서 **금지**하고 `Effect` 쪽으로 옮긴다.
  (c) R-25-5 를 "Condition 은 `rngCursor` 외의 상태를 바꾸지 않는다" 로 약화하고, T-25-08 을 그에 맞게 다시 쓴다.
  (a) 를 권장한다. 나머지 두 개는 D-13 의 솔버 요구와 충돌한다.

---

## 중요 결함

### F-06 `script_engine_adapter.dart:111` 인용이 4줄 어긋나 있다
- 위치: :58 (§1.2 호출 사슬 다이어그램)
- 실측: `await _engine.loadFromString(content);` 은 **@107**. @111 은 그 아래 `print(...)` 의 닫는 줄이다.
- 요구 조치: `:111` → `:107`.

### F-07 성공 로드의 `GameReloadException` 소유자가 미확정 — §6.5 와 §8.2 가 모순된다
- 위치: §8.2 로드 절차 8단계(:821) vs §6.5(:760 근처)
- 문서 주장: §8.2 는 로드 절차의 마지막 단계로 *"8. GameReloadException 던져 실행 루프 되감기"* 를 넣었다. §6.5 는 *"실패는 `HDSaveManager.loadGame` 이 `false` 를 반환하고"* 라 하여 반환값 규약을 전제한다.
- 실측: 현재 `HDSaveManager.loadGame` 은 **던지지 않고 `true`/`false` 만 반환**한다(`save_manager.dart:99`, `:104`). `GameReloadException` 을 던지는 곳은 `menu_flows.dart:519` 와 `:536` 뿐이고, 둘 다 **`processGameOver`(필드 사망 / 전투 전멸) 경로**다. 정상 메뉴 로드(`selectGameOption` case 4 → `selectLoadMenu`, `menu_flows.dart:306-307`)는 **예외를 던지지 않는다** — 즉 인게임 로드는 지금도 실행 루프를 되감지 않는다.
- 왜 중요한가: BP-25 §4.5 와 BP-27 §5.4 가 "대화 도중 `GameReloadException` 이 던져지면" 을 전제로 트랜잭션 규약을 세웠다. 그런데 **누가 언제 던지는지가 어느 문서에도 확정되어 있지 않다.** `loadGame` 이 던지도록 바꾸면 반환 타입 계약(§6.5)이 바뀌고, `menu_flows` 가 계속 던지면 §8.2 8단계는 `loadGame` 의 책임이 아니다.
- 요구 조치: §8.2 를 *"8. 호출자(`HDMenuFlows`)가 `loadGame` 이 `true` 를 반환하면 `GameReloadException` 을 던진다 — `loadGame` 자신은 던지지 않는다"* 로 확정하고, **인게임 로드 경로(`selectGameOption` case 4)에도 던지기를 추가하는 것이 이 장의 변경 범위인지** 명시할 것. 부수적으로 "현재는 인게임 로드가 루프를 되감지 않는다"는 사실을 §1.3 에 선행 결함으로 기록할 것(GROUND_TRUTH §7 의 서술도 이 점에서 부정확하다).

### F-08 `orphans` 가 어느 스키마에도 존재하지 않는다 — §6.1/§6.4 와 §2.1/§5.1 이 모순
- 위치: :713 (`ws.orphans = { … }`), :718 (정책표), §2.1 필드 표(:140-160), §5.1 세이브 예제(:509-565)
- 모순:
  1. §6.1/:713 의사코드는 `ws.orphans` — 즉 **`WorldState` 의 필드**로 쓴다.
  2. :718 정책표는 *"`WorldState` 에는 넣지 않지만 세이브 봉투 옆 `orphans` 블록에 보존한다"* — 반대로 말한다.
  3. §2.1 의 필드 표에 `orphans` 가 **없다**(12필드 전부 "필수 O"). §5.1 의 세이브 v2 전문 JSON 에도 `orphans` 블록이 **없다**.
  4. T-25-02 는 *"12개 필드 전부 fromJson(toJson(x)) == x"* 를 고정한다 — `orphans` 가 13번째 필드가 되면 이 테스트 문구부터 틀린다.
  5. `contentHash()`(§2.3)가 canonical JSON 을 해싱하는데, `orphans` 가 `WorldState` 안에 있으면 **해시 대상**이고 봉투에 있으면 **제외 대상**이다. §8.2 2단계 커밋의 round-trip 검증 결과가 갈린다.
- 요구 조치: `orphans` 를 세이브 **최상위**(`worldState` 밖, `envelope` 옆)에 두는 것으로 확정하고 §5.1 JSON 과 §5.2 차이표에 행을 추가. §6.1 의사코드의 `ws.orphans` 를 `v2.orphans` 로 정정.

### F-09 `pack.json#migrations` 를 BP-21 과 **다른 스키마**로 재정의 — SSoT 파손
- 위치: §7 (:790-805)
- 대조:

| 항목 | BP-21 §7.3 (팩 매니페스트 소유 장) | BP-25 §7 | 
|---|---|---|
| 항목 키 | `{ "from": 1, "to": 2, "steps": [...] }` — **정수 schemaVersion** | `{ "from": "1.2.x", "to": "1.3.0", "ops": [...] }` — **semver 문자열** |
| 스텝 배열 이름 | `steps` | `ops` |
| 스텝 판별 필드 | `kind` | `op` |
| 닫힌 집합 | `rename_id, rename_field, set_default, drop_field, retire_id, remap_enum, split_file` (7) | `rename_flag, rename_var, rename_item, drop_quest, remap_stage, set_default_var` (6) |
| MAJOR 상승 | **무조건 로드 거부** | C-4 `MIGRATE_STRICT` — migration 있으면 적용 |
| 팩 소실 | 상태 드롭 + 경고, 진행 중 퀘스트 있으면 거부 | C-6 `REFUSE_UNLESS_RETIRED` |
| patch 상승 | migrations 적용 | C-2 `COMPATIBLE` — migrations 미적용 |

- 두 스키마는 **키 이름조차 겹치지 않는다.** 빌드가 `steps/kind` 로 쓰고 런타임이 `ops/op` 로 읽으면 마이그레이션이 통째로 무시된다(그리고 D-05 의 "임의 op 는 하드 실패" 정신상 조용히 거부될 것이다).
- 요구 조치: `pack.json` 의 필드는 BP-21 소유다. BP-25 §7 은 **세이브 측 판정 매트릭스(C-1~C-9)만 남기고**, 마이그레이션 스텝 스키마는 BP-21 §7.3 을 링크할 것. MAJOR·patch 정책의 실질적 불일치는 BP-21 과 합의해 한쪽으로 통일해야 한다(현재는 정면 충돌).

### F-10 `WorldStateView` 로는 D-05 의 18개 op 중 5개를 평가할 수 없다
- 위치: §3.2 (:281-320)
- `WorldStateView` 멤버 전량: `schemaVersion, step, seed, hasFlag, getVar, itemCount, questState, questStage, objectiveCounter, isVisited, npcState, packVersion, journalView, flagsView, varsView`.
- D-05 의 op 과 대조:

| op | View 로 답할 수 있나 | 근거 |
|---|---|---|
| `true`/`false`/`and`/`or`/`not` | ✅ | 구조 |
| `flag` | ✅ `hasFlag` | |
| `var_cmp` | ✅ `getVar` | |
| `has_item` | ✅ `itemCount` | |
| `quest_state` / `quest_stage` | ✅ | |
| `visited` | ✅ `isVisited` | |
| `npc_state` | ✅ `npcState` | |
| `chance` | ⚠️ `WorldRng` 별도 인자 (F-05) | |
| **`map_is(mapName)`** | ❌ | View 에 현재 맵 접근자가 **없다**. §5.3 이 *"`map_is` op … 전부 '지금 어느 맵인가' 를 알아야 한다"* 라고 스스로 짚어 놓고 View 에 넣지 않았다 |
| **`gold_cmp`** | ❌ | 골드는 `party.gold`(`party.dart:58`) — BP-27 Q-27-3 이 미해결로 열어 둠 |
| **`party_level_cmp`** | ❌ | 동상 |
| **`party_has_class`** | ❌ | 동상 |
| **`time_of_day`** | ❌ | `WorldState` 에 시간대 필드가 없고 `step` → day/night 변환 규칙도 없다. D-16 이 "시간대"를 1차 스코프 밖 후보로 뒀지만 **op 은 D-05 에서 v1 확정 집합에 들어가 있다** |

- 요구 조치: §3.2 에 `String? get currentMap`, `PartySnapshot get party`(level/class/gold/food 만 담은 순수 값 객체), `TimeOfDay get timeOfDay` 를 추가하고 각각의 갱신 주체·시점을 명시. `time_of_day` 는 `step` 기반 파생 규칙(예: `(step ~/ N) % 2`)을 확정하거나, D-05 확장 없이 "v1 런타임에서는 항상 `day`" 로 못 박고 그 사실을 §11.3 열린 질문이 아니라 **§2 본문 규약**에 쓸 것.

### F-11 §8.2 의 원자성 규약이 §5.3 의 복원 규약과 실행 불가능한 조합이다
- 위치: §8.2 로드 절차 4~6단계(:815-822) vs §5.3 v2 복원 규약(:590 근처)
- §8.2: *"v2 는 **5번 커밋 지점 앞에서는 세션을 절대 건드리지 않는다.**"* (4단계 = 맵 원본 로드 + mapDelta 적용, 5단계 = 커밋 지점)
- §5.3: *"이 경로는 `loadMapFromFile` 과 같은 함수를 타므로 네이티브 스크립트 부착·cm2 페어링·battle 초기화가 전부 따라온다."*
- 실측 — `loadMapFromFile`(`game_session.dart:85-131`)이 **4단계에서 이미 하는 세션 변경**:
  | 줄 | 부작용 |
  |---|---|
  | :87 | `errorMessage` 갱신 |
  | :95 | `HDBattle().init()` — 전투 상태 초기화 |
  | :98 | `setNewMap()` → `map` 교체 + `mapVersion++` + `notifyListeners()` |
  | :100 | `currentMapCm2Path` 교체 |
  | :107 | `HDScriptEngine().loadScript(...)` → `clearRuntimeState()` + **`gameOption.scriptFile` 덮어쓰기**(`script_engine_adapter.dart:108`) |
  | :119 | 직전 맵 스크립트 `onUnload()` |
  | :123-125 | 새 맵 스크립트 생성 + `onPrepare()` + `onLoad()` — `Town1MapScript.onLoad` 는 **party 좌표까지 덮어쓴다**(`town1_map_script.dart:16-25`) |
- 즉 4단계가 실패하면(예: 5단계 이전에 mapDelta 적용에서 던지면) 세션은 이미 **맵·전투·스크립트 엔진·`scriptFile`·파티 좌표**가 바뀐 상태다. "커밋 지점 앞에서 세션을 안 건드린다"는 성립하지 않는다.
- 추가 순서 문제: :107 이 `gameOption.scriptFile` 을 덮어쓴 뒤 6단계에서 저장된 `gameOption` 을 통째로 복원하므로 결과적으로는 맞지만, **두 번 쓰는 순서에 의존**한다. 문서는 이 의존을 명시하지 않았다.
- 요구 조치: 4단계를 **"부작용 없는 맵 원본 파싱"** 과 **"세션 반영"** 으로 쪼갤 것. 전자는 `HDMapNavigation.loadByName` + `HDMapLoader` 만 쓰고(둘 다 세션을 안 건드린다), 후자는 커밋 지점 **뒤**로 옮긴 뒤 `native.currentMapScript` 부착·`loadScript`·`onLoad` 를 명시적으로 재현할 것. `onLoad` 가 파티 좌표를 덮으므로 **좌표 복원은 반드시 `onLoad` 뒤**여야 한다는 순서 제약도 §8.2 에 적을 것.

### F-12 §6.3 "맵 이름 추론" 의 1순위 단서가 현실에서 거의 작동하지 않는다
- 위치: §6.3 표 1행(:700) — *"`gameOption.scriptFile` 이 `assets/MapNNN.cm2` 형태면 → … 확신도 **높음** — 가장 흔한 경로"*
- 실측:
  - `map_navigation.dart:44` 가 `cm2Path = 'Map$idStr.cm2'` 를 **무조건** 설정한다(부록 A-1).
  - `assets/` 에 실제 존재하는 `MapNNN.cm2` 는 **`Map002.cm2`, `Map003.cm2` 두 개뿐**이다(`ls assets/*.cm2` 확인).
  - `HDScriptEngine.loadScript` 는 로드 실패 시 `:98` 에서 **`scriptFile` 갱신 전에 early return** 한다(부록 A-2). 따라서 MapInfos 에 등록된 15개 중 **13개 맵에서는 맵을 옮겨도 `scriptFile` 이 갱신되지 않고 직전 값(대개 `assets/startup.cm2`)이 남는다.**
- 결과: 단서 1은 확신도 "높음"이 아니라 **대부분의 맵에서 오답 또는 무응답**이다. 오답일 경우(직전 맵 이름) §6.3 이 실패를 못 내고 **엉뚱한 맵으로 조용히 복원**한다 — §6.3 이 스스로 금지한 바로 그 실패 양상이다.
- 요구 조치: 단서 1의 확신도를 "낮음(부록 A-1/A-2 로 대부분 스테일)"으로 정정하고, **단서 3(타일 배열 해시)을 1순위로 승격**할 것. 아울러 부록 A-1/A-2 를 §1.3 의 선행 결함 목록에 명시적으로 추가할 것(현재 본 장은 부록 A 를 한 번도 인용하지 않는다).

### F-13 §2.4 의 `step` 증가 트리거가 실제 코드 소유자와 어긋난다 (부록 B-3 미반영)
- 위치: §2.4 표(:238-244)
- 문서 주장: *"파티가 한 칸 이동 완료 → `HDMapNavigation` / 이동 처리 후"*, *"타일 상호작용 1회 종료 → `HDTileEventDispatcher.check` 의 `finally`"*
- 실측: `HDMapNavigation`(`map_navigation.dart` 전 81줄)은 **이름→`MapBundle` 해석기일 뿐 이동과 아무 관련이 없다.** 파티 이동과 타일 상호작용 트리거는 `hadar2026_app/lib/presentation/panels/player_sprite.dart` 의 `update(double dt)`(:103) 폴링 안에 있고, `:193`/`:362`/`:405` 에서 `HDGameMain().checkTileEvent(...)` 를 부른다(GROUND_TRUTH 부록 B-3).
- 파급: 이동마다 `step` 을 올리려면 **presentation 계층에서 `WorldStateMutator` 를 호출**해야 하는데, 그건 D-11 배치·CI 계층 grep 과 정면 충돌한다. 헤드리스 시뮬레이터(D-13)도 이동을 구동할 수 없어 T-25-07/T-27-26 의 결정론 검증이 성립하지 않는다.
- 요구 조치: §2.4 첫 행의 위치를 **"(현재 소유자 없음) — 이동 루프가 `presentation/panels/player_sprite.dart:103` 에 있음. `application/` 으로의 이동 루프 추출이 선결 과제(부록 B-3)"** 로 정정하고, §11.2 "다음 장으로 넘긴 것"에 해당 선결 태스크를 명시할 것.

---

## 개선 제안 (선택)

### S-01 식별자 접두사가 문서 규약 3번을 벗어난다
DECISIONS 「문서 규약」 3 은 `R-<장>-<n> / D-<n> / G-<n> / T-<n> / RK-<n> / Q-<n>` 만 정의한다. 본 장은 `S1~S5`, `INV-1~7`, `EV-1~7`, `C-1~C-9`, `SV-1~5` 를 추가로 쓴다. 특히 **`C-1`~`C-9` 는 GROUND_TRUTH 부록 C 의 `C-1`~`C-4`(세이브/결정론 실측)와 문자 그대로 충돌**한다 — 검수·태스크 추적에서 오독을 유발한다. `SC-1`(save compat) 같이 두 글자 접두사로 바꾸기를 권한다. `T-25-01~27` 은 규약상 "태스크" 접두사와 겹치므로 `TC-25-nn`(test case) 을 권한다.

### S-02 `legacyVarMap` 의 소유 장이 공중에 뜬다
D-04 는 `legacyFlagMap` 만 확정했다. 본 장이 §6.2 에서 `legacyVarMap` 을 도입하고 §11.2 에서 생성 책임을 BP-21/BP-35 로 넘겼는데, **BP-21 에는 `legacyVarMap` 이 한 번도 등장하지 않는다**(`grep` 확인). 넘긴 곳이 받지 않는 상태다. §11.2 에 "BP-21 이 아직 이 필드를 정의하지 않음 — 신설 필요"를 명시하거나, D-04 개정 요청으로 올릴 것.

### S-03 §2.5 크기 추정에 `mapDelta` 와 `envelope` 가 빠져 있다
§2.5 는 `WorldState` 만 계산해 "대 시나리오 193KB" 를 낸다. 그런데 §8.3 SV-1 은 슬롯당 총량을 "60~260KB" 라 하고, `party.players` 6칸(SV-2 이전)과 `gameOption.flags/variables` 512칸 배열(v2 에서도 **유지**, §5.2)이 계산에서 누락돼 있다. `flags: [false×256]` 만으로도 canonical JSON 기준 ~1.6KB, `variables` ~0.8KB 다. 총량 표를 한 줄 추가해 맞출 것.

### S-04 `journal` 상한 500 이 append-only 불변식과 충돌한다
§2.1 은 `journal` 을 *"추가 전용(append-only)"* 이라 하면서 동시에 *"초과 시 앞에서 폐기"* 라 쓴다. 앞을 버리면 append-only 가 아니다. INV-7(`at` 비감소)도 폐기와 무관하게 유지되긴 하나, `contentHash()` 결정론 관점에서는 **"같은 상태"의 정의가 폐기 이력에 의존**하게 된다. Q-25-5 에 이 점을 근거로 추가하거나, "append-only + 링 버퍼(상한 도달 시 head 전진, `journalHead: int` 를 상태에 저장)" 로 확정할 것.

### S-05 자동 저장 트리거와 EV-7 의 상호작용이 미확정
§8.1 은 "퀘스트 스테이지 전이 → 자동 저장(auto)" 을 두고, 바로 아래에 *"자동 저장은 드레인 완료 후(EV-7 이후)에만 한다"* 를 둔다. 그런데 스테이지 전이는 **드레인 한복판**에서 일어난다(§4.3 다이어그램 H→I). 한 드레인에서 스테이지가 3번 전이하면 자동 저장은 몇 번인가? "드레인 종료 후 1회로 병합" 을 명시할 것.

### S-06 §9.1 디버그 커맨드가 19종이라고 §11.1 에 적혀 있으나 표에는 18행
§9.1 표를 세면 `flag set/clear/list, var set, item give/take, quest start/stage/complete/fail/reset, npc state, place visit, warp, state dump, state hash, event fire, seed, step` = 19. 표는 맞고 본문 계산도 맞다 — 다만 `var get` 이 없어 `state dump` 로만 변수를 볼 수 있다. `var get <id>` 추가를 권한다.

---

## 잘된 점

- **§1 현황 서술의 실측 밀도가 매우 높다.** S1~S5 표, `clearRuntimeState` 이중 호출 추적(§1.2 시퀀스), `map_model.toJson()` 의 `events` 누락(부록 C-1) — 코드 인용 23곳 중 19곳이 줄 단위로 정확했다. 특히 §1.2 의 "1차 소실 / 2차 중복 소실" 추적은 실제 코드(`script_engine_adapter.dart:103` + `cm2_script.dart:75`)와 정확히 일치한다.
- **부록 C 4건 중 3건을 정면으로 다뤘다**: C-1(`events` 미저장 → 이름 재로드로 해소, §5.2), C-2(네이티브 스크립트 미부착 → §5.3 근거 3), C-3(570KB → `mapDelta`, §5.4/§8.3). C-4(결정론)는 §2.4 에서 진단하고 BP-27 §9 로 정확히 넘겼다.
- **§4.3 의 이벤트 큐 규칙 EV-1~7 은 이 문서에서 가장 완성도 높은 부분이다.** "Effect 배열 전부 적용 후 드레인"(EV-1), FIFO(EV-2/3), 재진입 금지(EV-5), cascade 8 상한(EV-4)까지 **연쇄 종료가 증명 가능하게** 닫혀 있고, T-25-09~13 이 각 규칙에 1:1 대응한다. 브리프가 물은 "Effect→Effect 연쇄의 종료 보장"에 대한 답이 여기 있다.
- **지연 효과(deferred effect) 분류가 D-05 의 22개 do 를 빠짐없이 덮는다.** §4.4 표의 즉시 19 + 지연 3 = 22 로 D-05 와 정확히 일치한다(BP-27 이 "24개"라 잘못 센 것과 대조된다).
- **§8.2 의 2단계 커밋(스테이징 키 → 검증 → 승격 → 정리)** 은 `SharedPreferences` 에 트랜잭션이 없다는 실제 제약에서 출발한 실용적인 설계이고, T-25-17 로 검증까지 걸어 뒀다.
- **§6.5 "부분 로드 금지"와 폴백 거부 원칙**이 명확하다. "모르겠으니 TOWN1 로 보낸다"를 명시적으로 금지한 것은 `map_navigation.dart:50-52` 의 기존 조용한 폴백 패턴과 대비되는 올바른 판단이다.
- **테스트 27건이 각 규칙에 추적 가능하게 매핑**되어 있고, 골든 픽스처를 "손으로 쓰지 말고 실제 v1 세이브를 떠서 넣어라"고 못 박은 것은 실무적으로 정확한 지침이다.

---

## 다른 장에 전파해야 할 발견

1. **BP-23 / BP-24 / BP-25 의 월드 이벤트 이름 집합이 3파로 갈렸다**(F-03). 세 장 모두 "닫힌 집합" 을 선언했으므로 **어느 하나를 고치는 것으로는 끝나지 않는다.** 메인이 SSoT 소유 장을 지정해야 한다. BP-23 §23.11.4 의 커버리지 증명이 BP-23 집합 위에 서 있으므로 BP-23 을 소유자로 삼는 편이 파급이 적다.
2. **BP-21 §7.3 ↔ BP-25 §7 의 `migrations` 스키마 충돌**(F-09). BP-21 검수자에게도 전달 필요.
3. **BP-23 도 D-08a 미반영**이다 — `23_quest_model.md:617` `startedAt:now`, `:622`/`:625` `updatedAt`. BP-23 검수자에게 전달할 것. `now` 라는 표현은 벽시계를 직접 암시하므로 더 위험하다.
4. **BP-28 R-28-2("티어 0 은 자체 가드를 두지 않는다. `_isScriptRunning` 하나가 유일한 상호배제 지점")** 와 BP-27 §4.2 의 이중 가드가 충돌한다. BP-25 §4.4 는 "`ContentRuntime` 의 상호작용 락"을 전제로 `play_dialogue` 지연 규칙을 세웠으므로 이 결정에 종속된다 — 세 장이 함께 정해야 한다.
5. **`game_session.dart:125` 의 인자 오류**: `native.currentMapScript!.onLoad(bundle.mapName, 0, 0)` 이 `prevMap` 자리에 **새 맵 이름**을 넘긴다. 그래서 `Town1MapScript.onLoad` 의 `if (prevMap == 'GROUND1')` 분기는 영원히 거짓이다. 본 장의 범위는 아니나 §5.3 이 "`loadMapFromFile` 과 같은 함수를 탄다"고 의존을 선언했으므로 BP-28/BP-51 에 선행 버그로 등록할 것.
6. **`assets/maps/` 에 `Map004.json` 이 없다.** `MapInfos.json` 은 TOWN1→id 4 로 매핑하고 `map_navigation.dart:43` 은 `Map004.json` 을 요구하는데, 실제 파일명은 `TOWN1.json` 이다(`json` 오버라이드 필드도 없다). 즉 **TOWN1 은 JSON 로드에 실패하고 "cm2-only 맵"으로 취급된다**(`map_navigation.dart:67`). §6.3 의 맵 이름 추론과 §5.3 의 이름 재로드 전제에 직접 영향이 있으므로 BP-28/BP-35 에서 데이터 정합 태스크로 잡을 것.
7. **부록 B-4(`menu_flows.dart:2` 의 `dart:io`, `:504/:522/:540` 의 `exit(0)`)** 를 본 장이 다루지 않았다. §8.1 의 "앱 백그라운드 전환 → 자동 저장" 은 웹/모바일 전제인데, `dart:io` 가 남아 있는 한 웹 빌드 자체가 위험하다. BP-28/BP-35 에 CI grep 확장(`dart:io`/`dart:html`)을 요청할 것.

---

## 결정 재검토 요청

### RQ-25-A D-05 의 `time_of_day` op 과 D-16 의 "시간대는 1차 스코프 밖" 이 충돌한다
- D-05 는 `time_of_day(value ∈ {day,night})` 를 **v1 확정 op 집합**에 넣었다.
- D-16 은 시간대를 *"선택(권장하되 1차 스코프 밖으로 둘 수 있음)"* 으로 분류했다.
- 그 결과 BP-25 §2.1 의 `WorldState` 에 시간대를 담을 필드가 없고, §3.2 `WorldStateView` 에 조회 창구도 없다(F-10). 콘텐츠 작가가 `time_of_day` 를 쓰면 **빌드는 통과하고 런타임은 항상 거짓**이 된다 — D-02 가 cm2 의 결함으로 지목한 "조용한 오분기"와 같은 양상이다.
- 요청: D-05 에서 `time_of_day` 를 v2 로 미루거나, D-16 의 시간대를 필수로 승격하거나, 둘 중 하나. 결정은 유지한 채 본 문서에는 §11.3 열린 질문으로만 남겨 두었으므로 **본 검수는 결정을 바꾸지 않는다.**

### RQ-25-B D-08 의 `startedAt/updatedAt/at` 문구 자체를 D-08a 로 치환할 것
D-08a 는 파급만 기술하고 D-08 본문의 필드명은 그대로 두었다. 그 결과 BP-25 §2.2 가 "D-08 문구 자체는 유지"(Q-25-1)라는 근거로 벽시계 이름을 남길 여지가 생겼다. D-08 본문의 `startedAt/updatedAt/at` 을 `startedStep/updatedStep/atStep` 으로 직접 고치면 이후 장들의 재발을 막을 수 있다. (본 검수는 기록만 하고 문서를 고치지 않는다.)

---

## 재검수 통과 조건 (체크리스트)

- [ ] F-01 S3/S4 "쓰는 주체" 정정 + `legacy.nativeFlags` 존치 여부 확정
- [ ] F-02 D-08a 10곳 치환 + Q-25-1 종결 처리
- [ ] F-03 이벤트 이름 집합 단일화 (BP-23/24 와 합의)
- [ ] F-04 `Map::Init`/`Map::SetRow` 생성 맵의 세이브 규약 신설
- [ ] F-05 `chance` op 의 순수성 문제 해소 (권장: 무커서 해시 방식)
- [ ] F-06~F-13 반영
- [ ] 재검수 시 §0.1 코드 인용 대조를 다시 수행 (인용 정확도 23/23 목표)
