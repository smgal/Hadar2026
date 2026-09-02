# 검수 보고서 — BP-27 런타임 실행 엔진 설계

- **검수자**: R4 · **대상 파일**: blueprint/27_runtime_engine.md (1555줄)
- **판정**: **수정 필요**
- **점수**: A3 B2 C2 D2 E4 F2 G4 = **19/35** (합격선 26. B/C/D/F 가 2점)

> 이 장은 "구현 착수 문서"다. 축 C(구현 가능성)와 축 E(검증 가능성)를 가장 엄격히 봤다.
> 코드 인용 정확도는 **매우 높다**(§0.1, 26곳 중 22곳 정확). 문제는 사실이 아니라 **계약의 구멍과 인접 장과의 충돌**이다.

## 0. 수행한 기계적 검사 (증거)

| # | 검사 | 결과 |
|---|---|---|
| 1 | 줄 수 | 1555줄 — 최소 250줄 **충족** |
| 2 | 코드 인용 검증 | **26곳** 직접 열어 대조 (§0.1). 22 정확 / 4 오류 |
| 3 | 링크 검증 | 15개 상대 링크. 9개(33/34/35/40/41/42/51/90 등) 미생성이나 OUTLINE 계획 파일 → 허용. 23/24/25/26/28 실재 확인 |
| 4 | 식별자 검증 | **D-05 op/do 개수를 둘 다 틀렸다** — F-05 |
| 5 | 중복 검사 | `_dispatchScripted` before/after 를 BP-28 §2.3 과 중복 서술(결론이 다름). 대화 순회 루프를 BP-24 §24.4 와 중복 서술(선택지 UI 결론이 정반대) |
| 6 | 미확정 표현 grep | 핵심 명세에 "적절히/추후/TBD/등등" **0건**. `:1552` Q-27-5 의 "미정" 은 열린 질문 절이라 허용 |

### 0.1 코드 인용 대조 (26곳)

| 문서 위치 | 주장 | 실측 | 판정 |
|---|---|---|---|
| :131 | `ci.yml:50-75` 계층 grep 잡 | @50-75 정확 | ✅ |
| :529-556 | `tile_event_dispatcher.dart:106-157` before 코드 | @106-157, 구조·문자열 일치 | ✅ |
| :592 | `check` 의 `_dispatchScripted` 호출 @:67 | @67 | ✅ |
| :607 | `finally` autoFlush @:96-103 | @96-103 | ✅ |
| :603 | `pendingNavigation` (HDScriptEngine) | `script_engine_adapter.dart:34` 존재 | ✅ |
| :680 | `_isScriptRunning=false` @`:102` | @102 | ✅ |
| :787 | `beginNarrative` @`tile_event_dispatcher.dart:62` | @62 | ✅ |
| :788 | `clearLogs` @`:64` | @64 | ✅ |
| :789 | SIGN `setHeader` @`:117` | @117 | ✅ |
| :793 | `endNarrative` @`:98` | @98 | ✅ |
| :731 | `ui_host.dart:69` beginNarrative 멱등 | @69 주석 일치 | ✅ |
| :101 | `ui_host.dart:58` 색 태그 주석 | @58 `@X..@@` 주석 | ✅ |
| :438-443 | `hd_game_main.dart:172` bind | @172 | ✅ |
| :445 | `hd_game_main.dart:211` preloadAssets | @211 | ✅ |
| :455 | `hd_game_main.dart:212` session.init | @212 | ✅ |
| :419 | `game_session.dart:69-76` startup 부팅 | @67-77 | ✅ |
| :884-893 | `battle.dart:236-248` gotoEndBattle | @236 시작, 본문 일치 | ✅ |
| :924 | `battle.dart:43` registerEnemy | @43 | ✅ |
| :1218 | `battle.dart` 14곳 `Random()` 줄 목록 | **14곳 전부 일치**(155/174/389/427/432/440/441/474/478/479/488/503/513/514) | ✅ 정밀 |
| :1219 | `menu_flows.dart:104` `Random().nextInt(10)` | @104 | ✅ |
| :1216 | `player.dart:71` 벽시계 데미지 | @71 | ✅ |
| :1084 | `script_engine_adapter.dart:52-61` run 뒤 setPosition | @50 run, @52-61 setPosition | ✅ |
| :1170 | `map_navigation.dart:50-52` 조용한 폴백 | @50-52 | ✅ |
| :1295 | `map_navigation_test.dart:13-28, 66-78, 188-198` | 세 구간 전부 정확 | ✅ 정밀 |
| :925 | `HDBattle` 에 encounter 개념 없음 | `registerEnemy(int)` 뿐 — 사실 | ✅ |
| :28 | "D-05 의 **15개** op" | 실제 **18개** | ❌ F-05 |
| :29 | "D-05 의 **24개** do" | 실제 **22개** | ❌ F-05 |
| :866-870 | `menu_flows.dart:33-43` 인용에 `// 1`~`// 7` 주석 | 원본에 **그 주석 없음** | ⚠️ 축자 인용 아님 |
| :1222 | "`damagedByPoison()` 은 `HDParty.timeGoes()`(`party.dart:249`)" | `timeGoes` 는 @234, :249 는 호출 줄 | ⚠️ 근사 |
| :1244 | "위 grep 은 `lib/application/content/` 만 보므로 `save_manager.dart` 는 걸리지 않는다" | **거짓** — F-06 | ❌ |
| :159 | `grep -E "…(?!foundation)"` | ERE 는 lookahead 미지원, **실행 시 문법 에러** (재현 확인) | ❌ F-06 |

---

## 1. 공개 API 감사표 (필수 산출물)

기준: **사전조건 / 사후조건 / 예외** 셋을 모두 명시했는가, 반환 타입이 정의된 타입인가.
`○` = 명시, `△` = 부분, `✗` = 없음.

### 1.1 `application/content/` — 유스케이스

