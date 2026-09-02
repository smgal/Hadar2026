# 검수 보고서 — BP-20 목표 아키텍처 전체 그림

- **검수자**: R1 · **대상 파일**: `blueprint/20_target_architecture.md` (749줄)
- **판정**: **수정 필요**
- **점수**: A4 B3 C3 D3 E4 F3 G5 = **25/35** (합격선 26 미달)

> 총평: 코드 인용 정확도와 검증 수단 설계(INV 18종)는 이 레포에서 본 기획 문서 중 최상위다.
> 그러나 **"기존 시스템과의 접합점 5곳"이라는 전수 주장이 틀렸고**(warp/맵 전환, Effect 실행기 누락),
> **자기가 §0 에서 BP-25 소유라고 못 박은 세이브 v2 포맷을 스스로 정의했으며 그 정의가 BP-25 실물과 어긋난다.**
> 두 결함 모두 다른 장이 이 장을 SSoT 로 인용하는 순간 전파되므로 병합 전 수정이 필요하다.

---

## 0. 기계적 검사 실행 기록 (루브릭 §"검수자가 반드시 하는 기계적 검사")

| # | 검사 | 실행 방법 | 결과 |
|---|---|---|---|
| 1 | 줄 수 | `wc -l` | 749줄 — 규약 8(최소 250, 권장 350~600) **충족**(권장 상한 초과이나 반려 사유 아님) |
| 2 | 코드 인용 검증 | 아래 §0.1 — **12곳 직접 대조** | 10곳 정확, 2곳 부정확 |
| 3 | 링크 검증 | 상대 링크 18개 추출 후 `-e` 테스트 | 실재 8, 미생성 10 — 미생성 10개 **전부 OUTLINE.md 에 계획된 파일** → 통과 |
| 4 | 식별자 검증 | D-05 op/do, D-06/07 필드명, D-16 항목번호 대조 | op/do 재정의 없음(이름만 인용) → 통과. 단 §5.5 의 `enemyIds` 는 D-04 ID 체계와 불일치(F-05) |
| 5 | 중복 검사 | BP-21/23/25 와 `grep` 교차 | **세이브 v2 포맷을 BP-25 와 중복·충돌 정의**(F-02), lock.json 해시 필드명 BP-21 과 충돌(F-06) |
| 6 | 미확정 표현 | `grep -nE "적절히\|추후\|등등\|TBD\|미정\|나중에"` | 1건(`:724` Q-20-1 의 "수단 미정") — **열린 질문 절 안**이므로 허용 |

### 0.1 코드 인용 대조 결과 (12곳)

| # | 문서가 주장한 위치 | 실제 확인 | 판정 |
|---|---|---|---|
| 1 | `tile_event_dispatcher.dart:106-157` = `_dispatchScripted` | 106행 시그니처 ~ 157행 닫힘 | ✅ 정확 |
| 2 | `tile_event_dispatcher.dart:34` = `_isScriptRunning` | `bool _isScriptRunning = false;` | ✅ 정확 |
| 3 | `tile_event_dispatcher.dart:166-178` = JSON 선형 탐색 | 166 `for`, 176 `return`, 178 닫힘 | ✅ 정확 |
| 4 | `tile_event_dispatcher.dart:120-146` 현행 스니펫 | 120~146 일치(`xs/ys/tag` 3줄 생략은 `// ...` 로 표기됨) | ✅ 정확 |
| 5 | `save_manager.dart:18-24` = 세이브 페이로드 | 18~24행 문자 단위 일치 | ✅ 정확 |
| 6 | `menu_flows.dart:34-42` = 메인 메뉴 항목 | 34 `final choices = [`, 35~42 항목, 43 `];` | ✅ 정확(범위 끝 1줄 여유) |
| 7 | `menu_flows.dart:55-77` = switch 분기 | 54 `switch`, 55~77 case 본문 | ✅ 정확 |
| 8 | `battle.dart:240-264` = 승리 보상 | 240 `if (_battleResult == 1) {` ~ 264 `); // Add dummy gold` | ✅ **문자 단위 일치** |
| 9 | `bundle_asset_source.dart:22-27` | 22~27행 일치 | ✅ 정확 |
| 10 | `pubspec.yaml:65-69` = 비재귀 에셋 선언 | 65 `assets:`, 66~69 4항목 | ✅ 정확 |
| 11 | `host_binding.dart:60-75` = bind/reset | 60~68 `bind`, 71~75 `reset` | ✅ 정확 |
| 12 | `.github/workflows/ci.yml:50-75` = 계층 grep | 50 `- name: Check layering invariants`, 68~73 두 `check` 호출, 75 `exit $fail` | ✅ **정확. §4.3 이 인용한 grep 정규식 2개가 ci.yml:69/73 과 문자 단위 일치** |

