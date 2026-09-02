# 검수 보고서 — BP-28 cm2·네이티브 스크립트와의 공존 및 이관

- **검수자**: R1 · **대상 파일**: `blueprint/28_migration_and_coexistence.md` (756줄)
- **판정**: **수정 필요**
- **점수**: A3 B3 C2 D3 E3 F4 G5 = **23/35** (C 축 2점 → 자동 반려, 총점도 합격선 26 미달)

> 총평: 자산 재고(§1)의 실측 정확도는 인상적이다 — cm2 17파일 줄 수 전부, `Event::Override` 호출 수,
> JSON 이벤트 수 38건, 네이티브 스크립트 좌표까지 직접 대조해 **모두 일치**했다.
> 그러나 (1) **이관 제외 판단의 핵심 근거가 주석 처리된 줄을 실코드로 오독한 결과**이고,
> (2) **§2.3 의 "변경 후" 코드가 JSON 대사를 두 번 방출하는 버그를 담고 있으며**(자기가 §6.2 에서 고치겠다고 한 바로 그 버그),
> (3) **§2.4 "전수 대조" 표가 T-28-2 가 유발하는 13개 맵의 티어 이동을 누락**했다.
> 셋 다 이 문서만 보고 코드를 짜면 회귀가 나는 종류다.

---

## 0. 기계적 검사 실행 기록

| # | 검사 | 실행 방법 | 결과 |
|---|---|---|---|
| 1 | 줄 수 | `wc -l` | 756줄 — 규약 8 충족 |
| 2 | 코드/데이터 인용 검증 | 아래 §0.1 — **19곳 직접 대조** | 14곳 정확, 5곳 부정확 |
| 3 | 링크 검증 | 상대 링크 11개 추출 후 `-e` 테스트 | 실재 3, 미생성 8 — 미생성 8개 **전부 OUTLINE.md 에 계획됨** → 통과 |
| 4 | 식별자 검증 | D-03/D-04/D-05 필드·op·do 대조 | **`pack.json#enabled` 는 D-03 필수 필드에도 BP-21 §3.1 필드표에도 없음**(F-04) |
| 5 | 중복 검사 | BP-20/21/25/26 과 `grep` 교차 | `content.lock.json#migration` 을 BP-21/BP-35 와 조율 없이 신설(F-06). 앵커 스키마는 BP-26 으로 정직하게 넘김 ✅ |
| 6 | 미확정 표현 | `grep -nE "적절히\|추후\|등등\|TBD\|미정\|나중에"` | 1건(`:571` "정책 미정 → Q-28-3") — 열린 질문으로 등록됨 → 허용 |

### 0.1 인용 대조 결과 (19곳)

**정확한 것 (14)**

| # | 문서 주장 | 실측 | 판정 |
|---|---|---|---|
| 1 | cm2 17파일 총 4,056줄 + 파일별 줄 수 17개 전부 | `wc -l assets/*.cm2` → 4,056, 개별 값 **17개 전부 일치** | ✅ |
| 2 | `Event::Override` 사용 파일은 `Map002.cm2`(3), `Map003.cm2`(1) 뿐 | `grep -c` → 정확히 그 둘, 3/1 | ✅ |
| 3 | 17개 중 12개가 `Tile::Copy*`/`Map::SetRow/SetTile/ChangeTile` 사용 | `grep -l ... \| wc -l` → **12** | ✅ |
| 4 | `map_navigation.dart:40-48` 범위 | 39~49행이 MapInfos 루프 | ✅ |
| 5 | `script_engine_adapter.dart:92-99` loadScript 조기 return | 92 시그니처, 98 `return;` | ✅ |
| 6 | `script_engine_adapter.dart:45-46` LoadScript 두 규약 | 45 `loadMapFromFile`, 46 `loadScript('assets/…')` | ✅ |
| 7 | `native_script_runner.dart:68-89` 4종만 라우팅 | 68 시그니처, 77~88 `switch`, 89 닫힘 | ✅ |
| 8 | `native_script_runner.dart:22-23` flags/variables | `Map<int,bool> flags` / `Map<int,int> variables` | ✅ |
| 9 | `native_script_runner.dart:91-97` isFlagSet/setFlag 실구현 | 91~93, 95~97 | ✅ |
| 10 | `map_script.dart:41-44` / `:46-48` 스텁 | 문자 단위 일치 | ✅ |
| 11 | `tile_event_dispatcher.dart:34,48,102` 가드 | 34 선언, 48 set true, 102 set false | ✅ |
| 12 | `tile_event_dispatcher.dart:133` 반환값 폐기 / `:166-178` 첫 이벤트만 | 정확 | ✅ |
| 13 | JSON 이벤트 수 Map002=18, Map003=3, Map010=8, Map011=9, 합계 38 + 크기 50×50/21×21/65×82/53×52 | Python 으로 전 맵 파싱 → **전부 일치**. 이벤트 0개 맵 목록도 일치 | ✅ |
| 14 | `Town1MapScript` 좌표·플래그 전수: (45,8) 3단 분기 / (50,27) 2페이지 / (50,83)·(23,30) SIGN / (49~51,29) / (48~52,92) / `isFlagSet(33/34/41)`·`setFlag(33/41)`·`setTile(44,14,0)` | 소스 대조 → **전부 일치.** `setFlag(34)` 는 레포 어디에도 없어 "34번 분기 영구 도달 불가" 주장도 정확 | ✅ |

**부정확한 것 (5)**