| # | 클래스 | 메서드 / 멤버 | 사전 | 사후 | 예외 | 반환타입 정의 | 결함 |
|---|---|---|---|---|---|---|---|
| 1 | `ContentRepository` | `load({bundlePath, indexPath})` | ○ | ○ | ○ | — | **A-01** §3.4 와 예외 정책 모순 |
| | | `isLoaded` / `schemaVersion` | ✗ | ✗ | — | ✅ | — |
| | | `report` | ✗ | ✗ | ✗ | ✗ `ContentLoadReport` **미정의** | **A-02** |
| | | `packVersions` | ✗ | △ | ✗ | ✅ | — |
| | | `quest/dialogue/actor/item/place/anchor(String)` | ✗ | △("없으면 null") | ○("절대 던지지 않는다") | △ 모델은 BP-23/24/26 소유 | 사전조건(id 형식 검증 여부) 미정 |
| | | `allQuests` | ✗ | △("정렬된 순서") | ✗ | ✅ | 정렬 키 미명시(id? act?) |
| | | `strings` | ✗ | ✗ | ✗ | ✗ `StringTable` **API 없음** | **A-03** |
| | | `triggers` | ✗ | ✗ | ✗ | ✅ | — |
| | | `legacyFlagMap` / `legacyVarMap` | ✗ | ✗ | ✗ | ✅ | 방향(`flagId→int`) 미명시 |
| | | `reset()` | ✗ | ✗ | ✗ | — | — |
| 2 | `TriggerIndex` | `at(map,x,y)` | △ | ○("없으면 null, O(1)") | ✗ | ✅ | **A-04** BP-26 의 `(map,x,y,kind)`→List 모델과 충돌 |
| | | `forMap(map)` | ✗ | △("id 정렬") | ✗ | ✅ | — |
| | | `bindingsOf(placeId)` | ✗ | ✗ | ✗ | ✗ `PlaceBinding` **미정의** | **A-02** |
| | | `watchers(WorldEventType)` | ✗ | ✗ | ✗ | ✗ `ObjectiveRef` **미정의** | **A-02** |
| | | `anchorCount` / `objectiveWatcherCount` | ✗ | ✗ | — | ✅ | — |
| 3 | `WorldEventBus` | `publish(WorldEvent)` | ✗ | ○(EV-5/EV-6 반영) | ✗ | — | `WorldEvent` 생성자 목록 미정의 |
| | | `drain()` | ✗ | ○ | ○("던지지 않는다") | — | **A-05** `Future` 인데 UI 재진입 규약이 Q-27-7 로 미결 |
| | | `isDraining` / `pendingCount` | ✗ | ✗ | — | ✅ | — |
| | | `subscribe/unsubscribe` | ✗ | ✗ | ✗ | — | 중복 구독·순서 규약 없음 → **결정론 위험** |
| | | `maxCascadeDepth = 8` | — | — | — | ✅ | — |
| 4 | `WorldEventSubscriber` | `onWorldEvent(e, mutator)` | ○ | ○("직접 drain 금지") | ✗ | — | 구독자 예외 정책은 §8.1 에만 |
| 5 | `DialogueRuntime` | `run(d, {state, host, trace})` | ○ | ○ | ○(`GameReloadException` 만 전파) | △ | `DialogueTrace` **미정의**(A-02) |
| | | `isRunning` / `reset()` | ✗ | ✗ | — | ✅ | — |
| 6 | `DialogueResult` | 4필드 | — | — | — | ✗ `DeferredEffect` **미정의** | **A-02** |
| 7 | `QuestRuntime` | `start(id, state, {ignorePrerequisites})` | ✗ | ○ | ✗ | ✅ bool | `startedAt` → D-08a 위반(F-01) |
| | | `advance(id, stageId, state)` | ○("active") | ○ | ✗ | ✗ `DeferredEffect` | 사전조건 위반 시 동작 미정 |
| | | `complete/fail(id, state)` | ✗ | ✗ | ✗ | ✗ | **A-06** 계약 완전 부재 |
| | | `onWorldEvent(e, state)` | △ | ✗ | ✗ | — | 카운터 delta 산출 규칙 없음(F-07) |
| | | `activeJournal(view)` | ✗ | ✗ | ✗ | ✗ `QuestJournalView` **미정의** | **A-02** |
| 8 | `ContentRuntime` | `boot()` | ✗ | ✗ | ○(`ContentLoadException`) | — | **A-01** §3.4 와 모순 |
| | | `isReady` | ✗ | ✗ | — | ✅ | — |
| | | `state` | ✗ | ✗ | ✗ | ✅ `MutableWorldState` | **A-07** BP-25 §3.4 "두 얼굴 중 하나만" 을 정면으로 어긴다 |
| | | `adoptState(s)` | ✗ | ✗ | ✗ | — | 기존 상태 폐기/이벤트큐 처리 미정 |
| | | `handleTile({...6인자})` | ○ | ○ | ○ | ✅ bool | `action` 인자를 어디에도 안 쓴다(A-04) |
| | | `onMapEntered(map,x,y)` | ✗ | △ | ✗ | — | **A-08** §3.1 과 §7.4 가 이중 호출을 만든다 |
| | | `playDialogue(id, host)` | ✗ | ✗ | ✗ | ✅ | 락 획득 여부 미정 |
| | | `isInteracting` | ✗ | ✗ | — | ✅ | **A-09** BP-28 R-28-2 와 충돌 |
| | | `pendingNavigation` (가변 public 필드) | ✗ | ✗ | ✗ | ✗ `PendingWarp` **미정의** | **A-02** + 소비 주체 미정 |
| | | `reset()` | ✗ | ✗ | — | — | — |
| 9 | `HDEffectBridge` | **메서드 0개** | ✗ | ✗ | ✗ | ✗ | **A-10 치명** — §1.2/§1.3/R-27-2 가 존재를 선언했으나 **시그니처가 문서 어디에도 없다** |
| 10 | `HDDebugCommands` | **메서드 0개** | ✗ | ✗ | ✗ | ✗ | BP-25 §9 가 커맨드 문법만 정의. 등록/파싱 API 없음 |

### 1.2 `domain/content/` — 순수 데이터 + 평가기

| # | 타입 | 멤버 | 사전 | 사후 | 예외 | 결함 |
|---|---|---|---|---|---|---|
| 11 | `ConditionEvaluator` | `evaluate(c, view, {rng})` | ○ | ○ | ○ | **F-04** 순수성 주장과 `rng` 부작용 모순 / **F-08** 5개 op 평가 불가 |
| | | `referencedIds(c)` | ✗ | ✗ | ✗ | 반환 `Set<String>` ✅ | — |
| 12 | `EffectApplier` | `apply(effects, mutator, {rng})` | ○ | ○ | ○ | 반환 `List<DeferredEffect>` 미정의(A-02) |
| | | `referencedIds(effects)` | ✗ | ✗ | ✗ | — | — |
| 13 | `WorldRng` | `nextInt(max)` | ○ | ○ | ✗ | **F-09** `stream()` 과 단일 `rngCursor` 가 모순 |
| | | `stream(String label)` | ✗ | ✗ | ✗ | ✗ | **F-09 치명** — 커서 분리가 불가능 |
| 14 | `WorldEvent` / `WorldEventType` | — | ✗ | ✗ | ✗ | ✗ | 11종이라 했으나 BP-23 은 12종·다른 이름(F-02) |
| 15 | `StringTable` | — | ✗ | ✗ | ✗ | ✗ | A-03 |
| 16 | `ContentId` / `IdKind` / `IdError` | — | ✗ | ✗ | ✗ | ✗ | 이름만 존재 |
| 17 | `Condition`/`ConditionOp`, `Effect`/`EffectDo` | — | — | — | — | — | BP-90 로 위임 — 허용 |
| 18 | `Anchor` / `AnchorKind` | — | — | — | — | — | BP-26 소유 — 허용. 단 R-27-6 이 요구하는 `fallback` 필드가 **BP-26 에 없다**(F-03) |

**요약**: 시그니처가 제시된 클래스 **11개**, R-27-2 가 12개라고 주장하나 `HDEffectBridge` 는 **0개 메서드**. 반환 타입 중 **8개가 이름만 있는 미정의 타입**(`ContentLoadReport`, `ContentLoadException`, `PlaceBinding`, `ObjectiveRef`, `QuestJournalView`, `PendingWarp`, `DeferredEffect`, `DialogueTrace`). 사전·사후·예외 3종이 모두 명시된 메서드는 **6개**(`ContentRepository.load`, `WorldEventBus.drain`, `DialogueRuntime.run`, `ContentRuntime.handleTile`, `ConditionEvaluator.evaluate`, `EffectApplier.apply`)뿐이다. 나머지 40여 멤버는 계약이 비어 있다.

---

## 치명 결함 (반드시 고쳐야 함)

### F-01 D-08a 미반영 — `startedAt` / `updatedAt` / `at` 이 8곳 남아 있다
| # | 줄 | 현재 | 치환 |
|---|---|---|---|
| 1 | :346 | `startedAt == state.step` (`QuestRuntime.start` 사후조건) | `startedStep == state.step` |
| 2 | :352 | `updatedAt 갱신` (`advance` 사후조건) | `updatedStep` |
| 3 | :828 | 흐름도 Z2 `updatedAt 갱신 후 종료` | `updatedStep` |
| 4 | :866 | 저널 append `at: step` (퀘스트 시작) | `atStep: step` |
| 5 | :867 | 동상 (스테이지 전이) | `atStep` |
| 6 | :868 | 동상 (완료) | `atStep` |
| 7 | :869 | 동상 (실패) | `atStep` |
| 8 | :870 | 동상 (`journal` 효과) | `atStep` |

DECISIONS D-08a: *"퀘스트/저널의 시각 필드는 전부 이 `step` 을 기록한다(`startedStep`, `updatedStep`, `atStep`)"*. BP-25 와 합쳐 **총 18곳**이 미반영이다.

### F-02 월드 이벤트 이름 집합이 BP-23·BP-24 와 충돌 — 티어 0 의 핵심 배선이 갈라진다
- 위치: :35 (`world_event.dart` = "BP-25 §4.2 의 11종"), :665 `publish(talked_to)`, :476 `publish(entered_place)`, :769 `publish(choice_made{...})`, §7.1 `WorldEvent.battleWon(...)`, §7.5 `WorldEvent.itemGained(itemId:, count:, total:)`
- 대조:

| BP-27 이 쓰는 이름 | BP-23 §23.11.1 "v1 확정 닫힌 집합" | BP-24 §24.4 | 판정 |
|---|---|---|---|
| `talked_to` | `talk` | — | ❌ |
| `entered_place` | `enter_place` | — | ❌ |
| `choice_made` | `dialogue_choice` | `dialogue_choice` (24_dialogue_model.md:464) | ❌ **BP-27 만 다름** |
| `battle_won{…, count}` | `battle_won{…, map, x, y}` | — | ⚠️ payload |
| `itemGained(count:)` | `item_gained{delta}` | — | ⚠️ 필드명 |
| (없음) | `step_tile`, `map_changed`, `gold_changed`, `party_rested` | — | ❌ 4종 누락 |