- **부정확 2건**: §5.5 의 `currentEncounterId`(F-03), §8.1 의 "`application/` 총합 약 2,800줄"(S-02, 실측 3,451줄).
- 계층 CI 주장은 **CLAUDE.md/GROUND_TRUTH 의 구식 grep 표기가 아니라 ci.yml 실물을 인용**했다. 이 점은 명백한 강점이다.

---

## 치명 결함 (반드시 고쳐야 함)

### F-01 "접합점 5곳"이 전수가 아니다 — 맵 전환(`warp`)의 접합점이 통째로 빠졌다

- **위치**: `20_target_architecture.md:270-278`(§5.1 표), `:280-310`(§5.2)
- **문서 주장**: §5 제목이 "기존 시스템과의 접합점 **5곳**"이고, §5.1 표가 (a)~(e) 다섯 행으로 전수를 주장한다. §5.2 는 티어 0 이 `true` 를 반환하면 "`return`" 만 하면 된다고 쓴다.
- **실제**:
  - D-05 의 Effect `do` 집합에 `warp(map, x, y)` 가 있다. 현행 코드에서 **맵 전환은 즉시 실행되지 않는다.**
    `HDScriptEngine.pendingNavigation`(`script_engine_adapter.dart:34`)에 예약되고,
    `hd_game_main.dart:74,80` 이 `pendingNavigation != null` 을 감지해 `executePendingNavigation()` 를 나중에 호출한다.
  - 더 결정적으로 `tile_event_dispatcher.dart:98-100` 의 `finally` 가
    `await host.endNarrative(autoFlush: HDScriptEngine().pendingNavigation == null);`
    을 호출한다. 즉 **narrative 사이클의 flush 여부가 cm2 엔진의 `pendingNavigation` 값에 직접 결합돼 있다.**
  - 콘텐츠 티어의 `warp` 는 cm2 엔진을 거치지 않으므로 `pendingNavigation` 이 `null` 로 남는다
    → 맵 전환이 예약된 상태에서도 `autoFlush: true` 로 narrative 가 flush되어 **오버레이가 한 번 닫혔다 다시 열리는 화면 깜빡임**이 발생한다.
    이것은 D-10 이 요구한 "무중단 점진 이관"과 INV-20-05 의 정신에 정면으로 어긋난다.
- **문서 전체에서 `pendingNavigation` 은 0회 언급된다** (`grep -c "pendingNavigation" 20_target_architecture.md` → `0`). BP-28 도 0회다.
- **요구 조치**:
  1. §5.1 표에 **(f) 맵 전환 예약** 행을 추가하고 대상 파일을 `script_engine_adapter.dart:34`(필드) + `hd_game_main.dart:74-80`(소비 지점) + `tile_event_dispatcher.dart:99`(autoFlush 판정)로 명시할 것.
  2. 다음 중 하나를 **이 장에서 확정**할 것(BP-27 로 넘기면 접합점 전수 주장이 계속 거짓이 된다):
     - (A) `ContentRuntime` 이 `HDScriptEngine.pendingNavigation` 을 **재사용**한다 → 그러면 `application/content/` 가 `scripting/script_engine_adapter.dart` 를 import 하게 되므로 의존 방향(§4.1)을 갱신해야 한다.
     - (B) `pendingNavigation` 을 `HDGameSession` 으로 승격시키고(중립 위치) cm2·콘텐츠 양쪽이 같은 필드를 쓴다 → **권장**. 이 경우 `tile_event_dispatcher.dart:99` 와 `hd_game_main.dart:74,80` 의 참조 대상 변경이 선행 작업 목록에 들어가야 한다.
  3. §5.2 표의 "필요한 선행 작업" 칸에 `currentMapName` 과 나란히 위 항목을 적을 것.

---

### F-02 §0 이 BP-25 소유라고 선언한 세이브 v2 포맷을 스스로 정의했고, 그 정의가 BP-25 실물과 충돌한다

- **위치**: `20_target_architecture.md:26`(§0 중복 금지 표), `:322-360`(§5.3), `:706`(R-20-4)
- **문서 주장**:
  - §0: "`WorldState` 필드, **세이브 v2 바이트 포맷**, 마이그레이션 규칙 → BP-25" (이름만 언급하고 정의하지 말 것)
  - 그러나 §5.3 은 v2 페이로드를 **키 단위로 전부 나열**하고, R-20-4 가 그것을 확정 사항으로 못 박는다.
