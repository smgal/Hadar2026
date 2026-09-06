# 제작 에이전트용 사실 브리프 (GROUND TRUTH)

> 이 파일은 기획서 본문이 아니라 **제작·검수 에이전트가 참조하는 내부 자료**다.
> 여기 적힌 코드 사실은 2026-08-30 기준 실측이며, 기획서 본문에서 현황을 서술할 때는
> 반드시 이 내용과 일치해야 한다. 추측으로 코드 사실을 쓰지 말 것.

## 1. 레포 구성 (실측)

```
SMG_hadar2026/
  hadar2026_app/            Flutter 앱 (Bonfire/Flame). lib/ 는 domain/application/presentation 3계층
  packages/cm2_script/      CM2 DSL 파서+인터프리터 (parser.dart 164줄, cm2_script.dart 340줄, ast.dart 30줄)
  cm2_script_sample/        CUI 데모
  tools/                    파이썬 레거시 변환기 + mapEditor (TS/Vite, pnpm)
  tools/mapEditor/          맵 에디터 + AI REST API + MCP 래퍼
  docs/                     기존 문서 (architecture, boot_and_map_loading, cm2_script_manual, key_input_policy, design/*)
  blueprint/                ← 이번 기획서 (본 SSoT)
  REF_hadar/ REF_UNITY_LoreEp1/ REF_FLUTTER_lore2026/   읽기 전용 참조 구현
```

애플리케이션 코드 규모(실측, 줄 수):
- `application/`: battle 538, menu_flows 544, magic_system 280, tile_event_dispatcher 180, game_session 152, save_manager 107, map_loader 94, map_navigation 81, window_manager 46, select 44, game_reload_exception 15
  (2026-09-04 실측: battle **572**. B1 이 `packages/hd_battle` 로 이식했고 이쪽은 B4-03 에서 삭제된다 — 부록 O)
- `application/scripting/`: script_engine_adapter 582, native_script_runner 98, map_script_context 60, map_script 57
- `hd_game_main.dart` 249
- `tools/mapEditor/server/`: ai_api.ts 828, preview.ts 181, store.ts 166, util.ts 27; `mcp/server.mjs` 259

## 2. 계층 규칙 (CI 로 강제됨 — 기획서의 모든 신규 코드 배치안이 지켜야 함)

`.github/workflows/ci.yml` 의 "Check layering invariants" 잡이 아래 두 grep 이 **빈 결과**여야 통과:

```bash
grep -rn "^import.*presentation\|^import.*hd_game_main" lib/application/ lib/domain/
grep -rn "package:flutter/material\|package:bonfire\|package:flame" lib/application/ lib/domain/
```

- `domain/` 허용 Flutter import: `package:flutter/foundation.dart` 뿐 (ChangeNotifier, kIsWeb, kDebugMode).
- `application/` 도 동일. `dart:io` 금지, `services` 금지.
- 따라서 **신규 콘텐츠 런타임(퀘스트/대화 엔진)은 `application/` 아래**, 순수 데이터 모델은 `domain/` 아래에 두어야 하며,
  파일 I/O 는 반드시 `AssetSource` 포트를 통해야 한다.
- CI 는 `flutter analyze --no-fatal-infos` + `flutter test`, cm2 는 `dart analyze`(warning fatal) + `dart test`.
- `dart format` 게이트는 아직 없음(레포가 format-clean 이 아님).

## 3. 포트(Port) 3종 — 헤드리스 하네스의 기존 이음매

`lib/application/ports/`:

- `UiHost` (ui_host.dart) — 추상 메서드 전량:
  `showMenu(items,{initialChoice,enabledCount,clearLogs}) -> Future<int>` (1-based, 0=취소, items[0]은 제목),
  `showWindowMenu(items,{initialChoice,enabledCount,x,y}) -> Future<int>`,
  `showMessageWindow(text,{x,y}) -> Future<void>`,
  `addLog(message,{isDialogue=true}) -> Future<void>`,
  `waitForAnyKey() -> Future<void>`,
  `clearLogs()`, `setHeader(text)`, `beginNarrative()`,
  `endNarrative({summary, autoFlush=true}) -> Future<void>`,
  `refresh()`, `preloadAssets() -> Future<void>`
  + `enum HDConsoleViewMode { progress, overlay }`
- `PartyMovementHost` (movement_host.dart)
- `AssetSource` (asset_source.dart) — `loadString(path)`
- `HDHosts` (host_binding.dart) — 합성 루트. `HDHosts().bind(ui:, movement:, assets:)`, `HDHosts().reset()`.
  bind 전에 포트를 읽으면 StateError.

**중요**: 이 3포트가 이미 존재하므로 "헤드리스 시뮬레이터" 는 신규 발명이 아니라 **기존 이음매의 활용**이다.
기존 예제: `hadar2026_app/test/application/map_navigation_test.dart` 가 in-memory `AssetSource` 페이크로
`MapInfos.json` → `MapModel` 전 경로를 파일시스템 없이 구동한다. 기획서는 이 파일을 "이미 있는 선례"로 인용할 것.

## 4. 타일 이벤트 3티어 디스패치 (실측: application/tile_event_dispatcher.dart)

`HDTileEventDispatcher.check({map, party, host, x, y, isInteraction})`:
1. `_isScriptRunning` 재진입 가드(전역 bool 1개).
2. `HDTileProperties.getUnitAction(map.getUnit(x,y))` 로 `HDTileAction` 결정.
3. `isScriptedAction = isInteraction ? action.isInteractive : action.isStepOn`.
4. scripted 면 `host.beginNarrative()` → `clearLogs()` → `_dispatchScripted()` → finally `endNarrative(autoFlush: pendingNavigation==null)`.
5. scripted 아니고 step 이면 ambient(swamp/lava/water) 처리 — `addLog(isDialogue:false)`.

`_dispatchScripted` 우선순위:
- SIGN 이면 `host.setHeader('@B푯말에 써 있기를:')` 선설정.
- **네이티브 맵 스크립트가 있으면**: `_emitJsonDialog()` 를 *먼저* 내보내고 `native.processMapEvent()` 실행 후 return.
  (즉 네이티브 맵은 JSON 대사가 항상 같이 나옴 = 레거시 동작. 네이티브의 반환 bool 은 현재 소비되지 않음.)
- **cm2 페어링 맵이면**: `setTargetPos(x,y)`, `setScriptMode(action.scriptMode)`, `run()`,
  `HDScriptEngine().handled` (= cm2 의 `Event::Override()` 호출 여부) 가 true 면 return, 아니면 JSON 폴백.
- **둘 다 없으면(레거시)**: JSON 대사 emit + 전역 cm2 체인 run.

`_emitJsonDialog` 는 `map.events` 를 선형 탐색해 (x,y) 일치하는 **첫 이벤트**의 `dialogLines` 를 순서대로 `host.addLog`.
→ 좌표당 이벤트 1개만 유효, 조건 분기 없음, 상태 참조 없음.

## 5. 타일 액션 (domain/map/tile_properties.dart)

`enum HDTileAction { none(0), talk(1), sign(2), event(3), enter(4), water(5), swamp(6), lava(7), cliff(8), move(9) }`
- 괄호 안은 `scriptMode` — cm2 로 넘어가는 **와이어 값**이며 `Enum.index` 가 아님.
  `assets/const.cm2` 의 `FLAG_MAP/FLAG_TALK/FLAG_SIGN/FLAG_EVENT/FLAG_ENTER` 와 대응.
  `test/domain/map/tile_action_test.dart` 가 이 값을 고정한다.
- `isInteractive` = talk|sign|enter (마주보고 확인, 동시에 이동 차단)
- `isStepOn` = event|enter
- `HDTileProperties.getUnitAction(unit)`: `unit.ixEvent & 0x00FF0000` 우선(0x1=event,0x2=talk,0x3=sign,0x4=enter)
  → 없으면 `ixObj1` 의 오브젝트 규칙 → 없으면 `ixTile` 규칙(<56 move, <60 water, <62 swamp, <64 lava, <70 enter, <72 cliff, <128 none, else move).
- `mapType`: TYPE_TOWN 0, TYPE_KEEP 1, TYPE_GROUND 2, TYPE_DEN 3.

## 6. 맵 데이터 실측

- `assets/maps/*.json` 은 RPG Maker MV 포맷. `MapInfos.json` 이 이름 인덱스.
- **현재 MapInfos.json 의 어떤 엔트리에도 `cm2`/`json` 필드가 없다.** (코드는 지원하지만 데이터가 안 씀)
  → 모든 맵이 `Map${id:03d}.json` + `Map${id:03d}.cm2` 규칙으로 해석되고, 해당 cm2 파일이 없으면 로드 실패 로그만 남고 진행.
- MapInfos 등록 이름: Test(1), LORE_EP(2), MAP003(3), TOWN1(4), GROUND1(5), DEN1(6), DEN2(7), Template_TOWN(8),
  Prolog(9), Prolog_B1(10), Prolog_B2(11), Template_DUNGEON(12), LoreContinent(13), CastleLore(14), LastDitch(15).
- 실제 맵 파일과 이벤트 수(실측):
  | 파일 | 크기 | events | displayName |
  |---|---|---|---|
  | TOWN1.json | 100x100 | **0** | 로어성 |
  | GROUND1.json | 100x100 | **0** | 로어 대륙 |
  | DEN1.json | 50x50 | **0** | 메너스 |
  | DEN2.json | 53x53 | **0** | 53x53 |
  | ORIGIN.json | 100x100 | 0 | 로어성 |
  | Map001.json | 4x4 | 0 | 맵이름 |
  | Map002.json | 50x50 | 18 | 맵 |
  | Map003.json | 21x21 | 3 | 작은맵 |
  | Map010.json | 65x82 | 8 | emj_789654.txt |
  | Map011.json | 53x52 | 9 | emj_85371_cave.txt |
  | Map013/014/015.json | 100x100/100x100/75x75 | 0 | 로어 대륙/로어성/라스트디치 |
- 이벤트 name 접두사가 타입 판정: TALK/ENTER/EVENT|EVT/NPC/SIGN → `MapEvent._parseTypeString`.
  단 실제 디스패치는 타일의 `HDTileAction` 이 하고, `MapEvent.type` 은 사실상 미사용.
- `hadarEvent: {kind, payload}` 확장은 **파싱만 되고 디스패치되지 않음**(warp/oneshot 미구현). 맵 에디터 API 는 이미 쓰기를 지원.
- `assets/maps/books.json` 에 weapon 등 아이템 데이터가 있으나 **앱 코드 어디에서도 로드하지 않음**(grep 결과 참조 0건).

## 7. 저장/로드 (application/save_manager.dart)

`saveGame(slot)` 이 SharedPreferences 에 넣는 것: `{version:1, party, gameSystem, gameOption, map}`.
- `gameOption` = `{flags: List<bool>(256), variables: List<int>(256), mapType, scriptFile}`
- **저장되지 않는 것**: `HDNativeScriptRunner.flags`/`.variables` (Map<int,bool>/Map<int,int>),
  `HDScriptEngine.variables`, 현재 맵의 **이름**(맵 데이터 스냅샷만 저장), `currentMapCm2Path`.
- `loadGame` 순서: party → gameSystem → gameOption.scriptFile 로 `loadScript` → flags/variables 덮어쓰기 → map 복원 → 위치 복원 → `mapVersion++` → `HDHosts().ui.refresh()`.
- 성공 로드는 `GameReloadException` 을 던져 현재 실행 루프를 되감고, 스크립트 엔진은 이 예외를 조용히 무시.

## 8. 상태(플래그/변수)의 현재 모습 — **3중 분열**

1. `HDGameOption.flags: List<bool>(256)` / `variables: List<int>(256)` — cm2 의 `Flag::Set/Reset/IsSet`, `Variable::Set/Add/Get` 이 사용. **저장됨.**
2. `HDNativeScriptRunner.flags: Map<int,bool>` / `variables: Map<int,int>` — 네이티브 스크립트용. **저장 안 됨.**
3. `HDScriptEngine.variables` (cm2 엔진 내부) — 맵 전환 시 `loadScript` 가 `clearRuntimeState()` 로 **전부 날림**.

전부 **이름 없는 정수 인덱스**. 의미는 `assets/const.cm2` 나 스크립트 주석에만 존재.

## 9. CM2 언어의 실제 능력/한계 (packages/cm2_script 실측)

문법(parser.dart): 들여쓰기 기반 블록, `if (Cond(...))` / `else`, `#` 주석, `name.method(args)` 형태 지원.
**없는 것: while/for 루프, 함수 정의, 사용자 정의 타입, 문자열 조작(JoinString 제외), 산술은 Add 만.**

내장(cm2_script.dart): 커맨드 `variable`, `include`, `halt`, `Event::Override`, `Context::SetCurrent/Delete/Set`;
함수 `Not/Or/And/Equal/Less/Add/Random/ScriptMode/JoinString/Context::Get/Context::GetCurrent`.

Hadar 등록 커맨드(script_engine_adapter.dart, 실측 전량):
`Talk, Log, SetHeader, Answer, PressAnyKey, Map::Init, Map::SetTile, Map::SetRow, Select::Init, Select::Add,
Select::Run, LoadScript, Map::LoadFromFile, Battle::Init, Battle::RegisterEnemy, Battle::ShowEnemy, Battle::Start,
Map::SetStartPos, Map::ChangeTile, WarpPrevPos, Flag::Set, Flag::Reset, Variable::Set, Variable::Add,
Player::ChangeAttribute, Enemy::ChangeAttribute, Player::AssignFromEnemyData, Party::PosX, Party::PosY,
Party::PlusGold, Party::Move, Map::SetType, Map::SetEncounter, DisplayMap, DisplayStatus, Wait, TextAlign,
Tile::CopyTile, Tile::CopyToDefaultTile, Tile::CopyToDefaultSprite,
Item::Give, Item::Take,                                    ← 2026-09-03 G1-08
GameOver, Player::ApplyAttribute, Player::ReviseAttribute,
Map::SetLightArea, Map::ResetLightArea`                    ← 2026-09-03 G2-02

Hadar 등록 함수: `Flag::IsSet, Variable::Get, On, OnArea, Battle::Result, Select::Result, Party::PosX, Party::PosY,
Player::GetName, Player::GetGenderName, Player::GetAttribute, Player::IsAvailable,
Item::Has,                                                 ← 2026-09-03 G1-08
Party::CheckIf`                                            ← 2026-09-03 G2-02

**침묵 실패 모드(중요 — AI 생성 타깃으로 부적합한 근거)**:
- 미등록 커맨드 → "Unknown command" 출력 후 스킵
- 미등록 함수 → "Unknown function" 출력 후 **0 반환** → 조건문이 조용히 오분기
- `loadFromString()` 은 init 단계에서 `variable`/`include`/`.assign` 실행, `run()` 은 `variable`/`include` 만 건너뛰고
  **모든 `.assign` 을 매 실행마다 재실행** → 메인 스크립트 상단의 `score.assign(0)` 은 매 루프마다 상태를 지움.
- 맵 전환 시 per-map cm2 로드가 엔진 전역을 전부 날림.

## 10. 파티/플레이어/전투 실측

- `HDParty`: `PartyPosition{x,y,xPrev,yPrev,faced,isMoving}`, `PartyInventory{food=100, gold=500}`,
  `PartyBuffs{magicTorch, levitation, walkOnWater, walkOnSwamp, mindControl, penetration, canUseEsp, canUseSpecialMagic}`,
  `maxEnemy=3`, `encounter=3`, `players: List<HDPlayer>(6)` (0번 "슴갈" 에스퍼, 1번 "유리" 초능력자, 2~5 빈 슬롯).
- **인벤토리는 food/gold 정수 2개가 전부.** 아이템 목록 없음.
- `HDPlayer.weapon/shield/armor` 는 **정수 ID 1개씩**이고 이름은 `getWeaponName() => weapon==0 ? "맨손" : "무기$weapon"` 하드코딩 플레이스홀더.
- 클래스: 0 에스퍼 / 1 싸이보그 / 2 초능력자.
- exp 테이블 21단계(0,0,1500,6000,20000,50000,150000,250000,500000,800000,...,5100000), 레벨업 시 스탯 성장식 존재.
- 적 데이터 `domain/battle/enemy_data.dart` 에 **75종**(id 0~74) 하드코딩 테이블.
  (초판은 76종이라 적었다 — 부록 B-1 이 정정했고, 이 줄은 2026-09-04 에 뒤늦게 맞췄다.)
- 퀘스트/저널/목표 관련 코드는 **레포 전체에 0건**(grep "quest" 결과 없음).

## 11. 맵 에디터 AI API (tools/mapEditor) — 확장의 기반

dev 서버 `http://localhost:5310` (`pnpm dev`), `GET /api/ai` 가 AI_GUIDE.md 전문을 반환. MCP 래퍼 `mcp/server.mjs`.

엔드포인트(실측): `GET /api/ai/current`, `GET /api/ai/maps`, `POST /api/ai/maps`(생성, `registerAs` 로 MapInfos 등록),
`GET /api/ai/maps/{file}`(요약), `/region`, `/passability`, `/validate`, `/preview.png`(야간/광원/이벤트 테두리 옵션),
`POST /api/ai/maps/{file}/edit`(ops 배치: set/rect/fill/setCells/resize/setDisplayName),
이벤트 CRUD `GET|POST /events`, `PATCH|DELETE /events/{id}`, `GET /api/ai/palette`, `GET /api/ai/tile.png?a5=|b=`.

레이어 규약: ground(z0, `1536+A5index`), ground2(z1 미사용), objLower(z2 장식), objUpper(z3 **통행 판정**),
shadow(z4 사분면 비트 0~15, 0=항상 밝음/15=야간 완전 어둠), region(z5, 게임이 ixEvent 로 읽음).
A5 인덱스: 0~55 MOVE, 56~59 WATER, 60~61 SWAMP, 62~63 LAVA, 64~69 ENTER, 70~71 CLIFF, 72~127 BLOCK.
B 타일: 1~63 BLOCK, 64~87 MOVE, 88~95 MOVE(애니), 96~111 BLOCK, 112~123 SIGN, 124~127 ENTER, 128~143 TALK, 144~239 MOVE, 240~255 예약.

**이 API 는 이번 기획의 콘텐츠 서버가 따라야 할 선례다**: 배치 편집, validate, 미리보기, 힌트 포함 에러(`{error, hint}`), MCP 래퍼.

## 12. 기타 실측 사실

- UI 는 800x480 고정 픽셀 레이아웃 + FittedBox 스케일. 뷰포트: 맵(0,0/288x320), 콘솔(288,0/512x320),
  상태(0,320/800x160... 실제 statusPanel 288x160 + inputPanel 512x160), 하단 컨트롤, `HDWindowLayer` 오버레이.
- `HDConfig`: tileSize 32, maxFlags 256, maxVariables 256, maxLinesPerPage 13, maxProgressLines 200,
  startupScript `assets/startup.cm2`.