- BP-23 §23.11.1 은 이 집합의 발행처를 **`lib/application/content/world_event_bus.dart` (= 이 장이 설계하는 파일)** 로 지정했다. 즉 두 장이 같은 파일의 API 를 다르게 정의한다. §23.11.4 의 objective 커버리지 증명도 BP-27 의 집합으로는 성립하지 않는다.
- 요구 조치: 이름 집합의 SSoT 를 한 장으로 지정하고 나머지는 링크. BP-27 §1.1 의 "11종" 서술을 그 장으로 대체할 것.

### F-03 앵커 조회 모델이 BP-26 과 정면 충돌 — `TriggerIndex.at()` 시그니처로는 BP-26 의 콘텐츠를 표현할 수 없다
- 위치: :222-224 (`Anchor? at(String map, int x, int y)` — *"한 좌표에 앵커가 둘 이상이면 빌드가 hard-fail 하므로(BP-33) 런타임은 1개를 전제한다"*), :505 §3.4 (*"앵커 좌표 충돌(한 칸에 2개) … id 정렬 첫 번째만 채택 + 경고"*)
- BP-26 의 실제 규정:
  - 인덱스 키가 `(map, x, y, **kind**)` 이고 값이 **배열**이다 — `26_entity_registry_and_anchors.md:410-417` 의 인덱스 예제가 `"61,82": { "event": ["anchor.core.town1_crypt_secret", "anchor.gen_ep1.crypt_scholar_clue"] }` 처럼 **한 좌표에 2개**를 담는다.
  - `R-26-17`: 같은 좌표+kind 에 앵커가 여럿인 것은 **에러가 아니라 기능**이다(`when` 으로 조건 선택). 하드 실패는 "모두 `when` 을 생략했을 때"뿐.
  - `R-26-18`: 같은 좌표의 **다른 kind** 앵커는 자유롭게 공존한다.
- 파급:
  1. `Anchor? at(map,x,y)` 는 kind 를 구분할 수 없고 다중 앵커를 반환할 수 없다. **팩 합성(D-03)으로 core 위에 gen_ep1 을 얹는 시나리오가 런타임에서 죽는다.**
  2. §3.4 의 "id 정렬 첫 번째만 채택 + 경고"는 BP-26 이 **의도한 콘텐츠를 조용히 버린다** — 이 장 §8.2 가 스스로 금지한 "조용한 실패"에 해당한다.
  3. `handleTile` 이 `action: HDTileAction` 를 인자로 받으면서 **본문 설명 어디에서도 쓰지 않는다**(:392-404, §4.4 시퀀스). BP-26 §3.3 은 kind↔`HDTileAction` 대응표를 갖고 있으므로 여기가 연결점이어야 한다.
- 요구 조치: `List<Anchor> at(String map, int x, int y, HDTileAction action)` 또는 `Anchor? resolve(map, x, y, action, WorldStateView)` 로 바꾸고, `when` 평가 + `priority`(BP-26:145) 정렬 규칙을 §4.3 에 명시할 것. §3.4 의 "좌표 충돌" 행은 삭제하고 BP-26 R-26-17 의 실제 하드 실패 조건으로 대체할 것.
- 추가: **R-27-6 이 요구하는 앵커의 `fallback` 필드가 BP-26 의 공통 필드 표(:136-147)에 없다.** BP-26 검수자와 합의해 필드를 신설하거나 R-27-6 을 다른 방식(대화의 기본 진입 노드 — BP-24 DV-01 이 이미 "마지막 entry 는 `when` 없음"을 하드 게이트로 강제)으로 바꿔야 한다. 후자가 중복이 없다.

### F-04 `ConditionEvaluator.evaluate` 의 "순수 함수" 주장이 `WorldRng` 와 모순 (BP-25 R-25-5 파괴)
- 위치: :266-277 (§2.4) + :1203-1213 (§9.2)
- 문서 주장: *"순수 함수 — `[state]` 를 변경하지 않는다 / 사후조건: 같은 `(c, state, rng 커서)` 에 대해 항상 같은 결과"*
- 실제: `WorldRng.nextInt(max) => _state.nextRandom(max)` 이고 `_state` 의 타입은 **`WorldStateMutator`** (:1208). BP-25 §3.3(:378-379, :392)은 `nextRandom` 이 **`rngCursor` 를 증가시킨다**고 못 박았다.
  → `chance` op 이 있는 Condition 을 평가하면 **`WorldState` 가 바뀐다.** 사후조건의 "rng 커서" 를 괄호에 넣은 것이 곧 순수성이 깨졌다는 자백이다.
- 파급:
  - BP-25 R-25-5(*"Condition 평가는 상태를 바꿀 수 없다"*)와 T-25-08(*"View 만으로는 상태를 바꿀 수 없다 … 스냅샷 해시로 검증"*)이 무너진다.
  - D-13 의 `QuestSolver` 는 상태를 노드로 두고 탐색한다. 탐색 중 조건 평가마다 커서가 밀리면 **탐색 자체가 상태를 오염**시킨다 — BP-25 §3.1 이 View/Mutator 를 나눈 첫 번째 이유가 무효화된다.
  - `DialogueRuntime.run` 의사코드(:702, :745)가 **조건 평가마다 `rng` 를 넘긴다.** 선택지가 6개면 6번 밀린다.
- 요구 조치: `chance` 를 **커서를 소비하지 않는 결정론적 해시**로 재정의할 것 — `chance(p) := splitmix64(seed, step, conditionSitePath) % 100 < p`. 이러면 `WorldStateView` 만으로 평가 가능하고, 같은 스텝의 같은 조건은 항상 같은 값이며(Q-27-4 의 save-scumming 논의도 그대로 유지), 솔버는 양 분기를 자유롭게 탐색할 수 있다. `WorldRng`(커서 소비형)는 **Effect 와 전투 전용**으로 한정할 것.

### F-05 D-05 의 op/do 개수를 둘 다 틀렸다 (식별자 검증 실패)
- 위치: :28 *"D-05 의 **15개** op"*, :29 *"D-05 의 **24개** do"*
- 실측(DECISIONS.md D-05 원문 계수):
  - op = `true,false,and,or,not`(5) + `flag,var_cmp,has_item,quest_state,quest_stage,party_has_class,party_level_cmp,gold_cmp,map_is,visited,npc_state,time_of_day,chance`(13) = **18**
  - do = `set_flag,clear_flag,set_var,add_var,give_item,take_item,add_gold,add_food,start_quest,advance_quest,complete_quest,fail_quest,set_npc_state,warp,change_tile,start_battle,play_dialogue,journal,heal_party,grant_exp,set_encounter,unlock_place` = **22**
- 교차 확인: BP-25 §4.4 의 즉시효과 19 + 지연효과 3 = 22 로 **BP-25 는 정확하다**. BP-27 만 틀렸다.
- 왜 치명인가: 이 숫자는 `ConditionEvaluator` / `EffectApplier` 의 **switch 완전성 테스트의 기준**이 된다. 15/24 로 착각하면 `map_is`·`time_of_day`·`party_has_class` 처리 누락이 리뷰를 통과한다. 실제로 F-08 이 그 결과다.
- 요구 조치: 개수를 쓰지 말고 **"D-05 가 확정한 op 전량 / do 전량"** 으로 표현하고, §10 에 "op·do 열거형이 D-05 목록과 1:1 임을 고정하는 테스트"(`test/domain/content/dsl_coverage_test.dart`)를 추가할 것.

### F-06 §1.4 와 §9.3 이 제안한 CI grep 두 개가 **둘 다 동작하지 않는다**
- 위치: :158-161, :1236-1244
- (a) `:159` — `check "domain/content must stay Flutter-free beyond foundation" -E "^import 'dart:io'|package:flutter/(?!foundation)" lib/domain/content/`
  - `-E`(ERE)는 **negative lookahead `(?!…)` 를 지원하지 않는다.** 실제로 실행하면 문법 에러로 죽는다:
    ```
    $ grep -rnE "package:flutter/(?!foundation)" lib/domain/
    ugrep: error: error at position 22 … invalid syntax
    ```
    (GNU grep 도 동일하게 실패한다.) `-P` 로 바꾸거나 `package:flutter/(material|services|widgets|cupertino)` 화이트리스트 반전으로 다시 쓸 것.
- (b) `:1238` — `check "…must not read the wall clock" -E "DateTime\.now\(\)" lib/domain/ lib/application/content/` 와 :1244 의 *"위 grep 은 `lib/application/content/` 만 보므로 `save_manager.dart` 는 걸리지 않는다"*
  - `ci.yml:54-65` 의 `check()` 헬퍼는 **검색 경로가 하드코딩**돼 있다: `hits="$(grep -rn "$@" lib/application/ lib/domain/ || true)"`. 인자로 넘긴 경로는 **추가**될 뿐 범위를 좁히지 못한다. 결과 경로는 `lib/domain/content/ lib/application/ lib/domain/` 의 합집합이다.
  - 따라서 §7.3 이 새로 넣는 `save_manager.dart` 의 `DateTime.now().toUtc()`(envelope) 는 **반드시 걸린다.** :1244 의 안심 문장은 거짓이다.
  - 부수적으로, 이 게이트를 그대로 넣으면 `player.dart:71` 때문에 **DT-1 이 끝나기 전까지 CI 가 빨갛다**(레포 전체에서 `DateTime.now()` 는 이 한 곳뿐임을 확인했다).
