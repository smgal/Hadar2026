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
Tile::CopyTile, Tile::CopyToDefaultTile, Tile::CopyToDefaultSprite`

Hadar 등록 함수: `Flag::IsSet, Variable::Get, On, OnArea, Battle::Result, Select::Result, Party::PosX, Party::PosY,
Player::GetName, Player::GetGenderName, Player::GetAttribute, Player::IsAvailable`

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
- 적 데이터 `domain/battle/enemy_data.dart` 에 **76종** 하드코딩 테이블.
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

## B-1 적 데이터는 76종이 아니라 **75종**이며, 그중 하나는 소환 불가
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

## B-2 전투 결과 코드가 cm2 상수와 **정반대**로 매핑되어 있다
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

## F-3 `Battle::Result()` 는 전투를 하지 않아도 승리를 반환한다
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

## H-2 **[정정됨]** `books.json` 의 ac 10/20 은 전투를 "무효화" 하지 않는다

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

## M-1 `flag4ep1.cm2:42-43` 의 대입 이름 오타
```cm2
variable(GFD1_WORK_TRAP_BY_TRICK)
GFD1_WORK_TRAP_BY_TRICK.assign(14)

variable(GFD1_OPEN_DOWN_STAIRS)
GFD1_OPEN_ODD_WALL.assign(15)      # ← GFD1_OPEN_DOWN_STAIRS 에 대입해야 한다
```
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

## M-3 미등록 심볼 6종·9곳이 조용히 실패 중이다
등록되지 않은 커맨드/함수가 실사용 cm2 에 있다:
`Party::CheckIf` · `GameOver` · `Player::ApplyAttribute` · `Map::SetLightArea` · `Map::ResetLightArea` · `Player::ReviseAttribute`

특히 **`Party::CheckIf` 는 함수라서 0을 반환**하고(§9), 그 결과 부양 마법 관련 분기가 **의도와 반대로 동작**한다.

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