- 입력 모드 `HDInputMode {window, menu, dialogue, map}` 우선순위 해석, 전역 키 핸들러는 `HDInputDispatcher`.
- 테스트 현황: `test/domain/party/party_actions_test.dart`, `domain/lighting/sight_calculator_test.dart`,
  `domain/console/text_utils_test.dart`, `domain/console/console_log_test.dart`, `domain/map/map_event_test.dart`,
  `domain/map/tile_action_test.dart`, `presentation/host/flutter_ui_host_test.dart`,
  `application/map_navigation_test.dart`. 위젯 테스트 없음.
- flame 1.35.1 (dependency_overrides), bonfire 3.16.1 고정 — 올리지 말 것.

---

# 부록 A — 제작 중 발견된 선행 버그 (2026-08-30 검증 완료)

아래 4건은 기획 작업 중 발견되어 **메인이 직접 코드로 재확인한 사실**이다. 이후 모든 장은 이를 전제로 삼을 것.

## A-1 모든 등록 맵에 존재하지 않는 cm2 경로가 무조건 부여된다
`hadar2026_app/lib/application/map_navigation.dart:43` 이 `cm2Path = 'Map$idStr.cm2'` 를 **무조건** 설정한다.
`MapInfos.json` 에 `cm2` 필드가 하나도 없으므로(§6), 모든 맵이 `Map004.cm2` 같은 **존재하지 않는 파일**을 페어링 cm2 로 갖는다.
→ `HDGameSession.loadMapFromFile` 이 그 경로로 `loadScript` 를 호출하고, 실패한다.

## A-2 cm2 로드 실패가 엔진 상태를 누수시킨다
`hadar2026_app/lib/application/scripting/script_engine_adapter.dart:92-99`:
```dart
Future<void> loadScript(String assetPath) async {
  String content;
  try {
    content = await HDHosts().assets.loadString(assetPath);
  } catch (e) {
    print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
    return;                      // ← clearRuntimeState() 없이 반환
  }
```
로드 실패 시 `_engine.clearRuntimeState()` 에 도달하지 못하므로 **직전 맵의 스크립트와 변수가 그대로 남는다**.
A-1 과 합쳐지면: 맵을 옮겨도 이전 맵의 cm2 가 계속 실행되는 상태가 정상 동작처럼 보인다.
→ 티어 판정(`currentMapCm2Path != null`)이 사실상 항상 참이므로 **디스패치 3티어 중 cm2 티어가 항상 선택된다**.

## A-3 네이티브 맵 스크립트의 상태 분기는 한 번도 동작한 적이 없다
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
`HDMapScript` 의 플래그 API 가 **미구현 스텁**이다. `HDNativeScriptRunner` 에는 실제 구현(`isFlagSet`/`setFlag`)이 있으나
맵 스크립트는 자기 자신의 스텁을 호출한다. → 네이티브 맵의 모든 조건 분기가 항상 `false` 로 평가된다.
D-16-3("조건부 대화 필요")의 직접 근거.

## A-4 에셋 선언이 비재귀다
`hadar2026_app/pubspec.yaml` 의 `flutter.assets` 는 `assets/`, `assets/images/`, `assets/maps/`, `assets/fonts/` 를 열거한다.
Flutter 의 디렉토리 선언은 **하위 디렉토리를 포함하지 않는다.** 따라서 D-03 의
`assets/content/**` 는 **모든 하위 디렉토리를 명시적으로 열거**해야 번들에 실린다.
소스 JSON 을 웹 페이로드에서 빼려면 `assets/content/build/` 만 선언하는 선택도 가능하다(BP-30/35 에서 결정).

# 부록 B — 2차 발견 사실 (2026-08-30 메인 검증 완료)

## B-1 **[해소됨 2026-09-03]** 적 데이터는 76종이 아니라 **75종**이며, 그중 하나는 소환 불가였다

> **2026-09-03 (P0-15)**: `battle.dart` 의 `registerEnemy` 가드가 `<= 0` → `< 0` 으로 바뀌어
> **id 0(`Orc`) 을 포함한 75종 전량이 소환 가능**하다. 범위 밖 인자는 경고 로그를 남긴다.
> → BP-21/22/23/42 의 "74종(id 1~74) 기준" 서술은 **75종(id 0~74)** 으로 고쳐야 한다.
> 고정 테스트: `test/domain/battle/enemy_table_test.dart`.
>
> 아래는 원래 기록이다.
`hadar2026_app/lib/domain/battle/enemy_data.dart:33` 의 `const List<HDEnemyData> enemyTable` 은
**75개 엔트리**(id 0~74)를 갖는다. (`grep -c "EnemyData("` 가 76을 반환하는 것은 16번 줄의 생성자 선언이 함께 잡히기 때문.)
`hadar2026_app/lib/application/battle.dart:43-46`:
```dart
void registerEnemy(int enemyTableId) {
  if (enemyTableId <= 0 || enemyTableId >= enemyTable.length) return;
  enemies.add(HDEnemy(enemyTable[enemyTableId]));
}
```
`<= 0` 가드 때문에 **id 0 (`Orc`) 은 cm2/콘텐츠에서 영원히 소환할 수 없다.** 실제 사용 가능한 적은 **id 1~74, 74종**.
→ §10 의 "76종" 서술은 폐기. BP-21/22/23/42 는 **74종(id 1~74)** 기준으로 쓸 것.

## B-2 **[해소됨 2026-09-03]** 전투 결과 코드가 cm2 상수와 **정반대**로 매핑되어 있었다

> **2026-09-03 (P0-12)**: `assets/const.cm2` 를 정본으로 삼고 Dart 를 맞췄다.
> `domain/battle/battle_result.dart` 의 `HDBattleResult` 가 와이어 값을 명시로 들고
> (`evade` 0 · `win` 1 · `lose` 2), `battle.dart` 에서 정수 리터럴 비교가 사라졌다.
> `const.cm2` 는 **수정하지 않았다.** 고정 테스트: `test/domain/battle/battle_result_test.dart`.
>
> 아래는 원래 기록이다.
`hadar2026_app/lib/application/battle.dart:27` — `int _battleResult = 1; // 1: Win, 0: Lose, 2: Run away`
`hadar2026_app/assets/const.cm2:53-55` — `BATTLERESULT_EVADE=0`, `BATTLERESULT_WIN=1`, `BATTLERESULT_LOSE=2`

| 값 | Dart 의미 | cm2 상수 의미 | 일치 |
|---|---|---|---|
| 0 | Lose | EVADE(도주) | **불일치** |
| 1 | Win | WIN | 일치 |
| 2 | Run away | LOSE(패배) | **불일치** |

`Battle::Result()` 로 분기하는 cm2 스크립트는 패배와 도주를 뒤바꿔 처리한다. 콘텐츠 런타임의
`battle_won` / 전투 결과 조건을 설계할 때 **어느 쪽을 정본으로 삼을지 먼저 정해야 한다**(BP-27 결정 사항).

## B-3 헤드리스 하네스의 진짜 장벽은 포트가 아니라 **상호작용 코드의 위치**
타일 상호작용의 트리거가 `application/` 이 아니라 **Bonfire 스프라이트의 `update(dt)` 폴링** 안에 있다:
`hadar2026_app/lib/presentation/panels/player_sprite.dart:103` `void update(double dt)`,
같은 파일 `:193`, `:362`, `:405` 에서 `HDGameMain().checkTileEvent(...)` 를 직접 호출.

→ `UiHost`/`AssetSource` 포트를 페이크로 바꿔도 **이동과 상호작용 자체를 헤드리스로 구동할 수 없다.**
BP-27/BP-34 는 "이동·상호작용 루프를 `application/` 으로 추출" 을 **선결 과제**로 잡아야 한다.
(현재 `PartyMovementHost` 포트는 애니메이션 위임용이지 이동 판정 소유자가 아니다.)

## B-4 `application/menu_flows.dart` 가 `dart:io` 를 쓰고 `exit(0)` 를 호출한다

`hadar2026_app/lib/application/menu_flows.dart:2` `import 'dart:io';`
같은 파일 `:504`, `:522`, `:540` 에서 `exit(0)`.

**⚠ 정정 (2026-08-30, 실빌드로 검증)**: 초판 B-4 는 "`dart:io` 때문에 웹 빌드가 깨져 있을 것" 이라고 추정했다.
**이 추정은 틀렸다.** `flutter build web --release` 를 실제로 실행한 결과 **성공**했다
(Flutter 3.41.4, 컴파일 16.5초, exit code 0, 산출물 `build/web` 생성).
`dart:io` import 자체는 웹 빌드를 막지 않는다. 아래 세 항목 중 **2번은 폐기**하고 나머지만 유효하다.

유효한 문제:
1. **계층 위반** — CLAUDE.md 는 `application/` 에서 `dart:io` 금지를 명시하지만, CI 의 grep 2종은
   `flutter/material`·`bonfire`·`flame`·`presentation`·`hd_game_main` 만 검사하므로 **잡히지 않는다**. (유효)
2. ~~웹 빌드 파손~~ — **폐기.** 실빌드 성공으로 반증됨.
3. **헤드리스 하네스 파괴** — `exit(0)` 는 시뮬레이터 프로세스를 통째로 죽인다. BP-34 의 선결 과제. (유효)
4. **[신규·미확인] 웹 런타임 동작** — 빌드는 되지만 웹에서 `exit(0)` 가 호출될 때의 실제 동작은 확인하지 않았다.
   `dart:io` 의 프로세스 제어는 웹에서 지원되지 않으므로 해당 메뉴 항목이 런타임 오류를 낼 가능성이 있다.
   **브라우저에서 그 메뉴를 실제로 눌러 확인해야 한다.** 빌드 성공은 이 항목을 보증하지 않는다.

→ 조치: CI 계층 grep 에 `dart:io` 추가(D-23)는 **계층 규율** 근거로 여전히 타당하다.
   단 "웹 빌드가 깨진다" 를 근거로 쓰지 말 것.

## B-5 웹 페이로드 실측 (2026-08-30)
`flutter build web --release` 산출물 **총 45MB**:

| 구성 | 크기 | 비고 |
|---|---|---|
| `canvaskit/` | 31MB | Flutter 웹 렌더러. 여러 변종을 포함하며 실제 전송은 그중 일부 |
| `assets/assets/` | 9.7MB | 게임 자산(맵 1.2MB + 이미지 1.3MB + cm2 등) |
| `assets/NOTICES` | 1.3MB | 라이선스 |
| 나머지 | ~3MB | JS/폰트/셰이더 |

→ BP-35 의 번들 크기 목표는 **이 실측치를 기준선으로** 잡아야 한다.
콘텐츠 팩이 추가하는 용량은 현행 자산 9.7MB 대비 상대적으로 평가할 것.
부록 A-4(에셋 선언 비재귀)와 함께 보면, `assets/content/` 의 **소스 JSON 을 웹 페이로드에서 빼는** 선택이
실질적 이득인지 여부도 이 수치로 판단해야 한다(소스가 수 MB 가 아니라면 이득이 작다).

# 부록 C — 세이브/결정론 실측 (2026-08-30 메인 검증 완료)

## C-1 `MapModel.toJson()` 이 `events` 를 저장하지 않는다 → 로드 후 JSON 대사 티어가 영구 사망
`hadar2026_app/lib/domain/map/map_model.dart:50-58`:
```dart
Map<String, dynamic> toJson() {
  return {
    'width': width, 'height': height,
    'data': data.map((u) => u.toJson()).toList(),
    'handicapData': handicapData.toList(),
    'tileOverrides': tileOverrides.map((k, v) => MapEntry(k.toString(), v)),
  };            // ← 'events' 없음
}
```
`MapModel.fromJson` 도 `events` 를 복원하지 않으므로 **세이브를 로드한 순간 `map.events` 는 빈 리스트**가 된다.
`HDTileEventDispatcher._emitJsonDialog` 는 `map.events` 를 순회하므로 **3티어 중 JSON 대사 티어가 통째로 무력화**된다.
→ Map002(18개)·Map003(3개)·Map010(8개)·Map011(9개)의 정적 대사는 세이브 로드 후 전부 사라진다.

## C-2 세이브 로드가 네이티브 맵 스크립트를 붙이지 않는다
`hadar2026_app/lib/application/save_manager.dart:86` 은 `session.setNewMap(loadedMap)` 을 **직접** 호출한다.
네이티브 스크립트 스왑(`onUnload` → `mapScriptFactory` → `onPrepare`/`onLoad`)은
`hadar2026_app/lib/application/game_session.dart:117-128`, 즉 **`loadMapFromFile` 안에만** 있다.
→ 세이브 로드 경로는 그 코드를 타지 않으므로 `currentMapScript` 가 **직전 맵의 것으로 남거나 null 이 된다.**
`currentMapCm2Path` 도 갱신되지 않는다.

## C-3 맵 스냅샷 세이브가 웹 저장 한계에 근접한다
`hadar2026_app/lib/domain/map/map_unit.dart` 의 `toJson()` 은 칸마다
`{"ixTile":N,"ixObj0":N,"ixObj1":N,"shadow":N,"ixEvent":N}` 을 만든다 — 최소 **~57바이트/칸**.
100×100 맵 = 10,000칸 → **약 570KB**(값이 커지면 더 큼). 슬롯 4개면 2MB 이상.
브라우저 `localStorage` 는 통상 5MB 이고 UTF-16 저장이라 실질 여유는 그 절반이다.
→ 맵 전체 스냅샷 대신 **원본 대비 델타(`mapDelta`)만 저장**하는 방식이 선택이 아니라 필수.

## C-4 결정론 위반 실측
- `hadar2026_app/lib/domain/party/player.dart:71` —
  `damaged(20 + (DateTime.now().millisecondsSinceEpoch % 20));` **벽시계로 데미지 결정**.
  `HDParty.timeGoes()` 가 독 상태에서 이를 호출하므로 이동마다 발동 가능.
- `hadar2026_app/lib/application/battle.dart` — 시드 없는 `Random()` **14곳**.
- 위 둘 때문에 현재 게임은 **동일 입력 재현이 불가능**하다. 골든 회귀 테스트(D-15)의 선결 과제.

# 부록 D — 맵 이름 해석 파손 (2026-08-30 메인 검증 완료)

## D-1 `MapInfos.json` 등록 이름 15개 중 **7개가 존재하지 않는 파일로 해석**된다

`hadar2026_app/lib/application/map_navigation.dart:30-51` 의 해석 순서:
```dart
String resolvedJsonName = '$searchName.json';      // ← 폴백을 먼저 설정
...
for (var info in mapInfos) {
  if (info != null && info['name'] == searchName) {
    resolvedJsonName = 'Map$idStr.json';           // ← 폴백을 덮어씀
    ...
```
`MapInfos.json` 에 `json` 필드가 하나도 없으므로(§6), 이름이 인덱스에 **있으면** 무조건 `Map{id:03d}.json` 이 된다.

| 이름 | id | 해석 결과 | 파일 존재 | `<이름>.json` 존재 | 판정 |
|---|---|---|---|---|---|
| Test | 1 | Map001.json | Y | N | OK |
| LORE_EP | 2 | Map002.json | Y | N | OK |
| MAP003 | 3 | Map003.json | Y | Y | OK |
| **TOWN1** | 4 | Map004.json | **N** | **Y** | **깨짐** |
| **GROUND1** | 5 | Map005.json | **N** | **Y** | **깨짐** |
| **DEN1** | 6 | Map006.json | **N** | **Y** | **깨짐** |
| **DEN2** | 7 | Map007.json | **N** | **Y** | **깨짐** |
| Template_TOWN | 8 | Map008.json | N | N | 깨짐 |
| Prolog | 9 | Map009.json | N | N | 깨짐 |
| Prolog_B1 | 10 | Map010.json | Y | N | OK |
| Prolog_B2 | 11 | Map011.json | Y | N | OK |
| Template_DUNGEON | 12 | Map012.json | N | N | 깨짐 |
| LoreContinent | 13 | Map013.json | Y | N | OK |
| CastleLore | 14 | Map014.json | Y | N | OK |
| LastDitch | 15 | Map015.json | Y | N | OK |

**핵심 역설**: TOWN1/GROUND1/DEN1/DEN2 는 `TOWN1.json` 등 **동명 파일이 실제로 존재**한다.
이름이 `MapInfos.json` 에 **등록되어 있지 않았다면 폴백이 살아남아 정상 로드되었을 것**이다.
즉 **인덱스에 등록하는 행위가 맵을 로드 불가로 만든다.**

## D-2 로드 실패가 실패로 보고되지 않는다
A-1 때문에 `cm2Path` 는 항상 non-null 이다. `map_navigation.dart:66-73` 은
JSON 로드 실패 시 `cm2Path == null` 일 때만 에러를 반환하므로, **항상 `json: null` 인 `MapBundle` 을 "성공" 으로 반환**한다.
`HDGameSession.loadMapFromFile:97-99` 은 `bundle.json != null` 일 때만 `setNewMap` 을 호출하므로
**맵은 바뀌지 않은 채 스크립트만 교체되고, 함수는 `true`(성공)를 반환**한다.

→ 부록 A-1·A-2 와 합쳐, 현재 맵 전환 시스템은 **실패를 성공으로 보고하며 이전 맵 위에 새 스크립트를 얹는다.**
BP-26 의 앵커·warp 검증, BP-22 의 places 매핑, BP-34 의 시뮬레이터는 전부 이 문제의 해결(T-22-1: `MapInfos.json` 에
`json` 필드 추가 또는 폴백 우선순위 반전)에 의존한다.

# 부록 E — RPG Maker MV 이벤트 명령 실측 (2026-08-30 메인 검증 완료)

`hadar2026_app/assets/maps/Map0*.json` 전체를 훑어 실제로 등장하는 명령 코드는 **3종뿐**이다:

| code | 출현 | 실제 파라미터 예시 | 의미 |
|---|---|---|---|
| 0 | 38회 | `[]` | 리스트 종료 표식 |
| 101 | 25회 | `['', 0, 0, 2]` | **대화창 설정** = `[faceName, faceIndex, background, positionType]` |
| 401 | 31회 | `['저에게 말고 윗분에게 말씀을 걸어 주세요.']` | 대사 본문 1줄 |

## E-1 `code 101` 은 텍스트 헤더가 **아니다**
`101` 은 뒤따르는 `401` 들의 **표시 방식**(얼굴 그림 이름/인덱스, 배경 종류, 창 위치)을 지정하는 헤더 명령이지
표시될 텍스트를 담지 않는다. 실측 파라미터가 `['', 0, 0, 2]` 인 것이 근거 — 첫 요소가 빈 문자열(faceName)이다.
→ "101 → `Node.header`" 로 대응시키는 서술은 **오류**다. `Node.header`(BP-24)는 MV 계보가 아니라
본 기획서의 독자 개념이며, 근거는 `tile_event_dispatcher.dart:116` 의 `setHeader('@B푯말에 써 있기를:')` 이다.
`hadar2026_app/lib/domain/map/map_event.dart:79` 가 `code == 401` 만 읽고 `101` 을 통째로 버리는 것은
**의도적으로 옳은 동작**이다(얼굴 그림 시스템이 없으므로).