- 요구 조치: `check()` 를 경로 인자를 받도록 고치는 **ci.yml 변경 자체를 §9.3 의 태스크에 포함**시키고, DT-7 의 실행 순서를 "DT-1 완료 후"로 못 박을 것. 예외 처리는 grep 패턴이 아니라 `--exclude=save_manager.dart` 로 명시할 것.

### F-07 `battle_won` → `defeat` 카운터의 증가량(delta) 규칙이 어디에도 없다
- 위치: §4.2 이벤트 payload(:436 BP-25), §6.1 흐름도 `counters[objId] += delta`(:836), §7.1 `WorldEvent.battleWon(encounterId:, enemyIds:, count: enemies.length)`
- 문제:
  - `count: enemies.length` 는 "이 전투에 등장한 적 수"다. 목표가 `defeat(enemyId: 12, count: 3)` 일 때, 오크 2 + 고블린 1 을 잡은 전투에서 `count=3` 을 그대로 더하면 **오크 3마리를 잡은 것으로 기록된다.**
  - `enemyIds` 는 있지만 **중복 개수를 세는 규칙이 없다.** `[12,12,7]` 에서 12 가 2 라는 것을 누가 계산하는가?
  - `encounterId` 목표와 `enemyId` 목표가 **동시에 매칭될 때**의 처리도 없다.
- 또한 GROUND_TRUTH **B-2 가 이 장에 명시적으로 위임한 결정이 이행되지 않았다**: `battle.dart:27` 은 `1:Win, 0:Lose, 2:Run away` 인데 `assets/const.cm2:53-55` 는 `EVADE=0, WIN=1, LOSE=2` 로 **0과 2가 뒤바뀌어 있다**. §7.1 은 `_battleResult == 1` 분기에만 훅을 걸고 이 불일치를 언급조차 하지 않았다. 패배/도주를 구분하는 퀘스트(실패 조건, `fail_quest`)를 설계하는 순간 바로 터진다.
- 요구 조치:
  1. `battle_won` payload 를 `{encounterId?, defeated: Map<enemyId,int>}` 형태로 바꾸고 매칭 규칙(`counters[obj] += defeated[params.enemyId] ?? 0`)을 §6.1 에 확정.
  2. `battle_lost` / `battle_fled` 이벤트를 신설하거나, 신설하지 않는 이유를 명시.
  3. **B-2 의 정본을 이 장에서 결정**하고(권장: Dart 를 정본으로 두고 `const.cm2` 상수를 고치는 태스크를 BP-28 에 등록), §7.1 에 표로 남길 것.
- 부수: §4.2 의 `turn_survived`(objective `survive` 대응)는 **§7 의 훅 5곳 어디에도 발행처가 없다.** R-27-10 이 "훅 5곳 확정"이라 했으나 카탈로그를 다 덮으려면 최소 1곳이 더 필요하다. BP-23 은 `survive ← step_tile` 로 아예 다른 이벤트를 쓴다(F-02).

### F-08 `WorldStateView` 로 평가 불가능한 D-05 op 이 5개인데, 이 장이 그중 3개만 열린 질문으로 남겼다
- 위치: Q-27-3(:1550) — `gold_cmp` / `party_level_cmp` / `party_has_class` 만 다룬다.
- 남은 2개:
  - **`map_is(mapName)`** — `WorldStateView`(BP-25 §3.2)에 현재 맵 접근자가 없다. BP-25 §5.3 이 *"`map_is` op … 전부 '지금 어느 맵인가'를 알아야 한다"* 라고 짚었는데 두 장 모두 창구를 만들지 않았다. `HDGameSession().currentMapName` 을 직접 읽으면 `domain/content` 가 `application/` 을 import 하게 되어 **D-11 배치가 깨진다**.
  - **`time_of_day(day|night)`** — `WorldState` 에 시간대 필드가 없고 `step → day/night` 변환 규칙도 없다. 현재 설계로는 항상 거짓/기본값이 되어 **D-02 가 cm2 의 결함으로 지목한 "조용한 오분기"가 그대로 재현**된다.
- 요구 조치: Q-27-3 의 잠정안(`partySnapshot`)을 **§2.8 의 정식 계약으로 승격**하고 `currentMap`·`timeOfDay` 를 포함시킬 것. "런타임이 매 평가 전에 갱신" 이라는 갱신 주체·시점을 §4.2/§7.4 의 어느 지점인지 못 박아야 구현 가능하다.

### F-09 `WorldRng.stream(label)` 은 단일 `rngCursor` 위에서 구현 불가능하다
- 위치: :1214-1216 — *"결정론적 스트림 분기. 같은 `(seed, cursor, label)` → 같은 값. 전투와 퀘스트가 서로의 커서를 밀지 않게 할 때 쓴다."* / Q-27-4 의 잠정안이 여기에 의존한다.
- 모순: BP-25 §2.1 의 `WorldState` 에는 `rngCursor` 가 **하나뿐**이다(:160). `stream(label)` 이 반환한 `WorldRng` 도 결국 `_state.nextRandom()` 을 부르므로 **같은 커서를 민다.** "서로의 커서를 밀지 않게" 가 성립하지 않는다.
- 요구 조치: 둘 중 하나 —
  (a) `WorldState.rngCursors: Map<String,int>`(라벨별 커서)로 바꾸고 BP-25 §2.1/§2.3/T-25-02 를 함께 고친다. 직렬화 정렬 규칙도 추가.
  (b) `stream(label)` 을 **커서를 전혀 쓰지 않는** 순수 함수 `roll(label, step, n) := splitmix64(seed, step, label) % n` 으로 정의하고, 커서 소비형 `nextInt` 는 전투 내부에서만 쓴다.
  (b) 를 권장한다 — F-04 의 해법과 같은 도구를 쓴다.

### F-10 `HDEffectBridge` 가 이름만 있고 API 가 전무하다 — 지연 효과 실행 경로 전체가 미정의
- 위치: :51(§1.2), :72/:123(§1.3), R-27-2(:1518)
- `HDEffectBridge` 는 `warp` / `start_battle` / `heal_party` / `grant_exp` / `change_tile` 을 세션·전투·맵에 연결하는 **유일한 클래스**로 지정돼 있는데, **메서드가 하나도 없다.**
- 그 결과 다음이 전부 미정이다:
  - `warp(map,x,y)` 가 `HDGameSession.loadMapFromFile` 을 부르는가, `HDScriptEngine.pendingNavigation` 을 세우는가, `ContentRuntime.pendingNavigation`(:409)을 세우는가? §4.4 시퀀스(:674)는 세 번째처럼 보이지만 **누가 소비하는지**가 없다. `HDScriptEngine.executePendingNavigation()`(`script_engine_adapter.dart:39`)에 대응하는 함수가 필요하다.
  - `start_battle(encounterId)` 가 `HDBattle.init/registerEnemy/start` 를 어떤 순서로 부르는가? encounter → 적 목록 해석은 누구 책임인가(BP-40 로 넘겼지만 브리지 시그니처는 이 장 소관)?
  - `change_tile(map?,x,y,tile)` 이 **현재 맵이 아닌 맵**을 지정했을 때(스키마상 `map?` 이 있으므로 가능) 어떻게 처리하는가? 로드되지 않은 맵의 타일 변경은 `mapDelta`(BP-25 §5.4)에 담기지 않는다 — **저장 손실**이다.
  - `heal_party(percent)` / `grant_exp(amount)` 가 `HDParty`/`HDPlayer` 의 어느 메서드를 타는가?
- 요구 조치: §2.8 뒤에 `HDEffectBridge` 절을 신설하고 5개 do 각각에 대해 (사전조건 / 부작용 / 실패 시 동작 / 어느 훅에서 호출되는가)를 표로 확정할 것. R-27-2 의 "12개" 주장은 그때까지 거짓이다.

---

## 중요 결함

