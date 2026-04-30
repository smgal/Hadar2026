# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter/Dart remake of the classic Korean RPG "또 다른 지식의 성전 (Hadar)". The repo is a multi-package layout, not a single Flutter app.

- `hadar2026_app/` — the Flutter app (Bonfire/Flame engine, `window_manager` for desktop). Entry point `lib/main.dart`.
- `packages/cm2_script/` — standalone Dart package: parser + interpreter for the CM2 scripting language. Pulled in via local path dep.
- `cm2_script_sample/` — CUI demo exercising every cm2_script feature.
- `tools/` — Python scripts for converting/extracting legacy Hadar binary data (maps, enemies, sprites).
- `REF_hadar/` (C++ original), `REF_UNITY_LoreEp1/` (Unity port), `REF_FLUTTER_lore2026/` (sibling Flutter port — git submodule). Read-only reference implementations; do not edit.

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
```

`flame` is pinned to `1.35.1` via `dependency_overrides` and `bonfire` is pinned to exactly `3.16.1` in `hadar2026_app/pubspec.yaml` — don't bump them casually. bonfire 3.17.x assumes flame 1.36+ (`RenderGameWidget(behavior:)`) and will not compile against flame 1.35.1.

## Architecture

### `lib/` is layered: domain / application / presentation

`hadar2026_app/lib/` was reorganized from a flat `models/ + views/ + game_components/ + scripting/` into:

- `domain/` — pure data + game rules. Allowed Flutter import: `foundation.dart` only (for `ChangeNotifier`). Subfolders: `party/`, `map/`, `battle/`, `magic/`, `lighting/`, `console/`, `window/`, plus `game_option.dart`.
- `application/` — use-cases that compose domain with a UI host. No `flutter/material`, no `bonfire`, no `flame`. Contains `game_session.dart`, `menu_flows.dart`, `battle.dart`, `magic_system.dart`, `map_navigation.dart`, `tile_event_dispatcher.dart`, `save_manager.dart`, `select.dart`, `map_loader.dart`, `scripting/` (CM2 adapter + native map scripts), and `ports/` (the abstract host interfaces application calls into — `UiHost`, `PartyMovementHost`).
- `presentation/` — Flutter/Bonfire-bound code: `host/` (`HDFlutterUiHost`, the concrete adapter implementing every `application/ports/` interface), `input/` (`HDInputDispatcher`, `HDVirtualInputState`, `HDInputMode`), `panels/` (the 6 panels + `world_map_renderer.dart` + `player_sprite.dart`), and `window_manager.dart`.
- `lib/hd_game_main.dart` — thin facade that wires the layers together. Singleton, implements `UiHost` + `PartyMovementHost`, forwards both `HDGameSession` and `HDFlutterUiHost` change notifications. Existing `HDGameMain()` call sites and `ListenableBuilder(listenable: HDGameMain(), ...)` keep working unchanged.

When adding a class, pick the layer first. If a domain file ever imports `package:flutter/material.dart` or `package:bonfire/...`, that's a layering violation — push the rendering concern out into `presentation/` or the use-case into `application/`. Application code must not import `lib/presentation/...` either; talk to a port instead.

### Layout (fixed 800×480)
The UI is hand-laid out at fixed pixel coordinates by `lib/main.dart`, scaled with `FittedBox`. Constants live in `lib/hd_config.dart`. Three viewports + a mobile control strip:

- `HDMapViewport` (0,0 / 288×320) — Bonfire game world, camera locked to player.
- `HDConsolePanel` (288,0 / 512×320) — script dialogue + system logs.
- `HDStatusPanel` (0,320 / 800×160) — party HP/SP/ESP grid.
- `HDBottomControlPanel` — virtual D-pad + action buttons for mobile.
- `HDWindowLayer` — overlay stack (battle, magic, etc.) drawn on top of everything.

All five panel widgets live in `lib/presentation/panels/`. See `hadar2026_app/UI_SPEC.md` for the visual spec.

### Singleton-heavy core
Most subsystems are accessed as `Foo()` (factory returning a static instance): `HDGameMain`, `HDGameSession`, `HDFlutterUiHost`, `HDInputDispatcher`, `HDWindowManager`, `HDBattle`, `HDMenuFlows`, `HDTileEventDispatcher`, `HDMapNavigation`, `HDScriptEngine`, `HDNativeScriptRunner`, `HDSelect`, `HDSaveManager`. The codebase intentionally mirrors the original C++ globals — it's not a target for DI refactoring. What was cleaned up is *responsibility splitting*: `HDGameMain` shrank from ~1000 lines to ~185 by handing menu flow / map loading / tile dispatch / input routing / UI hosting / session state to dedicated singletons. New code should pick the right one rather than growing `HDGameMain` again.

`HDGameMain` extends `ChangeNotifier` and is still the source of truth for UI rebuilds (via `ListenableBuilder(listenable: HDGameMain(), …)`). It implements `UiHost` and forwards changes from both `HDFlutterUiHost` and `HDGameSession` (`addListener(notifyListeners)`), so a single listenable still drives the whole UI even though state lives in two layered singletons. `notifyListeners()` is wrapped in `Future.microtask` to avoid notifying during build.

The `UiHost` and `PartyMovementHost` interfaces (`application/ports/`) are the seam if you ever need a headless test driver, a CLI/MUD frontend, or an alternate Flutter layout — application code only ever calls `host.showMenu / addLog / waitForAnyKey / beginNarrative / endNarrative / preloadAssets / animatePartyMove`, never the concrete `HDFlutterUiHost` or `HDGameMain`. To swap frontends, write a new adapter implementing the ports; nothing in `domain/` or `application/` changes.

### Input modes
`HDGameMain.currentInputMode` resolves to one of `HDInputMode.{window, menu, dialogue, map}` in priority order. The global `HardwareKeyboard.instance` handler is registered by `HDInputDispatcher().registerGlobalHandler()`; every key flows through `HDInputDispatcher.process()` which dispatches by current mode (`HDGameMain.processKey()` is now a thin facade over it). Key bindings policy is documented in `docs/key_input_policy.md`:

- Move: arrows / WASD
- Confirm: Enter / E
- Menu/Cancel: Esc / Q / Space (Space opens main menu only on map mode)

Window-mode keys are dispatched by `HDWindowManager._dispatch`, which type-switches on the topmost window (`HDMessageWindow.close()`, `HDMagicSelectionWindow.moveCursor/confirm/cancel`). Domain window classes no longer carry their own `handleInput`.

### Scripting: two parallel runtimes
The game has **two** scripting subsystems running side-by-side. New work generally goes into the native Dart side; the CM2 side is for legacy/data-driven scripts ported from the original.

1. **CM2 scripts** (legacy, line-based DSL) — `.cm2` files under `hadar2026_app/assets/`. Parsed/run by `packages/cm2_script` (`ScriptEngine`). The Hadar-specific command/function set is registered in `lib/application/scripting/script_engine_adapter.dart` (`HDScriptEngine`) — `Talk`, `Map::*`, `Battle::*`, `Player::*`, `Flag::*`, `Variable::*`, `Select::*`, etc. Language reference: `docs/cm2_script_manual.md` and `packages/cm2_script/README.md`.

2. **Native Dart map scripts** — one class per map under `lib/application/scripting/maps/` (e.g. `town1_map_script.dart`), each extending `HDMapScript` with `onLoad/onUnload/onTalk/onSign/onEvent/onEnter` lifecycle hooks. `HDNativeScriptRunner.mapScriptFactory` maps a script name (e.g. `'TOWN1'`) to its constructor. When entering a tile, `HDTileEventDispatcher.check` (called via `HDGameMain.checkTileEvent`) first asks the native runner; if there's no native handler for the current map it falls back to `HDScriptEngine.run()`.

#### CM2 gotcha — initialization vs run phase
`loadFromString()` runs an **initialization phase** that executes `variable`, `include`, and `name.assign`. `run()` then **skips** `variable`/`include` but **re-executes** every `.assign`. So a `score.assign(0)` at the top of the main script will wipe runtime state every loop iteration. Put one-shot initial assignments inside an `include`d file. Unregistered commands silently print "Unknown command" and are skipped; unregistered functions print "Unknown function" and **return 0**, which can silently mis-branch — watch for typos.

### Map data
Maps live as `assets/maps/MapNNN.json` with a name index in `assets/maps/MapInfos.json`. `HDMapNavigation.loadByName(name)` (in `application/map_navigation.dart`) resolves `name` → numeric id via `MapInfos.json` then loads `MapNNN.json` via `HDMapLoader`; `HDGameMain.loadMapFromFile` is a thin facade over it. Don't bypass the index. Tile actions (`HDTileProperties.ACTION_TALK/SIGN/ENTER/EVENT/SWAMP/LAVA/WATER`) drive interaction dispatch in `HDTileEventDispatcher.check`.

### Save/load
`HDSaveManager.saveGame(slot)` / `loadGame(slot)`. Save files are `save_data_*.json` (gitignored). A successful load throws `GameReloadException` to unwind the current run loop — the script engine catches and silently stops on this exception, so do not log it as an error.

## Tests

`hadar2026_app/test/` holds domain/unit tests against the layered code (no widget tests yet). Run from `hadar2026_app/` with `flutter test`. The currently-covered areas are `domain/party/party_actions_test.dart`, `domain/lighting/sight_calculator_test.dart`, and `domain/console/text_utils_test.dart`. New domain rules should land with a test in the matching subfolder.

## Deployment
Web is published to GitHub Pages by `.github/workflows/deploy_web.yml` (manual `workflow_dispatch`). It runs `flutter build web --base-href "/Hadar2026/" --release` in `hadar2026_app/` and pushes `build/web` via `peaceiris/actions-gh-pages@v3`. There is no CI for tests or analyze yet — run `flutter test` and `flutter analyze` locally before pushing.
