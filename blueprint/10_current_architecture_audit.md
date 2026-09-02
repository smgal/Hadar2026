# 현행 구조 정밀 감사

> `상태: 참고` — 현황 조사·참조 자료. 사실 정본은 [`_meta/GROUND_TRUTH.md`](_meta/GROUND_TRUTH.md) 이며,
> 이 장의 **결론·권고는 1차 노선 기준**이라 [`issues/DECISION-LOG.md`](../issues/DECISION-LOG.md) 2차 판정이 우선한다.

> **문서 ID**: BP-10 · **상태**: 초안 · **선행 문서**: 없음(현황 파트의 최초 문서)
> **독자**: 이 프로젝트를 처음 보는 구현자 · **한 줄 요약**: Hadar2026 이 지금 어떤 계층·싱글턴·디스패치 경로·데이터로 굴러가는지를, 코드를 열지 않고도 재현할 수 있을 만큼 실측해 기록한다.

---

## 0. 이 문서의 사용법

- 여기 적힌 모든 코드 사실은 `2026-08-30` 시점 워킹 트리 실측이다. 인용은 `경로:줄` 형식이며, 줄 번호는 그 시점 기준이다.
- **추측은 "미확인" 으로 표시**했다. 표시 없는 서술은 전부 파일을 직접 읽어 확인한 것이다.
- 이 장은 **현황만** 다룬다. "그래서 무엇이 문제인가" 는 [BP-11](11_gap_analysis.md), "그래서 어떻게 바꿀 것인가" 는 [BP-20](20_target_architecture.md) 이하가 맡는다.
- 파이프라인 구획(D-01) 기준으로 이 장은 **Runtime 구획의 현재 상태 기술**이다. Authoring/Build 구획은 현재 존재하지 않는다(그것 자체가 BP-11 의 결함 항목).

---

## 1. 시스템 개관

### 1.1 레포 구성

| 디렉토리 | 역할 | 편집 가능 |
|---|---|---|
| `hadar2026_app/` | Flutter 앱 본체. Bonfire/Flame 엔진, `window_manager`(데스크톱 창) | ✅ |
| `packages/cm2_script/` | CM2 DSL 파서 + 인터프리터. 독립 Dart 패키지(로컬 path dep) | ✅ |
| `cm2_script_sample/` | CM2 전 기능을 훑는 CUI 데모 | ✅ |
| `tools/` | 레거시 Hadar 바이너리 변환 파이썬 스크립트 + `tools/mapEditor`(TS/Vite 웹 맵 에디터) | ✅ |
| `docs/` | 기존 개발 문서(architecture, boot_and_map_loading, cm2_script_manual, key_input_policy) | ✅ |
| `blueprint/` | 본 기획서(SSoT) | ✅ |
| `REF_hadar/`, `REF_UNITY_LoreEp1/`, `REF_FLUTTER_lore2026/` | 원본 C++ / Unity 포팅 / 자매 Flutter 포팅. **읽기 전용 참조** | ❌ |

### 1.2 `lib/` 3계층 + 파사드 + 포트

```
lib/
  domain/          순수 데이터 + 게임 규칙.  허용 Flutter import = foundation.dart 뿐
    party/ map/ battle/ magic/ lighting/ console/ window/ system/ text/ game_option.dart
  application/     유스케이스. domain + 포트 조합.  material/bonfire/flame 금지
    battle.dart menu_flows.dart magic_system.dart tile_event_dispatcher.dart
    game_session.dart map_navigation.dart map_loader.dart save_manager.dart
    select.dart window_manager.dart game_reload_exception.dart
    scripting/     script_engine_adapter.dart native_script_runner.dart
                   map_script.dart map_script_context.dart maps/*.dart
    ports/         ui_host.dart movement_host.dart asset_source.dart host_binding.dart
  presentation/    Flutter/Bonfire 결합 코드
    host/          flutter_ui_host.dart bundle_asset_source.dart
    input/         input_dispatcher.dart window_key_dispatcher.dart
                   virtual_input_state.dart input_mode.dart
    panels/        map_viewport / console_panel / input_panel / status_panel /
                   bottom_control_panel / window_view / world_map_renderer / player_sprite
  utils/           hd_text_utils.dart      ← 3계층 어디에도 속하지 않는 4번째 폴더
  hd_game_main.dart  파사드(싱글턴). UiHost + PartyMovementHost 구현
  hd_config.dart     전 화면/스크립트 상수
  main.dart          800x480 고정 레이아웃 조립 + 부팅
  test_script.dart   포트 도입 이전에 남은 고아 엔트리포인트(현재 실행 불가, §9.4)
```

**계층 규모 실측(줄 수)**

| 파일 | 줄 | 파일 | 줄 |
|---|---:|---|---:|
| `application/scripting/script_engine_adapter.dart` | 582 | `presentation/host/flutter_ui_host.dart` | 304 |
| `application/menu_flows.dart` | 544 | `application/magic_system.dart` | 280 |
| `application/battle.dart` | 538 | `domain/party/party.dart` | 257 |
| `domain/party/player.dart` | 466 | `utils/hd_text_utils.dart` | 255 |
| `presentation/panels/player_sprite.dart` | 424 | `hd_game_main.dart` | 249 |
| `presentation/panels/window_view.dart` | 335 | `domain/map/tile_properties.dart` | 227 |
| `application/tile_event_dispatcher.dart` | 180 | `application/game_session.dart` | 152 |

`lib/` 전체 8,904줄, 테스트 1,157줄, cm2 패키지 lib 534줄(parser 164 + engine 340 + ast 30).

### 1.3 포트 3종 — 이미 존재하는 헤드리스 이음매

`lib/application/ports/` 는 application 이 presentation 을 이름조차 부르지 않게 만드는 경계다.

| 포트 | 파일 | 메서드 |
|---|---|---|
| `UiHost` | `ports/ui_host.dart:10` | `showMenu` / `showWindowMenu` / `showMessageWindow` / `addLog` / `waitForAnyKey` / `clearLogs` / `setHeader` / `beginNarrative` / `endNarrative` / `refresh` / `preloadAssets` |
| `PartyMovementHost` | `ports/movement_host.dart:7` | `animatePartyMove(dx, dy)` |
| `AssetSource` | `ports/asset_source.dart:12` | `loadString(path)` |
| `HDHosts`(합성 루트) | `ports/host_binding.dart:16` | `bind(ui:, movement:, assets:)` / `reset()` / `isBound` |

`HDHosts` 는 bind 전에 포트를 읽으면 **고치는 법을 문장으로 알려주는 `StateError`** 를 던진다:

```dart
// hadar2026_app/lib/application/ports/host_binding.dart:31
throw StateError(
  'HDHosts.ui read before bind(). The shell must call '
  'HDHosts().bind(...) during boot (see HDGameMain), and tests must '
  'bind a fake UiHost before exercising application code.',
);
```

바인딩은 파사드 생성자 한 곳에서만 일어난다:

```dart
// hadar2026_app/lib/hd_game_main.dart:172
HDHosts().bind(
  ui: _host,
  movement: _host,
  assets: HDBundleAssetSource(),
);
```

`AssetSource` 의 유일한 프로덕션 구현은 "데스크톱이면 실제 파일이 우선, 아니면 rootBundle" 이다. 이것이 `tools/mapEditor` 가 제자리 편집한 결과를 재빌드 없이 게임이 집어 드는 이유다.

```dart
// hadar2026_app/lib/presentation/host/bundle_asset_source.dart:23
if (!kIsWeb && await File(path).exists()) {
  return File(path).readAsString();
}
return rootBundle.loadString(path);
```

### 1.4 계층 규칙이 CI 로 강제되는 방식

`.github/workflows/ci.yml:50` "Check layering invariants" 잡이 두 grep 을 돌리고, **결과가 비어야** 통과한다.

```bash
# .github/workflows/ci.yml:68
check "application/domain must not import presentation/ or hd_game_main.dart" \
  -E "^import .*(presentation/|hd_game_main\.dart)"
# .github/workflows/ci.yml:72
check "application/domain must not import material/bonfire/flame" \
  -E "package:flutter/material|package:bonfire|package:flame"
```

실측 결과 **두 grep 모두 현재 빈 결과**(위반 0건)다.

다만 CLAUDE.md 가 선언한 규칙 중 **`dart:io` 금지·`flutter/services` 금지는 CI 가 검사하지 않고, 실제로 위반이 있다**:

```dart
// hadar2026_app/lib/application/menu_flows.dart:2
import 'dart:io';
// ...
// hadar2026_app/lib/application/menu_flows.dart:504
exit(0);
```

세 가지 문제가 겹친다:

| # | 문제 | 근거 |
|---:|---|---|
| 1 | **계층 위반** — CLAUDE.md 는 `application/` 의 `dart:io` 금지를 명시하지만 CI grep 2종이 검사하지 않는다 | `ci.yml:68`·`:72` 가 검사하는 것은 presentation/facade import 와 material/bonfire/flame 뿐 |
| 2 | **웹 빌드 파손 가능성** — `dart:io` 는 웹에서 컴파일되지 않는다. `:503`/`:521`/`:539` 가 `if (!kIsWeb)` 런타임 가드를 걸었지만 **`import 'dart:io';`(2행) 은 가드 밖**이라 컴파일 실패를 막지 못한다 | §9.5 — CI 에 `flutter build web` 이 없다 |
| 3 | **헤드리스 하네스 파괴** — `exit(0)` 가 시뮬레이터 프로세스를 통째로 죽인다 | §9.3 · [BP-34](34_headless_sim_and_solver.md) |

D-23 이 CI 에 세 번째 검사(`^import 'dart:(io|html)'`)를 추가하기로 확정했으나, **지금 추가하면 CI 가 즉시 빨개진다** —
따라서 검사 추가와 `exit(0)` 3곳 제거는 같은 변경으로 함께 가야 한다(태스크 **T-022 · T-023 · T-024**).
근거: 부록 B-4. 결함 등록은 [BP-11 G-26](11_gap_analysis.md).

### 1.5 파사드 `HDGameMain`

```dart
// hadar2026_app/lib/hd_game_main.dart:38
class HDGameMain with ChangeNotifier implements UiHost, PartyMovementHost {
```

- **싱글턴**이며 `HDGameSession`(세션 상태)과 `HDFlutterUiHost`(콘솔/메뉴)의 변경 알림을 **둘 다 자기 리스너로 전달**한다. 그래서 UI 는 `ListenableBuilder(listenable: HDGameMain(), …)` 하나로 전체를 갱신한다.
- 알림은 빌드 중 notify 를 피하려고 마이크로태스크로 미룬다:
  ```dart
  // hadar2026_app/lib/hd_game_main.dart:201
  void notifyListeners() {
    Future.microtask(() { if (hasListeners) super.notifyListeners(); });
  }
  ```
- 맵 전환 시에만 진행 로그 스크롤백을 비우는 **부수효과가 파사드에 있다**(`refresh()` 와 구분되는 지점):
  ```dart
  // hadar2026_app/lib/hd_game_main.dart:189
  void _onSessionChanged() {
    if (_session.mapVersion != _lastObservedMapVersion) {
      _lastObservedMapVersion = _session.mapVersion;
      _host.consoleLog.clearProgress();
    }
    notifyListeners();
  }
  ```
- `HDGameMain` 은 약 1,000줄에서 249줄로 줄어들었고, 줄어든 책임은 §3 의 싱글턴들이 나눠 가졌다.

---

## 2. 부팅과 맵 로딩 전 경로

### 2.1 시퀀스

```mermaid
sequenceDiagram
    autonumber
    participant M as main.dart
    participant F as HDGameMain (파사드)
    participant H as HDFlutterUiHost
    participant S as HDGameSession
    participant N as HDNativeScriptRunner
    participant E as HDScriptEngine (cm2)
    participant V as HDMapNavigation
    participant A as AssetSource

    M->>F: HDGameMain() (첫 참조 → _internal())
    Note over F: HDHosts().bind(ui,movement,assets)<br/>HDInputDispatcher().registerGlobalHandler()
    M->>F: init()
    F->>H: preloadAssets()  (Flame.images.loadAll)
    F->>S: init()
    S->>N: startNewGame()  → flags/variables clear, faced=1
    S->>E: loadScript('assets/startup.cm2')
    E->>A: loadString('assets/startup.cm2')
    Note over E: clearRuntimeState() → parse →<br/>init 단계(variable / include / .assign 만 실행)
    S->>E: run()
    Note over E: scriptMode 기본값 0 → if(Equal(ScriptMode(),0)) 진입
    E->>E: LoadScript("LORE_EP", 32, 25)
    Note over E: isScriptRunning == false 이므로<br/>즉시 executePendingNavigation()
    E->>S: loadMapFromFile("LORE_EP")
    S->>V: loadByName("LORE_EP")
    V->>A: loadString('assets/maps/MapInfos.json')
    Note over V: name=="LORE_EP" → id=2 →<br/>json='Map002.json', cm2='Map002.cm2'
    V->>A: loadString('assets/maps/Map002.json')
    V-->>S: MapBundle{mapName:'LORE_EP', json:MapModel, cm2Path:'Map002.cm2'}
    S->>S: HDBattle().init()
    S->>S: setNewMap(json) → mapVersion++ → notify
    S->>E: loadScript('assets/Map002.cm2')   ⚠ 엔진 전역 전부 소실
    S->>N: currentMapScript swap (mapScriptFactory['LORE_EP'] → 없음 → null)
    E->>E: setScriptMode(0); run()   (= FLAG_MAP 패스)
    Note over E: Map002.cm2 의 `if (FLAG_MAP.Equal(ScriptMode()))`<br/>→ Map::SetStartPos(32,27) → _startPosHint
    E->>S: party.setPosition(32, 25)  (LoadScript 인자가 hint 보다 우선)
    E->>E: _applyEntryFacing()
    E-->>F: halted = true → 바깥 startup.cm2 루프 종료
    F-->>M: init() 반환 → setState(_ready = true)
```

### 2.2 단계별 코드 근거

| # | 단계 | 코드 |
|---|---|---|
| 1 | 앱 진입, 전체화면/가로 고정, 데스크톱 창 816x519 | `lib/main.dart:13`~`:38` |
| 2 | 파사드 최초 참조 시 포트 바인딩 + 전역 키 핸들러 등록 | `lib/hd_game_main.dart:169`~`:182` |
| 3 | 렌더링 자산 프리로드 후 세션 부팅 | `lib/hd_game_main.dart:210` |
| 4 | 네이티브 러너 초기화(맵은 로드 안 함) | `lib/application/game_session.dart:68` |
| 5 | `startup.cm2` 로드/실행 | `lib/application/game_session.dart:69`, `:76` |
| 6 | 시작 맵 결정(코드가 아니라 **데이터**가 결정) | `assets/startup.cm2:2`~`:6` |
| 7 | `LoadScript` 핸들러 | `lib/application/scripting/script_engine_adapter.dart:287` |
| 8 | 이름 → 번들 해석 | `lib/application/map_navigation.dart:25` |
| 9 | 번들 적용(전투 정리 → setNewMap → cm2 로드 → 네이티브 swap) | `lib/application/game_session.dart:85`~`:130` |
| 10 | 위치/방향 확정 | `script_engine_adapter.dart:52`~`:63` |

`startup.cm2` 전문(6줄, 주석 포함):

```cm2
# hadar2026_app/assets/startup.cm2
if (Equal(ScriptMode(), 0))
#	LoadScript("L1_ep1d0.cm2", 47, 28)
#	LoadScript("menace.cm2", 24, 41)
#	LoadScript("town2.cm2", 50, 30)
	LoadScript("LORE_EP", 32, 25)
```

### 2.3 `LoadScript` 의 두 얼굴

`LoadScript(x, ...)` 는 **맵 이름**과 **cm2 파일명** 둘 다를 받는다. 분기는 `loadMapFromFile` 의 성공 여부로 결정된다.

```dart
// hadar2026_app/lib/application/scripting/script_engine_adapter.dart:45
bool isMap = await HDGameSession().loadMapFromFile(nav.path);
if (!isMap) await loadScript('assets/${nav.path}');
```

사실은 **세 갈래**다. 세 번째가 §7.2 의 역설을 낳는다.

| # | 인자 | 해석 경로 | 결과 |
|---:|---|---|---|
| 1 | `"LORE_EP"` — MapInfos 에 **있는** 이름 | `Map{id:03d}.json` + `Map{id:03d}.cm2` 로 강제 해석 | 파일이 있으면 정상 로드. 없으면 조용히 실패(§7.2) |
| 2 | `"town1.cm2"` — 파일명 | `loadByName` 실패(`town1.cm2.json` 없음, cm2Path 도 null) → `null` 반환 | `assets/town1.cm2` 를 **전역 스크립트로 교체**(레거시 체인) |
| 3 | `"ORIGIN"` — MapInfos 에 **없는** 이름 + 동명 json 존재 | 아래 폴백이 살아남음 | `assets/maps/ORIGIN.json` **정상 로드**, `cm2Path == null` → 레거시 티어 |

