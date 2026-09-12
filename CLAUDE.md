# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter/Dart remake of the classic Korean RPG "또 다른 지식의 성전 (Hadar)". The repo is a multi-package layout, not a single Flutter app.

- `hadar2026_app/` — the Flutter app (Bonfire/Flame engine, `window_manager` for desktop). Entry point `lib/main.dart`.
- `packages/cm2_script/` — standalone Dart package: parser + interpreter for the CM2 scripting language. Pulled in via local path dep.
- `packages/hd_battle/` — 전투 model. 순수 Dart, Flutter·한국어·화면 전부 없음.
- `packages/hd_battle_text/` — 그 이벤트의 **한국어 문장**. 콘솔과 앱이 같은 것을 쓴다.
- `packages/hd_world/` — 인물·파티·아이템·장비 model. 순수 Dart, **이 레포의 어떤 패키지도 import 하지 않는다**.
- `packages/hd_world_text/` — 그 model 의 한국어 이름표.
- `packages/hd_world_legacy/` — 출하 스크립트가 쓰는 **옛 어휘**(속성 이름 · 아이템 정수).
- `packages/hd_bridge/` — `hd_world` ↔ `hd_battle`. **양쪽은 서로를 모른다.**
- `hd_world_lab/` — 그 model 의 **OpenAPI 서버 + 마우스 장비 화면**. 규칙을 갖지 않는다.
- `cm2_script_sample/` — CUI demo exercising every cm2_script feature.
- `tools/` — Python scripts for converting/extracting legacy Hadar binary data (maps, enemies, sprites), plus `tools/mapEditor/` — a TypeScript/Vite web map editor (pnpm) that reads/writes `hadar2026_app/assets/maps/*.json` in place while preserving the full RPG Maker MV format (see `tools/mapEditor/README.md`).
- `REF_hadar/` (C++ original), `REF_UNITY_LoreEp1/` (Unity port), `REF_FLUTTER_lore2026/` (sibling Flutter port — git submodule). Read-only reference implementations; do not edit.

## 기획·이슈 문서 (AI 자동 시나리오 생성 작업)

이 레포에는 "배포 전에 AI 로 맵·대화·퀘스트를 생성하는" 작업의 기획서와 이슈 보드가 있다.
**그 작업을 하려면 아래를 먼저 읽어야 한다.** 두 디렉토리는 역할이 다르고 우선순위가 정해져 있다.

| 디렉토리 | 역할 | 우선순위 |
|---|---|---|
| `issues/` | **실행 계획과 이슈 보드.** 무엇부터 할지는 여기가 정본 | **실행에 관해서는 최우선** |
| `blueprint/` | 설계 SSoT 34개 장(약 43,000줄). 왜·무엇을 | 설계 근거 |

**작업 착수 순서**
1. `issues/DECISION-LOG.md` — **반드시 먼저.** 현재 노선과 **1차 판정이 폐기된 이유**.
   1차 판정(P0→P1→GATE→P2)을 따르면 잘못된 일을 하게 된다.
2. `issues/MILESTONES.md` §0~§1 — S 트랙 노선은
   **G1(아이템·장비 이식) → G2(전투 정합) → S1(샘플 퀘스트) → S2(실측 걸림돌) → S3(AI 생성)**
   그리고 `§7` — **B 트랙**(2026-09-04 신설, 4차 판정): 전투를 별도 pure Dart 패키지로 떼어
   **B1 분리 → B2 확장 → B5 위치 → B3 RPG 연결 → B4 Flutter view**. G1·G2 는 완료 상태다.
   **B5 는 2026-09-05 신설(8차 판정)이고 B3 보다 먼저다** — 규격이 v1 → v2 로 열렸다.
   그리고 `§8` — **W 트랙**(2026-09-08 신설, 10차 판정): RPG 핵심(인물·파티·아이템·장비)을
   **새 패키지로 다시 썼다. 9/9 완료(2026-09-09)** — 앱이 새 모델 위에서 돈다.
   B7·B8·B9 제안을 대신하고, 닫으면서 **B3·B4 도 함께 닫혔다**.
   **두 트랙은 별개이고 S1 과 B1 의 선후는 아직 정하지 않았다.**
3. `issues/BOARD.md` — 착수 가능한 이슈
4. 설계 근거가 필요하면 `blueprint/` — 단 **BP-01·BP-50·BP-51 은 1차 노선 기준**이라 참고만 할 것

**항상 정본인 두 파일** (코드를 만지기 전에 확인)
- `blueprint/_meta/GROUND_TRUTH.md` — **코드 실측 사실.** 부록 A~M 에 검증된 잠복 결함과 정정 이력.
  코드에 대한 주장은 여기와 일치해야 한다. 어긋나면 이 파일을 먼저 고친다.