### F-11 §3.1 부팅 시퀀스와 §7.4 패치가 `onMapEntered` 이중 호출을 만든다
- §7.4 는 `loadMapFromFile` **안**에서 `await ContentRuntime().onMapEntered(bundle.mapName, party.x, party.y)` 를 부르게 한다(:1076-1080).
- §3.1 세이브 복원 분기는 `SV->>S: loadMapFromFile(currentMapName) + mapDelta 적용` → `SV->>CR: adoptState(...)` → `SV->>CR: onMapEntered(currentMapName, x, y)` 순서를 그린다(:481-486).
- 두 개를 합치면 로드 시 **`onMapEntered` 가 2번** 불리고, 첫 번째는 **`adoptState` 이전(= 구 WorldState)** 에서 `entered_place` 를 발행하고 드레인한다. 구 상태의 퀘스트가 진행되고, 그 진행은 곧바로 `adoptState` 로 폐기된다 — 이벤트 유실과 예측 불가한 부작용이 동시에 생긴다.
- §3.2 표는 *"맵 로드 중 `onMapEntered` 가 발행되면 안 되므로, 로드 시에는 알림을 억제"* 라고 했으나 **억제 수단이 §7.4 패치에 없다.** Q-27-5 가 `suppressMapEnterNotification` 을 잠정안으로 두었을 뿐이다.
- 요구 조치: Q-27-5 를 열린 질문에서 빼고 **§7.4 패치에 억제 플래그를 명시적으로 포함**시킬 것(`if (!suppressMapEnterNotification) await ContentRuntime().onMapEntered(...)`). 설정/해제 지점을 `HDSaveManager.loadGame` 의 커밋 지점 기준으로 못 박을 것.

### F-12 `ContentRepository.load()` 의 예외 계약이 §3.4 실패 처리와 모순 — T-27-02/03/24 가 동시에 통과할 수 없다
| 위치 | 서술 |
|---|---|
| :181 | `load()` 예외: `ContentLoadException` (**파일 없음** / 파싱 실패 / schemaVersion 불일치 / 참조 깨짐) |
| :377 | `ContentRuntime.boot()` 예외: `ContentLoadException` |
| :500 (§3.4) | 번들 파일 없음 → *"**콘텐츠 티어 비활성**으로 계속 진행"* |
| T-27-02 | *"번들이 없으면 **예외 대신** 비활성 상태로 끝난다"* |
| T-27-24 | *"bind 전에 boot 하면 **StateError 가 난다**"* |

- 던지는가 안 던지는가가 정반대다. 게다가 "파일 없음"을 삼키는 구현이면 **`HDHosts` 미바인드 시의 `StateError`(`host_binding.dart:31`)도 같이 삼켜져** T-27-24 가 실패한다(둘 다 `HDHosts().assets` 접근 지점에서 발생한다).
- 요구 조치: `load()` 를 *"에셋 부재는 `report` 에 기록하고 정상 반환. 파싱 실패·스키마 불일치·참조 깨짐만 `ContentLoadException`. `StateError`(미바인드)는 잡지 않고 전파"* 로 확정하고, §2.1 주석·§3.4 표·T-27-02/03/24 를 일치시킬 것.

### F-13 `ContentRuntime.state` 가 BP-25 §3.4 의 "금지 규칙"을 정면으로 어긴다
- :381 `MutableWorldState get state;  // 유일한 소유자`
- BP-25 §3.4: *"**금지 규칙**: `MutableWorldState` 필드에 외부에서 직접 접근하는 코드를 두지 않는다. `ContentRuntime` 이 **두 얼굴 중 하나만 넘기는 것**이 유일한 접근 경로다."*
- 그런데 `state` 는 두 얼굴을 다 가진 구현체를 public getter 로 내준다. 실제로 이 장이 그렇게 쓴다 — §7.2 `QuestRuntime().activeJournal(ContentRuntime().state)`(:880), §10.1 테스트 `ContentRuntime().state.hasFlag(...)`(:1478). 저널 UI(presentation)가 `ContentRuntime().state` 를 잡으면 **UI 가 상태를 쓸 수 있다**(BP-25 §3.4 표는 저널 UI 에 `WorldStateView` 만 주라고 못 박았다).
- 요구 조치: `WorldStateView get view;` 를 공개하고 `MutableWorldState` 는 **private**(`_state`)로 감출 것. `adoptState`/`HDSaveManager` 용으로는 `MutableWorldState get stateForPersistence` 처럼 이름으로 의도를 드러내거나, 직렬화 메서드만 노출할 것.

### F-14 §4.2 의 이중 재진입 가드가 BP-28 R-28-2 와 정면 충돌
- :581 `+    if (ContentRuntime().isInteracting) return;` / Q-27-2 잠정 *"두 개 유지"*
- BP-28 §3(`28_migration_and_coexistence.md:313`): **R-28-2** *"티어 0 은 자체 가드를 두지 않는다. `_isScriptRunning` 하나가 유일한 상호배제 지점이다. **가드를 이중화하면 해제 순서 버그가 생긴다.**"*
- BP-28 은 같은 절에서 보호 범위(`check()` 진입 ~ `endNarrative()` 완료)와 해제 지점(`finally`)까지 확정하고 `INV-20-16` 으로 테스트를 고정했다. BP-27 의 T-27-10 과 목적은 같지만 **수단이 반대**다.
- 참고로 현재 코드에서 `_isScriptRunning`(`tile_event_dispatcher.dart:46-48`)은 `check()` 전 구간을 이미 덮으므로 `isInteracting` 가드는 `check()` 경로에서 **도달 불가능한 죽은 코드**다(메뉴/저널에서 `playDialogue` 를 부를 때만 의미가 생긴다). BP-28 쪽이 더 정확하다.
- 요구 조치: BP-28 R-28-2 를 따르고 §4.2 의 가드 1줄을 제거하거나, `isInteracting` 을 `_isScriptRunning` 의 **읽기 전용 미러**로 정의할 것. Q-27-2 는 열린 질문이 아니라 이미 BP-28 이 결정한 사항이다.

### F-15 대화 선택지 UI 가 BP-24 의 명시적 결정과 반대다
- BP-27 §5.1(:757) `picked = await host.showWindowMenu(items)`, §5.2 표 6행 `showWindowMenu(items)`(:791)
- BP-24 §24.4.3(`24_dialogue_model.md:471`): **"`showMenu` vs `showWindowMenu` — `showMenu` 채택"**. 근거까지 붙어 있다 — *"문맥 보존이 대화의 본질이다. `showWindowMenu` 는 그 대사를 창으로 덮는다. `select.dart:31-35` 의 주석이 이미 같은 판단을 코드에 남겨 뒀다"*. `:401` 은 `showWindowMenu` 를 **"쓰지 않는 것"** 목록에 넣었다(타일 상호작용 밖에서만 예외).
- 두 장이 같은 런타임 루프(`dialogue_runtime.dart`)를 서로 다르게 규정한다. §5.2 의 "UiHost 호출 순서 규약" 은 T-27-13 이 **페이크 UiHost 의 호출 기록으로 고정**하는 대상이므로, 이 불일치는 그대로 테스트 실패로 이어진다.
- 요구 조치: BP-24 가 대화 UI 의 소유 장이므로 BP-27 §5.1/§5.2 를 `showMenu` 로 맞추고, 타일 밖 호출(`playDialogue`)의 분기 규칙(BP-24:491-496)을 링크할 것.

### F-16 `choiceOnceFlag()` 가 정의되지 않았고, 만들어내는 id 가 D-04 문법을 위반한다
- 위치: :747, :765 — `state.view.hasFlag(choiceOnceFlag(d.id, node.id, c))` / `state.setFlag(choiceOnceFlag(d.id, node.id, chosen))`
- 문제:
  1. `choiceOnceFlag` 의 정의가 문서 어디에도 없다.
  2. 어떤 규칙으로 만들든 결과는 `flag.<pack>.<domain>.<name>` (D-04) 형식을 만족하기 어렵다. `dlg.gen_ep1.guard_intro` + `n1` + `c_ask` 를 이어 붙이면 슬러그 길이 제한(3~48자)도 넘긴다.
  3. 그 플래그들이 `WorldState.flags` 에 들어가면 **세이브에 영구 누적**되고, BP-25 §6.4 의 orphan 처리·`legacyFlagMap` 역참조·§2.5 크기 추정(플래그 1개 ~46바이트)에 전부 영향을 준다. 대화 100개 × 선택 3개면 300개 플래그다.
  4. BP-24 는 다른 메커니즘을 쓴다 — `ctx.consumeChoice(dialogue.id, node.id, chosen.id)`(`24_dialogue_model.md:463`)이고, `Node.once` 는 **`visitedNodes`**(`:81`)에 기록한다. `WorldState`(BP-25 §2.1)에는 `visitedNodes` 필드가 **없다**.