## E-2 `pages` 선택 규칙이 본 기획서의 `entry` 와 **정반대**다
- RPG Maker MV: 조건을 만족하는 페이지 중 **번호가 가장 큰 것**을 고른다(뒤에서부터 탐색).
- 본 기획서 `Dialogue.entry[]`(BP-24, D-07): **위에서부터 첫 번째 참**을 고른다.

현재 레포의 모든 이벤트는 `pages` 가 1개뿐이라(실측) 당장의 차이는 없다.
그러나 **MV 에디터로 저작된 다중 페이지 데이터를 이관할 때 분기 의미가 역전**된다.
→ BP-24 §10(레거시 변환)과 BP-28(이관)은 변환 시 **페이지 순서를 뒤집어야** 함을 명시해야 한다.

## E-3 cm2 는 튜링 완전이 아니다
`packages/cm2_script/lib/src/parser.dart` 에는 루프도 함수 정의도 없다(§9). 따라서
"cm2 는 튜링 완전이라 정적 검증이 불가능하다" 는 논거는 **성립하지 않는다.**
D-02(선언적 데이터 채택)의 실제 근거는 튜링 완전성이 아니라 §9 에 실측된 것들이다:
미등록 함수가 0을 반환해 조용히 오분기 · 맵 전환 시 전역 소실 · `.assign` 재실행 · 스키마 부재.
이 논거들만으로 D-02 는 충분히 정당화되므로 **결정은 유지**하되, 근거 문장은 정정할 것.

# 부록 F — 3차 검증 (2026-08-30 메인 검증 완료)

## F-0 §9 의 등록 심볼 수는 **정확하다** (재확인)
`grep -c "e.registerCommand('"` = **40**, `grep -c "e.registerFunction('"` = **12**.
§9 의 목록이 정본이다. (BP-10 이 43/11 로 센 것은 오류.)

> **2026-09-03 갱신 (G1-08 · G2-02 완료)**: 현재 값은 **47 / 14** 다.
> - G1-08 — `Item::Give`·`Item::Take`(커맨드) · `Item::Has`(함수) → 42 / 13
> - G2-02 — `GameOver`·`Player::ApplyAttribute`·`Player::ReviseAttribute`·
>   `Map::SetLightArea`·`Map::ResetLightArea`(커맨드) · `Party::CheckIf`(함수) → **47 / 14**
>
> `Item::Has` 와 `Party::CheckIf` 는 **반드시 함수**여야 한다 — 커맨드로 등록하면
> 아래 침묵 실패 모드(미등록 함수 → 0 반환)와 같은 결과가 되어 조건이 조용히 오분기한다.
특기: `Party::PosX`/`Party::PosY` 는 **커맨드(no-op)와 함수 양쪽에 동시 등록**되어 있다
(`script_engine_adapter.dart:418-419` 와 `:545-546`). 커맨드 쪽은 빈 구현이다.

## F-1 등록 커맨드의 범위 밖 인자가 **조용히 무시**된다 (§9 의 침묵 실패 계열 확장)
`script_engine_adapter.dart:362-391`:
```dart
e.registerCommand('Flag::Set', (stmt, eng) async {
  ...
  if (idx >= 0 && idx < HDConfig.maxFlags) {
    flags()[idx] = true;
  }              // ← else 없음
});
```
`Flag::Set` / `Flag::Reset` / `Variable::Set` / `Variable::Add` 전부 **범위 검사에 else 가 없다.**
`Flag::Set(300)` 은 아무 일도 하지 않고 아무 로그도 남기지 않는다.
`Battle::RegisterEnemy(0)` 도 같은 계열이다(`battle.dart:44` 의 `<= 0` 가드, 부록 B-1).

→ §9 가 기록한 "미등록 심볼의 침묵 실패" 와 **원인이 다른 별개 계열**이다.
전자는 오타로 생기고, 후자는 **정상 문법·정상 심볼인데 값이 범위 밖**일 때 생긴다.
이름 있는 상태 키(D-04)를 채택해야 하는 직접적 근거 — 정수 인덱스에는 "범위 밖" 이라는 실패 양식이 내재한다.

## F-2 네이티브 맵 스크립트가 **지오메트리 없는 맵에 바인딩**된다
`hadar2026_app/lib/application/game_session.dart:97-128`:
```dart
if (bundle.json != null) {
  setNewMap(bundle.json!);      // ← json 이 null 이면 맵은 그대로
}
...
final factory = native.mapScriptFactory[bundle.mapName];
if (factory != null) {          // ← 이 블록은 json 유무와 무관하게 실행
  native.currentMapScript = factory();
  native.currentMapScript!.onPrepare();
  native.currentMapScript!.onLoad(bundle.mapName, 0, 0);
}
```
부록 D 와 합치면: `TOWN1` 로드 시 `Map004.json` 이 없어 `bundle.json == null` 이지만
`mapScriptFactory['TOWN1']` 은 존재하므로 **`Town1MapScript` 가 직전 맵 위에 부착**된다.
그 스크립트의 `isOn(x,y)` 는 **다른 맵의 좌표**를 상대로 평가된다.
부록 A-3(플래그 스텁)과 **원인이 독립적**이므로 A-3 을 고쳐도 이 문제는 남는다.

## F-3 **[해소됨 2026-09-03]** `Battle::Result()` 는 전투를 하지 않아도 승리를 반환했다

> **2026-09-03 (P0-13)**: `HDBattleResult.none`(와이어 **-1**)이 추가되어 `init()`·`start()` 진입이
> 그것으로 초기화된다. cm2 의 `BATTLERESULT_*`(0·1·2)와 겹치지 않으므로 콘텐츠는
> **어느 분기도 타지 않는다** — 그것이 "결과 없음" 의 올바른 표현이다.
> `gotoEndBattle` 은 `switch` 라 값 누락이 컴파일 에러가 된다.
> `assets/const.cm2` 에 상수를 추가하지 **않았다**.
>
> 아래는 원래 기록이다.
`hadar2026_app/lib/application/battle.dart:27` — `int _battleResult = 1; // 1: Win`.
`HDBattle().init()` 도 `_battleResult = 1` 로 되돌린다(`:38`).
→ cm2 가 `Battle::Start` 없이 `Battle::Result()` 를 읽으면 **항상 승리**다.
부록 B-2(0/2 의미 역전)와 합쳐, 전투 결과 계약 전체를 BP-27 이 재정의해야 한다.

## F-4 `ORIGIN.json` 은 정상 로드된다 (부록 D 의 역설을 확증)
`ORIGIN` 은 `MapInfos.json` 에 **등록되어 있지 않다.** 따라서 `map_navigation.dart:30` 의
폴백 `'$searchName.json'` 이 살아남아 `ORIGIN.json` 이 실제로 로드된다.
등록된 `TOWN1`/`GROUND1`/`DEN1`/`DEN2` 는 로드되지 않는다. **등록이 손해라는 부록 D-1 의 직접 증거.**

# 부록 G — 집계 정정 및 추가 (2026-08-30)

## G-1 부록의 검증 사실은 20건이 아니라 **21건**이다
A-1~A-4(4) + B-1~B-4(4) + C-1~C-4(4) + D-1~D-2(2) + E-1~E-3(3) + F-1~F-4(4) = **21건**.
(F-0 은 기존 수치의 재확인이므로 별건으로 세지 않는다.)
이 중 **E-1·E-3 두 건은 코드 결함이 아니라 기획서 서술 정정**이다. 나머지 19건이 코드/데이터 문제다.
로드맵·태스크 분해는 21건 전부에 대응 태스크를 가져야 한다.

## G-2 `TOWN2` 는 맵 없이 스크립트만 등록되어 있다
`hadar2026_app/lib/application/scripting/native_script_runner.dart:25-30` 의 `mapScriptFactory` 는
`'TOWN1'`, `'GROUND1'`, `'TOWN2'`, `'DEN1'` 4종을 등록한다.
그러나 `TOWN2` 는 `MapInfos.json` 에 **등록되어 있지 않고** `assets/maps/TOWN2.json` **파일도 없다**.
→ `Town2MapScript` 는 `mapScriptFactory[bundle.mapName]` 조회에 걸릴 수 없으므로 **한 번도 실행된 적이 없는 코드**다.
부록 F-2(json 없이도 네이티브 부착)와 달리 이쪽은 **이름 자체가 도달 불가**다.

# 부록 H — 장비·전투 규칙 실측 (2026-08-30 메인 검증 완료)

## H-1 **[정정됨]** 죽은 장비 필드는 `powOfShield` / `powOfArmor` **2개뿐**이다

> **초판 오류 (2026-08-30 정정)**: 초판은 `powOfWeapon`/`powOfShield`/`powOfArmor` **3개 모두**가 죽은 필드라고
> 적었다. **틀렸다.** 원인은 조정자가 `grep -rn "powOfShield\|powOfArmor"` 만 실행하고
> 그 결과로 `powOfWeapon` 까지 일반화한 것이다. **검색하지 않은 것을 결론에 포함시켰다.**

### 실제 (전수 확인)

`powOfWeapon` 은 **플레이어 공격력으로 실제로 읽힌다** — `hadar2026_app/lib/application/battle.dart:439`:
```dart
int damage = (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;
damage -= (damage * Random().nextInt(50)) ~/ 100;      // :440  0~49% 감쇠
damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10;   // :441  적 방어
```

`powOfShield` / `powOfArmor` 는 **읽는 곳이 0곳**이다. 등장하는 곳은 전부 대입·직렬화·속성 스위치뿐:
`party.dart:107,129`(초기값), `player.dart:50,134,136,293,294,358,361,426,427`.

**방어는 양쪽 모두 `ac` 하나로만 계산된다**:
- 플레이어가 맞을 때 — `battle.dart:514`: `damage -= (t.ac * t.level.physical * (rand(10)+1)) ~/ 10;`
- 적이 맞을 때 — `battle.dart:441`: `damage -= (t.ac * t.level * (rand(10)+1)) ~/ 10;`
  (플레이어는 `level.physical`, 적은 `level` — 타입이 다르다)

### 파급
- **무기는 이미 작동한다.** 아이템의 무기 성능을 `powOfWeapon` 에 넣으면 **전투식을 고치지 않아도** 반영된다.
- **방어구·방패는 작동하지 않는다.** 아이템 성능을 `ac` 로 합산해 넣는 방식이면 전투식 변경이 **불필요**하고,
  방패를 별개 축으로 두거나 부위별 감쇠·속성 상성을 도입하려면 **그때만** 전투식 변경이 필요하다.
- 즉 "장비를 쓰려면 전투식 변경이 선행" 이라는 초판 서술은 **과장**이었다. 선행 과제는 **선택한 설계 갈래에 달려 있다.**

## H-2 **[구 전투식 기준 · 2026-09-05]** `books.json` 의 ac 10/20 은 전투를 "무효화" 하지 않는다

> **이 표는 `hadar2026_app/lib/application/battle.dart` 의 전투식 기준이다.**
> B2 가 방어를 부위별로 쪼개고 방패를 별 축으로 옮겼으므로(B2-08),
> 새 전투의 대역은 **부록 U** 를 볼 것. 물리 피해식 자체는 바뀌지 않아
> Troll 수치는 그대로 재현되지만, `ac` 에 들어가는 값의 의미가 달라졌다.

> **초판 오류 (2026-08-30 정정)**: 초판은 "ac 10/20 은 초반 전투를 통째로 무효화한다" 고 적었다.
> **과장이었다.** 실제 확률을 계산하지 않고 최댓값만 비교한 결과다.

`battle.dart:513-514` 의 식으로 10×10 = 100가지 난수 조합을 전수 계산한 결과
(적 `Troll` id 1: strength 9, level 1 / 플레이어 level.physical 1):

| 플레이어 `ac` | 피해가 발생하는 턴 비율 | 최대 피해 |
|---|---|---|
| 2 | **83.0%** | 9 |
| 5 | **65.0%** | 9 |
| 9 | **45.0%** | 9 |
| 10 | **36.0%** | 8 |
| 20 | **16.0%** | 7 |

`Orc`(id 0, strength 8) 기준으로도 ac 10 → 31.0%, ac 20 → 13.0% 다.
→ ac 20 이어도 **6턴 중 1턴은 최대 7 피해가 들어온다.** 무효화가 아니라 **강한 감쇠**다.

**그러나 재척도의 필요성은 남는다**: 원작 파티의 초기 `ac` 는 3~5 이고(`party.dart:108,130`),
`books.json` 의 10/20 은 그보다 2~4배 크다. BP-42 가 2/5 로 재척도한 것은
**"무효화되기 때문" 이 아니라 "기존 파티 스탯 대역과 맞추기 위해서"** 라는 근거로 다시 서술해야 한다.
## H-3 `books.json` 의 id 공간은 `HDPlayer.weapon` 정수와 **무관**하다
`assets/maps/books.json` 의 `weapon[].id` 는 1부터 시작하는 자체 번호이고,
`HDPlayer.weapon` 은 `getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon"` 로만 쓰이는 별개 정수다.
두 공간을 같다고 가정한 코드 주석이 있으나 **근거가 없다.** BP-42 의 마이그레이션은 이 둘을 명시적으로 매핑해야 한다.

## H-4 맵 에디터의 `registerAs` 는 이미 `json` 필드를 쓴다
`tools/mapEditor/server/ai_api.ts:592` 가 `MapInfos.json` 항목을 만들 때 `json: file` 을 포함한다.
→ 부록 D-1 의 갭은 "앞으로 만들 맵" 이 아니라 **기존 15개 엔트리를 고칠 경로가 없다**는 것이다.
신규 맵은 이미 올바르게 등록된다. 수리 대상은 기존 데이터뿐이다.

## H-5 무기 이름 인덱스와 공격력은 원작에서 **묶여 있지 않다** (2026-09-03 G1-02 중 확인)

`HDPlayer.weapon`/`shield`/`armor` 가 담는 정수는 **이름 인덱스일 뿐이고 성능치를 결정하지 않는다.**
C++ 원작 `REF_hadar/src/hadar/hd_class_pc_player.h:60-66` 이 두 축을 별개 필드로 둔다:

```cpp
int weapon; int shield; int armor;              // 이름 인덱스
int pow_of_weapon; int pow_of_shield; int pow_of_armor;   // 성능
```

`hd_class_pc_player.cpp:212` 이 `pow_of_weapon = 5` 로, `:451` 이 `pow_of_weapon = level[0] * 2 + 10` 으로
**`weapon` 과 무관하게** 채운다. 이름은 `:304` 가 `resource::getWeaponName(weapon)` 으로 따로 뽑는다.

**배포된 스크립트가 이를 실증한다** — 같은 `weapon=3`(미늘창)에 서로 다른 공격력을 넣는다:

| 파일 | `weapon` | `pow_of_weapon` |
|---|---|---|
| `assets/L1_ep1d0.cm2:168-169` | 3 | **100** |
| `assets/L1_ep1d2.cm2:147-148` | 3 | **9** |
| `assets/lore_ep1.cm2:388-389` | 1 | 5 |

방어구도 같다 — `L1_ep1d0.cm2:164-167` 이 `armor=3` + `pow_of_armor=4`, `shield=5` + `pow_of_shield=5`.

### 파급

- **부록 H-3 의 확장**이다. H-3 은 "`books.json` 의 id 공간이 `HDPlayer.weapon` 과 무관" 이라고만 적었는데,
  실제로는 **`HDPlayer.weapon` 자신이 어떤 성능 표와도 묶여 있지 않다.**
- [G1-02](../../issues/G1-items/G1-02-item-data.md) 의 "C++ 이름 + Unity 수치를 이름으로 매칭" 은
  **원작에 없던 결합을 새로 만드는 일**이다. 하지 않겠다는 뜻이 아니라, **Unity 포트의 판단을 채택하는 것**이지
  C++ 원작을 복원하는 것이 아니라는 뜻이다. `item_data.dart` 헤더가 이 사실을 적고 있다.
- 그 결합의 결과가 단조롭지 않다 — C++ 인덱스 순서(0→9)로 늘어놓으면 공격력이
  `1, 10, 25, 80, 60, 60, 35, 90, 60, 10` 이다. **C++ 의 인덱스 순서는 성능 사다리가 아니다.**
  (인덱스 순서가 성능 순이라는 근거는 어디에도 없다. 위 수열이 그 반증이다.)
- `화염검`(C++ 인덱스 9)은 Unity 무기 표에 **대응 항이 아예 없다.** 유일한 등장이
  `ObjItem.cs:453` 의 소환수 기술(`SUMMON_SINGLE` index 8)이고, 그 표의 21개 power 는 전부
  원작이 TODO 로 남긴 자리표시 `10.0` 이다(`ObjItem.cs:603-611`).
  → `item_data.dart` 의 `attaPow: 10` 은 **자리표시값을 옮긴 것**이지 밸런스 판단이 아니다.
  추적은 [G1-10](../../issues/G1-items/G1-10-flame-sword-power.md).
  **"원작보다 약해졌다" 가 아니다** — 원작에 값이 애초에 없다.
- [G1-05](../../issues/G1-items/G1-05-equipment-effect.md) 가 `powOfWeapon ← attaPow` 를 배선하면
  **위 cm2 3곳과 충돌한다** — 스크립트가 직접 넣은 `pow_of_weapon` 을 장비가 덮어쓰게 된다.
  G1-05 는 이 충돌을 어느 쪽으로 풀지 정해야 한다.

### 화염검은 플레이 중 손에 들어오지 않는다 (2026-09-03 추가 실측)

배포된 cm2 전량에서 `Player::ChangeAttribute(n, "weapon", …)` 에 들어가는 값은
**0(8건) · 1(24건) · 3(4건)** 뿐이다. **9는 0건**이므로 화염검은 이름 표에만 존재하고
도달 경로가 없다. 따라서 위 자리표시값의 실플레이 영향은 **0** 이다.
(`REF_hadar/bin/gamedat0.sav`·`gamedat1.sav` 는 포맷 미해독 — 확인 범위 밖.)

### 정정 사항

- G1-02 이슈의 "`WEAPON_LIST` … 51" 은 **59**다(무기 38 + 소환수 기술 21). 나머지 수치는 맞다.

# 부록 I — region 레이어 예약안 반증 (2026-08-30 메인 검증 완료)

## I-1 `Map001.json` 은 **이미 region 200~255 대역을 쓰고 있다**
BP-26 이 `trigger` 앵커용으로 region 200~255 를 예약하며 "기존 동작 무영향" 이라 주장했으나,
`hadar2026_app/assets/maps/Map001.json`(4×4 테스트 맵)의 region 레이어 실측:

```
region: (1,0)=1 (2,0)=1 (3,0)=1 (0,1)=2 (1,1)=2 (2,1)=2 (3,1)=2
        (0,2)=3 (1,2)=3 (2,2)=3 (3,2)=3 (0,3)=64 (1,3)=128 (2,3)=255
```

**(2,3) 이 이미 `region=255`** 다. 같은 칸의 objUpper 는 `112`(B 타일 112~123 = SIGN 대역)다.
→ 예약안을 그대로 적용하면 이 칸의 해석이 바뀐다. "무영향" 은 **거짓**이다.