- `blueprint/_meta/DECISIONS.md` — 확정 설계 결정 D-01~D-31(개정 이력 포함, D-24 는 결번).
  주제별 소유 장 표(D-18)가 "어느 문서를 고쳐야 하는가" 를 정한다.

**현재 노선의 핵심 사실** (틀리기 쉬운 부분이라 못박아 둔다)
- 퀘스트는 **이미 저작 가능하다.** 원작 방식은 `assets/flag4ep1.cm2`(이름 붙인 플래그 상수) +
  `assets/L1_ep1d0~d5_1.cm2`(2,441줄). **퀘스트 아이템은 플래그로 표현**되며 인벤토리는 필요 없다.
- 새 맵·등장인물 추가는 **코드 변경 0**: `MapInfos.json` 항목 + `assets/maps/Map0NN.json` + `assets/Map0NN.cm2`.
  (`LORE_EP` = `Map002.json` + `Map002.cm2` 가 작동 예. 다음 빈 id 는 16)
- cm2 의 **중첩 `include` 는 매 `run()` 재실행된다**(부록 L, 실행 검증). 최상위 `include` 만 init 전용이다.
  → 한 맵에 퀘스트 여러 개를 파일 단위로 분리하는 것이 **엔진 변경 없이 가능**하다.
- **아이템·장비는 "설계" 가 아니라 "이식" 이다** — `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs`(877줄) ·
  `GameEventEquipment.cs`(448줄) · `ObjTypes.cs`(`ITEM_TYPE`: 부위 개념 `ARMOR`/`HEAD`/`LEG`/`ORNAMENT` 포함)에
  완성된 원작 구현이 있다. 현재 Dart 는 `weapon`/`shield`/`armor` **정수 3칸**뿐이고 `"무기1"` 이 플레이어에게 보인다.
  **G1 이 S1 보다 먼저인 이유**: 플래그로 아이템을 표현해 퀘스트를 만들면 나중에 전부 다시 써야 한다(3차 판정).
- **선언적** 콘텐츠 팩·저널·솔버·MCP 는 **보류**다(`issues/deferred/`, 26건). 폐기가 아니라
  cm2 노선이 실제로 막힐 때 꺼내 쓴다. **G1 의 아이템은 이 보류 노선이 아니라 원작 이식이다.**
- 마법은 선택 UI·이름만 있고 **효과가 레벨 기반 공식 2개로 뭉쳐 있다**(`battle.dart:166,185`). 45종 개별 효과 없음.
  이 "별 트랙" 이 **B 트랙**으로 구체화되었다(4차 판정) — `issues/B2-battle-expand/B2-01`.
- **전투를 손대려면 B 트랙 문서를 먼저 읽는다.** `hadar2026_app/lib/application/battle.dart`(572줄)는
  B4-03 에서 삭제될 코드다. 새 전투는 `packages/hd_battle/`(pure Dart, `dart run` 으로 콘솔 시연)에 만든다.
  **B1 · B2 · B5 · B6 완료, B3 4/5 (2026-09-06).** 규격은
  `packages/hd_battle/CONTRACT.md` **v3** 가 정본이다.
  **전투는 이미 새 model 로 돈다** — cm2 동사 다섯 개가
  `application/battle_bridge/cm2_battle_adapter.dart` 를 거치고,
  `HDBattleRunner` 가 `UiHost` 로 굴린다. 남은 것은 B3-04(전투 밖 효과) ·
  B4-02(게임 안으로) · B4-03(옛 코드 제거).
- **아군 model 은 `packages/hd_world` 다**(10차 판정, W1 완료). `HDPlayer` ·
  `domain/item/*` · `equipment_flow.dart` · `setup_assembly.dart` 는 **지웠다**.
  인물·장비를 고치려면 `packages/hd_world` 를 고친다. 부위는 **여덟**(오른손·왼손·머리·몸통·
  다리·공통 부적·직업 부적 1·2)이고 저장 번호 0~5 는 옛 값 그대로다.
  **파생값은 저장하지 않는다** — 무기 종류·최종 수치·통행 능력·시야는 읽을 때 계산된다.
  `World.apply` 가 유일한 문이고 **throw 하지 않는다**(거절은 닫힌 열거를 실은 이벤트).
  한국어는 `packages/hd_world_text` 한 곳이다.
- **앱 쪽 파티는 `HDParty` 이지만 명부와 가방은 `party.world` 가 갖는다.**
  `party.members` 는 **자리 여섯**이고 빈 자리도 들어 있다 — 자리 번호가 곧 신원이라
  접으면 cm2 가 손보는 사람이 옮겨진다(`menace.cm2:45` 가 여섯째 자리를 미리 만진다).
  표시용 조사·직업 이름·장비 이름은 `domain/party/member_display.dart` 의 **확장**이다.