- **실제 충돌 3건** (`25_world_state_and_save.md` 실물 대조):

  | 항목 | BP-20 §5.3 / R-20-4 | BP-25 §5.1(:511-566), §5.2(:570-582) | 판정 |
  |---|---|---|---|
  | 맵 저장 | `'map': session.map?.toJson()` **유지** | `map` 을 **`mapDelta` 로 교체**(`:577`, 570KB 절감 근거 §8.3) | 정면 충돌 |
  | 네이티브 러너 상태 키 | `'nativeScript': {'flags':…, 'variables':…}` | `"legacy": {"nativeFlags":…, "nativeVariables":…}`(`:562-564`) | 키 이름 충돌 |
  | 봉투 | 없음 | `"envelope"` 블록 신설(`:514-520`) | BP-20 에 누락 |

- 두 장이 모두 "확정 사항" 표에 넣었으므로 구현자는 어느 쪽을 따를지 알 수 없다. 이것이 SSoT 붕괴다.
- **요구 조치**:
  1. §5.3 의 "변경 후" 코드블록을 **삭제**하고, 그 자리에 "v2 봉투의 필드 정의는 [BP-25 §5.1](../../25_world_state_and_save.md) 이 SSoT" 한 줄 링크 + **접합 사실만** 남길 것
     (남겨도 되는 것: "`HDSaveManager.saveGame` 이 `version: 2` 로 분기하고 `loadGame` 이 `case 1: _migrateV1ToV2` 를 탄다" 라는 *제어 흐름*).
  2. **R-20-4 를 삭제하거나** "세이브 v2 의 필드 확정 권한은 BP-25 에 있다" 로 바꿀 것. 현 문장은 BP-25 를 무효화한다.
  3. 그래도 BP-20 에 남겨야 할 접합 사실이 있다면 `save_manager.dart:18`(저장) / `:86`(`setNewMap` 만 호출) 두 지점만 인용할 것.

---

### F-03 `currentEncounterId` — 존재하지 않는 식별자를 있는 것처럼 쓰고, 선행 작업으로도 등록하지 않았다

- **위치**: `20_target_architecture.md:416-421`(§5.5 "변경 후" 코드블록)
- **문서 주장**:
  ```dart
  WorldEventBus().publish(WorldEvent.defeat(
    enemyIds: [for (final e in enemies) e.data.id],
    encounterId: currentEncounterId,   // null 이면 자유 조우
  ));
  ```
- **실제**: `grep -n "currentEncounterId\|encounterId" hadar2026_app/lib/application/battle.dart` → **0건**.
  `HDBattle` 에는 encounter 라는 개념 자체가 없다. 조우는 `HDParty.encounter`(정수 확률)와
  cm2 커맨드 `Battle::RegisterEnemy(id)`(`script_engine_adapter.dart:334`)의 나열로만 구성되고,
  "이 전투가 어떤 조우인가"를 식별하는 값은 코드 어디에도 없다.
- **왜 치명인가**: D-05 의 `start_battle(encounterId)`, D-06 의 `Objective.kind = defeat(encounterId|enemyId, count)`,
  그리고 이 장 §8.3 의 인덱스 키 `byQuestObjective: { "defeat:enemy.core.skeleton": [...] }` 가
  **전부 encounter 식별자의 존재를 전제한다.** 그 식별자를 누가 만들고 어디에 저장하는지 아무 장도 정하지 않았다.
  §5.2 는 `currentMapName` 에 대해서는 "필요한 선행 작업" 을 성실히 적었는데, §5.5 는 같은 성격의 부재를 침묵했다.
- **요구 조치**:
  1. §5.5 표에 "필요한 선행 작업 | `HDBattle` 에 `String? currentEncounterId` 신설. `Battle::Init` 및 Effect `start_battle` 이 세팅, `gotoEndBattle` 에서 소비 후 `null` 로 리셋" 행을 추가할 것.
  2. **자유 조우(랜덤 인카운터)의 `encounterId` 규약을 이 장에서 정할 것.** `null` 로 두면 `defeat(encounterId)` 목표가 자유 조우로는 절대 진행되지 않는다 — 그것이 의도라면 명시하고, 아니면 `encounter.core.random.<mapName>` 같은 합성 규칙을 확정할 것.
  3. §10.3 에 열린 질문으로 미루지 말 것. `encounterId` 는 BP-23(Objective)·BP-27(이벤트 버스)이 **동시에** 전제하는 값이라 이 장이 정하지 않으면 두 장이 각자 발명한다.