충돌 칸이 테스트 맵 1칸뿐이라 **비용은 여전히 작다.** 그러나
- "무영향" 이라는 서술은 **"충돌 1칸, 조치 필요"** 로 정정해야 하고,
- 예약 도입 시 **기존 region ≥200 값을 스캔해 마이그레이션하는 태스크**가 필요하며,
- 이 사실을 근거로 삼은 다른 주장(무영향 전제의 승인 항목)도 재검토해야 한다.

참고: 같은 맵의 objUpper 는 `(0,1)=1 (1,1)=2 (2,1)=3 (3,1)=4 (0,3)=128 (2,3)=112`,
ground 는 A5 기준 `(0,2)=56 (1,2)=64 (2,2)=72 (3,2)=80` 으로 각각 WATER/ENTER/CLIFF/BLOCK 경계값이다.
**`Map001.json` 은 타일 액션 경계를 의도적으로 훑는 테스트 픽스처**로 보인다 — 함부로 정리하지 말 것.

# 부록 J — region 레이어는 **기능적으로 죽어 있다** (2026-08-30 메인 검증 완료)

## J-1 region 값은 타일 액션을 만들어 낼 수 없다
`hadar2026_app/lib/application/map_loader.dart:44`:
```dart
map.data[index].ixEvent = _getLayerData(rawData, 5, index, size);   // z5 = region (0~255)
```
`hadar2026_app/lib/domain/map/tile_properties.dart:186-187`:
```dart
int eventType = unit.ixEvent & 0x00FF0000;   // 비트 16~23
if (eventType != 0) { ... }
```

region 값은 **0~255, 즉 비트 0~7** 에 들어간다. 마스크는 **비트 16~23** 을 본다.
→ `200 & 0x00FF0000 == 0`. **어떤 region 값도 타일 액션을 만들지 못한다.**

`ixEvent` 의 상위 바이트가 채워지는 유일한 경로는 `map_loader.dart:60-70` 이다 —
맵 JSON 의 `events[]` 를 읽어 이름 접두사(TALK/SIGN/EVENT/ENTER)로
`eventType = 0x00010000 | ... | 0x00040000` 을 만들어 `ixEvent = eventType | parsedEvent.id` 로 덮어쓴다.

**결론**: region 레이어는 로드되지만 **읽히기만 하고 아무 효과가 없다.**
`tools/mapEditor/AI_GUIDE.md` 의 "region: 지역 ID (게임이 ixEvent 로 읽음)" 서술은
"읽지만 아무 일도 하지 않는다" 로 이해해야 한다.

## J-2 이 사실이 무효화하는 것들
- **BP-26 의 `trigger` 앵커 region 200~255 예약안** — 설계대로는 **동작하지 않는다.**
  (부록 I-1 은 "충돌 1칸" 이라는 비용 문제였고, J-1 은 **작동 자체가 안 된다**는 더 근본적인 문제다.)
- BP-31/BP-36 이 이 예약안을 전제로 만든 검증·편집 기능.
- BP-26 R-31-7 의 "서버가 직접 통행/액션을 검사" — `unitAction` 계산이 region 을 받지 않으므로 성립 불가.

## J-3 타일 액션의 실제 출처는 3개뿐이다
1. 맵 JSON `events[]` 의 이름 접두사 → `ixEvent` 상위 바이트 (TALK/SIGN/EVENT/ENTER)
2. `ixObj1`(objUpper) 의 B 타일 id 대역 → `_getObjectAction`
3. `ixTile`(ground) 의 A5 인덱스 대역 → `_getTileAction`

region(z5)·objLower(z2)·shadow(z4)·ground2(z1) 는 **타일 액션에 관여하지 않는다.**

# 부록 K — 타일 이벤트 진입점 3개의 게이트 비대칭 (2026-08-30 메인 검증 완료)

`HDGameMain().checkTileEvent(...)` 를 부르는 곳은 `hadar2026_app/lib/presentation/panels/player_sprite.dart` 에 **3개**뿐이고,
**타일 액션 선검사(게이트)의 유무가 서로 다르다.**

| 진입점 | 줄 | 호출 | presentation 게이트 | 결과 |
|---|---|---|---|---|
| **이동 완료(step-on)** | `:193` | `checkTileEvent(party.x, party.y, isInteraction: false)` | **없음** | 밟은 칸의 타일 액션과 **무관하게 항상 호출**된다 |
| **이동 차단 시 상호작용(bump)** | `:359-366` | `checkTileEvent(nextX, nextY, isInteraction: true)` | **있음** — `if (action.isInteractive)` | 타일이 talk/sign/enter 여야 호출된다 |
| **확인키 상호작용** | `:405` | `checkTileEvent(targetX, targetY, isInteraction: true)` | **없음** | 마주본 칸의 타일 액션과 무관하게 항상 호출된다 |

## K-1 D-27 은 3개 중 2개에서 **코드 변경 없이 성립한다**
step-on(`:193`)과 확인키(`:405`)는 선검사가 없으므로, 콘텐츠 티어가 `(map,x,y)` 로 트리거 인덱스를 직접 조회하면
**앵커가 맵에 아무 표시를 남기지 않아도 발화한다.** D-27 의 전제가 여기서 충족된다.

`move`/`swamp` 같은 평범한 칸에 놓인 앵커도 잡힌다. BLOCK 칸에서 step-on 이 발화하지 않는 것은
**"거부" 가 아니라 "호출 부재"** 다 — 애초에 그 칸으로 이동이 완료되지 않기 때문이다.

## K-2 bump 경로만 presentation 게이트가 남아 비대칭이다
`:359` 의 `if (action.isInteractive)` 는 **presentation 계층이 콘텐츠 발화 여부를 결정**하는 유일한 지점이다.
→ 벽을 향해 걸어 부딪히는 방식으로는 통행 불가 타일 위의 앵커만 잡히고, 확인키로는 잡힌다. **같은 앵커가 조작 방식에 따라 다르게 동작한다.**
이 게이트를 제거하거나 콘텐츠 조회를 앞세우는 **1줄 수준의 변경**이 필요하다. BP-27 이 `Q-27-10` 으로 등록했다.

## K-3 부수 사실
- `:193` 의 호출은 **fire-and-forget** 이다(주석: "so we don't deadlock the next movement frame inside update(dt)").
  await 하지 않으므로 이동 프레임과 콘텐츠 실행이 겹칠 수 있다 — 재진입 가드(`_isScriptRunning`)가 유일한 보호막이다.
- `:360-367` 은 `_lastInteractedX/Y` 로 **같은 누름 세션 안의 중복 상호작용**을 막는다. 이 상태도 presentation 소유다.
- 부록 B-3 의 "이동·상호작용이 스프라이트 폴링 안에 있다" 는 사실은 유효하다. 다만 **콘텐츠 발화에 관해서는
  게이트가 거의 없어** D-27 이 요구하는 만큼은 이미 열려 있다. 헤드리스 구동(BP-34 선결 과제)은 별개 문제다.

# 부록 L — cm2 중첩 `include` 는 매 `run()` 재실행된다 (2026-09-01 실행으로 검증)

## L-1 `include` 스킵은 **최상위 문장에만** 걸린다

`packages/cm2_script/lib/src/cm2_script.dart:92-104` 의 `run()`:
```dart
final statements = List<ScriptStatement>.from(currentScript);
for (var stmt in statements) {
  if (stmt is CommandStatement) {
    if (stmt.command == 'variable' || stmt.command == 'include') continue;  // ← 최상위만
  }
  await executeStatement(stmt);
```
중첩 문장은 `executeStatement`(`:114`) → `executeCommand` → `case 'include'`(`:162`) 를 타므로 **필터에 걸리지 않는다.**

## L-2 실행 검증

`ScriptEngine` 을 직접 구동해 확인했다(임시 하네스).

```cm2
variable(mode)
mode.assign(1)

if (Equal(mode, 1))
	include("quest1.cm2")      # 중첩
```
`quest1.cm2` = `Log(...)` + `Event::Override()`

| 시점 | 결과 |
|---|---|
| `loadFromString` (init) | 실행 **안 됨** — init 은 최상위 `variable`/`include`/`.assign` 만 처리하고 `if` 를 건너뛴다 |
| `run()` 1회 | 실행됨, `handled = true` |
| `run()` 2·3회 | **매번 재실행됨**, `handled = true` |

## L-3 cm2 override 가 **엔진 변경 없이 성립한다**

맵 cm2 가 조건 안에서 퀘스트 cm2 를 `include` 하면 퀘스트 핸들러가 **타일 디스패치마다 실행**된다:

```cm2
if (Equal(ScriptMode(), FLAG_TALK))
	include("quest_seokmun.cm2")
	include("quest_other.cm2")
```

한 맵에 퀘스트 여러 개를 **파일 단위로 분리**할 수 있고, 각 파일이 `Event::Override()` 로 JSON 폴백을 억제할 수 있다.

**대가** (설계 시 반드시 고려):
- 포함 파일의 `.assign` 이 **매 디스패치 재실행**된다 → 상수 대입은 무해하지만 **상태 초기화를 두면 매번 리셋된다**
- 매 디스패치마다 파일을 다시 읽고 파싱한다(작은 파일이면 무해)
- **include 실패가 침묵한다** — `_executeInclude` 의 catch 가 `print` 만 한다(`:220-224`).
  경로 오타 = 퀘스트가 조용히 존재하지 않음. **린터가 include 경로 존재를 검사해야 한다**

## L-4 정정 이력
초판 서술("`include` 는 init 전용 1회성이라 per-tile 핸들러를 담을 수 없다")은 **오류였다.**
`run()` 의 필터가 최상위 전용임을 놓치고 코드를 부분만 읽은 결과다. **추론이 아니라 실행으로 확정할 것.**
CLAUDE.md 의 "one-shot initial assignments 를 `include` 에 두라" 는 규약은 **최상위 include** 에 관한 것이고 유효하다.

# 부록 M — 출시 콘텐츠의 플래그 충돌 (2026-09-01 검증)

## M-1 `flag4ep1.cm2:42-43` 의 대입 이름 오타 — **2026-09-05 고침**
```cm2
variable(GFD1_WORK_TRAP_BY_TRICK)
GFD1_WORK_TRAP_BY_TRICK.assign(14)

variable(GFD1_OPEN_DOWN_STAIRS)
GFD1_OPEN_ODD_WALL.assign(15)      # ← GFD1_OPEN_DOWN_STAIRS 에 대입해야 한다
```
**고친 뒤**: `GFD1_OPEN_DOWN_STAIRS.assign(15)`. 아래 두 문제가 함께 사라진다 —
`GFD1_OPEN_ODD_WALL` 은 13(자기 줄)으로 돌아가고 `GFD1_OPEN_DOWN_STAIRS` 는 15 를 갖는다.
같은 오타가 다시 들어오면 `test/application/scripting/cm2_assets_audit_test.dart`
의 "선언만 하고 값을 안 준 이름이 없다" 가 잡는다.
**세이브 호환**: 이전 세이브는 아래층 계단을 0번, 이상한 벽을 15번 칸에 적어 두었다.
저장 파일은 gitignore 대상(개발용)이라 옮기지 않았다.

아래는 고치기 전의 분석이다.
하나의 오타가 **두 가지 문제**를 만든다:
1. `GFD1_OPEN_DOWN_STAIRS` 는 대입을 못 받아 `cm2_script.dart:160`(`variables[args[0]] = 0`)의 기본값 **0** 으로 남는다.
   → `GFD0_IS_FIRST`(=0)와 **충돌**한다. `L1_ep1d1.cm2:176` 의 `Flag::Set(GFD1_OPEN_DOWN_STAIRS)` 는
   실제로 **d0 첫 방문 플래그를 켠다.**
2. `GFD1_OPEN_ODD_WALL` 이 13 → **15** 로 덮어써진다. 인덱스 13 은 아무도 쓰지 않게 되고 15 를 공유한다.

`L1_ep1d1.cm2:349` 가 `Flag::IsSet(GFD1_OPEN_DOWN_STAIRS)` 로 그 칸을 읽으므로 **런타임에 실제로 영향이 있다.**

## M-2 생 숫자 플래그가 40건 있다
`Flag::Set/IsSet` 에 **이름 상수 대신 정수 리터럴**을 쓴 곳: `lore_ep1.cm2` 19건 · `town2.cm2` 19건 · `menace.cm2` 2건 = **40건**.
사용 인덱스: 10 · 31 · 32 · 50~55. (`L1_ep1*` 7개 파일은 0건 — 전부 이름을 쓴다.)

→ 이름 레지스트리(`flag4ep1.cm2`)를 **우회**하므로 충돌 검출이 불가능하다. 실제로 **10 · 31 · 50 에서 충돌이 이미 발생**했다
(예: 10 = `GFD1_WALL_REMOVER_USED` vs `town1.cm2` 의 `flag_battle`).

→ AI 생성의 직접적 위험 근거다. 플래그 레지스트리(이슈 S2-01)가 필요한 이유가 이것이다.

## M-3 **[해소됨 2026-09-03]** 미등록 심볼 6종·9곳이 조용히 실패 중이었다

> **2026-09-03 (G2-02)**: 6종 전부 등록되어 이 항목은 **해소**되었다.
> 아래는 무엇이 어떻게 틀려 있었는지의 기록으로 남긴다 — 같은 형태의 결함을
> 다시 만들지 않기 위해서다.

등록되지 않은 커맨드/함수가 실사용 cm2 에 있었다:
`Party::CheckIf` · `GameOver` · `Player::ApplyAttribute` · `Map::SetLightArea` · `Map::ResetLightArea` · `Player::ReviseAttribute`

특히 **`Party::CheckIf` 는 함수라서 0을 반환**했고(§9), 그 결과 부양 마법 관련 분기가 **의도와 반대로 동작**했다:

| 위치 | 증상 |
|---|---|
| `L1_ep1d2.cm2:200` `Not(Party::CheckIf(CHECKIF_LEVITATION))` | 항상 참 → **부양 마법 중에도 절벽에서 떨어졌다** |
| `L1_ep1d4.cm2:45` `if (Party::CheckIf(CHECKIF_MAGICTORCH))` | 항상 거짓 → 불을 켜도 해당 대사가 안 나왔다 |
| `L1_ep1d4.cm2:51` `if (Not(...))` | 항상 참 → **불을 켠 상태에서도** 물의 정령 이벤트가 발생했다 |
| `L1_ep1d0.cm2:441` `GameOver()` | 커맨드라 건너뛰기만 함 → 강제 종료 장면 뒤로 **게임이 계속 진행됐다** |

회귀 테스트: `hadar2026_app/test/application/cm2_unregistered_symbols_test.dart`.
`Map::SetLightArea`/`ResetLightArea` 는 원작의 per-tile `map::setLight`
(`hd_base_extern.h:44-45`)를 사각형 루프로 감싼 것이고,
저장소는 `domain/lighting/light_areas.dart` 의 `HDLightAreas`(맵 전환 시 초기화)다.

# 부록 N — 원작 아이템 이름표와 미등록 심볼의 게임플레이 영향 (2026-09-01 검증)

## N-1 원작 아이템 이름표가 있고, **Dart 정수와 같은 인덱스 공간**이다

`REF_hadar/src/hadar/hd_class_pc_player.cpp:302-315`:
```cpp
const char* hadar::PcPlayer::getWeaponName(void) const
{
    return resource::getWeaponName(weapon).sz_name;   // weapon 정수를 그대로 인덱스로
}
```
`REF_hadar/src/hadar/hd_res_string.cpp:38+` 에 이름 배열이 있다(소스는 **CP949** 인코딩. 디코드해 확인).

| 분류 | 개수 | 이름 |
|---|---|---|
| 무기 | **10** | 맨손 · 단도 · 곤봉 · 미늘창 · 장검 · 철퇴 · 기병창 · 도끼창 · 삼지창 · 화염검 |
| 방패 | **6** | 없음 · 가죽 방패 · 청동 방패 · 강철 방패 · 은제 방패 · 금제 방패 |
| 갑옷 | **6** | 없음 · 가죽 갑옷 · 청동 갑옷 · 강철 갑옷 · 은제 갑옷 · 금제 갑옷 |

`RETURN_HAN_STRING("0,2..4,6..9", false)` 형태로 **조사(助詞) 정보까지** 들어 있다.

→ 즉 `HDPlayer.getWeaponName() => "무기$weapon"` 은 **존재하는 이름표 조회를 하지 않고 있는 것**이다.
포팅 비용은 배열 22개 + CP949 디코드뿐이며, 전투 로그·상태 메뉴 **4곳**이 즉시 개선된다.

**`assets/maps/books.json` 은 비정본이다** — 단검·단창·작은도끼는 위 표에 없다.
무기 5·방어구 3짜리 별개 샘플이므로 이름 충돌 시 **C++ 원작이 정본**이다.

## N-2 `Party::CheckIf` 미등록이 **마법을 무력화**하고 있다

`Party::CheckIf` 는 `script_engine_adapter.dart` 에 **등록되어 있지 않다**(grep 0건).
§9 에 따라 미등록 **함수는 0을 반환**한다.

`hadar2026_app/assets/L1_ep1d2.cm2:199-202`:
```cm2
if (Not(flag_event_hit))
	if (Not(Party::CheckIf(CHECKIF_LEVITATION)))
		Talk("@7일행들은 절벽으로 떨어질뻔 했다.")
		WarpPrevPos()
```
`Party::CheckIf(...)` → 0 → `Not(0)` → **참** → **공중 부상 상태에서도 추락한다.**
공중 부상 마법이 이 절벽에서 아무 역할을 하지 못한다.

`hadar2026_app/assets/L1_ep1d4.cm2:45,51` 은 같은 원인으로 **두 분기가 동시에 어긋난다**:
- `if (Party::CheckIf(CHECKIF_MAGICTORCH))` → 항상 거짓 → 횃불 켠 상태의 대사가 **절대 안 나온다**
- `if (Not(Party::CheckIf(CHECKIF_MAGICTORCH)))` → 항상 참 → 횃불 끈 상태의 대사가 **항상 나온다**

→ 부록 M-3 의 "미등록 심볼 6종" 이 단순 누락이 아니라 **실제 게임플레이를 망치고 있다**는 확증이다.
원작에 구현이 있다(`REF_hadar/src/hadar/hd_base_extern.h` 계열) → 제거가 아니라 **등록**이 정답이다.

---

# 부록 O — B1(전투 분리) 이식 중 확인한 전투 실측 (2026-09-04 코드 대조 + 실행 검증)

전투를 `packages/hd_battle` 로 옮기면서 `battle.dart`(572줄)·`magic_system.dart`·`enemy.dart` 를
줄 단위로 대조했다. 아래는 그 과정에서 **새로 확인한** 사실이다. 이식본은 전부 그대로 옮겼고
(B1 은 규칙 무변경), 각 항목을 받는 B2 이슈를 적어 둔다.

## O-1 전투 중 마법 지수는 **검사만 하고 차감되지 않는다** — 마법이 사실상 무료다

`magic_system.dart:242-256` 이 `player.sp < spCost` 를 확인하고 거절하지만,
**전투 경로 어디에도 `sp -= ` 가 없다.** 차감은 전투 밖 `castSpell`(`:66`)에만 있다.