- **통행 능력과 불은 출처가 둘이다** — 부적(상시)과 마법(칸 수). `party.canWalkOnWater` ·
  `canWalkOnSwamp` · `canLevitate` · `light` 가 둘을 합쳐 답한다(BP-47 §7.2).
  쉬면 **마법 잔량만** 줄고 부적은 그대로다.
- **직업 번호는 원작의 17종이다**(부록 Z-7). 이전 모델의 0=에스퍼·1=싸이보그·2=초능력자는
  출하 스크립트와 어긋나 있었다 — cm2 가 `class` 에 5·8·9 를 쓴다. 슴갈·유리 둘 다 **에스퍼(8)**.
- **레벨업은 최대치를 내리지 않는다**(부록 Z-8). 원작 공식이 손으로 정한 시작값보다 작아서
  슴갈이 처음 레벨 2가 될 때 최대 체력이 150→34 로 떨어졌다. 큰 쪽을 쓴다.
- **전투에 넘길 때는 `packages/hd_bridge`** 를 쓴다 — `toBattleSetup` · `settle`.
  손 구성이 만드는 값 넷(`strikes`·`coatingSlots`·`evasionBonus`·`initiativeBonus`)은
  RPG 가 풀어서 넘긴다. 전투는 두 손을 보지 않으므로 스스로 알 수 없다(규격 **v4**).
- **장비를 만져 보려면 `cd hd_world_lab && dart run bin/serve.dart`** — 마우스로 여덟 칸을
  갈아 끼우는 화면과 OpenAPI 표면이 함께 뜬다(`http://127.0.0.1:5330/`).
  터미널이 아닌 이유는 부위 여덟이 **동시에 보여야** 하고 고칠 때마다 값이 다시 계산되기
  때문이다. 무엇을 눌러 볼지는 `hd_world_lab/RUN.md`, 도메인 안내는 `GET /api/guide`.
- **전투를 손보려면 `flutter run -t lib/battle_lab_main.dart`** — 전투만 띄우는
  실험실이다(B4-01). 콘솔과 **같은 fixture** 를 읽고, 「한 수 물리기」가 있어
  같은 상황에서 다른 수를 시험할 수 있다. 화면 위젯
  (`presentation/panels/battle/`)은 게임에 쓸 것과 같은 것이고,
  게임 안에 넣는 것이 B4-02 다.
- **전투 문구·색은 `packages/hd_battle_text` 한 곳에서 온다** — 문장 ·
  이름 색(`enemyNameColor`/`conditionColor`) · 메뉴 문구(`actionLabel` ·
  `reachVerdict` …). 콘솔과 Flutter 가 같은 것을 보여야 하므로 한쪽에만
  쓰면 안 된다.
- **전투를 옮기면 RPG 쪽 뒤처리가 딸려 온다.** 두 번 물렸다 —
  전멸해도 게임 오버가 안 됐고(어댑터가 `processGameOver(2)` 를 안 불렀다),
  `checkLevelUp()` 호출처가 죽은 `application/battle.dart` 하나뿐이라
  **레벨이 전혀 오르지 않았다**(B3-05 에서 `battle_bridge/level_up.dart` 로 해소).
  전투 밖 효과 13종(B3-04)이 같은 종류로 남아 있다.
- **cm2 는 검증된 적 없는 코드다.** `test/application/scripting/cm2_assets_audit_test.dart`
  가 출하 `assets/*.cm2` 전량을 훑는다 — 모르는 명령·함수, 없는 속성 이름,
  값을 못 받은 `variable`, 결과를 안 읽는 `Battle::Start`. cm2 를 고치면 이것도 돈다.
- **`application/battle.dart` 는 없다** — B4-03 이 809줄(옛 전투 · 옛 적 클래스 ·
  중복된 75행 표)을 지웠다. **전투를 고치려면 `packages/hd_battle`** 을 고친다.
  게임 안의 전투 화면은 실험실과 **같은 위젯**을 쓴다(`HDFormationStrip` ·
  `HDEnemyPane` · `HDPartyPane`), 묻는 것은 `UiHost.showWindowMenu` 다.