- 요구 조치: 선택지/노드의 1회성 기록을 담을 전용 저장소를 **BP-25 §2.1 에 필드로 신설**하도록 요청하고(`dialogueMemory: Map<dialogueId, Set<nodeOrChoiceId>>` 등), BP-27 §5.1 을 그 API 로 바꿀 것. 일반 플래그 공간에 합성 id 를 섞는 것은 금지.

### F-17 `node.promptKey` 는 D-07 · BP-24 어디에도 없는 필드다
- 위치: :755 `items = [ strings[node.promptKey ?? defaultPrompt] ] + …`
- D-07 의 `Node` 는 `id, speaker?, lines, header?, onEnter, choices?, next?` 뿐이다. BP-24 의 Node 필드 표(`:61-94`)에도 `promptKey` 가 없다.
- `defaultPrompt` 도 정의되지 않았다(`UiHost.showMenu/showWindowMenu` 는 `items[0]` 을 제목으로 쓰므로 반드시 필요하다).
- 요구 조치: BP-24 에 필드 신설을 요청하거나, 제목을 `node.header` 로 대체하는 규칙을 명시할 것. `defaultPrompt` 의 실제 문자열(또는 stringKey)을 확정할 것.

### F-18 §7.4 의 `currentMapName` 대입 위치가 스크립트 생성 맵에서 **스테일 값을 남긴다**
- 위치: :1064-1070 diff — `setNewMap` 직후, `currentMapCm2Path = bundle.cm2Path;` 앞에 `currentMapName = bundle.mapName;` 삽입.
- 문제: `loadMapFromFile` 은 `bundle == null` 이면 **line 88 에서 즉시 `return false`** 한다(`game_session.dart:88`). 이 early return 이 삽입 지점보다 **위**에 있으므로, 실패 시 `currentMapName` 은 **직전 맵 이름 그대로** 남는다.
- 이 경로는 이론이 아니다. `LoadScript("L1_ep1d0.cm2", 47, 28)` 처럼 **cm2 가 맵을 직접 만드는 콘텐츠가 8개** 있고(`Map::Init` + `Map::SetRow` 사용: `L1_ep1d0/1/2/3/4/5/5_1.cm2`, `town1.cm2`), 이들은 전부 `MapInfos.json` 에 이름이 없어 `loadByName` 이 null 을 반환한다 → `loadMapFromFile` false → `script_engine_adapter.dart:46` 이 `loadScript` 로 폴백해 맵을 스크립트로 생성한다.
- 결과: 티어 0 이 **엉뚱한 맵의 앵커를 붙일 수 있고**, BP-25 R-25-4 의 세이브가 **잘못된 `currentMapName` 을 기록**한다(§8.2 의 원자성으로도 못 막는다 — 값이 "없음"이 아니라 "틀림"이기 때문).
- 요구 조치: `clearCurrentMap()` 뿐 아니라 **`loadMapFromFile` 의 실패 반환 직전에도 `currentMapName = null`** 을 두고, `Map::Init` 핸들러(`script_engine_adapter.dart:241`)에서도 `currentMapName = null` 로 무효화할 것. BP-28:89 가 "티어 0 진입 불가"만 다루고 세이브 측은 다루지 않으므로, 이 장이 §7.3/§7.4 에서 함께 못 박아야 한다.

### F-19 부록 B-3(이동·상호작용 루프가 presentation 에 있음)을 다루지 않았다 — GROUND_TRUTH 가 이 장에 지정한 선결 과제
- GROUND_TRUTH 부록 B-3: *"`UiHost`/`AssetSource` 포트를 페이크로 바꿔도 **이동과 상호작용 자체를 헤드리스로 구동할 수 없다.** **BP-27/BP-34 는 '이동·상호작용 루프를 `application/` 으로 추출' 을 선결 과제로 잡아야 한다.**"*
- 실측: `presentation/panels/player_sprite.dart:103` `void update(double dt)`, 그리고 `:193`/`:362`/`:405` 에서 `HDGameMain().checkTileEvent(...)` 직접 호출. 이 파일은 BP-27 에 **한 번도 등장하지 않는다**(`grep player_sprite` → 0건).
- 파급:
  - §10 의 통합 테스트(T-27-07~11)는 `HDTileEventDispatcher().check(...)` 를 **직접** 부르므로 통과한다. 하지만 D-13 의 `SimDriver`(scripted/greedy/random 정책)는 **이동을 구동할 수 없다.**
  - BP-25 §2.4 의 `step` 증가 트리거 1번("파티가 한 칸 이동 완료")도 소유자가 없다.
  - `reach` 목표의 좌표 판정을 §7.4(:1092)가 *"이동 처리 쪽에서 별도로 검사한다"* 로 넘겼는데, **그 "이동 처리"가 어느 파일인지 이 장이 정하지 않았다.** 현재 그것은 presentation 이다 → 계층 규칙상 거기서 `QuestRuntime` 을 부를 수 없다.
- 요구 조치: §7 에 여섯 번째 훅으로 **"(f) 이동 루프 추출"** 을 신설하고, 최소한 `HDPartyMovement`(application) 신설 + `player_sprite` 가 그것을 호출하는 방향으로 뒤집는 태스크를 §11.2 로 명시할 것. `reach`/`step` 이 여기에 달려 있다.

### F-20 부록 B-4(`dart:io` / `exit(0)`)를 다루지 않았다 — §1.4 의 CI 게이트 제안이 실제 위반을 못 잡는다
- 실측: `lib/application/menu_flows.dart:2` `import 'dart:io';`, `:504`/`:522`/`:540` `exit(0)`.
- §1.4 는 CI 게이트를 제안하면서 **`lib/domain/content/` 만** 대상으로 삼았다(:159-160). 기존 위반은 `lib/application/` 에 있어 잡히지 않는다.
- 헤드리스 하네스 관점에서 더 심각한 것은 `exit(0)` 다 — `processGameOver` 는 **전투 전멸/필드 사망**에서 불리므로, `SimDriver(policy: random)` 퍼징이 파티를 죽이면 **테스트 프로세스가 통째로 죽는다.** §9.4 의 "같은 입력 2회 실행 → 트레이스 해시 비교" 가 성립하지 않는다.
- 요구 조치: §1.4 의 게이트 범위를 `lib/application/` 전체로 넓히고, `exit(0)` → `UiHost` 를 통한 종료 요청(`UiHost.requestQuit()` 신설 등)으로 대체하는 태스크를 §11.2 에 명시할 것.

### F-21 §5.4 "세이브 로드는 대화 중 직접 발생하지 않는다" 는 근거가 약하다
- :816 — *"사용자가 대화 중 메뉴를 열 수 없으므로 직접 발생하지 않는다"*
- 실측으로 확인한 반례 경로: `HDBattle` 은 `on GameReloadException { … rethrow; }`(`battle.dart:229`)를 갖고 있고, `menu_flows.dart:519`/`:536` 은 **`processGameOver`(필드 사망 / 전투 전멸) 안**에서 던진다. 지연 효과 `start_battle` 이 대화 종료 후 전투를 열고 전멸하면 그 경로가 열린다. 또 `heal_party` 의 반대(독 데미지 등)로 `timeGoes()` 가 사망을 유발하는 경로도 있다.
- 더불어 F-22 참고: **인게임 로드(`selectGameOption` case 4 → `selectLoadMenu`)는 현재 `GameReloadException` 을 아예 던지지 않는다**(`menu_flows.dart:306-307`). 즉 "성공 로드가 실행 루프를 되감는다"는 전제 자체가 코드와 다르다.
- 요구 조치: §5.4 첫 행의 근거를 삭제하고 *"`start_battle` 지연 효과 → 전멸 → `processGameOver` → `selectLoadMenu` 성공 경로에서 발생할 수 있다"* 로 정정. 락 해제(`finally`)와 `WorldEventBus` 큐 폐기(BP-25 §4.5)가 그 경로에서도 동작함을 T-27 에 테스트로 추가할 것.