→ 문턱(공격 마법 5, 치료·초감각 10)을 한 번 넘기면 그 전투 내내 무한히 쓸 수 있다.
`fixtures/heal.json` 이 40턴 동안 치료를 시전하며 이를 보여준다.
받는 이슈: [B2-02](../../issues/B2-battle-expand/B2-02-heal-applies.md).

## O-2 명령표가 4칸인데 파티 슬롯은 6칸이다 — 잠복 `RangeError`

`battle.dart:120` `playerCommands = List.generate(4, (_) => [0, 0, 0]);`
그리고 `:132` `int order = p.order;` → `playerCommands[order]`.

`HDParty.players` 는 **6칸**이고 `order` 는 0~5 다(`party.dart:189`). 시작 파티가 2명이라
우연히 동작한다. **슬롯 4·5 에 사람이 있으면 전투 첫 턴에 `RangeError` 로 죽는다.**
파티원을 늘리는 콘텐츠를 만들면 즉시 물린다.

이식본은 슬롯을 키로 쓰는 map 이라 이 경계가 없다. 구 코드에 남아 있으므로
[B4-03](../../issues/B4-battle-view/B4-03-remove-old-battle.md) 까지는 유효한 결함이다.

## O-3 **[해소됨 2026-09-05, B2-04]** 의식불명 즉살 분기는 도달 불가능했다

> 재조준이 이제 붕괴한(의식불명) 대상을 **그대로 두고 마무리한다** —
> `packages/hd_battle/lib/src/model/battle.dart` `_executeAttack`.
> 시연: `hd_battle_console/fixtures/finishing_blow.json`.
> 고정 테스트: `packages/hd_battle/test/flow/collapse_flow_test.dart`.

`battle.dart:437-447` 의 *"의식불명 상태인 …을 가볍게 처치했다!"* 분기는
`t.unconscious > 0 && t.dead == 0` 을 요구한다. 그런데 바로 위 `:428-433` 의 재조준이
`indexWhere((e) => e.isConscious())` 로 **의식 있는 적만** 고르고,
`isConscious()` 는 `unconscious == 0` 을 포함한다(`enemy.dart:45`).

즉 두 조건이 동시에 성립할 수 없다. 의식불명을 만드는 것은 독뿐이고(O-4), 독은 적 페이즈에서
돌고 다음 라운드에 대상이 다시 선택된다. → **그 문장은 한 번도 출력된 적이 없다.**
받는 이슈: [B2-04](../../issues/B2-battle-expand/B2-04-unconscious-stage.md).

## O-4 **[해소됨 2026-09-05, B2-04]** hp 0 의 처리가 죽는 경로에 따라 달랐다

> 세 경로가 `rules/collapse.dart` 의 `applyDamage` **하나**로 합쳐졌다.
> 무엇으로 맞아도 의식불명이 되고, 쓰러진 대상에 다시 피해가 들어가면 **누적된다**.
> 마법 사망도 이제 hp 를 0 으로 정리하고 경험치를 준다.
> **2026-09-05 (B2-03) 정정**: 처음에는 "쓰러진 대상에 다시 피해 → 즉사" 로 넣었으나,
> 부록 Q-2 에서 `unconscious` 가 누적값임을 확인해 임계값 방식으로 교체했다.

| 경로 | 코드 | 결과 |
|---|---|---|
| 독 | `battle.dart:212-218` | hp 0 → `unconscious = 1` (**2단계**) |
| 물리 | `battle.dart:486-489` | hp 0 → `unconscious = 0; dead = 1` (**즉사**) |
| 마법 | `battle.dart:171-176`·`:190-195` | `dead = 1` 만. **hp 를 0 으로 정리하지 않고, 처치 경험치도 없다** |

`:488` 의 주석이 스스로 생략을 적어 두었다
(*"goes unconscious first in hadar sometimes but let's just do death for simplicity"*).
마법 사망이 경험치를 주지 않는 것은 주석조차 없다.
받는 이슈: [B2-04](../../issues/B2-battle-expand/B2-04-unconscious-stage.md) ·
[B2-01](../../issues/B2-battle-expand/B2-01-magic-effects.md).

## O-5 승리 경험치는 적의 **테이블 위치**를 읽는다 (레벨이 아니다)

`battle.dart:276-280`:
```dart
int plus = e.data.id + 1;
plus = (plus * plus * plus) ~/ 8;
return xp + max(1, plus);
```

`e.data.id` 는 `enemyTable` 의 **배열 인덱스**다. 그래서 같은 레벨 1 인데
`Orc`(id 0)는 1, `Earth Worm`(id 3)은 8 — **여덟 배**다. 테이블에 행을 끼워 넣으면
그 뒤 모든 적의 보상이 바뀐다.

이것이 B1-02 가 정체성을 문자열 키로 바꾸고 `legacyId` 를 따로 보존한 이유 중 하나다.
고정 테스트: `packages/hd_battle/test/rules/settle_vitals_test.dart`.

## O-6 **[부분 해소 2026-09-05, B2-04]** 독 피해는 로그가 하나도 없었다

> 콘솔 view 가 `·` 표시와 함께 출력한다. **그리고 파티의 독은 아예 처리되지 않았다** —
> 전투 중 `HDPlayer.poison` 을 읽는 곳이 0곳이었다. B2-04 가 턴마다 처리하게 했고,
> 붕괴가 회복 가능해진 뒤로는 그것이 파티의 유일한 사망 경로다.
> 시연: `hd_battle_console/fixtures/party_poison.json`.

`battle.dart:211-219` 의 독 처리 블록에 `addLog` 가 **0개**다. 파티원과 적 모두
독으로 hp 가 줄고 쓰러져도 화면에 아무것도 나오지 않는다.
콘솔 view 는 이 줄들을 `·` 표시와 함께 새로 추가했다(원작에 없던 줄이라는 뜻).

## O-7 **[해소됨 2026-09-05, B2-04]** 파티원 hp 는 음수로 남았다

> `applyDamage` 가 0 으로 정리한다. 구 `battle.dart` 에는 남아 있다(B4-03 까지).

적은 죽을 때 `t.hp = 0` 으로 정리하지만(`battle.dart:487`), 파티원은
`t.hp -= damage` 뒤 `if (t.hp <= 0) t.dead = 1` 만 한다(`:558-565`, `:522-528`).
**정리하지 않는다.** 전투 후 파티에 `hp: -4` 가 남는다.

이식본도 그대로 옮겼으므로 `BattleOutcome` 이 음수를 실어 보낸다
(`fixtures/heal.json` 재생에서 `HP -1` · `HP -4` 로 확인). 되붙일 때
[B3-02](../../issues/B3-battle-integrate/B3-02-setup-and-settle.md) 가 판단할 일이다.

## O-8 `menu_flows.dart:92-93` 의 주석이 틀렸다

```dart
HDBattle().registerEnemy(5); // Skeleton
HDBattle().registerEnemy(7); // Slime
```

테이블에서 **id 5 는 `Giant`, id 7 은 `Wolf`** 다. `Skeleton`·`Slime` 이라는 이름은
75행 어디에도 없다. 실플레이 영향은 없지만(주석뿐이다) 전투를 읽는 사람을 잘못 이끈다.

## O-9 마법 33~40 은 전투 메뉴로 **도달할 수 없다**

`magic_system.dart:197-223` 의 카테고리는 1\~3 · 4\~10 · 11\~18 · 19\~32 · 41\~45 다.
**33\~40 은 어느 범위에도 없다** — 마법의 횃불·공중 부상·물/늪 위를 걸음·기화 이동·
지형 변화·공간 이동·식량 제조. 전투 밖 `castSpell` 로만 쓴다.

한편 41\~44(투시·예언·독심·천리안)는 효과가 전투 밖인데 **전투 메뉴에는 올라온다.**
고정 테스트: `packages/hd_battle/test/rules/spellbook_test.dart`.
받는 이슈: [B2-01](../../issues/B2-battle-expand/B2-01-magic-effects.md) ·
[B3-04](../../issues/B3-battle-integrate/B3-04-world-effects.md).

## O-10 뽑기 순서에 **단축 평가가 섞여 있다**

`battle.dart:507-510` 은 `(e.special > 0 || e.castLevel > 0) && (rand > rand) && e.strength > 0`
이다. 특수 능력이 없는 적은 `&&` 단축 평가 때문에 **난수를 하나도 뽑지 않는다.**

시드를 도입해 전투를 재현 가능하게 만들면 이 조건의 재배치가 **그 뒤 모든 뽑기를 밀어낸다.**
같은 시드가 다른 결과를 내게 되므로, 조건식을 정리할 때 반드시 확인해야 한다.
고정 테스트: `packages/hd_battle/test/rules/enemy_action_test.dart` (`rng.draws == 0`).

## O-11 부록 H-2 의 대역표는 새 구현에서 **정확히 재현된다**

`packages/hd_battle/test/rules/enemy_action_test.dart` 가 `enemyPhysicalDamage` 를
10×10 뽑기 조합으로 전수 구동해 H-2 표를 그대로 얻는다 —
Troll 기준 ac 2 → 83.0% · 5 → 65.0% · 9 → 45.0% · 10 → 36.0% · 20 → 16.0%,
최대 피해 9 / 8 / 7. Orc ac 10 → 31.0% · 20 → 13.0%.

**차이는 방법이다.** `hadar2026_app/test/application/defense_scale_test.dart:14-18` 은
*"the real formula cannot be driven from a test"* 라 적고 수식을 테스트 안에 **복사**했다.
새 구현은 시드를 받으므로 **원본 함수를 직접 호출**한다 → 복사본이 원본과 갈라질 수 없다.

**H-2 표는 구 전투식 기준임을 기억할 것.** B2-08(부위별 감쇠)·B2-09(속성 상성)가 들어오면
폐기하고 새 실측을 등재해야 한다([B2-99](../../issues/B2-battle-expand/B2-99-freeze-contract.md)).

---

# 부록 P — 원작 전투 구현의 소재 (2026-09-04 대조 확인)

B2(전투 확장)를 짜기 전에 이식 원본을 찾은 결과다. 판정은
[`issues/DECISION-LOG.md` 5차](../../issues/DECISION-LOG.md).

## P-1 C++ 원작에 전투가 **완성되어 있다** — cm2·Dart 가 따르는 세대다

| 파일 | 줄수 | 함수 |
|---|---|---|
| `REF_hadar/src/hadar/hd_class_pc_player.cpp` | **2,242** | `castAttackSpell` · `castCureSpell` · `castPhenominaSpell` · `castSpellToOne` · `castSpellToAll` · `castSpellWithSpecialAbility` · `useESP` · `useESPForBattle` · `attackWithWeapon` · `tryToRunAway` · `applyAttribute` · `reviseAttribute` |
| ↑ 치료 8종 | | `m_healOne` · `m_antidoteOne` · `m_recoverConsciousnessOne` · `m_revitalizeOne` · `m_healAll` · `m_antidoteAll` · `m_recoverConsciousnessAll` · `m_revitalizeAll` |
| ↑ 상태 표현 | | `checkCondition` · `getConditionString` · `getConditionColor` |
| ↑ 자격 판정 | | `m_canUseSpecialMagic` · `m_canUseESP` · `m_printSpNotEnough` · `m_printESPNotEnough` |
| `REF_hadar/src/hadar/hd_class_pc_enemy.cpp` | **1,079** | `enemyAttackWithWeapon` · `enemyCastSpell` · `enemyCastAttackSpellToAll` · `enemyCastAttackSpellToOne` · `enemyCastAttackSpellSub` · **`enemyCastCureSpell`** · `enemyAttackWithSpecialAbility` · `enemyCastSpellWithSpecialAbility` · `getRandomPlayer(PLAYERSTATUS)` |
| `REF_hadar/src/hadar/hd_base_game_main.cpp` | | `runBattleMode` · `checkEndOfBattle` · `encounterEnemy` · `selectEnemy` · `selectPlayer` · `plusGold` · `registerEnemy` · `detectGameOver` · `castSpell` · `useExtrasense` |

`enemyCastCureSpell` 은 **적이 서로를 치료한다**는 뜻이다. 현재 Dart 에는 그 개념이 없다.

`getRandomPlayer` 는 대상 선정을 `PLAYERSTATUS_CONSCIOUS` / `NOT_DEAD` / `ALL` 세 갈래로
구분한다 — 지금 Dart 는 conscious 하나뿐이다(`battle.dart:502`).

## P-2 마법 피해는 원작에서 **마법마다 다르다** (id 가 제곱으로 들어간다)

`hd_class_pc_player.cpp` `castSpellToOne`:

```cpp
int consumption = (ix_object * ix_object * p_player->level[1] + 1) / 2;
int damage      =  ix_object * ix_object * p_player->level[1] * 2;
```

`ix_object` 가 마법 id, `level[1]` 이 마법 레벨이다. 그래서 `마법 화살`(1)과 `마법 단창`(3)은
**9배** 차이다. 45종 각각의 손으로 쓴 효과는 아니지만 **id 별로 값이 다르다.**

그리고 **`consumption` 을 실제로 차감한다.** 부록 O-1 이 적은 "전투 중 마법 지수가 차감되지
않는다" 는 설계 공백이 아니라 **이식 누락**이다.

`useESPForBattle` 은 id 별 분기가 있다 — `(ix_object == 1 || 2 || 4)` 와 `== 3` 이 다르게 동작한다.

## P-3 ⚠ Unity 포트 `OldStyleBattle.cs`(3,248줄)는 **이식 원본이 아니다**

같은 게임의 전투를 **다시 만든 것**이고 미완성이다. 대조 결과:

| 항목 | C++ 원작 (cm2·Dart 세대) | Unity 포트 |
|---|---|---|
| 마법 번호 | 1~45, 5개 카테고리 | **1~10 단일 / 11~20 전체** |
| 능력치 | 개별 필드 | `status[STATUS.LUC/CON/AGI]` · `skill[SKILL_TYPE.DAMAGE]` 배열 |
| 마법 피해식 | `id² × level[1] × 2` | `skill[DAMAGE] × id² × 3` |
| 적 저항 | `resistance` **하나** (`hd_class_pc_enemy.h` `EnemyData`) | `resistance_1` + `resistance_2` |
| 적 테이블 | `s_enemy_data[75]`, `[0] = Orc` | **77행, `[0] = "존재없음"` → 인덱스 +1** |
| 행동 순서 | 슬롯 고정 | `_ProcessOnCombatPower` 가 **TODO 스텁** — 합만 구하고 버린다 |
| 신규 개념 | 없음 | 크리티컬 히트 · 회피율 · `regenerative_hp` · `doppelganger` · 전투 중 아이템·소환 |

**인덱스 +1 이 함정이다.** Unity 를 보고 "26 = Mummy" 로 옮기면 cm2 의
`Battle::RegisterEnemy(26)`(= Devil Hunter)과 어긋난다.

Unity 에만 있는 것(전투 중 아이템 `_SelectMedicalItem`·`_SelectCrystalItem`,
몬스터 소환 `_SelectMonsterToSummon`)은 **참고는 되지만 이식이 아니다.**

## P-4 Dart 적 테이블은 어긋나지 않았다 — 인덱스까지 대조 확인

`tools/convert_enemy.py:6` 이 읽은 원본은 `hd_class_pc_enemy.cpp` 의
`static hadar::EnemyData s_enemy_data[75]` 다. 전수 대조:

```
[0] Orc · [1] Troll · [2] Serpent · [3] Earth Worm · [4] Dwarf
[5] Giant · [6] Phantom · [7] Wolf · [26] Devil Hunter · [74] Neo-Necromancer
```

**C++ 와 완전 일치.** `resistance` 가 하나뿐인 것도 C++ `EnemyData` 구조체를 따른 것이고
누락이 아니다(부록 B-1 의 75종 판정과도 일치).

→ `packages/hd_battle` 의 `legacyId` 매핑과 B3-01 의 cm2 어댑터는 **이 인덱스를 쓰는 것이 맞다.**

## P-5 이식 비용에 대한 정직한 평가