- **B6 가 전투 메뉴를 원작에서 떼어 냈다**(9차 판정, 2026-09-06 완료). 최상위 **6줄**
  (⚔ 공격 · ✨ 기술 · 🎒 물건 · 🛡 버팀 · 🏃 도망 · ⚙ 지시), 마법·초능력은 **한 목록**이고
  `SkillScope` 글자가 갈래를 말한다. `BattleAction` 에 `castSingle` 류는 **없다** —
  `castSkill` 하나다. 목록이 **8줄을 넘으면** view 가 범위 묶음으로 한 번 접는다
  (`hd_battle_text` `skillListFolds`, model 은 모른다). 리더 = 의식 있는 최소 슬롯.
  **묻는 순서는 리더 → 1열 → 2열 → 3열**이고 화면도 그 순서다(B6-07; 행동 순서인 민첩
  선제와는 별개). 하위 물음의 취소는 **턴을 잃지 않고 한 단계 위로**, 후보가 하나면
  묻지 않는다, 단일 치료도 아이템처럼 대상을 묻는다. 도망은 리더의 파티 행동이고 간격이
  확률을 만든다(+15/칸, `tool/escape_odds.dart`). 무기 도포(독·마비·화염, 3 라운드)는
  마법 13 과 소비품(`HDItemType.consumable(12)`, `domain/item/consumable_data.dart`)
  두 길이다. **emoji 도 한국어처럼 model 에 들어가지 않는다** — `hd_battle_text` 가 붙인다.
- **B5 가 전투에 위치를 넣었다**(8차 판정, 완료). 좌표가 아니라 **각자의 `rank`(1~3) + 양측
  공통 `gap`(0~2)** 이고 거리는 `gap + (내 rank-1) + (상대 rank-1)` 이다. 근간은 드래곤 퀘스트 —
  라운드 시작에 전원 명령 → 일괄 해결, 자유 이동 없음, 순서 미리보기 없음.
  **불변식 하나: 사거리 밖은 벌점이지 무효가 아니다.** 헛턴이 나오는 경로를 만들면 안 된다 —
  규칙·무기 표·메뉴 세 곳에서 지켜지고 `purity_test.dart` 가 확인한다.
  포기한 것: 측면 우회 · 한 열 안의 개별 위치 · 특정 적만 골라 밀어내기.
  **무기는 두 세계가 나눠 갖는다** — RPG 가 `powOfWeapon`(얼마나 센지), 전투가
  `weaponKey`(어떻게 닿는지). **연계는 순서가 아니라 상태에 건다**(밀린 표식) — 민첩 선제와
  충돌하지 않게 하려면 그래야 한다.
- **⚠ 파티는 5인 + 소환수가 기본이다.** 그런데 fixture 17개 중 **14개가 2인 파티**라
  B1·B2 의 밸런스 실측이 대표성이 없다(부록 W). 5인이면 라운드가 절반(9→4)이고
  **적의 특수 능력이 처음으로 발동한다**(0회→10회, `consciousPlayers > 3` 게이트).
  **전투 수치를 재려면 B5-00(fixture 5인 재작성)이 먼저다.**
- **⚠ C++(`REF_hadar/`)은 정본이 아니다**(6차 판정). 진짜 원본은 **Pascal 이고 레포에 없다**
  (`*.pas` 0건). C++ 은 검증된 적 없는 이식본이라 `REF_UNITY_LoreEp1/` 과 같은 지위다.
  **C++ 이 버그처럼 보이면 버그다** — 옮기지 말고 고친다. B2 에서 실제로 6건 고쳤다.
  개념의 존재 여부는 받아들이고 값만 의심하는 선을 지킨다. C++ 은 cp949 로 읽는다.
  `REF_UNITY_LoreEp1/src_as_cs/OldStyleBattle.cs` 는 특히 위험하다 — 마법 번호가 1~20 이고
  **적 테이블 인덱스가 +1 밀려** cm2 의 `RegisterEnemy(26)` 과 어긋난다(부록 P-3).
- 전투 실측은 `GROUND_TRUTH` **부록 O·P·Q·R·S·T·U·W** 에 있다. 부록 **H-2 는 구 전투식 기준**이고
  새 대역은 **부록 U**(2인 파티 기준), 파티 인원·저항·피해 사슬 실측은 **부록 W** 다.
  콘솔 색은 **부록 V** — 원작에 색 규격이 이미 있었다(`writeConsole(색번호, ...)`).

## Common commands