| # | 문서 주장 | 실측 | 심각도 |
|---|---|---|---|
| 15 | `L1_ep1d5_1.cm2` 가 `L1_ep1d6.cm2` "를 부르지만 그 파일은 없다(참조 끊김)" | 두 호출(`:34`, `:45`) **모두 `#` 로 주석 처리**됨. cm2 파서(`parser.dart:20`)는 `trim().startsWith('#')` 를 스킵 → **끊긴 참조가 아니다** | **치명(F-01)** |
| 16 | `map_navigation.dart` 인라인 `// :43` 이 `cm2Path = 'Map$idStr.cm2'` 를 가리킴 | 실제 `:43` 은 `resolvedJsonName = 'Map$idStr.json';`. cm2Path 대입은 **`:44`** | 중요(F-05) |
| 17 | §5.1 "cm2 커맨드 **41종**의 처분" | `registerCommand` 실측 **40종**. 표에 나열된 것은 **38종**(`Party::PosX`/`Party::PosY` 누락) | 중요(F-07) |
| 18 | `Town1MapScript` **97줄** | `wc -l` → **98줄** (나머지 3종 116/83/73 은 정확) | 경미(S-03) |
| 19 | §1.6 "네이티브 4맵의 JSON 해소 경로 … **이 경로도 실패한다**" | `loadMapFromFile` 은 `false` 가 아니라 **`true`** 를 반환한다. `cm2Path='Map004.cm2'` 가 non-null 이라 `loadByName` 의 catch 가 `return null` 하지 않고 `MapBundle(json: null)` 을 돌려주며, `game_session.dart:97` 이 `if (bundle.json != null)` 로 감싸 **직전 맵이 그대로 남는다** | 중요(F-08) |

---

## 치명 결함 (반드시 고쳐야 함)

### F-01 `L1_ep1d6.cm2` "참조 끊김" 은 주석을 실코드로 오독한 것 — 이관 제외 판단의 근거가 무너진다

- **위치**: `28_migration_and_coexistence.md:31`(§1.1 표 마지막 행), `:37`(§1.1 "읽어낼 수 있는 사실" 3번), `:589`(§9.1 `L1_ep1d*` 행), `:750`(Q-28-4)
- **문서 주장**:
  - §1.1 표: "`L1_ep1d5_1.cm2` … `L1_ep1d6.cm2` 를 **부르지만 그 파일은 없다**(참조 끊김)"
  - §1.1 사실 3: "레거시 체인은 이미 끊긴 상태. **완주 불가**를 전제로 취급해야 한다"
  - §9.1: "`L1_ep1d*` 체인 … **이관하지 않는다.** `L1_ep1d6.cm2` 부재로 이미 완주 불가(§1.1)"
  - Q-28-4: "`L1_ep1d*` 7파일(2,441줄)을 `frozen` 으로 보존할 것인가 삭제할 것인가? **이미 완주 불가**이고 아무도 도달하지 않는다"
- **실제** (`grep -rn "L1_ep1d6" assets/*.cm2`):
  ```
  L1_ep1d5_1.cm2:34:#			LoadScript("L1_ep1d6.cm2", 38,21)
  L1_ep1d5_1.cm2:45:#			LoadScript("L1_ep1d6.cm2", 30,14)
  ```
  **두 줄 모두 첫 문자가 `#` 이다.** `packages/cm2_script/lib/src/parser.dart:20` 은
  `if (line.trim().isEmpty || line.trim().startsWith('#'))` 로 해당 줄을 파싱 자체에서 제외한다.
  GROUND_TRUTH §9 도 "`#` 주석" 을 문법으로 명시한다.
  즉 **런타임에 `L1_ep1d6.cm2` 를 부르는 코드는 존재하지 않으며, 끊긴 참조도 없다.**
- **왜 치명인가**: 이 오독 하나가 세 곳의 결론을 지탱한다 — 이관 제외(§9.1), 폐기 후보 승격(Q-28-4), "레거시 체인은 이미 끊김"(§1.1 사실 3).
  근거가 사라지면 "2,441줄을 손대지 않는다" 는 판단이 무근거가 된다. (판단 자체는 다른 근거로 유지될 수 있다 — 아래 조치 참조.)
- **요구 조치**:
  1. §1.1 표의 `L1_ep1d5_1.cm2` 행 비고를 "`L1_ep1d6.cm2` 호출이 **주석 처리**돼 있어 5층 분기가 막다른 길" 로 수정.
  2. §1.1 사실 3 을 **실제로 검증된 근거로 교체**할 것. 검수 중 확인한 대체 근거:
     - `grep -n "Map::LoadFromFile" assets/*.cm2` → `menace.cm2:70 "den1.map"`, `lore_ep1.cm2:501 "town1.map"`,
       `ground1.cm2:29 "ground1.map"`, `town2.cm2:501 "town1.map"`.
     - `ls assets/*.map` → **파일 없음**. CLAUDE.md 도 "The legacy `*.map` files are no longer used (deleted)" 라고 못 박는다.
     - **즉 레거시 체인이 끊긴 진짜 이유는 `.map` 파일 전부 삭제**다. 이건 `L1_ep1d*` 뿐 아니라
       `lore_ep1/town1/town2/ground1/menace` 5종에도 동시에 적용되는 훨씬 강한 근거다.
  3. §9.1 과 Q-28-4 의 "완주 불가" 근거를 위 `.map` 부재로 교체할 것.
  4. §1.1 표에 "**`Map::LoadFromFile` 대상 `.map` 존재 여부**" 열을 추가할 것 — 12개 파일이 타일 조작을 쓴다는 열은 있는데, 그 타일 조작의 전제인 맵 로드가 실패한다는 사실이 표에 없다.

---

### F-02 §2.3 "변경 후" 코드가 JSON 대사를 두 번 방출한다 — §6.2 가 고치겠다고 선언한 바로 그 버그를 재도입

- **위치**: `28_migration_and_coexistence.md:225-276`(§2.3 변경 후 코드블록)
- **문서 주장**: T-28-4(네이티브 `bool` 소비) + T-28-5(JSON 선-방출 게이트)로
  §6.2 증상 2 "JSON 이 **무조건** 선-방출되어 네이티브 대사와 중복된다" 를 해소한다.
- **실제 코드 경로 추적** — `legacy` 상태 네이티브 맵에서 네이티브가 `false` 를 반환하는 경우:

  ```
  TIER 1: legacyJsonPreEmit(mapName) == true  →  _emitJsonDialog(…)      ← 1회차 방출
          handled = await native.processMapEvent(…) == false → fall through
  TIER 2: cm2Path != null → run() → handled==false → _emitJsonDialog(…)  ← 2회차 방출
          (또는 T-28-2 로 cm2Path==null 이면)
  TIER 3: print + _emitJsonDialog(…)                                      ← 2회차 방출
  ```

  **어느 분기로 가든 `_emitJsonDialog` 가 두 번 호출된다.** `_emitJsonDialog`
  (`tile_event_dispatcher.dart:159-179`)는 좌표 일치 이벤트의 `dialogLines` 를 그대로 `host.addLog` 하는 순수 방출이라
  중복 억제가 없다.