G1(C# → Dart)보다 무겁다.

- **cp949 인코딩**이다. `codecs.open(p, 'r', 'cp949')` 로 읽어야 하고, 주석이 한국어다
- 전역 상태(`hadar::game::object::getPlayerList()`)와 콘솔 출력(`console.Write(...)`)이
  규칙과 **한 함수 안에 뒤섞여 있다.** 순수 함수로 뽑으려면 B1 에서 한 것과 같은 분리가 필요하다
- 그래도 **값과 분기는 그대로 옮길 수 있다.** B1 이 이미 `rules/` 에 순수 함수 자리를 만들었다

---

# 부록 Q — 특수 마법(13~18)과 상태 모델의 실체 (2026-09-05, B2-03)

C++ 은 정본이 아니다([6차 판정](../../issues/DECISION-LOG.md)) — 아래는 **어떤 개념이 있었는가**의
증거이고, 값과 분기는 B2 에서 우리가 정한다. 그런데 이 조사가 B2-03 의 전제를 뒤집었다.

## Q-1 특수 마법 13~18 은 **지속 시간이 있는 상태이상이 아니다** — 영구 능력치 감소다

`hd_class_pc_player.cpp` `castSpellWithSpecialAbility`(183줄), `ix_object` 는 **카테고리 내 색인**이다:

| 색인 | 마법 | SP | 효과 |
|---|---|---|---|
| 1 | 독 (13) | 10 | `++p_enemy->poison` — **독 수치를 누적**한다 |
| 2 | 기술 무력화 (14) | 30 | `p_enemy->special = 0` |
| 3 | 방어 무력화 (15) | 15 | 저항 30 이하면 `--ac`, 아니면 반반으로 `resistance -= 10` |
| 4 | 능력 저하 (16) | 20 | `--level`(1 아래로는 안 감) + `resistance -= 10` |
| 5 | 마법 불능 (17) | 15 | `--cast_level` |
| 6 | 탈 초인화 (18) | 20 | `--special_cast_level` |

**지속·강도 컨테이너를 만들 일이 아니었다.** 적의 능력치가 가변이고 영구히 깎이는 모델이다.
B1 이 `EnemyInstance` 에 능력치를 값으로 복사해 둔 것이 마침 이 모델에 맞는다.

각 마법은 `random(100) < resistance` 로 저지 판정, `random(N) > accuracy[1]` 로 명중 판정을 한다
(`N` 이 마법마다 다르다 — 40/60/40 또는 25/30/100/100). SP 도 마법마다 다르고 **실제로 차감된다.**

## Q-2 `unconscious` 는 불린이 아니라 **누적값**이다

`hd_class_pc_player.cpp` `checkCondition` — 7줄 전부다:

```cpp
if ((hp <= 0) && (unconscious == 0))
    unconscious = 1;
if ((unconscious > endurance * level[0]) && (dead == 0))
    dead = 1;
```

쓰러진 뒤 더 맞으면 그만큼 쌓이고, **체력 × 레벨**을 넘으면 죽는다. 버그로 보이지 않고
일관된 기제라 받아들였다 — B2-04 가 처음 넣은 "한 번 더 맞으면 사망" 을 이것으로 교체했다.
Unity 포트가 `enemy.state.unconscious += magic_damage` 를 하는 것도 같은 기제다.

## Q-3 상태는 **4가지뿐**이었다

`hd_res_string.h`:

```cpp
enum CONDITION { CONDITION_GOOD = 0, CONDITION_POISONED = 1,
                 CONDITION_UNCONSCIOUS = 2, CONDITION_DEAD = 3 };
```

→ 마법 14~18 을 위한 상태 칸이 **없다.** Q-1 대로 능력치를 직접 깎았으니 필요가 없었다.

## Q-4 C++ 의 버그 2건 — 저항이 음수가 된다

`castSpellWithSpecialAbility`:

* **case 3**(방어 무력화): `p_enemy->resistance -= 10;` — 클램프가 **아예 없다**
* **case 4**(능력 저하): `if (resistance > 0) resistance -= 10; else resistance = 0;`
  — 가드가 있지만 **저항 5 는 -5 가 된다**

읽는 자리(`random(100) < resistance`)에서는 음수가 항상 거짓이라 결과적으로 무해하지만,
표시하거나 저장하는 순간 드러난다. Pascal 원본이 없어 의도를 확인할 수 없고,
**C++ 이 버그처럼 보이면 버그다**(6차 판정) → `rules/condition.dart` 의 `reduceStat` 이
바닥값으로 클램프한다. 고정 테스트: `packages/hd_battle/test/rules/collapse_test.dart`.

## Q-5 누적값은 사실상 **파티 쪽 기제**다

적은 전원 붕괴하는 순간 전투가 끝나므로(`_enemiesAlive` 가 의식 있는 적만 센다) 누적값이
자랄 시간이 거의 없다 — 같은 턴 뒤 사람이 한 번 더 때리는 창뿐이다.
파티는 반대로 여러 라운드에 걸쳐 쌓이고, 그것이 **파티의 사망 경로**가 된다.

이 비대칭은 우리 판단의 결과이고 원작이 그랬는지는 알 수 없다. 밸런스를 볼 때 기억할 것.

---

# 부록 R — 치료 마법과 자동 전투의 실체 (2026-09-05, B2-02)

C++ 은 정본이 아니다([6차 판정](../../issues/DECISION-LOG.md)) — 아래는 개념의 증거이고
값은 B2 에서 우리가 정한다. 다만 이번에는 **구조가 명확해서 대부분 받아들였다.**

## R-1 치료 14종은 **네 갈래의 조합**이다

`hd_class_pc_player.cpp` `castCureSpell`(148줄) + `m_*One` 4종:

| id | 이름 | 조합 |
|---|---|---|
| 19 / 26 | 치료 | heal |
| 20 / 27 | 독 제거 | antidote |
| 21 / 28 | 치료와 독제거 | **antidote → heal** |
| 22 / 29 | 의식 돌림 | recoverConsciousness |
| 23 / 31 | 부활 | revitalize |
| 24 / 30 | 치료와 독제거와 의식돌림 | recoverConsciousness → antidote → heal |
| 25 / 32 | 복합 치료 | revitalize → recoverConsciousness → antidote → heal |

**단일(19~25)과 전체(26~32)의 순서가 다르다** — 단일은 부활이 5번째(23), 전체는 6번째(31).
이름표 자체가 비대칭이고 C++ 의 두 `switch` 는 각자의 절반과 맞는다 → 실수가 아니다.

## R-2 조합 순서는 **장식이 아니다** — 회복이 독을 거부한다

`m_healOne` 의 첫 줄:

```cpp
if ((p_target->dead > 0) || (p_target->unconscious > 0) || (p_target->poison > 0))
    return;
```

**독에 걸려 있으면 회복이 안 된다.** 죽거나 쓰러진 것만이 아니다.
그래서 `치료와 독제거`(21)가 독을 먼저 지운 뒤 회복하는 순서여야 하고, 그것이 이 마법이
별도로 존재하는 이유다. `m_antidoteOne` 도 쓰러진 대상에는 닿지 않으므로,
`24`(의식돌림 → 독제거 → 회복)의 순서 역시 필연이다.

## R-3 비용 — 대상 상태에 따라 달라진다

| 갈래 | 비용 | 효과 |
|---|---|---|
| heal | `2 × 시전자 마법레벨` | `비용 × 3/2` 회복, 최대치에서 멈춤 |
| antidote | **15 고정** | `poison = 0` |
| recoverConsciousness | **`10 × 대상의 의식불명 누적값`** | `unconscious = 0`, `hp` 최소 1 |
| revitalize | **30 고정** | `dead = 0`, `unconscious` 를 임계값으로 클램프(최소 1) |

`recoverConsciousness` 의 비용이 누적값에 비례한다 — 부록 Q-2 의 누적값 기제가
**여기서 두 번째 용도를 얻는다.** 깊이 쓰러졌으면 깨우는 값이 비싸다.

**부활은 의식불명 상태로 돌려놓는다.** 완전 회복에는 부활 + 의식 돌림이 둘 다 필요하다.

그리고 **치료는 SP 를 실제로 차감한다**(`p_player->sp -= consumption` 이 네 함수 모두에 있다).
공격 마법 쪽 미차감(부록 O-1)은 여전히 B2-01 이 갚아야 한다.

## R-4 선택 게이트가 절반마다 다르다

```cpp
int num_enabled = p_player->level[1] / 2 + 1;   // 단일 대상
int num_enabled = p_player->level[1] / 2 - 3;   // 전체 대상
```

둘 다 7 로 상한. 전체 대상은 값이 양수가 아니면 **거부**하므로 마법 레벨 **8** 이 필요하다.

그 거부 조건에 C++ 이 스스로 주석을 달아 놨다 — `//@@ 원래는 < 0 이었음 검토 필요`.
`< 0` 이면 0개짜리 메뉴가 열리므로 바꾼 쪽이 맞아 보여 받아들였지만, **신뢰가 아니라 표시**다.

## R-5 C++ 버그 — 마법 레벨 0 인 시전자가 0 을 회복시키고 성공을 보고한다

`heal` 의 비용은 `2 × 마법레벨`, 회복량은 `비용 × 3/2`. 마법 레벨 0 이면 **비용 0, 회복 0** 이다.
그런데 단일 대상 게이트가 `level/2 + 1` 이라 레벨 0 에게도 `치료` 를 **한 칸 열어 준다.**
→ 아무 일도 없는데 성공한 것처럼 처리된다. 버그로 보고 거부하게 했다(6차 판정).

실제로 이 레포의 시작 파티에서 재현된다 — 유리는 마법 레벨 0 이다.

## R-6 ⚠ 자동 전투(`case 8`)는 **직업별 분기**이고, C++ 이 버그를 자백해 놨다

`hd_base_game_main.cpp` 의 전투 명령 수집 `case 8`:

| 직업 | 행동 |
|---|---|
| 0·1·4·5·6·7·8·10 | 물리 공격 |
| 2·9 | 단일 공격 마법. 마법 레벨 0~3 → 1번, 4~11 → 2번, 그 위 → 3번 |
| 3 | 초능력 5번(염력) |

현재 Dart 는 이것을 전부 "첫 생존 적 물리 공격" 으로 뭉갰다(`battle.dart:377-382`).

그리고 직업 3 의 대상 선정에 **C++ 자신의 주석이 붙어 있다**:

```cpp
{ // @@ dead 맞나?
    if ((enemy[ix_enemy]->unconscious == 0) && (enemy[ix_enemy]->dead))
        target = ix_enemy;
}
```

**의식이 있고 죽은 적**을 고른다 — 그런 적은 존재하지 않는다. `!dead` 였어야 한다.
게다가 루프가 `ix_enemy = 1` 에서 시작해 0번 적을 건너뛴다. 버그 2개다.
B2-07(적 행동)이 아니라 **자동 전투** 항목이 받아야 하므로, 이식할 때 이 두 줄은 고친다.

## R-7 공격 마법의 선택 게이트도 단계형이다

같은 곳의 `case 2`~`case 4` 가 `level2`(마법 레벨) 문턱으로 개수를 정한다 —
단일 공격은 `≤3 / ≤7 / ≤11 / ≤15`, 전체 공격은 `≤2 / ≤5 / ≤9 / ≤13 / ≤17`,
특수 공격은 `≤9 / ≤11 / ≤13 / ≤15 / ≤17`. 현재 Dart 의 "레벨 = 개수, 카테고리 크기로 상한"
(`magic_system.dart:225-227`)과 다르다. **B2-01 이 이 문턱표를 받아야 한다.**

---

# 부록 S — 공격 마법의 카테고리 경계와 초능력 (2026-09-05, B2-01)

C++ 은 정본이 아니다([6차 판정](../../issues/DECISION-LOG.md)). 아래는 개념·구조의 증거다.

## S-1 **Dart 의 마법 카테고리 경계가 틀렸다**

`hd_base_game_main.cpp` 의 전투 메뉴가 `ixMagicOffset` **0 / 6 / 12** 로 각 **6종**을 만든다:

| 카테고리 | Dart 가 쓰던 것 | 실제 | 마법 |
|---|---|---|---|
| 단일 공격 | 1~3 | **1~6** | 마법 화살 · 마법 화구 · 마법 단창 · 독 바늘 · 맥동 광선 · 직격 뇌전 |
| 전체 공격 | 4~10 | **7~12** | 공기 폭풍 · 열선 파동 · 초음파 · 초냉기 · 인공 지진 · 차원 이탈 |
| 특수 공격 | 11~18 | **13~18** | 독 · 기술 무력화 · 방어 무력화 · 능력 저하 · 마법 불능 · 탈 초인화 |
| 초능력 | 41~45 | 41~45 (5종) | 투시 · 예언 · 독심 · 천리안 · 염력 |

**이름과 정확히 맞는다** — 독 바늘·맥동 광선·직격 뇌전은 단일 대상이고, 인공 지진·차원 이탈은
광역이다. 낡은 경계는 독 바늘을 전체 공격에, 인공 지진을 능력 저하 계열에 넣고 있었다.

## S-2 마법 피해·비용은 **카테고리 내 순번**의 제곱이다

`castSpellToOne`:

```cpp
int consumption = (ix_object * ix_object * p_player->level[1] + 1) / 2;
int damage      =  ix_object * ix_object * p_player->level[1] * 2;
```

`ix_object` 는 메뉴 선택값 `selected - 1`, 즉 **1~6** 이다(전역 마법 id 가 아니다).
그래서 카테고리 끝 마법이 첫 마법의 **36배**로 때리고 비용도 그만큼 든다.
5차 판정이 이 값을 "그대로 옮길 것" 으로 적었고 6차 판정이 그것을 뒤집었지만,
**곡선 자체는 결과적으로 받아들였다** — 카테고리를 6칸으로 보면 1~36배 대역이 합리적이다.

전체 공격은 `castSpellToAll` 이 `castSpellToOne` 을 **적마다 호출**하므로 **비용도 적마다** 든다.

## S-3 마법 판정은 물리와 미묘하게 다르다

| | 물리 | 마법 |
|---|---|---|
| 명중 | `random(20) > accuracy[0]` → 실패 | `random(20) >= accuracy[1]` → 실패 |
| 저항 | `random(100) < resistance` | 같음 |
| 방어 항 | `(ac × level × (rand(10)+1)) / 10` **버림** | `(ac × level × (rand(10)+1) + 5) / 10` **반올림** |

명중은 같은 값에서 마법이 한 칸 더 잘 빗나가고, 방어는 마법에 살짝 더 잘 통한다.
두 갈래 모두 원작 그대로 옮겼다.

## S-4 특수 마법(13~18)은 마법마다 비용·판정 범위가 다르다

| id | 마법 | SP | 저항 범위 | 명중 범위 |
|---|---|---|---|---|
| 13 | 독 | 10 | 100 | 40 |
| 14 | 기술 무력화 | 30 | 100 | 60 |
| 15 | 방어 무력화 | 15 | 100 | **ac<5 → 40, 아니면 25** |
| 16 | 능력 저하 | 20 | **200** | 30 |
| 17 | 마법 불능 | 15 | 100 | 100 |
| 18 | 탈 초인화 | 20 | 100 | 100 |

16 의 저항 범위가 200 이라 저항의 효과가 절반이다(강한 마법이라 저지가 어렵다).
15 는 **가벼운 갑옷을 입은 적이 벗기기 쉽다.**

## S-5 초능력은 전혀 다른 물건이다 — 별 이슈로 뺐다

`useESPForBattle`(271줄), `ix_object` 1~5 ↔ 마법 41~45:

| 색인 | 마법 | 전투 중 동작 |
|---|---|---|
| 1·2·4 | 투시 · 예언 · 천리안 | **아무것도 하지 않는다.** 이름만 출력하고 반환 |
| 3 | 독심 | ESP 15. **적이 파티에 합류한다** — 화이트리스트 `{6,10,20,24,27,29,33,35,40,47,53,62}` 의 `ed_number` 만 가능. 성공하면 `player[size-1]` 에 적 데이터를 넣고 그 적은 제거된다 |
| 5 | 염력 | ESP 20. `random(ESP레벨)+1` 로 **랜덤 효과표**를 굴린다 |

염력의 효과표:

| 굴림 | 효과 |
|---|---|
| 1~6 | 단일 대상 `굴림 × 10` 피해 |
| 7~10 | 전체 대상 `굴림 × 5` 피해 |
| 11~12 | 공포 — 적이 **도망간다**(`dead = 1`). 실패 시 저항·체력 -5 |
| 13~14 | 독 (`++poison`) |
| 15~17 | 심장 정지 — `++unconscious`(누적값!). 실패 시 hp -10 |
| 18+ | 환상 — 명중 -1 두 칸. 실패 시 민첩 -5 |

**실패 분기도 뭔가를 한다** — 부분 효과가 있다. 그리고 위력 상한이 ESP 레벨에 비례한다.

**독심의 파티 합류는 모드 인계 규격을 바꾼다**(파티원이 늘어난다). 그래서 B2-01 에 넣지 않고
[B2-10](../../issues/B2-battle-expand/B2-10-esp-abilities.md) 으로 뺐다.
현재 초능력 41~45 는 B1 의 뭉친 공식을 그대로 쓴다.

---

# 부록 T — 적 AI 의 실체 (2026-09-05, B2-07)

C++ 은 정본이 아니다([6차 판정](../../issues/DECISION-LOG.md)). 구조는 받고 버그는 고쳤다.

## T-1 디스패처 `PcEnemy::attack()` — 두 가지를 잃고 있었다

```cpp
if (special_cast_level > 0)
    enemyCastSpellWithSpecialAbility(p_enemy);   // ← return 이 없다
int agility = min(agility, 20);
if ((special > 0) && (random(50) < agility))
    if (getNumOfConsciousPlayer() > 3) { enemyAttackWithSpecialAbility(...); return; }
if ((random(acc[0]*1000) > random(acc[1]*1000)) && strength > 0) 물리;
else if (cast_level > 0) 마법; else 물리;
```

- **`special_cast_level` 이 있는 적은 한 턴에 두 번 행동한다.** 초자연 시전 뒤에 `return` 이
  없어서 일반 행동까지 한다. 그 필드는 Dart 에서 **읽는 곳이 0곳**이었다(부록 O) — 이것이 용도다.
- **특수 능력은 의식 있는 파티원이 4명 이상**이어야 나온다. 시작 파티(2명)로는 **절대 안 나온다.**
  적이 단조롭게 느껄린 큰 이유다.

## T-2 마법은 `cast_level` 1~6 사다리다

| 레벨 | 행동 |
|---|---|
| 1 | 아무 슬롯이나 골라 단일 공격 (의식 없으면 **한 번만** 다시 뽑음) |
| 2 | 의식 있는 무작위 대상 |
| 3 | `random(의식 있는 수) < 2` 면 단일, 아니면 전체 |
| 4 | 체력이 1/3 아래 + `random(2)==0` → **자기 치료**, 아니면 3 과 같음 |
| 5 | 4 와 같으나 `random(3)`, 그리고 무리가 상하면 **동료 전체 치료**. 단일은 **가장 약한 대상** |
| 6 | 5 에 더해 `random(5)==0` 로 **파티 방어구를 갈아 내림** (파티 평균 ac > 4 일 때) |

체력 판정은 `hp < endurance × level / 3` 이다 — 최대 체력이 곧 `endurance × level` 이므로 1/3 이다.

## T-3 **적이 동료를 치료하고 되살린다**

`enemyCastCureSpell(caster, target, recovery)`:

```
target->dead > 0        → dead = 0            (부활)
else unconscious > 0    → unconscious = 0, hp 최소 1
else                    → hp += recovery, 최대치에서 멈춤
```

회복량은 **자기 `level × mentality / 4`, 동료 `/ 6`** — 자기를 더 잘 챙긴다.
한 번에 한 단계씩 되돌리므로 파티의 부활 사슬(`rules/cure.dart`)과 같은 모양이다.

## T-4 특수 능력 3종 — **행운이 막아 준다**

`enemyAttackWithSpecialAbility(special)`:

| special | 효과 | 민첩 판정 범위 | 대상 |
|---|---|---|---|
| 1 | 독 (`++poison`) | 40 | 의식 있는 대상. **중독 안 된 사람을 5번까지 다시 뽑는다** |
| 2 | 기절 (`unconscious = 1, hp = 0`) | 50 | 의식 있는 대상 |
| 3 | **즉사** (`dead = 1, hp = 0`) | 60 | `NOT_DEAD` — **쓰러진 사람도 노린다** |

두 단계 판정이다: `random(범위) > 적 민첩` 이면 실패, 그다음 `random(20) < 대상 행운` 이면 회피.

**행운이 처음으로 일을 한다.** Dart 에서 `luck` 은 도주 공식에서만 읽혔다.
**단 시작 파티는 행운이 0 이라 하나도 못 막는다.**

3번이 `NOT_DEAD` 를 쓰는 것이 중요하다 — 쓰러진 파티원이 안전하지 않다는 뜻이고,
2단계 붕괴(B2-04)가 의미를 갖는 나머지 절반이다.

## T-5 C++ 버그 3건 — 전부 고쳤다

`enemyCastSpell` `case 6`:

1. **`average_ac` 가 파티가 아니라 적 자신의 ac 를 더한다** —
   `accum_ac += p_enemy->ac;` 여야 할 것이 `(*obj)->ac` 다. 파티 무장과 무관하게 판정된다
2. **방어구 갈아 내리는 루프가 `player.begin()+1` 에서 시작한다** — **슬롯 0 은 절대 안 깎인다.**
   초기화도 없어서 의도한 것으로 보기 어렵다
3. `case 5` 의 **가장 약한 대상 탐색이 `isConscious` 를 확인하지 않는다** — 초기값이
   `*player.begin()` 이라 빈 슬롯이나 죽은 사람을 고를 수 있다.
   **`case 6` 은 같은 탐색을 센티널과 `isConscious` 로 제대로 한다** → 고친 형태가 원작 자신의 것이다

세 번째가 특히 강한 증거다 — 같은 파일 안에서 같은 탐색을 두 번 쓰는데 한쪽만 맞다.

## T-6 초자연 시전은 뗐다 → B2-11

`enemyCastSpellWithSpecialAbility` 는 `special_cast_level` 3단으로 쌓인다:

| 단 | 효과 |
|---|---|
| ≥1 | **적을 소환한다** — 무리가 줄면 `registerEnemy(ed_number + random(4) - 20)` (자기보다 약한 변종) |
| ≥2 | **파티원을 적으로 끌어간다** — 마지막 유효 파티원을 적 목록에 복사하고 이름을 지운다 |
| ≥3 | `special != 0` 이고 `random(5)==0` 이면 파티 전원에게 즉사 판정 |

**2단이 파티원을 없앤다** — 모드 인계 규격이 바뀐다(B2-10 의 독심과 같은 종류).
그래서 [B2-11](../../issues/B2-battle-expand/B2-11-superhuman-casting.md) 으로 뺐다.
현재는 초자연 시전이 "사용했다" 로 announce 만 되고 효과는 없다.

이 함수에는 porter 의 불확실 표시가 둘 있다 — `//@@ 0 맞나?` · `//@@ 0이 맞는지 확인 필요`.

---

# 부록 U — 새 전투식의 피해 대역 (2026-09-05, B2-99 규격 확정)

`packages/hd_battle/tool/damage_band.dart` 로 재생성한다. 10×10 뽑기 조합 전수 계산이고,
**수식을 복사하지 않고 출하된 함수를 직접 구동**한다 — 부록 H-2 를 만든
`defense_scale_test.dart` 가 복사본을 써야 했던 것과 다른 점이다.

> **파티 인원과 무관한 표다** — 한 대당 피해이므로 2인이든 5인이든 같다.
> 인원에 따라 달라지는 것(라운드 수 · 적 특수 능력 발동)은 부록 W 다.
> 이 표를 읽을 때 "전투가 이 정도 길이더라" 는 감각은 **2인 fixture 에서
> 온 것이므로 믿지 말 것.**

## U-1 물리 피해 — 착용 방어구만 (방패 0)

| 적 | 착용 ac | 피해 발생 % | 최대 피해 |
|---|---|---|---|
| Orc | 0 | 90.0% | 8 |
| Orc | 2 | 83.0% | 8 |
| Orc | 5 | 62.0% | 8 |
| Orc | 10 | 31.0% | 7 |
| Orc | 20 | 13.0% | 6 |
| Troll | 0 | 90.0% | 9 |
| Troll | 2 | 83.0% | 9 |
| Troll | 5 | 65.0% | 9 |
| Troll | 10 | 36.0% | 8 |
| Troll | 20 | 16.0% | 7 |
| Giant | 0 | 100.0% | 30 |
| Giant | 5 | 95.0% | 30 |
| Giant | 20 | 67.0% | 28 |
| Black Knight | 0 | 100.0% | 945 |
| Black Knight | 20 | 100.0% | 943 |

**물리 피해식은 바뀌지 않았다** — Troll 의 83/65/36/16 은 부록 H-2 와 같다.
달라진 것은 `ac` 에 들어가는 값이다: **착용 방어구만** 들어가고 방패는 빠졌다(U-2).

**Black Knight 의 945 는 밸런스가 아니다.** `strength 63 × level 30 × (1~10) / 10` 이
그대로 나온 것이고, 원작 전투식을 옮긴 결과다. 후반 적의 피해가 파티 최대 체력을
몇 배로 넘는 것은 이 게임의 원래 성질이며, 밸런스 재설계는 B2 의 범위가 아니었다.

## U-2 방패는 다른 축이다

방패는 방어구를 더하지 않고 **한 대를 통째로 막는 확률**로 굴린다(B2-08).

| 방패 블록 | 실제로 맞는 비율 (Troll, 착용 ac 5) |
|---|---|
| 0 | 65.0% |
| 15 | 55.3% |
| 30 | 45.5% |
| 45 | 35.8% |
| 60 | 26.0% |
| 75 | 16.3% |
| 100 | 16.3% (상한 75) |

방패 45 가 착용 ac 10(36.0%)과 비슷한 값을 낸다 — **같은 점수를 방패로 쓰는 것이
방어구로 쓰는 것보다 유리하도록** 의도한 결과다. 상한 75 는 방패가 벽이 되지 않게 한다.

## U-3 마법 피해 — 카테고리 내 순번

`순번² × 마법레벨 × 2`, 비용 `(순번² × 마법레벨 + 1) / 2` (B2-01, 부록 S-2).

| 순번 | 피해 (마법레벨 20) | 비용 |
|---|---|---|
| 1 | 40 | 10 |
| 2 | 160 | 40 |
| 3 | 360 | 90 |
| 4 | 640 | 160 |
| 5 | 1000 | 250 |
| 6 | 1440 | 360 |

**마법이 물리를 압도한다** — 마법 레벨 20 의 6번 마법 1440 대 무기의 한 자릿수.
원작 수식을 옮긴 결과이고, 시작 파티의 슴갈이 마법 레벨 20 인 것도 원작 설정이다.
전체 공격 마법은 **적마다** 비용을 물어 총 비용이 커지는 것이 유일한 제동이다.
밸런스를 볼 때 여기가 첫 지점이다.

## U-4 속성 상성은 이 표에 곱해진다

약점 ×2, 저항 ÷2 (B2-09). 속성이 붙은 마법은 18종 중 9종이고 나머지는 무속성이라
상성이 적용되지 않는다 — 설계가 얇다는 것을 표가 정직하게 보여준다.

# 부록 V — 원작의 색 규격 (2026-09-05, 콘솔 view 착색 중 확인)

전투 콘솔에 색을 넣으려고 원작을 뒤졌더니 **색은 이미 규격으로 존재했다.**
지어낼 것이 아니라 옮길 것이었다. 근거는 네 곳이다.

## V-1 16색 표 — `hd_base_gfx.cpp:17-40`

`getColorFromIndexedColor(index, default)` 가 0~15 의 표를 들고 있다.

| 번호 | ARGB | 이름 | 번호 | ARGB | 이름 |
|---|---|---|---|---|---|
| 0 | `FF000000` | 검정 | 8 | `FF404040` | 진한 회색 |
| 1 | `FF000080` | 파랑 | 9 | `FF0000FF` | 밝은 파랑 |
| 2 | `FF008000` | 초록 | 10 | `FF00FF00` | 밝은 초록 |
| 3 | `FF008080` | 청록 | 11 | `FF00FFFF` | 밝은 청록 |
| 4 | `FF800000` | 빨강 | 12 | `FFFF0000` | 밝은 빨강 |
| 5 | `FF800080` | 자홍 | 13 | `FFFF00FF` | 밝은 자홍 |
| 6 | `FF808000` | 갈색 | 14 | `FFFFFF00` | 노랑 |
| 7 | `FF808080` | 밝은 회색 | 15 | `FFFFFFFF` | 하양 |

**순서가 DOS 색 번호와 같다.** 그래서 ANSI 16색(30~37 / 90~97)과 번호 하나
어긋남 없이 맞고, 터미널에 그대로 옮길 수 있다. 범위 밖 번호는 기본색으로
떨어진다 — 자산에 실제로 있는 `@G`(=16)가 그 경로를 탄다.

## V-2 색은 글자 단위로도 지정된다 — `@` 표기

`drawFormatedText`(`hd_base_gfx.cpp:107-158`)가 문자열 안의 `@` 를 색 지정으로 읽는다.

- `@0`~`@9` · `@A`~`@F` : 그 번호 색으로 바꿈
- `@@` : 기본색으로 되돌림
- 범위 밖 : 기본색

**게임 데이터가 실제로 쓴다.** `hadar2026_app/assets/*.cm2` 에서:
`@7`(설명문) 80건 · `@@` 34건 · `@B`(아이템 획득 `[황금 방패 +1]`) 17건 ·
`@A`(강조·고유명사) 9건 · `@C` 4건 · `@D` 3건 · `@G` 1건.
`hd_res_string.cpp:237` 의 `@F<<< 방향을 선택하시오 >>>@@` 도 같은 표기다.

**소문자 분기는 원작의 버그다** — `index_char - 'A' + 10` 이라 `'a'` 가 42 가 되어
범위 밖으로 떨어진다. 값이 아니라 입력 해석이고 자산이 소문자를 쓰지 않아 그대로 두었다.

## V-3 전투 메시지는 전부 색 번호를 달고 나간다 — `writeConsole(색번호, ...)`

`hd_base_extern.cpp:241` 의 시그니처가 `writeConsole(unsigned long index, int num_arg, ...)`
이고 **첫 인자가 색 번호**다. 즉 원작의 모든 전투 줄에는 색이 지정되어 있었다.
호출부를 훑어서 얻은 규칙:

| 색 | 뜻 | 대표 호출 |
|---|---|---|
| 12 밝은 빨강 | **일행이 움직인 줄** | `pc_player.cpp:1010,1016,1035,1064,1124,1175` |
| 13 밝은 자홍 | **적이 움직인 줄** | `pc_enemy.cpp:324,481,575,601,632,704,795,844` |
| 7 밝은 회색 | 빗나감·저지·막힘·실패·안내 | `pc_enemy.cpp:309,325,334,579`, `pc_player.cpp:1041,1147` |
| 5 자홍 | **일행이 입은 피해** | `pc_enemy.cpp:346,488,909` |
| 4 빨강 | 상태가 나빠짐 (중독·의식불명·사망·능력 저하) | `pc_enemy.cpp:589,615,646`, `pc_player.cpp:1735,1757,1782,1808` |
| 15 하양 | 치료 성공·금화 | `pc_player.cpp:1963,1997,2036,2071`, `game_main.cpp:368` |
| 14 노랑 | 경험치 | `pc_player.cpp:2160` |
| 11 밝은 청록 | 도주 성공·적 영입 | `pc_player.cpp:1486,1890` |
| 10 밝은 초록 | 적이 겁먹고 달아남 | `pc_player.cpp:1618` |

**줄 색과 글자 색이 겹쳐 쓰인 자리가 두 곳 있다.** `pc_enemy.cpp:346`·`:909` 는
줄을 5번으로 내면서 피해 수치만 `@D`(13)로 감쌌다.

### V-3-1 C++ 이 스스로 표시한 이탈 1건

`pc_player.cpp:1074`·`:1185` — 일행이 적에게 준 피해 줄이다.

```cpp
writeConsole(7, 3, "적은 ", IntToStr(damage)(), "만큼의 피해를 입었다"); // 원래는 중간이 15번 색
```

주석이 "원래는 중간이 15번 색" 이라고 적혀 있다. 적이 준 피해(5번 줄 + `@D` 수치)와
**대칭**이므로 주석 쪽이 맞다. [6차 판정](../../issues/DECISION-LOG.md)에 따라 원래
형태(7번 줄 + `@F` 수치)로 되돌렸다.

## V-4 이름 색이 곧 상태였다 — 창 두 개의 규칙

### V-4-1 적 이름 — `hd_class_window_battle.h:27-47`

```
hp > 300  → 10 밝은 초록      hp <= 50 → 4  빨강
hp <= 300 → 2  초록           hp <= 20 → 12 밝은 빨강
hp <= 200 → 14 노랑           hp <= 0  → 8  진한 회색
hp <= 100 → 6  갈색
unconscious → 8 · dead → 0 (HP 판정을 덮어씀)
```

**비율이 아니라 절대 HP** 로 나눈다. 최대 HP 를 보지 않으므로 덩치 큰 적은 반쯤
깎여도 초록이고 작은 적은 멀쩡해도 빨갛다. 원작이 적의 최대 HP 를 화면에 보여주지
않았으니 앞뒤는 맞는다.

**죽은 적은 0번(검정)** 이다. 배경이 항상 검정이었으므로 이것은 "목록에서 지운다" 는
뜻이었다. 터미널은 배경색을 고를 수 없어서 콘솔 renderer 만 0번을 8번으로 바꾼다 —
규칙 자체는 원작대로 0번을 낸다.

### V-4-2 파티 이름 — `hd_class_pc_player.cpp:238-256` `getConditionColor`

| 상태 | 색 |
|---|---|
| GOOD | 15 하양 |
| POISONED | 13 밝은 자홍 |
| UNCONSCIOUS | 7 밝은 회색 |
| DEAD | 8 진한 회색 |

빈 슬롯("예약됨")은 `getRealColor(4)` — 빨강(`hd_class_window_status.h:74`).
**원작은 320x240 화면에 상태 이름을 적을 자리가 없어서 이름 색으로만 상태를 알렸다**
(`hd_class_window_status.h:70` 주석이 그렇게 적어 뒀다).

## V-5 메뉴도 색 규칙이 있다 — `hd_class_select.cpp:12-33`

| 무엇 | 색 |
|---|---|
| 머리글 | `FFFF0000` = 12 밝은 빨강 |
| 지금 고른 항목 | `FFFFFFFF` = 15 하양 |
| 고를 수 있는 항목 | `FF808080` = 7 밝은 회색 |
| 고를 수 없는 항목 | `FF000000` = 0 검정 (= 안 보임) |

"고를 수 없는 항목을 검정으로 지운다" 가 V-4-1 의 죽은 적과 같은 수법이다.

## V-6 이 규격이 지금 어디에 있나

`hd_battle_console/lib/palette.dart` 가 V-1·V-2 를, `lib/view.dart` 의 `colorOf` 가
V-3 을, `palette.dart` 의 `enemyNameColor`·`conditionColor` 가 V-4 를 담는다.
`hd_battle_console/test/palette_test.dart` 가 표와 규칙을 고정한다.

**model(`packages/hd_battle`)은 색을 모른다.** 색은 view 의 일이고, B4 의 Flutter
view 는 같은 표(V-1 의 ARGB 값)를 그대로 쓰면 된다.

# 부록 W — 5인 파티가 기본이라는 전제와 그 결과 (2026-09-05, B5 착수 전 실측)

B5(위치 전투)를 논의하다 **파티 인원 전제가 틀렸다**는 것이 드러났다. 지금까지의
전투 실측은 거의 전부 2인 파티에서 나왔는데, **실제 게임은 5인 + 소환수**다.
이 부록은 그 차이가 무엇을 바꾸는지 실측한 것이다.

측정 방법: `packages/hd_battle` 을 직접 구동. 같은 적·같은 명령(무조건 공격)·시드 1~60.

## W-1 라운드 수가 **절반이 된다**

| 적 | 파티 2인 | **파티 5인** | 파티 6인 |
|---|---|---|---|
| Giant + Wolf | 9 (7~14) | **4** (3~6) | 4 (2~6) |
| Orc ×3 | 5 (3~8) | **3** (2~4) | 3 (2~4) |
| Devil Hunter ×7 | 1 — 전멸 | 3 — 전멸 | 4 — 전멸 |

중앙값(최소~최대). **실전 전투는 3~4 라운드다.**

5인과 6인의 차이는 거의 없다 — 한 명 더 늘어도 길이가 안 바뀐다.

→ 라운드 안에서 시간이 걸리는 기제(이동·준비·축적)를 설계할 때 **쓸 수 있는 라운드가
3~4 뿐**이라는 것이 상한이다. 2인 기준(9라운드)으로 잡으면 두 배 어긋난다.

## W-2 적의 특수 능력은 **5인부터 발동한다**

Basilisk ×2, 같은 시드에서 `EnemyAbilityUsed` 발생 횟수:

| 파티 | 발동 |
|---|---|
| 2인 | **0회** |
| **5인** | **10회** |
| 6인 | 9회 |

부록 T 가 찾아낸 `consciousPlayers > 3` 게이트(`rules/enemy_ai.dart:53`,
원작 `PcEnemy::attack` 의 `getNumOfConsciousPlayer() > 3`)가 실제로 이렇게 작동한다.

**적의 큰 기제 하나가 지금까지 한 번도 켜지지 않은 채로 밸런스를 봐 왔다.**

같은 게이트가 적의 시전 사다리에도 있다 — `rng.next(consciousPlayers) < 2`
(`enemy_ai.dart:187,192,197,215`). 2인이면 **항상 참**이고 5인이면 40% 다.
**적의 마법 대상 선택 확률 자체가 파티 인원에 따라 달라진다.**

## W-3 그래서 fixture 17개 중 14개가 대표성이 없다

| 파티 인원 | fixture 수 |
|---|---|
| 1인 | 2 |
| **2인** | **14** |
| 4인 | 1 |
| 5인 이상 | **0** |

B1·B2 가 남긴 모든 대역표와 감각(부록 O·U 포함)은 이 구성에서 나온 것이다.
**5인 기준 fixture 를 다시 만들기 전에는 어떤 밸런스 판단도 근거가 약하다.**

## W-4 `resistance` 는 확률 판정이 아니라 **종족 특성**이라고 말하고 있다

적 테이블 75행의 `resistance` 분포:

| 값 | 종수 | 뜻 |
|---|---|---|
| **0** | **38** | 절반 이상이 **저항 판정에 걸리지 않는다** |
| 10~70 | 29 | 어중간 |
| 80~100 | 6 | Sprite · Death Skull · Ancient Evil · Lord Ahn · Panzer Viper · Neo-Necromancer 등 |
| **255** | **2** | **Stheno · Euryale** — `rand(100) < 255` 는 항상 참 = **물리 완전 면역** (`ac` 도 255) |

`enemyResistsAttack`(`rules/physical.dart:22`)과 `enemyResistsMagic`
(`rules/attack_magic.dart:134`)은 **문자 그대로 같은 식**이다 —
`rng.next(100) < enemyResistance`. 물리가 마법 저항을 빌려 쓰고 있다.

→ 데이터는 "물리 면역은 종족·보스의 특성" 이라고 말하는데 구현은 전 종족 확률 판정이다.
절반 넘는 적에게는 아무 일도 하지 않고, 소수에게는 사실상 면역이다.

## W-5 아군과 적의 피해 변동식이 서로 다른 모양이다

```
적  →  아군 :  damage = strength × level × (rand(10)+1)/10      배율 0.1 ~ 1.0
아군 →  적  :  damage -= damage × rand(50)/100                  배율 0.51 ~ 1.0
```

**적 쪽에는 이미 넓은 배율이 있고 아군 쪽에는 좁은 것이 있다.** 회피에 따른 피해 배율을
넣는다면 그것은 새 굴림을 더하는 것이 아니라 **아군을 적과 같은 모양으로 맞추는 것**이다.

슴갈(힘 18 · 무기 10 · 물리레벨 1) → Orc(ac 1 · 레벨 1), 40,000회:

| 사슬 | 평균 | 피해 발생 | 최대 |
|---|---|---|---|
| 지금 | 7.18 | 100% | 9 |
| 회피 배율을 **그냥 얹음** | 3.09 | 85% | 8 |
| `rand(50)` 을 **회피 배율로 교체** | 3.90 | 88% | 8 |
| 교체 + 기본식 ×2 | 8.41 | 94% | 17 |

**변동원을 둘로 겹치면 평균이 절반 아래로 떨어진다.** 교체해야 하고, 그래도 기본식을
올려야 지금 수준이 유지된다.

## W-6 `agility` 를 읽는 곳은 아직 둘뿐이다

`rules/` 와 `model/` 전체에서 `agility` 를 실제로 읽는 지점:

1. 선제 굴림 — `initiative.dart` (B2-05 가 만든 것)
2. 도주식 — `escape.dart:34`

(그 외는 필드 선언·전달·염력의 민첩 감소뿐이다.) 75행 테이블의 한 칸이 여전히 거의 놀고 있다.

## W-7 전투 중 합류는 지금 **판에서 지우는 방식**이다

`model/battle.dart:920` — 독심술(마법 43)로 마음을 돌린 적:

```dart
_recruits.add(_snapshotOfEnemy(t));   // slot: -1
t.dead = 1; t.unconscious = 1; t.hp = 0; t.level = 0;
```

- 영입된 적은 **그 전투에서 싸우지 않는다.** 판에서 완전히 지워진다
- `slot: -1` 로 넘기고 **전투가 끝난 뒤 RPG 가 자리를 정한다**
- **정원 검사가 없다.** `BattleSetup` 은 `party`·`enemyKeys`·`seed`·`mode`·`consumables`
  뿐이라 **빈 슬롯이 몇 칸인지 모른다**

`slot` 은 규격에 "0..5, 두 세계를 잇는 열쇠" 로 정의되어 있다(`battle_setup.dart:52`).
소환은 현재 **적 전용**이다 — `EnemySummoned(callerIndex, enemyIndex)`. 아군 소환 이벤트는 없다.

# 부록 X — B5 위치 전투의 실측 (2026-09-05~, 구간 진행 중)

부록 W 가 B5 **착수 전**의 실측이라면, 이 부록은 **만들면서** 나온 것이다.
구간이 끝나면 여기가 새 전투의 대역표가 된다.

## X-1 초기 간격 분포 — 위치가 3~4 라운드 안에 들어간다

`packages/hd_battle/tool/opening_gap.dart` 로 재생성한다.
간격은 `openingGap()` 이 양측의 민첩·레벨 평균에서 유도하고,
조우가 `BattleSetup.initialGap` 으로 덮어쓸 수 있다(기습 0 · 원거리 발견 2).

적 75종 각각을 혼자 세웠을 때, 파티 물리 레벨별 분포:

| 파티 레벨 | 간격 0 (붙어서 시작) | 간격 1 | 간격 2 |
|---|---|---|---|
| 1 | **100%** | 0% | 0% |
| 3 | 99% | 1% | 0% |
| 5 | 95% | 5% | 0% |
| 8 | 88% | 11% | 1% |
| 12 | 64% | 24% | 12% |
| 20 | 35% | 20% | **45%** |

실제 조우:

| 조우 | 레벨 1 | 레벨 5 | 레벨 20 |
|---|---|---|---|
| Orc ×3 | 0 | 1 | 2 |
| Giant + Wolf | 0 | 0 | 2 |
| Devil Hunter ×7 | 0 | 0 | 2 |
| **Archi-Mage** | 0 | 0 | **0** |
| **Neo-Necromancer** | 0 | 0 | **0** |

읽히는 것 셋:

1. **초반에는 위치 놀이가 없다.** 레벨 1 이면 100% 가 간격 0 이다 — 무엇을 만나든
   이미 붙어 있다. 대열(누가 앞에 서나)은 여전히 결정이지만 간격은 아니다
2. **강해질수록 거리가 생긴다.** 약한 것을 만나면 붙기 전에 정리할 여유가 있다
3. **보스는 레벨과 무관하게 붙어서 시작한다.** Archi-Mage 도 Neo-Necromancer 도
   레벨 20 파티 앞에서 간격 0 이다. 거리를 둘 수 없는 상대라는 것이 그대로 나온다

**3~4 라운드 안에 들어간다**(부록 W-1). 대부분 0~1 에서 열리므로 붙는 데 한 번이면 되고,
간격 2 는 파티가 이미 우위인 상황에서만 나온다.

## X-2 사거리 밖은 벌점이다 — 헛턴이 나오는 경로가 없다

```
1칸 모자라면   명중 -6,  가까운 쪽이 30% 확률로 대신 맞음
2칸 이상       명중 -14, 55% 확률로 대신 맞음
```

가로채기 확률이 100% 가 되지 않는 것이 규칙이다(`position_test.dart`) —
**반드시 남이 대신 맞는 공격은 이름만 바꾼 헛턴**이다.

`fixtures/rules/reach.json` 이 이것을 보여준다. Archi-Mage 를 3열에, Orc 셋을 1열에
두고 간격 1 에서 전원이 보스를 노린다:

```
슴갈은 1칸 멀리 있는 ArchiMage를 향해 몸을 뻗었다
앞을 막아선 Orc이 슴갈의 공격을 ArchiMage 대신 받아냈다
유리는 2칸 멀리 있는 ArchiMage를 향해 몸을 뻗었다
```

1열의 슴갈은 1칸, 2열의 유리는 2칸 모자란다. **앞을 치우지 않으면 보스에 닿지 않지만,
목록에서 빠지지는 않는다** — 빈틈을 노리는 도박이 남는다.

## X-3 열 가중 대상 선택 — 파티에 방어 쪽 결정이 처음 생겼다

`packages/hd_battle/tool/target_share.dart` 로 재생성한다.

전에는 `pickTargetIndex` 가 **의식 있는 파티원 중 균등 추첨**이었다. 그래서
앞열·뒷열이 없고, 마법사를 지킬 방법이 없고, **파티 순서 화면이 전투에 아무 영향이
없었다.** B5-04 가 거리로 가중을 준다.

가중은 **사거리 안/밖이 아니라 거리 자체**로 떨어진다 — 사거리가 닿는다고 앞사람을
뚫고 뒤를 치기가 똑같이 쉬운 것은 아니다. 감쇠 폭은 무기 사거리가 정한다
(`falloffForReach`): 창은 앞을 지나쳐 고르고, 철퇴는 앞사람을 친다.

**전투 400판을 끝까지 돌린 실측** (Orc 넷 · 간격 0 · 물리 피해만):

| 파티원 | 열 | 피격 비율 |
|---|---|---|
| 슴갈 | 1 | **29.9%** |
| 방패병 | 1 | **31.0%** |
| 유리 | 2 | 19.6% |
| 술사 | 3 | 9.8% |
| 치유사 | 3 | 9.7% |

**앞열이 뒷열의 3배를 맞는다.** 뽑기 함수만 본 예측(31/20/31/9/9)과 그대로 맞는다.

세 가지가 여기서 따라 나온다:

1. **탱커가 성립한다.** 방패(B2-08)는 지금까지 자기만 지켰다 — 적이 그 사람을 안 때렸기
   때문이다. 앞에 서면 실제로 더 맞으므로 방패가 값을 한다
2. **전원 뒤에 세우면 가중이 균등으로 수렴한다.** 아무도 앞에 없으면 뒤에 숨을 것도 없다.
   숨는 것이 전략이 되지 않는다
3. **혼자 앞에 선 사람은 45% 를 받는다.** [B5-03](../../issues/B5-battle-position/B5-03-advance.md)
   의 전진 방어가 별도 도발 없이 작동하는 근거다

## X-4 피해 사슬 재편 후의 대역 (B5-05)

`packages/hd_battle/tool/damage_band.dart` 로 재생성한다. **부록 U 의 표는 이전
사슬 기준**이다 — 변동원이 둘(공격 굴림 + 방어 굴림)에서 하나(회피 배율 + 방어 굴림)로
바뀌었다.

### 적 → 아군 (회피 10 · 행운 0 기준)

| 적 | 착용 ac | 피해 발생 | 평균 | 최대 |
|---|---|---|---|---|
| Orc | 0 | 90.0% | 3.7 | 8 |
| Orc | 5 | 59.0% | 1.8 | 8 |
| Orc | 20 | 12.0% | 0.3 | 6 |
| Troll | 0 | 92.0% | 4.3 | 9 |
| Giant | 5 | — | — | 30 |
| **Black Knight** | 20 | 100% | **588** | **943** |

### 아군 → 적 (슴갈: 힘 18 · 무기 10 · 물리 레벨 1)

| 적 | 피해 발생 | 평균 | 최대 |
|---|---|---|---|
| Orc | 99.9% | **10.3** | 18 |
| Troll | 99.9% | 10.3 | 18 |
| Giant | 93.9% | 8.6 | 18 |
| Black Knight | 1.0% | 0.0 | 2 |

**기본 피해식을 2배로 올린 결과**(`physicalPowerScale`)다. 회피 배율이 옛 `random(50)`
변동을 대체하면서 평균이 절반이 됐고(7.18 → 3.90), 2배로 되돌리니 10.3 이 됐다.
평균은 예전보다 높고 **편차는 훨씬 넓다** — 같은 무기로 0 도 나오고 18 도 나온다.

### 방패는 배율로 흡수됐다

| 방패 블록 | 피해 발생 | 평균 (Troll, ac 5) |
|---|---|---|
| 0 | 64.5% | 2.4 |
| 45 | 42.5% | **1.2** |
| 75 (상한) | 30.5% | 0.7 |

방패 45 가 들어오는 피해를 **절반으로** 만든다. B2-08 은 방패에 별도 굴림을 줬는데,
회피 배율이 생기면서 **같은 생각이 두 번**이 됐다 — 방패 저지는 배율 0 이다.
`evasionOf` 로 합치고, 배율이 0 으로 떨어지면 `ShieldBlocked` 로 보고한다.
방어 층이 넷에서 셋(면역 · 회피 · 방어구)으로 줄었다.

### ⚠ Black Knight 는 여전히 부서져 있다

평균 588 · 최대 943. **사슬이 아니라 데이터 문제**다 — `힘 × 레벨` 이 945 다.
부록 U-3 이 지적한 그대로이고 B5-05 의 범위가 아니다. 적 표의 값을 손봐야 풀린다.

### ⚠ 회피 배율의 기울기를 한 번 되돌렸다

처음에는 `명중 - 회피` 를 3배로 곱했는데, 명중이 높은 적이 **거의 항상 최대치**를
때렸다(Black Knight 평균이 최대치의 절반에서 5분의 4로 올랐다). 그건 빗맞음 기제가
아니라 이름만 바꾼 피해 상승이다. 배수를 1로 낮추고 `grazeEdgeCap` 으로 ±30 을 걸었다.

## X-5 물리 속성 — 체질 6종으로 75행을 덮었다 (B5-06)

75종 × 9속성 = 675칸을 손으로 못 쓴다(B2-09 의 `enemyAffinities` 가 21종만 채워진 것도
같은 이유였다). **체질**을 능력치와 이름에서 읽고, 이름 있는 것만 손질한다.

| 체질 | 종수 | 약점 | 저항 |
|---|---|---|---|
| **살 (ordinary)** | **43** | 베기 | 타격 |
| 언데드 | 12 | 타격 | 베기 · 찌르기 |
| 갑주 | 8 | 타격 | 베기 |
| 무형 | 5 | 찌르기 | 베기 · 타격 |
| 벌레 | 4 | 찌르기 | 타격 |
| 정령 | 3 | 찌르기 | 베기 |

**약점이 없는 적이 0종이다** — 모든 적에게 어떤 무기든 답이 있다.
살이 절반 이상이라 **베기가 기본값**이고, 언데드·갑주를 만나면 검이 갑자기
안 듣는다. 그때 두 번째 답을 들고 있느냐가 결정이 된다.

마법 상성(B2-09)은 같은 축에 그대로 남는다 — 미라는 불에 약하고 타격에도 약하다.
**표는 한 벌이다.**

## X-6 넉백은 **타격에만** 붙는다

약점을 찌르면 ×2 인 것은 그대로고, **밀어내는 것은 타격뿐**이다.

모든 약점이 밀면 살 43종에 베기가 통하는 것이 곧 **상시 밀어내기**가 되어
위치를 계획할 수 없게 된다 — 이동원이 이미 넷인데 여기서 다섯째가 매 턴 터진다.
타격만으로 좁히면 드물어서 읽히고, 철퇴와 창 자루에 다른 무기가 못 하는 일이 생기고,
설명이 따로 필요 없다(곤봉은 사람을 넘기고 칼자국은 안 넘긴다).

```
타격으로 약점을 찌르면      한 열 밀려난다
뒤로 물러설 열이 없으면     밀리는 대신 +50% 피해 (벽)
밀려난 상대는              다음 피격에 +30%
```

마지막 줄이 **순서가 아니라 상태**에 걸린 연계다. 민첩 선제(B2-05)를 유지하므로
"밀어낸 **직후의** 공격이 강하다" 로 만들면 누가 먼저 움직이냐에 걸리는 복권이 된다.
표식으로 두면 순서와 무관하다 — 페르소나의 다운, 다키스트 던전의 표식과 같은 방식이다.
표식은 그 진영의 다음 라운드 시작에 지워진다.

`fixtures/rules/knockback.json` 이 사슬 전체를 보여준다 — 철퇴로 Skeleton 을 치면
2열로, 다시 치면 3열로 밀리고 뒤의 ArchiMage 가 드러난다.

# 부록 Y — B6 전투 메뉴 현대화 실측 (2026-09-06)

## Y-1 메뉴 줄 수

| | 리더 | 나머지 |
|---|---|---|
| B5 까지 | 최대 12 (마법 5갈래 + 자동 + 전진 + 후퇴 …) | 최대 10 |
| B6 | **6** (공격 · 기술 · 물건 · 버팀 · 도망 · 지시) + 조건부 돌격 | **4~5** |

기술을 고르는 단계가 2 → 1 이 된 대신 목록이 길어진다. 마법 레벨 20 · ESP 5 인 술사는
**37줄**(`castableSkills(levelMagic: 20, levelEsp: 5).length`) — 🎯 단일 6 · 💥 전체 6 ·
🌀 도포 1 · ☠ 저주 4 · 💚 치료 7 · 💞 전체 치료 7 · 🔮 초능력 6(41~45 + 16).

**판정(2026-09-06)**: 8줄을 넘으면 범위 묶음(≤7)을 먼저 고르고 그 안에서 고른다.
model 은 모르는 view 규칙이다(`hd_battle_text` `skillListFolds`). 초반 파티(마법 1)는
5줄이라 한 화면. 검토한 다른 안 — 치료 14 → 2 로 자동 조합(smart-cast), 공격 사다리의
낡은 단계 숨기기, 전투 중 무효인 41·42·44 빼기 — 는 목록을 ~12 줄로 만들지만 마법의
뜻을 바꾸므로 뒤로 미뤘다.
실험실에서 실제로 훑어 본 뒤 길면 "최근 쓴 것을 위로" 만 넣기로 했다 — 갈래는 되살리지 않는다(9차 판정).

## Y-2 도망 성공률 — 간격이 결정을 만든다 (`tool/escape_odds.dart`, 시드 10,000)

5인 기본 파티(민첩 평균 11 · 행운 2). 식은 `(민첩+행운)/2 + rand(20) + gap×15 > 적 민첩 + 10`.

| 적 평균 민첩 | 간격 0 | 간격 1 | 간격 2 |
|---|---|---|---|
| 5 (Orc 급) | 49% | 100% | 100% |
| 10 | 25% | 100% | 100% |
| 15 | 0% | 75% | 100% |
| 20 (Black Knight) | 0% | 49% | 100% |
| 25 | 0% | 25% | 100% |
| 30 | 0% | 0% | 75% |

**간격 0 에서는 민첩 15 이상의 적에게서 못 달아난다.** 후퇴를 두 번 해서 2 를 만들면
거의 언제나 된다. 그 두 라운드(적은 정상 공격)가 도망의 값이다. 전에는 슬롯 1~4 가 각자
굴려 하나만 되면 전원 도주였으므로 **위 표의 어느 칸도 실제 성공률이 아니었다** — 다섯
번 굴리면 25% 도 76% 가 된다.

## Y-3 무기 도포 — 3 라운드의 근거와 실측

부록 W-1: 5인 파티의 실전은 **3~4 라운드**다. 바르는 데 한 라운드를 쓰면 남는 것이 2~3.
`coatingRounds = 3` 은 바른 다음 라운드부터 세므로 **실제로 휘두르는 라운드 수가 3** 이다 —
실전의 거의 전부다. 그래서 "바를 것인가" 는 첫 라운드의 결정이고, 그 뒤로는 안 물린다.

### 첫 fixture 는 아무것도 보여 주지 못했다

`coating.json` 초판(Troll + Orc, 유리·술사가 바름)은 시드 8개를 바꿔 돌려도 마비·중독이
**0회**였다. 원인 둘: (1) 방침이 "바르기" 라 **매 라운드 다시 바르기만 하고 휘두르지 않았다**,
(2) 5인 파티가 두 라운드에 끝내 버려 발린 무기를 쓸 라운드가 없었다.
→ 방침을 "한 번 바르면 싸운다" 로 고치고(`runner.dart` `_topLevel`), 적을 Giant 둘 + Troll 로.

### 시드 40개 × 적 3조합 훑기 (`attack,0=item,2=coat`, 마비병 1)

| 적 | 마비·중독이 **둘 다** 나온 시드 | 라운드 | 결과 |
|---|---|---|---|
| Giant ×2 + Troll | 40 중 **12** | 4~7 | 전부 승리 |
| Ogre ×2 | 40 중 6 | 6~9 | 전부 **전멸** |
| Troll ×3 | 40 중 3 | 3~4 | 승리 |

채택: Giant ×2 + Troll, 시드 5 — 5 라운드, 마비 2회, 중독 3회. **마비는 저항 굴림 뒤 50%**
라 명중 셋 중 하나꼴로 걸린다; 100 이면 마비병 하나가 적 하나를 전투 내내 묶는다.
Ogre 둘은 시작 파티에게 전멸 조합이다 — 밸런스 판단 자료로 남겨 둔다.

## Y-4 시작 인벤토리

치료약 ×3 · 해독제 · 기력의 약 · 독병 ×2 · 마비병 · 화염병 = 9칸 / 20. **새 게임에만**
(`HDGameSession` 생성 시). 원작 난이도를 깨뜨리는지는 실측 전이다 — 개수는 숫자 하나라
줄이기 쉽다.

## Y-5 메뉴 흐름 감사에서 나온 것 (B6-07)

| 있었던 것 | 어디서 왔나 | 지금 |
|---|---|---|
| 하위 물음 취소 = 턴 상실 | 원작 `battle.dart:349` | 한 단계 위로. 8번 가드 |
| 슬롯 순으로 묻기 | 원작 | 리더 → 1열 → 2열 → 3열. 화면도 같은 순서 |
| 적 하나여도 대상 묻기 | 원작 | 후보 하나면 생략 |
| 단일 치료가 대상을 안 묻음 | Dart 이식이 떨어뜨림(B2-02 가 "가장 필요한 사람" 으로 메꿈) | 아이템처럼 묻고, 필요한 순으로 나열 |
| 부족한 기술 고르면 턴 상실 | B6-01 | 거절하고 돌아옴 |

한 답짜리 물음 생략의 크기: 적 하나짜리 전투에서 5인 파티는 라운드마다 **5번** 눌렀다.