경로 3 의 근거 — 폴백을 먼저 설정하고 매치될 때만 덮어쓴다:

```dart
// hadar2026_app/lib/application/map_navigation.dart:29
String resolvedJsonName = '$searchName.json'; // Fallback
...
// :41~:44  (이름이 매치될 때만 실행)
final int id = info['id'];
final idStr = id.toString().padLeft(3, '0');
resolvedJsonName = 'Map$idStr.json';
cm2Path = 'Map$idStr.cm2';
```

즉 `startup.cm2` 의 주석 처리된 세 줄(`menace.cm2`, `town2.cm2`, `L1_ep1d0.cm2`)이 경로 2 이고,
`ORIGIN` 은 경로 3 으로 **지금 당장 동작한다**. 반대로 `TOWN1` 은 **등록되어 있기 때문에** 경로 1 로 끌려가 죽는다(§7.2).

### 2.4 재진입 시 경로(타일 이벤트 중 맵 전환)

타일 이벤트 처리 중에는 즉시 전환하지 않고 **지연 전환**을 쓴다. 위젯 계층이 `map == null` 을 보고 로딩 화면을 띄운 뒤 재진입한다.

```dart
// hadar2026_app/lib/application/scripting/script_engine_adapter.dart:297
if (HDTileEventDispatcher().isScriptRunning) {
  pendingNavigation = (path: path, hasExplicit: hasExplicitPos, nx: nx, ny: ny);
  HDWindowManager().clear();
  HDGameSession().clearCurrentMap();
} else {
  pendingNavigation = (...);
  await executePendingNavigation();
}
```

```dart
// hadar2026_app/lib/main.dart:83 (_MainScreenState._onGameChanged)
void _onGameChanged() {
  if (HDGameMain().map == null && HDGameMain().hasPendingNavigation) {
    _loadPendingMap();
  }
}
```

### 2.5 시작 위치 결정 우선순위

`executePendingNavigation`(`script_engine_adapter.dart:39`) 이 확정한다.

| 우선순위 | 조건 | 위치 |
|---|---|---|
| 1 | `LoadScript(name, x, y)` 로 좌표를 명시 | `(x, y)` |
| 2 | FLAG_MAP 실행 중 `Map::SetStartPos(x, y)` 호출 | 그 좌표 |
| 3 | 둘 다 없음 | 맵 중앙 `(width~/2, height~/2)` |

방향은 그다음 `_applyEntryFacing()`(`:144`) 이 결정한다 — ① 인접한 `enter` 타일이 있으면 그 반대 방향, ② 없으면 맵 중앙 쪽(우세 축), ③ 이미 중앙이면 아래.

---

## 3. 싱글턴 지도

`Foo()` 팩토리가 정적 인스턴스를 돌려주는 형태가 코드베이스 전반의 관례다(원본 C++ 전역을 의도적으로 미러링). **DI 리팩터링 대상이 아니다.**

| 싱글턴 | 계층 | 소유 상태 | 세이브 v1 저장 | 리셋 방법 |
|---|---|---|---|---|
| `HDGameMain` | 파사드(`lib/`) | 없음(전부 위임). `_lastObservedMapVersion` 만 자체 보유 | — | 없음 |
| `HDGameSession` | application | `map`, `mapVersion`, `sessionId`, `errorMessage`, `party`, `gameSystem`, `gameOption`, `currentMapCm2Path` | `party`/`gameSystem`/`gameOption`/`map` ✅ · `currentMapCm2Path` ❌ · **현재 맵 이름** ❌ | 없음(`clearCurrentMap()` 이 맵만 해제) |
| `HDFlutterUiHost` | presentation | `consoleLog`(events/progress), `activeMenu`, `_header`, `_narrativeActive`, `_keyWaitCompleter`, `_bonfireGame` | ❌ | `resetForTest()` (`@visibleForTesting`) |
| `HDInputDispatcher` | presentation | `_registered` 플래그만 | ❌ | 없음 |
| `HDWindowKeyDispatcher` | presentation | 없음(스택을 조회만) | — | — |
| `HDWindowManager` | application | 오버레이 윈도우 스택 `List<HDWindow>` | ❌ | `clear()` |
| `HDBattle` | application | `enemies`, `playerCommands`, `_battleResult`, `isBattleActive`, `selectedEnemyIndex` | ❌ | `init()` |
| `HDMenuFlows` | application | 없음(전부 포트/세션 조회). 메인 메뉴는 8줄 리스트 리터럴(`menu_flows.dart:34`~`:43`) | — | — |
| `HDMagicSystem` | application | **싱글턴이 아니다** — `static` 메서드 3개(`castSpell`/`useESP`/`castBattleSpellUI`)뿐인 클래스(`magic_system.dart:8`) | — | 상태가 없어 불필요 |
| `HDSightCalculator` | domain | **싱글턴이 아니다** — `static` 순수 함수 3개(`sightRangeFor`/`isInMoonlight`/`lightBitFor`) | — | 불필요 |
| `HDTileEventDispatcher` | application | `_isScriptRunning` (bool 1개) | ❌ | 없음 |
| `HDMapNavigation` | application | `errorMessage` | ❌ | 없음 |
| `HDScriptEngine` | application | 내부 `ScriptEngine`(`variables`, `_contexts`, `currentScript`, `scriptMode`, `targetX/Y`, `handled`, `halted`), `_tileMap`, `_currentRow`, `_startPosHint`, `pendingNavigation` | ❌ (`gameOption.scriptFile` 로 **경로만** 저장) | `loadScript()` 가 `clearRuntimeState()` 호출 |
| `HDNativeScriptRunner` | application | `currentMapScript`, `flags: Map<int,bool>`, `variables: Map<int,int>`, `mapScriptFactory` | ❌ | `startNewGame()` |
| `HDSelect` | application | `items`, `selectedIndex`, `isSelectionActive`, `_lastResult` | ❌ | `init()` |
| `HDSaveManager` | application | 없음(전부 `static`) | — | — |
| `HDHosts` | application | 포트 3개 참조 | — | `reset()` |
| `HDBundleAssetSource` | presentation | 없음 | — | — |
| `HDVirtualInputState` | presentation | `actionPressed: bool`, `direction: JoystickMoveDirectional` (`virtual_input_state.dart:10`~`:11`) | ❌ | 없음 |
| `HDWorldMap` | presentation | 싱글턴 아님 — 맵마다 새 인스턴스. `_tileSheetA5`/`_tileSheetB` 스프라이트 시트 (`world_map_renderer.dart:17`~`:18`) | ❌ | 뷰포트 재생성 |

**읽는 법**: "세이브 v1 저장" 열의 ❌ 가 곧 §6 의 상태 분열 문제다. 특히 `HDNativeScriptRunner.flags/variables` 와 `HDScriptEngine.variables` 는 게임 진행에 직접 쓰이면서 저장되지 않는다.

**리셋 가능성**: 테스트가 되돌릴 수 있는 싱글턴은 `HDHosts`(`reset`), `HDFlutterUiHost`(`resetForTest`), `HDBattle`/`HDSelect`/`HDWindowManager`(`init`/`clear`) 뿐이다. `HDGameSession`, `HDScriptEngine`, `HDNativeScriptRunner`, `HDTileEventDispatcher` 는 리셋 수단이 없다.

---

## 4. 타일 상호작용 파이프라인

### 4.1 입력 → 이동 → 이벤트

```
[HardwareKeyboard]                 [가상 패드]
        │                               │
        └────────► HDInputDispatcher.process(key) ◄──── HDVirtualInputState
                            │
              currentInputMode 우선순위 해석 (hd_game_main.dart:159)
                window > menu > dialogue > map
                            │
   ┌────────────┬───────────┼────────────┬──────────────┐
   ▼            ▼           ▼            ▼              │
 window       menu       dialogue       map             │
 _handleWindow _handleMenu _handleDialogue _handleMap    │
   │            │           │            │              │
   │            │           │      Esc/Q/Space→메인메뉴  │
   │            │           │      Ins/Del/Home/End→시각 조작
   │            │           │      그 외 → return false ─┘
   │            │           │                (= 이동/확인 키는 여기서 처리되지 않음)
   ▼            ▼           ▼
HDWindowKey  menu.completer  host.dismissKeyWait()
Dispatcher   .complete(idx)
```

**결정적 사실**: 방향키 이동과 확인(Enter/E) 상호작용은 `HDInputDispatcher` 가 아니라 **Bonfire 컴포넌트 `HDPlayerSprite.update(dt)` 안**에서 매 프레임 `HardwareKeyboard.instance.isLogicalKeyPressed(...)` 를 폴링해 처리된다.

```dart
// hadar2026_app/lib/presentation/input/input_dispatcher.dart:149
// Action (Enter/E) is handled by HDPlayerSprite for now to know
// facing/position.
return false;
```

```dart
// hadar2026_app/lib/presentation/panels/player_sprite.dart:122
bool isActionKeyPressed =
    HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.enter) ||
    HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.keyE) ||
    HDVirtualInputState().actionPressed;
```

이벤트 발화 지점은 정확히 세 곳이다.

| 발화 | 위치 | 인자 |
|---|---|---|
| 타일에 **올라섰을 때** | `player_sprite.dart:193` | `checkTileEvent(party.x, party.y, isInteraction: false)` |
| **막힌 타일에 부딪혔을 때** | `player_sprite.dart:362` | `checkTileEvent(nextX, nextY, isInteraction: true)` |
| **바라보는 타일 확인 키** | `player_sprite.dart:405` | `checkTileEvent(targetX, targetY, isInteraction: true)` |

### 4.2 통행 판정과 액션 결정

`HDTileProperties.getUnitAction(unit)` 이 단일 진실이며 **3단 폴백**이다.

```dart
// hadar2026_app/lib/domain/map/tile_properties.dart:183
static HDTileAction getUnitAction(MapUnit? unit) {
  if (unit == null) return HDTileAction.none;
  int eventType = unit.ixEvent & 0x00FF0000;          // ① 이벤트 레이어 우선
  if (eventType != 0) {
    if (eventType == 0x00010000) return HDTileAction.event;
    if (eventType == 0x00020000) return HDTileAction.talk;
    if (eventType == 0x00030000) return HDTileAction.sign;
    if (eventType == 0x00040000) return HDTileAction.enter;
  }
  if (unit.ixObj1 > 0) {                              // ② 오브젝트(B 타일) 규칙
    final objAction = _getObjectAction(unit.ixObj1);
    if (objAction != HDTileAction.move && objAction != HDTileAction.none) return objAction;
    if (objAction == HDTileAction.none) return HDTileAction.none;
  }
  return _getTileAction(unit.ixTile);                 // ③ 지면(A5) 규칙
}
```

| 소스 | 범위 → 액션 | 코드 |
|---|---|---|
| `ixEvent & 0x00FF0000` | 0x1=event, 0x2=talk, 0x3=sign, 0x4=enter | `tile_properties.dart:187` |
| `ixObj1` (B 타일) | `<64` BLOCK, `<88` MOVE, `<96` MOVE(애니), `<112` BLOCK, `<124` SIGN, `<128` ENTER, `<144` TALK, else MOVE | `tile_properties.dart:208` |
| `ixTile` (A5) | `<56` MOVE, `<60` WATER, `<62` SWAMP, `<64` LAVA, `<70` ENTER, `<72` CLIFF, `<128` BLOCK(none), else MOVE | `tile_properties.dart:172` |

`ixEvent` 는 맵 로더가 **JSON `events[]` 를 타일에 도장 찍어** 만든다:

```dart
// hadar2026_app/lib/application/map_loader.dart:57
int eventType = 0;
if (parsedEvent.type == "EVENT") eventType = 0x00010000;
else if (parsedEvent.type == "TALK") eventType = 0x00020000;
else if (parsedEvent.type == "SIGN") eventType = 0x00030000;
else if (parsedEvent.type == "ENTER") eventType = 0x00040000;
unit.ixEvent = eventType | parsedEvent.id;
```

`type` 은 이벤트 `name` 의 **접두사**로 정해진다(`MapEvent._parseTypeString`, `domain/map/map_event.dart:54`): `TALK` / `ENTER` / `EVENT`|`EVT` / `NPC` / `SIGN` / 그 외 `UNKNOWN`. → **접두사가 없으면 `ixEvent` 도 0 이라 타일 액션이 생기지 않는다.**

통행 판정도 액션에서 파생된다:

```dart
// hadar2026_app/lib/domain/map/tile_properties.dart:107
if (action == HDTileAction.none || action.isInteractive) return false;
if (action == HDTileAction.water) return unit.ixTile == 56 && walkOnWater > 0;
return true;
```

### 4.3 `HDTileEventDispatcher.check` — 게이트

```dart
// hadar2026_app/lib/application/tile_event_dispatcher.dart:45 (check)
if (map == null) return;
if (_isScriptRunning) return;              // ← 전역 재진입 가드(bool 1개)

_isScriptRunning = true;
try {
  final action = HDTileProperties.getUnitAction(map.getUnit(x, y));
  final bool isScriptedAction =
      isInteraction ? action.isInteractive : action.isStepOn;   // :58

  if (isScriptedAction) {
    host.beginNarrative();                 // :62
    host.clearLogs();
    await Future.delayed(Duration.zero);
    await _dispatchScripted(action, x, y, map, host);
  } else if (!isInteraction) {
    switch (action) {                      // :73 앰비언트(진행 로그로만)
      case HDTileAction.swamp: await host.addLog("일행은 독이 있는 늪에 들어갔다 !!!", isDialogue: false);
      case HDTileAction.lava:  await host.addLog("일행은 용암지대로 들어섰다 !!!", isDialogue: false);
      case HDTileAction.water: if (party.walkOnWater > 0) { party.walkOnWater--; party.notifyListeners(); }
      case ... : break;                    // 나머지는 no-op (exhaustive switch)
    }
  }
} finally {
  if (narrativeOpened) {
    await host.endNarrative(
      autoFlush: HDScriptEngine().pendingNavigation == null);   // :98
  }
  _isScriptRunning = false;
}
```

`isScriptedAction` 판정표:

| 액션 | `isInteractive` | `isStepOn` | 밟았을 때 | 마주보고 확인 |
|---|:--:|:--:|---|---|
| `none(0)` | ✗ | ✗ | — | — (통행 불가) |
| `talk(1)` | ✓ | ✗ | — | 스크립트 |
| `sign(2)` | ✓ | ✗ | — | 스크립트 |
| `event(3)` | ✗ | ✓ | 스크립트 | — |
| `enter(4)` | ✓ | ✓ | 스크립트 | 스크립트 |
| `water(5)` | ✗ | ✗ | walkOnWater 소모 | — |
| `swamp(6)` | ✗ | ✗ | 앰비언트 로그 | — |
| `lava(7)` | ✗ | ✗ | 앰비언트 로그 | — |
| `cliff(8)` | ✗ | ✗ | — | — |
| `move(9)` | ✗ | ✗ | — | — |

괄호 안 숫자는 `scriptMode` — **와이어 값이며 `Enum.index` 가 아니다**. `assets/const.cm2:64`~`:68` 의 `FLAG_MAP/TALK/SIGN/EVENT/ENTER` 와 대응하고, `test/domain/map/tile_action_test.dart:11` 이 고정한다.

### 4.4 `_dispatchScripted` — 3티어

```dart
// hadar2026_app/lib/application/tile_event_dispatcher.dart:116
if (action == HDTileAction.sign) {
  host.setHeader('@B푯말에 써 있기를:');
}

final native = HDNativeScriptRunner();
final cm2Path = HDGameSession().currentMapCm2Path;

// ── 티어 1: 네이티브 맵 스크립트 ────────────────────────────
if (native.currentMapScript != null) {                     // :126
  await _emitJsonDialog(map, x, y, host, action);          // JSON 을 *먼저* 무조건 출력
  await native.processMapEvent(action, x, y);              // 반환 bool 은 소비되지 않음
  return;
}

// ── 티어 2: cm2 페어링 맵 ──────────────────────────────────
if (cm2Path != null) {                                     // :137
  HDScriptEngine().setTargetPos(x, y);
  HDScriptEngine().setScriptMode(action.scriptMode);
  await HDScriptEngine().run();
  if (HDScriptEngine().handled) return;                    // Event::Override() 호출 여부
  await _emitJsonDialog(map, x, y, host, action);          // 폴백
  return;
}

// ── 티어 3: 레거시(둘 다 없음) ─────────────────────────────
print('[JSN][$tag] ($xs, $ys)');                           // :152
await _emitJsonDialog(map, x, y, host, action);
HDScriptEngine().setTargetPos(x, y);
HDScriptEngine().setScriptMode(action.scriptMode);
await HDScriptEngine().run();
```