- 지금 당장 화면이 깨지지 않는 유일한 이유는 **네이티브 4맵의 JSON 이벤트 수가 0** 이기 때문이다(§1.5 로 문서 자신이 확인).
  그런데 §6.2 증상 2 는 "네이티브 맵에 JSON 이벤트가 생기면 즉시 이중 출력" 을 **고쳐야 할 문제로 지목**했다.
  §2.3 의 코드는 그 상황에서 이중이 아니라 **여전히 이중**이다 — 게이트가 선-방출에만 걸려 있고 폴백 방출에는 안 걸려 있다.
- **요구 조치**: §2.3 코드를 다음 중 하나로 고칠 것.
  - (A) 권장 — 지역 변수로 1회성 보장:
    ```dart
    bool jsonEmitted = false;
    Future<void> emitJsonOnce() async {
      if (jsonEmitted) return;
      jsonEmitted = true;
      await _emitJsonDialog(map, x, y, host, action);
    }
    ```
    티어 1/2/3 의 모든 방출을 `emitJsonOnce()` 로 교체.
  - (B) 티어 1 이 `false` 를 반환했고 선-방출을 이미 했으면 **티어 2 로 내려가되 티어 2/3 의 JSON 폴백만 건너뛰도록** 플래그를 넘긴다.
- 그리고 §2.4 전수 대조표의 "앵커 없음 + 네이티브 있음 + 스크립트가 `false`" 행의 "회귀 위험 **있음 → §2.6**" 참조를 고칠 것.
  **§2.6 은 재진입 가드 절이고 이 회귀를 전혀 다루지 않는다.** 실제로 가리켜야 할 곳은 §6.2 T-28-4 이며, 위 이중 방출은 그 어느 절에도 없다.

---

### F-03 콘텐츠 티어의 맵 전환(`warp`)과 재진입 가드·narrative 사이클의 상호작용이 정의되지 않았다

- **위치**: `28_migration_and_coexistence.md:300-315`(§2.6 재진입 가드 재정의)
- **문서 주장**: §2.6 은 가드의 보호 범위를 "`check()` 진입 ~ `endNarrative()` 완료" 로 정의하고,
  "티어 0 의 비동기 대화 그래프 전체를 포함한다", "가드 해제 시점: `finally` 블록" 이라고만 쓴다.
- **실제 코드** (`tile_event_dispatcher.dart:96-103`):
  ```dart
  } finally {
    if (narrativeOpened) {
      await host.endNarrative(
        autoFlush: HDScriptEngine().pendingNavigation == null,   // ← :99
      );
    }
    _isScriptRunning = false;
  }
  ```
  **narrative 의 flush 여부가 `HDScriptEngine.pendingNavigation` 에 직접 결합돼 있다.**
  cm2 의 `LoadScript` 는 `script_engine_adapter.dart:301/311` 에서 이 필드를 세우고,
  소비는 `hd_game_main.dart:74,80` 이 나중에 `executePendingNavigation()` 로 한다 — **디스패치가 끝난 뒤**다.
- 콘텐츠 티어의 Effect `warp`(D-05)는 cm2 엔진을 거치지 않으므로 `pendingNavigation` 이 `null` 로 남는다. 따라서:
  1. `autoFlush: true` 로 narrative 가 flush 되어 **맵이 바뀌기 직전에 오버레이가 한 번 닫힌다** → 화면 깜빡임. cm2 `warp` 와 동작이 달라진다.
  2. 반대로 `ContentRuntime` 이 `warp` 를 **즉시 실행**(`loadMapFromFile`)하면, `_isScriptRunning == true` 이고 narrative 가 열린 채로 맵 교체·네이티브 스크립트 스왑(`game_session.dart:117-128`)·`HDBattle().init()` 이 돌아간다. 새 맵의 `onLoad` 가 대사를 출력하면 그것은 **직전 맵의 narrative 사이클 안**에 들어간다.
  3. 세이브 로드로 `GameReloadException` 이 나면 §2.6 은 "`finally` 로 반드시 해제" 라고만 하는데, 그 `finally` 는 **먼저 `endNarrative` 를 `await`** 한다. 예외 전파 중 `await` 하는 이 순서가 콘텐츠 티어에서도 안전한지 아무 곳에도 없다.
- `grep -c "pendingNavigation" 28_migration_and_coexistence.md` → **0**. BP-20 도 0이다.
- **요구 조치**:
  1. §2.6 표에 행 3개를 추가할 것: **"맵 전환 예약 경로"**, **"narrative flush 판정"**, **"전환 중 재진입"**.
  2. `pendingNavigation` 의 소유를 확정할 것. 권장: `HDGameSession` 으로 승격해 cm2·콘텐츠가 같은 필드를 쓰고,
     `tile_event_dispatcher.dart:99` 를 `HDGameSession().pendingNavigation == null` 로 바꾼다.
     이 변경은 **T-28-3(`currentMapName` 신설)과 같은 파일·같은 성격의 선행 작업**이므로 §2.5 표에 **T-28-8** 로 등록할 것.
  3. INV-20-16(재진입 가드 고정 테스트)의 시나리오에 "티어 0 이 `warp` 를 발행한 직후 `check()` 재호출" 케이스를 명시할 것.

---

### F-04 §2.4 "전수 대조" 가 T-28-2 로 인한 13개 맵의 티어 이동을 누락했다

- **위치**: `28_migration_and_coexistence.md:281-289`(§2.4 표, 5행), `:294`(T-28-2)
- **문서 주장**: §2.4 는 "변경으로 인한 동작 차이 — **전수 대조**" 를 표방하고 5가지 상황만 나열한다.
  T-28-2 는 "`cm2` 가 없으면 필드 자체를 생략하고, 코드는 `Map%03d.cm2` 기본값을 **적용하지 않도록** 바꾼다" 를 지시한다.
