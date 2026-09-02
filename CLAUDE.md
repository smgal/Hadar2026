# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter/Dart remake of the classic Korean RPG "또 다른 지식의 성전 (Hadar)". The repo is a multi-package layout, not a single Flutter app.

- `hadar2026_app/` — the Flutter app (Bonfire/Flame engine, `window_manager` for desktop). Entry point `lib/main.dart`.
- `packages/cm2_script/` — standalone Dart package: parser + interpreter for the CM2 scripting language. Pulled in via local path dep.
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
2. `issues/MILESTONES.md` §0~§1 — 현재 노선은
   **G1(아이템·장비 이식) → G2(전투 정합) → S1(샘플 퀘스트) → S2(실측 걸림돌) → S3(AI 생성)**
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
- 마법은 선택 UI·이름만 있고 **효과가 레벨 기반 공식 2개로 뭉쳐 있다**(`battle.dart:155,174`). 45종 개별 효과 없음 — **별 트랙**.

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

## Deployment
Web is published to GitHub Pages by `.github/workflows/deploy_web.yml` (manual `workflow_dispatch`). It runs `flutter build web --base-href "/Hadar2026/" --release` in `hadar2026_app/` and pushes `build/web` via `peaceiris/actions-gh-pages@v3`. ## CI

`.github/workflows/ci.yml` runs on every push to `main`, every PR, and manual dispatch. Two jobs:

- **hadar2026_app** — `flutter analyze --no-fatal-infos`, `flutter test`, then the two layering greps above.
- **packages/cm2_script** — `dart analyze` (fatal on warnings), `dart test`.

`--no-fatal-infos` is deliberate: 77 pre-existing style infos (`constant_identifier_names`, `avoid_print`, `withOpacity` deprecations) would make the build red from day one. Errors and warnings *are* fatal, so new regressions still fail. Drop the flag once those infos are cleaned up.

There is no `dart format` gate yet — the repo is not format-clean (~20 files would change). Run a one-shot `dart format lib test` in both packages, then add `dart format --output=none --set-exit-if-changed lib test` to both jobs.