| 분기 | 조건 | JSON 대사 | 스크립트 | 폴백 |
|---|---|---|---|---|
| 네이티브 맵 | `mapScriptFactory[mapName] != null` | **항상 선출력** | `onTalk/onSign/onEvent/onEnter` | 없음(반환 bool 미사용) |
| cm2 페어 맵 | `currentMapCm2Path != null` | `handled == false` 일 때만 | cm2 `run()` | JSON |
| 레거시 | 둘 다 null | 항상 선출력 | 전역 cm2 체인 `run()` | 없음 |

> ⚠ **이 표의 "조건" 열은 티어를 고를 뿐, 그 티어가 올바른 스크립트를 들고 있음을 보장하지 않는다.**
> `currentMapCm2Path` 는 페어 cm2 **파일이 실제로 로드되었는지와 무관하게** 항상 설정되고(`game_session.dart:100`),
> 로드가 실패해도 엔진은 직전 맵 스크립트를 그대로 들고 있다(§5.4). 등록 이름 15개 중 13개가 이 상태다.
> 마찬가지로 네이티브 맵 분기는 **맵 지오메트리가 로드되지 않아도** 실행된다(§7.2, 부록 F-2).
> 따라서 "현재 동작" 을 보존 대상으로 삼는 이관 설계(D-10)는 **보존할 동작 자체가 비결정적**이라는 전제에서 출발해야 한다.

JSON 티어의 실제 구현 — **좌표당 첫 이벤트 하나, 조건 없음, 상태 참조 없음**:

```dart
// hadar2026_app/lib/application/tile_event_dispatcher.dart:159
Future<void> _emitJsonDialog(MapModel map, int x, int y, UiHost host, HDTileAction action) async {
  for (final ev in map.events) {
    if (ev.x == x && ev.y == y) {
      for (final line in ev.dialogLines) {
        if (line.isNotEmpty) await host.addLog(line);
      }
      return;                            // ← 첫 매치에서 종료
    }
  }
}
```

`events` 는 `List<MapEvent>` 이고 선형 탐색이다(`map_model.dart:13`). 인덱스가 없다.

### 4.5 `Event::Override()` 관례 — 메커니즘과 실제 자산의 관측 결과

`assets/Map002.cm2` 의 TALK 블록은 `Event::Override()` 를 부르지 않고, ENTER 블록은 부른다:

```cm2
# hadar2026_app/assets/Map002.cm2:5
if (Equal(ScriptMode(), FLAG_TALK))
	if (On(30, 20))
		SetHeader("누군지 모르는 사람")
		Talk("제가 철학적인 질문을 하나 해 보겠소.")
		...                                    # ← Event::Override() 없음
	if (OnArea(23, 21, 23, 22))
		Event::Override()                      # ← 이쪽은 있음
		Battle::Init()
```

**메커니즘상으로는** `handled == false` 로 끝나므로 그 뒤에 `_emitJsonDialog` 가 호출되고, 같은 좌표에 JSON 이벤트가 있으면 중복 출력이 난다.

**그러나 현재 자산에서 실제 중복은 관측되지 않는다.** `Map002.json` 의 이벤트 18개 좌표와 `Map002.cm2` 의 `On`/`OnArea` 좌표를 교차한 실측 결과:

| cm2 좌표 | 스크립트 모드 | `Event::Override()` | 같은 좌표에 JSON 이벤트 | 실제 결과 |
|---|---|:--:|:--:|---|
| `On(30, 20)` | FLAG_TALK | ❌ 없음 | **없음** | JSON 폴백이 매치 실패 → 출력 없음. **중복 안 남** |
| `OnArea(23, 21, 23, 22)` | FLAG_TALK | ✅ | 없음 | cm2 만 실행 |
| `On(30, 25)` | FLAG_ENTER | ✅ | ✅ `ENTER001` | cm2 만 실행 → **JSON 텍스트가 사문화** |
| `On(30, 28)` | FLAG_ENTER | ✅ | ✅ `ENTER002` | cm2 만 실행 → **JSON 텍스트가 사문화** |

(타일 액션 확인: (30,20)/(23,21)/(23,22) 는 `objUpper` 값이 129/135/143 이라 `_getObjectAction` 이 `talk` 을 돌려준다 — 즉 대화 자체는 발화된다. (30,25)/(30,28) 은 지면 A5 인덱스 64 라 `_getTileAction` 이 `enter` 를 돌려준다.)

즉 **`Event::Override()` 누락이 만드는 것은 "중복" 이 아니라 "누락 좌표에 JSON 이벤트가 없어 아무 일도 안 일어남" 이고, 반대로 `Event::Override()` 가 있는 곳에서는 JSON 대사가 영원히 표시되지 않는다.**

**사문 JSON 대사 실측 3줄** (cm2 가 Override 로 가려 버려 게임에서 절대 볼 수 없는 텍스트):

| 맵 | 좌표 | 이벤트 이름 | 표시되지 않는 텍스트 |
|---|---|---|---|
| Map002 (`LORE_EP`) | (30, 25) | `ENTER001` | `난데없는 던전 입구` |
| Map002 (`LORE_EP`) | (30, 28) | `ENTER002` | `(텍스트 내용)` |
| Map003 (`MAP003`) | (10, 5) | `ENTER001` | `쿠겔겔` |

`Map003.cm2:6`~`:7` 이 `On(10, 5)` 에서 `Event::Override()` 를 부르는 것이 세 번째 줄의 근거다.

> **왜 이 구분이 중요한가**: "중복이 난다" 는 *출력이 지저분해지는* 문제지만, "사문화된다" 는 *콘텐츠가 조용히 사라지는* 문제다.
> 후자가 AI 파이프라인에는 훨씬 나쁘다 — 생성 에이전트가 텍스트를 써 넣고 API 가 성공을 반환해도 플레이어에게 도달하지 않는다.
> 결함 등록은 [BP-11 G-07](11_gap_analysis.md).

## 5. 스크립팅 3종 능력 비교

### 5.1 언어/런타임 사양

| 축 | cm2 (DSL) | 네이티브 Dart (`HDMapScript`) | JSON `dialogLines` |
|---|---|---|---|
| 소스 위치 | `assets/*.cm2` | `lib/application/scripting/maps/*.dart` | `assets/maps/Map*.json#events[].pages[0].list[code=401]` |
| 등록 방식 | `MapInfos.json#cm2` 또는 `Map{id:03d}.cm2` 규칙 | `HDNativeScriptRunner.mapScriptFactory` 하드코딩 Map | 좌표 일치(선형 탐색) |
| **조건 분기** | `if (Cond(...))` / `else` 만. `elif` 없음 | Dart 전부 | **없음** |
| **루프** | **없음**(while/for 미지원) | Dart 전부 | 없음 |
| **함수 정의** | **없음** | Dart 전부 | 없음 |
| **산술** | `Add(...)` 만. `-`,`*`,`/` 없음 | Dart 전부 | 없음 |
| **비교** | `Equal`, `Less`, `Not`, `Or`, `And`, `<var>.Equal` | Dart 전부 | 없음 |
| **문자열 조작** | `JoinString(...)` 만 | Dart 전부 | 없음 |
| 상태 읽기 | `Flag::IsSet`, `Variable::Get`, `Party::PosX/Y`, `Player::Get*`, `Battle::Result`, `Select::Result`, `On`, `OnArea`, `ScriptMode` | 세션·러너 전역 전부(단, §5.4 주의) | **불가** |
| 상태 쓰기 | `Flag::Set/Reset`, `Variable::Set/Add`, `Party::PlusGold`, `Player::ChangeAttribute` 등 | Dart 전부 | 불가 |
| 맵 전환 | `LoadScript(name[,x,y])`, `Map::LoadFromFile` | `HDNativeScriptRunner.loadMapScript` | 불가(`hadarEvent.warp` 은 미구현) |
| **정적 검증** | **불가**(미등록 심볼도 파싱은 통과) | Dart 컴파일러/analyzer 전부 | JSON 스키마 없음 |
| **핫리로드** | ✅ 데스크톱에서 파일 저장만으로 반영(`HDBundleAssetSource` 파일 우선) | ❌ 코드 수정 + 재빌드 | ✅ 파일 저장만으로 반영 |
| **실패 모드** | 침묵(§5.3) | 컴파일 에러 / 런타임 예외 | 조용히 아무 것도 출력 안 함 |
| 재사용 단위 | `include("...")` | Dart 클래스/함수 | 없음 |

### 5.2 cm2 등록 심볼 전량 (실측)

**커맨드**(`script_engine_adapter.dart:180`~`:492`, **40개**)

```
Talk  Log  SetHeader  Answer  PressAnyKey
Map::Init  Map::SetTile  Map::SetRow  Map::LoadFromFile  Map::SetStartPos
Map::ChangeTile  Map::SetType  Map::SetEncounter
Select::Init  Select::Add  Select::Run
LoadScript  WarpPrevPos
Battle::Init  Battle::RegisterEnemy  Battle::ShowEnemy  Battle::Start
Flag::Set  Flag::Reset  Variable::Set  Variable::Add
Player::ChangeAttribute  Enemy::ChangeAttribute  Player::AssignFromEnemyData
Party::PosX  Party::PosY  Party::PlusGold  Party::Move
DisplayMap  DisplayStatus  Wait  TextAlign
Tile::CopyTile  Tile::CopyToDefaultTile  Tile::CopyToDefaultSprite
```

**함수**(`script_engine_adapter.dart:500`~`:580`, **12개**)

```
Flag::IsSet  Variable::Get  On  OnArea  Battle::Result  Select::Result
Party::PosX  Party::PosY  Player::GetName  Player::GetGenderName
Player::GetAttribute  Player::IsAvailable
```

**엔진 내장**(`packages/cm2_script/lib/src/cm2_script.dart`)

- 커맨드: `variable`, `include`, `halt`, `Event::Override`, `Context::SetCurrent/Delete/Set`, `<name>.assign`, `<name>.add`
- 함수: `Not`, `Or`, `And`, `Equal`, `Less`, `Add`, `Random`, `ScriptMode`, `JoinString`, `Context::Get`, `Context::GetCurrent`, `<name>.Equal`

**스텁(등록만 되고 아무 것도 안 하는 것)**: `Party::PosX`/`Party::PosY` 커맨드(`:418`~`:419` 빈 본문), `Map::SetEncounter`(`:445` print 만), `TextAlign`(`:458` print 만).

### 5.3 cm2 침묵 실패 모드 — 원문 인용

```dart
// packages/cm2_script/lib/src/cm2_script.dart:198  (미등록 커맨드)
default:
  final handler = _commands[cmd];
  if (handler != null) { await handler(stmt, this); }
  else { print("Unknown command: $cmd"); }        // ← 스킵하고 계속 진행
```

```dart
// packages/cm2_script/lib/src/cm2_script.dart:330  (미등록 함수)
final handler = _functions[cmd];
if (handler != null) return handler(args, this);
print("ScriptEngine: Unknown function $cmd");
return 0;                                          // ← 0 = false → 조건문이 조용히 오분기
```

```dart
// packages/cm2_script/lib/src/cm2_script.dart:81  (_executeRootInitialization, init 단계)
for (var stmt in currentScript) {
  if (stmt is CommandStatement) {
    if (stmt.command == 'variable' || stmt.command == 'include' ||
        stmt.command.endsWith('.assign')) { await executeCommand(stmt); }
  }
}
// packages/cm2_script/lib/src/cm2_script.dart:99  (run 단계)
if (stmt.command == 'variable' || stmt.command == 'include') continue;
//   ↑ .assign 은 건너뛰지 않는다 → 매 run() 마다 재실행
```

→ **메인 스크립트 최상단의 `score.assign(0)` 은 타일을 밟을 때마다 상태를 0으로 되돌린다.** 회피법은 초기 대입을 `include` 된 파일 안에 두는 것뿐이다.

파서도 관용적이라 오타를 잡지 못한다. 괄호가 없는 줄은 인자 없는 커맨드로 취급된다:

```dart
// packages/cm2_script/lib/src/parser.dart:111
int startParen = line.indexOf('(');
if (startParen == -1) return CommandStatement(line, []);
```

**침묵 실패는 한 계열이 아니라 두 계열이다.** 위의 것은 *심볼이 없을 때* 생기고, 아래는 *심볼도 문법도 맞는데 값이 범위 밖일 때* 생긴다:

```dart
// hadar2026_app/lib/application/scripting/script_engine_adapter.dart:362 (Flag::Set)
e.registerCommand('Flag::Set', (stmt, eng) async {
  final flagId = eng.getVal(stmt.args[0]);
  final idx = flagId is num ? flagId.toInt() : int.tryParse(flagId.toString()) ?? -1;
  if (idx >= 0 && idx < HDConfig.maxFlags) {
    flags()[idx] = true;
  }                                  // ← else 없음. Flag::Set(300) 은 무음 no-op
});
```

같은 형태가 `Flag::Reset`(`:369`), `Variable::Set`(`:376`), `Variable::Add`(`:383`) 에 모두 있고,
`HDBattle.registerEnemy`(`battle.dart:43`~`:46`), `Player::AssignFromEnemyData`(`:410`~`:416`),
`Player::GetName`(`:548`~`:554`, 범위 밖이면 `"Unknown"` 문자열 반환) 도 같은 계열이다.
로그도 예외도 없다. 자세한 파급은 [BP-11 G-30](11_gap_analysis.md) 이 다룬다.

### 5.4 맵 전환 시 상태 소실 — 그리고 **소실되지 않는 더 흔한 경우**

**로드에 성공한 경우** — 엔진 전역이 통째로 지워진다:

```dart
// hadar2026_app/lib/application/scripting/script_engine_adapter.dart:103 (loadScript, 성공 경로)
_engine.clearRuntimeState();      // variables.clear() + _contexts.clear()
_tileMap.clear();
_currentRow = 0;
await _engine.loadFromString(content);
```

`loadScript` 는 맵 전환마다 호출된다(`game_session.dart:107`). 따라서 로드가 성공하면 **cm2 의 `variable` 전역은 맵 하나 안에서만 유효**하다. 맵을 넘겨야 하는 상태는 `Flag::Set`/`Variable::Set`(→ `HDGameOption`) 이나 네이티브 러너 쪽에 둬야 한다.

**로드에 실패한 경우** — 아무것도 지워지지 않는다. `clearRuntimeState()` 에 도달하기 전에 조기 `return` 한다:

```dart
// hadar2026_app/lib/application/scripting/script_engine_adapter.dart:92~99 (loadScript, 실패 경로)
Future<void> loadScript(String assetPath) async {
  String content;
  try {
    content = await HDHosts().assets.loadString(assetPath);
  } catch (e) {
    print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
    return;                      // ← :103 의 clearRuntimeState() 에 도달하지 못함
  }
  ...
```

**그리고 실패가 정상이다.** `map_navigation.dart:44` 가 `cm2Path = 'Map$idStr.cm2'` 를 **무조건** 설정하는데
`MapInfos.json` 에는 `cm2` 필드가 하나도 없다(§7.2). 실제로 존재하는 페어 cm2 는 `Map002.cm2`·`Map003.cm2`
둘뿐이므로 **등록 이름 15개 중 13개가 존재하지 않는 `MapNNN.cm2` 를 페어로 갖는다.**

| 결과 | 내용 |
|---|---|
| 엔진 상태 | 직전 맵의 파싱된 `currentScript` + `variables` + `_contexts` 가 **그대로 잔존** |
| `currentMapCm2Path` | 실패와 무관하게 `bundle.cm2Path` 로 갱신됨(`game_session.dart:100`) → **non-null** |
| 티어 판정 | `_dispatchScripted` 가 `cm2Path != null` 을 보고 **티어 2(cm2)를 고름**(§4.4) |
| 실제 실행되는 스크립트 | **직전 맵의 cm2 핸들러**가 새 맵 좌표를 상대로 실행됨 |

즉 §5.4 의 두 문단은 서로 반대 방향의 사실이며, **어느 쪽이 적용될지는 파일 존재 여부라는 데이터 조건이 정한다.**
"cm2 전역의 수명" 이라는 언어 규칙이 존재하지 않고 호스트 구현 세부가 그것을 대신한다 — 프롬프트 계약으로 담을 수 없는 형태다.
근거: `_meta/GROUND_TRUTH.md` 부록 A-1 · A-2. 결함 등록은 [BP-11 G-29](11_gap_analysis.md).

### 5.5 네이티브 스크립트 — 현재 등록 현황과 헬퍼의 함정