```bash
# Flutter app (run on connected device / desktop)
cd hadar2026_app
flutter pub get
flutter run

# Web build (matches the GitHub Actions deploy)
cd hadar2026_app
flutter build web --base-href "/Hadar2026/" --release

# cm2_script package tests
cd packages/cm2_script
dart pub get
dart test                          # all
dart test test/parser_test.dart    # single file

# CM2 scripting CUI sample
cd cm2_script_sample
dart pub get
dart run bin/run.dart

# 전투 model (순수 Dart, B 트랙) — Flutter SDK 없이 돈다
cd packages/hd_battle
dart pub get
dart test

# 전투를 콘솔에서 직접 굴려 보기 (실행 안내: hd_battle_console/RUN.md)
cd hd_battle_console
dart pub get
dart run bin/battle.dart                            # 사용법 + fixture 목록
dart run bin/battle.dart fixtures/town1_pair.json   # 대화형
dart run bin/battle.dart fixtures/heal.json --replay # 기록된 명령 열 재생

# 전투 실험실 — 전투만 띄운다 (B4-01). 지도·cm2·RPG 를 안 거친다
cd hadar2026_app
flutter run -t lib/battle_lab_main.dart             # 데스크톱
flutter run -d chrome -t lib/battle_lab_main.dart   # 브라우저
# fixture 는 hd_battle_console 과 **같은 파일**이다. 고치면 다시 만든다:
cd hd_battle_console && dart run tool/make_fixtures.dart

# 인물·파티·장비 model (순수 Dart, W 트랙) — Flutter SDK 없이 돈다
cd packages/hd_world
dart pub get
dart test                                           # 103개

# 장비를 마우스로 갈아 끼워 보기 (실행 안내: hd_world_lab/RUN.md)
cd hd_world_lab
dart pub get
dart run bin/serve.dart                             # http://127.0.0.1:5330/
dart run bin/serve.dart 5331                        # 다른 번호로
# 명령으로도 같은 것을 한다 — 거절도 200 이고 이유가 실려 온다
curl -s localhost:5330/api/state | jq '.members[] | {name, weaponKind}'
curl -s localhost:5330/api/guide                    # 도메인 안내
# 그 장비로 한 판 싸워 본다 — 사거리가 실제로 값을 내는지 보인다
curl -s -X POST localhost:5330/api/battle \
  -H 'content-type: application/json' -d '{"seed":7}' | jq '.members'

# 옛 어휘와 다리 (앱 없이 돈다)
cd packages/hd_world_legacy && dart pub get && dart test
cd ../hd_bridge && dart pub get && dart test
# cm2 아이템 상수를 다시 만든다 (카탈로그가 바뀌면)
cd packages/hd_world_legacy && dart run tool/make_item_constants.dart

# Map editor (web UI for assets/maps/*.json)
cd tools/mapEditor
pnpm install
pnpm dev        # http://localhost:5310 — edits hadar2026_app/assets in place
# AI-facing semantic REST API on the same server: GET /api/ai returns the full
# machine-readable guide (batch edits, events CRUD, passability, validate,
# preview.png). MCP wrapper: node tools/mapEditor/mcp/server.mjs (dev server must be running).
```

`flame` is pinned to `1.35.1` via `dependency_overrides` and `bonfire` is pinned to exactly `3.16.1` in `hadar2026_app/pubspec.yaml` — don't bump them casually. bonfire 3.17.x assumes flame 1.36+ (`RenderGameWidget(behavior:)`) and will not compile against flame 1.35.1.

## Architecture

### `lib/` is layered: domain / application / presentation

`hadar2026_app/lib/` was reorganized from a flat `models/ + views/ + game_components/ + scripting/` into:

- `domain/` — pure data + game rules. Allowed Flutter import: `foundation.dart` only (for `ChangeNotifier`). Subfolders: `party/`, `map/`, `battle/`, `magic/`, `lighting/`, `console/`, `window/`, plus `game_option.dart`.
- `application/` — use-cases that compose domain with a UI host. No `flutter/material`, no `bonfire`, no `flame`, and no import of `presentation/` or `hd_game_main.dart`. Contains `game_session.dart`, `menu_flows.dart`, `battle.dart`, `magic_system.dart`, `map_navigation.dart`, `tile_event_dispatcher.dart`, `save_manager.dart`, `select.dart`, `map_loader.dart`, `window_manager.dart` (the overlay window *stack*), `game_reload_exception.dart`, `scripting/` (CM2 adapter + native map scripts + `HDMapScriptContext`), and `ports/` (the abstract host interfaces application calls into — `UiHost`, `PartyMovementHost`, `AssetSource`, and `HDHosts`, the binding the shell fills in at boot).
- `presentation/` — Flutter/Bonfire-bound code: `host/` (`HDFlutterUiHost` + `HDBundleAssetSource`, the concrete adapters implementing every `application/ports/` interface), `input/` (`HDInputDispatcher`, `HDWindowKeyDispatcher`, `HDVirtualInputState`, `HDInputMode`), and `panels/` (the 6 panels + `world_map_renderer.dart` + `player_sprite.dart`).
- `lib/hd_game_main.dart` — thin facade that wires the layers together. Singleton, implements `UiHost` + `PartyMovementHost`, forwards both `HDGameSession` and `HDFlutterUiHost` change notifications. Existing `HDGameMain()` call sites and `ListenableBuilder(listenable: HDGameMain(), ...)` keep working unchanged.