- **실제**: §1.6 표가 스스로 밝히듯 현재 **실재하는 `Map%03d.cm2` 는 `Map002.cm2`·`Map003.cm2` 2개뿐**이고,
  나머지 13개 등록 맵은 존재하지 않는 cm2 경로를 갖는다. T-28-2 를 적용하면 그 13개 맵의 `cm2Path` 가 `null` 이 된다.
  그러면 `_dispatchScripted` 에서 **티어 2 → 티어 3 으로 이동**한다. 두 티어의 동작은 같지 않다:

  | | 티어 2 (`cm2Path != null`) | 티어 3 (`cm2Path == null`) |
  |---|---|---|
  | 순서 | cm2 `run()` → `handled` 면 종료 → 아니면 JSON | `print('[JSN]…')` → JSON → cm2 `run()` |
  | JSON 조건 | `handled == false` 일 때만 | **무조건** |
  | 전역 cm2 체인 | 안 돎 | **돎** |
  | 디버그 출력 | 없음 | `[JSN][tag] (x, y)` |

  즉 T-28-2 적용만으로 **Prolog_B1(8이벤트)·Prolog_B2(9이벤트)·Test·DEN2·LoreContinent·CastleLore·LastDitch 등 13개 맵의 디스패치 순서와 출력이 바뀐다.**
  §2.4 표에는 이 상황이 한 행도 없다.
- 동일하게 **T-28-1 의 부작용도 표에 없다.** 현재는 A-2 버그 덕분에 "직전 맵의 스크립트가 살아남아" 티어 2 에서 `run()` 되고 있다.
  `clearRuntimeState()` 를 넣으면 그 13개 맵의 티어 2 는 **빈 스크립트를 돌리는 no-op** 이 된다 — Q-28-7 이 그 사실의 일부를 인지하지만 §2.4 표에는 반영되지 않았다.
- **요구 조치**:
  1. §2.4 표에 최소 3행 추가:
     - `T-28-1 적용: cm2 로드 실패 맵(13개)` — 변경 전 "직전 맵 스크립트 `run()`" / 변경 후 "빈 스크립트 no-op" / 회귀 위험 **있음**
     - `T-28-2 적용: cm2 미실재 맵(13개)` — 변경 전 "티어 2" / 변경 후 "티어 3(JSON 무조건 + 전역 체인 + print)" / 회귀 위험 **있음**
     - `T-28-2 적용: 네이티브 3맵(TOWN1/GROUND1/DEN1)` — cm2Path 가 null 이 되어 티어 1 fall-through 목적지가 티어 2 → 티어 3 으로 바뀜
  2. **"A-2 버그를 고치면 무엇이 회귀를 막는가" 에 대한 답을 §2.5 에 명시할 것.** 현재 §2.5 는 "T-28-1·T-28-2 는 티어 0 을 넣기 전에 끝나야 한다" 고만 하고 방어 수단이 없다.
     권장: T-28-1/T-28-2 **적용 전에** 위 13개 맵 + 네이티브 3맵의 `UiHost` 호출 시퀀스 골든을 §4.2 포맷으로 채취해 `test/` 에 커밋하고, 적용 후 diff 를 **의도된 변화 목록과 1:1 대조**하는 절차를 §2.5 에 태스크로 넣을 것(가칭 T-28-0 "선행 골든 채취").
     이것이 없으면 §9.3 M2 의 종료 조건("shadow diff 0")은 **이미 바뀐 동작을 기준선으로 삼는** 순환 논증이 된다.

---

## 중요 결함

### F-05 `map_navigation.dart` 인라인 줄 번호가 1 어긋난다

- **위치**: `:56-59`(§1.2 코드블록)
- **문서 주장**:
  ```dart
  cm2Path = 'Map$idStr.cm2';          // :43
  if (info['cm2'] is String) cm2Path = info['cm2'];   // :46
  ```
- **실제**: `:43` = `resolvedJsonName = 'Map$idStr.json';`, `:44` = `cm2Path = 'Map$idStr.cm2';`.
  두 번째 주석 `// :46` 은 정확하다.
- GROUND_TRUTH 부록 A-1 도 같은 오류(`map_navigation.dart:43`)를 갖고 있으므로 **문서가 GROUND_TRUTH 를 그대로 옮긴 결과**로 보인다. 그러나 이 장은 "직접 대조" 가 의무인 근거 장이다.
- **요구 조치**: `// :43` → `// :44` 로 수정. 겸사겸사 GROUND_TRUTH 부록 A-1 의 같은 오류도 메인에게 보고할 것(§"다른 장에 전파" P-01).

### F-06 `pack.json#enabled` 는 존재하지 않는 필드다 (D-03·BP-21 미등재)

- **위치**: `:612`(§8.1 킬 스위치 표 L1 행)
- **문서 주장**: "**L1 팩** | `pack.json#enabled: false` 또는 빌드에서 팩 제외"
- **실제**: D-03 의 `pack.json` 필수 필드는 `id, version, schemaVersion, title, dependsOn, generatedBy` 이고,
  BP-21 §3.1 필드표(`21_content_pack_spec.md:139-155`)의 선택 필드는
  `description, authors, license, idPrefix, retiredIds, migrations, entryPoints, contentBudget, _note` 다.
  **`enabled` 는 어디에도 없다.**
- 루브릭 기계적 검사 4("오탈자·임의 추가 적발")에 정확히 걸리는 사례다.
- **요구 조치**: 다음 중 하나.
  - (A) `enabled` 를 빼고 "빌드 대상 팩 목록에서 제외(`hadar_content build --exclude=<packId>`)" 만 남긴다 — **권장**. 이미 §8.1 에 대안으로 적혀 있다.
  - (B) `enabled` 를 유지하려면 §10.2 "다음 장으로 넘긴 것" 에 "`pack.json#enabled` 필드 신설 → BP-21" 행을 추가해 BP-21 이 필드표에 넣게 할 것.

### F-07 §5.1 "cm2 커맨드 41종의 처분" — 개수도 틀리고 전수도 아니다

- **위치**: `:512`(§5.1 제목), `:514-522`(처분 표)
- **문서 주장**: "cm2 커맨드 **41종**의 처분" — 표 제목이 전수 처분을 표방한다.
- **실제**: `grep -oE "registerCommand\('[^']+'" script_engine_adapter.dart` → **40종**.
  그리고 표에 실제로 나열된 것은 **38종**이다. 누락된 2종:
  `Party::PosX`(`script_engine_adapter.dart:418`), `Party::PosY`(`:419`) — 둘 다 `(_, __) async {}` 빈 커맨드로 등록돼 있다
  (동명의 **함수**는 `:545-546` 에 별도로 실구현이 있다).