```dart
// hadar2026_app/lib/application/scripting/native_script_runner.dart:25
final Map<String, HDMapScript Function()> mapScriptFactory = {
  'TOWN1': () => Town1MapScript(),
  'GROUND1': () => Ground1MapScript(),
  'TOWN2': () => Town2MapScript(),
  'DEN1': () => Den1MapScript(),
};
```

**등록 4종 중 `TOWN2` 는 이름 자체가 도달 불가다.** `MapInfos.json` 에 `TOWN2` 엔트리가 없고 `assets/maps/TOWN2.json` 파일도 없다.
`mapScriptFactory[bundle.mapName]` 조회에 걸리려면 `loadByName` 이 `mapName: 'TOWN2'` 인 번들을 돌려줘야 하는데,
`LoadScript("TOWN2")` 는 §2.3 경로 3(이름 폴백)으로 가서 `TOWN2.json` 을 찾다 실패하고 `cm2Path == null` 이므로 **`null` 을 반환**한다.
→ `Town2MapScript`(83줄)는 **한 번도 실행된 적이 없는 코드**다. 나머지 3종(`TOWN1`/`GROUND1`/`DEN1`)이 §7.2 의 "지오메트리 없이 부착"
상태인 것과 달리, `TOWN2` 는 **부착 자체가 일어나지 않는** 별개 사례다(부록 G-2).

라이프사이클 훅: `onPrepare` → `onLoad(prevMap, fromX, fromY)` → (이벤트) → `onUnload`.
이벤트 훅 4종은 전부 `Future<bool>` 이며 "처리했다" 를 뜻한다(`map_script.dart:17`). 그러나 **디스패처가 이 반환값을 소비하지 않는다**(`tile_event_dispatcher.dart:129` 주석이 명시).

`HDMapScript` 의 플래그 헬퍼는 **본문이 비어 있는 스텁**이다:

```dart
// hadar2026_app/lib/application/scripting/map_script.dart:41
bool isFlagSet(int index) {
  // Requires implementation in GameModel / State
  return false;
}
void setFlag(int index) {
  // Requires implementation in GameModel / State
}
```

`Town1MapScript` 는 이 스텁을 오버라이드하지 않은 채 그대로 쓴다:

```dart
// hadar2026_app/lib/application/scripting/maps/town1_map_script.dart:76
if (isOn(45, 8)) {
  if (!isFlagSet(33)) {                       // ← 항상 true
    await talk("게임의 진행을 위해 이 안 쪽 감옥의 문을 열어 주겠소.");
    setFlag(33);                              // ← no-op
    game.map?.setTile(44, 14, 0);
  } else { ... }                              // ← 도달 불가
```

`HDNativeScriptRunner` 에는 제대로 동작하는 `isFlagSet`/`setFlag`(`native_script_runner.dart:91`, `:95`) 가 있지만 **맵 스크립트가 그것을 호출하지 않는다.** 결과: 네이티브 맵의 일회성/조건부 대사가 전부 무력화되어 매번 같은 첫 분기만 재생된다. → [BP-11 G-05](11_gap_analysis.md)

### 5.6 두 런타임이 공존하는 이유(현행 근거)

- cm2: 데이터라서 핫리로드가 되고, 원본 Hadar 스크립트를 옮기기 쉽다. 콘텐츠 작성자가 코드 없이 만질 수 있다.
- 네이티브 Dart: 타입이 있고 IDE 지원을 받는다. cm2 의 표현력(루프·함수·산술)이 부족한 로직을 담는다.
- 새 맵은 보통 둘 중 하나를 고르고, 3티어 체인이 공존을 가능하게 하는 이음매다.

### 5.7 cm2 언어의 한계는 "튜링 완전" 이 아니다 — 정확한 근거

cm2 를 "정적 검증 불가" 라고 말할 때 **튜링 완전성을 근거로 들면 틀린다.** `parser.dart` 에는 루프도 함수 정의도 없고(§5.1),
`ast.dart` 의 노드는 `CommandStatement` 와 `IfStatement` 둘뿐(`packages/cm2_script/lib/src/ast.dart:5`, `:14`)이다.
분기만 있고 반복이 없는 언어는 오히려 **정적 분석이 쉬운 쪽**이다.

실제 근거는 **언어 능력이 아니라 런타임 계약의 부재**다:

| # | 근거 | 위치 |
|---:|---|---|
| 1 | 미등록 함수가 `0` 을 반환해 조건이 조용히 오분기 | `cm2_script.dart:330`~`:336` |
| 2 | 등록 심볼도 범위 밖 인자를 무음 no-op 으로 삼킴 | `script_engine_adapter.dart:362`, `:369`, `:376`, `:383` |
| 3 | 맵 전환 시 전역 소실 — **단, 로드 실패 시에는 소실되지 않음**(§5.4) | `script_engine_adapter.dart:92`~`:103` |
| 4 | `.assign` 이 매 `run()` 재실행 | `cm2_script.dart:99` |
| 5 | 스키마·타입 선언이 없음(모든 인자가 문자열, `getVal` 이 런타임에 추론) | `cm2_script.dart:255` |

D-02(선언적 데이터 채택)는 위 5개만으로 충분히 정당화되며, "튜링 완전" 논거는 쓰지 않는다. 근거: 부록 E-3.

### 5.8 전투 · 마법 · 메뉴 · 선택 — 감사되지 않았던 유스케이스 4종

`application/` 의 1,406줄(battle 538 + menu_flows 544 + magic_system 280 + select 44)은 앞 절들이 스크립팅 관점에서만 스쳤다.
콘텐츠 런타임이 붙을 지점이므로 책임·상태·진입점을 정리한다.

| 대상 | 형태 | 상태 소유 | 진입점 | 콘텐츠 런타임과의 접점 |
|---|---|---|---|---|
| `HDBattle` | **싱글턴** (`battle.dart:17`~`:19`) | `enemies`, `playerCommands`, `_battleResult`, `isBattleActive`, `selectedEnemyIndex` | `init()` `registerEnemy(id)` `showEnemy()` `start(mode)` | D-05 `start_battle`, D-06 `defeat` 목표 |
| `HDMagicSystem` | **싱글턴 아님 — `static` 전용 클래스** (`magic_system.dart:8`) | 없음. 전부 인자·세션 조회 | `castSpell(player)`(`:9`) `useESP(player)`(`:106`) `castBattleSpellUI(...)`(`:183`) | D-05 `heal_party` |
| `HDMenuFlows` | 싱글턴 (상태 없음) | 없음 | `showMainMenu()`(`:33`) 외 10종 | D-16-1 "임무" 메뉴 항목 |
| `HDSelect` | 싱글턴 | `items`, `selectedIndex`, `isSelectionActive`, `_lastResult` | `init()` `add(text)` `run()` `result()` | D-07 `Choice` 가 대체할 대상 |

#### 5.8.1 `HDBattle` 턴 루프

`start(mode)`(`battle.dart:103`) 의 구조:

```
start(mode)
 ├ _modeAssault()            (:277) 플레이어별 명령 수집 → playerCommands[order] = [cmd, ?, target]
 │    └ showWindowMenu 6~7항목: 무기공격 / 한명마법 / 전체마법 / 특수마법 / 치료 / 초능력 (+order==0 이면 자동전투)
 ├ 라운드 루프
 │    ├ playerCommands 소비 → 공격/마법 실행 (Random 14곳, §9.6)
 │    └ 적 턴
 ├ 종료 판정                  (:222) !_playersAlive() → 0 / !_enemiesAlive() && result!=2 → 1
 └ gotoEndBattle()           (:236) 보상 · 레벨업 · 게임오버 분기
```

`playerCommands` 는 **이름 없는 `List<List<int>>`** 이다(`battle.dart:30`). 인덱스 의미(`[0]`=cmd, `[2]`=target)는
`:123`·`:124` 의 사용처에만 있고 상수도 주석도 없다.

**`_battleResult` 는 두 가지 이유로 신뢰할 수 없다.**

```dart
// hadar2026_app/lib/application/battle.dart:27
int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away
// :34~:41  init()
void init() {
  enemies.clear();
  playerCommands.clear();
  isBattleActive = false;
  _battleResult = 1;              // :38 — 다시 "승리"로
  ...
}
```

① 초기값이 `1`(Win)이고 `init()` 도 `1` 로 되돌린다. `init()` 은 **맵 전환마다** 호출된다(`game_session.dart:95`).
   `Battle::Result` 함수는 그대로 노출되므로(`script_engine_adapter.dart:543`), **전투를 한 번도 하지 않고 `Battle::Result()` 를 읽으면 항상 승리**다.
② 값 0/2 의 의미가 `const.cm2` 상수와 정반대다(§9.7).

→ "전투 미발생" 을 표현하는 상태가 없다. 근거: 부록 F-3 · B-2. 결함 등록은 [BP-11 G-24](11_gap_analysis.md).

#### 5.8.2 `HDMagicSystem` — 45종 중 실제 구현은 3종

`castSpell`(`magic_system.dart:9`)의 분기 실측:

| magicId 범위 | 분기 | 실제 효과 |
|---|---|---|
| 19~32 (치료) | `:66` | 대상 선택 후 **`magicId == 19` 만** `hp += level.magic * 5`(`:80`~`:85`). 20~32 는 SP 만 소모하고 메시지만 출력 |
| 33~39 (현상) | `:86` | **33**(`magicTorch += 10`, `:89`) · **34**(`levitation = 1`, `:92`) 만 구현. 35~39 는 SP 만 소모 |
| 그 외(1~18 공격) | `:95` | `"… 시전했다! (전투 외)"` 로그만. 효과 없음 |

즉 **필드에서 실제 상태를 바꾸는 마법은 19 · 33 · 34 세 개뿐**이다. SP 비용은 `(magicId >= 33) ? 10 : 5`(`:56`) 이분법.
`useESP`(`:106`)도 같은 구조이며 `party.canUseEsp` 를 추가로 본다(`:118`).

→ D-05 의 `heal_party(percent)` Effect 가 착지하려면 **치료 마법의 회복량 규칙 자체를 새로 정의**해야 한다(현재는 19번 하나의 하드코딩 식뿐).

#### 5.8.3 `HDMenuFlows` 메인 메뉴 — "임무" 항목이 들어갈 자리

```dart
// hadar2026_app/lib/application/menu_flows.dart:34  (showMainMenu, :33)
final choices = [
  "당신의 명령을 고르시오 ===>",   // :35  index 0 = 제목
  "일행의 상황을 본다",            // :36  → 1
  "개인의 상황을 본다",            // :37  → 2
  "일행의 건강 상태를 본다",       // :38  → 3
  "마법을 사용한다",               // :39  → 4
  "초능력을 사용한다",             // :40  → 5
  "여기서 쉰다",                   // :41  → 6
  "게임 선택 상황",                // :42  → 7
];                                 // :43
```

- 리스트 리터럴이며 **제목 1 + 항목 7**. 반환값은 1-based, 0 = 취소.
- 분기는 `switch (selected)` 의 `case 1`~`case 7` 로 **인덱스에 직접 결합**되어 있다 → 중간에 항목을 끼우면 아래가 전부 밀린다.
- 전체가 `beginNarrative()` / `finally endNarrative()` 로 감싸인 하나의 내러티브 사이클이다.
- 팝업 x 좌표만 레거시 값 `200` 을 넘긴다(`showWindowMenu(choices, x: 200)`).

D-16-1 이 요구하는 "메인 메뉴에 임무 항목 추가" 는 이 리터럴과 `switch` 를 함께 고치는 작업이다. 설계는 [BP-41](41_journal_ui_spec.md).

#### 5.8.4 `HDSelect` — cm2 의 선택지 3단계 절차

```dart
// hadar2026_app/lib/application/select.dart:13  init()  → HDHosts().ui.addLog('') 로 개행 1회 + 상태 리셋
// :23  add(text)   → 앞뒤 큰따옴표를 벗겨 items 에 push
// :31  run()       → showMenu(items, clearLogs: false) 결과를 _lastResult 에 보관
// :41  result()    → _lastResult
```

`items[0]` 이 제목이라는 규약은 `UiHost.showMenu` 와 동일하다. `clearLogs: false` 라서 **앞선 대사가 화면에 남은 채** 선택지가 붙는다.
전역 싱글턴이므로 **중첩 선택이 불가능**하다 — 선택지 안에서 또 선택지를 열면 `items` 가 덮어써진다.

### 5.9 오버레이 윈도우 — 도메인 타입과 완료 신호

`HDWindowManager`(`application/window_manager.dart:14`) 는 **스택만** 갖는다: `addWindow` / `removeWindow` / `clear` / `hideTopWindow`.
키 라우팅은 `presentation/input/window_key_dispatcher.dart` 로 분리되어 있어(§8.3) application 이 presentation 을 부르지 않는다.

| 도메인 타입 | 줄 | 완료 신호 | 키 처리 |
|---|---:|---|---|
| `HDWindow`(추상, `domain/window/game_window.dart:3`) | 34 | — | — |
| `HDSelectionWindow`(`selection_window_data.dart:5`) | 65 | `Completer<int> _completer`(`:9`) → `Future<int> get result`(`:14`) | ↑↓/WS · Enter/Space/E · Esc/Q |
| `HDMessageWindow`(`message_window_data.dart:14`) | 39 | `Completer<void>? _closeCompleter`(`:16`) → `waitForClose()`(`:27`) | Space/Enter/E/Esc/Q → `close()` |
| `HDMagicSelectionWindow`(`magic_window_data.dart`) | 126 | 내부 completer + `HDSelectionMode`(category/magic 2단) | ↑↓/WS · 확인 · 취소 |

`showWindowMenu`/`showMessageWindow` 는 `try/finally` 로 **반드시 스택에서 제거**한다(`flutter_ui_host.dart:176`~`:180`, `:189`~`:191`).
→ 헤드리스 호스트는 이 `Completer` 들을 즉시 완료시키는 방식으로 대체할 수 있다.

---

## 6. 상태 저장의 현재 모습

### 6.1 플래그/변수의 3중 분열

| # | 저장소 | 타입 | 접근 경로 | 맵 전환 생존 | 세이브 v1 |
|---|---|---|---|:--:|:--:|
| 1 | `HDGameOption.flags` / `.variables` | `List<bool>(256)` / `List<int>(256)` | cm2 `Flag::Set/Reset/IsSet`, `Variable::Set/Add/Get` | ✅ | ✅ |
| 2 | `HDNativeScriptRunner.flags` / `.variables` | `Map<int,bool>` / `Map<int,int>` | 네이티브 스크립트용(단 §5.5 때문에 실제 호출 0건) | ✅ | ❌ |
| 3 | `HDScriptEngine.variables` (= `ScriptEngine.variables`) | `Map<String,dynamic>` | cm2 `variable(x)` / `x.assign(v)` / `x.add(v)` | ❌ (`clearRuntimeState`) | ❌ |

```dart
// hadar2026_app/lib/domain/game_option.dart:9
List<bool> flags = List.filled(HDConfig.maxFlags, false);      // maxFlags = 256
List<int> variables = List.filled(HDConfig.maxVariables, 0);   // maxVariables = 256
```

**세 저장소 전부 이름 없는 정수 인덱스다.** 의미는 `assets/const.cm2` 나 스크립트 주석에만 존재하고, 코드에서 조회할 방법이 없다. 예: `Town1MapScript` 의 33 / 34 / 41 은 어디에도 문서화되어 있지 않다.

### 6.2 세이브 v1 페이로드

```dart
// hadar2026_app/lib/application/save_manager.dart:18 (saveGame)
final Map<String, dynamic> data = {
  'version': 1,                        // :19
  'party': session.party.toJson(),
  'gameSystem': session.gameSystem.toJson(),
  'gameOption': session.gameOption.toJson(),
  'map': session.map?.toJson(),
};
```

`SharedPreferences` 키 `hadar_save_<index>` 에 JSON 문자열로 저장한다.

| 담기는 것 | 세부 |
|---|---|
| `party` | 좌표(x,y,xPrev,yPrev,faced), maxEnemy, encounter, food, gold, 버프 8종, `players[6]` 전체 |
| `gameSystem` | year/month/day/hour/min/sec |
| `gameOption` | `flags[256]`, `variables[256]`, `mapType`, `scriptFile`(경로 문자열) |
| `map` | width/height/`data[]`(MapUnit 전량 스냅샷)/handicapData/tileOverrides |