When adding a class, pick the layer first. If a domain file ever imports `package:flutter/material.dart` or `package:bonfire/...`, that's a layering violation — push the rendering concern out into `presentation/` or the use-case into `application/`. Application code must not import `lib/presentation/...` **or `lib/hd_game_main.dart`** either — the facade pulls `flutter/material` plus the whole presentation layer in with it. Reach for a port instead: `HDHosts().ui` / `HDHosts().movement` for effects, `HDGameSession()` for session state.

Two greps keep this honest (both must come back empty):

```bash
cd hadar2026_app
grep -rn "^import.*presentation\|^import.*hd_game_main" lib/application/ lib/domain/
grep -rn "package:flutter/material\|package:bonfire\|package:flame" lib/application/ lib/domain/
```

Both greps run in CI (`.github/workflows/ci.yml`, "Check layering invariants"), so a violation fails the build rather than waiting to be noticed. The only Flutter import allowed under `application/`/`domain/` is `package:flutter/foundation.dart` (`ChangeNotifier`, `kIsWeb`, `kDebugMode`) — no `services`, no `dart:io`.

### Layout (fixed 800×480)
The UI is hand-laid out at fixed pixel coordinates by `lib/main.dart`, scaled with `FittedBox`. Constants live in `lib/hd_config.dart`. Three viewports + a mobile control strip:

- `HDMapViewport` (0,0 / 288×320) — Bonfire game world, camera locked to player.
- `HDConsolePanel` (288,0 / 512×320) — script dialogue + system logs.
- `HDStatusPanel` (0,320 / 800×160) — party HP/SP/ESP grid.
- `HDBottomControlPanel` — virtual D-pad + action buttons for mobile.
- `HDWindowLayer` — overlay stack (battle, magic, etc.) drawn on top of everything.

All five panel widgets live in `lib/presentation/panels/`. See `hadar2026_app/UI_SPEC.md` for the visual spec.

### Singleton-heavy core
Most subsystems are accessed as `Foo()` (factory returning a static instance): `HDGameMain`, `HDGameSession`, `HDFlutterUiHost`, `HDInputDispatcher`, `HDWindowKeyDispatcher`, `HDWindowManager`, `HDBattle`, `HDMenuFlows`, `HDTileEventDispatcher`, `HDMapNavigation`, `HDScriptEngine`, `HDNativeScriptRunner`, `HDSelect`, `HDSaveManager`, `HDHosts`. The codebase intentionally mirrors the original C++ globals — it's not a target for DI refactoring. What was cleaned up is *responsibility splitting*: `HDGameMain` shrank from ~1000 lines to ~185 by handing menu flow / map loading / tile dispatch / input routing / UI hosting / session state to dedicated singletons. New code should pick the right one rather than growing `HDGameMain` again.

`HDGameMain` extends `ChangeNotifier` and is still the source of truth for UI rebuilds (via `ListenableBuilder(listenable: HDGameMain(), …)`). It implements `UiHost` and forwards changes from both `HDFlutterUiHost` and `HDGameSession` (`addListener(notifyListeners)`), so a single listenable still drives the whole UI even though state lives in two layered singletons. `notifyListeners()` is wrapped in `Future.microtask` to avoid notifying during build.

The `UiHost` and `PartyMovementHost` interfaces (`application/ports/`) are the seam if you ever need a headless test driver, a CLI/MUD frontend, or an alternate Flutter layout — application code only ever calls `host.showMenu / showWindowMenu / showMessageWindow / addLog / waitForAnyKey / setHeader / clearLogs / beginNarrative / endNarrative / refresh / preloadAssets / animatePartyMove`, never the concrete `HDFlutterUiHost` or `HDGameMain`. To swap frontends, write a new adapter implementing the ports; nothing in `domain/` or `application/` changes.

`AssetSource` is the third port: every text asset read (map JSON, `MapInfos.json`, cm2 scripts) goes through `HDHosts().assets.loadString(path)`. `HDBundleAssetSource` implements it as "on-disk file wins on desktop, else `rootBundle`" — that override is what lets desktop runs pick up `tools/mapEditor` writes without a rebuild. Application code must never reach for `rootBundle` itself.

`HDHosts` (`application/ports/host_binding.dart`) is the composition root that carries those ports to the use-cases. `HDGameMain._internal()` calls `HDHosts().bind(ui: _host, movement: _host, assets: HDBundleAssetSource())` at boot; a test binds fakes and calls `HDHosts().reset()` in `tearDown`. Reading a port before `bind` throws a `StateError` naming the fix rather than failing later with a null.