---

### F-04 Effect 24종 중 8종은 `WorldStateMutator` 로 적용할 수 없다 — 실행기(Effect executor)의 자리가 없다

- **위치**: `20_target_architecture.md:216`(§4.1 표의 `effect.dart` 행), `:212-226`(§4.1), `:236-245`(§4.2 표)
- **문서 주장**:
  - §4.1: `effect.dart` — 아는 것 "Effect do 집합(D-05), `apply(WorldStateMutator)`" / 모르는 것 "화면 출력, 저장 시점"
  - §4.1 규칙: "`domain/content/` → **아무것도 import 하지 않는다.** `application/ports/` 조차 모른다."
  - §4.2 표는 `application/content/` 6파일의 책임을 나열하는데, **Effect 를 게임 시스템에 적용하는 주체가 없다.**
- **실제**: D-05 의 `do` 24종을 분류하면

  | 순수 `WorldState` 변이 | 외부 시스템 접근 필요 |
  |---|---|
  | `set_flag` `clear_flag` `set_var` `add_var` `give_item` `take_item` `start_quest` `advance_quest` `complete_quest` `fail_quest` `set_npc_state` `journal` `unlock_place` `set_encounter`\* | `add_gold` `add_food`(→ `HDParty.inventory`, `party.dart`) · `warp`(→ `loadMapFromFile`/`pendingNavigation`) · `change_tile`(→ `MapModel` + 세이브 오버레이) · `start_battle`(→ `HDBattle`) · `play_dialogue`(→ `DialogueRuntime`) · `heal_party` `grant_exp`(→ `HDPlayer`) |

  \* `set_encounter` 는 `HDParty.encounter` 를 건드리므로 사실상 오른쪽이다 → **최소 8종**.
- GROUND_TRUTH §10 이 확인해 준 대로 `gold`/`food` 는 `PartyInventory` 에 있고 `WorldState`(D-08) 밖이다. §6.1 소유권표도 "파티 스탯·골드·식량 | 세이브 ●" 로 **`WorldState` 가 아닌 곳**에 둔다. 즉 `add_gold` 는 정의상 `WorldStateMutator` 로 적용 불가다.
- **요구 조치**:
  1. §4.1 의 `effect.dart` 행을 고칠 것. 권장 형태:
     `domain/content/effect.dart` 는 Effect 를 **파싱·검증·직렬화**하고 `apply` 는 추상 인터페이스
     `abstract class EffectSink { void setFlag(...); void addGold(int); Future<void> warp(...); … }` 에 위임한다.
     순수 부분(`WorldStateMutator`)과 엔진 부분(`GameSystemsSink`)을 **하나의 sink 인터페이스로 합쳐** domain 이 Flutter/포트를 모르는 성질을 유지할 것.
  2. §4.2 표에 `effect_executor.dart`(가칭) 행을 추가하고 "부르는 포트"에 `UiHost`·`PartyMovementHost`·`HDGameSession`·`HDBattle` 을 명시할 것.
  3. §4.4 예산표의 `lib/application/content/` 파일 수 6 → 7 이상으로 갱신할 것.
  4. **CLI 재사용 영향**: R-20-2("`domain/content/` 는 Flutter 를 전혀 import 하지 않는다")를 지키려면 CLI 측은 `EffectSink` 의 no-op/기록용 구현을 쓰게 된다. 그 사실을 §4.1 의 "재사용처" 칸에 적을 것 — 안 적으면 D-12 의 "authoring 시맨틱 = 런타임 시맨틱" 이 8종 do 에 대해 성립하지 않는다.

---

## 중요 결함

### F-05 `enemyIds` 가 레거시 정수 ID 인데 D-04 ID 체계·§8.3 인덱스 키는 문자열 ID 를 전제한다 (다리 부재)

- **위치**: `:418`(§5.5 코드), `:610`(§8.3 인덱스 예시)
- **문서 주장**: `enemyIds: [for (final e in enemies) e.data.id]` / `byQuestObjective: { "defeat:enemy.core.skeleton": [...] }`
- **실제**: `hadar2026_app/lib/domain/battle/enemy.dart:5` 는 `final HDEnemyData data;` 이고 `data.id` 는 **정수**다
  (GROUND_TRUTH §10: 적 데이터 76종 하드코딩 테이블). `enemy.core.skeleton` 같은 문자열 ID 는 어디에도 없다.