| **빠지는 것** | 왜 문제인가 |
|---|---|
| **`map.events`** | `MapModel.toJson()` 에 `'events'` 키가 아예 없다(아래 6.2.1) → 로드 후 **JSON 대사 티어 전체가 무력화** |
| `HDNativeScriptRunner.flags` / `.variables` | 네이티브 맵의 진행도가 통째로 소실 |
| `HDScriptEngine.variables` / `_contexts` | cm2 지역 상태 소실(맵 전환에서도 이미 소실되므로 일관은 함) |
| **현재 맵 이름** | 맵 데이터 스냅샷만 저장 → 이름을 잃어 `mapScriptFactory` / `MapInfos` 재바인딩 불가. §7.11 의 조명 규칙도 함께 죽는다 |
| `currentMapCm2Path` | 로드 후 타일 디스패치가 어느 티어로 갈지가 달라짐 |
| `HDBattle` 상태 | 전투 중 저장은 시나리오상 없으므로 실해는 미확인 |
| 콘솔 스크롤백 | 의도적 제외로 보임(미확인) |

#### 6.2.1 `MapModel.toJson()` 이 `events` 를 저장하지 않는다

```dart
// hadar2026_app/lib/domain/map/map_model.dart:50
Map<String, dynamic> toJson() {
  return {
    'width': width,
    'height': height,
    'data': data.map((u) => u.toJson()).toList(),
    'handicapData': handicapData.toList(),
    'tileOverrides': tileOverrides.map((k, v) => MapEntry(k.toString(), v)),
  };                                   // ← 'events' 없음
}
```

`MapModel.fromJson`(`:60`~`:81`) 도 `events` 를 복원하지 않는다. 따라서 세이브를 로드한 순간 `map.events` 는 **빈 리스트**가 되고,
`_emitJsonDialog` 가 `map.events` 를 순회하므로(§4.4) **3티어 중 JSON 대사 티어가 통째로 사망**한다.

| 맵 | 이벤트 | 로드 후 |
|---|---:|---|
| Map002 (`LORE_EP`) | 18 | 0 |
| Map003 (`MAP003`) | 3 | 0 |
| Map010 (`Prolog_B1`) | 8 | 0 |
| Map011 (`Prolog_B2`) | 9 | 0 |

주의: `ixEvent` 는 `MapUnit.toJson()` 에 포함되므로 **타일 액션(talk/sign/enter)은 살아남는다.**
즉 NPC 를 향해 확인 키를 눌러도 반응만 있고 **대사가 비어 있는** 상태가 된다.
근거: 부록 C-1. 결함 등록은 [BP-11 G-04](11_gap_analysis.md).

#### 6.2.2 저장 크기가 웹 저장 한계에 근접한다

`MapUnit.toJson()`(`domain/map/map_unit.dart:26`) 은 칸마다 `{"ixTile":N,"ixObj0":N,"ixObj1":N,"shadow":N,"ixEvent":N}` 을 만든다 — 최소 **약 57바이트/칸**.
100×100 맵 = 10,000칸 → **약 570KB**, 슬롯 4개면 2MB 이상. 브라우저 `localStorage` 는 통상 5MB 이고 UTF-16 저장이라 실질 여유는 그 절반이다.
→ 맵 전체 스냅샷 대신 **원본 대비 델타만 저장**하는 방식이 선택이 아니라 필수. 근거: 부록 C-3. 설계는 [BP-25](25_world_state_and_save.md).

### 6.3 로드 순서와 부작용

```
1. party.fromJson         (좌표를 savedX/savedY/savedFaced 로 별도 보관)
2. gameSystem.fromJson
3. gameOption.scriptFile 로 HDScriptEngine.loadScript()   ← 엔진 전역 초기화
4. flags/variables/mapType/scriptFile 덮어쓰기            ← 스크립트 기본 대입을 이김
5. map = MapModel.fromJson → setNewMap()                  ← mapVersion++
6. party.setPosition(savedX, savedY); faced 복원          ← Map::SetStartPos 를 이김
7. mapVersion++ ; HDHosts().ui.refresh()
```

`loadGame` 은 `run()` 을 부르지 않는다(`save_manager.dart:79` 주석). 즉 **복원된 맵에서 FLAG_MAP 패스가 재실행되지 않는다** — 맵 로드시 스크립트가 하던 초기 세팅(예: `Map::SetType`, 타일 치환)은 재적용되지 않고, 저장 시점의 `map.data` 스냅샷과 `gameOption.mapType` 에 의존한다.

#### 6.3.1 로드 경로가 네이티브 스크립트를 붙이지 않는다

5단계는 `setNewMap` 을 **직접** 호출한다:

```dart
// hadar2026_app/lib/application/save_manager.dart:84
if (data['map'] != null) {
  final loadedMap = MapModel.fromJson(data['map']);
  session.setNewMap(loadedMap);        // :86 — loadMapFromFile 을 거치지 않음
}
```

네이티브 스크립트 스왑(`onUnload` → `mapScriptFactory` → `onPrepare`/`onLoad`)과 `currentMapCm2Path` 갱신은
**`HDGameSession.loadMapFromFile` 안에만** 있다(`game_session.dart:117`~`:128`, `:100`).
→ 세이브 로드 경로는 그 코드를 타지 않으므로 `currentMapScript` 가 **직전 실행의 것으로 남거나 null 인 채**로 유지되고,
`currentMapCm2Path` 도 저장 시점 값이 아니라 **직전 값 그대로**다. 근거: 부록 C-2.

#### 6.3.2 `GameReloadException` 제어 흐름 — 4지점

성공 로드는 예외로 실행 루프를 되감는다. 이 예외는 **정상 종료 신호**이므로 실패로 오분류하면 안 된다(헤드리스 하네스에 직결).

```dart
// hadar2026_app/lib/application/game_reload_exception.dart:9
class GameReloadException implements Exception { ... }
```

| 역할 | 위치 | 코드 | 의미 |
|---|---|---|---|
| **throw ①** | `application/menu_flows.dart:519` | `if (await selectLoadMenu()) { throw GameReloadException(); }` | `processGameOver(1)` — 필드 전멸 후 로드 성공 |
| **throw ②** | `application/menu_flows.dart:536` | 같은 형태 | `processGameOver(2)` — 전투 패배 후 로드 성공 |
| **rethrow** | `application/battle.dart:229` | `} on GameReloadException { isBattleActive = false; notifyListeners(); rethrow; }` | 전투 루프가 자기 상태만 정리하고 통과시킴 |
| **catch(종점)** | `application/scripting/script_engine_adapter.dart:124` | `if (e is GameReloadException) { return; }` (`run`의 `onError`) | 조용히 실행 중단. **로그도 남기지 않음** |

흐름: `processGameOver → throw → (battle 이 정리 후 rethrow) → script engine 이 조용히 종료`.
throw 지점이 둘 다 `menu_flows.dart` 안이므로, 헤드리스 `SimDriver` 는 이 두 지점을 **"세이브 로드로 인한 정상 재시작"** 으로 인식해야 한다([BP-34](34_headless_sim_and_solver.md)).

### 6.4 세이브-콘텐츠 호환 개념

`version: 1` 필드는 저장만 되고 **로드 시 읽지 않는다**(`save_manager.dart` 전체에 `data['version']` 참조 0건). 마이그레이션 규칙도 없다.

---

## 7. 데이터 자산 현황

### 7.1 맵 파일 실측 (`hadar2026_app/assets/maps/`)

| 파일 | 크기(B) | w×h | events | code=401 대사 줄 | displayName | MapInfos 로 도달 가능? |
|---|---:|---|---:|---:|---|---|
| `Map001.json` | 753 | 4×4 | 0 | 0 | `맵이름` | ✅ `Test`(id 1) |
| `Map002.json` | 54,156 | 50×50 | **18** | **22** | `맵` | ✅ `LORE_EP`(id 2) — **부팅 맵** |
| `Map003.json` | 9,665 | 21×21 | 3 | 3 | `작은맵` | ✅ `MAP003`(id 3) |
| `Map010.json` | 86,785 | 65×82 | 8 | 6 | `emj_789654.txt` | ✅ `Prolog_B1`(id 10) |
| `Map011.json` | 48,016 | 53×52 | 9 | 0 | `emj_85371_cave.txt` | ✅ `Prolog_B2`(id 11) |
| `Map013.json` | 161,320 | 100×100 | 0 | 0 | `로어 대륙` | ✅ `LoreContinent`(id 13) |
| `Map014.json` | 156,484 | 100×100 | 0 | 0 | `로어성` | ✅ `CastleLore`(id 14) |
| `Map015.json` | 90,579 | 75×75 | 0 | 0 | `라스트디치` | ✅ `LastDitch`(id 15) |
| `TOWN1.json` | 156,484 | 100×100 | 0 | 0 | `로어성` | ❌ **등록되어 있어서** 도달 불가 (§7.2) |
| `GROUND1.json` | 161,320 | 100×100 | 0 | 0 | `로어 대륙` | ❌ |
| `DEN1.json` | 40,495 | 50×50 | 0 | 0 | `메너스` | ❌ |
| `DEN2.json` | 44,140 | 53×53 | 0 | 0 | `53x53` | ❌ |
| `ORIGIN.json` | 156,484 | 100×100 | 0 | 0 | `로어성` | ✅ **이름 폴백으로 로드됨** (MapInfos 미등록 → §2.3 경로 3, 레거시 티어) |

**중복 실측(md5)**: `TOWN1.json` = `ORIGIN.json` = `Map014.json` (`ff07223d9cc29f85e4a318d1bb75ce37`), `GROUND1.json` = `Map013.json` (`90bd99e5bf8bfab32d5f1f099a81a06c`). 즉 같은 내용이 3중/2중으로 존재한다.

**전체 이벤트 총계: 38개, 대사 줄 총계: 31줄.** 게임 전체의 정적 대사 자산이 이것뿐이다.

### 7.2 MapInfos 등록 이름과 실제 파일의 불일치 — 그리고 "등록이 손해" 라는 역설

`MapInfos.json` 의 **어떤 엔트리에도 `cm2`/`json` 필드가 없다**(전문 실측). 코드는 지원하지만 데이터가 쓰지 않는다. 따라서 등록된 이름은 전부 `Map{id:03d}` 규칙을 탄다.

```dart
// hadar2026_app/lib/application/map_navigation.dart:41
final int id = info['id'];
final idStr = id.toString().padLeft(3, '0');
resolvedJsonName = 'Map$idStr.json';    // ← :29 의 이름 폴백을 덮어씀
cm2Path = 'Map$idStr.cm2';              // ← 무조건 설정 (부록 A-1)
if (info['json'] is String) overrideJsonName = info['json'];
if (info['cm2'] is String) cm2Path = info['cm2'];
```

#### 7.2.1 해석 결과 전수표 (5열 = 3티어 판정 입력 + 관측 증상)

`json` = 해석된 JSON 파일 존재 여부 · `cm2` = 해석된 cm2 파일 존재 여부 · `native` = `mapScriptFactory` 등록 여부.
"선택 티어" 는 §4.4 의 우선순위(native > cm2 > 레거시)를 그대로 적용한 결과다.

| MapInfos 이름 | id | 해석 JSON | json | 해석 cm2 | cm2 | native | 선택 티어 | 관측 증상 |
|---|---:|---|:--:|---|:--:|:--:|---|---|
| `Test` | 1 | `Map001.json` | ✅ | `Map001.cm2` | ❌ | ✗ | cm2(잔존) | 맵은 4×4 로 바뀌나 스크립트는 **직전 맵 것이 실행**, 미처리 시 JSON(0건) 폴백 |
| `LORE_EP` | 2 | `Map002.json` | ✅ | `Map002.cm2` | ✅ | ✗ | **cm2(정상)** | 정상. 부팅 맵 |
| `MAP003` | 3 | `Map003.json` | ✅ | `Map003.cm2` | ✅ | ✗ | **cm2(정상)** | 정상 |
| `TOWN1` | 4 | `Map004.json` | ❌ | `Map004.cm2` | ❌ | ✅ | native | **맵이 안 바뀜** + `Town1MapScript` 가 직전 맵 좌표에 부착 |
| `GROUND1` | 5 | `Map005.json` | ❌ | `Map005.cm2` | ❌ | ✅ | native | 동일 |
| `DEN1` | 6 | `Map006.json` | ❌ | `Map006.cm2` | ❌ | ✅ | native | 동일 |
| `DEN2` | 7 | `Map007.json` | ❌ | `Map007.cm2` | ❌ | ✗ | cm2(잔존) | 맵도 스크립트도 안 바뀜. `LoadScript` 는 `true` 반환 |
| `Template_TOWN` | 8 | `Map008.json` | ❌ | `Map008.cm2` | ❌ | ✗ | cm2(잔존) | 동일 |
| `Prolog` | 9 | `Map009.json` | ❌ | `Map009.cm2` | ❌ | ✗ | cm2(잔존) | 동일 |
| `Prolog_B1` | 10 | `Map010.json` | ✅ | `Map010.cm2` | ❌ | ✗ | cm2(잔존) | 맵은 바뀌나 **직전 맵 cm2 실행** → 미처리 시 JSON(8건) 폴백 |
| `Prolog_B2` | 11 | `Map011.json` | ✅ | `Map011.cm2` | ❌ | ✗ | cm2(잔존) | 동일(JSON 9건) |
| `Template_DUNGEON` | 12 | `Map012.json` | ❌ | `Map012.cm2` | ❌ | ✗ | cm2(잔존) | 맵도 스크립트도 안 바뀜 |
| `LoreContinent` | 13 | `Map013.json` | ✅ | `Map013.cm2` | ❌ | ✗ | cm2(잔존) | 맵은 바뀌나 직전 cm2 실행, JSON 0건 |
| `CastleLore` | 14 | `Map014.json` | ✅ | `Map014.cm2` | ❌ | ✗ | cm2(잔존) | 동일 |
| `LastDitch` | 15 | `Map015.json` | ✅ | `Map015.cm2` | ❌ | ✗ | cm2(잔존) | 동일 |
| *(미등록)* `ORIGIN` | — | `ORIGIN.json`(폴백) | ✅ | — | — | ✗ | **레거시(티어 3)** | **정상 로드.** `cm2Path == null` 이라 JSON + 전역 cm2 체인 |

집계: **JSON 이 실제로 로드되는 등록 이름 9개 / 로드 실패 7개**(`Map004`·`005`·`006`·`007`·`008`·`009`·`012`).
**페어 cm2 가 실제로 존재하는 것은 2개**(`LORE_EP`·`MAP003`)뿐이고, 나머지 **13개는 §5.4 의 잔존 실행 상태**다.

> "cm2(잔존)" 이 뜻하는 것: `currentMapCm2Path` 는 non-null 이라 티어 2 가 선택되는데, `loadScript` 가 실패해
> 엔진에는 **직전 맵의 스크립트가 그대로** 있다. 따라서 새 맵의 좌표를 직전 맵의 `On(x,y)` 블록이 판정한다.
> 방문 순서에 따라 결과가 달라지므로 **골든 회귀를 뜰 수 없는 상태**다(부록 A-2).

#### 7.2.2 로드 실패가 실패로 보고되지 않는다

`loadByName` 은 JSON 로드가 실패해도 `null` 을 반환하지 않는다 — `cm2Path` 가 항상 non-null 이기 때문이다:

```dart
// hadar2026_app/lib/application/map_navigation.dart:60
} catch (e) {
  // JSON-less is allowed only if a cm2 script is paired. Otherwise
  // there's no map at all.
  if (cm2Path == null) {
    errorMessage = "Failed to load map: $e";
    return null;
  }
  print("HDMapNavigation: cm2-only map $searchName (no JSON: $e)");
}
return MapBundle(mapName: searchName, json: json, cm2Path: cm2Path);
```

상위에서는 `json == null` 이면 `setNewMap` 을 건너뛰지만 **네이티브 스크립트 부착은 무조건 실행된다**:

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