`UiHost.refresh()` is a *pure repaint request* and is deliberately distinct from a session-changed notification: a map transition additionally clears the per-map progress scrollback (`HDGameMain._onSessionChanged`), whereas `refresh()` never does. Application code that mutates map state in place (tile overrides, map-type swaps, a restored save) must call `HDHosts().ui.refresh()`, not `HDGameSession().notifyListeners()`.

### Input modes
`HDGameMain.currentInputMode` resolves to one of `HDInputMode.{window, menu, dialogue, map}` in priority order. The global `HardwareKeyboard.instance` handler is registered by `HDInputDispatcher().registerGlobalHandler()`; every key flows through `HDInputDispatcher.process()` which dispatches by current mode (`HDGameMain.processKey()` is now a thin facade over it). Key bindings policy is documented in `docs/key_input_policy.md`:

- Move: arrows / WASD
- Confirm: Enter / E
- Menu/Cancel: Esc / Q / Space (Space opens main menu only on map mode)

Window-mode keys are dispatched by `HDWindowKeyDispatcher` (`presentation/input/`), which type-switches on the topmost visible window (`HDMessageWindow.close()`, `HDMagicSelectionWindow.moveCursor/confirm/cancel`). Domain window classes no longer carry their own `handleInput`, and the stack itself (`HDWindowManager`, in `application/`) holds no key handling — that split is what lets application code open a window without importing `presentation/`.

### Scripting: three event tiers per tile

Tile events are dispatched through a 3-tier priority chain in `HDTileEventDispatcher.check` → `_dispatchScripted`:

1. **native map script** — Dart class extending `HDMapScript` under `lib/application/scripting/maps/`, registered in `HDNativeScriptRunner.mapScriptFactory` (`'TOWN1' → Town1MapScript`, etc.). Lifecycle hooks: `onLoad/onUnload/onTalk/onSign/onEvent/onEnter`. **All four event hooks return `Future<bool>` — `true` means "handled, don't fall through".**
2. **cm2 paired script** — `.cm2` file under `hadar2026_app/assets/`, referenced from `MapInfos.json#cm2`. Loaded into `HDScriptEngine` on map entry. Signals processing via the `Event::Override()` builtin — without it, dispatch falls through to JSON. Convention: place `Event::Override()` at the top of the matched-tile handler block so it reads as a declarative "this block overrides JSON" annotation.
3. **JSON `MapEvent.dialogLines`** — static fallback emitted by the dispatcher when neither native nor cm2 handled the tile. The legacy RPG Maker `code=401` text is parsed; the optional `events[].hadarEvent: { kind, payload }` extension is parsed but not yet dispatched (placeholder for future warp/oneshot kinds).

**Per-map binding**: `MapInfos.json` entries carry optional `cm2` and `json` fields. Missing `json` falls back to `Map${id:03d}.json`. Missing `cm2` is allowed only if the map has a registered native script (otherwise the map has no dynamic scripting at all). Native maps without a paired cm2 keep the legacy "JSON dialogLines emitted alongside native" behaviour. Maps with neither native nor paired cm2 fall back to the legacy global cm2 chain (`startup.cm2` → ...) and don't fall through to JSON — preserves pre-migration cm2 dispatch.

**Why two scripting runtimes still**: cm2 is a hot-reloadable, data-driven DSL good for porting original Hadar scripts and for content authors. Native Dart is for typed, IDE-supported logic where cm2's expressivity falls short. New maps generally pick one — the 3-tier chain is the seam that lets them coexist.

#### CM2 gotchas
- **init vs run phase**: `loadFromString()` runs an **initialization phase** that executes `variable`, `include`, and `name.assign`. `run()` then **skips** `variable`/`include` but **re-executes** every `.assign`. So a `score.assign(0)` at the top of the main script will wipe runtime state every loop iteration. Put one-shot initial assignments inside an `include`d file.
- **silent failure modes**: Unregistered commands print "Unknown command" and are skipped; unregistered functions print "Unknown function" and **return 0**, which can silently mis-branch — watch for typos.
- **`Event::Override` is required** for cm2-paired maps to override JSON dialogue cleanly. If a cm2 handler does its work but forgets to call it, JSON gets re-emitted as a duplicate dialogue. For legacy global-cm2 maps (no `cm2` field in `MapInfos.json`), the dispatcher skips the JSON tier entirely so a missing call is harmless.
- **per-map cm2 load wipes engine globals**: `HDGameSession.loadMapFromFile` calls `HDScriptEngine().loadScript(cm2Path)` on map transitions, which clears `variables`/contexts. Globals are not preserved across maps in the new model — keep state in `HDNativeScriptRunner.flags`/`.variables` if it must survive.