### F-22 §7.3 의 `saveGame` 패치가 BP-25 §8.2 의 원자성·순서 규약과 충돌
- :1018-1046 의 diff 는 `mapDelta: _diffMap(await _originOf(mapName), session.map)` 를 **data 맵 리터럴 안에서 await** 한다. `_diffMap`/`_originOf` 는 정의되지 않았고, `_originOf` 가 `AssetSource` 로 원본 156KB 를 다시 읽는 비용(Q-25-7)이 저장 경로에 들어간다.
- `loadGame` 쪽은 *"`session.loadMapFromFile('$mapName.json')` 를 타야 한다"*(:1051-1054)고만 적혀 있는데, 그 함수는 **커밋 지점 이전에 세션 7가지를 변경**한다(`HDBattle().init()`, `setNewMap`+`mapVersion++`+`notifyListeners`, `currentMapCm2Path`, `loadScript`(→`gameOption.scriptFile` 덮어씀), `onUnload`, `onPrepare`, `onLoad`(→ **party 좌표 덮어씀**, `town1_map_script.dart:16-25`)). BP-25 §8.2 의 *"5번 커밋 지점 앞에서는 세션을 절대 건드리지 않는다"* 와 양립 불가다.
- 특히 `onLoad` 가 파티 좌표를 덮으므로 **좌표 복원은 반드시 `loadMapFromFile` 뒤**여야 한다. 두 장 모두 이 순서 제약을 적지 않았다.
- 요구 조치: `_diffMap`/`_originOf` 의 시그니처와 실패 동작을 §7.3 에 명시하고, `loadGame` 의 단계별 순서를 BP-25 §8.2 와 **한 표로 통합**해 어느 장이 소유하는지 정할 것.

### F-23 §10.1 예시 테스트가 "실제로 쓸 수 있는 코드"라는 주장에 못 미친다
문서가 *"실제로 쓸 수 있는 코드"* 라고 단언한 파일(:1298-1494)을 실코드와 대조한 결과:

| 항목 | 검증 결과 |
|---|---|
| `_FakeAssets` 구조 | `map_navigation_test.dart:13-28` 과 동일 ✅ |
| `_RecordingUiHost` 가 `UiHost` 11멤버 전부 구현 | `ui_host.dart` 실측 11개와 정확히 일치 ✅ |
| `_mapJson()` 의 레이어 배치 | `HDMapLoader._getLayerData`(layer0=tile, 2/3=obj, 4=shadow, 5=event) 와 일치. `size=3`, layer0 index 0..2 = 10 → `ixTile 10` → `move` ✅ |
| 이벤트로 (1,0) 을 TALK 로 만드는 것 | `map_loader.dart:60-67` 이 `unit.ixEvent = 0x00020000 \| id` 를 넣어 성립 ✅ |
| `MapInfos [{'id':4,'name':'TOWN1'}]` → `Map004.json` | `map_navigation.dart:42-43` 과 일치 ✅ |
| **`mapScriptFactory['TOWN1']` 이 존재한다** | `native_script_runner.dart:25-30` 에 `TOWN1 → Town1MapScript` 등록됨 → `loadMapFromFile` 이 **네이티브 스크립트를 붙이고 `onLoad` 를 실행**한다. `Town1MapScript.onLoad` 는 `party.x=50; party.y=31`(3×1 맵에서 범위 밖)을 세운다 ❌ |
| 두 번째 테스트("앵커 없으면 3티어 그대로")의 기대 | 실제로는 **티어 1(네이티브)** 이 타져서 `_emitJsonDialog` 가 불린다. 기대값은 맞지만 **문서가 설명하는 이유(티어 2/3)와 다르다** ❌ |
| `expect(ui.calls.first, 'beginNarrative')` | `bootWith` 안의 `loadMapFromFile` 이 §7.4 패치로 `onMapEntered` → `drain()` 을 부르므로, 구독자가 UI 를 건드리면(Q-27-7 미해결) `calls.first` 가 달라진다. 취약한 단언 ❌ |
| `ContentRuntime().state.hasFlag(...)` | F-13 의 금지 규칙 위반을 예제가 정착시킨다 ❌ |
| `HDGameSession` 을 `tearDown` 에서 리셋하지 않음 | 싱글턴이라 다음 테스트로 맵·`currentMapScript` 가 샌다 ❌ |

- 요구 조치: 예시 맵 이름을 `mapScriptFactory` 에 없는 것(예: `MAP003`/`Test`)으로 바꾸고, `HDGameSession` 리셋 수단을 §2 에 추가하거나 `tearDown` 에 명시할 것. `calls.first` 단언은 `calls` 부분 시퀀스 매칭으로 완화할 것.

---

## 개선 제안 (선택)

### S-01 식별자 접두사가 문서 규약 3번을 벗어난다
`V-1~V-5`, `DT-1~DT-7`, `EV-*`(BP-25 소유) 는 규약 목록(`R/D/G/T/RK/Q`)에 없다. `DT-*` 는 실질적으로 태스크이므로 `T-27-*` 로 통일하고, `V-*` 는 `G-27-*`(갭)으로 바꾸는 편이 BP-11 갭 목록과 이어진다. 현재 `T-27-01~31` 은 테스트에 쓰여 태스크 접두사와 충돌하므로 `TC-27-nn` 을 권한다.

### S-02 `WorldEventBus.subscribe` 의 순서 규약이 없다 — 결정론 구멍
§2.3 은 *"`QuestRuntime` 이 유일한 기본 구독자"* 라고만 한다. 구독자가 둘 이상 되면(저널 배지, 업적, 트레이스 수집기) **호출 순서가 등록 순서에 의존**하고, 등록 순서는 부팅 경로에 따라 갈릴 수 있다. §9 의 결정론 요구와 직결되므로 "구독자는 `priority:int` 로 정렬, 동률은 타입명 사전순" 같은 규칙을 명시할 것.

### S-03 `maxCascadeDepth = 8` 의 계수 의미가 §6.1 과 어긋난다
BP-25 §4.3 흐름도는 **이벤트를 하나 처리할 때마다 `depth++`** 한다. 그러면 "깊이"가 아니라 **처리 건수 상한 8**이다. 퀘스트 하나가 목표 3개를 동시에 채우면 `quest_state_changed` + 저널 + 다음 스테이지 `onEnter` 만으로 8을 소진할 수 있다. 진짜 깊이(연쇄 세대 수)로 세거나 상한을 올릴 것. §6.1 흐름도에는 depth 증가 지점이 아예 없어 두 장이 다르게 읽힌다.

### S-04 `DialogueRuntime` 의 `kMaxDialogueSteps = 256` 과 `visited` Set 이 둘 다 있는데 후자를 안 쓴다
:697 에서 `visited = Set()  # 사이클 방어` 를 선언해 놓고 루프 어디서도 참조하지 않는다. `steps` 상한만으로 방어한다면 `visited` 를 지우고, 노드 재방문을 막으려면 BP-24 의 `Node.once`(F-16)와 통합할 것.

### S-05 §3.3 인덱스 구축 비용 추정에 근거 파일이 없다
"번들 1.5MB → 웹 200ms" 는 측정이 아니라 추정이다. 실제 근거가 될 만한 실측치(`assets/maps/TOWN1.json` 156KB 파싱 시간 등)를 붙이거나 "추정치, BP-35 에서 실측"이라고 표기할 것. Q-25-7 과 함께 묶어 실측 태스크로 만드는 것이 낫다.

### S-06 `HDLog` 유틸이 §8.3 에서 언급만 되고 정의가 없다
*"새 코드는 `debugPrint` 대신 얇은 `HDLog` 유틸을 쓴다"*(:1194) — 어느 계층에 두는지, 헤드리스 하네스가 어떻게 가로채는지(포트인가 정적 훅인가)가 없다. `application/ports/` 에 `LogSink` 포트를 추가할지 여부는 D-11 배치 결정이므로 이 장에서 정해야 한다.

---

## 잘된 점