- D-04 는 **플래그**에 대해서만 다리(`legacyFlagMap`)를 확정했고 적 ID 다리는 아무 결정도 없다. BP-28 §7 도 플래그만 다룬다.
- **요구 조치**: §5.5 표 또는 §6.1 소유권표에 **적 ID 다리**를 확정할 것. 최소한 다음 중 하나:
  (A) `content.lock.json#legacyEnemyMap: {"enemy.core.skeleton": 5}` 를 도입하고 `WorldEvent.defeat` 는 **문자열 ID 로 정규화해서** 발행,
  (B) 이벤트는 정수로 발행하고 `QuestRuntime` 이 인덱스 조회 직전에 환산 — 이 경우 §8.3 의 인덱스 키를 정수로 바꿔야 함.
  어느 쪽이든 §10.2 에서 BP-23 이 아니라 **이 장 또는 BP-21** 이 정한다는 것을 명시할 것.

### F-06 `content.lock.json` 해시 필드 이름이 BP-21 과 다르다

- **위치**: `:576-582`(§7.3 표)
- **문서 주장**: `#sources[path]`, `#bundleHash`, `#schemaHash`, `#legacyFlagMapHash`
- **실제**: `21_content_pack_spec.md:131` — "`content.lock.json` 의 **`buildInputHash`** 가 이를 고정하고 CI 가 재빌드 후 해시 일치를 검사한다(D-15)"
- §0 중복 금지 표는 `content.lock.json` 의 소유자를 지정하지 않았다. 그래서 두 장이 각자 필드를 발명했고 이름이 갈렸다.
- **요구 조치**: §0 중복 금지 표에 "`content.lock.json` 필드 정의 → BP-21 (또는 BP-35)" 행을 추가하고, §7.3 은 **해시 대상(무엇을 해시하는가)만** 남기고 필드명을 링크로 대체할 것.

### F-07 §7.2 의 "소비 카운터 사용하지 않음" 이 BP-25 의 `rngCursor` 와 정면 충돌

- **위치**: `:569`(§7.2 표 "소비 카운터 | **사용하지 않음** | 카운터 방식은 평가 순서에 의존해 리팩터링에 취약")
- **실제**: `25_world_state_and_save.md:160` 은 `WorldState.rngCursor: int` 를 **필수 필드**로 정의하고
  `:378` 은 "시드 난수 1회 소비. `rngCursor` 를 증가시키고 값을 돌려준다", `:970` R-25-7 은 확정 사항으로 못 박는다.
- 두 장 모두 규범 문장이고, **하나가 다른 하나를 금지한다.**
- **요구 조치**: 이 장 §7.2 와 BP-25 R-25-7 중 하나를 철회해야 한다.
  - 판단 근거를 제공하자면 — BP-20 의 `callSiteId` 해시 방식은 **같은 호출 지점을 두 번 평가하면 같은 값**이 나온다
    (예: 대화를 반복 진입해 `chance(30)` 를 다시 굴려도 결과가 고정). 이는 게임적으로 "재시도해도 안 바뀜"이라 의도일 수도, 버그일 수도 있다.
    `rngCursor` 방식은 그 문제가 없지만 BP-20 이 지적한 순서 의존성이 생긴다.
  - 최소한 §7.2 에 "BP-25 R-25-7 과 상충 — 미해결" 을 **열린 질문 Q-20-9 로 등록**하고 결정 기한을 적을 것. 지금은 충돌 사실 자체가 어느 문서에도 없다.

### F-08 R-20-2 가 D-11 을 조용히 뒤집는다 (선언 없는 결정 강화)

- **위치**: `:250-252`(R-20-2)
- **문서 주장**: "`lib/domain/content/` 는 `package:flutter/foundation.dart` **조차** import 하지 않는다."
- **실제 D-11**: "`lib/domain/content/` # 순수 데이터 모델 + 평가기 (**Flutter foundation 만 import**)"
  D-12 는 "flutter/foundation 도 **최소로**" 라고만 했다. 즉 D-11 은 허용, R-20-2 는 금지 — 강화 방향이지만 **명시적 충돌**이다.
- 루브릭은 결정을 뒤집지 말라고 하되, 이 장은 뒤집으면서 뒤집었다는 사실을 적지 않았다. 구현자가 D-11 만 읽으면 `ChangeNotifier` 를 쓸 것이고 R-20-2 를 읽으면 못 쓴다.
- **요구 조치**: R-20-2 본문에 "**D-11 의 괄호 주석(`Flutter foundation 만 import`)을 이 요구사항이 더 좁힌다. D-12 의 CLI 공유 요건이 근거**" 라는 한 문장을 넣을 것. (결정 자체를 바꾸라는 요구가 아니라 충돌 표시 요구다. 결정 변경 요청은 §"결정 재검토 요청" 참조.)