return true;                        // ← :130. 항상 "성공"
```

→ `LoadScript("TOWN1")` 은 **`true`(성공)를 반환하면서** 실제로는 ① 맵 지오메트리 미변경 ② 직전 맵 cm2 잔존
③ `Town1MapScript` 부착 — 3중 혼합 상태를 만든다. `Town1MapScript.isOn(45, 8)` 은 **직전 맵의 (45,8)** 을 판정한다.
근거: 부록 D-2 · F-2. 결함 등록은 [BP-11 G-22 / G-31](11_gap_analysis.md).

#### 7.2.3 역설: **인덱스에 등록하는 행위가 맵을 죽인다**

`TOWN1`/`GROUND1`/`DEN1`/`DEN2` 는 **동명 파일 `TOWN1.json` 등이 실제로 존재**한다(§7.1).
이 이름들이 `MapInfos.json` 에 **등록되어 있지 않았다면** `map_navigation.dart:29` 의 폴백이 살아남아 정상 로드되었을 것이다.

이것은 추론이 아니라 **관측된 사실**이다 — `ORIGIN` 이 정확히 그 상태로 지금 동작한다(부록 F-4).

| 이름 | MapInfos 등록 | 동명 `.json` | 결과 |
|---|:--:|:--:|---|
| `ORIGIN` | ❌ | ✅ | **로드됨** |
| `TOWN1` | ✅ | ✅ | 로드 실패 |
| `GROUND1` | ✅ | ✅ | 로드 실패 |
| `DEN1` | ✅ | ✅ | 로드 실패 |
| `DEN2` | ✅ | ✅ | 로드 실패 |

따라서 이 결함의 수리는 **두 갈래**이며, 값이 다르다:

| 선택지 | 방법 | 비용 | 부수 효과 |
|---|---|---|---|
| ① 명시 참조 | 7개 엔트리에 `json`(+`cm2`) 필드 추가 | 엔트리 7개 편집 | `cm2Path` 는 여전히 non-null → §5.4 잔존 문제는 **남는다** |
| ② **등록 해제** | `TOWN1`/`GROUND1`/`DEN1`/`DEN2` 4개 엔트리를 MapInfos 에서 제거 | 엔트리 4개 삭제 | 이름 폴백이 살아나고 **`cm2Path == null` 이 되어 §5.4 잔존 문제까지 동시 회피** |

②는 파일 이름과 논리 이름이 이미 같은 4개에 정확히 들어맞는다. 나머지 3개(`Template_TOWN`/`Prolog`/`Template_DUNGEON`)는
동명 파일이 없으므로 ① 이나 "엔트리 삭제 + 맵 신규 작성" 이 필요하다. 선택은 [BP-26](26_entity_registry_and_anchors.md) / Q-10-01.

한편 `mapScriptFactory` 의 `TOWN2` 는 **MapInfos 에 이름조차 없고 `TOWN2.json` 도 없다** → `Town2MapScript` 는 어떤 경로로도 도달 불가.

### 7.3 cm2 자산

| 파일 | 줄 | 도달 경로 |
|---|---:|---|
| `startup.cm2` | 6 | `HDConfig.startupScript` 로 부팅 시 로드 |
| `const.cm2` | 68 | `include("const.cm2")` |
| `Map002.cm2` | 60 | `LORE_EP` 페어 cm2 |
| `Map003.cm2` | 18 | `MAP003` 페어 cm2 |
| `L1_ep1d0.cm2` | 585 | `startup.cm2` 주석 처리 — 현재 도달 불가 |
| `L1_ep1d1..d5_1.cm2` | 352/369/244/534/193/164 | `LoadScript` 로 서로 참조(미확인) |
| `lore_ep1.cm2` | 558 | 미확인 |
| `town1.cm2` / `town2.cm2` / `ground1.cm2` / `menace.cm2` | 120/547/35/93 | `startup.cm2` 주석 또는 상호 `LoadScript` |
| `flag4ep1.cm2` | 110 | `include` 로 추정(미확인) |

총 4,056줄. 이 중 부팅 경로에서 실제로 실행되는 것은 `startup.cm2` + `const.cm2` + `Map002.cm2` = 134줄뿐이다.

### 7.4 `books.json` — 미사용 아이템 데이터

`assets/maps/books.json`(1,506B) 에 `weapon` 배열이 있고, 각 항목은 `{id, name, type, power, etc_data, etc_description:{brief:[{image,text}]}}` 구조다(예: `맨손`/NONE/1.0, `단도`/STAB/5.0, `단검`/WIELD/15.0, `단창`/STAB/20.0).

**`grep -rn "books" hadar2026_app/lib` 결과 0건.** 앱 코드 어디서도 로드하지 않는다. `pubspec.yaml` 의 assets 목록에도 개별 지정이 없다(디렉토리 통째 지정 여부 미확인).

한편 플레이어의 무기/방패/갑옷은 **정수 ID 1개씩**이고 이름은 하드코딩 플레이스홀더다:

```dart
// hadar2026_app/lib/domain/party/player.dart:91
String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";
String getShieldName() => shield == 0 ? "없음" : "방패$shield";
String getArmorName()  => armor  == 0 ? "평상복" : "갑옷$armor";
```

이 문자열이 전투 로그(`battle.dart:453`)와 캐릭터 상태 화면(`menu_flows.dart:275`)에 그대로 노출된다.

### 7.5 적 데이터

`lib/domain/battle/enemy_data.dart` 의 `const List<HDEnemyData> enemyTable` — **실측 75종(id 0~74)**.

> ⚠ **두 숫자를 구분할 것.** 테이블 엔트리는 **75개**(id 0~74, `grep -c "HDEnemyData(id:"` = 75)이지만,
> `registerEnemy` 의 `<= 0` 가드 때문에 **콘텐츠에서 참조 가능한 것은 74종(id 1~74)** 이다.
> `_meta/GROUND_TRUTH.md` §10 의 "76종" 은 폐기되었고, 부록 B-1 이 **"BP-21/22/23/42 는 74종(id 1~74) 기준"** 을
> 규범으로 지시한다. 본 기획서의 후속 장은 **74종**을 기준으로 삼는다.

레벨 분포: Lv1 4종 → Lv2 4 → Lv3 4 → Lv4 4 → Lv5 4 → Lv6 4 → Lv7 4 → Lv8 4 → Lv9 4 → Lv10 4 → Lv11 3 → Lv12 3 → Lv13 3 → Lv14 3 → Lv15 3 → Lv16 2 → Lv17 2 → Lv18 2 → Lv19 2 → Lv20 2 → Lv21~30 각 1.
필드: `strength, mentality, endurance, resistance, agility, accuracy[2], ac, special, castLevel, specialCastLevel, level`. 보상 계산식은 코드에 있다:

```dart
// hadar2026_app/lib/application/battle.dart:243 (gotoEndBattle, Win 분기)
int totExp = enemies.fold(0, (xp, e) {
  int plus = e.data.id + 1;
  plus = (plus * plus * plus) ~/ 8;      // (id+1)^3 / 8
  return xp + max(1, plus);
});
// :261~264
_party.gold += enemies.fold(0, (g, e) => g + e.level * 5);   // "Add dummy gold" 주석
```

주의: `registerEnemy` 가 `enemyTableId <= 0` 을 거부하므로(`battle.dart:43` 메서드 / `:44` 가드) **id 0(`Orc`) 은 cm2 로 소환할 수 없다.**

### 7.6 경험치/레벨 테이블

21단계 정수 배열이 `player.dart` 안에 **두 번 하드코딩**되어 있다.

| 위치 | 길이 | 값 |
|---|---:|---|
| `player.dart:167` (`checkLevelUp`) | 21 | 0, 0, 1500, 6000, 20000, 50000, 150000, 250000, 500000, 800000, 1050000, 1320000, 1620000, 1950000, 2310000, 2700000, 3120000, 3570000, 4050000, 4560000, 5100000 |
| `player.dart:250` (`assignFromEnemyData`) | **20** | 위와 동일하되 마지막 `5100000` 없음 |

레벨업 성장식(`player.dart:193`~`:206`): `strength += 1 + strength~/10`, `endurance += 2`, `agility += 1`, `accuracy.physical += 1`, `mentality`/`concentration` 은 0 초과일 때만 +1. 이후 `maxHp = endurance * level.physical`, `maxSp = mentality * level.magic`, `maxEsp = concentration * level.esp` 로 재계산하고 HP/SP/ESP 를 만땅으로 회복시킨다.

### 7.7 마법/초능력 카탈로그

`lib/domain/magic/magic.dart:11` — 45종, 4구간.

| 구간 | index | 개수 | 예 |
|---|---|---:|---|
| 공격 | 1~18 | 18 | 마법 화살 / 직격 뇌전 / 탈 초인화 |
| 치료 | 19~32 | 14 | 한명 부활 / 모두 복합 치료 |
| 현상 | 33~39 | 7 | 마법의 횃불 / 물위를 걸음 / 공간 이동 |
| 초능력 | 40~45 | 6 | 식량 제조 / 투시 / 천리안 / 염력 |

SP 소모는 index 로만 갈린다: `spCost = (magicId >= 33) ? 10 : 5` (`magic_system.dart:56`, `castSpell` 안). 마법별 개별 밸런스 데이터는 없다.

### 7.8 파티 초기값

```dart
// hadar2026_app/lib/domain/party/party.dart:13
class PartyInventory {
  int food = 100;
  int gold = 500;
}
```

`players` 는 6칸 고정 배열이며 0번 `슴갈`(에스퍼, class 0), 1번 `유리`(초능력자, class 2, 여성)만 채워지고 2~5 는 빈 슬롯이다(`party.dart:81`~`:133`). 클래스는 0 에스퍼 / 1 싸이보그 / 2 초능력자.
`maxEnemy = 3`, `encounter = 3`.

**인벤토리는 `food`/`gold` 정수 두 개가 전부다. 아이템 목록·소지품 개념이 존재하지 않는다.**

### 7.9 맵 에디터 자산 규약 (`tools/mapEditor`)

RPG Maker MV 6레이어를 그대로 쓴다. 게임 로더의 읽는 순서는 `map_loader.dart:40`~`:44`:

| z | 에디터 이름 | 게임 필드 | 의미 |
|---|---|---|---|
| 0 | ground | `ixTile` | A5 지면. 저장값은 `1536 + a5index`, 로더가 `-0x600` 보정 |
| 1 | ground2 | (읽지 않음) | 미사용 |
| 2 | objLower | `ixObj0` | 장식(통행 판정 없음) |
| 3 | objUpper | `ixObj1` | **통행 판정에 쓰임** |
| 4 | shadow | `shadow` | 사분면 비트 0~15 (0 항상 밝음 / 15 야간 완전 어둠) |
| 5 | region | `ixEvent` | 게임이 이벤트 타입 비트로 읽음 |

에디터 서버는 `GET /api/ai` 로 가이드 전문을 주고, `maps` CRUD / `region` / `passability` / `validate` / `preview.png` / 배치 `edit` / 이벤트 CRUD / `palette` / `tile.png` 를 제공한다(`tools/mapEditor/server/ai_api.ts:480`~). `POST /api/ai/maps` 에 `registerAs` 를 주면 **MapInfos 에 `json` 필드를 명시한 엔트리를 추가**한다(`ai_api.ts:570` 부근) — 즉 새 맵은 §7.2 의 함정을 피한다.

에러 규약은 `{error, hint}` 이며, 이는 콘텐츠 서버가 따라야 할 선례다(D-12).

### 7.10 자산 번들 선언

```yaml
# hadar2026_app/pubspec.yaml:65
  assets:
    - assets/
    - assets/images/
    - assets/maps/
    - assets/fonts/