- **요구 조치**: 제목을 "cm2 커맨드 **40종**" 으로 고치고, 표에 행을 추가할 것.
  권장 처분: "`Party::PosX`/`Party::PosY` 커맨드는 빈 구현이며 동명 함수와 혼동을 부른다 → **삭제 대상**(T-28-n)".
  이건 단순 개수 문제가 아니다 — 표가 "전수" 를 표방하는 한, 누락된 커맨드는 이관 계획에서 영영 안 보인다.

### F-08 §1.6 "이 경로도 실패한다" 가 실제 증상을 잘못 기술했다 — 실패가 아니라 **직전 맵 잔류**다

- **위치**: `:117`(§1.6 표 아래 주의 문단)
- **문서 주장**: "네이티브 4맵의 JSON 해소 경로는 … `Map004.json` fallback… **이 경로도 실패한다**. **T-28-2**: `MapInfos.json` 에 `json`/`cm2` 필드를 채우는 것이 이관의 0번째 작업이다."
- **실제 코드 추적**(`map_navigation.dart:57-74`, `game_session.dart:85-131`):
  1. `loadByName('TOWN1')` → `resolvedJsonName='Map004.json'` → `_loader.loadMap` 예외
  2. catch 블록 `:63` — `if (cm2Path == null) return null;` 인데 `cm2Path='Map004.cm2'` 라 **non-null** → `return null` 하지 **않는다**
  3. `MapBundle(mapName:'TOWN1', json: null, cm2Path:'Map004.cm2')` 반환
  4. `loadMapFromFile` `:97` — `if (bundle.json != null) setNewMap(...)` → **건너뜀. `session.map` 은 직전 맵 그대로**
  5. `:117-128` — 네이티브 스왑은 정상 실행되어 `Town1MapScript` 가 등록됨
  6. `:130` — **`return true`**
- 즉 증상은 "실패" 가 아니라 **"직전 맵의 타일 위에 TOWN1 의 네이티브 핸들러가 붙는다"** 는 더 위험한 상태다.
  타일 액션 판정은 옛 맵의 `getUnit(x,y)` 로 하고, 좌표 분기는 TOWN1 기준으로 하니 좌표가 전부 어긋난다.
- **왜 중요한가**: §9.1 순번 3 이 "TOWN1 — 유일하게 서사 대사를 가진 네이티브 맵" 을 이관 대상으로 잡는데,
  **TOWN1.json 이 실제로 로드된 적이 없다면** 그 맵의 shadow 트레이스는 애초에 채취할 수 없다. 이관 순서표의 전제가 흔들린다.
- **요구 조치**:
  1. §1.6 주의 문단을 위 6단계 추적으로 교체할 것.
  2. §1.6 표의 "현재 실효 티어" 열에서 id 4/5/6 의 값 "네이티브" 옆에 **"(단, 맵 데이터는 직전 맵 잔류)"** 를 병기할 것.
  3. T-28-2 의 완료 정의에 "`MapInfos.json` 에 `json: "TOWN1.json"` 등을 채운 뒤 **`session.map.displayName` 이 실제로 바뀌는지** 확인" 을 검증 조건으로 넣을 것.
  4. `loadByName` 의 catch 로직(json 실패인데 cm2 가 있으면 통과) 자체를 재검토 대상으로 §2.5 에 올릴 것 — 지금 규약은 "cm2-only 맵" 을 위한 것인데, A-1 때문에 **모든 맵이 cm2-only 처럼 보인다.**

### F-09 `TOWN2` 는 로드 불가능한데 §9.1 이 이관 대상으로 편성했다

- **위치**: `:104-119`(§1.6 표 15행 — TOWN2 없음), `:88`(§1.4 `Town2MapScript` 행), `:586`(§9.1 순번 4)
- **문서 주장**: §9.1 순번 4 — "GROUND1 / DEN1 / **TOWN2** … 네이티브 116/73/**83**줄 … 셋을 한 묶음으로" (M5 목표)
- **실제**:
  - `MapInfos.json` 에 `TOWN2` 엔트리가 **없다**(§1.6 표 15행이 이를 정확히 반영한다).
  - `assets/maps/TOWN2.json` **파일도 없다**(`ls assets/maps/` 로 확인 — DEN1/DEN2/GROUND1/TOWN1/ORIGIN/Map0xx 만 존재).
  - 진입 경로는 `ground1_map_script.dart:82` 의 `HDNativeScriptRunner().loadMapScript('TOWN2')` 하나뿐이고,
    이는 `loadMapFromFile('TOWN2.json')` → `loadByName` 에서 MapInfos 미스 → `cm2Path == null` → JSON 로드 실패 →
    **`return null`** → `loadMapFromFile` 이 `false` 반환 → 아무 일도 일어나지 않는다.
  - 따라서 `Town2MapScript`(83줄)는 **한 번도 실행된 적 없는 코드**이고, GROUND1 의 (75,56) 출구는 무반응이다.
- §1.4 는 `Town2MapScript` 를 다른 3종과 동등하게 "현 자산" 으로 제시하고, "공통 성격" 표에도 이 사실이 없다.
  §1.1 이 도달 불가 cm2 5종에 대해서는 "부팅 경로에서 도달" 열을 만들어 성실히 표시한 것과 대조된다.
- **요구 조치**:
  1. §1.4 표에 "**진입 가능 여부**" 열을 추가하고 `Town2MapScript` 를 "불가(MapInfos 미등록 + `TOWN2.json` 부재)" 로 표시할 것.
  2. §9.1 순번 4 에서 TOWN2 를 빼거나, "이관 전 `TOWN2.json` 신규 제작 + MapInfos 등록이 선행 필요" 를 명시할 것. 지금은 "기계적 변환 가능" 으로 분류돼 있어 M5 추정이 틀린다.
  3. 같은 검사를 `DEN2`(id 7 등록, `DEN2.json` 존재, `Map007.json` 부재)에도 적용할 것 — F-08 과 동일한 잔류 증상이 난다.

### F-10 §4.4 shadow 실행 위치가 BP-20 Q-20-1·R-20-2 와 모순된다