### F-09 `HDJournalFlows` 의 배치가 정해지지 않았다

- **위치**: `:387`(§5.4 `await HDJournalFlows().showJournal();   // application/content 소비자`)
- **실제**: 주석은 "application/content 소비자" 라고만 하고, §4.2 의 `application/content/` 6파일 표에도 §4.4 의 예산표(6파일)에도 저널 플로우가 없다.
  `HDMenuFlows`(`menu_flows.dart`)와 같은 층에 두는지, `application/content/journal_flows.dart` 인지, `presentation/panels/` 인지 미정.
- **요구 조치**: §4.2 표에 행을 추가하거나, §5.4 주석을 "배치는 [BP-41](../../41_journal_ui_spec.md) 가 정한다" 로 바꾸고 §10.2 에도 그 항목을 넣을 것. 지금은 §10.2 가 "저널 UI 800×480 배치"만 넘기고 **플로우 클래스의 계층 배치**는 아무도 안 받았다.

### F-10 INV-20-05 가 BP-28 의 실행 계획과 이미 충돌한다

- **위치**: `:648`(INV-20-05), `:299`(§5.2 "앵커 없음 | `false` 반환 → 기존 3티어가 **문자 그대로 이전과 동일하게** 동작")
- **문서 주장**: "앵커가 없는 맵의 타일 상호작용 동작은 티어 0 도입 전후로 **동일**하다" + 골든 비교로 고정
- **실제**: `28_migration_and_coexistence.md:230-240`(§2.3 변경 후)는 티어 1 에서
  `final handled = await native.processMapEvent(...); if (handled) return;` 로 **반환값을 소비**하고
  `if (ContentRuntime().legacyJsonPreEmit(mapName))` 로 JSON 선-방출을 게이트한다.
  BP-28 §2.4 는 "네이티브가 `false` 반환 → 티어 2 로 하강 → **회귀 위험 있음**" 이라고 자기 입으로 인정한다.
  이는 앵커가 하나도 없는 맵에서도 발생하는 변화다 → **INV-20-05 위반**.
- **요구 조치**: INV-20-05 의 명제를 정밀화할 것. 권장:
  "앵커가 없고 **T-28-4/T-28-5 적용 전인** 맵의 동작은 티어 0 도입 전후로 동일하다. T-28-4/5 적용은 별도 골든 갱신을 동반하며 그 diff 는 §BP-28 §2.4 에 열거된 3케이스로 한정된다."
  그리고 §5.2 표의 "문자 그대로 이전과 동일하게" 문장에 T-28-4/5 예외 각주를 달 것.

---

## 개선 제안 (선택)

### S-01 INV-20-02 의 검증 절차가 프로세스 분리를 보장하지 않는다 (Dart `Map` 이터레이션 순서 질문에 대한 답)

- §7.1 행 2 는 "키 정렬 후 순회", `Set<String> flags` → `..sort()` 를 규정했다 — **질문에 대한 답이 부분적으로는 있다.**
- 그러나 Dart 의 `Map`/`Set` 기본 구현은 `LinkedHashMap`/`LinkedHashSet`(삽입 순서)이라 **키가 String 이면 런 간 안정적이지만**,
  키가 사용자 정의 객체이거나 `HashMap` 을 명시적으로 쓰면 `Object.hashCode` 가 개입해 **프로세스마다 순서가 달라진다.**
- INV-20-02 의 검증 수단은 "`hadar_content build && sha256sum` × 2회 비교" 인데, 이것이 **같은 프로세스 내 2회**면 그 위험을 잡지 못한다.
- **제안**:
  1. INV-20-02 의 검증 수단을 "**별도 프로세스**로 2회 빌드" 로 명시.
  2. §7.1 행 2 의 검증 수단을 "골든 파일 비교"(순환 논증에 가깝다) 대신 **"직렬화기는 `dart:convert` 의 `JsonEncoder` 에 넣기 전 모든 object 키를 `SplayTreeMap` 으로 재구성한다"** 는 구현 규약 + 단위 테스트로 바꿀 것.
  3. R-20-9(빌드 산출물 금지 항목)에 "**순서가 정의되지 않은 컬렉션의 직렬화**" 를 추가.

### S-02 §8.1 기준선 수치 갱신

- "`application/` 총합 약 2,800줄" → 실측 `find lib/application -name '*.dart' | xargs wc -l` = **3,451줄**(`maps/` 4파일 370줄 포함).
- 나머지 실측치는 전부 일치했다: `assets` 9.7 MB ✅, `assets/maps` 1.2 MB ✅, `GROUND1.json`/`Map013.json` 161,320 B ✅, cm2 17파일 4,056줄 ✅.