- **코드 인용의 정밀도가 이 기획서 전체에서 가장 높다.** `battle.dart` 의 `Random()` **14곳 줄번호를 하나도 틀리지 않았고**(155/174/389/427/432/440/441/474/478/479/488/503/513/514), `tile_event_dispatcher.dart:62/64/67/96-103/117/159`, `hd_game_main.dart:172/211/212`, `game_session.dart:69-76/85/117-128`, `map_navigation_test.dart:13-28/66-78/188-198` 이 모두 정확했다. §4.1 의 before 코드는 실제 파일과 구조·문자열까지 일치한다.
- **§1.4 "계층 규칙 통과 논증"이 형식적 서술을 넘어선다.** 신규 파일별 import 전량을 표로 세우고 "UI 에 하는 모든 일은 `UiHost` 11개 메서드뿐, 파일에 하는 모든 일은 `AssetSource.loadString` 뿐" 이라는 **구조적 근거**를 제시했다. 이건 검수자가 직접 검증할 수 있는 형태다(실제로 검증했고 논증은 타당하다 — grep 자체의 문법 오류(F-06)만 별개다).
- **§4.2 의 티어 0 삽입이 최소 변경으로 설계됐다.** `_dispatchScripted` 상단 1블록 + `check` 가드 1줄 + `finally` 판정 1줄. 기존 3티어 본문을 손대지 않아 D-10 의 "무중단 점진 이관"이 코드 수준에서 실현 가능하다. §4.3 의 "앵커가 있으면 조건이 전부 거짓이어도 `handled=true`" 판단은 D-09 의 "맵 JSON events[] 는 레거시 폴백"과 정확히 정합한다.
- **§9 결정론 절이 부록 C-4 를 정면으로 받았다.** V-1(벽시계 독 데미지)의 파급을 *"이동할 때마다 실행 → 벽시계 값이 파티 HP 에 남아 세이브까지 흘러들어간다"* 로 정확히 추적했고, DT-1 의 해법(`damagedByPoison(int roll)` — 난수를 인자로)이 도메인을 순수하게 유지하는 옳은 방향이다. V-4(Map/Set 삽입 순서)를 잡아낸 것도 날카롭다 — LinkedHashMap 이라 이터레이션은 결정적이지만 **삽입 순서가 플레이 경로에 의존**한다는 지적은 정확하다.
- **§8.1 의 디버그/릴리스 이원 정책이 일관되게 적용**된다. "디버그는 `assert`, 릴리스는 안전한 기본값 + 로그", 그리고 §8.2 의 "조용한 실패 금지 3종(세이브/맵이름/스키마)". `map_navigation.dart:50-52` 의 기존 조용한 폴백을 반면교사로 명시한 것이 좋다.
- **§10 의 테스트 31건이 각 규칙에 1:1 추적 가능**하고, §10.1 의 실행 가능한 예시 파일은 (F-23 의 문제에도 불구하고) `map_navigation_test.dart` 의 페이크 패턴을 정확히 재현했다. `UiHost` 11멤버를 빠짐없이 구현한 것도 확인했다.
- **§6.3 의 성능 논증이 정량적이다.** 3중 필터(이벤트 타입 역인덱스 → 활성 퀘스트 → 현재 스테이지)로 "이벤트당 평균 5~20 비교"까지 내려간 계산은 검증 가능하고, `TriggerIndex.watchers()` 라는 구현 수단까지 붙어 있다.

---

## 다른 장에 전파해야 할 발견

1. **월드 이벤트 이름 집합 3파 분열**(F-02) — BP-23(12종) / BP-24(`dialogue_choice`) / BP-25·BP-27(11종). 메인이 SSoT 소유 장을 지정해야 한다. BP-23 §23.11.4 의 objective 커버리지 증명이 BP-23 집합 위에 있으므로 BP-23 소유가 파급이 적다.
2. **BP-26 의 앵커 다중성 모델과 BP-27 의 `TriggerIndex.at()` 충돌**(F-03). BP-26 검수자에게도 전달. `fallback` 필드 신설 여부도 함께 결정해야 한다.
3. **BP-24 의 `showMenu` 결정과 BP-27 의 `showWindowMenu` 충돌**(F-15), **BP-24 의 `Node.once`/`visitedNodes` 저장소가 BP-25 `WorldState` 에 없음**(F-16). 세 장이 함께 정해야 한다.
4. **BP-28 R-28-2(단일 가드)와 BP-27 이중 가드 충돌**(F-14). BP-28 이 이미 `INV-20-16` 으로 테스트까지 고정했으므로 BP-27 을 맞추는 것이 자연스럽다.
5. **BP-23 도 D-08a 미반영** — `23_quest_model.md:617` `startedAt:now`, `:622`/`:625` `updatedAt`. `now` 라는 표현은 벽시계를 직접 암시하므로 더 위험하다.
6. **`Map::Init`/`Map::SetRow` 로 맵을 통째로 만드는 cm2 가 8개**(`L1_ep1d0~d5_1`, `town1.cm2`; SetRow 30~50행). 이들은 `MapInfos.json` 에 이름이 없어 `currentMapName` 이 스테일해지고(F-18), BP-25 의 `mapDelta`·R-25-4 도 성립하지 않는다. BP-25·BP-28·BP-35 가 함께 다뤄야 한다.
7. **`assets/maps/Map004.json` 이 존재하지 않는다.** `MapInfos.json` 은 TOWN1→id 4 로 매핑하고 리졸버는 `Map004.json` 을 찾는데 실제 파일명은 `TOWN1.json` 이며 `json` 오버라이드 필드도 없다 → TOWN1 은 "cm2-only 맵"으로 취급된다(`map_navigation.dart:67`). §10.1 의 예시 픽스처는 이 규칙을 정확히 따랐지만, **실제 게임 데이터는 깨져 있다.** BP-28/BP-35 에 데이터 정합 태스크로 등록할 것.
8. **`game_session.dart:125` 의 인자 오류**: `onLoad(bundle.mapName, 0, 0)` 이 `prevMap` 자리에 새 맵 이름을 넘긴다 → `Town1MapScript` 의 `prevMap == 'GROUND1'` 분기는 영원히 거짓. §7.4 가 이 함수에 의존하므로 BP-28/BP-51 에 선행 버그로 등록.
9. **인게임 로드가 `GameReloadException` 을 던지지 않는다**(`menu_flows.dart:306-307`, F-21). GROUND_TRUTH §7 의 서술과 다르다. BP-25 §8.2 8단계의 소유자 확정과 함께 처리해야 한다.

---

## 결정 재검토 요청

### RQ-27-A D-05 의 `chance` op 을 "커서 소비형"으로 두면 D-05 자신의 "부작용 없음, 순수 함수" 규정과 충돌한다
D-05 는 Condition 을 *"단일 JSON 객체 … 부작용 없음. 순수 함수"* 로 규정하면서 동시에 `chance(percent)` 를 *"시드 난수"* 로 정의했다. 커서 소비형 난수는 정의상 부작용이다(F-04). **결정을 바꾸지 않고 해결하는 길**은 `chance` 를 `(seed, step, 조건 위치)` 의 순수 해시로 구현하는 것이며, 이는 D-05 문구를 그대로 만족시킨다. 다만 "같은 스텝 안에서 같은 조건은 항상 같은 값" 이라는 의미론이 D-05 에 명시돼 있지 않으므로, **D-05 에 한 줄 보강**을 요청한다. (본 검수는 결정을 유지하고 기록만 한다.)

### RQ-27-B D-05 의 `time_of_day` op 과 D-16 의 "시간대는 1차 스코프 밖" 충돌
F-08 참고. 콘텐츠 작가가 `time_of_day` 를 쓰면 빌드는 통과하고 런타임은 항상 기본값이 된다 — D-02 가 cm2 의 결함으로 지목한 "조용한 오분기"와 같은 양상이다. `time_of_day` 를 v2 로 미루거나 D-16 의 시간대를 필수로 승격하거나, 둘 중 하나. (기록만 한다.)

### RQ-27-C GROUND_TRUTH B-2(전투 결과 코드 뒤바뀜)의 정본 결정이 이 장에 위임됐으나 이행되지 않았다
GT B-2 는 *"콘텐츠 런타임의 `battle_won` / 전투 결과 조건을 설계할 때 어느 쪽을 정본으로 삼을지 먼저 정해야 한다(**BP-27 결정 사항**)"* 라고 명시했다. 본 장은 결정하지 않았다(F-07). 이것은 DECISIONS 의 결정을 뒤집는 요청이 아니라 **위임된 결정의 미이행**이므로, 재검수 통과 조건에 포함한다.

---

## 재검수 통과 조건 (체크리스트)

- [ ] F-01 D-08a 8곳 치환
- [ ] F-02 이벤트 이름 집합 단일화 (BP-23/24/25 와 합의)
- [ ] F-03 `TriggerIndex` 를 BP-26 의 `(map,x,y,kind)`→다중 앵커 모델로 정정 + `fallback` 필드 처리
- [ ] F-04 `chance` 순수성 해소 (권장: 무커서 해시)
- [ ] F-05 op 18 / do 22 로 정정 + DSL 커버리지 테스트 추가
- [ ] F-06 CI grep 2개를 실행 가능한 형태로 재작성 (`check()` 경로 인자화 포함)
- [ ] F-07 `battle_won` delta 규칙 확정 + **B-2 정본 결정** + `battle_lost`/`turn_survived` 발행처
- [ ] F-08 `WorldStateView` 에 `currentMap` / `partySnapshot` / `timeOfDay` 신설 요청
- [ ] F-09 `WorldRng.stream` 구현 가능한 형태로 재정의
- [ ] F-10 **`HDEffectBridge` 절 신설** — 5개 do 의 계약 확정
- [ ] F-11~F-23 반영
- [ ] §1 공개 API 감사표의 `✗` 를 `○` 로 — 특히 미정의 타입 8종(`ContentLoadReport`, `ContentLoadException`, `PlaceBinding`, `ObjectiveRef`, `QuestJournalView`, `PendingWarp`, `DeferredEffect`, `DialogueTrace`)의 정의 또는 소유 장 위임