- **위치**: `:435`(§4.4 제약표 "실행 위치 | ② Build 구획(CLI `hadar_content sim --shadow --map=…`)"), `:437`(R-28-6)
- **문서 주장**: shadow 동등성 비교를 순수 Dart CLI(`tools/content_cli/`)에서 돌린다.
- **실제**: shadow 는 정의상 **레거시 경로도 함께 돌려야** 한다(§4.1 그림의 `LEG` 분기).
  레거시 경로 = `HDTileEventDispatcher` + `HDScriptEngine` + `HDGameSession` + `HDNativeScriptRunner` + `HDBattle`.
  그런데 `game_session.dart:3` 은 `import 'package:flutter/foundation.dart';` 를 갖고,
  `save_manager.dart:3` 은 `package:shared_preferences` 까지 끌어온다.
  **BP-20 RK-20-1/Q-20-1 이 정확히 이 문제를 제기했다**: 순수 Dart CLI 가 `hadar2026_app` 을 path 의존으로 끌어오면
  `sdk: flutter` 가 딸려와 `dart pub get` 이 실패한다.
- R-28-6 은 "`test/` **또는** `tools/content_cli/` 에만 존재" 로 헷지했지만, 제약표는 CLI 를 단정한다.
- **요구 조치**:
  1. §4.4 제약표의 "실행 위치" 를 "**`flutter test` 하네스**(레거시 경로가 Flutter 의존이므로 순수 Dart CLI 불가 — BP-20 Q-20-1)" 로 확정할 것.
  2. CLI 쪽에는 "콘텐츠 경로 단독 시뮬(`sim`)만 가능하고, 레거시 대조(`--shadow`)는 `flutter test` 잡" 이라는 분담을 명시할 것.
  3. §9.3 M2 종료 조건("shadow diff 0")이 어느 CI 잡에서 돌아가는지를 BP-20 §9.1 의 3잡 구성과 맞출 것 — 현재는 `content` 잡(순수 Dart 전제)에 들어갈 수 없다.

### F-11 팩 단위 롤백(L1) 시 진행 중 세이브의 퀘스트 상태 규약이 없다

- **위치**: `:610-614`(§8.1 킬 스위치 표), `:638-646`(§8.3 세이브 호환 매트릭스)
- **문서 주장**: §8.3 매트릭스의 행은 `v1` / `v2, 팩 버전 == 현재` / `v2, 팩 버전 < 현재` / `v2, 팩 버전 > 현재` 4개다.
- **실제 공백**: L1 롤백은 **팩을 통째로 제외**하는 조치다. 그 결과 런타임 번들에 `gen_ep1` 이 없는데
  세이브의 `worldState.contentVersion` 에는 `{"gen_ep1": "0.3.1"}` 이,
  `worldState.quests` 에는 `quest.gen_ep1.*` 엔트리가 남는다.
  **"팩 부재" 는 버전 비교의 어느 칸에도 해당하지 않는다** — `>`도 `<`도 `==`도 아니다.
- 부수 질문도 답이 없다: 진행 중이던 `stage`·`counters` 를 버리는가 보존하는가? `flags`/`vars` 중 그 팩 네임스페이스만 남기는가?
  `journal` 항목의 `entryKey` 가 `strings/ko.json` 에서 사라졌을 때 저널 UI 는 무엇을 그리는가?
- BP-21 `:471` R-21-18 은 `retiredIds`(개별 ID 은퇴)만 다루고 팩 전체 제거는 다루지 않는다. BP-25 `:718` 의 `orphans` 블록이 가장 가까운 장치다.
- **요구 조치**:
  1. §8.3 매트릭스에 **`v2, 팩 자체가 번들에 없음`** 행을 추가할 것.
  2. 규약을 확정할 것. 권장:
     - 로드는 **거부하지 않는다**(킬 스위치가 세이브를 죽이면 롤백 수단으로 쓸 수 없다).
     - 사라진 팩의 `quests` 엔트리는 삭제하지 말고 **BP-25 의 `orphans` 블록으로 이동**하고, 저널 UI 에서는 숨긴다.
     - 그 팩 네임스페이스의 `flags`/`vars` 도 `orphans` 로 보존한다(팩 복구 시 재개 가능하도록).
     - 진행 중이던 대화 포인터는 휘발이므로 폐기(§6.1 소유권표와 일치).
  3. R-28-10(킬 스위치 3단계) 옆에 "**킬 스위치 어느 레벨도 기존 세이브를 무효화하지 않는다**" 를 R-28-12 로 추가할 것. 지금 §8.2 는 L0 에 대해서만 세이브 안전성을 논증한다.

### F-12 §2.3 의 "변경 전" 코드가 현행이 아니고, "변경 후" 코드는 컴파일되지 않는다

- **위치**: `:196`(§2.3 "**변경 전** (`…tile_event_dispatcher.dart:106-157`, **현행**)"), `:225-276`(변경 후)
- **실제**: 실제 `:120-124` 에는
  ```dart
  final xs = x.toString().padLeft(2);
  final ys = y.toString().padLeft(2);
  final tag = action.debugTag.isEmpty ? '???' : action.debugTag;
  ```
  3줄이 있는데 **두 블록 모두 이 3줄을 생략**했다. 그런데 티어 3 의
  `print('[JSN][$tag] ($xs, $ys)');` 는 그대로 남겨두었다 → **"변경 후" 를 그대로 붙여넣으면 미정의 식별자 3개로 컴파일 실패**한다.
- BP-20 §5.2 는 같은 코드를 인용하면서 `// ...` 로 생략을 표시했다. 이 장은 "현행" 이라고 단언했으므로 기준이 더 엄격해야 한다.
- **요구 조치**: 두 블록에 생략 표시(`// … xs/ys/tag 선언 생략`)를 넣거나 3줄을 복원할 것.
  §2.3 은 구현자가 그대로 옮겨 쓰는 것을 전제로 한 절이므로 후자를 권장한다.

---

## 개선 제안 (선택)

### S-01 §4.3 정규화 규칙에 "분기 구조가 다를 때" 규칙이 없다

- §4.4 는 "메뉴 선택 정책 `scripted` 로 **모든 분기를 순회**" 를 요구한다. 그런데 cm2 의 `Select::Add` 목록과 콘텐츠의 `Choice` 목록은
  개수·순서가 다를 수 있다(이관은 1:1 번역이 아니다). 그 경우 §4.3 의 7개 규칙 중 어느 것도 적용되지 않아 diff 가 통째로 불일치로 뜬다.
