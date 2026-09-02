# AI 자동 생성 관점 결함 목록

> `상태: 참고` — 현황 조사·참조 자료. 사실 정본은 [`_meta/GROUND_TRUTH.md`](_meta/GROUND_TRUTH.md) 이며,
> 이 장의 **결론·권고는 1차 노선 기준**이라 [`issues/DECISION-LOG.md`](../issues/DECISION-LOG.md) 2차 판정이 우선한다.

> **문서 ID**: BP-11 · **상태**: 초안 · **선행 문서**: [BP-10](10_current_architecture_audit.md)
> **독자**: 아키텍트 · 툴체인 구현자 · 의사결정자 · **한 줄 요약**: "지금 구조로 AI 가 시나리오/퀘스트를 자동으로 불려 나갈 수 있는가" 에 정면으로 답하고, 그것을 막고 있는 결함 **34건**(하위 항목 제외 시 독립 28건)을 근거·영향·심각도·뿌리·해소 위치·태스크와 함께 등록한다.

---

## 0. 결론 먼저

### 0.1 한 문장 답

> **불가능하다.** 지금의 Hadar2026 은 AI 가 콘텐츠를 **생성할 표현 형식**도, **검증할 계약**도, **실행해 볼 하네스**도 갖고 있지 않다. 다만 **부분적으로 가능해질 이음매(포트 3종 + 맵 에디터 AI API)는 이미 존재**하므로, 신규 발명이 아니라 확장으로 도달할 수 있다.

### 0.2 세 축으로 나눈 판정

AI 파이프라인은 **생성(Generate) → 검증(Validate) → 유지보수(Maintain)** 세 단계로 나뉜다. 각 단계의 현재 가능 여부:

| 축 | 판정 | 근거 |
|---|---|---|
| **생성** | ❌ **불가능** | 생성할 타깃 표현이 없다. 후보 3개 전부 부적격: ① cm2 는 정적 검증이 불가하고 미등록 심볼이 조용히 `0` 을 반환한다([G-08](#g-08-cm2-는-미등록-심볼을-침묵으로-흘려보낸다)) ② 네이티브 Dart 는 콘텐츠 추가가 곧 코드 수정 + 재빌드다([G-12](#g-12-콘텐츠-추가가-코드-수정과-재빌드를-요구한다)) ③ JSON `dialogLines` 는 조건·분기·상태 참조가 전혀 없는 순수 문자열 배열이다([G-07](#g-07-조건부-대사가-원리적으로-불가능하다)) |
| **검증** | ❌ **불가능** | 스키마도 검증기도 없고([G-10](#g-10-콘텐츠-스키마와-검증기가-존재하지-않는다)), 실행해 볼 헤드리스 경로도 없으며([G-11](#g-11-헤드리스-실행-경로가-끊겨-있다)), 난수에 시드가 없어 결과 재현이 안 된다([G-17](#g-17-난수와-시각에-시드가-없어-재현이-불가능하다)). "이 퀘스트가 완주 가능한가" 를 물어볼 대상 자체가 없다([G-01](#g-01-퀘스트목표저널-개념이-코드에-0건-존재한다)) |
| **유지보수** | ❌ **불가능** | 대사가 맵 좌표에 물리적으로 박혀 있어 맵을 고치면 대사가 끊긴다([G-06](#g-06-대사가-맵-좌표에-물리적으로-박혀-있다), [G-18](#g-18-맵-편집이-콘텐츠-정합성을-소리없이-깨뜨린다)). 상태 키가 이름 없는 정수라 생성물이 서로의 플래그를 침범해도 알 수 없다([G-03](#g-03-상태가-3중으로-분열되어-있고-전부-이름-없는-정수다)). 세이브가 콘텐츠 버전을 모른다([G-20](#g-20-세이브가-콘텐츠-버전을-모른다)) |

### 0.3 그럼에도 "부분 가능" 이라고 말할 수 있는 근거

전면 재작성이 아니라 **확장**으로 갈 수 있게 하는 자산이 이미 있다:

| 이미 있는 것 | 위치 | 왜 중요한가 |
|---|---|---|
| **포트 3종 + 합성 루트** | `lib/application/ports/` | `HDHosts().bind(...)` 로 페이크를 주입하는 헤드리스 이음매가 이미 뚫려 있다. `test/application/map_navigation_test.dart` 가 파일시스템 없이 전 경로를 구동하는 선례다. **단, 포트만으로는 게임이 돌지 않는다** — 이동·상호작용 판정이 `presentation/panels/player_sprite.dart` 의 프레임 폴링 안에 있고 `menu_flows.dart:504` 가 `exit(0)` 로 프로세스를 죽인다([G-11](#g-11-헤드리스-실행-경로가-끊겨-있다)). 이음매는 **출발점이지 완성품이 아니다** |
| **계층 규칙의 CI 강제** | `.github/workflows/ci.yml:50` | 신규 콘텐츠 런타임을 `application/`+`domain/` 에 두면 Flutter 의존 없이 CLI 검증기에서 재사용할 수 있음이 **기계적으로 보장**된다 |
| **3티어 디스패치의 폴백 구조** | `application/tile_event_dispatcher.dart:106` | 앞에 티어를 하나 더 얹으면(D-10) 기존 맵의 동작이 그대로 보존되는 무중단 이관이 가능하다 |
| **맵 에디터 AI API + MCP 래퍼** | `tools/mapEditor/server/ai_api.ts` | 배치 편집 · `validate` · 미리보기 · `{error, hint}` 에러 규약 · MCP 노출까지 **콘텐츠 서버가 따라야 할 패턴이 이미 검증됨** |
| **`hadarEvent {kind, payload}` 확장 슬롯** | `domain/map/map_event.dart:12` | 파싱은 이미 되고 디스패치만 없다. 앵커 도입 전 임시 다리로 쓸 수 있다 |

### 0.4 "가능하게 만들기 위해 반드시 있어야 하는 것" (D-16 재확인)

BP-10 실측이 D-16 의 6개 최소 집합을 전부 뒷받침한다:

| D-16 항목 | BP-10 근거 | 관련 결함 |
|---|---|---|
| 1. 퀘스트 저널 UI | 퀘스트 코드 0건(§7 grep) | G-01 |
| 2. 인벤토리/아이템 | `PartyInventory{food, gold}` 뿐(§7.8) | G-02, G-25 |
| 3. 조건부 대화 | `_emitJsonDialog` 무조건 출력(§4.4) | G-07, G-27 |
| 4. 이름 있는 전역 상태 | 3중 분열 + 정수 인덱스(§6.1) | G-03, G-04 |
| 5. NPC 정체성 | 좌표만 있고 식별자 없음(§4.2) | G-15 |
| 6. 월드 이벤트 버스 | 전투 승리가 로그만 남김(§7.5) | G-14 |

---

## 1. 결함 등록부

> **읽는 법**: 심각도 `치명` = 이것 없이는 AI 파이프라인이 성립하지 않음. `높음` = 성립하지만 품질/운영이 무너짐. `중간` = 우회 가능하나 부채. `낮음` = 정리 대상.
> "해소 위치" 는 [OUTLINE](_meta/OUTLINE.md) 의 장 번호다.

---

### G-01 퀘스트/목표/저널 개념이 코드에 0건 존재한다

- **증상**: 게임에 "임무", "목표", "진행 단계" 라는 개념 자체가 없다. NPC 가 뭔가를 부탁해도 그것을 **기억할 자료구조가 없다**.
- **근거**:
  ```bash
  $ grep -rin "quest\|journal\|objective" hadar2026_app/lib packages/cm2_script/lib
  # 실질 매칭 0건.
  # 걸리는 것은 "request" 단어 오검출 2건뿐: ui_host.dart:89("repaint request"),
  #                                        flutter_ui_host.dart:19("One-shot menu request")
  ```
  진행 상태를 표현할 수 있는 유일한 수단은 `HDGameOption.flags[256]` 의 불리언 하나다:
  ```dart
  // hadar2026_app/lib/domain/game_option.dart:9
  List<bool> flags = List.filled(HDConfig.maxFlags, false);
  ```
- **AI 파이프라인에 미치는 영향**: **생성 / 검증 / 유지보수 전부**. 생성 에이전트가 만들 산출물의 스키마가 없고, "완주 가능한가" 를 물을 대상이 없으며, 플레이어에게 진행 상황을 보여줄 화면도 없다. AI 콘텐츠의 본체가 통째로 표현 불가.
- **심각도**: **치명**
- **관련 결정**: D-06, D-16-1
- **해소 위치**: [BP-23](23_quest_model.md) · UI 는 [BP-41](41_journal_ui_spec.md)

---

### G-02 아이템·인벤토리가 정수 두 개뿐이다

- **증상**: 소지품 목록이 없다. "녹슨 열쇠를 받아 문을 연다" 같은 가장 기본적인 퀘스트 구조가 표현되지 않는다.
- **근거**:
  ```dart
  // hadar2026_app/lib/domain/party/party.dart:13
  class PartyInventory {
    int food = 100;
    int gold = 500;
  }
  ```
  장비는 슬롯 3개에 정수 ID 하나씩이고, 이름은 하드코딩 플레이스홀더다:
  ```dart
  // hadar2026_app/lib/domain/party/player.dart:91
  String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";
  String getShieldName() => shield == 0 ? "없음" : "방패$shield";
  String getArmorName()  => armor  == 0 ? "평상복" : "갑옷$armor";
  ```
  이 문자열이 전투 로그(`battle.dart:453`)와 상태 화면(`menu_flows.dart:275`)에 그대로 노출된다.
- **AI 파이프라인에 미치는 영향**: **생성**. D-06 Objective.kind 의 `acquire` / `deliver` 가 원천 불가. 보상 Effect `give_item` / `take_item`(D-05)도 착륙할 곳이 없다. 퀘스트 설계 공간이 "플래그 켜기" 로 축소된다.
- **심각도**: **치명**
- **관련 결정**: D-05, D-16-2
- **해소 위치**: [BP-42](42_item_and_inventory.md)

---

### G-03 상태가 3중으로 분열되어 있고 전부 이름 없는 정수다

- **증상**: 게임 진행 상태를 담는 저장소가 셋인데 수명과 저장 여부가 전부 다르고, 어느 것도 "이 플래그가 무슨 뜻인지" 를 코드로 알 수 없다.
- **근거**:
  | # | 저장소 | 타입 | 맵 전환 생존 | 세이브 |
  |---|---|---|:--:|:--:|
  | 1 | `HDGameOption.flags/.variables` | `List<bool>(256)` / `List<int>(256)` | ✅ | ✅ |
  | 2 | `HDNativeScriptRunner.flags/.variables` | `Map<int,bool>` / `Map<int,int>` | ✅ | ❌ |
  | 3 | `HDScriptEngine.variables` | `Map<String,dynamic>` | ❌ | ❌ |
  ```dart
  // hadar2026_app/lib/application/scripting/native_script_runner.dart:22
  Map<int, bool> flags = {};
  Map<int, int> variables = {};
  ```
  의미는 오직 스크립트 주석에만 있다. 예컨대 `Town1MapScript` 의 33/34/41 이 뭔지 어디에도 없다:
  ```dart
  // hadar2026_app/lib/application/scripting/maps/town1_map_script.dart:38
  if (!isFlagSet(41) && isArea(49, 29, 51, 29)) { ... setFlag(41); }
  ```
- **AI 파이프라인에 미치는 영향**: **생성 / 검증 / 유지보수 전부**. 생성 에이전트가 "빈 플래그 번호" 를 고를 방법이 없다(0~255 중 무엇이 쓰이는지 조회 불가) → 팩끼리 충돌한다. 검증기가 "이 플래그를 세우는 곳과 읽는 곳" 을 연결할 수 없다. 두 팩이 41번을 동시에 쓰면 조용히 서로를 덮어쓴다.
- **심각도**: **치명**
- **관련 결정**: D-04(상태 키 네이밍), D-08, D-16-4
- **해소 위치**: [BP-25](25_world_state_and_save.md)

---

### G-04 세이브 v1 이 진행 상태의 일부를 통째로 버린다

- **증상**: 저장 후 불러오면 네이티브 스크립트가 기록한 진행도가 전부 사라지고, 어느 맵에 있었는지도 잊는다.
- **근거**:
  ```dart
  // hadar2026_app/lib/application/save_manager.dart:18
  final Map<String, dynamic> data = {
    'version': 1,
    'party': session.party.toJson(),
    'gameSystem': session.gameSystem.toJson(),
    'gameOption': session.gameOption.toJson(),
    'map': session.map?.toJson(),
  };
  ```
  누락 목록: `HDNativeScriptRunner.flags/.variables`, `HDScriptEngine.variables`, **현재 맵 이름**, `currentMapCm2Path`.
  맵은 `MapModel.toJson()` 스냅샷만 저장하므로(`map_model.dart:50`) 이름을 잃는다 → 복원 후 `mapScriptFactory` / `MapInfos` 재바인딩이 불가능하다.
  또 `loadGame` 은 `run()` 을 부르지 않아 FLAG_MAP 초기화가 재실행되지 않는다:
  ```dart
  // hadar2026_app/lib/application/save_manager.dart:79
  // 4. Script definitions are already loaded via loadScript in step 2.
  // We skip the explicit run() call to avoid re-initializing state.
  ```
- **AI 파이프라인에 미치는 영향**: **검증**. 헤드리스 시뮬레이터가 "중간 상태에서 재개" 를 못 하고, 세이브/로드를 낀 회귀 테스트가 원천적으로 거짓 음성을 낸다. 생성된 장편 퀘스트가 세이브를 건너면 깨진다.
- **심각도**: **높음** *(초판 "치명" 에서 하향 — "헤드리스 재개 불가" 논거가 [G-28](#g-28-진행-상태를-외부에서-관측주입할-api-가-없다) 과 겹쳐 이중 계상이었다. 데이터 손실 자체는 여전히 심각하나 v2 봉투 하나로 해소된다)*
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.** `HDSaveManager` 왕복 테스트가 0건이다(BP-10 §9.3).
- **관련 결정**: D-08, D-22
- **해소 위치**: [BP-25](25_world_state_and_save.md) · 태스크 **T-008 · T-014 · T-015 · T-016 · T-063**

---

### G-05 네이티브 맵 스크립트의 플래그 헬퍼가 빈 스텁이다 (현행 버그)

- **증상**: 등록된 네이티브 맵 4종 전부에서 **조건 분기가 무력화**되어 있다. 같은 대사가 무한 반복되고 `else` 가지는 도달 불가다.
- **근거**:
  ```dart
  // hadar2026_app/lib/application/scripting/map_script.dart:41
  bool isFlagSet(int index) {
    // Requires implementation in GameModel / State
    return false;            // ← 항상 false
  }
  void setFlag(int index) {
    // Requires implementation in GameModel / State
  }                          // ← no-op
  ```
  `Town1MapScript` 는 오버라이드 없이 이 스텁을 쓴다:
  ```dart
  // hadar2026_app/lib/application/scripting/maps/town1_map_script.dart:76
  if (isOn(45, 8)) {
    if (!isFlagSet(33)) {                       // 항상 true
      await talk("게임의 진행을 위해 이 안 쪽 감옥의 문을 열어 주겠소.");
      setFlag(33);                              // no-op
      game.map?.setTile(44, 14, 0);
    } else {
      if (!isFlagSet(34)) { ... } else { ... }  // 도달 불가
    }
  ```
  제대로 동작하는 구현은 `HDNativeScriptRunner` 에 이미 있으나(`native_script_runner.dart:91`, `:95`) 아무도 호출하지 않는다.
- **AI 파이프라인에 미치는 영향**: **검증**. 시뮬레이터가 이 맵을 돌리면 "잘 동작하는 것처럼 보이는 잘못된 기준선" 을 만든다. 골든 회귀 파일이 버그를 정본으로 굳힌다. 또한 "네이티브 티어는 조건 분기가 가능하다" 는 §5 능력 비교표의 전제가 실제로는 거짓.
- **심각도**: **높음** *(초판 "치명" 에서 하향 — §2.4 가 스스로 "2줄 수정" 으로 분류한 항목이다. 다만 §2.4 M0 우선순위는 그대로 유지한다: 지금 골든을 뜨면 버그가 정본이 되기 때문)*
- **다른 결함과의 관계**: [G-31](#g-31-네이티브-맵-스크립트가-지오메트리-없는-맵에-바인딩된다)과 **원인이 독립적**이다. 이것은 "조건이 항상 false" 인 플래그 문제고, G-31 은 "좌표 판정이 다른 맵을 본다" 는 바인딩 문제다. **이것을 고쳐도 G-31 은 남는다.**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.** 태스크 **T-033** 이 먼저 "항상 false" 를 진단 테스트로 고정한 뒤 **T-111** 이 뒤집는다.
- **관련 결정**: D-10(공존 전략의 전제)
- **해소 위치**: [BP-28](28_migration_and_coexistence.md) · 태스크 **T-033 → T-111** · 열린 질문 Q-10-05

---

### G-06 대사가 맵 좌표에 물리적으로 박혀 있다

- **증상**: NPC 의 말이 `Map002.json` 안 `events[]` 의 `x`/`y` 에 종속된다. 텍스트를 고치려면 맵 파일을 열어야 하고, 좌표를 옮기면 대사가 사라진다.
- **근거**: 대사 조회가 좌표 선형 탐색이다.
  ```dart
  // hadar2026_app/lib/application/tile_event_dispatcher.dart:166
  for (final ev in map.events) {
    if (ev.x == x && ev.y == y) {
      for (final line in ev.dialogLines) {
        if (line.isNotEmpty) await host.addLog(line);
      }
      return;
    }
  }
  ```
  cm2 도 좌표가 유일한 식별자다:
  ```cm2
  # hadar2026_app/assets/Map002.cm2:6
  	if (On(30, 20))
  		SetHeader("누군지 모르는 사람")
  ```
  네이티브도 마찬가지(`town1_map_script.dart:62` `isOn(50, 83)`, `:76` `isOn(45, 8)`).
  대사 본문은 RPG Maker `code=401` 파라미터에서 뽑는다(`domain/map/map_event.dart:79`).
- **AI 파이프라인에 미치는 영향**: **생성 / 유지보수**. 생성 에이전트가 대사를 쓰려면 **맵 바이너리 구조를 이해해야** 한다(z=5 region 레이어 + `events[].pages[0].list[code=401]`). 텍스트 리뷰·톤 조정·번역이 맵 파일 diff 로 나타나 검토가 불가능하다.
- **심각도**: **치명**
- **관련 결정**: D-09
- **해소 위치**: [BP-26](26_entity_registry_and_anchors.md)

---

### G-07 조건부 대사가 원리적으로 불가능하다

- **증상**: 같은 NPC 가 상황에 따라 다른 말을 할 수 없다. JSON 티어는 **무조건 같은 줄을 같은 순서로** 출력한다.
- **근거**: `_emitJsonDialog` 에 조건도, 상태 참조도, 랜덤도 없다(위 G-06 인용 코드 전문이 함수 전부다 — `tile_event_dispatcher.dart:159`~`:179`).
  게다가 **좌표당 이벤트는 첫 번째 하나만 유효**하다: 같은 (x,y) 에 이벤트가 둘 있어도 `return` 이 첫 매치에서 끊는다.
  네이티브 티어에서는 JSON 이 **선출력**되므로 조건을 붙일 수조차 없다:
  ```dart
  // hadar2026_app/lib/application/tile_event_dispatcher.dart:126
  if (native.currentMapScript != null) {
    await _emitJsonDialog(map, x, y, host, action);   // ← 무조건 먼저
    await native.processMapEvent(action, x, y);
    return;
  }
  ```
  cm2 티어만 `Event::Override()` 로 억제할 수 있고, 실제 자산에 누락 사례가 있다(`Map002.cm2:6`~`:19` 의 TALK 블록).
  다만 그 누락이 만드는 **실제 증상은 "중복 출력" 이 아니다** — (30,20) 에는 JSON 이벤트가 없어 폴백이 아무것도 출력하지 않는다.
  반대로 `Event::Override()` 가 **있는** 곳에서는 JSON 텍스트가 영구히 표시되지 않는다. 실측 사문 대사 3줄(BP-10 §4.5):

  | 맵 | 좌표 | 이벤트 | 표시되지 않는 텍스트 |
  |---|---|---|---|
  | Map002(`LORE_EP`) | (30, 25) | `ENTER001` | `난데없는 던전 입구` |
  | Map002(`LORE_EP`) | (30, 28) | `ENTER002` | `(텍스트 내용)` |
  | Map003(`MAP003`) | (10, 5) | `ENTER001` | `쿠겔겔` |

  → **AI 관점에서 더 나쁜 쪽은 사문화다.** 중복은 출력이 지저분해지는 문제지만, 사문화는 콘텐츠가 조용히 사라지는 문제다.
  API 가 성공을 반환해도 플레이어에게 도달하지 않는다.
- **AI 파이프라인에 미치는 영향**: **생성**. D-07 Dialogue 모델의 `entry: [{when, go}]`(조건부 진입)과 `Choice.when` 이 전부 착륙 불가. 퀘스트 진행에 따라 NPC 반응이 바뀌는 것이 서사의 기본인데 그게 안 된다.
- **심각도**: **치명**
- **다른 결함과의 관계**: **[G-27](#g-27-대화가-선형-로그-스트림이고-그래프-개념이-없다)의 하위 항목**이다. G-27(대화 그래프 부재)이 상위 개념이고 이것은 그중 "조건부 진입" 축이다.
  따라서 §2.2 집계에서 G-27 을 치명으로 올리고 이 항목은 **G-27 에 종속된 치명**으로 센다(이중 계상 방지 — §2.2.1).
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: D-07, D-10, D-16-3
- **해소 위치**: [BP-24](24_dialogue_model.md) · 티어 재정의는 [BP-27](27_runtime_engine.md) · 태스크 **T-044 · T-054 · T-059**

---

### G-08 cm2 는 미등록 심볼을 침묵으로 흘려보낸다

- **증상**: 오타 난 커맨드는 그냥 건너뛰고, 오타 난 **함수는 `0` 을 반환**해 조건문이 조용히 반대로 분기한다. 에러가 아니라 `print` 다.
- **근거**:
  ```dart
  // packages/cm2_script/lib/src/cm2_script.dart:198
  default:
    final handler = _commands[cmd];
    if (handler != null) { await handler(stmt, this); }
    else { print("Unknown command: $cmd"); }     // 스킵 후 계속
  ```
  ```dart
  // packages/cm2_script/lib/src/cm2_script.dart:330
  final handler = _functions[cmd];
  if (handler != null) return handler(args, this);
  print("ScriptEngine: Unknown function $cmd");
  return 0;                                       // ← 조건문이 false 로 오분기
  ```
  파서도 관용적이다 — 괄호 없는 줄은 "인자 없는 커맨드" 로 통과한다:
  ```dart
  // packages/cm2_script/lib/src/parser.dart:111
  int startParen = line.indexOf('(');
  if (startParen == -1) return CommandStatement(line, []);
  ```
  게다가 언어 자체에 **루프도, 함수 정의도, 사칙연산도 없다**(`Add` 만 있음, `cm2_script.dart:300`).
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. LLM 생성물의 가장 흔한 실패가 "그럴듯한 이름의 존재하지 않는 API 호출" 인데, cm2 는 그것을 **검출조차 못 하고 잘못된 게임 상태로 흘려보낸다**. 정적 검증이 불가능한 언어는 LLM 생성 타깃으로 부적격. D-02 의 근거가 정확히 이것이다.
- **심각도**: **치명** *(초판 "높음" 에서 상향 — D-02(AI 생성 타깃을 cm2 가 아닌 선언적 데이터로 정함)의 **유일한 결정 근거**다. 이 결함이 없다면 D-02 자체가 성립하지 않는다)*
- **주의**: 이것은 **오타 계열**이다. 문법·이름이 전부 맞는데 값이 범위 밖이라 죽는 **별개 계열**은 [G-30](#g-30-등록된-심볼도-범위-밖-인자를-침묵-no-op-으로-삼킨다) 이다.
- **cm2 를 "정적 검증 불가" 라고 말할 때 튜링 완전성을 근거로 들면 안 된다**: `parser.dart` 에 루프도 함수 정의도 없고 AST 노드는 `CommandStatement`/`IfStatement` 둘뿐이다(`packages/cm2_script/lib/src/ast.dart:5`, `:14`). 분기만 있고 반복이 없는 언어는 오히려 정적 분석이 쉽다. 실제 근거는 위의 침묵 실패 2계열 + 전역 수명 비결정([G-09](#g-09-cm2-전역의-수명이-파일-존재-여부에-따라-정반대로-갈린다--assign-매-실행-재실행)) + `.assign` 재실행 + 스키마 부재다. 근거: 부록 E-3, 태스크 **T-032**.
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: D-02
- **해소 위치**: [BP-20](20_target_architecture.md), [BP-28](28_migration_and_coexistence.md) · 태스크 **T-032**

---

### G-09 cm2 전역의 수명이 **파일 존재 여부에 따라 정반대**로 갈린다 (+ `.assign` 매 실행 재실행)

- **증상**: cm2 스크립트가 기억하는 범위가 "한 맵 안" 인지 "계속 남음" 인지가 **언어 규칙이 아니라 자산 배치**로 정해진다.
  거기에 더해 상단 대입문이 매 상호작용마다 상태를 초기화한다.
- **근거**: 맵 전환마다 `loadScript` 가 불린다.
  ```dart
  // hadar2026_app/lib/application/game_session.dart:107
  await HDScriptEngine().loadScript(_resolveCm2Asset(bundle.cm2Path!));
  ```
  **로드 성공** 시에만 엔진 전역이 지워진다:
  ```dart
  // hadar2026_app/lib/application/scripting/script_engine_adapter.dart:103 (성공 경로)
  _engine.clearRuntimeState();   // variables.clear() + _contexts.clear()
  ```
  **로드 실패** 시에는 그 줄에 도달하지 못한다 — 조기 `return` 한다(→ [G-29](#g-29-cm2-로드-실패가-엔진-상태를-누수시켜-티어-판정을-신뢰할-수-없게-만든다)):
  ```dart
  // hadar2026_app/lib/application/scripting/script_engine_adapter.dart:92~99 (실패 경로)
  } catch (e) {
    print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
    return;                      // ← :103 의 clearRuntimeState() 미도달
  }
  ```
  그리고 **실패가 다수다.** `MapInfos.json` 등록 이름 15개 중 페어 cm2 파일이 실제로 존재하는 것은 2개(`LORE_EP`·`MAP003`)뿐이라
  **13개 맵에서는 전역이 지워지지 않는다.** 즉 "맵 전환마다 소실" 은 **소수 경로(2/15)** 이고 다수 경로는 그 반대다.

  init 단계는 `variable`/`include`/`.assign` 을 실행하고, run 단계는 앞의 둘만 건너뛴다:
  ```dart
  // packages/cm2_script/lib/src/cm2_script.dart:83  (init)
  if (stmt.command == 'variable' || stmt.command == 'include' ||
      stmt.command.endsWith('.assign')) { await executeCommand(stmt); }
  // packages/cm2_script/lib/src/cm2_script.dart:99   (run)
  if (stmt.command == 'variable' || stmt.command == 'include') continue;
  //   ↑ .assign 은 매 run() 마다 재실행됨
  ```
- **AI 파이프라인에 미치는 영향**: **생성 / 유지보수**. 생성 에이전트에게 "상태는 어디에 두라" 를 설명할 수 없다.
  상태 수명이 언어 규칙이 아니라 **"페어 cm2 파일이 디스크에 있는가" 라는 데이터 조건**에 달려 있어서,
  프롬프트 계약(D-12/[BP-37](37_prompt_contracts.md))에 "언제나 지워짐" 도 "언제나 남음" 도 쓸 수 없다.
  이 비결정성이 오히려 D-02(선언적 데이터 채택)를 강화한다.
- **심각도**: **높음**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: D-02, D-08
- **해소 위치**: [BP-25](25_world_state_and_save.md), [BP-28](28_migration_and_coexistence.md) · 태스크 **T-010 · T-011**

---

### G-10 콘텐츠 스키마와 검증기가 존재하지 않는다

- **증상**: "올바른 콘텐츠" 의 정의가 어디에도 없다. 맵 JSON 은 RPG Maker MV 포맷을 빌려 쓰고, `hadarEvent` 확장은 자유형 `Map<String, dynamic>` 이다.
- **근거**:
  ```dart
  // hadar2026_app/lib/domain/map/map_event.dart:18
  factory HadarEvent.fromJson(Map<String, dynamic> json) {
    return HadarEvent(
      kind: (json['kind'] as String?) ?? '',        // 빈 문자열도 통과
      payload: (json['payload'] is Map<String, dynamic>)
          ? json['payload'] as Map<String, dynamic>
          : const {},                               // 잘못된 타입은 조용히 {}
    );
  }
  ```
  `MapEvent.fromJson` 도 전부 `?? 기본값` 이라 어떤 입력도 거부하지 않는다(`map_event.dart:63`~`:91`).
  타입 판정은 이름 접두사 문자열 매칭이다 — 오타 하나면 `UNKNOWN` 이 되어 `ixEvent = 0`, 즉 **타일에 이벤트가 아예 안 붙는다**:
  ```dart
  // hadar2026_app/lib/domain/map/map_event.dart:54
  if (name.startsWith("TALK")) return "TALK";
  ...
  return "UNKNOWN";
  ```
  맵 에디터 쪽에는 `validate` 가 있지만 **지형 레이어 값 범위 검사**이지 콘텐츠 의미 검사가 아니다(`tools/mapEditor/server/ai_api.ts:345 validateMap`).
- **AI 파이프라인에 미치는 영향**: **검증 전부**. D-15 Hard gate 8개 항목(스키마 유효 · 미해결 참조 0 · 도달 불가 노드 0 · 퀘스트 사이클 0 · 솔버 완주 · 앵커-통행 충돌 0 · 문자열 키 누락 0 · 재빌드 해시 일치) 중 **현재 검사 가능한 것이 0개**다.
- **심각도**: **치명**
- **관련 결정**: D-03, D-05, D-12, D-15
- **해소 위치**: [BP-21](21_content_pack_spec.md), [BP-33](33_validation_and_lint.md), [BP-90](90_appendix_schemas.md)

---

### G-11 헤드리스 실행 경로가 끊겨 있다

- **증상**: 포트는 있는데 **하네스가 없다**. 그리고 포트만 채워도 게임이 돌지 않는다 — 이동과 상호작용이 Bonfire 컴포넌트 안에 있기 때문이다.
- **근거**: 입력 디스패처는 map 모드에서 이동/확인을 처리하지 않고 넘긴다.
  ```dart
  // hadar2026_app/lib/presentation/input/input_dispatcher.dart:149
  // Action (Enter/E) is handled by HDPlayerSprite for now to know
  // facing/position.
  return false;
  ```
  실제 처리는 Bonfire `update(dt)` 안의 **키보드 폴링**이다:
  ```dart
  // hadar2026_app/lib/presentation/panels/player_sprite.dart:122
  bool isActionKeyPressed =
      HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.enter) || ...
  ```
  이벤트 발화 3지점이 전부 `player_sprite.dart` 안이다(`:193`, `:362`, `:405`).
  더 나쁜 것: application 계층이 프로세스를 죽인다.
  ```dart
  // hadar2026_app/lib/application/menu_flows.dart:2
  import 'dart:io';
  // hadar2026_app/lib/application/menu_flows.dart:504, :522, :540
  exit(0);
  ```
  그리고 콘솔 출력이 줄마다 실시간 지연을 건다:
  ```dart
  // hadar2026_app/lib/presentation/host/flutter_ui_host.dart:137
  await Future.delayed(const Duration(milliseconds: 10));
  ```
  포트 도입 이전의 헤드리스 시도인 `lib/test_script.dart` 는 `HDHosts().bind` 가 없어 `StateError` 로 죽는다(BP-10 §9.4).
- **AI 파이프라인에 미치는 영향**: **검증 전부**. D-13 의 `SimDriver`/`QuestSolver` 가 설 자리가 없다. "생성된 퀘스트를 실제로 플레이해 본다" 는 D-14 6단계가 통째로 불가능.
- **심각도**: **치명**
- **관련 결정**: D-13, D-14-6
- **해소 위치**: [BP-34](34_headless_sim_and_solver.md) · 이동/상호작용 추출은 [BP-27](27_runtime_engine.md)

---

### G-12 콘텐츠 추가가 코드 수정과 재빌드를 요구한다

- **증상**: 새 맵에 로직을 붙이려면 Dart 파일을 만들고 **하드코딩된 Map 리터럴에 등록**한 뒤 앱을 다시 빌드해야 한다.
- **근거**:
  ```dart
  // hadar2026_app/lib/application/scripting/native_script_runner.dart:25
  final Map<String, HDMapScript Function()> mapScriptFactory = {
    'TOWN1': () => Town1MapScript(),
    'GROUND1': () => Ground1MapScript(),
    'TOWN2': () => Town2MapScript(),
    'DEN1': () => Den1MapScript(),
  };
  ```
  cm2 커맨드/함수도 마찬가지로 어댑터에 하드코딩 등록이다(`script_engine_adapter.dart:180`~`:580`, **커맨드 40 + 함수 12**;
  `grep -c "e.registerCommand('"` = 40, `grep -c "e.registerFunction('"` = 12).
  이 목록이 손으로 관리된다는 증거로, `Party::PosX`/`Party::PosY` 는 **커맨드(빈 구현, `:418`~`:419`)와 함수(`:545`~`:546`) 양쪽에 중복 등록**되어 있다.
  앰비언트 메시지처럼 순수 텍스트조차 Dart 리터럴이다:
  ```dart
  // hadar2026_app/lib/application/tile_event_dispatcher.dart:75
  await host.addLog("일행은 독이 있는 늪에 들어갔다 !!!", isDialogue: false);
  ```
- **AI 파이프라인에 미치는 영향**: **생성 / 유지보수**. D-01 이 정한 "Runtime 은 구워진 번들을 해석만 한다" 가 깨진다. 콘텐츠 PR 이 코드 PR 이 되어 CI·리뷰·릴리스가 전부 무거워진다. 웹 배포는 재빌드 없이는 갱신 불가.
- **심각도**: **높음**
- **관련 결정**: D-01, D-02, D-03
- **해소 위치**: [BP-20](20_target_architecture.md), [BP-21](21_content_pack_spec.md)

---

### G-13 세계관 SSoT 가 없어 생성물의 일관성 근거가 없다

- **증상**: 지명·인물·연대기·톤이 코드/맵/스크립트에 흩어져 있고, "이 세계에서 참인 것" 을 모아놓은 문서나 데이터가 없다.
- **근거**: 세계관 조각들의 현재 분포 —
  | 조각 | 실제 위치 |
  |---|---|
  | 지명 `로어성`, `로어 대륙`, `메너스`, `라스트디치` | 맵 JSON 의 `displayName` (BP-10 §7.1) |
  | 인물 `로드안 - 로어성의 성주` | `town1_map_script.dart:39` Dart 문자열 |
  | 인물 `Joe`(수감자) | `town1_map_script.dart:83` Dart 문자열 |
  | 파티원 `슴갈`(에스퍼) / `유리`(초능력자) | `party.dart:84`, `:110` 하드코딩 |
  | 적 75종 이름(`Lord Ahn`, `Ancient Evil` …) | `enemy_data.dart:33` const 테이블 |
  | `Lord Ahn` 이 푯말 서명으로도 등장 | `town1_map_script.dart:63` |
  | 마법 45종 이름 | `magic.dart:11` |
  같은 `로어성` 이 세 파일(`TOWN1.json`/`ORIGIN.json`/`Map014.json`)에 md5 동일로 중복 존재한다(BP-10 §7.1).
- **AI 파이프라인에 미치는 영향**: **생성 / 유지보수**. D-14-1 "컨텍스트 팩 구성(world bible + 기존 콘텐츠 요약 + 스타일 가이드)" 에 넣을 원본이 없다. 생성물이 기존 설정과 모순돼도 검수 에이전트가 판정할 기준이 없다.
- **심각도**: **높음**
- **관련 결정**: D-03(`world/`), D-14-1
- **해소 위치**: [BP-22](22_world_bible_model.md) · 문체는 [BP-43](43_content_style_guide.md)

---

### G-14 월드 이벤트 훅이 없어 게임 안 사건을 관측할 수 없다

- **증상**: 전투 승리·경험치 획득·금화 증가·맵 입장 같은 사건이 **로그 문자열로만 나타나고 사라진다**. 무엇이 일어났는지 프로그램이 알 수 없다.
- **근거**: 전투 승리 처리 전체가 로그 출력 + 필드 직접 증가다. 발행되는 이벤트가 없다.
  ```dart
  // hadar2026_app/lib/application/battle.dart:243 (gotoEndBattle, Win 분기)
  int totExp = enemies.fold(0, (xp, e) { int plus = e.data.id + 1;
    plus = (plus * plus * plus) ~/ 8; return xp + max(1, plus); });
  await _host.addLog("전투에서 승리하여 경험치 $totExp을 얻었다.");
  for (var p in _party.players) {
    if (p.isConscious()) { p.experience += totExp; if (p.checkLevelUp()) { ... } }
  }
  _party.gold += enemies.fold(0, (g, e) => g + e.level * 5);   // "Add dummy gold"
  ```
  맵 입장도 마찬가지다. `loadMapFromFile`(`game_session.dart:85`)이 발행하는 유일한 신호는 `setNewMap`(`:54`~`:58`) 안의
  **무인자 `notifyListeners()`** 이며, "어느 맵에서 어느 맵으로 갔는지" 를 담지 않는다:
  ```dart
  // hadar2026_app/lib/application/game_session.dart:54
  void setNewMap(MapModel newMap) {
    map = newMap;
    mapVersion++;
    notifyListeners();          // ← 무엇이 바뀌었는지 payload 없음
  }
  ```
  D-20 의 `map_changed {from, to}` 를 발행하려면 `from` 을 알아야 하는데 **현재 맵 이름 자체가 어디에도 없다**(BP-10 §6.2).
  `ChangeNotifier` 는 있지만 **"무엇이 바뀌었는지" 를 담지 않는 무인자 통지**다.
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. D-06 Objective.kind 의 `defeat` / `acquire` / `reach` 가 자동 진행될 방법이 없다. 시뮬레이터가 트레이스(D-13 산출물)를 뽑을 대상도 없다. 퀘스트가 "플래그 수동 세팅" 으로만 진행되면 생성 난이도가 폭증한다.
- **심각도**: **치명**
- **관련 결정**: D-11(`world_event_bus.dart`), D-16-6
- **해소 위치**: [BP-27](27_runtime_engine.md)

---

### G-15 NPC 에게 정체성이 없다

- **증상**: NPC 는 "타일에 붙은 TALK 액션" 일 뿐이다. 이름도, ID 도, 상태도, 소속도 없다. 같은 인물이 두 맵에 등장할 수 없다.
- **근거**: NPC 를 나타내는 유일한 흔적은 이벤트 이름 접두사 `NPC` 인데, **그 접두사조차 `ixEvent` 로 변환되지 않는다**:
  ```dart
  // hadar2026_app/lib/domain/map/map_event.dart:58
  if (name.startsWith("NPC")) return "NPC";
  ```
  ```dart
  // hadar2026_app/lib/application/map_loader.dart:57
  int eventType = 0;
  if (parsedEvent.type == "EVENT") eventType = 0x00010000;
  else if (parsedEvent.type == "TALK") eventType = 0x00020000;
  else if (parsedEvent.type == "SIGN") eventType = 0x00030000;
  else if (parsedEvent.type == "ENTER") eventType = 0x00040000;
  // "NPC" 는 어느 분기에도 없음 → eventType = 0 → 타일에 액션이 안 붙음
  ```
  → `NPC*` 로 이름 붙인 이벤트는 **대화가 아예 발화되지 않는다.**
  화자 표시는 헤더 문자열 한 줄로만 존재한다:
  ```cm2
  # hadar2026_app/assets/Map002.cm2:7
  		SetHeader("누군지 모르는 사람")
  ```
- **AI 파이프라인에 미치는 영향**: **생성 / 유지보수**. D-06 `Objective.talk_to(actorId)`, D-07 `Dialogue.speaker`, D-05 `npc_state(id, state)` 가 전부 착륙 불가. 캐릭터 일관성(같은 인물의 말투 유지)을 검수 에이전트가 검사할 단위가 없다.
- **심각도**: **치명**
- **관련 결정**: D-03(`actors/`), D-09, D-16-5
- **해소 위치**: [BP-26](26_entity_registry_and_anchors.md)

---

### G-16 표시 문자열에 키가 없다

- **증상**: 모든 텍스트가 리터럴이다. 중복 탐지·톤 감사·일괄 교정·번역이 전부 불가능하다.
- **근거**: 같은 성격의 텍스트가 세 종류 매체에 흩어져 있다.
  | 매체 | 예 |
  |---|---|
  | Dart 리터럴 | `tile_event_dispatcher.dart:117` `'@B푯말에 써 있기를:'`, `:76` `"일행은 독이 있는 늪에 들어갔다 !!!"` |
  | Dart 리터럴(메뉴) | `menu_flows.dart:34`~`:43` 메인메뉴 리스트(문자열 8개는 `:35`~`:42`), `:500` `"정말로 끝내겠습니까 ?"` |
  | cm2 문자열 | `Map002.cm2:8` `Talk("제가 철학적인 질문을 하나 해 보겠소.")` |
  | JSON `code=401` | `Map002.json` 22줄 |
  | 문자열 조립 | `battle.dart:453` `"${p.name}${p.name.sub1} ${p.getWeaponName()}${_getJosaRo(...)} ..."` |
  색 태그도 표현식 안에 섞인다(`@B`, `@G`, `@@` — `utils/hd_text_utils.dart:4`~`:21` 의 `colorTable` **17개 엔트리**: `'0'`~`'F'` 16 + `'G'` 1).
- **AI 파이프라인에 미치는 영향**: **생성 / 유지보수**. D-15 Soft gate 의 "문체 점수 · 대사 길이 분포 · 중복도 · 지역 톤 일치" 를 측정할 대상 집합을 만들 수 없다. D-07 의 `lines: [stringKey]` 도 착륙 불가.
- **심각도**: **높음**
- **관련 결정**: D-03(`strings/ko.json`), D-07, D-15, D-17(ko 만 구현하되 구조는 열어둠)
- **해소 위치**: [BP-24](24_dialogue_model.md), [BP-43](43_content_style_guide.md)

---

### G-17 난수와 시각에 시드가 없어 재현이 불가능하다

- **증상**: 같은 입력을 두 번 넣어도 다른 결과가 나온다. 회귀 골든도, 솔버 증명도, 최소 재현 시퀀스도 성립하지 않는다.
- **근거**: 시드 주입 지점이 코드베이스에 **0곳**이다.
  ```dart
  // packages/cm2_script/lib/src/cm2_script.dart:311
  return Random().nextInt(max);
  ```
  전투는 전부 무시드 난수다 — `battle.dart` 의 155, 174, 389, 427, 432, 440, 441, 474, 478, 479, 488, 503, 513, 514 (14곳). 도주 판정도 마찬가지(`menu_flows.dart:104`).
  최악은 벽시계다:
  ```dart
  // hadar2026_app/lib/domain/party/player.dart:71
  void damagedByPoison() {
    // 20 ~ 39 damage
    damaged(20 + (DateTime.now().millisecondsSinceEpoch % 20));
  }
  ```
- **AI 파이프라인에 미치는 영향**: **검증 전부**. D-01 이 "난수는 시드 기반만 허용" 이라 못박은 지점. D-05 의 `chance(percent)` op 도 "검증기에서 양 분기 모두 탐색" 을 전제하는데 그 전제가 깨진다. D-15 Hard gate 의 "결정론 재빌드 해시 일치" 도 런타임 쪽에서 무너진다.
- **심각도**: **치명** *(초판 "높음" 에서 상향 — D-01 "난수는 시드 기반만 허용" 과 D-15 Hard gate "결정론 재빌드 해시 일치" 를 **직접** 위반한다. 이것이 살아 있으면 D-14 6단계(sim)와 7단계(critic) 산출물을 신뢰할 수 없다)*
- **관련 결정**: D-01, D-05, D-08(`WorldState.seed`), D-15, **D-21**(`chance` 는 커서를 밀지 않는 무커서 해시)
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.** 태스크 **T-021** 이 "같은 시드·같은 입력열 2회 → 바이트 동일" 을 고정한다.
- **해소 위치**: [BP-27](27_runtime_engine.md), [BP-34](34_headless_sim_and_solver.md), [BP-35](35_ci_and_build.md) · 태스크 **T-017 ~ T-021 · T-142**

---

### G-18 맵 편집이 콘텐츠 정합성을 소리없이 깨뜨린다

- **증상**: 맵 에디터(또는 AI)가 타일 하나를 옮기면, 그 좌표에 묶여 있던 대사가 **경고 없이 죽거나 엉뚱한 곳에서 발화**한다.
- **근거**: 이벤트→타일 도장이 로드 시점에 좌표 기준으로만 찍힌다.
  ```dart
  // hadar2026_app/lib/application/map_loader.dart:55
  final unit = map.getUnit(parsedEvent.x, parsedEvent.y);
  if (unit != null) { ... unit.ixEvent = eventType | parsedEvent.id; }
  ```
  `unit == null`(맵 밖 좌표)이면 **아무 일도 일어나지 않고 아무도 모른다**. `map.events` 에는 남아 있지만 어떤 타일도 그것을 가리키지 않는다.
  반대로 `objUpper`(z3) 를 통행 가능 타일로 바꾸면 `getUnitAction` 이 `talk` 대신 `move` 를 반환해 대화가 사라진다(`tile_properties.dart:196`~`:205`).
  맵 에디터의 `validate` 는 레이어 raw 값 범위만 본다:
  ```ts
  // tools/mapEditor/server/ai_api.ts:370
  if (badCells.ground) issues.push({ severity: 'warning',
    message: `ground 에 A5 범위(0, 1536~1663) 밖 값 ${badCells.ground}개` });
  ```
  즉 **"이벤트가 걸린 좌표가 통행 가능해졌다" 를 검사하는 규칙이 없다.**
- **AI 파이프라인에 미치는 영향**: **유지보수 / 검증**. D-14-4(bind 단계에서 맵 에디터 API 로 앵커 배치)가 안전하지 않다. AI 가 맵과 콘텐츠를 동시에 만지는 순간 조용한 파손이 누적된다.
- **심각도**: **치명**
- **관련 결정**: D-09(앵커-통행 충돌 시 빌드 실패), D-15
- **해소 위치**: [BP-26](26_entity_registry_and_anchors.md), [BP-36](36_map_editor_extension.md)

---

### G-19 재진입 가드가 전역 bool 하나다

- **증상**: "한 번에 하나의 상호작용" 을 전역 플래그 하나로 지킨다. 실패해도 알림이 없고, 중첩 대화·큐잉·타임아웃 개념이 없다.
- **근거**:
  ```dart
  // hadar2026_app/lib/application/tile_event_dispatcher.dart:34
  bool _isScriptRunning = false;
  // :46
  if (_isScriptRunning) return;      // 조용히 무시
  ```
  이 플래그를 스크립트 어댑터가 **제어 흐름 분기에도 쓴다** — 부팅 경로인지 인게임 경로인지를 이걸로 판정한다:
  ```dart
  // hadar2026_app/lib/application/scripting/script_engine_adapter.dart:297
  if (HDTileEventDispatcher().isScriptRunning) { /* 지연 전환 */ }
  else { /* 즉시 전환 */ }
  ```
  발화 지점 중 하나는 **fire-and-forget** 이라 완료를 기다리지 않는다:
  ```dart
  // hadar2026_app/lib/presentation/panels/player_sprite.dart:192 (주석) / :193 (호출)
  // Fire-and-forget so we don't deadlock the next movement frame inside update(dt)
  HDGameMain().checkTileEvent(party.x, party.y, isInteraction: false);
  ```
  `finally` 에서만 해제되므로 예외가 나면 복구되지만, **중간에 `await` 가 여럿 있어** 그 사이 입력이 누락되는 것은 관측되지 않는다.
- **AI 파이프라인에 미치는 영향**: **검증**. 시뮬레이터가 입력을 빠르게 밀어 넣을 때 조용히 버려지는 상호작용이 생겨 "재현되지 않는 실패" 를 만든다. D-10 이 요구하는 "가드의 의미를 문서화하고 테스트로 고정" 이 아직 없다.
- **심각도**: **중간**
- **관련 결정**: D-10
- **해소 위치**: [BP-27](27_runtime_engine.md)

---

### G-20 세이브가 콘텐츠 버전을 모른다

- **증상**: `version: 1` 을 쓰기만 하고 읽지 않는다. 콘텐츠가 바뀐 뒤 옛 세이브를 불러도 아무 검사가 없다.
- **근거**:
  ```dart
  // hadar2026_app/lib/application/save_manager.dart:19 (saveGame 의 페이로드 첫 필드)
  'version': 1,
  ```
  `loadGame`(`save_manager.dart:37`~`:106`) 전체에 `data['version']` 참조가 **0건**. 마이그레이션 함수도, 거부 경로도 없다.
  게다가 세이브에 담긴 `map` 은 `MapUnit` 전량 스냅샷이므로(`map_model.dart:50`), **맵 파일이 바뀌어도 옛 세이브는 옛 지형을 그대로 되살린다** — 새 콘텐츠가 배치된 좌표가 옛 지형에서는 벽일 수 있다.
- **AI 파이프라인에 미치는 영향**: **유지보수**. 팩을 계속 얹어 나가는(D-03 "합성 가능") 모델에서 세이브 호환은 필수 전제인데 개념이 없다. 생성 콘텐츠를 배포할 때마다 기존 플레이어의 진행이 조용히 깨진다.
- **심각도**: **높음**
- **관련 결정**: D-03(`dependsOn`, `migrations`), D-08
- **해소 위치**: [BP-25](25_world_state_and_save.md)

---

### G-21 밸런스 데이터가 하드코딩되어 생성물이 참조할 수 없다

- **증상**: 적 능력치·경험치 곡선·마법 목록이 전부 Dart `const` 이므로, 생성 에이전트가 "Lv7 짜리 적" 이나 "이 보상이 적정한가" 를 조회할 수 없다.
- **근거**:
  ```dart
  // hadar2026_app/lib/domain/battle/enemy_data.dart:33
  const List<HDEnemyData> enemyTable = [
    HDEnemyData(id: 0, name: 'Orc', strength: 8, ..., level: 1),
    ... 총 75종 (id 0~74)
  ];
  ```
  경험치 테이블은 **같은 파일에 두 번** 하드코딩되어 있고 길이도 다르다:
  ```dart
  // hadar2026_app/lib/domain/party/player.dart:167   (checkLevelUp, 21개)
  final expTable = [0, 0, 1500, 6000, ..., 4560000, 5100000];
  // hadar2026_app/lib/domain/party/player.dart:250   (assignFromEnemyData, 20개 — 마지막 없음)
  final expTable = [0, 0, 1500, 6000, ..., 4560000];
  ```
  전투 보상식도 코드에 묻혀 있다(`battle.dart:243`~`:247` `(id+1)^3/8`, `:261`~`:264` `level*5` — 주석 자체가 `Add dummy gold`).
  마법 SP 비용은 인덱스 하나로 갈린다: `spCost = (magicId >= 33) ? 10 : 5` (`magic_system.dart:56`, `castSpell` 안).
  덤: `registerEnemy` 가 `enemyTableId <= 0` 을 거부해 **id 0(`Orc`) 은 cm2 로 소환 불가**다(`battle.dart:43` 메서드 / `:44` 가드).
  > ⚠ **두 숫자를 구분할 것.** 테이블 엔트리는 **75개**(id 0~74)지만 `<= 0` 가드 때문에
  > **콘텐츠가 참조 가능한 것은 74종(id 1~74)** 이다. 부록 B-1 이 "BP-21/22/23/42 는 **74종(id 1~74)** 기준" 을 규범으로 지시한다.
  > `_meta/GROUND_TRUTH.md` §10 의 "76종" 은 폐기. BP-10 §7.5 참조.
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. D-06 `Objective.defeat(enemyId, count)` 의 인자를 고를 근거가 없고, D-15 Soft gate 의 "보상 밸런스" 를 계산할 데이터가 런타임 밖에서 안 보인다.
- **심각도**: **높음**
- **관련 결정**: D-03(`items/`, 확장으로 `encounters/`), D-15
- **해소 위치**: [BP-21](21_content_pack_spec.md), [BP-42](42_item_and_inventory.md)

---

### G-22 MapInfos 등록 이름의 절반 가까이가 존재하지 않는 파일로 해석된다

- **증상**: `TOWN1` 을 로드하면 조용히 **3중 혼합 상태**가 된다 — ① 맵 지오메트리는 **직전 맵 그대로**, ② cm2 엔진에는 **직전 맵의 스크립트가 잔존**([G-29](#g-29-cm2-로드-실패가-엔진-상태를-누수시켜-티어-판정을-신뢰할-수-없게-만든다)),
  ③ `Town1MapScript` 만 새로 부착([G-31](#g-31-네이티브-맵-스크립트가-지오메트리-없는-맵에-바인딩된다)). 에러도, 화면 표시도 없고 `loadMapFromFile` 은 `true` 를 반환한다.
- **근거**: `MapInfos.json` 의 **어떤 엔트리에도 `cm2`/`json` 필드가 없어** 전부 `Map{id:03d}` 규칙을 탄다.
  ```dart
  // hadar2026_app/lib/application/map_navigation.dart:41
  final int id = info['id'];
  final idStr = id.toString().padLeft(3, '0');
  resolvedJsonName = 'Map$idStr.json';   // ← 이름 폴백을 덮어씀
  cm2Path = 'Map$idStr.cm2';
  ```
  등록 이름 15개 중 **7개**(`TOWN1`·`GROUND1`·`DEN1`·`DEN2`·`Template_TOWN`·`Prolog`·`Template_DUNGEON`)가 없는 파일을 가리킨다(BP-10 §7.2 표). 나머지 8개 중에서도 페어 cm2 가 실제로 존재하는 것은 `LORE_EP`·`MAP003` 둘뿐이다.
  그런데 JSON 로드가 실패해도 `null` 을 반환하지 않는다:
  ```dart
  // hadar2026_app/lib/application/map_navigation.dart:60
  } catch (e) {
    if (cm2Path == null) { errorMessage = "Failed to load map: $e"; return null; }
    print("HDMapNavigation: cm2-only map $searchName (no JSON: $e)");
  }
  return MapBundle(mapName: searchName, json: json, cm2Path: cm2Path);
  ```
  `cm2Path` 는 규칙상 항상 non-null 이므로 **JSON 이 없어도 "성공" 으로 취급**된다. 상위에서는 `json == null` 이면 `setNewMap` 을 건너뛴다(`game_session.dart:97`).
  동시에 `assets/maps/TOWN1.json`(=`ORIGIN.json`=`Map014.json`, md5 동일)은 `TOWN1` 이름으로는 도달할 수 없다.

  **역설: 등록하는 행위가 맵을 죽인다.** `map_navigation.dart:29` 의 이름 폴백은 이름이 인덱스에 **없을 때만** 살아남는다.

  ```dart
  // hadar2026_app/lib/application/map_navigation.dart:29
  String resolvedJsonName = '$searchName.json'; // Fallback
  ```

  | 이름 | MapInfos 등록 | 동명 `.json` | 결과 |
  |---|:--:|:--:|---|
  | `ORIGIN` | ❌ | ✅ | **정상 로드**(레거시 티어, `cm2Path == null`) |
  | `TOWN1` / `GROUND1` / `DEN1` / `DEN2` | ✅ | ✅ | 로드 실패 |

  즉 `ORIGIN` 이 **"등록 해제가 수리다" 의 산 증거**로 이미 동작 중이다(부록 F-4).
- **AI 파이프라인에 미치는 영향**: **생성 / 검증 / 유지보수**. AI 가 `TOWN1` 에 콘텐츠를 배치하면 그 콘텐츠는 실행되지 않는데 **아무도 실패를 보고하지 않는다**. 자산 인덱스를 신뢰할 수 없으면 앵커 바인딩(D-09)의 기반이 무너진다.
- **심각도**: **치명**
- **수리 선택지 2종** ([G-34](#g-34-g-22-의-수리는-두-갈래이고-더-싼-쪽이-누락되어-있었다) 에서 상세 비교):

  | 선택지 | 방법 | 비용 | `cm2Path` 잔존 문제(G-29) |
  |---|---|---|---|
  | ① 명시 참조 | 7개 엔트리에 `json`(+`cm2`) 필드 추가 | 엔트리 7개 편집 | **남는다** (`cm2Path` 여전히 non-null) |
  | ② **등록 해제** | `TOWN1`/`GROUND1`/`DEN1`/`DEN2` 엔트리 제거 | 엔트리 4개 삭제 | **동시 해소** (`cm2Path == null`) |

- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.** BP-10 §9.3 이 지적한 "자산 정합성 테스트 0건" 이 정확히 이 공백이다.
- **관련 결정**: D-09, D-15
- **해소 위치**: [BP-26](26_entity_registry_and_anchors.md), [BP-33](33_validation_and_lint.md) · 태스크 **T-004 · T-005 · T-006 · T-009** · 열린 질문 Q-10-01 / Q-11-03

---

### G-23 `hadarEvent` 확장이 파싱만 되고 디스패치되지 않는다

- **증상**: 맵 JSON 에 `warp`/`oneshot` 을 써도 아무 일이 일어나지 않는다. 맵 에디터 API 는 이미 쓰기를 지원해서 **써지긴 하는데 동작하지 않는다**.
- **근거**: 도메인 모델과 파서는 완비되어 있다.
  ```dart
  // hadar2026_app/lib/domain/map/map_event.dart:12
  /// - `"warp"`: payload `{ "map": String, "x": int, "y": int }`
  /// - `"oneshot"`: payload `{ "flag": int }`
  class HadarEvent { final String kind; final Map<String, dynamic> payload; }
  ```
  테스트도 파싱을 고정해 둔다(`test/domain/map/map_event_test.dart:31`).
  그러나 `hadarEvent` 를 **읽는 코드가 디스패처에 없다** — `_dispatchScripted`/`_emitJsonDialog` 어디에도 참조가 없다(`tile_event_dispatcher.dart:106`~`:179` 전문 확인).
  반면 에디터는 쓰기를 지원한다:
  ```ts
  // tools/mapEditor/server/ai_api.ts:166
  if ('hadarEvent' in body) { ... ev.hadarEvent = { kind, payload }; }
  ```
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. "성공적으로 저장됐다" 는 API 응답을 받고도 게임에서는 무시되는 **가짜 성공 신호**를 만든다. AI 에이전트가 잘못 학습하기 딱 좋은 형태.
- **심각도**: **높음** *(초판 "중간(단 위험도는 높음)" 의 각주와 등급이 어긋나 있었다 — 등급을 각주에 맞춰 상향)*
- **현재 이 결함을 잡아 줄 테스트/게이트**: **파싱만 고정되어 있다.** `test/domain/map/map_event_test.dart:31` 이 `hadarEvent{kind,payload}` 파싱을 검증하지만, **디스패치되는지는 아무도 확인하지 않는다** — 테스트의 존재가 오히려 "구현되어 있다" 는 착각을 만든다.
- **관련 결정**: D-09, D-10
- **해소 위치**: [BP-27](27_runtime_engine.md), [BP-36](36_map_editor_extension.md) · 태스크 **T-059 · T-118**

---

### G-24 `Battle::Result` 의 값 의미가 Dart 와 cm2 사이에서 어긋난다

- **증상**: cm2 스크립트가 `BATTLERESULT_LOSE` 로 패배를 검사하면 실제로는 **도주** 를 잡는다.
- **근거**:
  ```dart
  // hadar2026_app/lib/application/battle.dart:27
  int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away
  // hadar2026_app/lib/application/battle.dart:240
  if (_battleResult == 1) { /* Win: 경험치/금화 */ }
  else if (_battleResult == 0) { await _host.addLog("파티가 전멸했습니다."); await HDMenuFlows().processGameOver(2); }
  else if (_battleResult == 2) { await _host.addLog("무사히 도망쳤다..."); }
  ```
  ```cm2
  # hadar2026_app/assets/const.cm2:49
  variable(BATTLERESULT_EVADE)
  variable(BATTLERESULT_WIN)
  variable(BATTLERESULT_LOSE)
  BATTLERESULT_EVADE.assign(0)
  BATTLERESULT_WIN.assign(1)
  BATTLERESULT_LOSE.assign(2)
  ```
  | 값 | Dart | const.cm2 |
  |---:|---|---|
  | 0 | Lose | `EVADE` |
  | 1 | Win | `WIN` ✅ 일치 |
  | 2 | Run away | `LOSE` |

  **두 번째 독립된 이유: 초기값이 "승리" 다.** 선언 시점에도 `init()` 에서도 `1`(Win)로 설정된다.

  ```dart
  // hadar2026_app/lib/application/battle.dart:27
  int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away
  // :34~:41  init()
  void init() {
    enemies.clear(); playerCommands.clear(); isBattleActive = false;
    _battleResult = 1;                   // :38 — 다시 "승리"로
    selectedEnemyIndex = -1; notifyListeners();
  }
  ```

  `init()` 은 **맵 전환마다** 호출되고(`game_session.dart:95`), `Battle::Result` 함수는 그대로 노출된다:

  ```dart
  // hadar2026_app/lib/application/scripting/script_engine_adapter.dart:543
  e.registerFunction('Battle::Result', (_, __) => HDBattle().result());
  ```

  → `Battle::Start` 없이 `Battle::Result()` 를 읽는 cm2/콘텐츠는 **무조건 승리 분기**로 간다.
  **"전투 미발생" 을 표현하는 상태가 없다** — 승/패/도주 3상태뿐이고 그중 하나를 초기값으로 빌려 쓴다. 근거: 부록 F-3.
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. 생성 에이전트에게 줄 "cm2 상수 사전" 이 실제 런타임과 어긋난다. 전투 결과 분기를 쓰는 퀘스트가 조용히 반대로 동작하고, 전투를 안 했는데도 보상 분기가 열린다. 이런 계약 불일치가 하나라도 있으면 프롬프트 계약(D-12/[BP-37](37_prompt_contracts.md))의 신뢰가 무너진다.
- **심각도**: **높음**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: D-05(`start_battle`), D-12, D-20(`battle_won` 이벤트)
- **해소 위치**: [BP-28](28_migration_and_coexistence.md), [BP-27](27_runtime_engine.md) · 태스크 **T-025 · T-026 · T-027** · 열린 질문 Q-10-03

---

### G-25 `books.json` 에 아이템 데이터가 있으나 아무도 읽지 않는다

- **증상**: 무기 카탈로그가 이미 자산으로 존재하는데 로더가 없다. 게임은 `무기1`, `무기2` 라는 플레이스홀더를 계속 보여준다.
- **근거**:
  ```json
  // hadar2026_app/assets/maps/books.json
  { "weapon": [
    { "id": 1, "name": "맨손", "type": "NONE", "power": 1.0, "etc_data": [1,2,3,4],
      "etc_description": { "brief": [ { "image": "img_fist", "text": "무기를 장착하지 않은 상태이다. ..." } ] } },
    { "id": 2, "name": "단도", "type": "STAB", "power": 5.0, ... },
    { "id": 3, "name": "단검", "type": "WIELD", "power": 15.0, ... },
    { "id": 4, "name": "단창", "type": "STAB", "power": 20.0, ... } ] }
  ```
  ```bash
  $ grep -rn "books" hadar2026_app/lib
  # 0건
  ```
  스키마 자체는 쓸 만하다 — `type`(NONE/STAB/WIELD), `power`, 설명 텍스트 + 이미지 키까지 있다. 즉 **의도는 있었고 배선만 없다**.
- **AI 파이프라인에 미치는 영향**: **생성**. G-02 를 해소할 때 백지에서 시작할지 이 스키마를 계승할지가 결정되지 않아 아이템 ID 체계(D-04)의 출발점이 흔들린다.
- **심각도**: **낮음** *(초판 "중간" 에서 하향 — "영향" 절이 결함이 아니라 열린 질문(Q-10-04)을 서술하고 있었다. 실질은 [G-02](#g-02-아이템인벤토리가-정수-두-개뿐이다) 의 하위 각주 + 미사용 자산 정리 항목이다)*
- **다른 결함과의 관계**: **[G-02](#g-02-아이템인벤토리가-정수-두-개뿐이다) 의 하위 항목.** §2.2 집계에서 독립 결함으로 세지 않는다(§2.2.1).
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음**(미사용 자산이므로 잡을 것도 없다).
- **관련 결정**: D-03(`items/items.json`), D-04
- **해소 위치**: [BP-42](42_item_and_inventory.md) · 태스크 **T-099** · 열린 질문 Q-10-04

---

### G-26 계층 불변식이 선언과 강제 사이에 구멍이 있다

- **증상**: CLAUDE.md 가 "`dart:io` 금지, `services` 금지" 를 선언하지만 CI 는 검사하지 않고, 실제 위반이 있다.
- **근거**: CI 는 두 규칙만 검사한다.
  ```bash
  # .github/workflows/ci.yml:68
  check "..." -E "^import .*(presentation/|hd_game_main\.dart)"
  # .github/workflows/ci.yml:72
  check "..." -E "package:flutter/material|package:bonfire|package:flame"
  ```
  실측 위반:
  ```dart
  // hadar2026_app/lib/application/menu_flows.dart:2
  import 'dart:io';
  // :504 :522 :540
  exit(0);
  ```
  또한 `lib/utils/` 는 3계층 어디에도 속하지 않는 4번째 폴더이며 `flutter/material` 을 import 한다(`utils/hd_text_utils.dart:1`). presentation 만 쓰긴 하지만 규칙상 위치가 미정의다.
  분석 게이트도 느슨하다 — `flutter analyze --no-fatal-infos` 로 info 77건을 통과시킨다(`ci.yml:45`). `dart format` 게이트는 없다.

  **가장 무거운 축은 웹 빌드다**([G-33](#g-33-dartio-위반이-웹-빌드를-깨뜨리는지-ci-가-확인하지-않는다) 에서 상세). `dart:io` 는 웹에서 컴파일되지 않는데
  `import 'dart:io';`(2행) 은 `if (!kIsWeb)` 런타임 가드 **밖**에 있고, CI 는 `flutter build web` 을 돌리지 않는다.
- **AI 파이프라인에 미치는 영향**: **생성 / 유지보수 / 배포**. D-11 이 정한 `domain/content/` 의 "파일 I/O·UiHost 를 절대 모른다 → 그대로 CLI 검증기에서 재사용" 이 **기계적으로 보장되지 않는다**. AI 가 만든 코드가 `dart:io` 를 끌어들이면 검증기 빌드가 깨지는데 CI 는 통과시킨다. 그리고 D-14-8(생성물 배포)의 유일한 공개 경로인 웹이 이미 막혀 있을 가능성을 아무도 모른다.
- **심각도**: **높음** *(초판의 "중간" 에서 상향 — 웹 빌드 축이 누락되어 있었다)*
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.** D-23 이 CI 검사 추가를 확정했으나 아직 배선되지 않았고, **`exit(0)` 제거와 같은 변경으로 묶어야** CI 가 즉시 빨개지지 않는다.
- **관련 결정**: D-11, D-12, **D-23**
- **해소 위치**: [BP-35](35_ci_and_build.md) · 태스크 **T-022 · T-023 · T-024 · T-142**

---

### G-27 대화가 선형 로그 스트림이고 그래프 개념이 없다

- **증상**: 대사 출력이 `addLog` 를 순서대로 부르는 것뿐이다. 노드·분기·재진입·되돌아가기 같은 대화 구조가 표현되지 않는다.
- **근거**: 포트 API 자체가 스트림 형태다.
  ```dart
  // hadar2026_app/lib/application/ports/ui_host.dart:44
  Future<void> addLog(String message, {bool isDialogue = true});
  ```
  선택지는 별도 싱글턴에 누적하는 절차형이다:
  ```dart
  // hadar2026_app/lib/application/select.dart:23
  void add(String text) { ... items.add(text); }
  // :31
  Future<void> run() async { _lastResult = await HDHosts().ui.showMenu(items, clearLogs: false); }
  ```
  cm2 에서도 3단계 절차다(`Select::Init` → `Select::Add`×N → `Select::Run` → `Select::Result()`, `Map002.cm2:10`~`:19`).
  페이지 넘김은 호스트가 13줄에서 자동 처리한다:
  ```dart
  // hadar2026_app/lib/presentation/host/flutter_ui_host.dart:120
  if (consoleLog.events.length >= _maxLinesPerPage) { await waitForAnyKey(); consoleLog.clearEvents(); ... }
  ```
  `HDSelect` 는 **전역 싱글턴**이라 중첩 선택도 불가능하다 — 선택지 안에서 또 선택지를 열면 `items` 가 덮어써진다.
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. D-07 이 요구하는 "종료 노드까지 도달 가능해야 한다(빌드에서 도달성 검사)" 를 적용할 그래프가 없다. 선택지의 결과가 `int` 하나로만 돌아와 어떤 선택이 어떤 상태를 바꿨는지 추적 불가.
- **심각도**: **치명** *(초판 "높음" 에서 상향 — [G-07](#g-07-조건부-대사가-원리적으로-불가능하다)(치명)을 **포함하는 상위 개념**인데 등급이 더 낮아 역전되어 있었다)*
- **다른 결함과의 관계**: **G-07 을 하위로 포함한다.** §2.2 집계에서 G-07 은 이 항목에 종속시켜 이중 계상을 피한다(§2.2.1).
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: D-07
- **해소 위치**: [BP-24](24_dialogue_model.md), [BP-27](27_runtime_engine.md) · 태스크 **T-044 · T-054**

---

### G-28 진행 상태를 외부에서 관측·주입할 API 가 없다

- **증상**: 게임의 현재 상태를 덤프하거나, 특정 상태를 만들어 놓고 시작하는 방법이 없다. 디버그 커맨드도 없다.
- **근거**: 상태 접근은 전부 싱글턴 필드 직접 참조다. 직렬화 가능한 진입점은 `HDSaveManager` 뿐인데 그것은 `SharedPreferences` 에 묶여 있다:
  ```dart
  // hadar2026_app/lib/application/save_manager.dart:16
  final prefs = await SharedPreferences.getInstance();
  ```
  → 파일이나 문자열로 상태를 주고받을 수 없다.
  리셋 수단이 있는 싱글턴은 `HDHosts.reset()`, `HDFlutterUiHost.resetForTest()`, `HDBattle.init()`, `HDSelect.init()`, `HDWindowManager.clear()` 뿐이며, **`HDGameSession` / `HDScriptEngine` / `HDNativeScriptRunner` / `HDTileEventDispatcher` 는 리셋 수단이 없다**(BP-10 §3).
  디버그용 키는 시각 강제 4개뿐이다(`input_dispatcher.dart:127`~`:147` Insert/Delete/Home/End).
- **AI 파이프라인에 미치는 영향**: **검증**. D-13 의 "트레이스 JSON(모든 상호작용·상태 전이)" 과 "실패 시 최소 재현 시퀀스" 가 만들어질 수 없다. 테스트 간 상태 격리도 불완전해 시뮬레이션이 서로를 오염시킨다.
- **심각도**: **중간**
- **관련 결정**: D-08, D-11(`reset()` 요구), D-13
- **해소 위치**: [BP-34](34_headless_sim_and_solver.md), [BP-25](25_world_state_and_save.md)

---

### G-29 cm2 로드 실패가 엔진 상태를 누수시켜 티어 판정을 신뢰할 수 없게 만든다

- **증상**: 맵을 옮겨도 **직전 맵의 cm2 스크립트가 계속 실행**된다. 그러면서 겉으로는 정상 동작처럼 보인다.
- **근거**: `loadScript` 는 자산 로드에 실패하면 `clearRuntimeState()` 에 도달하기 **전에** 반환한다.
  ```dart
  // hadar2026_app/lib/application/scripting/script_engine_adapter.dart:92
  Future<void> loadScript(String assetPath) async {
    String content;
    try {
      content = await HDHosts().assets.loadString(assetPath);
    } catch (e) {
      print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
      return;                      // ← :103 의 clearRuntimeState() 미도달
    }
    ...
    _engine.clearRuntimeState();   // :103 — 성공했을 때만 실행
  ```
  그리고 **실패가 다수 경로다.** `cm2Path` 가 무조건 설정되기 때문이다:
  ```dart
  // hadar2026_app/lib/application/map_navigation.dart:44
  cm2Path = 'Map$idStr.cm2';       // MapInfos 에 cm2 필드가 0건이므로 항상 이 값
  ```
  `MapInfos.json` 등록 이름 15개 중 페어 cm2 파일이 실재하는 것은 **2개**(`LORE_EP`→`Map002.cm2`, `MAP003`→`Map003.cm2`)뿐 →
  **나머지 13개 맵으로 이동할 때마다 직전 맵의 `currentScript`·`variables`·`_contexts` 가 그대로 살아남는다.**
  동시에 `currentMapCm2Path` 는 실패와 무관하게 갱신되어 non-null 이므로(`game_session.dart:100`), 디스패처는 **티어 2(cm2)** 를 고른다:
  ```dart
  // hadar2026_app/lib/application/tile_event_dispatcher.dart:137
  if (cm2Path != null) {
    HDScriptEngine().setTargetPos(x, y);
    HDScriptEngine().setScriptMode(action.scriptMode);
    await HDScriptEngine().run();          // ← 직전 맵의 스크립트가 새 맵 좌표를 판정
    if (HDScriptEngine().handled) return;
    ...
  ```
- **AI 파이프라인에 미치는 영향**: **검증 / 유지보수**.
  - D-10 의 대전제 **"기존 3티어의 동작은 앵커가 없는 맵에서 그대로 보존된다 → 무중단 점진 이관"** 이 성립하지 않는다. **보존할 "기존 동작" 자체가 비결정적**이기 때문이다 — 같은 맵에 어디서 들어왔느냐에 따라 실행되는 cm2 가 달라진다.
  - 골든 회귀(D-15, 태스크 T-002)를 뜨면 **방문 순서에 따라 다른 값이 나온다.** 회귀 기준선을 만들 수 없다.
  - [G-09](#g-09-cm2-전역의-수명이-파일-존재-여부에-따라-정반대로-갈린다--assign-매-실행-재실행) 와 **정반대 방향의 결함이 공존**한다: G-09 는 "맵 전환마다 지워진다" 를 문제 삼는데, 실제로는 **지워지지 않는 경우가 13/15 로 더 흔하다.** 이 모순 자체가 "프롬프트 계약으로 상태 수명을 담을 수 없다" 는 논지를 강화한다.
- **심각도**: **치명**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.** `HDScriptEngine` 어댑터 테스트가 0건이다(BP-10 §9.3).
- **관련 결정**: D-10(선결 과제로 승격 필요), D-02
- **해소 위치**: [BP-28](28_migration_and_coexistence.md), [BP-27](27_runtime_engine.md) · 태스크 **T-010**(2줄 수정: catch 에서 `clearRuntimeState()` 선행 호출) **· T-011**
- **근거 자료**: `_meta/GROUND_TRUTH.md` 부록 A-1 · A-2

---

### G-30 등록된 심볼도 범위 밖 인자를 침묵 no-op 으로 삼킨다

- **증상**: `Flag::Set(300)` 은 **아무 일도 하지 않고 아무 로그도 남기지 않는다.** 문법도 심볼 이름도 전부 맞는데 조용히 죽는다.
- **근거**: 범위 검사에 `else` 가 없다.
  ```dart
  // hadar2026_app/lib/application/scripting/script_engine_adapter.dart:362
  e.registerCommand('Flag::Set', (stmt, eng) async {
    final flagId = eng.getVal(stmt.args[0]);
    final idx = flagId is num ? flagId.toInt() : int.tryParse(flagId.toString()) ?? -1;
    if (idx >= 0 && idx < HDConfig.maxFlags) {
      flags()[idx] = true;
    }                                  // ← else 없음
  });
  ```
  같은 형태의 실측 목록:

  | 심볼 | 위치 | 범위 밖일 때 |
  |---|---|---|
  | `Flag::Set` | `script_engine_adapter.dart:362` | 무음 no-op |
  | `Flag::Reset` | `:369` | 무음 no-op |
  | `Variable::Set` | `:376` | 무음 no-op |
  | `Variable::Add` | `:383` | 무음 no-op |
  | `Battle::RegisterEnemy` | `battle.dart:43`~`:46` (`<= 0` 또는 테이블 밖이면 `return`) | 무음 — **적이 안 나오는 전투**가 만들어진다 |
  | `Player::AssignFromEnemyData` | `script_engine_adapter.dart:410`~`:416` | 무음 no-op |
  | `Player::GetName` | `:548`~`:554` | `"Unknown"` **문자열 반환** (대사에 그대로 출력됨) |

- **[G-08](#g-08-cm2-는-미등록-심볼을-침묵으로-흘려보낸다) 과 무엇이 다른가**: G-08 은 **오타**를 잡는 이야기다. 이것은 **문법·이름이 전부 맞는 생성물**이 죽는 이야기다.
  LLM 이 `Flag::Set(300)` 이나 `Battle::RegisterEnemy(0)` 을 쓰는 것은 오타가 아니라 **인덱스 공간을 모르기 때문에 생기는 정상적인 실패**다.
  `flags[256]` / `variables[256]` 이라는 유한 공간과 "적 id 는 1~74" 라는 범위를 LLM 에게 전달할 방법이 현재 없고([G-03](#g-03-상태가-3중으로-분열되어-있고-전부-이름-없는-정수다), [G-21](#g-21-밸런스-데이터가-하드코딩되어-생성물이-참조할-수-없다)), 두 결함이 곱해진다.
- **왜 D-04 의 직접 근거인가**: **정수 인덱스에는 "범위 밖" 이라는 실패 양식이 내재한다.**
  `flag.gen_ep1.quest.missing_scholar.met_client` 같은 이름 있는 키에는 "범위" 라는 개념 자체가 없다 — 존재하거나 존재하지 않거나 둘 중 하나이고, 존재하지 않으면 **빌드가 미해결 참조로 잡는다**(D-15 Hard gate).
  즉 D-04(이름 있는 상태 키)는 취향 문제가 아니라 **실패 양식 하나를 구조적으로 제거하는 조치**다.
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. 린트가 잡아야 할 것이 "미등록 심볼" 만이 아니라 **"등록 심볼의 인자 범위"** 라는 뜻이다 — `Flag::Set(0..255)`, `Battle::RegisterEnemy(1..74)`, `Player::*(1..6)` 같은 **도메인 범위표**가 필요하다.
- **심각도**: **높음**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: **D-04**, D-05(닫힌 op 집합), D-15
- **해소 위치**: [BP-33](33_validation_and_lint.md)(인덱스 범위 린트), [BP-28](28_migration_and_coexistence.md) · 태스크 **T-028 · T-029 · T-072**
- **근거 자료**: 부록 F-1

---

### G-31 네이티브 맵 스크립트가 지오메트리 없는 맵에 바인딩된다

- **증상**: `Town1MapScript` 가 붙되 **좌표계는 직전 맵의 것**이다. `isOn(45, 8)` 이 다른 맵의 (45,8) 타일을 판정한다.
- **근거**: `bundle.json == null` 이면 `setNewMap` 은 건너뛰지만, **네이티브 부착 블록은 무조건 실행**된다.
  ```dart
  // hadar2026_app/lib/application/game_session.dart:97
  if (bundle.json != null) {
    setNewMap(bundle.json!);          // ← json 이 null 이면 맵은 직전 것 그대로
  }
  currentMapCm2Path = bundle.cm2Path;
  ...
  // :121~:128  (json 유무와 무관하게 실행)
  final factory = native.mapScriptFactory[bundle.mapName];
  if (factory != null) {
    native.currentMapScript = factory();
    native.currentMapScript!.onPrepare();
    native.currentMapScript!.onLoad(bundle.mapName, 0, 0);
  } else {
    native.currentMapScript = null;
  }
  return true;                        // :130 — 항상 "성공"
  ```
  `TOWN1`/`GROUND1`/`DEN1` 은 `Map004`/`005`/`006.json` 로드에 실패하므로([G-22](#g-22-mapinfos-등록-이름의-절반-가까이가-존재하지-않는-파일로-해석된다)) 정확히 이 경로를 탄다.
  게다가 `onLoad(bundle.mapName, 0, 0)` 의 첫 인자는 `prevMap` 자리인데 **현재 맵 이름이 넘어간다** — `Town1MapScript.onLoad`(`town1_map_script.dart:15`)가
  `if (prevMap == 'GROUND1')` 로 분기하므로 이 분기 역시 영원히 false 다.
- **[G-05](#g-05-네이티브-맵-스크립트의-플래그-헬퍼가-빈-스텁이다-현행-버그) 와 무엇이 다른가**: G-05 는 "조건 분기가 항상 false" 인 **플래그 스텁** 문제이고, 이것은 "좌표 판정이 다른 맵을 본다" 는 **바인딩** 문제다.
  **원인이 독립적이므로 G-05 를 고쳐도 이건 안 고쳐진다.** 둘을 합치면 결론은 **등록된 네이티브 맵 4종 중 정상 동작하는 것이 0개**다:

  | 맵 | 상태 |
  |---|---|
  | `TOWN1` / `GROUND1` / `DEN1` | 지오메트리 없이 부착 (G-31) + 플래그 스텁 (G-05) |
  | `TOWN2` | **이름 자체가 도달 불가** — `MapInfos.json` 에 없고 `TOWN2.json` 파일도 없어 `mapScriptFactory` 조회에 걸리지 않는다. `Town2MapScript`(83줄)는 **한 번도 실행된 적이 없는 코드**다(부록 G-2) |

- **AI 파이프라인에 미치는 영향**: **생성 / 검증 / 유지보수**. D-10 의 티어 1(native)이 **현재 0개 맵에서 동작**하므로, "네이티브 티어는 보존하고 그 위에 콘텐츠 티어를 얹는다" 는 이관 계획의 전제가 사실과 다르다. 이관 계획은 **"네이티브 티어는 이관할 동작이 없다"** 에서 출발해야 한다.
- **심각도**: **치명**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: D-10, D-09(앵커 바인딩의 전제)
- **해소 위치**: [BP-28](28_migration_and_coexistence.md), [BP-26](26_entity_registry_and_anchors.md) · 태스크 **T-012 · T-013 · T-112 · T-114**
- **근거 자료**: 부록 F-2 · G-2

---

### G-32 `Battle::Result()` 에 "전투 미발생" 상태가 없어 전투 없이도 승리를 반환한다

- **증상**: cm2/콘텐츠가 `Battle::Start` 없이 `Battle::Result()` 를 읽으면 **무조건 승리 분기**로 간다.
- **근거**: 초기값이 `1`(Win)이고, `init()` 도 그 값으로 되돌린다.
  ```dart
  // hadar2026_app/lib/application/battle.dart:27
  int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away
  // :34
  void init() {
    enemies.clear();
    playerCommands.clear();
    isBattleActive = false;
    _battleResult = 1;                 // :38
    selectedEnemyIndex = -1;
    notifyListeners();
  }
  ```
  `init()` 은 **맵 전환마다** 호출되고(`game_session.dart:95`), 함수는 무조건 노출된다:
  ```dart
  // hadar2026_app/lib/application/scripting/script_engine_adapter.dart:543
  e.registerFunction('Battle::Result', (_, __) => HDBattle().result());
  ```
  → 표현 가능한 상태가 **승/패/도주 3개뿐**이고, 그중 "승" 을 초기값으로 빌려 쓰고 있다. "아직 안 싸웠다" 를 표현할 값이 없다.
- **[G-24](#g-24-battleresult-의-값-의미가-dart-와-cm2-사이에서-어긋난다) 와의 관계**: G-24 는 **값의 의미가 뒤바뀐** 문제, 이것은 **상태 공간이 부족한** 문제다.
  두 결함이 독립적으로 존재하므로 `Battle::Result()` 는 **두 가지 이유로** 신뢰할 수 없다. 하나만 고쳐도 나머지가 남는다.
- **AI 파이프라인에 미치는 영향**: **생성 / 검증**. D-20 의 `battle_won {encounterId?, enemyIds}` 이벤트를 "전투 결과 폴링" 으로 구현할 수 없다 —
  폴링하면 전투 전에도 참이 된다. **이벤트 발행 지점을 전투 종료 확정 시점에 두어야만** 성립한다.
  D-05 의 전투 결과 조건도 4상태(미발생/승/패/도주)를 전제로 재정의되어야 한다.
- **심각도**: **높음**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: D-05(`start_battle`), **D-20**(`battle_won`)
- **해소 위치**: [BP-27](27_runtime_engine.md), [BP-28](28_migration_and_coexistence.md) · 태스크 **T-027**
- **근거 자료**: 부록 F-3

---

### G-33 `dart:io` 위반이 웹 빌드를 깨뜨리는지 CI 가 확인하지 않는다

- **증상**: 이 프로젝트의 **유일한 공개 배포 경로(GitHub Pages 웹)** 가 이미 막혀 있을 수 있는데, 확인할 방법이 파이프라인에 없다.
- **근거**: `dart:io` 는 웹에서 컴파일되지 않는다. 런타임 가드는 컴파일 실패를 막지 못한다 — `import` 는 가드 **밖**에 있다.
  ```dart
  // hadar2026_app/lib/application/menu_flows.dart:2
  import 'dart:io';                    // ← 가드 밖. 웹 컴파일 대상
  ...
  // :503
  if (!kIsWeb) {
    exit(0);                           // :504 — 런타임 가드는 여기에만
  }
  ```
  그런데 CI 는 웹 빌드를 돌리지 않는다:
  ```yaml
  # .github/workflows/ci.yml — app 잡의 스텝 전량
  #   flutter pub get → flutter analyze --no-fatal-infos → flutter test → 계층 grep 2종
  # .github/workflows/deploy_web.yml:3
  on:
    workflow_dispatch: # 수동 트리거   ← push/PR 트리거 없음
  # :28
    run: flutter build web --base-href "/Hadar2026/" --release
  ```
  `flutter test` 는 Dart VM 에서 돌므로 `dart:io` 를 문제없이 컴파일한다. → **회귀가 배포 버튼을 누를 때까지 감지되지 않는 구조.**
- **미확인**: 실제로 `flutter build web` 이 지금 실패하는지는 **본 감사에서 실빌드로 확인하지 못했다.** 확실한 것은 *확인 수단이 파이프라인에 없다*는 구조적 사실이다(Q-10-08 / Q-11-07).
- **[G-26](#g-26-계층-불변식이-선언과-강제-사이에-구멍이-있다) 과의 관계**: G-26 의 **세 번째 축**으로 흡수했으나, 파급 대상이 다르므로(계층 규칙 vs 배포 경로) 별도 ID 를 부여해 추적한다.
  §2.2 집계에서는 G-26 에 종속시켜 이중 계상을 피한다(§2.2.1).
- **AI 파이프라인에 미치는 영향**: **배포**. D-14 8단계(commit)의 종착점인 "생성된 콘텐츠를 플레이어에게 전달" 이 막혀 있을 가능성을 결함 목록이 모르고 있었다.
- **심각도**: **높음**
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.**
- **관련 결정**: **D-23**(CI 에 `^import 'dart:(io|html)'` 검사 추가 — 단 `exit(0)` 제거와 **같은 변경으로 묶어야** 함)
- **해소 위치**: [BP-35](35_ci_and_build.md) · 태스크 **T-022 · T-023 · T-024 · T-142**
- **근거 자료**: 부록 B-4-2

---

### G-34 G-22 의 수리는 두 갈래이고, 더 싼 쪽이 누락되어 있었다

- **증상**: 결함이 아니라 **수리 설계의 공백**이다. 초판은 G-22 의 해법으로 "MapInfos 에 `json`/`cm2` override 명시" 하나만 제시했는데,
  **더 싸고 부작용이 적은 두 번째 선택지가 있고 이미 동작 중인 증거까지 있다.**
- **근거**: 이름 폴백은 인덱스에 이름이 **없을 때만** 살아남는다.
  ```dart
  // hadar2026_app/lib/application/map_navigation.dart:29
  String resolvedJsonName = '$searchName.json'; // Fallback
  ...
  // :40~:44
  if (info != null && info['name'] == searchName) {
    final int id = info['id'];
    final idStr = id.toString().padLeft(3, '0');
    resolvedJsonName = 'Map$idStr.json';   // ← 매치되면 폴백을 덮어씀
    cm2Path = 'Map$idStr.cm2';             // ← cm2Path 도 여기서 non-null 이 됨
  ```
  `ORIGIN` 은 `MapInfos.json` 에 등록되어 있지 않아 폴백이 살아남고 `assets/maps/ORIGIN.json` 이 **정상 로드된다**(부록 F-4).
  `cm2Path == null` 이므로 디스패치는 레거시 티어(티어 3)를 타고, **[G-29](#g-29-cm2-로드-실패가-엔진-상태를-누수시켜-티어-판정을-신뢰할-수-없게-만든다) 의 잔존 문제도 겪지 않는다.**

  | 선택지 | 대상 | 편집량 | G-29 잔존 문제 | 적용 가능 범위 |
  |---|---|---|---|---|
  | ① 명시 참조 | 7개 엔트리에 `json`(+`cm2`) 추가 | 7행 편집 | **남는다** — `cm2Path` 가 여전히 non-null | 7개 전부 |
  | ② **등록 해제** | `TOWN1`/`GROUND1`/`DEN1`/`DEN2` 엔트리 삭제 | 4행 삭제 | **동시 해소** — `cm2Path == null` | 동명 json 이 있는 **4개만** |

  ②가 들어맞는 조건은 "파일 이름과 논리 이름이 이미 같다" 인데, `TOWN1.json`/`GROUND1.json`/`DEN1.json`/`DEN2.json` 4개가 **정확히 그렇다**(BP-10 §7.1).
  나머지 3개(`Template_TOWN`/`Prolog`/`Template_DUNGEON`)는 동명 파일이 없으므로 ① 이거나 "엔트리 삭제 + 맵 신규 작성" 이다.
- **AI 파이프라인에 미치는 영향**: **유지보수**. 수리 선택지를 잘못 고르면 G-22 만 닫히고 G-29 가 남아, **"맵은 제대로 로드되는데 엉뚱한 cm2 가 도는"** 더 헷갈리는 상태가 된다.
  또한 ②를 택하면 "인덱스는 **override 가 필요할 때만** 등록한다" 는 규칙이 서고, 이것이 앵커 바인딩(D-09)의 이름 해석 규칙과도 일관된다.
- **심각도**: **중간** *(결함 자체보다 설계 결정의 공백)*
- **현재 이 결함을 잡아 줄 테스트/게이트**: **없음.** 태스크 **T-009** 가 "등록 15 + ORIGIN 16케이스" 회귀 테스트로 두 선택지의 결과를 고정한다.
- **관련 결정**: D-09, D-15
- **해소 위치**: [BP-26](26_entity_registry_and_anchors.md) · 태스크 **T-004 · T-005 · T-009** · 열린 질문 Q-10-01 / Q-11-03
- **근거 자료**: 부록 D-1 · F-4

---

## 2. 결함 요약 매트릭스

### 2.1 결함 × 심각도 × 뿌리 × 해소 장 (34건)

"뿌리" 는 §2.2.1 의 뿌리 원인 코드다. "축" 은 생성(生) / 검증(檢) / 유지(維) / 배포(配) 중 막는 것.

| ID | 제목 | 심각도 | 축 | 뿌리 | 관련 결정 | 해소 장 · 태스크 |
|---|---|---|---|:--:|---|---|
| G-01 | 퀘스트/목표/저널 개념 0건 | 치명 | 生檢維 | R-A | D-06, D-16-1 | [BP-23](23_quest_model.md), [BP-41](41_journal_ui_spec.md) · T-043·T-055·T-104 |
| G-02 | 아이템·인벤토리가 정수 2개 | 치명 | 生 | R-B | D-05, D-16-2 | [BP-42](42_item_and_inventory.md) · T-099~T-103 |
| G-03 | 상태 3중 분열 + 무명 정수 | 치명 | 生檢維 | R-C | D-04, D-08, D-16-4 | [BP-25](25_world_state_and_save.md) · T-046·T-066 |
| G-04 | 세이브 v1 상태 누락(`events` 포함) | 높음 ↓ | 檢 | R-C | D-08, D-22 | [BP-25](25_world_state_and_save.md) · T-008·T-014·T-015·T-016·T-063 |
| G-05 | 네이티브 플래그 헬퍼가 빈 스텁 | 높음 ↓ | 檢 | R-G | D-10 | [BP-28](28_migration_and_coexistence.md) · T-033→T-111 |
| G-06 | 대사가 맵 좌표에 박힘 | 치명 | 生維 | R-D | D-09 | [BP-26](26_entity_registry_and_anchors.md) · T-045·T-118 |
| G-07 | 조건부 대사 불가 | 치명 ⊂G-27 | 生 | R-E | D-07, D-10, D-16-3 | [BP-24](24_dialogue_model.md), [BP-27](27_runtime_engine.md) · T-044·T-054·T-059 |
| G-08 | cm2 침묵 실패(미등록 심볼) | **치명** ↑ | 生檢 | R-F | D-02 | [BP-20](20_target_architecture.md), [BP-28](28_migration_and_coexistence.md) · T-032 |
| G-09 | cm2 전역 수명이 파일 존재로 갈림 | 높음 | 生維 | R-F | D-02, D-08 | [BP-25](25_world_state_and_save.md), [BP-28](28_migration_and_coexistence.md) · T-010·T-011 |
| G-10 | 콘텐츠 스키마·검증기 부재 | 치명 | 檢 | R-H | D-03, D-05, D-12, D-15 | [BP-21](21_content_pack_spec.md), [BP-33](33_validation_and_lint.md), [BP-90](90_appendix_schemas.md) · T-071~T-084 |
| G-11 | 헤드리스 실행 경로 끊김 | 치명 | 檢 | R-I | D-13, D-14-6 | [BP-34](34_headless_sim_and_solver.md), [BP-27](27_runtime_engine.md) · T-085~T-098 |
| G-12 | 콘텐츠 추가 = 코드 수정 + 재빌드 | 높음 | 生維 | R-H | D-01, D-02, D-03 | [BP-20](20_target_architecture.md), [BP-21](21_content_pack_spec.md) · T-052·T-068 |
| G-13 | 세계관 SSoT 부재 | 높음 | 生維 | R-J | D-03, D-14-1 | [BP-22](22_world_bible_model.md), [BP-43](43_content_style_guide.md) |
| G-14 | 월드 이벤트 훅 부재 | 치명 | 生檢 | R-K | D-11, D-16-6, **D-20** | [BP-27](27_runtime_engine.md) · T-050·T-051·T-109 |
| G-15 | NPC 정체성 부재 | 치명 | 生維 | R-D | D-03, D-09, D-16-5 | [BP-26](26_entity_registry_and_anchors.md) · T-045 |
| G-16 | 문자열 키 부재 | 높음 | 生維 | R-J | D-03, D-07, D-15 | [BP-24](24_dialogue_model.md), [BP-43](43_content_style_guide.md) |
| G-17 | 난수·시각에 시드 없음 | **치명** ↑ | 檢 | R-L | D-01, D-05, D-08, D-15, **D-21** | [BP-27](27_runtime_engine.md), [BP-34](34_headless_sim_and_solver.md), [BP-35](35_ci_and_build.md) · T-017~T-021·T-142 |
| G-18 | 맵 편집이 정합성을 조용히 파손 | 치명 ⊂G-06 | 檢維 | R-D | D-09, D-15 | [BP-26](26_entity_registry_and_anchors.md), [BP-36](36_map_editor_extension.md) · T-075 |
| G-19 | 재진입 가드가 전역 bool 1개 | 중간 | 檢 | R-I | D-10 | [BP-27](27_runtime_engine.md) · T-059 |
| G-20 | 세이브-콘텐츠 버전 호환 개념 부재 | 높음 | 維 | R-C | D-03, D-08 | [BP-25](25_world_state_and_save.md) · T-063·T-066 |
| G-21 | 밸런스 데이터 하드코딩 | 높음 | 生檢 | R-H | D-03, D-15 | [BP-21](21_content_pack_spec.md), [BP-42](42_item_and_inventory.md) · T-099 |
| G-22 | MapInfos 이름↔파일 불일치 | 치명 | 生檢維 | R-M | D-09, D-15 | [BP-26](26_entity_registry_and_anchors.md), [BP-33](33_validation_and_lint.md) · T-004~T-006·T-009 |
| G-23 | `hadarEvent` 미디스패치(가짜 성공) | **높음** ↑ | 生檢 | R-E | D-09, D-10 | [BP-27](27_runtime_engine.md), [BP-36](36_map_editor_extension.md) · T-059·T-118 |
| G-24 | `Battle::Result` 값 의미 충돌 | 높음 | 生檢 | R-N | D-05, D-12, D-20 | [BP-28](28_migration_and_coexistence.md), [BP-27](27_runtime_engine.md) · T-025·T-026 |
| G-25 | `books.json` 미사용 | **낮음** ↓ ⊂G-02 | 生 | R-B | D-03, D-04 | [BP-42](42_item_and_inventory.md) · T-099 |
| G-26 | 계층 불변식 강제 구멍 | **높음** ↑ | 生維配 | R-O | D-11, D-12, **D-23** | [BP-35](35_ci_and_build.md) · T-022~T-024·T-142 |
| G-27 | 대화가 선형 스트림, 그래프 없음 | **치명** ↑ | 生檢 | R-E | D-07 | [BP-24](24_dialogue_model.md), [BP-27](27_runtime_engine.md) · T-044·T-054 |
| G-28 | 상태 관측·주입 API 부재 | 중간 | 檢 | R-I | D-08, D-11, D-13 | [BP-34](34_headless_sim_and_solver.md), [BP-25](25_world_state_and_save.md) · T-091~T-093 |
| **G-29** | **cm2 로드 실패로 엔진 상태 누수 → 티어 판정 불신** | **치명** 🆕 | 檢維 | R-M | D-10, D-02 | [BP-28](28_migration_and_coexistence.md), [BP-27](27_runtime_engine.md) · **T-010**·T-011 |
| **G-30** | **등록 심볼도 범위 밖 인자를 침묵 no-op** | **높음** 🆕 | 生檢 | R-F | **D-04**, D-05, D-15 | [BP-33](33_validation_and_lint.md), [BP-28](28_migration_and_coexistence.md) · T-028·T-029·T-072 |
| **G-31** | **네이티브 맵이 지오메트리 없는 맵에 바인딩** | **치명** 🆕 | 生檢維 | R-M | D-10, D-09 | [BP-28](28_migration_and_coexistence.md), [BP-26](26_entity_registry_and_anchors.md) · T-012·T-013·T-112 |
| **G-32** | **`Battle::Result()` 에 "전투 미발생" 상태 없음** | **높음** 🆕 | 生檢 | R-N | D-05, **D-20** | [BP-27](27_runtime_engine.md), [BP-28](28_migration_and_coexistence.md) · **T-027** |
| **G-33** | **`dart:io` 웹 빌드 파손 여부를 CI 가 미검증** | **높음** 🆕 ⊂G-26 | 配 | R-O | **D-23** | [BP-35](35_ci_and_build.md) · T-022~T-024·T-142 |
| **G-34** | **G-22 의 더 싼 수리(등록 해제)가 누락** | **중간** 🆕 | 維 | R-M | D-09, D-15 | [BP-26](26_entity_registry_and_anchors.md) · T-004·T-005·T-009 |

범례: 🆕 재검수에서 신규 등록 · ↑↓ 초판 대비 심각도 조정 · ⊂ 다른 결함의 하위 항목(집계 시 이중 계상하지 않음)

### 2.2 심각도 분포

| 심각도 | 총 등록 | 하위 항목 제외한 **독립 결함** | ID |
|---|---:|---:|---|
| **치명** | 16 | **14** | G-01, G-02, G-03, G-06, G-08↑, G-10, G-11, G-14, G-15, G-17↑, G-22, G-27↑, **G-29**, **G-31** · *(하위 2: G-07⊂G-27, G-18⊂G-06)* |
| **높음** | 14 | **13** | G-04↓, G-05↓, G-09, G-12, G-13, G-16, G-20, G-21, G-23↑, G-24, G-26↑, **G-30**, **G-32** · *(하위 1: G-33⊂G-26)* |
| **중간** | 3 | 3 | G-19, G-28, **G-34** |
| **낮음** | 1 | 0 | G-25 ⊂G-02 |
| **합계** | **34** | **30** | 신규 6건(G-29~G-34) 포함 |

**초판 대비 변동 내역**

| 구분 | 내용 |
|---|---|
| 신규 등록 | G-29(치명) · G-30(높음) · G-31(치명) · G-32(높음) · G-33(높음) · G-34(중간) — **+6** |
| 상향 | G-08 높음→치명(D-02 의 유일한 근거) · G-17 높음→치명(D-01·D-15 직접 위반) · G-27 높음→치명(G-07 역전 해소) · G-23 중간→높음(각주와 등급 일치) · G-26 중간→높음(웹 빌드 축 추가) |
| 하향 | G-04 치명→높음(G-28 과 논거 중복) · G-05 치명→높음(2줄 수정) · G-25 중간→낮음(결함이 아니라 열린 질문) |
| 구조 정리 | 하위 항목 4건 지정(G-07·G-18·G-25·G-33) → 이중 계상 제거 |

> **치명 비율은 개선되지 않았다 — 46%(13/28) → 47%(16/34)** 이며 독립 기준으로도 14/30 = 47% 다.
> 하향 3건보다 상향 3건 + 신규 치명 2건이 더 컸기 때문이다. 검수가 지적한 **등급 역전(G-07⊂G-27)과 이중 계상은 해소**됐고
> "낮음 0건" 도 해소됐으나, **비율 자체는 문제가 아니라 실측 결과**다 — 재검수에서 새로 찾은 것이 하필 둘 다 치명이었다(G-29·G-31).
> §2.3 의 임계 경로 논증은 등급이 아니라 **담당 장 건수와 뿌리(§2.2.2)** 로 하고 있으므로 이 비율에 의존하지 않는다.

#### 2.2.1 이중 계상 정리 — 부분집합 4쌍

| 상위 | 하위 | 관계 |
|---|---|---|
| G-27 대화 그래프 부재 | **G-07** 조건부 대사 불가 | G-07 은 G-27 의 "조건부 진입" 축. G-27 을 치명으로 올리고 G-07 을 종속시켜 역전 해소 |
| G-06 대사가 좌표에 박힘 | **G-18** 맵 편집이 정합성 파손 | 같은 뿌리(좌표가 유일 식별자)의 저작 측면 / 편집 측면 |
| G-02 인벤토리 부재 | **G-25** `books.json` 미사용 | G-25 는 G-02 해소 시 자연히 흡수되는 자산 정리 항목 |
| G-26 계층 불변식 구멍 | **G-33** 웹 빌드 미검증 | 같은 `dart:io` 위반의 계층 측면 / 배포 측면. 파급 대상이 달라 ID 는 분리 유지 |

**독립적이라 합치면 안 되는 쌍**(원인이 다르므로 하나를 고쳐도 나머지가 남는다):

| 쌍 | 왜 독립인가 |
|---|---|
| G-05 ↔ G-31 | 플래그 스텁(조건이 항상 false) vs 바인딩(좌표가 다른 맵) |
| G-08 ↔ G-30 | 오타(미등록 심볼) vs 정상 심볼의 범위 밖 인자 |
| G-24 ↔ G-32 | 값 의미 역전 vs 상태 공간 부족 |
| G-09 ↔ G-29 | "지워진다" 축 vs "안 지워진다" 축 — **정반대 방향의 결함이 공존** |

### 2.2.2 뿌리 원인 15종

34건은 실제로는 **15개 뿌리**에서 나온다. 로드맵([BP-50](50_roadmap.md))이 결함 단위가 아니라 뿌리 단위로 잡히면 임계 경로가 짧아진다.

| 뿌리 | 이름 | 결함 | 주 담당 장 |
|---|---|---|---|
| R-A | 퀘스트 개념 부재 | G-01 | BP-23 |
| R-B | 아이템 개념 부재 | G-02, G-25 | BP-42 |
| R-C | 상태·세이브 분열 | G-03, G-04, G-20 | BP-25 |
| R-D | **좌표가 유일 식별자** | G-06, G-15, G-18 | BP-26 |
| R-E | 대화 구조 부재 | G-07, G-23, G-27 | BP-24 |
| R-F | cm2 계약 부재 | G-08, G-09, G-30 | BP-28 |
| R-G | 네이티브 헬퍼 미구현 | G-05 | BP-28 |
| R-H | 콘텐츠 계약·배포 결합 | G-10, G-12, G-21 | BP-21 |
| R-I | 실행 경로가 presentation 에 묶임 | G-11, G-19, G-28 | BP-34 |
| R-J | 세계관·문자열 SSoT 부재 | G-13, G-16 | BP-22 |
| R-K | 이벤트 관측 불가 | G-14 | BP-27 |
| R-L | 결정론 부재 | G-17 | BP-27 |
| R-M | **맵 이름 해석 파손** | G-22, G-29, G-31, G-34 | BP-28 |
| R-N | 전투 결과 계약 파손 | G-24, G-32 | BP-27 |
| R-O | 계층·배포 게이트 구멍 | G-26, G-33 | BP-35 |

**R-M(맵 이름 해석 파손)이 단일 뿌리로 결함 4건**을 낳고, 그중 2건이 치명이다. 그런데 수리는 M0 태스크 6개(T-004~T-006, T-009~T-013)로 끝난다 —
**투입 대비 회수가 가장 큰 뿌리**이며, 이것이 §2.4 가 M0 을 먼저 하라고 말하는 이유다.

### 2.3 해소 장별 부담

| 장 | 담당 결함 | 건수 |
|---|---|---:|
| [BP-27](27_runtime_engine.md) 런타임 엔진 | G-07, G-11, G-14, G-17, G-19, G-23, G-24, G-27, G-29, G-32 | **10** |
| [BP-28](28_migration_and_coexistence.md) 공존·이관 | G-05, G-08, G-09, G-24, G-29, G-30, G-31, G-32 | **8** |
| [BP-26](26_entity_registry_and_anchors.md) 엔티티·앵커 | G-06, G-15, G-18, G-22, G-31, G-34 | 6 |
| [BP-25](25_world_state_and_save.md) 월드 상태·세이브 | G-03, G-04, G-09, G-20, G-28 | 5 |
| [BP-33](33_validation_and_lint.md) 검증·린트 | G-10, G-22, G-30 | 3 |
| [BP-24](24_dialogue_model.md) 대화 그래프 | G-07, G-16, G-27 | 3 |
| [BP-42](42_item_and_inventory.md) 아이템·인벤토리 | G-02, G-21, G-25 | 3 |
| [BP-34](34_headless_sim_and_solver.md) 헤드리스 | G-11, G-17, G-28 | 3 |
| [BP-35](35_ci_and_build.md) CI·빌드 | G-17, G-26, G-33 | 3 |
| [BP-21](21_content_pack_spec.md) 팩 스펙 | G-10, G-12, G-21 | 3 |
| [BP-36](36_map_editor_extension.md) 맵 에디터 확장 | G-18, G-23 | 2 |
| [BP-20](20_target_architecture.md) 목표 아키텍처 | G-08, G-12 | 2 |
| [BP-43](43_content_style_guide.md) 문체 | G-13, G-16 | 2 |
| [BP-23](23_quest_model.md) 퀘스트 모델 | G-01 | 1 |
| [BP-22](22_world_bible_model.md) 세계관 | G-13 | 1 |
| [BP-41](41_journal_ui_spec.md) 저널 UI | G-01 | 1 |
| [BP-90](90_appendix_schemas.md) 스키마 부록 | G-10 | 1 |

**읽는 법**: BP-27(10건)과 BP-28(8건)이 최다다. 초판에서는 BP-27 7건 · BP-25 5건이었는데, 신규 4건(G-29·G-31·G-32·G-30)이
전부 **레거시 공존 축**에 걸리면서 BP-28 이 2위로 올라왔다. 즉 **"새 것을 만드는 일" 보다 "옛 것을 신뢰 가능하게 만드는 일" 의 비중이 커졌다.**

### 2.4 "지금 당장 고칠 수 있는 것" — M0 선행 수리 8건

아키텍처 변경 없이 처리 가능하며, 이후 모든 작업의 기준선을 정직하게 만드는 항목. 태스크 번호는 [BP-51](51_task_breakdown.md).

| # | 결함 | 수리 내용 | 태스크 | **검증 수단** | 왜 먼저인가 |
|---:|---|---|---|---|---|
| 1 | **G-29** | `loadScript` 의 catch 블록에서 `clearRuntimeState()` 를 선행 호출 (2줄) | **T-010** | 맵 전환 후 `_engine.currentScript.length == 0` 을 단언 | **이것이 안 되면 골든 자체를 못 뜬다.** 방문 순서에 따라 결과가 달라진다 |
| 2 | **G-22 / G-34** | `MapInfos.json` 정리 — 선택지 ①(json 명시) 또는 ②(등록 해제) 결정 후 적용 | **T-004 · T-005** | 자산 정합성 테스트: "MapInfos 의 모든 name + ORIGIN 16케이스가 실제 로드 가능"(**T-009**) | 자산 인덱스를 신뢰할 수 없으면 앵커 바인딩의 기반이 없다 |
| 3 | **G-31** | 네이티브 부착에 `bundle.json != null` 가드 | **T-012** | 지오메트리 없는 전환 후 `currentMapScript == null` 단언(**T-013**) | 네이티브 티어가 "0개 맵에서 동작" 인 것을 먼저 드러내야 이관 계획이 정직해진다 |
| 4 | **G-05** | `HDMapScript.isFlagSet`/`setFlag` → `HDNativeScriptRunner` 위임 | **T-033** → **T-111** | T-033 이 "항상 false" 를 먼저 고정 → T-111 이 뒤집고 `approvedDeltas` 에 등재 | 지금 골든을 뜨면 버그가 정본이 된다 |
| 5 | **G-24 / G-32** | 전투 결과 정본 확정 + 상수 통일 + "미발생" 상태 추가 | **T-025 · T-026 · T-027** | `test/domain/battle/battle_result_test.dart` 로 `const.cm2` 상수와 Dart 값의 일치를 고정 | 프롬프트 계약(BP-37)의 신뢰 전제 |
| 6 | **G-26 / G-33** | CI 계층 grep 에 `^import 'dart:(io\|html)'` 추가 + `exit(0)` 3곳을 `UiHost` 종료 요청으로 대체 (**같은 변경으로**) | **T-022 · T-023 · T-024** | CI 검사 통과 + `flutter build web --release` 스모크 추가(**T-142**) | 헤드리스 하네스의 선결 조건. D-23 이 순서를 못박았다 |
| 7 | **G-17** | `WorldRng` 도입 → `Random()` 14곳 + `player.dart:71` 벽시계 교체 | **T-017 ~ T-020** | 같은 시드·같은 입력열 2회 실행 → 파티 HP·전투 로그 **바이트 동일**(**T-021**) | 재현성이 없으면 이후 모든 검증이 무의미 |
| 8 | **G-30** | `Flag::Set/Reset`·`Variable::Set/Add`·`registerEnemy` 의 범위 밖 인자에 경고 로그 | **T-028 · T-029** | 범위 밖 호출 시 경고가 남는지 단언 | 침묵 실패를 관측 가능하게 만드는 것이 린트 설계(BP-33)의 입력 |

**추가 정리 항목**(동작 변화 0, 골든 diff 없음): `Party::PosX`/`PosY` 의 중복 커맨드 등록 제거(**T-030**),
RPG Maker `code 101` 서술 정정(**T-031**), D-02 근거에서 "튜링 완전" 논거 제거(**T-032**).

### 2.5 부록 검증 사실 21건과의 대응

`_meta/GROUND_TRUTH.md` 부록 A~F 의 검증 사실은 **21건**(A-1~A-4, B-1~B-4, C-1~C-4, D-1~D-2, E-1~E-3, F-1~F-4)이며,
그중 **E-1·E-3 두 건은 코드 결함이 아니라 기획서 서술 정정**이다. 나머지 **19건이 코드/데이터 문제**다(부록 G-1).

| 부록 | 사실 | 성격 | 본 장의 결함 |
|---|---|---|---|
| A-1 | 모든 등록 맵에 없는 cm2 경로가 무조건 부여 | 코드 | G-29 · G-22 |
| A-2 | cm2 로드 실패가 엔진 상태 누수 | 코드 | **G-29** |
| A-3 | 네이티브 플래그 스텁 | 코드 | G-05 |
| A-4 | 에셋 선언 비재귀 | 코드 | G-12 (BP-10 §7.10) |
| B-1 | 적 75엔트리 / 참조 가능 74종 | 데이터 | G-21 |
| B-2 | 전투 결과 코드 역전 | 코드 | G-24 |
| B-3 | 헤드리스 장벽은 상호작용 코드 위치 | 코드 | G-11 |
| B-4 | `dart:io` + `exit(0)` (3문제) | 코드 | G-26 · **G-33** · G-11 |
| C-1 | `MapModel.toJson` 이 `events` 누락 | 코드 | **G-04** |
| C-2 | 세이브 로드가 네이티브 스왑 건너뜀 | 코드 | **G-04** |
| C-3 | 맵 스냅샷이 웹 저장 한계 근접 | 코드 | G-04 (BP-10 §6.2.2) |
| C-4 | 결정론 위반 실측 | 코드 | G-17 |
| D-1 | 등록 이름 7개가 없는 파일로 해석 | 데이터 | G-22 · **G-34** |
| D-2 | 로드 실패가 실패로 보고되지 않음 | 코드 | G-22 · G-31 |
| E-1 | `code 101` 은 텍스트 헤더가 아니다 | **서술 정정** | — (BP-10 §7.12, T-031) |
| E-2 | MV `pages` 선택 규칙이 `entry` 와 정반대 | 데이터 | — (BP-10 §7.12, BP-24 이관 규칙) |
| E-3 | cm2 는 튜링 완전이 아니다 | **서술 정정** | — (G-08 주석, T-032) |
| F-1 | 등록 커맨드의 범위 밖 인자 무시 | 코드 | **G-30** |
| F-2 | 네이티브가 지오메트리 없는 맵에 바인딩 | 코드 | **G-31** |
| F-3 | `Battle::Result()` 가 전투 없이 승리 반환 | 코드 | **G-32** |
| F-4 | `ORIGIN.json` 은 정상 로드된다 | 데이터 | **G-34** (역설의 증거) |
| G-2 | `TOWN2` 는 이름 자체가 도달 불가 | 코드 | G-31 |

→ **코드/데이터 문제 19건 + G-2 가 전부 결함 ID 에 대응되었다.** 서술 정정 2건(E-1·E-3)은 결함이 아니므로
BP-10 §7.12 · G-08 주석에서 사실을 바로잡는 것으로 처리했고, 태스크 T-031·T-032 가 나머지 장의 문장을 정정한다.

---

## 3. 요약

### 3.1 이 장이 확정한 것

1. **현 구조로 AI 자동 생성은 불가능하다** — 생성 타깃 표현, 검증 계약, 실행 하네스 셋 다 없다(§0.2).
2. **그러나 전면 재작성은 필요 없다** — 포트 3종 + CI 계층 강제 + 3티어 폴백 + 맵 에디터 AI API 라는 확장 기반이 이미 있다(§0.3). 단 포트는 **출발점이지 완성품이 아니다**(G-11).
3. **결함 34건을 등록했다** — 치명 16 · 높음 14 · 중간 3 · 낮음 1. 하위 항목 4건(G-07·G-18·G-25·G-33)을 제외한 **독립 결함은 30건**(§2.2). 각 결함은 `파일:줄` 근거, 막는 축, 뿌리 코드, 관련 결정, 해소 장 + 태스크 번호, **현재 이 결함을 잡아 줄 게이트** 를 갖는다.
4. **재검수에서 6건이 추가되었다**(G-29~G-34). 그중 2건(G-29 엔진 상태 누수 · G-31 지오메트리 없는 바인딩)은 **치명**이며, 초판이 놓쳐서 G-22 의 증상 서술을 실제와 다르게 만들고 있었다.
5. **"현재 동작을 보존한다" 는 이관 전제가 성립하지 않는다.** G-29 때문에 보존할 동작 자체가 비결정적이다 — 같은 맵에 어디서 들어왔느냐에 따라 실행되는 cm2 가 달라진다. **D-10 의 티어 0 을 얹기 전에 티어 판정 정상화가 선결 과제**다.
6. **네이티브 티어는 현재 정상 동작하는 맵이 0개다.** G-05(플래그 스텁) · G-31(지오메트리 없는 바인딩) · 부록 G-2(`TOWN2` 도달 불가) 세 원인이 독립적으로 작용한다. 이관 계획은 "네이티브 티어는 **이관할 동작이 없다**" 에서 출발해야 한다.
7. **침묵 실패는 한 계열이 아니라 두 계열이다.** 오타(G-08, 미등록 심볼)와 **정상 심볼의 범위 밖 인자**(G-30)는 원인이 다르다. 후자는 **정수 인덱스에 내재한 실패 양식**이며, D-04(이름 있는 상태 키)가 그것을 구조적으로 제거한다는 논증의 직접 근거다.
8. **`Battle::Result()` 는 두 가지 독립된 이유로 신뢰 불가**다 — 값 의미 역전(G-24)과 "전투 미발생" 상태 부재(G-32). 하나만 고쳐도 나머지가 남는다.
9. **D-16 의 최소 집합 6개가 전부 실측으로 뒷받침된다**(§0.4). "게임 변경" 파트의 스코프는 임의 선택이 아니라 결함에서 도출된 것이다.
10. **34건은 실제로는 15개 뿌리에서 나온다**(§2.2.2). 그중 **R-M(맵 이름 해석 파손)이 단일 뿌리로 결함 4건**(G-22·G-29·G-31·G-34, 치명 2)을 낳는데 수리는 M0 태스크 6개로 끝난다 — **투입 대비 회수가 가장 큰 뿌리**.
11. **임계 경로는 BP-27(10건)과 BP-28(8건)** 이다(§2.3). 초판은 BP-27·BP-25 였는데, 신규 4건이 전부 레거시 공존 축에 걸리면서 **"새 것을 만드는 일" 보다 "옛 것을 신뢰 가능하게 만드는 일" 의 비중이 커졌다.**
12. **아키텍처와 무관한 M0 선행 수리 8건이 존재하고, 각각 검증 수단이 명시되어 있다**(§2.4). 이것을 먼저 하지 않으면 이후 골든·시뮬레이션이 버그를 정본으로 굳힌다.
13. **부록 검증 사실 21건 중 코드/데이터 문제 19건 + 부록 G-2 가 전부 결함 ID 에 대응된다**(§2.5). 나머지 2건(E-1 `code 101`, E-3 튜링 완전)은 **결함이 아니라 기획서 서술 정정**이며 태스크 T-031·T-032 로 처리된다.

### 3.2 다음 장으로 넘긴 것

| 주제 | 이관 대상 |
|---|---|
| 각 결함의 **해결 설계** | §2.1 "해소 장" 열의 각 문서 |
| 타 게임/툴이 같은 문제를 어떻게 풀었는가 | [BP-12](12_reference_designs.md) |
| 결함 해소 순서·의존성·추정 | [BP-50](50_roadmap.md), [BP-51](51_task_breakdown.md) |
| 결함이 해소되지 **않았을 때의 리스크** 정량화 | [BP-52](52_risks.md) |
| "해소되었다" 의 판정 기준 | [BP-53](53_acceptance_criteria.md) |
| G-01~G-34 를 관통하는 엔드투엔드 예제 | [BP-91](91_appendix_worked_example.md) |
| 뿌리 15종(§2.2.2)을 마일스톤에 배치하는 순서 | [BP-50](50_roadmap.md) |

### 3.3 열린 질문

| ID | 질문 | 왜 지금 답이 없는가 |
|---|---|---|
| Q-11-01 | 치명 16건(독립 기준 14건)을 **전부** 해소해야 1차 릴리스가 가능한가, 아니면 부분 집합으로 "AI 가 조건부 대사만 생성" 하는 축소 스코프가 유의미한가? | 스코프 협상은 [BP-50](50_roadmap.md) 의 결정 사항 |
| Q-11-02 | G-05 수정이 **동작 변경**이므로(지금까지 도달 불가였던 분기가 살아남), 네이티브 맵 4종의 대사를 그대로 살릴지 콘텐츠 팩으로 이관하며 다시 쓸지. | 이관 전략(BP-28)에 종속. Q-10-05 와 동일 사안 |
| Q-11-03 | G-22 의 수리를 **① 명시 참조 추가** / **② 등록 해제**(G-34) / **③ `Map{id:03d}` 규칙 폐기** 중 어느 것으로 할 것인가? ②는 4개 맵에만 들어맞지만 G-29 잔존 문제까지 동시에 없앤다. ③은 기존 5개 정상 맵의 엔트리도 고쳐야 한다. | 태스크 **T-004** 가 이 결정을 요구한다. 규칙 폐기는 [BP-21](21_content_pack_spec.md) 의 팩 매니페스트 설계와 맞물림 |
| Q-11-04 | 레거시 cm2 4,056줄 중 실제로 도달 가능한 분량이 얼마인가? D-17 이 "전면 재작성 제외" 를 선언했으므로 **얼마를 그대로 둘지**가 이관 비용을 좌우한다. | 상호 `LoadScript` 그래프 미분석(Q-10-02 와 동일 사안) |
| Q-11-05 | G-17 의 시드화 범위 — cm2 `Random()` 과 전투 14곳을 **한 시드로 묶을지**, 서브시스템별로 나눌지. 후자는 트레이스 비교가 국소화되지만 상태가 늘어난다. | BP-27/BP-34 의 설계 사항 |
| Q-11-06 | 결함 중 **의도된 설계**인 것이 섞여 있는가? 특히 G-19(전역 가드)와 G-12(네이티브 팩토리 하드코딩)는 "원본 C++ 전역을 의도적으로 미러링" 이라는 CLAUDE.md 방침과 충돌 소지가 있다. | 원저자 확인 필요 — 코드만으로는 의도 판별 불가 |
| Q-11-07 | **`flutter build web` 이 지금 성공하는가?** G-33 은 "확인 수단이 없다" 는 구조적 사실까지만 확정했다. 실패한다면 현재 웹 배포가 이미 불가능한 상태이고 M0 우선순위가 올라간다. | 본 장에서 실빌드 미수행(미확인). 태스크 **T-023** 착수 전 1회 확인 필요. Q-10-08 과 동일 사안 |
| Q-11-08 | `Town2MapScript`(83줄, 한 번도 실행된 적 없음)를 **되살릴 것인가 삭제할 것인가?** 되살리려면 `TOWN2` 맵 자산을 새로 만들어야 한다. | [BP-28](28_migration_and_coexistence.md) 의 이관 범위 결정 사항. 부록 G-2 |
| Q-11-09 | G-24 / G-32 를 함께 고칠 때 **전투 결과의 정본을 Dart 로 할 것인가 `const.cm2` 로 할 것인가?** 그리고 "미발생" 을 4번째 값으로 추가할 것인가 별도 `bool` 로 둘 것인가? | 태스크 **T-025** 가 이 결정을 요구한다. 원본 C++(`REF_hadar/`) 미대조 |
