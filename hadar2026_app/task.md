# Hadar 2026 — MVC 재구성 Task

> Source: `hadar2026_app/lib/` 구조 분석 (2026-04-27).
> 목표: **다른 View 렌더링이 가능할 만큼 Model 을 독립시키고, `lib/` 디렉토리를 그에 맞게 재구성한다.**
> 가장 중요한 섹션은 [§4 lib/ 재구성](#4-제안--lib-재구성-가장-중요).

---

## 1. 현재 디렉토리 분류 현황 (참고)

| 디렉토리 | 파일 수 | 의도 | 실제 |
|---|---:|---|---|
| `lib/models/` | 10 | 데이터 (M) | 데이터 + 윈도우 입력 핸들러(View 책임) 혼재 |
| `lib/views/` | 6 | 화면 (V) | 화면 + Bonfire 게임 로직(`HDWorldMap`) 혼재 |
| `lib/game_components/` | 9 | 컨트롤러/시스템 (C) | 거대 god object + 컨트롤러 + Bonfire 컴포넌트 + 모델급 매니저 혼재 |
| `lib/scripting/` | 7 | 스크립트 엔진 (C) | 비교적 분리 양호 |
| `lib/utils/` | 1 | 텍스트 유틸 | OK |
| `lib/main.dart` | 1 | 부트/조립 | OK (168줄) |

총 6,785줄 / 36 파일.

## 2. MVC 관점에서 잘된 점 (유지 대상)

- [main.dart:130-153](lib/main.dart#L130-L153) `ListenableBuilder(listenable: HDGameMain(), …)` — View는 모델을 듣기만 하는 단방향 흐름.
- [models/hd_party.dart](lib/models/hd_party.dart), [models/hd_player.dart](lib/models/hd_player.dart), [models/map_model.dart](lib/models/map_model.dart) 는 거의 순수한 데이터 + 도메인 로직(레벨업, 시간 흐름). `toJson/fromJson` 갖춰져 있음.
- [views/hd_status_panel.dart](lib/views/hd_status_panel.dart) — 모범. `HDGameMain().party` 만 듣고 단순 렌더링.
- 스크립트 두 런타임은 `HDScriptEngine` / `HDNativeScriptRunner` 로 분리, `HDMapScript` 베이스 + `mapScriptFactory` 등록 방식이 깨끗함.

---

## 3. 핵심 문제점 (해결 시 체크)

### A. `HDGameMain` god object — 4개 역할 동시 수행
- [ ] **A1.** 입력 디스패치 분리 ([hd_game_main.dart:65-208](lib/game_components/hd_game_main.dart#L65-L208)) → `presentation/input/input_dispatcher.dart`
- [ ] **A2.** 콘솔 데이터/줄분할/폰트 상수 ([L223-L268](lib/game_components/hd_game_main.dart#L223-L268)) → `domain/console/console_log.dart` (TextStyle 제거)
- [ ] **A3.** 메인/캐릭터/파티/저장/난이도 메뉴 흐름 ([L385-L781](lib/game_components/hd_game_main.dart#L385-L781)) → `application/menu_flows.dart`
- [ ] **A4.** `restHere`, `showCharacterStatus`, `_dismissPartyMember` 등 게임 룰 ([L454-L750](lib/game_components/hd_game_main.dart#L454-L750)) → `domain/party/party_actions.dart`
- [ ] **A5.** `loadMapFromFile`, MapInfos 인덱스 해석 ([L959-L992](lib/game_components/hd_game_main.dart#L959-L992)) → `application/map_navigation.dart`
- [ ] **A6.** `checkTileEvent` ([L895-L953](lib/game_components/hd_game_main.dart#L895-L953)) → `application/tile_event_dispatcher.dart`
- [ ] **A7.** 가상 D-pad 상태 ([L74-L75](lib/game_components/hd_game_main.dart#L74)) → `presentation/input/virtual_input_state.dart`

### B. `models/` 안에 View 책임이 들어감
- [ ] **B1.** [models/hd_magic_window.dart:48-70](lib/models/hd_magic_window.dart#L48-L70) — `KeyEvent` 직접 핸들링을 모델 밖으로
- [ ] **B2.** [models/hd_window.dart:37-39](lib/models/hd_window.dart#L37-L39) — `handleInput` 추상 메서드를 베이스 모델에서 제거
- [ ] **B3.** `HDMessageWindow`, `HDMagicSelectionWindow` 의 데이터/입력 분리

### C. `views/` 안에 게임 룰이 박힘
- [ ] **C1.** `HDWorldMap._getSightRange` ([hd_map_viewport.dart:363-406](lib/views/hd_map_viewport.dart#L363-L406)) → 도메인으로 추출
- [ ] **C2.** `_isInMoonlight` ([L408-L427](lib/views/hd_map_viewport.dart#L408-L427)) → 도메인으로 추출
- [ ] **C3.** `_computeLightBit` ([L335-L361](lib/views/hd_map_viewport.dart#L335-L361)) → 도메인으로 추출
- [ ] **C4.** `HDWorldMap` 자체를 `presentation/panels/world_map_renderer.dart` 로 이동(렌더만)

### D. `game_components/` 가 4가지 다른 layer를 한 통에 담음
- [ ] **D1.** Bonfire `SimplePlayer` 인 `game_components/hd_player.dart` (411줄) → `presentation/panels/player_sprite.dart`, 클래스 이름 `HDPlayerSprite` 로 변경
- [ ] **D2.** 같은 이름 `HDPlayer` 충돌 해소 (모델 vs 컴포넌트)
- [ ] **D3.** `hd_battle.dart` 의 도메인 룰과 UI flow 분리 — `HDGameMain().showMenu()`/`addLog()` 직접 호출 끊기 ([hd_battle.dart:57-60](lib/game_components/hd_battle.dart#L57-L60))
- [ ] **D4.** `hd_tile_properties.dart` 가 사실상 도메인 상수임을 인정하고 `domain/map/` 으로 이동

### E. 모델이 View 상수를 들고 있음
- [ ] **E1.** `HDGameMain.consoleStyle` (TextStyle), `consoleWidth` 같은 픽셀 상수 ([hd_game_main.dart:233-238](lib/game_components/hd_game_main.dart#L233-L238)) 를 모델에서 제거
- [ ] **E2.** `addLog()` 의 `HDTextUtils.splitToLines(...)` 호출 — wrap 폭에 맞춘 사전 줄분할을 View 측으로 옮김

### F. View ↔ Controller 동기 결합
- [ ] **F1.** `HDBattle.showEnemy()` ([hd_battle.dart:57](lib/game_components/hd_battle.dart#L57)) 등 도메인의 `HDGameMain()` 직접 호출 제거
- [ ] **F2.** `await HDGameMain().showMenu(...)` 형태의 동기 메뉴 대기를 인터페이스(UiHost) 추상화 뒤로 보내 헤드리스 테스트 가능하게

---

## 4. 제안 — `lib/` 재구성 (가장 중요)

### 4.1 목표 디렉토리 트리

```
lib/
├─ main.dart                           # 부트만, 현재 그대로
├─ hd_config.dart
│
├─ domain/                             # 순수 Dart, Flutter import 없음
│  │                                   # (Bonfire/Material/Services 금지)
│  ├─ party/
│  │   ├─ party.dart                   # 현 models/hd_party.dart
│  │   ├─ player.dart                  # 현 models/hd_player.dart (속성 데이터만)
│  │   └─ party_actions.dart           # restHere, dismissMember, sortParty 룰
│  ├─ map/
│  │   ├─ map_model.dart
│  │   ├─ map_unit.dart
│  │   ├─ map_event.dart
│  │   └─ tile_properties.dart         # 현 hd_tile_properties.dart
│  ├─ battle/
│  │   ├─ battle_state.dart            # enemies, result, isActive
│  │   ├─ battle_engine.dart           # 룰 부분만
│  │   ├─ enemy.dart, enemy_data.dart
│  │   └─ commands.dart
│  ├─ magic/
│  │   ├─ magic.dart
│  │   └─ magic_system.dart            # 현 hd_magic_system.dart 룰 부분
│  ├─ lighting/
│  │   └─ sight_calculator.dart        # _getSightRange/_isInMoonlight/_computeLightBit
│  ├─ console/
│  │   └─ console_log.dart             # eventLogs/progressLogs (TextStyle 없는 plain)
│  └─ window/
│      ├─ game_window.dart             # HDWindow에서 handleInput 빼고 데이터만
│      ├─ message_window_data.dart
│      └─ magic_window_data.dart
│
├─ application/                        # 유스케이스 — UI에 의존하지 않는 비동기 흐름
│  ├─ game_session.dart                # 현 HDGameMain.init/sessionId/mapVersion
│  ├─ map_navigation.dart              # loadMapFromFile + MapInfos 해석
│  ├─ tile_event_dispatcher.dart       # 현 checkTileEvent
│  ├─ menu_flows.dart                  # showMainMenu/character/heal/option
│  ├─ save_manager.dart
│  └─ scripting/                       # 현 lib/scripting 그대로 이전
│      ├─ script_engine_adapter.dart
│      ├─ native_script_runner.dart
│      ├─ map_script.dart
│      └─ maps/
│
├─ presentation/                       # Flutter/Bonfire 의존 — 갈아끼울 수 있는 영역
│  ├─ host/
│  │   ├─ ui_host.dart                 # interface: showMenu(), addLog(), waitForAnyKey()
│  │   └─ flutter_ui_host.dart         # 현재 800×480 콘솔 구현
│  ├─ input/
│  │   ├─ input_dispatcher.dart        # 현 HDGameMain.processKey
│  │   ├─ input_mode.dart
│  │   └─ virtual_input_state.dart
│  ├─ panels/                          # 현 views/
│  │   ├─ map_viewport.dart
│  │   ├─ world_map_renderer.dart      # 현 HDWorldMap (렌더만)
│  │   ├─ player_sprite.dart           # 현 game_components/hd_player.dart
│  │   ├─ console_panel.dart
│  │   ├─ status_panel.dart
│  │   ├─ battle_overlay.dart
│  │   ├─ window_layer.dart
│  │   └─ bottom_control_panel.dart
│  └─ window_manager.dart               # window 입력 핸들러 포함
│
└─ utils/
   └─ text_utils.dart
```

### 4.2 Phase 별 진행 (의존성 순서대로)

각 phase 끝마다: `flutter analyze` 통과 + 게임이 실행되어 첫 맵까지 진입 + 저장/불러오기 가능 — 을 확인.

---

#### Phase 0 — 준비
- [x] **0.1** 현재 상태에서 `flutter analyze` 통과 확인 (재구성 전 baseline) — error/warning 0, info 90 (lint only)
- [x] **0.2** `flutter run` 으로 정상 부팅 + 첫 맵 진입 확인 — 사용자 검증 완료. 빌드 도중 발견된 의존성 이슈(`bonfire ^3.16.1`이 3.17.2로 자동 갱신되어 flame 1.35.1 호환 깨짐)는 `pubspec.yaml`에서 정확 버전 핀(`bonfire: 3.16.1`)으로 해결
- [x] **0.3** 빈 디렉토리 골격 생성: `lib/domain/{party,map,battle,magic,lighting,console,window}`, `lib/application/{,scripting/maps}`, `lib/presentation/{host,input,panels}`

---

#### Phase 1 — 도메인 분리 (입력/View 의존이 가장 적은 것부터)

순수 데이터 모델은 옮기기만 하면 되므로 import 경로 갱신이 주된 작업.

- [x] **1.1** `models/hd_party.dart` → `domain/party/party.dart`
- [x] **1.2** `models/hd_player.dart` → `domain/party/player.dart` (모델 쪽)
- [x] **1.3** `models/hd_enemy.dart`, `hd_enemy_data.dart` → `domain/battle/`
- [x] **1.4** `models/hd_magic.dart` → `domain/magic/magic.dart`
- [x] **1.5** `models/map_model.dart` 안의 `MapEvent`/`MapUnit`/`MapModel` 을 파일별로 분리하여 `domain/map/` 로 (re-export로 호환 유지)
- [x] **1.6** `models/hd_game_option.dart` → `domain/game_option.dart`
- [x] **1.7** `game_components/hd_tile_properties.dart` → `domain/map/tile_properties.dart` (D4)
- [x] **1.8** `game_components/hd_magic_system.dart` 의 정적 룰 → `domain/magic/magic_system.dart` (UI 의존은 Phase 3/6에서 분리)
- [x] **1.9** import 경로 일괄 갱신 + `flutter analyze` 통과 — error/warning 0, info 90 (baseline 동일)

---

#### Phase 2 — `HDGameMain` god object 해체 (최우선) (A 항목)

> 이 phase 가 전체 재구성의 핵심. 한 번에 모두 쪼개지 말고 단계별로.

- [x] **2.1** `presentation/input/input_mode.dart` 에 `HDInputMode` enum 이전 (HDGameMain에서 export하여 호환 유지)
- [x] **2.2** `presentation/input/input_dispatcher.dart` 신설 — `processKey()` 와 `HardwareKeyboard.instance.addHandler` 등록 이전 (A1). `HDGameMain.processKey` 는 dispatcher 위임 thin wrapper로 축소. `HDWindowManager.hideTopWindow()` helper 추가
- [x] **2.3** `presentation/input/virtual_input_state.dart` 신설 — `virtualActionPressed`, `virtualDirection` 이전 (A7). 호출자 3곳(player sprite, bottom panel) 업데이트 완료
- [x] **2.4** `presentation/host/ui_host.dart` 인터페이스 정의: `Future<int> showMenu()`, `Future<void> addLog()`, `Future<void> waitForAnyKey()`, `void clearLogs()` (F2 의 핵심). `HDGameMain implements UiHost` 적용 — 시그니처 일치 검증됨
- [x] **2.5** `domain/console/console_log.dart` 신설 — 데이터 컨테이너 `HDConsoleLog` 분리(events/progress + append/clear). HDGameMain은 위임 (A2 / E1 부분 — TextStyle은 host로 이동했고 도메인은 TextSpan 보관 중. raw String 보관 전환은 추후 정리)
- [x] **2.6** `presentation/host/flutter_ui_host.dart` 신설 — `HDFlutterUiHost`(ChangeNotifier, UiHost). HDMenu/activeMenu/_keyWaitCompleter/consoleLog/wrap 상수(consoleStyle/consoleWidth/maxLinesPerPage)/`splitToLines` wrap 호출 모두 이전 (E1 / E2 핵심). HDGameMain은 facade 위임 + `_host.addListener(notifyListeners)` 로 기존 listener 호환 유지. `views/hd_console_panel.dart` 의 `HDGameMain.consoleStyle` 참조는 panel 자체 const로 흡수
- [x] **2.7** `application/menu_flows.dart` 신설 — `HDMenuFlows` 클래스에 `showMainMenu`/`showBattleMenu`/`showPartyStatus`/`showHealthStatus`/`showCharacterStatus`/`restHere`/`selectGameOption`/`_sortParty`/`_dismissPartyMember`/`selectDifficulty`/`selectLoadMenu`/`selectSaveMenu`/`processGameOver`/`_selectPlayerForMagic`/`_selectPlayerForESP` 이전. HDGameMain의 동명 메서드는 위임 thin wrapper. 미사용 import(`dart:io`/`dart:math`/`hd_save_manager`/`hd_battle`/`hd_player`) 정리. **HDGameMain 993줄 → 257줄** (A3, A4 부분)
- [~] **2.8** `domain/party/party_actions.dart` 신설 — `restHere`, `_sortParty`, `_dismissPartyMember` (A4). 현재 이 메서드들은 한국어 UI flow + 게임 룰이 한 흐름으로 섞여 있어 도메인 룰만 추출하려면 큰 수술. Phase 6 (도메인 결합 정리)에서 함께 진행. **현재는 menu_flows.dart 에 통째 보관**
- [x] **2.9** `application/map_navigation.dart` 신설 — `HDMapNavigation.loadByName` 으로 `loadMapFromFile` + MapInfos 인덱스 해석 이전. HDGameMain.loadMapFromFile은 위임 (A5)
- [x] **2.10** `application/tile_event_dispatcher.dart` 신설 — `HDTileEventDispatcher.check` 으로 `checkTileEvent` + `_isScriptRunning` 플래그 이전. HDGameMain은 `isScriptRunning` getter도 dispatcher 위임 (A6)
- [ ] **2.11** `application/game_session.dart` 신설 — `init()`, `sessionId`, `mapVersion`, `errorMessage`, `mapViewGameRef` 등 잔여 세션 상태
- [ ] **2.12** `HDGameMain` 자체는 thin facade 로 축소(혹은 제거). 기존 `HDGameMain()` 호출처는 단계적으로 새 위치로 변경
- [ ] **2.13** 게임이 다시 부팅 + 첫 맵 진입 + 메뉴/대화/저장 동작 확인 — **사용자 검증 필요**

---

#### Phase 3 — Window 모델에서 입력 책임 제거 (B 항목)

- [x] **3.1** `models/hd_window.dart` → `domain/window/game_window.dart`. `handleInput(dynamic)` 추상 메서드 제거 (B2)
- [x] **3.2** `models/hd_message_window.dart` → `domain/window/message_window_data.dart`. `handleInput` + `package:flutter/services.dart` import 제거 (도메인 정화)
- [x] **3.3** `models/hd_magic_window.dart` → `domain/window/magic_window_data.dart`. `handleInput` 제거. `moveCursor`/`confirm`/`cancel` 은 도메인 메서드로 유지 (key→method 매핑만 presentation으로 이동) (B3)
- [x] **3.4** `models/hd_magic_window.dart` 의 키 처리 → `presentation/window_manager.dart._handleMagic` (B1)
- [x] **3.5** `game_components/hd_window_manager.dart` → `presentation/window_manager.dart` 로 이전. `_dispatch` 가 top window의 런타임 타입을 보고 `_handleMessage` / `_handleMagic` 으로 분기. `models/` 디렉토리 비워짐

---

#### Phase 4 — View 안의 게임 룰을 도메인으로 (C 항목)

- [x] **4.1** `domain/lighting/sight_calculator.dart` 신설 — `HDSightCalculator.sightRangeFor({party, mapName})` 정적 함수로 추출 (C1)
- [x] **4.2** `HDSightCalculator.isInMoonlight({party, mapName})` (C2)
- [x] **4.3** `HDSightCalculator.lightBitFor({mapX, mapY, playerX, playerY, sightRange})` 순수 함수 (C3)
- [x] **4.4** `HDWorldMap._renderShadow` 가 위 3개 함수 호출만 — 게임 룰을 view에서 완전 분리
- [x] **4.5** `HDWorldMap` → `presentation/panels/world_map_renderer.dart` (C4)

---

#### Phase 5 — Bonfire 컴포넌트 분리 + 이름 충돌 해소 (D1, D2)

- [x] **5.1** `game_components/hd_player.dart` 의 `HDPlayer` 를 `HDPlayerSprite` 로 클래스명 변경
- [x] **5.2** `presentation/panels/player_sprite.dart` 로 파일 이동
- [x] **5.3** 호출자 갱신 — `views/hd_map_viewport.dart`, `scripting/hd_script_engine.dart` (Party::Move 캐스팅 포함). 도메인 `HDPlayer` (데이터)와 sprite `HDPlayerSprite` 이름 충돌 해소
- [x] **5.4** `views/hd_map_viewport.dart` → `presentation/panels/map_viewport.dart` (`main.dart` import 갱신)

---

#### Phase 6 — 전투 도메인의 UI 결합 끊기 (D3, F1)

- [~] **6.1** `game_components/hd_battle.dart` 의 데이터(BattleState)/룰(BattleEngine) 분리 — 한 클래스에 룰+UI flow가 깊게 얽혀 있어 한 phase에서 분리 어려움. 의존 방향(domain → application/presentation 금지) 정리는 Phase 8과 함께
- [x] **6.2** `HDBattle.showEnemy()`, `addLog`, `clearLogs`, `waitForAnyKey` 모두 `_host` getter (UiHost interface) 통해 호출 (F1)
- [x] **6.3** `await HDGameMain().showMenu(...)` 모두 `_host.showMenu()` 로 치환. `processGameOver` 는 `HDMenuFlows().processGameOver` 로 (F2)
- [x] **6.4** `_selectEnemyUI`, `_modeAssault` 의 메뉴 호출 모두 `_host.showMenu`. `HDGameMain().party` 도 `_party` getter 통해 — HDBattle은 이제 `UiHost` + `HDParty` interface에만 의존

---

#### Phase 7 — 나머지 인프라/스크립트/뷰 이전

- [x] **7.1** `game_components/hd_save_manager.dart` → `application/save_manager.dart`
- [x] **7.2** `game_components/hd_map_loader.dart` → `application/map_loader.dart`
- [x] **7.3** `game_components/hd_select.dart` → `application/select.dart`
- [x] **7.4** `scripting/*` → `application/scripting/*` — `hd_script_engine.dart` → `script_engine_adapter.dart`, `hd_native_script_runner.dart` → `native_script_runner.dart`, `hd_map_script.dart` → `map_script.dart`, `maps/*` 그대로
- [x] **7.5** `views/*` → `presentation/panels/*` (hd_ 접두사 제거: `hd_battle_overlay.dart` → `battle_overlay.dart` 등)
- [~] **7.6** `game_components/` 정리 — `hd_battle.dart`, `hd_game_main.dart` 두 파일 남음. §6.1, §2.11/12 의존방향 정리와 함께 처리
- [x] **7.7** `models/` 디렉토리 — 모든 파일 이전됨, 디렉토리 자동 제거
- [x] **7.8** `views/` 디렉토리 — 모든 파일 이전됨, 디렉토리 자동 제거

---

#### Phase 8 — 검증

- [x] **8.1** `flutter analyze` — error/warning **0**, info 84
- [ ] **8.2** 회귀 시나리오 — **사용자 검증 필요**:
  - 첫 맵 진입
  - 메뉴 열기/닫기
  - 캐릭터 상태 보기
  - 저장/불러오기
  - 전투 시뮬레이션
  - 마법 시전 윈도우
  - 맵 이동/대화 타일/표지판
- [~] **8.3** `domain/` Flutter import 검사 — `foundation.dart` (ChangeNotifier) 3건 허용 / **`material.dart`** 1건 잔여 (`domain/console/console_log.dart` 가 TextSpan 보관 중. raw text + tag로 전환은 §2.5 후속 작업으로)
- [x] **8.4** `application/` 에 `material`/`bonfire`/`flame` import **0건** — 통과
- [x] **8.5** presentation 외부 `HDGameMain` 직접 참조 점검 — `main.dart`(부트/리스너) + `application/*`(facade 사용) 허용 범위. **`domain/magic/magic_system.dart` → `application/magic_system.dart`** 로 이전(UI flow + 도메인 룰 혼재 파일). `domain/` 내 `HDGameMain` 참조 **0건** 확인

---

## 5. 우선순위 5가지 (Phase 매핑)

| 순위 | 작업 | Phase |
|---:|---|---|
| 1 | 입력 라우팅을 `input_dispatcher.dart` 로 분리 | 2.1–2.3 |
| 2 | 콘솔 로그/메뉴를 도메인 + UiHost 인터페이스로 분리 (도메인의 `HDGameMain()` 직접 결합 끊기) | 2.4–2.8, 6.2–6.3 |
| 3 | `HDWindow.handleInput` 모델 밖으로 | 3.1, 3.4 |
| 4 | `HDWorldMap` 의 sight/moonlight/light bit 도메인 추출 | 4.1–4.4 |
| 5 | `game_components/hd_player.dart` → `HDPlayerSprite` 로 개명/이동 | 5.1–5.3 |

## 6. 결론 (재확인용)

- **모델 자체는 데이터로서 잘 빠져있다** — `HDParty`, `HDPlayer`(데이터), `MapModel`, `MapEvent`, `MapUnit` 의 직렬화/도메인 메서드는 다른 view 로 옮길 수 있는 형태.
- **하지만 디렉토리 분류가 의도와 어긋나 있다.** `models/` 에 입력 핸들러, `views/` 에 게임 룰, `game_components/` 에 god object + Bonfire 컴포넌트 + 도메인이 섞여 들어가 있음.
- **가장 큰 결합점은 `HDGameMain`** — 이걸 `domain/console`, `application/menu_flows`, `presentation/input`, `presentation/host` 4개로 쪼개면 "다른 View 렌더링" 요구가 자연스럽게 충족됨.
- 위 디렉토리 트리(`domain/` / `application/` / `presentation/`)로 재구성하면 헤드리스 자동 플레이 테스트, 모바일 풀스크린 변형 UI, 콘솔 텍스트 전용 view 같은 것들이 동일 도메인을 공유하면서 별도 presentation 으로 갈아끼울 수 있는 구조가 된다.