- 제안: 규칙 8 "선택지 집합은 **표시 텍스트의 정렬된 다중집합**으로 비교하고, 선택 결과(`result`)는 텍스트로 매칭한다" 를 추가.

### S-02 §6.3 의 "의도된 동작 변경" 예외 절차가 T-28-7 하나에만 있다

- §6.3 은 `isFlagSet` 스텁 해소가 만드는 diff 를 "버그 수정으로 승인" 라벨로 처리한다고 쓰고 Q-28-6 으로 승인 주체를 미룬다.
- 그런데 같은 성격의 "의도된 diff" 는 T-28-1(스크립트 누수 차단), T-28-2(티어 이동), T-28-4(bool 소비)에서도 발생한다(F-04 참조).
- 제안: §4 에 "**승인된 diff(approved-delta)**" 를 1급 개념으로 올리고, `shadow_report.json` 스키마에
  `approvedDeltas: [{traceOp, reason, taskId, approvedBy}]` 필드를 두어 diff 0 판정에서 제외할 것. 그러면 §9.3 의 종료 조건이 기계적으로 판정 가능해진다.

### S-03 `Town1MapScript` 줄 수 97 → 98

- `wc -l lib/application/scripting/maps/town1_map_script.dart` → **98**. §1.4 와 §9.1 순번 3 두 곳에 나온다.
- 나머지 3종(ground1 116 / town2 83 / den1 73)은 정확했다.

### S-04 §7.3 read-back 시점 "네이티브 `processMapEvent` 반환 직후" 가 §2.3 코드와 안 맞는다

- §7.3 은 정수→이름 read-back 을 "티어 경계에서만 — cm2 `run()` 반환 직후, 네이티브 `processMapEvent` 반환 직후" 로 규정한다.
- 그런데 §2.3 의 변경 후 코드는 네이티브가 `false` 를 반환하면 **티어 2 로 하강**한다. 그러면 한 번의 상호작용에서 read-back 이 2회(네이티브 후 + cm2 후) 일어난다.
  RK-28-4 의 dirty 비교로 안전하다고 볼 수도 있으나, "티어 경계" 가 2회 이상 나타난다는 사실이 §7.3 어디에도 없다.
- 제안: §7.3 표에 "한 상호작용 내 read-back 은 티어 하강 횟수만큼 발생할 수 있다" 를 명시하고, §2.3 코드에 read-back 호출 지점을 주석으로 표시할 것.

### S-05 §1.1 표에 "`.map` 파일 존재" 열 추가 (F-01 조치와 연동)

- 12개 파일이 타일 조작을 쓴다는 열은 있는데, 그 중 4개(`menace/lore_ep1/ground1/town2`)가 `Map::LoadFromFile` 로
  **삭제된 `.map` 파일**을 부른다는 사실이 표에 없다. 이것이 "레거시 체인 도달 불가" 의 가장 강한 증거다.

---

## 잘된 점

- **§1 자산 재고의 실측 정확도가 매우 높다.** 검수에서 별도로 계산한 값과 대조한 결과:
  cm2 17파일 개별 줄 수 **17/17 일치**, 총 4,056줄 일치, `Event::Override` 3/1 일치,
  타일 조작 사용 파일 12개 일치, JSON 이벤트 18/3/8/9 및 합계 38 일치, 맵 크기 4건 일치,
  이벤트 0개 맵 목록 일치, `Town1MapScript` 좌표·플래그 인덱스 **전수 일치**. 추측으로 쓴 흔적이 없다.
- **§1.2 가 A-1 + A-2 의 합성 효과("cm2 티어가 사실상 항상 선택된다")를 코드 라인 단위로 추적**했다.
  RK-28-1 의 구체적 시나리오(`Map003.cm2` 가 DEN2 에서 살아남아 `On(10,5)` 가 우연히 맞음)는 실제로 성립하는 경로다.
- **§1.3 이 `LoadScript` 의 두 호출 규약을 분리해 낸 것**은 문서화되지 않은 함정을 정확히 짚었다.
  "두 번째 규약으로 들어온 맵은 `currentMapName` 이 없으므로 티어 0 진입 자체가 불가 → 자동으로 `legacy`" 는
  코드(`script_engine_adapter.dart:45-46`)와 정확히 일치하는 추론이고, Q-28-1 로 성실히 등록했다.
- **§3.2 상태 기록 위치 결정표**가 3후보를 놓고 기각 이유를 밝혔고, `MapInfos.json` 기각 근거를
  BP-20 §6 의 "지형 vs 의미 분리" 로 연결한 것은 장 간 일관성의 좋은 예다.
- **§4.1 이 "콘솔 픽셀이 아니라 `UiHost` 포트 호출 시퀀스를 비교" 로 동등성의 정의를 내린 것**이 이 장 최대의 설계 기여다.
  포트가 이미 존재하고(GROUND_TRUTH §3) 선례(`map_navigation_test.dart`)도 있으므로 신규 발명이 아니다.
- **§5.1 이 cm2 를 "동결이 아니라 축소" 로 재정의(R-28-7)** 하고, 지형 DSL 과 서사 DSL 을 갈라 처분한 것은
  "12개 파일이 실제로 타일 조작을 쓴다" 는 실측에 근거한 판단이다.
- §9.1 이맵별로 이벤트 수·레거시 자산·복잡도·리스크를 표로 놓고 순서를 도출한 것,
  특히 "부팅 맵 LORE_EP 는 파이프라인이 증명된 다음" 이라는 배치는 타당하다.

---

## 다른 장에 전파해야 할 발견