### Map data
Maps live as `assets/maps/MapNNN.json` with a name index in `assets/maps/MapInfos.json`. `HDMapNavigation.loadByName(name)` (in `application/map_navigation.dart`) returns a `MapBundle { mapName, json?, cm2Path? }`: `name` → entry in `MapInfos.json` → resolves both the JSON map data and the optional cm2 path. Don't bypass the index.

Tile actions are the `HDTileAction` enum (`domain/map/tile_properties.dart`), which drives interaction dispatch in `HDTileEventDispatcher.check`. Ask the enum rather than restating a list of members — `isInteractive` (talk/sign/enter: faced-and-confirmed, and the set that blocks movement), `isStepOn` (event/enter), `debugTag`. Every `switch` over it is exhaustive, so adding an action surfaces each site that must handle it as a compile error.

**`HDTileAction.scriptMode` is a wire value, not an index.** 0–4 are handed to `HDScriptEngine.setScriptMode` and read back by cm2 scripts as `ScriptMode()`, compared against `FLAG_MAP`/`FLAG_TALK`/`FLAG_SIGN`/`FLAG_EVENT`/`FLAG_ENTER` in `assets/const.cm2`. They are declared explicitly on the enum and pinned by `test/domain/map/tile_action_test.dart` — never switch to `Enum.index`. The legacy `*.map` files are no longer used (deleted).

### Save/load
`HDSaveManager.saveGame(slot)` / `loadGame(slot)`. Save files are `save_data_*.json` (gitignored). A successful load throws `GameReloadException` to unwind the current run loop — the script engine catches and silently stops on this exception, so do not log it as an error.

## Tests

`hadar2026_app/test/` holds domain/unit tests against the layered code (no widget tests yet). Run from `hadar2026_app/` with `flutter test`. Currently-covered areas: `domain/party/party_actions_test.dart`, `domain/lighting/sight_calculator_test.dart`, `domain/console/text_utils_test.dart`, `domain/console/console_log_test.dart`, `domain/map/map_event_test.dart`, `domain/map/tile_action_test.dart`, `presentation/host/flutter_ui_host_test.dart`.

`test/application/map_navigation_test.dart` is the worked example of the headless seam: it binds a fake `AssetSource` serving maps from an in-memory `Map<String, String>` and drives the whole name → `MapInfos.json` → `MapModel` path with no asset bundle and no filesystem. Copy that shape to test `HDMenuFlows` / `HDBattle` / `HDTileEventDispatcher` — bind fakes via `HDHosts().bind(...)`, `HDHosts().reset()` in `tearDown`. cm2 engine has its own tests in `packages/cm2_script/test/` (run with `dart test`). New domain rules should land with a test in the matching subfolder.

`packages/hd_world/` 는 시험 103개를 갖고 `test/flow/purity_test.dart` 가 **독립성**을
지킨다 — Flutter · 이 레포의 다른 패키지 · `dart:io` · `DateTime.now` · `print` ·
시드 없는 `Random` · 한국어 · emoji, 그리고 **파생값을 인물에 저장하는 것**까지 막는다
(옛 `PartyBuffs` 네 칸 중 셋이 썩은 것이 저장했기 때문이다). `hd_world_lab/test/` 는
HTTP 표면을 스크립트가 쓰는 방식대로 굴린다(13개).

## Deployment
Web is published to GitHub Pages by `.github/workflows/deploy_web.yml` (manual `workflow_dispatch`). It runs `flutter build web --base-href "/Hadar2026/" --release` in `hadar2026_app/` and pushes `build/web` via `peaceiris/actions-gh-pages@v3`. ## CI

`.github/workflows/ci.yml` runs on every push to `main`, every PR, and manual dispatch. Two jobs:

- **hadar2026_app** — `flutter analyze --no-fatal-infos`, `flutter test`, then the two layering greps above.
- **hd_battle** — `packages/hd_battle` + `hd_battle_text` + `hd_battle_console`, plus a purity grep and a fixture replay determinism check.
- **hd_world** — `packages/hd_world` + `hd_world_text` + `hd_world_lab`, plus an independence grep (Flutter · 이 레포의 다른 패키지 · `dart:io`) and an OpenAPI parse check.
- **packages/cm2_script** — `dart analyze` (fatal on warnings), `dart test`.

`--no-fatal-infos` is deliberate: 77 pre-existing style infos (`constant_identifier_names`, `avoid_print`, `withOpacity` deprecations) would make the build red from day one. Errors and warnings *are* fatal, so new regressions still fail. Drop the flag once those infos are cleaned up.

There is no `dart format` gate yet — the repo is not format-clean (~20 files would change). Run a one-shot `dart format lib test` in both packages, then add `dart format --output=none --set-exit-if-changed lib test` to both jobs.