### S-03 §4.4 파일 수가 D-11 열거와 1개 어긋난다

- §4.4: `lib/domain/content/` 예상 파일 수 **13**. D-11 이 열거한 파일은 `content_ids, condition, effect, quest, stage, objective, dialogue, node, choice, actor, item, place, anchor, world_state` = **14**개.
- 예산표이므로 치명은 아니나 D-11 을 그대로 세면 되는 값이라 틀릴 이유가 없다.

### S-04 INV-20-07 의 grep 이 현재 통과함을 확인했으니 그 사실을 적을 것

- `grep -rniE "http|dio|websocket|anthropic|openai" hadar2026_app/lib/` → **0건**. 즉 이 불변식은 도입 시점부터 green 이다.
- "현재 0건이므로 최초 커밋부터 게이트를 켤 수 있다" 를 명시하면 구현자가 baseline 조사를 반복하지 않는다.
  (반대로 `-i` 없이 `http` 만 grep 하면 주석 URL 이 걸릴 위험이 있으므로, **패턴을 `package:http`·`dart:io` 처럼 import 형태로 좁힐 것**을 권장.)

### S-05 §8.2 "부팅 시 번들 파싱 ≤ 40ms/150ms" 의 측정 방법이 없다

- 다른 예산 항목은 CI 로 잴 수 있는 파일 크기지만 이 행만 런타임 측정이 필요하다. 측정 훅(`preloadAssets()` 구간 Stopwatch + `kDebugMode` 로그)을 명시하거나 "M4 까지 측정 수단 없음(soft)" 로 강등할 것.

---

## 잘된 점

- **계층 CI 인용이 실물 기준이다.** CLAUDE.md·GROUND_TRUTH 는 구식 grep 표기를 담고 있는데, 이 장 §4.3 은 `ci.yml:68-73` 의 정규식(`-E "^import .*(presentation/|hd_game_main\.dart)"`)을 문자 단위로 정확히 옮겼다. 12곳 인용 중 10곳이 정확했고, `battle.dart:240-264` 는 시작·끝 줄이 정확히 보상 블록의 경계와 일치했다.
- **INV 18종 전부에 "자동 검증 수단 + 실행 위치 + 실패 시 의미" 를 붙였다.** "수단이 없는 명제는 불변식이 아니라 열망이다" 라는 규율은 이 기획서 전체가 따라야 할 기준이다.
- §2.2 반례 반박표가 "런타임 LLM 금지"를 **세이브 ID 안정성**이라는 구체적 기술 근거로 방어한다 — D-01/D-17 을 단순 인용하지 않고 도출했다.
- §6.1 소유권표(21행)가 맵 JSON/콘텐츠 팩/세이브 3자의 겹침을 항목 단위로 증명하고, `contentVersion` 만 "의도된 중복" 으로 예외 처리한 것은 정확한 설계 판단이다.
- §5.4 의 "메뉴 항목을 **끝에** 추가한다 — `showWindowMenu` 는 1-based 인덱스를 그대로 `switch` 에 쓰므로 중간 삽입은 7개 분기를 흔든다" 는 코드 실물(`menu_flows.dart:54-78`)을 정확히 읽은 결과다.
- §0 의 "중복 금지 규약" 표를 **문서 서두에 명시적으로 둔 것** 자체가 좋은 패턴이다(F-02 는 그 표를 스스로 어긴 것이지, 표가 나쁜 게 아니다).

---

## 다른 장에 전파해야 할 발견