```

Flutter 의 디렉토리 선언은 **재귀적이지 않다** — 각 줄은 그 디렉토리 **바로 아래** 파일만 포함한다. 따라서 D-03 이 정한 `assets/content/{world,actors,items,quests,dialogue,anchors,strings,build}/` 를 웹 빌드에서 읽으려면 **하위 디렉토리마다 한 줄씩 추가**해야 한다. 데스크톱에서는 `HDBundleAssetSource` 의 파일 우선 경로(§1.3) 덕분에 선언 없이도 읽히므로, **"데스크톱에서는 되는데 웹에서만 안 되는" 함정**이 구조적으로 존재한다.

또한 `assets/` 한 줄이 `assets/*.cm2` 17개와 `startup.cm2` 를 전부 커버하므로, cm2 파일을 추가하면 매니페스트 수정 없이 번들에 들어간다.
근거: 부록 A-4.

### 7.11 조명·시야 파이프라인 — shadow 레이어를 실제로 소비하는 코드

§7.9 의 `shadow`(z4, 사분면 비트 0~15) 레이어는 **읽기만 하고 끝나는 데이터가 아니다.** 소비 경로는 domain 규칙 → presentation 렌더러다.

```
MapUnit.shadow (z4, 0~15)
        │
        ▼
HDWorldMap._renderShadow(canvas, x, y, shadowVal)      presentation/panels/world_map_renderer.dart:164
        ├─ mapName  = HDNativeScriptRunner().currentMapScript?.mapName ?? ""   :168~:169   ⚠ 아래 참조
        ├─ sightRange = HDSightCalculator.sightRangeFor(gameSystem, party, mapName)   :170
        │        └─ domain/lighting/sight_calculator.dart:15
        ├─ (sightRange >= 5 이면 즉시 return — 낮에는 그림자 계산 자체를 건너뜀)   :175
        ├─ pX/pY = 스프라이트 실좌표 기반 보간 (이동 중 선반영)   :182~:188
        ├─ inMoonlight = HDSightCalculator.isInMoonlight(...)      :191  (domain :59)
        ├─ lightBit    = HDSightCalculator.lightBitFor(...)        :196  (domain :82)
        └─ ix = ((shadowVal ^ 15) | lightBit) ^ 15  →  B 타일 240+ix 를 덧그림   :203~:210
```

**domain 쪽 규칙(`HDSightCalculator`, 순수 static 함수 3개)**

| 함수 | 규칙 |
|---|---|
| `sightRangeFor`(`:15`) | `time = hour*100 + min`. `<600`→1, `<620`→2, `<640`→3, `<700`→4, `<1800`→**5**, `<1820`→4, `<1840`→3, `<1900`→2, else 1 (`:20`~`:41`). 그 뒤 `mapName` 에 `DEN` 이 들어가면 **무조건 1**(`:43`~`:44`). 어두울 때 `magicTorch` 1~2 면 최소 2, 3 이상이면 최소 3(`:47`~`:52`) |
| `isInMoonlight`(`:59`) | `(day ~/ 12)` 가 10~20 이면 달빛. `DEN` 이면 false, `TOWN`/`CASTLE` 이면 강제 true(`:64`~`:70`). 어두울 때 `magicTorch > 4` 면 true(`:75`) |
| `lightBitFor`(`:82`) | `sightRange >= 5` 면 15(완전 밝음). 아니면 타일을 2×2 로 쪼개 반경 `2*sightRange + 0.3` 안에 드는 서브셀마다 비트를 세운다(`:91`~`:106`) |

**⚠ 발견: `mapName` 이 실제 플레이 맵에서 항상 빈 문자열이다.**

```dart
// hadar2026_app/lib/presentation/panels/world_map_renderer.dart:168
final String mapName =
    HDNativeScriptRunner().currentMapScript?.mapName ?? "";
```

맵 이름의 출처가 `MapModel` 도 `MapBundle` 도 아니라 **네이티브 맵 스크립트 인스턴스**다. 그런데 §7.2 에 따르면:

| 맵 | `currentMapScript` | 렌더러가 보는 `mapName` | 결과 |
|---|---|---|---|
| `LORE_EP`(부팅 맵), `MAP003`, `Prolog_B1/B2`, `LoreContinent`, `CastleLore`, `LastDitch`, `Test`, `ORIGIN` | `null` (팩토리 미등록) | `""` | `DEN`/`TOWN`/`CASTLE` 판정이 **전부 false** → 지형별 조명 규칙이 한 번도 발동하지 않음. 시야는 **시각에만** 의존 |
| `TOWN1`/`GROUND1`/`DEN1` | 부착됨 | `'TOWN1'`/`'GROUND1'`/`'DEN1'` | 이름은 맞지만 **지오메트리는 직전 맵의 것**(§7.2.2) → 조명이 다른 맵의 타일에 적용됨 |
| `TOWN2` | 도달 불가(§5.5) | — | — |

즉 **`CastleLore`(displayName `로어성`)에서도 `isTown` 이 false** 다 — 이름이 `""` 이기 때문이다.
"지역 정체성이 렌더링 규칙에 실제로 쓰이는데, 그 정체성의 출처가 스크립트 등록 여부라는 무관한 조건에 묶여 있다" 는 것이 요점이며,
§6.2 의 "세이브가 현재 맵 이름을 저장하지 않는다" 와 같은 뿌리다. 결함 등록은 [BP-11 G-15 / G-22](11_gap_analysis.md).

→ D-05 의 `time_of_day`(day/night) op 은 이 `sightRangeFor` 의 시각 경계(600 / 1800)와 **경계값을 공유해야** 일관된다([BP-27](27_runtime_engine.md), 태스크 **T-110**).

### 7.12 RPG Maker MV 이벤트 명령 — 실제로 등장하는 코드는 3종뿐

`assets/maps/Map0*.json` 전체를 훑은 실측(부록 E):

| code | 출현 | 파라미터 실측 예 | 의미 |
|---:|---:|---|---|
| `0` | 38회 | `[]` | 리스트 종료 표식 |
| `101` | 25회 | `['', 0, 0, 2]` | **대화창 설정** = `[faceName, faceIndex, background, positionType]` |
| `401` | 31회 | `['저에게 말고 윗분에게 말씀을 걸어 주세요.']` | 대사 본문 1줄 |

**`code 101` 은 텍스트 헤더가 아니다.** 뒤따르는 `401` 들의 *표시 방식*(얼굴 그림 이름/인덱스, 배경 종류, 창 위치)을 지정하는 헤더 명령이며
표시될 텍스트를 담지 않는다 — 실측 첫 파라미터가 빈 문자열(`faceName`)인 것이 근거다.
따라서 `map_event.dart:79` 가 `code == 401` 만 읽고 `101` 을 버리는 것은 **의도적으로 옳은 동작**이다(이 게임에 얼굴 그림 시스템이 없다).
§4.4 의 헤더(`setHeader('@B푯말에 써 있기를:')`, `tile_event_dispatcher.dart:117`)는 MV 계보가 아니라 이 프로젝트의 독자 개념이다.

**`pages` 선택 규칙이 본 기획서의 `entry` 와 정반대다.**

| 체계 | 규칙 |
|---|---|
| RPG Maker MV | 조건을 만족하는 페이지 중 **번호가 가장 큰 것**(뒤에서부터 탐색) |
| 본 기획서 `Dialogue.entry[]` (D-07) | **위에서부터 첫 번째 참** |

현재 레포의 모든 이벤트는 `pages` 가 1개뿐이라(실측) 당장의 차이는 없다. 그러나 MV 에디터로 저작된 다중 페이지 데이터를 이관하면
**분기 의미가 역전**된다 → 변환 시 페이지 순서를 뒤집어야 한다([BP-24](24_dialogue_model.md) / [BP-28](28_migration_and_coexistence.md), 태스크 **T-031**).

---

## 8. UI / 입력 제약

### 8.1 800×480 고정 레이아웃

`lib/main.dart:133` 의 `FittedBox(fit: BoxFit.contain)`(그 바깥이 `:131` `Flexible`) 안에 `SizedBox(800, 480)`(`:136`) 이 들어 있다. 실제 창 크기와 무관하게 **논리 좌표는 항상 800×480**이며 전체가 균일 스케일된다.

```
┌──────────────────────────────┬───────────────────────────────────────────┐
│ HDMapViewport                │ HDDialogPanel (콘솔)                       │
│ (0,0) 288 × 320              │ (288,0) 512 × 320                          │
│ Bonfire 월드, 카메라 = 플레이어 │ 헤더 1줄 + 본문 13줄/페이지 + 프롬프트       │
├──────────────────────────────┼───────────────────────────────────────────┤
│ HDStatusPanel                │ HDDescriptionPanel (입력/선택)             │
│ (0,320) 288 × 160            │ (288,320) 512 × 160                        │
└──────────────────────────────┴───────────────────────────────────────────┘
             ▲ 위 전체 위에 HDWindowLayer(오버레이 스택)가 겹침
             ▼ 그 아래 HDBottomControlPanel (모바일 D-pad + 액션, FittedBox 밖)
```

주의: CLAUDE.md 는 상태 패널을 "0,320 / 800×160" 로 적지만, 실제 위젯 구성은 `HDStatusPanel`(288×160) + `HDDescriptionPanel`(512×160) 두 개다(`hd_config.dart:26`~`:34`, `main.dart:166`~`:171`).

### 8.2 콘솔 상수와 페이지 규칙

```dart
// hadar2026_app/lib/hd_config.dart:45  (maxFlags)
static const int maxFlags = 256;
// :46  (maxVariables)
static const int maxVariables = 256;
// :52  (maxLinesPerPage) — 사이에 4줄 doc 주석이 있어 연속 줄이 아니다
static const int maxLinesPerPage = 13;    // 이벤트 오버레이 1페이지
// :58  (maxProgressLines)
static const int maxProgressLines = 200;  // 진행 로그 롤링 버퍼
```

| 값 | 근거 |
|---|---|
| `maxLinesPerPage = 13` | 320px 패널 − 패딩 16 − 프롬프트 48 = 약 256px, 16pt × 행높이 1.2 = 19.2px/줄 |
| 랩 폭 | `consoleWidth - 32 = 480px` (`flutter_ui_host.dart:63`) |
| 색 태그 | `@0`~`@F` + `@G`(앰버), 종료 `@@`. `colorTable` 엔트리 **17개** (`utils/hd_text_utils.dart:4`~`:21`) |

**13줄 넘김의 실제 거동** — 대사 한 덩어리가 13줄을 넘으면 자동으로 키 대기 후 본문만 비운다(헤더는 살린다):

```dart
// hadar2026_app/lib/presentation/host/flutter_ui_host.dart:120
if (consoleLog.events.length >= _maxLinesPerPage) {
  await waitForAnyKey();
  consoleLog.clearEvents();
  notifyListeners();
  await Future.delayed(Duration.zero);
}
consoleLog.appendEvent(line);
```

⚠ 진행 로그(`isDialogue: false`) 는 `_maxProgressLines`(200)로 잘리지만, 파라미터 이름은 `maxLinesPerPage` 다(`console_log.dart:27`) — 혼동 유발 명명.

또한 **줄마다 10ms 지연**이 박혀 있다:

```dart
// hadar2026_app/lib/presentation/host/flutter_ui_host.dart:137
await Future.delayed(const Duration(milliseconds: 10));
```

이것은 렌더 타이밍용이지만, 헤드리스 시뮬레이션에서 그대로 비용이 된다(BP-11 G-11).

### 8.3 입력 모드 4종

```dart
// hadar2026_app/lib/hd_game_main.dart:159
HDInputMode get currentInputMode {
  if (HDWindowManager().windows.isNotEmpty) return HDInputMode.window;
  if (activeMenu != null) return HDInputMode.menu;
  if (isWaitingForKey) return HDInputMode.dialogue;
  return HDInputMode.map;
}
```

| 모드 | 진입 조건 | 처리기 | 소비 정책 |
|---|---|---|---|
| `window` | 오버레이 스택 비어있지 않음 | `HDWindowKeyDispatcher` → 실패 시 Esc/Q 로 최상단 숨김 | **모든 키 소비** (`input_dispatcher.dart:55`) |
| `menu` | `activeMenu != null` | `_handleMenu` — ↑↓/WS 이동, Enter/E/Space 확정, Esc/Q 취소(0) | **모든 키 소비** (`:86`) |
| `dialogue` | `waitForAnyKey()` 대기 중 | `_handleDialogue` — 방향키·수식키가 아니면 대기 해제 | 방향/수식키는 통과(`:114`) |
| `map` | 그 외 | `_handleMap` — Esc/Q/Space 메인메뉴, Insert/Delete/Home/End 시각 강제 | 나머지는 통과 → `HDPlayerSprite` 가 폴링 |

키 바인딩 정책(`docs/key_input_policy.md`): 이동 = 방향키/WASD, 확인 = Enter/E, 메뉴·취소 = Esc/Q/Space(Space 는 map 모드에서만 메인메뉴).

윈도우 타입별 키 처리는 `HDWindowKeyDispatcher._dispatch` 가 **런타임 타입 스위치**로 한다: `HDMessageWindow.close()`, `HDMagicSelectionWindow.moveCursor/confirm/cancel`, `HDSelectionWindow.moveCursor/confirm/cancel`. 도메인 윈도우 클래스는 더 이상 `handleInput` 을 갖지 않는다.

#### 8.3.1 `presentation/input/` 4파일의 역할 분담

| 파일 | 줄 | 소유 | 책임 |
|---|---:|---|---|
| `input_mode.dart` | 1 | — | `enum HDInputMode { map, dialogue, menu, window }` **한 줄짜리 파일**. 우선순위 해석은 `hd_game_main.dart:159` 에 있다 |
| `input_dispatcher.dart` | 153 | 싱글턴, `_registered: bool` 만 | `HardwareKeyboard.instance.addHandler` 등록(`:20`~`:27`, 멱등) → `process(key)`(`:29`) 가 모드별 4핸들러로 분기 |
| `window_key_dispatcher.dart` | 101 | 싱글턴, 상태 없음 | 스택 최상단부터 아래로 훑으며(`:27`) 런타임 타입 스위치(`:35`) |
| `virtual_input_state.dart` | 12 | 싱글턴 | `actionPressed: bool`(`:10`), `direction: JoystickMoveDirectional`(`:11`). 하단 컨트롤 패널이 쓰고 `HDPlayerSprite` 가 읽는다 |

**주의할 우회 경로**: `_handleWindow`(`input_dispatcher.dart:40`~`:56`)는 `LogicalKeyboardKey` 를 받아 **가짜 `KeyDownEvent` 를 합성**해
`HDWindowKeyDispatcher` 에 넘긴다 — `PhysicalKeyboardKey.findKeyByCode(key.keyId) ?? PhysicalKeyboardKey.keyA` 로 물리 키를 억지로 만든다(`:42`~`:47`).
윈도우 쪽 API 가 `KeyEvent` 를 요구하기 때문인데, 헤드리스 호스트에서는 이 합성이 불가능/무의미하므로
**입력 진입점을 `LogicalKeyboardKey` 가 아닌 추상 액션으로 바꾸는 것**이 하네스의 선결 과제다([BP-34](34_headless_sim_and_solver.md), 태스크 **T-090**).

#### 8.3.2 `HDTextUtils` — 3계층 밖의 4번째 폴더

`lib/utils/hd_text_utils.dart`(255줄)는 `domain`/`application`/`presentation` 어디에도 속하지 않는 유일한 파일이며 `package:flutter/material.dart` 를 import 한다(`:1`).
CI 계층 grep 대상이 `lib/application/ lib/domain/` 뿐이라(§1.4) 검사에 걸리지 않는다. 실제 소비자는 presentation 3곳뿐이다
(`host/flutter_ui_host.dart:13`, `panels/input_panel.dart:4`, `panels/console_panel.dart:4`).

| 책임 | 진입점 |
|---|---|
| `@X..@@` 태그 → `TextSpan` 파싱 | `parseRichText(text, {baseStyle})` (`:25`) |
| 픽셀 폭 기준 줄바꿈(`TextPainter` 사용) | `splitToRawLines(text, width, style)` — `flutter_ui_host.dart:110` 이 호출 |
| 색 테이블 | `colorTable` (`:4`~`:21`) — **엔트리 17개**: `'0'`~`'F'` 16개 + `'G'`(앰버) 1개 |

색 코드는 `'0'` Black / `'1'` Dark Blue / … / `'F'` White 순의 고전 16색 팔레트에 `'G'` 앰버가 덧붙은 형태다.
**텍스트에 색을 넣는 유일한 수단이 문자열 인라인 태그**라서, 색 정보가 문자열 값 안에 섞여 있고 별도 필드가 없다 — 문자열 키 체계 도입 시 이관 대상이다([BP-24](24_dialogue_model.md)).

### 8.4 시간 진행

이동 1칸마다 시간이 흐른다:

```dart
// hadar2026_app/lib/presentation/panels/player_sprite.dart:181 (_moveTowardsTarget)
final mapType = HDGameMain().gameOption.mapType;
if (mapType == HDTileProperties.TYPE_GROUND) {
  HDGameMain().gameSystem.passTime(0, 2, 0, onTimeGoes: party.timeGoes);  // 2분
} else {
  HDGameMain().gameSystem.passTime(0, 0, 5, onTimeGoes: party.timeGoes);  // 5초
}
```

`party.timeGoes()` 가 버프 감소(mindControl/levitation/penetration)와 독 피해를 처리한다(`party.dart:234`).

**`HDGameSystem`(`domain/system/game_system.dart:3`, 66줄)** 은 `ChangeNotifier` 를 확장한 시각 저장소다.

| 필드 | 초기값 | 쓰이는 곳 |
|---|---:|---|
| `year` | 1 | 상태 패널 표시 · 자릿수 올림만 |
| `month` | 1 | **어디에도 쓰이지 않는다.** `passTime` 이 증가시키지 않고(`:11`~`:37` 에 `month++` 없음) 조명 계산도 `day`/`hour` 만 본다 |
| `day` | 1 | `isInMoonlight` 의 `(day ~/ 12)` 가 10~20 인지(§7.11) |
| `hour` / `min` | 12 / 0 | `sightRangeFor` 의 `hour*100 + min`(§7.11), 디버그 키 4종(`input_dispatcher.dart:127`~`:147`) |
| `sec` | 0 | 자릿수 올림만 |

`passTime(h, m, s, {onTimeGoes})`(`:11`)의 올림 규칙: `sec≥60 → min++`, `min≥60 → hour++`, `hour≥24 → day++`, **`day≥365 → year++`**.
즉 `month` 는 초기값 1 에서 영원히 움직이지 않으며 `day` 가 1~364 범위를 돈다 — **달력 개념이 사실상 없다.**
`onTimeGoes` 콜백으로 `party.timeGoes()` 를 받아 버프·독을 함께 처리하는 구조라, 시간 진행과 상태 감쇠가 한 호출에 묶여 있다.

→ D-05 의 `time_of_day(day|night)` op 은 `month` 가 아니라 `hour` 를 근거로 삼아야 하고, §7.11 의 경계값(600/1800)을 공유해야 한다(태스크 **T-110**).

---

## 9. 테스트 / CI 현황

### 9.1 테스트 인벤토리 (`hadar2026_app/test/`, 총 1,157줄)

| 파일 | 줄 | 무엇을 고정하는가 |
|---|---:|---|
| `domain/party/party_actions_test.dart` | 243 | 휴식 규칙 8분기(`RestOutcome`), 식량 소비, SP/ESP 재충전, 파티 교체/해산 |
| `domain/lighting/sight_calculator_test.dart` | 209 | 시야/광원 계산 |
| `application/map_navigation_test.dart` | 198 | **헤드리스 이음매의 유일한 선례** — 인메모리 `AssetSource` 페이크로 이름→MapInfos→MapModel 전 경로 |
| `presentation/host/flutter_ui_host_test.dart` | 147 | 콘솔 페이지 넘김, 헤더 수명, narrative 사이클 |
| `domain/text/noun_test.dart` | 82 | 한국어 조사 처리 |
| `domain/map/tile_action_test.dart` | 97 | **`scriptMode` 와이어 값(0~4)**, `isInteractive`/`isStepOn` 집합, `debugTag`, `isUnitPassable` |
| `domain/console/text_utils_test.dart` | 71 | `@X..@@` 태그 파싱/랩 |
| `domain/map/map_event_test.dart` | 59 | `code=401` 파싱, `hadarEvent{kind,payload}` 파싱 |
| `domain/console/console_log_test.dart` | 51 | events/progress 버퍼 |

`packages/cm2_script/test/`: `cm2_script_test.dart`(331줄), `parser_test.dart`(108줄).

### 9.2 헤드리스 선례 — `map_navigation_test.dart`

```dart
// hadar2026_app/test/application/map_navigation_test.dart:13
class _FakeAssets implements AssetSource {
  _FakeAssets(this.files);
  final Map<String, String> files;
  final List<String> reads = [];
  @override
  Future<String> loadString(String path) async {
    reads.add(path);
    final content = files[path];
    if (content == null) throw Exception('asset not found: $path');
    return content;
  }
}
// :71
HDHosts().bind(ui: _UnusedUiHost(), movement: _UnusedMovementHost(), assets: assets);
// :78
tearDown(HDHosts().reset);
```

쓰지 않는 포트는 `noSuchMethod` 로 "쓰면 터지게" 만들어 둔다(`:188`, `:194`). **이 형태가 `HDMenuFlows` / `HDBattle` / `HDTileEventDispatcher` 를 테스트하는 템플릿이다.**

### 9.3 비어 있는 영역

| 영역 | 테스트 | 비고 |
|---|:--:|---|
| `HDTileEventDispatcher` 3티어 분기 | ❌ | 게임 로직의 심장인데 커버 0 |
| `HDScriptEngine` (Hadar 커맨드 40 + 함수 12) | ❌ | cm2 엔진 자체는 커버되나 Hadar 어댑터는 0 |
| `HDNativeScriptRunner` / `HDMapScript` | ❌ | §5.5 의 스텁 버그가 여기서 잡혔어야 함 |
| `HDSaveManager` | ❌ | 라운드트립·누락 필드 검증 없음 |
| `HDBattle` / `HDMagicSystem` / `HDMenuFlows` | ❌ | 합계 1,362줄이 무검증 |
| 위젯/골든 테스트 | ❌ | 하나도 없음 |
| 자산 정합성(맵 이름 ↔ 파일) | ❌ | §7.2 의 불일치를 아무도 못 잡음 |

### 9.4 고아 코드

`lib/test_script.dart`(24줄) 는 `main()` 을 가진 별도 엔트리포인트로 `HDScriptEngine` 을 직접 구동하려 한다. 그러나 `HDHosts().bind` 가 없으므로 `Talk` 커맨드가 `HDHosts().ui` 를 읽는 순간 `StateError` 로 죽는다. **포트 도입 이전의 잔재이며 CI 가 실행하지 않는다.**

### 9.5 CI 구성 (`.github/workflows/ci.yml`)

트리거: `main` push / 모든 PR / 수동 dispatch. 같은 ref 재푸시 시 진행 중 실행 취소(`concurrency`).

| 잡 | 스텝 |
|---|---|
| `app` | `flutter pub get` → `flutter analyze --no-fatal-infos` → `flutter test` → 계층 grep 2종 |
| `cm2_script` | `dart pub get` → `dart analyze`(warning fatal) → `dart test` |

- `--no-fatal-infos` 는 의도적. 기존 스타일 info 77건(`constant_identifier_names`, `avoid_print`, `withOpacity` deprecation)이 있어 처음부터 빨갛지 않게 하려는 것. **error/warning 은 여전히 치명**이라 새 회귀는 잡힌다.
- `dart format` 게이트 없음(레포가 format-clean 이 아님, 약 20파일이 바뀜).
- 서브모듈 `REF_FLUTTER_lore2026` 은 체크아웃하지 않는다(`submodules: false`).

#### 9.5.1 CI 가 검증하지 **않는** 것 — 웹 빌드

배포는 별도 `.github/workflows/deploy_web.yml` 이 담당하고, 트리거는 **수동 `workflow_dispatch` 뿐**이다:

```yaml
# .github/workflows/deploy_web.yml:3
on:
  workflow_dispatch: # 수동 트리거
...
# :26~:28
- name: Build Web 🏗️
  working-directory: hadar2026_app
  run: flutter build web --base-href "/Hadar2026/" --release
# :30~:34  peaceiris/actions-gh-pages@v3 → ./hadar2026_app/build/web
```

즉 **`flutter build web` 은 push 에도 PR 에도 돌지 않는다.** `ci.yml` 의 `flutter test` 는 Dart VM 에서 돌므로 `dart:io` 를 문제없이 컴파일한다.
→ §1.4 의 `dart:io` 위반이 실제로 웹 빌드를 깨뜨리는지 여부는 **본 감사 범위에서 실빌드로 확인하지 못했다(미확인)**.
확실한 것은 **깨지더라도 배포 버튼을 누를 때까지 아무도 모른다**는 구조적 사실이다.
이 프로젝트의 유일한 공개 배포 경로가 웹(GitHub Pages)이므로, 콘텐츠 CI 설계([BP-35](35_ci_and_build.md))는 웹 스모크 빌드를 입력으로 가져야 한다.

### 9.6 결정론 관련 실측

런타임에 **시드가 없는 난수와 벽시계**가 섞여 있다.

| 위치 | 코드 | 성격 |
|---|---|---|
| `packages/cm2_script/lib/src/cm2_script.dart:311` | `return Random().nextInt(max);` | cm2 `Random()` 함수 |
| `application/battle.dart` 155,174,389,427,432,440,441,474,478,479,488,503,513,514 | `Random().nextInt(...)` | 전투 전량 |
| `application/menu_flows.dart:104` | `Random().nextInt(10)` | 도주 판정 |
| `domain/party/player.dart:71` | `damaged(20 + (DateTime.now().millisecondsSinceEpoch % 20));` | **독 피해가 벽시계 기반** |

시드 주입 지점이 한 곳도 없다. → 회귀 골든 비교·솔버 증명이 현재 구조로는 불가능(BP-11 G-17).

### 9.7 상수 의미 충돌 (실측)

`HDBattle._battleResult` 의 Dart 주석과 `const.cm2` 상수가 **어긋난다**.

| 값 | Dart (`battle.dart:27` 선언, `:240`~`:275` 분기) | `const.cm2:53`~`:55` |
|---:|---|---|
| 0 | Lose (전멸 → `processGameOver(2)`) | `BATTLERESULT_EVADE` |
| 1 | Win | `BATTLERESULT_WIN` |
| 2 | Run away ("무사히 도망쳤다") | `BATTLERESULT_LOSE` |

즉 cm2 가 `if (Equal(Battle::Result(), BATTLERESULT_LOSE))` 로 패배를 검사하면 실제로는 **도주** 를 잡는다. 현재 자산 중 이 조합을 쓰는 스크립트가 있는지는 미확인(`L1_ep1d*.cm2` 미정독).

---

## 10. 요약

### 10.1 이 장이 확정한 것

1. **계층 규칙은 실재하고 CI 로 강제된다** — presentation/파사드 import 금지, material/bonfire/flame 금지 두 grep 모두 현재 위반 0건. 단 `dart:io` 금지는 강제되지 않으며 실제 위반이 1건 있고(`menu_flows.dart:2`), **웹 빌드는 CI 가 아예 돌리지 않는다**(§1.4, §9.5.1).
2. **포트 3종(`UiHost`/`PartyMovementHost`/`AssetSource`)과 합성 루트 `HDHosts` 는 이미 존재한다.** 헤드리스 하네스는 신규 발명이 아니라 기존 이음매의 활용이며, 선례는 `test/application/map_navigation_test.dart` 다. 다만 §4.1 대로 **이동·상호작용 판정이 `presentation/` 안에 있어 포트만으로는 구동되지 않는다.**
3. **부팅 시작 맵은 코드가 아니라 `assets/startup.cm2` 한 줄이 정한다** — 현재 `LoadScript("LORE_EP", 32, 25)` → `Map002.json` + `Map002.cm2`.
4. **`LoadScript` 는 두 얼굴이 아니라 세 얼굴이다**(§2.3) — ① MapInfos 등록 이름 ② cm2 파일명 ③ **미등록 이름 + 동명 json**(이름 폴백). ③ 이 `ORIGIN` 을 살리고 ① 이 `TOWN1` 을 죽인다.
5. **타일 상호작용은 `HDTileEventDispatcher.check` 하나로 모이고, 그 안이 3티어(native → cm2 → JSON)다.** 다만 이동/확인 입력의 실제 발화점은 `HDPlayerSprite.update(dt)` 폴링이며 `HDInputDispatcher` 가 아니다(`input_dispatcher.dart:149` 주석이 명시).
6. **티어 판정은 티어의 내용물을 보장하지 않는다.** `currentMapCm2Path` 는 페어 cm2 로드 성공 여부와 무관하게 항상 설정되고, `loadScript` 는 실패 시 `clearRuntimeState()` 에 도달하기 전에 조기 `return` 한다(§5.4, `script_engine_adapter.dart:92`~`:99`). **등록 이름 15개 중 13개가 이 잔존 상태**이므로 새 맵의 좌표를 직전 맵의 cm2 핸들러가 판정한다.
7. **JSON 대사 티어는 좌표당 첫 이벤트 1개, 조건 없음, 상태 참조 없음**이다(`_emitJsonDialog`, 선형 탐색). `Event::Override()` 누락이 만드는 실제 증상은 "중복" 이 아니라 **반대로 Override 가 있는 곳의 JSON 텍스트가 사문화되는 것**이고, 현재 자산에서 사문 대사는 3줄이다(§4.5).
8. **상태는 3중으로 분열되어 있고 전부 이름 없는 정수 인덱스다.** 세이브 v1 은 그중 하나만 담고, **`map.events` 와 현재 맵 이름도 담지 않으며**(§6.2.1), 로드 경로는 네이티브 스크립트를 붙이지 않는다(§6.3.1).
9. **게임 전체의 정적 대사 자산은 이벤트 38개·대사 31줄이다.** 인벤토리는 food/gold 정수 2개, 퀘스트/저널/목표 개념은 코드 0건.
10. **MapInfos 등록 이름 15개 중 7개가 존재하지 않는 파일로 해석된다**(`Map004`·`005`·`006`·`007`·`008`·`009`·`012`). 그리고 **등록 자체가 원인**이다 — 미등록인 `ORIGIN` 은 이름 폴백으로 정상 로드된다(§7.2.3). 수리 선택지는 "명시 참조 추가" 와 "**등록 해제**" 둘이며 후자가 §5.4 잔존 문제까지 동시에 없앤다.
11. **네이티브 티어는 현재 정상 동작하는 맵이 0개다.** ① `isFlagSet`/`setFlag` 가 본문 없는 스텁이라 모든 조건 분기가 `false`(§5.5) ② `TOWN1`/`GROUND1`/`DEN1` 은 지오메트리 없이 부착되어 직전 맵 좌표를 판정(§7.2.2) ③ `TOWN2` 는 이름 자체가 도달 불가(§5.5). 세 원인은 서로 독립적이다.
12. **`Battle::Result()` 는 두 가지 이유로 신뢰할 수 없다** — 초기값이 `1`(Win)이고 `init()` 이 맵 전환마다 그것으로 되돌리며(§5.8.1), 값 0/2 의 의미가 `const.cm2` 상수와 정반대다(§9.7).
13. **적 테이블은 75개 엔트리(id 0~74)지만 콘텐츠가 참조 가능한 것은 74종(id 1~74)** 이다 — `registerEnemy` 의 `<= 0` 가드 때문(§7.5). 후속 장은 **74종** 기준.
14. **런타임 난수에 시드가 없고 `player.dart:71` 은 벽시계를 쓴다**(§9.6) — 현 상태로는 재현 가능한 시뮬레이션이 불가능.
15. **지역 정체성이 렌더링에 실제로 쓰이는데 그 출처가 무관한 조건에 묶여 있다** — 조명 규칙의 `mapName` 이 `currentMapScript?.mapName ?? ""` 에서 오므로, 실제 플레이 맵 전부에서 빈 문자열이고 `DEN`/`TOWN`/`CASTLE` 판정이 한 번도 발동하지 않는다(§7.11).
16. **cm2 를 "정적 검증 불가" 라고 말할 때 튜링 완전성을 근거로 들면 틀린다**(§5.7). 실제 근거는 침묵 실패 2계열(미등록 심볼 / 범위 밖 인자), 전역 수명의 비결정, `.assign` 재실행, 스키마 부재다.
17. **테스트는 domain 규칙 위주이며 게임 로직의 심장(디스패처·스크립트 어댑터·세이브·전투)이 전부 무검증**이다. 위젯 테스트 0건, 자산 정합성 테스트 0건.

### 10.2 다음 장으로 넘긴 것

| 주제 | 이관 대상 |
|---|---|
| 위 사실들이 AI 자동 생성에 어떤 벽이 되는가(G-nn) | [BP-11](11_gap_analysis.md) |
| 타 게임/툴의 해결 방식 참조 | [BP-12](12_reference_designs.md) |
| 목표 아키텍처 전체 그림 | [BP-20](20_target_architecture.md) |
| Content Pack 포맷·ID 체계 | [BP-21](21_content_pack_spec.md) |
| 상태 3중 분열 통합과 세이브 v2 | [BP-25](25_world_state_and_save.md) |
| 좌표 결합 해소(앵커) | [BP-26](26_entity_registry_and_anchors.md) |
| 디스패치 티어 재정의(D-10) 구현 | [BP-27](27_runtime_engine.md) |
| cm2/네이티브 공존·이관 | [BP-28](28_migration_and_coexistence.md) |
| 맵 에디터 API 를 콘텐츠 서버로 확장 | [BP-31](31_content_server_api.md), [BP-36](36_map_editor_extension.md) |
| 헤드리스 하네스 설계 | [BP-34](34_headless_sim_and_solver.md) |
| 인벤토리/저널 신설 | [BP-41](41_journal_ui_spec.md), [BP-42](42_item_and_inventory.md) |
| 위 사실들의 수리 순서·태스크 번호 | [BP-50](50_roadmap.md), [BP-51](51_task_breakdown.md) |

**이 장의 사실 ↔ M0 수리 태스크 대응**(전체 목록은 [BP-51](51_task_breakdown.md)):

| 이 장의 절 | 사실 | 태스크 |
|---|---|---|
| §7.2 | MapInfos 이름 해석 파손 | **T-004 · T-005 · T-006 · T-009** |
| §5.4 | `loadScript` 실패 시 상태 누수 | **T-010 · T-011** |
| §7.2.2 | 지오메트리 없이 네이티브 부착 | **T-012 · T-013** |
| §6.2.1 | `MapModel.toJson` 이 `events` 누락 | **T-014 · T-016** |
| §6.3.1 | 세이브 로드가 네이티브 스왑을 건너뜀 | **T-015** |
| §6.2 | 현재 맵 이름 미저장 | **T-008** |
| §9.6 | 무시드 난수 · 벽시계 | **T-017 · T-018 · T-019 · T-020 · T-021** |
| §1.4 | `dart:io` / `exit(0)` | **T-022 · T-023 · T-024** |
| §5.8.1 · §9.7 | `Battle::Result` 정본·초기값 | **T-025 · T-026 · T-027** |
| §5.3 | 범위 밖 인자 침묵 no-op | **T-028 · T-029** |
| §5.2 | `Party::PosX`/`PosY` 중복 등록 | **T-030** |
| §7.12 | `code 101` 서술 정정 | **T-031** |
| §5.7 | "튜링 완전" 논거 제거 | **T-032** |
| §5.5 | 네이티브 플래그 스텁 | **T-033**(진단 고정) → **T-111**(수리) |
| §7.11 | `time_of_day` 경계값 공유 | **T-110** |
| §4.1 | 이동·상호작용 추출 | **T-085 ~ T-090** |

### 10.3 열린 질문

| ID | 질문 | 왜 지금 답이 없는가 |
|---|---|---|
| Q-10-01 | `TOWN1/GROUND1/DEN1/DEN2` 를 **어느 방식으로 살릴 것인가?** ① MapInfos 에 `json`/`cm2` override 명시 ② **MapInfos 에서 엔트리 제거해 이름 폴백에 맡김**(`ORIGIN` 이 이미 그렇게 동작 중, §7.2.3) ③ `Map013/014` 계열로 통일하고 중복 파일 삭제. ②는 `cm2Path == null` 이 되어 §5.4 잔존 문제까지 동시에 없앤다. | md5 중복(§7.1)으로 보아 어느 쪽이 최신인지 코드만으로는 판정 불가. 태스크 **T-004** 가 이 결정을 요구한다 |
| Q-10-02 | `L1_ep1d0~d5_1.cm2`(2,441줄) 와 `lore_ep1.cm2`(558줄), `town2.cm2`(547줄) 는 **현재 도달 가능한가?** 상호 `LoadScript` 그래프를 정독하지 않아 미확인. 레거시 이관 범위(D-17)에 직결. | 본 감사 범위에서 전문 정독 미수행 |
| Q-10-03 | `HDBattle._battleResult` 와 `const.cm2` 의 값 의미 충돌(§9.7) 중 **어느 쪽이 정본인가?** Dart 쪽을 const.cm2 에 맞출지, 반대로 갈지. | 원본 C++(`REF_hadar/`) 미대조 |
| Q-10-04 | `books.json` 의 `weapon` 스키마를 **신규 아이템 카탈로그의 출발점으로 삼을 것인가**, 아니면 D-03 의 `items/items.json` 을 백지에서 정의할 것인가. | BP-42 의 결정 사항 |
| Q-10-05 | `HDMapScript.isFlagSet/setFlag` 스텁을 `HDNativeScriptRunner` 로 연결하는 것이 **버그 수정인가 동작 변경인가?** 고치면 `Town1MapScript` 의 지금까지 도달 불가였던 분기가 갑자기 살아난다. | 그 분기들이 검증된 적이 없음 |
| Q-10-06 | `month` 필드처럼 저장만 되고 안 쓰이는 상태가 더 있는가? 세이브 v2 설계 전에 전수 조사가 필요. | §8.4 에서 `HDGameSystem.month` 는 확정. `party` 의 버프 8종 중 `walkOnSwamp`/`penetration`/`canUseSpecialMagic` 의 소비처는 미확인 |
| Q-10-08 | `dart:io` 위반이 **실제로 `flutter build web` 을 깨뜨리는가?** 깨진다면 현재 웹 배포가 이미 불가능한 상태다. | §9.5.1 — 본 감사에서 실빌드 미수행(미확인). 태스크 **T-023** 전에 1회 확인 필요 |
| Q-10-09 | `Town2MapScript`(83줄)를 **되살릴 것인가 삭제할 것인가?** `TOWN2` 는 MapInfos 에도 파일에도 없어 한 번도 실행된 적이 없다(§5.5, 부록 G-2). | 되살리려면 맵 자산을 새로 만들어야 한다 — [BP-28](28_migration_and_coexistence.md) 의 이관 범위 결정 사항 |
| Q-10-07 | 콘텐츠 팩 디렉토리(D-03)가 **7개 하위 디렉토리**를 갖는데, 이를 `pubspec.yaml` 에 전부 나열할 것인가 아니면 빌드 산출물 1~3개 파일만 번들에 넣을 것인가. §7.10 참조. | BP-21/BP-35 의 결정 사항 |