| # | 발견 | 영향받는 장 | 확인 요망 사항 |
|---|---|---|---|
| P-01 | GROUND_TRUTH 부록 A-1 의 `map_navigation.dart:43` 이 실제로는 `:44`. 이 장이 그 오류를 상속 | `_meta/GROUND_TRUTH.md`, BP-10 | 메인이 GROUND_TRUTH 를 수정해야 다른 장의 재발을 막음 |
| P-02 | `L1_ep1d6.cm2` 호출은 주석이며, 레거시 체인이 끊긴 진짜 원인은 `.map` 파일 전량 삭제 | BP-10(현행 감사), BP-11(갭 분석), BP-50/52 | BP-10 이 같은 오독을 했는지 확인 필요 |
| P-03 | `Town2MapScript`(83줄)는 MapInfos 미등록 + `TOWN2.json` 부재로 **실행된 적 없는 코드** | BP-10, BP-50, BP-51 | 이관 추정치에서 83줄을 빼거나 "맵 신규 제작" 태스크로 재분류 |
| P-04 | TOWN1/GROUND1/DEN1/DEN2 는 `Map00N.json` 부재로 **맵 데이터가 로드되지 않고 직전 맵이 잔류**한다(`loadMapFromFile` 은 `true` 반환) | **BP-10**, BP-25 §5.3, BP-26 | BP-25 가 `currentMapName` 재로드 규약을 세울 때 이 경로를 전제해야 함. 앵커 좌표 검증(BP-26)도 로드되지 않는 맵에서는 무의미 |
| P-05 | `pendingNavigation` 을 언급하는 장이 0개(BP-20·BP-28 모두 grep 0회). Effect `warp` 의 실행 경로가 미정 | **BP-27**, BP-20 §5 | BP-27 이 `tryHandle` 내부에서 맵 전환을 어떻게 처리하는지 확인. 처리 없으면 BP-20 §5 접합점 표 갱신 필요 |
| P-06 | `content.lock.json#migration` 을 이 장이 신설했으나 BP-21 `:126` 의 lock 내용 목록에도, BP-20 §7.3 해시 표에도 없음. 게다가 **런타임이 읽는다**(R-28-5) | **BP-21**, BP-35, BP-20 | lock.json 을 "빌드 증빙" 으로 볼지 "런타임 입력" 으로 볼지 정의가 갈림. 소유 장을 하나로 정할 것 |
| P-07 | `pack.json#enabled` 가 BP-21 필드표에 없음 | **BP-21** | 필드 추가 여부 결정 |
| P-08 | INV-20-05("앵커 없는 맵 동작 동일")를 T-28-4/T-28-5 가 위반. 이 장은 §2.4 에서 "회귀 위험 있음" 으로 자인하지만 INV 와 연결하지 않음 | **BP-20**, BP-50 | BP-20 이 INV-20-05 의 명제를 정밀화해야 함 |
| P-09 | shadow 하네스는 Flutter 의존 코드를 구동해야 하므로 순수 Dart CLI 에서 못 돈다 | **BP-30**, BP-34, BP-35 | BP-34 가 `sim --shadow` 를 CLI 서브커맨드로 스펙했다면 실행 환경을 `flutter test` 로 정정 |
| P-10 | cm2 등록 커맨드는 40종이고 `Party::PosX/PosY` 는 커맨드·함수가 동명으로 중복 등록됨 | BP-10, BP-33 | 린트 대상 후보 |

---

## 결정 재검토 요청 (결정은 유지, 근거만 기록)

### D-10 의 "기존 3티어의 동작은 앵커가 없는 맵에서 그대로 보존된다"

- D-10 은 티어 0 삽입만으로 무중단 이관이 성립한다고 전제한다. 그러나 이 장이 정확히 지적했듯
  **티어 1(네이티브)은 반환값을 버리고 JSON 을 무조건 선-방출하는 상태**라, 티어 0 을 넣지 않아도 이미 고쳐야 한다.
  T-28-4/T-28-5 를 적용하는 순간 D-10 의 "그대로 보존" 은 앵커 없는 맵에서도 성립하지 않는다(F-04, P-08).
- 요청: D-10 에 "티어 1 의 `handled` 소비와 JSON 선-방출 게이트 적용은 **동작 보존의 예외**이며, 그 diff 는 승인 절차를 거친다" 한 줄을 추가해 주기 바람.

### D-05 Effect `warp` 의 실행 시점

- D-05 는 `warp(map, x, y)` 를 do 목록에 넣었을 뿐, **즉시 실행인지 예약인지** 정하지 않았다.
  현행 cm2 는 예약(`pendingNavigation`)이고 그 값이 narrative flush 판정에까지 쓰인다(`tile_event_dispatcher.dart:99`).
  이 공백이 F-03 을 낳았다.
- 요청: D-05 에 "`warp` 는 **현재 상호작용이 끝난 뒤** 적용된다(예약 방식). 예약 저장소는 BP-27 이 정한다" 를 추가하거나,
  D-10 의 재진입 가드 조항에 맵 전환을 명시해 주기 바람.

### D-16-2 인벤토리와 `add_gold`/`add_food` 의 저장소

- 이 장의 범위 밖이지만 §7.3 의 이중 진실 원천 논의와 같은 구조의 문제가 인벤토리에도 있다.
  `WorldState.inventory`(D-08)와 `HDParty.inventory{food,gold}`(GROUND_TRUTH §10)가 분리돼 있고,
  Effect `add_gold`/`add_food` 는 후자를 건드린다. §7.3 이 플래그에 대해 세운 "정본 + 파생 캐시" 규약을
  골드/식량에도 적용할지가 미정이다.
- 요청: BP-42 배정 시 이 항목을 명시적으로 넘겨 주기 바람.

---

## 재검수 조건

다음 6건이 반영되면 재검수를 요청할 것 — 반영 시 A4 B4 C4 D4 E4 F4 G5 = 29/35 로 합격 가능하다고 본다.

1. F-01: `L1_ep1d6` 오독 정정 + `.map` 부재를 근거로 교체(§1.1, §9.1, Q-28-4)
2. F-02: §2.3 코드의 JSON 이중 방출 제거 + §2.4 의 잘못된 `§2.6` 참조 수정
3. F-03: `pendingNavigation`/`warp` 를 §2.6 과 §2.5(T-28-8)에 편입
4. F-04: §2.4 전수 대조표에 T-28-1/T-28-2 유발 티어 이동 3행 추가 + 선행 골든 채취 태스크 신설
5. F-08 / F-09: §1.6 주의 문단 정정, §1.4 에 진입 가능 여부 열 추가, §9.1 에서 TOWN2 재분류
6. F-11: §8.3 에 "팩 부재" 행 추가 + 킬 스위치가 세이브를 무효화하지 않는다는 규칙 명문화