| # | 발견 | 영향받는 장 | 확인 요망 사항 |
|---|---|---|---|
| P-01 | 세이브 v2 봉투가 BP-20 §5.3 과 BP-25 §5.1 에서 서로 다르게 정의됨(`map` vs `mapDelta`, `nativeScript` vs `legacy.nativeFlags`, `envelope` 유무) | **BP-25**, BP-28 §8.3 | BP-25 가 SSoT 임을 확정하고 BP-20 R-20-4 를 철회할 것. BP-28 §8.3 세이브 호환 매트릭스는 BP-25 쪽 키를 전제하는지 확인 |
| P-02 | 시드 난수 방식이 BP-20 §7.2(callSiteId 해시, 카운터 금지)와 BP-25 R-25-7(`rngCursor` 카운터)로 정면 충돌 | **BP-25**, BP-27, BP-34(솔버의 `chance` 양분기 탐색) | 둘 중 하나 철회. 솔버 설계가 어느 쪽을 전제하는지 먼저 확인 |
| P-03 | `encounterId` 를 정의하는 장이 없는데 D-05 `start_battle`·D-06 `defeat`·BP-20 §8.3 인덱스가 모두 전제 | **BP-23**, BP-27, BP-42 | BP-23 이 `Objective.defeat` 를 어떻게 스펙했는지 확인. 정수 적 ID 를 쓰고 있다면 P-04 와 함께 다리 필요 |
| P-04 | 적 ID 다리(정수 76종 ↔ `enemy.core.*`)가 어느 장에도 없음. D-04 는 플래그만 다룸 | BP-21(lock 필드), BP-23, BP-28 §7 | BP-28 §7 의 `legacyFlagMap` 옆에 `legacyEnemyMap` 이 필요한지 판단 |
| P-05 | `content.lock.json` 필드명이 BP-20 §7.3(`bundleHash` 등)과 BP-21 `:131`(`buildInputHash`)에서 갈림. BP-28 §3.2 는 여기에 `#migration` 을 또 추가 | **BP-21**, BP-35, BP-28 | lock.json 의 소유 장을 하나로 정하고 세 장의 필드를 병합할 것 |
| P-06 | `pendingNavigation` 을 언급하는 장이 0개(BP-20·BP-28 모두 0회 grep) | **BP-27**, BP-28 | Effect `warp` 의 실제 실행 경로를 BP-27 이 정의했는지 확인. 정의했다면 BP-20 §5 접합점 표에 역참조 필요 |
| P-07 | Effect 24종 중 8종이 `WorldStateMutator` 밖의 시스템을 건드림 | **BP-27**, BP-42(`give_item` ↔ `add_gold` 의 저장소 분리) | BP-27 이 EffectSink 류의 어댑터를 두었는지 확인 |
| P-08 | INV-20-05("앵커 없는 맵 동작 동일")가 BP-28 T-28-4/5 와 충돌 | **BP-28**, BP-50 | 마일스톤 M4 에서 골든이 깨지는 것이 계획된 사실임을 양쪽에 기록 |

---

## 결정 재검토 요청 (결정은 유지, 근거만 기록)

### D-11 의 `domain/content/` Flutter foundation 허용

- D-11 은 `lib/domain/content/` 에 "Flutter foundation 만 import" 를 허용하지만, D-12 는 이 코드를 순수 Dart CLI(`tools/content_cli/`)가 그대로 import 하라고 요구한다. 두 요구는 양립하지 않는다 — `package:flutter/foundation.dart` 를 import 하는 라이브러리는 `dart pub get`(Flutter SDK 없음) 환경에서 해석되지 않는다.
- BP-20 은 R-20-2 로 D-11 을 좁혀 이 문제를 실질적으로 해결했으나(그리고 그 해결은 옳다), **결정 파일 쪽이 갱신되지 않으면 다른 장이 D-11 을 근거로 `ChangeNotifier` 를 쓸 것이다.**
- 요청: D-11 의 괄호 주석을 "Flutter import 0" 으로 수정하거나, R-20-2 를 D-nn 으로 승격해 주기 바람. (본 검수는 결정을 바꾸지 않고 기록만 한다.)

### D-05 `chance(percent)` 의 평가 규약

- D-05 는 "`chance` 는 시드 난수, 검증기에서 양 분기 모두 탐색" 까지만 정했고 **시드 소비 모델**을 정하지 않았다. 그 공백이 BP-20 §7.2 와 BP-25 R-25-7 의 충돌(F-07/P-02)을 낳았다.
- 요청: D-05 에 "시드 소비 모델은 D-nn 으로 별도 확정" 한 줄을 추가하거나, 두 장 중 하나를 규범으로 지정해 주기 바람.

---

## 재검수 조건

다음 6건이 반영되면 재검수를 요청할 것 — 반영 시 A5 B4 C4 D4 E4 F4 G5 = 30/35 로 합격 가능하다고 본다.

1. F-01: §5 에 맵 전환 접합점 추가 + `pendingNavigation` 소유 위치 확정
2. F-02: §5.3 v2 페이로드 정의 삭제 + R-20-4 철회/축소
3. F-03: `currentEncounterId` 선행 작업 등록 + 자유 조우 규약 확정
4. F-04: Effect 실행기(sink)를 §4.1/§4.2/§4.4 에 반영
5. F-07: `rngCursor` 충돌을 Q-20-9 로 등록(또는 해소)
6. F-10: INV-20-05 명제 정밀화
